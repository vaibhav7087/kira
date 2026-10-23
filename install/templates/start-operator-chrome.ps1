# Kira operator Chrome launcher.
# Launches a DEDICATED Chrome profile with a remote-debugging port.
# A non-default --user-data-dir is what keeps Chrome from showing the
# per-connection "Allow remote debugging?" consent dialog.

$ErrorActionPreference = "Stop"
$settingsPath = Join-Path $PSScriptRoot "kira.settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

$chromeCandidates = @(
  $settings.chromePath,
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { $_ -and (Test-Path $_) }
$chrome = $chromeCandidates | Select-Object -First 1
if (-not $chrome) { Write-Error "Chrome not found. Set chromePath in kira.settings.json."; exit 1 }

$profileDir = $settings.profileDir
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$port = $settings.port
$urls = @($settings.startUrls)

Write-Host "Launching Kira operator Chrome (profile: $profileDir, debug port: $port)"
Start-Process -FilePath $chrome -ArgumentList @(
  "--user-data-dir=`"$profileDir`"",
  "--remote-debugging-port=$port",
  "--no-first-run",
  "--no-default-browser-check",
  @($urls | ForEach-Object { "`"$_`"" })
)
