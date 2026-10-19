@echo off
title Remove Scratchpad shortcuts
del "%USERPROFILE%\Desktop\Scratchpad.lnk" 2>nul
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Scratchpad.lnk" 2>nul
echo Shortcuts removed. Your notes are untouched.
echo To erase notes as well, delete this folder:
echo   %LOCALAPPDATA%\ScratchpadApp
echo.
pause
