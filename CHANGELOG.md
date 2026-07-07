# AegisRun 更新日志

---

## v0.6.0 (2026-07-05) — 全面加固

- 默认策略数据集中管理（`defaults.mbt`，修改规则只需改一个文件）
- Rust CI 补全（cargo build + clippy + test）
- 真 SHA256 签名验证（sha2 crate 替代伪实现）
- Rust/MoonBit/YAML 三方策略对齐（30+ 规则统一，serde_yaml 解析 preset）
- `check_path()` bug 修复（contains→starts_with，消除误拦截）
- MCP 端点策略丢失修复（使用实际策略而非每次 new Policy::standard()）
- wasmtime 沙箱资源限制（30s 超时 + 256MB 内存上限）
- AuditLogger flush 改为 append-only（不再 O(n) 重写全文件）
- PolicyWatcher 从死代码激活（server 主循环中检测 policy.json 变更）
- CORS preflight 支持（OPTIONS 返回 204）
- Server 改为多线程（Arc<Policy> + thread::spawn per connection）
- Dashboard 修复：stats DOM 元素、exportCLI 路径、applyPreset merge、版本号
- YAML preset 同步：env 14→36，path 10→22，移除 api.openai.com/anthropic.com 白名单
- MoonBit IP 前缀从硬编码改为迭代列表（core.mbt ip_prefixes 字段）
- `export_policy()` 从占位符改为追踪数组实现（绕过 HashMap 不可遍历）
- `has_attack("all")` 返回 true 修复
- DNS guard 重复 CIDR 条目清除（194.26. / 37.59.）
- Alert 限流（每10次输出1次，Emergency 不受限）
- Monitor::update_metrics 添加 elapsed_secs 参数
- 自动化测试：Rust 14 用例（6 测试函数）+ MoonBit 6 测试函数
- 版本号全局统一至 0.6.0（moon.mod / Cargo.toml / cli.mbt / dashboard.html / lib.rs / main.rs）
- 文档更新：CONTRIBUTING、使用指南、新建 SECURITY-POLICY.md，删除过时 WASMTIME_INTEGRATION.md

## v0.5.0 (2026-07-05) — 统一门面 + 策略补强 + CI 完善

- 统一门面 `AegisRun::new("standard")`：一行 API 替代旧的四行调用，内置 HashMap 缓存
- 审计日志 JSONL 持久化（AuditLogger，50条批量刷盘）
- 策略持久化 + 热加载（save_policy/load_policy + PolicyWatcher 文件监控）
- Web 仪表盘实时刷新（每2秒 fetchStats）
- 工具签名验证（ToolRegistry + SHA256 + 发布者注册表）
- 安全策略补强：环境变量 8→30+（新增云平台/CI/CD/SaaS），路径 8→30+（新增 macOS/Linux/Windows 完整凭证目录），IP 15→20+（新增 APT C2 段）
- MoonBit: moon check + moon fmt --check 0 警告
- Rust: cargo clippy 0 警告
- 恶意 .wasm 工具 evil-plugin 27/27 拦截验证
- 文档全面更新（CHANGELOG、CONTRIBUTING、使用指南）

---

## v0.4.1 (2026-06-23) — wasmtime WASI 物理隔离

- wasmtime 39 集成：Cargo.toml 启用 wasmtime + wasmtime-wasi
- sandbox.rs：WASI p1 沙箱，零目录预打开 + 过滤环境变量
- 恶意 .wasm 工具验证：/etc/passwd(os error 44) / API_KEY(not set) 全部被拦截
- 物理隔离：不是策略返回 Deny，是 WASI 层根本没给工具访问能力

---

## v0.4.0 (2026-06-22) — 统一入口 + MCP 集成

### 新增
- Rust 库/CLI 分离：`lib.rs`（库）+ `main.rs`（CLI），`cargo add` 可嵌入
- MCP Server 端点：`/mcp`，`tools/list` + `tools/call`，Claude Desktop 兼容
- Web 管理面板（`serve` 内嵌 + 双击 `dashboard.html`）
- 通用脚本扫描器：Python/JS 自动提取字符串→对照策略
- OS 级沙箱：`sandbox_read_file()`/`sandbox_getenv()` 读前检查
- 统一 Demo 结构：`src/demo/`（拦截）+ `src/generator/`（生成器）
- 使用指南：`docs/使用指南.md`

