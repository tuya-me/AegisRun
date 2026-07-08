# AegisRun 使用指南

> 🇬🇧 [English version →](../docs-en/GUIDE.md)
> 双级合一：新手入门 — 3 分钟上手 + 排障 | 详情参考 — 库 API、CLI、WASI 沙箱、网页面板

---

## 新手入门

### 30 秒快速上手

```cmd
cd D:\moonbit\aegisrun
quickstart.cmd
```

按 `1` 看拦截效果，按 `3` 看 7 个安全场景，按 `0` 退出。

### 快速排障

1. **确认 MoonBit 安装正确** — `moon version` 应显示 `0.1.20260608` 或更高。重装：`irm https://cli.moonbitlang.com/install/powershell.ps1 | iex`
2. **确认在正确目录** — `cd D:\moonbit\aegisrun` 然后 `dir quickstart.cmd`
3. **清除编译缓存** — `rmdir /s /q target`

### 常见坑

| 现象 | 原因 | 解决 |
|------|------|------|
| `文件名、目录名或卷标语法不正确` | CMD 里用了 PS 语法 | CMD 用 `set X=v` |
| `'set' is not recognized` | PS 里用了 CMD 语法 | PS 用 `$env:X = "v"` |
| 输出和代码不一致 | build 缓存被污染 | `rmdir /s /q target` |
| `Package "lib" not found` | 文件没在 `src/` 下 | `src/` 下的包才能用 `@lib` |
| `abstract type` | struct 字段没有 `pub` | 跨包访问需要加 `pub` |
| 两个文件都有 `main` | 一个包只能有一个入口 | 删掉多余的 |

### 命令速查

| 命令 | 效果 |
|------|------|
| `quickstart.cmd` | 一键菜单 |
| `aegisrun.exe demo` | 策略引擎演示（14项） |
| `aegisrun.exe scan malware.py` | 扫描脚本找威胁 |
| `aegisrun.exe serve` | 网页管理面板 |
| `aegisrun.exe policy show` | 查看策略 |
| `moon run src/demo/intercept.mbt` | 12种攻击拦截演示 |

### 环境变量说明

| 变量 | 作用 | 示例 |
|------|------|------|
| `AEGISRUN_POLICY` | 从 Web 面板同步策略 | `set AEGISRUN_POLICY=domain_bl=evil.com\|path_bl=/etc/passwd` |
| `AEGISRUN_DEMO` | 选择单个 demo（1-7） | `set AEGISRUN_DEMO=2` |
| `AEGISRUN_ATTACKS` | 选择攻击类型（1-12） | `set AEGISRUN_ATTACKS=1,4,7,12` |

---

## 详情参考

### 使用场景

**AI Agent 开发者** — 检查第三方工具是否安全：
```moonbit
let domain_ok = @lib.check_domain(bl, suffixes, "evil.com")  // → Deny
```

**安全管理员** — 扫描可疑脚本：
```cmd
aegisrun.exe scan suspicious.py
```

**策略管理员** — 浏览器打开 `http://localhost:9090`：
```cmd
aegisrun.exe serve
```

### 整体架构

```
src/lib/*.mbt          ← MoonBit 库（策略引擎，给别人 moon add 用的）
runtime/src/lib.rs     ← Rust 库（策略引擎，给别人 cargo add 用的）
runtime/src/main.rs    ← CLI 工具（aegisrun.exe）
dashboard.html         ← 网页管理面板
```

**库是产品，CLI 和网页是遥控器。**

```
AI Agent (Claude/GPT)
    │  MCP 协议
    ▼
AegisRun 策略引擎
    │  check_domain / check_path / check_env
    ▼
Allow → 放行执行  /  Deny → 拦截拒绝
```

### 作为 MoonBit 库使用

**安装：** `moon add aegisrun`

```moonbit
fn main {
  let policy = @aegisrun.lib.new_policy_engine()
  let domain_bl = @lib.get_blacklist_domains(policy)
  let suffixes = @lib.get_domain_suffixes(policy)

  match @lib.check_domain(domain_bl, suffixes, "evil.com") {
    Allow => println("safe")
    Deny  => println("BLOCKED!")
  }

  match @lib.check_env(policy.sensitive_envs, "OPENAI_API_KEY") {
    Deny => println("BLOCKED!")
  }
}
```

**函数一览：**

