@echo off
title Remove .md association
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "Remove-Item 'HKCU:\Software\Classes\Scratchpad.md' -Recurse -Force -EA 0;" ^
 "Remove-Item 'HKCU:\Software\Classes\Applications\Scratchpad.exe' -Recurse -Force -EA 0;" ^
 "foreach($e in '.md','.markdown','.mdown','.mkd'){ Remove-ItemProperty -Path ('HKCU:\Software\Classes\'+$e+'\OpenWithProgids') -Name 'Scratchpad.md' -Force -EA 0; $p='HKCU:\Software\Classes\'+$e; if((Get-ItemProperty $p -EA 0).'(default)' -eq 'Scratchpad.md'){ Remove-ItemProperty $p -Name '(default)' -Force -EA 0 } };" ^
 "Write-Host 'Association removed.' -ForegroundColor Green"
echo.
pause
