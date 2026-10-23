# Kira scheduled run: invoked every 20 minutes by Task Scheduler.
# Self-guards: Chrome debugging port reachable, quiet hours, no overlapping runs.

$ErrorActionPreference = "SilentlyContinue"
$now = Get-Date
$settings = Get-Content (Join-Path $PSScriptRoot "kira.settings.json") -Raw | ConvertFrom-Json
$log = Join-Path $PSScriptRoot $settings.logFile
$lock = Join-Path $PSScriptRoot "run.lock"
function Log($m) { Add-Content -Path $log -Value ("[{0}] {1}" -f $now.ToString("yyyy-MM-dd HH:mm:ss"), $m) }

# Quiet hours: no scheduled sends between settings.quietStart and settings.quietEnd (local time)
function Test-QuietHours([datetime]$d, [string]$start, [string]$end) {
  $s = [datetime]::ParseExact($start, "HH:mm", $null)
  $e = [datetime]::ParseExact($end, "HH:mm", $null)
  $t = $d.TimeOfDay
  if ($s -le $e) { return ($t -ge $s.TimeOfDay -and $t -lt $e.TimeOfDay) }
  return ($t -ge $s.TimeOfDay -or $t -lt $e.TimeOfDay)
}
if (Test-QuietHours $now $settings.quietStart $settings.quietEnd) { Log "quiet hours - skip"; exit 0 }

# Prevent overlapping runs (runs may take longer than the tick interval)
if (Test-Path $lock) {
  $age = $now - (Get-Item $lock).LastWriteTime
  if ($age.TotalMinutes -lt $settings.maxRunMinutes) { Log "previous run still active - skip"; exit 0 }
}
New-Item -ItemType File -Path $lock -Force | Out-Null

try {
  # Probe: operator Chrome with remote debugging must be on the configured port
  $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port $settings.port -InformationLevel Quiet -WarningAction SilentlyContinue
  if (-not $tcp) { Log "operator Chrome (port $($settings.port)) not reachable - run start-operator-chrome.ps1"; exit 0 }

  Log "scheduled agent run starting"
  Push-Location $PSScriptRoot
  opencode run --auto $settings.prompt >> (Join-Path $PSScriptRoot $settings.runOutputFile) 2>&1
  $code = $LASTEXITCODE
  Pop-Location
  Log "agent run finished with exit code $code"
}
finally {
  Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
