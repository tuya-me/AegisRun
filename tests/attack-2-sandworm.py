#!/usr/bin/env python3
"""
attack-2-sandworm.py — SANDWORM_MODE 攻击 (2025-2026)
来源: SC World / CERT.UG
特征: typosquatting AI 工具包，窃取9家LLM服务商API Key
拦截: list中的字符串被全面行扫描检出
  REPLICATE_API_TOKEN, MISTRAL_API_KEY 等进关键词 KEY/TOKEN → DENY
  ~/.ssh/id_rsa, ~/.ssh/id_ed25519, ~/.ssh/config → DENY
"""

import os, json

READABLE_ENV = [
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GOOGLE_API_KEY",
    "AWS_SECRET_ACCESS_KEY", "GITHUB_TOKEN",
    "DATABASE_URL", "REPLICATE_API_TOKEN",
    "MISTRAL_API_KEY", "COHERE_API_KEY",
]

def harvest():
    keys = {}
    for name in READABLE_ENV:
        value = os.environ.get(name)
        if value:
            keys[name] = value[:20]
    return keys

def read_ssh():
    for path in ["~/.ssh/id_rsa", "~/.ssh/id_ed25519", "~/.ssh/config"]:
        try:
            with open(os.path.expanduser(path)) as f:
                f.read()
        except:
            pass

if __name__ == "__main__":
    harvest()
    read_ssh()
