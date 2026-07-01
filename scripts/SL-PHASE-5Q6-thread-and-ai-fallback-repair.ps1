$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

python3 (Join-Path $ScriptDir "SL-PHASE-5Q6-thread-and-ai-fallback-repair.py")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
