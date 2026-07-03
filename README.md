# AegisRun v0.5.0

**AI Agent 安全工具执行框架 — MoonBit + Rust**

MoonBit 策略引擎做判断（check_domain/check_path/check_env），Rust wasmtime WASI 物理隔离做拦截。

## 快速开始

```cmd
cd D:\moonbit\aegisrun
moon run src/demo/intercept.mbt      # 12种攻击拦截演示
moon run src/generator/generator.mbt  # 恶意脚本生成器
aegisrun.exe demo                     # Rust CLI 演示
aegisrun.exe scan malware.py          # 脚本安全扫描
```

## 使用库

**MoonBit**: `moon add aegisrun` → `AegisRun::new("standard").check_domain("evil.com")`

**Rust**: `cargo add aegisrun-runtime` → `Policy::standard().check_domain("evil.com")`

## 五层防御

①安装时声明审查 ②域名/IP黑名单(45+规则) ③路径+环境变量保护(30+) ④工具黑名单+审计 ⑤wasmtime WASI物理隔离

## 验证

```cmd
aegisrun.exe sandbox evil-plugin.wasm
→ /etc/passwd: os error 44 (blocked)
→ OPENAI_API_KEY: not set (blocked)
→ 27/27 malicious operations intercepted
```

## 文档

[新手指南](GUIDE.md) · [路线图](ROADMAP.md) · [更新日志](CHANGELOG.md) · [架构文档](docs/ARCHITECTURE.md) · [使用指南](docs/使用指南.md)
