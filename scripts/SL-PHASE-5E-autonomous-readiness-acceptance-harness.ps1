#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5E: Autonomous Readiness Acceptance Harness

.DESCRIPTION
    Runs all acceptance tests for the autonomous layer design.
    No production writes. Tests are offline only.

.PARAMETER RunAll
    Run all acceptance test categories.

.PARAMETER RunEligibilityOnly
    Run only eligibility engine tests (Category B).

.PARAMETER RunConfigOnly
    Run only config safety tests (Category A).

.PARAMETER RunDigestOnly
    Run only schema validity tests (Category E).

.PARAMETER RunWorkflowSpecOnly
    Run only workflow safety tests (Category C).

.PARAMETER ExportReport
    Export results to outputs/autonomous_readiness_acceptance_report.json.

.PARAMETER NoProductionWrites
    Default: enabled. No production writes.

.EXAMPLE
    .\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1 -RunAll -ExportReport
#>

[CmdletBinding()]
param(
    [switch]$RunAll,
    [switch]$RunEligibilityOnly,
    [switch]$RunConfigOnly,
    [switch]$RunDigestOnly,
    [switch]$RunWorkflowSpecOnly,
    [switch]$ExportReport,
    [switch]$NoProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot  = Split-Path $PSScriptRoot -Parent
$OutputsDir  = Join-Path $ScriptRoot "outputs"
$DocsDir     = Join-Path $ScriptRoot "docs"
$WorkflowDir = Join-Path $ScriptRoot "workflows"
$Timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5E: Autonomous Readiness Acceptance Harness ===" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp"
Write-Host "[SAFE] No production writes." -ForegroundColor Green
Write-Host ""

$AllResults = [System.Collections.Generic.List[hashtable]]::new()
$TotalPass = 0; $TotalFail = 0

function Assert-Check {
    param([string]$Id, [string]$Test, [bool]$Condition, [string]$Note = "")
    $result = if ($Condition) { "PASS" } else { "FAIL" }
    $script:AllResults.Add(@{ id=$Id; test=$Test; result=$result; note=$Note })
    if ($Condition) { $script:TotalPass++ } else { $script:TotalFail++ }
    $color = if ($Condition) { "Green" } else { "Red" }
    Write-Host ("  [{0}] {1}: {2}" -f $result, $Id, $Test) -ForegroundColor $color
}

function Test-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    try { Get-Content $Path -Raw | ConvertFrom-Json | Out-Null; return $true } catch { return $false }
}

# ── CATEGORY A — CONFIG SAFETY ────────────────────────────────────────────────

if ($RunAll -or $RunConfigOnly) {
    Write-Host "[Category A] Config Safety Tests" -ForegroundColor Yellow
    $samplePath = Join-Path $OutputsDir "autonomous_sample_config.json"
    $schemaPath = Join-Path $OutputsDir "autonomous_config_schema.json"

    $sampleOK = Test-JsonFile $samplePath
    if ($sampleOK) { $sample = Get-Content $samplePath -Raw | ConvertFrom-Json -AsHashtable } else { $sample = @{} }

    Assert-Check "A01" "Sample config autonomous_enabled=false"   ($sampleOK -and $sample["autonomous_enabled"] -eq $false)
    Assert-Check "A02" "Sample config shadow_only=true"           ($sampleOK -and $sample["shadow_only"] -eq $true)
    Assert-Check "A03" "Sample config dry_run=true"               ($sampleOK -and $sample["dry_run"] -eq $true)
    Assert-Check "A04" "Sample config emergency_disabled=true"    ($sampleOK -and $sample["emergency_disabled"] -eq $true)
    Assert-Check "A05" "Sample config campaign_allowlist empty"   ($sampleOK -and @($sample["campaign_allowlist"]).Count -eq 0)
    Assert-Check "A06" "Sample config sender_allowlist empty"     ($sampleOK -and @($sample["sender_allowlist"]).Count -eq 0)
    Assert-Check "A07" "Sample config intent_allowlist empty"     ($sampleOK -and @($sample["intent_allowlist"]).Count -eq 0)
    Assert-Check "A08" "Sample config max_sends_per_day=0"        ($sampleOK -and $sample["max_autonomous_sends_per_day"] -eq 0)
    Assert-Check "A09" "Sample config is valid JSON"              $sampleOK
    Assert-Check "A10" "Config schema exists"                     (Test-Path $schemaPath)
    Write-Host ""
}

# ── CATEGORY B — ELIGIBILITY ENGINE ──────────────────────────────────────────

