# AegisRun Documentation Guide / 文档规范

> v0.8.0 | Standard for all project documentation / 项目所有文档的编写标准

<style>
.en { display: none; }
.zh { display: block; }
#en:target { display: block; }
#en:target ~ .zh { display: none; }
.lang-bar { text-align: center; margin: 16px 0; }
.lang-btn { display: inline-block; padding: 6px 20px; background: #f0f0f0; border-radius: 20px; text-decoration: none; color: #333; font-size: 14px; margin: 0 4px; }
.lang-btn:hover { background: #e0e0e0; }
</style>

<div class="lang-bar">
<a href="#en" class="lang-btn">🇬🇧 English</a>
<a href="#zh-cn" class="lang-btn">🇨🇳 中文</a>
</div>

---

<div id="en" class="en">

## Structure

All public documentation lives under `docs/`. The only `.md` file at the project root is `README.md`.

```
D:\moonbit\aegisrun\
├── README.md                    ← Project overview (architecture + navigation)
│
└── docs/                        ← All other documentation
    ├── GUIDE.md                    User guide (beginner + detailed levels, bilingual)
    ├── ARCHITECTURE.md             Full call chain + data structures
    ├── CONTRIBUTING.md             Developer contribution guide
    ├── CHANGELOG.md                Version history
    ├── SECURITY-POLICY.md          Security policy whitepaper
    └── DOCUMENTATION-GUIDE.md      This file
```

## Conventions

| Item | Rule |
|------|------|
| Language | All docs bilingual (English + Chinese) |
| Toggle | Every page has a CN/EN toggle bar at top using CSS `:target` |
| Filename | English uppercase for root docs; English for docs/ |
| Content | Code blocks are language-agnostic; text alternates by section |
| Sensitive info | No local paths, credentials, or internal details |

## Language Toggle Mechanism

Each documentation page uses the CSS `:target` pseudo-class to switch between English and Chinese:

```html
<style>
.en { display: none; }
.zh { display: block; }
#en:target { display: block; }
#en:target ~ .zh { display: none; }
</style>

<a href="#en">🇬🇧 English</a>
<a href="#zh-cn">🇨🇳 中文</a>

<div id="en" class="en">...English...</div>
<div class="zh">...中文...</div>
```

- Default: shows Chinese
- Click "English": URL hash becomes `#en` → English visible, Chinese hidden
- Click "中文": URL hash becomes `#zh-cn` → Chinese visible
- Graceful degradation: if CSS is not supported, both languages display stacked

## Not in Repository (Local Only / Private)

- OSC2026 competition proposal: `D:\moonbit\md\01-参赛方案.md`
- Project declaration: `D:\moonbit\md\02-项目申报书.md`
- Presentation slides: `D:\moonbit\md\03-演示PPT.pptx`

These are excluded from git and kept locally.

</div>

<div class="zh">

## 文档结构

所有公开文档统一放在 `docs/` 目录下，项目根目录只保留 `README.md`。

```
D:\moonbit\aegisrun\
├── README.md                    ← 项目概览（架构 + 文档导视）
│
└── docs/                        ← 所有其他文档
    ├── GUIDE.md                    使用指南（新手级 + 详情级，中英双语）
    ├── ARCHITECTURE.md             架构 + 完整调用链 + 数据结构
    ├── CONTRIBUTING.md             开发者贡献指南
    ├── CHANGELOG.md                版本更新日志
    ├── SECURITY-POLICY.md          安全策略白皮书
    └── DOCUMENTATION-GUIDE.md      本文档
```

## 编写规范

| 项目 | 规则 |
|------|------|
| 语言 | 全部文档中英双语 |
| 切换 | 每页顶部有 CN/EN 切换按钮，使用 CSS `:target` 实现 |
| 文件名 | 统一使用英文 |
| 内容 | 代码块语言无关；文本按章节交替中英文 |
| 隐私 | 不包含本地路径、个人凭证等敏感信息 |

## 语言切换机制

每页文档通过 CSS `:target` 伪类实现中英文切换：

```html
<style>
.en { display: none; }
.zh { display: block; }
#en:target { display: block; }
#en:target ~ .zh { display: none; }
</style>

<a href="#en">🇬🇧 English</a>
<a href="#zh-cn">🇨🇳 中文</a>

<div id="en" class="en">...English content...</div>
<div class="zh">...中文内容...</div>
```

- 默认显示中文
- 点击 English → URL hash 变为 `#en` → 显示英文，隐藏中文
- 点击 中文 → URL hash 变为 `#zh-cn` → 显示中文
- 降级处理：若 CSS 不支持，两种语言同时显示

## 不提交到仓库的文件

- OSC2026 参赛方案：`D:\moonbit\md\01-参赛方案.md`
- 项目申报书：`D:\moonbit\md\02-项目申报书.md`
- 演示 PPT：`D:\moonbit\md\03-演示PPT.pptx`

以上文件仅在本地，已通过 .gitignore 排除。

</div>
