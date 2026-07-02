# WASI 拦截器补丁 · 下一版本接入

当前 `runtime/src/main.rs` 已实现真实的 OS 级拦截：
- `sandbox_read_file()` → 先 check_path，再 std::fs::read
- `sandbox_write_file()` → 先 check_path，再 std::fs::write
- `sandbox_getenv()` → 先 check_env，再 std::env::var

接入 wasmtime 后，这些函数会变成 WASI 宿主函数：

```rust
// Step 1: 恢复 Cargo.toml 依赖
[dependencies]
wasmtime = "39"
wasmtime-wasi = "39"

// Step 2: WASI path_open 宿主函数
// 工具 wasm 调用 path_open("/etc/passwd")
// wasmtime 拦截 → 调 AegisRun::sandbox_read_file()
// Deny → wasmtime_trap("BLOCKED")
// Allow → 真正打开文件

// Step 3: WASI environ_get 宿主函数
// 工具 wasm 遍历环境变量
// wasmtime 拦截 → 过滤掉 all blocked patterns
// 工具只能看到非敏感变量
```

接入命令：
```bash
# 恢复 wasmtime 依赖
cargo add wasmtime@39 wasmtime-wasi@39

# 编译 + 运行
cargo build --release
cargo run -- tool.wasm --policy ../policy.example.yaml
```