---

## v0.3.0 (2026-06-22) — 沙箱运行时 + DNS 防护

### 新增

**Rust 沙箱运行时 (`runtime/`)**
- `runtime/src/main.rs` — wasmtime-based 沙箱执行器（210 行），Demo 模式 + WASI 拦截框架
- `runtime/Cargo.toml` — wasmtime 39 + WASI preview2 依赖
- `runtime/README.md` — Rust vs C 对比说明 + 用法文档
- 策略引擎移植到 Rust：`check_domain` / `check_path` / `check_env` 三大检查器
- 策略文件热加载（YAML/JSON）
- WASI 拦截点定义：`path_open` / `environ_get` / `sock_send` / `sock_connect`

**DNS 劫持防御 (`src/lib/dns_guard.mbt`)**
- IP 黑名单引擎：15 条预置规则（RFC1918 / C2 / Tor / 钓鱼 / 链路本地）
- `check_ip()` — IP 精确匹配 + CIDR 前缀匹配
- `detect_dns_hijack()` — 域名→IP→黑名单 三级检查
- `check_hosts_integrity()` — hosts 文件篡改检测（扫描知名域名劫持）

**告警通知 (`src/lib/alert.mbt`)**
- 三种恢复模式：Auto / Manual / SemiAuto
- 四级告警：Info / Warning / Critical / Emergency

**终端仪表盘 (`src/lib/dashboard.mbt`)**
- ASCII 进度条渲染（CPU/MEM/Slot/Queue）
- Web 面板开关 `toggle_web_panel()`

**恶意脚本生成器 (`src/generator/`)**
- 12 种攻击类型可选，环境变量控制
- 拦截演示模式：真实调用 `@lib.check_*` 函数

### 技术决策

| 决策 | 选择 | 原因 |
|------|:--:|------|
| 沙箱运行时语言 | **Rust** | wasmtime 生产级 + 内存安全 + WASI Preview 2 |
| Wasm 运行时 | **wasmtime 39** | Fastly/Shopify 同款，WASI 拦截原生支持 |
| 策略引擎语言 | **MoonBit**（逻辑）+ **Rust**（执行） | MoonBit 做判断，Rust 做拦截 |

### 安全关键修复

- `check_env` 新增 PASSWORD / CREDENTIAL 关键词
- `check_domain` 新增 IP 前缀匹配（192.168. / 10. / 172.）
- 沙箱层接入 IP 黑名单（`sandbox.mbt` 新增 `ip_bl` 字段）

---

## v0.1.0 (2026-06-22) — 首个版本

### 新增

**核心引擎 (`src/lib/core.mbt`)**
- `enum Decision { Allow; Deny }` — 安全判定结果类型
- `struct PolicyState` — 策略状态，包含域名/路径/工具黑名单、域名白名单、敏感环境变量、后缀/前缀匹配数组
- `check_domain()` — 域名三级检查：HashMap 精确匹配 (O(1)) + 后缀通配 + IP 前缀
- `check_path()` — 路径两级检查：HashMap 精确匹配 + 前缀目录拦截
- `check_env()` — 环境变量两级检查：显式模式匹配 + KEY/SECRET/TOKEN/PASSWORD/CREDENTIAL 关键词检测
- `check_tool_id()` — 工具黑名单 HashMap 查表
- `new_policy_engine()` — 创建策略引擎并加载 standard 预设
- `load_standard_preset()` — 填充初始黑/白名单规则（7 域名 + 5 路径 + 3 后缀 + 2 白名单 + 4 环境变量）
- 跨包访问器: `get_blacklist_domains()`, `get_blacklist_paths()`, `get_blacklist_tools()`, `get_sensitive_envs()`, `get_domain_suffixes()`, `get_path_prefixes()`
- 跨包 setter: `set_preset()`, `bl_add_domain()`, `wl_add_domain()`, `bl_add_tool()`, `bl_add_path()`
- `make_tool()` / `tool_id()` / `tool_desc()` — ToolInfo 工厂和访问器

