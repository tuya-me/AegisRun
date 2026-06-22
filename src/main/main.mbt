// AegisRun Lite — Main Entry (路由)
// 只负责: 创建引擎 → 读环境变量 → 路由到对应 demo
fn main {
  println("")
  println("  ╔══════════════════════════════════════════════════════╗")
  println("  ║   AegisRun Lite v0.1.0                              ║")
  println("  ║   AI Agent Secure Tool Execution Framework          ║")
  println("  ║   MoonBit + WebAssembly  .  OSC2026                 ║")
  println("  ╚══════════════════════════════════════════════════════╝")

  let policy = @lib.new_policy_engine()

  let demo_choice = match @env.get_env_var("AEGISRUN_DEMO") {
    Some(v) => v
    None => "all"
  }
  println("  [ENV] AEGISRUN_DEMO=" + demo_choice)
  println("")

  match demo_choice {
    "1" => @demo.demo1()
    "2" => @demo.demo2(policy)
    "3" => @demo.demo3(policy)
    "4" => @demo.demo4(policy)
    "5" => @demo.demo5(policy)
    "6" => @demo.demo6()
    "7" => @demo.demo7(policy)
    _ => {
      @demo.demo1()
      @demo.demo2(policy)
      @demo.demo3(policy)
      @demo.demo4(policy)
      @demo.demo5(policy)
      @demo.demo6()
      @demo.demo7(policy)
    }
  }

  println("")
  println("  ============================================================")
  println("   Demo complete. AegisRun Lite — Ready for MCP mode.")
  println("  ============================================================")
  println("")
}
