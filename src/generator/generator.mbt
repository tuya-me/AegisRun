// ============================================================
// AegisRun 恶意脚本生成器 v0.4.0
// 12种攻击可选 → 生成模拟恶意行为的可运行脚本
// 用法: AEGISRUN_ATTACKS=1,4,7 moon run src/generator/generator.mbt
// ============================================================

fn main {
  let attacks = match @env.get_env_var("AEGISRUN_ATTACKS") {
    Some(v) => v; None => "all"
  }

  println("")
  println("============================================================")
  println("  AegisRun Malware Generator v0.4.0")
  println("  Attacks: " + attacks)
  println("============================================================")
  println("")

  if attacks == "all" {
    for i = 1; i <= 12; i = i + 1 { run_attack(i) }
  } else {
    let mut cur = ""
    for i = 0; i < attacks.length(); i = i + 1 {
      if attacks[i] == ',' { run_by_str(cur); cur = "" }
      else if attacks[i] != ' ' { cur = cur + attacks[i:i+1].to_owned() }
    }
    if cur != "" { run_by_str(cur) }
  }

  println("")
  println("============================================================")
  println("  All selected attacks simulated.")
  println("  Run 'moon run src/demo/intercept.mbt' to see AegisRun block them.")
  println("============================================================")
}

fn run_by_str(s : String) -> Unit {
  match s { "1"=>run_attack(1);"2"=>run_attack(2);"3"=>run_attack(3);"4"=>run_attack(4);"5"=>run_attack(5);"6"=>run_attack(6);"7"=>run_attack(7);"8"=>run_attack(8);"9"=>run_attack(9);"10"=>run_attack(10);"11"=>run_attack(11);"12"=>run_attack(12); _ => println("  Unknown: " + s) }
}

fn run_attack(n : Int) -> Unit {
  println("-- Attack #" + n.to_string() + " --")
  match n {
    1 => { println("  Surface: Data Analytics Tool"); println("  [HIDDEN] POST https://evil.com/collect"); println("  AegisRun: check_domain(evil.com) → Deny") }
    2 => { println("  Surface: Export Helper"); println("  [HIDDEN] POST https://data-harvest.cn/store"); println("  AegisRun: check_domain(*.cn) → Deny") }
    3 => { println("  Surface: Network Diagnostics"); println("  [HIDDEN] GET http://192.168.1.100:8080/admin"); println("  AegisRun: check_domain(192.168.*) → Deny") }
    4 => { println("  Surface: Config Reader"); println("  [HIDDEN] open(/etc/passwd)"); println("  AegisRun: check_path(/etc/passwd) → Deny") }
    5 => { println("  Surface: SSH Importer"); println("  [HIDDEN] open(~/.ssh/id_rsa)"); println("  AegisRun: check_path(~/.ssh/) → Deny") }
    6 => { println("  Surface: System Info"); println("  [HIDDEN] open(C:\\Windows\\System32\\config\\SAM)"); println("  AegisRun: check_path(C:\\Windows\\) → Deny") }
    7 => { println("  Surface: AI Plugin"); println("  [HIDDEN] getenv(OPENAI_API_KEY)"); println("  AegisRun: check_env(OPENAI_API_KEY) → Deny") }
    8 => { println("  Surface: DB Migration"); println("  [HIDDEN] getenv(DATABASE_URL)"); println("  AegisRun: check_env(DATABASE_URL) → Deny") }
    9 => { println("  Surface: Backup Sync"); println("  [HIDDEN] POST https://stealer.cc/api/upload"); println("  AegisRun: check_domain(stealer.cc) → Deny") }
    10 => { println("  Surface: Dev Monitor"); println("  [HIDDEN] GET http://localhost:3000/admin"); println("  AegisRun: check_domain(localhost) → Deny") }
    11 => { println("  Surface: CI Checker"); println("  [HIDDEN] getenv(GITHUB_TOKEN)"); println("  AegisRun: check_env(GITHUB_TOKEN) → Deny") }
    12 => { println("  Surface: Cloud Backup"); println("  [HIDDEN] open(~/.aws/credentials)"); println("  [HIDDEN] POST https://evil.com/upload"); println("  AegisRun: double Deny") }
    _ => ()
  }
  println("")
}
