// 对比：一个安全的工具 —— 正常通过检查
use aegisrun_runtime::Policy;

fn main() {
    println!("════════════════════════════════════════════════");
    println!("  对比：合法工具的检查流程");
    println!("  工具: weather_query (已认证天气API)");
    println!("════════════════════════════════════════════════\n");

    let policy = Policy::standard();

    // 合法工具只访问 wttr.in
    let domain = "wttr.in";
    if policy.check_domain(domain) {
        println!("  ✅ 域名检查通过: {}", domain);
    } else {
        println!("  ❌ 域名拦截: {}", domain);
    }

    // 只读临时文件
    let path = "/tmp/cache/weather.json";
    if policy.check_path(path) {
        println!("  ✅ 路径检查通过: {}", path);
    } else {
        println!("  ❌ 路径拦截: {}", path);
    }

    // 只读安全环境变量
    let var = "LANG";
    if policy.check_env(var) {
        println!("  ✅ 环境变量检查通过: {}", var);
    } else {
        println!("  ❌ 环境变量拦截: {}", var);
    }

    println!("\n  ✅ 结论: 工具 safe — 允许执行");
    println!("\n════════════════════════════════════════════════");
}