if ($RunAll -or $RunEligibilityOnly) {
    Write-Host "[Category B] Eligibility Engine Tests" -ForegroundColor Yellow
    $matrixPath = Join-Path $OutputsDir "autonomous_eligibility_decision_matrix.json"
    $summaryPath = Join-Path $OutputsDir "autonomous_eligibility_summary.json"

    $matrixOK = Test-JsonFile $matrixPath
    $summaryOK = Test-JsonFile $summaryPath

    $matrix  = if ($matrixOK) { (Get-Content $matrixPath -Raw | ConvertFrom-Json) } else { $null }
    $summary = if ($summaryOK) { (Get-Content $summaryPath -Raw | ConvertFrom-Json) } else { $null }

    $hardFails  = if ($matrix)  { $matrix.hard_failures } else { 1 }
    $totalScen  = if ($matrix)  { $matrix.total_scenarios } else { 0 }
    $safetyGate = if ($summary) { $summary.safety_gate_result } else { "FAIL" }

    Assert-Check "B01" "All scenarios would_send_live_now=false"  ($hardFails -eq 0)
    Assert-Check "B02" "75+ scenarios evaluated"                  ($totalScen -ge 75)
    Assert-Check "B03" "Safety gate result=PASS in summary"       ($safetyGate -eq "PASS")
    Assert-Check "B04" "Decision matrix is valid JSON"            $matrixOK
    Assert-Check "B05" "Eligibility summary is valid JSON"        $summaryOK

    # Check specific scenarios if matrix available
    if ($matrix -and $matrix.scenarios) {
        $scenarios = $matrix.scenarios
        $unsubCase   = $scenarios | Where-Object { $_.micro_intent -eq "UNSUBSCRIBE" } | Select-Object -First 1
        $pricingCase = $scenarios | Where-Object { $_.micro_intent -eq "PRICING_REQUEST" } | Select-Object -First 1
        $legalCase   = $scenarios | Where-Object { $_.micro_intent -eq "LEGAL_COMPLAINT" } | Select-Object -First 1
        $infoCase    = $scenarios | Where-Object { $_.micro_intent -eq "INFORMATION_REQUEST" -and $_.in_human_working_hours -eq $true } | Select-Object -First 1

        Assert-Check "B06" "UNSUBSCRIBE case: would_send_live_now=false"     (-not $unsubCase -or $unsubCase.would_send_live_now -eq $false) "Permanently blocked"
        Assert-Check "B07" "PRICING_REQUEST case: would_send_live_now=false" (-not $pricingCase -or $pricingCase.would_send_live_now -eq $false)
        Assert-Check "B08" "LEGAL_COMPLAINT case: would_send_live_now=false" (-not $legalCase -or $legalCase.would_send_live_now -eq $false)
        Assert-Check "B09" "INFORMATION_REQUEST in-hours: shadow_eligible"   (-not $infoCase -or $infoCase.would_be_shadow_eligible -eq $true -or $infoCase.confidence -lt 0.85)
    } else {
        Assert-Check "B06" "UNSUBSCRIBE blocked (matrix unavailable)" $false "Run 5C script first"
        Assert-Check "B07" "PRICING_REQUEST blocked (matrix unavailable)" $false "Run 5C script first"
        Assert-Check "B08" "LEGAL_COMPLAINT blocked (matrix unavailable)" $false "Run 5C script first"
        Assert-Check "B09" "INFORMATION_REQUEST shadow eligible (matrix unavailable)" $false "Run 5C script first"
    }
    Write-Host ""
}

# ── CATEGORY C — WORKFLOW SAFETY ─────────────────────────────────────────────

if ($RunAll -or $RunWorkflowSpecOnly) {
    Write-Host "[Category C] Workflow Safety Tests" -ForegroundColor Yellow
    $wfPath = Join-Path $WorkflowDir "disabled_autonomous_shadow_evaluator.json"
    $wfOK = Test-JsonFile $wfPath
    $wf   = if ($wfOK) { Get-Content $wfPath -Raw | ConvertFrom-Json } else { $null }

    Assert-Check "C01" "Disabled workflow exists"                  (Test-Path $wfPath)
    Assert-Check "C02" "Workflow active=false"                     ($wf -and $wf.active -eq $false)
    Assert-Check "C03" "Workflow name contains DISABLED"           ($wf -and $wf.name -like "*DISABLED*")
    Assert-Check "C04" "No Sender node in workflow"                ($wf -and @($wf.nodes | Where-Object { $_.name -like "*sender*" }).Count -eq 0)
    Assert-Check "C05" "No Instantly node in workflow"             ($wf -and @($wf.nodes | Where-Object { $_.name -like "*instantly*" }).Count -eq 0)
    $wfContent = if ($wfOK) { Get-Content $wfPath -Raw } else { "" }
    Assert-Check "C06" "shadow_evaluator_mode marker present"      ($wfContent -like "*shadow_evaluator_mode*")
    Write-Host ""
}

# ── CATEGORY D — DOCUMENT COMPLETENESS ───────────────────────────────────────

