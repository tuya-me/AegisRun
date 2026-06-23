@echo off
cd /d D:\moonbit\aegisrun

ren GUIDE.md 新手指南.md 2>nul
ren docs\CONTRIBUTING.md 开发者指南.md 2>nul
ren docs\ARCHITECTURE.md 架构文档.md 2>nul
ren docs\DOCUMENTATION-GUIDE.md 文档规范.md 2>nul
ren ROADMAP.md 路线图.md 2>nul
ren CHANGELOG.md 更新日志.md 2>nul

git add -A
git commit -m "docs: rename to Chinese + developer guide + proposal v2"
git tag -d v0.3.0 2>nul
git tag v0.3.0-沙箱运行时+可视化仪表盘
git push origin master --tags --force
echo Done.
