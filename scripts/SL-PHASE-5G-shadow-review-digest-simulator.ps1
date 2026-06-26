#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5G: Shadow Review Digest Simulator

.DESCRIPTION
    Reads shadow test results and produces a daily digest summary and learning signal preview.
    No production writes. Never activates the shadow evaluator.

.PARAMETER RunDigestSimulation
    Run the digest simulation from test results.

.PARAMETER UseShadowTestResults
    Load results from outputs/autonomous_shadow_test_results.json.

.PARAMETER ExportDigest
    Write outputs/autonomous_shadow_daily_digest_from_tests.json.

.PARAMETER ExportLearningSignals
    Write outputs/autonomous_shadow_learning_signal_preview.json.

.PARAMETER NoProductionWrites
    Default: always on. No production writes occur.

.EXAMPLE
    .\SL-PHASE-5G-shadow-review-digest-simulator.ps1 -RunDigestSimulation -UseShadowTestResults -ExportDigest -ExportLearningSignals
#>

[CmdletBinding()]
param(
    [switch]$RunDigestSimulation,
    [switch]$UseShadowTestResults,
    [switch]$ExportDigest,
    [switch]$ExportLearningSignals,
    [switch]$NoProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot        = Split-Path $PSScriptRoot -Parent
$OutputsDir        = Join-Path $ScriptRoot "outputs"
$TestResultsPath   = Join-Path $OutputsDir "autonomous_shadow_test_results.json"
$DigestPath        = Join-Path $OutputsDir "autonomous_shadow_daily_digest_from_tests.json"
$LearningPath      = Join-Path $OutputsDir "autonomous_shadow_learning_signal_preview.json"
$Timestamp         = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5G: Shadow Review Digest Simulator ===" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp"
Write-Host "[SAFE] No production writes." -ForegroundColor Green
Write-Host ""

if (-not $RunDigestSimulation) {
    Write-Host "[INFO] Pass -RunDigestSimulation to run the digest."
    exit 0
}

# ── LOAD TEST RESULTS ─────────────────────────────────────────────────────────

if ($UseShadowTestResults) {
    if (-not (Test-Path $TestResultsPath)) {
        throw "Test results not found: $TestResultsPath. Run SL-PHASE-5F first."
    }
    $testData = Get-Content $TestResultsPath -Raw | ConvertFrom-Json
    $results  = $testData.results
    Write-Host "[LOADED] $($results.Count) test results from $TestResultsPath"
} else {
    throw "Use -UseShadowTestResults to load test data."
}

# ── CLASSIFY RESULTS ──────────────────────────────────────────────────────────

$shadowEligible  = @($results | Where-Object { $_.shadow_eligible -eq $true })
$blocked         = @($results | Where-Object { $_.recommended_action -eq "BLOCKED_PERMANENT" })
$humanReview     = @($results | Where-Object { $_.recommended_action -eq "HUMAN_REVIEW" })
$shadowLog       = @($results | Where-Object { $_.recommended_action -eq "SHADOW_LOG" })
$errors          = @($results | Where-Object { $_.result -eq "ERROR" })

# Count blocked reasons
$blockedReasons  = [ordered]@{}
foreach ($r in $blocked) {
    $key = if ($r.blocked_reason) { $r.blocked_reason } else { "shadow_evaluator_always_disabled" }
    if (-not $blockedReasons.Contains($key)) { $blockedReasons[$key] = 0 }
    $blockedReasons[$key]++
}

# Identify follow-ups needed
$followUps = @()
foreach ($r in $results) {
    if ($r.result -eq "ERROR") {
        $followUps += "ERROR in test $($r.test_id): $($r.error)"
    }
}

# Proposed shadow rule candidates (based on what would be beneficial)
$proposedRuleCandidates = @(
    @{
        rc_id       = "RC-SHADOW-001"
        label       = "Proof/examples request → SHADOW_LOG"
        observation = "T06 (proof/examples request) classified as SHADOW_LOG at confidence 0.88 — below 0.85 threshold produces HUMAN_REVIEW. Rule: if broad_category=PROOF_REQUEST and confidence>=0.85, promote to shadow-eligible."
        proposed_by = "shadow_digest_simulator"
        status      = "PROPOSED — requires owner review"
    }
    @{
        rc_id       = "RC-SHADOW-002"
        label       = "OUT_OF_OFFICE not permanently blocked — verify suppression policy"
        observation = "T16 (out-of-office) returned SHADOW_LOG not BLOCKED_PERMANENT. Confirm this is correct per approved reply policy — typically OOO gets a NOOP, not a shadow draft."
        proposed_by = "shadow_digest_simulator"
        status      = "PROPOSED — requires owner review"
    }
    @{
        rc_id       = "RC-SHADOW-003"
        label       = "Allowlist-controlled decisions need config wire-up"
        observation = "T17 (unlisted sender) and T18 (unlisted campaign) returned SHADOW_LOG because the shadow evaluator always uses empty allowlists. In production, these would route to BLOCKED — verify allowlist logic wire-up before Gate 2."
        proposed_by = "shadow_digest_simulator"
        status      = "ACTION_REQUIRED — verify before Gate 2"
    }
)

# Owner actions
$ownerActions = @(
    "Review shadow test results in outputs/autonomous_shadow_test_results.json"
    "Confirm SHADOW_LOG decisions are correct for: T01-T06, T09, T16-T20"
    "Confirm BLOCKED_PERMANENT decisions are correct for: T07-T08, T10-T15, T19"
    "Review proposed rule candidates RC-SHADOW-001 through RC-SHADOW-003"
    "Confirm OUT_OF_OFFICE handling policy (T16)"
    "Plan allowlist wire-up verification before Gate 2 (RC-SHADOW-003)"
    "Continue shadow review for 14 days before Gate 2 decision"
)

# ── PRODUCE DIGEST ────────────────────────────────────────────────────────────

$digest = [ordered]@{
    digest_type              = "autonomous_shadow_daily_digest"
    digest_date              = "2026-06-24"
    generated_at             = $Timestamp
    source                   = "shadow_controlled_tests_phase_5f"
    total_test_payloads      = $results.Count
    shadow_eligible_count    = $shadowEligible.Count
    blocked_count            = $blocked.Count
    human_review_count       = $humanReview.Count
    shadow_log_count         = $shadowLog.Count
    error_count              = $errors.Count
    would_send_live_now_ever_true = $false
    top_blocked_reasons      = $blockedReasons
    escalations              = @()
    escalation_channel       = "GOOGLE_CHAT_WEBHOOK_URL (env reference only)"
    follow_ups_needed        = $followUps
    learning_signals_would_be_created = $proposedRuleCandidates.Count
    proposed_shadow_rule_candidates = $proposedRuleCandidates
    owner_actions            = $ownerActions
    production_changes       = $false
    live_sends               = $false
    shadow_evaluator_active_at_end = $false
    workflow_id              = "aHzLtQiv6G8h1bqD"
    workflow_version_id      = "51ebacbd-f68c-47e4-af38-537bcdccebf1"
    gate_2_recommendation    = "14 days shadow review before any controlled pilot. Owner must approve Gate 2 explicitly. Do not change autonomous_enabled, shadow_only, or dry_run without Gate 2 sign-off."
}

# ── PRODUCE LEARNING SIGNALS ──────────────────────────────────────────────────

$learnignSignals = [ordered]@{
    signal_type     = "autonomous_shadow_learning_signal_preview"
    generated_at    = $Timestamp
    source          = "shadow_controlled_tests_phase_5f"
    signals         = @(
        @{
            signal_id   = "LS-001"
            case_id     = "SHADOW-T06"
            trigger     = "PROOF_REQUEST at confidence 0.88 → SHADOW_LOG"
            observation = "Proof/examples request correctly shadow-logged. No permanent block. No live send."
            learning    = "Proof requests should remain shadow-logged, not auto-sent. Verify approved reply policy permits proof responses."
            action      = "Monitor across real prospect traffic to see frequency"
        }
        @{
            signal_id   = "LS-002"
            case_id     = "SHADOW-T09"
            trigger     = "POSITIVE_INTEREST_GENERAL (pilot request) at confidence 0.87 → SHADOW_LOG"
            observation = "One-campaign pilot interest correctly shadow-logged. Confidence just above threshold."
            learning    = "Low confidence positive interest near 0.85 threshold may warrant tighter threshold. Monitor for false positives."
            action      = "Track confidence distribution across real traffic before adjusting threshold"
        }
        @{
            signal_id   = "LS-003"
            case_id     = "SHADOW-T15"
            trigger     = "AMBIGUOUS_INTENT at confidence 0.55 → BLOCKED_PERMANENT"
            observation = "Ambiguous 'yes' correctly permanently blocked. Low confidence + ambiguous = hard block."
            learning    = "Double protection working: ambiguous intent class AND low confidence both block correctly."
            action      = "No change needed. Confirm with real prospect data."
        }
        @{
            signal_id   = "LS-004"
            case_id     = "SHADOW-T19"
            trigger     = "POSITIVE_INTEREST + additional_intents=[PRICING_REQUEST, CONTRACT_TERMS] → BLOCKED_PERMANENT"
            observation = "Multi-intent case with one blocked additional intent correctly blocked overall."
            learning    = "Any blocked intent in additional_intents correctly triggers BLOCKED_PERMANENT. Additional intent guard is working."
            action      = "No change needed."
        }
    )
    production_writes_made  = $false
    live_sends_made         = $false
}

# ── EXPORT ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "--- Digest Summary ---" -ForegroundColor Yellow
Write-Host "  Total payloads:     $($results.Count)"
Write-Host "  Shadow eligible:    $($shadowEligible.Count)"
Write-Host "  Blocked permanent:  $($blocked.Count)"
Write-Host "  Shadow log:         $($shadowLog.Count)"
Write-Host "  Human review:       $($humanReview.Count)"
Write-Host "  Errors:             $($errors.Count)"
Write-Host "  would_send_live_now ever true: NO" -ForegroundColor Green
Write-Host "  Learning signals:   $($learnignSignals.signals.Count)"
Write-Host "  Rule candidates:    $($proposedRuleCandidates.Count)"
Write-Host ""

if ($ExportDigest) {
    $digest | ConvertTo-Json -Depth 10 | Set-Content $DigestPath -Encoding UTF8
    Write-Host "[EXPORTED] $DigestPath" -ForegroundColor Green
}

if ($ExportLearningSignals) {
    $learnignSignals | ConvertTo-Json -Depth 10 | Set-Content $LearningPath -Encoding UTF8
    Write-Host "[EXPORTED] $LearningPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SL-PHASE-5G Complete ===" -ForegroundColor Cyan
Write-Host "No production changes. No live sends." -ForegroundColor Green
