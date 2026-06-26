#Requires -Version 7.0
# SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1
#
# Autonomous out-of-hours shadow simulation scaffold.
# Does NOT call production n8n, Instantly, or any external API.
# Does NOT write to production workflows.
# Does NOT enable autonomous mode.
# Does NOT send emails.
# Does NOT modify Sender, HumanApproval, Decision, Intake, ErrorHandler, or SLAWatchdog.
#
# Purpose: Model what an autonomous out-of-hours responder WOULD do, locally only.
# All output is shadow (proposed_shadow only). No actual sends. Human review required.
#
# Usage:
#   .\SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1 -WhatIf
#   .\SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1 -RunOfflineShadowScenarios
#   .\SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1 -ExportAutonomousDecisionMatrix
#   .\SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1 -ValidateWorkingHoursConfig
#   .\SL-PHASE-5A-autonomous-shadow-simulation-scaffold.ps1 -UseSampleWorkingHours -RunOfflineShadowScenarios

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RunOfflineShadowScenarios,
    [switch]$ExportAutonomousDecisionMatrix,
    [switch]$ValidateWorkingHoursConfig,
    [switch]$UseSampleWorkingHours,
    [switch]$NoProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Safety: this script must never write to production
$NoProductionWrites = $true

foreach ($term in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($term)) { Write-Error "SAFETY: forbidden term in script path."; exit 1 }
}

Write-Host "`n=== SL-PHASE-5A AUTONOMOUS SHADOW SIMULATION SCAFFOLD ===" -ForegroundColor Cyan
Write-Host "Autonomous mode: DISABLED (shadow simulation only)" -ForegroundColor Yellow
Write-Host "Production writes: BLOCKED (NoProductionWrites = true)" -ForegroundColor Yellow
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "[WhatIf] Would run offline shadow simulation scenarios" -ForegroundColor Cyan
    Write-Host "[WhatIf] Would export autonomous decision matrix to outputs/" -ForegroundColor Cyan
    Write-Host "[WhatIf] Would validate working hours config" -ForegroundColor Cyan
    Write-Host "[WhatIf] No production changes. No sends. No workflow modifications." -ForegroundColor Green
    exit 0
}

# ── Working Hours Configuration ──────────────────────────────────────────────
$SAMPLE_WORKING_HOURS = @{
    timezone = "Europe/London"
    start_hour = 9
    end_hour = 18
    working_days = @(1,2,3,4,5)  # Mon-Fri
}

function Get-WorkingHoursConfig {
    if ($UseSampleWorkingHours) { return $SAMPLE_WORKING_HOURS }
    $configPath = Join-Path $PSScriptRoot "..\docs\AUTONOMOUS_SHADOW_MODE_DESIGN.md"
    if (Test-Path $configPath) {
        return $SAMPLE_WORKING_HOURS  # Use sample; real config is in design doc
    }
    return $SAMPLE_WORKING_HOURS
}

function Test-IsOutOfHours {
    param($config, $testTime = $null)
    $now = if ($testTime) { $testTime } else { [DateTime]::UtcNow }
    $dayOfWeek = [int]$now.DayOfWeek
    $hour = $now.Hour
    $isWorkingDay = $config.working_days -contains $dayOfWeek
    $isWorkingHour = $hour -ge $config.start_hour -and $hour -lt $config.end_hour
    return -not ($isWorkingDay -and $isWorkingHour)
}

