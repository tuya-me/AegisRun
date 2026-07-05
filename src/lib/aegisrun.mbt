// ============================================================
// AegisRun v0.5.0 — 统一门面，一行接入，内部函数零暴露
// ============================================================
// 用法:
//   let aegis = @lib.AegisRun::new("standard")
//   aegis.check_domain("evil.com")          // → Deny
//   aegis.check_path("/etc/passwd")          // → Deny
//   aegis.check_env("OPENAI_API_KEY")        // → Deny
//   aegis.scan_tool_manifest("tool.toml")    // → RiskReport
//   aegis.export_policy()                    // → String (JSON)
//   aegis.switch_preset("strict")            // → 切换预设
//   aegis.block("domain", "evil.com")        // → 加入黑名单
//   aegis.allow("domain", "wttr.in")         // → 加入白名单
// ============================================================

///|
pub struct AegisRun {
  policy : PolicyState
  ip_bl : IpBlacklist
  // 缓存：HashMap 加速重复查询
  mut domain_cache : @hashmap.HashMap[String, Decision]
  mut path_cache : @hashmap.HashMap[String, Decision]
  mut env_cache : @hashmap.HashMap[String, Decision]
  // 统计
  mut total_checks : Int
  mut total_blocks : Int
  // ponytail: 追踪数组——绕过 HashMap 不可遍历，供 export_policy 使用
  domain_bl_track : Array[String]
  path_bl_track : Array[String]
  tool_bl_track : Array[String]
}

// ═══════ 创建 ═══════

///|
pub fn AegisRun::new(preset : String) -> AegisRun {
  let policy = new_policy_engine()
  match preset {
    "strict" => {
      policy.preset_name = "strict"
      policy.blacklist_domains.set("*", "all blocked")
    }
    "permissive" => policy.preset_name = "permissive"
    _ => () // standard is default
  }
  {
    policy,
    ip_bl: new_ip_blacklist(),
    domain_cache: @hashmap.HashMap([], capacity=64),
    path_cache: @hashmap.HashMap([], capacity=64),
    env_cache: @hashmap.HashMap([], capacity=32),
    total_checks: 0,
    total_blocks: 0,
    domain_bl_track: [],
    path_bl_track: [],
    tool_bl_track: [],
  }
}

// ═══════ 核心检查（一行调用，内部自动取 bl/suffixes）═══

// 域名检查 —— 用户只需传域名

///|
pub fn AegisRun::check_domain(self : AegisRun, domain : String) -> Decision {
  self.total_checks = self.total_checks + 1
  // 查缓存
  match self.domain_cache.get(domain) {
    Some(result) => {
      self.domain_cache.set(domain, result)
      return result
    }
    None => ()
  }
  // 查黑名单
  let result = check_domain(
    self.policy.blacklist_domains,
    self.policy.domain_suffix_patterns,
    self.policy.ip_prefixes,
    domain,
  )
  self.domain_cache.set(domain, result)
  match result {
    Deny => self.total_blocks = self.total_blocks + 1
    _ => ()
  }
  result
}

// 路径检查

///|
pub fn AegisRun::check_path(self : AegisRun, path : String) -> Decision {
  self.total_checks = self.total_checks + 1
  match self.path_cache.get(path) {
    Some(result) => return result
    None => ()
  }
  let result = check_path(
    self.policy.blacklist_paths,
    self.policy.path_prefix_patterns,
    path,
  )
  self.path_cache.set(path, result)
  match result {
    Deny => self.total_blocks = self.total_blocks + 1
    _ => ()
  }
  result
}

// 环境变量检查

///|
pub fn AegisRun::check_env(self : AegisRun, varname : String) -> Decision {
  self.total_checks = self.total_checks + 1
  match self.env_cache.get(varname) {
    Some(result) => return result
    None => ()
  }
  let result = check_env(self.policy.sensitive_envs, varname)
  self.env_cache.set(varname, result)
  match result {
    Deny => self.total_blocks = self.total_blocks + 1
    _ => ()
  }
  result
}

// ═══════ 批量检查 ═══════

///|
pub fn AegisRun::check_domains(
  self : AegisRun,
  domains : Array[String],
) -> Array[String] {
  let results : Array[String] = []
  for domain in domains {
    match self.check_domain(domain) {
      Allow => results.push(domain + ":ALLOW")
      Deny => results.push(domain + ":DENY")
    }
  }
  results
}

///|
pub fn AegisRun::check_paths(
  self : AegisRun,
  paths : Array[String],
) -> Array[String] {
  let results : Array[String] = []
  for path in paths {
    match self.check_path(path) {
      Allow => results.push(path + ":ALLOW")
      Deny => results.push(path + ":DENY")
    }
  }
  results
}

// ═══════ 策略管理 ═══════

///|
pub fn AegisRun::switch_preset(self : AegisRun, name : String) -> Unit {
  // 清缓存
  self.domain_cache = @hashmap.HashMap([], capacity=64)
  self.path_cache = @hashmap.HashMap([], capacity=64)
  self.env_cache = @hashmap.HashMap([], capacity=32)

  // ponytail: 清空旧黑名单再加载新预设，避免 strict 的 "*" 残留
  self.policy.blacklist_domains = @hashmap.HashMap([], capacity=16)
  self.policy.blacklist_paths = @hashmap.HashMap([], capacity=16)
  self.policy.ip_prefixes = []
  match name {
    "strict" => {
      self.policy.preset_name = "strict"
      self.policy.blacklist_domains.set("*", "all blocked")
    }
    "permissive" => self.policy.preset_name = "permissive"
    _ => load_standard_preset(self.policy)
  }
}

