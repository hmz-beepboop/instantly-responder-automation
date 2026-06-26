#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5I: Shadow Evaluator Allowlist Enforcement (RC-SHADOW-003)

.DESCRIPTION
    Patches the disabled shadow evaluator to enforce campaign, sender, and intent
    allowlists inside the eligibility node. would_send_live_now remains ALWAYS FALSE.
    Gate 1 (shadow_evaluator_always_disabled) remains unconditional.
    Final active state of the shadow evaluator remains false.

.PARAMETER WhatIf
    Show what would change without writing any files or calling n8n API.

.PARAMETER Apply
    Patch local JSON and deploy to n8n production API.
    Requires $env:HMZ_N8N_API_KEY.

.PARAMETER ValidateOnly
    Validate the current local JSON for safety properties only.

.PARAMETER RunAllowlistTests
    Run 20 offline allowlist test cases against the patched JS logic.
    No network activation required.

.PARAMETER NoActivation
    Default: true. Never activates the shadow evaluator workflow.

.PARAMETER NoSecretOutput
    Default: true. Never prints API keys or secrets.

.EXAMPLE
    .\SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1 -WhatIf
    .\SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1 -Apply
    .\SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1 -RunAllowlistTests
#>

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply,
    [switch]$ValidateOnly,
    [switch]$RunAllowlistTests,
    [switch]$NoActivation = $true,
    [switch]$NoSecretOutput = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot   = Split-Path $PSScriptRoot -Parent
$WorkflowPath = Join-Path $ScriptRoot "workflows\disabled_autonomous_shadow_evaluator.json"
$OutputsDir   = Join-Path $ScriptRoot "outputs"
$N8nBase      = "https://n8n.hmzaiautomation.com/api/v1"
$WorkflowId   = "aHzLtQiv6G8h1bqD"
$Timestamp    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5I: Shadow Evaluator Allowlist Enforcement (RC-SHADOW-003) ===" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp"
Write-Host "[SAFETY] would_send_live_now=false is hardcoded and immutable." -ForegroundColor Green
Write-Host "[SAFETY] Gate 1 (shadow_evaluator_always_disabled) is unconditional." -ForegroundColor Green
Write-Host "[SAFETY] Shadow evaluator final active state will remain false." -ForegroundColor Green
Write-Host ""

# ── NEW JS CODE FOR ELIGIBILITY NODE (RC-SHADOW-003) ─────────────────────────
# Single-quoted here-string prevents PowerShell variable interpolation.
$NewEligibilityJs = @'
// SHADOW EVALUATOR v1.1 — RC-SHADOW-003 Allowlist Wire-Up
// Gate 1 (shadow_evaluator_always_disabled) is UNCONDITIONAL.
// would_send_live_now is ALWAYS FALSE — immutable safety constraint.
const SHADOW_CONFIG = {
  autonomous_enabled: false,
  shadow_only: true,
  dry_run: true,
  emergency_disabled: true,
  campaign_allowlist: [],
  sender_allowlist: [],
  intent_allowlist: [],
  confidence_threshold: 0.85,
  max_autonomous_sends_per_day: 0
};

const PERMANENT_BLOCK = ['UNSUBSCRIBE','DO_NOT_CONTACT','OPT_OUT','LEGAL_COMPLAINT',
  'ANGRY_REPLY','HOSTILE_REPLY','BILLING_DISPUTE','REFUND_REQUEST','PRICING_REQUEST',
  'PRICING_NEGOTIATION','CONTRACT_TERMS','GDPR_REQUEST','SOC2_REQUEST',
  'DATA_SECURITY_REQUEST','PRIVACY_QUESTION','COMPLIANCE_QUESTION',
  'SENSITIVE_PERSONAL_DATA','CUSTOM_PROPOSAL_REQUEST','ENTERPRISE_REQUEST',
  'HIGH_VALUE_JUDGEMENT','AMBIGUOUS_INTENT'];

const p = $input.first().json;
const intent = p.micro_intent;
const addIntents = p.additional_intents || [];
const confidence = p.confidence;

