# AegisRun Lite v0.1.0

**AI Agent 安全工具执行框架 — 基于 MoonBit + WebAssembly**

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> **环境要求**: MoonBit `>= 0.1.20260608` | 完整版 `>= 0.1.20260522`

---

## 项目简介

AegisRun 让 AI Agent（Claude、GPT 等）可以安全地调用第三方工具——每个工具都在 MoonBit 编译的 WebAssembly 沙箱中执行，默认零权限，按需显式授权。

**核心理念**：每个工具跑在笼子里。默认什么都不能做。你显式授予每一项权限——能访问哪些域名、能读哪些文件夹、能查哪些数据表。

```
AI Agent (Claude / GPT / 开源)
    │ MCP 协议
    ▼
AegisRun 运行时
    │ ① 黑名单检查 → "这个工具被封了吗？"
    │ ② 权限计算     → "它实际被允许做什么？"
    │ ③ Wasm 沙箱    → "在笼子里执行"
    │ ④ 审计日志     → "记录一切"
    ▼
返回结果给 Agent
```

---

## 快速开始

### 1. 安装 MoonBit 工具链

```powershell
powershell -C "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.com/install/powershell.ps1 | iex"
```

### 2. 克隆项目

```bash
git clone https://gitlink.org.cn/tuya/AegisRun.git
cd aegisrun
```

### 3. 运行演示

```bash
# 运行全部 7 个安全演示
moon run src/main

# 交互式菜单（双击运行）
.\run_demo.bat
```

---

## 调用方式

### 方式一：CLI 命令（开发调试）

```bash
cd D:\moonbit\aegisrun

# 查看帮助
moon run src/main

# 切换安全预设
moon run src/main preset standard      # 标准模式（推荐）
moon run src/main preset strict         # 严格模式
moon run src/main preset permissive     # 宽松模式

# 黑名单管理
moon run src/main deny tool weather-query   # 封杀一个工具
moon run src/main deny domain evil.com      # 封杀一个域名

# 白名单管理
moon run src/main allow domain wttr.in     # 放行一个域名

# 查看当前策略
moon run src/main show

# 运行单个演示
moon run src/main demo 2    # 只看 Demo 2（域名外泄拦截）
moon run src/main demo 5    # 只看 Demo 5（工具实时封杀）
```

### 方式二：环境变量选 Demo（配合脚本）

```bash
# Windows CMD
set AEGISRUN_DEMO=2 && moon run src/main    # 只跑 Demo 2

# 不设环境变量 → 跑全部
moon run src/main
```

### 方式三：交互式菜单

双击 `run_demo.bat`，输入数字 1-7 选择单个演示，按 8 跑全部，按 0 退出。

### 方式四（将来发布 mooncakes.io 后）

```bash
moon install aegisrun/aegisrun    # 全局安装
aegisrun preset standard           # 直接调用
aegisrun serve                     # 启动 MCP Server
```

---

## 7 个安全演示

| # | 演示 | 场景说明 |
|:--:|------|------|
| 1 | 工具安装审查 | 安装 weather-query 时自动审查权限声明，4 项检查通过，风险评分 92/100 |
| 2 | 域名外泄拦截 | 工具正常查天气时，偷偷 POST 数据到 evil.com → 沙箱在发 HTTP 请求前掐断 |
| 3 | 路径访问控制 | 日志分析器尝试读取 /etc/passwd 和 ~/.ssh/id_rsa → 精确命中路径黑名单 |
| 4 | 密钥保护 | 代码格式化器偷偷读取 OPENAI_API_KEY → 敏感模式匹配，3 个密钥全部拦截 |
| 5 | 工具实时封杀 | 发现异常 → `aegisrun deny tool weather-query` → 即时从可用变封杀，无需重启 |
| 6 | 审计日志追踪 | 6 条审计记录完整呈现攻击链：安装→外泄尝试→拦截→封杀 |
| 7 | 策略总览 | 展示当前 5 层防御状态：黑名单/白名单/路径保护/密钥防护/审计 |

---

## 项目结构

```
aegisrun/
├── src/
│   ├── lib/core.mbt              # 核心引擎：类型、黑名单引擎、策略引擎（可复用）
│   ├── demo/scenarios.mbt        # 7 个演示场景
│   └── main/
│       ├── main.mbt              # 入口：路由（30 行）
│       └── cli.mbt               # CLI 命令处理
├── presets/                      # 安全预设模板
│   ├── strict.yaml
│   ├── standard.yaml
│   └── permissive.yaml
├── run_demo.bat                  # 交互式菜单启动器
├── aegisrun.bat                  # CLI 包装脚本
├── ROADMAP.md                    # 完整版路线图
└── README.md
```

---

## 安全架构（五层防御）

| 层 | 名称 | 实现方式 |
|:--:|------|------|
| 1 | 预设模板 | `strict` / `standard` / `permissive` 一键切换 |
| 2 | 黑名单引擎 | HashMap O(1) 域名/路径/工具匹配 |
| 3 | 白名单通道 | 受信工具/作者跳过后续检查 |
| 4 | 沙箱执行 | Wasm 隔离：默认无网络/文件/环境变量权限 |
| 5 | 审计追踪 | JSONL 日志记录每一次安全决策 |

---

## 相关文档

- [ROADMAP.md](ROADMAP.md) — v1.1 → v2.0 完整路线图

