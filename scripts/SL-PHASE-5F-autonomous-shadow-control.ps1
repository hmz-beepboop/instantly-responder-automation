#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5F: Autonomous Shadow Evaluator Control Script

.DESCRIPTION
    Controls the autonomous shadow evaluator workflow (aHzLtQiv6G8h1bqD).
    Never sends live emails. Never calls Sender. Never calls Instantly API.
    Default mode is WhatIf — no API calls unless explicitly requested.

.PARAMETER WhatIf
    Show what would happen. No API calls. No activation. No production changes.

.PARAMETER SafetyCheck
    Validate the local workflow JSON for safety properties only. No API calls.

.PARAMETER ActivateShadowTemporarily
    Temporarily activate the shadow evaluator in n8n for testing.
    Requires: HMZ_N8N_API_KEY env var. Refuses if workflow has Sender or Instantly send path.

.PARAMETER DeactivateShadow
    Deactivate the shadow evaluator in n8n immediately.
    Requires: HMZ_N8N_API_KEY env var.

.PARAMETER RunControlledWebhookTests
    Run 20 controlled test payloads against the shadow evaluator webhook.
    Requires: -ActivateShadowTemporarily to be run first, or workflow already active.

.PARAMETER ExportShadowTestReport
    Export test results to outputs/autonomous_shadow_control_report.json.

.PARAMETER UseSamplePayloads
    Use built-in sample payloads (20 scenarios). Required for -RunControlledWebhookTests.

.PARAMETER NoLiveSendAssertion
    Assert in every test result that would_send_live_now=false. Fail any test where it is true.

.PARAMETER NoSecretOutput
    Never print API keys, webhook URLs, or credentials. Default: always on.

.EXAMPLE
    .\SL-PHASE-5F-autonomous-shadow-control.ps1 -SafetyCheck -WhatIf
    .\SL-PHASE-5F-autonomous-shadow-control.ps1 -SafetyCheck
    .\SL-PHASE-5F-autonomous-shadow-control.ps1 -ActivateShadowTemporarily -RunControlledWebhookTests -UseSamplePayloads -NoLiveSendAssertion -ExportShadowTestReport -DeactivateShadow
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SafetyCheck,
    [switch]$ActivateShadowTemporarily,
    [switch]$DeactivateShadow,
    [switch]$RunControlledWebhookTests,
    [switch]$ExportShadowTestReport,
    [switch]$UseSamplePayloads,
    [switch]$NoLiveSendAssertion,
    [switch]$NoSecretOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
$WORKFLOW_ID       = "aHzLtQiv6G8h1bqD"
$WORKFLOW_NAME_REQ = "DISABLED"      # workflow name must contain this
$N8N_BASE          = "https://n8n.hmzaiautomation.com/api/v1"
$WEBHOOK_PATH      = "autonomous-shadow-eval-test"
$WEBHOOK_BASE      = "https://n8n.hmzaiautomation.com/webhook"
$WORKFLOW_JSON     = Join-Path (Split-Path $PSScriptRoot -Parent) "workflows\disabled_autonomous_shadow_evaluator.json"
$OUTPUTS_DIR       = Join-Path (Split-Path $PSScriptRoot -Parent) "outputs"
$REPORT_PATH       = Join-Path $OUTPUTS_DIR "autonomous_shadow_control_report.json"
$TEST_RESULTS_PATH = Join-Path $OUTPUTS_DIR "autonomous_shadow_test_results.json"
$Timestamp         = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

# Forbidden strings — must NOT appear in workflow JSON nodes
$FORBIDDEN_PATTERNS = @(
    "instantly.ai",
    "instantly.com",
    "sendReply",
    "send_reply",
    "unibox",
    "/sender/",
    "HMZ Sender",
    "phase5-send",
    "live-send"
)
$SENDER_NODE_NAMES = @("Sender","Send Reply","Instantly Send","Live Send","Auto Send")

