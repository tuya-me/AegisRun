# AegisRun v0.8.0

**AI Agent Secure Tool Execution Framework — MoonBit Policy Engine + Rust Sandbox Runtime**
**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

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

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80` (runtime only) | wasmtime 39
> **Install:** `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **Branch:** `clean-v2`

---

<div id="en" class="en">

## Overview

AI agents can be tricked into leaking API keys, uploading sensitive files, or scanning internal networks. AegisRun provides a **lightweight security execution layer** with five-level defense between tools and your system.

- **MoonBit layer** (~3500 lines): Domain/IP blacklist, path interception, env var filtering, risk scoring, rate limiting, SQL guard
- **Rust layer** (~1000 lines): wasmtime WASI physical sandbox, web dashboard, audit logging, tool signature verification

## Architecture

```
MoonBit Library (src/lib/)               Rust Runtime (runtime/)
┌────────────────────┐           ┌──────────────────────────────┐
│ check_domain()     │   Allow   │ wasmtime WASI interceptor     │
│ check_path()       │←─────────│ path_open → check_path       │
│ check_env()        │   Deny    │ environ_get → check_env      │
│                    │           │ sock_send → check_domain    │
│ Pure logic,        │           │ Syscall interception,        │
│ pure MoonBit       │           │ Rust implementation          │
└────────────────────┘           └──────────────────────────────┘
    Policy Decision Layer             Execution Interception Layer
```

### Five-Layer Defense

| Layer | Name | Implementation |
|:-----:|------|----------------|
| 1 | Installation review | Risk scoring engine (Safe/Warning/Dangerous/Critical) |
| 2 | Domain/IP blacklist | HashMap O(1) + suffix wildcard + IP prefix (45+ rules) |
| 3 | Path + env var protection | Exact + prefix + KEY/SECRET/TOKEN detection (60+ patterns) |
| 4 | Tool blacklist + audit | Instant block + JSONL persistence + hot reload |
| 5 | Wasm physical sandbox | Rust wasmtime WASI zero preopens + filtered env |

## Quick Start

```cmd
cd D:\moonbit\aegisrun
quickstart.cmd                    # Interactive menu

moon run src/main                 # MoonBit CLI: policy engine demo

cd runtime
cargo run -- demo                 # Rust CLI: policy engine demo
cargo run -- serve                # Web dashboard (port 9090)
```

## Document Navigation

All documentation is bilingual (English / Chinese). Navigate by your role:

| If you are... | Start here |
|---------------|------------|
| **New user** — run it ASAP | [docs/GUIDE.md](docs/GUIDE.md) (Beginner Level) |
| **Developer** — integrating the library | [docs/GUIDE.md](docs/GUIDE.md) (Detailed Level) |
| **Contributor** — submitting code | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| **Security engineer** — auditing rules | [docs/SECURITY-POLICY.md](docs/SECURITY-POLICY.md) |
| **Architecture explorer** | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| **Changelog reader** | [docs/CHANGELOG.md](docs/CHANGELOG.md) |

### Doc Tree

```
README.md                  ← This file (overview + navigation)
docs/
├── GUIDE.md               ← User guide (beginner + detailed)
├── ARCHITECTURE.md        ← Full call chain + data structures
├── CONTRIBUTING.md        ← Contribution guide
├── CHANGELOG.md           ← Version history
├── SECURITY-POLICY.md     ← Security policy whitepaper
└── DOCUMENTATION-GUIDE.md ← Documentation standards
```

## Quick Reference

### CLI Commands

| Command | Effect |
|---------|--------|
| `moon run src/main` | MoonBit policy engine + demo |
| `cargo run -- demo` | Rust policy engine demo |
| `cargo run -- scan malware.py` | Scan script for threats |
| `cargo run -- sandbox tool.wasm` | WASI physical sandbox |
| `cargo run -- serve` | Web dashboard (port 9090) |
| `cargo run -- audit` | Audit log JSONL |
| `cargo run -- verify tool.wasm id pub` | Tool signature verification |

### Library Usage

```moonbit
// MoonBit: moon add tuya-me/aegisrun
let aegis = @lib.AegisRun::new("standard")
aegis.check_domain("evil.com")          // → Deny
```

```rust
// Rust: cargo add aegisrun-runtime
let policy = Policy::standard();
policy.check_domain("evil.com");  // → false
```

### MCP Integration

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

5 tools: `sandbox`, `scan`, `check_domain`, `check_path`, `check_env`.

## License

Apache License 2.0

</div>

<div class="zh">

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
| 1 | 安装时声明审查 | 风险评分引擎（Safe/Warning/Dangerous/Critical） |
| 2 | 域名/IP 黑名单 | HashMap O(1) + 后缀通配 + IP 前缀（45+规则） |
| 3 | 路径 + 环境变量保护 | 精确 + 前缀 + KEY/SECRET/TOKEN 检测（60+模式） |
| 4 | 工具黑名单 + 审计 | 即时封杀 + JSONL 持久化 + 策略热加载 |
| 5 | Wasm 沙箱物理隔离 | Rust wasmtime WASI 零目录预打开 + 过滤环境变量 |

## 快速开始

```cmd
cd D:\moonbit\aegisrun
quickstart.cmd                    # 一键菜单

moon run src/main                 # MoonBit CLI：策略引擎演示

cd runtime
cargo run -- demo                 # Rust CLI：策略引擎演示
cargo run -- serve                # Web 面板（9090端口）
```

## 文档导视

所有文档均为中英双语，根据角色选择入口：

| 如果你... | 从这里开始 |
|-----------|-----------|
| **新手** — 想立刻跑起来 | [docs/GUIDE.md](docs/GUIDE.md)（新手入门） |
| **开发者** — 集成库 | [docs/GUIDE.md](docs/GUIDE.md)（详情参考） |
| **贡献者** — 提代码 | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| **安全工程师** — 审计规则 | [docs/SECURITY-POLICY.md](docs/SECURITY-POLICY.md) |
| **架构探索** — 理解设计 | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| **版本追踪** — 看更新 | [docs/CHANGELOG.md](docs/CHANGELOG.md) |

### 文档树

```
README.md                  ← 本文（项目概览 + 文档导视）
docs/
├── GUIDE.md               ← 使用指南（新手级 + 详情级）
├── ARCHITECTURE.md        ← 架构 + 调用链 + 数据结构
├── CONTRIBUTING.md        ← 贡献指南
├── CHANGELOG.md           ← 更新日志
├── SECURITY-POLICY.md     ← 安全策略白皮书
└── DOCUMENTATION-GUIDE.md ← 文档规范
```

## 命令速查

| 命令 | 效果 |
|------|------|
| `moon run src/main` | MoonBit 策略引擎 + 演示 |
| `cargo run -- demo` | Rust 策略引擎演示 |
| `cargo run -- scan malware.py` | 扫描脚本找威胁 |
| `cargo run -- sandbox tool.wasm` | WASI 物理隔离沙箱 |
| `cargo run -- serve` | Web 面板（9090端口） |
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

</div>
