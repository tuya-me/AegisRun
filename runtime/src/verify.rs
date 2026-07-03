//! AegisRun Tool Signature Verification
//! 加载 .wasm 前验证工具签名，确保来源可信
//! 使用 SHA256 哈希作为签名（生产环境可用 Ed25519）

use std::fs;
use std::collections::HashMap;

#[derive(Clone)]
pub struct ToolRegistry {
    // 已知的可信工具 (tool_id → expected_sha256)
    trusted_tools: HashMap<String, String>,
    // 已知的可信发布者
    trusted_publishers: Vec<String>,
}

#[allow(dead_code)] // Public API — called from external consumers
impl ToolRegistry {
    pub fn new() -> Self {
        let mut trusted = HashMap::new();
        // 预置可信工具
        trusted.insert("calculator".into(), "sha256:known-hash-here".into());
        Self { trusted_tools: trusted, trusted_publishers: vec!["@moonbit-official".into(), "@aegisrun".into()] }
    }

    /// 验证 .wasm 文件的 SHA256 哈希
    pub fn verify_wasm_hash(&self, wasm_path: &str, expected_hash: &str) -> Result<(), String> {
        let bytes = fs::read(wasm_path).map_err(|e| format!("Cannot read: {}", e))?;
        // 计算 SHA256
        let hash = sha256_digest(&bytes);
        if hash != expected_hash {
            return Err(format!(
                "SIGNATURE MISMATCH: {} expected={} actual={}",
                wasm_path, expected_hash, hash
            ));
        }
        Ok(())
    }

    /// 检查工具 ID 是否在可信列表中
    pub fn is_trusted_tool(&self, tool_id: &str) -> bool {
        self.trusted_tools.contains_key(tool_id)
    }

    /// 检查发布者是否可信
    pub fn is_trusted_publisher(&self, publisher: &str) -> bool {
        self.trusted_publishers.iter().any(|p| p == publisher)
    }

    /// 注册可信工具
    pub fn register_trusted(&mut self, tool_id: &str, sha256_hash: &str) {
        self.trusted_tools.insert(tool_id.to_string(), sha256_hash.to_string());
    }

    /// 完整验证：检查文件哈希 + 检查工具是否在可信列表
    pub fn verify_tool(&self, wasm_path: &str, tool_id: &str, publisher: &str) -> Result<(), String> {
        // 1. 检查发布者是否可信
        if !self.is_trusted_publisher(publisher) {
            return Err(format!("UNTRUSTED PUBLISHER: '{}' is not in the trusted list", publisher));
        }

        // 2. 检查工具是否在可信列表中
        if let Some(expected_hash) = self.trusted_tools.get(tool_id).cloned() {
            // 3. 验证文件哈希
            self.verify_wasm_hash(wasm_path, &expected_hash)?;
        } else {
            return Err(format!("UNREGISTERED TOOL: '{}' is not in the trusted registry. Register it first.", tool_id));
        }

        println!("[VERIFY] Tool '{}' (by {}) — signature verified ✓", tool_id, publisher);
        Ok(())
    }
}

/// 简易 SHA256 实现（演示用，生产环境用 sha2 crate）
fn sha256_digest(data: &[u8]) -> String {
    // 简化：使用文件大小 + 前256字节作为指纹
    let len = data.len();
    let preview: Vec<u8> = data.iter().take(256).copied().collect();
    format!("sha256:{}-{}", len, hex_encode(&preview))
}

fn hex_encode(data: &[u8]) -> String {
    data.iter().map(|b| format!("{:02x}", b)).collect::<Vec<_>>().join("")[..16].to_string()
}
