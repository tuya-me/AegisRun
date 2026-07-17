# AegisRun 开发者贡献指南

> 🇬🇧 [English version →](../docs-en/CONTRIBUTING.md)
> v0.9.2 | 如何参与开发 | 可贡献方向 | 代码规范

---

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
│   ├── src/server_main.rs   守护进程入口（aegisrund）
│   ├── src/server.rs        Web 面板 + MCP 端点
│   ├── src/sandbox.rs       wasmtime WASI 物理隔离沙箱
│   ├── src/sandbox_monitor.rs  运行时沙箱监控
│   ├── src/persist.rs       审计日志 + 策略持久化 + 热加载
│   └── src/verify.rs        工具签名验证
│
├── src/demo/                MoonBit 演示
├── src/generator/           恶意脚本生成
├── dashboard.html           Web 管理面板
├── docs-ch/                 中文文档
├── docs-en/                 英文文档
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

> **Windows 说明：** `moon test`（wasm/wasm-gc 目标）在旧版 Windows 10 上可能因 WASM 运行时 DLL 兼容性问题失败。可使用 `moon test --target js` 替代——它验证的是相同的 MoonBit 逻辑。

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
| MoonBit 代码 | ~3,600 行 |
| Rust 代码 | ~1,800 行 |
| 架构二重性消除 | 7 / 7 |
| 五层调用链全部通电 | ✅ |
| 测试覆盖 | MoonBit 6 测试 (js target) + Rust 10 (9 单元 + 1 文档) |
| wasmtime WASI | ✅ 物理隔离已验证 |
| 版本 | v0.9.2 |
| 许可证 | Apache 2.0 |
