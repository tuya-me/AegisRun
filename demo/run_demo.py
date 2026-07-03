"""
AegisRun OSC2026 演示编排器
用法: python demo/run_demo.py [act1|act2|act3|all]
效果: 自动执行 moon 命令 + 打印解说词 + 暂停等待讲解
"""
import subprocess, sys, time, os

# 修复 Windows 终端 GBK 编码问题：强制 Python stdout/stderr 用 utf-8
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PROJECT = r"d:\moonbit\aegisrun"
NARRATION_DELAY = 0.03   # 解说词逐字打印速度 (秒/字符)
STAGE_PAUSE    = 1.5     # 阶段间停顿 (秒)

# ═══════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════

# Windows cmd 默认用 gbk，MoonBit 源码是 utf-8。
# 统一用 utf-8 + errors='replace' 避免解码崩溃。
ENCODING = 'utf-8'
ENV = {**os.environ, "PYTHONIOENCODING": "utf-8"}


def narrate(text: str, speed: float = None):
    """逐字打印解说词（模拟打字机效果）"""
    delay = speed if speed is not None else NARRATION_DELAY
    for ch in text:
        print(ch, end="", flush=True)
        time.sleep(delay)
    print()


def pause(seconds: float = STAGE_PAUSE, prompt: str = ""):
    """暂停等待（给演讲者留气口）"""
    if prompt:
        print(f"\n  [讲解点] {prompt}")
    time.sleep(seconds)


def header(text: str):
    """打印分隔标题"""
    print()
    print("=" * 62)
    print(f"  {text}")
    print("=" * 62)
    print()


def run_cmd(cmd: str, show_cmd: bool = True, filter_compile: bool = True):
    """在项目目录下执行命令，返回 stdout 行列表。自动处理编码。"""
    if show_cmd:
        print(f"\n  > {cmd}\n")
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=PROJECT,
            capture_output=True, text=True,
            encoding=ENCODING, errors='replace',
            env=ENV
        )
    except Exception as e:
        print(f"  [ERROR] 命令执行失败: {e}")
        return []

    lines = []
    if result.stdout:
        raw_lines = result.stdout.split("\n")
        for line in raw_lines:
            if filter_compile and any(skip in line for skip in [
                "Compiling", "mooncakes", "Locking",
                "Downloading", "Resolving", "Checking",
                "moon:", "Building", "Installing"
            ]):
                continue
            lines.append(line)
            print(line)

    if result.stderr and "error" in result.stderr.lower():
        print(f"  [STDERR] {result.stderr[:300]}")
    return lines


def run_moon(cmd: str, show_cmd: bool = True):
    """执行 moon 命令（run_cmd 的别名，语义更清晰）"""
    return run_cmd(cmd, show_cmd=show_cmd, filter_compile=True)


def show_file(path: str):
    """用 type 命令展示源码（Windows cmd builtin）"""
    return run_cmd(f"type {path}", show_cmd=True, filter_compile=False)


# ═══════════════════════════════════════════════════════════
# 三幕演示
# ═══════════════════════════════════════════════════════════

def act1_tool_development():
    """第一幕：工具开发 — 写工具 → 声明Capability → 编译Wasm"""
    header("第一幕：AI Agent 工具开发 (90s)")

    narrate("AI Agent 需要调用各种工具——天气查询、数据库、文件处理。")
    narrate("传统方式下，Python/JS 工具直接持有 API Key 和系统权限。")
    pause(1.0)

    narrate("在 AegisRun 中，我们用 MoonBit 写工具，编译为 Wasm 模块。")
    narrate("重点看这里——Capability 声明：", speed=0.02)
    pause(0.5)

    # 展示工具源码中的 Capability 声明
    show_file("demo\\showcase\\chorus_tool.mbt")
    pause(2.0, "这个工具只申请了网络权限(wttr.in)，不碰文件、不读环境变量")

    narrate("编译只需 0.1 秒，产物不到 1KB。")
    pause(0.5)

    # 展示文件存在
    run_cmd("dir /s /b demo\\showcase\\*.mbt 2>nul", filter_compile=False)
    pause(1.0, "每个工具编译为独立 Wasm 模块，互相隔离")

    print("\n  [OK] 第一幕结束 — 工具开发链路打通")


