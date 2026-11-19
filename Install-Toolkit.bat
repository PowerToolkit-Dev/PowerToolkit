@echo off
title Installing PowerShell Toolkit...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if %errorlevel% neq 0 (
    echo.
    echo The installer exited with an error. See message above if any.
    pause
)
