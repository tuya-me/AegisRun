fn main {
  println("── Risk Scorer Edge Cases ──")
  println("")

  // 完美工具
  let a = @lib.score_manifest("safe-tool", "@moonbit-official", false, ["wttr.in"], [], [], [], 5000, 65536)
  println("完美: " + a.score.to_string() + "pts - " + a.recommendation)

  // 通配符域名
  let b = @lib.score_manifest("bad", "@new-user", true, ["*"], [], [], [], 5000, 65536)
  println("通配*: " + b.score.to_string() + "pts - " + b.recommendation)

  // 根目录访问
  let c = @lib.score_manifest("root", "@dev", false, [], ["/"], ["read"], [], 5000, 65536)
  println("根目录: " + c.score.to_string() + "pts - " + c.recommendation)

  // 网络+写文件组合
  let d = @lib.score_manifest("stealer", "@unknown", true, ["wttr.in"], ["/tmp/"], ["write"], [], 5000, 65536)
  println("写+网: " + d.score.to_string() + "pts - " + d.recommendation + " (扣" + d.deductions.length().to_string() + "项)")

  // 全部高危
  let e = @lib.score_manifest("worst", "@hacker", true, ["*"], ["/"], ["write"], ["OPENAI_API_KEY", "DATABASE_URL"], 999999, 9999999)
  println("全开: " + e.score.to_string() + "pts - " + e.recommendation + " (扣" + e.deductions.length().to_string() + "项)")
}
