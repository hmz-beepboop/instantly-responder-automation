param()

$ErrorActionPreference = "Stop"
Write-Host "SL-PHASE-5Q4 HumanApproval render ID guard"
Write-Host "Local-only: no n8n, Sender, Instantly, or production operations."

$scriptPath = Join-Path $PSScriptRoot "SL-PHASE-5Q4-humanapproval-render-id-guard.py"
python3 $scriptPath
