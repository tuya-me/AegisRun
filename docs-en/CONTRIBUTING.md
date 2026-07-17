# AegisRun Contribution Guide

> v0.9.2
> 🇨🇳 [中文版 →](../docs-ch/CONTRIBUTING.md)

---

## Project Architecture

```
aegisrun/
├── src/lib/                 MoonBit Library (policy engine)
│   ├── core.mbt             Blacklist engine + policy engine
│   ├── sandbox.mbt          Sandbox interception layer
│   ├── scorer.mbt           Risk scoring
│   ├── sql_guard.mbt        SQL resource control
│   ├── limiter.mbt          3D concurrency throttling
│   ├── monitor.mbt          Pressure monitoring
│   ├── dns_guard.mbt        DNS hijacking detection
│   ├── alert.mbt            Alert notifications
│   └── dashboard.mbt        Terminal dashboard
│
├── runtime/                 Rust Library + CLI
│   ├── src/lib.rs           Core (Policy + sandbox + scanner)
│   ├── src/main.rs          CLI (aegisrun.exe)
│   ├── src/server_main.rs   Daemon entry (aegisrund)
│   ├── src/server.rs        Web dashboard + MCP
│   ├── src/sandbox.rs       wasmtime WASI sandbox
│   ├── src/sandbox_monitor.rs  Runtime sandbox monitor
│   ├── src/persist.rs       Audit + persistence
│   └── src/verify.rs        Signature verification
│
├── src/demo/                MoonBit demos
├── src/generator/           Malicious script generator
├── dashboard.html           Web admin panel
├── docs-ch/                 Chinese docs
├── docs-en/                 English docs
└── presets/                 Security presets (YAML)
```

## Contribution Directions

**Low barrier:** Add domain blacklist (`core.mbt`), add env patterns (`core.mbt`), extend scoring (`scorer.mbt`)

**Medium barrier:** CLI auto-completion, dashboard real-time refresh, per-user rate limiting

**High barrier:** wasmtime WASI host functions, MoonBit→Rust FFI, distributed policy sync

**New in v0.9.2:**
- Extend `sandbox_monitor.rs` with more Python runtime intercepts (file write monitoring, etc.)
- Add new MCP tools (batch scanning, policy export, etc.)
- Dashboard internationalization (add Japanese, Korean, etc.)

## Development

**Rust:** `cd runtime && cargo build && cargo test && cargo clippy`

**MoonBit:** `moon build && moon check && moon fmt --check && moon test`

> **Windows note:** `moon test` (wasm/wasm-gc targets) may fail on older Windows 10 builds due to WASM runtime DLL compatibility. Use `moon test --target js` as a workaround — it validates the same MoonBit logic.

**Commit:** `git checkout -b feature/xxx` → write code → `git commit -m "feat: description"` → push → PR

## Code Style

**MoonBit:** `snake_case` functions, `PascalCase` structs. Public functions need Chinese comments.

**Rust:** Standard `rustfmt`, `snake_case`, `anyhow::Result`, `///` doc comments.

**Commits:** English labels. Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`.

## Project Status

| Metric | Value |
|--------|-------|
| MoonBit code | ~3,600 lines |
| Rust code | ~1,800 lines |
| Dualities eliminated | 7 / 7 |
| Call chain | ✅ Fully powered |
| Tests | MoonBit 6 (js target) + Rust 10 (9 unit + 1 doc) |
| Version | v0.9.2 |
| License | Apache 2.0 |
