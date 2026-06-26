#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5I: Manual Shadow Review Helper for 14-day shadow review period.

.DESCRIPTION
    Helps the owner run the 14-day shadow review without guesswork.
    Takes a real inbound reply, helps construct a safe shadow payload,
    records the system decision, and tracks whether the decision was correct.
    No production writes. No activation. No live sends.

.PARAMETER GeneratePayloadTemplate
    Output a blank payload template for a new inbound reply.

.PARAMETER CreateDailyReviewSheet
    Create a fresh daily review sheet for today.

.PARAMETER ValidateManualPayload
    Validate a manually constructed payload JSON file before submission.
    Pass -PayloadFile <path>

.PARAMETER AppendShadowReviewResult
    Append a completed review result to the daily shadow review log.
    Pass -PayloadFile <path> (with result fields filled in)

.PARAMETER ExportDailySummary
    Export a summary of today's shadow review results.

.PARAMETER NoProductionWrites
    Default: enabled. Never writes to production systems.

.PARAMETER PayloadFile
    Path to a JSON payload file (used with -ValidateManualPayload and -AppendShadowReviewResult).

.PARAMETER Day
    Review day number (1-14). Defaults to today's day in cycle.

.EXAMPLE
    .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate
    .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day 1
    .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile outputs\my_payload.json
    .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -AppendShadowReviewResult -PayloadFile outputs\my_result.json
    .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ExportDailySummary
#>

