// ────────────────────────────────────────────
// AegisRun — Core Library
// Types, Blacklist Engine, Policy Engine
// Reusable across main, demo, and MCP server
// ────────────────────────────────────────────

// ── Types ──

///|
pub enum Decision {
  Allow
  Deny
} derive(Eq, Debug)

///|
impl Show for Decision with to_string(self) {
  match self {
    Allow => "Allow"
    Deny => "Deny"
  }
}

///|
pub struct ToolInfo {
  id : String
  description : String
}

///|
pub fn make_tool(id : String, description : String) -> ToolInfo {
  { id, description }
}

///|
pub fn tool_id(t : ToolInfo) -> String {
  t.id
}

///|
pub fn tool_desc(t : ToolInfo) -> String {
  t.description
}

///|
pub struct PolicyState {
  mut preset_name : String
  mut blacklist_domains : @hashmap.HashMap[String, String]
  mut blacklist_paths : @hashmap.HashMap[String, String]
  blacklist_tools : @hashmap.HashMap[String, String]
  whitelist_domains : @hashmap.HashMap[String, String]
  sensitive_envs : Array[String]
  mut auto_grant_timeout_ms : Int
  mut auto_grant_memory_kb : Int
  mut domain_suffix_patterns : Array[String]
  path_prefix_patterns : Array[String]
  mut ip_prefixes : Array[String] // ponytail: 替代硬编码 IP 前缀判断
}

// ── Blacklist Engine ──

///|
pub fn check_domain(
  exact_bl : @hashmap.HashMap[String, String],
  suffix_patterns : Array[String],
  ip_prefixes : Array[String],
  domain : String,
) -> Decision {
  // ponytail: "*" wildcard → block all
  match exact_bl.get("*") {
    Some(_) => {
      println("    [INFO] wildcard-block: " + domain)
      return Deny
    }
    None => ()
  }
  match exact_bl.get(domain) {
    Some(_) => {
      println("    [INFO] exact-match: " + domain)
      Deny
    }
    None => {
      // DNS suffix match: *.cn → www.example.cn
      for pattern in suffix_patterns {
        if pattern.has_prefix("*.") {
          let suffix = pattern[1:]
          if domain.has_suffix(suffix) {
            println("    [INFO] suffix-match: " + pattern + " -> " + domain)
            return Deny
          }
        }
      }
      // IP prefix match: iterate ip_prefixes list
      for prefix in ip_prefixes {
        if domain.has_prefix(prefix) {
          println("    [INFO] ip-prefix: " + prefix + "* -> " + domain)
          return Deny
        }
      }
      Allow
    }
  }
}

///|
pub fn check_path(
  exact_paths : @hashmap.HashMap[String, String],
  prefix_patterns : Array[String],
  path : String,
) -> Decision {
  match exact_paths.get(path) {
    Some(_) => {
      println("    [INFO] exact-path: " + path)
      Deny
    }
    None => {
      for blocked in prefix_patterns {
        if path.has_prefix(blocked) {
          println("    [INFO] prefix-path: " + blocked + " -> " + path)
          return Deny
        }
      }
      Allow
    }
  }
}

///|
pub fn check_env(sensitive : Array[String], varname : String) -> Decision {
  for pattern in sensitive {
    if varname.contains(pattern) {
      println(
        "    [INFO] sensitive-pattern: " + pattern + " matches " + varname,
      )
      return Deny
    }
  }
  let upper = varname.to_upper()
  for kw in env_keywords() {
    if upper.contains(kw) {
      println("    [INFO] keyword-pattern: " + kw + " matches " + varname)
      return Deny
    }
  }
  Allow
}

///|
pub fn check_tool_id(
  bl : @hashmap.HashMap[String, String],
  id : String,
) -> Decision {
  match bl.get(id) {
    Some(_) => Deny
    None => Allow
  }
}

// ═══════════════════════════════════════════
// 默认策略数据（唯一维护点）
// v0.8.0: 从 defaults.mbt 合并至此，删除重复
// ═══════════════════════════════════════════

///|
pub fn default_domain_blacklist() -> Array[(String, String)] {
  [("evil.com", "known-malware-c2"), ("stealer.cc", "data-exfil-host"),
  ("192.168.*", "internal-network"), ("10.*", "private-network"),
  ("172.16.*", "private-network"), ("127.0.0.1", "loopback"),
  ("localhost", "loopback")]
}

///|
pub fn default_domain_suffixes() -> Array[String] {
  ["*.cn", "*.ru", "*.tk"]
}

///|
pub fn default_ip_prefixes() -> Array[String] {
  ["10.", "172.", "192.168."]
}

///|
pub fn default_domain_whitelist() -> Array[(String, String)] {
  [("api.github.com", "GitHub-API"), ("wttr.in", "weather-API")]
}

