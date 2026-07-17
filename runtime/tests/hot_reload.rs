// Policy hot-reload tests: PolicyWatcher change detection

use super::*;
use super::persist::{save_policy, load_policy, PolicyWatcher};
use std::io::Write;

#[test]
fn test_policy_save_and_load() {
    let mut policy = Policy::standard();
    policy.blocked_domains.push("test-block.com".into());
    let path = "_test_policy_save.json";
    save_policy(&policy, path).expect("save should succeed");
    let loaded = load_policy(path).expect("load should succeed");
    assert_eq!(loaded.preset, "standard");
    assert!(loaded.blocked_domains.contains(&"test-block.com".to_string()));
    let _ = std::fs::remove_file(path);
}

#[test]
fn test_policy_load_nonexistent() {
    let result = load_policy("_nonexistent_policy_file.json");
    assert!(result.is_err(), "Loading nonexistent file should fail");
}

#[test]
fn test_policy_watcher_detect_change() {
    let path = "_test_watcher_change.json";
    let mut policy = Policy::standard();
    save_policy(&policy, path).expect("initial save");
    let mut watcher = PolicyWatcher::new(path);
    // Initially should not detect change
    assert!(!watcher.check_changed(), "Should not detect change on fresh watcher");
    // Modify the file
    policy.blocked_domains.push("new-block.com".into());
    save_policy(&policy, path).expect("modified save");
    std::thread::sleep(std::time::Duration::from_millis(100)); // ensure mtime changes
    assert!(watcher.check_changed(), "Should detect change after file modification");
    // Second check should return false (mtime already recorded)
    assert!(!watcher.check_changed(), "Should not detect same change twice");
    let _ = std::fs::remove_file(path);
}

#[test]
fn test_policy_watcher_auto_reload() {
    let path = "_test_autoreload.json";
    let mut policy = Policy::standard();
    save_policy(&policy, path).expect("initial save");
    let mut watcher = PolicyWatcher::new(path);
    // Auto-reload with no changes should return None
    assert!(watcher.auto_reload().is_none(), "No change should return None");
    // Modify file then auto-reload should return Some(policy)
    policy.blocked_domains.push("reload-test.com".into());
    save_policy(&policy, path).expect("modified save");
    std::thread::sleep(std::time::Duration::from_millis(100));
    let reloaded = watcher.auto_reload();
    assert!(reloaded.is_some(), "Change should trigger reload");
    let r = reloaded.unwrap();
    assert!(r.blocked_domains.contains(&"reload-test.com".to_string()));
    let _ = std::fs::remove_file(path);
}

#[test]
fn test_policy_change_detection_multiple_changes() {
    let path = "_test_multi_change.json";
    let mut policy = Policy::standard();
    save_policy(&policy, path).expect("initial save");
    let mut watcher = PolicyWatcher::new(path);
    // First change
    policy.blocked_domains.push("first.com".into());
    save_policy(&policy, path).expect("first change");
    std::thread::sleep(std::time::Duration::from_millis(100));
    assert!(watcher.check_changed(), "First change should be detected");
    // Second change
    policy.blocked_domains.push("second.com".into());
    save_policy(&policy, path).expect("second change");
    std::thread::sleep(std::time::Duration::from_millis(100));
    assert!(watcher.check_changed(), "Second change should be detected");
    let _ = std::fs::remove_file(path);
}
