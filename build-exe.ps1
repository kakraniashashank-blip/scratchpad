# Builds Scratchpad.exe (a tiny launcher) using the C# compiler that ships with Windows.
$root = Split-Path -Parent $PSCommandPath
$src  = Join-Path $root 'Scratchpad.cs'
$ico  = Join-Path $root 'scratchpad.ico'
$exe  = Join-Path $root 'Scratchpad.exe'

$csc = @(
  "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
  "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $csc) { Write-Host "C# compiler not found - using the script launcher instead." -ForegroundColor Yellow; exit 1 }

if (Test-Path $exe) { Remove-Item $exe -Force -ErrorAction SilentlyContinue }
& $csc /nologo /target:winexe "/out:$exe" "/win32icon:$ico" $src | Out-Null

if (Test-Path $exe) { Write-Host "Built Scratchpad.exe" -ForegroundColor Green; exit 0 }
Write-Host "Build failed - using the script launcher instead." -ForegroundColor Yellow
exit 1
