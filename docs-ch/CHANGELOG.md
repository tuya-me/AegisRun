# AegisRun 更新日志

> 🇬🇧 [English version →](../docs-en/CHANGELOG.md)


---

## v0.8.0 (2026-07-08) — 消除架构二重性

- **7 项架构二重性消除**：策略数据双源、重复扫描器、仪表盘双份、评分不经过沙箱、SQL 每次新建连接、策略持久化双通道、MCP 虚假承诺
- **五层调用链全部通电**：limiter/monitor/alert/sql_guard/scorer 在沙箱拦截链中实际调用
- **Scorer 预检**：`sandbox_http_request` 可选评分预拦截
- **SQL 连接复用**：Sandbox 结构体整合 `sql_conn`
- **仪表盘接入**：`stats()` 含限流/监控/告警状态
- **MoonBit CLI 诚实化**：`serve` 如实说明 MCP 在 Rust 侧；新增 `sync` 命令
- **CI 全线通过**：tokenizers-moonbit 式 setup + multi-target matrix + release gates
- MoonBit：~3580 行（+220）；Rust：~1073 行（-115）

## v0.7.0 (2026-07-05) — 全面加固

- 统一门面 `AegisRun::new("standard")`：一行 API，内置 HashMap 缓存
- 审计日志 JSONL 持久化（AuditLogger，50条批量刷盘）
- 策略持久化 + 热加载（save_policy/load_policy + PolicyWatcher）
- Web 仪表盘实时刷新（每2秒 fetchStats）
- 工具签名验证（ToolRegistry + SHA256 + 发布者注册表）
- 安全策略补强：环境变量 8→30+，路径 8→30+，IP 15→20+
- MoonBit / Rust 编译 0 警告
- 恶意 .wasm 工具 27/27 拦截验证

## v0.6.0 (2026-07-05) — 全面加固（接上）

- 默认策略数据集中管理（`defaults.mbt`）
- Rust CI 补全（cargo build + clippy + test）
- 真 SHA256 签名验证（sha2 crate）
- Rust/MoonBit/YAML 三方策略对齐（30+ 规则）
- `check_path()` bug 修复（contains→starts_with）
- MCP 端点策略丢失修复（使用实际策略而非 new Policy::standard()）
- wasmtime 沙箱资源限制（30s 超时 + 256MB 内存）
- AuditLogger flush 改为 append-only
- PolicyWatcher 从死代码激活
- CORS preflight 支持
- Server 改为多线程
- 自动化测试：Rust 14 用例 + MoonBit 6 测试函数

## v0.4.1 (2026-06-23) — WASI 物理隔离

- wasmtime 39 集成
- sandbox.rs：WASI p1 沙箱，零目录预打开 + 过滤环境变量
- 恶意 .wasm 工具 27/27 全部拦截
- 物理隔离：WASI 层根本没给工具访问能力

## v0.4.0 (2026-06-22) — 统一入口 + MCP 集成

- Rust 库/CLI 分离：`lib.rs`（库）+ `main.rs`（CLI）
- MCP Server 端点：`/mcp`，Claude Desktop 兼容
- Web 管理面板 + 通用脚本扫描器 + OS 级沙箱
- 统一 Demo 结构：`src/demo/` + `src/generator/`

## v0.3.0 (2026-06-22) — 沙箱运行时 + DNS 防护

- **Rust 沙箱运行时**：wasmtime 执行器，WASI 拦截框架，策略引擎移植
- **DNS 劫持防御**：IP 黑名单引擎（15 条规则），`check_ip()`，`detect_dns_hijack()`
- **告警通知**：3 种恢复模式，4 级告警
- **终端仪表盘**：ASCII 进度条
- **恶意脚本生成器**：12 种攻击类型

### 技术决策

| 决策 | 选择 | 原因 |
|------|:----:|------|
| 沙箱运行时语言 | **Rust** | wasmtime 生产级 + 内存安全 |
| Wasm 运行时 | **wasmtime 39** | 原生 WASI 拦截（Fastly/Shopify 同款）|
| 策略引擎语言 | **MoonBit**（逻辑）+ **Rust**（执行）| MoonBit 做判断，Rust 做拦截 |

### 安全修复

- `check_env` 新增 PASSWORD/CREDENTIAL 关键词
- `check_domain` 新增 IP 前缀匹配（192.168./10./172.）
- 沙箱层接入 IP 黑名单

## v0.1.0 (2026-06-22) — 首个版本

- **核心引擎**：Decision 枚举、PolicyState、check_domain/path/env/tool_id
- **沙箱拦截层**：SandboxGrant、Sandbox、sandbox_http_request/file_open/getenv
- **CLI**：preset/deny/allow/show/demo/serve 命令
- **演示**：7 场景，14/14 扫描 + 22/22 沙箱测试
- **预设**：strict/standard/permissive YAML 模板

### 技术指标

| 项目 | 数值 |
|------|------|
| 核心代码 | ~500 行 MoonBit |
| 编译器 | MoonBit 0.1.20260608 |
| 编译目标 | wasm-gc |
| 包架构 | 3 包 |
| 测试覆盖 | 14 扫描 + 22 沙箱，0 失败 |

### 已知限制

- 沙箱层为纯 MoonBit 函数调用拦截，尚未接入 wasm5 宿主函数
- 策略状态不持久化，程序退出即销毁
- 命令行仅支持单次调用，无交互式 Shell
- 后缀/前缀匹配为 O(n) 遍历，规则超 100 条建议切换到 Trie 树
