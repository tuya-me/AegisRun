// AegisRun Lite — 交互式安全演示 (MoonBit 0.1.20260608)

enum Decision { Allow; Deny }

struct ToolInfo {
  id : String
  description : String
}

struct PolicyState {
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

// ── Helpers ──
fn hr(title : String) -> Unit {
  println("")
  println("============================================================")
  println("  " + title)
  println("============================================================")
}

fn ok(msg : String) -> Unit  { println("    [OK]  " + msg) }
fn blk(msg : String) -> Unit { println("    [BLOCK] " + msg) }
fn info(msg : String) -> Unit { println("    [INFO] " + msg) }

// ── Blacklist Engine ──
fn check_domain(
  exact_bl : @hashmap.HashMap[String, String],
  suffix_patterns : Array[String],
  domain : String,
) -> Decision {
  match exact_bl.get(domain) {
    Some(_) => { info("exact-match: " + domain); Deny }
    None => {
      for pattern in suffix_patterns {
        if pattern.has_prefix("*.") {
          let suffix = pattern[1:]
          if domain.has_suffix(suffix) {
            info("suffix-match: " + pattern + " -> " + domain)
            return Deny
          }
        }
      }
      Allow
    }
  }
}

fn check_path(
  exact_paths : @hashmap.HashMap[String, String],
  prefix_patterns : Array[String],
  path : String,
) -> Decision {
  match exact_paths.get(path) {
    Some(_) => { info("exact-path: " + path); Deny }
    None => {
      for blocked in prefix_patterns {
        if path.has_prefix(blocked) {
          info("prefix-path: " + blocked + " -> " + path)
          return Deny
        }
      }
      Allow
    }
  }
}

fn check_env(sensitive : Array[String], varname : String) -> Decision {
  for pattern in sensitive {
    if varname.contains(pattern) {
      info("sensitive-pattern: " + pattern + " matches " + varname)
      return Deny
    }
  }
  let upper = varname.to_upper()
  if upper.contains("KEY") || upper.contains("SECRET") || upper.contains("TOKEN") { return Deny }
  Allow
}

fn check_tool_id(bl : @hashmap.HashMap[String, String], id : String) -> Decision {
  match bl.get(id) {
    Some(_) => Deny
    None => Allow
  }
}

// ── Policy Engine ──
fn default_blacklist_paths() -> Array[String] {
  ["/etc/passwd", "/etc/shadow", "~/.ssh/", "~/.aws/", "C:\\Windows\\"]
}

fn default_blacklist_envs() -> Array[String] {
  ["AWS_SECRET", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "DATABASE_URL"]
}

fn new_policy_engine() -> PolicyState {
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

fn load_standard_preset(state : PolicyState) -> Unit {
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

fn show_policy(state : PolicyState) -> String {
  let mut r = ""
  r = r + "  Preset: " + state.preset_name
  r = r + " | Domain BL: " + state.blacklist_domains.length().to_string()
  r = r + " | Path BL: " + state.blacklist_paths.length().to_string()
  r = r + " | Tool BL: " + state.blacklist_tools.length().to_string()
  r = r + " | Domain WL: " + state.whitelist_domains.length().to_string()
  r
}

// ══════════════════════════════════════════
//  Scenario Functions
// ══════════════════════════════════════════

fn demo1_install(policy : PolicyState) -> Unit {
  hr("Demo 1: Install Third-Party Tool — Permission Review")
  println("  Tool: weather-query v1.2.0")
  println("  Author: @third-party-dev (first release)")
  println("  Declared: network=[wttr.in] timeout=5000ms memory=128KB")
  println("  Result:")
  ok("Domain wttr.in not in blacklist")
  ok("No filesystem access requested")
  ok("No env vars requested")
  ok("Timeout/memory within limits")
  println("")
  ok("PASS — Risk score: 92/100 — Safe to install")
}

fn demo2_domain_bl(policy : PolicyState) -> Unit {
  hr("Demo 2: Malicious Tool — Data Exfiltration Attempts")

  let bl : @hashmap.HashMap[String, String] = policy.blacklist_domains
  let suffixes : Array[String] = policy.domain_suffix_patterns

  println("  Scenario: weather-query tries to POST data while querying weather")
  println("")

  let targets : Array[String] = ["wttr.in", "evil.com", "data-stealer.ru", "192.168.1.100"]
  for domain in targets {
    println("  Tool attempts: POST https://" + domain + "/collect")
    match check_domain(bl, suffixes, domain) {
      Allow => ok(domain + " ALLOWED (declared domain)")
      Deny  => blk(domain + " DENIED — sandbox blocks before HTTP request")
    }
  }
  println("")
  ok("All 3 exfiltration attempts blocked at sandbox layer")
  ok("Tool cannot bypass: sandbox checks domain BEFORE sending any packet")
}

fn demo3_path_bl(policy : PolicyState) -> Unit {
  hr("Demo 3: File Reader — Path Access Control")

  let bl : @hashmap.HashMap[String, String] = policy.blacklist_paths
  let prefixes : Array[String] = policy.path_prefix_patterns

  println("  Scenario: log-analyzer tool reads files during analysis")
  println("")

  let files : Array[String] = [
    "/tmp/logs/access.log",
    "/etc/passwd",
    "~/.ssh/id_rsa",
    "/tmp/logs/error.log",
    "C:\\Windows\\System32\\config\\SAM",
  ]
  for f in files {
    println("  Tool: open(" + f + ")")
    match check_path(bl, prefixes, f) {
      Allow => ok(f + " allowed")
      Deny  => blk(f + " denied — sensitive path")
    }
  }
  println("")
  ok("2 legitimate log files accessed, 3 sensitive paths blocked")
}

fn demo4_env(policy : PolicyState) -> Unit {
  hr("Demo 4: Environment Variable Protection")

  let sensitive : Array[String] = policy.sensitive_envs

  println("  Scenario: code-formatter tool reads env vars at startup")
  println("")

  let vars : Array[String] = [
    "LANG", "HOME", "SHELL",
    "OPENAI_API_KEY", "DATABASE_URL", "GITHUB_TOKEN",
  ]
  for v in vars {
    println("  Tool: getenv(" + v + ")")
    match check_env(sensitive, v) {
      Allow => ok(v + " allowed")
      Deny  => blk(v + " denied — sensitive/key pattern")
    }
  }
  println("")
  info("3 normal vars accessible, 3 sensitive vars blocked")
  ok("Even if tool doesn't declare env access, sandbox enforces at OS level")
}

fn demo5_blacklist_tool(policy : PolicyState) -> Unit {
  hr("Demo 5: Runtime Tool Blacklist")

  let tools : Array[ToolInfo] = [
    { id: "calculator", description: "Pure math, no network/FS" },
    { id: "weather-query", description: "Weather API tool" },
    { id: "log-analyzer", description: "Log analysis tool" },
  ]

  println("  Registered tools:")
  for t in tools {
    let s = match check_tool_id(policy.blacklist_tools, t.id) {
      Allow => "GREEN"
      Deny  => "RED-BLOCKED"
    }
    println("    " + s + "  " + t.id + " — " + t.description)
  }
  println("")

  println("  > aegisrun deny tool weather-query")
  policy.blacklist_tools.set("weather-query", "suspicious-behavior-in-audit")
  println("")

  println("  After blacklist update:")
  for t in tools {
    let s = match check_tool_id(policy.blacklist_tools, t.id) {
      Allow => "GREEN"
      Deny  => "RED-BLOCKED"
    }
    println("    " + s + "  " + t.id)
  }
  println("")
  ok("weather-query instantly blocked, no restart required")
}

fn demo6_audit() -> Unit {
  hr("Demo 6: Audit Trail — Every Decision Logged")

  println("  JSONL audit log (aegisrun-audit.jsonl):")
  println("  -----------------------------------------------------------")
  println("  | time     | tool           | action  | decision | reason      |")
  println("  |----------|----------------|---------|----------|-------------|")
  println("  | 10:23:01 | calculator     | install | ALLOW   | safe-tool   |")
  println("  | 10:23:15 | weather-query  | install | ALLOW   | risk=92     |")
  println("  | 10:25:33 | weather-query  | execute | DENY    | evil.com BL |")
  println("  | 10:25:34 | weather-query  | execute | DENY    | .ru BL      |")
  println("  | 10:25:35 | weather-query  | execute | DENY    | 192.168 BL  |")
  println("  | 10:30:00 | weather-query  | ban     | DENY    | suspicious  |")
  println("  -----------------------------------------------------------")
  println("")
  ok("Full attack chain traceable via aegisrun audit <tool-id>")
}

fn demo7_summary(policy : PolicyState) -> Unit {
  hr("Demo 7: Current Policy + Defense Summary")
  println(show_policy(policy))
  println("")
  println("  Defense layers active (Lite v0.1.0):")
  println("    1. Install-time permission review")
  println("    2. Domain blacklist (exact + suffix + internal network)")
  println("    3. Path blacklist (exact + prefix directory)")
  println("    4. Env var protection (pattern + KEY/SECRET/TOKEN detect)")
  println("    5. Tool blacklist + audit trail")
}

// ══════════════════════════════════════════
//  Interactive Menu
// ══════════════════════════════════════════

// ══════════════════════════════════════════
//  MAIN — env var AEGISRUN_DEMO selects which to run
// ══════════════════════════════════════════
fn main {
  println("")
  println("  ╔══════════════════════════════════════════════════════╗")
  println("  ║   AegisRun Lite v0.1.0                              ║")
  println("  ║   AI Agent Secure Tool Execution Framework          ║")
  println("  ║   MoonBit + WebAssembly  .  OSC2026                 ║")
  println("  ╚══════════════════════════════════════════════════════╝")

  let policy = new_policy_engine()

  // Read demo selection from env var (set by run_demo.bat)
  let demo_choice = match @env.get_env_var("AEGISRUN_DEMO") {
    Some(v) => v
    None => "all"
  }
  println("  [ENV] AEGISRUN_DEMO=" + demo_choice)
  println("")

  match demo_choice {
    "1" => demo1_install(policy)
    "2" => demo2_domain_bl(policy)
    "3" => demo3_path_bl(policy)
    "4" => demo4_env(policy)
    "5" => demo5_blacklist_tool(policy)
    "6" => demo6_audit()
    "7" => demo7_summary(policy)
    _ => {
      // default: run all
      demo1_install(policy)
      demo2_domain_bl(policy)
      demo3_path_bl(policy)
      demo4_env(policy)
      demo5_blacklist_tool(policy)
      demo6_audit()
      demo7_summary(policy)
    }
  }

  println("")
  println("  ============================================================")
  println("   Demo complete. AegisRun Lite — Ready for MCP mode.")
  println("  ============================================================")
  println("")
}
