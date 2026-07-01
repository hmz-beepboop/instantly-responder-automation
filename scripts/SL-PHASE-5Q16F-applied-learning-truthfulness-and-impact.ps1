param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $scriptDir "SL-PHASE-5Q16F-applied-learning-truthfulness-and-impact.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