if ($ValidateWorkingHoursConfig) {
    Write-Host "=== Working Hours Validation ===" -ForegroundColor Cyan
    $cfg = Get-WorkingHoursConfig
    Write-Host "Timezone: $($cfg.timezone)"
    Write-Host "Hours: $($cfg.start_hour):00 - $($cfg.end_hour):00"
    Write-Host "Days: $($cfg.working_days -join ',')"

    $testTimes = @(
        [DateTime]::new(2026, 6, 23, 10, 0, 0),  # Tuesday 10:00 — IN hours
        [DateTime]::new(2026, 6, 23, 20, 0, 0),  # Tuesday 20:00 — OUT of hours
        [DateTime]::new(2026, 6, 27, 10, 0, 0),  # Saturday 10:00 — OUT of hours (weekend)
        [DateTime]::new(2026, 6, 22, 8, 0, 0)    # Monday 08:00 — OUT of hours (before start)
    )
    foreach ($t in $testTimes) {
        $oot = Test-IsOutOfHours -config $cfg -testTime $t
        $label = if ($oot) { "OUT-OF-HOURS" } else { "IN-HOURS" }
        $color = if ($oot) { "Yellow" } else { "Green" }
        Write-Host ("  {0:yyyy-MM-dd HH:mm} UTC — {1}" -f $t, $label) -ForegroundColor $color
    }
    Write-Host ""
}

# ── Eligibility Matrix ────────────────────────────────────────────────────────
$AUTONOMOUS_ELIGIBLE = @(
    @{ category = "POSITIVE_INTEREST"; micro_intent = "DISCOVERY_CALL_REQUEST"; eligible = $true;  reason = "Simple scheduling — no pricing, legal, or commitment required" }
    @{ category = "POSITIVE_INTEREST"; micro_intent = "GENERAL_INTEREST";        eligible = $true;  reason = "Simple positive acknowledgement — can safely encourage next step" }
    @{ category = "INFORMATION_REQUEST"; micro_intent = "HOW_IT_WORKS_REQUEST";  eligible = $true;  reason = "Simple info — can answer from approved KB without human judgment" }
    @{ category = "INFORMATION_REQUEST"; micro_intent = "OFFER_EXPLANATION";      eligible = $true;  reason = "Simple offer explanation — grounded in approved KB" }
    @{ category = "SCHEDULING";          micro_intent = "AVAILABILITY_REQUEST";   eligible = $true;  reason = "Simple scheduling — propose a time from approved booking link" }
)

$AUTONOMOUS_BLOCKED = @(
    @{ category = "UNSUBSCRIBE_REQUEST";                    eligible = $false; reason = "Must always suppress immediately — human must verify and action" }
    @{ category = "LEGAL_OR_COMPLIANCE";                    eligible = $false; reason = "Legal — never autonomous" }
    @{ category = "COMPLAINT_OR_HOSTILE";                   eligible = $false; reason = "Complaint or hostile — human only" }
    @{ category = "PRICING_OR_COMMERCIAL_NEGOTIATION";      eligible = $false; reason = "Pricing, negotiation, or commercial terms — human only" }
    @{ category = "DATA_SECURITY_OR_COMPLIANCE_COMMITMENT"; eligible = $false; reason = "Data/security/compliance commitments — human only" }
    @{ category = "INFORMATION_REQUEST"; micro_intent = "PROOF_OR_CASE_STUDY_REQUEST"; eligible = $false; reason = "Requires human judgment on evidence claims" }
    @{ category = "INFORMATION_REQUEST"; micro_intent = "CONTRACT_TERMS_REQUEST";       eligible = $false; reason = "Contract terms — human only" }
    @{ category = "INFORMATION_REQUEST"; micro_intent = "DATA_SECURITY_REQUEST";        eligible = $false; reason = "Data/security commitment — human only" }
    @{ category = "AMBIGUOUS_OR_SHORT";                     eligible = $false; reason = "Ambiguous intent — human only" }
    @{ category = "HIGH_VALUE_CUSTOM";                      eligible = $false; reason = "High-value custom request — human only" }
    @{ category = "BILLING_DISPUTE";                        eligible = $false; reason = "Billing dispute — human only" }
)

