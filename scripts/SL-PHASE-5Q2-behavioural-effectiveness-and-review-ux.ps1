#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "SL-PHASE-5Q2 behavioural effectiveness and review UX harness"
Write-Host "Local-only: no n8n, Sender, Instantly, or production operations."
python3 "$PSScriptRoot/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.py"
exit $LASTEXITCODE
