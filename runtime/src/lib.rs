//! AegisRun Rust Library v0.6.0
//!
//! ```rust
//! use aegisrun_runtime::Policy;
//!
//! let policy = Policy::standard();
//! assert!(!policy.check_domain("evil.com"));   // blocked
//! assert!(policy.check_domain("wttr.in"));     // allowed
//! assert!(!policy.check_path("/etc/passwd"));  // blocked
//! assert!(!policy.check_env("OPENAI_API_KEY")); // blocked
//! ```

use std::fs;
use serde::Deserialize;

// ═══════════════════════════════════════
// 策略引擎 — 统一从 YAML preset 加载
// ═══════════════════════════════════════

#[derive(Clone)]
pub struct Policy {
    pub blocked_domains: Vec<String>,
    pub domain_suffixes: Vec<String>,
    pub blocked_paths: Vec<String>,
    pub path_prefixes: Vec<String>,
    pub blocked_env_patterns: Vec<String>,
    pub allowed_domains: Vec<String>,
    pub preset: String,
}

// ── YAML 反序列化结构 ──

#[derive(Deserialize, Default)]
struct PresetYaml {
    blacklist: Option<PresetBlacklist>,
    whitelist: Option<PresetWhitelist>,
}

#[derive(Deserialize, Default)]
struct PresetBlacklist {
    network: Option<PresetNetwork>,
    filesystem: Option<PresetFilesystem>,
    env_vars: Option<Vec<String>>,
}

#[derive(Deserialize, Default)]
struct PresetNetwork {
    domains: Option<Vec<String>>,
}

#[derive(Deserialize, Default)]
struct PresetFilesystem {
    paths: Option<Vec<String>>,
}

#[derive(Deserialize, Default)]
struct PresetWhitelist {
    network: Option<PresetNetwork>,
}

impl Policy {
    /// 从编译期嵌入的 YAML preset 加载策略
    pub fn from_preset(name: &str) -> Self {
        let yaml_str = match name {
            "strict" => include_str!("../../presets/strict.yaml"),
            "permissive" => include_str!("../../presets/permissive.yaml"),
            _ => include_str!("../../presets/standard.yaml"),
        };
        Self::from_yaml(yaml_str, name)
    }

    fn from_yaml(yaml_str: &str, name: &str) -> Self {
        let preset: PresetYaml = serde_yaml::from_str(yaml_str).unwrap_or_default();
        let mut blocked_domains = Vec::new();
        let mut domain_suffixes = Vec::new();
        let mut blocked_paths = Vec::new();
        let mut path_prefixes = Vec::new();
        let mut blocked_env_patterns = Vec::new();
        let mut allowed_domains = Vec::new();

        if let Some(bl) = &preset.blacklist {
            if let Some(net) = &bl.network {
                if let Some(domains) = &net.domains {
                    for d in domains {
                        if d.starts_with("*.") {
                            domain_suffixes.push(d.clone());
                        } else {
                            blocked_domains.push(d.clone());
                        }
                    }
                }
            }
            if let Some(fs) = &bl.filesystem {
                if let Some(paths) = &fs.paths {
                    for p in paths {
                        if p.ends_with('*') {
                            let prefix = p.trim_end_matches('*').trim_end_matches('/');
                            path_prefixes.push(prefix.to_string());
                        } else {
                            blocked_paths.push(p.clone());
                        }
                    }
                }
            }
            if let Some(envs) = &bl.env_vars {
                blocked_env_patterns = envs.clone();
            }
        }

        if let Some(wl) = &preset.whitelist {
            if let Some(net) = &wl.network {
                if let Some(domains) = &net.domains {
                    allowed_domains = domains.clone();
                }
            }
        }

        Self {
            blocked_domains,
            domain_suffixes,
            blocked_paths,
            path_prefixes,
            blocked_env_patterns,
            allowed_domains,
            preset: name.to_string(),
        }
    }

    pub fn standard() -> Self { Self::from_preset("standard") }
    pub fn strict() -> Self { Self::from_preset("strict") }
    pub fn permissive() -> Self { Self::from_preset("permissive") }

