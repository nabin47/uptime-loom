@echo off
setlocal
title Uptime Loom - Install
rem Double-click this file to install Uptime Loom. No administrator rights needed.
rem It runs SetupHeartbeat.ps1 from this folder in a way that works even when
rem PowerShell scripts are blocked or open in Notepad.

set "UL_SRC=%~dp0"
if not exist "%~dp0SetupHeartbeat.ps1" goto notextracted

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $env:UL_SRC 'SetupHeartbeat.ps1') -Raw -Encoding UTF8)))"
echo.
pause
exit /b

:notextracted
echo.
echo   Uptime Loom: the setup files were not found next to Install.cmd.
echo.
echo   Right-click the downloaded ZIP file, choose "Extract All...",
echo   then open the extracted folder and double-click Install.cmd again.
echo.
pause
exit /b 1
