@echo off
title AegisRun - Full Test Suite

echo ============================================================
echo   AegisRun Lite v0.1.0 - Full Test Suite
echo ============================================================
echo.
echo This script tests all CLI commands and demos.
echo.

setlocal enabledelayedexpansion
D:
cd D:\moonbit\aegisrun

:: ===== Test 1: Show =====
echo -----------------------------------------------------------
echo  Test 1/8: show (view current policy)
echo -----------------------------------------------------------
echo.
moon run src/main show
if !errorlevel! neq 0 echo [FAIL] show command
echo.
echo.

:: ===== Test 2: Preset strict =====
echo -----------------------------------------------------------
echo  Test 2/8: preset strict
echo -----------------------------------------------------------
echo.
moon run src/main preset strict
if !errorlevel! neq 0 echo [FAIL] preset strict
echo.
echo.

:: ===== Test 3: Preset permissive =====
echo -----------------------------------------------------------
echo  Test 3/8: preset permissive
echo -----------------------------------------------------------
echo.
moon run src/main preset permissive
if !errorlevel! neq 0 echo [FAIL] preset permissive
echo.
echo.

:: ===== Test 4: Preset standard =====
echo -----------------------------------------------------------
echo  Test 4/8: preset standard (back to recommended)
echo -----------------------------------------------------------
echo.
moon run src/main preset standard
if !errorlevel! neq 0 echo [FAIL] preset standard
echo.
echo.

:: ===== Test 5: Deny tool =====
echo -----------------------------------------------------------
echo  Test 5/8: deny tool weather-query
echo -----------------------------------------------------------
echo.
moon run src/main deny tool weather-query
if !errorlevel! neq 0 echo [FAIL] deny tool
echo.
echo.

:: ===== Test 6: Allow domain =====
echo -----------------------------------------------------------
echo  Test 6/8: allow domain wttr.in
echo -----------------------------------------------------------
echo.
moon run src/main allow domain wttr.in
if !errorlevel! neq 0 echo [FAIL] allow domain
echo.
echo.

:: ===== Test 7: Deny domain =====
echo -----------------------------------------------------------
echo  Test 7/8: deny domain evil.com
echo -----------------------------------------------------------
echo.
moon run src/main deny domain evil.com
if !errorlevel! neq 0 echo [FAIL] deny domain
echo.
echo.

:: ===== Test 8: Demo ALL =====
echo -----------------------------------------------------------
echo  Test 8/8: demo all (7 security scenarios)
echo -----------------------------------------------------------
echo.
set AEGISRUN_DEMO=all
moon run src/main
if !errorlevel! neq 0 echo [FAIL] demo all
echo.

echo ============================================================
echo   Test suite complete!
echo ============================================================
echo.
echo   Legend:
echo     [OK]   = test passed
echo     [FAIL] = test failed
echo     [INFO] = additional info
echo     [BLOCK]= security decision: blocked
echo.
pause
