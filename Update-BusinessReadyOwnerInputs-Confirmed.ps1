#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$OwnerFile = Join-Path $Project "BUSINESS_READY_OWNER_INPUTS.md"
$ConfigFile = Join-Path $Project "config\business-ready.config.json"

$WorkspaceId = "c7f84f11-4a1a-42dc-9a74-a417e44cb87e"
$SenderEmail = "hamzah@teamhmzautomations.com"
$SenderName = "Hamza"
$BookingLink = "https://calendar.app.google/qtTHURBWvZKcDxeY7"
$ReviewerIdentity = "hamzah@teamhmzautomations.com"
$ControlledRecipient = "hamzahzahid0@gmail.com"
$ControlledSubject = "HMZ-RESPONDER-CONTROLLED-LIVE-001"

$PublicHost = "n8n.hmzaiautomation.com"
$N8nPublicUrl = "https://$PublicHost"
$ReviewBaseUrl = "$N8nPublicUrl/webhook/reply-review"
$ReviewFormUrl = "$ReviewBaseUrl/review"
$ReviewSubmitUrl = "$ReviewBaseUrl/submit"
$ProductionIntakeUrl = "$N8nPublicUrl/webhook/instantly-reply"

if (-not (Test-Path -LiteralPath $OwnerFile -PathType Leaf)) {
    throw "Missing owner-input file: $OwnerFile"
}

if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Missing configuration file: $ConfigFile"
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $env:USERPROFILE "Downloads\Instantly_Responder_OwnerInput_Backup_$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Copy-Item -LiteralPath $OwnerFile -Destination (Join-Path $BackupDir "BUSINESS_READY_OWNER_INPUTS.md") -Force
Copy-Item -LiteralPath $ConfigFile -Destination (Join-Path $BackupDir "business-ready.config.json") -Force

$OwnerText = Get-Content -LiteralPath $OwnerFile -Raw

$Replacements = [ordered]@{
    '<REQUIRED_PRIMARY_REVIEWER_NAME>' = 'Hamzah Zahid'
    '<REQUIRED_PRIMARY_REVIEWER_CONTACT>' = $ReviewerIdentity
    '<REQUIRED_BACKUP_REVIEWER_NAME>' = 'Not configured for supervised launch'
    '<REQUIRED_BACKUP_REVIEWER_CONTACT>' = 'N/A'
    '<REQUIRED_GOOGLE_CHAT_SPACE_NAME>' = 'HMZ Instantly Responder Alerts'
    '<REQUIRED_GOOGLE_CHAT_WEBHOOK_READY: true|false>' = 'false'
    '<REQUIRED_REVIEW_BASE_URL>' = $ReviewBaseUrl
    '<REQUIRED_REVIEW_TOKEN_TTL_MINUTES>' = '60'
    '<REQUIRED_REVIEW_PUBLIC_FORM_URL>' = $ReviewFormUrl
    '<REQUIRED_REVIEW_PUBLIC_SUBMIT_URL>' = $ReviewSubmitUrl
    '<REQUIRED_N8N_PUBLIC_URL>' = $N8nPublicUrl
    '<REQUIRED_PRODUCTION_INSTANTLY_WEBHOOK_URL>' = $ProductionIntakeUrl
    '<REQUIRED_SENDER_EACCOUNT_1>' = $SenderEmail
    '<REQUIRED_SENDER_NAME_1>' = $SenderName
    '<REQUIRED_BOOKING_LINK_1>' = $BookingLink
    '<REQUIRED_WORKSPACE_ID>' = $WorkspaceId
    '<REQUIRED_LIVE_CAMPAIGN_IDS>' = '[]'
    '<REQUIRED_SENDER_ACCOUNT_ALLOWLIST>' = $SenderEmail
    '<REQUIRED_CONTROLLED_LIVE_EACCOUNT>' = $SenderEmail
    '<REQUIRED_CONTROLLED_LIVE_LEAD_EMAIL>' = $ControlledRecipient
    '<REQUIRED_CONTROLLED_LIVE_EMAIL_ID>' = 'NOT_REQUIRED — derived from the genuine inbound reply webhook during acceptance'
    '<REQUIRED_CONTROLLED_LIVE_REPLY_SUBJECT>' = $ControlledSubject
    '<REQUIRED_INSTANTLY_CREDENTIAL_BOUND: false>' = 'false'
    '<REQUIRED_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_BOUND: false>' = 'false'
    '<REQUIRED_REVIEW_BASIC_AUTH_CREDENTIAL_BOUND: false>' = 'false'
    '<REQUIRED_N8N_API_KEY_BOUND: false>' = 'false'
    '<REQUIRED_KB_APPROVED: false>' = 'false'
    '<REQUIRED_CASE_RETENTION_DAYS>' = '90'
    '<REQUIRED_SEND_STATE_RETENTION_DAYS>' = '90'
    '<REQUIRED_ERROR_RETENTION_DAYS>' = '90'
    '<REQUIRED_PUBLIC_DOMAIN>' = $PublicHost
    '<REQUIRED_TLS_STRATEGY>' = "Caddy automatic Let's Encrypt TLS after the DNS A record points to the VPS"
    '<REQUIRED_OWNER_ACKNOWLEDGEMENT_CONTROLLED_LIVE: true|false>' = 'true'
}

foreach ($Entry in $Replacements.GetEnumerator()) {
    $OwnerText = $OwnerText.Replace([string]$Entry.Key, [string]$Entry.Value)
}

