@echo off
title AegisRun — Quick Start
chcp 65001 >nul 2>&1

:menu
cls
echo.
echo   ===============================================
echo     AegisRun v0.6.0 — AI Agent Secure Tool Runtime
echo     Quick Start Menu
echo   ===============================================
echo.
echo   1. Intercept Demo (14 attacks + dashboard)
echo   2. Policy Engine Demo (domain/path/env checks)
echo   3. WASI Sandbox Demo (physical isolation)
echo   4. Script Scanner (find threats in .py/.js)
echo   5. Web Dashboard (port 9090)
echo   6. Audit Log (JSONL write + view)
echo   7. CLI Commands Help
echo   8. Show Current Policy
echo   0. Exit
echo   ===============================================
echo.
set /p choice=  Enter choice (0-8):

if "%choice%"=="0" goto :eof
if "%choice%"=="1" call :run_intercept
if "%choice%"=="2" call :run_demo
if "%choice%"=="3" call :run_sandbox
if "%choice%"=="4" call :run_scanner
if "%choice%"=="5" call :run_dashboard
if "%choice%"=="6" call :run_audit
if "%choice%"=="7" call :show_help
if "%choice%"=="8" call :show_policy
goto menu

:run_intercept
echo.
echo   Running: Intercept Demo (14 attacks)
echo   ===============================================
moon run src/main
echo.
pause
goto :eof

:run_demo
echo.
echo   Running: Policy Engine Demo
echo   ===============================================
cd runtime
cargo run -- demo
cd ..
echo.
pause
goto :eof

:run_sandbox
echo.
echo   Running: WASI Sandbox Demo
echo   ===============================================
cd runtime
cargo run -- sandbox
cd ..
echo.
pause
goto :eof

:run_scanner
echo.
echo   Running: Script Scanner
echo   ===============================================
cd runtime
cargo run -- scan
cd ..
echo.
pause
goto :eof

:run_dashboard
echo.
echo   Running: Web Dashboard (http://localhost:9090)
echo   ===============================================
cd runtime
cargo run -- serve
cd ..
echo.
pause
goto :eof

:run_audit
echo.
echo   Running: Audit Log
echo   ===============================================
cd runtime
cargo run -- audit
if exist aegisrun-audit.jsonl type aegisrun-audit.jsonl
cd ..
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
echo   MoonBit CLI:
echo     moon run src/main                    Run all demos
echo     moon run src/main <cmd> <args>      Policy management
echo.
echo   Rust CLI (from runtime\ dir):
echo     cargo run -- demo                   Policy engine demo
echo     cargo run -- scan <file>            Scan script for threats
echo     cargo run -- sandbox <tool.wasm>    WASI sandbox
echo     cargo run -- serve                  Web dashboard
echo     cargo run -- audit                  Write audit log
echo     cargo run -- verify <w> <id> <pub>  Tool signature
echo     cargo run -- policy show            View policy
echo     cargo run -- save [path]            Save policy JSON
echo.
echo   Quick menu:
echo     .\quickstart.cmd                    This menu
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
