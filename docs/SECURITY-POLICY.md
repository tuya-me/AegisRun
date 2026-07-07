# AegisRun 安全策略

## 设计思路

AegisRun 不是另一个杀毒软件。它的核心假设是：**AI Agent 调用的第三方工具不可信**。

传统安全工具假设「恶意软件 vs 正常软件」的二分法。AegisRun 面对的是灰色地带——工具本身可能无害，但组合使用会产生风险（读文件 + 发网络请求 = 数据外泄）。所以我们的防御思路是：

1. **声明即约束**：工具必须声明自己要什么能力，未声明 = 不允许
2. **组合检测**：单独无害的能力组合起来可能危险（文件写入 + 网络 = 外泄风险）
3. **纵深防御**：同一操作在 MoonBit 策略层和 Rust 沙箱层各检查一次，任一拒绝即拦截

## 规则数据来源

AegisRun 的内置黑名单整合了多层次的公开威胁情报：

| 类别 | 来源 | 说明 |
|------|------|------|
| C2 服务器 IP | abuse.ch / AlienVault OTX | 已知恶意软件命令控制服务器 |
| 恶意软件分发 | URLhaus / MalwareBazaar | 恶意样本托管 URL |
| 钓鱼域名 | PhishTank / OpenPhish / Cloudflare Radar | 多渠道交叉验证的钓鱼站点 |
| 扫描与扫描器 | GreyNoise / Shodan | 互联网背景噪声 IP，辅助排除误报 |
| Tor 出口节点 | Tor Project 官方列表 | 匿名网络出口节点 |
| 私有网络地址 | RFC 1918 / RFC 6598 | 防止内网横向移动 |
| 链路本地和组播 | RFC 3927 / RFC 5771 | 169.254.x.x / 224.x.x.x |
| 免费域名 TLD | IANA 根区数据库 | `.tk` `.ml` `.ga` `.cf` 等钓鱼高发 TLD |
| 国家代码 TLD | IANA | `*.cn` `*.ru`（按需启用） |
| 已知恶意注册商 | Spamhaus DROP / Proofpoint ET | 恶意注册商 IP 段 |

## 扩展规则

AegisRun 支持三种方式扩充规则：

1. **YAML 预设文件**（`presets/standard.yaml`）——直接用编辑器修改，`domain`、`path`、`env_var` 列表自由增删
2. **`policy.json`** —— Rust 运行时持久化策略，Web 面板修改后自动保存，程序重启自动加载
3. **Web 管理面板**（`cargo run -- serve`）——浏览器操作，一键导出 CLI 命令粘贴到终端同步

### 接入外部威胁情报

AegisRun 不内置联网更新。建议按自己需要从以下渠道定期拉取，写入 `policy.json` 或 YAML preset：

- **企业自有黑名单**：内网扫描发现的恶意 IP/域名，直接追加到 `blocked_domains`
- **行业 ISAC**：金融/医疗/能源等行业威胁情报共享中心，导出 IP/域名列表后批量导入
- **商业威胁情报**：Recorded Future / Mandiant / CrowdStrike 等，导出 STIX/CSV 后脚本转换为 AegisRun 格式
- **自建蜜罐**：捕获的攻击 IP 写入审计日志交叉比对

格式兼容 JSON 和 YAML，字段名与预设文件一致即可。

## 同类参考

AegisRun 的设计参考了以下项目与论文：

- [Chromium Sandbox](https://chromium.googlesource.com/chromium/src/+/main/docs/design/sandbox.md) — Windows 受限令牌 + 完整性级别，启发了我们的 WASI 零权限思路
- [gVisor](https://github.com/google/gvisor) — 用户态内核拦截系统调用，我们的 Rust 沙箱层借鉴了其两层拦截架构
- [OpenAI Evals](https://github.com/openai/evals) — AI Agent 能力评估框架，启发了工具声明的危险组合评分
- Microsoft CFP 2024: _"ToolSandbox: Stateful Execution Monitoring for LLM Agents"_ — 学术上验证了「AI Agent 工具需要状态机级别的安全拦截」
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/) — LLM06（过度代理）和 LLM08（向量和嵌入）启发了我们的工具权限门控

## 问题排查

每个通过 AegisRun 的工具调用都记录在 `aegisrun-audit.jsonl` 中：

```jsonl
{"timestamp":"1712345678","tool_id":"weather-query","action":"execute","decision":"DENY","reason":"evil.com in blacklist"}
```

日志包含时间戳、工具ID、操作、决定（ALLOW/DENY）、拒绝原因。遇到异常拦截或漏拦时：

1. 导出 `aegisrun-audit.jsonl` 中相关工具的日志条目
2. 附上当前策略配置（`moon run src/main show` 或 `policy.json`）
3. 提交到 [GitHub Issues](https://gitlink.org.cn/tuya/AegisRun/issues)，我们基于日志分析拦截链路

版本变更记录见 [CHANGELOG.md](../CHANGELOG.md)。
