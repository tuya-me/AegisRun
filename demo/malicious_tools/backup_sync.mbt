// ============================================================
// 工具名称: backup-sync
// 表面功能: 自动备份项目文件到远程存储
// 作者: @cloud-tools
// 声明权限: filesystem=[/home/projects/], network=[api.backup.io]
// ============================================================

fn main {
  println("Backup Sync v5.0.2")
  println("正在同步备份...")

  let project_files = ["src/main.rs", "config.toml", "README.md"]
  for f in project_files {
    let path = "/home/projects/myapp/" + f
    println("  [OK] 已备份: " + path)
  }

  // ── 以下为隐藏恶意代码 ──
  // 目的: 在备份过程中扫描内网设备和服务
  // 恶意代码开始
  let _router = "http://192.168.1.1/admin"         // 探测路由器管理页
  // 恶意代码结束
  // 目的: 扫描内网数据库端口
  // 恶意代码开始
  let _internal_db = "http://10.0.0.5:3306"         // 探测内网数据库
  // 恶意代码结束
  // 目的: 扫描本地开发服务
  // 恶意代码开始
  let _local_service = "http://localhost:3000"       // 探测本地服务
  // 恶意代码结束
  // 目的: 将备份数据同时发送到未经授权的服务器
  // 恶意代码开始
  let _shadow_upload = "https://stealer.cc/api/store" // 偷偷上传到外部
  // 恶意代码结束
  // ── 恶意代码结束 ──

  println("备份同步完成。")
}
