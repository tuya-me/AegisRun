//! AegisRun CLI v0.6.0 — 统一入口
//! 该二进制本身不是库——库在 src/lib.rs 和 src/lib/*.mbt
//!
//! 作为库使用:
//!   Rust:  cargo add aegisrun-runtime → use aegisrun_runtime::Policy
//!   MoonBit: moon add aegisrun → import @aegisrun/lib

use aegisrun_runtime::{Policy, scan_script};
mod sandbox;
mod server;
mod persist;
mod verify;

use persist::{AuditLogger, save_policy, load_policy};
use verify::{ToolRegistry, ToolMeta};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("help");

    // 策略持久化：启动时加载 policy.json
    let mut policy = load_policy("policy.json").unwrap_or_else(|_| {
        println!("[INIT] No policy.json found, using standard preset");
        Policy::standard()
    });
    // 工具注册表：尝试加载持久化文件
    let mut registry = ToolRegistry::load("tool-registry.json")
        .unwrap_or_else(|_| ToolRegistry::with_path("tool-registry.json"));
    match cmd {
        "sandbox" => {
            let wasm_path = args.get(2).expect("Usage: aegisrun sandbox <tool.wasm>");
            run_sandbox(wasm_path);
        }
        "scan" => {
            let mut json_output = false;
            let mut code_mode = false;
            let mut source = String::new();
            let mut i = 2;
            while i < args.len() {
                match args[i].as_str() {
                    "--code" => { code_mode = true; i += 1; if i < args.len() { source = args[i].clone(); } }
                    "--json" => { json_output = true; }
                    _ => { if !code_mode { source = args[i].clone(); } }
                }
                i += 1;
            }
            if source.is_empty() {
                eprintln!("Usage: aegisrun scan <file.py|.js>        Scan a file");
                eprintln!("       aegisrun scan --code \"<source>\"    Scan inline code");
                eprintln!("       aegisrun scan <file> --json         JSON output");
                return;
            }
            let (src, findings) = if code_mode {
                (source.clone(), scan_script(&source))
            } else {
                match aegisrun_runtime::scan_file(&source) {
                    Ok(r) => r,
                    Err(e) => { eprintln!("Error: {}", e); return; }
                }
            };
            if json_output {
                let items: Vec<serde_json::Value> = findings.iter().map(|f| serde_json::json!({"line":f.line,"kind":f.kind,"value":f.value,"blocked":f.blocked})).collect();
                println!("{}", serde_json::json!({"source": src, "findings": items, "violations": findings.iter().filter(|f| f.blocked).count()}).to_string());
            } else {
                run_scan_output(&source, &findings, if code_mode { "<inline>" } else { &source });
            }
        }
        "audit" => {
            let content = std::fs::read_to_string("aegisrun-audit.jsonl").unwrap_or_default();
            if content.is_empty() {
                println!("  No audit records found.");
            } else {
                let total = content.lines().count();
                let denied = content.lines().filter(|l| l.contains("\"DENY\"")).count();
                println!("  Audit log ({} entries, {} denied):", total, denied);
                println!("  ─────────────────────────────────────────────");
                for line in content.lines().rev().take(20) {
                    if let Ok(entry) = serde_json::from_str::<serde_json::Value>(line) {
                        let ts = entry.get("timestamp").and_then(|t| t.as_str()).unwrap_or("?");
                        let tid = entry.get("tool_id").and_then(|t| t.as_str()).unwrap_or("?");
                        let act = entry.get("action").and_then(|a| a.as_str()).unwrap_or("?");
                        let dec = entry.get("decision").and_then(|d| d.as_str()).unwrap_or("?");
                        let reason = entry.get("reason").and_then(|r| r.as_str()).unwrap_or("");
                        println!("  [{}] {} {} — {} (ts:{})", tid, act, dec, reason, ts);
                    }
                }
            }
        }
        "verify" => {
            let wasm = args.get(2).cloned().unwrap_or_else(|| "tool.wasm".to_string());
            let tool_id = args.get(3).cloned().unwrap_or_else(|| "unknown".to_string());
            let publisher = args.get(4).cloned().unwrap_or_else(|| "@unknown".to_string());
            match registry.verify_tool(&wasm, &tool_id, &publisher) {
                Ok(_) => println!("[VERIFY] Tool trusted — may execute in sandbox"),
                Err(e) => println!("[VERIFY] BLOCKED: {}", e),
            }
        }
        "register" => {
            let tool_id = args.get(2).expect("Usage: aegisrun register <tool_id> <wasm_path> <publisher> [description] [tags]");
            let wasm = args.get(3).expect("Usage: aegisrun register <tool_id> <wasm_path> <publisher>");
            let publisher = args.get(4).cloned().unwrap_or_else(|| "@aegisrun".to_string());
            let desc = args.get(5).cloned().unwrap_or_default();
            let tags: Vec<String> = args.get(6).map(|s| s.split(',').map(|t| t.trim().to_string()).collect()).unwrap_or_default();
            match registry.register_from_wasm(tool_id, wasm, &publisher, &desc, "0.1.0", tags) {
                Ok(_) => println!("[REGISTER] Tool '{}' registered and saved", tool_id),
                Err(e) => println!("[REGISTER] Failed: {}", e),
            }
        }
        "unregister" => {
            let tool_id = args.get(2).expect("Usage: aegisrun unregister <tool_id>");
            match registry.unregister(tool_id) {
                Ok(meta) => println!("[UNREGISTER] Tool '{}' removed (was v{}, by {})", meta.tool_id, meta.version, meta.publisher),
                Err(e) => println!("[UNREGISTER] Failed: {}", e),
            }
        }
        "list-tools" => {
            let tools = registry.list_tools();
            if tools.is_empty() {
                println!("No tools registered. Use 'aegisrun register' to add tools.");
            } else {
                println!("Registered tools ({}):", tools.len());
                for m in tools {
                    let tags = if m.tags.is_empty() { "—".to_string() } else { m.tags.join(", ") };
                    println!("  {} v{} [{}] by {} — {}", m.tool_id, m.version, tags, m.publisher, m.description);
                }
            }
        }
        "search-tools" => {
            let keyword = args.get(2).unwrap_or_else(|| { println!("Usage: aegisrun search-tools <keyword|tag>"); std::process::exit(0); });
            let results = registry.search(keyword);
            if results.is_empty() {
                println!("No tools match '{}'", keyword);
            } else {
                println!("Tools matching '{}' ({}):", keyword, results.len());
                for m in results {
                    let tags = if m.tags.is_empty() { "—".to_string() } else { m.tags.join(", ") };
                    println!("  {} v{} [{}] — {}", m.tool_id, m.version, tags, m.description);
                }
            }
        }
        "save" => {
            let path = args.get(2).map(|s| s.as_str()).unwrap_or("policy.json");
            match save_policy(&policy, path) {
                Ok(_) => {}
                Err(e) => eprintln!("Save failed: {}", e),
            }
        }
        "serve" => {
            server::run(policy);
        }
        "demo" => run_demo(),
        "policy" => {
            let sub = args.get(2).map(|s| s.as_str()).unwrap_or("show");
            match sub {
                "show" => println!("{}", policy.show()),
                "set" => {
                    let preset = args.get(3).map(|s| s.as_str()).unwrap_or("standard");
                    policy = match preset { "strict" => Policy::strict(), "permissive" => Policy::permissive(), _ => Policy::standard() };
                    println!("Preset: {}", policy.preset);
                }
                "block" => {
                    let target = args.get(3).map(|s| s.as_str()).unwrap_or("");
                    let val = args.get(4).map(|s| s.as_str()).unwrap_or("");
                    if target == "domain" && !val.is_empty() { policy.blocked_domains.push(val.into()); println!("Blocked: {}", val); }
                }
                "allow" => {
                    let target = args.get(3).map(|s| s.as_str()).unwrap_or("");
                    let val = args.get(4).map(|s| s.as_str()).unwrap_or("");
                    if target == "domain" && !val.is_empty() { policy.allowed_domains.push(val.into()); println!("Allowed: {}", val); }
                }
                _ => println!("Usage: aegisrun policy [show|set|block|allow]"),
            }
        }
        _ => print_help(),
    }
}