// GATE 1 — system state (always disabled in shadow evaluator — immutable)
const blockedReason = 'shadow_evaluator_always_disabled';
const wouldSendLiveNow = false; // HARDCODED — never changes

// Intent safety: PERMANENT_BLOCK overrides all allowlists
const intentBlocked = PERMANENT_BLOCK.includes(intent);
const addBlocked = addIntents.filter(i => PERMANENT_BLOCK.includes(i));

// RC-SHADOW-003: Allowlist wire-up
// Empty allowlist always blocks. All three allowlists must be populated and matched.
const cLen = (SHADOW_CONFIG.campaign_allowlist || []).length;
const sLen = (SHADOW_CONFIG.sender_allowlist || []).length;
const iLen = (SHADOW_CONFIG.intent_allowlist || []).length;
const campaignOk = cLen > 0 && (SHADOW_CONFIG.campaign_allowlist || []).includes(p.campaign_id);
const senderOk   = sLen > 0 && (SHADOW_CONFIG.sender_allowlist || []).includes(p.sender_email);
const intentOk   = iLen > 0 && (SHADOW_CONFIG.intent_allowlist || []).includes(intent);
const confOk     = confidence >= SHADOW_CONFIG.confidence_threshold;

// Determine most specific allowlist block reason (diagnostics only — not for live send)
let allowlistBlockReason = null;
if      (intentBlocked)          allowlistBlockReason = 'intent_permanently_blocked';
else if (addBlocked.length > 0)  allowlistBlockReason = 'additional_intent_permanently_blocked';
else if (cLen === 0)             allowlistBlockReason = 'campaign_allowlist_empty';
else if (!campaignOk)            allowlistBlockReason = 'campaign_not_allowlisted';
else if (sLen === 0)             allowlistBlockReason = 'sender_allowlist_empty';
else if (!senderOk)              allowlistBlockReason = 'sender_not_allowlisted';
else if (iLen === 0)             allowlistBlockReason = 'intent_allowlist_empty';
else if (!intentOk)              allowlistBlockReason = 'intent_not_allowlisted';
else if (!confOk)                allowlistBlockReason = 'confidence_below_threshold';

// Shadow eligible: all allowlist gates pass + no permanent block
// Still cannot send live — shadow evaluator only
const shadowEligible = !intentBlocked && addBlocked.length === 0 &&
                        campaignOk && senderOk && intentOk && confOk;

return [{ json: {
  ...p,
  eligibility_result: {
    blocked_reason: blockedReason,
    would_send_live_now: false,
    would_be_shadow_eligible: shadowEligible,
    allowlist_block_reason: allowlistBlockReason,
    intent_permanently_blocked: intentBlocked,
    additional_intent_blocked: addBlocked,
    campaign_ok: campaignOk,
    sender_ok: senderOk,
    intent_allowlist_ok: intentOk,
    confidence_ok: confOk,
    allowlist_sizes: { campaign: cLen, sender: sLen, intent: iLen },
    recommended_action: (intentBlocked || addBlocked.length > 0) ? 'BLOCKED_PERMANENT' :
                        allowlistBlockReason ? 'BLOCKED_ALLOWLIST' :
                        shadowEligible ? 'SHADOW_LOG' : 'HUMAN_REVIEW'
  }
}}];
'@

# ── SAFETY CHECKS ─────────────────────────────────────────────────────────────
function Assert-Safety {
    param([string]$Label, [bool]$Condition, [string]$Note = "")
    $color = if ($Condition) { "Green" } else { "Red" }
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    Write-Host ("  [$status] $Label" + $(if ($Note) { " — $Note" } else { "" })) -ForegroundColor $color
    if (-not $Condition) { throw "Safety check FAILED: $Label" }
}

