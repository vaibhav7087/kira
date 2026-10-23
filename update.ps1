# Re-apply templates from a cloned kira repo to the installed workdir.
# Usage: .\update.ps1 [-Repo <path-to-kira-clone>]
[CmdletBinding()]
param([string]$Repo = $PSScriptRoot)

$WorkDir = Join-Path $env:USERPROFILE ".opencode-operator"
$tplDir = Join-Path $Repo "install\templates"

if (-not (Test-Path (Join-Path $WorkDir "kira.settings.json"))) {
  Write-Warning "Kira not installed in $WorkDir. Run install\setup-operator.ps1 first."
  exit 1
}

foreach ($name in @("start-operator-chrome.ps1", "run-operator.ps1")) {
  Copy-Item (Join-Path $tplDir $name) (Join-Path $WorkDir $name) -Force
  Write-Host "updated $name"
}
Write-Host "kira.settings.json left untouched (check repo templates for new keys)"
