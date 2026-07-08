# AegisRun Changelog / 更新日志

> All notable changes to this project. / 项目所有重要变更记录。

<style>
.en { display: none; }
.zh { display: block; }
#en:target { display: block; }
#en:target ~ .zh { display: none; }
.lang-bar { text-align: center; margin: 16px 0; }
.lang-btn { display: inline-block; padding: 6px 20px; background: #f0f0f0; border-radius: 20px; text-decoration: none; color: #333; font-size: 14px; margin: 0 4px; }
.lang-btn:hover { background: #e0e0e0; }
</style>

<div class="lang-bar">
<a href="#en" class="lang-btn">🇬🇧 English</a>
<a href="#zh-cn" class="lang-btn">🇨🇳 中文</a>
</div>

---

<div id="en" class="en">

## v0.8.0 (2026-07-08) — Architecture Duality Elimination

- **7 architecture dualities eliminated**: dual policy source, duplicate scanner, dual dashboard, scorer not called via sandbox, SQL reconnect every time, dual policy persistence, fake MCP in MoonBit CLI
- **5-layer call chain fully powered**: limiter/monitor/alert/sql_guard/scorer actually invoked in sandbox interception
- **Scorer pre-check**: `sandbox_http_request` optional scoring pre-interception via `min_score`
- **SQL connection reuse**: Sandbox struct integrates `sql_conn`, no per-query connections
- **Dashboard wired in**: `stats()` includes limiter/monitor/alert status
- **MoonBit CLI honesty**: `serve` explains MCP is on Rust side; new `sync` command
- **CI all green**: tokenizers-moonbit setup + multi-target matrix + release gates
- MoonBit: ~3,580 lines (+220); Rust: ~1,073 lines (-115)

## v0.7.0 (2026-07-05) — Full Hardening

- Unified facade `AegisRun::new("standard")`: one-line API, built-in HashMap cache
- Audit log JSONL persistence (AuditLogger, batch flush every 50 entries)
- Policy persistence + hot reload (save_policy/load_policy + PolicyWatcher)
- Web dashboard real-time refresh (fetchStats every 2s)
- Tool signature verification (ToolRegistry + SHA256 + publisher registry)
- Security policy reinforcement: env vars 8→30+, paths 8→30+, IP 15→20+
- MoonBit/Rust: 0 warnings
- Malicious .wasm tool 27/27 interception verified

## v0.6.0 (2026-07-05) — Full Hardening (continued)

> Note: v0.6.0 and v0.7.0 share the same date - v0.7.0 was a rebase/rename.

- Default policy data centralized (`defaults.mbt`)
- Rust CI completed (cargo build + clippy + test)
- Real SHA256 signature verification (sha2 crate)
- Rust/MoonBit/YAML three-way policy alignment (30+ rules)
- `check_path()` bug fix (contains→starts_with)
- MCP endpoint policy loss fix (uses actual policy, not `new Policy::standard()`)
- wasmtime sandbox resource limits (30s timeout + 256MB memory)
- AuditLogger flush: append-only (no more O(n) rewrite)
- PolicyWatcher activated from dead code
- CORS preflight support
- Server multithreaded (Arc\<Policy\> + thread::spawn)
- Automated tests: Rust 14 cases + MoonBit 6 test functions

## v0.4.1 (2026-06-23) — wasmtime WASI Physical Isolation

- wasmtime 39 integration: Cargo.toml with wasmtime + wasmtime-wasi
- sandbox.rs: WASI p1 sandbox, zero preopens + filtered env
- Malicious .wasm tool verified: all 27/27 operations intercepted
- True physical isolation: WASI layer never grants capability

## v0.4.0 (2026-06-22) — Unified Entry + MCP Integration

- Rust lib/CLI separation: `lib.rs` (library) + `main.rs` (CLI)
- MCP Server endpoint: `/mcp`, `tools/list` + `tools/call`, Claude Desktop compatible
- Web admin panel + universal script scanner + OS-level sandbox
- Unified demo structure: `src/demo/` + `src/generator/`

## v0.3.0 (2026-06-22) — Sandbox Runtime + DNS Protection

- **Rust sandbox runtime**: wasmtime-based executor, WASI interception framework, policy engine port
- **DNS hijacking defense**: IP blacklist engine (15 rules), `check_ip()`, `detect_dns_hijack()`
- **Alert notifications**: 3 recovery modes, 4 alert levels
- **Terminal dashboard**: ASCII progress bars
- **Malicious script generator**: 12 attack types

### Technical Decisions

| Decision | Choice | Reason |
|----------|:------:|--------|
| Sandbox runtime language | **Rust** | wasmtime production-grade, memory safety |
| Wasm runtime | **wasmtime 39** | Native WASI interception (Fastly/Shopify) |
| Policy engine language | **MoonBit** (logic) + **Rust** (execution) | MoonBit for judgment, Rust for OS-level |

### Security Fixes

- `check_env`: added PASSWORD/CREDENTIAL keywords
- `check_domain`: added IP prefix matching (192.168./10./172.)
- Sandbox layer wired to IP blacklist

## v0.1.0 (2026-06-22) — Initial Release

- **Core engine**: Decision enum, PolicyState, check_domain/path/env/tool_id
- **Sandbox interception**: SandboxGrant, Sandbox, sandbox_http_request/file_open/getenv
- **CLI**: preset/deny/allow/show/demo/serve commands
- **Demos**: 7 scenarios, 14/14 scan + 22/22 sandbox tests
- **Presets**: strict/standard/permissive YAML templates

### Technical Metrics

| Metric | Value |
|--------|-------|
| Core code | ~500 lines MoonBit |
| Compiler | MoonBit 0.1.20260608 |
| Target | wasm-gc |
| Package architecture | 3 packages |
| Test coverage | 14 scan + 22 sandbox, 0 failures |

### Known Limitations

- Sandbox is pure MoonBit function interception, not wired to wasm5 host functions
- Policy state not persisted, lost on exit
- CLI single-call only, no interactive shell
- O(n) suffix/prefix matching — recommend Trie when rules exceed 100

</div>

<div class="zh">

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

</div>