$OwnerText = $OwnerText.Replace(
    'Status: **template — not yet completed by the owner**.',
    'Status: **PARTIALLY COMPLETED — confirmed non-secret owner values recorded; deployment-specific IDs and hosting remain pending**.'
)

$OwnerText = $OwnerText.Replace(
    'All `<REQUIRED_*>` values above remain unfilled.',
    'Confirmed non-secret values are filled. Any remaining `<REQUIRED_*>` values are deployment-specific items that do not yet exist.'
)

Set-Content -LiteralPath $OwnerFile -Value $OwnerText -Encoding utf8

$Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json

$Config.owner_inputs_status = "INCOMPLETE — pending controlled campaign, credential IDs, Review Cases Data Table, Google Chat webhook, VPS/DNS/TLS deployment"
$Config.operating_mode = "VALIDATION"
$Config.dry_run = $true
$Config.live_campaigns = @()

$Config.workspace_allowlist = @($WorkspaceId)
$Config.allowlists.workspace_id = $WorkspaceId
$Config.allowlists.campaign_ids = @()
$Config.allowlists.connected_sender_eaccounts = @($SenderEmail)
$Config.reviewer_allowlist = @($ReviewerIdentity)

$Config.sender_mapping = [ordered]@{
    $SenderEmail = [ordered]@{
        sender_name = $SenderName
        booking_link = $BookingLink
    }
}

$Config.kb_approved_for_runtime = $false

$Config.review.destination_status = "NOT_CONFIGURED"
$Config.review.google_chat_credential_name = "ENV:GOOGLE_CHAT_WEBHOOK_URL"
$Config.review.google_chat_configured = $false
$Config.review.review_base_url = $ReviewBaseUrl
$Config.review.review_token_ttl_minutes = 60
$Config.review.review_token_ttl_minutes_default = 60
$Config.review.production_review_form_path = "reply-review/review"
$Config.review.production_review_submit_path = "reply-review/submit"
$Config.review.review_basic_auth_credential_name = "hmzReviewBasicAuth"

$Config.retention.review_case_retention_days = 90
$Config.retention.review_case_retention_days_default = 90
$Config.retention.send_state_retention_days = 90
$Config.retention.send_state_retention_days_default = 90
$Config.retention.error_record_retention_days = 90
$Config.retention.error_record_retention_days_default = 90

$Config.live_credential_readiness.instantly_api_key_bound = $false
$Config.live_credential_readiness.instantly = $false
$Config.live_credential_readiness.n8n_api_key_bound = $false
$Config.live_credential_readiness.review_basic_auth_bound = $false
$Config.live_credential_readiness.review_basic_auth = $false
$Config.live_credential_readiness.ready_for_controlled_live_test = $false

$Config.suppression_action_enablement.source_campaign_stop_enabled = $false
$Config.suppression_action_enablement.interest_status_update_enabled = $false
$Config.suppression_action_enablement.subsequence_removal_enabled = $false
$Config.suppression_action_enablement.exact_email_blocklist_enabled = $false

$Config |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $ConfigFile -Encoding utf8

# Validate the generated JSON.
$ValidatedConfig = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json

if ($ValidatedConfig.operating_mode -ne "VALIDATION") {
    throw "Safety validation failed: operating_mode changed."
}

if ([bool]$ValidatedConfig.dry_run -ne $true) {
    throw "Safety validation failed: dry_run is not true."
}

if (@($ValidatedConfig.live_campaigns).Count -ne 0) {
    throw "Safety validation failed: live_campaigns is not empty."
}

if ([bool]$ValidatedConfig.live_credential_readiness.ready_for_controlled_live_test) {
    throw "Safety validation failed: controlled-live readiness was enabled."
}

$RemainingOwnerPlaceholders = @(
    Select-String `
        -LiteralPath $OwnerFile `
        -Pattern '<REQUIRED_[^>]+>' `
        -AllMatches |
    ForEach-Object {
        $_.Matches.Value
    } |
    Sort-Object -Unique
)

$RemainingConfigPlaceholders = @(
    Select-String `
        -LiteralPath $ConfigFile `
        -Pattern '<REQUIRED_[^>]+>|__REQUIRED_[^_]+__' `
        -AllMatches |
    ForEach-Object {
        $_.Matches.Value
    } |
    Sort-Object -Unique
)

Write-Host ""
Write-Host "=== OWNER INPUT PARTIAL UPDATE COMPLETE ==="
Write-Host "Backup: $BackupDir"
Write-Host "Reviewer: $ReviewerIdentity"
Write-Host "Sender: $SenderName <$SenderEmail>"
Write-Host "Booking link: $BookingLink"
Write-Host "Workspace: $WorkspaceId"
Write-Host "Controlled recipient: $ControlledRecipient"
Write-Host "Stored config: VALIDATION / DRY_RUN=true / LIVE_CAMPAIGNS=[]"
Write-Host "Owner file remaining placeholders: $($RemainingOwnerPlaceholders.Count)"
Write-Host "Config remaining placeholders: $($RemainingConfigPlaceholders.Count)"

if ($RemainingOwnerPlaceholders.Count -gt 0) {
    Write-Host ""
    Write-Host "Remaining owner inputs:"
    $RemainingOwnerPlaceholders | ForEach-Object { Write-Host " - $_" }
}

if ($RemainingConfigPlaceholders.Count -gt 0) {
    Write-Host ""
    Write-Host "Remaining config placeholders:"
    $RemainingConfigPlaceholders | ForEach-Object { Write-Host " - $_" }
}

Write-Host ""
Write-Host "Do not change owner_inputs_status to COMPLETE yet."
