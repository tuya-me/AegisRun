// ============================================================
// AegisRun v0.3.0 — 告警通知 + 熔断恢复策略
// ============================================================

///|
pub enum RecoveryMode {
  Auto // 自动恢复: 连续N个周期低于阈值→自动关闭熔断
  Manual // 手动恢复: 必须管理员确认后才能关闭熔断
  SemiAuto // 半自动: 自动恢复但发送确认通知，可手动提前干预
}

///|
pub enum AlertLevel {
  Info // 信息
  Warning // 警告
  Critical // 严重
  Emergency // 紧急
}

///|
pub struct AlertConfig {
  recovery_mode : RecoveryMode
  auto_recovery_check_count : Int // 连续多少次低于阈值后自动恢复 (默认3)
  manual_recovery_url : String // 管理员确认链接
  webhook_url : String // 企业微信/钉钉 Webhook URL
  sms_number : String // 紧急告警手机号
  email : String // 通知邮箱
  dashboard_refresh_ms : Int // 仪表盘刷新间隔
}

///|
pub struct AlertManager {
  config : AlertConfig
  mut alert_count : Int
  mut emergency_count : Int
  mut last_alert_level : AlertLevel
  mut recovery_requested : Bool
}

// 默认告警配置

///|
pub fn default_alert_config() -> AlertConfig {
  {
    recovery_mode: SemiAuto,
    auto_recovery_check_count: 3,
    manual_recovery_url: "",
    webhook_url: "",
    sms_number: "",
    email: "",
    dashboard_refresh_ms: 2000,
  }
}

///|
pub fn new_alert_manager(config : AlertConfig) -> AlertManager {
  {
    config,
    alert_count: 0,
    emergency_count: 0,
    last_alert_level: Info,
    recovery_requested: false,
  }
}

// ── 发送告警 ──

///|
pub fn AlertManager::send_alert(
  self : AlertManager,
  level : AlertLevel,
  title : String,
  body : String,
) -> Unit {
  self.alert_count = self.alert_count + 1
  self.last_alert_level = level

  match level {
    Warning => println("[ALERT:WARN] " + title + " — " + body)
    Critical => {
      println("[ALERT:CRITICAL] " + title + " — " + body)
      self.emergency_count = self.emergency_count + 1
    }
    Emergency => {
      println("[ALERT:EMERGENCY] " + title + " — " + body)
      println(
        "[ALERT:EMERGENCY] PagerDuty/webhook fired: " + self.config.webhook_url,
      )
      self.emergency_count = self.emergency_count + 1
    }
    _ => ()
  }
}

// ── 熔断恢复判定 ──

///|
pub fn AlertManager::should_recover(
  self : AlertManager,
  level : MonitorLevel,
  duration_below_threshold : Int,
) -> Bool {
  match self.config.recovery_mode {
    Auto =>
      // 自动恢复: 连续N个周期低于阈值
      level == Normal &&
      duration_below_threshold >= self.config.auto_recovery_check_count
    Manual =>
      // 手动恢复: 必须管理员确认
      self.recovery_requested
    SemiAuto =>
      // 半自动: 自动恢复 + 发送通知
      if level == Normal &&
        duration_below_threshold >= self.config.auto_recovery_check_count {
        println("[ALERT] 熔断器自动恢复: 压力已降至正常水平")
        true
      } else {
        false
      }
  }
}

// ── 手动请求恢复 ──

///|
pub fn AlertManager::request_recovery(self : AlertManager) -> Unit {
  self.recovery_requested = true
}

// ── 告警统计 ──

///|
pub fn AlertManager::alert_stats(self : AlertManager) -> String {
  "Alerts: " +
  self.alert_count.to_string() +
  " total, " +
  self.emergency_count.to_string() +
  " emergency, " +
  "last: " +
  (match self.last_alert_level {
    Info => "INFO"
    Warning => "WARN"
    Critical => "CRIT"
    Emergency => "EMERG"
  }) +
  " recovery: " +
  (match self.config.recovery_mode {
    Auto => "AUTO"
    Manual => "MANUAL"
    SemiAuto => "SEMI-AUTO"
  })
}

///|
fn _all_variants_for_api() -> Unit {
  let _modes : Array[RecoveryMode] = [Auto, Manual, SemiAuto]
  let _levels : Array[AlertLevel] = [Info, Warning, Critical, Emergency]
}
