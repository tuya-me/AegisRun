// Tool Registry tests

use super::*;
use super::verify::{ToolRegistry, ToolMeta};

fn test_meta(id: &str, tags: Vec<&str>) -> ToolMeta {
    ToolMeta {
        tool_id: id.to_string(),
        description: format!("Test tool {}", id),
        version: "0.1.0".to_string(),
        publisher: "@aegisrun".to_string(),
        sha256: "abc123".to_string(),
        tags: tags.into_iter().map(|s| s.to_string()).collect(),
        registered_at: "1234567890".to_string(),
    }
}

#[test]
fn test_registry_register_and_list() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("tool-a", vec!["net"])).unwrap();
    reg.register(test_meta("tool-b", vec!["fs"])).unwrap();
    assert_eq!(reg.tool_count(), 2);
    let tools = reg.list_tools();
    assert_eq!(tools.len(), 2);
    // list_tools returns sorted by tool_id
    assert_eq!(tools[0].tool_id, "tool-a");
    assert_eq!(tools[1].tool_id, "tool-b");
}

#[test]
fn test_registry_unregister() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("tool-x", vec![])).unwrap();
    assert_eq!(reg.tool_count(), 1);
    let removed = reg.unregister("tool-x").unwrap();
    assert_eq!(removed.tool_id, "tool-x");
    assert_eq!(reg.tool_count(), 0);
}

#[test]
fn test_registry_unregister_nonexistent() {
    let mut reg = ToolRegistry::with_path("");
    assert!(reg.unregister("ghost").is_err());
}

#[test]
fn test_registry_get_tool() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("lookup-me", vec!["tag1"])).unwrap();
    let found = reg.get_tool("lookup-me");
    assert!(found.is_some());
    assert_eq!(found.unwrap().tool_id, "lookup-me");
    assert!(reg.get_tool("nope").is_none());
}

#[test]
fn test_registry_search_by_keyword() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("weather-fetcher", vec!["net", "weather"])).unwrap();
    reg.register(test_meta("log-analyzer", vec!["fs", "logs"])).unwrap();
    reg.register(test_meta("weather-station", vec!["iot"])).unwrap();

    let results = reg.search("weather");
    assert_eq!(results.len(), 2);
    let ids: Vec<&str> = results.iter().map(|m| m.tool_id.as_str()).collect();
    assert!(ids.contains(&"weather-fetcher"));
    assert!(ids.contains(&"weather-station"));
}

#[test]
fn test_registry_search_by_description() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(ToolMeta {
        tool_id: "calc".into(),
        description: "A fast calculator tool".into(),
        version: "1.0.0".into(),
        publisher: "@aegisrun".into(),
        sha256: "".into(),
        tags: vec![],
        registered_at: "0".into(),
    }).unwrap();
    let results = reg.search("calculator");
    // "calculator" matches "calculator" in description "A fast calculator tool"
    assert_eq!(results.len(), 1);
}

#[test]
fn test_registry_search_by_tags() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("alpha", vec!["security", "net"])).unwrap();
    reg.register(test_meta("beta", vec!["fs"])).unwrap();
    reg.register(test_meta("gamma", vec!["security"])).unwrap();

    let results = reg.search_by_tags(&["security".to_string()]);
    assert_eq!(results.len(), 2);
}

#[test]
fn test_registry_all_tags() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("t1", vec!["net", "security"])).unwrap();
    reg.register(test_meta("t2", vec!["fs", "net"])).unwrap();

    let tags = reg.all_tags();
    assert_eq!(tags.len(), 3);
    assert!(tags.contains(&"fs".to_string()));
    assert!(tags.contains(&"net".to_string()));
    assert!(tags.contains(&"security".to_string()));
}

#[test]
fn test_registry_untrusted_publisher_rejected() {
    let mut reg = ToolRegistry::with_path("");
    let meta = ToolMeta {
        tool_id: "evil-tool".into(),
        description: "bad".into(),
        version: "0.0.1".into(),
        publisher: "@random-hacker".into(),
        sha256: "".into(),
        tags: vec![],
        registered_at: "0".into(),
    };
    assert!(reg.register(meta).is_err());
    assert_eq!(reg.tool_count(), 0);
}

#[test]
fn test_registry_add_trusted_publisher() {
    let mut reg = ToolRegistry::with_path("");
    assert!(!reg.is_trusted_publisher("@new-pub"));
    reg.add_trusted_publisher("@new-pub");
    assert!(reg.is_trusted_publisher("@new-pub"));

    let meta = ToolMeta {
        tool_id: "new-tool".into(),
        description: "from new publisher".into(),
        version: "1.0.0".into(),
        publisher: "@new-pub".into(),
        sha256: "".into(),
        tags: vec![],
        registered_at: "0".into(),
    };
    assert!(reg.register(meta).is_ok());
}

#[test]
fn test_registry_persistence_roundtrip() {
    let tmp = std::env::temp_dir().join("aegisrun_test_registry.json");
    let path = tmp.to_string_lossy().to_string();

    {
        let mut reg = ToolRegistry::with_path(&path);
        reg.register(test_meta("persist-tool", vec!["test"])).unwrap();
        assert_eq!(reg.tool_count(), 1);
    }

    // Reload from disk
    let reg2 = ToolRegistry::load(&path).unwrap();
    assert_eq!(reg2.tool_count(), 1);
    assert!(reg2.is_trusted_tool("persist-tool"));

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_registry_backward_compat_register_trusted() {
    let mut reg = ToolRegistry::with_path("");
    reg.register_trusted("legacy-tool", "deadbeef");
    assert!(reg.is_trusted_tool("legacy-tool"));
    assert_eq!(reg.tool_count(), 1);
}

#[test]
fn test_registry_is_trusted_tool() {
    let mut reg = ToolRegistry::with_path("");
    reg.register(test_meta("trusted-1", vec![])).unwrap();
    assert!(reg.is_trusted_tool("trusted-1"));
    assert!(!reg.is_trusted_tool("untrusted-1"));
}
