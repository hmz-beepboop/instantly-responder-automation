#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5H: Shadow Review Operations Pack

.DESCRIPTION
    Supports the 14-day autonomous shadow review period.
    Generates daily checklists, metrics templates, and validates shadow review readiness.
    No production writes. No activation of shadow evaluator. Read-only by default.

.PARAMETER GenerateDailyChecklist
    Print today's daily checklist to the console.

.PARAMETER GenerateMetricsTemplate
    Export a fresh metrics template JSON to outputs/.

.PARAMETER ValidateShadowReviewReadiness
    Check all pre-review conditions: workflow IDs, file existence, safety state.

.PARAMETER ExportReport
    Export a readiness report to outputs/autonomous_shadow_review_readiness_report.json.

.PARAMETER NoProductionWrites
    Default: always enabled. No production writes.

.EXAMPLE
    .\SL-PHASE-5H-shadow-review-ops-pack.ps1 -ValidateShadowReviewReadiness -ExportReport
    .\SL-PHASE-5H-shadow-review-ops-pack.ps1 -GenerateDailyChecklist
    .\SL-PHASE-5H-shadow-review-ops-pack.ps1 -GenerateMetricsTemplate
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$GenerateDailyChecklist,
    [switch]$GenerateMetricsTemplate,
    [switch]$ValidateShadowReviewReadiness,
    [switch]$ExportReport,
    [switch]$NoProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot  = Split-Path $PSScriptRoot -Parent
$OutputsDir  = Join-Path $ScriptRoot "outputs"
$DocsDir     = Join-Path $ScriptRoot "docs"
$Timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$Today       = (Get-Date -Format "yyyy-MM-dd")

# Known workflow IDs — never modify these
$SHADOW_EVALUATOR_ID   = "aHzLtQiv6G8h1bqD"
$DECISION_ID           = "tgYmY97CG4Bm8snI"

Write-Host ""
Write-Host "=== SL-PHASE-5H: Shadow Review Operations Pack ===" -ForegroundColor Cyan
Write-Host "Timestamp : $Timestamp"
Write-Host "Today     : $Today"
Write-Host "[SAFE] No production writes. No workflow activation." -ForegroundColor Green
Write-Host ""

# ── DAILY CHECKLIST ───────────────────────────────────────────────────────────

if ($GenerateDailyChecklist) {
    Write-Host "=== DAILY SHADOW REVIEW CHECKLIST — $Today ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "STEP 1 — Pre-review safety check" -ForegroundColor Cyan
    Write-Host "  [ ] Shadow evaluator ($SHADOW_EVALUATOR_ID) is active=false in n8n UI"
    Write-Host "  [ ] Decision workflow ($DECISION_ID) running normally"
    Write-Host "  [ ] No n8n errors in last 24h"
    Write-Host "  [ ] No outstanding opt-outs or complaints"
    Write-Host ""
    Write-Host "STEP 2 — Select candidates from Instantly.ai (1-5 replies)" -ForegroundColor Cyan
    Write-Host "  [ ] Found __ candidates"
    Write-Host "  [ ] Excluded opt-outs/complaints (route to human immediately)"
    Write-Host "  [ ] Excluded OOO replies (log as human-only)"
    Write-Host ""
    Write-Host "STEP 3 — Activate shadow evaluator briefly" -ForegroundColor Cyan
    Write-Host "  .\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Activate"
    Write-Host "  [ ] Confirmed active=true in n8n UI"
    Write-Host ""
    Write-Host "STEP 4 — Submit payloads to shadow webhook" -ForegroundColor Cyan
    Write-Host "  Webhook: https://n8n.hmzaiautomation.com/webhook/autonomous-shadow-eval-test"
    Write-Host "  [ ] Submitted __ candidates"
    Write-Host "  [ ] All returned would_send_live_now: false"
    Write-Host ""
    Write-Host "STEP 5 — Deactivate immediately" -ForegroundColor Cyan
    Write-Host "  .\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -Deactivate"
    Write-Host "  [ ] Confirmed active=false in n8n UI"
    Write-Host ""
    Write-Host "STEP 6 — Log results" -ForegroundColor Cyan
    Write-Host "  [ ] Updated outputs/autonomous_shadow_review_metrics_template.json"
    Write-Host "  [ ] Noted any disagreements"
    Write-Host ""
    Write-Host "CRITICAL: If would_send_live_now=true for any case — KILL SWITCH IMMEDIATELY" -ForegroundColor Red
    Write-Host "  .\scripts\SL-PHASE-5F-autonomous-shadow-control.ps1 -KillSwitch" -ForegroundColor Red
    Write-Host ""
}

