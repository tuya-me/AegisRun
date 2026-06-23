# AegisRun 开发者贡献指南

> v0.3.0 | 如何参与开发 | 可贡献方向 | 代码规范

---

## 一、项目架构

```
aegisrun/
├── src/lib/              核心库（MoonBit，纯逻辑，无 IO）
│   ├── core.mbt           黑名单引擎 + 策略引擎
│   ├── sandbox.mbt        沙箱拦截层（网络/文件/环境变量/资源）
│   ├── scorer.mbt         风险评分引擎 v1.1
│   ├── sql_guard.mbt      SQL 资源控制 v1.2
│   ├── limiter.mbt        三维并发限流 v1.3
│   ├── monitor.mbt        压力监控 + 熔断 v1.4
│   ├── dns_guard.mbt      DNS 劫持检测 + IP 黑名单 v0.3
│   ├── alert.mbt          告警通知 v0.3
│   └── dashboard.mbt      终端仪表盘 v0.3
│
├── runtime/              沙箱运行时（Rust，真正拦截 syscall）
│   ├── src/main.rs        wasmtime + WASI 拦截器
│   └── Cargo.toml
│
├── src/generator/        恶意脚本生成 + 拦截演示
├── src/full_demo/        Full 集成测试（13 项）
├── src/sandbox_demo/     沙箱演示（22 项）
├── docs/                  公开文档
└── presets/              安全预设（YAML）
```

**两层模型**：
- **MoonBit 库**做判断（`check_domain` 返回 Allow/Deny）
- **Rust 运行时**做拦截（wasmtime trap 终止工具进程）

---

## 二、可以增加的方向

### 代码层面（低门槛）

| 方向 | 难度 | 说明 | 文件 |
|------|:--:|------|------|
| 添加新域名到黑名单 | 低 | 在 `load_standard_preset` 里加一行 `state.blacklist_domains.set("xxx", "reason")` | `core.mbt` |
| 添加新敏感路径 | 低 | 在 `default_blacklist_paths()` 返回数组里加路径 | `core.mbt` |
| 添加新环境变量模式 | 低 | 在 `default_blacklist_envs()` 里加模式 | `core.mbt` |
| 添加新 IP 黑名单段 | 低 | 在 `load_default_ip_rules()` 里加 `bl.cidr_prefixes.push(...)` | `dns_guard.mbt` |
| 扩展风险评分扣分项 | 中 | 在 `score_manifest` 里加新的检查维度 | `scorer.mbt` |
| 添加新的 SQL 拦截规则 | 中 | 在 `guard_query` 里加新的 SQL 关键词检测 | `sql_guard.mbt` |
| 扩展限流维度 | 中 | 在 `acquire` 里加"按用户"维度的限流 | `limiter.mbt` |

### 安全层面（需设计）

| 方向 | 难度 | 说明 |
|------|:--:|------|
| WASI 拦截器完整实现 | 高 | 在 Rust runtime 里实现 `path_open` / `sock_connect` 的 wasmtime 宿主函数拦截 |
| DNS 查询拦截 | 高 | 在 Rust runtime 里拦截 WASI `dns_lookup`，返回过滤后的 IP |
| MoonBit→Rust FFI | 高 | MoonBit 编译到 native，Rust 调用 MoonBit 的 `check_domain` 函数 |
| 多工具间内存隔离 | 高 | 每个工具独立 wasmtime instance，Heap 完全隔离 |
| 工具签名验证 | 中 | 加载 .wasm 前验证 Ed25519 签名，拒绝未签名工具 |
| 策略自动学习 | 高 | 从审计日志中学习正常行为模式，自动生成白名单 |

### 体验层面

| 方向 | 难度 | 说明 |
|------|:--:|------|
| Web 仪表盘 | 中 | MoonBit 生成 HTML/CSS/JS 静态页面，`moon run src/dashboard` 输出 HTML 文件 |
| 日志文件写盘 | 低 | 当前审计日志只 println，加 `fs.write` 写入 `aegisrun-audit.jsonl` |
| 策略持久化 | 中 | 程序退出前把当前策略写回 `policy.yaml`，下次启动自动加载 |
| 命令行自动补全 | 低 | 生成 bash/pwsh completion 脚本 |
| VSCode 插件 | 中 | 在 VSCode 侧边栏显示 AegisRun 拦截统计 |

---

## 三、安全加固方向（优先级排名）

### 高优先级

1. **WASI 拦截器完整实现**
   - 当前 `runtime/src/main.rs` 只是框架，`path_open`/`sock_send` 的 wasmtime 宿主函数还没写
   - 完成后工具就算没有 `check_domain` 调用，沙箱层也会自动拦截

2. **MoonBit→Rust FFI**
   - MoonBit 编译到 native（LLVM 后端）
   - Rust 通过 FFI 调用 `extern "C" fn check_domain(domain: *const c_char) -> i32`
   - 策略引擎改动只需改 MoonBit 代码，Rust 方自动同步

3. **审计日志文件写入**
   - 当前 `println` 输出，程序退出就丢
   - 改为追加写入 `aegisrun-audit.jsonl`，配合 `aegisrun audit` 查询

### 中优先级

4. **工具签名验证**
   - 每个 .wasm 文件附带 `.sig` 签名
   - 加载时验证签名是否在白名单发布者列表中
   - 未签名工具→拒绝加载

5. **策略热加载文件监控**
   - 当前改 `policy.yaml` 不生效（没有文件监控）
   - 加入 `notify` crate，文件变更时自动重载策略

### 低优先级（长期）

6. **多工具间资源配额**
   - CPU time slice、memory hard limit、网络带宽限制
   - 防止一个工具耗尽宿主机资源

7. **攻击回放测试框架**
   - 自动生成恶意工具 → 跑沙箱 → 验证拦截 → 记录报告
   - 作为 CI 的一部分

---

## 四、代码规范

### MoonBit

```moonbit
// 文件名: snake_case.mbt
// 函数: snake_case
// 公开: pub fn
// 私有: fn（无 pub）
// struct: PascalCase

pub fn check_domain(...) -> Decision { ... }
fn extract_host(url : String) -> String { ... }
```

### Rust

```rust
// 标准 Rust 风格: rustfmt
// 文件: src/main.rs
// 函数: snake_case
// 结构体: PascalCase
// 错误处理: anyhow::Result
```

### 注释

- `//` 单行注释用于逻辑说明
- `// ── Section ──` 分节
- `///` 文档注释（Rust）
- 每个公开函数必须有中文注释说明用途

### 测试

- MoonBit: 在 `src/` 下新建 `*_test.mbt`，用 `fn main` 做集成测试
- Rust: `cargo test`
- 提交前必须 `moon build` 确认 0 error

---

## 五、提交流程

```bash
git checkout -b feature/xxx
# 写代码...
git add -A
git commit -m "feat: description"
git push origin feature/xxx
# 在 GitLink 创建 PR → review → merge
```

---

## 六、当前项目状态

| 指标 | 数值 |
|------|------|
| MoonBit 核心模块 | 10 个 (`src/lib/`) |
| MoonBit 代码行数 | ~1,250 行 |
| Rust 运行时 | 1 个文件，210 行 |
| 测试覆盖 | 14+22+13+14 = 63 项 |
| 编译器版本 | MoonBit 0.1.20260608 |
| 编译目标 | wasm-gc |
| 许可证 | Apache 2.0 |
