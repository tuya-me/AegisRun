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
use verify::ToolRegistry;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("help");

    // 策略持久化：启动时加载 policy.json
    let mut policy = load_policy("policy.json").unwrap_or_else(|_| {
        println!("[INIT] No policy.json found, using standard preset");
        Policy::standard()
    });
    match cmd {
        "sandbox" => {
            let wasm_path = args.get(2).expect("Usage: aegisrun sandbox <tool.wasm>");
            run_sandbox(wasm_path);
        }
        "scan" => {
            let script_path = args.get(2).expect("Usage: aegisrun scan <file.py|file.js>");
            run_scan(script_path);
        }
        "audit" => {
            let mut logger = AuditLogger::new("aegisrun-audit.jsonl");
            logger.log("weather-query", "execute", "DENY", "evil.com in blacklist");
            logger.log("log-analyzer", "execute", "DENY", "/etc/passwd blocked");
            logger.log("calculator", "execute", "ALLOW", "safe tool");
            logger.flush();
            println!("Audit log saved: aegisrun-audit.jsonl ({} entries, {} denied)",
                     logger.total_entries, logger.denied_count);
        }
        "verify" => {
            let wasm = args.get(2).cloned().unwrap_or_else(|| "tool.wasm".to_string());
            let tool_id = args.get(3).cloned().unwrap_or_else(|| "unknown".to_string());
            let publisher = args.get(4).cloned().unwrap_or_else(|| "@unknown".to_string());
            let registry = ToolRegistry::new();
            match registry.verify_tool(&wasm, &tool_id, &publisher) {
                Ok(_) => println!("[VERIFY] Tool trusted — may execute in sandbox"),
                Err(e) => println!("[VERIFY] BLOCKED: {}", e),
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

fn run_scan(path: &str) {
    let source = std::fs::read_to_string(path).unwrap_or_else(|e| { eprintln!("Failed: {}", e); String::new() });
    let findings = scan_script(&source);
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun Scanner — {:<48}║", path);
    println!("╚══════════════════════════════════════════════════════════╝");
    for f in &findings {
        println!("  🔴 Line {:3} [DENY] {} → {}", f.line, f.kind, f.value);
    }
    let blocked = findings.iter().filter(|f| f.blocked).count();
    println!("═══════════════════════════════════════════════════════════");
    if blocked > 0 { println!("  {} violations — BLOCKED", blocked); }
    else { println!("  No violations found."); }
}

fn run_sandbox(wasm_path: &str) {
    sandbox::run(wasm_path);  // wasmtime WASI sandbox — physical isolation
}

fn print_help() {
    println!(r#"
AegisRun v0.6.0 — AI Agent Secure Tool Runtime

USAGE:
  aegisrun demo                         Policy engine demo
  aegisrun scan <file.py|.js>           Scan script for threats
  aegisrun sandbox <tool.wasm>           OS-level sandbox interception
  aegisrun save [path]                    Save policy to JSON file
  aegisrun audit                          Write audit log to JSONL
  aegisrun verify <wasm> <id> <pub>       Verify tool signature
  aegisrun serve                          Web dashboard (port 9090, auto-reload)
  aegisrun policy [show|set|block|allow]

LIBRARY:
  Rust:    cargo add aegisrun-runtime → use aegisrun_runtime::Policy
  MoonBit: moon add aegisrun → import @aegisrun/lib
"#);
}
