#!/usr/bin/env python3
"""
evasion-08-cloud-metadata.py — 云元数据服务攻击 (IMDS)
参考事件: CAI Cloud Worm (2026.07) — 云环境凭证窃取
         TeamPCP — 通过CI/CD窃取云凭证
严重等级: 严重 (高)
拦截方式: 云元数据IP加入黑名单策略
  http://169.254.169.254/       → 域名黑名单 169.254.* → DENY
  http://metadata.google.internal/ → 域名黑名单 *.internal → DENY
  http://100.100.100.200/       → 域名黑名单 100.100.* → DENY
"""
import os, requests

requests.get("http://169.254.169.254/latest/meta-data/")
requests.get("http://169.254.169.254/latest/meta-data/iam/security-credentials/admin")
requests.get("http://metadata.google.internal/computeMetadata/v1/")
requests.get("http://169.254.169.254/metadata/identity/oauth2/token")
requests.get("http://100.100.100.200/latest/meta-data/")
requests.get("http://localhost:2375/containers/json")
requests.get("https://kubernetes.default.svc/api/v1/secrets")
requests.get("http://localhost:2379/v2/keys/")