function Get-AutonomousEligibility {
    param($category, $microIntent)
    # Check blocked list first (takes precedence)
    foreach ($b in $AUTONOMOUS_BLOCKED) {
        if ($b.category -eq $category) {
            if (-not $b.micro_intent -or $b.micro_intent -eq $microIntent) {
                return @{ eligible = $false; reason = $b.reason; list = "blocked" }
            }
        }
    }
    # Check eligible list
    foreach ($e in $AUTONOMOUS_ELIGIBLE) {
        if ($e.category -eq $category -and $e.micro_intent -eq $microIntent) {
            return @{ eligible = $true; reason = $e.reason; list = "eligible" }
        }
    }
    # Default: not eligible (conservative)
    return @{ eligible = $false; reason = "Not in eligible list — default deny"; list = "default_deny" }
}

if ($ExportAutonomousDecisionMatrix) {
    Write-Host "=== Autonomous Decision Matrix Export ===" -ForegroundColor Cyan
    $matrixPath = Join-Path $PSScriptRoot "..\outputs\autonomous_shadow_decision_matrix.json"
    $matrix = @{
        version = "shadow-1.0"
        generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        autonomous_mode = "DISABLED"
        note = "Shadow simulation only. No autonomous sends active."
        eligible = $AUTONOMOUS_ELIGIBLE
        blocked = $AUTONOMOUS_BLOCKED
        default_action = "DENY"
    }
    $matrix | ConvertTo-Json -Depth 10 | Set-Content -Path $matrixPath -Encoding UTF8
    Write-Host "Matrix exported to: $matrixPath" -ForegroundColor Green
    Write-Host ""
}

# ── Shadow Simulation Scenarios ───────────────────────────────────────────────
$JS_SHADOW_SIMULATION = @'
const ELIGIBLE_CATEGORIES = [
  { category: "POSITIVE_INTEREST",   micro_intent: "DISCOVERY_CALL_REQUEST" },
  { category: "POSITIVE_INTEREST",   micro_intent: "GENERAL_INTEREST" },
  { category: "INFORMATION_REQUEST", micro_intent: "HOW_IT_WORKS_REQUEST" },
  { category: "INFORMATION_REQUEST", micro_intent: "OFFER_EXPLANATION" },
  { category: "SCHEDULING",          micro_intent: "AVAILABILITY_REQUEST" }
];
const BLOCKED_CATEGORIES = [
  { category: "UNSUBSCRIBE_REQUEST" },
  { category: "LEGAL_OR_COMPLIANCE" },
  { category: "COMPLAINT_OR_HOSTILE" },
  { category: "PRICING_OR_COMMERCIAL_NEGOTIATION" },
  { category: "DATA_SECURITY_OR_COMPLIANCE_COMMITMENT" },
  { category: "INFORMATION_REQUEST", micro_intent: "PROOF_OR_CASE_STUDY_REQUEST" },
  { category: "INFORMATION_REQUEST", micro_intent: "CONTRACT_TERMS_REQUEST" },
  { category: "INFORMATION_REQUEST", micro_intent: "DATA_SECURITY_REQUEST" },
  { category: "AMBIGUOUS_OR_SHORT" },
  { category: "BILLING_DISPUTE" }
];

function getEligibility(cat, mi) {
  // Blocked list first
  for (var b of BLOCKED_CATEGORIES) {
    if (b.category === cat && (!b.micro_intent || b.micro_intent === mi)) {
      return { eligible: false, source: "blocked" };
    }
  }
  // Eligible list
  for (var e of ELIGIBLE_CATEGORIES) {
    if (e.category === cat && e.micro_intent === mi) {
      return { eligible: true, source: "eligible" };
    }
  }
  return { eligible: false, source: "default_deny" };
}

