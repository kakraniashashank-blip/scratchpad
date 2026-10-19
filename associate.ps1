# Registers Scratchpad as a handler for .md files (current user only, no admin).
$root = Split-Path -Parent $PSCommandPath
$vbs  = Join-Path $root 'Scratchpad.vbs'
$ico  = Join-Path $root 'scratchpad.ico'
$exe  = Join-Path $root 'Scratchpad.exe'

if (-not (Test-Path $exe)) { & (Join-Path $root 'build-exe.ps1') | Out-Null }

if (Test-Path $exe) {
  $cmd = "`"$exe`" `"%1`""
  $app = 'Scratchpad.exe'
} else {
  $cmd = "$env:SystemRoot\System32\wscript.exe `"$vbs`" `"%1`""
  $app = $null
}
$prog = 'Scratchpad.md'

# --- ProgID (what a .md file points at) ---
New-Item -Path "HKCU:\Software\Classes\$prog"                    -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\$prog\DefaultIcon"        -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\$prog\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$prog"                    -Name '(default)'        -Value 'Markdown Document'
Set-ItemProperty -Path "HKCU:\Software\Classes\$prog"                    -Name 'FriendlyTypeName' -Value 'Markdown Document'
Set-ItemProperty -Path "HKCU:\Software\Classes\$prog\DefaultIcon"        -Name '(default)'        -Value "$ico,0"
Set-ItemProperty -Path "HKCU:\Software\Classes\$prog\shell\open\command" -Name '(default)'        -Value $cmd

# --- Application entry (what the 'Open with' list displays: name + icon) ---
if ($app) {
  $ak = "HKCU:\Software\Classes\Applications\$app"
  New-Item -Path "$ak\shell\open\command" -Force | Out-Null
  New-Item -Path "$ak\DefaultIcon"        -Force | Out-Null
  New-Item -Path "$ak\SupportedTypes"     -Force | Out-Null
  Set-ItemProperty -Path $ak -Name 'FriendlyAppName' -Value 'Scratchpad'
  Set-ItemProperty -Path "$ak\shell\open\command" -Name '(default)' -Value $cmd
  Set-ItemProperty -Path "$ak\DefaultIcon"        -Name '(default)' -Value "$ico,0"
  foreach ($ext in @('.md','.markdown','.mdown','.mkd')) {
    Set-ItemProperty -Path "$ak\SupportedTypes" -Name $ext -Value ''
  }
}

foreach ($ext in @('.md', '.markdown', '.mdown', '.mkd')) {
  New-Item -Path "HKCU:\Software\Classes\$ext\OpenWithProgids" -Force | Out-Null
  Set-ItemProperty -Path "HKCU:\Software\Classes\$ext\OpenWithProgids" -Name $prog -Value ([byte[]]@()) -Type None

  $uc = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
  if (-not (Test-Path $uc)) {
    New-Item -Path "HKCU:\Software\Classes\$ext" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Classes\$ext" -Name '(default)' -Value $prog
    Write-Host "$ext  -> set as default" -ForegroundColor Green
  } else {
    Write-Host "$ext  -> added to 'Open with' (Windows already has a default for it)" -ForegroundColor Yellow
  }
}

Add-Type -Namespace W -Name Sh -MemberDefinition '
[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern void SHChangeNotify(int e, uint f, System.IntPtr a, System.IntPtr b);' -ErrorAction SilentlyContinue
try { [W.Sh]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero) } catch { }

Write-Host ""
Write-Host "Registered as 'Scratchpad'. One manual step remains:" -ForegroundColor Cyan
Write-Host "  right-click any .md file -> Open with -> Choose another app"
Write-Host "  -> pick Scratchpad -> tick 'Always use this app'"
