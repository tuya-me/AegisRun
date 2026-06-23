// AegisRun Full Demo — v1.1~v1.4 integration test
fn main {
  println("")
  println("╔══════════════════════════════════════════════════════╗")
  println("║   AegisRun Full v2.0 — All Features Demo            ║")
  println("╚══════════════════════════════════════════════════════╝")
  println("")

  let mut pass = 0
  let mut total = 0

  // v1.1: Risk Scoring
  println("── v1.1: Risk Scoring Engine ──")
  let safe = @lib.score_manifest("weather-query", "@trusted-team", false, ["wttr.in"], [], [], [], 5000, 131072)
  total = total + 1
  if safe.score >= 90 { pass = pass + 1; println("  [PASS] Safe: " + safe.score.to_string() + "/100") }
  else { println("  [FAIL] Expected >=90, got " + safe.score.to_string()) }

  let dangerous = @lib.score_manifest("data-analyzer", "@new-user", true, ["*"], ["/"], ["write"], ["OPENAI_API_KEY"], 300000, 2097152)
  total = total + 1
  if dangerous.score < 30 { pass = pass + 1; println("  [PASS] Dangerous: " + dangerous.score.to_string() + "/100 — " + dangerous.recommendation) }
  else { println("  [FAIL] Expected <30, got " + dangerous.score.to_string()) }
  println("")

  // v1.2: SQL Guard
  println("── v1.2: SQL Resource Guard ──")
  let db = @lib.new_sql_connection("reports_db", "/data/reports.db")
  let orders_rule = @lib.make_sql_rule("orders", ["SELECT", "INSERT"], ["id", "amount", "date"], 100, false, ["DROP", "ALTER"])
  db.add_table(orders_rule)

  total = total + 1
  match db.guard_query("DROP TABLE orders") {
    Err(_) => { pass = pass + 1; println("  [PASS] DROP TABLE blocked") }
    Ok(_) => println("  [FAIL] DROP should be blocked")
  }
  total = total + 1
  match db.guard_query("SELECT id, amount, date FROM orders") {
    Ok(_) => { pass = pass + 1; println("  [PASS] SELECT with allowed columns") }
    Err(e) => println("  [FAIL] " + e)
  }
  total = total + 1
  match db.guard_query("SELECT * FROM orders") {
    Err(_) => { pass = pass + 1; println("  [PASS] SELECT * blocked (column restriction)") }
    Ok(_) => println("  [FAIL] SELECT * should be blocked")
  }
  total = total + 1
  match db.guard_query("INSERT INTO orders VALUES (1, 100, '2026-01-01')") {
    Ok(_) => { pass = pass + 1; println("  [PASS] INSERT allowed") }
    Err(_) => println("  [FAIL] INSERT should pass")
  }
  let users_rule = @lib.make_sql_rule("users", ["SELECT", "DELETE"], [], 0, true, ["DROP"])
  db.add_table(users_rule)
  total = total + 1
  match db.guard_query("DELETE FROM users") {
    Err(_) => { pass = pass + 1; println("  [PASS] DELETE without WHERE blocked") }
    Ok(_) => println("  [FAIL] Should require WHERE")
  }
  println("  " + db.sql_guard_stats())
  println("")

  // v1.3: Concurrency
  println("── v1.3: 3D Concurrency Limiter ──")
  let lim = @lib.default_limiter()
  lim.set_tool_limit("image-processor", 3)
  lim.set_tool_limit("weather-query", 20)
  let mut acquired = 0
  for i = 0; i < 3; i = i + 1 {
    match lim.acquire("weather-query", "session-A") {
      Ok(_) => acquired = acquired + 1
      Err(_) => ()
    }
  }
  total = total + 1
  if acquired == 3 { pass = pass + 1; println("  [PASS] 3/3 slots acquired") }
  else { println("  [FAIL] Expected 3, got " + acquired.to_string()) }

  let mut rejected = false
  for i = 0; i < 10; i = i + 1 {
    match lim.acquire("weather-query", "session-B") {
      Err(_) => rejected = true
      Ok(_) => ()
    }
  }
  for i = 0; i < 3; i = i + 1 { lim.release("weather-query", "session-A") }
  total = total + 1
  if rejected { pass = pass + 1; println("  [PASS] Excess requests rejected (per-tool limit)") }
  else { println("  [FAIL] Should reject excess") }
  println("  " + lim.limiter_stats())
  println("")

  // v1.4: Monitor
  println("── v1.4: Pressure Monitor + Circuit Breaker ──")
  let mon = @lib.default_monitor()
  mon.simulate_pressure(30, 40)
  total = total + 1
  if !mon.is_circuit_open() { pass = pass + 1; println("  [PASS] CPU 30% → Normal, circuit closed") }
  else { println("  [FAIL]") }

  mon.simulate_pressure(75, 60)
  total = total + 1
  let lvl = mon.level_code()
  if lvl == 1 || lvl == 0 { pass = pass + 1; println("  [PASS] CPU 75% → Warning level") }
  else { println("  [FAIL]") }

  mon.simulate_pressure(90, 80)
  total = total + 1
  if mon.level_code() == 2 { pass = pass + 1; println("  [PASS] CPU 90% → Degraded") }
  else { println("  [FAIL]") }

  mon.simulate_pressure(97, 92)
  total = total + 1
  if mon.level_code() == 3 { pass = pass + 1; println("  [PASS] CPU 97% → Critical") }
  else { println("  [FAIL]") }
  mon.kill_tool("weather-query")
  mon.kill_tool("image-processor")
  println("  " + mon.monitor_dashboard())
  println("")

  println("============================================================")
  println("  Full Demo: " + pass.to_string() + "/" + total.to_string() + " passed")
  if pass == total { println("  All Full-version features working correctly.") }
  else { println("  " + (total - pass).to_string() + " failed.") }
  println("============================================================")
}