**沙箱拦截层 (`src/lib/sandbox.mbt`)**
- `struct SandboxGrant` — 工具授权模型（域名/路径/环境变量白名单 + 资源上限）
- `struct Sandbox` — 沙箱实例（绑定 PolicyState + SandboxGrant + 统计计数器）
- `sandbox_http_request()` — 网络拦截器：两关检查（黑名单 → 授权）
- `sandbox_file_open()` — 文件拦截器：两关检查（黑名单 → 授权）
- `sandbox_getenv()` — 环境变量拦截器：两关检查（黑名单 → 授权）
- `sandbox_check_timeout()` — 超时裁剪：超出上限 → 自动降至上限值
- `sandbox_check_memory()` — 内存裁剪：超出上限 → 自动降至上限值
- `sandbox_stats()` — 沙箱统计：总检查数/拦截数
- `standard_sandbox()` — 快捷创建（standard 预设 + 默认授权）
- `extract_host()` — URL 域名提取
- `join_strings()` — 数组拼接

**CLI 命令 (`src/main/cli.mbt`)**
- `preset` — 切换安全预设（strict/standard/permissive）
- `deny <domain|tool>` — 添加黑名单，即时生效
- `allow domain` — 添加白名单
- `show` — 查看当前策略状态
- `demo [1-7|all]` — 运行安全演示
- `serve` — MCP Server 启动（预留）
- 命令行参数解析（`@env.args()`）

**演示程序**
- `src/demo/scenarios.mbt` — 7 个安全场景演示（安装审查/外泄拦截/路径控制/密钥保护/工具封杀/审计/策略总览）
- `src/scanner/scanner.mbt` — 恶意工具扫描器：对 5 个伪装工具执行真实黑名单检查（14/14 拦截）
- `src/sandbox_demo/sandbox_demo.mbt` — 沙箱层演示：22 次拦截测试（6 网络 + 6 文件 + 6 环境变量 + 4 资源），22/22 正确

**恶意工具演示 (`demo/malicious_tools/`)**
- `weather_helper.mbt` — 伪装天气查询，隐藏数据外泄
- `log_cleaner.mbt` — 伪装日志清理，隐藏敏感文件读取
- `json_formatter.mbt` — 伪装 JSON 格式化，隐藏 API Key 窃取
- `backup_sync.mbt` — 伪装备份同步，隐藏内网扫描 + 外泄
- `image_optimizer.mbt` — 伪装图片优化，隐藏凭证窃取 + 资源滥用

**预设模板 (`presets/`)**
- `strict.yaml` — 严格模式：全拒，逐个审批
- `standard.yaml` — 标准模式（推荐）：常用 API 放行，敏感路径拦截
- `permissive.yaml` — 宽松模式：仅拦截关键路径

**工具脚本**
- `run_demo.bat` — 交互式菜单（环境变量 AEGISRUN_DEMO 选择 demo）
- `aegisrun.bat` — CLI 包装脚本
- `test_demo.bat` — 8 项自动化测试套件

**文档**
- `README.md` — 项目说明（简体中文）
- `ARCHITECTURE.md` — 架构文档（完整调用链）
- `policy.example.yaml` — 策略配置示例

### 技术指标

| 项目 | 数值 |
|------|------|
| 核心代码行数 | ~500 行 MoonBit (lib) |
| 编译器版本 | MoonBit 0.1.20260608 |
| 编译目标 | wasm-gc |
| 编译警告 | 8 (deprecated API, 0 errors) |
| 包架构 | 3 包 (lib / demo+scanner+sandbox_demo / main) |
| 测试覆盖 | 14 项扫描 + 22 项沙箱测试，0 失败 |

### 已知限制

- 沙箱层为纯 MoonBit 函数调用拦截，尚未接入 wasm5 宿主函数（Wasm 沙箱）
- 策略状态不持久化，程序退出即销毁
- 命令行参数仅支持单次调用，无交互式 Shell
- 后缀/前缀匹配为 O(n) 遍历，规则数超过 100 条时建议切换到 Trie 树


