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
    │ MCP Protocol
    ▼
AegisRun Runtime
    │ ① Blacklist check → "Is this tool blocked?"
    │ ② Grant compute      → "What is it actually allowed to do?"
    │ ③ Wasm sandbox       → "Run it in the cage"
    │ ④ Audit log           → "Record everything"
    ▼
Result returned to Agent
```

---

## Quick Start

### 1. Install

```bash
# Install MoonBit toolchain
curl -fsSL https://cli.moonbitlang.com/install.sh | bash

# Clone and build
git clone https://github.com/your-username/aegisrun.git
cd aegisrun
moon build
```

### 2. Choose a security preset

```bash
# Recommended for daily use
aegisrun preset standard

# Strict: deny everything, approve individually
aegisrun preset strict

# Permissive: dev mode, only block critical paths
aegisrun preset permissive
```

### 3. Connect your AI agent

```bash
# Start MCP server on stdio
aegisrun

# In Claude Desktop config (claude_desktop_config.json):
# {
#   "mcpServers": {
#     "aegisrun": {
#       "command": "aegisrun"
#     }
#   }
# }
```

### 4. Let your agent use tools safely

Now your AI agent can call `calculator`, `weather-query`, `file-reader` — all running inside sandboxes with exactly the permissions you granted.

---

## Security Architecture (5-Layer Defense)

| Layer | Name | What it does |
|:-----:|------|-------------|
| 1 | **Preset Templates** | One command to load a policy (`strict`/`standard`/`permissive`) |
| 2 | **Blacklist Engine** | Hash-based O(1) domain/path/tool matching, < 1μs overhead |
| 3 | **Whitelist Bypass** | Trusted tools/authors skip all checks |
| 4 | **Sandbox Enforcement** | Wasm cage: no network/FS access without explicit grant |
| 5 | **Audit Trail** | Every call, denial, and error logged to JSONL |

---

## Demo Tools

| Tool | Permissions Needed | Demonstrates |
|------|-------------------|-------------|
| `calculator` | None (pure function) | Zero-trust sandboxed execution |
| `weather-query` | Network → `wttr.in` | Domain whitelisting |
| `file-reader` | Filesystem → `/tmp/aegisrun/` | Path whitelisting + read-only |

---

## Project Structure

```
aegisrun/
├── src/
│   ├── types.mbt                  # Core type definitions
│   ├── main/main.mbt              # CLI entry + MCP server startup
│   ├── permission/                # Policy engine
│   │   ├── policy.mbt             #   Policy loading + hot-reload
│   │   ├── blacklist.mbt          #   O(1) hash-based matching
│   │   ├── grant.mbt              #   Capability intersection
│   │   ├── preset.mbt             #   strict/standard/permissive
│   │   └── cli.mbt                #   allow/deny/show commands
│   ├── sandbox/                   # Wasm execution sandbox
│   │   ├── executor.mbt           #   Wasm5 integration
│   │   ├── limits.mbt             #   Resource enforcement
│   │   └── capabilities.mbt       #   Network/FS/env interceptors
│   ├── mcp/                       # MCP protocol
│   │   ├── types.mbt              #   JSON-RPC types
│   │   ├── server.mbt             #   tools/list + tools/call
│   │   └── transport.mbt          #   stdio transport
│   ├── registry/                  # Tool registry
│   │   ├── registry.mbt           #   Register/find/list tools
│   │   └── manifest.mbt           #   Manifest parsing
│   └── audit/                     # Audit logging
│       └── telemetry.mbt          #   Async batch-write JSONL
├── demo/                          # Demo tools
│   ├── calculator/tool.mbt
│   ├── weather/tool.mbt
│   └── file_reader/tool.mbt
├── test/                          # Test suites
│   ├── attack_test.mbt            #   Security attack simulation
│   ├── blacklist_test.mbt         #   Blacklist engine tests
│   └── integration_test.mbt       #   End-to-end MCP tests
├── presets/                       # Security preset templates
│   ├── strict.yaml
│   ├── standard.yaml
│   └── permissive.yaml
├── policy.example.yaml            # Example policy config
├── ROADMAP.md                     # Full version roadmap
└── README.md
```

---

## CLI Commands

```bash
aegisrun preset <name>           # Switch security preset
aegisrun allow <type> <value>    # Add to whitelist
aegisrun deny <type> <value>     # Add to blacklist
aegisrun policy show             # Display current policy
aegisrun audit <tool> [count]    # View audit log
aegisrun run <tool> <json>       # Execute a tool manually
```

---

## Competition Info

This project is submitted to **OSC2026 — MoonBit × CCF Open Source Innovation Contest**, under the **AI Agent Engineering (AI Agent 工程化开发)** track.

See [OSC2026_AI_Agent_参赛方案.md](../md/wendang/OSC2026_AI_Agent_参赛方案.md) for the full proposal (Chinese).

---

## License

Apache 2.0 — See [LICENSE](LICENSE)

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the Full version plan (v1.1 → v2.0).
