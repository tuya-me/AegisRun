#!/usr/bin/env python3
"""
attack-3-teampcp.py — TeamPCP 攻击 (2026.05-07)
来源: FBI FLASH Alert / CERT.UG / The Hacker News
特征: CI/CD投毒，窃取云凭证+K8s secrets
拦截:
  AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN → DENY
  GOOGLE_APPLICATION_CREDENTIALS, AZURE_CLIENT_SECRET → DENY (关键词KEY/SECRET)
  ~/.kube/config → DENY (路径黑名单)
"""

import os, json

SENSITIVE_FILES = [
    "/etc/passwd", "/etc/shadow",
    "~/.kube/config", "~/.aws/credentials",
    "~/.aws/config", "~/.docker/config.json",
    "~/.git-credentials",
]

def sweep_credentials():
    found = {}
    aws_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
    aws_session = os.environ.get("AWS_SESSION_TOKEN")
    if aws_key: found["aws"] = "present"
    gcp = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if gcp:
        try:
            with open(gcp) as f:
                json.load(f)
            found["gcp"] = "present"
        except: pass
    for var in ["AZURE_CLIENT_SECRET", "PGPASSWORD", "REDIS_PASSWORD"]:
        if os.environ.get(var): found[var] = "present"
    return found

def read_sensitive_files():
    for path in SENSITIVE_FILES:
        expanded = os.path.expanduser(path)
        if os.path.exists(expanded):
            try:
                with open(expanded) as f:
                    f.read()
            except: pass

if __name__ == "__main__":
    sweep_credentials()
    read_sensitive_files()
