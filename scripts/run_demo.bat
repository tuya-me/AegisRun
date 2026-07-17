@echo off
title AegisRun Lite - Security Demo

:menu
cls
echo.
echo   ===============================================
echo     AegisRun Lite v0.1.0 - Security Demo
echo   ===============================================
echo.
echo   Select a demo:
echo   -----------------------------------------------
echo   1. Tool Install - permission review
echo   2. Domain Blacklist - exfiltration blocking
echo   3. Path Blacklist - sensitive file access
echo   4. Env Var Protection - API key theft prevention
echo   5. Tool Blacklist - runtime ban and audit
echo   6. Audit Trail - full attack chain trace
echo   7. Policy Summary - current defense status
echo   8. Run ALL demos
echo   0. Exit
echo   -----------------------------------------------
echo.
set DEMO=
set /p DEMO=  Enter choice (0-8):
if "%DEMO%"=="0" goto :eof
if "%DEMO%"=="" goto menu

D:
cd D:\moonbit\aegisrun

if "%DEMO%"=="8" set AEGISRUN_DEMO=all
if "%DEMO%"=="7" set AEGISRUN_DEMO=7
if "%DEMO%"=="6" set AEGISRUN_DEMO=6
if "%DEMO%"=="5" set AEGISRUN_DEMO=5
if "%DEMO%"=="4" set AEGISRUN_DEMO=4
if "%DEMO%"=="3" set AEGISRUN_DEMO=3
if "%DEMO%"=="2" set AEGISRUN_DEMO=2
if "%DEMO%"=="1" set AEGISRUN_DEMO=1

if "%AEGISRUN_DEMO%"=="" goto menu

echo.
echo   Running Demo %DEMO%...
echo   ===============================================
echo.
moon run src/main
echo.
echo   ===============================================
echo   Demo complete. Press any key for menu...
pause >nul
goto menu
