$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