///|
pub fn default_sensitive_paths() -> Array[String] {
  [
    "/etc/passwd", "/etc/shadow", "/etc/ssl/private/", "/var/run/secrets/",
    "/proc/self/environ", "/root/.bash_history", "/var/log/auth.log",
     "~/.ssh/", "~/.aws/", "~/.gnupg/", "~/.kube/config",
     "~/Library/Keychains/", "~/Library/Application Support/Google/Chrome/",
    "~/Library/Application Support/Firefox/",
     "C:\\Windows\\System32\\config\\", "C:\\Users\\*\\.kube\\config",
    "C:\\Users\\*\\AppData\\Roaming\\npm\\npmrc",
    "C:\\ProgramData\\Docker\\config.json",
     ".pem", ".key", ".env", "config.yaml",
  ]
}

///|
pub fn default_env_patterns() -> Array[String] {
  ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "COHERE_API_KEY", "DEEPSEEK_API_KEY",
  "GOOGLE_AI_API_KEY",
   "AWS_SECRET", "AWS_ACCESS_KEY", "GCP_", "AZURE_", "ALIBABA_CLOUD",
  "TENCENT_CLOUD", "HUAWEI_CLOUD",
   "DATABASE_URL", "REDIS_URL", "MONGODB_URI", "RABBITMQ_URL", "POSTGRES_",
  "MYSQL_",
   "GITHUB_TOKEN", "GITLAB_TOKEN", "BITBUCKET_", "CIRCLECI_", "JENKINS_",
  "TRAVIS_",
   "SENDGRID_API", "TWILIO_", "STRIPE_", "SLACK_TOKEN", "SLACK_WEBHOOK",
  "NOTION_TOKEN",
   "DOCKER_PASSWORD", "DOCKER_AUTH", "KUBECONFIG", "KUBE_",
   "PRIVATE_KEY", "SSL_KEY", "CERTIFICATE", "PGP_", "GPG_", "NPM_TOKEN",
  "PYPI_TOKEN"]
}

///|
pub fn env_keywords() -> Array[String] {
  ["KEY", "SECRET", "TOKEN", "PASSWORD", "CREDENTIAL"]
}

///|
pub fn default_timeout_ms() -> Int { 30000 }

///|
pub fn default_memory_kb() -> Int { 262144 }

///|
pub fn new_policy_engine() -> PolicyState {
  let state : PolicyState = {
    preset_name: "standard",
    blacklist_domains: @hashmap.HashMap([], capacity=16),
    blacklist_paths: @hashmap.HashMap([], capacity=16),
    blacklist_tools: @hashmap.HashMap([], capacity=8),
    whitelist_domains: @hashmap.HashMap([], capacity=8),
    sensitive_envs: default_env_patterns(),
    auto_grant_timeout_ms: 30000,
    auto_grant_memory_kb: 262144,
    domain_suffix_patterns: [],
    path_prefix_patterns: [],
    ip_prefixes: [],
  }
  load_standard_preset(state)
  state
}

///|
pub fn load_standard_preset(state : PolicyState) -> Unit {
  state.preset_name = "standard"
  for pair in default_domain_blacklist() {
    state.blacklist_domains.set(pair.0, pair.1)
  }
  state.domain_suffix_patterns = default_domain_suffixes()
  state.ip_prefixes = default_ip_prefixes()
  for p in default_sensitive_paths() {
    state.blacklist_paths.set(p, "sensitive")
    state.path_prefix_patterns.push(p)
  }
  for pair in default_domain_whitelist() {
    state.whitelist_domains.set(pair.0, pair.1)
  }
  state.auto_grant_timeout_ms = default_timeout_ms()
  state.auto_grant_memory_kb = default_memory_kb()
}

///|
pub fn show_policy(state : PolicyState) -> String {
  let mut r = ""
  r = r + "  Preset: " + state.preset_name
  r = r + " | Domain BL: " + state.blacklist_domains.length().to_string()
  r = r + " | Path BL: " + state.blacklist_paths.length().to_string()
  r = r + " | Tool BL: " + state.blacklist_tools.length().to_string()
  r = r + " | Domain WL: " + state.whitelist_domains.length().to_string()
  r
}

// Setters for CLI commands

///|
pub fn set_preset(state : PolicyState, name : String) -> Unit {
  state.preset_name = name
}

///|
pub fn bl_add_domain(
  state : PolicyState,
  domain : String,
  reason : String,
) -> Unit {
  state.blacklist_domains.set(domain, reason)
  // ponytail: 自动检测 IP 前缀通配符 (如 10.* → push "10." 到 ip_prefixes)
  if domain.has_suffix(".*") {
    let prefix = domain[:domain.length() - 2].to_owned()
    if !state.ip_prefixes.contains(prefix) {
      state.ip_prefixes.push(prefix)
    }
  }
}

///|
pub fn wl_add_domain(
  state : PolicyState,
  domain : String,
  reason : String,
) -> Unit {
  state.whitelist_domains.set(domain, reason)
}

///|
pub fn bl_add_tool(
  state : PolicyState,
  tool_id : String,
  reason : String,
) -> Unit {
  state.blacklist_tools.set(tool_id, reason)
}

///|
pub fn bl_add_path(state : PolicyState, path : String, reason : String) -> Unit {
  state.blacklist_paths.set(path, reason)
}

// Accessors for demo scenarios

