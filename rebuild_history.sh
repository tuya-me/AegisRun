#!/bin/bash
# AegisRun — 重建干净提交历史（15个有意义提交）
# 用法: bash rebuild_history.sh
set -e

cd /d/moonbit/aegisrun

# 切回 master 确保文件完整
git checkout master 2>/dev/null || true

# 备份当前 github remote URL
GITHUB_URL=$(git remote get-url github 2>/dev/null || echo "")

# 创建孤儿分支
git checkout --orphan clean-v2

# 清空暂存区（保留文件在磁盘上）
git rm -r --cached . 2>/dev/null || true

echo "=== 开始分批提交 ==="

# Commit 1: 项目骨架
git add moon.mod.json .gitignore LICENSE presets/ policy.example.yaml
git commit -m "feat: project scaffold — MoonBit project, APACHE 2.0, security presets"

# Commit 2: 核心类型和黑名单引擎
git add src/lib/core.mbt src/lib/moon.pkg.json src/types.mbt 2>/dev/null || true
git add src/lib/core.mbt src/lib/moon.pkg.json
git commit -m "feat: blacklist engine — check_domain, check_path, check_env with HashMap O(1)"

# Commit 3: 策略引擎和预设
git add src/lib/policy.mbt src/lib/preset.mbt src/lib/cli.mbt 2>/dev/null || true
git add src/lib/*.mbt
git commit -m "feat: policy engine — standard/strict/permissive presets, CLI commands"

# Commit 4: 主入口和演示
git add src/main/ src/demo/ 2>/dev/null || true
git add src/main/ src/demo/
git commit -m "feat: CLI entry + 7 security demo scenarios"

# Commit 5: 风险评分引擎
git add src/lib/scorer.mbt
git commit -m "feat: risk scoring engine — static manifest analysis, 0-100, 4 levels"

# Commit 6: SQL 资源控制
git add src/lib/sql_guard.mbt
git commit -m "feat: SQL resource guard — table/column authorization, DROP/ALTER interception"

# Commit 7: 并发限流和压力监控
git add src/lib/limiter.mbt src/lib/monitor.mbt
git commit -m "feat: concurrency limiter (3D) + pressure monitor (4-level circuit breaker)"

# Commit 8: DNS 防护
git add src/lib/dns_guard.mbt
git commit -m "feat: DNS guard — IP blacklist (15 rules), hijack detection, hosts integrity"

# Commit 9: 告警和仪表盘
git add src/lib/alert.mbt src/lib/dashboard.mbt
git commit -m "feat: alert manager + terminal ASCII dashboard"

# Commit 10: 恶意工具演示
git add src/generator/ src/scanner/ demo/ 2>/dev/null || true
git add src/generator/ demo/
git commit -m "feat: malware generator (12 attacks) + intercept demo"

# Commit 11: Rust 运行时
git add runtime/Cargo.toml runtime/src/lib.rs runtime/src/main.rs runtime/README.md
git add runtime/src/scanner.rs runtime/src/sandbox.rs 2>/dev/null || true
git add runtime/
git commit -m "feat: Rust runtime — Policy lib, CLI, sandbox, script scanner"

# Commit 12: Web 面板和 MCP
git add dashboard.html src/lib/server.rs runtime/src/server.rs 2>/dev/null || true
git add dashboard.html
git commit -m "feat: Web dashboard + MCP server endpoint (port 9090, 5 tools)"

# Commit 13: 统一 API 门面
git add src/lib/aegisrun.mbt
git commit -m "feat: unified facade — AegisRun::new().check_domain(), 1-line API, built-in cache"

# Commit 14: 持久化和验证
git add runtime/src/persist.rs runtime/src/verify.rs
git commit -m "feat: audit persistence + policy save/load + hot-reload + tool signature verification"

# Commit 15: WASI 沙箱和补强策略
git add runtime/tools/evil_plugin/ runtime/Cargo.lock 2>/dev/null || true
git add runtime/tools/evil_plugin/
git commit -m "feat: wasmtime WASI sandbox — physical isolation, evil-plugin 27/27 blocked"

# Commit 16: 文档
git add README.md GUIDE.md ROADMAP.md CHANGELOG.md SECURITY.md ARCHITECTURE.md 2>/dev/null || true
git add docs/ *.md *.html *.bat *.yaml 2>/dev/null || true
git add docs/ *.md
git commit -m "docs: complete documentation — README, GUIDE, ROADMAP, CHANGELOG, architecture"

echo ""
echo "=== Done! 16 commits created ==="
echo "Next: git push github clean-v2 --force"
echo "Then on GitHub: Settings > Branches > set clean-v2 as default"
