//! AegisRun Server — Web Dashboard + MCP endpoint
//! 启动后浏览器打开 http://localhost:9090 管理策略
//! MCP 端点在 http://localhost:9090/mcp 供 AI Agent 调用

use std::net::TcpListener;
use std::io::{Read, Write};
use super::Policy;

pub fn run(policy: Policy) {
    let listener = TcpListener::bind("127.0.0.1:9090").expect("Failed to bind port 9090");
    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Web Dashboard                                 ║");
    println!("║  Open: http://localhost:9090                            ║");
    println!("║  MCP:  http://localhost:9090/mcp                        ║");
    println!("║  Press Ctrl+C to stop                                   ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();

    for stream in listener.incoming() {
        if let Ok(mut stream) = stream {
            let mut buf = [0u8; 8192];
            if stream.read(&mut buf).is_err() { continue; }

            let request = String::from_utf8_lossy(&buf);
            let first_line = request.lines().next().unwrap_or("");
            let parts: Vec<&str> = first_line.split_whitespace().collect();
            if parts.len() < 2 { continue; }

            let method = parts[0];
            let path = parts[1];

            let (status, content_type, body) = match (method, path) {
                // MCP 端点
                ("POST", "/mcp") => handle_mcp(&request),
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
                // 静态文件: dashboard.html
                _ => serve_dashboard(),
            };

            let response = format!(
                "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{}",
                status, content_type, body.len(), body
            );
            let _ = stream.write_all(response.as_bytes());
        }
    }
}

fn handle_mcp(request: &str) -> (&'static str, &'static str, String) {
    // 简易 MCP: 提取 JSON body 中的 method
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
        // 提取 domain 参数并检查
        let domain = extract_json_field(body, "domain").unwrap_or("unknown");
        let policy = super::Policy::standard();
        let allowed = policy.check_domain(domain);
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0", "id": 1,
            "result": {
                "content": [{"type": "text", "text": format!("Domain '{}': {}", domain, if allowed {"ALLOW"}else{"DENY"})}]
            }
        }).to_string());
    }

    ("200 OK", "application/json", serde_json::json!({
        "jsonrpc": "2.0", "id": 1, "result": {"message": "AegisRun MCP Server ready"}
    }).to_string())
}

fn serve_dashboard() -> (&'static str, &'static str, String) {
    // 内嵌 dashboard.html
    let html = include_str!("../../dashboard.html");
    ("200 OK", "text/html; charset=utf-8", html.to_string())
}

fn extract_json_field<'a>(json: &'a str, field: &str) -> Option<&'a str> {
    let pattern = format!("\"{}\": \"", field);
    let start = json.find(&pattern)? + pattern.len();
    let end = json[start..].find('"')?;
    Some(&json[start..start+end])
}