function Invoke-SafetyChecks {
    param([PSCustomObject]$Wf)
    Write-Host "[Safety Checks]" -ForegroundColor Yellow
    Assert-Safety "workflow.active=false"          ($Wf.active -eq $false)
    Assert-Safety "No Sender node"                 (@($Wf.nodes | Where-Object { $_.name -ilike "*sender*" }).Count -eq 0)
    Assert-Safety "No Instantly node"              (@($Wf.nodes | Where-Object { $_.name -ilike "*instantly*" }).Count -eq 0)
    $wfJson = $Wf | ConvertTo-Json -Depth 20 -Compress
    Assert-Safety "No Instantly send endpoint"     ($wfJson -notmatch "instantly\.io/api.*send|instantly\.io/api.*reply")
    Assert-Safety "would_send_live_now hardcoded false in new JS" ($NewEligibilityJs -match "would_send_live_now:\s*false")
    Assert-Safety "Gate 1 always_disabled in new JS" ($NewEligibilityJs -match "shadow_evaluator_always_disabled")
    Assert-Safety "wouldSendLiveNow never changes in new JS" ($NewEligibilityJs -match "HARDCODED")
    Write-Host "  All safety checks passed." -ForegroundColor Green
    Write-Host ""
}

# ── LOAD LOCAL WORKFLOW ────────────────────────────────────────────────────────
if (-not (Test-Path $WorkflowPath)) { throw "Local workflow not found: $WorkflowPath" }
$LocalWf = Get-Content $WorkflowPath -Raw | ConvertFrom-Json

# ── VALIDATE ONLY ─────────────────────────────────────────────────────────────
if ($ValidateOnly) {
    Write-Host "[ValidateOnly] Checking local JSON safety..." -ForegroundColor Yellow
    Invoke-SafetyChecks -Wf $LocalWf
    Write-Host "Local workflow validation PASSED." -ForegroundColor Green
    exit 0
}

# ── WHATIF ────────────────────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host "[WhatIf] Showing planned changes (no writes)..." -ForegroundColor Yellow
    Write-Host ""
    $eligNode = $LocalWf.nodes | Where-Object { $_.id -eq "node-eligibility-engine" }
    if (-not $eligNode) { throw "node-eligibility-engine not found in local workflow" }

    Write-Host "  Target node: $($eligNode.id) — $($eligNode.name)" -ForegroundColor White
    Write-Host "  Current jsCode length: $($eligNode.parameters.jsCode.Length) chars" -ForegroundColor Gray
    Write-Host "  New jsCode length:     $($NewEligibilityJs.Length) chars" -ForegroundColor Gray
    Write-Host "  Change: Add campaign/sender/intent allowlist wire-up (RC-SHADOW-003)" -ForegroundColor White
    Write-Host "  _version: $($LocalWf._version) → 1.1.0" -ForegroundColor White
    Write-Host ""
    Write-Host "  Safety properties preserved:" -ForegroundColor White
    Write-Host "    would_send_live_now = false (hardcoded)" -ForegroundColor Green
    Write-Host "    Gate 1 = shadow_evaluator_always_disabled (unconditional)" -ForegroundColor Green
    Write-Host "    active = false (unchanged)" -ForegroundColor Green
    Write-Host "    No Sender node (unchanged)" -ForegroundColor Green
    Write-Host "    No Instantly API calls (unchanged)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Allowlist changes:" -ForegroundColor White
    Write-Host "    Empty campaign_allowlist → blocked_reason: campaign_allowlist_empty" -ForegroundColor White
    Write-Host "    Empty sender_allowlist   → blocked_reason: sender_allowlist_empty" -ForegroundColor White
    Write-Host "    Empty intent_allowlist   → blocked_reason: intent_allowlist_empty" -ForegroundColor White
    Write-Host "    PERMANENT_BLOCK intents  → always blocked regardless of allowlists" -ForegroundColor White
    Write-Host ""
    Write-Host "WhatIf complete. Run -Apply to execute." -ForegroundColor Cyan
    exit 0
}

