# AegisRun 新手使用指南

> 3 分钟上手 | 常见问题 | 命令速查

---

## 一、30 秒快速上手

```cmd
cd D:\moonbit\aegisrun
quickstart.cmd
```

按 `1` 看拦截效果，按 `3` 看 7 个安全场景，按 `0` 退出。

---

## 二、如果报错了，检查这 3 步

### 1. 确认 MoonBit 安装正确

```cmd
moon version
```

应该显示 `moon 0.1.20260608` 或更高。如果显示旧版本或找不到命令：

```powershell
# PowerShell 重装
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

### 2. 确认在正确目录下

```cmd
cd D:\moonbit\aegisrun
dir quickstart.cmd
```

如果找不到文件，说明你没在项目根目录。

### 3. 清除编译缓存

```cmd
rmdir /s /q target
```

改代码后如果运行结果不变，就是缓存没清。

---

## 三、常见坑及解决办法

| 现象 | 原因 | 解决 |
|------|------|------|
| `文件名、目录名或卷标语法不正确` | 在 CMD 里用了 PS 语法 `$env:X = "v"` | CMD 用 `set X=v` |
| `'set' is not recognized` | 在 PS 里用了 CMD 语法 `set X=v` | PS 用 `$env:X = "v"` |
| 运行时输出和代码不一致 | build 缓存被污染 | `rmdir /s /q target` |
| `Package "lib" not found` | 文件没放在 `src/` 下面 | `src/` 下的包才能用 `@lib` |
| 改了文件名但还跑原来的 | MoonBit 不认 `_` 前缀和 `.bak` | 需要改扩展名，如 `.mbt.bak` |
| 运行报 `abstract type` | struct 字段没有 `pub` | 跨包访问需要加 `pub` 或访问器函数 |
| 两个文件都有 `main` | MoonBit 一个包只能有一个主入口 | 删掉多余的或改成其他函数名 |

---

## 四、所有命令速查

### 新手首选

| 命令 | 效果 |
|------|------|
| `quickstart.cmd` | 一键菜单 |
| `aegisrun.exe demo` | 策略引擎演示（14项检查） |
| `aegisrun.exe scan malware.py` | 扫描脚本找威胁 |

### MoonBit Demo（2个）

| 命令 | 效果 |
|------|------|
| `moon run src/demo/intercept.mbt` | 12种攻击拦截演示 |
| `moon run src/generator/generator.mbt` | 恶意脚本生成器 |

### Rust CLI（统一入口）

| 命令 | 效果 |
|------|------|
| `aegisrun.exe demo` | 策略引擎演示 |
| `aegisrun.exe scan file.py` | 扫描脚本找威胁 |
| `aegisrun.exe serve` | Web 管理面板 |
| `aegisrun.exe policy show` | 查看策略 |
| `aegisrun.exe policy set strict` | 切换预设 |

### 使用库（写代码调用）

```rust
// Rust: cargo add aegisrun-runtime
let policy = Policy::standard();
policy.check_domain("evil.com"); // → false
scan_script(&source);            // → 返回违规列表
```

```moonbit
// MoonBit: import @aegisrun/lib
let policy = @lib.new_policy_engine()
@lib.check_domain(bl, suffixes, "evil.com") // → Deny
```

---

## 五、代码改了怎么验证

```cmd
rmdir /s /q target          ← 清缓存
moon build                   ← 只编译，不运行
moon run src/xxx/xxx.mbt     ← 编译+运行
```

`moon run` = `moon build` + 自动执行，通常一步就够了。

---

## 六、环境变量说明

| 变量 | 作用 | 示例 |
|------|------|------|
| `AEGISRUN_DEMO` | 选择单独 demo（1-7） | `set AEGISRUN_DEMO=2` |
| `AEGISRUN_ATTACKS` | 选择攻击类型（1-12） | `set AEGISRUN_ATTACKS=1,4,7,12` |

不设变量 = 默认跑全部。

---

## 七、文件结构速览

```
aegisrun/
├── quickstart.cmd        ← 新手入口（双击）
├── run_demo.bat          ← 旧版菜单
├── src/lib/              ← 核心库（10 个模块）
│   ├── core.mbt          ← 黑名单引擎 + 策略引擎
│   ├── sandbox.mbt       ← 沙箱拦截层
│   ├── scorer.mbt        ← 风险评分引擎 v1.1
│   ├── sql_guard.mbt     ← SQL 资源控制 v1.2
│   ├── limiter.mbt       ← 并发限流器 v1.3
│   ├── monitor.mbt       ← 压力监控 v1.4
│   ├── dns_guard.mbt     ← DNS 劫持检测 v0.3
│   ├── alert.mbt         ← 告警通知
│   └── dashboard.mbt     ← 终端仪表盘
├── docs/                 ← 公开文档
│   ├── ARCHITECTURE.md   ← 架构+完整调用链
│   └── DOCUMENTATION-GUIDE.md ← 文档规范
└── CHANGELOG.md          ← 版本日志
```

---

## 八、12 种攻击速查

| # | 表面功能 | 隐藏行为 | AegisRun 怎么拦 |
|:--:|------|------|------|
| 1 | 数据分析 | POST evil.com | `check_domain` 精确命中 |
| 2 | 导出助手 | POST *.cn | `check_domain` 后缀匹配 |
| 3 | 网络诊断 | GET 192.168.1.100 | 内网 IP 黑名单 |
| 4 | 配置读取器 | open(/etc/passwd) | `check_path` 精确命中 |
| 5 | SSH 导入 | open(~/.ssh/id_rsa) | `check_path` 前缀匹配 |
| 6 | 系统信息 | open(C:\Windows\SAM) | `check_path` 前缀匹配 |
| 7 | AI 插件 | getenv(OPENAI_API_KEY) | `check_env` 敏感模式 |
| 8 | 数据库迁移 | getenv(DATABASE_URL) | `check_env` 敏感模式 |
| 9 | 备份同步 | POST stealer.cc | `check_domain` 精确命中 |
| 10 | 开发监控 | GET localhost:3000 | 回环地址黑名单 |
| 11 | CI 状态检查 | getenv(GITHUB_TOKEN) | TOKEN 关键词检测 |
| 12 | 云配置备份 | open(.aws) + POST evil | 双重拦截 |
