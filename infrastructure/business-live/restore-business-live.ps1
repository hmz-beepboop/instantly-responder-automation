#Requires -Version 7.0
[CmdletBinding()]
param(
    # Timestamp folder name under infrastructure/business-live/backups (as
    # printed by backup-business-live.ps1). Mandatory - there is no
    # "most recent" default, to avoid accidentally restoring an unintended
    # backup over a live volume.
    [Parameter(Mandatory)]
    [string]$BackupTimestamp,

    # Must be passed explicitly to confirm this destructive operation.
    [switch]$Confirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Restores the two named Docker volumes used by
# infrastructure/business-live/docker-compose.yml from archives produced by
# backup-business-live.ps1. This is DESTRUCTIVE: it erases the current
# contents of each volume and replaces them with the backup contents.
#
# Requires the stack to be stopped first:
#   docker compose -f infrastructure/business-live/docker-compose.yml down
# (volumes are NOT removed by "down" without -v, so they still exist and can
# be restored into). After this script completes, start the stack again:
#   docker compose -f infrastructure/business-live/docker-compose.yml up -d
#
# Refuses to run without -Confirm, and refuses if any target volume is
# currently in use by a running container.

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$ComposeDir = Join-Path $Project "infrastructure\business-live"
$BackupDir = Join-Path $ComposeDir "backups\$BackupTimestamp"

if (-not $Confirm) {
    throw "Refusing to restore without -Confirm. This will ERASE the current contents of hmz_n8n_business_live_data and hmz_send_state_business_live_data. Stop the stack first, then re-run with -Confirm."
}

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    throw "Backup folder not found: $BackupDir"
}

$Volumes = @(
    "hmz_n8n_business_live_data",
    "hmz_send_state_business_live_data"
)

foreach ($Volume in $Volumes) {
    $Archive = Join-Path $BackupDir "$Volume.tar.gz"
    if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
        throw "Missing backup archive for '$Volume': $Archive. Refusing partial restore."
    }
}

foreach ($Volume in $Volumes) {
    $InUse = docker ps --filter "volume=$Volume" --format "{{.Names}}"
    if (-not [string]::IsNullOrWhiteSpace($InUse)) {
        throw "Volume '$Volume' is currently in use by running container(s): $InUse. Stop the stack first (docker compose -f infrastructure/business-live/docker-compose.yml down)."
    }
}

foreach ($Volume in $Volumes) {
    $Archive = "$Volume.tar.gz"
    Write-Host "Restoring volume '$Volume' <- $BackupDir\$Archive"

    docker run --rm `
        -v "${Volume}:/target" `
        -v "${BackupDir}:/backup:ro" `
        alpine:3 `
        sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null; tar -xzf /backup/$Archive -C /target"

    if ($LASTEXITCODE -ne 0) {
        throw "Restore of volume '$Volume' failed (exit code $LASTEXITCODE)."
    }
}

Write-Host ""
Write-Host "BUSINESS_LIVE_RESTORE_COMPLETE"
Write-Host "Restored from: $BackupDir"
Write-Host "Start the stack with: docker compose -f infrastructure/business-live/docker-compose.yml up -d"
