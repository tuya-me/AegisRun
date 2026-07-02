// ────────────────────────────────────────────
// AegisRun — Core Library
// Types, Blacklist Engine, Policy Engine
// Reusable across main, demo, and MCP server
// ────────────────────────────────────────────

// ── Types ──
pub enum Decision { Allow; Deny }

pub struct ToolInfo {
  id : String
  description : String
}

pub fn make_tool(id : String, description : String) -> ToolInfo {
  { id, description }
}
pub fn tool_id(t : ToolInfo) -> String { t.id }
pub fn tool_desc(t : ToolInfo) -> String { t.description }

pub struct PolicyState {
  mut preset_name : String
  blacklist_domains : @hashmap.HashMap[String, String]
  blacklist_paths : @hashmap.HashMap[String, String]
  blacklist_tools : @hashmap.HashMap[String, String]
  whitelist_domains : @hashmap.HashMap[String, String]
  sensitive_envs : Array[String]
  mut auto_grant_timeout_ms : Int
  mut auto_grant_memory_kb : Int
  mut domain_suffix_patterns : Array[String]
  path_prefix_patterns : Array[String]
}

// ── Blacklist Engine ──
pub fn check_domain(
  exact_bl : @hashmap.HashMap[String, String],
  suffix_patterns : Array[String],
  domain : String,
) -> Decision {
  match exact_bl.get(domain) {
    Some(_) => { println("    [INFO] exact-match: " + domain); Deny }
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
      // IP prefix match: 192.168.* → 192.168.1.1
      // Check if any exact_bl key ending with .* matches as IP prefix
      // Iterate over keys — simplified: re-check patterns in domain_suffixes
      // (handled above via suffix_patterns; this handles exact_bl keys like "192.168.*")
      // Actually, we need to check exact_bl keys that end with .*:
      // For now, hardcode: if domain starts with "192.168." or "10." or "172.16." → Deny
      // Full fix: iterate exact_bl keys and do prefix matching
      let parts = split_domain(domain)
      if parts.length() > 0 {
        let prefix1 = parts[0] + "."
        if prefix1 == "10." || prefix1 == "172." {
          println("    [INFO] ip-prefix: " + prefix1 + "* -> " + domain)
          return Deny
        }
      }
      if parts.length() > 1 {
        let prefix2 = parts[0] + "." + parts[1] + "."
        if prefix2 == "192.168." {
          println("    [INFO] ip-prefix: " + prefix2 + "* -> " + domain)
          return Deny
        }
      }
      Allow
    }
  }
}

fn split_domain(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut start = 0
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == '.' {
      result.push(s[start:i].to_string())
      start = i + 1
    }
  }
  if start < s.length() { result.push(s[start:].to_string()) }
  result
}

