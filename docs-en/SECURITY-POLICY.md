# AegisRun Security Policy

> 🇨🇳 [中文版 →](../docs-ch/SECURITY-POLICY.md)

---
## v0.9.2 New Security Features

### Runtime Sandbox Monitor

New `sandbox_monitor.rs` module provides runtime behavior monitoring via Python audit hooks:

- **Environment variable interception**: monkey-patches `os.getenv` and `os.environ` to block sensitive variable access
- **Network connection interception**: monkey-patches `socket.connect` to block blacklisted domain connections
- **Subprocess interception**: monkey-patches `subprocess.Popen` to check command parameters for dangerous operations
- **File operation interception**: intercepts `open()` calls via audit hook

### Web Panel Security Enhancements

- **Dual detection modes**: Static Scan + Runtime Sandbox, independently toggleable
- **Audit log visualization**: Real-time display of all security decisions (ALLOW/DENY)
- **MCP Agent preflight**: Automatic policy checks before interactive tool calls

### MCP Tools Expanded to 9

Expanded from 5 to 9 tools, adding:
- `policy.summary`: Returns complete policy and defense layer state
- `guard_tool_call`: Preflight entire tool calls (domains/paths/env/command)
- `scan_code`: Scan code strings
- `sandbox_python`: Runtime sandbox execution
- `sandbox_wasm`: WASI physical isolation sandbox

## Design Philosophy

Core assumption: **third-party tools called by AI agents are untrusted**.

Three principles:
1. **Declaration is constraint** — undeclared = denied
2. **Combination detection** — harmless alone ≠ harmless in combination
3. **Defense in depth** — checked at both MoonBit policy layer and Rust sandbox layer

## Policy Sources

All default rules in `src/lib/core.mbt`:

- 7 malicious domains, 3 suffix TLDs, 3 private IP ranges
- 22 sensitive paths, 36 env var patterns, 5 keywords
- 30s timeout, 256MB memory limit

## Threat Intelligence

| Category | Sources |
|----------|---------|
| C2 servers | abuse.ch, AlienVault OTX |
| Malware | URLhaus, MalwareBazaar |
| Phishing | PhishTank, OpenPhish |
| Tor exit nodes | Tor Project |
| Private networks | RFC 1918 |
| Free TLDs | IANA (`.tk`, `.ml`, `.ga`, `.cf`) |

## Extending Rules

1. YAML preset (`presets/standard.yaml`)
2. `policy.json` — Rust persistence
3. Web panel — `cargo run -- serve`

## Audit

All calls logged in `aegisrun-audit.jsonl`:
```jsonl
{"tool_id":"weather-query","decision":"DENY","reason":"evil.com in blacklist"}
```
