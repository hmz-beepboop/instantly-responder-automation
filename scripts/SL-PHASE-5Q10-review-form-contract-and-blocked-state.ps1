$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q10-review-form-contract-and-blocked-state.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
