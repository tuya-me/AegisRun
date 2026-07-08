# AegisRun Changelog

> 🇨🇳 [中文版 →](docs-ch/CHANGELOG.md)

---

## v0.8.0 (2026-07-08) — Architecture Duality Elimination

- 7 architecture dualities eliminated: dual policy source, duplicate scanner, dual dashboard, scorer not via sandbox, SQL reconnect, dual persistence, fake MCP
- 5-layer call chain fully powered: limiter/monitor/alert/sql_guard/scorer invoked in sandbox
- Scorer pre-check via `min_score`
- SQL connection reuse in Sandbox struct
- MoonBit CLI honesty: `serve` explains MCP is on Rust; new `sync` command
- CI all green: multi-target matrix + release gates

## v0.7.0 (2026-07-05) — Full Hardening

- Unified facade `AegisRun::new("standard")`, audit log JSONL, policy hot reload
- Web dashboard real-time refresh, tool signature verification (SHA256)
- 0 warnings (MoonBit + Rust), 27/27 interception verified

## v0.4.1 — wasmtime WASI Physical Isolation

- wasmtime 39, zero preopens + filtered env
- 27/27 malicious operations intercepted at WASI layer

## v0.4.0 — Unified Entry + MCP

- Rust lib/CLI separation, MCP endpoint (`/mcp`, Claude Desktop compatible)
- Web admin panel, script scanner, OS-level sandbox

## v0.3.0 — Sandbox Runtime + DNS

- Rust wasmtime sandbox runtime, DNS hijacking defense
- Alert notifications, terminal dashboard, script generator

## v0.1.0 — Initial Release

- Core engine (check_domain/path/env/tool_id), sandbox interception layer
- CLI (preset/deny/allow/show/demo/serve), 3 presets (strict/standard/permissive)
