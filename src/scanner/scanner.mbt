// AegisRun 恶意工具扫描器 —— 调用 @lib 黑名单引擎做安全筛查
fn main {
  println("")
  println("============================================================")
  println("  AegisRun — 恶意工具扫描器")
  println("  5 个伪装工具的隐藏恶意行为 → 真实黑名单检查")
  println("============================================================")
  println("")

  let engine = @lib.new_policy_engine()
  let domain_bl = @lib.get_blacklist_domains(engine)
  let path_bl = @lib.get_blacklist_paths(engine)
  let env_sensitive = @lib.get_sensitive_envs(engine)
  let suffixes = @lib.get_domain_suffixes(engine)
  let prefixes = @lib.get_path_prefixes(engine)

  let mut ok = 0
  let mut fail = 0

  // ── 1. weather_helper → 向 evil.com 外泄数据 ──
  println("── [1/5] weather_helper.mbt: 偷偷外泄用户位置到 evil.com ──")
  match @lib.check_domain(domain_bl, suffixes, "evil.com") {
    Allow => { println("    [FAIL] evil.com 未被拦截"); fail = fail + 1 }
    Deny  => { println("    [OK] evil.com 黑名单命中"); ok = ok + 1 }
  }
  println("")

  // ── 2. log_cleaner → 读 /etc/shadow 和 ~/.ssh/config ──
  println("── [2/5] log_cleaner.mbt: 假装清理日志，实读系统密码文件 ──")
  match @lib.check_path(path_bl, prefixes, "/etc/shadow") {
    Allow => { println("    [FAIL] /etc/shadow 未被拦截"); fail = fail + 1 }
    Deny  => { println("    [OK] /etc/shadow 敏感路径命中"); ok = ok + 1 }
  }
  match @lib.check_path(path_bl, prefixes, "~/.ssh/config") {
    Allow => { println("    [FAIL] ~/.ssh/config 未被拦截"); fail = fail + 1 }
    Deny  => { println("    [OK] ~/.ssh/config 前缀命中"); ok = ok + 1 }
  }
  println("")

  // ── 3. json_formatter → 偷 API Key ──
  println("── [3/5] json_formatter.mbt: JSON工具偷读 3 个密钥 ──")
  let env_vars = ["OPENAI_API_KEY", "DATABASE_URL", "GITHUB_TOKEN"]
  for v in env_vars {
    match @lib.check_env(env_sensitive, v) {
      Allow => { println("    [FAIL] " + v + " 未被拦截"); fail = fail + 1 }
      Deny  => { println("    [OK] " + v + " 敏感变量命中"); ok = ok + 1 }
    }
  }
  println("")

  // ── 4. backup_sync → 内网扫描 + 外泄 ──
  println("── [4/5] backup_sync.mbt: 扫描内网并外泄到 stealer.cc ──")
  let bad_urls = ["192.168.1.1", "10.0.0.5", "localhost", "stealer.cc"]
  for d in bad_urls {
    match @lib.check_domain(domain_bl, suffixes, d) {
      Allow => { println("    [FAIL] " + d + " 未被拦截"); fail = fail + 1 }
      Deny  => { println("    [OK] " + d + " 黑名单命中"); ok = ok + 1 }
    }
  }
  println("")

  // ── 5. image_optimizer → 偷 AWS + Docker + 超量资源 ──
  println("── [5/5] image_optimizer.mbt: 偷凭证 + 资源滥用 ──")
  match @lib.check_path(path_bl, prefixes, "~/.aws/credentials") {
    Allow => { println("    [FAIL] ~/.aws/credentials 未被拦截"); fail = fail + 1 }
    Deny  => { println("    [OK] ~/.aws/credentials 前缀命中"); ok = ok + 1 }
  }
  match @lib.check_env(env_sensitive, "DOCKER_PASSWORD") {
    Allow => { println("    [FAIL] DOCKER_PASSWORD 未被拦截"); fail = fail + 1 }
    Deny  => { println("    [OK] DOCKER_PASSWORD 模式命中"); ok = ok + 1 }
  }
  if 1048576 > engine.auto_grant_memory_kb {
    println("    [OK] 内存 1048576KB > 限制 " + engine.auto_grant_memory_kb.to_string() + "KB"); ok = ok + 1
  } else { println("    [FAIL] 内存未限制"); fail = fail + 1 }
  if 600000 > engine.auto_grant_timeout_ms {
    println("    [OK] 超时 600000ms > 限制 " + engine.auto_grant_timeout_ms.to_string() + "ms"); ok = ok + 1
  } else { println("    [FAIL] 超时未限制"); fail = fail + 1 }

  println("")
  println("============================================================")
  println("  结果: " + ok.to_string() + " 项拦截成功 / " + fail.to_string() + " 项失败")
  if fail == 0 {
    println("  结论: 5 个工具的所有隐藏恶意行为被黑名单引擎检出")
  } else {
    println("  警告: " + fail.to_string() + " 个漏网项")
  }
  println("============================================================")
}
