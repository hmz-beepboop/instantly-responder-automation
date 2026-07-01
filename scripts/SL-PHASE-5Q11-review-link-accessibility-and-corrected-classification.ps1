$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q11-review-link-accessibility-and-corrected-classification.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
