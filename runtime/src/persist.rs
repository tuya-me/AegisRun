//! AegisRun Persistence — 审计日志写盘 + 策略持久化 + 热加载
//! 三项功能合一：写入/读取/监控

use serde::{Serialize, Deserialize};
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

// ═══════ 审计日志 ═══════

#[derive(Serialize, Deserialize, Clone)]
pub struct AuditEntry {
    pub timestamp: String,
    pub tool_id: String,
    pub action: String,
    pub decision: String,
    pub reason: String,
}

pub struct AuditLogger {
    path: String,
    buffer: Vec<AuditEntry>,
    batch_size: usize,
    pub total_entries: usize,
    pub denied_count: usize,
}

impl AuditLogger {
    pub fn new(path: &str) -> Self {
        Self { path: path.to_string(), buffer: Vec::new(), batch_size: 50, total_entries: 0, denied_count: 0 }
    }

    pub fn log(&mut self, tool_id: &str, action: &str, decision: &str, reason: &str) {
        let ts = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let entry = AuditEntry {
            timestamp: format!("{}", ts),
            tool_id: tool_id.to_string(),
            action: action.to_string(),
            decision: decision.to_string(),
            reason: reason.to_string(),
        };
        if decision == "DENY" { self.denied_count += 1; }
        self.buffer.push(entry);
        self.total_entries += 1;
        if self.buffer.len() >= self.batch_size { self.flush(); }
    }

    pub fn flush(&mut self) {
        use std::io::Write;
        let mut content = String::new();
        for entry in &self.buffer {
            content.push_str(&serde_json::to_string(entry).unwrap());
            content.push('\n');
        }
        // ponytail: append-only，不读全文件重写
        if let Ok(mut file) = std::fs::OpenOptions::new().append(true).create(true).open(&self.path) {
            let _ = file.write_all(content.as_bytes());
        }
        self.buffer.clear();
    }
}

impl Drop for AuditLogger {
    fn drop(&mut self) {
        if !self.buffer.is_empty() {
            self.flush();
        }
    }
}

// ═══════ 异步审计日志（channel + 后台线程）═══

use std::sync::mpsc;
use std::time::Duration;

/// 异步审计日志：log() 不阻塞，后台线程攒批写入
pub struct BufAuditLogger {
    sender: mpsc::Sender<AuditEntry>,
    #[allow(dead_code)]
    handle: Option<std::thread::JoinHandle<()>>,
}

impl BufAuditLogger {
    pub fn new(path: &str) -> Self {
        let (tx, rx) = mpsc::channel::<AuditEntry>();
        let path = path.to_string();
        let handle = std::thread::spawn(move || {
            let mut buffer: Vec<AuditEntry> = Vec::new();
            let batch_size = 50;
            loop {
                match rx.recv_timeout(Duration::from_millis(500)) {
                    Ok(entry) => {
                        buffer.push(entry);
                        if buffer.len() >= batch_size {
                            flush_entries(&path, &buffer);
                            buffer.clear();
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Timeout) => {
                        if !buffer.is_empty() {
                            flush_entries(&path, &buffer);
                            buffer.clear();
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Disconnected) => {
                        if !buffer.is_empty() {
                            flush_entries(&path, &buffer);
                        }
                        break;
                    }
                }
            }
        });
        Self { sender: tx, handle: Some(handle) }
    }

    /// 非阻塞写审计日志（直接发到 channel）
    pub fn log(&self, tool_id: &str, action: &str, decision: &str, reason: &str) {
        let ts = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let entry = AuditEntry {
            timestamp: format!("{}", ts),
            tool_id: tool_id.to_string(),
            action: action.to_string(),
            decision: decision.to_string(),
            reason: reason.to_string(),
        };
        let _ = self.sender.send(entry); // 忽略错误（后台线程已退出）
    }
}

fn flush_entries(path: &str, entries: &[AuditEntry]) {
    use std::io::Write;
    let mut content = String::new();
    for entry in entries {
        content.push_str(&serde_json::to_string(entry).unwrap());
        content.push('\n');
    }
    if let Ok(mut file) = std::fs::OpenOptions::new().append(true).create(true).open(path) {
        let _ = file.write_all(content.as_bytes());
    }
}

// ═══════ 策略持久化 ═══════

use crate::Policy; // Policy defined in lib.rs

#[derive(Serialize, Deserialize)]
struct PolicyFile {
    preset: String,
    blocked_domains: Vec<String>,
    allowed_domains: Vec<String>,
    blocked_paths: Vec<String>,
    blocked_env_patterns: Vec<String>,
}

#[allow(dead_code)]
pub fn save_policy(policy: &Policy, path: &str) -> Result<(), String> {
    let pf = PolicyFile {
        preset: policy.preset.clone(),
        blocked_domains: policy.blocked_domains.clone(),
        allowed_domains: policy.allowed_domains.clone(),
        blocked_paths: policy.blocked_paths.clone(),
        blocked_env_patterns: policy.blocked_env_patterns.clone(),
    };
    let json = serde_json::to_string_pretty(&pf).map_err(|e| e.to_string())?;
    fs::write(path, json).map_err(|e| e.to_string())?;
    println!("[PERSIST] Policy saved to {}", path);
    Ok(())
}

pub fn load_policy(path: &str) -> Result<Policy, String> {
    if !Path::new(path).exists() {
        return Err(format!("Policy file not found: {}", path));
    }
    let json = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let pf: PolicyFile = serde_json::from_str(&json).map_err(|e| e.to_string())?;

    let mut policy = match pf.preset.as_str() {
        "strict" => Policy::strict(),
        "permissive" => Policy::permissive(),
        _ => Policy::standard(),
    };

    // Override with saved values
    policy.blocked_domains = pf.blocked_domains;
    policy.allowed_domains = pf.allowed_domains;
    policy.blocked_paths = pf.blocked_paths;
    policy.blocked_env_patterns = pf.blocked_env_patterns;
    policy.preset = pf.preset;

    println!("[PERSIST] Policy loaded from {}", path);
    Ok(policy)
}

// ═══════ 策略热加载（文件监控）═══

use std::time::SystemTime as StdTime;

pub struct PolicyWatcher {
    path: String,
    last_modified: Option<StdTime>,
    callback_count: usize,
}

impl PolicyWatcher {
    pub fn new(path: &str) -> Self {
        let lm = Path::new(path).metadata().ok().and_then(|m| m.modified().ok());
        Self { path: path.to_string(), last_modified: lm, callback_count: 0 }
    }

    /// 检查文件是否变更，变更了返回 true
    pub fn check_changed(&mut self) -> bool {
        if let Ok(meta) = fs::metadata(&self.path) {
            if let Ok(mtime) = meta.modified() {
                let changed = self.last_modified.is_none_or(|lm| mtime > lm);
                if changed {
                    self.last_modified = Some(mtime);
                    self.callback_count += 1;
                    return true;
                }
            }
        }
        false
    }

    /// 如果有变更，自动重新加载策略
    pub fn auto_reload(&mut self) -> Option<Policy> {
        if self.check_changed() {
            match load_policy(&self.path) {
                Ok(p) => {
                    println!("[WATCHER] Policy reloaded (change #{})", self.callback_count);
                    return Some(p);
                }
                Err(e) => eprintln!("[WATCHER] Reload failed: {}", e),
            }
        }
        None
    }
}
