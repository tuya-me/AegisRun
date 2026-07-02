//! AegisRun WASI Sandbox — 物理隔离，wasmtime 宿主函数拦截
use anyhow::{Context, Result};
use wasmtime::*;
use wasmtime_wasi::p1::WasiP1Ctx;
use wasmtime_wasi::WasiCtxBuilder;

pub fn run(wasm_path: &str) {
    println!();
    println!("╔══════════════════════════════════════════════════════════╗");
    println!("║  AegisRun WASI Sandbox — Physical Isolation              ║");
    println!("║  Loading: {:<48}║", wasm_path);
    println!("╚══════════════════════════════════════════════════════════╝");
    println!();
    println!("Sandbox mode: ZERO preopened directories → no file access");
    println!("               Filtered env vars → no API keys visible");
    println!();

    match execute_wasm(wasm_path) {
        Ok(_) => println!("Tool exited normally (all operations within sandbox)"),
        Err(e) => eprintln!("Tool TERMINATED by sandbox: {}", e),
    }
}

fn execute_wasm(wasm_path: &str) -> Result<()> {
    // 1. wasmtime 引擎
    let engine = Engine::default();
    let wasm_bytes = std::fs::read(wasm_path)
        .with_context(|| format!("Cannot read: {}", wasm_path))?;
    let module = Module::from_binary(&engine, &wasm_bytes)?;

    // 2. WASI 上下文 —— 物理隔离的关键
    let mut wasi = WasiCtxBuilder::new();

    // 只给基础能力
    wasi.inherit_stdio();      // 允许打印（可以看到工具输出）
    wasi.inherit_args();       // 允许命令行参数

    // 不给任何目录预打开 → 工具无法访问任何文件
    // 不调用 wasi.preopened_dir(...)

    // 只给安全的环境变量
    wasi.env("USER", "sandbox-user")
        .env("HOME", "/sandbox-home")
        .env("LANG", "en_US.UTF-8")
        .env("PATH", "/usr/bin");
    // ★ 不给 OPENAI_API_KEY、DATABASE_URL、GITHUB_TOKEN

    let wasi_ctx = wasi.build_p1();
    let mut store = Store::new(&engine, wasi_ctx);

    // 3. 链接 WASI（工具能调的唯一出口）
    let mut linker = Linker::new(&engine);
    wasmtime_wasi::p1::add_to_linker_sync(&mut linker, |s: &mut WasiP1Ctx| s)?;

    let instance = linker.instantiate(&mut store, &module)?;

    // 4. 执行
    println!("═══ Tool Execution (sandboxed) ═══");
    println!();
    let start = instance.get_typed_func::<(), ()>(&mut store, "_start")?;
    start.call(&mut store, ())?;

    Ok(())
}