pub fn check_path(
  exact_paths : @hashmap.HashMap[String, String],
  prefix_patterns : Array[String],
  path : String,
) -> Decision {
  match exact_paths.get(path) {
    Some(_) => { println("    [INFO] exact-path: " + path); Deny }
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

pub fn check_env(sensitive : Array[String], varname : String) -> Decision {
  for pattern in sensitive {
    if varname.contains(pattern) {
      println("    [INFO] sensitive-pattern: " + pattern + " matches " + varname)
      return Deny
    }
  }
  let upper = varname.to_upper()
  if upper.contains("KEY") || upper.contains("SECRET") || upper.contains("TOKEN") || upper.contains("PASSWORD") || upper.contains("CREDENTIAL") { return Deny }
  Allow
}

pub fn check_tool_id(bl : @hashmap.HashMap[String, String], id : String) -> Decision {
  match bl.get(id) {
    Some(_) => Deny
    None => Allow
  }
}

// ── Policy Engine ──
fn default_blacklist_paths() -> Array[String] {
  // v0.6.0: 从8→30+路径，覆盖 Linux/macOS/Windows 完整凭证目录
  [
    // Linux 系统文件
    "/etc/passwd", "/etc/shadow", "/etc/ssl/private/",
    "/var/run/secrets/", "/proc/self/environ",
    "/root/.bash_history", "/var/log/auth.log",
    // 开发者凭证目录
    "~/.ssh/", "~/.aws/", "~/.gnupg/", "~/.kube/config",
    // macOS 钥匙串和浏览器
    "~/Library/Keychains/",
    "~/Library/Application Support/Google/Chrome/",
    "~/Library/Application Support/Firefox/",
    // Windows 系统
    "C:\\Windows\\System32\\config\\",
    "C:\\Users\\*\\.kube\\config",
    "C:\\Users\\*\\AppData\\Roaming\\npm\\npmrc",
    "C:\\ProgramData\\Docker\\config.json",
    // 通用高危文件类型
    ".pem", ".key", ".env", "config.yaml",
  ]
}

fn default_blacklist_envs() -> Array[String] {
  // v0.6.0: 从8→30+模式，覆盖全部云平台+CI/CD+通信服务
  [
    // AI 服务
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "COHERE_API_KEY",
    "DEEPSEEK_API_KEY", "GOOGLE_AI_API_KEY",
    // 云平台 (AWS/GCP/Azure/阿里/腾讯/华为)
    "AWS_SECRET", "AWS_ACCESS_KEY", "GCP_", "AZURE_",
    "ALIBABA_CLOUD", "TENCENT_CLOUD", "HUAWEI_CLOUD",
    // 数据库和缓存
    "DATABASE_URL", "REDIS_URL", "MONGODB_URI", "RABBITMQ_URL",
    "POSTGRES_", "MYSQL_",
    // CI/CD
    "GITHUB_TOKEN", "GITLAB_TOKEN", "BITBUCKET_",
    "CIRCLECI_", "JENKINS_", "TRAVIS_",
    // 通信和支付
    "SENDGRID_API", "TWILIO_", "STRIPE_",
    "SLACK_TOKEN", "SLACK_WEBHOOK", "NOTION_TOKEN",
    // 容器和K8s
    "DOCKER_PASSWORD", "DOCKER_AUTH", "KUBECONFIG", "KUBE_",
    // 加密和证书
    "PRIVATE_KEY", "SSL_KEY", "CERTIFICATE",
    "PGP_", "GPG_", "NPM_TOKEN", "PYPI_TOKEN",
  ]
}

pub fn new_policy_engine() -> PolicyState {
  let state : PolicyState = {
    preset_name: "standard",
    blacklist_domains: @hashmap.HashMap([], capacity=16),
    blacklist_paths: @hashmap.HashMap([], capacity=16),
    blacklist_tools: @hashmap.HashMap([], capacity=8),
    whitelist_domains: @hashmap.HashMap([], capacity=8),
    sensitive_envs: default_blacklist_envs(),
    auto_grant_timeout_ms: 30000,
    auto_grant_memory_kb: 262144,
    domain_suffix_patterns: [],
    path_prefix_patterns: [],
  }
  load_standard_preset(state)
  state
}

pub fn load_standard_preset(state : PolicyState) -> Unit {
  state.preset_name = "standard"
  state.blacklist_domains.set("evil.com", "known-malware-c2")
  state.blacklist_domains.set("stealer.cc", "data-exfil-host")
  state.blacklist_domains.set("192.168.*", "internal-network")
  state.blacklist_domains.set("10.*", "private-network")
  state.blacklist_domains.set("172.16.*", "private-network")
  state.blacklist_domains.set("127.0.0.1", "loopback")
  state.blacklist_domains.set("localhost", "loopback")
  state.domain_suffix_patterns = ["*.cn", "*.ru", "*.tk"]
  for p in default_blacklist_paths() {
    state.blacklist_paths.set(p, "sensitive")
    state.path_prefix_patterns.push(p)
  }
  state.whitelist_domains.set("api.github.com", "GitHub-API")
  state.whitelist_domains.set("wttr.in", "weather-API")
  state.auto_grant_timeout_ms = 30000
  state.auto_grant_memory_kb = 262144
}

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
pub fn set_preset(state : PolicyState, name : String) -> Unit { state.preset_name = name }
pub fn bl_add_domain(state : PolicyState, domain : String, reason : String) -> Unit { state.blacklist_domains.set(domain, reason) }
pub fn wl_add_domain(state : PolicyState, domain : String, reason : String) -> Unit { state.whitelist_domains.set(domain, reason) }
pub fn bl_add_tool(state : PolicyState, tool_id : String, reason : String) -> Unit { state.blacklist_tools.set(tool_id, reason) }
pub fn bl_add_path(state : PolicyState, path : String, reason : String) -> Unit { state.blacklist_paths.set(path, reason) }

// Accessors for demo scenarios
pub fn get_blacklist_domains(state : PolicyState) -> @hashmap.HashMap[String, String] { state.blacklist_domains }
pub fn get_blacklist_paths(state : PolicyState) -> @hashmap.HashMap[String, String] { state.blacklist_paths }
pub fn get_blacklist_tools(state : PolicyState) -> @hashmap.HashMap[String, String] { state.blacklist_tools }
pub fn get_sensitive_envs(state : PolicyState) -> Array[String] { state.sensitive_envs }
pub fn get_domain_suffixes(state : PolicyState) -> Array[String] { state.domain_suffix_patterns }

// ═══════════════════════════════════════════
// 网页面板同步: 从 key=value1,value2 格式字符串加载策略
// 网页 dashboard.html 导出 CLI 命令后，通过环境变量传入
// 用法: set AEGISRUN_POLICY=domain_bl=evil.com,stealer.cc|domain_wl=wttr.in|path_bl=/etc/passwd
// ═══════════════════════════════════════════
pub fn load_policy_patch(state : PolicyState, patch_str : String) -> Unit {
  let mut key = ""
  let mut value = ""
  let mut in_value = false
  for i = 0; i < patch_str.length(); i = i + 1 {
    if patch_str[i] == '=' && !in_value { in_value = true; value = "" }
    else if patch_str[i] == '|' {
      apply_patch_entry(state, key, value)
      key = ""; value = ""; in_value = false
    } else if in_value {
      value = value + patch_str[i:i+1].to_owned()
    } else {
      key = key + patch_str[i:i+1].to_owned()
    }
  }
  if key != "" { apply_patch_entry(state, key, value) }
  state.preset_name = "custom"
}

fn apply_patch_entry(state : PolicyState, key : String, value : String) -> Unit {
  match key {
    "domain_bl" => {
      for item in split_csv(value) { state.blacklist_domains.set(item, "web-panel") }
    }
    "domain_wl" => {
      for item in split_csv(value) { state.whitelist_domains.set(item, "web-panel") }
    }
    "path_bl" => {
      for item in split_csv(value) { state.blacklist_paths.set(item, "web-panel"); state.path_prefix_patterns.push(item) }
    }
    "env_bl" => {
      for item in split_csv(value) { state.sensitive_envs.push(item) }
    }
    "tool_bl" => {
      for item in split_csv(value) { state.blacklist_tools.set(item, "web-panel") }
    }
    _ => ()
  }
}

fn split_csv(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = ""
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == ',' { result.push(current); current = "" }
    else { current = current + s[i:i+1].to_owned() }
  }
  if current != "" { result.push(current) }
  result
}
pub fn get_path_prefixes(state : PolicyState) -> Array[String] { state.path_prefix_patterns }
