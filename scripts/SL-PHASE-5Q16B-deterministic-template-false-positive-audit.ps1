param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $scriptDir "SL-PHASE-5Q16B-deterministic-template-false-positive-audit.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
