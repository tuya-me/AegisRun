// Policy persistence tests

use super::*;
use super::persist::{save_policy, load_policy, PolicyWatcher};

#[test]
fn test_policy_save_and_load() {
    let tmp = std::env::temp_dir().join("aegisrun_test_policy.json");
    let path = tmp.to_string_lossy().to_string();
    let p = Policy::standard();
    save_policy(&p, &path).unwrap();
    let loaded = load_policy(&path).unwrap();
    assert_eq!(loaded.preset, "standard");
    assert_eq!(loaded.blocked_domains.len(), p.blocked_domains.len());
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_policy_load_nonexistent() {
    assert!(load_policy("/tmp/aegisrun_nonexistent_policy.json").is_err());
}

#[test]
fn test_policy_watcher_detects_change() {
    let tmp = std::env::temp_dir().join("aegisrun_test_watcher.json");
    let path = tmp.to_string_lossy().to_string();

    // Write initial policy
    let p = Policy::standard();
    save_policy(&p, &path).unwrap();

    let mut watcher = PolicyWatcher::new(&path);
    // First check: no change since watcher was created
    assert!(!watcher.check_changed());

    // Modify the file (sleep to ensure mtime advances)
    std::thread::sleep(std::time::Duration::from_millis(100));
    let p2 = Policy::strict();
    save_policy(&p2, &path).unwrap();

    // Now watcher should detect the change
    assert!(watcher.check_changed());
    // Subsequent check: no new change
    assert!(!watcher.check_changed());

    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_policy_watcher_auto_reload() {
    let tmp = std::env::temp_dir().join("aegisrun_test_watcher_reload.json");
    let path = tmp.to_string_lossy().to_string();

    let p = Policy::standard();
    save_policy(&p, &path).unwrap();

    let mut watcher = PolicyWatcher::new(&path);
    assert!(watcher.auto_reload().is_none()); // no change

    std::thread::sleep(std::time::Duration::from_millis(100));
    let p2 = Policy::permissive();
    save_policy(&p2, &path).unwrap();

    let reloaded = watcher.auto_reload();
    assert!(reloaded.is_some());
    assert_eq!(reloaded.unwrap().preset, "permissive");

    let _ = std::fs::remove_file(&tmp);
}
