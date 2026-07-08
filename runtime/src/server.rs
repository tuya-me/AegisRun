//! AegisRun Server — Web Dashboard + MCP endpoint
//! 启动后浏览器打开 http://localhost:9090 管理策略
//! MCP 端点在 http://localhost:9090/mcp 供 AI Agent 调用

use std::net::TcpListener;
use std::io::{Read, Write};
use std::sync::Arc;
use super::Policy;
use super::persist::PolicyWatcher;

pub fn run(policy: Policy) {
    let listener = TcpListener::bind("127.0.0.1:9090").expect("Failed to bind port 9090");
    let mut watcher = PolicyWatcher::new("policy.json");
    let policy_arc = Arc::new(policy);
    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Web Dashboard                                 ║");
    println!("║  Open: http://localhost:9090                            ║");
    println!("║  MCP:  http://localhost:9090/mcp                        ║");
    println!("║  Press Ctrl+C to stop                                   ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    for stream in listener.incoming().flatten() {
        // ponytail: 策略热加载——WATCHER 从死代码激活，检测到变更打印日志
        // 完全热替换需 RwLock，当前变更后重启生效
        let _ = watcher.auto_reload();

        let p = policy_arc.clone();
        std::thread::spawn(move || {
            handle_connection(stream, &p);
        });
    }
}

fn handle_connection(mut stream: std::net::TcpStream, policy: &Policy) {
    let mut buf = [0u8; 8192];
    if stream.read(&mut buf).is_err() { return; }

    let request = String::from_utf8_lossy(&buf);
    let first_line = request.lines().next().unwrap_or("");
    let parts: Vec<&str> = first_line.split_whitespace().collect();
    if parts.len() < 2 { return; }

    let method = parts[0];
    let path = parts[1];

    let (status, content_type, body) = match (method, path) {
        // CORS preflight
        ("OPTIONS", _) => (
            "204 No Content", "text/plain",
            String::new()
        ),
        // MCP 端点（传入实际 policy 而非新建）
        ("POST", "/mcp") => handle_mcp(&request, policy),
        // API 端点
        ("GET", "/api/policy") => (
            "200 OK", "application/json",
            serde_json::json!({
                "preset": policy.preset,
                "blocked_domains": policy.blocked_domains,
                "allowed_domains": policy.allowed_domains,
                "blocked_paths": policy.blocked_paths,
                "blocked_env_patterns": policy.blocked_env_patterns,
            }).to_string()
        ),
        ("GET", "/api/stats") => (
            "200 OK", "application/json",
            serde_json::json!({
                "status": "active",
                "uptime": "running",
                "sandbox_mode": "wasi-zero-preopens"
            }).to_string()
        ),
        _ => serve_dashboard(),
    };

    let extra_headers = if method == "OPTIONS" {
        "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n"
    } else {
        "Access-Control-Allow-Origin: *\r\n"
    };

    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\n{}Connection: close\r\n\r\n{}",
        status, content_type, body.len(), extra_headers, body
    );
    let _ = stream.write_all(response.as_bytes());
}

fn handle_mcp(request: &str, policy: &Policy) -> (&'static str, &'static str, String) {
    let body = request.split("\r\n\r\n").nth(1).unwrap_or("{}");

    if body.contains("tools/list") {
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0", "id": 1,
            "result": {
                "tools": [
                    {"name": "aegisrun.sandbox", "description": "Run tool in WASI sandbox"},
                    {"name": "aegisrun.scan", "description": "Scan script for threats"},
                    {"name": "aegisrun.policy.check_domain", "description": "Check domain against blacklist"},
                    {"name": "aegisrun.policy.check_path", "description": "Check path against blacklist"},
                    {"name": "aegisrun.policy.check_env", "description": "Check env var against blacklist"}
                ]
            }
        }).to_string());
    }

    if body.contains("tools/call") && body.contains("check_domain") {
        let domain = extract_json_field(body, "domain").unwrap_or("unknown");
        let allowed = policy.check_domain(domain);
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0", "id": 1,
            "result": {
                "content": [{"type": "text", "text": format!("Domain '{}': {}", domain, if allowed {"ALLOW"}else{"DENY"})}]
            }
        }).to_string());
    }

    if body.contains("tools/call") && body.contains("check_path") {
        let path = extract_json_field(body, "path").unwrap_or("unknown");
        let allowed = policy.check_path(path);
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0", "id": 1,
            "result": {
                "content": [{"type": "text", "text": format!("Path '{}': {}", path, if allowed {"ALLOW"}else{"DENY"})}]
            }
        }).to_string());
    }

    if body.contains("tools/call") && body.contains("check_env") {
        let varname = extract_json_field(body, "varname").unwrap_or("unknown");
        let allowed = policy.check_env(varname);
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0", "id": 1,
            "result": {
                "content": [{"type": "text", "text": format!("Env '{}': {}", varname, if allowed {"ALLOW"}else{"DENY"})}]
            }
        }).to_string());
    }

    ("200 OK", "application/json", serde_json::json!({
        "jsonrpc": "2.0", "id": 1, "result": {"message": "AegisRun MCP Server ready"}
    }).to_string())
}

fn serve_dashboard() -> (&'static str, &'static str, String) {
    let html = include_str!("../../dashboard.html");
    ("200 OK", "text/html; charset=utf-8", html.to_string())
}

fn extract_json_field<'a>(json: &'a str, field: &str) -> Option<&'a str> {
    // Handle "field":"value" and "field": "value" and "field" : "value"
    let pattern = format!("\"{}\"", field);
    let field_pos = json.find(&pattern)?;
    let after_field = &json[field_pos + pattern.len()..];
    // Skip ": " or ":" or " : " etc.
    let val_start = after_field.find(':')? + 1;
    let after_colon = after_field[val_start..].trim_start();
    if after_colon.starts_with('"') {
        let end = after_colon[1..].find('"')?;
        Some(&after_colon[1..1 + end])
    } else {
        None
    }
}
