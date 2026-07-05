# AegisRun v0.6.0

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80`（仅 runtime 目录需要）| wasmtime 39

---

## 项目简介

AegisRun 让 AI Agent 安全调用第三方工具。每个工具编译为 WebAssembly 模块，零权限启动，按需授权。

**两层架构**：

```
MoonBit 库 (src/lib/)               Rust 运行时 (runtime/)
┌────────────────────┐           ┌──────────────────────────┐
│ check_domain()     │   Allow   │ wasmtime WASI 拦截器      │
│ check_path()       │←─────────│ path_open → check_path    │
│ check_env()        │   Deny    │ environ_get → check_env   │
│                    │           │ sock_send → check_domain  │
│ 纯逻辑，纯 MoonBit  │           │ 系统调用拦截，Rust 实现    │
└────────────────────┘           └──────────────────────────┘
    策略判断层                         执行拦截层
```

---

## 快速开始

```cmd
cd D:\moonbit\aegisrun

# 新手一键菜单
quickstart.cmd

# 拦截演示（14/14 拦截率）
set AEGISRUN_ATTACKS=all
moon run src/demo/intercept.mbt

# 恶意脚本生成器（12 种攻击可选）
moon run src/generator/generator.mbt

# Rust CLI 演示
aegisrun.exe demo
aegisrun.exe scan malware.py
```

---

## 调用方式

### 作为库使用

```moonbit
// MoonBit: moon add aegisrun
let aegis = @lib.AegisRun::new("standard")
aegis.check_domain("evil.com")          // → Deny
aegis.check_path("/etc/passwd")          // → Deny
aegis.check_env("OPENAI_API_KEY")        // → Deny
```

```rust
// Rust: cargo add aegisrun-runtime
let policy = Policy::standard();
policy.check_domain("evil.com");  // → false
scan_script(&source);             // → 返回违规列表
```

### CLI 命令

| 命令 | 效果 |
|------|------|
| `aegisrun.exe demo` | 策略引擎演示（14项） |
| `aegisrun.exe scan malware.py` | 扫描脚本找威胁 |
| `aegisrun.exe sandbox tool.wasm` | WASI 物理隔离沙箱 |
| `aegisrun.exe serve` | Web 管理面板（9090端口） |
| `aegisrun.exe audit` | 审计日志 JSONL 写盘 |
| `aegisrun.exe verify tool.wasm id pub` | 工具签名验证 |
| `aegisrun.exe policy show` | 查看当前策略 |

### WASI 物理隔离沙箱

```cmd
:: 编译恶意工具
cd runtime\tools\evil_plugin
cargo build --target wasm32-wasip1 --release

:: 沙箱执行——工具物理上无法访问任何文件/密钥
aegisrun.exe sandbox target\wasm32-wasip1\release\evil-plugin.wasm
```

输出：
```
[BLOCKED] /etc/passwd: os error 44 (sandbox — zero preopens)
[BLOCKED] OPENAI_API_KEY: not set (sandbox — filtered env)
[BLOCKED] GITHUB_TOKEN: not set (sandbox — filtered env)
27/27 malicious operations intercepted — 不是策略 Deny，是 WASI 物理隔离
```

### Web 管理面板

```cmd
aegisrun.exe serve                  # 启动 Web 面板
start dashboard.html                # 或双击打开
:: 浏览器 → http://localhost:9090
:: 网页改策略 → 点"复制CLI命令" → 粘贴到CMD → 同步到库
```

### MCP 集成

```json
// Claude Desktop 配置
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

Agent 可调 5 个工具：sandbox / scan / check_domain / check_path / check_env

---

## 12 种可拦截攻击

