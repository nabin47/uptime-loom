@echo off
setlocal
title Uptime Loom - Uninstall
rem Double-click this file to remove Uptime Loom (stops logging and removes the
rem startup entry and shortcuts). Your tracked data is kept.

set "UL_SRC=%~dp0"
set "UL_SETUP=%~dp0SetupHeartbeat.ps1"
if not exist "%UL_SETUP%" set "UL_SETUP=%USERPROFILE%\UptimeLoom\SetupHeartbeat.ps1"
if not exist "%UL_SETUP%" goto missing

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath $env:UL_SETUP -Raw -Encoding UTF8))) -Uninstall"
echo.
pause
exit /b

:missing
echo.
echo   Uptime Loom: SetupHeartbeat.ps1 was not found, so nothing could be removed.
echo.
pause
exit /b 1