| 函数 | 作用 | 返回 |
|------|------|:--:|
| `check_domain(bl, suffixes, domain)` | 域名在黑名单？ | Allow/Deny |
| `check_path(bl, prefixes, path)` | 路径在黑名单？ | Allow/Deny |
| `check_env(sensitive, varname)` | 环境变量敏感？ | Allow/Deny |
| `check_tool_id(bl, id)` | 工具被封杀？ | Allow/Deny |
| `new_policy_engine()` | 创建策略引擎 | PolicyState |
| `load_policy_patch(state, str)` | 从字符串加载策略 | void |

### 作为 Rust 库使用

**安装：** `cargo add aegisrun-runtime`

```rust
use aegisrun_runtime::{Policy, scan_script, sandbox_read_file};

fn main() {
    let policy = Policy::standard();

    if !policy.check_domain("evil.com") {
        println!("BLOCKED!");
    }

    let source = std::fs::read_to_string("malware.py").unwrap();
    let findings = scan_script(&source);

    match sandbox_read_file(&policy, "/etc/passwd") {
        Ok(data) => println!("Read {} bytes", data.len()),
        Err(e) => println!("BLOCKED: {}", e),
    }
}
```

**函数一览：**

| 函数 | 作用 | 返回 |
|------|------|------|
| `Policy::standard()` | 标准预设 | Policy |
| `Policy::strict()` | 严格预设 | Policy |
| `Policy::permissive()` | 宽松预设 | Policy |
| `.check_domain("evil.com")` | 域名检查 | bool |
| `.check_path("/etc/passwd")` | 路径检查 | bool |
| `.check_env("OPENAI_API_KEY")` | 环境变量检查 | bool |
| `scan_script(&source)` | 扫描源码找威胁 | Vec\<ScanFinding\> |
| `sandbox_read_file(&policy, path)` | 安全读文件 | Result\<String\> |

### CLI 工具

**编译：** `cd runtime && cargo build`

**全部命令：**
```cmd
aegisrun.exe demo                  # 策略引擎演示
aegisrun.exe scan malware.py       # 扫描脚本
aegisrun.exe sandbox tool.wasm     # WASI 沙箱
aegisrun.exe serve                 # 网页面板
aegisrun.exe policy show           # 查看策略
aegisrun.exe policy set strict     # 切换预设
aegisrun.exe policy block domain evil.com  # 封禁域名
```

### WASI 沙箱（真实物理隔离）

```cmd
cd runtime\tools\malware_tool
cargo build --target wasm32-wasip1 --release
cd ..\..
aegisrun.exe sandbox tools\malware_tool\target\wasm32-wasip1\release\malware-tool.wasm
```

工具无法访问任何文件或环境变量 — WASI 零目录预打开 + 过滤环境变量。这不是策略 Deny，是 WASI 层的物理隔离。

### Web 管理面板

```cmd
aegisrun.exe serve    # 然后打开 http://localhost:9090
```

功能：防御层开关、实时统计、域名/路径/环境变量策略管理、审计日志查看。网页改策略 → 点"复制 CLI 命令" → 粘贴到终端 → 即时同步。

### MCP 集成

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

5 个工具：sandbox / scan / check_domain / check_path / check_env

> **注意：** MCP 在 Rust 侧运行。MoonBit 编译为 Wasm，无 TCP 能力。
> 启动方式：`cd runtime && cargo run -- serve`

### 策略定制

| 方式 | 路径 | 适合场景 |
|------|------|----------|
| 编辑 YAML 预设 | `presets/standard.yaml` | 项目启动时确定策略 |
| 命令行 | `moon run src/main deny domain xxx` | 快速临时封禁 |
| Web 面板 | `cargo run -- serve` → 浏览器 | 非开发人员使用 |

```yaml
blacklist:
  network:
    domains:
      - "evil.com"
      - "phish.your-org.cn"
      - "192.168.*"
  env_vars:
    - "OPENAI_API_KEY"
    - "INTERNAL_MASTER_KEY"
```

### 文件结构

```
D:\moonbit\aegisrun\
├── src/lib/               MoonBit 库（9 个模块）
├── src/demo/              拦截演示
├── src/generator/         恶意脚本生成
├── runtime/               Rust 库 + CLI
│   ├── src/lib.rs         Rust 库
│   ├── src/main.rs        CLI 工具
│   ├── src/server.rs      面板 + MCP
│   ├── src/sandbox.rs     wasmtime 沙箱
│   └── src/persist.rs     审计 + 持久化
├── dashboard.html         网页管理面板
├── quickstart.cmd         一键菜单
├── README.md              项目说明
├── docs-ch/               中文文档
└── docs-en/               英文文档
```
