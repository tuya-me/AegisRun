# AegisRun Architecture

> v0.8.0 | MoonBit 0.1.20260608

---

## Overview

```
User Code → Sandbox Interception → Blacklist Engine → Allow/Deny
```

AegisRun has two layers: **MoonBit policy decision** (src/lib/) and **Rust execution interception** (runtime/).

### Three-Layer Responsibility

| Layer | File | Responsibility |
|:------|------|---------------|
| Sandbox Interception | `sandbox.mbt` | Tool IO egress, two-gate check |
| Blacklist Engine | `core.mbt` | Rule matching, Allow/Deny |
| Demo/Test | `scenarios.mbt` | Verify correctness |

### Core Functions

**check_domain()** — HashMap exact match → suffix wildcard → IP prefix → Allow/Deny
**check_path()** — HashMap exact match → prefix directories → Allow/Deny
**check_env()** — Explicit pattern match → KEY/SECRET/TOKEN detection → Allow/Deny

### Data Structures

```
PolicyState { preset_name, blacklist_domains/paths/tools, whitelist_domains, sensitive_envs, ... }
SandboxGrant { allowed_domains/paths/env_vars, max_timeout_ms, max_memory_kb, max_file_size_kb }
Sandbox { policy, grant, checked_count, blocked_count }
Decision = Allow | Deny
```

### Performance

| Operation | Complexity |
|-----------|:----------:|
| Domain exact match | O(1) |
| Domain suffix | O(n) n=3 |
| Path exact | O(1) |
| Path prefix | O(m) m=5 |
| Env explicit | O(k) k=4 |
| **Total** | **< 1μs** |
