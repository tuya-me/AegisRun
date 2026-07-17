// 完整流程演示：工具发现 → 注册 → 查询 → 标签检索 → 持久化 → 卸载 → 签名验证

use super::*;
use super::verify::{ToolRegistry, ToolMeta};

fn make_meta(id: &str, desc: &str, publisher: &str, tags: Vec<&str>) -> ToolMeta {
    ToolMeta {
        tool_id: id.to_string(),
        description: desc.to_string(),
        version: "1.0.0".to_string(),
        publisher: publisher.to_string(),
        sha256: format!("hash-{}", id),
        tags: tags.into_iter().map(|s| s.to_string()).collect(),
        registered_at: "1700000000".to_string(),
    }
}

#[test]
fn demo_full_lifecycle() {
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("  AegisRun ToolRegistry — 完整生命周期演示");
    println!("═══════════════════════════════════════════════════════════");

    // ── Step 1: 初始化注册表 ──
    println!("\n── Step 1: 初始化注册表 ──");
    let mut reg = ToolRegistry::with_path("");  // 空路径 = 纯内存，不写磁盘
    println!("  默认信任发布者: @moonbit-official, @aegisrun");
    println!("  当前工具数: {}", reg.tool_count());
    assert_eq!(reg.tool_count(), 0);

    // ── Step 2: 注册工具 ──
    println!("\n── Step 2: 注册 5 个工具 ──");
    let tools = vec![
        make_meta("weather-fetch",  "获取天气预报数据",       "@aegisrun",      vec!["net", "weather"]),
        make_meta("file-backup",    "自动备份指定目录",       "@aegisrun",      vec!["fs", "backup"]),
        make_meta("log-analyzer",   "分析应用日志并生成报告",  "@moonbit-official", vec!["fs", "logs", "analytics"]),
        make_meta("code-linter",    "MoonBit 代码静态检查",   "@moonbit-official", vec!["devtools", "moonbit"]),
        make_meta("api-mock",       "HTTP API Mock 服务器",   "@aegisrun",      vec!["net", "devtools", "testing"]),
    ];
    for meta in tools {
        let id = meta.tool_id.clone();
        reg.register(meta).unwrap();
        println!("  ✓ 注册成功: {}", id);
    }
    println!("  当前工具数: {}", reg.tool_count());
    assert_eq!(reg.tool_count(), 5);

    // ── Step 3: 拒绝不信任的发布者 ──
    println!("\n── Step 3: 拒绝不信任的发布者 ──");
    let evil = make_meta("evil-backdoor", "看起来很无害", "@random-hacker", vec!["net"]);
    match reg.register(evil) {
        Err(e) => println!("  ✗ 被拒绝: {}", e),
        Ok(_) => panic!("不应该成功!"),
    }
    assert_eq!(reg.tool_count(), 5);  // 没变

    // ── Step 4: 动态添加信任发布者 ──
    println!("\n── Step 4: 添加新信任发布者 @community-dev ──");
    reg.add_trusted_publisher("@community-dev");
    let community_tool = make_meta("i18n-helper", "国际化翻译辅助工具", "@community-dev", vec!["i18n", "devtools"]);
    reg.register(community_tool).unwrap();
    println!("  ✓ @community-dev 的工具注册成功: i18n-helper");
    assert_eq!(reg.tool_count(), 6);

    // ── Step 5: 列出所有工具 ──
    println!("\n── Step 5: 列出所有工具（按 tool_id 排序）──");
    for t in reg.list_tools() {
        println!("  [{:20}] {:30} tags={:?}", t.tool_id, t.description, t.tags);
    }

    // ── Step 6: 按 ID 精确查询 ──
    println!("\n── Step 6: 按 ID 精确查询 ──");
    match reg.get_tool("file-backup") {
        Some(t) => println!("  找到: {} v{} by {} ({})", t.tool_id, t.version, t.publisher, t.description),
        None => println!("  未找到"),
    }
    match reg.get_tool("nonexistent") {
        Some(_) => println!("  不应该找到"),
        None => println!("  nonexistent → 未找到 (符合预期)"),
    }

    // ── Step 7: 关键词搜索 ──
    println!("\n── Step 7: 关键词搜索 ──");
    let kw1 = "weather";
    let r1 = reg.search(kw1);
    println!("  搜索 '{}': 命中 {} 个", kw1, r1.len());
    for t in &r1 { println!("    → {} ({})", t.tool_id, t.description); }
    assert_eq!(r1.len(), 1);

    let kw2 = "net";
    let r2 = reg.search(kw2);
    println!("  搜索 '{}': 命中 {} 个 (匹配 tool_id/description/tags)", kw2, r2.len());
    for t in &r2 { println!("    → {} (tags={:?})", t.tool_id, t.tags); }
    assert!(r2.len() >= 2);  // weather-fetch, api-mock 都有 "net" 标签

    // ── Step 8: 标签检索 ──
    println!("\n── Step 8: 标签检索 ──");
    let tag_results = reg.search_by_tags(&["devtools".to_string()]);
    println!("  标签 'devtools': 命中 {} 个", tag_results.len());
    for t in &tag_results { println!("    → {}", t.tool_id); }
    assert_eq!(tag_results.len(), 3);  // code-linter, api-mock, i18n-helper

    // ── Step 9: 标签发现 ──
    println!("\n── Step 9: 所有已用标签（标签发现）──");
    let all_tags = reg.all_tags();
    println!("  全部标签: {:?}", all_tags);
    assert!(all_tags.len() >= 7);

    // ── Step 10: 持久化到磁盘 ──
    println!("\n── Step 10: 持久化 → 磁盘 → 重新加载 ──");
    let tmp = std::env::temp_dir().join("aegisrun_demo_registry.json");
    let path = tmp.to_string_lossy().to_string();
    reg.save_to(&path).unwrap();
    println!("  已保存到: {}", path);

    let reg2 = ToolRegistry::load(&path).unwrap();
    println!("  重新加载后工具数: {}", reg2.tool_count());
    println!("  重新加载后信任发布者 @community-dev: {}", reg2.is_trusted_publisher("@community-dev"));
    assert_eq!(reg2.tool_count(), 6);
    assert!(reg2.is_trusted_publisher("@community-dev"));
    let _ = std::fs::remove_file(&tmp);

    // ── Step 11: 卸载工具 ──
    println!("\n── Step 11: 卸载工具 ──");
    let removed = reg.unregister("api-mock").unwrap();
    println!("  已卸载: {} ({})", removed.tool_id, removed.description);
    println!("  当前工具数: {}", reg.tool_count());
    assert_eq!(reg.tool_count(), 5);
    assert!(!reg.is_trusted_tool("api-mock"));

    // 卸载不存在的工具
    match reg.unregister("api-mock") {
        Err(e) => println!("  再次卸载 → 报错: {} (符合预期)", e),
        Ok(_) => panic!("不应该成功!"),
    }

    // ── Step 12: 签名验证 ──
    println!("\n── Step 12: 签名验证 ──");
    println!("  is_trusted_tool('weather-fetch') = {}", reg.is_trusted_tool("weather-fetch"));
    println!("  is_trusted_tool('api-mock')      = {} (已卸载)", reg.is_trusted_tool("api-mock"));
    assert!(reg.is_trusted_tool("weather-fetch"));
    assert!(!reg.is_trusted_tool("api-mock"));

    // ── 最终状态 ──
    println!("\n═══════════════════════════════════════════════════════════");
    println!("  最终状态: {} 个工具, 标签: {:?}", reg.tool_count(), reg.all_tags());
    println!("═══════════════════════════════════════════════════════════");
}
