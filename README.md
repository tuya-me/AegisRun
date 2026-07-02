# AegisRun v0.3.0

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](runtime/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80`（仅 runtime 目录需要）| 沙箱运行时 `>= wasmtime 39`

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

加入 Rust 不是因为 MoonBit 不够——MoonBit 做策略判断非常合适（类型安全 + Wasm 产物极小）。但**真正的沙箱需要拦截操作系统调用**（文件打开、网络发包、环境变量读取），这需要 wasmtime 的 WASI 宿主函数支持，只有 Rust/C 能做到。

---

## 快速开始

```cmd
cd D:\moonbit\aegisrun

# 新手一键菜单（推荐）
quickstart.cmd

# 或直接跑拦截演示
set AEGISRUN_ATTACKS=all
moon run src/generator/intercept.mbt
```

---

## 统一入口（推荐）

```cmd
:: 唯一入口 — 两个 demo
moon run src/demo/intercept.mbt      ← 安全拦截演示 (14/14 拦截)
moon run src/generator/generator.mbt  ← 恶意脚本生成器 (12 种可选)

:: 选择攻击类型
set AEGISRUN_ATTACKS=1,4,7,12
moon run src/demo/intercept.mbt
```

## MCP 调用 (AI Agent 集成)

```json
// Claude Desktop 配置: %APPDATA%\Claude\claude_desktop_config.json
{
  "mcpServers": {
    "aegisrun": { "url": "http://localhost:9090/mcp" }
  }
}
```

Agent 可调用的 5 个工具: `aegisrun.sandbox` / `aegisrun.scan` / `aegisrun.policy.check_domain` / `aegisrun.policy.check_path` / `aegisrun.policy.check_env`

## 调用方式

| 命令 | 效果 |
|------|------|
| `quickstart.cmd` | 可视化菜单，所有功能一键选 |
| `moon run src/main web` | 打开网页管理面板（浏览器修改策略） |
| `dashboard.html` | 双击打开网页管理面板 |
| `moon run src/generator/intercept.mbt` | 12 种攻击拦截演示（14/14 拦截） |
| `moon run src/main` | 7 个安全场景 |
| `moon run src/full_demo/full_demo.mbt` | Full 集成测试（13 项） |
| `moon run src/sandbox_demo/sandbox_demo.mbt` | 沙箱演示（22 项） |
| `moon run src/scanner/scanner.mbt` | 恶意工具扫描器（14 项） |
| `moon run src/scanner/scanner.mbt` | 恶意工具扫描器（14 项） |

### CLI 命令

```cmd
moon run src/main preset standard        # 切换预设
moon run src/main deny tool weather-query # 封杀工具
moon run src/main allow domain wttr.in   # 白名单域名
moon run src/main show                   # 查看策略
```

### 网页管理面板 + 策略同步

```cmd
:: 方式1: 双击打开
dashboard.html

:: 方式2: CLI 命令
moon run src/main web

:: 网页操作流程:
:: ① 在网页修改黑白名单/预设模板
:: ② 点「复制 CLI 命令」按钮
:: ③ 粘贴到 CMD → 策略立刻同步到库
::
:: 示例:
set AEGISRUN_POLICY=domain_bl=evil.com,stealer.cc|domain_wl=wttr.in|path_bl=/etc/passwd
moon run src/main show
```

### Rust 沙箱运行时（独立使用）

```bash
cd runtime
cargo build --release
cargo run                           # 演示模式（策略引擎测试）
cargo run -- tool.wasm              # 加载 .wasm 工具沙箱执行
cargo run -- tool.wasm --policy ../policy.example.yaml
```

---

## 12 种可拦截攻击

| # | 表面功能 | 隐藏恶意 | AegisRun 拦截 |
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
| 11 | CI 检查 | getenv(GITHUB_TOKEN) | TOKEN 关键词检测 |
| 12 | 云备份 | open(.aws) + POST evil | 双重拦截 |

---

## 项目结构

```
aegisrun/
├── src/lib/                核心库（MoonBit，10 个模块，~1,250 行）
│   ├── core.mbt              黑名单引擎 + 策略引擎
│   ├── sandbox.mbt           沙箱拦截层（5 个拦截器）
│   ├── scorer.mbt            风险评分引擎 v1.1
│   ├── sql_guard.mbt         SQL 资源控制 v1.2
│   ├── limiter.mbt           三维并发限流 v1.3
│   ├── monitor.mbt           压力监控+熔断 v1.4
│   ├── dns_guard.mbt         DNS 劫持检测 + IP 黑名单 v0.3
│   ├── alert.mbt             告警通知 v0.3
│   └── dashboard.mbt         终端仪表盘 v0.3
│
├── runtime/               沙箱运行时（Rust + wasmtime, 210 行）
│   ├── src/main.rs           WASI 拦截器 + 策略引擎（Demo 模式）
│   ├── Cargo.toml
│   └── README.md
│
├── src/generator/         恶意脚本生成 + 拦截演示
├── docs/                   公开文档
│   ├── ARCHITECTURE.md       架构文档（完整调用链）
│   ├── CONTRIBUTING.md       开发者指南（代码安全方向）
│   └── DOCUMENTATION-GUIDE.md  文档规范
├── presets/                安全预设（YAML）
├── quickstart.cmd          新手一键菜单
├── GUIDE.md                新手指南
├── ROADMAP.md              路线图
└── CHANGELOG.md            更新日志
```

---

## 安全架构（五层防御）

| 层 | 名称 | 实现 |
|:--:|------|------|
| 1 | 安装时声明审查 | 风险评分引擎（Safe/Warning/Dangerous/Critical） |
| 2 | 域名/IP 黑名单 | HashMap O(1) + 后缀通配 + IP 前缀 + 内网保护 |
| 3 | 路径 + 环境变量保护 | 精确 + 前缀目录 + KEY/SECRET/TOKEN 检测 |
| 4 | 工具黑名单 + 审计 | 即时封杀 + JSONL 日志 |
| 5 | Wasm 沙箱执行 | Rust wasmtime WASI 拦截 |

---

## 版本

| 版本 | 标签 | 核心变更 |
|------|------|------|
| v0.1.0 | `v0.1.0` | 黑名单引擎 + 沙箱拦截层 |
| v0.2.0 | — | 风险评分 + SQL 控制 + 限流 + 监控 |
| v0.3.0 | `v0.3.0-sandbox` | Rust 运行时 + DNS 防护 + 仪表盘 + 生成器 |

---

## 相关文档

- [GUIDE.md](GUIDE.md) — 新手指南（3 分钟上手 + 常见坑）
- [ROADMAP.md](ROADMAP.md) — 路线图 v1.1 → v2.0
- [CHANGELOG.md](CHANGELOG.md) — 版本更新日志
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 架构文档（完整调用链 + 数据结构）
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — 开发者指南（可贡献方向 + 代码规范）
- [docs/DOCUMENTATION-GUIDE.md](docs/DOCUMENTATION-GUIDE.md) — 文档存放规范
- [runtime/README.md](runtime/README.md) — Rust 运行时说明

---

## 开源许可

Apache License 2.0
