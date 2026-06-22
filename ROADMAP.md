# AegisRun Roadmap

> Lite v0.1.0 → Full v2.0.0

---

## v0.1.0 Lite ← CURRENT (OSC2026 Submission)

**~1,200 lines MoonBit · 12 day build**

- [x] MCP Server (stdio transport, `tools/list`, `tools/call`)
- [x] Wasm sandbox (wasm5 interpreter binding)
- [x] Blacklist engine (HashMap-accelerated domain/path/tool matching)
- [x] Whitelist bypass (tool ID + author level)
- [x] Network interceptor (domain exact + suffix matching)
- [x] Filesystem interceptor (path whitelist + permission check)
- [x] Environment variable blocker (KEY/SECRET/TOKEN pattern detection)
- [x] Three security presets (`strict` / `standard` / `permissive`)
- [x] CLI commands (`allow`, `deny`, `preset`, `show`, `audit`, `run`)
- [x] Policy hot-reload (change `policy.yaml` without restart)
- [x] Audit logging (async batch-write JSONL)
- [x] Tool registry (register, find, list, unregister)
- [x] 3 demo tools (calculator, weather, file-reader)
- [x] 10 security attack simulation tests
- [x] Integration tests (MCP end-to-end)

---

## v1.1 — Risk Scoring Engine

*Estimated: +3 days · ~300 lines*

- [ ] Static manifest analysis on install
- [ ] Risk score 0-100 based on declared capabilities
- [ ] Pattern detection: wildcard domains, root paths, network+write combos
- [ ] Color-coded warnings (🟢 90+ / 🟡 60-89 / 🟠 30-59 / 🔴 <30)
- [ ] Auto-reject below threshold
- [ ] "I know the risk" override for 🟠 level

---

## v1.2 — SQL Resource Control

*Estimated: +3 days · ~400 lines*

- [ ] SQL connection alias (tool never sees real connection string)
- [ ] Table-level permissions (SELECT / INSERT / UPDATE / DELETE per table)
- [ ] Column-level filtering (auto-trim unauthorized columns from results)
- [ ] Row limit enforcement (max_rows per query)
- [ ] WHERE clause requirement (prevent accidental full-table DELETE)
- [ ] Forbidden operations (DROP, ALTER, TRUNCATE auto-blocked)
- [ ] SQL audit logging (query text + row count + duration)

---

## v1.3 — Concurrency Control

*Estimated: +2 days · ~250 lines*

- [ ] Three-dimensional rate limiter:
  - Global max concurrent calls
  - Per-tool max concurrent instances
  - Per-session max concurrent calls
- [ ] Fair queuing (FIFO with priority lanes)
- [ ] Queue size limit + overflow rejection
- [ ] Queue timeout (drop stale requests)
- [ ] Per-tool concurrency presets (lightweight tools get more slots)

---

## v1.4 — Pressure Monitoring + Circuit Breaker

*Estimated: +3 days · ~350 lines*

- [ ] Real-time metrics collection:
  - CPU usage, memory usage, Wasm instance count
  - Queue depth, average response time
  - Denial rate per minute
- [ ] Four-level response:
  - 🟢 Normal (resource < 70%)
  - 🟡 Warning (70-85%) → webhook notification
  - 🟠 Degraded (85-95%) → reject new calls, drain queue
  - 🔴 Circuit open (>95%) → kill non-critical tools, clear queue
- [ ] Auto-recovery when resource drops below threshold
- [ ] Webhook/email alert integration

---

## v2.0 Full — Production Release

*Estimated: +5 days · ~500 lines*

- [ ] Web admin panel (visual policy editor, real-time metrics dashboard)
- [ ] SSE transport (browser-based agent support)
- [ ] mooncakes.io SDK publishing (`moon add aegisrun-sdk`)
- [ ] WIT interface standardization (tool contract for cross-platform)
- [ ] wasmoon JIT runtime integration (high-performance mode)
- [ ] Extism PDK compatibility (run Extism plugins)
- [ ] Multi-tenant session isolation
- [ ] Policy import/export (share and version control policies)

---

## Timeline

```
Jun 22  ─── v0.1 Lite (OSC2026 submission)        ← CURRENT
Jul 01  ─── v1.1 Risk Scoring
Jul 04  ─── v1.2 SQL Resource Control
Jul 06  ─── v1.3 Concurrency Control
Jul 09  ─── v1.4 Pressure Monitoring + Circuit Breaker
Jul 14  ─── v2.0 Full Release
```
