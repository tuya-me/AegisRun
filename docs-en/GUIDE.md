# AegisRun User Guide

> 🇨🇳 [中文版 →](../docs-ch/GUIDE.md)
> Two levels: Beginner — 3 min onboarding | Detailed — library API, CLI, WASI sandbox, web panel

---

## Beginner Level

### 30-Second Quick Start

```cmd
cd D:\moonbit\aegisrun
quickstart.cmd
```

Press `1` for interception, `3` for 7 security scenarios, `0` to exit.

### Quick Troubleshooting

1. **Check MoonBit** — `moon version` → `0.1.20260608+`
2. **Check directory** — `cd D:\moonbit\aegisrun` then `dir quickstart.cmd`
3. **Clear cache** — `rmdir /s /q target`

### Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Invalid path syntax` | PS syntax in CMD | Use `set X=v` in CMD |
| `'set' is not recognized` | CMD syntax in PS | Use `$env:X = "v"` in PS |
| Output stale | Build cache | `rmdir /s /q target` |

### Command Cheatsheet

| Command | Effect |
|---------|--------|
| `quickstart.cmd` | Interactive menu |
| `aegisrun.exe demo` | Policy demo (14 checks) |
| `aegisrun.exe scan malware.py` | Scan script |
| `aegisrun.exe serve` | Web admin panel |
| `cargo run -- sandbox tool.wasm` | WASI sandbox |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `AEGISRUN_POLICY` | Sync policy from web panel |
| `AEGISRUN_DEMO` | Select demo (1-7) |
| `AEGISRUN_ATTACKS` | Select attack types (1-12) |

---

## Detailed Level

### Using as MoonBit Library

```moonbit
fn main {
  let policy = @aegisrun.lib.new_policy_engine()
  match @lib.check_domain(domain_bl, suffixes, "evil.com") {
    Allow => println("safe")
    Deny  => println("BLOCKED!")
  }
}
```

### Using as Rust Library

```rust
use aegisrun_runtime::Policy;
let policy = Policy::standard();
if !policy.check_domain("evil.com") { println!("BLOCKED!"); }
```

### CLI Commands

```cmd
aegisrun.exe demo                  # Policy demo
aegisrun.exe scan malware.py       # Scan script
aegisrun.exe sandbox tool.wasm     # WASI sandbox
aegisrun.exe serve                 # Web panel (port 9090)
aegisrun.exe policy set strict     # Switch preset
```

### WASI Sandbox

```cmd
cd runtime\tools\malware_tool
cargo build --target wasm32-wasip1 --release
aegisrun.exe sandbox tools/malware_tool/target/wasm32-wasip1/release/malware-tool.wasm
```

True physical isolation: zero preopens + filtered env. Not a policy Deny, WASI layer never grants capability.

### MCP Integration

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

5 tools: `sandbox`, `scan`, `check_domain`, `check_path`, `check_env`.
