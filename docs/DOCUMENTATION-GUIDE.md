# AegisRun 文档存放规范

> v0.2.0 | 2026-06-22

---

## 文档分类

### 公开文档 → GitLink 仓库 `D:\moonbit\aegisrun\`

推送到 `https://gitlink.org.cn/tuya/AegisRun`，评审可见。

```
D:\moonbit\aegisrun\
├── README.md                    ← 项目首页（简体中文，含快速开始+调用方式）
├── CHANGELOG.md                 ← 版本更新日志
├── ROADMAP.md                   ← 路线图 v1.1 → v2.0
├── policy.example.yaml          ← 策略配置示例
├── presets/                     ← 安全预设模板
│   ├── strict.yaml
│   ├── standard.yaml
│   └── permissive.yaml
└── docs/                        ← 详细设计文档
    ├── DOCUMENTATION-GUIDE.md   ← 本文档
    ├── ARCHITECTURE.md          ← 架构文档（完整调用链+数据结构）
    └── SECURITY-POLICY.md       ← 安全策略白皮书
```

**规则**：
- `*.md` 全部用简体中文撰写
- 文件名全大写
- 不包含本地路径、个人凭证等敏感信息

---

### 本地私有文档 → `D:\moonbit\md\`

**不推送**，仅本地参考。

```
D:\moonbit\md\
├── 01-参赛方案.md               ← OSC2026 参赛方案（含敏感策略细节）
├── 02-项目申报书.md / .docx     ← 项目申报书（含联系方式）
├── 03-演示PPT.pptx              ← 竞赛演示幻灯片
└── AegisRun_AI_Agent_参赛方案.md(备份)
```

**规则**：
- `01-` `02-` 前缀按重要程度排序
- `.md` 格式优先，`.docx`/`.pptx` 仅在需要格式富文本时保留
- 此目录**已被 .gitignore 排除**（或在仓库外）

---

### 不应提交到 Git 的文件

| 类型 | 位置 | 原因 |
|------|------|------|
| `target/` | 编译产物 | 已 .gitignore |
| `_build/` | 中间构建 | 已 .gitignore |
| `*.log` | 日志 | 已 .gitignore |
| `gen_*.py` | 临时生成脚本 | 用完即删 |

---

## 命名规范

| 类型 | 格式 | 示例 |
|------|------|------|
| 项目首页 | `README.md` | `README.md` |
| 变更日志 | `CHANGELOG.md` | `CHANGELOG.md` |
| 路线图 | `ROADMAP.md` | `ROADMAP.md` |
| 架构文档 | `docs/ARCHITECTURE.md` | `docs/ARCHITECTURE.md` |
| 安全策略 | `docs/SECURITY-POLICY.md` | `docs/SECURITY-POLICY.md` |
| 参赛方案 | `md/01-参赛方案.md` | `md/01-参赛方案.md` |
| 申报书 | `md/02-项目申报书.md` | `md/02-项目申报书.md` |
| 演示PPT | `md/03-演示PPT.pptx` | `md/03-演示PPT.pptx` |

---

## 当前文档清单

| 文档 | 位置 | 公开? | 内容 | 最后更新 |
|------|------|:--:|------|:--:|
| README | aegisrun/ | ✅ | 项目说明+快速开始+调用方式 | 2026-07-05 |
| GUIDE | aegisrun/ | ✅ | 新手指南 | ✅ |
| ROADMAP | aegisrun/ | ✅ | v1.1→v2.0 路线图 | ✅ 已更新 |
| CHANGELOG | aegisrun/ | ✅ | v0.1.0~v0.5.0 变更 | ✅ 已更新 |
| ARCHITECTURE | aegisrun/docs/ | ✅ | 完整调用链+数据结构 | ✅ 已更新 |
| CONTRIBUTING | aegisrun/docs/ | ✅ | 开发者指南+贡献方向 | ✅ 已标注完成项 |
| 使用指南 | aegisrun/docs/ | ✅ | 详细调用方式 | ✅ |
| DOCUMENTATION-GUIDE | aegisrun/docs/ | ✅ | 本文档 | ✅ |
| 参赛方案 | md/ | ❌ | OSC2026 参赛方案全文 | — |
| 项目申报书 | md/ | ❌ | 附录二格式申报书 | — |
| 演示PPT | md/ | ❌ | 演示幻灯片 | — |
