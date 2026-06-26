#Requires -Version 7.0
[CmdletBinding()]
param(
    # Directory to write timestamped backup archives into. Defaults to
    # infrastructure/business-live/backups/<timestamp>/.
    [string]$BackupRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Backs up the two named Docker volumes used by
# infrastructure/business-live/docker-compose.yml:
#   - hmz_n8n_business_live_data       (n8n: workflows, credentials, settings, SQLite DB)
#   - hmz_send_state_business_live_data (hmz-send-state: send-lock + error records)
#
# Does NOT stop the stack (volumes are read while containers keep running;
# n8n's SQLite WAL means an in-flight write could be missed - for a
# guaranteed-consistent backup, stop the stack first with
#   docker compose -f infrastructure/business-live/docker-compose.yml stop
# then run this script, then start it again).
#
# Each volume is archived with a short-lived alpine container that mounts
# the volume read-only and tars it to a host-mounted backup directory.
# No application container is modified or restarted by this script.

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$ComposeDir = Join-Path $Project "infrastructure\business-live"

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $ComposeDir "backups"
}

$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$Dest = Join-Path $BackupRoot $Timestamp
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

$Volumes = @(
    "hmz_n8n_business_live_data",
    "hmz_send_state_business_live_data"
)

foreach ($Volume in $Volumes) {
    $Archive = "$Volume.tar.gz"
    Write-Host "Backing up volume '$Volume' -> $Dest\$Archive"

    docker run --rm `
        -v "${Volume}:/source:ro" `
        -v "${Dest}:/backup" `
        alpine:3 `
        tar -czf "/backup/$Archive" -C /source .

    if ($LASTEXITCODE -ne 0) {
        throw "Backup of volume '$Volume' failed (exit code $LASTEXITCODE)."
    }
}

Write-Host ""
Write-Host "BUSINESS_LIVE_BACKUP_COMPLETE"
Write-Host "Backup directory: $Dest"
foreach ($Volume in $Volumes) {
    Write-Host ("- {0}.tar.gz" -f $Volume)
}
