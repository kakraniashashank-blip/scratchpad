$root = Split-Path -Parent $PSCommandPath
$vbs  = Join-Path $root 'Scratchpad.vbs'
$ico  = Join-Path $root 'scratchpad.ico'
$ws   = New-Object -ComObject WScript.Shell

& (Join-Path $root 'build-exe.ps1') | Out-Null
$exe  = Join-Path $root 'Scratchpad.exe'

$targets = @(
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Scratchpad.lnk'),
  (Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" 'Scratchpad.lnk')
)

foreach ($lnk in $targets) {
  $dir = Split-Path -Parent $lnk
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $sc = $ws.CreateShortcut($lnk)
  if (Test-Path $exe) { $sc.TargetPath = $exe; $sc.Arguments = '' }
  else { $sc.TargetPath = "$env:SystemRoot\System32\wscript.exe"; $sc.Arguments = '"' + $vbs + '"' }
  $sc.WorkingDirectory = $root
  $sc.IconLocation     = "$ico,0"
  $sc.Description      = 'Scratchpad'
  $sc.WindowStyle      = 1
  $sc.Save()
  Write-Host "Created: $lnk"
}

Write-Host ""
Write-Host "Done. Scratchpad is on your Desktop and in the Start Menu." -ForegroundColor Green
Write-Host "Open it once, then right-click its taskbar icon and choose Pin to taskbar."

Write-Host ""
Write-Host "Registering .md files..." -ForegroundColor Cyan
& (Join-Path $root 'associate.ps1')
