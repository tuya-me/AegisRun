# AegisRun 安全策略白皮书

> v0.2.0 | 2026-06-22 | 待讨论稿

---

## 1. 风险评分引擎——参考数据来源

**当前评分规则的数据来源**：

| 扣分项 | 扣分 | 判断逻辑 | 依据来源 |
|------|:--:|------|------|
| 域名含 `*` 通配符 | -30 | `"*"` 或 `"*.example.com"` | OWASP Top 10: 过度权限 |
| 文件路径为 `/` 或 `C:\` 根 | -30 | 路径 == `"/"` | CWE-22: 路径遍历 |
| 同时申请网络 + 文件写入 | -20 | has_write && domains.len>0 | MITRE ATT&CK T1041: 数据外泄 |
| 环境变量含 KEY/SECRET/TOKEN | -20 | 字符串包含匹配 | CIS Benchmark: 凭证保护 |
| 新作者首次发布 | -10 | `author_is_new == true` | NPM 供应链攻击案例 |
| 超时 > 120s | -10 | > 120000ms | 资源耗尽 DoS |
| 内存 > 1GB | -10 | > 1048576KB | 宿主机资源保护 |

**问题：这些扣分数值和阈值是怎么定的？**

实话实说——当前是**人工经验值**，不是数据驱动。扣分 10/15/20/30 的分档来自于常见攻击模式的危害等级判断，但没有经过大规模工具样本的统计验证。

**改进方向**：
- 爬取 mooncakes.io 上已有的包，提取声明字段，建立正常分布基线
- 用异常检测替代固定阈值（如：声明了 `*.com` 比 99% 的同类工具宽泛 → 扣分）
- 引入社区信誉：作者历史发布数、被举报次数、wasm 哈希是否被其他用户信任

---

## 2. SQL 资源控制——实现方式与适用范围

### 实现原理

`sql_guard.mbt` 是**语法层拦截器**，不是数据库驱动层。它对 SQL 字符串做词法分析（转大写、查关键词、截表名），然后对照 `SqlTableRule` 做判定。

```
用户 SQL 字符串 → to_upper() → 查 DROP/ALTER/TRUNCATE 关键词
                            → 提取表名（FROM / INTO）
                            → 查表规则（权限/列/WHERE/行数）
                            → Allow / Err
```

**它没有做的事**：
- 不解析完整 AST（不是 SQL parser）
- 不连接真实数据库执行查询
- 不校验列名是否真实存在于表中
- 不进行 SQL 注入检测

### 适用范围分析

| 数据库 | 当前可用 | 限制 |
|------|:--:|------|
| **SQLite** | ✅ 可用 | DML 语法兼容 |
| **MySQL** | ⚠️ 部分 | DROP/ALTER/INSERT/SELECT/DELETE/UPDATE 兼容，但 `LIMIT` 语法不同 |
| **PostgreSQL** | ⚠️ 部分 | 基础 DML 兼容，`RETURNING` 子句 / `COPY` 命令未覆盖 |
| **Oracle** | ❌ 不适用 | PL/SQL 语法完全不同，`MERGE` / `CONNECT BY` 未覆盖 |
| **MongoDB** | ❌ 不适用 | NoSQL，不是 SQL 语法，完全不同的查询语言 |

**结论**：当前仅适用于 SQLite 和基础 MySQL/PostgreSQL DML 语句。生产化需要：
- 集成真正的 SQL parser（如 sqlparser-rs 的 MoonBit 移植）
- MongoDB 需要单独的 BSON 查询拦截器
- Oracle 需要 PL/SQL 词法分析

### 安全策略粒度问题

你提的问题非常关键："最开始管理表是可以不让访问的，其他的表用于安全策略会不会太宽泛？"

**当前设计：白名单模式**。未在 `tables` 数组中注册的表 → 自动拒绝。

```moonbit
let db = @lib.new_sql_connection("reports_db", "/data/reports.db")

// 只授权了 orders 表 → 其他所有表均不可访问
db.add_table(make_sql_rule("orders", ["SELECT"], ["id","amount"], 100, false, ["DROP"]))

