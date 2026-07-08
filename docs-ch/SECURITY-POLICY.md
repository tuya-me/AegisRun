# AegisRun 安全策略

---

## 设计思路

AegisRun 不是另一个杀毒软件。它的核心假设是：**AI Agent 调用的第三方工具不可信**。

传统安全工具假设「恶意软件 vs 正常软件」的二分法。AegisRun 面对的是灰色地带——工具本身可能无害，但组合使用会产生风险（读文件 + 发网络请求 = 数据外泄）。防御思路：

1. **声明即约束**：工具必须声明自己要什么能力，未声明 = 不允许
2. **组合检测**：单独无害的能力组合起来可能危险（文件写入 + 网络 = 外泄风险）
3. **纵深防御**：同一操作在 MoonBit 策略层和 Rust 沙箱层各检查一次

## 策略文件

所有默认规则集中在一个文件里维护：

```
src/lib/core.mbt  ← 唯一维护点（v0.8.0 合并至此）
  ├─ default_domain_blacklist()   → 7 条恶意域名
  ├─ default_domain_suffixes()    → 3 条后缀 TLD
  ├─ default_ip_prefixes()        → 3 条内网 IP 段
  ├─ default_domain_whitelist()   → 2 条可信域名
  ├─ default_sensitive_paths()    → 22 条敏感路径
  ├─ default_env_patterns()       → 36 条环境变量模式
  ├─ env_keywords()               → 5 个关键词
  ├─ default_timeout_ms()         → 30000
  └─ default_memory_kb()          → 262144
```

### 策略在每层拦截中的调用链

| 拦截层 | 入口文件 | 策略来源 | 策略函数 |
|--------|----------|----------|----------|
| 1. 安装审查 | `scorer.mbt:36` | 内置评分规则 | `score_manifest()` |
| 2. 域名/IP | `core.mbt` ← `sandbox.mbt:78` | `core.mbt` 默认规则 | `check_domain()` |
| 3. 路径 | `core.mbt` ← `sandbox.mbt` + `lib.rs:83` | `core.mbt` 默认规则 | `check_path()` |
| 3. 环境变量 | `core.mbt` ← `lib.rs:91` | `core.mbt` 默认规则 | `check_env()` |
| 4. 工具黑名单 | `core.mbt:141` ← `aegisrun.mbt:192` | 运行时动态添加 | `check_tool_id()` |
| 5. WASI 沙箱 | `sandbox.rs`（Rust）| 不依赖策略文件 | wasmtime 零目录预打开 |

## 规则数据来源

| 类别 | 来源 | 说明 |
|------|------|------|
| C2 服务器 IP | abuse.ch / AlienVault OTX | 已知恶意软件 C2 |
| 恶意软件分发 | URLhaus / MalwareBazaar | 恶意样本托管 URL |
| 钓鱼域名 | PhishTank / OpenPhish / Cloudflare Radar | 交叉验证的钓鱼站点 |
| Tor 出口节点 | Tor Project | 匿名网络出口节点 |
| 私有网络地址 | RFC 1918 / RFC 6598 | 防止内网横向移动 |
| 免费域名 TLD | IANA | `.tk` `.ml` `.ga` `.cf` 等 |
| 国家代码 TLD | IANA | `*.cn` `*.ru`（按需启用）|

## 扩展规则

三种方式扩充规则：

1. **YAML 预设文件**（`presets/standard.yaml`）——编辑器修改，`domain`、`path`、`env_var` 列表自由增删
2. **`policy.json`** —— Rust 运行时持久化策略，Web 面板修改后自动保存
3. **Web 管理面板**（`cargo run -- serve`）——浏览器操作，一键导出 CLI 命令

### 接入外部威胁情报

从以下渠道定期拉取，写入 `policy.json` 或 YAML preset：

- **企业自有黑名单**：内网发现的恶意 IP/域名，追加到 `blocked_domains`
- **行业 ISAC**：金融/医疗/能源等行业威胁情报共享中心
- **商业威胁情报**：Recorded Future / Mandiant / CrowdStrike
- **自建蜜罐**：捕获的攻击 IP 写入审计日志交叉比对

## 同类参考

- [Chromium Sandbox](https://chromium.googlesource.com/chromium/src/+/main/docs/design/sandbox.md)
- [gVisor](https://github.com/google/gvisor)
- [OpenAI Evals](https://github.com/openai/evals)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)

## 审计与排查

每个工具调用记录在 `aegisrun-audit.jsonl` 中：

```jsonl
{"timestamp":"1712345678","tool_id":"weather-query","action":"execute","decision":"DENY","reason":"evil.com in blacklist"}
```

排查步骤：

```bash
grep "weather-query" aegisrun-audit.jsonl     # 1. 导出日志
moon run src/main show                          # 2. 查看当前策略
type policy.json                                 # 或查 policy.json
```
