# AegisRun v0.9.3

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

> 🇬🇧 [English README →](docs-en/README.md)

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260703-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2046-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260703` | Rust `>= 1.80`（仅 runtime 目录需要）| wasmtime 46
> **安装：** `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **分支：** `clean-v2`

---

## 项目简介

AegisRun 解决的是一个很具体的问题：当 AI Agent 调用外部工具时，怎么防止这些工具越权操作？

AegisRun 的做法是在 Agent 和系统之间插入一个安全检查层，分成两个独立的部分：

- **MoonBit 策略引擎**（`src/lib/`，约 3600 行）：负责所有"该不该放行"的判断。维护域名/IP 黑名单（45+ 条规则），拦截敏感路径（`/etc/passwd`、`~/.ssh/` 等），过滤环境变量模式（KEY/SECRET/TOKEN 等 60+ 条），还包含风险评分、限流熔断、DNS 防护、SQL 守卫等模块。

- **Rust 运行时**（`runtime/`，约 1800 行）：负责把策略落地到实际执行中。核心是 wasmtime WASI 沙箱——工具代码编译成 Wasm 后在沙箱里运行，所有系统调用都被拦截后调用策略函数决定放行/拒绝。提供 Web 管理面板（9090 端口）、审计日志、Python audit hook 运行时监控、工具注册表（ToolRegistry）。

## 快速开始

```cmd
moon run src/main                          # MoonBit 策略引擎演示

cd runtime
cargo run -- demo                          # Rust 策略引擎演示
cargo run -- serve                         # Web 面板（http://localhost:9090）
```

## 命令速查

### CLI 命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `demo` | 策略引擎演示 | `cargo run -- demo` |
| `scan <file> [--json]` | 扫描文件 | `cargo run -- scan malware.py` |
| `scan --code "<code>"` | 内联代码扫描 | `cargo run -- scan --code "import os; os.environ['KEY']"` |
| `audit` | 审计日志（最近 20 条） | `cargo run -- audit` |
| `sandbox <wasm>` | WASI 沙箱执行 | `cargo run -- sandbox tool.wasm` |
| `list-tools` | 列出注册工具 | `cargo run -- list-tools` |
| `search-tools <kw>` | 搜索工具 | `cargo run -- search-tools weather` |
| `register <id> <wasm> <pub>` | 注册工具 | `cargo run -- register my.wasm my-tool @pub` |
| `unregister <id>` | 取消注册 | `cargo run -- unregister my-tool` |
| `verify <wasm> <id> <pub>` | 验证签名 | `cargo run -- verify t.wasm id @pub` |
| `serve` | Web 面板 | `cargo run -- serve` |
| `policy show` | 查看策略 | `cargo run -- policy show` |
| `policy set <preset>` | 切换预设 | `cargo run -- policy set strict` |
| `policy block domain <val>` | 封禁域名 | `cargo run -- policy block domain evil.com` |

### Web 管理面板

```cmd
cd runtime && cargo run -- serve
```

浏览器打开 `http://localhost:9090`。

| 区域 | 功能 |
|------|------|
| **仪表盘** | 五层防御开关、拦截统计、预设模板 |
| **域名策略** | 黑名单/白名单管理 |
| **路径策略** | 敏感路径拦截 |
| **环境变量** | 敏感变量模式 |
| **工具管理** | ToolRegistry（注册/搜索/标签/卸载）+ 示例工具 + 目录扫描注册 |
| **审计日志** | 实时操作记录，按工具/操作/决策筛选 |
| **Sandbox** | 静态扫描 + 运行时沙箱双模式，支持粘贴代码或指定文件路径 |
| **MCP Agent** | 14 个 MCP 工具列表、批量调用、演示/真实模式切换 |

