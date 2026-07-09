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
/// 全面扫描: 不依赖特定函数调用，扫描所有行的字符串/域名/路径
pub fn scan_script(source: &str) -> Vec<ScanFinding> {
    let policy = Policy::standard();
    let mut findings = Vec::new();
    let sensitive_commands = ["curl ", "wget ", "ssh ", "scp ", "sftp ", "telnet ", "nc "];

    for (i, line) in source.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") { continue; }

        let strings = extract_strings(trimmed);
        let hosts = extract_hosts(trimmed);

        // 1. 扫描所有字符串: 检查是否是敏感环境变量名
        for s in &strings {
            if is_env_var_name(s) && !policy.check_env(s) {
                findings.push(ScanFinding { line: i+1, kind: "env".into(), value: s.clone(), blocked: true });
            }
            if s.contains(' ') || s.contains('/') {
                for token in s.split(&[' ', '/', '\t', ':'][..]) {
                    let t = token.trim();
                    if is_env_var_name(t) && !policy.check_env(t) {
                        findings.push(ScanFinding { line: i+1, kind: "env".into(), value: t.to_string(), blocked: true });
                        break;
                    }
                }
            }
        }

        // 2. 检查 shell 命令中的嵌入路径
        for s in &strings {
            if looks_like_path(s) && !policy.check_path(s) {
                findings.push(ScanFinding { line: i+1, kind: "path".into(), value: s.clone(), blocked: true });
            }
            if s.contains(' ') {
                for token in s.split_whitespace() {
                    if looks_like_path(token) && !policy.check_path(token) {
                        findings.push(ScanFinding { line: i+1, kind: "path".into(), value: token.to_string(), blocked: true });
                        break;
                    }
                }
            }
        }

        // 3. 敏感 shell 命令 + subprocess URL 检测
        for cmd in &sensitive_commands {
            if trimmed.contains(cmd) {
                for s in &strings {
                    for token in s.split_whitespace() {
                        if token.starts_with("http://") || token.starts_with("https://") {
                            for host in extract_hosts(token) {
                                if !policy.check_domain(&host) {
                                    findings.push(ScanFinding { line: i+1, kind: "host".into(), value: host.clone(), blocked: true });
                                }
                            }
                        }
                        if looks_like_path(token) && !policy.check_path(token) {
                            findings.push(ScanFinding { line: i+1, kind: "path".into(), value: token.to_string(), blocked: true });
                        }
                    }
                }
                break;
            }
        }

        // 4a. 敏感编码函数调用
        let encoding_funcs = ["base64.b64decode", "binascii.unhexlify", "unhexlify",
                              "base64_decode", "fromhex", "translate("];
        for func in &encoding_funcs {
            if trimmed.contains(func) {
                for s in &strings {
                    if is_env_var_name(s) && !policy.check_env(s) {
                        findings.push(ScanFinding { line: i+1, kind: "encoded-env".into(), value: s.clone(), blocked: false });
                    }
                }
                findings.push(ScanFinding { line: i+1, kind: "suspicious".into(), value: format!("encoding call: {}", func), blocked: false });
            }
        }

        // 4b. 解码 base64 并检查解码后的内容
        for s in &strings {
            if s.len() >= 8 && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '/' || c == '=') {
                if let Some(decoded) = try_decode_base64(s) {
                    let norm = normalize_homoglyphs(&decoded);
                    if is_env_var_name(&norm) && !policy.check_env(&norm) {
                        findings.push(ScanFinding { line: i+1, kind: "env".into(), value: norm.clone(), blocked: true });
                    }
                    if looks_like_path(&norm) && !policy.check_path(&norm) {
                        findings.push(ScanFinding { line: i+1, kind: "path".into(), value: norm.clone(), blocked: true });
                    }
                }
            }
        }

        // 4c. config/dynamic URL/env 检测
        if ["configparser", "json.load(", "yaml.load(", "yaml.safe_load(", "config.read(", "config.get("].iter().any(|f| trimmed.contains(f)) {
            findings.push(ScanFinding { line: i+1, kind: "suspicious".into(), value: "external config read".into(), blocked: false });
        }
        if trimmed.contains("f\"https://") || trimmed.contains("f'https://") {
            findings.push(ScanFinding { line: i+1, kind: "suspicious".into(), value: "dynamic URL f-string".into(), blocked: true });
        }
        if (trimmed.contains("os.environ.get(") || trimmed.contains("environ.get(")) && !strings.iter().any(|s| is_env_var_name(s)) {
            findings.push(ScanFinding { line: i+1, kind: "suspicious".into(), value: "dynamic env var read".into(), blocked: true });
        }

        // 4d. 预编译字节码检测
        for func in &["compile(", "py_compile", ".pyc", "marshal.loads(", "pickle.loads("] {
            if trimmed.contains(func) {
                findings.push(ScanFinding { line: i+1, kind: "suspicious".into(), value: format!("bytecode: {}", func), blocked: false });
            }
        }

        // 5. 扫描所有提取的域名 + IP
        for host in &hosts {
            if !policy.check_domain(host) {
                findings.push(ScanFinding { line: i+1, kind: "host".into(), value: host.clone(), blocked: true });
            }
        }

        // 6. 检测裸域名（未带 http:// 的纯域名字符串）
        for s in &strings {
            let dots = s.chars().filter(|&c| c == '.').count();
            if dots >= 1 && dots <= 3 && !s.contains(' ') && s.len() > 5 {
                let host = normalize_homoglyphs(s);
                if host.as_str() != s.as_str() && !policy.check_domain(&host) {
                    findings.push(ScanFinding { line: i+1, kind: "host".into(), value: host.clone(), blocked: true });
                }
            }
        }
    }
    findings
}

