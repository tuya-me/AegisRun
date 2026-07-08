# AegisRun Contribution Guide

> v0.8.0
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
│   ├── src/sandbox.rs       wasmtime WASI sandbox
│   ├── src/server.rs        Web dashboard + MCP
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

## Development

**Rust:** `cd runtime && cargo build && cargo test && cargo clippy`

**MoonBit:** `moon build && moon check && moon fmt --check && moon test`

**Commit:** `git checkout -b feature/xxx` → write code → `git commit -m "feat: description"` → push → PR

## Code Style

**MoonBit:** `snake_case` functions, `PascalCase` structs. Public functions need Chinese comments.

**Rust:** Standard `rustfmt`, `snake_case`, `anyhow::Result`, `///` doc comments.

**Commits:** English labels. Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`.

## Project Status

| Metric | Value |
|--------|-------|
| MoonBit code | ~3,580 lines |
| Rust code | ~1,073 lines |
| Dualities eliminated | 7 / 7 |
| Call chain | ✅ Fully powered |
| Version | v0.8.0 |
| License | Apache 2.0 |
