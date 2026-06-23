// ============================================================
// AegisRun v1.1 — Risk Scoring Engine
// 安装前对工具声明做静态风险打分 (0-100)
// ============================================================

pub enum RiskLevel {
  Safe       // >= 90
  Warning    // 60-89
  Dangerous  // 30-59
  Critical   // < 30
}

pub struct RiskReport {
  tool_id : String
  tool_author : String
  score : Int
  level : RiskLevel
  deductions : Array[Deduction]  // 扣分明细
  total_checks : Int
  recommendation : String
}

pub struct Deduction {
  category : String       // "network" | "filesystem" | "env" | "combo" | "author" | "resource"
  points : Int            // 扣分
  reason : String         // 为什么扣分
  severity : String       // "high" | "medium" | "low"
}

// ── 主入口：对工具声明打分 ──
pub fn score_manifest(
  tool_id : String,
  author : String,
  author_is_new : Bool,          // 首次发布？
  declared_domains : Array[String],
  declared_paths : Array[String],
  declared_path_perms : Array[String],  // "read" | "write" per entry
  declared_envs : Array[String],
  declared_timeout_ms : Int,
  declared_memory_kb : Int,
) -> RiskReport {
  let mut score = 100
  let deductions : Array[Deduction] = []
  let mut total_checks = 0

  // ── 1. 网络域名检查 ──
  let mut has_wildcard_domain = false
  for d in declared_domains {
    total_checks = total_checks + 1
    if d == "*" {
      score = score - 30
      deductions.push({ category: "network", points: 30,
        reason: "通配符域名 '*' 申请访问全部网络", severity: "high" })
      has_wildcard_domain = true
    } else if d.has_prefix("*.") {
      score = score - 15
      deductions.push({ category: "network", points: 15,
        reason: "后缀通配域名 '" + d + "' 覆盖范围过大", severity: "medium" })
      has_wildcard_domain = true
    } else if d.contains("*") {
      score = score - 10
      deductions.push({ category: "network", points: 10,
        reason: "域名含通配符 '" + d + "'", severity: "medium" })
    }
  }

  // ── 2. 文件路径检查 ──
  let mut has_write = false
  for i = 0; i < declared_paths.length(); i = i + 1 {
    total_checks = total_checks + 1
    let p = declared_paths[i]
    let perm = if i < declared_path_perms.length() { declared_path_perms[i] } else { "read" }

    if p == "/" || p == "C:\\" || p == "~" {
      score = score - 30
      deductions.push({ category: "filesystem", points: 30,
        reason: "根目录访问 '" + p + "' 权限过大", severity: "high" })
    } else if p.has_prefix("/etc/") || p.has_prefix("C:\\Windows\\") {
      score = score - 20
      deductions.push({ category: "filesystem", points: 20,
        reason: "系统目录访问 '" + p + "' 存在风险", severity: "high" })
    }

    if perm == "write" || perm == "readwrite" {
      has_write = true
    }
  }

  // ── 3. 环境变量检查 ──
  for e in declared_envs {
    total_checks = total_checks + 1
    let upper = e.to_upper()
    if upper.contains("KEY") || upper.contains("SECRET") || upper.contains("TOKEN") || upper.contains("PASSWORD") {
      score = score - 20
      deductions.push({ category: "env", points: 20,
        reason: "申请密钥类环境变量 '" + e + "'", severity: "high" })
    } else if upper.contains("DATABASE") || upper.contains("REDIS") {
      score = score - 15
      deductions.push({ category: "env", points: 15,
        reason: "申请数据库连接变量 '" + e + "'", severity: "medium" })
    }
  }

  // ── 4. 组合危险检测 ──
  total_checks = total_checks + 1
  if has_write && declared_domains.length() > 0 {
    score = score - 20
    deductions.push({ category: "combo", points: 20,
      reason: "同时申请文件写入 + 网络访问（数据外泄风险）", severity: "high" })
  }
  if has_wildcard_domain && declared_envs.length() > 0 {
    score = score - 15
    deductions.push({ category: "combo", points: 15,
      reason: "通配网络 + 环境变量（凭证外泄风险）", severity: "high" })
  }

  // ── 5. 作者信誉 ──
  total_checks = total_checks + 1
  if author_is_new {
    score = score - 10
    deductions.push({ category: "author", points: 10,
      reason: "首次发布者，无历史信誉记录", severity: "medium" })
  }

  // ── 6. 资源检查 ──
  total_checks = total_checks + 1
  if declared_timeout_ms > 120000 {
    score = score - 10
    deductions.push({ category: "resource", points: 10,
      reason: "超时声明 " + declared_timeout_ms.to_string() + "ms > 120s 上限", severity: "medium" })
  } else if declared_timeout_ms > 60000 {
    score = score - 5
    deductions.push({ category: "resource", points: 5,
      reason: "超时声明 " + declared_timeout_ms.to_string() + "ms > 60s", severity: "low" })
  }
  total_checks = total_checks + 1
  if declared_memory_kb > 1048576 {
    score = score - 10
    deductions.push({ category: "resource", points: 10,
      reason: "内存声明 " + declared_memory_kb.to_string() + "KB > 1GB", severity: "medium" })
  } else if declared_memory_kb > 524288 {
    score = score - 5
    deductions.push({ category: "resource", points: 5,
      reason: "内存声明 " + declared_memory_kb.to_string() + "KB > 512MB", severity: "low" })
  }

  // ── 限制分数范围 ──
  if score < 0 { score = 0 }
  if score > 100 { score = 100 }

  let level = classify_score(score)
  let recommendation = match level {
    Safe       => "自动通过，无需审查"
    Warning    => "建议人工审查后安装"
    Dangerous  => "需手动输入确认后才能安装"
    Critical   => "自动拒绝安装"
  }

  { tool_id, tool_author: author, score, level, deductions, total_checks, recommendation }
}

fn classify_score(score : Int) -> RiskLevel {
  if score >= 90 { Safe }
  else if score >= 60 { Warning }
  else if score >= 30 { Dangerous }
  else { Critical }
}

// ── 格式化报告 ──
pub fn format_report(report : RiskReport) -> String {
  let mut r = ""
  let icon = match report.level {
    Safe => "GREEN"
    Warning => "YELLOW"
    Dangerous => "ORANGE"
    Critical => "RED"
  }
  r = r + "Risk Report: " + report.tool_id + " (by " + report.tool_author + ")\n"
  r = r + "Score: " + report.score.to_string() + "/100 [" + icon + "]\n"
  r = r + "Level: " + icon + "\n"
  r = r + "Deductions: " + report.deductions.length().to_string() + " items\n"
  for d in report.deductions {
    r = r + "  [" + d.severity + "] -" + d.points.to_string() + " " + d.category + ": " + d.reason + "\n"
  }
  r = r + "Checks performed: " + report.total_checks.to_string() + "\n"
  r = r + "Recommendation: " + report.recommendation
  r
}