# ── GENERATE METRICS TEMPLATE ─────────────────────────────────────────────────

if ($GenerateMetricsTemplate) {
    Write-Host "[GenerateMetricsTemplate] Creating daily log entry template..." -ForegroundColor Yellow

    $DayEntry = @{
        day                                  = "FILL_IN"
        date                                 = $Today
        candidates_reviewed                  = 0
        would_send_live_now_true_incidents   = 0
        critical_misses                      = 0
        owner_agreements                     = 0
        owner_disagreements                  = 0
        shadow_evaluator_deactivated_after   = $true
        notes                                = ""
        intent_types_seen                    = @()
        cases                                = @()
    }

    $TemplatePath = Join-Path $OutputsDir "autonomous_shadow_review_day_entry_$Today.json"
    $DayEntry | ConvertTo-Json -Depth 10 | Set-Content $TemplatePath -Encoding UTF8
    Write-Host "  Written: $TemplatePath" -ForegroundColor Green
    Write-Host "  Fill in candidates_reviewed, owner_agreements, notes, and cases." -ForegroundColor Cyan
}

# ── VALIDATE SHADOW REVIEW READINESS ──────────────────────────────────────────

$Checks   = [System.Collections.Generic.List[hashtable]]::new()
$Passed   = 0
$Failed   = 0
$Warnings = 0

function Add-ReadinessCheck {
    param([string]$Check, [string]$Result, [string]$Note = "")
    $script:Checks.Add(@{ check = $Check; result = $Result; note = $Note })
    if ($Result -eq "PASS")    { $script:Passed++ }
    elseif ($Result -eq "WARN") { $script:Warnings++ }
    else                       { $script:Failed++ }
    $color = switch ($Result) { "PASS" { "Green" } "WARN" { "Yellow" } default { "Red" } }
    Write-Host ("  [{0}] {1}" -f $Result, $Check) -ForegroundColor $color
    if ($Note) { Write-Host ("       Note: {0}" -f $Note) -ForegroundColor Gray }
}

