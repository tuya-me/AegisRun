// ============================================================
// AegisRun Pressure Monitor Tests
// ============================================================

///|
test "monitor_default_normal" {
  let m = default_monitor()
  assert_eq(m.get_level(), Normal)
  assert_eq(m.level_code(), 0)
  assert_eq(m.is_circuit_open(), false)
}

///|
test "monitor_classify_pressure_thresholds" {
  let config = {
    warning_threshold_pct: 70,
    degraded_threshold_pct: 85,
    critical_threshold_pct: 95,
    sustained_seconds: 30,
    recovery_seconds: 60,
  }
  assert_eq(classify_pressure(50, config), Normal)
  assert_eq(classify_pressure(69, config), Normal)
  assert_eq(classify_pressure(70, config), Warning)
  assert_eq(classify_pressure(84, config), Warning)
  assert_eq(classify_pressure(85, config), Degraded)
  assert_eq(classify_pressure(94, config), Degraded)
  assert_eq(classify_pressure(95, config), Critical)
  assert_eq(classify_pressure(100, config), Critical)
}

///|
test "monitor_warning_transition" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 75, 60, 5, 10, 100, 2, 10)
  assert_eq(m.get_level(), Warning)
  assert_eq(m.level_code(), 1)
}

///|
test "monitor_degraded_transition" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 88, 70, 10, 20, 200, 5, 10)
  assert_eq(m.get_level(), Degraded)
  assert_eq(m.level_code(), 2)
}

///|
test "monitor_critical_transition" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 96, 80, 20, 50, 500, 10, 10)
  assert_eq(m.get_level(), Critical)
  assert_eq(m.level_code(), 3)
}

///|
test "monitor_circuit_breaker_opens_after_sustained_critical" {
  let m = new_monitor({
    warning_threshold_pct: 70,
    degraded_threshold_pct: 85,
    critical_threshold_pct: 95,
    sustained_seconds: 30,
    recovery_seconds: 60,
  })
  PressureMonitor::update_metrics(m, 97, 90, 20, 50, 500, 10, 20)
  assert_eq(m.is_circuit_open(), false)
  PressureMonitor::update_metrics(m, 98, 92, 20, 50, 500, 10, 15)
  assert_eq(m.is_circuit_open(), true)
}

///|
test "monitor_circuit_breaker_closes_after_recovery" {
  let m = new_monitor({
    warning_threshold_pct: 70,
    degraded_threshold_pct: 85,
    critical_threshold_pct: 95,
    sustained_seconds: 10,
    recovery_seconds: 20,
  })
  PressureMonitor::update_metrics(m, 97, 90, 20, 50, 500, 10, 15)
  assert_eq(m.is_circuit_open(), true)
  PressureMonitor::update_metrics(m, 30, 20, 5, 2, 50, 0, 25)
  assert_eq(m.is_circuit_open(), false)
}

///|
test "monitor_kill_tool_increments" {
  let m = default_monitor()
  PressureMonitor::kill_tool(m, "tool-a")
  PressureMonitor::kill_tool(m, "tool-b")
  PressureMonitor::kill_tool(m, "tool-c")
  let dash = m.monitor_dashboard()
  assert_eq(dash.contains("Tools Killed: 3"), true)
}

///|
test "monitor_simulate_pressure" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 50, 40)
  assert_eq(m.get_level(), Normal)
  PressureMonitor::simulate_pressure(m, 96, 50)
  assert_eq(m.get_level(), Critical)
  PressureMonitor::simulate_pressure(m, 50, 88)
  assert_eq(m.get_level(), Degraded)
}

///|
test "monitor_dashboard_contains_metrics" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 45, 60, 8, 12, 150, 3, 5)
  let dash = m.monitor_dashboard()
  assert_eq(dash.contains("CPU: 45%"), true)
  assert_eq(dash.contains("MEM: 60%"), true)
  assert_eq(dash.contains("Instances: 8"), true)
  assert_eq(dash.contains("Queue: 12"), true)
  assert_eq(dash.contains("Avg Response: 150ms"), true)
  assert_eq(dash.contains("Denial Rate: 3/min"), true)
  assert_eq(dash.contains("GREEN"), true)
  assert_eq(dash.contains("CLOSED"), true)
}

///|
test "monitor_get_action_normal" {
  let m = default_monitor()
  assert_eq(PressureMonitor::get_action(m), "ALLOW: normal operation")
}

///|
test "monitor_get_action_warning" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 75, 60)
  assert_eq(
    PressureMonitor::get_action(m),
    "WARN: accept all, send notification",
  )
}

///|
test "monitor_get_action_degraded" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 88, 70)
  assert_eq(
    PressureMonitor::get_action(m),
    "DEGRADE: stop accepting new calls, reject low-priority queue items",
  )
}

///|
test "monitor_get_action_critical" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 97, 80)
  assert_eq(
    PressureMonitor::get_action(m),
    "CRITICAL: reject all new calls, kill all non-critical tools, clear queue",
  )
}

///|
test "monitor_get_action_circuit_open" {
  let m = new_monitor({
    warning_threshold_pct: 70,
    degraded_threshold_pct: 85,
    critical_threshold_pct: 95,
    sustained_seconds: 10,
    recovery_seconds: 60,
  })
  PressureMonitor::update_metrics(m, 97, 90, 20, 50, 500, 10, 15)
  assert_eq(
    PressureMonitor::get_action(m),
    "CIRCUIT_OPEN: reject all new calls, kill non-critical tools, clear queue",
  )
}

///|
test "monitor_level_resets_duration_on_change" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 75, 60, 5, 10, 100, 2, 10)
  PressureMonitor::update_metrics(m, 75, 60, 5, 10, 100, 2, 10)
  let dash1 = m.monitor_dashboard()
  assert_eq(dash1.contains("duration: 20s"), true)
  PressureMonitor::update_metrics(m, 88, 70, 5, 10, 100, 2, 5)
  let dash2 = m.monitor_dashboard()
  assert_eq(dash2.contains("duration: 5s"), true)
}

///|
test "monitor_uses_max_of_cpu_mem" {
  let m = default_monitor()
  PressureMonitor::update_metrics(m, 50, 90, 5, 10, 100, 2, 5)
  assert_eq(m.get_level(), Critical)
  PressureMonitor::update_metrics(m, 90, 50, 5, 10, 100, 2, 5)
  assert_eq(m.get_level(), Critical)
  PressureMonitor::update_metrics(m, 50, 75, 5, 10, 100, 2, 5)
  assert_eq(m.get_level(), Warning)
}
