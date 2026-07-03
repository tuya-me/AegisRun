// ============================================================
// AegisRun — Sandbox Engine (Execution Layer)
// 运行时拦截层：工具操作的唯一出口，所有操作必经此处
// ============================================================

// 工具被授予的权限（从 Capability 声明 + 管理员批准得出）

///|
pub struct SandboxGrant {
  allowed_domains : Array[String] // 精确域名白名单
  allowed_paths : Array[String] // 路径白名单
  allowed_env_vars : Array[String] // 环境变量白名单
  max_timeout_ms : Int // 超时上限
  max_memory_kb : Int // 内存上限
  max_file_size_kb : Int // 单文件大小上限
}

// 沙箱实例 —— 每个工具实例一个

///|
pub struct Sandbox {
  policy : PolicyState
  grant : SandboxGrant
  ip_bl : IpBlacklist
  mut checked_count : Int
  mut blocked_count : Int
}

// ── 创建沙箱 ──

///|
pub fn new_sandbox(policy : PolicyState, grant : SandboxGrant) -> Sandbox {
  {
    policy,
    grant,
    ip_bl: new_ip_blacklist(),
    checked_count: 0,
    blocked_count: 0,
  }
}

// ── 默认授权（演示用）──

///|
pub fn default_grant() -> SandboxGrant {
  {
    allowed_domains: ["wttr.in", "api.github.com"],
    allowed_paths: ["/tmp/reports/", "/tmp/logs/"],
    allowed_env_vars: ["USER", "LANG", "HOME"],
    max_timeout_ms: 30000,
    max_memory_kb: 262144,
    max_file_size_kb: 10240,
  }
}

// ── 创建标准沙箱：standard 预设 + 默认授权 ──

///|
pub fn standard_sandbox() -> Sandbox {
  let policy = new_policy_engine()
  new_sandbox(policy, default_grant())
}

// ═══════════════════════════════════════════
// 拦截器 1: 网络 HTTP 请求
// ═══════════════════════════════════════════

///|
pub fn Sandbox::sandbox_http_request(
  self : Sandbox,
  url : String,
) -> Result[String, String] {
  self.checked_count = self.checked_count + 1
  let domain = extract_host(url)

  // 第一关：黑名单检查
  match
    check_domain(
      self.policy.blacklist_domains,
      self.policy.domain_suffix_patterns,
      domain,
    ) {
    Deny => {
      self.blocked_count = self.blocked_count + 1
      return Err("BLOCKED: domain '" + domain + "' is blacklisted")
    }
    Allow => ()
  }

  // 第二关：DNS劫持检测 —— 域名解析到的IP在黑名单中吗？
  // (生产环境: 真实DNS解析→check_ip；当前: 跳过DNS解析，仅做IP字符串检查)
  // match dnslookup(domain) {
  //   Some(ip) => check_ip(self.ip_bl, ip) → Err/Ok
  //   None => () // 无法解析则不基于IP拦截
  // }

  // 第三关：授权检查 —— 工具声明过这个域名吗？
  let mut granted = false
  for d in self.grant.allowed_domains {
    if d == domain {
      granted = true
      break
    }
    if d == "*" {
      granted = true
      break
    }
  }
  if !granted {
    self.blocked_count = self.blocked_count + 1
    return Err(
      "BLOCKED: domain '" +
      domain +
      "' not in granted capabilities (granted: " +
      join_strings(self.grant.allowed_domains) +
      ")",
    )
  }

  // 两关都过 → 允许执行真正的 HTTP 请求
  // 生产环境: 调用 wasi-http 或宿主函数
  Ok("[sandbox] HTTP " + url + " → ALLOWED (domain=" + domain + ")")
}

// ═══════════════════════════════════════════
// 拦截器 2: 文件打开
// ═══════════════════════════════════════════