// 访问 users 表 → Err("BLOCKED: table 'USERS' not granted")
db.guard_query("SELECT * FROM users")
```

这个设计就是"最小权限原则"——只开放你明确授权的表。但当前实现有个问题：**表规则是全局的，没有按工具/Session 区分**。理想设计：

```moonbit
// 改进方向：工具级别的 SQL 授权
grant_sql_for_tool("weather-query", {
  tables: ["reports_db.orders"],   // 只能查这张表
  max_queries_per_minute: 10,      // 每分钟最多 10 次查询
  forbidden_keywords: ["DROP", "ALTER"],
})
```

---

## 3. 三维限流——界定与用户可见性

### 三个维度

```
┌─────────────────────────────────────────────┐
│  维度 1: max_total = 100                     │
│  全局总槽位，所有工具共享                      │
│  超过 → 排队或拒绝                             │
├─────────────────────────────────────────────┤
│  维度 2: max_per_tool (可自定义)              │
│  weather-query=20, image-processor=3         │
│  防止某个慢工具占满全局槽位                    │
├─────────────────────────────────────────────┤
│  维度 3: max_per_session = 5                 │
│  单个 Agent 会话最多同时跑 5 个工具            │
│  防止单个用户霸占资源                          │
└─────────────────────────────────────────────┘
```

### 可配置性

```moonbit
let lim = @lib.default_limiter()
lim.set_tool_limit("weather-query", 20)   // 轻量工具，多给
lim.set_tool_limit("image-processor", 3)  // 重计算，少给
```

### 用户可见性问题——缺失的告警信息

**当前返回**：
```
Err("REJECTED: tool 'weather-query' limit 20")
Err("QUEUED: position 15/200")
```

**缺失**：
- 没有告诉用户"预计还要等多久"（没有队列时间估算）
- 没有告诉用户"当前哪些工具在占用槽位"
- 没有建议"要不要提权或换一个工具"

**改进方向**：
```
Err("RATE_LIMITED: tool 'image-processor' is at capacity (3/3). 
     Currently running: instance-A (2.3s elapsed), instance-B (1.1s).
     Estimated wait: 3 seconds. 
     Suggestion: wait or use 'image-compressor' (0/5 slots free).")
```

---

## 4. 压力监控与熔断——预警和应急策略

### 当前四级响应

| 级别 | 阈值 | 动作 | 恢复 |
|------|:--:|------|:--:|
| Normal | < 70% | 正常运行 | — |
| Warning | 70-85% | 发 webhook 通知 | 自动 |
| Degraded | 85-95% | 停接新调用 + 拒绝低优先级排队 | 持续低于 85% 超过 60s 恢复 |
| Critical | > 95% | 清队列 + 杀所有非关键工具 + 熔断器打开 | 持续低于 70% 超过 120s 恢复 |

### 问题：预警策略缺失的细节

**当前没有**：
- 慢查询检测（单个工具执行超过 30s → 告警但未必杀掉）
- 异常流量检测（某工具调用量突然暴增 → 可能被攻击）
- 分级通知（Warning 发日志、Critical 打电话/钉钉/企微）
- 手动恢复确认（熔断后是自动恢复还是人工确认？）

### 改进方向

```
告警矩阵:
  Warning:  企业微信机器人 / 邮件
  Degraded: 企业微信 + 短信
  Critical: 企业微信 + 电话 + 自动创建 Incident

熔断恢复策略:
  自动恢复: 连续 3 个采样周期低于阈值 → 半开 → 放少量流量 → 全开
  手动恢复: 发送确认链接 → 管理员点击后恢复
```

---

## 5. 可视化实现

### 当前状态：零

没有 Web 面板，没有 Grafana 集成，没有日志可视化。所有信息通过 `println` 输出。

### 可实现的三个层级

**Level 1: 终端仪表盘（立即可做）**
```
┌─────────────────────────────────────────┐
│ AegisRun v0.3.0 Dashboard               │
│─────────────────────────────────────────│
│ CPU  [████████░░] 78%  ● Normal         │
│ MEM  [██████████] 95%  ● Warning        │
│ Slot [████████░░] 67/100                 │
│ Queue ██░░░░░░░░░ 12/200                │
│─────────────────────────────────────────│
│ Last 5 blocked:                          │
│  10:23:33 weather-query → evil.com (BL)  │
│  10:23:34 weather-query → stealer (BL)   │
│  10:25:01 log-analyzer  → /etc/pw (BL)   │
└─────────────────────────────────────────┘
```

**Level 2: Web 面板（Roadmap v2.0）**
- 用 MoonBit 编译 Wasm 跑在浏览器
- 实时策略编辑（拖拽黑名单规则）
- 工具调用拓扑图（哪个 Agent 调了哪个工具）

**Level 3: Grafana 集成**
- 导出 OpenTelemetry metrics
- 对接 Prometheus + Grafana
- 预置 Dashboard JSON

---

## 6. 黑白名单的设置——怎么来的

### 当前预设规则的来源

`standard` 预设里的黑名单不是凭空编的：

| 规则 | 来源 |
|------|------|
| `evil.com`, `stealer.cc` | 演示用占位域名——真实使用时会替换为实际威胁情报 |
| `192.168.*`, `10.*`, `172.16.*` | RFC 1918 私有地址段 |
| `127.0.0.1`, `localhost` | 回环地址，防止 SSRF |
| `*.cn`, `*.ru`, `*.tk` | 演示用国家级后缀拦截 |
| `/etc/passwd`, `/etc/shadow` | Unix 标准敏感文件 |
| `~/.ssh/`, `~/.aws/` | 开发者凭证目录 |
| `C:\Windows\` | Windows 系统目录 |
| `OPENAI_API_KEY`, `DATABASE_URL` | 常见环境变量密钥名 |

### 问题：这些规则对真实用户够用吗？

**不够。** 预设只是"开箱演示"级别的。真实使用需要：
- 接入威胁情报源（AlienVault OTX, Abuse.ch URLhaus）
- 企业自定义规则（公司内部域名白名单、微服务间调用许可）
- 按项目/团队区分策略（前端团队的工具可能需要访问 CDN，后端团队需要访问数据库）

---

## 7. 域名是否可以被 DNS 提前解析绕过？

### 攻击场景

```
恶意工具声明: "我需要访问 wttr.in"
AegisRun 审查: wttr.in 不在黑名单 → 放行
工具运行时:   在本地 /etc/hosts 中将 wttr.in 解析到 evil.com 的 IP
工具实际访问: evil.com 的 IP
AegisRun 看到: 域名仍然是 wttr.in（因为 HTTP 请求里 Host 头是 wttr.in）
```

**是的，可以通过 DNS 劫持绕过域名检查。** 因为 AegisRun 当前检查的是域名字符串，不是解析后的 IP。

### 解决方案

**双重检查**：先查域名，再查 DNS 解析后的 IP。

```
sandbox_http_request("https://wttr.in/Shenzhen")
  │
  ├─ ① 域名检查: wttr.in → Allow (通过)
  │
  ├─ ② DNS 解析: wttr.in → 93.184.216.34
  │
  ├─ ③ IP 黑名单检查: 93.184.216.34 在 IP 黑名单中？
  │   （当前未实现 IP 黑名单）
  │
  ├─ ④ 劫持检测: wttr.in 的历史解析记录是 5.9.243.187？
  │   现在突然变成 93.184.216.34？
  │   → 可能被劫持 → 告警或拒绝
  │
  └─ 全部通过 → 放行
```

**当前状态**：① 已实现，②③④ 均未实现。这是沙箱层接入真实网络栈后才能做的事情。

---

## 8. 审计日志的可读性

### 当前输出

```
[JSONL] {"timestamp":"2026-06-22T10:25:33Z","tool_id":"weather-query","action":"execute","decision":"deny","reason":"evil.com BL"}
```

**问题**：
- 纯文本，无颜色
- 无严重等级标识
- 新手看不懂 `BL` = `blacklisted` 缩写
- 单行 JSON 字段超过 5 个时肉眼难读
- 无多行格式化输出选项

### 改进方案

**终端彩色输出**：

```
10:25:33  weather-query  execute  🔴 DENIED   evil.com is blacklisted
                                              └─ exact-match in blacklist
10:25:34  weather-query  execute  🔴 DENIED   data-stealer.ru blocked
                                              └─ suffix-match: *.ru
10:26:01  calculator     execute  🟢 ALLOWED
10:30:00  ADMIN          ban      🟡 ACTION   weather-query → blacklisted
```

**两级适配**：

| 模式 | 输出 | 适合 |
|------|------|------|
| **simple** (默认) | `10:25:33 🔴 DENIED weather-query → evil.com` | 新人、日常运维 |
| **verbose** | 带匹配规则路径、调用栈、策略来源 | 安全审计、事后溯源 |
| **jsonl** (现有) | 机器可读 JSONL | 导入 SIEM/ELK |

**配色方案**：
- 🔴 `#FF4757` 拦截/拒绝
- 🟢 `#00CC88` 放行/正常
- 🟡 `#FFD700` 警告/封杀
- 🔵 `#6C63FF` 信息/统计

---

## 待讨论清单

| # | 问题 | 优先级 |
|:--:|------|:--:|
| 1 | 风险评分阈值需不需要数据驱动校准 | 中 |
| 2 | SQL guard 是否扩展到 MongoDB/Oracle | 低（先做 SQLite/MySQL 完整支持） |
| 3 | 限流维度是否需要加"按用户"维度 | 中 |
| 4 | 熔断恢复是自动还是手动 | 高 |
| 5 | 可视化优先做终端面板还是 Web | 中 |
| 6 | 黑白名单是否需要接入外部威胁情报 | 低 |
| 7 | DNS 劫持检测优先级 | 高（涉及核心安全） |
| 8 | 审计日志默认模式用 simple 还是 jsonl | 中 |
