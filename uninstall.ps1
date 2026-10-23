# Remove Kira tasks + scripts. Chrome profile (logins) stays unless -Purge.
# Usage: .\uninstall.ps1 [-Purge]
[CmdletBinding()]
param([switch]$Purge)

$WorkDir = Join-Path $env:USERPROFILE ".opencode-operator"

foreach ($t in @("Kira Operator", "Kira Operator Chrome")) {
  Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "removed scheduled task: $t (if existed)"
}

if (Test-Path $WorkDir) {
  Get-ChildItem $WorkDir -File -Exclude "kira.settings.json" | Remove-Item -Force -ErrorAction SilentlyContinue
  Write-Host "removed scripts/logs from $WorkDir"
}

if ($Purge) {
  Remove-Item (Join-Path $WorkDir "chrome-profile") -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "purged operator Chrome profile (all service logins deleted)"
}
else { Write-Host "kept $WorkDir\chrome-profile (logins survived). Use -Purge to delete." }

Write-Host ""
Write-Host "NOTE: global opencode config still contains the chrome-devtools MCP +"
Write-Host "permission:'allow', and global AGENTS.md still contains Kira rules."
Write-Host "Remove manually if you want a fully clean slate."