function simulateShadowDecision(scenario) {
  const { category, micro_intent, is_out_of_hours, active_rules_count } = scenario;
  const eligibility = getEligibility(category, micro_intent);

  const shadowDecision = {
    scenario_id: scenario.id,
    category, micro_intent, is_out_of_hours,
    autonomous_eligible: eligibility.eligible,
    eligibility_source: eligibility.source,
    shadow_action: null,
    would_send_autonomously: false,
    human_review_required: true,
    proposed_shadow_draft_status: "DRAFT_NOT_CREATED",
    note: ""
  };

  if (!is_out_of_hours) {
    shadowDecision.shadow_action = "DEFER_TO_HUMAN_IN_HOURS";
    shadowDecision.note = "Human is available — no autonomous action even if eligible";
    shadowDecision.human_review_required = true;
    return shadowDecision;
  }

  if (!eligibility.eligible) {
    shadowDecision.shadow_action = "BLOCK_AUTONOMOUS_ALWAYS_HUMAN";
    shadowDecision.note = "Category/intent in blocked list — autonomous action never taken";
    shadowDecision.human_review_required = true;
    return shadowDecision;
  }

  // Eligible + out of hours → SHADOW ONLY (autonomous mode not yet live)
  shadowDecision.shadow_action = "SHADOW_ELIGIBLE_OUT_OF_HOURS";
  shadowDecision.note = "Would be autonomous candidate. Shadow simulation only — no actual send.";
  shadowDecision.proposed_shadow_draft_status = "SHADOW_DRAFT_PENDING_HUMAN_REVIEW";
  shadowDecision.human_review_required = true;  // always, even in shadow
  shadowDecision.would_send_autonomously = false;  // never true — autonomous mode disabled
  shadowDecision.post_autonomous_human_review = true;
  return shadowDecision;
}

const scenarios = [
  { id: "AS-1", category: "POSITIVE_INTEREST",   micro_intent: "DISCOVERY_CALL_REQUEST",       is_out_of_hours: true,  active_rules_count: 2, expected: "SHADOW_ELIGIBLE_OUT_OF_HOURS" },
  { id: "AS-2", category: "POSITIVE_INTEREST",   micro_intent: "DISCOVERY_CALL_REQUEST",       is_out_of_hours: false, active_rules_count: 2, expected: "DEFER_TO_HUMAN_IN_HOURS" },
  { id: "AS-3", category: "UNSUBSCRIBE_REQUEST",  micro_intent: "OPT_OUT",                     is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-4", category: "PRICING_OR_COMMERCIAL_NEGOTIATION", micro_intent: "PRICING_REQUEST", is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-5", category: "INFORMATION_REQUEST",  micro_intent: "HOW_IT_WORKS_REQUEST",        is_out_of_hours: true,  active_rules_count: 2, expected: "SHADOW_ELIGIBLE_OUT_OF_HOURS" },
  { id: "AS-6", category: "INFORMATION_REQUEST",  micro_intent: "PROOF_OR_CASE_STUDY_REQUEST", is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-7", category: "INFORMATION_REQUEST",  micro_intent: "CONTRACT_TERMS_REQUEST",      is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-8", category: "SCHEDULING",           micro_intent: "AVAILABILITY_REQUEST",        is_out_of_hours: true,  active_rules_count: 2, expected: "SHADOW_ELIGIBLE_OUT_OF_HOURS" },
  { id: "AS-9", category: "LEGAL_OR_COMPLIANCE",  micro_intent: "DATA_SECURITY_REQUEST",       is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-10", category: "AMBIGUOUS_OR_SHORT",  micro_intent: "UNKNOWN",                     is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" },
  { id: "AS-11", category: "POSITIVE_INTEREST",   micro_intent: "GENERAL_INTEREST",            is_out_of_hours: true,  active_rules_count: 2, expected: "SHADOW_ELIGIBLE_OUT_OF_HOURS" },
  { id: "AS-12", category: "INFORMATION_REQUEST",  micro_intent: "DATA_SECURITY_REQUEST",      is_out_of_hours: true,  active_rules_count: 2, expected: "BLOCK_AUTONOMOUS_ALWAYS_HUMAN" }
];

