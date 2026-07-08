# AegisRun v1.0.0

**AI Agent 安全工具执行框架 — MoonBit 策略引擎 + Rust 沙箱运行时**

> 🇬🇧 [English README →](docs-en/README.md)

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

---

## 目录

1. [项目简介](#项目简介)
2. [快速开始](#快速开始)
3. [真实攻击拦截报告](#真实攻击拦截报告)
4. [沙箱行为监控](#沙箱行为监控)
5. [策略配置](#策略配置)
6. [文档导视](#文档导视)

---

## 项目简介

AI Agent 调用的第三方工具可能窃取 API Key、上传敏感文件、扫描内网。AegisRun 提供**五层纵深防御** + **运行时行为监控**，在工具执行前和执行中双重拦截。

### 架构

```
MoonBit 策略引擎 (src/lib/)        Rust 沙箱运行时 (runtime/)
┌────────────────────┐           ┌──────────────────────────────┐
│ check_domain()     │   Allow   │ wasmtime WASI 物理隔离        │
│ check_path()       │←─────────│ Python 运行时沙箱监控          │
│ check_env()        │   Deny    │ 静态源码扫描                  │
│ 五层防御+缓存       │           │ MCP 端点 / Web 面板          │
└────────────────────┘           └──────────────────────────────┘
```

---

## 快速开始

### 静态扫描（推荐首选）

```bash
cd runtime
cargo run -- scan malicious.py          # 扫描脚本中的违规行为
cargo run -- demo                        # 14项策略引擎演示
cargo run -- serve                       # Web 面板 (localhost:9090)
```

### 运行时沙箱监控（检测编码/运行时逃逸）

```bash
cargo run -- sandbox-run malicious.py    # 在 Python audit hook 中执行
```

### MoonBit 库调用

```bash
moon add tuya-me/aegisrun
```

```moonbit
let aegis = @lib.AegisRun::new("standard")
aegis.check_domain("evil.com")           // → Deny
aegis.check_env("OPENAI_API_KEY")        // → Deny
aegis.check_http("https://evil.com")     // → Err (五层防御)
```

### Rust 库调用

```bash
cargo add aegisrun-runtime
```

```rust
let policy = Policy::standard();
policy.check_domain("evil.com");         // → false
policy.check_path("/etc/passwd");        // → false
```

### MCP 集成（AI Agent 直接调用）

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

---

## 真实攻击拦截报告

基于 2025-2026 年真实供应链攻击事件编写了 **10 类 60+ 测试样本**：

| # | 攻击类型 | 对应真实事件 | 场景数 | 拦截 |
|:-:|---------|-------------|:------:|:----:|
| 1 | 直接凭证窃取 | TeamPCP Trivy 投毒 | 7 | ✅ 全拦 |
| 2 | 变量间接引用 | SANDWORM_MODE typosquat | 8 | ✅ 全拦 |
| 3 | 字符串拼接/f-string | GuardFall Class C | 5 | ⚠️ 部分 |
| 4 | Base64/Hex 编码 | SkillCloak SFS Packing | 5 | ⚠️ 标记 |
| 5 | Shell 命令注入 | GuardFall Class A-E | 8 | ✅ 全拦 |
| 6 | Unicode 同形字 | TrapDoor 零宽字符 | 5 | ❌ 需运行时 |
| 7 | 外部配置读取 | 恶意 npm postinstall | 5 | ❌ 需运行时 |
| 8 | 云元数据 IMDS | CAI Cloud Worm | 8 | ✅ 全拦 |
| 9 | eval/exec 构造 | SkillCloak 自解压 | 7 | ✅ 全拦 |
| 10 | 真实攻击综合 | Shai-Hulud / TanStack | 8 | ✅ 全拦 |
| | **总计** | | **66** | **~85%** |

### 实际恶意代码拦截示例

扫描 `real-world-attack.py`（模拟 TeamPCP 窃密工具）：

```
🔴 [env] DATABASE_URL      — 数据库连接串泄露
🔴 [env] AWS_SECRET_ACCESS_KEY — 云凭证泄露
🔴 [env] OPENAI_API_KEY    — LLM API Key 泄露
🔴 [host] stealer.cc       — 恶意域名外泄
4 violations — BLOCKED
```

运行时沙箱监控（检测 `open()` 等系统调用）：

```
🔴 [runtime-open] /etc/passwd       — BLOCKED at runtime
🔴 [runtime-open] ~/.ssh/id_rsa     — BLOCKED at runtime
```

---

## 沙箱行为监控

### 原理

在 **Python audit hook** 层面拦截脚本的敏感操作：

```
目标脚本 → Python exec
            │
            ├─ audit_hook("open", path)      → check_path() → DENY
            ├─ audit_hook("socket.connect")   → check_domain() → DENY
            └─ audit_hook("subprocess.Popen") → 检查命令内容 → BLOCKED
```

### 调用方式

```bash
cd runtime
cargo run -- sandbox-run suspicious.py
```

### 输出报告

```
╔══════════════════════════════════════════════════╗
║  AegisRun 沙箱运行报告                           ║
║  静态扫描: 8 项 | 运行时: 2 项              ║
╚══════════════════════════════════════════════════╝

  🔴 [env] OPENAI_API_KEY       — BLOCKED (静态)
  🔴 [runtime-open] /etc/passwd — BLOCKED (运行时)
  ⚠️ [runtime-open] /tmp/data   — FLAGGED (仅记录)
```

---

## 策略配置

### 修改预设

编辑 `presets/standard.yaml`：

```yaml
blacklist:
  network:
    domains:
      - "evil.com"           # 已有
      - "your-threat.cn"     # 新增自定义规则
  env_vars:
    - "YOUR_INTERNAL_KEY"    # 新增内部密钥模式
```

### CLI 临时封禁

```bash
cargo run -- policy block domain evil.com
cargo run -- policy set strict
cargo run -- policy show
```

### Web 面板可视化

```bash
cargo run -- serve
# 浏览器 → http://localhost:9090
```

---

## 文档导视

| 如果你... | 请阅读 |
|-----------|--------|
| **新手** | [docs-ch/GUIDE.md](docs-ch/GUIDE.md) |
| **开发者** | [docs-ch/GUIDE.md](docs-ch/GUIDE.md)（详情参考） |
| **贡献者** | [docs-ch/CONTRIBUTING.md](docs-ch/CONTRIBUTING.md) |
| **安全策略** | [docs-ch/SECURITY-POLICY.md](docs-ch/SECURITY-POLICY.md) |
| **架构** | [docs-ch/ARCHITECTURE.md](docs-ch/ARCHITECTURE.md) |

---

## 开源许可

Apache License 2.0
