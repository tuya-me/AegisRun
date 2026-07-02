//! AegisRun Rust Library v0.4.0
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

// ═══════════════════════════════════════
// 策略引擎
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

impl Policy {
    pub fn standard() -> Self {
        Self {
            blocked_domains: vec!["evil.com".into(),"stealer.cc".into(),"192.168.*".into(),"10.*".into(),"172.16.*".into(),"127.0.0.1".into(),"localhost".into()],
            domain_suffixes: vec!["*.cn".into(),"*.ru".into(),"*.tk".into()],
            blocked_paths: vec!["/etc/passwd".into(),"/etc/shadow".into(),"~/.ssh/id_rsa".into(),"~/.aws/credentials".into()],
            path_prefixes: vec!["~/.ssh/".into(),"~/.aws/".into(),"/etc/".into()],
            blocked_env_patterns: vec!["AWS_SECRET".into(),"OPENAI_API_KEY".into(),"ANTHROPIC_API_KEY".into(),"DATABASE_URL".into(),"REDIS_URL".into(),"GITHUB_TOKEN".into(),"DOCKER_PASSWORD".into(),"KUBECONFIG".into()],
            allowed_domains: vec!["wttr.in".into(),"api.github.com".into()],
            preset: "standard".into(),
        }
    }

    pub fn strict() -> Self { let mut p = Self::standard(); p.blocked_domains.push("*".into()); p.allowed_domains.clear(); p.preset = "strict".into(); p }
    pub fn permissive() -> Self { let mut p = Self::standard(); p.blocked_domains.retain(|d| d.starts_with("192.")||d.starts_with("10.")||d.starts_with("172.")); p.blocked_paths = vec!["/etc/passwd".into(),"/etc/shadow".into()]; p.path_prefixes = vec!["/etc/".into()]; p.preset = "permissive".into(); p }

    /// 检查域名: true=放行
    pub fn check_domain(&self, domain: &str) -> bool {
        for b in &self.blocked_domains {
            if b == domain { return false; }
            if b.ends_with(".*") && domain.starts_with(&b[..b.len()-2]) { return false; }
        }
        for s in &self.domain_suffixes {
            if s.starts_with("*.") && domain.ends_with(&s[1..]) { return false; }
        }
        true
    }

    /// 检查路径: true=放行
    pub fn check_path(&self, path: &str) -> bool {
        for b in &self.blocked_paths { if path.contains(b.as_str()) { return false; } }
        for pr in &self.path_prefixes { if path.contains(pr.as_str()) { return false; } }
        true
    }

    /// 检查环境变量: true=放行
    pub fn check_env(&self, var: &str) -> bool {
        for p in &self.blocked_env_patterns { if var.to_uppercase().contains(&p.to_uppercase()) { return false; } }
        for kw in &["KEY","SECRET","TOKEN","PASSWORD","CREDENTIAL"] { if var.to_uppercase().contains(kw) { return false; } }
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
    std::env::var(var).map_err(|_| format!("env not set"))
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
