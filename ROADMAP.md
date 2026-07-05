# AegisRun 路线图（Roadmap）

> v0.6.0 当前版本 | 更新于 2026-07-05

---

## v0.1.0 Lite ✅ 已完成

**~1,200 行 MoonBit · 12 天开发**

- [x] 黑名单引擎（HashMap O(1) 域名/路径/工具匹配）
- [x] 沙箱拦截层（网络/文件/环境变量/资源拦截器，两关检查）
- [x] 白名单通道（工具 ID + 作者级别）
- [x] 三种安全预设（`strict` / `standard` / `permissive`）
- [x] CLI 命令（`preset` / `allow` / `deny` / `show` / `demo`）
- [x] 审计日志（异步批量写入 JSONL）
- [x] 工具注册表（注册/发现/卸载）
- [x] 7 个交互式安全演示
- [x] 5 个伪装恶意工具
- [x] 14 项恶意工具扫描测试
- [x] 22 项沙箱拦截测试

---

## v0.6.0 当前 ← 最新版本

- [x] Rust CI 补全（cargo build + clippy + test）
- [x] 真 SHA256 签名验证（sha2 crate）
- [x] Rust/MoonBit/YAML 三方策略对齐（30+ 规则统一）
- [x] `check_path()` bug 修复（contains→starts_with）
- [x] MCP 策略丢失修复
- [x] wasmtime 资源限制（30s 超时 + 256MB 内存）
- [x] AuditLogger append-only 写盘
- [x] PolicyWatcher 从死代码激活
- [x] CORS preflight + Dashboard 多项修复
- [x] IP 前缀迭代 + export_policy 实现
- [x] 自动化测试（Rust 14 用例 + MoonBit 6 函数）
- [x] 版本号全局统一 + 文档更新

## v0.5.0 ✅

- [x] 统一门面一行 API（`AegisRun::new("standard").check_domain("evil.com")`）
- [x] 审计日志 JSONL 持久化（50条批量刷盘）
- [x] 策略持久化 + 热加载（policy.json 保存/加载/文件监控）
- [x] Web 仪表盘实时刷新（每2秒 fetchStats）
- [x] 工具签名验证（SHA256 + 发布者注册表）
- [x] 安全策略补强（env 8→30+，path 8→30+，IP 15→20+）
- [x] CI 工作流完善（moon check + moon fmt + cargo clippy 0 警告）
- [x] 文档全面更新（使用指南、开发者指南、路线图、更新日志）

## v0.4.1 WASI ✅

wasmtime 39 WASI 物理隔离——恶意 .wasm 工具 27/27 拦截。

## v0.4.0 Unified ✅

统一 CLI + MCP Server（5工具）+ Web 面板 + Rust 库/CLI 分离。

## v0.1.0~v0.3.0 ✅

黑名单引擎 → 风险评分+SQL控制+限流+监控 → Rust 运行时+DNS 防护。

## 下一版本（计划）

- [ ] mooncakes.io 发布（`moon add aegisrun`）
- [ ] MoonBit→Rust FFI（编译 native + C ABI 互调）
- [ ] 攻击回放 CI 框架
