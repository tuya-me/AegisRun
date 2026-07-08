# AegisRun Contribution Guide / 开发者贡献指南

> v0.8.0 | How to contribute / 如何参与开发 | Code style / 代码规范

<style>
.en { display: none; }
.zh { display: block; }
#en:target { display: block; }
#en:target ~ .zh { display: none; }
.lang-bar { text-align: center; margin: 16px 0; }
.lang-btn { display: inline-block; padding: 6px 20px; background: #f0f0f0; border-radius: 20px; text-decoration: none; color: #333; font-size: 14px; margin: 0 4px; }
.lang-btn:hover { background: #e0e0e0; }
</style>

<div class="lang-bar">
<a href="#en" class="lang-btn">🇬🇧 English</a>
<a href="#zh-cn" class="lang-btn">🇨🇳 中文</a>
</div>

---

<div id="en" class="en">

## Project Architecture

```
aegisrun/
├── src/lib/                 MoonBit Library (policy engine)
│   ├── core.mbt             Blacklist engine + policy engine
│   ├── sandbox.mbt          Sandbox interception layer
│   ├── scorer.mbt           Risk scoring engine
│   ├── sql_guard.mbt        SQL resource control
│   ├── limiter.mbt          3D concurrency throttling
│   ├── monitor.mbt          Pressure monitoring + circuit breaker
│   ├── dns_guard.mbt        DNS hijacking detection
│   ├── alert.mbt            Alert notifications
│   └── dashboard.mbt        Terminal dashboard
│
├── runtime/                 Rust Library + CLI
│   ├── src/lib.rs           Core library (Policy + sandbox + scanner)
│   ├── src/main.rs          CLI tool (aegisrun.exe)
│   ├── src/sandbox.rs       wasmtime WASI physical sandbox
│   ├── src/server.rs        Web dashboard + MCP endpoint
│   ├── src/persist.rs       Audit log + policy persistence + hot reload
│   └── src/verify.rs        Tool signature verification
│
├── src/demo/                MoonBit demos
├── src/generator/           Malicious script generator
├── dashboard.html           Web admin panel
├── docs/                    All documentation (bilingual)
└── presets/                 Security presets (YAML)
```

**Call relationships:**
```
AI Agent → MCP → AegisRun Server → Policy Engine → Allow/Deny
Developer → cargo add / moon add → src/lib or runtime/src/lib.rs
Admin → aegisrun.exe / dashboard.html → policy config
```

## Contribution Directions

### Low Barrier (Add rules, config changes)

| Direction | What to do | Where |
|-----------|-----------|-------|
| Add domain blacklist | `state.blacklist_domains.set("xxx.com","reason")` | `core.mbt` |
| Add sensitive path | Add to `default_blacklist_paths()` | `core.mbt` |
| Add env var pattern | Add to `default_blacklist_envs()` | `core.mbt` |
| Add IP blacklist range | `bl.cidr_prefixes.push(...)` | `dns_guard.mbt` |
| Extend risk scoring | Add check dimension in `score_manifest` | `scorer.mbt` |
| Add SQL interception rule | Add keyword in `guard_query` | `sql_guard.mbt` |

### Medium Barrier (Add features)

| Direction | What to do | Difficulty |
|-----------|-----------|:----------:|
| CLI auto-completion | Generate bash/pwsh completion | Low |
| Dashboard real-time refresh | Add polling `/api/stats` | Medium |
| Per-user rate limiting | Add `user_id` param to `acquire()` | Medium |

### High Barrier (Architecture-level)

| Direction | What to do | Difficulty |
|-----------|-----------|:----------:|
| wasmtime WASI host functions | Implement `path_open`/`sock_send` interception | High |
| MoonBit→Rust FFI | Compile MoonBit native → call from Rust | High |
| Distributed policy sync | Multi-instance via Redis/MQ | High |
| Tool signature verification | Ed25519 sig before loading .wasm | Medium ✅ |
| Attack replay CI | Auto-generate → sandbox → verify | Medium |

## Priority Roadmap

| Priority | Direction | Status |
|:--------:|-----------|:------:|
| High | MoonBit→Rust FFI (compile native + C ABI) | Pending |
| Medium | Multi-tool resource quotas (CPU/Mem/Net) | Planned |
| Medium | Attack replay CI framework | Planned |
| Low | Distributed policy sync | Planned |

## Development Workflow

**Rust side:**
```bash
cd runtime
cargo build          # Compile (lib + CLI)
cargo test           # Run tests
cargo run -- demo    # Run demo
cargo clippy         # Lint check
```

**MoonBit side:**
```bash
moon build           # Compile
moon check           # Type check
moon fmt --check     # Format check
moon run src/demo/intercept.mbt  # Run demo
moon test            # Run tests
```

**Commit workflow:**
```bash
git checkout -b feature/xxx
git add -A
git commit -m "feat: description"
git push origin feature/xxx
# Create PR on GitLink
```

## Code Style

**MoonBit:** `snake_case` for functions/variables, `PascalCase` for structs/enums. Public functions must have Chinese comments.

**Rust:** Standard `rustfmt`, `snake_case`, `anyhow::Result` for errors, `///` doc comments for public functions.

**Commits:** Use English labels. Follow conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`.

## Project Status

| Metric | Value |
|--------|-------|
| MoonBit core modules | 9 |
| MoonBit code | ~3,580 lines |
| Rust code | ~1,073 lines |
| Architecture dualities eliminated | 7 / 7 |
| Call chain fully powered | ✅ |
| Test coverage | MoonBit 6 tests + Rust 14 cases |
| wasmtime WASI | ✅ Physical isolation verified |
| Version | v0.8.0 |
| License | Apache 2.0 |

</div>

<div class="zh">

## 项目架构

```
aegisrun/
├── src/lib/                 MoonBit 库（策略引擎）
│   ├── core.mbt             黑名单引擎 + 策略引擎
│   ├── sandbox.mbt          沙箱拦截层
│   ├── scorer.mbt           风险评分引擎
│   ├── sql_guard.mbt        SQL 资源控制
│   ├── limiter.mbt          三维并发限流
│   ├── monitor.mbt          压力监控 + 熔断
│   ├── dns_guard.mbt        DNS 劫持检测
│   ├── alert.mbt            告警通知
│   └── dashboard.mbt        终端仪表盘
│
├── runtime/                 Rust 库 + CLI
│   ├── src/lib.rs           核心库（Policy + sandbox + scanner）
│   ├── src/main.rs          CLI 工具（aegisrun.exe）
│   ├── src/sandbox.rs       wasmtime WASI 物理隔离沙箱
│   ├── src/server.rs        Web 面板 + MCP 端点
│   ├── src/persist.rs       审计日志 + 策略持久化 + 热加载
│   └── src/verify.rs        工具签名验证
│
├── src/demo/                MoonBit 演示
├── src/generator/           恶意脚本生成
├── dashboard.html           Web 管理面板
├── docs/                    全部文档（中英双语）
└── presets/                 安全预设（YAML）
```

**调用关系：**
```
AI Agent → MCP → AegisRun Server → 策略引擎 → Allow/Deny
开发者 → cargo add / moon add → src/lib 或 runtime/src/lib.rs
管理员 → aegisrun.exe / dashboard.html → 策略配置
```

## 可贡献方向

### 低门槛（加规则、改配置）

| 方向 | 做什么 | 改哪 |
|------|--------|------|
| 添加域名黑名单 | `state.blacklist_domains.set("xxx.com","reason")` | `core.mbt` |
| 添加敏感路径 | 在 `default_blacklist_paths()` 加路径 | `core.mbt` |
| 添加环境变量模式 | 在 `default_blacklist_envs()` 加模式 | `core.mbt` |
| 添加 IP 黑名单段 | `bl.cidr_prefixes.push(...)` | `dns_guard.mbt` |
| 扩展风险评分 | 在 `score_manifest` 加检查维度 | `scorer.mbt` |
| 添加 SQL 拦截规则 | 在 `guard_query` 加关键词 | `sql_guard.mbt` |

### 中门槛（加功能）

| 方向 | 做什么 | 难度 |
|------|--------|:----:|
| 命令行自动补全 | 生成 bash/pwsh completion | 低 |
| 仪表盘实时刷新 | 加定时轮询 `/api/stats` | 中 |
| 限流增加"按用户"维度 | `acquire` 加 user_id 参数 | 中 |

### 高门槛（架构级）

| 方向 | 做什么 | 难度 |
|------|--------|:----:|
| wasmtime WASI 宿主函数 | 实现 `path_open`/`sock_send` 拦截 | 高 |
| MoonBit→Rust FFI | MoonBit 编译 native → Rust FFI 调用 | 高 |
| 分布式策略同步 | 多实例通过 Redis/MQ 共享策略 | 高 |
| 工具签名验证 | 加载 .wasm 前验证 Ed25519 签名 | 中 ✅ |
| 攻击回放 CI | 自动生成 → 沙箱运行 → 验证拦截 | 中 |

## 优先级路线

| 优先级 | 方向 | 状态 |
|:------:|------|:----:|
| 高 | MoonBit→Rust FFI（编译 native + C ABI） | 待完成 |
| 中 | 多工具资源配额（CPU/Mem/Net 硬限制） | 规划中 |
| 中 | 攻击回放 CI 框架 | 规划中 |
| 低 | 分布式策略同步 | 规划中 |

## 开发流程

**Rust 侧：**
```bash
cd runtime
cargo build          # 编译（含库 + CLI）
cargo test           # 测试
cargo run -- demo    # 运行 demo
cargo clippy         # 代码检查
```

**MoonBit 侧：**
```bash
moon build           # 编译
moon check           # 类型检查
moon fmt --check     # 格式检查
moon run src/demo/intercept.mbt  # 运行演示
moon test            # 测试
```

**提交流程：**
```bash
git checkout -b feature/xxx
git add -A
git commit -m "feat: description"
git push origin feature/xxx
# GitLink 创建 PR
```

## 代码规范

**MoonBit：** `snake_case` 函数/变量，`PascalCase` struct/enum，公开函数加中文注释。

**Rust：** 标准 `rustfmt`，`snake_case`，`anyhow::Result` 错误处理，公开函数加 `///` 文档注释。

**提交：** 标签用英文。遵循 conventional commits：`feat:`、`fix:`、`docs:`、`refactor:`、`test:`。

## 项目状态

| 指标 | 数值 |
|------|------|
| MoonBit 核心模块 | 9 |
| MoonBit 代码 | ~3,580 行 |
| Rust 代码 | ~1,073 行 |
| 架构二重性消除 | 7 / 7 |
| 五层调用链全部通电 | ✅ |
| 测试覆盖 | MoonBit 6 测试 + Rust 14 用例 |
| wasmtime WASI | ✅ 物理隔离已验证 |
| 版本 | v0.8.0 |
| 许可证 | Apache 2.0 |

</div>
