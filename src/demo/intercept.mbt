// ============================================================
// AegisRun 恶意工具拦截演示 — 库实际调用
// 选攻击 → @lib 真实拦截 → 显示结果
// ============================================================
// 用法:
//   set AEGISRUN_ATTACKS=1,3,7,12
//   moon run src/generator/intercept.mbt
// ============================================================

///|
pub fn run_intercept_demo() -> Unit {
  let attacks = match @env.get_env_var("AEGISRUN_ATTACKS") {
    Some(v) => v
    None => "all"
  }

  // 加载 AegisRun 引擎
  let policy = @lib.new_policy_engine()
  let domain_bl = @lib.get_blacklist_domains(policy)
  let path_bl = @lib.get_blacklist_paths(policy)
  let env_sensitive = @lib.get_sensitive_envs(policy)
  let suffixes = @lib.get_domain_suffixes(policy)
  let ip_prefixes = @lib.get_ip_prefixes(policy)
  let prefixes = @lib.get_path_prefixes(policy)
  let _sb = @lib.standard_sandbox()
  let ip_bl = @lib.new_ip_blacklist()

  let mut caught = 0
  let mut missed = 0

  println("")
  println("============================================================")
  println("  AegisRun INTERCEPT Demo — Live Library Calls")
  println("  Attacks selected: " + attacks)
  println("============================================================")
  println("")

  // ═══ Attack 1: evil.com ═══
  if has_attack(attacks, "1") {
    println("-- Attack 1: evil.com exfiltration --")
    println("  Tool attempts: POST https://evil.com/collect?data=x")
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "evil.com") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] evil.com in blacklist — HTTP request never sent")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED] evil.com was allowed!")
      }
    }
    println("")
  }

  // ═══ Attack 2: *.cn suffix ═══
  if has_attack(attacks, "2") {
    println("-- Attack 2: *.cn suffix exfiltration --")
    println("  Tool attempts: POST https://data-harvest.cn/store")
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "data-harvest.cn") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] *.cn suffix matched — sandbox intercept")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 3: internal IP ═══
  if has_attack(attacks, "3") {
    println("-- Attack 3: Internal network scan --")
    println("  Tool attempts: GET http://192.168.1.100:8080/admin")
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "192.168.1.100") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] 192.168.* internal network — blocked")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    match @lib.check_ip(ip_bl, "192.168.1.100") {
      Err(e) => {
        caught = caught + 1
        println("  [BLOCKED] IP blacklist also: " + e)
      }
      Ok(_) => println("  [INFO] IP check passed (domain already blocked)")
    }
    println("")
  }

  // ═══ Attack 4: /etc/passwd ═══
  if has_attack(attacks, "4") {
    println("-- Attack 4: /etc/passwd file theft --")
    println("  Tool attempts: open(/etc/passwd)")
    match @lib.check_path(path_bl, prefixes, "/etc/passwd") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] /etc/passwd in path blacklist — file not opened")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 5: SSH key ═══
  if has_attack(attacks, "5") {
    println("-- Attack 5: SSH key theft --")
    println("  Tool attempts: open(~/.ssh/id_rsa)")
    match @lib.check_path(path_bl, prefixes, "~/.ssh/id_rsa") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] ~/.ssh/ prefix matched — SSH key protected")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 6: Windows SAM ═══
  if has_attack(attacks, "6") {
    println("-- Attack 6: Windows SAM access --")
    println("  Tool attempts: open(C:\\Windows\\System32\\config\\SAM)")
    match
      @lib.check_path(path_bl, prefixes, "C:\\Windows\\System32\\config\\SAM") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] C:\\Windows\\ prefix matched — SAM protected")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 7: OPENAI_API_KEY ═══
  if has_attack(attacks, "7") {
    println("-- Attack 7: OpenAI API key theft --")
    println("  Tool attempts: getenv(OPENAI_API_KEY)")
    match @lib.check_env(env_sensitive, "OPENAI_API_KEY") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] API_KEY pattern matched — credential protected")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 8: DATABASE_URL ═══
  if has_attack(attacks, "8") {
    println("-- Attack 8: Database credential theft --")
    println("  Tool attempts: getenv(DATABASE_URL)")
    match @lib.check_env(env_sensitive, "DATABASE_URL") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] DATABASE_URL pattern matched")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 9: stealer.cc ═══
  if has_attack(attacks, "9") {
    println("-- Attack 9: stealer.cc exfiltration --")
    println("  Tool attempts: POST https://stealer.cc/api/upload")
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "stealer.cc") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] stealer.cc in blacklist")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 10: localhost ═══
  if has_attack(attacks, "10") {
    println("-- Attack 10: Localhost attack --")
    println("  Tool attempts: GET http://localhost:3000/admin")
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "localhost") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] localhost in blacklist — SSRF prevented")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 11: GITHUB_TOKEN ═══
  if has_attack(attacks, "11") {
    println("-- Attack 11: CI token theft --")
    println("  Tool attempts: getenv(GITHUB_TOKEN)")
    match @lib.check_env(env_sensitive, "GITHUB_TOKEN") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] TOKEN keyword detected — CI token protected")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED]")
      }
    }
    println("")
  }

  // ═══ Attack 12: AWS + evil.com combo ═══
  if has_attack(attacks, "12") {
    println("-- Attack 12: AWS credential + exfiltration combo --")
    println("  Tool attempts: open(~/.aws/credentials) then POST evil.com")
    match @lib.check_path(path_bl, prefixes, "~/.aws/credentials") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] ~/.aws/ prefix — credentials protected")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED] ~/.aws/")
      }
    }
    match @lib.check_domain(domain_bl, suffixes, ip_prefixes, "evil.com") {
      Deny => {
        caught = caught + 1
        println("  [BLOCKED] evil.com — exfiltration blocked")
      }
      Allow => {
        missed = missed + 1
        println("  [MISSED] evil.com")
      }
    }
    println("")
  }

  // ═══ Summary ═══
  println("============================================================")
  println("  Interception Results")
  println(
    "  Caught: " + caught.to_string() + "  |  Missed: " + missed.to_string(),
  )
  if missed == 0 {
    println("  VERDICT: All malicious behaviors intercepted by AegisRun")
  } else {
    println("  WARNING: " + missed.to_string() + " attack(s) evaded detection")
  }
  println("============================================================")

  // ═══ Dashboard ═══
  let dash = @lib.default_dashboard()
  dash.toggle_web_panel()
  println("")
  println(
    dash.render_terminal(45, 62, 67, 100, 12, 200, caught, "Normal", false),
  )
}

///|
fn has_attack(selection : String, num : String) -> Bool {
  if selection == "all" {
    return true
  }
  selection.contains(num)
}
