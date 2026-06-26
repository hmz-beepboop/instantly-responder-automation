#Requires -Version 7.0
[CmdletBinding()]
param(
    # Timestamp folder name under verification/business-ready/preapply-backup
    # (as printed by apply-business-ready.ps1). Defaults to the most recent
    # backup folder.
    [string]$BackupTimestamp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Restores the 7 business-ready VALIDATION workflows to the exact
# {name, nodes, connections, settings} captured by apply-business-ready.ps1
# immediately before it patched them, and ensures all 7 remain inactive
# afterwards. Does not delete, create, or activate any workflow, and does
# not touch credentials or contact Instantly. Safe to re-run.

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$BackupRoot = Join-Path $Project "verification\business-ready\preapply-backup"
$ConfigPath = Join-Path $Project "config\business-ready.config.json"
$InstantlyCredentialNames = @("hmzInstantlyApi", "hmzInstantlyWebhookToken")
$AllowedBackupCredentialNames = @("hmzInstantlyApi", "hmzInstantlyWebhookToken", "hmzReviewBasicAuth")

$CanonicalNames = @(
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Instantly Reply Sender - Validation",
    "HMZ - Reply Human Approval - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Reply Full Test Harness - Validation",
    "HMZ - Instantly Reply Intake - Validation"
)

$FileByName = @{
    "HMZ - Reply Error Handler - Validation" = "04_reply_error_handler_validation.json"
    "HMZ - Reply Decision Engine - Validation" = "02_reply_decision_engine_validation.json"
    "HMZ - Instantly Reply Sender - Validation" = "03_reply_sender_validation.json"
    "HMZ - Reply Human Approval - Validation" = "07_reply_human_approval_validation.json"
    "HMZ - Reply SLA Watchdog - Validation" = "05_reply_sla_watchdog_validation.json"
    "HMZ - Reply Full Test Harness - Validation" = "06_reply_full_test_harness_validation.json"
    "HMZ - Instantly Reply Intake - Validation" = "01_reply_intake_validation.json"
}

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function Invoke-N8nApi {
    param(
        [Parameter(Mandatory)][ValidateSet("GET","PUT","POST")][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body = $null,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    $Uri = "$N8nUrl/api/v1$Path"

    if ($null -ne $Body) {
        $Json = $Body | ConvertTo-Json -Depth 100
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $Json -ContentType "application/json"
    }

    if ($Method -eq "POST") {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -ContentType "application/json" -Body "{}"
    }

    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
}

function Get-AllWorkflowSummaries {
    param([Parameter(Mandatory)][hashtable]$Headers)

    $Items = @()
    $Cursor = $null

    do {
        $Path = "/workflows?limit=250"
        if (-not [string]::IsNullOrWhiteSpace($Cursor)) {
            $Path += "&cursor=$([Uri]::EscapeDataString($Cursor))"
        }

        $Response = Invoke-N8nApi -Method GET -Path $Path -Headers $Headers
        $Data = Get-OptionalPropertyValue -Object $Response -Name "data"
        if ($null -ne $Data) {
            $Items += @($Data)
        }

        $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "nextCursor"
        if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) {
            $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "next_cursor"
        }

        $Cursor = if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) {
            $null
        }
        else {
            [string]$CursorValue
        }
    }
    while ($null -ne $Cursor)

    return @($Items)
}

function Assert-BackupCredentialsSafe {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$Name
    )

    # A backup taken before a prior credential-bound apply (i.e. with
    # config.live_credential_readiness.instantly = true and/or
    # config.live_credential_readiness.review_basic_auth = true at the time)
    # may legitimately carry credentialPlaceholder nodes resolved to the
    # hmzInstantlyApi / hmzInstantlyWebhookToken (httpHeaderAuth) or
    # hmzReviewBasicAuth (httpBasicAuth) credentials. Restoring that snapshot
    # is safe; any other credential is not.
    foreach ($Node in @($Workflow.nodes)) {
        $Credentials = Get-OptionalPropertyValue -Object $Node -Name "credentials"
        if ($null -eq $Credentials) {
            continue
        }

        foreach ($CredProp in $Credentials.PSObject.Properties) {
            $CredName = [string](Get-OptionalPropertyValue -Object $CredProp.Value -Name "name")
            if ($AllowedBackupCredentialNames -notcontains $CredName) {
                throw "Backup for '$Name' node '$($Node.name)' references an unexpected credential '$CredName'. Refusing to restore."
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw "HMZ_N8N_API_KEY is not set in this PowerShell process."
}

if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
    throw "No backup directory found at $BackupRoot. Nothing to roll back."
}

if ([string]::IsNullOrWhiteSpace($BackupTimestamp)) {
    $Latest = Get-ChildItem -LiteralPath $BackupRoot -Directory |
        Sort-Object -Property Name -Descending |
        Select-Object -First 1

    if ($null -eq $Latest) {
        throw "No backup folders found under $BackupRoot."
    }

    $BackupDir = $Latest.FullName
}
else {
    $BackupDir = Join-Path $BackupRoot $BackupTimestamp
    if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
        throw "Backup folder not found: $BackupDir"
    }
}

Write-Host "Restoring from backup: $BackupDir"

foreach ($Name in $CanonicalNames) {
    $File = $FileByName[$Name]
    $BackupPath = Join-Path $BackupDir $File
    if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        throw "Missing backup file for '$Name': $BackupPath. Refusing partial rollback."
    }
}