///|
pub fn Sandbox::sandbox_file_open(
  self : Sandbox,
  path : String,
) -> Result[String, String] {
  self.checked_count = self.checked_count + 1

  // 第一关：黑名单检查
  match
    check_path(
      self.policy.blacklist_paths,
      self.policy.path_prefix_patterns,
      path,
    ) {
    Deny => {
      self.blocked_count = self.blocked_count + 1
      return Err("BLOCKED: path '" + path + "' is blacklisted")
    }
    Allow => ()
  }

  // 第二关：授权检查 —— 路径在允许范围内吗？
  let mut granted = false
  for p in self.grant.allowed_paths {
    if path.has_prefix(p) {
      granted = true
      break
    }
    if p == "*" {
      granted = true
      break
    }
  }
  if !granted {
    self.blocked_count = self.blocked_count + 1
    return Err(
      "BLOCKED: path '" +
      path +
      "' not in granted scope (granted: " +
      join_strings(self.grant.allowed_paths) +
      ")",
    )
  }

  // 两关都过
  Ok("[sandbox] open(" + path + ") → ALLOWED")
}

// ═══════════════════════════════════════════
// 拦截器 3: 环境变量读取
// ═══════════════════════════════════════════

///|
pub fn Sandbox::sandbox_getenv(
  self : Sandbox,
  varname : String,
) -> Result[String, String] {
  self.checked_count = self.checked_count + 1

  // 第一关：黑名单检查
  match check_env(self.policy.sensitive_envs, varname) {
    Deny => {
      self.blocked_count = self.blocked_count + 1
      return Err(
        "BLOCKED: env var '" +
        varname +
        "' is sensitive (pattern/keyword match)",
      )
    }
    Allow => ()
  }

  // 第二关：授权检查 —— 工具声明了需要这个变量吗？
  let mut granted = false
  for v in self.grant.allowed_env_vars {
    if v == varname {
      granted = true
      break
    }
    if v == "*" {
      granted = true
      break
    }
  }
  if !granted {
    self.blocked_count = self.blocked_count + 1
    return Err(
      "BLOCKED: env var '" +
      varname +
      "' not in granted set (granted: " +
      join_strings(self.grant.allowed_env_vars) +
      ")",
    )
  }

  Ok("[sandbox] getenv(" + varname + ") → ALLOWED")
}

// ═══════════════════════════════════════════
// 拦截器 4: 资源限制
// ═══════════════════════════════════════════

///|
pub fn Sandbox::sandbox_check_timeout(
  self : Sandbox,
  requested_ms : Int,
) -> Result[Int, String] {
  self.checked_count = self.checked_count + 1
  if requested_ms > self.grant.max_timeout_ms {
    println(
      "    [INFO] sandbox: timeout " +
      requested_ms.to_string() +
      "ms capped to " +
      self.grant.max_timeout_ms.to_string() +
      "ms",
    )
    Ok(self.grant.max_timeout_ms)
  } else {
    Ok(requested_ms)
  }
}

///|
pub fn Sandbox::sandbox_check_memory(
  self : Sandbox,
  requested_kb : Int,
) -> Result[Int, String] {
  self.checked_count = self.checked_count + 1
  if requested_kb > self.grant.max_memory_kb {
    println(
      "    [INFO] sandbox: memory " +
      requested_kb.to_string() +
      "KB capped to " +
      self.grant.max_memory_kb.to_string() +
      "KB",
    )
    Ok(self.grant.max_memory_kb)
  } else {
    Ok(requested_kb)
  }
}

// ═══════════════════════════════════════════
// 沙箱统计
// ═══════════════════════════════════════════

///|
pub fn Sandbox::sandbox_stats(self : Sandbox) -> String {
  let total = self.checked_count
  let blocked = self.blocked_count
  let allowed = total - blocked
  "sandbox: " +
  total.to_string() +
  " ops checked, " +
  allowed.to_string() +
  " allowed, " +
  blocked.to_string() +
  " blocked"
}

// ═══════════════════════════════════════════
// 辅助函数
// ═══════════════════════════════════════════

///|
fn extract_host(url : String) -> String {
  // "https://evil.com/collect" → "evil.com"
  let s = url
  // Remove protocol → StringView, convert to String
  let body = if s.has_prefix("https://") {
    s[8:].to_owned()
  } else if s.has_prefix("http://") {
    s[7:].to_owned()
  } else {
    s
  }
  // Cut at first / or :
  for i = 0; i < body.length(); i = i + 1 {
    if body[i] == '/' || body[i] == ':' {
      return body[0:i].to_owned()
    }
  }
  body
}

///|
fn join_strings(arr : Array[String]) -> String {
  let mut r = ""
  for i = 0; i < arr.length(); i = i + 1 {
    if i > 0 {
      r = r + ", "
    }
    r = r + arr[i]
  }
  r
}