#[derive(Clone)]
pub struct ScanFinding {
    pub line: usize,
    pub kind: String,
    pub value: String,
    pub blocked: bool,
}

pub mod sandbox_monitor;

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
fn normalize_homoglyphs(s: &str) -> String {
    s.chars().map(|c| match c {
        'е' => 'e', 'Е' => 'E', 'а' => 'a', 'А' => 'A',
        'о' => 'o', 'О' => 'O', 'с' => 'c', 'С' => 'C',
        'р' => 'p', 'Р' => 'P', 'х' => 'x', 'Х' => 'X',
        'і' => 'i', 'І' => 'I', 'В' => 'B', 'К' => 'K',
        'М' => 'M', 'Н' => 'H', 'Т' => 'T', 'У' => 'Y',
        _ if c == '\u{200b}' || c == '\u{200c}' || c == '\u{200d}' || c == '\u{feff}' || c == '\u{2060}' => ' ',
        _ => c,
    }).collect()
}

fn try_decode_base64(s: &str) -> Option<String> {
    use base64::Engine as _;
    let engine = base64::engine::general_purpose::STANDARD;
    if let Ok(bytes) = engine.decode(s) {
        if let Ok(text) = String::from_utf8(bytes) {
            if text.len() > 3 { return Some(text); }
        }
    }
    None
}
fn looks_like_path(s: &str) -> bool { let n = normalize_homoglyphs(s); n.starts_with('/') || n.starts_with('~') || n.contains(":\\") || n.ends_with(".json") }
fn is_env_var_name(s: &str) -> bool { let n = normalize_homoglyphs(s); n.chars().all(|c| c.is_uppercase() || c == '_' || c.is_numeric()) && n.len() > 3 && n.contains('_') }
fn extract_hosts(line: &str) -> Vec<String> {
    let mut hosts = Vec::new();
    for s in extract_strings(line) {
        for prefix in &["https://", "http://"] {
            if let Some(rest) = s.strip_prefix(prefix) {
                let raw = rest.split('/').next().unwrap_or(rest).split(':').next().unwrap_or(rest);
                let host = normalize_homoglyphs(raw);
                if !host.is_empty() && !host.chars().any(|c| c > '\u{007f}') { hosts.push(host); }
            }
        }
    }
    hosts
}

fn extract_hosts_from_str(s: &str) -> Vec<String> {
    let mut hosts = Vec::new();
    for prefix in &["https://", "http://"] {
        if let Some(rest) = s.strip_prefix(prefix) {
            let raw = rest.split('/').next().unwrap_or(rest).split(':').next().unwrap_or(rest);
            let host = normalize_homoglyphs(raw);
            if !host.is_empty() { hosts.push(host); }
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
