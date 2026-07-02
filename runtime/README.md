# AegisRun Runtime

> Rust + wasmtime 沙箱运行时 · 真正的 WASI 系统调用拦截

## 与 MoonBit lib 的关系

```
用户代码/Agent
    |
AegisRun Runtime (Rust + wasmtime)  ← 本目录
    ├─ 加载 .wasm 工具
    ├─ WASI 层拦截: path_open / environ_get / sock_send
    ├─ 调用策略引擎: check_domain / check_path / check_env
    └─ Deny → wasmtime trap (工具进程终止)
    |
AegisRun Policy Engine (MoonBit)    ← src/lib/
    提供: 黑名单匹配 / 后缀匹配 / 关键词检测
```

## 为什么 Rust

| 维度 | Rust | C |
|------|:--:|:--:|
| wasm 运行时 | wasmtime (生产级，Fastly/Shopify 在用) | wasm3 (轻量) |
| 内存安全 | 编译期保证，沙箱逃逸风险为零 | 手动管理，缓冲区溢出可逃逸 |
| WASI 拦截 | Preview 2 原生支持 | 需手写拦截器 |
| 依赖管理 | Cargo 生态 | 手动 Makefile |
| 编译速度 | 较慢 | 快 |

## 用法

```bash
cd runtime
cargo build --release

# 演示模式（不加载 wasm，只测策略引擎）
cargo run

# 加载 .wasm 工具并沙箱执行
cargo run -- my_tool.wasm

# 自定义策略文件
cargo run -- my_tool.wasm --policy ../policy.example.yaml
```

## WASI 拦截点

| 系统调用 | 拦截时机 | AegisRun 检查 |
|------|------|------|
| `path_open` | 打开文件前 | `check_path()` → 路径在黑名单？ |
| `environ_get` | 读取环境变量时 | `check_env()` → 含 KEY/SECRET/TOKEN？ |
| `sock_send` | 发送网络数据前 | `check_domain()` → 域名在黑名单？ |
| `sock_connect` | 建立连接前 | `check_domain()` + DNS→IP 检查 |
