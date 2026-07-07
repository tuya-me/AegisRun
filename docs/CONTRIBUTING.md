# AegisRun 开发者贡献指南

> v0.6.0 | 如何参与开发 | 可贡献方向 | 代码规范

---

## 一、项目架构

```
aegisrun/
├── src/lib/                 MoonBit 库（策略引擎，别人 moon add 用的）
│   ├── core.mbt               黑名单引擎 + 策略引擎
│   ├── sandbox.mbt            沙箱拦截层（两关检查）
│   ├── scorer.mbt             风险评分引擎
│   ├── sql_guard.mbt          SQL 资源控制
│   ├── limiter.mbt            三维并发限流
│   ├── monitor.mbt            压力监控+熔断
│   ├── dns_guard.mbt          DNS 劫持检测
│   ├── alert.mbt              告警通知
│   └── dashboard.mbt          终端仪表盘
│
├── runtime/                  Rust 库 + CLI（别人 cargo add 用的）
│   ├── src/lib.rs             核心库（Policy + sandbox + scanner）
│   ├── src/main.rs            CLI 工具（aegisrun.exe）
│   ├── src/sandbox.rs         wasmtime WASI 物理隔离沙箱
│   ├── src/server.rs          Web 面板 + MCP 端点
│   └── Cargo.toml             wasmtime 39
│
├── src/demo/                 MoonBit 演示
│   └── intercept.mbt          12 种攻击拦截演示
│
├── src/generator/            恶意脚本生成
│   ├── generator.mbt          12 种攻击可选生成
│   └── malware.py             Python 恶意脚本样本
│
├── dashboard.html            Web 管理面板
├── docs/                      公开文档
└── presets/                  安全预设（YAML）
```

**调用关系**：
```
AI Agent → MCP → AegisRun Server → Policy 引擎 → Allow/Deny
开发者 → cargo add / moon add → src/lib 或 runtime/src/lib.rs
管理员 → aegisrun.exe / dashboard.html → 策略配置
```

---

## 二、可贡献方向

### 低门槛（加规则、改配置）

| 方向 | 做什么 | 改哪 |
|------|------|------|
| 添加域名黑名单 | `state.blacklist_domains.set("xxx.com","reason")` | `core.mbt` |
| 添加敏感路径 | 在 `default_blacklist_paths()` 加路径 | `core.mbt` |
| 添加环境变量模式 | 在 `default_blacklist_envs()` 加模式 | `core.mbt` |
| 添加 IP 黑名单段 | `bl.cidr_prefixes.push(...)` | `dns_guard.mbt` |
| 扩展风险评分扣分项 | 在 `score_manifest` 加检查维度 | `scorer.mbt` |
| 添加 SQL 拦截规则 | 在 `guard_query` 加关键词 | `sql_guard.mbt` |

### 中门槛（加功能）

| 方向 | 做什么 | 难度 |
|------|------|:--:|
| 策略持久化 | 程序退出前写 `policy.yaml`，启动时读取 | 中 |
| 审计日志写盘 | 改 `println` 为 `fs.write` JSONL 文件 | 低 |
| 命令行自动补全 | 生成 bash/pwsh completion | 低 |
| Web 仪表盘实时刷新 | `dashboard.html` 加定时轮询 `/api/stats` | 中 |
| 限流增加"按用户"维度 | `acquire` 函数加 user_id 参数 | 中 |

### 高门槛（架构级）

| 方向 | 做什么 | 难度 |
|------|------|:--:|
| wasmtime WASI 宿主函数 | 在 Rust runtime 实现 `path_open`/`sock_send` 的 wasmtime 拦截 | 高 |
| MoonBit→Rust FFI | MoonBit 编译 native → Rust 通过 FFI 调用 | 高 |
| 分布式策略同步 | 多实例共享 policy，通过 Redis/MQ 同步 | 高 |
| 工具签名验证 | 加载 .wasm 前验证 Ed25519 签名 | 中 |
| 攻击回放 CI | 自动生成恶意工具 → 沙箱运行 → 验证拦截 → CI 报告 | 中 |

---

## 三、开发流程

### Rust 侧

```bash
cd runtime
# 修改 lib.rs 或 main.rs
cargo build          # 编译（含库 + CLI）
cargo test           # 测试
cargo run -- demo    # 运行 demo
```

### MoonBit 侧

```bash
# 修改 src/lib/*.mbt 或 src/demo/*.mbt
moon build           # 编译
moon run src/demo/intercept.mbt  # 运行 demo
```

### 提交流程

```bash
git checkout -b feature/xxx
# 写代码
git add -A
git commit -m "feat: description"
git push origin feature/xxx
# GitLink 创建 PR → merge
```

---

## 四、可贡献方向

| 优先级 | 方向 | 状态 |
|:--:|------|:--:|
| 高 | MoonBit→Rust FFI（编译 native + C ABI） | 待完成 |
| 中 | 多工具资源配额（CPU/Mem/Net 硬限制） | 规划中 |
| 中 | 攻击回放 CI 框架 | 规划中 |
| 低 | 分布式策略同步 | 规划中 |

---

## 五、代码规范

**MoonBit**：`snake_case` 函数/变量，`PascalCase` struct/enum，公开函数加中文注释。
**Rust**：标准 `rustfmt`，`snake_case`，`anyhow::Result` 错误处理，公开函数加 `///` 文档注释。

## 六、当前项目状态

| 指标 | 数值 |
|------|------|
| MoonBit 核心模块 | 9 个 |
| MoonBit 代码 | ~1,250 行 |
| Rust 代码 | ~500 行 |
| 测试覆盖 | 63 项端到端 |
| 版本 | v0.4.1 |
| wasmtime WASI | ✅ 物理隔离已验证 |
| 许可证 | Apache 2.0 |
