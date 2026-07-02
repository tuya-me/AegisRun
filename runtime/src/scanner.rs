//! AegisRun Scanner — 扫描 Python/JS 脚本，提取威胁并对照策略引擎
use std::fs;

pub fn run(script_path: &str) {
    let content = match fs::read_to_string(script_path) {
        Ok(c) => c,
        Err(e) => { eprintln!("Failed to read {}: {}", script_path, e); return; }
    };

    // 使用与 main.rs 相同的策略
    let policy = super::Policy::standard();

    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Scanner — Script Security Analysis             ║");
    println!("║  File: {:<48}║", script_path);
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    let mut found = 0;
    let mut blocked = 0;

    for (i, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("//") { continue; }

        // 检测文件操作
        if trimmed.contains("open(") {
            for s in extract_strings(trimmed) {
                if looks_like_path(&s) {
                    found += 1;
                    let ok = policy.check_path(&s);
                    if !ok { blocked += 1; }
                    println!("  {} Line {:3} [{}] path → {}", if ok {"🟢"}else{"🔴"}, i+1, if ok {"ALLOW"}else{"DENY"}, s);
                }
            }
        }

        // 检测环境变量
        if trimmed.contains("environ.get(") || trimmed.contains("os.environ[") || trimmed.contains("getenv(") {
            for s in extract_strings(trimmed) {
                if is_env_var_name(&s) {
                    found += 1;
                    let ok = policy.check_env(&s);
                    if !ok { blocked += 1; }
                    println!("  {} Line {:3} [{}] env  → {}", if ok {"🟢"}else{"🔴"}, i+1, if ok {"ALLOW"}else{"DENY"}, s);
                }
            }
        }

        // 检测域名/URL
        if trimmed.contains("http://") || trimmed.contains("https://") || trimmed.contains("socket.") {
            for host in extract_hosts(trimmed) {
                found += 1;
                let ok = policy.check_domain(&host);
                if !ok { blocked += 1; }
                println!("  {} Line {:3} [{}] host → {}", if ok {"🟢"}else{"🔴"}, i+1, if ok {"ALLOW"}else{"DENY"}, host);
            }
        }
    }

    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("  Found: {} | Blocked: {} | Clean: {}",
             found, blocked, found - blocked);
    if blocked > 0 {
        println!("  VERDICT: {} security violations detected — BLOCKED", blocked);
    } else {
        println!("  VERDICT: No security violations");
    }
    println!("═══════════════════════════════════════════════════════════");
}

fn extract_strings(line: &str) -> Vec<String> {
    let mut results = Vec::new();
    let mut in_str = false;
    let mut quote = '"';
    let mut cur = String::new();
    for ch in line.chars() {
        if !in_str && (ch == '"' || ch == '\'') { in_str = true; quote = ch; cur.clear(); }
        else if in_str && ch == quote { in_str = false; if !cur.is_empty() { results.push(cur.clone()); } }
        else if in_str { cur.push(ch); }
    }
    results
}

fn looks_like_path(s: &str) -> bool {
    s.starts_with('/') || s.starts_with('~') || s.contains(":\\") || s.starts_with("./") || s.ends_with(".json") || s.ends_with(".yaml")
}

fn is_env_var_name(s: &str) -> bool {
    s.chars().all(|c| c.is_uppercase() || c == '_' || c.is_numeric()) && s.len() > 3 && s.contains('_')
}

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
    // Also detect raw IPs
    for s in extract_strings(line) {
        let parts: Vec<&str> = s.split('.').collect();
        if parts.len() == 4 && parts.iter().all(|p| p.parse::<u8>().is_ok()) {
            hosts.push(s);
        }
    }
    hosts
}