[CmdletBinding()]
param(
    [switch]$GeneratePayloadTemplate,
    [switch]$CreateDailyReviewSheet,
    [switch]$ValidateManualPayload,
    [switch]$AppendShadowReviewResult,
    [switch]$ExportDailySummary,
    [switch]$NoProductionWrites = $true,
    [string]$PayloadFile = "",
    [int]$Day = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot  = Split-Path $PSScriptRoot -Parent
$OutputsDir  = Join-Path $ScriptRoot "outputs"
$DocsDir     = Join-Path $ScriptRoot "docs"
$Timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$DateStamp   = (Get-Date -Format "yyyy-MM-dd")
$CycleDay    = if ($Day -gt 0) { $Day } else { 1 }

$ReviewLogPath    = Join-Path $OutputsDir "autonomous_shadow_review_log.json"
$DailySheetDir    = Join-Path $OutputsDir "shadow_review_days"

Write-Host ""
Write-Host "=== SL-PHASE-5I: Manual Shadow Review Helper ===" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp"
Write-Host "[SAFE] No production writes. No activation. No live sends." -ForegroundColor Green
Write-Host ""

# Ensure output dirs exist
if (-not (Test-Path $DailySheetDir)) { New-Item -ItemType Directory -Path $DailySheetDir | Out-Null }

# ── GENERATE PAYLOAD TEMPLATE ─────────────────────────────────────────────────
if ($GeneratePayloadTemplate) {
    Write-Host "[GeneratePayloadTemplate] Creating blank shadow payload template..." -ForegroundColor Yellow
    Write-Host ""

    $Template = [ordered]@{
        "_instructions" = @(
            "1. Fill in all fields from the real inbound reply.",
            "2. Use micro_intent from the Decision workflow output (NOT your own guess).",
            "3. Use confidence from the Decision workflow output.",
            "4. Leave case_id as a unique value (e.g. case_YYYYMMDD_001).",
            "5. Set in_human_working_hours based on when the reply arrived.",
            "6. Do NOT submit if incoming_text contains PII beyond a first name.",
            "7. Run -ValidateManualPayload before submitting."
        )
        case_id            = "case_YYYYMMDD_001"
        thread_id          = "thread_XXXX"
        campaign_id        = "CAMP_XXXX"
        sender_email       = "sender@yourdomain.com"
        incoming_text      = "[Paste reply text here — remove PII except first name]"
        broad_category     = "[From Decision output — e.g. SCHEDULING_POSITIVE]"
        micro_intent       = "[From Decision output — e.g. SCHEDULING_REQUEST]"
        confidence         = 0.0
        additional_intents = @()
        risk_flags         = @()
        in_human_working_hours = $false
        review_metadata    = [ordered]@{
            review_date         = $DateStamp
            review_day_in_cycle = $CycleDay
            owner_notes         = "[Optional: any observations about this reply]"
        }
    }

    $OutPath = Join-Path $OutputsDir "autonomous_manual_shadow_payload_template.json"
    $Template | ConvertTo-Json -Depth 10 | Set-Content -Path $OutPath -Encoding UTF8
    Write-Host "  [CREATED] $OutPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "  HOW TO USE:" -ForegroundColor White
    Write-Host "  1. Open: $OutPath" -ForegroundColor Gray
    Write-Host "  2. Fill in the fields from a real inbound reply and its Decision output" -ForegroundColor Gray
    Write-Host "  3. Run: .\SL-PHASE-5I-manual-shadow-review-helper.ps1 -ValidateManualPayload -PayloadFile <path>" -ForegroundColor Gray
    Write-Host "  4. Submit the validated payload to the shadow evaluator webhook (if workflow is active)" -ForegroundColor Gray
    Write-Host "  5. Record the result using -AppendShadowReviewResult" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# ── CREATE DAILY REVIEW SHEET ─────────────────────────────────────────────────
if ($CreateDailyReviewSheet) {
    Write-Host "[CreateDailyReviewSheet] Creating Day $CycleDay review sheet..." -ForegroundColor Yellow
    Write-Host ""

    $Sheet = [ordered]@{
        review_date         = $DateStamp
        review_day_in_cycle = $CycleDay
        reviewer            = "owner"
        cases_reviewed      = 0
        cases_blocked_correct = 0
        cases_shadow_eligible_correct = 0
        cases_incorrect     = 0
        notes               = ""
        checklist           = @(
            @{ item="Check shadow evaluator is active=false"; done=$false }
            @{ item="Pull 1-3 real inbound replies from Instantly.ai"; done=$false }
            @{ item="For each reply: copy Decision output fields (micro_intent, confidence, broad_category)"; done=$false }
            @{ item="Run GeneratePayloadTemplate, fill in fields, validate each payload"; done=$false }
            @{ item="For each payload: record what the shadow evaluator would decide"; done=$false }
            @{ item="For each case: record your own assessment (should it have been blocked/eligible?)"; done=$false }
            @{ item="For any disagreement: log in learning_signals array below"; done=$false }
            @{ item="Export daily summary at end of session"; done=$false }
        )
        cases              = @()
        learning_signals   = @()
        metrics            = [ordered]@{
            total_shadow_eligible     = 0
            total_blocked_permanent   = 0
            total_blocked_allowlist   = 0
            total_human_review        = 0
            false_positive_count      = 0
            false_negative_count      = 0
            owner_override_count      = 0
        }
    }

    $SheetPath = Join-Path $DailySheetDir "shadow_review_day_${CycleDay}_${DateStamp}.json"
    $Sheet | ConvertTo-Json -Depth 10 | Set-Content -Path $SheetPath -Encoding UTF8
    Write-Host "  [CREATED] $SheetPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "  DAILY CHECKLIST:" -ForegroundColor White
    foreach ($item in $Sheet.checklist) {
        Write-Host "    [ ] $($item.item)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  Fill in cases[] array with each payload result." -ForegroundColor Gray
    Write-Host "  Then run -ExportDailySummary to compile the day's metrics." -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# ── VALIDATE MANUAL PAYLOAD ───────────────────────────────────────────────────
if ($ValidateManualPayload) {
    if (-not $PayloadFile) { throw "Specify -PayloadFile <path>" }
    if (-not (Test-Path $PayloadFile)) { throw "File not found: $PayloadFile" }
    Write-Host "[ValidateManualPayload] Validating: $PayloadFile" -ForegroundColor Yellow
    Write-Host ""

    $P = Get-Content $PayloadFile -Raw | ConvertFrom-Json

    $Required = @("case_id","thread_id","campaign_id","sender_email","incoming_text",
                  "broad_category","micro_intent","confidence")
    $Missing = @($Required | Where-Object { -not ($P.PSObject.Properties.Name -contains $_) -or
                                            [string]::IsNullOrEmpty($P.$_) })

    $Errors = [System.Collections.Generic.List[string]]::new()
    if ($Missing.Count -gt 0) { $Errors.Add("Missing required fields: " + ($Missing -join ", ")) }
    if ($P.confidence -lt 0 -or $P.confidence -gt 1) { $Errors.Add("confidence must be 0.0–1.0") }
    if ($P.case_id -match "YYYY") { $Errors.Add("case_id still has placeholder 'YYYY' — set a real value") }
    if ($P.incoming_text -match "Paste reply text") { $Errors.Add("incoming_text still has placeholder text") }
    if ($P.broad_category -match "^\[") { $Errors.Add("broad_category still has placeholder value") }
    if ($P.micro_intent -match "^\[") { $Errors.Add("micro_intent still has placeholder value") }

    # PII check
    $PiiPatterns = @('\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b', '\b\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4}\b',
                     '\b\d{3}-\d{2}-\d{4}\b')
    foreach ($pat in $PiiPatterns) {
        if ($P.incoming_text -match $pat) {
            $Errors.Add("incoming_text may contain PII — phone/card/SSN pattern detected. Remove PII before submitting.")
        }
    }

    if ($Errors.Count -gt 0) {
        Write-Host "  [INVALID] Payload validation FAILED:" -ForegroundColor Red
        foreach ($e in $Errors) { Write-Host "    - $e" -ForegroundColor Red }
        exit 1
    }

    Write-Host "  [VALID] Payload passes all validation checks." -ForegroundColor Green
    Write-Host "  case_id:      $($P.case_id)" -ForegroundColor Gray
    Write-Host "  micro_intent: $($P.micro_intent)" -ForegroundColor Gray
    Write-Host "  confidence:   $($P.confidence)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Ready to submit to shadow evaluator webhook (if active) or record manually." -ForegroundColor White
    Write-Host ""
    exit 0
}

# ── APPEND SHADOW REVIEW RESULT ───────────────────────────────────────────────
if ($AppendShadowReviewResult) {
    if (-not $PayloadFile) { throw "Specify -PayloadFile <path> (the result JSON with filled-in outcome fields)" }
    if (-not (Test-Path $PayloadFile)) { throw "File not found: $PayloadFile" }
    Write-Host "[AppendShadowReviewResult] Appending result from: $PayloadFile" -ForegroundColor Yellow

    $Result = Get-Content $PayloadFile -Raw | ConvertFrom-Json

    # Load or create log
    $Log = if (Test-Path $ReviewLogPath) {
        Get-Content $ReviewLogPath -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{ generated=$Timestamp; entries=@() }
    }

    $Entry = @{
        appended_at         = $Timestamp
        case_id             = $Result.case_id
        micro_intent        = $Result.micro_intent
        confidence          = $Result.confidence
        shadow_decision     = $Result.shadow_decision
        owner_assessment    = $Result.owner_assessment
        was_correct         = $Result.was_correct
        should_have_blocked = $Result.should_have_blocked
        learning_signal     = $Result.learning_signal
        owner_notes         = $Result.owner_notes
    }

    $Log.entries = @($Log.entries) + @($Entry)
    $Log | ConvertTo-Json -Depth 10 | Set-Content -Path $ReviewLogPath -Encoding UTF8
    Write-Host "  [APPENDED] $ReviewLogPath (total entries: $(@($Log.entries).Count))" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ── EXPORT DAILY SUMMARY ──────────────────────────────────────────────────────
if ($ExportDailySummary) {
    Write-Host "[ExportDailySummary] Compiling daily summary for Day $CycleDay ($DateStamp)..." -ForegroundColor Yellow
    Write-Host ""

    # Find today's day sheet
    $DaySheets = @(Get-ChildItem -Path $DailySheetDir -Filter "shadow_review_day_${CycleDay}_*.json" -ErrorAction SilentlyContinue)
    $LogEntries = if (Test-Path $ReviewLogPath) {
        @((Get-Content $ReviewLogPath -Raw | ConvertFrom-Json).entries)
    } else { @() }

    # Filter today's entries
    $TodayEntries = @($LogEntries | Where-Object { $_.appended_at -like "$DateStamp*" })

    $Summary = [ordered]@{
        summary_date        = $DateStamp
        review_day          = $CycleDay
        generated           = $Timestamp
        cases_in_log        = @($TodayEntries).Count
        correct_decisions   = @($TodayEntries | Where-Object { $_.was_correct -eq $true }).Count
        incorrect_decisions = @($TodayEntries | Where-Object { $_.was_correct -eq $false }).Count
        learning_signals    = @($TodayEntries | Where-Object { $_.learning_signal -ne "" -and $null -ne $_.learning_signal }) | ForEach-Object { $_.learning_signal }
        notes               = "Day $CycleDay shadow review complete. Review log at: $ReviewLogPath"
        day_sheet_files     = $DaySheets | ForEach-Object { $_.FullName }
    }

    $SummaryPath = Join-Path $OutputsDir "autonomous_shadow_review_day_${CycleDay}_summary.json"
    $Summary | ConvertTo-Json -Depth 10 | Set-Content -Path $SummaryPath -Encoding UTF8
    Write-Host "  [EXPORTED] $SummaryPath" -ForegroundColor Green
    Write-Host "  Cases reviewed today:  $($Summary.cases_in_log)" -ForegroundColor White
    Write-Host "  Correct decisions:     $($Summary.correct_decisions)" -ForegroundColor Green
    Write-Host "  Incorrect decisions:   $($Summary.incorrect_decisions)" -ForegroundColor $(if ($Summary.incorrect_decisions -gt 0) { "Yellow" } else { "Green" })
    if (@($Summary.learning_signals).Count -gt 0) {
        Write-Host "  Learning signals:      $(@($Summary.learning_signals).Count)" -ForegroundColor Yellow
        foreach ($ls in @($Summary.learning_signals)) { Write-Host "    - $ls" -ForegroundColor Gray }
    }
    Write-Host ""
    exit 0
}

Write-Host "Specify one of: -GeneratePayloadTemplate, -CreateDailyReviewSheet, -ValidateManualPayload, -AppendShadowReviewResult, -ExportDailySummary" -ForegroundColor Yellow
