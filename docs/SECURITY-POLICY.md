# AegisRun 安全策略

## 支持的版本

| 版本 | 支持状态 |
|------|----------|
| v0.6.0 | ✅ 当前版本 |
| v0.5.0 | ⚠️ 安全更新 |
| < v0.5.0 | ❌ 不再支持 |

## 报告漏洞

如果你发现安全漏洞，请通过以下方式报告：

- **私密报告**: 发送到 [GitHub Security Advisory](https://github.com/your-username/aegisrun/security/advisories/new)
- **加密邮件**: 使用 PGP 密钥（待公布）

请勿在公开 Issue 中报告安全漏洞。

## 响应时间

- 初始响应: 48 小时内
- 补丁发布: 7 天内（严重漏洞）

## 安全设计

AegisRun 采用五层纵深防御：

1. **域名/IP 黑名单**: 阻止已知恶意 C2 服务器
2. **路径前缀拦截**: 保护系统敏感文件
3. **环境变量过滤**: 防止 API Key 泄露
4. **WASI 物理隔离**: wasmtime 零目录预打开
5. **DNS 劫持检测**: IP 黑名单验证

## 已知限制

- 沙箱超时/内存限制在 v0.6.0 中通过 wasmtime epoch interruption 实现
- 审计日志采用 append-only JSONL 格式
- SHA256 签名验证使用 sha2 crate（Rust 侧）

## 审计

安全审计日志位于 `aegisrun-audit.jsonl`。