///|
pub fn get_blacklist_domains(
  state : PolicyState,
) -> @hashmap.HashMap[String, String] {
  state.blacklist_domains
}

///|
pub fn get_blacklist_paths(
  state : PolicyState,
) -> @hashmap.HashMap[String, String] {
  state.blacklist_paths
}

///|
pub fn get_blacklist_tools(
  state : PolicyState,
) -> @hashmap.HashMap[String, String] {
  state.blacklist_tools
}

///|
pub fn get_sensitive_envs(state : PolicyState) -> Array[String] {
  state.sensitive_envs
}

///|
pub fn get_domain_suffixes(state : PolicyState) -> Array[String] {
  state.domain_suffix_patterns
}

// ═══════════════════════════════════════════
// 网页面板同步: 从 key=value1,value2 格式字符串加载策略
// 网页 dashboard.html 导出 CLI 命令后，通过环境变量传入
// 用法: set AEGISRUN_POLICY=domain_bl=evil.com,stealer.cc|domain_wl=wttr.in|path_bl=/etc/passwd
// ═══════════════════════════════════════════

///|
pub fn load_policy_patch(state : PolicyState, patch_str : String) -> Unit {
  let mut key = ""
  let mut value = ""
  let mut in_value = false
  for i = 0; i < patch_str.length(); i = i + 1 {
    if patch_str[i] == '=' && !in_value {
      in_value = true
      value = ""
    } else if patch_str[i] == '|' {
      apply_patch_entry(state, key, value)
      key = ""
      value = ""
      in_value = false
    } else if in_value {
      value = value + patch_str[i:i + 1].to_owned()
    } else {
      key = key + patch_str[i:i + 1].to_owned()
    }
  }
  if key != "" {
    apply_patch_entry(state, key, value)
  }
  state.preset_name = "custom"
}

///|
fn apply_patch_entry(state : PolicyState, key : String, value : String) -> Unit {
  match key {
    "domain_bl" =>
      for item in split_csv(value) {
        state.blacklist_domains.set(item, "web-panel")
      }
    "domain_wl" =>
      for item in split_csv(value) {
        state.whitelist_domains.set(item, "web-panel")
      }
    "path_bl" =>
      for item in split_csv(value) {
        state.blacklist_paths.set(item, "web-panel")
        // ponytail: 去重——避免重复导入时累积
        if !state.path_prefix_patterns.contains(item) {
          state.path_prefix_patterns.push(item)
        }
      }
    "env_bl" =>
      for item in split_csv(value) {
        state.sensitive_envs.push(item)
      }
    "tool_bl" =>
      for item in split_csv(value) {
        state.blacklist_tools.set(item, "web-panel")
      }
    _ => ()
  }
}

///|
fn split_csv(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = ""
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == ',' {
      result.push(current)
      current = ""
    } else {
      current = current + s[i:i + 1].to_owned()
    }
  }
  if current != "" {
    result.push(current)
  }
  result
}

///|
pub fn get_ip_prefixes(state : PolicyState) -> Array[String] {
  state.ip_prefixes
}

///|
pub fn get_path_prefixes(state : PolicyState) -> Array[String] {
  state.path_prefix_patterns
}

// ═══════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════

///|
test "domain_blocks" {
  let policy = new_policy_engine()
  let bl = get_blacklist_domains(policy)
  let suffixes = get_domain_suffixes(policy)
  let ip_prefixes = get_ip_prefixes(policy)

  assert_eq(check_domain(bl, suffixes, ip_prefixes, "evil.com"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "stealer.cc"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "192.168.1.100"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "10.0.0.1"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "172.16.0.1"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "127.0.0.1"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "localhost"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "data-harvest.cn"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "botnet.ru"), Deny)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "wttr.in"), Allow)
  assert_eq(check_domain(bl, suffixes, ip_prefixes, "example.com"), Allow)
}

///|
test "path_blocks" {
  let policy = new_policy_engine()
  let path_bl = get_blacklist_paths(policy)
  let prefixes = get_path_prefixes(policy)

  assert_eq(check_path(path_bl, prefixes, "/etc/passwd"), Deny)
  assert_eq(check_path(path_bl, prefixes, "/etc/shadow"), Deny)
  assert_eq(check_path(path_bl, prefixes, "~/.ssh/id_rsa"), Deny)
  assert_eq(check_path(path_bl, prefixes, "/tmp/logs/app.log"), Allow)
  assert_eq(check_path(path_bl, prefixes, "/home/user/docs"), Allow)
}

///|
test "env_blocks" {
  let policy = new_policy_engine()
  let env_sensitive = get_sensitive_envs(policy)

  assert_eq(check_env(env_sensitive, "OPENAI_API_KEY"), Deny)
  assert_eq(check_env(env_sensitive, "DATABASE_URL"), Deny)
  assert_eq(check_env(env_sensitive, "GITHUB_TOKEN"), Deny)
  assert_eq(check_env(env_sensitive, "MY_SECRET_KEY"), Deny)
  assert_eq(check_env(env_sensitive, "USER"), Allow)
  assert_eq(check_env(env_sensitive, "LANG"), Allow)
}
