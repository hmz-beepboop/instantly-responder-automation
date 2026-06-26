#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5C: Autonomous Eligibility Engine — Offline Scenario Evaluation

.DESCRIPTION
    Evaluates 75+ offline scenarios against the autonomous eligibility gates.
    No production writes. No live sends. would_send_live_now is always false
    when using the sample config (autonomous_enabled=false, dry_run=true).

.PARAMETER WhatIf
    Show what would be done without doing it.

.PARAMETER RunOfflineScenarios
    Evaluate all 75+ offline scenarios.

.PARAMETER ExportDecisionMatrix
    Export per-scenario decisions to outputs/autonomous_eligibility_decision_matrix.json.

.PARAMETER ExportSummary
    Export aggregate summary to outputs/autonomous_eligibility_summary.json.

.PARAMETER UseSampleConfig
    Use the sample config (all defaults disabled — recommended).

.PARAMETER NoProductionWrites
    Default: enabled. No production writes occur.

.EXAMPLE
    .\SL-PHASE-5C-autonomous-eligibility-engine.ps1 -UseSampleConfig -RunOfflineScenarios -ExportDecisionMatrix -ExportSummary
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RunOfflineScenarios,
    [switch]$ExportDecisionMatrix,
    [switch]$ExportSummary,
    [switch]$UseSampleConfig,
    [switch]$NoProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot  = Split-Path $PSScriptRoot -Parent
$OutputsDir  = Join-Path $ScriptRoot "outputs"
$Timestamp   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5C: Autonomous Eligibility Engine ===" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp"
Write-Host "[SAFE] No production writes. would_send_live_now=false for all scenarios with sample config." -ForegroundColor Green
Write-Host ""

# ── SAMPLE CONFIG (same as 5B) ────────────────────────────────────────────────

$Config = @{
    autonomous_enabled            = $false
    shadow_only                   = $true
    dry_run                       = $true
    emergency_disabled            = $true
    campaign_allowlist            = @()
    sender_allowlist              = @()
    intent_allowlist              = @()
    micro_intent_allowlist        = @()
    additional_intent_blocklist   = @("PRICING_REQUEST","PRICING_NEGOTIATION","CONTRACT_TERMS","GDPR_REQUEST","SOC2_REQUEST","DATA_SECURITY_REQUEST","PRIVACY_QUESTION","COMPLIANCE_QUESTION","LEGAL_COMPLAINT","CUSTOM_PROPOSAL_REQUEST","ENTERPRISE_REQUEST","SENSITIVE_PERSONAL_DATA")
    risk_blocklist                = @("UNSUBSCRIBE","DNC","OPT_OUT","HOSTILE","COMPLAINT","BILLING","REFUND")
    confidence_threshold          = 0.85
    max_autonomous_sends_per_day  = 0
    reviewer_timezone             = "America/New_York"
    working_hours_start           = "09:00"
    working_hours_end             = "18:00"
    working_days                  = @("Monday","Tuesday","Wednesday","Thursday","Friday")
}

# Permanent block list — hardcoded, cannot be overridden by config
$PermanentBlock = @("UNSUBSCRIBE","DO_NOT_CONTACT","OPT_OUT","LEGAL_COMPLAINT","ANGRY_REPLY","HOSTILE_REPLY",
    "BILLING_DISPUTE","REFUND_REQUEST","PRICING_REQUEST","PRICING_NEGOTIATION","CONTRACT_TERMS",
    "GDPR_REQUEST","SOC2_REQUEST","DATA_SECURITY_REQUEST","PRIVACY_QUESTION","COMPLIANCE_QUESTION",
    "SENSITIVE_PERSONAL_DATA","CUSTOM_PROPOSAL_REQUEST","ENTERPRISE_REQUEST","HIGH_VALUE_JUDGEMENT","AMBIGUOUS_INTENT")

# ── ELIGIBILITY FUNCTION ──────────────────────────────────────────────────────

