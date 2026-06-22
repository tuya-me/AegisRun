# AegisRun Lite v0.1.0

**Secure AI Agent Tool Execution Framework — MoonBit + WebAssembly**

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> **MoonBit 版本要求**: `>= 0.1.20260608`（本演示项目）| 完整版 `>= 0.1.20260522`

---

## What is AegisRun?

AegisRun lets AI agents (Claude, GPT, etc.) safely execute third-party tools by running each tool inside a **MoonBit-compiled WebAssembly sandbox**. 

**Core idea**: Every tool runs in a cage. By default, it can do nothing. You explicitly grant each permission — which domains it can access, which folders it can read, which SQL tables it can query.

```
AI Agent (Claude/GPT)
    | MCP Protocol
    v
AegisRun Runtime
    | 1. Blacklist check -> "Is this tool blocked?"
    | 2. Grant compute     -> "What is it actually allowed to do?"
    | 3. Wasm sandbox      -> "Run it in the cage"
    | 4. Audit log          -> "Record everything"
    v
Result returned to Agent
```

---

## Quick Start

```bash
# Install MoonBit toolchain
powershell -C "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.com/install/powershell.ps1 | iex"

# Clone and run
git clone https://gitlink.org.cn/tuya/AegisRun.git
cd aegisrun
moon run src/main

# Interactive menu
.\run_demo.bat
```

---

## 7 Interactive Security Demos

Run `moon run src/main` or `.\run_demo.bat` to see:

| # | Demo | Scenario |
|:--:|------|------|
| 1 | Tool Install | Permission declaration review |
| 2 | Domain BL | Malicious data exfiltration blocked |
| 3 | Path BL | Sensitive file access denied |
| 4 | Env Protect | API key theft prevented |
| 5 | Tool Ban | Runtime blacklist, instant effect |
| 6 | Audit Trail | Full attack chain traceable |
| 7 | Policy Summary | 5-layer defense overview |

---

## Security Architecture

| Layer | Name | Implementation |
|:-----:|------|---------------|
| 1 | Preset Templates | `strict` / `standard` / `permissive` |
| 2 | Blacklist Engine | HashMap O(1) domain/path/tool matching |
| 3 | Whitelist Bypass | Trusted tools/authors skip checks |
| 4 | Sandbox Enforcement | Wasm cage: zero ambient authority |
| 5 | Audit Trail | JSONL log of every decision |

---

## License

Apache 2.0 — See [LICENSE](LICENSE)

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for v1.1 → v2.0 plan.
