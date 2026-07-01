#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir "SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.py"

if (Get-Command python3 -ErrorAction SilentlyContinue) {
  & python3 $pythonScript
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
  & python $pythonScript
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  throw "Python interpreter not found. Install python3 or python to run the SL-PHASE-5Q15 harness."
}