function Invoke-EligibilityCheck {
    param(
        [hashtable]$Scenario,
        [hashtable]$Cfg
    )

    $id          = $Scenario.scenario_id
    $intent      = $Scenario.micro_intent
    $broad       = $Scenario.broad_category
    $addIntents  = $Scenario.additional_intents
    $inHours     = $Scenario.in_human_working_hours
    $campaignOK  = $Scenario.campaign_allowlisted
    $senderOK    = $Scenario.sender_allowlisted
    $confidence  = $Scenario.confidence
    $dupRisk     = $Scenario.duplicate_risk
    $threadOK    = $Scenario.thread_identity_confident
    $senderIdOK  = $Scenario.sender_identity_confident
    $campaignId  = $Scenario.campaign_identity_confident
    $riskFlags   = $Scenario.risk_flags
    $ruleConf    = $Scenario.active_rule_conflict

    $blockedReason = $null
    $wouldSend     = $false

    # Gate 1 — System state
    if ($Cfg.autonomous_enabled -eq $false) { $blockedReason = "autonomous_enabled=false" }
    elseif ($Cfg.dry_run -eq $true)          { $blockedReason = "dry_run=true" }
    elseif ($Cfg.shadow_only -eq $true)      { $blockedReason = "shadow_only=true" }
    elseif ($Cfg.emergency_disabled -eq $true) { $blockedReason = "emergency_disabled=true" }

    # Gate 2 — Identity
    elseif (-not $threadOK)  { $blockedReason = "thread_identity_not_confident" }
    elseif (-not $senderIdOK) { $blockedReason = "sender_identity_not_confident" }
    elseif (-not $campaignId) { $blockedReason = "campaign_identity_not_confident" }

    # Gate 3 — Allowlists
    elseif (-not $campaignOK)                           { $blockedReason = "campaign_not_allowlisted" }
    elseif (-not $senderOK)                             { $blockedReason = "sender_not_allowlisted" }
    elseif (@($Cfg.intent_allowlist).Count -eq 0)       { $blockedReason = "intent_allowlist_empty" }
    elseif ($intent -notin $Cfg.intent_allowlist)       { $blockedReason = "intent_not_allowlisted: $intent" }

    # Gate 4 — Permanent block list
    elseif ($intent -in $script:PermanentBlock) { $blockedReason = "intent_permanently_blocked: $intent" }
    else {
        $blockedAdd = @($addIntents | Where-Object { $_ -in $script:PermanentBlock -or $_ -in $Cfg.additional_intent_blocklist })
        if ($blockedAdd.Count -gt 0) { $blockedReason = "additional_intent_blocked: $($blockedAdd[0])" }
    }

    # Gate 5 — Working hours
    if (-not $blockedReason -and -not $inHours) { $blockedReason = "out_of_working_hours" }

    # Gate 6 — Confidence
    if (-not $blockedReason -and $confidence -lt $Cfg.confidence_threshold) { $blockedReason = "confidence_below_threshold: $confidence" }

    # Gate 7 — Duplicate risk
    if (-not $blockedReason -and $dupRisk) { $blockedReason = "duplicate_risk" }

    # Gate 8 — Daily cap
    if (-not $blockedReason -and $Cfg.max_autonomous_sends_per_day -le 0) { $blockedReason = "daily_cap_zero" }

    # Gate 9 — Active rule conflict
    if (-not $blockedReason -and $ruleConf) { $blockedReason = "active_rule_conflict" }

    # Risk flags
    if (-not $blockedReason) {
        $hitRisk = @($riskFlags | Where-Object { $_ -in $Cfg.risk_blocklist })
        if ($hitRisk.Count -gt 0) { $blockedReason = "risk_flag: $($hitRisk[0])" }
    }

    # would_be_shadow_eligible: true if would be eligible for shadow logging (all identity/intent gates pass, even if system is disabled)
    $shadowEligible = (
        $threadOK -and $senderIdOK -and $campaignId -and
        ($intent -notin $script:PermanentBlock) -and
        (@($addIntents | Where-Object { $_ -in $script:PermanentBlock }).Count -eq 0) -and
        $confidence -ge $Cfg.confidence_threshold -and
        -not $dupRisk
    )

    if (-not $blockedReason) { $wouldSend = $true }

    $action = if ($wouldSend) { "AUTONOMOUS_ELIGIBLE" }
              elseif ($shadowEligible) { "SHADOW_LOG" }
              elseif ($intent -in $script:PermanentBlock -or (@($addIntents | Where-Object { $_ -in $script:PermanentBlock }).Count -gt 0)) { "BLOCKED_PERMANENT" }
              else { "HUMAN_REVIEW" }

    return [ordered]@{
        scenario_id                   = $id
        incoming_text                 = $Scenario.incoming_text
        broad_category                = $broad
        micro_intent                  = $intent
        additional_intents            = $addIntents
        in_human_working_hours        = $inHours
        out_of_hours                  = (-not $inHours)
        campaign_allowlisted          = $campaignOK
        sender_allowlisted            = $senderOK
        intent_allowlisted            = ($intent -in $Cfg.intent_allowlist)
        risk_flags                    = $riskFlags
        confidence                    = $confidence
        active_rule_conflict          = $ruleConf
        duplicate_risk                = $dupRisk
        thread_identity_confident     = $threadOK
        sender_identity_confident     = $senderIdOK
        campaign_identity_confident   = $campaignId
        would_be_shadow_eligible      = $shadowEligible
        would_send_live_now           = $wouldSend
        blocked_reason                = $blockedReason
        recommended_action            = $action
        post_action_review_required   = $true
    }
}

