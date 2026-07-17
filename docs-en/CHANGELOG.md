# AegisRun Changelog

> 🇨🇳 [中文版 →](../docs-ch/CHANGELOG.md)

---
## v0.9.3 (2026-07-17) — ToolRegistry + Test Refactoring + Dashboard Upgrade + UX Alignment

### Added
- **ToolRegistry full lifecycle**: tool discovery, registration, unregistration, tag search, keyword search, SHA256 signature verification, JSON persistence
- **3 MCP tools**: `tools.list`, `tools.search`, `tools.tags`, MCP count 9→12
- **5 REST API endpoints**: Tool registry CRUD + directory scan
- **Dashboard ToolRegistry UI**: tool list, keyword search, tag cloud, registration form, unregister
- **Dashboard MCP parameter templates**: all tools with JSON templates
- **Sandbox file path input**: specify file path instead of pasting code
- **Sandbox mode toggle**: static scan / runtime sandbox dual mode
- **`aegisrun.tools.get` MCP tool**: query single tool by ID (13th MCP tool)
- **`GET /api/tools/get/<id>` REST endpoint**: single tool query
- **`BufAuditLogger` async audit**: channel + background thread, non-blocking log(), 500ms batch flush
- **CLI `scan --code`**: inline code scanning `aegisrun scan --code "..."`, aligned with web
- **CLI `scan --json`**: JSON output for CI/CD integration
- **CLI `audit` reads real log**: shows last 20 entries (previously wrote 3 hardcoded demo entries)
- **CLI help rewritten**: sectioned COMMANDS/EXAMPLES/LIBRARY

### Improvements
- **Web UX alignment**: info-banners, empty states, loading states added to Dashboard/Domain/Path/Env/Audit
- **Env page button fix**: unified to "Block" (was "Add")
- **Audit clear confirmation**: confirm dialog before clearing
- **Tool registry search fix**: tag cloud uses `?tag=`, backend supports `keyword/q/tag` params
- **Tool unregister fix**: frontend sends POST body, route matched correctly
- **`scan_file()` library function**: `pub fn scan_file(path)` in `lib.rs`, eliminates duplicated code
- **MoonBit CLI `web` path fix**: `dashboard.html` → `web/dashboard.html`
- **README `cargo run` standardization**: removed dead `sandbox-monitor`, all commands with `cd runtime` prefix

### Refactor
- **AuditLogger split**: synchronous `AuditLogger` retained, async `BufAuditLogger` added (channel-based)
- **Rust test file separation**: 7 test files extracted to `runtime/tests/`
- **MoonBit test file separation**: `monitor_tests.mbt` (18), `limiter_tests.mbt` (14)

### Tests
- Rust tests: 81 items (new: wasi_sandbox:6, mcp:6, hot_reload:5)
- MoonBit tests: 32 test blocks
- CI: `moon build` + `moon test` + `cargo test` full coverage

### Docs
- Full README/GUIDE/CHANGELOG update: CLI commands, REST API endpoints, MCP tool list, library API
- Web panel version v0.9.2 → v0.9.3

---
## v0.9.2 (2026-07-14) — MCP Rewrite + Runtime Sandbox + Dashboard Redesign

### Added
- **MCP tools expanded from 5 to 9**: `policy.summary`, `guard_tool_call`, `scan_code`, `sandbox_python`, `sandbox_wasm`
- **MCP JSON-RPC normalization**: proper id echo, error codes, inputSchema
- **`/api/sandbox-run` endpoint**: web panel supports Python runtime sandbox (static + runtime merge)
- **Interactive MCP tool caller** in dashboard: select tool, fill args, call directly
- **Dashboard visual separation**: Web management / Sandbox / MCP Agent zones
- **Dual sandbox mode**: Static Scan / Runtime Sandbox toggle
- **`sandbox_connect_domain`**: Rust runtime network guard
- **Wildcard path matching**: `wildcard_match` supports `*`

### Fixed
- `production-check` example clippy warning
- Sandbox monitor: full monkey-patch of `os.getenv`/`os.environ`/`socket.connect`/`subprocess.Popen`
- Path backslash normalization

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
