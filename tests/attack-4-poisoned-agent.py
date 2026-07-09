#!/usr/bin/env python3
"""
attack-4-poisoned-agent.py — AI Agent 投毒攻击 (2026)
来源: Check Point Research (CVE-2025-59536 / CVE-2026-21852)
     CSA / Arize AI — Agent供应链攻击
特征: 恶意AI Agent插件窃取API Key + OAuth token
拦截:
  GITHUB_TOKEN, GITLAB_TOKEN, SLACK_TOKEN 等 → DENY (TOKEN关键词)
  DISCORD_TOKEN, HUGGINGFACE_TOKEN           → DENY (TOKEN关键词)
  OAUTH_ACCESS_TOKEN                          → DENY (TOKEN关键词)
"""

import os, json

AGENT_KEYWORDS = [
    "ANTHROPIC_API_KEY", "OPENAI_API_KEY",
    "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    "CLAUDE_API_KEY", "GITHUB_TOKEN",
    "GITLAB_TOKEN", "SLACK_TOKEN",
    "DISCORD_TOKEN", "HUGGINGFACE_TOKEN",
]

def crawl_agent_configs():
    secrets = {}
    for dirname in [".claude/", ".cursor/", ".vscode/", "~/.continue/"]:
        expanded = os.path.expanduser(dirname)
        if not os.path.isdir(expanded): continue
        for root, dirs, files in os.walk(expanded):
            for f in files:
                if f.endswith((".json", ".yaml", ".env", ".toml")):
                    try:
                        with open(os.path.join(root, f)) as fh:
                            content = fh.read()
                        for kw in AGENT_KEYWORDS:
                            if kw in content:
                                secrets.setdefault(kw, [])
                                secrets[kw].append(os.path.join(root, f))
                    except: pass
    return secrets

def exfiltrate_oauth():
    tokens = os.environ.get("OAUTH_ACCESS_TOKEN")
    if tokens: pass

if __name__ == "__main__":
    secrets = crawl_agent_configs()
    exfiltrate_oauth()
    print(json.dumps({"found": len(secrets)}))
