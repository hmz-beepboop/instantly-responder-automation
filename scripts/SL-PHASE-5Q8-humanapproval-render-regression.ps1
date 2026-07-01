$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q8-humanapproval-render-regression.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
