# AegisRun Architecture

> v0.9.3 | MoonBit 0.1.20260608
> 🇨🇳 [中文版 →](../docs-ch/ARCHITECTURE.md)

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

### ToolRegistry (Tool Registry)

```
ToolRegistry {
  tools: HashMap<String, ToolMeta>     // tool_id → metadata
  trusted_publishers: Vec<String>      // trusted publisher list
  persist_path: String                 // JSON persistence path
}

ToolMeta {
  tool_id: String                      // unique tool identifier
  description: String                  // tool description
  version: String                      // semantic version
  publisher: String                    // publisher (e.g. @aegisrun)
  sha256: String                       // WASM file SHA256 hash
  tags: Vec<String>                    // tag list (e.g. ["net", "security"])
  registered_at: String                // registration timestamp
}
```

**Capabilities:**

| Method | Description | Complexity |
|--------|-------------|:----------:|
| `register(meta)` | Register a tool (verifies publisher) | O(1) |
| `register_from_wasm(...)` | Auto-compute hash from WASM file and register | O(n) n=file size |
| `unregister(tool_id)` | Unregister a tool | O(1) |
| `list_tools()` | List all tools (sorted by ID) | O(k log k) |
| `get_tool(tool_id)` | Lookup by ID | O(1) |
| `search(keyword)` | Keyword search (ID/description/tags/publisher) | O(k) |
| `search_by_tags(tags)` | Tag search (any match) | O(k·t) |
| `all_tags()` | Get all used tags | O(k·t) |
| `verify_tool(path, id, pub)` | Full verification (publisher + hash + registration) | O(n) |
| `save() / load()` | JSON persistence | O(k) |

**Security Model:** Registration requires publisher trust check (default trusted: `@moonbit-official` and `@aegisrun`). `verify_tool()` performs triple verification: publisher trust → tool registered → WASM file hash match.

### Performance

| Operation | Complexity |
|-----------|:----------:|
| Domain exact match | O(1) |
| Domain suffix | O(n) n=3 |
| Path exact | O(1) |
| Path prefix | O(m) m=5 |
| Env explicit | O(k) k=4 |
| **Total** | **< 1μs** |