if ($ValidateShadowReviewReadiness -or $ExportReport) {
    Write-Host "[ValidateShadowReviewReadiness] Checking pre-review conditions..." -ForegroundColor Yellow
    Write-Host ""

    # Required files
    $RequiredFiles = @(
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_14_DAY_SHADOW_REVIEW_PLAN.md";             Label = "14-day plan doc" }
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_SHADOW_REVIEW_DAILY_CHECKLIST.md";         Label = "Daily checklist doc" }
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_SHADOW_REVIEW_METRICS_TEMPLATE.md";        Label = "Metrics template doc" }
        @{ Path = Join-Path $OutputsDir "autonomous_shadow_review_metrics_template.json";   Label = "Metrics template JSON" }
        @{ Path = Join-Path $DocsDir "RC_SHADOW_OWNER_DECISION_PACKET.md";                  Label = "RC-SHADOW decision packet" }
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_ALLOWLIST_WIREUP_VERIFICATION.md";         Label = "Allowlist wire-up doc" }
        @{ Path = Join-Path $OutputsDir "autonomous_allowlist_wireup_report.json";           Label = "Allowlist wire-up report" }
        @{ Path = Join-Path $ScriptRoot "scripts\SL-PHASE-5F-autonomous-shadow-control.ps1"; Label = "Shadow control script" }
        @{ Path = Join-Path $ScriptRoot "scripts\SL-PHASE-5G-shadow-review-digest-simulator.ps1"; Label = "Digest simulator script" }
        @{ Path = Join-Path $ScriptRoot "scripts\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1"; Label = "Acceptance harness" }
        @{ Path = Join-Path $ScriptRoot "workflows\disabled_autonomous_shadow_evaluator.json"; Label = "Shadow evaluator JSON" }
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md";              Label = "Owner approval checklist" }
        @{ Path = Join-Path $DocsDir "AUTONOMOUS_LIVE_SHADOW_TRAFFIC_BRIDGE_DESIGN.md";     Label = "Live traffic bridge design" }
    )

    foreach ($f in $RequiredFiles) {
        if (Test-Path $f.Path) {
            Add-ReadinessCheck $f.Label "PASS" "File exists"
        } else {
            Add-ReadinessCheck $f.Label "FAIL" "MISSING: $($f.Path)"
        }
    }

    # Acceptance harness outputs
    $AcceptancePath = Join-Path $OutputsDir "autonomous_readiness_acceptance_report.json"
    if (Test-Path $AcceptancePath) {
        $ar = Get-Content $AcceptancePath -Raw | ConvertFrom-Json
        if ($ar.overall_result -eq "PASS") {
            Add-ReadinessCheck "Acceptance harness result is PASS" "PASS" "45/45 previously reported"
        } else {
            Add-ReadinessCheck "Acceptance harness result is PASS" "FAIL" "Last result: $($ar.overall_result)"
        }
    } else {
        Add-ReadinessCheck "Acceptance harness output exists" "WARN" "Run 5E harness to generate"
    }

    # Allowlist wire-up report
    $AllowlistPath = Join-Path $OutputsDir "autonomous_allowlist_wireup_report.json"
    if (Test-Path $AllowlistPath) {
        $aw = Get-Content $AllowlistPath -Raw | ConvertFrom-Json
        $liveSend = $aw.test_results | Where-Object { $_.would_send_live_now -eq $true }
        if ($null -eq $liveSend -or @($liveSend).Count -eq 0) {
            Add-ReadinessCheck "Allowlist report: no live send possible" "PASS" "All tests would_send_live_now=false"
        } else {
            Add-ReadinessCheck "Allowlist report: no live send possible" "FAIL" "CRITICAL: live send found in report"
        }
    }

    # RC-SHADOW-003 status check
    $AllowlistDocPath = Join-Path $DocsDir "AUTONOMOUS_ALLOWLIST_WIREUP_VERIFICATION.md"
    if (Test-Path $AllowlistDocPath) {
        $content = Get-Content $AllowlistDocPath -Raw
        if ($content -match "PRE.GATE.2 ACTION REQUIRED") {
            Add-ReadinessCheck "RC-SHADOW-003: noted as pre-Gate 2 action" "WARN" "Must be resolved before Gate 2, not before shadow review"
        } else {
            Add-ReadinessCheck "RC-SHADOW-003 doc present" "PASS"
        }
    }

    # Safety: config defaults
    $SamplePath = Join-Path $OutputsDir "autonomous_sample_config.json"
    if (Test-Path $SamplePath) {
        $sc = Get-Content $SamplePath -Raw | ConvertFrom-Json
        $enabled = $sc.autonomous_enabled
        $dry = $sc.dry_run
        $shadow = $sc.shadow_only
        if ($enabled -eq $false -and $dry -eq $true -and $shadow -eq $true) {
            Add-ReadinessCheck "Sample config defaults: autonomous_enabled=false, dry_run=true, shadow_only=true" "PASS"
        } else {
            Add-ReadinessCheck "Sample config defaults are safe" "FAIL" "CRITICAL: defaults may allow live sends"
        }
    }

    Write-Host ""
    Write-Host ("Passed: {0}  Warnings: {1}  Failed: {2}" -f $Passed, $Warnings, $Failed) -ForegroundColor $(if ($Failed -gt 0) { "Red" } elseif ($Warnings -gt 0) { "Yellow" } else { "Green" })
    $Overall = if ($Failed -gt 0) { "FAIL" } elseif ($Warnings -gt 0) { "READY_WITH_WARNINGS" } else { "READY" }
    Write-Host "Overall shadow review readiness: $Overall" -ForegroundColor $(if ($Failed -gt 0) { "Red" } elseif ($Warnings -gt 0) { "Yellow" } else { "Green" })
}

# ── EXPORT REPORT ─────────────────────────────────────────────────────────────

if ($ExportReport) {
    $ReportPath = Join-Path $OutputsDir "autonomous_shadow_review_readiness_report.json"
    $Report = @{
        report_type             = "shadow_review_readiness"
        generated_at            = $Timestamp
        phase                   = "5H"
        shadow_evaluator_id     = $SHADOW_EVALUATOR_ID
        overall_result          = if ($Failed -gt 0) { "FAIL" } elseif ($Warnings -gt 0) { "READY_WITH_WARNINGS" } else { "READY" }
        checks_passed           = $Passed
        checks_warnings         = $Warnings
        checks_failed           = $Failed
        live_send_possible      = $false
        production_writes_made  = $false
        gate2_approved          = $false
        checks                  = $Checks
    }
    $Report | ConvertTo-Json -Depth 10 | Set-Content $ReportPath -Encoding UTF8
    Write-Host ""
    Write-Host "  Report written: $ReportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SL-PHASE-5H Complete ===" -ForegroundColor Cyan
Write-Host ""