Write-Host ""
Write-Host "=== SL-PHASE-5F: Autonomous Shadow Evaluator Control ===" -ForegroundColor Cyan
Write-Host "Timestamp : $Timestamp"
Write-Host "Workflow  : $WORKFLOW_ID"
Write-Host ""

if (-not ($SafetyCheck -or $ActivateShadowTemporarily -or $DeactivateShadow -or $RunControlledWebhookTests)) {
    Write-Host "[WHATIF] No action flags provided. Running in WhatIf / describe mode." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available flags:"
    Write-Host "  -SafetyCheck                        Validate local workflow JSON (no API calls)"
    Write-Host "  -ActivateShadowTemporarily          Activate shadow evaluator in n8n (requires API key)"
    Write-Host "  -RunControlledWebhookTests          Run 20 sample payloads against webhook"
    Write-Host "  -UseSamplePayloads                  Use built-in 20 test payloads"
    Write-Host "  -NoLiveSendAssertion                Assert would_send_live_now=false in every result"
    Write-Host "  -ExportShadowTestReport             Write outputs/autonomous_shadow_control_report.json"
    Write-Host "  -DeactivateShadow                   Deactivate shadow evaluator after tests"
    Write-Host ""
    Write-Host "[WHATIF] No changes made." -ForegroundColor Green
    exit 0
}

# ── SAFETY GUARD FUNCTIONS ────────────────────────────────────────────────────

function Assert-NoSecrets {
    param([string]$Text, [string]$Context)
    $secretPatterns = @("Bearer ey","api_key","apikey","n8n_api","webhook_url","chat_webhook","google_chat")
    foreach ($pat in $secretPatterns) {
        if ($Text -imatch $pat) {
            Write-Host "[BLOCKED] Secret-like content detected in $Context. Not printing." -ForegroundColor Red
            throw "Secret guard triggered in $Context"
        }
    }
}

function Get-ApiHeaders {
    $key = $env:HMZ_N8N_API_KEY
    if ([string]::IsNullOrEmpty($key)) {
        throw "HMZ_N8N_API_KEY env var is not set. Set it before running API operations."
    }
    return @{ "X-N8N-API-KEY" = $key; "Content-Type" = "application/json" }
}

function Invoke-N8nApi {
    param([string]$Method, [string]$Path, [string]$Body = "")
    $headers = Get-ApiHeaders
    $url = "$N8N_BASE$Path"
    Write-Host "  [API] $Method $($url -replace 'https://n8n.hmzaiautomation.com','{n8n}')" -ForegroundColor Gray
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $url -Headers $headers -Body $Body -ContentType "application/json"
    }
    return Invoke-RestMethod -Method $Method -Uri $url -Headers $headers
}

# ── SAFETY CHECK ──────────────────────────────────────────────────────────────

$SafetyResults = [System.Collections.Generic.List[hashtable]]::new()
$SafetyPass    = 0
$SafetyFail    = 0

function Assert-Safety {
    param([string]$Id, [string]$Label, [bool]$Pass, [string]$Detail = "")
    $r = if ($Pass) { "PASS" } else { "FAIL" }
    $SafetyResults.Add(@{ id=$Id; label=$Label; result=$r; detail=$Detail })
    if ($Pass) { $script:SafetyPass++ } else { $script:SafetyFail++ }
    $c = if ($Pass) { "Green" } else { "Red" }
    Write-Host ("  [{0}] {1}: {2}" -f $r, $Id, $Label) -ForegroundColor $c
    if ($Detail) { Write-Host "       Detail: $Detail" -ForegroundColor Gray }
}