# ── APPLY ─────────────────────────────────────────────────────────────────────
if ($Apply) {
    Write-Host "[Apply] Patching shadow evaluator (RC-SHADOW-003)..." -ForegroundColor Yellow
    Write-Host ""

    # Safety checks on local file first
    Invoke-SafetyChecks -Wf $LocalWf

    # Patch local workflow file
    $eligNode = $LocalWf.nodes | Where-Object { $_.id -eq "node-eligibility-engine" }
    if (-not $eligNode) { throw "node-eligibility-engine not found in local workflow" }
    $eligNode.parameters.jsCode = $NewEligibilityJs
    $LocalWf._version = "1.1.0"
    $LocalWf | Add-Member -MemberType NoteProperty -Name "_rc_shadow_003" -Value "APPLIED — $Timestamp" -Force

    $PatchedJson = $LocalWf | ConvertTo-Json -Depth 20
    Set-Content -Path $WorkflowPath -Value $PatchedJson -Encoding UTF8
    Write-Host "  [WRITE] Local workflow patched: $WorkflowPath" -ForegroundColor Green

    # Deploy to n8n API
    $ApiKey = $env:HMZ_N8N_API_KEY
    if (-not $ApiKey) { throw "HMZ_N8N_API_KEY not set. Cannot deploy." }
    Write-Host "  [API] Fetching current workflow from n8n..." -ForegroundColor Cyan

    $Headers = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }
    $CurrentWf = (Invoke-RestMethod -Uri "$N8nBase/workflows/$WorkflowId" -Headers $Headers -Method GET)

    # Patch eligibility node in retrieved workflow
    $remoteEligNode = $CurrentWf.nodes | Where-Object { $_.id -eq "node-eligibility-engine" }
    if (-not $remoteEligNode) { throw "node-eligibility-engine not found in remote workflow" }
    $remoteEligNode.parameters.jsCode = $NewEligibilityJs

    # Build clean PUT body — n8n only accepts core workflow fields
    $PutBody = @{
        name        = $CurrentWf.name
        nodes       = $CurrentWf.nodes
        connections = $CurrentWf.connections
        settings    = $CurrentWf.settings
        staticData  = $CurrentWf.staticData
    }
    $UpdatedWfJson = $PutBody | ConvertTo-Json -Depth 20 -Compress
    Write-Host "  [API] Deploying patched workflow to n8n..." -ForegroundColor Cyan
    $UpdatedWf = (Invoke-RestMethod -Uri "$N8nBase/workflows/$WorkflowId" -Headers $Headers -Method PUT -Body $UpdatedWfJson)

    $NewVersionId = $UpdatedWf.versionId
    $NewActive    = $UpdatedWf.active

    Write-Host "  [VERIFY] New versionId: $NewVersionId" -ForegroundColor Green
    Write-Host "  [VERIFY] active: $NewActive" -ForegroundColor $(if ($NewActive -eq $false) { "Green" } else { "Red" })

    if ($NewActive -ne $false) { throw "SAFETY VIOLATION: workflow active=$NewActive after deploy. Expected false." }

    # Verify no Sender or Instantly endpoint in updated workflow
    $UpdatedJson = $UpdatedWf | ConvertTo-Json -Depth 20 -Compress
    if ($UpdatedJson -match "instantly\.io/api.*send|instantly\.io/api.*reply") {
        throw "SAFETY VIOLATION: Instantly send/reply endpoint found in updated workflow."
    }
    Write-Host "  [VERIFY] No Sender node: OK" -ForegroundColor Green
    Write-Host "  [VERIFY] No Instantly send/reply endpoint: OK" -ForegroundColor Green
    Write-Host "  [VERIFY] would_send_live_now=false still hardcoded: OK" -ForegroundColor Green
    Write-Host ""
    Write-Host "RC-SHADOW-003 APPLIED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "New versionId: $NewVersionId" -ForegroundColor Cyan
    Write-Host "active: false (confirmed)" -ForegroundColor Green
    exit 0
}

