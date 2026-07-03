// AegisRun Lite — Main Entry

///|
fn main {
  let args = @env.args()
  let policy = @lib.new_policy_engine()

  // Check env var for web panel policy sync (set by dashboard.html export)
  let policy_env = match @env.get_env_var("AEGISRUN_POLICY") {
    Some(v) => v
    None => ""
  }
  if policy_env != "" {
    @lib.load_policy_patch(policy, policy_env)
    println("  [WEB] Policy loaded from web panel: " + policy_env)
  }

  // Check env var for demo mode (set by run_demo.bat)
  let demo_env = match @env.get_env_var("AEGISRUN_DEMO") {
    Some(v) => v
    None => ""
  }

  print_banner()

  if demo_env != "" {
    // Demo mode: AEGISRUN_DEMO=n moon run src/main
    run_demo(demo_env, policy)
    println("")
    println("  Demo complete. AegisRun Lite — Ready for MCP mode.")
  } else if args.length() > 1 {
    // CLI mode: aegisrun <command> [args...]
    handle_command(args, policy)
  } else {
    // No args: help + run all demos
    print_help()
    println("")
    println("  No command given — running ALL demos as default...")
    run_demo("all", policy)
  }
}
