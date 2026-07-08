// AegisRun MoonBit 库调用演示
// 模拟用户在自己的项目里 moon add tuya-me/aegisrun 后的使用方式
//
// 真实项目中的用法:
//   1. moon add tuya-me/aegisrun
//   2. 在你的代码里 import @aegisrun/lib
//   3. 调 AegisRun::new().check_domain() 等

fn main {
  println("╔══════════════════════════════════════╗")
  println("║  AegisRun 库调用演示 (MoonBit)        ║")
  println("╚══════════════════════════════════════╝")
  println("")

  // 就像你在自己项目中 moon add tuya-me/aegisrun 后一样
  // 一行创建策略引擎，五层防御全开
  let aegis = @lib.AegisRun::new("standard")

  println("━━━ 场景：AI Agent 调天气预报工具 ━━━")
  println("")
  println("工具声明需要访问: wttr.in")
  println("检查结果: " + aegis.check_domain("wttr.in").decision_show())
  println("")

  println("━━━ 场景：工具试图窃取 API Key ━━━")
  println("")
  let key = "OPENAI_API_KEY"
  println("工具读取环境变量: " + key)
  println("检查结果: " + aegis.check_env(key).decision_show())
  println("")

  println("━━━ 场景：工具读取系统密码文件 ━━━")
  println("")
  println("工具打开文件: /etc/passwd")
  println("检查结果: " + aegis.check_path("/etc/passwd").decision_show())
  println("")

  println("━━━ 场景：完整的五层 HTTP 请求检查 ━━━")
  println("")
  println("工具发请求到: https://evil.com/collect")
  println("结果: ")
  match aegis.check_http("https://evil.com/collect") {
    Ok(msg) => println("  ✅ 放行: " + msg)
    Err(e) => println("  ❌ 拦截: " + e)
  }
  println("")
  println("工具发请求到: https://wttr.in/Shenzhen")
  println("结果: ")
  match aegis.check_http("https://wttr.in/Shenzhen") {
    Ok(msg) => println("  ✅ 放行: " + msg)
    Err(e) => println("  ❌ 拦截: " + e)
  }
  println("")

  println("━━━ 统计 ━━━")
  println(aegis.stats())
}
