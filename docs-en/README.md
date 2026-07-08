# AegisRun v0.8.0

**AI Agent Secure Tool Execution Framework — MoonBit Policy Engine + Rust Sandbox Runtime**


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
| **New users** | [docs-en/GUIDE.md](GUIDE.md) (Beginner) |
| **Developers** | [docs-en/GUIDE.md](GUIDE.md) (Detailed) |
| **Contributors** | [docs-en/CONTRIBUTING.md](CONTRIBUTING.md) |
| **Security** | [docs-en/SECURITY-POLICY.md](SECURITY-POLICY.md) |
| **Architecture** | [docs-en/ARCHITECTURE.md](ARCHITECTURE.md) |
| **中文文档** | [README.md](../README.md) |

## License

Apache License 2.0
