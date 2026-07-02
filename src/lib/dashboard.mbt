// ============================================================
// AegisRun v0.3.0 — 终端仪表盘 + Web面板开关
// ============================================================

pub struct DashboardConfig {
  mut web_panel_enabled : Bool       // Web面板开关
  web_panel_port : Int               // Web面板端口
  refresh_interval_ms : Int          // 刷新间隔
  max_log_lines : Int                // 最多显示多少行日志
}

pub struct Dashboard {
  config : DashboardConfig
  mut frame_count : Int
  log_buffer : Array[String]    // 最近N条日志
}

pub fn default_dashboard() -> Dashboard {
  { config: { web_panel_enabled: false, web_panel_port: 9090, refresh_interval_ms: 2000, max_log_lines: 20 },
    frame_count: 0, log_buffer: [] }
}

// 开启/关闭 Web 面板
pub fn toggle_web_panel(self : Dashboard) -> Unit {
  self.config.web_panel_enabled = !self.config.web_panel_enabled
  if self.config.web_panel_enabled {
    println("[DASHBOARD] Web panel started on http://localhost:" + self.config.web_panel_port.to_string())
  } else {
    println("[DASHBOARD] Web panel stopped")
  }
}

// ── 渲染终端仪表盘 ──
pub fn render_terminal(
  self : Dashboard,
  cpu_pct : Int,
  mem_pct : Int,
  slot_used : Int,
  slot_max : Int,
  queue_len : Int,
  queue_max : Int,
  blocked_today : Int,
  level_name : String,
  circuit_open : Bool,
) -> String {
  self.frame_count = self.frame_count + 1
  let mut r = ""

  // 清屏（ANSI）
  r = r + "╔══════════════════════════════════════════════════════════════╗\n"
  r = r + "║  AegisRun Dashboard     Frame: " + self.frame_count.to_string() + pad_left("", 37) + "║\n"
  r = r + "╠══════════════════════════════════════════════════════════════╣\n"
  r = r + "║  CPU " + bar(cpu_pct) + " " + pad(cpu_pct.to_string() + "%", 4) + pad_left("", 28) + "║\n"
  r = r + "║  MEM " + bar(mem_pct) + " " + pad(mem_pct.to_string() + "%", 4) + pad_left("", 28) + "║\n"
  r = r + "║  Slot" + bar_slot(slot_used, slot_max) + " " + slot_used.to_string() + "/" + slot_max.to_string() + pad_left("", 28) + "║\n"
  r = r + "║  Queue" + bar_slot(queue_len, queue_max) + " " + queue_len.to_string() + "/" + queue_max.to_string() + pad_left("", 28) + "║\n"
  r = r + "╠══════════════════════════════════════════════════════════════╣\n"
  r = r + "║  Level: " + pad(level_name, 10)
  r = r + "  Circuit: " + (if circuit_open { "OPEN" } else { "CLOSED" })
  r = r + "  Blocked: " + blocked_today.to_string() + pad_left("", 15) + "║\n"
  r = r + "╠══════════════════════════════════════════════════════════════╣\n"
  r = r + "║  Web Panel: " + (if self.config.web_panel_enabled { "ON :" + self.config.web_panel_port.to_string() } else { "OFF" }) + pad_left("", 30) + "║\n"
  r = r + "║  Refresh: " + self.config.refresh_interval_ms.to_string() + "ms" + pad_left("", 30) + "║\n"
  r = r + "╚══════════════════════════════════════════════════════════════╝\n"

  r
}

// ── 进度条渲染 ──
fn bar(pct : Int) -> String {
  let blocks = pct / 5   // 20 blocks total
  let mut s = ""
  for i = 0; i < 20; i = i + 1 {
    if i < blocks {
      if pct < 70 { s = s + "█" }
      else if pct < 85 { s = s + "▓" }
      else { s = s + "▒" }
    } else {
      s = s + "░"
    }
  }
  s
}

fn bar_slot(used : Int, max : Int) -> String {
  let blocks = if max > 0 { used * 20 / max } else { 0 }
  let mut s = ""
  for i = 0; i < 20; i = i + 1 {
    if i < blocks { s = s + "█" } else { s = s + "░" }
  }
  s
}

fn pad(s : String, width : Int) -> String {
  let mut r = s
  while r.length() < width { r = r + " " }
  r
}

fn pad_left(s : String, width : Int) -> String {
  let mut r = s
  while r.length() < width { r = " " + r }
  r
}