fn run_demo() {
    let policy = Policy::standard();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Policy Engine Demo                             ║");
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    println!("── Domain Checks ──");
    for (d, expect) in [("wttr.in",true),("evil.com",false),("stealer.cc",false),("192.168.1.100",false),("data-harvest.cn",false)] {
        let r = policy.check_domain(d);
        println!("  {} {} → {}", if r==expect {"✓"}else{"✗"}, d, if r {"ALLOW"}else{"DENY"});
    }
    println!();
    println!("── Path Checks ──");
    for (p, expect) in [("/tmp/logs/app.log",true),("/etc/passwd",false),("~/.ssh/id_rsa",false),("/home/user/docs",true)] {
        let r = policy.check_path(p);
        println!("  {} {} → {}", if r==expect {"✓"}else{"✗"}, p, if r {"ALLOW"}else{"DENY"});
    }
    println!();
    println!("── Env Var Checks ──");
    for (v, expect) in [("USER",true),("OPENAI_API_KEY",false),("DATABASE_URL",false),("GITHUB_TOKEN",false),("LANG",true)] {
        let r = policy.check_env(v);
        println!("  {} {} → {}", if r==expect {"✓"}else{"✗"}, v, if r {"ALLOW"}else{"DENY"});
    }
    println!();
    println!("Policy: {}", policy.show());
}

