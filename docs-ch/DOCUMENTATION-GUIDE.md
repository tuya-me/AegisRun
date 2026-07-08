# AegisRun 文档规范

> v1.0.0 | 项目文档编写标准

---

## 文档结构

```
D:\moonbit\aegisrun\
├── README.md                    ← 项目概览（中文）
├── docs-ch/                      ← 中文文档（主版本）
│   ├── GUIDE.md                    使用指南（新手级 + 详情级）
│   ├── ARCHITECTURE.md             架构 + 调用链 + 数据结构
│   ├── CONTRIBUTING.md             贡献指南
│   ├── CHANGELOG.md                更新日志
│   ├── SECURITY-POLICY.md          安全策略
│   └── DOCUMENTATION-GUIDE.md      本文档
└── docs-en/                      ← 英文文档（辅助版本）
    ├── GUIDE.md
    ├── ARCHITECTURE.md
    ├── CONTRIBUTING.md
    ├── CHANGELOG.md
    ├── SECURITY-POLICY.md
    └── DOCUMENTATION-GUIDE.md
```

## 编写规范

| 项目 | 规则 |
|------|------|
| 语言 | 中文为主，英文为辅 |
| 文档位置 | 中文文档统一在 `docs-ch/`，英文在 `docs-en/` |
| 文件名 | 统一使用英文（GUIDE.md 而非 使用指南.md）|
| 代码块 | 代码块语言无关，注释用中文 |
| 隐私 | 不包含本地路径、个人凭证等敏感信息 |


## 不提交到仓库的文件

- OSC2026 参赛方案：`D:\moonbit\md\01-参赛方案.md`
- 项目申报书：`D:\moonbit\md\02-项目申报书.md`
- 演示 PPT：`D:\moonbit\md\03-演示PPT.pptx`
