// Audit Logger tests

use super::*;
use super::persist::AuditLogger;

#[test]
fn test_audit_logger_basic() {
    let tmp = std::env::temp_dir().join("aegisrun_test_audit.jsonl");
    let path = tmp.to_string_lossy().to_string();
    {
        let mut logger = AuditLogger::new(&path);
        logger.log("tool-1", "execute", "ALLOW", "safe");
        logger.log("tool-2", "execute", "DENY", "blocked domain");
        assert_eq!(logger.total_entries, 2);
        assert_eq!(logger.denied_count, 1);
        logger.flush();
    }
    let content = std::fs::read_to_string(&path).unwrap();
    let lines: Vec<&str> = content.lines().collect();
    assert_eq!(lines.len(), 2);
    assert!(lines[0].contains("tool-1"));
    assert!(lines[1].contains("tool-2"));
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_audit_logger_batch_flush() {
    let tmp = std::env::temp_dir().join("aegisrun_test_audit_batch.jsonl");
    let path = tmp.to_string_lossy().to_string();
    let _ = std::fs::remove_file(&path);
    {
        let mut logger = AuditLogger::new(&path);
        // batch_size = 50, so 49 entries should NOT trigger auto-flush
        for i in 0..49 {
            logger.log(&format!("tool-{}", i), "exec", "ALLOW", "ok");
        }
        // File should not exist yet (no manual flush, no auto-flush)
        assert!(!std::path::Path::new(&path).exists());
        // The 50th entry triggers auto-flush
        logger.log("tool-49", "exec", "DENY", "bad");
        // Now file should exist
        assert!(std::path::Path::new(&path).exists());
        let content = std::fs::read_to_string(&path).unwrap();
        assert_eq!(content.lines().count(), 50);
    }
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_audit_logger_drop_flushes() {
    let tmp = std::env::temp_dir().join("aegisrun_test_audit_drop.jsonl");
    let path = tmp.to_string_lossy().to_string();
    let _ = std::fs::remove_file(&path);
    {
        let mut logger = AuditLogger::new(&path);
        logger.log("drop-tool", "exec", "ALLOW", "ok");
        // Drop without explicit flush — Drop impl should flush
    }
    let content = std::fs::read_to_string(&path).unwrap();
    assert!(content.contains("drop-tool"));
    let _ = std::fs::remove_file(&tmp);
}

#[test]
fn test_audit_logger_counts() {
    let tmp = std::env::temp_dir().join("aegisrun_test_audit_counts.jsonl");
    let path = tmp.to_string_lossy().to_string();
    let mut logger = AuditLogger::new(&path);
    logger.log("a", "x", "ALLOW", "ok");
    logger.log("b", "x", "DENY", "bad");
    logger.log("c", "x", "DENY", "worse");
    logger.log("d", "x", "ALLOW", "fine");
    assert_eq!(logger.total_entries, 4);
    assert_eq!(logger.denied_count, 2);
    let _ = std::fs::remove_file(&tmp);
}
