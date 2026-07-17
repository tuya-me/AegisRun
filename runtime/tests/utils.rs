// Utility function tests: wildcard, homoglyph, base64, extract, sha256

use super::*;
use super::verify::sha256_digest;

// ═══════════════════════════════════════
// Wildcard matching
// ═══════════════════════════════════════

#[test]
fn test_wildcard_match_exact() {
    assert!(wildcard_match("/etc/passwd", "/etc/passwd"));
    assert!(!wildcard_match("/etc/passwd", "/etc/shadow"));
}

#[test]
fn test_wildcard_match_suffix() {
    assert!(wildcard_match("/home/*", "/home/user/docs"));
    assert!(!wildcard_match("/home/*", "/etc/passwd"));
}

#[test]
fn test_wildcard_match_middle() {
    assert!(wildcard_match("*.evil.com", "sub.evil.com"));
}

#[test]
fn test_wildcard_no_wildcard_char() {
    assert!(wildcard_match("abc", "abc"));
    assert!(!wildcard_match("abc", "abd"));
}

// ═══════════════════════════════════════
// Homoglyph normalization
// ═══════════════════════════════════════

#[test]
fn test_homoglyph_cyrillic() {
    // Cyrillic 'е' → Latin 'e'
    assert_eq!(normalize_homoglyphs("tеst"), "test");
    // Cyrillic 'а' → Latin 'a'
    assert_eq!(normalize_homoglyphs("раth"), "path");
}

#[test]
fn test_homoglyph_zero_width() {
    // Zero-width chars should become spaces
    let s = "hello\u{200b}world";
    let n = normalize_homoglyphs(s);
    assert!(n.contains(' '));
    assert!(!n.contains('\u{200b}'));
}

#[test]
fn test_homoglyph_clean_string_unchanged() {
    assert_eq!(normalize_homoglyphs("normal text"), "normal text");
}

// ═══════════════════════════════════════
// Base64 decoding
// ═══════════════════════════════════════

#[test]
fn test_base64_decode_valid() {
    // "hello" in base64
    assert_eq!(try_decode_base64("aGVsbG8="), Some("hello".into()));
}

#[test]
fn test_base64_decode_too_short() {
    assert_eq!(try_decode_base64("YWJ"), None); // "ab" — too short (< 4 chars decoded)
}

#[test]
fn test_base64_decode_invalid() {
    assert_eq!(try_decode_base64("not-valid-base64!!!"), None);
}

// ═══════════════════════════════════════
// Helper functions
// ═══════════════════════════════════════

#[test]
fn test_extract_strings_basic() {
    let ss = extract_strings(r#"x = "hello" + 'world'"#);
    assert_eq!(ss.len(), 2);
    assert_eq!(ss[0], "hello");
    assert_eq!(ss[1], "world");
}

#[test]
fn test_extract_strings_empty() {
    let ss = extract_strings("x = 42");
    assert!(ss.is_empty());
}

#[test]
fn test_extract_hosts_from_urls() {
    let hosts = extract_hosts(r#"url = "https://evil.com/path""#);
    assert_eq!(hosts.len(), 1);
    assert_eq!(hosts[0], "evil.com");
}

#[test]
fn test_extract_hosts_multiple() {
    let line = r#"a = "https://foo.com/x"; b = "http://bar.org/y""#;
    let hosts = extract_hosts(line);
    assert_eq!(hosts.len(), 2);
    assert!(hosts.contains(&"foo.com".to_string()));
    assert!(hosts.contains(&"bar.org".to_string()));
}

#[test]
fn test_looks_like_path() {
    assert!(looks_like_path("/etc/passwd"));
    assert!(looks_like_path("~/.ssh/id_rsa"));
    assert!(looks_like_path("C:\\Users\\test"));
    assert!(looks_like_path("config.json"));
    assert!(!looks_like_path("hello world"));
    assert!(!looks_like_path("OPENAI_API_KEY"));
}

#[test]
fn test_is_env_var_name() {
    assert!(is_env_var_name("OPENAI_API_KEY"));
    assert!(is_env_var_name("DATABASE_URL"));
    assert!(is_env_var_name("AB_CD"));
    assert!(!is_env_var_name("hello"));
    assert!(!is_env_var_name("ab"));
    assert!(!is_env_var_name("no_underscore"));
}

// ═══════════════════════════════════════
// SHA256 digest (verify module)
// ═══════════════════════════════════════

#[test]
fn test_sha256_digest() {
    let hash = sha256_digest(b"hello");
    assert_eq!(hash.len(), 64); // SHA256 hex = 64 chars
    assert_eq!(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
}

#[test]
fn test_sha256_digest_empty() {
    let hash = sha256_digest(b"");
    assert_eq!(hash.len(), 64);
    assert_eq!(hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
}
