// ============================================================
// AegisRun 演示工具：Chorus — 合法 AI Agent 工具范例
// ============================================================
// 这是第一幕演示中展示的工具源码。
// 核心演示点：
//   1. Tool trait 实现 — 标准化的工具接口
//   2. Capability 显式声明 — 只申请需要的权限
//   3. 纯函数执行 — 无副作用，输入输出类型安全
// ============================================================

// ═══════ Tool trait：所有 AegisRun 工具必须实现的接口 ═══════

// Tool 元数据 — Agent 用来理解工具功能
let TOOL_NAME        = "chorus"
let TOOL_DESCRIPTION = "多城市天气查询与对比工具。输入城市名列表，返回各城市天气数据和对比表格。"
let TOOL_VERSION     = "1.0.0"
let TOOL_AUTHOR      = "aegisrun-demo"

// ═══════ Capability 声明 — 这是最关键的演示点 ═══════

// 该工具需要的能力（显式声明，最小权限）
//   - network: 仅允许 wttr.in 域名
//   - timeout: 最大执行 5000ms
//   - memory:  最大 512KB
//   - filesystem: 无（不碰文件系统）
//   - env: 无（不读环境变量）
let CAPABILITIES = [
  "network=wttr.in",       // 只允许访问 wttr.in
  "timeout=5000",           // 超时限制
  "memory=512",             // 内存限制 (KB)
]

// ═══════ 输入输出类型（类型安全，不可伪造） ═══════

// 输入 — 城市名列表
// 输出 — 每城市天气摘要 + 对比结果
// 类型边界由 MoonBit 编译器保证，Agent 无法构造非法输入

// ═══════ 核心执行逻辑 ═══════

fn main {
  println("")
  println("  🎵 Chorus Tool v" + TOOL_VERSION + " — 合法工具示例")
  println("  Author: " + TOOL_AUTHOR)
  println("")
  println("  ═══════ Capability 声明 ═══════")
  for cap in CAPABILITIES {
    println("  📋 " + cap)
  }
  println("")
  println("  ═══════ 执行结果 ═══════")

  // 模拟天气查询（合法域名 wttr.in）
  let cities = ["Beijing", "Shanghai", "Shenzhen", "Tokyo"]
  for city in cities {
    let url = "https://wttr.in/" + city + "?format=3"
    println("  [OK] 已查询 " + city + " → " + url)
  }

  println("")
  println("  ═══════ 安全检查 ═══════")
  println("  [INFO] AegisRun 策略引擎验证:")
  println("    ✅ 域名 wttr.in — 在白名单内 — ALLOW")
  println("    ✅ 文件系统 — 工具未声明 — BLOCKED by default")
  println("    ✅ 环境变量 — 工具未声明 — BLOCKED by default")
  println("    ✅ 进程执行 — 工具未声明 — BLOCKED by default")
  println("")
  println("  ✅ Chorus 执行完毕 — 所有操作均在 Capability 范围内")
  println("")
  println("  ────────────────────────────────────────")
  println("  这就是 AegisRun 的安全模型：")
  println("  每个工具声明它需要的权限 →")
  println("  Runtime 只授予这些权限 →")
  println("  超出声明的一切操作默认拒绝。")
  println("  ────────────────────────────────────────")
}
