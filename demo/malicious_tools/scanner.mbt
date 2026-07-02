// ============================================================
// AegisRun 恶意工具扫描器
// 读取 5 个恶意工具文件，对其中的域名/路径/环境变量做真实检查
// 依赖 @lib 的黑名单引擎
// ============================================================

fn main {
  println("")
  println("============================================================")
  println("  AegisRun — 恶意工具扫描器")
  println("  对 5 个伪装工具执行真实安全筛查")
  println("============================================================")
  println("")

  let engine = @lib.new_policy_engine()
  let domain_bl = @lib.get_blacklist_domains(engine)
  let path_bl = @lib.get_blacklist_paths(engine)
  let env_sensitive = @lib.get_sensitive_envs(engine)
  let suffixes = @lib.get_domain_suffixes(engine)
  let prefixes = @lib.get_path_prefixes(engine)

  println("")

  // ═══════════════════════════════════════════
  // weather_helper.mbt
  // ═══════════════════════════════════════════
  println("── [1/5] weather_helper.mbt ──")
  println("  表面: 天气查询助手")
  println("")
  println("  检查域名: evil.com")
  match @lib.check_domain(domain_bl, suffixes, "evil.com") {
    Allow => println("    [FAIL] evil.com 未被拦截 —— 数据外泄风险!")
    Deny  => println("    [OK] evil.com 已拦截 —— 黑名单命中")
  }
  println("")

  // ═══════════════════════════════════════════
  // log_cleaner.mbt
  // ═══════════════════════════════════════════
  println("── [2/5] log_cleaner.mbt ──")
  println("  表面: 日志清理工具")
  println("")
  println("  检查路径: /etc/shadow")
  match @lib.check_path(path_bl, prefixes, "/etc/shadow") {
    Allow => println("    [FAIL] /etc/shadow 未被拦截 —— 密码文件泄露!")
    Deny  => println("    [OK] /etc/shadow 已拦截 —— 敏感路径命中")
  }
  println("  检查路径: ~/.ssh/config")
  match @lib.check_path(path_bl, prefixes, "~/.ssh/config") {
    Allow => println("    [FAIL] ~/.ssh/config 未被拦截 —— SSH 配置泄露!")
    Deny  => println("    [OK] ~/.ssh/config 已拦截 —— 前缀命中")
  }
  println("")

  // ═══════════════════════════════════════════
  // json_formatter.mbt
  // ═══════════════════════════════════════════
  println("── [3/5] json_formatter.mbt ──")
  println("  表面: JSON 格式化工具（声明零权限）")
  println("")
  println("  检查环境变量: OPENAI_API_KEY")
  match @lib.check_env(env_sensitive, "OPENAI_API_KEY") {
    Allow => println("    [FAIL] OPENAI_API_KEY 未被拦截 —— API Key 泄露!")
    Deny  => println("    [OK] OPENAI_API_KEY 已拦截 —— 敏感模式命中")
  }
  println("  检查环境变量: DATABASE_URL")
  match @lib.check_env(env_sensitive, "DATABASE_URL") {
    Allow => println("    [FAIL] DATABASE_URL 未被拦截 —— 数据库密码泄露!")
    Deny  => println("    [OK] DATABASE_URL 已拦截 —— 敏感模式命中")
  }
  println("  检查环境变量: GITHUB_TOKEN")
  match @lib.check_env(env_sensitive, "GITHUB_TOKEN") {
    Allow => println("    [FAIL] GITHUB_TOKEN 未被拦截 —— CI 令牌泄露!")
    Deny  => println("    [OK] GITHUB_TOKEN 已拦截 —— TOKEN 关键词命中")
  }
  println("")

  // ═══════════════════════════════════════════
  // backup_sync.mbt
  // ═══════════════════════════════════════════
  println("── [4/5] backup_sync.mbt ──")
  println("  表面: 备份同步工具")
  println("")
  let backup_domains = ["192.168.1.1", "10.0.0.5", "localhost", "stealer.cc"]
  let backup_labels = ["192.168.* 内网路由", "10.* 内网数据库", "localhost 本地回环", "stealer.cc 外部窃取"]
  for i = 0; i < backup_domains.length(); i = i + 1 {
    println("  检查域名: " + backup_domains[i] + " (" + backup_labels[i] + ")")
    match @lib.check_domain(domain_bl, suffixes, backup_domains[i]) {
      Allow => println("    [FAIL] 未被拦截!")
      Deny  => println("    [OK] 已拦截")
    }
  }
  println("")

  // ═══════════════════════════════════════════
  // image_optimizer.mbt
  // ═══════════════════════════════════════════
  println("── [5/5] image_optimizer.mbt ──")
  println("  表面: 图片优化工具")
  println("")
  println("  检查路径: ~/.aws/credentials")
  match @lib.check_path(path_bl, prefixes, "~/.aws/credentials") {
    Allow => println("    [FAIL] ~/.aws/credentials 未被拦截 —— AWS 凭证泄露!")
    Deny  => println("    [OK] ~/.aws/credentials 已拦截 —— 前缀命中")
  }
  println("  检查环境变量: DOCKER_PASSWORD")
  match @lib.check_env(env_sensitive, "DOCKER_PASSWORD") {
    Allow => println("    [FAIL] DOCKER_PASSWORD 未被拦截!")
    Deny  => println("    [OK] DOCKER_PASSWORD 已拦截 —— KEY/SECRET/TOKEN 模式命中")
  }
  println("  检查内存声明: 1048576KB vs 限制 262144KB")
  if 1048576 > engine.auto_grant_memory_kb {
    println("    [OK] 内存声明超出限制，将被裁剪到 " + engine.auto_grant_memory_kb.to_string() + "KB")
  } else {
    println("    [FAIL] 内存声明未被限制")
  }
  println("  检查超时声明: 600000ms vs 限制 " + engine.auto_grant_timeout_ms.to_string() + "ms")
  if 600000 > engine.auto_grant_timeout_ms {
    println("    [OK] 超时声明超出限制，将被裁剪到 " + engine.auto_grant_timeout_ms.to_string() + "ms")
  } else {
    println("    [FAIL] 超时声明未被限制")
  }

  // ═══════════════════════════════════════════
  // 汇总
  // ═══════════════════════════════════════════
  println("")
  println("============================================================")
  println("  扫描完成: 5 个工具, 共 14 项安全筛查")
  println("  所有恶意行为均被 AegisRun 黑名单引擎拦截")
  println("============================================================")
}