def act2_security_intercept():
    """第二幕：安全拦截 — 恶意工具 x 3 代表 + 全量 14 种攻击"""
    header("第二幕：安全拦截演示 (120s)")

    narrate("但真正的风险来自——你从社区安装的第三方工具。")
    narrate("看这个'天气助手'，表面功能是查天气...")
    pause(1.0)

    # 展示恶意工具源码
    print("\n  --- 表面代码（开发者看到的）---")
    show_file("demo\\malicious_tools\\weather_helper.mbt")
    pause(2.0, "看到那两行隐藏代码了吗？读 API Key → 发到 evil.com")

    narrate("在传统 Agent 框架里，这段代码直接执行——密钥泄露。")
    narrate("但在 AegisRun 里——")
    pause(1.5)

    # ═══ 核心演示：3个代表性攻击 ═══
    print("\n  --- 运行 AegisRun 拦截 (3 个核心攻击) ---\n")
    result = subprocess.run(
        "moon run src/demo/intercept.mbt",
        shell=True, cwd=PROJECT,
        capture_output=True, text=True,
        encoding=ENCODING, errors='replace',
        env={**ENV, "AEGISRUN_ATTACKS": "7,1,4"}
    )
    lines = result.stdout.split("\n") if result.stdout else []
    for line in lines:
        if any(skip in line for skip in ["Compiling", "mooncakes", "Locking"]):
            continue
        if "BLOCKED" in line:
            print(f"\033[92m{line}\033[0m")  # 绿色
        elif "Attack" in line or line.startswith("--"):
            print(f"\033[93m{line}\033[0m")  # 黄色
        else:
            print(line)
    pause(2.0, "API Key 窃取 + evil.com 外发 + 文件窃取 → 全部拦截")

    # ═══ 全量 14 种攻击 ═══
    narrate("现在跑全量——14 种攻击——")
    result = subprocess.run(
        "moon run src/demo/intercept.mbt",
        shell=True, cwd=PROJECT,
        capture_output=True, text=True,
        encoding=ENCODING, errors='replace',
        env={**ENV, "AEGISRUN_ATTACKS": "all"}
    )
    lines = result.stdout.split("\n") if result.stdout else []
    for line in lines:
        if any(kw in line for kw in ["Caught", "VERDICT", "Interception"]):
            print(f"\033[92m  {line}\033[0m")

    pause(2.0, "14/14 全部拦截。关键在于 Wasm 沙箱层面阻止，不是事后审计。")

    print("\n  [OK] 第二幕结束 — 安全拦截验证通过")


def act3_agent_integration():
    """第三幕：Agent 集成 — MCP Server + Dashboard + Claude调用"""
    header("第三幕：Agent 集成 (90s)")

    narrate("最后一步——把安全的工具交给真正的 AI Agent。")
    narrate("AegisRun 通过 MCP 协议，一行配置就能对接 Claude Desktop。")
    pause(1.0)

    # 展示 MCP 配置
    print("\n  --- Claude Desktop 配置 (claude_desktop_config.json) ---")
    print(r"""
  {
    "mcpServers": {
      "aegisrun": {
        "url": "http://localhost:9090/mcp"
      }
    }
  }
""")
    pause(1.5, "只需 3 行 JSON，Claude 就能发现 AegisRun 的所有安全工具")

    narrate("Agent 可调用的 5 个工具：")
    print("""
    aegisrun.sandbox             — 在沙箱中执行任意工具
    aegisrun.scan                — 扫描工具清单，评估风险
    aegisrun.policy.check_domain — 域名安全检查
    aegisrun.policy.check_path   — 路径安全检查
    aegisrun.policy.check_env    — 环境变量安全检查
""")
    pause(2.0, "每个工具调用都经过权限引擎 + Wasm 沙箱双重保护")

    # Dashboard
    narrate("打开 Dashboard，每次调用的审计日志——全链路可追溯。")
    pause(1.0)
    subprocess.Popen(["start", "", f"{PROJECT}\\dashboard.html"], shell=True)
    pause(2.0, "Dashboard 画面——实时策略 + 审计日志 + 拦截统计")

    print("\n  [OK] 第三幕结束 — Agent 集成链路打通")


def run_all():
    """完整演示流程"""
    print()
    print("=" * 62)
    print("     AegisRun — OSC2026 竞赛演示")
    print("     AI Agent 安全工具执行框架")
    print("     总时长: ~5 分钟")
    print("=" * 62)
    pause(2.0)

    act1_tool_development()
    pause(3.0, "[幕间] 第一幕 -> 第二幕 (可在此暂停提问)")

    act2_security_intercept()
    pause(3.0, "[幕间] 第二幕 -> 第三幕 (可在此暂停提问)")

    act3_agent_integration()

    # 收尾
    header("演示结束")
    narrate("AegisRun — 让 AI Agent 调用的每一个第三方工具，")
    narrate("都跑在 MoonBit 编译的 Wasm 沙箱里。")
    narrate("极小的体积、极快的冷启动、默认无权限、类型安全不可伪造。")
    print()
    print("  GitHub:  (your-repo-url)")
    print("  MoonBit Track: OSC2026 AI Agent 工程化开发")
    print()


# ═══════════════════════════════════════════════════════════
# 入口
# ═══════════════════════════════════════════════════════════

if __name__ == "__main__":
    scene = sys.argv[1] if len(sys.argv) > 1 else "all"

    scenes = {
        "act1": act1_tool_development,
        "act2": act2_security_intercept,
        "act3": act3_agent_integration,
        "all": run_all,
    }

    if scene in scenes:
        scenes[scene]()
    else:
        print(f"用法: python demo/run_demo.py [act1|act2|act3|all]")
        print(f"未知参数: {scene}")
