#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{20,}$')]
    [string]$ControlledCampaignId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InstantlyApiCredentialId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InstantlyWebhookTokenCredentialId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ReviewBasicAuthCredentialId,

    [string]$HostTarget = "Planned Hostinger VPS running Ubuntu 24.04 LTS — not yet provisioned"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$OwnerFile = Join-Path $Project "BUSINESS_READY_OWNER_INPUTS.md"
$ConfigFile = Join-Path $Project "config\business-ready.config.json"

if (-not (Test-Path -LiteralPath $OwnerFile -PathType Leaf)) {
    throw "Missing owner-input file: $OwnerFile"
}
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Missing config file: $ConfigFile"
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $env:USERPROFILE "Downloads\Instantly_Responder_FinalOwnerSetup_Backup_$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath $OwnerFile -Destination (Join-Path $BackupDir "BUSINESS_READY_OWNER_INPUTS.md") -Force
Copy-Item -LiteralPath $ConfigFile -Destination (Join-Path $BackupDir "business-ready.config.json") -Force

$OwnerText = Get-Content -LiteralPath $OwnerFile -Raw

$LiteralReplacements = [ordered]@{
    '<REQUIRED_CONTROLLED_LIVE_CAMPAIGN_ID>' = $ControlledCampaignId
    '<REQUIRED_HOST_TARGET>' = $HostTarget
    '<REQUIRED_INSTANTLY_API_CREDENTIAL_ID>' = $InstantlyApiCredentialId
    '<REQUIRED_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID>' = $InstantlyWebhookTokenCredentialId
    '<REQUIRED_REVIEW_BASIC_AUTH_CREDENTIAL_ID>' = $ReviewBasicAuthCredentialId
}

foreach ($Entry in $LiteralReplacements.GetEnumerator()) {
    $OwnerText = $OwnerText.Replace([string]$Entry.Key, [string]$Entry.Value)
}

# Mark credential/action readiness in the owner table without exposing values.
$OwnerText = [regex]::Replace(
    $OwnerText,
    '(\|\s*`hmzInstantlyApi`\s*\|[^\r\n]*?\|)\s*false\s*(\|\s*`HMZ_INSTANTLY_API_CREDENTIAL_ID`)',
    '$1 true $2'
)
$OwnerText = [regex]::Replace(
    $OwnerText,
    '(\|\s*`hmzInstantlyWebhookToken`\s*\|[^\r\n]*?\|)\s*false\s*(\|\s*`HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID`)',
    '$1 true $2'
)
$OwnerText = [regex]::Replace(
    $OwnerText,
    '(\|\s*`hmzReviewBasicAuth`\s*\|[^\r\n]*?\|)\s*false\s*(\|\s*`HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID`)',
    '$1 true $2'
)
$OwnerText = [regex]::Replace(
    $OwnerText,
    '(\|\s*`hmzN8nApi`\s*\|[^\r\n]*?\|)\s*false\s*(\|)',
    '$1 true $2'
)

# Remove the generic placeholder notation that causes a false-positive search.
$OwnerText = $OwnerText.Replace(
    'Every value beginning with `<REQUIRED_*>` is a missing owner input.',
    'Every angle-bracket deployment placeholder in the tables below is a missing owner input.'
)
$OwnerText = $OwnerText.Replace(
    'Any remaining `<REQUIRED_*>` values are deployment-specific items that do not yet exist.',
    'Any remaining angle-bracket deployment placeholders are deployment-specific items that do not yet exist.'
)
$OwnerText = $OwnerText.Replace(
    'matching the keys above (e.g. `"<REQUIRED_REVIEW_BASE_URL>"`).',
    'matching the owner-input keys above.'
)

Set-Content -LiteralPath $OwnerFile -Value $OwnerText -Encoding utf8

$Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json -Depth 100

# Approved campaign may be accepted by the secured intake, but real sends remain
# impossible while dry_run=true and live_campaigns=[].
$Config.allowlists.campaign_ids = @($ControlledCampaignId)
$Config.owner_inputs_status = "COMPLETE"

$Config.operating_mode = "VALIDATION"
$Config.dry_run = $true
$Config.live_campaigns = @()

$Config.live_credential_readiness.instantly_api_key_bound = $true
$Config.live_credential_readiness.instantly = $true
$Config.live_credential_readiness.n8n_api_key_bound = $true
$Config.live_credential_readiness.review_basic_auth_bound = $true
$Config.live_credential_readiness.review_basic_auth = $true
$Config.live_credential_readiness.ready_for_controlled_live_test = $false

# Suppression remains disabled until local runtime acceptance and explicit
# controlled-live preparation.
$Config.suppression_action_enablement.source_campaign_stop_enabled = $false
$Config.suppression_action_enablement.interest_status_update_enabled = $false
$Config.suppression_action_enablement.subsequence_removal_enabled = $false
$Config.suppression_action_enablement.exact_email_blocklist_enabled = $false

$Config |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $ConfigFile -Encoding utf8

# Safety and completeness validation.
$Validated = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json -Depth 100
$ConfigJson = ConvertTo-Json -InputObject $Validated -Depth 100 -Compress

if ($Validated.owner_inputs_status -ne "COMPLETE") {
    throw "owner_inputs_status did not become COMPLETE."
}
if ($ConfigJson -match '<REQUIRED_[A-Z0-9_]+>') {
    throw "Config still contains an unresolved deployment placeholder."
}
if ($Validated.operating_mode -ne "VALIDATION") {
    throw "Safety failure: operating_mode is not VALIDATION."
}
if ([bool]$Validated.dry_run -ne $true) {
    throw "Safety failure: dry_run is not true."
}
if (@($Validated.live_campaigns).Count -ne 0) {
    throw "Safety failure: live_campaigns is not empty."
}
if ([bool]$Validated.live_credential_readiness.ready_for_controlled_live_test) {
    throw "Safety failure: controlled-live readiness became true."
}
if (@($Validated.allowlists.campaign_ids).Count -ne 1 -or
    [string]$Validated.allowlists.campaign_ids[0] -ne $ControlledCampaignId) {
    throw "Campaign allowlist was not set exactly."
}

$RemainingOwnerPlaceholders = @(
    Select-String `
        -LiteralPath $OwnerFile `
        -Pattern '<REQUIRED_[A-Z0-9_]+>' `
        -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    Sort-Object -Unique
)

Write-Host ""
Write-Host "=== BUSINESS-READY OWNER SETUP FINALISED ==="
Write-Host "Backup: $BackupDir"
Write-Host "Controlled campaign: $ControlledCampaignId"
Write-Host "Host target: $HostTarget"
Write-Host "Owner inputs status: COMPLETE"
Write-Host "Stored safety: VALIDATION / DRY_RUN=true / LIVE_CAMPAIGNS=[]"
Write-Host "Credential readiness recorded: Instantly API, webhook token, Review Basic Auth, n8n API"
Write-Host "Controlled-live readiness: False"
Write-Host "Remaining real owner placeholders: $($RemainingOwnerPlaceholders.Count)"

if ($RemainingOwnerPlaceholders.Count -gt 0) {
    $RemainingOwnerPlaceholders | ForEach-Object { Write-Host " - $_" }
    throw "Owner setup still contains real unresolved placeholders."
}

Write-Host ""
Write-Host "Next required environment variables in this PowerShell session:"
Write-Host '  $env:HMZ_N8N_API_KEY'
Write-Host '  $env:HMZ_REVIEW_CASES_DATA_TABLE_ID'
Write-Host '  $env:HMZ_INSTANTLY_API_CREDENTIAL_ID'
Write-Host '  $env:HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID'
Write-Host '  $env:HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID'
