$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
