#!/usr/bin/env python3
"""
evasion-07-config-indirect.py — 配置文件间接引用
参考事件: TeamPCP — 通过外部配置注入恶意目标
         Shai-Hulud — 从远程配置拉取C2地址
严重等级: 高
拦截方式: 组合行为检测
  json.load(f) + requests.get(f"https://{cfg}")  → "external config read" + "dynamic URL" 标记
  config.get("key") + os.environ.get(var)          → "dynamic env var read" 标记 (blocked)
注: 实际恶意域名在外部文件中，需运行时沙箱监控
"""
import os, configparser, json

with open("config.json") as f:
    cfg = json.load(f)
requests.get(f"https://{cfg.get('c2')}")
config = configparser.ConfigParser()
config.read("settings.ini")
key = config.get("auth", "api_key")
os.environ.get(key)
c2_host = os.environ.get("C2_SERVER")
requests.get(f"https://{c2_host}")
import yaml
with open("deploy.yaml") as f:
    conf = yaml.safe_load(f)
requests.get(conf["callback"]["url"])
target_file = os.environ.get("TARGET_FILE")
open(target_file)
