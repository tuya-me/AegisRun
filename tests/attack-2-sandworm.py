#!/usr/bin/env python3
"""
attack-2-sandworm.py — 基于 SANDWORM_MODE 攻击 (2025-2026)
无害化处理: 使用测试域名
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

def read_npm():
    for path in ["~/.npmrc", "~/.token"]:
        try:
            with open(os.path.expanduser(path)) as f:
                for line in f:
                    if "token" in line.lower() or "auth" in line.lower():
                        pass
        except:
            pass

if __name__ == "__main__":
    harvest()
    read_ssh()
    read_npm()