///|
pub fn AegisRun::block(
  self : AegisRun,
  target_type : String,
  value : String,
) -> Unit {
  match target_type {
    "domain" => {
      self.policy.blacklist_domains.set(value, "manual")
      self.domain_cache = @hashmap.HashMap([], capacity=64)
      if !self.domain_bl_track.contains(value) {
        self.domain_bl_track.push(value)
      }
    }
    "path" => {
      self.policy.blacklist_paths.set(value, "manual")
      self.path_cache = @hashmap.HashMap([], capacity=64)
      if !self.path_bl_track.contains(value) {
        self.path_bl_track.push(value)
      }
    }
    "tool" => {
      self.policy.blacklist_tools.set(value, "manual")
      if !self.tool_bl_track.contains(value) {
        self.tool_bl_track.push(value)
      }
    }
    _ => ()
  }
}

///|
pub fn AegisRun::allow(
  self : AegisRun,
  target_type : String,
  value : String,
) -> Unit {
  if target_type == "domain" {
    self.policy.whitelist_domains.set(value, "manual")
  }
}

// ═══════ 策略导入导出 ═══════

///|
pub fn AegisRun::export_policy(self : AegisRun) -> String {
  let mut r = ""
  r = r + "preset=" + self.policy.preset_name
  r = r + "|domain_bl="
  for i = 0; i < self.domain_bl_track.length(); i = i + 1 {
    if i > 0 { r = r + "," }
    r = r + self.domain_bl_track[i]
  }
  r = r + "|path_bl="
  for i = 0; i < self.path_bl_track.length(); i = i + 1 {
    if i > 0 { r = r + "," }
    r = r + self.path_bl_track[i]
  }
  r = r + "|tool_bl="
  for i = 0; i < self.tool_bl_track.length(); i = i + 1 {
    if i > 0 { r = r + "," }
    r = r + self.tool_bl_track[i]
  }
  r
}

// 从环境变量导入策略（配合网页面板使用）

///|
pub fn AegisRun::import_from_env(self : AegisRun) -> Unit {
  let patch = match @env.get_env_var("AEGISRUN_POLICY") {
    Some(v) => v
    None => ""
  }
  if patch != "" {
    load_policy_patch(self.policy, patch)
    // 清缓存
    self.domain_cache = @hashmap.HashMap([], capacity=64)
    self.path_cache = @hashmap.HashMap([], capacity=64)
    self.env_cache = @hashmap.HashMap([], capacity=32)
  }
}

// ═══════ 风险评分 ═══════

///|
pub fn AegisRun::score_manifest(
  self : AegisRun,
  tool_id : String,
  author : String,
  is_new : Bool,
  domains : Array[String],
  paths : Array[String],
  path_perms : Array[String],
  envs : Array[String],
  timeout : Int,
  memory : Int,
) -> RiskReport {
  let _ = self
  score_manifest(
    tool_id, author, is_new, domains, paths, path_perms, envs, timeout, memory,
  )
}

// ═══════ 统计 ═══════

///|
pub fn AegisRun::stats(self : AegisRun) -> String {
  "AegisRun: preset=" +
  self.policy.preset_name +
  " checks=" +
  self.total_checks.to_string() +
  " blocks=" +
  self.total_blocks.to_string() +
  " cache_size=" +
  self.domain_cache.length().to_string()
}

///|
pub fn AegisRun::block_rate(self : AegisRun) -> String {
  if self.total_checks == 0 {
    "0%"
  } else {
    (self.total_blocks * 100 / self.total_checks).to_string() + "%"
  }
}

// ═══════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════

test "aegisrun_facade" {
  let aegis = AegisRun::new("standard")
  assert_eq!(aegis.check_domain("evil.com"), Deny)
  assert_eq!(aegis.check_domain("wttr.in"), Allow)
  assert_eq!(aegis.check_path("/etc/passwd"), Deny)
  assert_eq!(aegis.check_path("/tmp/logs/app.log"), Allow)
  assert_eq!(aegis.check_env("OPENAI_API_KEY"), Deny)
  assert_eq!(aegis.check_env("USER"), Allow)
}

test "preset_switch" {
  let aegis = AegisRun::new("standard")
  assert_eq!(aegis.check_domain("wttr.in"), Allow)
  aegis.switch_preset("strict")
  assert_eq!(aegis.check_domain("wttr.in"), Deny)
  aegis.switch_preset("standard")
  assert_eq!(aegis.check_domain("wttr.in"), Allow)
}

test "block_and_export" {
  let aegis = AegisRun::new("standard")
  aegis.block("domain", "blocked-test.com")
  assert_eq!(aegis.check_domain("blocked-test.com"), Deny)
  aegis.allow("domain", "allowed-test.com")
  assert_eq!(aegis.check_domain("allowed-test.com"), Allow)
  let exported = aegis.export_policy()
  assert_eq!(exported.contains("preset=standard"), true)
  assert_eq!(exported.contains("blocked-test.com"), true)
}
