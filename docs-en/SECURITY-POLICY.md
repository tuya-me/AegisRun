# AegisRun Security Policy


---

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
