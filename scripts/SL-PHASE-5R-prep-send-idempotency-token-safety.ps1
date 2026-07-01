#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "SL-PHASE-5R-prep send idempotency and token safety harness"
Write-Host "Local-only: no n8n, Sender, Instantly, or production operations."
python3 "$PSScriptRoot/SL-PHASE-5R-prep-send-idempotency-token-safety.py"
exit $LASTEXITCODE