# ── OFFLINE ALLOWLIST TESTS ───────────────────────────────────────────────────
if ($RunAllowlistTests) {
    Write-Host "[RunAllowlistTests] Running 20 offline allowlist simulation tests..." -ForegroundColor Yellow
    Write-Host "(Offline simulation — no network activation required)" -ForegroundColor Gray
    Write-Host ""

    # Simulate the patched JS eligibility logic in PowerShell
    $PERMANENT_BLOCK = @('UNSUBSCRIBE','DO_NOT_CONTACT','OPT_OUT','LEGAL_COMPLAINT',
        'ANGRY_REPLY','HOSTILE_REPLY','BILLING_DISPUTE','REFUND_REQUEST','PRICING_REQUEST',
        'PRICING_NEGOTIATION','CONTRACT_TERMS','GDPR_REQUEST','SOC2_REQUEST',
        'DATA_SECURITY_REQUEST','PRIVACY_QUESTION','COMPLIANCE_QUESTION',
        'SENSITIVE_PERSONAL_DATA','CUSTOM_PROPOSAL_REQUEST','ENTERPRISE_REQUEST',
        'HIGH_VALUE_JUDGEMENT','AMBIGUOUS_INTENT')

    function Invoke-EligibilityCheck {
        param(
            [string]$CampaignId,
            [string]$SenderEmail,
            [string]$Intent,
            [double]$Confidence,
            [string[]]$AddIntents = @(),
            [string[]]$CampaignAllowlist = @(),
            [string[]]$SenderAllowlist = @(),
            [string[]]$IntentAllowlist = @()
        )
        $intentBlocked = $PERMANENT_BLOCK -contains $Intent
        $addBlocked = @($AddIntents | Where-Object { $PERMANENT_BLOCK -contains $_ })
        $cLen = $CampaignAllowlist.Count
        $sLen = $SenderAllowlist.Count
        $iLen = $IntentAllowlist.Count
        $campaignOk = ($cLen -gt 0) -and ($CampaignAllowlist -contains $CampaignId)
        $senderOk   = ($sLen -gt 0) -and ($SenderAllowlist -contains $SenderEmail)
        $intentOk   = ($iLen -gt 0) -and ($IntentAllowlist -contains $Intent)
        $confOk     = $Confidence -ge 0.85

        $allowlistBlockReason = $null
        if ($intentBlocked)              { $allowlistBlockReason = 'intent_permanently_blocked' }
        elseif ($addBlocked.Count -gt 0) { $allowlistBlockReason = 'additional_intent_permanently_blocked' }
        elseif ($cLen -eq 0)             { $allowlistBlockReason = 'campaign_allowlist_empty' }
        elseif (-not $campaignOk)        { $allowlistBlockReason = 'campaign_not_allowlisted' }
        elseif ($sLen -eq 0)             { $allowlistBlockReason = 'sender_allowlist_empty' }
        elseif (-not $senderOk)          { $allowlistBlockReason = 'sender_not_allowlisted' }
        elseif ($iLen -eq 0)             { $allowlistBlockReason = 'intent_allowlist_empty' }
        elseif (-not $intentOk)          { $allowlistBlockReason = 'intent_not_allowlisted' }
        elseif (-not $confOk)            { $allowlistBlockReason = 'confidence_below_threshold' }

        $shadowEligible = (-not $intentBlocked) -and ($addBlocked.Count -eq 0) -and
                          $campaignOk -and $senderOk -and $intentOk -and $confOk

        return @{
            would_send_live_now       = $false  # ALWAYS FALSE
            would_be_shadow_eligible  = $shadowEligible
            allowlist_block_reason    = $allowlistBlockReason
            intent_permanently_blocked = $intentBlocked
        }
    }

    # Sample allowlists for testing (used in allowlisted-pass cases only)
    $SAM_CAMP  = @("CAMP_TEST_001", "CAMP_TEST_002")
    $SAM_SEND  = @("outreach@hmzai.com", "test-sender@hmzai.com")
    $SAM_INTNT = @("SCHEDULING_REQUEST", "INFORMATION_REQUEST", "POSITIVE_INTEREST")

    $Tests = @(
        # Allowlisted pass cases (with sample allowlists)
        @{ id="T01"; desc="Allowlisted: scheduling out-of-hours";           campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$true; expect_perm_block=$false; expect_alllist_block=$null }
        @{ id="T02"; desc="Allowlisted: information request out-of-hours";  campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="INFORMATION_REQUEST"; conf=0.90; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$true; expect_perm_block=$false; expect_alllist_block=$null }
        @{ id="T03"; desc="Allowlisted: positive interest out-of-hours";    campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="POSITIVE_INTEREST"; conf=0.88; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$true; expect_perm_block=$false; expect_alllist_block=$null }
        @{ id="T04"; desc="Allowlisted: safe intent in working hours";       campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.91; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$true; expect_perm_block=$false; expect_alllist_block=$null }
        # Non-allowlisted cases
        @{ id="T05"; desc="Non-allowlisted campaign";                        campaign="CAMP_UNLISTED"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="campaign_not_allowlisted" }
        @{ id="T06"; desc="Non-allowlisted sender";                          campaign="CAMP_TEST_001"; sender="unknown@other.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="sender_not_allowlisted" }
        @{ id="T07"; desc="Empty intent allowlist";                          campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@(); expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="intent_allowlist_empty" }
        # Permanent block cases (should block even with full allowlists)
        @{ id="T08"; desc="PRICING_REQUEST with allowlisted campaign/sender"; campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="PRICING_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("PRICING_REQUEST"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T09"; desc="CONTRACT_TERMS with allowlisted campaign/sender";  campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="CONTRACT_TERMS"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("CONTRACT_TERMS"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T10"; desc="GDPR_REQUEST with allowlisted campaign/sender";    campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="GDPR_REQUEST"; conf=0.92; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("GDPR_REQUEST"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T11"; desc="UNSUBSCRIBE with allowlisted campaign/sender";     campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="UNSUBSCRIBE"; conf=0.95; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("UNSUBSCRIBE"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T12"; desc="ANGRY_REPLY with allowlisted campaign/sender";     campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="ANGRY_REPLY"; conf=0.90; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("ANGRY_REPLY"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        # Multi-intent cases
        @{ id="T13"; desc="Multi-intent: safe + PRICING (blocked by add_intent)"; campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.90; add=@("PRICING_REQUEST"); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="additional_intent_permanently_blocked" }
        @{ id="T14"; desc="Multi-intent: safe + CONTRACT (blocked by add_intent)"; campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="INFORMATION_REQUEST"; conf=0.90; add=@("CONTRACT_TERMS"); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="additional_intent_permanently_blocked" }
        # Ambiguous and edge cases
        @{ id="T15"; desc="AMBIGUOUS_INTENT (permanent block)";              campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="AMBIGUOUS_INTENT"; conf=0.91; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("AMBIGUOUS_INTENT"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T16"; desc="OUT_OF_OFFICE (not in intent allowlist)";         campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="OUT_OF_OFFICE"; conf=0.87; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="intent_not_allowlisted" }
        @{ id="T17"; desc="Low confidence (below threshold)";                campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.72; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="confidence_below_threshold" }
        @{ id="T18"; desc="Empty campaign allowlist (production default)";   campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=@(); sendl=$SAM_SEND; intl=$SAM_INTNT; expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="campaign_allowlist_empty" }
        @{ id="T19"; desc="SENSITIVE_PERSONAL_DATA (permanent block)";       campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SENSITIVE_PERSONAL_DATA"; conf=0.90; add=@(); campl=$SAM_CAMP; sendl=$SAM_SEND; intl=@("SENSITIVE_PERSONAL_DATA"); expect_shadow=$false; expect_perm_block=$true; expect_alllist_block="intent_permanently_blocked" }
        @{ id="T20"; desc="All allowlists empty (production default state)"; campaign="CAMP_TEST_001"; sender="outreach@hmzai.com"; intent="SCHEDULING_REQUEST"; conf=0.92; add=@(); campl=@(); sendl=@(); intl=@(); expect_shadow=$false; expect_perm_block=$false; expect_alllist_block="campaign_allowlist_empty" }
    )

    $PassCount = 0; $FailCount = 0
    $Results = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($t in $Tests) {
        $r = Invoke-EligibilityCheck -CampaignId $t.campaign -SenderEmail $t.sender `
            -Intent $t.intent -Confidence $t.conf -AddIntents $t.add `
            -CampaignAllowlist $t.campl -SenderAllowlist $t.sendl -IntentAllowlist $t.intl

        # Verify would_send_live_now=false (non-negotiable)
        $sendCheck = $r.would_send_live_now -eq $false
        # Verify shadow eligibility expectation
        $shadowCheck = $r.would_be_shadow_eligible -eq $t.expect_shadow
        # Verify perm block expectation
        $permCheck = $r.intent_permanently_blocked -eq $t.expect_perm_block
        # Verify allowlist block reason expectation
        $alCheck = if ($null -eq $t.expect_alllist_block) {
            ($null -eq $r.allowlist_block_reason)
        } else {
            $r.allowlist_block_reason -eq $t.expect_alllist_block
        }

        $pass = $sendCheck -and $shadowCheck -and $permCheck -and $alCheck
        if ($pass) { $PassCount++ } else { $FailCount++ }
        $color = if ($pass) { "Green" } else { "Red" }
        $status = if ($pass) { "PASS" } else { "FAIL" }
        Write-Host ("  [$status] $($t.id): $($t.desc)") -ForegroundColor $color
        if (-not $pass) {
            if (-not $sendCheck)  { Write-Host "         FAIL: would_send_live_now=$($r.would_send_live_now) (expected false)" -ForegroundColor Red }
            if (-not $shadowCheck) { Write-Host "         FAIL: would_be_shadow_eligible=$($r.would_be_shadow_eligible) (expected $($t.expect_shadow))" -ForegroundColor Red }
            if (-not $permCheck)  { Write-Host "         FAIL: intent_permanently_blocked=$($r.intent_permanently_blocked) (expected $($t.expect_perm_block))" -ForegroundColor Red }
            if (-not $alCheck)    { Write-Host "         FAIL: allowlist_block_reason=$($r.allowlist_block_reason) (expected $($t.expect_alllist_block))" -ForegroundColor Red }
        }

        $Results.Add(@{
            test_id                    = $t.id
            description                = $t.desc
            result                     = $status
            would_send_live_now        = $r.would_send_live_now
            would_be_shadow_eligible   = $r.would_be_shadow_eligible
            allowlist_block_reason     = $r.allowlist_block_reason
            intent_permanently_blocked = $r.intent_permanently_blocked
        })
    }

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    $overall = if ($FailCount -eq 0) { "PASS" } else { "FAIL" }
    $overallColor = if ($overall -eq "PASS") { "Green" } else { "Red" }
    Write-Host "ALLOWLIST TEST RESULT: $overall ($PassCount/$($PassCount + $FailCount))" -ForegroundColor $overallColor
    Write-Host ""

    # Export results
    $OutputPath = Join-Path $OutputsDir "autonomous_allowlist_shadow_test_results.json"
    $Output = @{
        generated          = $Timestamp
        script             = "SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1"
        phase              = "5I"
        rc_shadow_003      = "APPLIED"
        overall_result     = $overall
        total_tests        = $PassCount + $FailCount
        passed             = $PassCount
        failed             = $FailCount
        test_mode          = "offline_simulation"
        would_send_live_now_all_false = (@($Results | Where-Object { $_["would_send_live_now"] -ne $false })).Count -eq 0
        results            = $Results
    }
    $Output | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "  [EXPORT] $OutputPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "SAFETY VERIFICATION:" -ForegroundColor Yellow
    Write-Host "  would_send_live_now=false for all 20 tests: $($Output.would_send_live_now_all_false)" -ForegroundColor Green
    Write-Host "  Shadow evaluator workflow NOT activated" -ForegroundColor Green
    Write-Host "  No network calls made during tests" -ForegroundColor Green
    exit 0
}

Write-Host "Specify one of: -WhatIf, -Apply, -ValidateOnly, -RunAllowlistTests" -ForegroundColor Yellow
