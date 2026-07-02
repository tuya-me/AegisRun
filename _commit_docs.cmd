@echo off
cd /d D:\moonbit\aegisrun
git add -A
git commit -m "docs: update all docs for v0.4.0 + proposal v3"
git push origin master
echo Done.
