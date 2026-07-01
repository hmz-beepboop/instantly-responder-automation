param()

$ErrorActionPreference = "Stop"
Write-Host "SL-PHASE-5Q5 Save/reopen persistence harness"
Write-Host "Local-only: no n8n, Sender, Instantly, or production operations."

$scriptPath = Join-Path $PSScriptRoot "SL-PHASE-5Q5-save-reopen-persistence.py"
python3 $scriptPath
