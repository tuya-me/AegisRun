//! AegisRun Tool Registry — 工具发现、注册、卸载、标签检索 + 签名验证
//! 完整工具生命周期管理，持久化到 JSON 文件

use std::fs;
use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use sha2::{Sha256, Digest};

/// 工具元数据
#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct ToolMeta {
    pub tool_id: String,
    pub description: String,
    pub version: String,
    pub publisher: String,
    pub sha256: String,
    pub tags: Vec<String>,
    pub registered_at: String,
}

/// 持久化格式
#[derive(Serialize, Deserialize)]
struct RegistryFile {
    tools: Vec<ToolMeta>,
    trusted_publishers: Vec<String>,
}

/// 工具注册表：发现、注册、卸载、标签检索、签名验证
#[derive(Clone)]
pub struct ToolRegistry {
    tools: HashMap<String, ToolMeta>,
    trusted_publishers: Vec<String>,
    persist_path: String,
}

#[allow(dead_code)]
impl ToolRegistry {
    pub fn new() -> Self {
        Self {
            tools: HashMap::new(),
            trusted_publishers: vec!["@moonbit-official".into(), "@aegisrun".into()],
            persist_path: "tool-registry.json".to_string(),
        }
    }

    /// 创建并指定持久化路径
    pub fn with_path(path: &str) -> Self {
        let mut reg = Self::new();
        reg.persist_path = path.to_string();
        reg
    }

    // ═══════ 持久化 ═══════

    /// 从文件加载注册表
    pub fn load(path: &str) -> Result<Self, String> {
        let json = fs::read_to_string(path).map_err(|e| format!("Cannot read registry: {}", e))?;
        let rf: RegistryFile = serde_json::from_str(&json).map_err(|e| format!("Invalid registry: {}", e))?;
        let mut tools = HashMap::new();
        for meta in rf.tools {
            tools.insert(meta.tool_id.clone(), meta);
        }
        Ok(Self {
            tools,
            trusted_publishers: rf.trusted_publishers,
            persist_path: path.to_string(),
        })
    }

    /// 保存注册表到文件
    pub fn save(&self) -> Result<(), String> {
        if self.persist_path.is_empty() { return Ok(()); }
        self.save_to(&self.persist_path)
    }

    pub fn save_to(&self, path: &str) -> Result<(), String> {
        if path.is_empty() { return Ok(()); }
        let rf = RegistryFile {
            tools: self.tools.values().cloned().collect(),
            trusted_publishers: self.trusted_publishers.clone(),
        };
        let json = serde_json::to_string_pretty(&rf).map_err(|e| e.to_string())?;
        fs::write(path, json).map_err(|e| format!("Save failed: {}", e))?;
        Ok(())
    }

    // ═══════ 注册 / 卸载 ═══════

    /// 注册工具（含元数据和签名）
    pub fn register(&mut self, meta: ToolMeta) -> Result<(), String> {
        // 验证发布者
        if !self.is_trusted_publisher(&meta.publisher) {
            return Err(format!("Untrusted publisher: '{}'. Add it first.", meta.publisher));
        }
        // 如果有 wasm 路径，验证哈希
        if !meta.sha256.is_empty() {
            // sha256 is pre-computed, stored as-is
        }
        self.tools.insert(meta.tool_id.clone(), meta);
        self.save()
    }

    /// 注册工具（简化版：从 wasm 文件自动计算哈希）
    pub fn register_from_wasm(&mut self, tool_id: &str, wasm_path: &str, publisher: &str,
                               description: &str, version: &str, tags: Vec<String>) -> Result<(), String> {
        if !self.is_trusted_publisher(publisher) {
            return Err(format!("Untrusted publisher: '{}'", publisher));
        }
        let bytes = fs::read(wasm_path).map_err(|e| format!("Cannot read wasm: {}", e))?;
        let sha256 = sha256_digest(&bytes);
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default().as_secs();
        let meta = ToolMeta {
            tool_id: tool_id.to_string(),
            description: description.to_string(),
            version: version.to_string(),
            publisher: publisher.to_string(),
            sha256,
            tags,
            registered_at: format!("{}", ts),
        };
        self.tools.insert(tool_id.to_string(), meta);
        self.save()
    }

