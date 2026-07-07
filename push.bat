@echo off
chcp 65001 >nul 2>&1

REM 从 .gitcredentials 读取 token，通过 credential helper 推送
REM 首次使用前：把 .gitcredentials 里的 REPLACE_ME 替换为真实 token

git config --local credential.helper "store --file %~dp0.gitcredentials"
git push origin clean-v2