    /// 检查域名: true=放行
    pub fn check_domain(&self, domain: &str) -> bool {
        for b in &self.blocked_domains {
            if b == "*" || b == domain { return false; }
            if b.ends_with(".*") && domain.starts_with(&b[..b.len()-2]) { return false; }
        }
        for s in &self.domain_suffixes {
            if s.starts_with("*.") && domain.ends_with(&s[1..]) { return false; }
        }
        true
    }

    /// 检查路径: true=放行（exact == + prefix starts_with）
    pub fn check_path(&self, path: &str) -> bool {
        for b in &self.blocked_paths {
            if b == "*" || path == b.as_str() { return false; }
            // ponytail: "/" as exact path in strict mode → also blocks all absolute paths
            if b == "/" && path.starts_with('/') { return false; }
        }
        for pr in &self.path_prefixes {
            if pr.is_empty() || path.starts_with(pr.as_str()) { return false; }
        }
        true
    }

    /// 检查环境变量: true=放行
    pub fn check_env(&self, var: &str) -> bool {
        let upper = var.to_uppercase();
        for p in &self.blocked_env_patterns {
            if p == "*" { return false; }
            if upper.contains(&p.to_uppercase()) { return false; }
        }
        for kw in &["KEY","SECRET","TOKEN","PASSWORD","CREDENTIAL"] {
            if upper.contains(kw) { return false; }
        }
        true
    }

    pub fn show(&self) -> String {
        format!("Preset: {} | Blocked domains: {} | Blocked paths: {} | Blocked env: {} | Allowed domains: {}",
            self.preset, self.blocked_domains.len(), self.blocked_paths.len(), self.blocked_env_patterns.len(), self.allowed_domains.len())
    }
}

// ═══════════════════════════════════════
// OS 级沙箱拦截
// ═══════════════════════════════════════

/// 沙箱安全读文件: 先 check_path，通过才真读
pub fn sandbox_read_file(policy: &Policy, path: &str) -> Result<String, String> {
    if !policy.check_path(path) {
        return Err(format!("BLOCKED: path '{}' denied by security policy", path));
    }
    fs::read_to_string(path).map_err(|e| format!("OS error: {}", e))
}

/// 沙箱安全读环境变量: 先 check_env，通过才真读
pub fn sandbox_getenv(policy: &Policy, var: &str) -> Result<String, String> {
    if !policy.check_env(var) {
        return Err(format!("BLOCKED: env '{}' denied by security policy", var));
    }
    std::env::var(var).map_err(|_| "env not set".to_string())
}

// ═══════════════════════════════════════
// 脚本扫描器
// ═══════════════════════════════════════

/// 扫描脚本源码，返回安全违规列表
pub fn scan_script(source: &str) -> Vec<ScanFinding> {
    let policy = Policy::standard();
    let mut findings = Vec::new();

    for (i, line) in source.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") { continue; }

        // 检测文件操作
        if trimmed.contains("open(") {
            for s in extract_strings(trimmed) {
                if looks_like_path(&s) && !policy.check_path(&s) {
                    findings.push(ScanFinding { line: i+1, kind: "path".into(), value: s, blocked: true });
                }
            }
        }
        // 检测环境变量
        if trimmed.contains("environ.get(") || trimmed.contains("getenv(") {
            for s in extract_strings(trimmed) {
                if is_env_var_name(&s) && !policy.check_env(&s) {
                    findings.push(ScanFinding { line: i+1, kind: "env".into(), value: s, blocked: true });
                }
            }
        }
        // 检测域名
        if trimmed.contains("http://") || trimmed.contains("https://") {
            for host in extract_hosts(trimmed) {
                if !policy.check_domain(&host) {
                    findings.push(ScanFinding { line: i+1, kind: "host".into(), value: host, blocked: true });
                }
            }
        }
    }
    findings
}

pub struct ScanFinding {
    pub line: usize,
    pub kind: String,
    pub value: String,
    pub blocked: bool,
}