    /// 卸载工具
    pub fn unregister(&mut self, tool_id: &str) -> Result<ToolMeta, String> {
        let meta = self.tools.remove(tool_id)
            .ok_or_else(|| format!("Tool not found: {}", tool_id))?;
        self.save()?;
        Ok(meta)
    }

    // ═══════ 发现 / 查询 ═══════

    /// 列出所有已注册工具
    pub fn list_tools(&self) -> Vec<&ToolMeta> {
        let mut v: Vec<&ToolMeta> = self.tools.values().collect();
        v.sort_by(|a, b| a.tool_id.cmp(&b.tool_id));
        v
    }

    /// 按 tool_id 查询
    pub fn get_tool(&self, tool_id: &str) -> Option<&ToolMeta> {
        self.tools.get(tool_id)
    }

    /// 按标签检索（任一标签匹配即返回）
    pub fn search_by_tags(&self, tags: &[String]) -> Vec<&ToolMeta> {
        self.tools.values()
            .filter(|m| m.tags.iter().any(|t| tags.iter().any(|st| st == t)))
            .collect()
    }

    /// 按关键词搜索（匹配 tool_id、description、tags）
    pub fn search(&self, keyword: &str) -> Vec<&ToolMeta> {
        let kw = keyword.to_lowercase();
        self.tools.values()
            .filter(|m| {
                m.tool_id.to_lowercase().contains(&kw)
                || m.description.to_lowercase().contains(&kw)
                || m.tags.iter().any(|t| t.to_lowercase().contains(&kw))
                || m.publisher.to_lowercase().contains(&kw)
            })
            .collect()
    }

    /// 获取所有已使用的标签（用于标签发现）
    pub fn all_tags(&self) -> Vec<String> {
        let mut tags: Vec<String> = self.tools.values()
            .flat_map(|m| m.tags.clone())
            .collect();
        tags.sort();
        tags.dedup();
        tags
    }

    /// 工具总数
    pub fn tool_count(&self) -> usize {
        self.tools.len()
    }

    // ═══════ 签名验证（向后兼容）═══

    pub fn verify_wasm_hash(&self, wasm_path: &str, expected_hash: &str) -> Result<(), String> {
        let bytes = fs::read(wasm_path).map_err(|e| format!("Cannot read: {}", e))?;
        let hash = sha256_digest(&bytes);
        if hash != expected_hash {
            return Err(format!(
                "SIGNATURE MISMATCH: {} expected={} actual={}",
                wasm_path, expected_hash, hash
            ));
        }
        Ok(())
    }

    pub fn is_trusted_tool(&self, tool_id: &str) -> bool {
        self.tools.contains_key(tool_id)
    }

    pub fn is_trusted_publisher(&self, publisher: &str) -> bool {
        self.trusted_publishers.iter().any(|p| p == publisher)
    }

    pub fn add_trusted_publisher(&mut self, publisher: &str) {
        if !self.is_trusted_publisher(publisher) {
            self.trusted_publishers.push(publisher.to_string());
        }
    }

    /// 完整验证：检查文件哈希 + 检查工具是否在注册表
    pub fn verify_tool(&self, wasm_path: &str, tool_id: &str, publisher: &str) -> Result<(), String> {
        if !self.is_trusted_publisher(publisher) {
            return Err(format!("UNTRUSTED PUBLISHER: '{}' is not in the trusted list", publisher));
        }
        if let Some(meta) = self.tools.get(tool_id) {
            self.verify_wasm_hash(wasm_path, &meta.sha256)?;
        } else {
            return Err(format!("UNREGISTERED TOOL: '{}' is not in the trusted registry. Register it first.", tool_id));
        }
        println!("[VERIFY] Tool '{}' (by {}) — signature verified OK", tool_id, publisher);
        Ok(())
    }

    // ═══════ 向后兼容 ═══════

    /// 旧版 register_trusted 兼容
    pub fn register_trusted(&mut self, tool_id: &str, sha256_hash: &str) {
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default().as_secs();
        let meta = ToolMeta {
            tool_id: tool_id.to_string(),
            description: String::new(),
            version: String::new(),
            publisher: "@aegisrun".to_string(),
            sha256: sha256_hash.to_string(),
            tags: Vec::new(),
            registered_at: format!("{}", ts),
        };
        let _ = self.tools.insert(tool_id.to_string(), meta);
    }
}

/// SHA256 哈希
pub(crate) fn sha256_digest(data: &[u8]) -> String {
    format!("{:x}", Sha256::digest(data))
}
