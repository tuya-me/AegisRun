//! AegisRun Server — Web Dashboard + MCP endpoint

use std::net::TcpListener;
use std::io::{Read, Write};
use std::sync::{Arc, RwLock, Mutex};
use socket2::{Socket, Domain, Type, Protocol};
use aegisrun_runtime::{scan_script, sandbox_monitor};
use super::Policy;
use super::persist::{PolicyWatcher, AuditLogger};

pub struct DefenseState {
    pub layer1: bool, pub layer2: bool,
    pub layer3: bool, pub layer4: bool, pub layer5: bool,
}

impl DefenseState {
    pub fn all_on() -> Self { Self { layer1: true, layer2: true, layer3: true, layer4: true, layer5: true } }
    pub fn to_json(&self) -> String {
        format!(r#"{{"layer1":{},"layer2":{},"layer3":{},"layer4":{},"layer5":{}}}"#,
            self.layer1, self.layer2, self.layer3, self.layer4, self.layer5)
    }
}

static START_TIME: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

pub fn run(policy: Policy) {
    use std::time::{SystemTime, UNIX_EPOCH};
    START_TIME.store(SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs(), std::sync::atomic::Ordering::Relaxed);
    let mut port = 9090u16;
    let listener = loop {
        let s = match Socket::new(Domain::IPV4, Type::STREAM, Some(Protocol::TCP)) {
            Ok(v) => v, Err(_) => { port += 1; continue; }
        };
        let _ = s.set_reuse_address(true);
        let a: std::net::SocketAddr = format!("127.0.0.1:{}", port).parse().unwrap();
        if s.bind(&a.into()).is_ok() { s.listen(128).unwrap(); break TcpListener::from(s); }
        port += 1;
        if port > 9190 { panic!("No free port (9090-9190)"); }
    };
    if port != 9090 { println!("  (port {} was in use, using {} instead)", 9090, port); }
    let mut watcher = PolicyWatcher::new("policy.json");
    let policy_arc = Arc::new(RwLock::new(policy));
    let defense = Arc::new(RwLock::new(DefenseState::all_on()));
    let audit = Arc::new(Mutex::new(AuditLogger::new("aegisrun-audit.jsonl")));
    println!("\n  AegisRun — http://localhost:{}  |  MCP: /mcp\n", port);
    for stream in listener.incoming().flatten() {
        let _ = watcher.auto_reload();
        let p = policy_arc.clone();
        let d = defense.clone();
        let a = audit.clone();
        std::thread::spawn(move || handle(stream, &p, &d, &a));
    }
}

fn handle(mut s: std::net::TcpStream, p: &Arc<RwLock<Policy>>, d: &Arc<RwLock<DefenseState>>, a: &Arc<Mutex<AuditLogger>>) {
    let mut buf = [0u8; 8192];
    if s.read(&mut buf).is_err() { return; }
    let req = String::from_utf8_lossy(&buf);
    let line = req.lines().next().unwrap_or("");
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.len() < 2 { return; }
    let (method, path) = (parts[0], parts[1]);
    let (status, ct, body) = match (method, path) {
       ("OPTIONS", _) => ("204 No Content", "text/plain", String::new()),
       ("POST", "/mcp") => mcp(&req, &p.read().unwrap(), d, a),
       ("GET", "/api/policy") => pol(&p.read().unwrap()),
       ("POST", "/api/scan") => scan_api(&req),
        ("POST", "/api/sandbox-run") => sandbox_run_api(&req, &p.read().unwrap(), d, a),
       ("GET", "/api/stats") => stats(),
       ("GET", "/api/audit") => audit_api(),
        ("POST", "/api/clear-audit") => clear_audit(),
        ("GET", "/api/defense") => defs(d),
        ("POST", _) if path.starts_with("/api/toggle/") => tog(d, path),
        ("POST", _) if path.starts_with("/api/block/") => block_api(&mut p.write().unwrap(), path),
        ("POST", _) if path.starts_with("/api/unblock/") => unblock_api(&mut p.write().unwrap(), path),
        ("POST", _) if path.starts_with("/api/allow/") => allow_api(&mut p.write().unwrap(), path),
        ("POST", _) if path.starts_with("/api/preset/") => preset_api(&mut p.write().unwrap(), path),
        _ => dash(),
    };
    let cors = if method == "OPTIONS" { "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n" } else { "Access-Control-Allow-Origin: *\r\n" };
    let resp = format!("HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\n{}Connection: close\r\n\r\n{}", status, ct, body.len(), cors, body);
    let _ = s.write_all(resp.as_bytes());
}

