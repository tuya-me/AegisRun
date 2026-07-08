// AegisRun 实战演示
// 运行（需要 wasmtime）:
//   moon build --target wasm src/test-intercept
//   wasmtime run _build/wasm/debug/build/test-intercept/test-intercept.wasm

fn show_decision(r : Result[String, String]) -> String {
  match r {
    Ok(msg) => "  ✅ ALLOW: " + msg
    Err(e) => "  ❌ DENY: " + e
  }
}

fn show_decision_d(d : @lib.Decision) -> String {
  match d {
    Allow => "  ✅ ALLOW"
    Deny => "  ❌ DENY"
  }
}

fn main {
  println("╔══════════════════════════════════════════════════════╗")
  println("║        AegisRun v0.8.0 — 五层防御实战演示            ║")
  println("╠══════════════════════════════════════════════════════╣")
  println("║  第〇关: 并发限流 (limiter)                          ║")
  println("║  第〇关+: 风险评分预检 (scorer)                       ║")
  println("║  第一关: 黑名单引擎 (core.mbt)                       ║")
  println("║  第二关: DNS/IP 黑名单 (dns_guard)                   ║")
  println("║  第三关: 授权检查 (grant)                            ║")
  println("║  第五关: SQL 防护 (sql_guard)                        ║")
  println("╚══════════════════════════════════════════════════════╝")
  println("")

  // ═══════ 方式一：AegisRun 门面（一行API，五层全开）═══════
  println("━━━ 方式一：AegisRun 门面 ━━━")
  println("  一行 API，自动走五层防御")
  println("")
  let aegis = @lib.AegisRun::new("standard")

  println("  快速检查（缓存加速）：")
  println(show_decision_d(aegis.check_domain("evil.com")))
  println(show_decision_d(aegis.check_path("/etc/passwd")))
  println(show_decision_d(aegis.check_env("OPENAI_API_KEY")))

  println("")
  println("  完整五层 HTTP 检查（限流→评分→黑名单→DNS→授权）：")
  println(show_decision(aegis.check_http("https://evil.com/collect")))
  println(show_decision(aegis.check_http("https://wttr.in/Shenzhen")))

  println("")
  println(show_decision(aegis.check_http("https://stealer.cc/exfil")))

  // ═══════ 方式二：直接沙箱（精细控制）═══════
  println("")
  println("━━━ 方式二：直接沙箱 ───")
  println("  精细控制每个检查的 tool_id / session_id")
  println("")
  let sb = @lib.standard_sandbox()

  println("  HTTP 检查：")
  println(show_decision(sb.sandbox_http_request(
    "https://evil.com/collect", "tool-a", "http-sess", "")))
  println(show_decision(sb.sandbox_http_request(
    "https://192.168.1.100/admin", "tool-a", "http-sess", "192.168.1.100")))
  println(show_decision(sb.sandbox_http_request(
    "https://wttr.in/Shenzhen", "tool-a", "http-sess", "52.84.12.34")))

  println("")
  println("  文件操作检查：")
  println(show_decision(sb.sandbox_file_open(
    "/etc/passwd", "tool-b", "file-sess")))
  println(show_decision(sb.sandbox_file_open(
    "/tmp/logs/app.log", "tool-b", "file-sess")))

  println("")
  println("  环境变量检查：")
  println(show_decision(sb.sandbox_getenv(
    "OPENAI_API_KEY", "tool-c", "env-sess")))
  println(show_decision(sb.sandbox_getenv(
    "GITHUB_TOKEN", "tool-c", "env-sess")))
  println(show_decision(sb.sandbox_getenv(
    "USER", "tool-c", "env-sess")))

  println("")
  println("  SQL 查询防护：")
  println(show_decision(sb.sandbox_sql_query(
    "SELECT * FROM users", "tool-d", "sql-sess")))

  // ═══════ 统计 ═══════
  println("")
  println("━━━ 统计 ━━━")
  println("  门面统计: " + aegis.stats())
  println("  沙箱统计: " + sb.stats())
}
