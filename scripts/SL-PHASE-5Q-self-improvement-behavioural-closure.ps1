<#
SL-PHASE-5Q self-improvement behavioural closure harness.

This wrapper is intentionally local-only. It does not call n8n, Sender,
Instantly, Google Chat, or any production API.
#>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$PythonHarness = Join-Path $ScriptDir "SL-PHASE-5Q-self-improvement-behavioural-closure.py"

Write-Host "SL-PHASE-5Q self-improvement behavioural closure harness"
Write-Host "Local-only: no n8n, Sender, Instantly, or production operations."

$python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}

if (-not $python) {
    throw "Python is required to run the dependency-free local harness."
}

Push-Location $RepoRoot
try {
    & $python.Source $PythonHarness
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