// ── 辅助 ──
fn extract_strings(line: &str) -> Vec<String> {
    let mut results = Vec::new();
    let mut in_str = false; let mut quote = '"'; let mut cur = String::new();
    for ch in line.chars() {
        if !in_str && (ch == '"' || ch == '\'') { in_str = true; quote = ch; cur.clear(); }
        else if in_str && ch == quote { in_str = false; if !cur.is_empty() { results.push(cur.clone()); } }
        else if in_str { cur.push(ch); }
    }
    results
}
fn looks_like_path(s: &str) -> bool { s.starts_with('/') || s.starts_with('~') || s.contains(":\\") || s.ends_with(".json") }
fn is_env_var_name(s: &str) -> bool { s.chars().all(|c| c.is_uppercase() || c == '_' || c.is_numeric()) && s.len() > 3 && s.contains('_') }
fn extract_hosts(line: &str) -> Vec<String> {
    let mut hosts = Vec::new();
    for s in extract_strings(line) {
        for prefix in &["https://", "http://"] {
            if let Some(rest) = s.strip_prefix(prefix) {
                let host = rest.split('/').next().unwrap_or(rest).split(':').next().unwrap_or(rest);
                if !host.is_empty() { hosts.push(host.to_string()); }
            }
        }
    }
    hosts
}

// ═══════════════════════════════════════
// Tests
// ═══════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_check_domain_blocks() {
        let p = Policy::standard();
        assert!(!p.check_domain("evil.com"));
        assert!(!p.check_domain("stealer.cc"));
        assert!(!p.check_domain("192.168.1.100"));
        assert!(!p.check_domain("10.0.0.1"));
        assert!(!p.check_domain("127.0.0.1"));
        assert!(!p.check_domain("localhost"));
        assert!(!p.check_domain("data-harvest.cn"));
    }

    #[test]
    fn test_check_domain_allows() {
        let p = Policy::standard();
        assert!(p.check_domain("wttr.in"));
        assert!(p.check_domain("api.github.com"));
        assert!(p.check_domain("example.com"));
    }

    #[test]
    fn test_check_path_blocks() {
        let p = Policy::standard();
        assert!(!p.check_path("/etc/passwd"));
        assert!(!p.check_path("/etc/shadow"));
        assert!(!p.check_path("~/.ssh/id_rsa"));
        assert!(!p.check_path("~/.aws/credentials"));
    }

    #[test]
    fn test_check_path_boundary() {
        let p = Policy::standard();
        // 包含 /etc/ 但不是被拦截的精确路径 → 应放行
        assert!(p.check_path("/tmp/reports/etc_summary.txt"));
        assert!(p.check_path("/home/user/docs"));
    }

    #[test]
    fn test_check_env_blocks() {
        let p = Policy::standard();
        assert!(!p.check_env("OPENAI_API_KEY"));
        assert!(!p.check_env("DATABASE_URL"));
        assert!(!p.check_env("GITHUB_TOKEN"));
        assert!(!p.check_env("ANTHROPIC_API_KEY"));
    }

    #[test]
    fn test_check_env_allows() {
        let p = Policy::standard();
        assert!(p.check_env("USER"));
        assert!(p.check_env("LANG"));
        assert!(p.check_env("HOME"));
    }

    #[test]
    fn test_strict_preset() {
        let p = Policy::strict();
        // strict: all domains blocked
        assert!(!p.check_domain("example.com"));
        assert!(!p.check_domain("wttr.in"));
        // strict: all paths blocked
        assert!(!p.check_path("/tmp/test.txt"));
        // strict: all env blocked
        assert!(!p.check_env("USER"));
    }

    #[test]
    fn test_permissive_preset() {
        let p = Policy::permissive();
        // permissive: still blocks local network
        assert!(!p.check_domain("192.168.1.1"));
        // permissive: allows external
        assert!(p.check_domain("example.com"));
        // permissive: still blocks critical paths
        assert!(!p.check_path("/etc/passwd"));
    }
}
