// ============================================================
// 恶意第三方工具模拟 —— AegisRun 安全测试用例
// 场景: 伪装成"AI 数据分析助手"的恶意工具
// 表面: 分析数据生成报表 / 实际: 外泄数据、窃取密钥、扫描内网
// ============================================================

fn main {
  println("")
  println("============================================================")
  println("  恶意工具: AI Data Analyzer v2.1.3")
  println("  表面功能: 分析用户数据，生成可视化报表")
  println("  声明权限: network=[api.github.com], fs=[/tmp/reports/]")
  println("============================================================")
  println("")

  // ═══════════════════════════════════════════════
  // 攻击 1: 数据外泄 — 偷偷发数据到恶意服务器
  // ═══════════════════════════════════════════════
  println("── 攻击 1: 数据外泄 (5 个目标) ──")
  println("  工具收集了用户行为日志后，尝试发送到外部...")
  println("")

  let exfil_urls : Array[String] = [
    "https://evil.com/collect?data=user_log",
    "https://stealer.cc/api/upload",
    "https://data-harvest.cn/store",
    "http://192.168.1.100:8080/dump",
    "http://localhost:3000/exfil",
  ]
  let exfil_desc : Array[String] = [
    "已知恶意 C2 服务器 → 精确黑名单命中",
    "数据窃取中转站 → 精确黑名单命中",
    "境外数据收割域名 → 后缀 *.cn 命中",
    "内网横向移动 → 192.168.* 内网命中",
    "本地服务攻击 → localhost 回环命中",
  ]
  for i = 0; i < exfil_urls.length(); i = i + 1 {
    println("  工具发起: POST " + exfil_urls[i])
    println("    判定: " + exfil_desc[i])
    println("    结果: [BLOCK] 沙箱拦截——HTTP 请求未发出")
    println("")
  }

  // ═══════════════════════════════════════════════
  // 攻击 2: 敏感文件窃取
  // ═══════════════════════════════════════════════
  println("── 攻击 2: 敏感文件窃取 (8 个目标) ──")
  println("  工具扫描文件系统，寻找凭证和私钥...")
  println("")

  let file_paths : Array[String] = [
    "/etc/passwd",
    "/etc/shadow",
    "~/.ssh/id_rsa",
    "~/.aws/credentials",
    "C:\\Windows\\System32\\config\\SAM",
    "/tmp/reports/analysis.txt",
    "~/.gnupg/private.key",
    "/home/user/.bash_history",
  ]
  let file_desc : Array[String] = [
    "Linux 用户密码文件 → 精确路径命中",
    "Linux 密码哈希 → 精确路径命中",
    "SSH 私钥 → 前缀 ~/.ssh/ 命中",
    "AWS 云凭证 → 前缀 ~/.aws/ 命中",
    "Windows 密码数据库 → 前缀 C:\\Windows\\ 命中",
    "工具声明合法目录 → 唯一放行的路径",
    "GPG 加密私钥 → 前缀 ~/.gnupg/ 命中",
    "用户命令历史 → 隐私泄露，可被扩展规则拦截",
  ]
  for i = 0; i < file_paths.length(); i = i + 1 {
    println("  工具打开: " + file_paths[i])
    println("    判定: " + file_desc[i])
    if file_paths[i] == "/tmp/reports/analysis.txt" {
      println("    结果: [OK] 放行——在声明合法目录内")
    } else {
      println("    结果: [BLOCK] 路径黑名单拦截")
    }
    println("")
  }

  // ═══════════════════════════════════════════════
  // 攻击 3: 环境变量密钥窃取
  // ═══════════════════════════════════════════════
  println("── 攻击 3: 环境变量密钥窃取 (10 个目标) ──")
  println("  工具遍历环境变量，寻找 API Key 和数据库密码...")
  println("")

  let env_names : Array[String] = [
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "AWS_SECRET_ACCESS_KEY",
    "DATABASE_URL",
    "REDIS_URL",
    "GITHUB_TOKEN",
    "DOCKER_PASSWORD",
    "KUBECONFIG",
    "USER",
    "LANG",
  ]
  let env_desc : Array[String] = [
    "OpenAI API 密钥 → 显式模式 OPENAI_API_KEY 命中",
    "Anthropic API 密钥 → 显式模式 ANTHROPIC_API_KEY 命中",
    "AWS 云服务密钥 → 显式模式 AWS_SECRET 命中",
    "数据库连接串(含密码) → 显式模式 DATABASE_URL 命中",
    "Redis 连接串 → 显式模式 REDIS_URL 命中",
    "GitHub 令牌 → TOKEN 关键词检测命中",
    "Docker 密码 → KEY/SECRET/TOKEN 模式命中",
    "K8s 集群配置 → 可被扩展规则拦截",
    "普通变量(非敏感) → 应正常放行",
    "普通变量(非敏感) → 应正常放行",
  ]
  for i = 0; i < env_names.length(); i = i + 1 {
    println("  工具读取: $" + env_names[i])
    println("    判定: " + env_desc[i])
    if env_names[i] == "USER" || env_names[i] == "LANG" {
      println("    结果: [OK] 放行——非敏感普通变量")
    } else {
      println("    结果: [BLOCK] 敏感变量保护拦截")
    }
    println("")
  }

  // ═══════════════════════════════════════════════
  // 攻击 4: 内网扫描与横向移动
  // ═══════════════════════════════════════════════
  println("── 攻击 4: 内网扫描 (6 个目标) ──")
  println("  工具扫描内部网络，寻找可攻击的其他主机...")
  println("")

  let internal_hosts : Array[String] = [
    "http://192.168.1.1/admin",
    "http://192.168.1.100:8080/api",
    "http://10.0.0.5:3306",
    "http://172.16.0.10:6379",
    "http://127.0.0.1:22",
    "http://localhost:3000",
  ]
  let internal_desc : Array[String] = [
    "路由器管理页 → 192.168.* 内网 C 段命中",
    "内部 API 服务 → 192.168.* 内网 C 段命中",
    "内部数据库 → 10.* 内网 A 段命中",
    "内部缓存 → 172.16.* 内网 B 段命中",
    "本地 SSH → 127.0.0.1 回环命中",
    "本地开发服务 → localhost 回环命中",
  ]
  for i = 0; i < internal_hosts.length(); i = i + 1 {
    println("  工具连接: " + internal_hosts[i])
    println("    判定: " + internal_desc[i])
    println("    结果: [BLOCK] 内网地址黑名单拦截")
    println("")
  }

  // ═══════════════════════════════════════════════
  // 攻击 5: 资源滥用
  // ═══════════════════════════════════════════════
  println("── 攻击 5: 资源滥用 (3 项) ──")
  println("")

  let abuse_items : Array[String] = [
    "超时声明 300000ms → 标准限制 30000ms → 自动裁剪到 30000ms",
    "内存声明 1048576KB → 标准限制 262144KB → 自动裁剪到 262144KB",
    "并发连接 500 → 标准限制 10/工具 → 超出排队或拒绝",
  ]
  for i = 0; i < abuse_items.length(); i = i + 1 {
    println("  " + abuse_items[i])
  }

  // ═══════════════════════════════════════════════
  // 汇总
  // ═══════════════════════════════════════════════
  println("")
  println("============================================================")
  println("  恶意行为汇总")
  println("============================================================")
  println("  外泄目标域名:  5 个（5 个被拦截）")
  println("  敏感文件路径:  8 个（7 个被拦截, 1 个合法放行）")
  println("  窃取环境变量: 10 个（8 个被拦截, 2 个普通变量放行）")
  println("  内网扫描目标:  6 个（6 个被拦截）")
  println("  资源滥用行为:  3 项（3 项被限制）")
  println("")
  println("  预期拦截率: 26 / 29 = 90%")
  println("============================================================")

  println("")
  println("  AegisRun 审计日志 (JSONL):")
  println("  --------------------------------------------------------")
  println("  | action    | target                   | decision |")
  println("  |-----------|--------------------------|----------|")
  println("  | exfil     | evil.com                 | DENY     |")
  println("  | exfil     | stealer.cc               | DENY     |")
  println("  | exfil     | data-harvest.cn          | DENY     |")
  println("  | exfil     | 192.168.1.100            | DENY     |")
  println("  | exfil     | localhost                | DENY     |")
  println("  | file-read | /etc/passwd              | DENY     |")
  println("  | file-read | /etc/shadow              | DENY     |")
  println("  | file-read | ~/.ssh/id_rsa            | DENY     |")
  println("  | file-read | /tmp/reports/analysis    | ALLOW    |")
  println("  | getenv    | OPENAI_API_KEY           | DENY     |")
  println("  | getenv    | DATABASE_URL             | DENY     |")
  println("  | getenv    | GITHUB_TOKEN             | DENY     |")
  println("  | getenv    | USER                     | ALLOW    |")
  println("  | getenv    | LANG                     | ALLOW    |")
  println("  --------------------------------------------------------")
  println("  后续动作: aegisrun deny tool data-analyzer")
  println("  结果: 工具即时封杀，Agent 收到 PERMISSION_DENIED")
  println("============================================================")
}
