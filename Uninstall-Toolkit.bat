@echo off
title Uninstalling PowerShell Toolkit...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
if %errorlevel% neq 0 (
    echo.
    echo The uninstaller exited with an error. See message above if any.
    pause
)
