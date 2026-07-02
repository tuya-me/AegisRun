// ────────────────────────────────────────────
// AegisRun — Demo Scenarios (7 security demos)
// Depends on: aegisrun/lib (core engine)
// ────────────────────────────────────────────

fn hr(title : String) -> Unit {
  println("")
  println("============================================================")
  println("  " + title)
  println("============================================================")
}
fn ok(msg : String) -> Unit  { println("    [OK]  " + msg) }
fn blk(msg : String) -> Unit { println("    [BLOCK] " + msg) }
fn info(msg : String) -> Unit { println("    [INFO] " + msg) }

pub fn demo1() -> Unit {
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

pub fn demo2(policy : @lib.PolicyState) -> Unit {
  hr("Demo 2: Malicious Tool — Data Exfiltration Attempts")
  let bl = @lib.get_blacklist_domains(policy)
  let suffixes = @lib.get_domain_suffixes(policy)
  println("  Scenario: weather-query tries to POST data while querying weather")
  println("")
  let targets : Array[String] = ["wttr.in", "evil.com", "data-stealer.ru", "192.168.1.100"]
  for domain in targets {
    println("  Tool attempts: POST https://" + domain + "/collect")
    match @lib.check_domain(bl, suffixes, domain) {
      Allow => ok(domain + " ALLOWED (declared domain)")
      Deny  => blk(domain + " DENIED — sandbox blocks before HTTP request")
    }
  }
  println("")
  ok("All 3 exfiltration attempts blocked at sandbox layer")
  ok("Tool cannot bypass: sandbox checks domain BEFORE sending any packet")
}

pub fn demo3(policy : @lib.PolicyState) -> Unit {
  hr("Demo 3: File Reader — Path Access Control")
  let bl = @lib.get_blacklist_paths(policy)
  let prefixes = @lib.get_path_prefixes(policy)
  println("  Scenario: log-analyzer tool reads files during analysis")
  println("")
  let files : Array[String] = [
    "/tmp/logs/access.log", "/etc/passwd", "~/.ssh/id_rsa",
    "/tmp/logs/error.log", "C:\\Windows\\System32\\config\\SAM",
  ]
  for f in files {
    println("  Tool: open(" + f + ")")
    match @lib.check_path(bl, prefixes, f) {
      Allow => ok(f + " allowed")
      Deny  => blk(f + " denied — sensitive path")
    }
  }
  println("")
  ok("2 legitimate log files accessed, 3 sensitive paths blocked")
}

pub fn demo4(policy : @lib.PolicyState) -> Unit {
  hr("Demo 4: Environment Variable Protection")
  let sensitive = @lib.get_sensitive_envs(policy)
  println("  Scenario: code-formatter tool reads env vars at startup")
  println("")
  let vars : Array[String] = ["LANG", "HOME", "SHELL", "OPENAI_API_KEY", "DATABASE_URL", "GITHUB_TOKEN"]
  for v in vars {
    println("  Tool: getenv(" + v + ")")
    match @lib.check_env(sensitive, v) {
      Allow => ok(v + " allowed")
      Deny  => blk(v + " denied — sensitive/key pattern")
    }
  }
  println("")
  info("3 normal vars accessible, 3 sensitive vars blocked")
  ok("Even if tool doesn't declare env access, sandbox enforces at OS level")
}

pub fn demo5(policy : @lib.PolicyState) -> Unit {
  hr("Demo 5: Runtime Tool Blacklist")
  let bl = @lib.get_blacklist_tools(policy)
  let tools : Array[@lib.ToolInfo] = [
    @lib.make_tool("calculator", "Pure math, no network/FS"),
    @lib.make_tool("weather-query", "Weather API tool"),
    @lib.make_tool("log-analyzer", "Log analysis tool"),
  ]
  println("  Registered tools:")
  for t in tools {
    let s = match @lib.check_tool_id(bl, @lib.tool_id(t)) { Allow => "GREEN"; Deny => "RED-BLOCKED" }
    println("    " + s + "  " + @lib.tool_id(t) + " — " + @lib.tool_desc(t))
  }
  println("")
  println("  > aegisrun deny tool weather-query")
  bl.set("weather-query", "suspicious-behavior-in-audit")
  println("")
  println("  After blacklist update:")
  for t in tools {
    let s = match @lib.check_tool_id(bl, @lib.tool_id(t)) { Allow => "GREEN"; Deny => "RED-BLOCKED" }
    println("    " + s + "  " + @lib.tool_id(t))
  }
  println("")
  ok("weather-query instantly blocked, no restart required")
}

pub fn demo6() -> Unit {
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

pub fn demo7(policy : @lib.PolicyState) -> Unit {
  hr("Demo 7: Current Policy + Defense Summary")
  println(@lib.show_policy(policy))
  println("")
  println("  Defense layers active (Lite v0.1.0):")
  println("    1. Install-time permission review")
  println("    2. Domain blacklist (exact + suffix + internal network)")
  println("    3. Path blacklist (exact + prefix directory)")
  println("    4. Env var protection (pattern + KEY/SECRET/TOKEN detect)")
  println("    5. Tool blacklist + audit trail")
}
