# AegisRun 路线图（Roadmap）

> v0.2.0 → v2.0.0

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

## v0.4.0 Unified ← 当前版本（OSC2026 提交）

- [x] Rust 库/CLI 分离（`cargo add` + `aegisrun.exe`）
- [x] MCP Server 端点（`/mcp`，5个工具，Claude Desktop 兼容）
- [x] Web 管理面板（`serve` 内嵌 + `dashboard.html`）
- [x] 通用脚本扫描器（Python/JS 自动提取威胁）
- [x] OS 级沙箱拦截（文件/环境变量读前检查）
- [x] 统一 Demo（2个：intercept + generator）
- [x] 使用指南（`docs/使用指南.md`）

---

## v0.2.0 Full

**新增 ~600 行 MoonBit · 4 个新模块**

- [x] **v1.1 风险评分引擎** [`scorer.mbt`] — 静态声明分析，0-100 打分，四级判定（Safe/Warning/Dangerous/Critical），组合危险检测
- [x] **v1.2 SQL 资源控制** [`sql_guard.mbt`] — 表级授权、列名限制、行数上限、DROP/ALTER/TRUNCATE 拦截、DELETE 无 WHERE 拦截
- [x] **v1.3 三维并发限流** [`limiter.mbt`] — 全局/单工具/单 Session 上限，槽位获取/释放/排队/拒绝
- [x] **v1.4 压力监控+熔断** [`monitor.mbt`] — CPU/内存实时采集，四级响应（Normal→Warning→Degraded→Critical），熔断器自动开关
- [x] **Full 集成演示** [`full_demo.mbt`] — 13 项端到端测试，覆盖上述所有模块
- [x] 架构文档 [`docs/ARCHITECTURE.md`] — 完整调用链 + 数据结构
- [x] 文档规范 [`docs/DOCUMENTATION-GUIDE.md`]
- [x] 安全策略白皮书（本地讨论中，完成后推送）

---

## v0.3.0 — 生产加固（计划中）

*预计：+5 天 · ~500 行*

- [ ] MCP Server 完整实现（`tools/list` + `tools/call` over stdio）
- [ ] 策略持久化（`policy.yaml` 读写，程序退出不丢失状态）
- [ ] 命令行参数完整支持（替换环境变量路由）
- [ ] 审计日志文件写入（替换当前 println 输出）
- [ ] 风险评分数据驱动校准
- [ ] sandbox 层接入真实 wasm5 FFI
- [ ] 数据库兼容性扩展（MySQL / PostgreSQL）

---

## v0.4.0 — 可视化与体验（计划中）

*预计：+5 天 · ~400 行*

- [ ] 终端仪表盘（CPU/内存/槽位/拦截日志实时刷新）
- [ ] 审计日志彩色输出（simple 模式 + verbose 模式）
- [ ] 交互式 Shell（`aegisrun` 进入后持续交互，不退出）
- [ ] 队列时间预估（限流被拒时告知预计等待时间）
- [ ] DNS 劫持检测（域名检查 + IP 黑名单 + 历史比对）

---

## v1.0.0 — 正式发布（计划中）

*预计：+7 天 · ~600 行*

- [ ] mooncakes.io 发布（`moon add tuya/aegisrun`）
- [ ] WIT 接口标准化（工具合约跨平台复用）
- [ ] wasmoon JIT 运行时集成（高性能模式）
- [ ] Web 管理面板（策略可视化编辑 + 实时监控）
- [ ] 威胁情报接入（AlienVault OTX / Abuse.ch URLhaus）
- [ ] 分级告警通知（日志/邮件/短信/Webhook）

---

## 时间线

```
Jun 22  ─── v0.1.0 Lite（黑名单引擎 + 沙箱层）
Jun 22  ─── v0.2.0 Full（评分 + SQL + 限流 + 监控）  ← 当前版本
Jul 05  ─── v0.3.0（MCP + 持久化 + wasm5 FFI）
Jul 15  ─── v0.4.0（可视化 + 交互 Shell + DNS 检测）
Aug 01  ─── v1.0.0（mooncakes 发布 + Web 面板）
```

---

## 合并建议

当前两个分支：

| 分支 | 状态 | 内容 |
|------|:--:|------|
| `master` | v0.1.0 稳定版 | 黑名单引擎 + 沙箱层 |
| `v0.2.0-split` | v0.2.0 开发完成 | +风险评分 +SQL控制 +限流 +监控 |

**合并命令**：

```bash
git checkout master
git merge v0.2.0-split
git push origin master
```