| # | 表面功能 | 隐藏恶意 | 拦截方式 |
|:--:|------|------|------|
| 1 | 数据分析 | POST evil.com | check_domain 精确命中 |
| 2 | 导出助手 | POST *.cn | check_domain 后缀匹配 |
| 3 | 网络诊断 | GET 192.168.1.100 | 内网 IP 黑名单 |
| 4 | 配置读取 | open(/etc/passwd) | check_path 精确命中 |
| 5 | SSH 导入 | open(~/.ssh/id_rsa) | check_path 前缀匹配 |
| 6 | 系统信息 | open(C:\Windows\SAM) | check_path 前缀匹配 |
| 7 | AI 插件 | getenv(OPENAI_API_KEY) | check_env 敏感模式 |
| 8 | 数据库迁移 | getenv(DATABASE_URL) | check_env 敏感模式 |
| 9 | 备份同步 | POST stealer.cc | check_domain 精确命中 |
| 10 | 开发监控 | GET localhost:3000 | 回环地址黑名单 |
| 11 | CI 检查 | getenv(GITHUB_TOKEN) | TOKEN 关键词 |
| 12 | 云备份 | open(.aws) + POST evil | 双重拦截 |

---

## 项目结构

```
aegisrun/
├── src/lib/                 MoonBit 核心库（10 个模块，~1440 行）
│   ├── aegisrun.mbt           统一门面（一行 API 接入）
│   ├── core.mbt               黑名单引擎 + 策略引擎
│   ├── sandbox.mbt            沙箱拦截层
│   ├── scorer.mbt             风险评分引擎
│   ├── sql_guard.mbt          SQL 资源控制
│   ├── limiter.mbt            三维并发限流
│   ├── monitor.mbt            压力监控 + 熔断
│   ├── dns_guard.mbt          DNS 劫持检测
│   ├── alert.mbt              告警通知
│   └── dashboard.mbt          终端仪表盘
│
├── runtime/                  Rust 库 + CLI（~900 行）
│   ├── src/lib.rs              核心库（Policy + sandbox + scanner）
│   ├── src/main.rs             CLI 工具（aegisrun.exe）
│   ├── src/sandbox.rs          wasmtime WASI 物理隔离沙箱
│   ├── src/server.rs           Web 面板 + MCP 端点
│   ├── src/persist.rs          审计日志 + 策略持久化 + 热加载
│   ├── src/verify.rs           工具签名验证
│   └── tools/evil_plugin/     恶意 .wasm 测试工具（27/27 拦截验证）
│
├── src/demo/                 MoonBit 演示
├── src/generator/            恶意脚本生成器
├── dashboard.html            Web 管理面板
├── docs/                     公开文档
└── presets/                  安全预设（YAML）
```

---

## 安全架构（五层防御）

| 层 | 名称 | 实现 |
|:--:|------|------|
| 1 | 安装时声明审查 | 风险评分引擎（Safe/Warning/Dangerous/Critical） |
| 2 | 域名/IP 黑名单 | HashMap O(1) + 后缀通配 + IP 前缀 + 内网（45+规则） |
| 3 | 路径 + 环境变量保护 | 精确 + 前缀目录 + KEY/SECRET/TOKEN 检测（60+模式） |
| 4 | 工具黑名单 + 审计 | 即时封杀 + JSONL 持久化 + 策略热加载 |
| 5 | Wasm 沙箱物理隔离 | Rust wasmtime WASI 零目录预打开 + 过滤环境变量 |

---

## 相关文档

- [GUIDE.md](GUIDE.md) — 新手指南（3 分钟上手 + 常见坑）
- [ROADMAP.md](ROADMAP.md) — 路线图（v1.1 → v2.0）
- [CHANGELOG.md](CHANGELOG.md) — 更新日志（版本变更记录）
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 架构文档（完整调用链 + 数据结构）
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — 开发者指南（贡献方向 + 代码规范）
- [docs/DOCUMENTATION-GUIDE.md](docs/DOCUMENTATION-GUIDE.md) — 文档规范
- [runtime/README.md](runtime/README.md) — Rust 运行时说明

---

## 开源许可

Apache License 2.0