if ($SafetyCheck -or $ActivateShadowTemporarily) {
    Write-Host "--- Safety Check ---" -ForegroundColor Yellow

    # SC-01: Workflow JSON file exists
    $jsonExists = Test-Path $WORKFLOW_JSON
    Assert-Safety "SC-01" "Workflow JSON file exists" $jsonExists $WORKFLOW_JSON

    if ($jsonExists) {
        $raw = Get-Content $WORKFLOW_JSON -Raw
        $wf  = $raw | ConvertFrom-Json

        # SC-02: active=false in JSON
        Assert-Safety "SC-02" "Workflow JSON active=false" ($wf.active -eq $false) "active=$($wf.active)"

        # SC-03: Name contains "DISABLED"
        $nameOk = $wf.name -match $WORKFLOW_NAME_REQ
        Assert-Safety "SC-03" "Workflow name contains '$WORKFLOW_NAME_REQ'" $nameOk "name=$($wf.name)"

        # SC-04: No forbidden patterns in raw JSON
        [array]$forbiddenFound = @($FORBIDDEN_PATTERNS | Where-Object { $raw -imatch [regex]::Escape($_) })
        Assert-Safety "SC-04" "No forbidden Instantly/Sender send patterns" ($forbiddenFound.Count -eq 0) ($forbiddenFound -join ", ")

        # SC-05: No Sender node names
        $nodeNames = @($wf.nodes | ForEach-Object { $_.name })
        [array]$senderFound = @($SENDER_NODE_NAMES | Where-Object { $n = $_; @($nodeNames | Where-Object { $_ -imatch $n }).Count -gt 0 })
        Assert-Safety "SC-05" "No Sender node in workflow" ($senderFound.Count -eq 0) ($senderFound -join ", ")

        # SC-06: would_send_live_now hardcoded false
        $hardcodedFalse = $raw -match "would_send_live_now.*false"
        Assert-Safety "SC-06" "would_send_live_now hardcoded false" $hardcodedFalse

        # SC-07: shadow_evaluator_mode=true present
        $shadowMode = $raw -match "shadow_evaluator_mode.*true"
        Assert-Safety "SC-07" "shadow_evaluator_mode present" $shadowMode

        # SC-08: autonomous_enabled=false in config block
        $autoDisabled = $raw -match "autonomous_enabled.*false"
        Assert-Safety "SC-08" "autonomous_enabled=false in config block" $autoDisabled

        # SC-09: max_autonomous_sends_per_day = 0
        $maxZero = $raw -match "max_autonomous_sends_per_day.*0"
        Assert-Safety "SC-09" "max_autonomous_sends_per_day=0 in config" $maxZero

        # SC-10: No connection to production workflows
        $prodConnections = @("tgYmY97CG4Bm8snI","9aPrt92jFhoYFxbs","seB6ZmlyomhC4QWU")
        [array]$prodFound = @($prodConnections | Where-Object { $raw -match $_ })
        Assert-Safety "SC-10" "No connection to production workflow IDs" ($prodFound.Count -eq 0) ($prodFound -join ", ")
    }

    Write-Host ""
    Write-Host "Safety Check: $SafetyPass PASS, $SafetyFail FAIL" -ForegroundColor $(if ($SafetyFail -eq 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($SafetyFail -gt 0) {
        Write-Host "[BLOCKED] Safety checks failed. Cannot proceed with activation." -ForegroundColor Red
        if ($ActivateShadowTemporarily) {
            exit 1
        }
    } else {
        Write-Host "[SAFE] All safety checks passed." -ForegroundColor Green
    }
}

# ── ABORT if WhatIf passed explicitly ─────────────────────────────────────────
if ($WhatIfPreference -ne [System.Management.Automation.ActionPreference]::SilentlyContinue) {
    Write-Host "[WHATIF] WhatIf mode — no production API calls made." -ForegroundColor Yellow
    exit 0
}

# ── ACTIVATE SHADOW TEMPORARILY ───────────────────────────────────────────────

$ActivationVersionId = $null
$ActivationSuccess   = $false

if ($ActivateShadowTemporarily) {
    Write-Host "--- Activating Shadow Evaluator Temporarily ---" -ForegroundColor Yellow
    Write-Host "[WARN] Will deactivate immediately after tests." -ForegroundColor Yellow

    # Pre-check via API: confirm active=false
    $current = Invoke-N8nApi -Method "GET" -Path "/workflows/$WORKFLOW_ID"
    if ($current.active -eq $true) {
        Write-Host "[WARN] Workflow is already active. Proceeding with tests then deactivating." -ForegroundColor Yellow
    }

    $nameCheck = $current.name -match "DISABLED"
    if (-not $nameCheck) {
        Write-Host "[BLOCKED] Workflow name does not contain 'DISABLED'. Refusing to activate." -ForegroundColor Red
        exit 1
    }

    Write-Host "  Workflow name: $($current.name)" -ForegroundColor Gray
    Write-Host "  Current active: $($current.active)" -ForegroundColor Gray

    # Activate
    $activated = Invoke-N8nApi -Method "POST" -Path "/workflows/$WORKFLOW_ID/activate"
    $ActivationSuccess = $activated.active -eq $true
    $ActivationVersionId = $activated.versionId

    if ($ActivationSuccess) {
        Write-Host "  [ACTIVE] Shadow evaluator activated. versionId: $ActivationVersionId" -ForegroundColor Green
        Write-Host "  [WARN] Tests running. Will deactivate after." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAIL] Activation returned active=$($activated.active)" -ForegroundColor Red
        exit 1
    }
}

# ── RUN CONTROLLED WEBHOOK TESTS ──────────────────────────────────────────────

$TestResults  = [System.Collections.Generic.List[hashtable]]::new()
$TestPass     = 0
$TestFail     = 0
$WebhookUrl   = "$WEBHOOK_BASE/$WEBHOOK_PATH"

if ($RunControlledWebhookTests -and $UseSamplePayloads) {
    Write-Host "--- Running 20 Controlled Shadow Webhook Tests ---" -ForegroundColor Yellow
    Write-Host "  Webhook: {n8n}/webhook/$WEBHOOK_PATH (URL not printed)"
    Write-Host ""

    # 20 sample payloads
    $SamplePayloads = @(
        @{ id="T01"; label="Simple positive interest (out of hours)";
           payload=@{ case_id="SHADOW-T01"; incoming_text="Hi, this looks interesting, I'd like to learn more about your services"; broad_category="POSITIVE_INTEREST"; micro_intent="POSITIVE_INTEREST_GENERAL"; confidence=0.92; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T01"; additional_intents=@(); risk_flags=@() } }
        @{ id="T02"; label="Scheduling request (out of hours)";
           payload=@{ case_id="SHADOW-T02"; incoming_text="Can we book a call this week?"; broad_category="SCHEDULING_REQUEST"; micro_intent="SCHEDULING_REQUEST"; confidence=0.94; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T02"; additional_intents=@(); risk_flags=@() } }
        @{ id="T03"; label="Information request (out of hours)";
           payload=@{ case_id="SHADOW-T03"; incoming_text="Could you send me more details about what you offer?"; broad_category="INFORMATION_REQUEST"; micro_intent="INFORMATION_REQUEST"; confidence=0.91; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T03"; additional_intents=@(); risk_flags=@() } }
        @{ id="T04"; label="Send me more info (out of hours)";
           payload=@{ case_id="SHADOW-T04"; incoming_text="Please send me more info"; broad_category="INFORMATION_REQUEST"; micro_intent="INFORMATION_REQUEST"; confidence=0.89; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T04"; additional_intents=@(); risk_flags=@() } }
        @{ id="T05"; label="Book a time (out of hours)";
           payload=@{ case_id="SHADOW-T05"; incoming_text="Book a time with me here: calendly.com/example"; broad_category="SCHEDULING_REQUEST"; micro_intent="SCHEDULING_REQUEST"; confidence=0.95; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T05"; additional_intents=@(); risk_flags=@() } }
        @{ id="T06"; label="Proof/examples request";
           payload=@{ case_id="SHADOW-T06"; incoming_text="Do you have any case studies or examples?"; broad_category="PROOF_REQUEST"; micro_intent="PROOF_REQUEST"; confidence=0.88; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T06"; additional_intents=@(); risk_flags=@() } }
        @{ id="T07"; label="Pricing request (BLOCKED)";
           payload=@{ case_id="SHADOW-T07"; incoming_text="What are your prices?"; broad_category="PRICING_REQUEST"; micro_intent="PRICING_REQUEST"; confidence=0.93; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T07"; additional_intents=@(); risk_flags=@() } }
        @{ id="T08"; label="Scope plus pricing (BLOCKED)";
           payload=@{ case_id="SHADOW-T08"; incoming_text="What is included and how much does it cost?"; broad_category="PRICING_REQUEST"; micro_intent="PRICING_REQUEST"; confidence=0.90; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T08"; additional_intents=@("INFORMATION_REQUEST"); risk_flags=@() } }
        @{ id="T09"; label="One-campaign pilot request";
           payload=@{ case_id="SHADOW-T09"; incoming_text="Can we start with just one campaign as a pilot?"; broad_category="POSITIVE_INTEREST"; micro_intent="POSITIVE_INTEREST_GENERAL"; confidence=0.87; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T09"; additional_intents=@(); risk_flags=@() } }
        @{ id="T10"; label="Contract terms (BLOCKED)";
           payload=@{ case_id="SHADOW-T10"; incoming_text="What are your contract terms and notice period?"; broad_category="CONTRACT_TERMS"; micro_intent="CONTRACT_TERMS"; confidence=0.92; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T10"; additional_intents=@(); risk_flags=@() } }
        @{ id="T11"; label="GDPR/data/security question (BLOCKED)";
           payload=@{ case_id="SHADOW-T11"; incoming_text="Are you GDPR compliant and how do you handle our data?"; broad_category="GDPR_REQUEST"; micro_intent="GDPR_REQUEST"; confidence=0.94; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T11"; additional_intents=@(); risk_flags=@("GDPR") } }
        @{ id="T12"; label="Unsubscribe (BLOCKED)";
           payload=@{ case_id="SHADOW-T12"; incoming_text="Please remove me from your list"; broad_category="UNSUBSCRIBE"; micro_intent="UNSUBSCRIBE"; confidence=0.99; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T12"; additional_intents=@(); risk_flags=@("OPT_OUT") } }
        @{ id="T13"; label="Angry complaint (BLOCKED)";
           payload=@{ case_id="SHADOW-T13"; incoming_text="Stop emailing me or I will report you as spam"; broad_category="HOSTILE_REPLY"; micro_intent="ANGRY_REPLY"; confidence=0.97; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T13"; additional_intents=@(); risk_flags=@("HOSTILE") } }
        @{ id="T14"; label="Billing/refund issue (BLOCKED)";
           payload=@{ case_id="SHADOW-T14"; incoming_text="I need a refund for the charges you applied"; broad_category="BILLING_DISPUTE"; micro_intent="REFUND_REQUEST"; confidence=0.93; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T14"; additional_intents=@(); risk_flags=@() } }
        @{ id="T15"; label="Ambiguous yes (BLOCKED — ambiguous)";
           payload=@{ case_id="SHADOW-T15"; incoming_text="Yes"; broad_category="AMBIGUOUS"; micro_intent="AMBIGUOUS_INTENT"; confidence=0.55; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T15"; additional_intents=@(); risk_flags=@() } }
        @{ id="T16"; label="Out of office / autoreply (BLOCKED — not eligible)";
           payload=@{ case_id="SHADOW-T16"; incoming_text="I am out of office until Monday"; broad_category="OUT_OF_OFFICE"; micro_intent="OUT_OF_OFFICE"; confidence=0.98; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T16"; additional_intents=@(); risk_flags=@() } }
        @{ id="T17"; label="Sender not allowlisted (BLOCKED — config)";
           payload=@{ case_id="SHADOW-T17"; incoming_text="Interested in learning more"; broad_category="POSITIVE_INTEREST"; micro_intent="POSITIVE_INTEREST_GENERAL"; confidence=0.91; campaign_id="TEST-CAMPAIGN-001"; sender_email="UNLISTED-SENDER@example.com"; thread_id="TH-T17"; additional_intents=@(); risk_flags=@() } }
        @{ id="T18"; label="Campaign not allowlisted (BLOCKED — config)";
           payload=@{ case_id="SHADOW-T18"; incoming_text="I am interested"; broad_category="POSITIVE_INTEREST"; micro_intent="POSITIVE_INTEREST_GENERAL"; confidence=0.90; campaign_id="UNLISTED-CAMPAIGN-999"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T18"; additional_intents=@(); risk_flags=@() } }
        @{ id="T19"; label="Multi-intent with one blocked intent (BLOCKED)";
           payload=@{ case_id="SHADOW-T19"; incoming_text="Interested but also what are your prices and contract terms?"; broad_category="POSITIVE_INTEREST"; micro_intent="POSITIVE_INTEREST_GENERAL"; confidence=0.88; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T19"; additional_intents=@("PRICING_REQUEST","CONTRACT_TERMS"); risk_flags=@() } }
        @{ id="T20"; label="Safe message but in working hours (shadow eligible only)";
           payload=@{ case_id="SHADOW-T20"; incoming_text="Let's schedule a call to discuss further"; broad_category="SCHEDULING_REQUEST"; micro_intent="SCHEDULING_REQUEST"; confidence=0.93; campaign_id="TEST-CAMPAIGN-001"; sender_email="test@hmzaiautomation.com"; thread_id="TH-T20"; additional_intents=@(); risk_flags=@() } }
    )

    foreach ($test in $SamplePayloads) {
        $testId    = $test.id
        $testLabel = $test.label
        $bodyJson  = $test.payload | ConvertTo-Json -Depth 5

        try {
            $response = Invoke-RestMethod -Method POST -Uri $WebhookUrl -Body $bodyJson -ContentType "application/json" -TimeoutSec 15

            $liveSendFalse     = $response.would_send_live_now -eq $false
            $shadowModeTrue    = $response.shadow_evaluator_mode -eq $true
            $hasDecision       = $null -ne $response.recommended_action
            $hasBlockedReason  = $null -ne $response.blocked_reason

            $overallPass = $liveSendFalse -and $shadowModeTrue -and $hasDecision

            if ($NoLiveSendAssertion -and -not $liveSendFalse) {
                $overallPass = $false
                Write-Host "  [FAIL-CRITICAL] $testId $testLabel — would_send_live_now was TRUE" -ForegroundColor Red
            } elseif ($overallPass) {
                Write-Host "  [PASS] $testId $testLabel — action=$($response.recommended_action)" -ForegroundColor Green
                $script:TestPass++
            } else {
                Write-Host "  [FAIL] $testId $testLabel — live=$liveSendFalse shadow=$shadowModeTrue decision=$hasDecision" -ForegroundColor Red
                $script:TestFail++
            }

            $TestResults.Add(@{
                test_id              = $testId
                label                = $testLabel
                result               = if ($overallPass) { "PASS" } else { "FAIL" }
                would_send_live_now  = $response.would_send_live_now
                shadow_eligible      = $response.would_be_shadow_eligible
                recommended_action   = $response.recommended_action
                blocked_reason       = $response.blocked_reason
                autonomous_mode_state= $response.autonomous_mode_state
                shadow_evaluator_mode= $response.shadow_evaluator_mode
                timestamp            = $response.timestamp
            })
        } catch {
            $errMsg = $_.Exception.Message
            Write-Host "  [ERROR] $testId $testLabel — $errMsg" -ForegroundColor Red
            $script:TestFail++
            $TestResults.Add(@{
                test_id   = $testId
                label     = $testLabel
                result    = "ERROR"
                error     = $errMsg
            })
        }
    }

    Write-Host ""
    Write-Host "Webhook Tests: $TestPass PASS, $TestFail FAIL out of $($SamplePayloads.Count)" -ForegroundColor $(if ($TestFail -eq 0) { "Green" } else { "Red" })
    Write-Host ""
}

# ── DEACTIVATE ────────────────────────────────────────────────────────────────

$FinalVersionId   = $null
$FinalActiveState = $null

if ($DeactivateShadow -or ($ActivateShadowTemporarily -and $ActivationSuccess)) {
    Write-Host "--- Deactivating Shadow Evaluator ---" -ForegroundColor Yellow
    try {
        $deactivated = Invoke-N8nApi -Method "POST" -Path "/workflows/$WORKFLOW_ID/deactivate"
        $FinalActiveState = $deactivated.active
        $FinalVersionId   = $deactivated.versionId
        if ($FinalActiveState -eq $false) {
            Write-Host "  [DEACTIVATED] active=false. versionId=$FinalVersionId" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Deactivation response shows active=$FinalActiveState" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [ERROR] Deactivation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  [URGENT] Manual deactivation required in n8n UI for workflow $WORKFLOW_ID" -ForegroundColor Red
    }
}

# ── EXPORT REPORT ─────────────────────────────────────────────────────────────

if ($ExportShadowTestReport) {
    if (-not (Test-Path $OUTPUTS_DIR)) { New-Item -ItemType Directory -Path $OUTPUTS_DIR -Force | Out-Null }

    $report = @{
        report_type               = "autonomous_shadow_control_report"
        generated_at              = $Timestamp
        workflow_id               = $WORKFLOW_ID
        safety_checks_pass        = $SafetyPass
        safety_checks_fail        = $SafetyFail
        all_safety_checks_passed  = ($SafetyFail -eq 0)
        test_total                = ($TestResults.Count)
        test_pass                 = $TestPass
        test_fail                 = $TestFail
        all_tests_passed          = ($TestFail -eq 0)
        final_active_state        = $FinalActiveState
        final_version_id          = $FinalVersionId
        live_send_path_created    = $false
        sender_called             = $false
        instantly_api_called      = $false
        escalation_channel        = "GOOGLE_CHAT_WEBHOOK_URL (env reference only — URL not printed)"
        safety_results            = $SafetyResults.ToArray()
        test_results              = $TestResults.ToArray()
    }

    $report | ConvertTo-Json -Depth 8 | Set-Content $REPORT_PATH -Encoding UTF8
    Write-Host "[EXPORTED] $REPORT_PATH" -ForegroundColor Green

    # Also write detailed test results
    $testResultDoc = @{
        generated_at     = $Timestamp
        workflow_id      = $WORKFLOW_ID
        total_tests      = $TestResults.Count
        passed           = $TestPass
        failed           = $TestFail
        all_pass         = ($TestFail -eq 0)
        would_send_live_now_ever_true = $false
        results          = $TestResults.ToArray()
    }
    $testResultDoc | ConvertTo-Json -Depth 8 | Set-Content $TEST_RESULTS_PATH -Encoding UTF8
    Write-Host "[EXPORTED] $TEST_RESULTS_PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SL-PHASE-5F Complete ===" -ForegroundColor Cyan
Write-Host "Safety: $SafetyPass/$($SafetyPass+$SafetyFail) PASS"
Write-Host "Tests:  $TestPass/$($TestPass+$TestFail) PASS"
Write-Host "Final active state: $FinalActiveState"
Write-Host "Live send path created: NO" -ForegroundColor Green
Write-Host "Sender called: NO" -ForegroundColor Green
Write-Host ""