# ── SCENARIO DEFINITIONS (75 scenarios) ──────────────────────────────────────

function Get-Scenarios {
    $good = @{ campaign_allowlisted=$true; sender_allowlisted=$true; thread_identity_confident=$true; sender_identity_confident=$true; campaign_identity_confident=$true; confidence=0.92; duplicate_risk=$false; active_rule_conflict=$false; risk_flags=@(); additional_intents=@(); in_human_working_hours=$true }
    $oor  = $good.Clone(); $oor.in_human_working_hours = $false
    $noC  = $good.Clone(); $noC.campaign_allowlisted = $false
    $noS  = $good.Clone(); $noS.sender_allowlisted = $false
    $lowC = $good.Clone(); $lowC.confidence = 0.60
    $dup  = $good.Clone(); $dup.duplicate_risk = $true
    $rc   = $good.Clone(); $rc.active_rule_conflict = $true
    $noTI = $good.Clone(); $noTI.thread_identity_confident = $false
    $noSI = $good.Clone(); $noSI.sender_identity_confident = $false
    $noCi = $good.Clone(); $noCi.campaign_identity_confident = $false

    $s = @()

    function S($id, $text, $broad, $micro, $extra, $base) {
        $h = $base.Clone()
        $h.scenario_id = $id; $h.incoming_text = $text; $h.broad_category = $broad; $h.micro_intent = $micro; $h.additional_intents = $extra
        return $h
    }

    # 1-10: Basic positive/scheduling
    $s += S "S001" "Yes, I'm interested. Can we chat?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S002" "Sounds good, when can we talk?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $oor
    $s += S "S003" "Can you send me a calendar link?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S004" "Happy to connect, what times work?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $oor
    $s += S "S005" "Tell me more about your service." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S006" "Send me more info." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S007" "How does this work?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S008" "Book a time to speak." "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S009" "Sounds interesting, let me know more." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S010" "What results can you show?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good

    # 11-20: Blocked commercial
    $s += S "S011" "What's the price?" "POSITIVE_INTEREST" "PRICING_REQUEST" @() $good
    $s += S "S012" "How much does this cost and what's in scope?" "POSITIVE_INTEREST" "PRICING_REQUEST" @("SCOPE_REQUEST") $good
    $s += S "S013" "Can we do a one campaign pilot?" "POSITIVE_INTEREST" "SMALL_SCALE_PILOT_REQUEST" @() $good
    $s += S "S014" "What are the contract terms?" "POSITIVE_INTEREST" "CONTRACT_TERMS" @() $good
    $s += S "S015" "Are you GDPR compliant?" "POSITIVE_INTEREST" "GDPR_REQUEST" @() $good
    $s += S "S016" "Do you have SOC2 certification?" "POSITIVE_INTEREST" "SOC2_REQUEST" @() $good
    $s += S "S017" "Where is my data stored?" "POSITIVE_INTEREST" "DATA_SECURITY_REQUEST" @() $good
    $s += S "S018" "What's your privacy policy?" "POSITIVE_INTEREST" "PRIVACY_QUESTION" @() $good
    $s += S "S019" "Can you send us a custom proposal?" "POSITIVE_INTEREST" "CUSTOM_PROPOSAL_REQUEST" @() $good
    $s += S "S020" "We have 10,000 contacts, what's the enterprise deal?" "POSITIVE_INTEREST" "ENTERPRISE_REQUEST" @() $good

    # 21-30: Safety blocked
    $s += S "S021" "Please remove me from your list." "UNSUBSCRIBE" "UNSUBSCRIBE" @() $good
    $s += S "S022" "Do not contact me again." "UNSUBSCRIBE" "DO_NOT_CONTACT" @() $good
    $s += S "S023" "I'm reporting this to the FTC." "LEGAL_COMPLAINT" "LEGAL_COMPLAINT" @() $good
    $s += S "S024" "This is harassment. Stop emailing me." "HOSTILE_REPLY" "HOSTILE_REPLY" @() $good
    $s += S "S025" "You fraudsters, this is a scam." "HOSTILE_REPLY" "HOSTILE_REPLY" @("LEGAL_COMPLAINT") $good
    $s += S "S026" "I was charged incorrectly." "BILLING_DISPUTE" "BILLING_DISPUTE" @() $good
    $s += S "S027" "I need a refund." "BILLING_DISPUTE" "REFUND_REQUEST" @() $good
    $s += S "S028" "I'm angry about how you got my email." "ANGRY_REPLY" "ANGRY_REPLY" @() $good
    $s += S "S029" "UNSUBSCRIBE" "UNSUBSCRIBE" "UNSUBSCRIBE" @() $good
    $s += S "S030" "Take me off your list immediately or I'll sue." "UNSUBSCRIBE" "LEGAL_COMPLAINT" @("UNSUBSCRIBE") $good

    # 31-40: Ambiguous/low-quality
    $s += S "S031" "Ok" "AMBIGUOUS" "AMBIGUOUS_INTENT" @() $good
    $s += S "S032" "Yes" "AMBIGUOUS" "AMBIGUOUS_INTENT" @() $good
    $s += S "S033" "Send it" "AMBIGUOUS" "AMBIGUOUS_INTENT" @() $good
    $s += S "S034" "Not interested." "NEGATIVE" "NEGATIVE_RESPONSE" @() $good
    $s += S "S035" "Sounds good but not right now" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $lowC
    $s += S "S036" "Interesting idea but maybe later" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $lowC
    $s += S "S037" "Sure, share some details about your thing" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S038" "I have sensitive data in my CRM." "POSITIVE_INTEREST" "SENSITIVE_PERSONAL_DATA" @() $good
    $s += S "S039" "We work with PII records." "POSITIVE_INTEREST" "DATA_SECURITY_REQUEST" @() $good
    $s += S "S040" "We're looking for a competitor to [CompanyX]." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good

    # 41-50: Multi-intent and gate failures
    $s += S "S041" "Yes interested, also what's the price?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("PRICING_REQUEST") $good
    $s += S "S042" "Interested but need contract terms first." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("CONTRACT_TERMS") $good
    $s += S "S043" "Tell me more. Also are you SOC2?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("SOC2_REQUEST") $good
    $s += S "S044" "Need a retry on sending info." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $dup
    $s += S "S045" "Already got your reply, thanks." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $dup
    $s += S "S046" "Sender not in our approved list scenario." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $noS
    $s += S "S047" "Campaign not in allowlist scenario." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $noC
    $noCoor = $good.Clone(); $noCoor.campaign_allowlisted = $false; $noCoor.in_human_working_hours = $false
    $s += S "S048" "Tell me more [campaign not approved, out of hours]." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $noCoor
    $s += S "S049" "Safe info request but low confidence." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $lowC
    $s += S "S050" "Scheduling request, sender not allowlisted." "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $noS

    # 51-60: Edge cases with mixed signals
    $s += S "S051" "Can you explain your service? Also GDPR question." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("GDPR_REQUEST") $good
    $s += S "S052" "Interested, also pricing mention." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("PRICING_REQUEST") $good
    $s += S "S053" "Want to learn more. What about contracts?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("CONTRACT_TERMS") $good
    $s += S "S054" "Can I know more about GDPR handling?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("GDPR_REQUEST") $good
    $s += S "S055" "Schedule a call + what's the cost?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @("PRICING_REQUEST") $good
    $s += S "S056" "Yes interested, unsubscribe phrase slipped in." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("UNSUBSCRIBE") $good
    $s += S "S057" "Interested but before anything what's the price?" "POSITIVE_INTEREST" "PRICING_REQUEST" @() $good
    $s += S "S058" "Interested, need contract." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @("CONTRACT_TERMS") $good
    $s += S "S059" "Can you do this without my data leaving the US? SOC2?" "POSITIVE_INTEREST" "SOC2_REQUEST" @("DATA_SECURITY_REQUEST") $good
    $s += S "S060" "I like the idea but tone is a bit aggressive." "ANGRY_REPLY" "ANGRY_REPLY" @() $good

    # 61-75: Special reply types and common queries
    $s += S "S061" "Thanks!" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $lowC
    $s += S "S062" "I am out of the office until July 5." "OUT_OF_OFFICE" "OUT_OF_OFFICE" @() $good
    $s += S "S063" "This is an automated reply from Outlook." "AUTORESPONDER" "AUTORESPONDER" @() $good
    $s += S "S064" "MAILER-DAEMON: Delivery failed for user@example.com" "BOUNCE" "BOUNCE" @() $good
    $s += S "S065" "Earn money from home click here now" "SPAM_LIKE" "SPAM_LIKE" @() $lowC
    $s += S "S066" "Can we schedule for next Tuesday at 2pm?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S067" "Can we speak tomorrow?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S068" "Who is this? How did you get my email?" "AMBIGUOUS" "AMBIGUOUS_INTENT" @() $good
    $s += S "S069" "What does your company do exactly?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S070" "Can you resend your previous email?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S071" "Do you have a brochure I can look at?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S072" "Can you send a demo link?" "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $good
    $s += S "S073" "Can we do a quick 10-minute call?" "POSITIVE_INTEREST" "SCHEDULING_REQUEST" @() $good
    $s += S "S074" "Is this AI-generated spam?" "AMBIGUOUS" "AMBIGUOUS_INTENT" @() $lowC
    $s += S "S075" "Maybe later, not right now." "POSITIVE_INTEREST" "INFORMATION_REQUEST" @() $lowC

    return $s
}

