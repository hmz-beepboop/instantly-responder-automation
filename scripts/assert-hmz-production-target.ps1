#Requires -Version 7.0
# assert-hmz-production-target.ps1
# Run before any n8n operation to confirm the correct production target is in scope.
# Does NOT call any external API. Does NOT require secrets.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProductionApiUrl = "https://n8n.hmzaiautomation.com/api/v1"
$ProductionUiUrl  = "https://n8n.hmzaiautomation.com"

$LocalTerms = @(
    "localhost",
    "127.0.0.1",
    "hmz-n8n-local-dev",
    "local-n8n",
    "docker-compose",
    "Docker Desktop"
)

Write-Host ""
Write-Host "=== HMZ Production Target Guard ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Target environment : PRODUCTION_CLOUD_N8N" -ForegroundColor Green
Write-Host "  n8n API base URL   : $ProductionApiUrl" -ForegroundColor Green
Write-Host "  n8n UI             : $ProductionUiUrl" -ForegroundColor Green
Write-Host ""
Write-Host "  Local Docker / localhost is FORBIDDEN for production VPS responder work." -ForegroundColor Yellow
Write-Host "  Use local dev only when the user explicitly says 'local dev' or 'local Docker test'." -ForegroundColor Yellow
Write-Host ""

# Check if any argument or piped string contains a local term (optional warning mode).
$warnings = @()

if ($args.Count -gt 0) {
    $inputStr = $args -join " "
    foreach ($term in $LocalTerms) {
        if ($inputStr -imatch [regex]::Escape($term)) {
            $warnings += "  WARNING: Input contains local term '$term' — this targets LOCAL DEV, not the production VPS."
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "--- LOCAL DEV TERM DETECTED ---" -ForegroundColor Red
    $warnings | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Stop. Confirm with the user whether local dev was intended." -ForegroundColor Red
    Write-Host ""
    exit 1
} else {
    Write-Host "  No local dev terms detected in input. Production target confirmed." -ForegroundColor Green
    Write-Host ""
    exit 0
}
