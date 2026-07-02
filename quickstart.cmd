@echo off
title AegisRun — Quick Start
chcp 65001 >nul 2>&1

:menu
cls
echo.
echo   ===============================================
echo     AegisRun — AI Agent Secure Tool Runtime
echo     Quick Start Menu
echo   ===============================================
echo.
echo   1. Intercept Demo (all 12 attacks + dashboard)
echo   2. Intercept Demo (pick attacks yourself)
echo   3. Security Scenarios (7 demos)
echo   4. Malicious Tool Scanner (14 checks)
echo   5. Sandbox Demo (22 checks)
echo   6. Full Feature Demo (13 tests)
echo   7. CLI Commands Help
echo   8. Show Current Policy
echo   0. Exit
echo   ===============================================
echo.
set /p choice=  Enter choice (0-8):

if "%choice%"=="0" goto :eof
if "%choice%"=="1" call :run_all
if "%choice%"=="2" call :run_pick
if "%choice%"=="3" call :run_demo
if "%choice%"=="4" call :run_scanner
if "%choice%"=="5" call :run_sandbox
if "%choice%"=="6" call :run_full
if "%choice%"=="7" call :show_help
if "%choice%"=="8" call :show_policy
goto menu

:run_all
echo.
echo   Running: All 12 Attacks + Dashboard
echo   ===============================================
set AEGISRUN_ATTACKS=all
moon run src/generator/intercept.mbt
echo.
pause
goto :eof

:run_pick
cls
echo.
echo   Pick attacks to simulate (comma separated):
echo   1=evil.com  2=*.cn    3=192.168    4=/etc/passwd
echo   5=SSH key   6=SAM     7=API_KEY    8=DB_URL
echo   9=stealer   10=local  11=TOKEN     12=AWS+evil
echo.
set /p attacks=  Enter numbers (e.g. 1,4,7,12):
if "%attacks%"=="" set attacks=all
set AEGISRUN_ATTACKS=%attacks%
echo.
echo   Running: Attacks %attacks%
echo   ===============================================
moon run src/generator/intercept.mbt
echo.
pause
goto :eof

:run_demo
echo.
echo   Running: 7 Security Scenarios
echo   ===============================================
moon run src/main
echo.
pause
goto :eof

:run_scanner
echo.
echo   Running: Malicious Tool Scanner (14 checks)
echo   ===============================================
moon run src/scanner/scanner.mbt
echo.
pause
goto :eof

:run_sandbox
echo.
echo   Running: Sandbox Demo (22 checks)
echo   ===============================================
moon run src/sandbox_demo/sandbox_demo.mbt
echo.
pause
goto :eof

:run_full
echo.
echo   Running: Full Feature Demo (13 tests)
echo   ===============================================
moon run src/full_demo/full_demo.mbt
echo.
pause
goto :eof

:show_help
cls
echo.
echo   ===============================================
echo     CLI Commands
echo   ===============================================
echo.
echo   moon run src/main                     Run all demos
echo   moon run src/main preset standard     Switch preset
echo   moon run src/main deny tool TOOL_ID   Ban a tool
echo   moon run src/main allow domain DOMAIN Whitelist domain
echo   moon run src/main show                View policy
echo   moon run src/main demo 2              Run single demo
echo.
echo   moon run src/generator/intercept.mbt  Intercept demo
echo   moon run src/scanner/scanner.mbt      Malware scanner
echo   moon run src/sandbox_demo/sandbox_demo.mbt  Sandbox test
echo   moon run src/full_demo/full_demo.mbt  Full test
echo.
echo   .\quickstart.cmd                      This menu
echo.
pause
goto :eof

:show_policy
echo.
echo   Running: Show Policy
echo   ===============================================
moon run src/main show
echo.
pause
goto :eof
