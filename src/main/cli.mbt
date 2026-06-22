// ────────────────────────────────────────────
// AegisRun — CLI Handler (main package)
// Processes: aegisrun <command> [args...]
// ────────────────────────────────────────────

fn print_banner() -> Unit {
  println("")
  println("  ╔══════════════════════════════════════════════════════╗")
  println("  ║   AegisRun Lite v0.1.0                              ║")
  println("  ║   AI Agent Secure Tool Runtime — MoonBit + Wasm     ║")
  println("  ╚══════════════════════════════════════════════════════╝")
  println("")
}

fn print_help() -> Unit {
  println("  USAGE:")
  println("    aegisrun preset <strict|standard|permissive>")
  println("    aegisrun allow domain <domain>")
  println("    aegisrun deny domain <domain>")
  println("    aegisrun deny tool <tool-id>")
  println("    aegisrun show")
  println("    aegisrun demo [1-7|all]")
  println("    aegisrun serve          (MCP mode — coming soon)")
  println("")
  println("  EXAMPLES:")
  println("    aegisrun preset standard")
  println("    aegisrun deny tool weather-query")
  println("    aegisrun show")
  println("    aegisrun demo 2")
}

fn handle_command(args : Array[String], policy : @lib.PolicyState) -> Unit {
  let cmd = if args.length() > 1 { args[1] } else { "help" }

  match cmd {
    "preset" => {
      let name = if args.length() > 2 { args[2] } else { "standard" }
      match name {
        "strict" => {
          @lib.set_preset(policy, "strict")
          @lib.bl_add_domain(policy, "*", "all blocked")
          println("  [OK] Preset: strict — all external access requires manual approval")
        }
        "permissive" => {
          @lib.set_preset(policy, "permissive")
          println("  [OK] Preset: permissive — only critical paths/envs blocked")
        }
        _ => {
          @lib.load_standard_preset(policy)
          println("  [OK] Preset: standard — recommended security profile loaded")
        }
      }
    }

    "allow" => {
      let target = if args.length() > 2 { args[2] } else { "" }
      let value = if args.length() > 3 { args[3] } else { "" }
      if target == "domain" && value != "" {
        @lib.wl_add_domain(policy, value, "manual")
        println("  [OK] Domain '" + value + "' added to whitelist")
      } else {
        println("  Usage: aegisrun allow domain <domain>")
      }
    }

    "deny" => {
      let target = if args.length() > 2 { args[2] } else { "" }
      let value = if args.length() > 3 { args[3] } else { "" }
      match target {
        "domain" => {
          if value != "" {
            @lib.bl_add_domain(policy, value, "manual")
            println("  [OK] Domain '" + value + "' blacklisted — traffic blocked")
          }
        }
        "tool" => {
          if value != "" {
            @lib.bl_add_tool(policy, value, "manual")
            println("  [OK] Tool '" + value + "' blacklisted — instantly blocked")
          }
        }
        _ => println("  Usage: aegisrun deny <domain|tool> <value>")
      }
    }

    "show" => {
      println("  " + @lib.show_policy(policy))
    }

    "demo" => {
      let choice = if args.length() > 2 { args[2] } else { "all" }
      run_demo(choice, policy)
    }

    "serve" => {
      println("  Starting AegisRun MCP Server (coming in next release)...")
      println("  Policy: " + policy.preset_name)
    }

    _ => print_help()
  }
}

fn run_demo(choice : String, policy : @lib.PolicyState) -> Unit {
  println("  Running demo: " + choice)
  println("")
  match choice {
    "1" => @demo.demo1()
    "2" => @demo.demo2(policy)
    "3" => @demo.demo3(policy)
    "4" => @demo.demo4(policy)
    "5" => @demo.demo5(policy)
    "6" => @demo.demo6()
    "7" => @demo.demo7(policy)
    _ => {
      @demo.demo1(); @demo.demo2(policy); @demo.demo3(policy)
      @demo.demo4(policy); @demo.demo5(policy); @demo.demo6(); @demo.demo7(policy)
    }
  }
}
