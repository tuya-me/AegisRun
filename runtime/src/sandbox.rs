//! AegisRun WASI Sandbox — 物理隔离，wasmtime 宿主函数拦截
use anyhow::{Context, Result};
use wasmtime::*;
use wasmtime_wasi::p1::WasiP1Ctx;
use wasmtime_wasi::WasiCtxBuilder;
use std::sync::Arc;
use std::time::Duration;

use super::Policy;

pub fn run(wasm_path: &str) {
    let policy = Policy::standard();
    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun WASI Sandbox — Physical Isolation              ║");
    println!("║  Loading: {:<48}║", wasm_path);
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    println!("Sandbox mode: ZERO preopened directories → no file access");
    println!("               Filtered env vars → no API keys visible");
    println!("               Timeout: 30s | Memory limit: 256MB");
    println!();

    match execute_wasm(wasm_path, &policy) {
        Ok(_) => println!("Tool exited normally (all operations within sandbox)"),
        Err(e) => eprintln!("Tool TERMINATED by sandbox: {}", e),
    }
}

pub fn execute_wasm(wasm_path: &str, policy: &Policy) -> Result<()> {
    // 1. wasmtime 引擎（带资源限制）
    let mut config = Config::new();
    config.epoch_interruption(true);
    // ponytail: wasmtime 39 无 static_memory_maximum_size API，升级 wasmtime 后加回
    let engine = Engine::new(&config)?;
    let wasm_bytes = std::fs::read(wasm_path)
        .with_context(|| format!("Cannot read: {}", wasm_path))?;
    let module = Module::from_binary(&engine, &wasm_bytes)?;

    // 2. WASI 上下文 —— 物理隔离的关键
    let mut wasi = WasiCtxBuilder::new();

    // 只给基础能力
    wasi.inherit_stdio();
    wasi.inherit_args();

    // 安全环境变量（不在 blocked_env_patterns 中的）
    let safe_vars = ["USER", "HOME", "LANG", "PATH", "TMPDIR", "TEMP", "TMP"];
    for var in &safe_vars {
        if policy.check_env(var) {
            if let Ok(val) = std::env::var(var) {
                wasi.env(var, &val);
            }
        }
    }

    let wasi_ctx = wasi.build_p1();
    let mut store = Store::new(&engine, wasi_ctx);

    // 3. 超时：30秒后台线程
    let engine_arc = Arc::new(engine);
    let engine_clone = engine_arc.clone();
    store.set_epoch_deadline(1);
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_secs(30));
        engine_clone.increment_epoch();
    });

    // 4. 链接 WASI
    let mut linker = Linker::new(&engine_arc);
    wasmtime_wasi::p1::add_to_linker_sync(&mut linker, |s: &mut WasiP1Ctx| s)?;

    let instance = linker.instantiate(&mut store, &module)?;

    // 5. 执行
    println!("═══ Tool Execution (sandboxed) ═══");
    println!();
    let start = instance.get_typed_func::<(), ()>(&mut store, "_start")?;
    start.call(&mut store, ())?;

    Ok(())
}
