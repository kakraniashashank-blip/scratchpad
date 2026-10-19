@echo off
title Associate .md with Scratchpad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0associate.ps1"
echo.
pause
