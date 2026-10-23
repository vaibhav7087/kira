# Kira installer. Idempotent: safe to re-run; existing files are only replaced with -Replace.
# Usage: .\install\setup-operator.ps1 [-Port 9223] [-WorkDir "$env:USERPROFILE\.opencode-operator"] [-NoLaunch] [-Replace]

[CmdletBinding()]
param(
  [int]$Port = 9223,
  [string]$WorkDir = (Join-Path $env:USERPROFILE ".opencode-operator"),
  [string]$ChromePath = "",
  [string[]]$StartUrls = @("https://web.whatsapp.com"),
  [string]$Prompt = "check unread chats and handle as per AGENTS.md Kira rules",
  [string]$QuietStart = "23:30",
  [string]$QuietEnd = "08:00",
  [switch]$NoLaunch,
  [switch]$Replace
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$tplDir = Join-Path $PSScriptRoot "templates"

Write-Host "=== Kira installer ==="

# ---- 1. Prerequisites -------------------------------------------------------
$fail = $false
try {
  $nodeVer = ([int](node -v).Substring(1).Split(".")[0])
  if ($nodeVer -ge 22) { Write-Host "[ok] node $((node -v))" }
  else { Write-Warning "node >= 22 required (found $($nodeVer)). Chrome-devtools-mcp needs Node 22+."; $fail = $true }
} catch { Write-Warning "node not found on PATH. Install Node.js 22+: https://nodejs.org"; $fail = $true }

$chromeFound = @(
  $ChromePath,
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($chromeFound) { Write-Host "[ok] chrome found" } else { Write-Warning "Chrome not found. Kira needs Chrome 144+."; $fail = $true }

try { opencode --version *> $null; Write-Host "[ok] opencode on PATH" }
catch { Write-Warning "opencode not found on PATH. Install: npm i -g opencode-ai@latest  (continuing; install won't fail)" }

if ($fail) { Write-Warning "Fix the warnings above and re-run this installer."; }

# ---- 2. Work files ----------------------------------------------------------
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$profileDir = Join-Path $WorkDir "chrome-profile"

$files = @{
  "start-operator-chrome.ps1" = Join-Path $tplDir "start-operator-chrome.ps1"
  "run-operator.ps1"          = Join-Path $tplDir "run-operator.ps1"
  "AGENTS.kira.md"            = Join-Path $tplDir "AGENTS.kira.md"
}
foreach ($name in $files.Keys) {
  $dest = Join-Path $WorkDir $name
  if ((Test-Path $dest) -and -not $Replace) { Write-Host "[skip] $name (exists; use -Replace to overwrite)" }
  else { Copy-Item $files[$name] $dest -Force; Write-Host "[ok] $name" }
}

$settings = [ordered]@{
  port        = $Port
  workDir     = $WorkDir
  profileDir  = $profileDir
  chromePath  = $chromeFound
  startUrls   = $StartUrls
  prompt      = $Prompt
  quietStart  = $QuietStart
  quietEnd    = $QuietEnd
  logFile     = "operator.log"
  runOutputFile = "last-run.txt"
  maxRunMinutes = 15
}
$settingsPath = Join-Path $WorkDir "kira.settings.json"
$settings | ConvertTo-Json | Set-Content $settingsPath
Write-Host "[ok] kira.settings.json (tweak prompts/limits there any time)"

# .cmd wrapper so the scheduled task doesn't need a shell-profile env
$cmd = Join-Path $WorkDir "start-operator-chrome.cmd"
@" 
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-operator-chrome.ps1"
"@ | Set-Content $cmd
Write-Host "[ok] start-operator-chrome.cmd"

# ---- 3. Global opencode config (permission + chrome-devtools MCP) ----------
$configCandidates = @(
  (Join-Path $env:USERPROFILE ".config\opencode\opencode.jsonc"),
  (Join-Path $env:USERPROFILE ".config\opencode\opencode.json"),
  (Join-Path $env:USERPROFILE ".config\opencode\config.json")
) | Where-Object { Test-Path $_ }
$target = $configCandidates | Select-Object -First 1
if (-not $target) {
  $dir = Join-Path $env:USERPROFILE ".config\opencode"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $target = Join-Path $dir "opencode.json"
}
node (Join-Path $PSScriptRoot "merge-config.mjs") $target $Port
Write-Host "[ok] opencode config: $target (backup written next to it)"

# ---- 4. Global AGENTS.md rules block ---------------------------------------
$agentsPath = Join-Path $env:USERPROFILE ".config\opencode\AGENTS.md"
$agentsBlock = Get-Content (Join-Path $WorkDir "AGENTS.kira.md") -Raw
if (Test-Path $agentsPath) {
  $existing = Get-Content $agentsPath -Raw
  if ($existing -notmatch "Kira: agentic operator rules") {
    Add-Content -Path $agentsPath -Value ("`n`n" + $agentsBlock)
    Write-Host "[ok] appended Kira rules to $agentsPath"
  } else { Write-Host "[skip] Kira rules already in AGENTS.md" }
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path $agentsPath) | Out-Null
  Set-Content -Path $agentsPath -Value $agentsBlock
  Write-Host "[ok] created $agentsPath with Kira rules"
}
Write-Host ">>> EDIT the Voice section in $agentsPath so Kira texts like you <<<"

# ---- 5. Scheduled tasks ------------------------------------------------------
$taskChrome = "Kira Operator Chrome"
$taskRun    = "Kira Operator"
foreach ($t in @($taskChrome, $taskRun)) {
  Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

$actionChrome = New-ScheduledTaskAction -Execute $cmd
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName $taskChrome -Action $actionChrome -Trigger $triggerLogon -Description "Launch Kira operator Chrome profile with remote debugging" -Force | Out-Null
Write-Host "[ok] scheduled task: $taskChrome (at logon)"

$runScript = Join-Path $WorkDir "run-operator.ps1"
$actionRun = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runScript`""
$triggerRun = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 20) -RepetitionDuration (New-TimeSpan -Days 3650)
$settingsRun = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -DisallowHardTerminate -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskRun -Action $actionRun -Trigger $triggerRun -Settings $settingsRun -Description "Periodic unattended Kira agent run" -Force | Out-Null
Write-Host "[ok] scheduled task: $taskRun (every 20 min)"

# ---- 6. Launch operator Chrome ---------------------------------------------
if (-not $NoLaunch) {
  & (Join-Path $WorkDir "start-operator-chrome.ps1")
}

Write-Host ""
Write-Host "=== Manual steps (the only ones left) ==="
Write-Host "1. In the Kira Chrome window just opened: log into the services you want it"
Write-Host "   to operate (web.whatsapp.com QR, gmail, instagram, telegram). Logins persist."
Write-Host "2. Set permission:'allow' was done in config; restart opencode sessions to pick it up."
Write-Host "3. Smoke test:  opencode run --auto `"list my kira chrome tabs`""
Write-Host "Logs: $WorkDir\operator.log and last-run.txt"
