# Scratchpad - desktop launcher
# Serves this folder on a fixed local port (stable origin = notes persist),
# opens it in a borderless app window, and - when Windows hands over a file -
# loads that file and lets Ctrl+S write it back.
param([string]$FilePath)

$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $PSCommandPath
$port = 47823
$base = "http://127.0.0.1:$port/"
$profileDir = Join-Path $env:LOCALAPPDATA 'ScratchpadApp\profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$url = $base
if ($FilePath) {
  try { $FilePath = [System.IO.Path]::GetFullPath($FilePath) } catch { }
  $url = $base + '?open=' + [System.Uri]::EscapeDataString($FilePath)
}

# ---- locate a Chromium browser (Edge ships with Windows) ----
$cands = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$exe = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1

# ---- start the local file server (skipped if one is already running) ----
$listener = $null
try {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
  $listener.Start()
} catch { $listener = $null }

if (-not $exe) {
  Start-Process $url
  if ($listener) { Start-Sleep -Seconds 25; $listener.Stop() }
  exit
}

$browserArgs = @(
  "--app=$url",
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--no-default-browser-check",
  "--disable-background-networking",
  "--window-size=1180,860"
)
$proc = Start-Process -FilePath $exe -ArgumentList $browserArgs -PassThru

# Another copy is already serving - it will handle this window too.
if (-not $listener) { exit }

$rootResolved = [System.IO.Path]::GetFullPath($root)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$editable = @('.md','.markdown','.mdown','.mkd','.txt','.text','.html','.htm','.csv','.json','.log')

function Get-Mime([string]$p) {
  switch ([System.IO.Path]::GetExtension($p).ToLower()) {
    '.html' { 'text/html; charset=utf-8' }
    '.htm'  { 'text/html; charset=utf-8' }
    '.css'  { 'text/css; charset=utf-8' }
    '.js'   { 'application/javascript; charset=utf-8' }
    '.json' { 'application/json; charset=utf-8' }
    '.svg'  { 'image/svg+xml' }
    '.png'  { 'image/png' }
    '.jpg'  { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    '.gif'  { 'image/gif' }
    '.ico'  { 'image/x-icon' }
    '.woff2'{ 'font/woff2' }
    '.woff' { 'font/woff' }
    '.txt'  { 'text/plain; charset=utf-8' }
    default { 'application/octet-stream' }
  }
}

function Write-Response($stream, [int]$code, [string]$status, [string]$ctype, [byte[]]$body) {
  $head = "HTTP/1.1 $code $status`r`n" +
          "Content-Type: $ctype`r`n" +
          "Content-Length: $($body.Length)`r`n" +
          "Cache-Control: no-store`r`n" +
          "Connection: close`r`n`r`n"
  $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}
function Write-Text($stream, [int]$code, [string]$status, [string]$text) {
  Write-Response $stream $code $status 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($text))
}
function Get-Query([string]$qs, [string]$key) {
  foreach ($pair in $qs.Split('&')) {
    $kv = $pair.Split('=', 2)
    if ($kv.Length -eq 2 -and $kv[0] -eq $key) { return [System.Uri]::UnescapeDataString($kv[1].Replace('+', ' ')) }
  }
  return $null
}

while ($true) {
  if ($listener.Pending()) {
    $client = $listener.AcceptTcpClient()
    try {
      $client.ReceiveTimeout = 5000
      $ns = $client.GetStream()

      # --- read headers byte-wise so UTF-8 bodies survive intact ---
      $ms = New-Object System.IO.MemoryStream
      $buf = New-Object byte[] 8192
      $headerEnd = -1
      while ($headerEnd -lt 0) {
        $n = $ns.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        $ms.Write($buf, 0, $n)
        $arr = $ms.ToArray()
        for ($i = 3; $i -lt $arr.Length; $i++) {
          if ($arr[$i] -eq 10 -and $arr[$i-1] -eq 13 -and $arr[$i-2] -eq 10 -and $arr[$i-3] -eq 13) { $headerEnd = $i + 1; break }
        }
        if ($ms.Length -gt 1048576) { break }
      }
      $all = $ms.ToArray()
      if ($headerEnd -lt 0) { continue }

      $headerText = [System.Text.Encoding]::ASCII.GetString($all, 0, $headerEnd)
      $lines = $headerText -split "`r`n"
      $parts = $lines[0].Split(' ')
      $method  = $parts[0]
      $target  = if ($parts.Length -ge 2) { $parts[1] } else { '/' }

      $qs = ''
      $qi = $target.IndexOf('?')
      if ($qi -ge 0) { $qs = $target.Substring($qi + 1); $target = $target.Substring(0, $qi) }
      $target = [System.Uri]::UnescapeDataString($target)

      # ---------- file bridge ----------
      if ($target -eq '/__file') {
        $fp = Get-Query $qs 'p'
        $ext = if ($fp) { [System.IO.Path]::GetExtension($fp).ToLower() } else { '' }
        if (-not $fp -or ($editable -notcontains $ext)) {
          Write-Text $ns 400 'Bad Request' 'Unsupported file type'
        }
        elseif ($method -eq 'GET') {
          if (Test-Path -LiteralPath $fp -PathType Leaf) {
            Write-Response $ns 200 'OK' 'text/plain; charset=utf-8' ([System.IO.File]::ReadAllBytes($fp))
          } else { Write-Text $ns 404 'Not Found' 'No such file' }
        }
        elseif ($method -eq 'POST') {
          $len = 0
          foreach ($l in $lines) { if ($l -match '^(?i)Content-Length:\s*(\d+)') { $len = [int]$Matches[1] } }
          $body = New-Object byte[] $len
          $have = $all.Length - $headerEnd
          if ($have -gt $len) { $have = $len }
          if ($have -gt 0) { [Array]::Copy($all, $headerEnd, $body, 0, $have) }
          while ($have -lt $len) {
            $n = $ns.Read($body, $have, $len - $have)
            if ($n -le 0) { break }
            $have += $n
          }
          $text = [System.Text.Encoding]::UTF8.GetString($body, 0, $have)
          $bak = "$fp.bak"
          if ((Test-Path -LiteralPath $fp) -and -not (Test-Path -LiteralPath $bak)) {
            Copy-Item -LiteralPath $fp -Destination $bak -Force
          }
          try {
            [System.IO.File]::WriteAllText($fp, $text, $utf8)
            Write-Text $ns 200 'OK' 'saved'
          } catch {
            Write-Text $ns 500 'Server Error' 'Could not write the file'
          }
        }
        else { Write-Text $ns 405 'Method Not Allowed' 'no' }
      }
      # ---------- static files from the app folder ----------
      else {
        if ($target -eq '/' -or $target -eq '') { $target = '/index.html' }
        $rel  = $target.TrimStart('/').Replace('/', '\')
        $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
        if (-not $full.StartsWith($rootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
          Write-Text $ns 403 'Forbidden' 'Forbidden'
        } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
          Write-Response $ns 200 'OK' (Get-Mime $full) ([System.IO.File]::ReadAllBytes($full))
        } else {
          Write-Text $ns 404 'Not Found' 'Not found'
        }
      }
    } catch { }
    finally { try { $client.Close() } catch { } }
  } else {
    Start-Sleep -Milliseconds 120
    if ($proc.HasExited) { break }
  }
}

try { $listener.Stop() } catch { }