### REST API

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/policy` | GET | 当前策略 |
| `/api/scan` | POST | 静态扫描 `{code:` &#124;`path:}` |
| `/api/sandbox-run` | POST | 运行时沙箱 `{code:` &#124;`path:}` |
| `/api/audit` | GET | 审计日志 |
| `/api/audit?tool_id=&action=&decision=` | GET | 筛选审计 |
| `/api/tools` | GET | 所有注册工具 |
| `/api/tools/search?keyword=&tag=` | GET | 搜索工具 |
| `/api/tools/get/<id>` | GET | 单工具查询 |
| `/api/tools/tags` | GET | 所有标签 |
| `/api/tools/register` | POST | 注册工具 |
| `/api/tools/unregister` | POST | 卸载工具 |
| `/api/tools/scan-dir` | POST | 扫描目录 .wasm |
| `/api/tools/batch-register` | POST | 批量注册 |
| `/api/block/<domain&#124;path&#124;env>/<val>` | POST | 封禁 |
| `/api/unblock/<domain&#124;path&#124;env>/<val>` | POST | 解除封禁 |
| `/api/preset/<name>` | POST | 切换预设 |
| `/api/defense` | GET | 防御层状态 |
| `/api/toggle/<layer>` | POST | 开关防御层 |

### MCP 工具（14 个）

通过 `POST /mcp` 调用，标准 JSON-RPC 格式：

| 工具 | 说明 |
|------|------|
| `aegisrun.policy.summary` | 策略摘要 |
| `aegisrun.policy.check_domain` | 域名检查 |
| `aegisrun.policy.check_path` | 路径检查 |
| `aegisrun.policy.check_env` | 环境变量检查 |
| `aegisrun.guard_tool_call` | 综合预检 |
| `aegisrun.scan_code` | 代码扫描 |
| `aegisrun.scan_file` | 文件扫描 |
| `aegisrun.sandbox_python` | 运行时沙箱 |
| `aegisrun.sandbox_wasm` | WASI 沙箱 |
| `aegisrun.tools.list` | 列出工具 |
| `aegisrun.tools.search` | 搜索工具 |
| `aegisrun.tools.tags` | 标签列表 |
| `aegisrun.tools.get` | 按 ID 查工具 |

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

### 库调用

```moonbit
// MoonBit：moon add tuya-me/aegisrun
let aegis = @lib.AegisRun::new("standard")
aegis.check_domain("evil.com")          // → Deny
```

```rust
// Rust：cargo add aegisrun-runtime
use aegisrun_runtime::{Policy, scan_script, scan_file};
let policy = Policy::standard();
policy.check_domain("evil.com");         // → false
let findings = scan_script("import os; os.environ['KEY']");
let (src, findings) = scan_file("test.py").unwrap();
```

## 五层防御

| 层 | 名称 | 实现 |
|:--:|------|------|
| 1 | 运行时沙箱 | Python audit hook 监控 |
| 2 | 域名/IP 黑名单 | 精确匹配 + 后缀通配 + IP 前缀（45+规则）|
| 3 | 路径 + 环境变量保护 | 精确 + 前缀 + KEY/SECRET/TOKEN 检测（60+模式）|
| 4 | 扫描器 | 静态代码分析（env/path/host/command 6 种检测）|
| 5 | Wasm 沙箱物理隔离 | wasmtime WASI 零目录预打开 |

## 文档导视

| 如果你... | 请阅读 |
|-----------|--------|
| **新手** — 想立刻跑起来 | [docs-ch/GUIDE.md](docs-ch/GUIDE.md) |
| **贡献者** — 提代码 | [docs-ch/CONTRIBUTING.md](docs-ch/CONTRIBUTING.md) |
| **安全工程师** — 审计规则 | [docs-ch/SECURITY-POLICY.md](docs-ch/SECURITY-POLICY.md) |
| **架构探索** — 理解设计 | [docs-ch/ARCHITECTURE.md](docs-ch/ARCHITECTURE.md) |
| **版本追踪** — 看更新 | [docs-ch/CHANGELOG.md](docs-ch/CHANGELOG.md) |
| **English speakers** | [docs-en/README.md](docs-en/README.md) |

## 开源许可

Apache License 2.0
