//! AegisRun Server Daemon — 独立进程，与 CLI 互不干扰
//! 启动: cargo run --bin aegisrund

use aegisrun_runtime::Policy;
use aegisrun_runtime::persist::load_policy;

mod server;

fn main() {
    let policy = load_policy("policy.json").unwrap_or_else(|_| {
        println!("[INIT] No policy.json found, using standard preset");
        Policy::standard()
    });
    server::run(policy);
}