# ── RUN SCENARIOS ─────────────────────────────────────────────────────────────

if ($RunOfflineScenarios) {
    Write-Host "[RunOfflineScenarios] Evaluating 75 scenarios..." -ForegroundColor Yellow
    Write-Host ""

    $Scenarios = Get-Scenarios
    $Results   = [System.Collections.Generic.List[object]]::new()
    $PassCount = 0
    $HardFail  = 0

    foreach ($sc in $Scenarios) {
        $r = Invoke-EligibilityCheck -Scenario $sc -Cfg $Config
        $Results.Add($r)

        # HARD RULE: would_send_live_now must be false
        if ($r.would_send_live_now -eq $true) {
            $HardFail++
            Write-Host "  [HARD FAIL] $($r.scenario_id): would_send_live_now=true — SAMPLE CONFIG SAFETY VIOLATION" -ForegroundColor Red
        } else {
            $PassCount++
            $color = if ($r.recommended_action -eq "SHADOW_LOG") { "Green" } elseif ($r.recommended_action -like "BLOCKED*") { "DarkGray" } else { "Yellow" }
            Write-Host ("  [{0}] {1} — {2} — {3}" -f $r.recommended_action, $r.scenario_id, $r.micro_intent, $(if ($r.blocked_reason) { $r.blocked_reason } else { "ELIGIBLE" })) -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Host "Total scenarios: $($Results.Count)" -ForegroundColor Cyan
    Write-Host "would_send_live_now=false: $PassCount" -ForegroundColor Green
    Write-Host "HARD FAILURES (live_now=true): $HardFail" -ForegroundColor $(if ($HardFail -gt 0) {"Red"} else {"Green"})
    Write-Host ""

    if ($HardFail -gt 0) {
        Write-Error "SAFETY VIOLATION: $HardFail scenario(s) have would_send_live_now=true. This must not happen with sample config."
    }

    # Summary stats
    $shadowEligible  = @($Results | Where-Object { $_.would_be_shadow_eligible }).Count
    $blocked         = @($Results | Where-Object { -not $_.would_be_shadow_eligible }).Count
    $blockedReasons  = @($Results | Where-Object { $_.blocked_reason } | Group-Object { $_.blocked_reason } | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { @{ reason=$_.Name; count=$_.Count } })
    $actionBreakdown = @($Results | Group-Object { $_.recommended_action } | ForEach-Object { @{ action=$_.Name; count=$_.Count } })

    if ($ExportDecisionMatrix) {
        $MatrixPath = Join-Path $OutputsDir "autonomous_eligibility_decision_matrix.json"
        @{
            generated           = $Timestamp
            script              = "SL-PHASE-5C-autonomous-eligibility-engine.ps1"
            config_mode         = "SAMPLE_CONFIG_SHADOW_ONLY"
            total_scenarios     = $Results.Count
            hard_failures       = $HardFail
            production_writes   = $false
            scenarios           = $Results
        } | ConvertTo-Json -Depth 10 | Set-Content $MatrixPath -Encoding UTF8
        Write-Host "[ExportDecisionMatrix] Written: $MatrixPath" -ForegroundColor Green
    }

    if ($ExportSummary) {
        $SummaryPath = Join-Path $OutputsDir "autonomous_eligibility_summary.json"
        @{
            generated               = $Timestamp
            script                  = "SL-PHASE-5C-autonomous-eligibility-engine.ps1"
            config_mode             = "SAMPLE_CONFIG_SHADOW_ONLY"
            total_scenarios         = $Results.Count
            would_send_live_now     = $HardFail
            would_be_shadow_eligible = $shadowEligible
            blocked_or_human_review = $blocked
            hard_failures           = $HardFail
            safety_gate_result      = if ($HardFail -eq 0) {"PASS"} else {"FAIL"}
            top_blocked_reasons     = $blockedReasons
            action_breakdown        = $actionBreakdown
            production_writes       = $false
        } | ConvertTo-Json -Depth 10 | Set-Content $SummaryPath -Encoding UTF8
        Write-Host "[ExportSummary] Written: $SummaryPath" -ForegroundColor Green
    }

    Write-Host ""
    if ($HardFail -eq 0) {
        Write-Host "[PASS] All 75 scenarios: would_send_live_now=false. Sample config is safe." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== SL-PHASE-5C Complete ===" -ForegroundColor Cyan
Write-Host ""
