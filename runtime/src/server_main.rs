//! AegisRun Server Daemon — 独立进程，与 CLI 互不干扰
//! 启动: cargo run --bin aegisrund

use aegisrun_runtime::Policy;

mod server;
mod persist;

fn main() {
    let policy = persist::load_policy("policy.json").unwrap_or_else(|_| {
        println!("[INIT] No policy.json found, using standard preset");
        Policy::standard()
    });
    server::run(policy);
}