#[allow(unused_variables)]
fn run_scan_output(label: &str, findings: &[aegisrun_runtime::ScanFinding], _source: &str) {
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Scanner — {:<48}║", label);
    println!("╚══════════════════════════════════════════════════════════╝");
    let blocked = findings.iter().filter(|f| f.blocked).count();
    let flagged = findings.iter().filter(|f| !f.blocked).count();
    for f in findings {
        if f.blocked {
            println!("  🔴 Line {:3} [DENY] {} → {}", f.line, f.kind, f.value);
        } else {
            println!("  🟡 Line {:3} [FLAG] {} → {}", f.line, f.kind, f.value);
        }
    }
    println!("═══════════════════════════════════════════════════════════");
    if blocked > 0 { println!("  {} violations — BLOCKED", blocked); }
    else { println!("  No violations found."); }
    if flagged > 0 { println!("  {} flags — needs review", flagged); }
}

fn run_sandbox(wasm_path: &str) {
    sandbox::run(wasm_path);  // wasmtime WASI sandbox — physical isolation
}

fn print_help() {
    println!();
    println!("{}", "AegisRun v0.6.0 — AI Agent Secure Tool Runtime");
    println!();
    println!("{}", "COMMANDS:");
    println!("  demo                          Run policy engine demo");
    println!("  scan <file> [--json]          Scan file for security threats");
    println!("  scan --code \"<code>\"         Scan inline code (--json for JSON)");
    println!("  audit                         Show audit log (last 20 entries)");
    println!("  sandbox <tool.wasm>           Run WASM in physical isolation");
    println!("  save [path]                   Save policy to JSON file");
    println!("  verify <wasm> <id> <pub>      Verify tool SHA256 signature");
    println!("  register <id> <wasm> <pub> [desc] [tags]  Register tool");
    println!("  unregister <id>               Unregister tool");
    println!("  list-tools                    List all registered tools");
    println!("  search-tools <keyword>        Search tools by keyword or tag");
    println!("  serve                         Web dashboard (port 9090)");
    println!("  policy show                   Show current policy");
    println!("  policy set <preset>           Switch preset");
    println!("  policy block <domain|path|env> <val>  Block an item");
    println!("  policy allow domain <val>     Whitelist a domain");
    println!();
    println!("{}", "EXAMPLES:");
    println!("  aegisrun scan test.py --json");
    println!("  aegisrun scan --code \"import os; os.environ['KEY']\"");
    println!("  aegisrun audit");
    println!("  aegisrun list-tools");
    println!("  aegisrun serve");
    println!();
    println!("{}", "LIBRARY:");
    println!("  Rust:    cargo add aegisrun-runtime");
    println!("           use aegisrun_runtime::{{Policy, scan_script, scan_file}}");
    println!("  MoonBit: moon add aegisrun");
    println!("           import @aegisrun/lib");
    println!();
}

