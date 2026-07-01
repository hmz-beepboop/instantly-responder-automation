param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

python3 (Join-Path $scriptDir "SL-PHASE-5Q14B-deterministic-template-learning-bypass.py")
