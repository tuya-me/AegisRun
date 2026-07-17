// Sandbox monitor tests: merge_findings

use super::*;
use super::sandbox_monitor::{RuntimeFinding, merge_findings};

#[test]
fn test_merge_findings_combines_both() {
    let static_f = vec![
        ScanFinding { line: 1, kind: "host".into(), value: "evil.com".into(), blocked: true },
    ];
    let runtime_f = vec![
        RuntimeFinding {
            line: 5, kind: "env".into(), value: "API_KEY".into(),
            blocked: true, detail: "blocked env access".into(),
        },
    ];
    let merged = merge_findings(&static_f, &runtime_f);
    assert_eq!(merged.len(), 2);
    assert!(merged.iter().any(|f| f.kind == "host"));
    assert!(merged.iter().any(|f| f.kind == "runtime-env"));
}

#[test]
fn test_merge_findings_dedup() {
    let static_f = vec![
        ScanFinding { line: 1, kind: "host".into(), value: "evil.com".into(), blocked: true },
    ];
    let runtime_f = vec![
        RuntimeFinding {
            line: 0, kind: "host".into(), value: "evil.com".into(),
            blocked: true, detail: "runtime detected".into(),
        },
    ];
    let merged = merge_findings(&static_f, &runtime_f);
    // Static and runtime have different key prefixes, so both are kept
    assert_eq!(merged.len(), 2);
}

#[test]
fn test_merge_findings_empty_inputs() {
    let merged = merge_findings(&vec![], &vec![]);
    assert!(merged.is_empty());
}
