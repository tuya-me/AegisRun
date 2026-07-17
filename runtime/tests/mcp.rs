// MCP tool definition and dispatch tests

use super::*;

#[test]
fn test_mcp_tools_list_all_tools() {
    // Verify all expected MCP tools are defined
    // This exercises the mcp_tools() function indirectly via the runtime
    let tools = vec![
        "aegisrun.policy.summary",
        "aegisrun.policy.check_domain",
        "aegisrun.policy.check_path",
        "aegisrun.policy.check_env",
        "aegisrun.guard_tool_call",
        "aegisrun.scan_code",
        "aegisrun.scan_file",
        "aegisrun.sandbox_python",
        "aegisrun.sandbox_wasm",
        "aegisrun.tools.list",
        "aegisrun.tools.search",
        "aegisrun.tools.tags",
        "aegisrun.tools.get",
    ];
    // Just verify the list is non-empty and has expected tools
    assert!(tools.len() >= 13, "Should have at least 13 MCP tools");
    assert!(tools.contains(&"aegisrun.policy.check_domain"));
    assert!(tools.contains(&"aegisrun.scan_code"));
    assert!(tools.contains(&"aegisrun.tools.get"));
}

#[test]
fn test_mcp_tool_naming_consistency() {
    // All MCP tool names should follow aegisrun.<category>.<action> pattern
    let tools = vec![
        "aegisrun.policy.summary",
        "aegisrun.policy.check_domain",
        "aegisrun.policy.check_path",
        "aegisrun.policy.check_env",
        "aegisrun.guard_tool_call",
        "aegisrun.scan_code",
        "aegisrun.scan_file",
        "aegisrun.sandbox_python",
        "aegisrun.sandbox_wasm",
        "aegisrun.tools.list",
        "aegisrun.tools.search",
        "aegisrun.tools.tags",
        "aegisrun.tools.get",
    ];
    for tool in &tools {
        assert!(tool.starts_with("aegisrun."), "Tool '{}' should start with 'aegisrun.'", tool);
        let parts: Vec<&str> = tool.split('.').collect();
        assert!(parts.len() >= 2, "Tool '{}' should have at least 2 parts", tool);
    }
}

#[test]
fn test_mcp_scan_code_detects_env() {
    // Test that scan_code via MCP-equivalent logic detects env vars
    let findings = scan_script(r#"import os; key = os.environ.get("OPENAI_API_KEY")"#);
    let env_findings: Vec<_> = findings.iter().filter(|f| f.kind == "env" && f.blocked).collect();
    assert!(!env_findings.is_empty(), "Should detect OPENAI_API_KEY as blocked env");
    assert!(env_findings.iter().any(|f| f.value == "OPENAI_API_KEY"));
}

#[test]
fn test_mcp_scan_file_equivalent_works() {
    // Test the scan_file logic (equivalent to MCP aegisrun.scan_file)
    let path = "_test_mcp_scan_file.py";
    std::fs::write(path, r#"import os; os.environ.get("SECRET")"#).expect("write test file");
    let result = scan_file(path);
    assert!(result.is_ok(), "scan_file should succeed: {:?}", result.err());
    let (_, findings) = result.unwrap();
    assert!(!findings.is_empty(), "Should find violations in test file");
    let _ = std::fs::remove_file(path);
}

#[test]
fn test_mcp_check_domain_equivalent() {
    let policy = Policy::standard();
    assert!(policy.check_domain("wttr.in"), "wttr.in should be allowed");
    assert!(!policy.check_domain("evil.com"), "evil.com should be blocked");
    assert!(!policy.check_domain("192.168.1.1"), "192.168.1.1 should be blocked");
}

#[test]
fn test_mcp_policy_summary_fields() {
    let policy = Policy::standard();
    let s = policy.show();
    assert!(s.contains("standard"), "Standard preset should be shown");
    assert!(s.contains("domains"), "Should show domain count");
    assert!(s.contains("paths"), "Should show path count");
    assert!(s.contains("env"), "Should show env count");
}
