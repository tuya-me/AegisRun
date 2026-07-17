// WASI sandbox tests: wasmtime physical isolation

use super::*;

#[test]
fn test_sandbox_read_file_allowed() {
    // sandbox_read_file should allow permitted paths
    let policy = Policy::standard();
    let result = sandbox_read_file(&policy, "/tmp/test.txt");
    // File doesn't exist but should not be blocked by policy
    assert!(result.is_err()); // err because file doesn't exist, not because blocked
    let err = result.unwrap_err();
    assert!(!err.contains("BLOCKED"), "Should not be a policy block: {}", err);
}

#[test]
fn test_sandbox_read_file_blocked() {
    let policy = Policy::standard();
    let result = sandbox_read_file(&policy, "/etc/passwd");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("BLOCKED"), "Should be blocked by policy");
}

#[test]
fn test_sandbox_getenv_allowed() {
    let policy = Policy::standard();
    let result = sandbox_getenv(&policy, "USER");
    // USER is not in blocked env patterns for standard preset
    // Result may be Err (env var not set) but should not be BLOCKED
    if let Err(e) = result {
        assert!(!e.contains("BLOCKED"), "Should not be blocked: {}", e);
    }
}

#[test]
fn test_sandbox_getenv_blocked() {
    let policy = Policy::standard();
    let result = sandbox_getenv(&policy, "OPENAI_API_KEY");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("BLOCKED"));
}

#[test]
fn test_sandbox_connect_domain_allowed() {
    let policy = Policy::standard();
    let result = sandbox_connect_domain(&policy, "wttr.in");
    assert!(result.is_ok(), "wttr.in should be allowed");
}

#[test]
fn test_sandbox_connect_domain_blocked() {
    let policy = Policy::standard();
    let result = sandbox_connect_domain(&policy, "evil.com");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("BLOCKED"));
}

#[test]
fn test_sandbox_connect_domain_blocked_internal_ip() {
    let policy = Policy::standard();
    let result = sandbox_connect_domain(&policy, "192.168.1.1");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("BLOCKED"));
}
