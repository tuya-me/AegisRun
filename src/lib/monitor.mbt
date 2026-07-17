// ============================================================
// AegisRun v1.4 — Pressure Monitor + Circuit Breaker
// 四级响应: 正常 → 预警 → 降级 → 熔断
// ============================================================

///|
pub enum MonitorLevel {
  Normal
  Warning
  Degraded
  Critical
} derive(Eq, Show, Debug)

///|
pub struct MonitorConfig {
  warning_threshold_pct : Int // 默认 70
  degraded_threshold_pct : Int // 默认 85
  critical_threshold_pct : Int // 默认 95
  sustained_seconds : Int // 持续超过阈值才触发（秒）
  recovery_seconds : Int // 低于阈值多久恢复（秒）
}

///|
pub struct PressureMonitor {
  config : MonitorConfig
  mut cpu_pct : Int
  mut mem_pct : Int
  mut instance_count : Int
  mut queue_depth : Int
  mut avg_response_ms : Int
  mut denial_rate_per_min : Int
  mut current_level : MonitorLevel
  mut level_duration_sec : Int
  mut circuit_open : Bool // 熔断器状态
  mut total_killed : Int // 被熔断杀掉的工具数
}

// ── 创建监控器 ──

///|
pub fn new_monitor(config : MonitorConfig) -> PressureMonitor {
  {
    config,
    cpu_pct: 0,
    mem_pct: 0,
    instance_count: 0,
    queue_depth: 0,
    avg_response_ms: 0,
    denial_rate_per_min: 0,
    current_level: Normal,
    level_duration_sec: 0,
    circuit_open: false,
    total_killed: 0,
  }
}

///|
pub fn default_monitor() -> PressureMonitor {
  new_monitor({
    warning_threshold_pct: 70,
    degraded_threshold_pct: 85,
    critical_threshold_pct: 95,
    sustained_seconds: 30,
    recovery_seconds: 60,
  })
}

// ── 更新指标（由外部定时器调用）──

///|
pub fn PressureMonitor::update_metrics(
  self : PressureMonitor,
  cpu_pct : Int,
  mem_pct : Int,
  instances : Int,
  queue : Int,
  avg_ms : Int,
  denial_rate : Int,
  elapsed_secs : Int, // ponytail: 由调用方传入实际经过秒数
) -> Unit {
  self.cpu_pct = cpu_pct
  self.mem_pct = mem_pct
  self.instance_count = instances
  self.queue_depth = queue
  self.avg_response_ms = avg_ms
  self.denial_rate_per_min = denial_rate

  // 计算资源占用率（取 CPU 和内存的较大值）
  let pressure = if cpu_pct > mem_pct { cpu_pct } else { mem_pct }

  let new_level = classify_pressure(pressure, self.config)
  if new_level != self.current_level {
    self.current_level = new_level
    self.level_duration_sec = 0
  } else {
    self.level_duration_sec = self.level_duration_sec + elapsed_secs
  }

  // 熔断器逻辑
  match self.current_level {
    Critical =>
      if self.level_duration_sec >= self.config.sustained_seconds {
        self.circuit_open = true
      }
    _ =>
      if self.circuit_open &&
        self.level_duration_sec >= self.config.recovery_seconds {
        self.circuit_open = false
      }
  }
}

///|
fn classify_pressure(pressure : Int, config : MonitorConfig) -> MonitorLevel {
  if pressure >= config.critical_threshold_pct {
    Critical
  } else if pressure >= config.degraded_threshold_pct {
    Degraded
  } else if pressure >= config.warning_threshold_pct {
    Warning
  } else {
    Normal
  }
}

// ── 获取当前级别 —— 调用方据此决定行为 ──

///|
pub fn PressureMonitor::get_level(self : PressureMonitor) -> MonitorLevel {
  self.current_level
}

