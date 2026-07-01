param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

python3 (Join-Path $scriptDir "SL-PHASE-5Q17C-repeated-seeded-thread-context-loss.py")
