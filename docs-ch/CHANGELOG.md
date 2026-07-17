# AegisRun 更新日志

> 🇬🇧 [English version →](../docs-en/CHANGELOG.md)


---

## v0.9.3 (2026-07-17) — 工具注册表 + 测试重构 + 面板升级 + 体验对齐

### 新增
- **ToolRegistry 完整生命周期**：工具发现、注册、卸载、标签检索、关键词搜索、SHA256 签名验证、JSON 持久化（`verify.rs`，~250 行）
- **3 个 MCP 工具**：`tools.list`、`tools.search`、`tools.tags`，MCP 工具总数 9→12
- **5 个 REST API 端点**：工具注册表 CRUD + 扫描目录
- **Dashboard 工具注册表 UI**：工具列表、关键词搜索、标签云浏览、注册表单、一键卸载
- **Dashboard MCP 参数模板**：全部工具配备 JSON 参数模板
- **沙箱文件路径输入**：支持指定文件路径扫描，代替手动粘贴代码
- **沙箱模式切换**：静态扫描 / 运行时沙箱双模式，结果对比展示
- **`aegisrun.tools.get` MCP 工具**：按 `tool_id` 查询单个工具详情（第 13 个 MCP 工具）
- **`GET /api/tools/get/<id>` REST 端点**：单工具查询
- **`BufAuditLogger` 异步审计**：channel + 后台线程，`log()` 非阻塞，500ms 攒批写盘
- **CLI `scan --code`**：支持内联代码扫描 `aegisrun scan --code "..."`，与网页端对齐
- **CLI `scan --json`**：支持 JSON 格式输出，方便 CI/CD 集成
- **CLI `audit` 改为读取真实日志**：显示最近 20 条审计记录（之前是写 3 条硬编码演示数据）
- **CLI 帮助文本重写**：分节显示 COMMANDS/EXAMPLES/LIBRARY

### 改进
- **网页端体验对齐**：Dashboard/Domain/Path/Env/Audit 全部页面增加 info-banner 说明、空状态提示、加载状态
- **Env 页面按钮修复**：统一为「封禁」（之前为「添加」）
- **Audit 清空确认**：清空前弹窗确认，防误操作
- **工具注册表搜索修复**：标签云点击改为 `?tag=` 查询，后端同时支持 `keyword/q/tag` 三种参数
- **工具注册表取消注册修复**：前端发 POST body 而非 URL 参数，后端正确匹配路由
- **`scan_file()` 库函数**：`lib.rs` 新增 `pub fn scan_file(path)`，消除 CLI/MCP/REST 三处重复读文件+扫描代码
- **MoonBit CLI `web` 命令路径修复**：`dashboard.html` → `web/dashboard.html`
- **README `cargo run` 命令标准化**：移除失效的 `sandbox-monitor`，全部加 `cd runtime` 前缀

### 重构
- **`AuditLogger` 分离为同步/异步两个实现**：`AuditLogger`（同步缓冲）保留兼容，新增 `BufAuditLogger`（channel 异步）
- **Rust 测试文件分离**：7 个测试文件从源码中抽出到 `runtime/tests/`
- **MoonBit 测试文件分离**：`monitor_tests.mbt`（18）、`limiter_tests.mbt`（14）

### 测试
- Rust 测试：81 项（新增 wasi_sandbox:6, mcp:6, hot_reload:5）
- MoonBit 测试：32 测试块（monitor:18, limiter:14）
- CI: `moon build` + `moon test` + `cargo test` 全覆盖 <sup>← 已有</sup>

### 文档
- README/GUIDE/CHANGELOG 全量更新：CLI 命令表、REST API 端点、MCP 工具清单、库函数说明
- Web 面板版本号 v0.9.2 → v0.9.3

---

## v0.9.2 (2026-07-14) — MCP 重写 + 运行时沙箱 + 面板重设计

### 新增
- **MCP 工具从 5 扩展到 9**：新增 `policy.summary`、`guard_tool_call`、`scan_code`、`sandbox_python`、`sandbox_wasm`
- **MCP JSON-RPC 规范化**：正确 id 回显、错误码、inputSchema
- **`/api/sandbox-run` 端点**：Web 面板支持 Python 运行时沙箱检测（静态 + runtime 合并）
- **Dashboard MCP 交互调用面板**：选工具、填参数、直接调用
- **Dashboard 视觉分离**：Web 管理区 / Sandbox 区 / MCP Agent 区明确分区
- **沙箱双模式切换**：Static Scan / Runtime Sandbox
- **`sandbox_connect_domain`**：Rust 运行时网络守卫
- **路径通配匹配**：`wildcard_match` 支持 `*`

### 修复
- `production-check` 示例 clippy 警告
- Sandbox monitor：`os.getenv`/`os.environ`/`socket.connect`/`subprocess.Popen` 全 monkey-patch
- 路径反斜杠归一化

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