if ($RunAll) {
    Write-Host "[Category D] Document Completeness Tests" -ForegroundColor Yellow
    $docs = @(
        @{ id="D01"; test="Kill switch doc exists";                  path="AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md" }
        @{ id="D02"; test="Owner approval checklist exists";         path="AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md" }
        @{ id="D03"; test="Failure modes doc exists";                path="AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md" }
        @{ id="D04"; test="Post-action review spec exists";          path="AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md" }
        @{ id="D05"; test="Follow-up learning spec exists";          path="AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md" }
        @{ id="D06"; test="Daily digest spec exists";                path="AUTONOMOUS_DAILY_DIGEST_SPEC.md" }
        @{ id="D07"; test="Audit trail spec exists";                 path="AUTONOMOUS_AUDIT_TRAIL_SPEC.md" }
        @{ id="D08"; test="Shadow candidate logging spec exists";    path="AUTONOMOUS_SHADOW_CANDIDATE_LOGGING_SPEC.md" }
        @{ id="D09"; test="Go/no-go checklist exists";               path="AUTONOMOUS_GO_NO_GO_CHECKLIST.md" }
        @{ id="D10"; test="Architecture doc exists";                 path="AUTONOMOUS_PHASE_5_ARCHITECTURE.md" }
        @{ id="D11"; test="System boundaries doc exists";            path="AUTONOMOUS_SYSTEM_BOUNDARIES.md" }
        @{ id="D12"; test="Safety model doc exists";                 path="AUTONOMOUS_SAFETY_MODEL.md" }
    )
    foreach ($d in $docs) {
        $docPath = Join-Path $DocsDir $d.path
        Assert-Check $d.id $d.test (Test-Path $docPath)
    }
    Write-Host ""
}

# ── CATEGORY E — SCHEMA VALIDITY ─────────────────────────────────────────────

if ($RunAll -or $RunDigestOnly) {
    Write-Host "[Category E] Schema Validity Tests" -ForegroundColor Yellow
    $schemas = @(
        @{ id="E01"; test="Config schema valid JSON";           path=(Join-Path $OutputsDir "autonomous_config_schema.json") }
        @{ id="E02"; test="Sample config valid JSON";           path=(Join-Path $OutputsDir "autonomous_sample_config.json") }
        @{ id="E03"; test="Shadow log schema valid JSON";       path=(Join-Path $OutputsDir "autonomous_shadow_log_schema.json") }
        @{ id="E04"; test="Daily digest sample valid JSON";     path=(Join-Path $OutputsDir "autonomous_daily_digest_sample.json") }
        @{ id="E05"; test="Review queue sample valid JSON";     path=(Join-Path $OutputsDir "autonomous_review_queue_sample.json") }
        @{ id="E06"; test="Eligibility decision matrix valid";  path=(Join-Path $OutputsDir "autonomous_eligibility_decision_matrix.json") }
        @{ id="E07"; test="Eligibility summary valid JSON";     path=(Join-Path $OutputsDir "autonomous_eligibility_summary.json") }
        @{ id="E08"; test="Config validation report valid";     path=(Join-Path $OutputsDir "autonomous_config_validation_report.json") }
    )
    foreach ($s in $schemas) {
        Assert-Check $s.id $s.test (Test-JsonFile $s.path)
    }
    Write-Host ""
}

# ── SUMMARY ──────────────────────────────────────────────────────────────────

$overall = if ($TotalFail -eq 0) { "PASS" } else { "FAIL" }
$totalTests = $TotalPass + $TotalFail

$overallColor  = if ($overall -eq "PASS")  { "Green" } else { "Red" }
$passedColor   = if ($overall -eq "PASS")  { "Green" } else { "Yellow" }
$failedColor   = if ($TotalFail -eq 0) { "Green" } else { "Red" }
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "ACCEPTANCE HARNESS RESULT: $overall" -ForegroundColor $overallColor
Write-Host "Passed: $TotalPass / $totalTests" -ForegroundColor $passedColor
Write-Host "Failed: $TotalFail / $totalTests" -ForegroundColor $failedColor
Write-Host ""

if ($ExportReport) {
    $Report = @{
        generated            = $Timestamp
        script               = "SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1"
        overall_result       = $overall
        total_tests          = $totalTests
        passed               = $TotalPass
        failed               = $TotalFail
        production_writes    = $false
        live_autonomy_possible = $false
        tests                = $AllResults
    }
    $ReportPath = Join-Path $OutputsDir "autonomous_readiness_acceptance_report.json"
    $Report | ConvertTo-Json -Depth 10 | Set-Content $ReportPath -Encoding UTF8
    Write-Host "[ExportReport] Written: $ReportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SL-PHASE-5E Complete ===" -ForegroundColor Cyan
Write-Host ""

if ($TotalFail -gt 0) { exit 1 }
