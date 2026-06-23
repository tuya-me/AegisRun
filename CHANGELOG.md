# AegisRun 更新日志

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
- `ROADMAP.md` — v1.1 → v2.0 路线图
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

---

## Roadmap

| 版本 | 内容 | 预计 |
|------|------|:--:|
| **v0.1.0** | 黑名单引擎 + 沙箱层 + CLI + 演示 + 文档 | ✅ 已发布 |
| v0.2.0 | 风险评分引擎 (声明自动打分 0-100) | TBD |
| v0.3.0 | wasm5 宿主函数集成 (真实 Wasm 沙箱) | TBD |
| v0.4.0 | 策略持久化 (policy.yaml 读写) | TBD |
| v0.5.0 | MCP Server 完整实现 (tools/list + tools/call) | TBD |
| v1.0.0 | SQL 资源控制 + 并发限流 + 压力监控 | TBD |
| v2.0.0 | Web 管理面板 + mooncakes.io 发布 | TBD |
