$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $ScriptDir "SL-PHASE-5Q7-ai-source-label-and-validation.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
