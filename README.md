# AegisRun v0.8.0

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

> 🇬🇧 [English README →](docs-en/README.md)

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80`（仅 runtime 目录需要）| wasmtime 39
> **安装：** `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **分支：** `clean-v2`

---

## 项目简介

AI Agent 在运行中被第三方工具窃取 API Key、上传敏感文件、扫描内网——这不是假设，是已经发生的事。AegisRun 提供一个**轻量安全执行层**，在工具和系统之间做五层纵深防御。

- **MoonBit 层**（~3500 行）：域名/IP 黑名单、路径拦截、环境变量过滤、风险评分、限流熔断、SQL 防护
- **Rust 层**（~1000 行）：wasmtime WASI 物理隔离沙箱、Web 面板、审计日志、工具签名验证

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
quickstart.cmd                    # 一键菜单

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
| `cargo run -- audit` | 审计日志 JSONL |
| `cargo run -- verify tool.wasm id pub` | 工具签名验证 |

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

5 个工具：sandbox / scan / check_domain / check_path / check_env

## 开源许可

Apache License 2.0
