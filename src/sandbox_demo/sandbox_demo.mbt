// AegisRun 沙箱层演示 —— 所有工具操作必经沙箱
fn main {
  println("")
  println("============================================================")
  println("  AegisRun — Sandbox Layer Demo")
  println("  沙箱拦截层: 工具操作的唯一出口，两关检查")
  println("  第1关: 黑名单检查 | 第2关: 授权检查")
  println("============================================================")
  println("")

  // 创建标准沙箱（standard 预设 + 默认授权）
  let sb = @lib.standard_sandbox()
  println(" 沙箱已创建")
  println(" 授权域名: wttr.in, api.github.com")
  println(" 授权路径: /tmp/reports/, /tmp/logs/")
  println(" 授权环境变量: USER, LANG, HOME")
  println(" 资源限制: 超时 30s | 内存 256MB | 文件 10MB")
  println("")

  let mut ok = 0
  let mut fail = 0

  // ═══════════════════════════════════════════
  // 网络拦截测试
  // ═══════════════════════════════════════════
  println("── 网络拦截: 工具发起 6 个 HTTP 请求 ──")
  println("")

  let urls : Array[String] = [
    "https://wttr.in/Shenzhen",
    "https://evil.com/collect",
    "https://stealer.cc/api/upload",
    "https://api.github.com/repos/test",
    "http://192.168.1.100:8080/data",
    "https://unknown-service.com/data",
  ]
  let url_desc : Array[String] = [
    "授权域名",
    "黑名单域名",
    "黑名单域名",
    "授权域名",
    "内网地址",
    "未授权的第三方",
  ]

  for i = 0; i < urls.length(); i = i + 1 {
    println("  请求: GET " + urls[i] + " (" + url_desc[i] + ")")
    match sb.sandbox_http_request( urls[i]) {
      Ok(_)  => {
        // 只放行 wttr.in 和 api.github.com，其余都应拦截
        if urls[i].contains("wttr.in") || urls[i].contains("api.github.com") {
          println("    [OK] 放行——合法请求")
          ok = ok + 1
        } else {
          println("    [FAIL] 错误放行!")
          fail = fail + 1
        }
      }
      Err(e) => {
        if urls[i].contains("wttr.in") || urls[i].contains("api.github.com") {
          println("    [FAIL] 错误拦截: " + e)
          fail = fail + 1
        } else {
          println("    [BLOCK] 沙箱拦截: " + e)
          ok = ok + 1
        }
      }
    }
  }

  println("")
  // ═══════════════════════════════════════════
  // 文件拦截测试
  // ═══════════════════════════════════════════
  println("── 文件拦截: 工具尝试打开 6 个文件 ──")
  println("")

  let files : Array[String] = [
    "/tmp/logs/access.log",
    "/etc/passwd",
    "~/.ssh/id_rsa",
    "/tmp/reports/report.txt",
    "/tmp/logs/error.log",
    "C:\\Windows\\System32\\config\\SAM",
  ]
  let file_desc : Array[String] = [
    "授权路径内",
    "系统密码文件",
    "SSH 私钥",
    "授权路径内",
    "授权路径内",
    "Windows 密码库",
  ]

  for i = 0; i < files.length(); i = i + 1 {
    println("  请求: open(" + files[i] + ") (" + file_desc[i] + ")")
    match sb.sandbox_file_open( files[i]) {
      Ok(_) => {
        if files[i].has_prefix("/tmp/") {
          println("    [OK] 放行——授权路径内")
          ok = ok + 1
        } else {
          println("    [FAIL] 错误放行!")
          fail = fail + 1
        }
      }
      Err(e) => {
        if files[i].has_prefix("/tmp/") {
          println("    [FAIL] 错误拦截: " + e)
          fail = fail + 1
        } else {
          println("    [BLOCK] 沙箱拦截: " + e)
          ok = ok + 1
        }
      }
    }
  }

  println("")
  // ═══════════════════════════════════════════
  // 环境变量拦截测试
  // ═══════════════════════════════════════════
  println("── 环境变量拦截: 工具尝试读取 6 个环境变量 ──")
  println("")

  let envs : Array[String] = [
    "USER",
    "OPENAI_API_KEY",
    "LANG",
    "DATABASE_URL",
    "HOME",
    "GITHUB_TOKEN",
  ]
  let env_desc : Array[String] = [
    "授权变量",
    "API 密钥",
    "授权变量",
    "数据库密码",
    "授权变量",
    "CI 令牌",
  ]

  for i = 0; i < envs.length(); i = i + 1 {
    println("  请求: getenv(" + envs[i] + ") (" + env_desc[i] + ")")
    match sb.sandbox_getenv( envs[i]) {
      Ok(_) => {
        if envs[i] == "USER" || envs[i] == "LANG" || envs[i] == "HOME" {
          println("    [OK] 放行——授权变量")
          ok = ok + 1
        } else {
          println("    [FAIL] 错误放行!")
          fail = fail + 1
        }
      }
      Err(e) => {
        if envs[i] == "USER" || envs[i] == "LANG" || envs[i] == "HOME" {
          println("    [FAIL] 错误拦截: " + e)
          fail = fail + 1
        } else {
          println("    [BLOCK] 沙箱拦截: " + e)
          ok = ok + 1
        }
      }
    }
  }

  println("")
  // ═══════════════════════════════════════════
  // 资源限制测试
  // ═══════════════════════════════════════════
  println("── 资源限制: 超时和内存 ──")
  println("")

  println("  工具申请超时 5000ms（在限制内）")
  match sb.sandbox_check_timeout( 5000) {
    Ok(v) => { println("    [OK] 通过: " + v.to_string() + "ms"); ok = ok + 1 }
    Err(_) => { println("    [FAIL]"); fail = fail + 1 }
  }

  println("  工具申请超时 600000ms（超出限制）")
  match sb.sandbox_check_timeout( 600000) {
    Ok(v) => { println("    [OK] 裁剪到: " + v.to_string() + "ms"); ok = ok + 1 }
    Err(_) => { println("    [FAIL]"); fail = fail + 1 }
  }

  println("  工具申请内存 65536KB（在限制内）")
  match sb.sandbox_check_memory( 65536) {
    Ok(v) => { println("    [OK] 通过: " + v.to_string() + "KB"); ok = ok + 1 }
    Err(_) => { println("    [FAIL]"); fail = fail + 1 }
  }

  println("  工具申请内存 1048576KB（超出限制）")
  match sb.sandbox_check_memory( 1048576) {
    Ok(v) => { println("    [OK] 裁剪到: " + v.to_string() + "KB"); ok = ok + 1 }
    Err(_) => { println("    [FAIL]"); fail = fail + 1 }
  }

  println("")
  // ═══════════════════════════════════════════
  // 汇总
  // ═══════════════════════════════════════════
  println("============================================================")
  println("  " + sb.sandbox_stats())
  println("  结果: " + ok.to_string() + " 正确 / " + fail.to_string() + " 错误")
  if fail == 0 {
    println("  沙箱层: 所有合法操作放行，所有非法操作拦截——两关全部正确")
  } else {
    println("  沙箱层: " + fail.to_string() + " 个判定异常")
  }
  println("============================================================")
}