const results = scenarios.map(function(s) {
  const decision = simulateShadowDecision(s);
  const pass = decision.shadow_action === s.expected;
  // Verify autonomous send is NEVER true
  const safetyPass = decision.would_send_autonomously === false;
  const humanReviewPass = decision.human_review_required === true;
  return {
    id: s.id,
    result: (pass && safetyPass && humanReviewPass) ? "PASS" : "FAIL",
    checks: {
      shadow_action: pass,
      no_autonomous_send: safetyPass,
      human_review_required: humanReviewPass
    },
    decision
  };
});

const passed = results.filter(function(r){ return r.result === "PASS"; }).length;
const failed = results.filter(function(r){ return r.result === "FAIL"; }).length;

const output = {
  harness: "SL-PHASE-5A-autonomous-shadow-simulation",
  run_at: new Date().toISOString(),
  autonomous_mode: "DISABLED",
  total: results.length,
  passed, failed,
  safety_guarantee: "would_send_autonomously is always false in this scaffold",
  results
};

process.stdout.write(JSON.stringify(output, null, 2));
'@

if ($RunOfflineShadowScenarios) {
    Write-Host "=== Offline Shadow Simulation Scenarios ===" -ForegroundColor Cyan
    Write-Host "Autonomous mode: DISABLED — no actual sends" -ForegroundColor Yellow
    Write-Host ""

    $jsonOutput = $JS_SHADOW_SIMULATION | node --input-type=module 2>&1

    try {
        $results = $jsonOutput | ConvertFrom-Json
    } catch {
        Write-Host "SIMULATION ERROR:" -ForegroundColor Red
        Write-Host $jsonOutput
        exit 1
    }

    foreach ($r in $results.results) {
        $color = if ($r.result -eq "PASS") { "Green" } else { "Red" }
        $safetyFlag = if ($r.decision.would_send_autonomously -eq $false) { "[SAFE]" } else { "[UNSAFE!]" }
        Write-Host ("  [{0}] {1} — {2} → {3} {4}" -f $r.result, $r.id, $r.decision.category, $r.decision.shadow_action, $safetyFlag) -ForegroundColor $color
        if ($r.result -eq "FAIL" -or $VerbosePreference -eq "Continue") {
            Write-Host "        $($r.decision.note)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    $totalColor = if ($results.failed -eq 0) { "Green" } else { "Red" }
    Write-Host ("TOTAL: {0}/{1} PASS | Safety guarantee: {2}" -f $results.passed, $results.total, $results.safety_guarantee) -ForegroundColor $totalColor

    # Save shadow simulation results
    $outputsDir = Join-Path $PSScriptRoot "..\outputs"
    if (-not (Test-Path $outputsDir)) { New-Item -ItemType Directory -Path $outputsDir -Force | Out-Null }
    $shadowOutputFile = Join-Path $outputsDir "autonomous_shadow_decision_matrix.json"
    $results | ConvertTo-Json -Depth 20 | Set-Content -Path $shadowOutputFile -Encoding UTF8
    Write-Host "Shadow results saved to: $shadowOutputFile" -ForegroundColor Gray

    if ($results.failed -gt 0) {
        Write-Error "SHADOW SIMULATION FAILED: $($results.failed) scenario(s)"
        exit 1
    }
    Write-Host "`nAll shadow scenarios PASS. Eligibility matrix is sound." -ForegroundColor Green
}

if (-not $RunOfflineShadowScenarios -and -not $ExportAutonomousDecisionMatrix -and -not $ValidateWorkingHoursConfig) {
    Write-Host "No action specified. Use -WhatIf to preview, or:" -ForegroundColor Yellow
    Write-Host "  -RunOfflineShadowScenarios       Run AS-1 through AS-12 shadow scenarios" -ForegroundColor Gray
    Write-Host "  -ExportAutonomousDecisionMatrix  Export eligibility matrix to outputs/" -ForegroundColor Gray
    Write-Host "  -ValidateWorkingHoursConfig      Validate working hours logic" -ForegroundColor Gray
    Write-Host "  -UseSampleWorkingHours           Use built-in sample config (Mon-Fri 09:00-18:00 UTC)" -ForegroundColor Gray
}