fn pol(p: &Policy) -> (&'static str, &'static str, String) {
    ("200 OK", "application/json", serde_json::json!({"preset":p.preset,"blocked_domains":p.blocked_domains,"allowed_domains":p.allowed_domains,"blocked_paths":p.blocked_paths,"blocked_env_patterns":p.blocked_env_patterns}).to_string())
}
fn stats() -> (&'static str, &'static str, String) {
    use std::time::{SystemTime, UNIX_EPOCH};
    let n = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
    let u = n.saturating_sub(START_TIME.load(std::sync::atomic::Ordering::Relaxed));
    ("200 OK", "application/json", serde_json::json!({"status":"active","uptime":format!("{}h {}m {}s",u/3600,u%3600/60,u%60)}).to_string())
}
fn scan_api(req: &str) -> (&'static str, &'static str, String) {
    let raw = req.split("\r\n\r\n").nth(1).unwrap_or("{}");
    let end = raw.rfind('}').map(|i| i+1).unwrap_or(raw.len());
    let body = &raw[..end];
    let v: serde_json::Value = match serde_json::from_str(body) { Ok(v) => v, Err(_) => return ("400","application/json",r#"{"error":"bad json"}"#.into()) };
    let code = match v.get("code").and_then(|c| c.as_str()) { Some(s) => s.to_string(), None => return ("400","application/json",r#"{"error":"no code"}"#.into()) };
    let findings = scan_script(&code);
    let blocked = findings.iter().filter(|f| f.blocked).count();
    let items: Vec<serde_json::Value> = findings.iter().map(|f| serde_json::json!({"line":f.line,"kind":f.kind,"value":f.value,"blocked":f.blocked})).collect();
    ("200 OK", "application/json", serde_json::json!({"violations":blocked,"findings":items}).to_string())
}
fn sandbox_run_api(req: &str, p: &Policy, d: &Arc<RwLock<DefenseState>>, a: &Arc<Mutex<AuditLogger>>) -> (&'static str, &'static str, String) {
    let raw = req.split("\r\n\r\n").nth(1).unwrap_or("{}");
    let end = raw.rfind('}').map(|i| i+1).unwrap_or(raw.len());
    let body = &raw[..end];
    let v: serde_json::Value = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) => return ("400","application/json",r#"{"error":"bad json"}"#.into()),
    };
    let code = match v.get("code").and_then(|c| c.as_str()) {
        Some(s) => s.to_string(),
        None => return ("400","application/json",r#"{"error":"no code"}"#.into()),
    };
    let ds = d.read().unwrap();
    // Static scan
    let static_findings = if ds.layer4 { scan_script(&code) } else { Vec::new() };
    // Runtime sandbox: write code to temp file, run with audit hooks
    let runtime_findings = if ds.layer1 {
        let tmp = std::env::temp_dir().join(format!("aegisrun-web-{}.py", std::process::id()));
        if std::fs::write(&tmp, &code).is_ok() {
            let tmp_str = tmp.to_string_lossy().to_string();
            let findings = sandbox_monitor::run_sandbox(&tmp_str, p);
            let _ = std::fs::remove_file(&tmp);
            findings
        } else {
            Vec::new()
        }
    } else {
        Vec::new()
    };
    let merged = sandbox_monitor::merge_findings(&static_findings, &runtime_findings);
    let blocked = merged.iter().filter(|f| f.blocked).count();
    let items: Vec<serde_json::Value> = merged.iter().map(|f| serde_json::json!({"line":f.line,"kind":f.kind,"value":f.value,"blocked":f.blocked})).collect();
    // Audit log
    if blocked > 0 {
        audit_decision(a, "web-sandbox", "sandbox-run", false, &format!("{} violations", blocked));
    } else {
        audit_decision(a, "web-sandbox", "sandbox-run", true, "clean");
    }
    ("200 OK", "application/json", serde_json::json!({"violations":blocked,"static_findings":static_findings.len(),"runtime_findings":runtime_findings.len(),"findings":items}).to_string())
}
fn audit_api() -> (&'static str, &'static str, String) {
    let c = std::fs::read_to_string("aegisrun-audit.jsonl").unwrap_or_default();
    let mut v: Vec<serde_json::Value> = c.lines().filter_map(|l| serde_json::from_str(l).ok()).collect();
    v.reverse();
    ("200 OK", "application/json", serde_json::json!(v).to_string())
}
fn clear_audit() -> (&'static str, &'static str, String) {
    let _ = std::fs::write("aegisrun-audit.jsonl", "");
    ("200 OK", "application/json", r#"{"ok":true}"#.into())
}
fn block_api(p: &mut Policy, path: &str) -> (&'static str, &'static str, String) {
    let v: Vec<&str> = path.split('/').collect();
    if v.len() < 5 { return ("400","application/json",r#"{"error":"bad path"}"#.into()); }
    match v[3] { "domain" => p.blocked_domains.push(v[4].into()), "path" => p.blocked_paths.push(v[4].into()), _ => return ("400","application/json",r#"{"error":"unknown"}"#.into()) }
    ("200 OK","application/json",r#"{"ok":true}"#.into())
}
fn allow_api(p: &mut Policy, path: &str) -> (&'static str, &'static str, String) {
    let v: Vec<&str> = path.split('/').collect();
    if v.len() >= 5 && v[3] == "domain" { p.allowed_domains.push(v[4].into()); }
    ("200 OK","application/json",r#"{"ok":true}"#.into())
}
fn unblock_api(p: &mut Policy, path: &str) -> (&'static str, &'static str, String) {
    let v: Vec<&str> = path.split('/').collect();
    if v.len() < 5 { return ("400","application/json",r#"{"error":"bad"}"#.into()); }
    match v[3] { "domain" => p.blocked_domains.retain(|x|x!=v[4]), "path" => p.blocked_paths.retain(|x|x!=v[4]), _ => () }
    ("200 OK","application/json",r#"{"ok":true}"#.into())
}
fn preset_api(p: &mut Policy, path: &str) -> (&'static str, &'static str, String) {
    let n = path.strip_prefix("/api/preset/").unwrap_or("standard");
    *p = Policy::from_preset(n);
    ("200 OK","application/json",format!(r#"{{"ok":true,"preset":"{}"}}"#, n))
}
fn defs(d: &Arc<RwLock<DefenseState>>) -> (&'static str, &'static str, String) {
    ("200 OK", "application/json", d.read().unwrap().to_json())
}
fn tog(d: &Arc<RwLock<DefenseState>>, path: &str) -> (&'static str, &'static str, String) {
    let layer = path.strip_prefix("/api/toggle/").unwrap_or("");
    let mut s = d.write().unwrap();
    match layer {
        "layer1" => s.layer1 = !s.layer1, "layer2" => s.layer2 = !s.layer2,
        "layer3" => s.layer3 = !s.layer3, "layer4" => s.layer4 = !s.layer4,
        "layer5" => s.layer5 = !s.layer5, _ => return ("404","application/json",r#"{"error":"unknown"}"#.into()),
    };
    ("200 OK","application/json",r#"{"ok":true}"#.into())
}

fn mcp(req: &str, p: &Policy, d: &Arc<RwLock<DefenseState>>, a: &Arc<Mutex<AuditLogger>>) -> (&'static str, &'static str, String) {
    let body = http_body(req);
    let v: serde_json::Value = match serde_json::from_str(body) {
        Ok(v) => v,
        Err(_) if body.contains("tools/list") => {
            return ("200 OK", "application/json", serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "result": { "tools": mcp_tools() }
            }).to_string());
        }
        Err(_) => return ("200 OK", "application/json", mcp_error(serde_json::json!(null), -32700, "Parse error")),
    };
    let id = v.get("id").cloned().unwrap_or_else(|| serde_json::json!(1));
    let method = v.get("method").and_then(|m| m.as_str()).unwrap_or("");

    if method == "tools/list" || body.contains("\"tools/list\"") {
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": { "tools": mcp_tools() }
        }).to_string());
    }

    if method != "tools/call" {
        return ("200 OK", "application/json", serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": { "message": "ready", "endpoint": "mcp", "tools": "call tools/list" }
        }).to_string());
    }

    let name = v.pointer("/params/name").and_then(|x| x.as_str()).unwrap_or("");
    let args = v.pointer("/params/arguments").unwrap_or(&serde_json::Value::Null);
    let ds = d.read().unwrap();

    let result = match name {
        "aegisrun.policy.summary" => {
            serde_json::json!({
                "preset": p.preset,
                "blocked_domains": p.blocked_domains.len(),
                "allowed_domains": p.allowed_domains.len(),
                "blocked_paths": p.blocked_paths.len(),
                "blocked_env_patterns": p.blocked_env_patterns.len(),
                "defense": {
                    "runtime": ds.layer1,
                    "network": ds.layer2,
                    "filesystem_env": ds.layer3,
                    "scanner": ds.layer4,
                    "audit": ds.layer5
                }
            })
        }
        "aegisrun.policy.check_domain" => {
            let domain = arg_str(args, "domain").unwrap_or("unknown");
            let ok = !ds.layer2 || p.check_domain(domain);
            audit_decision(a, "mcp", "check_domain", ok, domain);
            serde_json::json!({"target": domain, "decision": decision(ok), "layer": "network"})
        }
        "aegisrun.policy.check_path" => {
            let path = arg_str(args, "path").unwrap_or("unknown");
            let ok = !ds.layer3 || p.check_path(path);
            audit_decision(a, "mcp", "check_path", ok, path);
            serde_json::json!({"target": path, "decision": decision(ok), "layer": "filesystem"})
        }
        "aegisrun.policy.check_env" => {
            let var = arg_str(args, "varname").or_else(|| arg_str(args, "env")).unwrap_or("unknown");
            let ok = !ds.layer3 || p.check_env(var);
            audit_decision(a, "mcp", "check_env", ok, var);
            serde_json::json!({"target": var, "decision": decision(ok), "layer": "environment"})
        }
        "aegisrun.scan_code" => {
            let code = arg_str(args, "code").unwrap_or("");
            let findings = if ds.layer4 { scan_script(code) } else { Vec::new() };
            let blocked = findings.iter().filter(|f| f.blocked).count();
            if blocked > 0 { audit_decision(a, "mcp", "scan_code", false, &format!("{} violations", blocked)); }
            serde_json::json!({"decision": decision(blocked == 0), "violations": blocked, "findings": findings_json(&findings)})
        }
        "aegisrun.scan_file" => {
            let path = arg_str(args, "path").unwrap_or("");
            let src = match std::fs::read_to_string(path) {
                Ok(src) => src,
                Err(e) => return ("200 OK", "application/json", mcp_text(&id, format!("Scan failed: {}", e))),
            };
            let findings = if ds.layer4 { scan_script(&src) } else { Vec::new() };
            let blocked = findings.iter().filter(|f| f.blocked).count();
            if blocked > 0 { audit_decision(a, "mcp", "scan_file", false, path); }
            serde_json::json!({"path": path, "decision": decision(blocked == 0), "violations": blocked, "findings": findings_json(&findings)})
        }
        "aegisrun.sandbox_python" => {
            let path = arg_str(args, "path").unwrap_or("");
            let src = std::fs::read_to_string(path).unwrap_or_default();
            let static_findings = if ds.layer4 { scan_script(&src) } else { Vec::new() };
            let runtime_findings = if ds.layer1 { sandbox_monitor::run_sandbox(path, p) } else { Vec::new() };
            let merged = sandbox_monitor::merge_findings(&static_findings, &runtime_findings);
            let blocked = merged.iter().filter(|f| f.blocked).count();
            if blocked > 0 { audit_decision(a, "mcp", "sandbox_python", false, path); }
            serde_json::json!({
                "path": path,
                "decision": decision(blocked == 0),
                "static_findings": static_findings.len(),
                "runtime_findings": runtime_findings.len(),
                "violations": blocked,
                "findings": findings_json(&merged)
            })
        }
        "aegisrun.guard_tool_call" => {
            let report = guard_tool_call(args, p, &ds);
            let ok = report["decision"] == "ALLOW";
            audit_decision(a, "mcp", "guard_tool_call", ok, report["reason"].as_str().unwrap_or("guard"));
            report
        }
        "aegisrun.sandbox_wasm" | "aegisrun.sandbox" => {
            let wasm = arg_str(args, "wasm").or_else(|| arg_str(args, "path")).unwrap_or("tool.wasm");
            let output = std::process::Command::new("target/debug/aegisrun").arg("sandbox").arg(wasm).output();
            let text = match output {
                Ok(x) => {
                    let mut s = String::from_utf8_lossy(&x.stdout).to_string();
                    if !x.stderr.is_empty() {
                        s.push_str(&String::from_utf8_lossy(&x.stderr));
                    }
                    s
                }
                Err(e) => e.to_string(),
            };
            serde_json::json!({"wasm": wasm, "output": text})
        }
        _ => return ("200 OK", "application/json", mcp_error(id, -32602, "Unknown tool")),
    };

    ("200 OK", "application/json", mcp_json_text(&id, result))
}

fn dash() -> (&'static str, &'static str, String) {
    ("200 OK", "text/html; charset=utf-8", include_str!("../../dashboard.html").to_string())
}

fn http_body(req: &str) -> &str {
    req.split("\r\n\r\n").nth(1).unwrap_or("{}").trim_end_matches('\0').trim()
}

fn mcp_tools() -> serde_json::Value {
    serde_json::json!([
        {
            "name": "aegisrun.policy.summary",
            "description": "Return active AegisRun policy and defense-layer state.",
            "inputSchema": {"type": "object", "properties": {}}
        },
        {
            "name": "aegisrun.policy.check_domain",
            "description": "Check whether a network domain is allowed before an agent tool call.",
            "inputSchema": {"type": "object", "properties": {"domain": {"type": "string"}}, "required": ["domain"]}
        },
        {
            "name": "aegisrun.policy.check_path",
            "description": "Check whether a file path is allowed before an agent tool reads or writes it.",
            "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}
        },
        {
            "name": "aegisrun.policy.check_env",
            "description": "Check whether an environment variable name is safe to expose.",
            "inputSchema": {"type": "object", "properties": {"varname": {"type": "string"}}, "required": ["varname"]}
        },
        {
            "name": "aegisrun.guard_tool_call",
            "description": "Preflight a whole agent tool call: domains, paths, env vars, and command text.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "domains": {"type": "array", "items": {"type": "string"}},
                    "paths": {"type": "array", "items": {"type": "string"}},
                    "env": {"type": "array", "items": {"type": "string"}},
                    "command": {"type": "string"}
                }
            }
        },
        {
            "name": "aegisrun.scan_code",
            "description": "Statically scan code provided by an agent for malicious behavior.",
            "inputSchema": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}
        },
        {
            "name": "aegisrun.scan_file",
            "description": "Statically scan a local source file path.",
            "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}
        },
        {
            "name": "aegisrun.sandbox_python",
            "description": "Run a Python script with AegisRun audit-hook runtime monitoring and return merged findings.",
            "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}
        },
        {
            "name": "aegisrun.sandbox_wasm",
            "description": "Run a WebAssembly tool in the wasmtime WASI sandbox.",
            "inputSchema": {"type": "object", "properties": {"wasm": {"type": "string"}}, "required": ["wasm"]}
        }
    ])
}

fn mcp_text(id: &serde_json::Value, text: String) -> String {
    serde_json::json!({"jsonrpc":"2.0","id":id,"result":{"content":[{"type":"text","text":text}]}}).to_string()
}

fn mcp_json_text(id: &serde_json::Value, value: serde_json::Value) -> String {
    mcp_text(id, serde_json::to_string_pretty(&value).unwrap_or_else(|_| "{}".into()))
}

fn mcp_error(id: serde_json::Value, code: i64, message: &str) -> String {
    serde_json::json!({"jsonrpc":"2.0","id":id,"error":{"code":code,"message":message}}).to_string()
}

fn arg_str<'a>(args: &'a serde_json::Value, key: &str) -> Option<&'a str> {
    args.get(key).and_then(|v| v.as_str())
}

fn arg_array(args: &serde_json::Value, key: &str) -> Vec<String> {
    args.get(key)
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default()
}

fn decision(ok: bool) -> &'static str {
    if ok { "ALLOW" } else { "DENY" }
}

fn audit_decision(a: &Arc<Mutex<AuditLogger>>, tool_id: &str, action: &str, ok: bool, reason: &str) {
    let mut al = a.lock().unwrap();
    al.log(tool_id, action, decision(ok), reason);
    al.flush();
}

fn findings_json(findings: &[aegisrun_runtime::ScanFinding]) -> serde_json::Value {
    serde_json::Value::Array(findings.iter().map(|f| {
        serde_json::json!({"line": f.line, "kind": f.kind, "value": f.value, "blocked": f.blocked})
    }).collect())
}

fn guard_tool_call(args: &serde_json::Value, p: &Policy, ds: &DefenseState) -> serde_json::Value {
    let mut violations: Vec<serde_json::Value> = Vec::new();
    let mut domains = arg_array(args, "domains");
    if let Some(domain) = arg_str(args, "domain") { domains.push(domain.to_string()); }
    for domain in domains {
        if ds.layer2 && !p.check_domain(&domain) {
            violations.push(serde_json::json!({"kind":"domain","value":domain,"reason":"blocked by network policy"}));
        }
    }

    let mut paths = arg_array(args, "paths");
    if let Some(path) = arg_str(args, "path") { paths.push(path.to_string()); }
    for path in paths {
        if ds.layer3 && !p.check_path(&path) {
            violations.push(serde_json::json!({"kind":"path","value":path,"reason":"blocked by filesystem policy"}));
        }
    }

    let mut envs = arg_array(args, "env");
    if let Some(var) = arg_str(args, "varname") { envs.push(var.to_string()); }
    for var in envs {
        if ds.layer3 && !p.check_env(&var) {
            violations.push(serde_json::json!({"kind":"env","value":var,"reason":"blocked by environment policy"}));
        }
    }

    if let Some(command) = arg_str(args, "command") {
        for f in scan_script(&format!("cmd = {:?}", command)) {
            if f.blocked {
                violations.push(serde_json::json!({"kind":f.kind,"value":f.value,"reason":"blocked by command scan"}));
            }
        }
        for token in command.split_whitespace() {
            let trimmed = token.trim_matches(|c: char| c == '"' || c == '\'' || c == ',' || c == ';');
            if (trimmed.starts_with('/') || trimmed.starts_with('~') || trimmed.contains(":\\"))
                && ds.layer3 && !p.check_path(trimmed) {
                violations.push(serde_json::json!({"kind":"path","value":trimmed,"reason":"blocked path in command"}));
            }
        }
    }

    let ok = violations.is_empty();
    serde_json::json!({
        "decision": decision(ok),
        "reason": if ok { "all requested capabilities allowed" } else { "one or more capabilities denied" },
        "violations": violations
    })
}