///|
pub fn PressureMonitor::level_code(self : PressureMonitor) -> Int {
  match self.current_level {
    Normal => 0
    Warning => 1
    Degraded => 2
    Critical => 3
  }
}

///|
pub fn PressureMonitor::is_circuit_open(self : PressureMonitor) -> Bool {
  self.circuit_open
}

// ── 获取当前行为 ──

///|
pub fn PressureMonitor::get_action(self : PressureMonitor) -> String {
  if self.circuit_open {
    return "CIRCUIT_OPEN: reject all new calls, kill non-critical tools, clear queue"
  }
  match self.current_level {
    Normal => "ALLOW: normal operation"
    Warning => "WARN: accept all, send notification"
    Degraded =>
      "DEGRADE: stop accepting new calls, reject low-priority queue items"
    Critical =>
      "CRITICAL: reject all new calls, kill all non-critical tools, clear queue"
  }
}

// ── 杀工具（熔断时）──

///|
pub fn PressureMonitor::kill_tool(
  self : PressureMonitor,
  tool_id : String,
) -> Unit {
  println("    [MONITOR] Circuit breaker killing tool: " + tool_id)
  self.total_killed = self.total_killed + 1
}

// ── 统计面板 ──

///|
pub fn PressureMonitor::monitor_dashboard(self : PressureMonitor) -> String {
  let level_str = match self.current_level {
    Normal => "GREEN"
    Warning => "YELLOW"
    Degraded => "ORANGE"
    Critical => "RED"
  }
  let mut r = ""
  r = r + "=== AegisRun Monitor ===\n"
  r = r + "CPU: " + self.cpu_pct.to_string() + "%\n"
  r = r + "MEM: " + self.mem_pct.to_string() + "%\n"
  r = r + "Instances: " + self.instance_count.to_string() + "\n"
  r = r + "Queue: " + self.queue_depth.to_string() + "\n"
  r = r + "Avg Response: " + self.avg_response_ms.to_string() + "ms\n"
  r = r + "Denial Rate: " + self.denial_rate_per_min.to_string() + "/min\n"
  r = r + "Level: [" + level_str + "]"
  r = r + " (duration: " + self.level_duration_sec.to_string() + "s)\n"
  r = r +
    "Circuit Breaker: " +
    (if self.circuit_open { "OPEN" } else { "CLOSED" }) +
    "\n"
  r = r + "Tools Killed: " + self.total_killed.to_string() + "\n"
  r = r + "Action: " + self.get_action()
  r
}

// ── 模拟压力场景（演示用）──

///|
pub fn PressureMonitor::simulate_pressure(
  self : PressureMonitor,
  cpu : Int,
  mem : Int,
) -> Unit {
  // 更新快速版本（duration 视为已持续）
  self.cpu_pct = cpu
  self.mem_pct = mem
  let pressure = if cpu > mem { cpu } else { mem }
  self.current_level = classify_pressure(pressure, self.config)
}

///|
test "monitor_default_normal" {
  let m = default_monitor()
  assert_eq(m.get_level(), Normal)
  assert_eq(m.level_code(), 0)
  assert_eq(m.is_circuit_open(), false)
}

///|
test "monitor_classify_pressure_thresholds" {
  let config = { warning_threshold_pct: 70, degraded_threshold_pct: 85, critical_threshold_pct: 95, sustained_seconds: 30, recovery_seconds: 60 }
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
  assert_eq(PressureMonitor::get_action(m), "WARN: accept all, send notification")
}

///|
test "monitor_get_action_degraded" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 88, 70)
  assert_eq(PressureMonitor::get_action(m), "DEGRADE: stop accepting new calls, reject low-priority queue items")
}

///|
test "monitor_get_action_critical" {
  let m = default_monitor()
  PressureMonitor::simulate_pressure(m, 97, 80)
  assert_eq(PressureMonitor::get_action(m), "CRITICAL: reject all new calls, kill all non-critical tools, clear queue")
}

