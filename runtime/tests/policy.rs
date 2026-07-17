// Policy tests: domain, path, env checks, runtime guards, presets

use super::*;

// ═══════════════════════════════════════
// Policy: Domain checks
// ═══════════════════════════════════════

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

// ═══════════════════════════════════════
// Policy: Path checks
// ═══════════════════════════════════════

#[test]
fn test_check_path_blocks() {
    let p = Policy::standard();
    assert!(!p.check_path("/etc/passwd"));
    assert!(!p.check_path("/etc/shadow"));
    assert!(!p.check_path("~/.ssh/id_rsa"));
    assert!(!p.check_path("~/.aws/credentials"));
    assert!(!p.check_path("/home/user/project/.env"));
    assert!(!p.check_path("C:\\Users\\alice\\AppData\\Roaming\\npm\\npmrc"));
}

#[test]
fn test_check_path_boundary() {
    let p = Policy::standard();
    assert!(p.check_path("/tmp/reports/etc_summary.txt"));
    assert!(p.check_path("/home/user/docs"));
}

// ═══════════════════════════════════════
// Policy: Env var checks
// ═══════════════════════════════════════

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

// ═══════════════════════════════════════
// Runtime guards
// ═══════════════════════════════════════

#[test]
fn test_runtime_network_guard() {
    let p = Policy::standard();
    assert!(sandbox_connect_domain(&p, "api.github.com").is_ok());
    assert!(sandbox_connect_domain(&p, "evil.com").is_err());
}

#[test]
fn test_sandbox_read_file_blocked() {
    let p = Policy::standard();
    assert!(sandbox_read_file(&p, "/etc/shadow").is_err());
}

#[test]
fn test_sandbox_getenv_blocked() {
    let p = Policy::standard();
    assert!(sandbox_getenv(&p, "OPENAI_API_KEY").is_err());
}

// ═══════════════════════════════════════
// Presets
// ═══════════════════════════════════════

#[test]
fn test_strict_preset() {
    let p = Policy::strict();
    assert!(!p.check_domain("example.com"));
    assert!(!p.check_domain("wttr.in"));
    assert!(!p.check_path("/tmp/test.txt"));
    assert!(!p.check_env("USER"));
}

#[test]
fn test_permissive_preset() {
    let p = Policy::permissive();
    assert!(!p.check_domain("192.168.1.1"));
    assert!(p.check_domain("example.com"));
    assert!(!p.check_path("/etc/passwd"));
}

#[test]
fn test_policy_show() {
    let p = Policy::standard();
    let s = p.show();
    assert!(s.contains("standard"));
    assert!(s.contains("Blocked domains"));
}