$Headers = @{
    "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY
}

$Status = [ordered]@{}

try {
    $Summaries = Get-AllWorkflowSummaries -Headers $Headers

    foreach ($Name in $CanonicalNames) {
        $Matches = @($Summaries | Where-Object { [string]$_.name -eq $Name })
        if ($Matches.Count -ne 1) {
            throw "Expected exactly one existing workflow named '$Name', found $($Matches.Count)."
        }

        $Id = [string]$Matches[0].id
        $BackupPath = Join-Path $BackupDir $FileByName[$Name]
        $Backup = Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json -Depth 100

        if ([string]$Backup.name -ne $Name) {
            throw "Backup file for '$Name' has a mismatched name: $($Backup.name)"
        }

        Assert-BackupCredentialsSafe -Workflow $Backup -Name $Name

        if ([bool]$Backup.active) {
            throw "Backup for '$Name' has active=true. Refusing to restore an active workflow body."
        }

        $Body = @{
            name = $Backup.name
            nodes = $Backup.nodes
            connections = $Backup.connections
            settings = $Backup.settings
        }

        Invoke-N8nApi -Method PUT -Path "/workflows/$Id" -Body $Body -Headers $Headers | Out-Null

        $Current = Invoke-N8nApi -Method GET -Path "/workflows/$Id" -Headers $Headers
        if ([bool]$Current.active) {
            Invoke-N8nApi -Method POST -Path "/workflows/$Id/deactivate" -Headers $Headers | Out-Null
            $Current = Invoke-N8nApi -Method GET -Path "/workflows/$Id" -Headers $Headers
        }

        if ([bool]$Current.active) {
            throw "Workflow '$Name' is still active after rollback."
        }

        $Status[$Name] = "RESTORED"
    }

    # Belt-and-suspenders: re-assert the safe default config state
    # regardless of what the live-path build or any controlled-live
    # acceptance run left behind.
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100
        $Config.operating_mode = "VALIDATION"
        $Config.dry_run = $true
        $Config | Add-Member -NotePropertyName "live_campaigns" -NotePropertyValue @() -Force
        $Config.allowlists.campaign_ids = @()
        $Config.live_credential_readiness.instantly = $false
        $Config.live_credential_readiness.review_basic_auth = $false
        $Config.live_credential_readiness.ready_for_controlled_live_test = $false
        $Config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
    }

    Write-Host ""
    Write-Host "BUSINESS_READY_ROLLBACK_COMPLETE"
    Write-Host "config.operating_mode=VALIDATION, config.dry_run=true, config.live_campaigns=[], config.allowlists.campaign_ids=[], and live_credential_readiness.{instantly,review_basic_auth,ready_for_controlled_live_test}=false re-asserted."
    foreach ($Name in $CanonicalNames) {
        Write-Host ("{0}: {1} | Active=False" -f $Name, $Status[$Name])
    }
}
catch {
    Write-Host ""
    Write-Host "BUSINESS_READY_ROLLBACK_FAILED"
    Write-Host ("Reason: {0}" -f $_.Exception.Message)

    foreach ($Name in $CanonicalNames) {
        $Current = if ($Status.Contains($Name)) { $Status[$Name] } else { "NOT_STARTED" }
        Write-Host ("{0}: {1}" -f $Name, $Current)
    }

    throw
}
finally {
    $Headers = $null
    $env:HMZ_N8N_API_KEY = $null
    Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
}
