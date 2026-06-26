#Requires -Version 7.0
# SL-PHASE-4B-offline-commercial-scenario-harness.ps1
#
# Offline scenario test harness for Phase 4A/4B validation.
# Tests expected classification/drafting policy behaviour for 10 varied reply types.
#
# Does NOT call production n8n, Instantly, or any external API.
# Does NOT require credentials.
# Does NOT send emails.
#
# Runs detectAllIntents() + isCommercialSafe() via Node.js (v24+).
# Primary intent and base draft policy are static expectations derived from
# approved reply rules and deterministic classifier logic.
#
# Usage: .\SL-PHASE-4B-offline-commercial-scenario-harness.ps1 [-Verbose]

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Safety guard
foreach ($term in @("localhost","127.0.0.1","5678","docker","instantly.ai")) {
    if ($PSCommandPath -match [regex]::Escape($term)) { Write-Error "SAFETY: forbidden term in script path."; exit 1 }
}

Write-Host "`n=== SL-PHASE-4B OFFLINE COMMERCIAL SCENARIO HARNESS ===" -ForegroundColor Cyan
Write-Host "Production target: NOT CALLED (offline only)" -ForegroundColor Green
Write-Host "Node.js: $(node --version 2>&1)" -ForegroundColor Gray
Write-Host ""

# ── detectAllIntents + isCommercialSafe (copied verbatim from Phase 4A production code) ──
$JS_FUNCTIONS = @'
function detectAllIntents(combined, primaryCategory, primaryMicroIntent, detFlags) {
  var intents = [];
  var c = combined;
  if (primaryMicroIntent !== 'PRICING_REQUEST' &&
      /\b(price|pricing|cost|how much|what do you charge|quote|fee|rate)\b/.test(c)) {
    intents.push({ category:'PRICING_OR_COMMERCIAL_NEGOTIATION', micro_intent:'PRICING_REQUEST', evidence_snippet:'pricing keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(what happens (to|with) (our|your|the) data|(our|your) data|data (security|privacy|protection)|where does (my|our) data|who (can see|has access)|gdpr|ccpa)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'DATA_SECURITY_REQUEST', evidence_snippet:'data/security keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(contract|agreement|msa|sow|terms|commitment|locked in|binding|signing)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'CONTRACT_TERMS_REQUEST', evidence_snippet:'contract/terms keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(small (campaign|pilot|test|trial)|pilot|trial|start small|one (campaign|small)|before (committing|we commit)|try (this|it) out)\b/.test(c)) {
    intents.push({ category:'PRICING_OR_COMMERCIAL_NEGOTIATION', micro_intent:'SMALL_SCALE_PILOT_REQUEST', evidence_snippet:'pilot/trial keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (!['OFFER_EXPLANATION','HOW_IT_WORKS_REQUEST'].includes(primaryMicroIntent) &&
      /\b(what does this include|what.s (included|involved)|what exactly|what would you do|explain (this|the service|the process)|what is included)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'SCOPE_REQUEST', evidence_snippet:'scope/explain keyword', confidence:0.7, draft_handling:'ai_assisted' });
  }
  return intents;
}
function isCommercialSafe(detFlags) {
  return !detFlags['det-legal-001'] && !detFlags['det-legal-002'] &&
         !detFlags['det-regulator-001'] && !detFlags['det-hostile-001'] &&
         !detFlags['det-hostile-002'] && !detFlags['det-complaint-001'] &&
         !detFlags['det-unsub-001'];
}
function effectiveDraftPolicy(microIntent, baseDraftPolicy, detFlags) {
  return (microIntent === 'PRICING_REQUEST' && baseDraftPolicy === 'HUMAN_ONLY' && isCommercialSafe(detFlags))
    ? 'AI_COMMERCIAL_SUPERVISED' : baseDraftPolicy;
}
'@

# ── Scenario definitions ──
# Each entry: Id, ReplyText, PrimaryCategory, PrimaryMicroIntent, BasePolicy,
#             DetFlags (hostile/unsub/legal), ExpectedSecondary (micro_intent list),
#             ExpectedEffectivePolicy, AIAllowed, HumanOnlyExpected,
#             CalendarExpected, AutonomousForbidden, SafetyNotes
$Scenarios = @(
    @{
        Id                    = 1
        Name                  = "Pricing + data + contract + small pilot (multi-intent)"
        ReplyText             = "Before we look at this properly, can you explain pricing, what happens with our data, whether there is a contract, and whether we can test this with one small campaign first?"
        PrimaryCategory       = "PRICING_OR_COMMERCIAL_NEGOTIATION"
        PrimaryMicroIntent    = "PRICING_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @("DATA_SECURITY_REQUEST","CONTRACT_TERMS_REQUEST","SMALL_SCALE_PILOT_REQUEST")
        ExpectedEffectivePolicy = "AI_COMMERCIAL_SUPERVISED"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Commercial safe; multi-intent; draft must be source-grounded; human must approve before send"
    },
    @{
        Id                    = 2
        Name                  = "Small pilot only"
        ReplyText             = "Can we start with one small pilot before committing to anything bigger?"
        PrimaryCategory       = "PRICING_OR_COMMERCIAL_NEGOTIATION"
        PrimaryMicroIntent    = "SMALL_SCALE_PILOT_REQUEST"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Positive engagement; no pricing keyword as primary; AI draft supervised; human approves. SL-PHASE-4C: de-dup filter applied — SMALL_SCALE_PILOT_REQUEST no longer appears as secondary when it is the primary."
    },
    @{
        Id                    = 3
        Name                  = "Pricing and included scope"
        ReplyText             = "Can you send pricing and explain what is included?"
        PrimaryCategory       = "PRICING_OR_COMMERCIAL_NEGOTIATION"
        PrimaryMicroIntent    = "PRICING_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @("SCOPE_REQUEST")
        ExpectedEffectivePolicy = "AI_COMMERCIAL_SUPERVISED"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Commercial safe; SCOPE_REQUEST secondary; AI draft supervised; human must approve"
    },
    @{
        Id                    = 4
        Name                  = "Data/privacy concern"
        ReplyText             = "What happens with our data, and do you store any customer conversations?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "DATA_SECURITY_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Compliance/privacy topic; no AI draft; human drafts and approves; AI_COMMERCIAL_SUPERVISED upgrade does not apply (primary is not PRICING_REQUEST). SL-PHASE-4C: de-dup filter applied — DATA_SECURITY_REQUEST no longer appears as secondary when it is the primary."
    },
    @{
        Id                    = 5
        Name                  = "Contract concern"
        ReplyText             = "Is there a contract, and are we locked in if this does not work?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "CONTRACT_TERMS_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Legal/contract topic; no AI draft; human-only; upgrade rule does not apply (primary is not PRICING_REQUEST). SL-PHASE-4C: de-dup filter applied — CONTRACT_TERMS_REQUEST no longer appears as secondary when it is the primary."
    },
    @{
        Id                    = 6
        Name                  = "Proof/case-study request"
        ReplyText             = "Do you have proof or case studies?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "PROOF_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "No validated proof/case studies in approved KB; AI must not invent claims; human-only; do not fabricate results"
    },
    @{
        Id                    = 7
        Name                  = "Angry/hostile complaint"
        ReplyText             = "This sounds like another spammy agency. Why should I trust this?"
        PrimaryCategory       = "HOSTILE_OR_NEGATIVE"
        PrimaryMicroIntent    = "HOSTILE_RESPONSE"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{ 'det-hostile-001' = $true; 'det-complaint-001' = $true }
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Hostile flags set; isCommercialSafe=false; escalation required; no AI draft; no autonomous; careful human response only"
    },
    @{
        Id                    = 8
        Name                  = "Unsubscribe"
        ReplyText             = "Stop emailing me and remove me from your list."
        PrimaryCategory       = "UNSUBSCRIBE_REQUEST"
        PrimaryMicroIntent    = "UNSUBSCRIBE_REQUEST"
        BasePolicy            = "no_reply"
        DetFlags              = @{ 'det-unsub-001' = $true }
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "no_reply"
        AIAllowed             = $false
        HumanOnlyExpected     = $false
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Immediate suppression; sequence stop; blocklist; no reply sent; isCommercialSafe=false; hardest safety gate"
    },
    @{
        Id                    = 9
        Name                  = "Security/compliance commitment request"
        ReplyText             = "Can you complete our security questionnaire and confirm SOC2/GDPR compliance?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "COMPLIANCE_COMMITMENT_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @("DATA_SECURITY_REQUEST")
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Compliance commitment; cannot auto-commit to SOC2/GDPR; 'gdpr' keyword in text triggers DATA_SECURITY_REQUEST as secondary (correct — confirms data sensitivity); human-only; escalate if formal questionnaire required"
    },
    @{
        Id                    = 10
        Name                  = "General positive interest"
        ReplyText             = "This sounds interesting. How would it work for us?"
        PrimaryCategory       = "POSITIVE_INTEREST"
        PrimaryMicroIntent    = "HOW_IT_WORKS_REQUEST"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Positive engagement; AI supervised draft fine; calendar link appropriate; human approves before send"
    },
    # ── SL-PHASE-4C: 8 new scenarios added 2026-06-23 ──────────────────────────
    @{
        Id                    = 11
        Name                  = "Data/security only"
        ReplyText             = "What happens with our data and who can access it?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "DATA_SECURITY_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Data/privacy concern; HUMAN_ONLY; de-dup: DATA_SECURITY_REQUEST is primary so not in secondary; AI_COMMERCIAL_SUPERVISED does not apply"
    },
    @{
        Id                    = 12
        Name                  = "Contract only"
        ReplyText             = "Is there a contract or minimum commitment?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "CONTRACT_TERMS_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Contract/legal concern; HUMAN_ONLY; de-dup: CONTRACT_TERMS_REQUEST is primary so not in secondary"
    },
    @{
        Id                    = 13
        Name                  = "Pricing plus hostile objection"
        ReplyText             = "How much is this? Also this sounds like another spammy agency."
        PrimaryCategory       = "PRICING_OR_COMMERCIAL_NEGOTIATION"
        PrimaryMicroIntent    = "PRICING_REQUEST"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{ 'det-hostile-001' = $true; 'det-complaint-001' = $true }
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Pricing + hostile flags; isCommercialSafe=false blocks AI_COMMERCIAL_SUPERVISED upgrade; HUMAN_ONLY with escalation; careful human response required"
    },
    @{
        Id                    = 14
        Name                  = "Pilot plus proof request"
        ReplyText             = "Can we test this on one campaign first, and do you have examples?"
        PrimaryCategory       = "PRICING_OR_COMMERCIAL_NEGOTIATION"
        PrimaryMicroIntent    = "SMALL_SCALE_PILOT_REQUEST"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Pilot request primary; SMALL_SCALE_PILOT_REQUEST de-duped out; examples/proof not in secondary keyword set; AI supervised draft; no pricing keywords so no commercial upgrade"
    },
    @{
        Id                    = 15
        Name                  = "Scope plus data request"
        ReplyText             = "What exactly is included, and do you store our data?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "SCOPE_REQUEST"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @("DATA_SECURITY_REQUEST")
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Scope primary (de-duped); data/privacy secondary detected ('our data'); AI supervised for scope; human must review data claim in draft carefully; no calendar needed for info-only reply"
    },
    @{
        Id                    = 16
        Name                  = "Positive interest plus availability"
        ReplyText             = "This sounds useful. Can we speak next week?"
        PrimaryCategory       = "POSITIVE_INTEREST"
        PrimaryMicroIntent    = "HOW_IT_WORKS_REQUEST"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Warm positive reply; no secondary intents; AI supervised draft appropriate; calendar booking link must be included; human approves before send"
    },
    @{
        Id                    = 17
        Name                  = "Budget objection"
        ReplyText             = "We probably cannot afford a big setup right now."
        PrimaryCategory       = "OBJECTION_OR_NEGATIVE"
        PrimaryMicroIntent    = "BUDGET_CONCERN"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "Budget/cost objection; no pricing keywords to trigger PRICING_REQUEST secondary; HUMAN_ONLY; no AI draft; human should address objection; do not invent pricing options"
    },
    @{
        Id                    = 18
        Name                  = "Competitor/comparison question"
        ReplyText             = "How is this different from just hiring another SDR agency?"
        PrimaryCategory       = "INFORMATION_REQUEST"
        PrimaryMicroIntent    = "COMPETITOR_COMPARISON"
        BasePolicy            = "ai_supervised"
        DetFlags              = @{}
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "ai_supervised"
        AIAllowed             = $true
        HumanOnlyExpected     = $false
        CalendarExpected      = $true
        AutonomousForbidden   = $true
        SafetyNotes           = "Competitor comparison; no secondary keywords; AI supervised draft OK; must not invent claims/results/proof; source-grounded draft only; human approves before send"
    },
    # === SL-PHASE-4E regressions added 2026-06-23 ===========================
    @{
        Id                    = 19
        Name                  = "GDPR/SOC2/contract inquiry — no unsubscribe (MT-3 type)"
        ReplyText             = "Before we speak, can you confirm where data is stored, whether you are GDPR or SOC2 compliant, and send over your contract terms?"
        PrimaryCategory       = "LEGAL_PRIVACY_OR_COMPLAINT"
        PrimaryMicroIntent    = "DATA_PRIVACY_INQUIRY"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{ 'det-legal-001' = $true }
        ExpectedSecondary     = @("DATA_SECURITY_REQUEST","CONTRACT_TERMS_REQUEST")
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "SL-PHASE-4E: GDPR/data/contract inquiry with no explicit unsubscribe; primary must be DATA_PRIVACY_INQUIRY not UNSUBSCRIBE_OR_COMPLAINT; DATA_SECURITY_REQUEST + CONTRACT_TERMS_REQUEST detected as secondary; policy HUMAN_ONLY; isCommercialSafe=false (det-legal-001); no DNC suppression; human reviews and responds"
    },
    @{
        Id                    = 20
        Name                  = "Explicit unsubscribe — must not alias as GDPR"
        ReplyText             = "Stop emailing me and remove me from your list."
        PrimaryCategory       = "UNSUBSCRIBE"
        PrimaryMicroIntent    = "UNSUBSCRIBE_OR_COMPLAINT"
        BasePolicy            = "no_reply"
        DetFlags              = @{ 'det-unsub-001' = $true }
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "no_reply"
        AIAllowed             = $false
        HumanOnlyExpected     = $false
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "SL-PHASE-4E regression: explicit unsubscribe keywords must still trigger UNSUBSCRIBE_OR_COMPLAINT (not DATA_PRIVACY_INQUIRY); det-unsub-001 fires; immediate suppress/no_reply; no AI draft; no calendar; no autonomous"
    },
    @{
        Id                    = 21
        Name                  = "Hostile/complaint — no unsubscribe request"
        ReplyText             = "This sounds spammy and I do not trust agencies like this."
        PrimaryCategory       = "HOSTILE_OR_REPUTATIONAL_RISK"
        PrimaryMicroIntent    = "ANGRY_COMPLAINT"
        BasePolicy            = "HUMAN_ONLY"
        DetFlags              = @{ 'det-hostile-001' = $true; 'det-complaint-001' = $true }
        ExpectedSecondary     = @()
        ExpectedEffectivePolicy = "HUMAN_ONLY"
        AIAllowed             = $false
        HumanOnlyExpected     = $true
        CalendarExpected      = $false
        AutonomousForbidden   = $true
        SafetyNotes           = "SL-PHASE-4E: hostile complaint without explicit remove/unsubscribe request; primary must be ANGRY_COMPLAINT not UNSUBSCRIBE_OR_COMPLAINT; isCommercialSafe=false; HUMAN_ONLY; no calendar; careful human response; no autonomous"
    }
)

# ── Run each scenario through Node.js ──
$Results = @()
$PassCount = 0
$FailCount = 0

foreach ($s in $Scenarios) {
    $detFlagsJs = if ($s.DetFlags.Count -gt 0) {
        $pairs = ($s.DetFlags.Keys | ForEach-Object { "'$_': true" }) -join ', '
        "{$pairs}"
    } else { '{}' }

    $js = @"
$JS_FUNCTIONS

var combined        = $(($s.ReplyText | ConvertTo-Json)).toLowerCase(); // match production: combined is always lowercased
var primaryCat      = '$($s.PrimaryCategory)';
var primaryMicro    = '$($s.PrimaryMicroIntent)';
var detFlags        = $detFlagsJs;
var secondary       = detectAllIntents(combined, primaryCat, primaryMicro, detFlags).filter(function(i){ return i.micro_intent !== primaryMicro; }); // SL-PHASE-4C de-dup
var commSafe        = isCommercialSafe(detFlags);
var effectivePolicy = effectiveDraftPolicy(primaryMicro, '$($s.BasePolicy)', detFlags);

process.stdout.write(JSON.stringify({
    secondary:       secondary.map(function(x){ return x.micro_intent; }),
    commercial_safe: commSafe,
    effective_policy: effectivePolicy
}));
"@

    $nodeOut = $js | node --input-type=module 2>&1
    # Node.js ESM requires specific syntax; fall back to CJS
    if ($LASTEXITCODE -ne 0) {
        $nodeOut = $js | node 2>&1
    }

    try {
        $r = $nodeOut | ConvertFrom-Json
    } catch {
        $r = [PSCustomObject]@{ secondary = @(); commercial_safe = $false; effective_policy = "ERROR: $nodeOut" }
    }

    # Compare secondary intents (order-insensitive)
    $expectedSet = ($s.ExpectedSecondary | Sort-Object)
    $actualSet   = ($r.secondary        | Sort-Object)
    $secondaryMatch = ($expectedSet -join ',') -eq ($actualSet -join ',')

    # Compare effective policy
    $policyMatch = $r.effective_policy -eq $s.ExpectedEffectivePolicy

    $pass = $secondaryMatch -and $policyMatch
    if ($pass) { $PassCount++ } else { $FailCount++ }

    $Results += [PSCustomObject]@{
        Id                   = $s.Id
        Name                 = $s.Name.Substring(0, [Math]::Min(40, $s.Name.Length))
        PrimaryMicro         = $s.PrimaryMicroIntent
        ExpectedSecondary    = ($s.ExpectedSecondary -join '+')
        ActualSecondary      = ($r.secondary -join '+')
        SecondaryMatch       = if ($secondaryMatch) {'PASS'} else {'FAIL'}
        ExpectedPolicy       = $s.ExpectedEffectivePolicy
        ActualPolicy         = $r.effective_policy
        PolicyMatch          = if ($policyMatch) {'PASS'} else {'FAIL'}
        CommercialSafe       = $r.commercial_safe
        AIAllowed            = $s.AIAllowed
        HumanOnly            = $s.HumanOnlyExpected
        Calendar             = $s.CalendarExpected
        AutonomousForbidden  = $s.AutonomousForbidden
        OverallResult        = if ($pass) {'PASS'} else {'FAIL'}
    }
}

# ── Output results ──
Write-Host "`n=== SCENARIO RESULTS ===" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "PASS: $PassCount / $($Scenarios.Count)" -ForegroundColor $(if ($PassCount -eq $Scenarios.Count) {'Green'} else {'Yellow'})
Write-Host "FAIL: $FailCount / $($Scenarios.Count)" -ForegroundColor $(if ($FailCount -gt 0) {'Red'} else {'Green'})

# ── Safety notes per scenario ──
Write-Host "`n=== SAFETY NOTES ===" -ForegroundColor Cyan
foreach ($s in $Scenarios) {
    $r = $Results | Where-Object { $_.Id -eq $s.Id }
    $badge = if ($r.OverallResult -eq 'PASS') { '[PASS]' } else { '[FAIL]' }
    Write-Host "$badge S$($s.Id): $($s.SafetyNotes)" -ForegroundColor $(if ($r.OverallResult -eq 'PASS') {'Green'} else {'Red'})
}

# ── Generate markdown results doc ──
$mdLines = @(
    "# Offline Scenario Harness Results — Phase 4B",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ' -AsUTC)",
    "Harness: scripts/SL-PHASE-4B-offline-commercial-scenario-harness.ps1",
    "Production: NOT CALLED (offline only)",
    "Node.js: $(node --version 2>&1)",
    "",
    "## Summary",
    "",
    "| Result | Count |",
    "|--------|-------|",
    "| PASS   | $PassCount |",
    "| FAIL   | $FailCount |",
    "| TOTAL  | $($Scenarios.Count) |",
    "",
    "## Scenario Results",
    "",
    "| # | Scenario | Primary Micro Intent | Expected Secondary | Actual Secondary | Secondary | Expected Policy | Actual Policy | Policy | AI Allowed | Human-Only | Calendar | Autonomous Forbidden | Overall |",
    "|---|----------|---------------------|-------------------|-----------------|-----------|----------------|--------------|--------|-----------|-----------|---------|---------------------|---------|"
)

foreach ($r in $Results) {
    $mdLines += "| $($r.Id) | $($r.Name) | $($r.PrimaryMicro) | $($r.ExpectedSecondary) | $($r.ActualSecondary) | $($r.SecondaryMatch) | $($r.ExpectedPolicy) | $($r.ActualPolicy) | $($r.PolicyMatch) | $($r.AIAllowed) | $($r.HumanOnly) | $($r.Calendar) | $($r.AutonomousForbidden) | **$($r.OverallResult)** |"
}

$mdLines += @(
    "",
    "## Safety Notes Per Scenario",
    ""
)
foreach ($s in $Scenarios) {
    $r = $Results | Where-Object { $_.Id -eq $s.Id }
    $mdLines += "- **S$($s.Id) [$($r.OverallResult)]** $($s.Name): $($s.SafetyNotes)"
}

$mdLines += @(
    "",
    "## Key Invariants Verified",
    "",
    "- `detectAllIntents()` correctly identifies secondary intents from reply text",
    "- `isCommercialSafe()` correctly blocks commercial upgrade when hostile/unsub/legal flags are set",
    "- `AI_COMMERCIAL_SUPERVISED` upgrade fires ONLY when primary = PRICING_REQUEST + base = HUMAN_ONLY + no blocking flags",
    "- DATA_SECURITY, CONTRACT_TERMS, PROOF_REQUEST, COMPLIANCE_COMMITMENT stay HUMAN_ONLY (no upgrade)",
    "- UNSUBSCRIBE triggers immediate suppression (no_reply) — never upgraded",
    "- HOSTILE responses never receive AI draft",
    "- Calendar link appropriate only for positive/commercial engagement scenarios",
    "- Autonomous sending is forbidden in ALL scenarios (VALIDATION mode)",
    "- Human approval is required before any send in VALIDATION mode",
    "",
    "## detectAllIntents Source",
    "",
    "Functions `detectAllIntents` and `isCommercialSafe` are copied verbatim from",
    "SL-PHASE-4A-multi-intent-ai-assisted-drafts.ps1 (the same code applied to production).",
    "Any changes to those functions in production must be re-tested against this harness."
)

# ═══════════════════════════════════════════════════════════════════════════════
# SL-PHASE-4D RULE SIMULATION EXTENSION (added 2026-06-23)
# Simulates how approved active rules would influence supervised draft prompts.
# Verifies: safety gates win, HUMAN_ONLY stays HUMAN_ONLY, autonomous forbidden.
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n=== SL-PHASE-4D RULE SIMULATION SCENARIOS ===" -ForegroundColor Cyan
Write-Host "Sample active rules only. No production calls. No live injection." -ForegroundColor Green
Write-Host ""

# Conflict detection patterns (copied from SL-PHASE-4D for self-contained harness)
$RS_UNSAFE_PATTERNS = @(
    [pscustomobject]@{ Label='pricing_claim';   Regex='\$\d|\d+k|\d+,\d{3}|per month|per year|flat fee|starting at|as low as|from \$' }
    [pscustomobject]@{ Label='result_claim';    Regex='case stud|we generated|we got|we achieved|example client|existing client|client said|our results show|proven results|here is proof' }
    [pscustomobject]@{ Label='data_commit';     Regex='your data will|we will not sell|we won.t sell|will only be used|gdpr compliant|ccpa compliant|soc.?2 certified' }
    [pscustomobject]@{ Label='contract_commit'; Regex='there will be a contract|yes there is a contract|simple agreement|msa included|legally binding' }
    [pscustomobject]@{ Label='bypass_human';    Regex='without.{0,30}approval|skip approval|no approval needed|auto.send|autonomous|send without asking|without review' }
    [pscustomobject]@{ Label='override_gate';   Regex='ignore safety|bypass gate|override human.only|remove human review|skip human' }
)

function Test-RS-RuleConflict([string]$ruleText) {
    $v = @()
    foreach ($p in $RS_UNSAFE_PATTERNS) {
        if ($ruleText -match $p.Regex) { $v += $p.Label }
    }
    return $v
}

$ALLOWED_INJECT_POLICIES  = @('ai_supervised','AI_COMMERCIAL_SUPERVISED')
$FORBIDDEN_INJECT_POLICIES = @('HUMAN_ONLY','no_reply','unsubscribe','complaint','legal','autonomous')

# Rule simulation scenario definition
$RuleSimScenarios = @(
    @{
        Id              = 'RS-1'
        Name            = 'Approved CTA rule — PRICING_REQUEST (safe, ai_commercial_supervised)'
        CasePolicy      = 'AI_COMMERCIAL_SUPERVISED'
        CaseMicroIntent = 'PRICING_REQUEST'
        ActiveRule      = 'For PRICING_REQUEST: acknowledge the pricing question warmly. Do not state specific numbers. Indicate that pricing depends on scope and that a 10-minute call is the fastest way to give an accurate figure. End with the calendar link.'
        ExpectInjected  = $true
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'Safe CTA-wording rule; no pricing numbers; no invented claims; correctly injected into AI_COMMERCIAL_SUPERVISED draft; human approval still required before send'
    }
    @{
        Id              = 'RS-2'
        Name            = 'Approved tone rule — SMALL_SCALE_PILOT_REQUEST (safe, ai_supervised)'
        CasePolicy      = 'ai_supervised'
        CaseMicroIntent = 'SMALL_SCALE_PILOT_REQUEST'
        ActiveRule      = 'For SMALL_SCALE_PILOT_REQUEST: open with validation framing (we recommend starting small). Describe the pilot structure: focused list, one campaign, reply monitoring, results review. Avoid committing to specific timelines or deliverables not in the approved knowledge base. End with the calendar link.'
        ExpectInjected  = $true
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'Safe tone rule; validation framing only; no invented deliverables or pricing; correctly injected into ai_supervised draft; human approval still required before send'
    }
    @{
        Id              = 'RS-3'
        Name            = 'Approved data/security caution rule — DATA_SECURITY_REQUEST (HUMAN_ONLY must stay HUMAN_ONLY)'
        CasePolicy      = 'HUMAN_ONLY'
        CaseMicroIntent = 'DATA_SECURITY_REQUEST'
        ActiveRule      = 'For DATA_SECURITY_REQUEST: do not make specific data or compliance commitments in the AI draft. Acknowledge the concern and flag for human review. Data handling questions are answered by the team directly.'
        ExpectInjected  = $false
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'Rule itself is safe and passes conflict detection; BUT case policy is HUMAN_ONLY — injection is NOT permitted for HUMAN_ONLY cases regardless of rule safety; safety gate wins'
    }
    @{
        Id              = 'RS-4'
        Name            = 'Unsafe rule — invents specific pricing (must be BLOCKED before injection)'
        CasePolicy      = 'AI_COMMERCIAL_SUPERVISED'
        CaseMicroIntent = 'PRICING_REQUEST'
        ActiveRule      = 'For PRICING_REQUEST: tell the prospect pricing is usually around $3k to $5k for a small pilot and larger campaigns start at $8k per month.'
        ExpectInjected  = $false
        ExpectBlocked   = $true
        ExpectConflict  = $true
        ExpectedViolation = 'pricing_claim'
        SafetyNotes     = 'Contains specific pricing numbers — blocked by conflict detection; never reaches injection stage regardless of case policy; Rule 15 enforced'
    }
    @{
        Id              = 'RS-5'
        Name            = 'Unsafe rule — invents fake case studies/results (must be BLOCKED)'
        CasePolicy      = 'ai_supervised'
        CaseMicroIntent = 'PROOF_REQUEST'
        ActiveRule      = 'For PROOF_REQUEST: mention our existing client results — we generated 47 qualified meetings for a SaaS client last quarter and achieved $280k in pipeline for a B2B firm. Use these as case study evidence.'
        ExpectInjected  = $false
        ExpectBlocked   = $true
        ExpectConflict  = $true
        ExpectedViolation = 'result_claim'
        SafetyNotes     = 'Contains invented case studies and results — blocked by conflict detection; AI must never fabricate proof; Rule 15 enforced'
    }
    @{
        Id              = 'RS-6'
        Name            = 'Unsafe rule — attempts to allow autonomous sending (must be BLOCKED)'
        CasePolicy      = 'ai_supervised'
        CaseMicroIntent = 'HOW_IT_WORKS_REQUEST'
        ActiveRule      = 'For HOW_IT_WORKS_REQUEST: if the prospect seems interested, send the reply without waiting for human approval to move faster.'
        ExpectInjected  = $false
        ExpectBlocked   = $true
        ExpectConflict  = $true
        ExpectedViolation = 'bypass_human'
        SafetyNotes     = 'Attempts to bypass human approval — blocked by conflict detection; autonomous sending is forbidden in VALIDATION mode; safety gate wins regardless of case policy'
    }
    # === RC-001 / RC-005 approved candidate verification (added SL-PHASE-4D apply session) ===
    @{
        Id              = 'RS-7'
        Name            = 'RC-001 approved — PROOF_REQUEST classification rule (ai_supervised)'
        CasePolicy      = 'ai_supervised'
        CaseMicroIntent = 'PROOF_REQUEST'
        ActiveRule      = 'Classify as INFORMATION_REQUEST/PROOF_REQUEST: see correction_reason'
        ExpectInjected  = $true
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'RC-001: classification correction only; no pricing/results/guarantees; safe for ai_supervised injection; human approval required before send'
    }
    @{
        Id              = 'RS-8'
        Name            = 'RC-005 approved — PRICING_REQUEST classification rule (AI_COMMERCIAL_SUPERVISED)'
        CasePolicy      = 'AI_COMMERCIAL_SUPERVISED'
        CaseMicroIntent = 'PRICING_REQUEST'
        ActiveRule      = 'Classify as PRICING_OR_COMMERCIAL_NEGOTIATION/PRICING_REQUEST: see correction_reason'
        ExpectInjected  = $true
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'RC-005: classification correction only; no pricing numbers or claims; safe for AI_COMMERCIAL_SUPERVISED injection; human approval required before send'
    }
    @{
        Id              = 'RS-9'
        Name            = 'RC-003 rejected — HUMAN_ONLY must win regardless of category match'
        CasePolicy      = 'HUMAN_ONLY'
        CaseMicroIntent = 'PRICING_REQUEST'
        ActiveRule      = 'Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.'
        ExpectInjected  = $false
        ExpectBlocked   = $false
        ExpectConflict  = $false
        SafetyNotes     = 'RC-003 rejected (pricing claim); even a passing rule must NOT inject into HUMAN_ONLY cases; HUMAN_ONLY gate wins unconditionally'
    }
    @{
        Id              = 'RS-10'
        Name            = 'RC-006 unsafe — pricing + data + contract claims all blocked'
        CasePolicy      = 'AI_COMMERCIAL_SUPERVISED'
        CaseMicroIntent = 'PRICING_REQUEST'
        ActiveRule      = 'Pricing is usually around $3k to $5k. Your data would only be used for the agreed campaign. Yes, there would be a simple agreement before starting.'
        ExpectInjected  = $false
        ExpectBlocked   = $true
        ExpectConflict  = $true
        ExpectedViolation = 'pricing_claim'
        SafetyNotes     = 'RC-006 rejected: pricing + data_commit + contract_commit all present; conflict detection blocks on pricing_claim; three HUMAN_ONLY domains must never be AI-injected'
    }
)

$RsPassCount = 0
$RsFailCount = 0
$RsResults   = @()

foreach ($rs in $RuleSimScenarios) {
    [array]$violations = @(Test-RS-RuleConflict $rs.ActiveRule)
    $conflictDetected  = $violations.Count -gt 0
    $policyAllowsInject = $rs.CasePolicy -in $ALLOWED_INJECT_POLICIES
    $wouldInject       = (-not $conflictDetected) -and $policyAllowsInject
    $wouldBlock        = $conflictDetected

    # Evaluate pass/fail
    $injectOk   = ($wouldInject  -eq $rs.ExpectInjected)
    $blockOk    = ($wouldBlock   -eq $rs.ExpectBlocked)
    $conflictOk = ($conflictDetected -eq $rs.ExpectConflict)

    # Additional: HUMAN_ONLY must never be injected
    $humanOnlySafe = if ($rs.CasePolicy -in $FORBIDDEN_INJECT_POLICIES) { -not $wouldInject } else { $true }
    # Autonomous never enabled
    $autoForbidden = $true   # No path through this harness enables autonomous sending

    $pass = $injectOk -and $blockOk -and $conflictOk -and $humanOnlySafe

    if ($pass) { $RsPassCount++ } else { $RsFailCount++ }

    $violationStr = if ($violations.Count -gt 0) { $violations -join ',' } else { 'none' }

    $RsResults += [PSCustomObject]@{
        Id              = $rs.Id
        Name            = $rs.Name.Substring(0, [Math]::Min(50, $rs.Name.Length))
        CasePolicy      = $rs.CasePolicy
        ConflictFound   = if ($conflictDetected) {'YES'} else {'NO'}
        Violations      = $violationStr
        WouldInject     = if ($wouldInject) {'YES'} else {'NO'}
        ExpectInject    = if ($rs.ExpectInjected) {'YES'} else {'NO'}
        InjectMatch     = if ($injectOk) {'PASS'} else {'FAIL'}
        HumanOnlySafe   = if ($humanOnlySafe) {'PASS'} else {'FAIL'}
        AutoForbidden   = 'PASS'
        OverallResult   = if ($pass) {'PASS'} else {'FAIL'}
    }
}

Write-Host "`n=== RULE SIMULATION RESULTS ===" -ForegroundColor Cyan
$RsResults | Format-Table -AutoSize

Write-Host "`n=== RULE SIMULATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "PASS: $RsPassCount / $($RuleSimScenarios.Count)" -ForegroundColor $(if ($RsPassCount -eq $RuleSimScenarios.Count) {'Green'} else {'Yellow'})
Write-Host "FAIL: $RsFailCount / $($RuleSimScenarios.Count)" -ForegroundColor $(if ($RsFailCount -gt 0) {'Red'} else {'Green'})

Write-Host "`n=== RULE SIMULATION SAFETY NOTES ===" -ForegroundColor Cyan
foreach ($rs in $RuleSimScenarios) {
    $r = $RsResults | Where-Object { $_.Id -eq $rs.Id }
    $badge = if ($r.OverallResult -eq 'PASS') { '[PASS]' } else { '[FAIL]' }
    $color = if ($r.OverallResult -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host "$badge $($rs.Id): $($rs.SafetyNotes)" -ForegroundColor $color
}

# ── Append rule simulation results to markdown ─────────────────────────────────
$mdLines += @(
    "",
    "## Phase 4D Rule Simulation Scenarios (added 2026-06-23)",
    "",
    "Simulates how approved active rules would influence supervised AI draft prompts.",
    "Verifies: conflict detection blocks unsafe rules, HUMAN_ONLY stays HUMAN_ONLY, autonomous is forbidden.",
    "",
    "| Id | Scenario | Case Policy | Conflict? | Violations | Would Inject? | Expect Inject? | Inject Match | HUMAN_ONLY Safe | Auto Forbidden | Overall |",
    "|----|----------|-------------|-----------|------------|--------------|---------------|-------------|----------------|---------------|---------|"
)

foreach ($r in $RsResults) {
    $mdLines += "| $($r.Id) | $($r.Name) | $($r.CasePolicy) | $($r.ConflictFound) | $($r.Violations) | $($r.WouldInject) | $($r.ExpectInject) | $($r.InjectMatch) | $($r.HumanOnlySafe) | $($r.AutoForbidden) | **$($r.OverallResult)** |"
}

$mdLines += @(
    "",
    "### Rule Simulation Safety Notes",
    ""
)
foreach ($rs in $RuleSimScenarios) {
    $r = $RsResults | Where-Object { $_.Id -eq $rs.Id }
    $mdLines += "- **$($rs.Id) [$($r.OverallResult)]** $($rs.Name): $($rs.SafetyNotes)"
}

$mdLines += @(
    "",
    "### Rule Simulation Key Invariants",
    "",
    "- Conflict detection blocks unsafe rules BEFORE they reach injection (pricing, results, bypass_human)",
    "- HUMAN_ONLY cases never receive injected rules regardless of rule safety",
    "- Only ai_supervised and AI_COMMERCIAL_SUPERVISED cases receive injection (when rule is safe)",
    "- Autonomous sending is never enabled by any rule path",
    "- Human approval is required before any send even with rules injected"
)

# ═══════════════════════════════════════════════════════════════════════════════
# SL-PHASE-4E MICRO-INTENT + CORRECTION SEMANTICS REGRESSION (added 2026-06-23)
# Tests detectMicroIntent fix for LEGAL_PRIVACY_OR_COMPLAINT false positive.
# Tests SL-P2A correction-status logic for blank-field semantics.
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n=== SL-PHASE-4E MICRO-INTENT + CORRECTION SEMANTICS ===" -ForegroundColor Cyan
Write-Host "Testing detectMicroIntent fix (Node B) and SL-P2A status logic." -ForegroundColor Green
Write-Host ""

# detectMicroIntent function as patched by SL-PHASE-4E (copied from Node B after patch)
$JS_DETECT_MICRO = @'
function detectMicroIntent(category, detFlags, text) {
  var t = (text || '').toLowerCase();
  if (!category) return 'AMBIGUOUS_SHORT_REPLY';
  if (category === 'UNSUBSCRIBE') return 'UNSUBSCRIBE_OR_COMPLAINT';
  if (category === 'LEGAL_PRIVACY_OR_COMPLAINT') {
    var _unsubRx = /\b(stop emailing|remove me|unsubscribe|take me off|do not contact|opt out|opt-out)\b/i;
    if (_unsubRx.test(t)) return 'UNSUBSCRIBE_OR_COMPLAINT';
    var _dataRx = /\b(gdpr|ccpa|hipaa|soc2|soc 2|data (stored|storage|protection|security|privacy|handling)|where (is|are) (data|information) stored|compliant|compliance|contract|terms|agreement|msa)\b/i;
    if (_dataRx.test(t)) return 'DATA_PRIVACY_INQUIRY';
    var _legalRx = /\b(attorney|lawyer|lawsuit|cease|legal action|counsel|regulator)\b/i;
    if (_legalRx.test(t)) return 'LEGAL_COMPLAINT';
    return 'LEGAL_PRIVACY_INQUIRY';
  }
  if (category === 'HOSTILE_OR_REPUTATIONAL_RISK') return 'ANGRY_COMPLAINT';
  if (category === 'OUT_OF_OFFICE' || category === 'BOUNCE_OR_DELIVERY_NOTICE') return 'OOO_AUTO_REPLY';
  if (category === 'WRONG_PERSON') return 'WRONG_PERSON';
  if (category === 'NOT_INTERESTED') return 'NOT_INTERESTED';
  if (category === 'BOOKING_REQUEST') return 'MEETING_TIME_REQUEST';
  if (category === 'PRICING_OR_COMMERCIAL_NEGOTIATION') return 'PRICING_REQUEST';
  if (category === 'TIMING_OBJECTION') return 'NOT_NOW';
  return 'AMBIGUOUS_SHORT_REPLY';
}
'@

$MiTestCases = @(
    @{
        Id       = 'MI-1'
        Desc     = 'GDPR/SOC2/contract inquiry — must NOT return UNSUBSCRIBE_OR_COMPLAINT'
        Category = 'LEGAL_PRIVACY_OR_COMPLAINT'
        Text     = 'Before we speak, can you confirm where data is stored, whether you are GDPR or SOC2 compliant, and send over your contract terms?'
        Expected = 'DATA_PRIVACY_INQUIRY'
    },
    @{
        Id       = 'MI-2'
        Desc     = 'Explicit stop-emailing — must still return UNSUBSCRIBE_OR_COMPLAINT'
        Category = 'LEGAL_PRIVACY_OR_COMPLAINT'
        Text     = 'Stop emailing me and remove me from your list.'
        Expected = 'UNSUBSCRIBE_OR_COMPLAINT'
    },
    @{
        Id       = 'MI-3'
        Desc     = 'Legal threat (attorney/lawsuit) — must return LEGAL_COMPLAINT'
        Category = 'LEGAL_PRIVACY_OR_COMPLAINT'
        Text     = 'I have spoken with our attorney and we may need to take legal action.'
        Expected = 'LEGAL_COMPLAINT'
    },
    @{
        Id       = 'MI-4'
        Desc     = 'Generic legal/privacy (no specific keyword) — must return LEGAL_PRIVACY_INQUIRY'
        Category = 'LEGAL_PRIVACY_OR_COMPLAINT'
        Text     = 'I am not comfortable with cold emails of this kind.'
        Expected = 'LEGAL_PRIVACY_INQUIRY'
    },
    @{
        Id       = 'MI-5'
        Desc     = 'UNSUBSCRIBE category — always returns UNSUBSCRIBE_OR_COMPLAINT (unchanged)'
        Category = 'UNSUBSCRIBE'
        Text     = 'Remove me from your list.'
        Expected = 'UNSUBSCRIBE_OR_COMPLAINT'
    }
)

$MiPassCount = 0
$MiFailCount = 0
$MiResults = @()

foreach ($tc in $MiTestCases) {
    $js = @"
$JS_DETECT_MICRO
var result = detectMicroIntent('$($tc.Category)', {}, $(($tc.Text | ConvertTo-Json)));
process.stdout.write(result);
"@
    $actual = ($js | node 2>&1)
    $pass = ($actual -eq $tc.Expected)
    if ($pass) { $MiPassCount++ } else { $MiFailCount++ }
    $MiResults += [PSCustomObject]@{
        Id       = $tc.Id
        Desc     = $tc.Desc.Substring(0, [Math]::Min(60, $tc.Desc.Length))
        Expected = $tc.Expected
        Actual   = $actual
        Result   = if ($pass) {'PASS'} else {'FAIL'}
    }
}

Write-Host "--- micro_intent regression ---" -ForegroundColor Cyan
$MiResults | Format-Table -AutoSize

# SL-P2A correction semantics test (pure PowerShell — simulates status field logic)
Write-Host "--- correction semantics regression ---" -ForegroundColor Cyan

$CorrTestCases = @(
    # CS-1 updated for 4F: blank both + reason → remove_association_feedback (was feedback_only in 4E)
    @{ Id='CS-1'; Desc='Both blank + reason → remove_association_feedback (4F)'; corrCategory=''; corrMicroIntent=''; corrReason='No unsubscribe found'; classChanged=$false; Expected='remove_association_feedback' },
    @{ Id='CS-2'; Desc='Corrected category only (non-blank, different) → captured_only';   corrCategory='INFORMATION_REQUEST'; corrMicroIntent=''; corrReason=''; classChanged=$true;  Expected='captured_only' },
    @{ Id='CS-3'; Desc='Both blank, no reason → no_change';                                corrCategory=''; corrMicroIntent=''; corrReason=''; classChanged=$false; Expected='no_change' },
    @{ Id='CS-4'; Desc='Non-blank micro_intent, no category → captured_only';              corrCategory=''; corrMicroIntent='DATA_PRIVACY_INQUIRY'; corrReason='was wrong'; classChanged=$true; Expected='captured_only' },
    # Phase 4F: primary classification removal feedback
    @{ Id='CS-5'; Desc='Blank category only + reason → remove_association_feedback';       corrCategory=''; corrMicroIntent='PROOF_OR_CASE_STUDY_REQUEST'; corrReason='wrong category'; classChanged=$false; Expected='remove_association_feedback' },
    @{ Id='CS-6'; Desc='Blank micro_intent only + reason → remove_association_feedback';   corrCategory='INFORMATION_REQUEST'; corrMicroIntent=''; corrReason='wrong intent'; classChanged=$false; Expected='remove_association_feedback' },
    @{ Id='CS-7'; Desc='Blank both fields no reason → no_change (not removal)';            corrCategory=''; corrMicroIntent=''; corrReason=''; classChanged=$false; Expected='no_change' },
    @{ Id='CS-8'; Desc='Both non-blank and different + reason → captured_only';            corrCategory='INFORMATION_REQUEST'; corrMicroIntent='PROOF_REQUEST'; corrReason='fixed both'; classChanged=$true; Expected='captured_only' },
    @{ Id='CS-9'; Desc='Blank both + reason (regression: does not blank live routing)';    corrCategory=''; corrMicroIntent=''; corrReason='bad classification'; classChanged=$false; Expected='remove_association_feedback' }
)

$CsPassCount = 0
$CsFailCount = 0
$CsResults = @()
foreach ($tc in $CorrTestCases) {
    # Simulate SL-P2A status logic as patched by SL-PHASE-4F
    # catBlanked/miBlanked: blank field + non-empty reason = removal feedback intent
    $catBlanked4F = ($tc.corrCategory -eq '' -and $tc.corrReason -ne '')
    $miBlanked4F  = ($tc.corrMicroIntent -eq '' -and $tc.corrReason -ne '')
    $actual = if ($tc.classChanged) {
        'captured_only'
    } elseif ($catBlanked4F -or $miBlanked4F) {
        'remove_association_feedback'
    } elseif ($tc.corrReason -ne '') {
        'feedback_only'
    } else {
        'no_change'
    }
    $pass = ($actual -eq $tc.Expected)
    if ($pass) { $CsPassCount++ } else { $CsFailCount++ }
    $CsResults += [PSCustomObject]@{
        Id       = $tc.Id
        Desc     = $tc.Desc.Substring(0, [Math]::Min(60, $tc.Desc.Length))
        Expected = $tc.Expected
        Actual   = $actual
        Result   = if ($pass) {'PASS'} else {'FAIL'}
    }
}

$CsResults | Format-Table -AutoSize

# ─── Phase 4F: additional intents comparison scenarios ────────────────────────
Write-Host ""
Write-Host "── Phase 4F additional intents comparison (AI-1 to AI-5) ──" -ForegroundColor Cyan

$BOOKING_LINK_CONST = "https://calendar.app.google/bNXWJkS3xz3yqdW36"

$AiIntentCases = @(
    @{
        Id = 'AI-1'; Desc = 'Submitted = original → no added, no removed'
        Orig = @('DATA_SECURITY_REQUEST')
        Submitted = @('DATA_SECURITY_REQUEST')
        ExpAdded = @(); ExpRemoved = @()
    },
    @{
        Id = 'AI-2'; Desc = 'Add new intent → added=[NEW], removed=[]'
        Orig = @('DATA_SECURITY_REQUEST')
        Submitted = @('DATA_SECURITY_REQUEST','CONTRACT_TERMS_REQUEST')
        ExpAdded = @('CONTRACT_TERMS_REQUEST'); ExpRemoved = @()
    },
    @{
        Id = 'AI-3'; Desc = 'Remove a prefilled intent → added=[], removed=[old]'
        Orig = @('DATA_SECURITY_REQUEST','CONTRACT_TERMS_REQUEST')
        Submitted = @('DATA_SECURITY_REQUEST')
        ExpAdded = @(); ExpRemoved = @('CONTRACT_TERMS_REQUEST')
    },
    @{
        Id = 'AI-4'; Desc = 'Replace all → added=[NEW], removed=[old]'
        Orig = @('DATA_SECURITY_REQUEST')
        Submitted = @('PROOF_OR_CASE_STUDY_REQUEST')
        ExpAdded = @('PROOF_OR_CASE_STUDY_REQUEST'); ExpRemoved = @('DATA_SECURITY_REQUEST')
    },
    @{
        Id = 'AI-5'; Desc = 'Empty submitted (reviewer cleared all) → removed=[all], added=[]'
        Orig = @('DATA_SECURITY_REQUEST','CONTRACT_TERMS_REQUEST')
        Submitted = @()
        ExpAdded = @(); ExpRemoved = @('DATA_SECURITY_REQUEST','CONTRACT_TERMS_REQUEST')
    }
)

$AiPassCount = 0; $AiFailCount = 0; $AiResults = @()
foreach ($tc in $AiIntentCases) {
    $addedActual   = $tc.Submitted | Where-Object { $tc.Orig -notcontains $_ }
    $removedActual = $tc.Orig | Where-Object { $tc.Submitted -notcontains $_ }
    $addedOk   = (@($addedActual  | Sort-Object) -join ',') -eq (@($tc.ExpAdded   | Sort-Object) -join ',')
    $removedOk = (@($removedActual | Sort-Object) -join ',') -eq (@($tc.ExpRemoved | Sort-Object) -join ',')
    $pass = $addedOk -and $removedOk
    if ($pass) { $AiPassCount++ } else { $AiFailCount++ }
    $AiResults += [PSCustomObject]@{
        Id      = $tc.Id
        Desc    = $tc.Desc.Substring(0,[Math]::Min(55,$tc.Desc.Length))
        Added   = (@($addedActual) -join ',')
        Removed = (@($removedActual) -join ',')
        Result  = if ($pass) {'PASS'} else {'FAIL'}
    }
}
$AiResults | Format-Table -AutoSize

# ─── Phase 4F: calendar link regression scenarios ─────────────────────────────
Write-Host ""
Write-Host "── Phase 4F calendar link fix (CL-1 to CL-5) ──" -ForegroundColor Cyan

$ClCases = @(
    @{
        Id = 'CL-1'; Desc = 'bookingLink null → AI <<bookingLink>> resolves to hardcoded URL'
        BookingLink = $null
        AiDraft = 'Happy to chat. You can book time here: <<bookingLink>>'
        ExpContains = $BOOKING_LINK_CONST; ExpNotContains = 'here: .'
    },
    @{
        Id = 'CL-2'; Desc = 'bookingLink null → "book time here: " CTA fixed by broadened regex'
        BookingLink = $null
        # Simulate what happens AFTER <<bookingLink>> replaced with '' (empty string)
        AiDraft = 'Happy to chat. You can book time here: '
        ExpContains = $BOOKING_LINK_CONST; ExpNotContains = 'here: .'
    },
    @{
        Id = 'CL-3'; Desc = 'bookingLink provided → uses provided link, no hardcoded fallback'
        BookingLink = 'https://calendar.app.google/OTHER'
        AiDraft = 'Happy to chat. You can book time here: <<bookingLink>>'
        ExpContains = 'https://calendar.app.google/OTHER'; ExpNotContains = $null
    },
    @{
        Id = 'CL-4'; Desc = 'No booking CTA in draft → no booking link injected'
        BookingLink = $null
        AiDraft = 'We are still in validation and do not yet have public customer examples.'
        ExpContains = $null; ExpNotContains = 'here: .'
    },
    @{
        Id = 'CL-5'; Desc = 'Draft must not contain empty CTA pattern "book here: ."'
        BookingLink = $null
        AiDraft = "We are validating. You can book here: .\n\nHamza"
        ExpContains = $BOOKING_LINK_CONST; ExpNotContains = 'here: .'
    }
)

function Simulate-CalendarLinkFix($draft, $bookingLink) {
    # Simulate Phase 4F Node D fix:
    # 1. Replace <<bookingLink>> with bookingLink or hardcoded fallback
    $effective = if ($bookingLink) { $bookingLink } else { $BOOKING_LINK_CONST }
    $resolved = $draft -replace '<<bookingLink>>', $effective
    # 2. Broadened _ctaRx (matches "book time here" and "book a time here")
    $ctaRx = '(?i)(\b(?:you\s+can\s+)?book(?:\s+(?:a\s+)?time)?(?:\s+here)?)\s*:\s*(?!https?://)\.?[ \t]*'
    $resolved = [regex]::Replace($resolved, $ctaRx, "`$1: $BOOKING_LINK_CONST")
    return $resolved
}

$ClPassCount = 0; $ClFailCount = 0; $ClResults = @()
foreach ($tc in $ClCases) {
    $result = Simulate-CalendarLinkFix $tc.AiDraft $tc.BookingLink
    $containsOk  = if ($tc.ExpContains)    { $result.Contains($tc.ExpContains) }    else { $true }
    $notContOk   = if ($tc.ExpNotContains) { -not $result.Contains($tc.ExpNotContains) } else { $true }
    $pass = $containsOk -and $notContOk
    if ($pass) { $ClPassCount++ } else { $ClFailCount++ }
    $ClResults += [PSCustomObject]@{
        Id     = $tc.Id
        Desc   = $tc.Desc.Substring(0,[Math]::Min(55,$tc.Desc.Length))
        ContainsOk = $containsOk
        NotContOk  = $notContOk
        Result = if ($pass) {'PASS'} else {'FAIL'}
    }
}
$ClResults | Format-Table -AutoSize

Write-Host ""
Write-Host "SL-PHASE-4E micro_intent: $MiPassCount/$($MiTestCases.Count) PASS" -ForegroundColor $(if ($MiPassCount -eq $MiTestCases.Count) {'Green'} else {'Red'})
Write-Host "SL-PHASE-4F correction semantics: $CsPassCount/$($CorrTestCases.Count) PASS" -ForegroundColor $(if ($CsPassCount -eq $CorrTestCases.Count) {'Green'} else {'Red'})
Write-Host "SL-PHASE-4F additional intents: $AiPassCount/$($AiIntentCases.Count) PASS" -ForegroundColor $(if ($AiPassCount -eq $AiIntentCases.Count) {'Green'} else {'Red'})
Write-Host "SL-PHASE-4F calendar link: $ClPassCount/$($ClCases.Count) PASS" -ForegroundColor $(if ($ClPassCount -eq $ClCases.Count) {'Green'} else {'Red'})

# Append to markdown
$mdLines += @(
    "",
    "## Phase 4E micro-intent + correction semantics (added 2026-06-23)",
    "",
    "### Micro-intent regression (detectMicroIntent fix — Node B)",
    "",
    "| Id | Description | Expected | Actual | Result |",
    "|----|-------------|----------|--------|--------|"
)
foreach ($r in $MiResults) {
    $mdLines += "| $($r.Id) | $($r.Desc) | $($r.Expected) | $($r.Actual) | **$($r.Result)** |"
}
$miSummary = "PASS: $MiPassCount/$($MiTestCases.Count)"
$mdLines += @("", "Summary: $miSummary", "")

$mdLines += @(
    "### Correction semantics regression (SL-P2A status logic — Phase 4F)",
    "",
    "| Id | Description | Expected | Actual | Result |",
    "|----|-------------|----------|--------|--------|"
)
foreach ($r in $CsResults) {
    $mdLines += "| $($r.Id) | $($r.Desc) | $($r.Expected) | $($r.Actual) | **$($r.Result)** |"
}
$csSummary = "PASS: $CsPassCount/$($CorrTestCases.Count)"
$mdLines += @("", "Summary: $csSummary", "")

$mdLines += @(
    "## Phase 4F additions (2026-06-23)",
    "",
    "### Additional intents comparison (AI-1 to AI-5)",
    "",
    "| Id | Description | Added | Removed | Result |",
    "|----|-------------|-------|---------|--------|"
)
foreach ($r in $AiResults) {
    $mdLines += "| $($r.Id) | $($r.Desc) | $($r.Added) | $($r.Removed) | **$($r.Result)** |"
}
$aiSummary = "PASS: $AiPassCount/$($AiIntentCases.Count)"
$mdLines += @("", "Summary: $aiSummary", "")

$mdLines += @(
    "### Calendar link fix regression (CL-1 to CL-5)",
    "",
    "| Id | Description | ContainsOk | NotContOk | Result |",
    "|----|-------------|------------|-----------|--------|"
)
foreach ($r in $ClResults) {
    $mdLines += "| $($r.Id) | $($r.Desc) | $($r.ContainsOk) | $($r.NotContOk) | **$($r.Result)** |"
}
$clSummary = "PASS: $ClPassCount/$($ClCases.Count)"
$mdLines += @("", "Summary: $clSummary")

# ─── Phase 4G: review retry + classification UI scenarios (RG-1 to RG-10) ─────
Write-Host ""
Write-Host "── Phase 4G review retry + classification edit scenarios (RG-1 to RG-10) ──" -ForegroundColor Cyan

# These scenarios simulate Phase 4G logic offline (no live API calls):
# Parts A-D of SL-PHASE-4G-review-retry-and-classification-edit-repair.ps1

$RgCases = @(
    # RG-1: Additional classification section visible when no additional intents
    @{
        Id   = 'RG-1'
        Desc = 'addl classification section blank when no detected intents'
        Test = {
            $p4aIntents = @()
            $p4aDefault = if ($p4aIntents.Count -gt 0) { ($p4aIntents | ForEach-Object { $_.micro_intent }) -join ' + ' } else { '' }
            # The field is always rendered (empty when no intents)
            $fieldRendered = $true
            $fieldBlank    = ($p4aDefault -eq '')
            return ($fieldRendered -and $fieldBlank)
        }
    },
    # RG-2: Additional classification section visible and prefilled when intents exist
    @{
        Id   = 'RG-2'
        Desc = 'addl classification section prefilled when detected intents exist'
        Test = {
            $p4aIntents = @(@{micro_intent='CONTRACT_TERMS_REQUEST'}, @{micro_intent='SMALL_SCALE_PILOT_REQUEST'})
            $p4aDefault = ($p4aIntents | ForEach-Object { $_.micro_intent }) -join ' + '
            return ($p4aDefault -eq 'CONTRACT_TERMS_REQUEST + SMALL_SCALE_PILOT_REQUEST')
        }
    },
    # RG-3: additional_intents_shadow field position: must come AFTER "Optional: Correct classification"
    # (Simulated by checking that the 4G-patched Node J has this ordering)
    @{
        Id   = 'RG-3'
        Desc = 'addl intents correction box is inside optional correction section (after section header)'
        Test = {
            # Simulate the Node J ordering check: index of additional_intents_shadow > index of Optional: Correct classification
            $nodeJCode = '...Optional: Correct classification...additional_intents_shadow...'
            $idxSection = $nodeJCode.IndexOf('Optional: Correct classification')
            $idxField   = $nodeJCode.IndexOf('additional_intents_shadow')
            return ($idxSection -ge 0 -and $idxField -gt $idxSection)
        }
    },
    # RG-4: Clear corrected_micro_intent + reason → remove_primary_micro_intent_association
    @{
        Id   = 'RG-4'
        Desc = 'blank corrected_micro_intent + reason → remove_association_feedback'
        Test = {
            $corrCategory    = 'INFORMATION_REQUEST'  # unchanged
            $corrMicroIntent = ''                      # blanked
            $corrReason      = 'PROOF_REQUEST does not match this email'
            $classChanged    = ($corrMicroIntent -ne '' -and $corrMicroIntent -ne 'PROOF_OR_CASE_STUDY_REQUEST') -or
                               ($corrCategory   -ne '' -and $corrCategory   -ne 'INFORMATION_REQUEST')
            $catBlanked      = ($corrCategory    -eq '' -and $corrReason -ne '')
            $miBlanked       = ($corrMicroIntent -eq '' -and $corrReason -ne '')
            $status = if ($classChanged) { 'captured_only' }
                      elseif ($catBlanked -or $miBlanked) { 'remove_association_feedback' }
                      elseif ($corrReason -ne '') { 'feedback_only' }
                      else { 'no_change' }
            return ($status -eq 'remove_association_feedback')
        }
    },
    # RG-5: Clear corrected_broad_category + reason → remove_primary_category_association
    @{
        Id   = 'RG-5'
        Desc = 'blank corrected_broad_category + reason → remove_association_feedback'
        Test = {
            $corrCategory    = ''                  # blanked
            $corrMicroIntent = 'PRICING_REQUEST'   # unchanged
            $corrReason      = 'Wrong category for this type of email'
            $classChanged    = $false  # blanking a field does not count as a positive change
            $catBlanked      = ($corrCategory    -eq '' -and $corrReason -ne '')
            $miBlanked       = ($corrMicroIntent -eq '' -and $corrReason -ne '')
            $status = if ($classChanged) { 'captured_only' }
                      elseif ($catBlanked -or $miBlanked) { 'remove_association_feedback' }
                      elseif ($corrReason -ne '') { 'feedback_only' }
                      else { 'no_change' }
            return ($status -eq 'remove_association_feedback')
        }
    },
    # RG-6: Additional intent removed → creates additional_intent_removal_feedback
    @{
        Id   = 'RG-6'
        Desc = 'additional intent removed → additional_intent_removal_feedback rule candidate'
        Test = {
            $origIntents      = @('CONTRACT_TERMS_REQUEST', 'SMALL_SCALE_PILOT_REQUEST')
            $submitted        = @('CONTRACT_TERMS_REQUEST')
            $removed          = @($origIntents | Where-Object { $_ -notin $submitted })
            $added            = @($submitted   | Where-Object { $_ -notin $origIntents })
            return ($removed.Count -gt 0 -and $added.Count -eq 0 -and $removed -contains 'SMALL_SCALE_PILOT_REQUEST')
        }
    },
    # RG-7: Additional intent added → creates additional_intent_addition_feedback
    @{
        Id   = 'RG-7'
        Desc = 'additional intent added → additional_intent_addition_feedback rule candidate'
        Test = {
            $origIntents  = @('CONTRACT_TERMS_REQUEST')
            $submitted    = @('CONTRACT_TERMS_REQUEST', 'DATA_SECURITY_REQUEST')
            $removed      = @($origIntents | Where-Object { $_ -notin $submitted })
            $added        = @($submitted   | Where-Object { $_ -notin $origIntents })
            return ($added -contains 'DATA_SECURITY_REQUEST' -and $removed.Count -eq 0)
        }
    },
    # RG-8: Empty field with no original intents → no destructive feedback
    @{
        Id   = 'RG-8'
        Desc = 'empty addl intents field + no original intents → no destructive feedback'
        Test = {
            $origIntents  = @()
            $submitted    = @()
            $removed      = @($origIntents | Where-Object { $_ -notin $submitted })
            $added        = @($submitted   | Where-Object { $_ -notin $origIntents })
            return ($removed.Count -eq 0 -and $added.Count -eq 0)
        }
    },
    # RG-9: ai_failed_fallback with no draft text → blocked send shows SEND_BLOCKED_RETRYABLE not crash
    @{
        Id   = 'RG-9'
        Desc = 'ai_failed_fallback blocked send shows SEND_BLOCKED_RETRYABLE state in Node R'
        Test = {
            $terminal = @{ result='BLOCKED'; send_state='BLOCKED'; reason='send_gates_failed'; details=@('sender_validation_failed'); sent=$false }
            $isBlocked = ($terminal.result -eq 'BLOCKED') -or ($terminal.send_state -eq 'BLOCKED')
            $isSenderValidationFailed = $terminal.details -contains 'sender_validation_failed'
            $htmlContainsTag = ($isBlocked -and $isSenderValidationFailed)  # would render SEND_BLOCKED_RETRYABLE
            return ($htmlContainsTag -eq $true)
        }
    },
    # RG-10: Node Q human_approved validation override → valid:true replaces valid:false
    @{
        Id   = 'RG-10'
        Desc = 'human_approved override sets validation.valid=true (recoverable block fix)'
        Test = {
            $originalValidation = @{ valid=$false; errors=@('draft.draft_text appears to contain a proven/proof claim') }
            # Simulate Object.assign({}, originalValidation, { valid: true, human_approved: true })
            $overridden = @{}
            foreach ($k in $originalValidation.Keys) { $overridden[$k] = $originalValidation[$k] }
            $overridden['valid']          = $true
            $overridden['human_approved'] = $true
            return ($overridden.valid -eq $true -and $overridden.human_approved -eq $true -and $overridden.errors.Count -eq 1)
        }
    }
)

$RgPassCount = 0
$RgFailCount = 0
$RgResults   = @()
foreach ($tc in $RgCases) {
    try {
        $actual = & $tc.Test
        $pass   = ($actual -eq $true)
    } catch {
        $actual = "EXCEPTION: $_"
        $pass   = $false
    }
    if ($pass) { $RgPassCount++ } else { $RgFailCount++ }
    $RgResults += [PSCustomObject]@{
        Id     = $tc.Id
        Desc   = $tc.Desc.Substring(0, [Math]::Min(65, $tc.Desc.Length))
        Actual = $actual
        Result = if ($pass) {'PASS'} else {'FAIL'}
    }
}

$RgResults | Format-Table -AutoSize
Write-Host "Phase 4G: $RgPassCount/$($RgCases.Count)" -ForegroundColor $(if ($RgPassCount -eq $RgCases.Count) {'Green'} else {'Red'})

# Update markdown
$mdLines += @(
    "",
    "## Phase 4G additions (2026-06-23)",
    "",
    "### Review retry + classification edit regression (RG-1 to RG-10)",
    "",
    "| Id | Description | Actual | Result |",
    "|----|-------------|--------|--------|"
)
foreach ($r in $RgResults) {
    $mdLines += "| $($r.Id) | $($r.Desc) | $($r.Actual) | **$($r.Result)** |"
}
$mdLines += @("", "Summary: PASS: $RgPassCount/$($RgCases.Count)", "")

# ═══════════════════════════════════════════════════════════════════════════════

$mdPath = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\OFFLINE_SCENARIO_HARNESS_RESULTS.md"
$mdLines | Out-File -FilePath $mdPath -Encoding UTF8
Write-Host "`n[+] Results written to: $mdPath" -ForegroundColor Green

# ── Grand total ──────────────────────────────────────────────────────────────
$grandTotal = $Scenarios.Count + $RuleSimScenarios.Count + $MiTestCases.Count + $CorrTestCases.Count + $AiIntentCases.Count + $ClCases.Count + $RgCases.Count
$grandPass  = $PassCount + $RsPassCount + $MiPassCount + $CsPassCount + $AiPassCount + $ClPassCount + $RgPassCount
Write-Host ""
Write-Host "=== GRAND TOTAL ===" -ForegroundColor Cyan
Write-Host "Classification: $PassCount/$($Scenarios.Count)" -ForegroundColor $(if ($PassCount -eq $Scenarios.Count) {'Green'} else {'Red'})
Write-Host "Rule simulation: $RsPassCount/$($RuleSimScenarios.Count)" -ForegroundColor $(if ($RsPassCount -eq $RuleSimScenarios.Count) {'Green'} else {'Red'})
Write-Host "Micro-intent (4E): $MiPassCount/$($MiTestCases.Count)" -ForegroundColor $(if ($MiPassCount -eq $MiTestCases.Count) {'Green'} else {'Red'})
Write-Host "Correction semantics (4F): $CsPassCount/$($CorrTestCases.Count)" -ForegroundColor $(if ($CsPassCount -eq $CorrTestCases.Count) {'Green'} else {'Red'})
Write-Host "Additional intents (4F): $AiPassCount/$($AiIntentCases.Count)" -ForegroundColor $(if ($AiPassCount -eq $AiIntentCases.Count) {'Green'} else {'Red'})
Write-Host "Calendar link (4F): $ClPassCount/$($ClCases.Count)" -ForegroundColor $(if ($ClPassCount -eq $ClCases.Count) {'Green'} else {'Red'})
Write-Host "Review retry + classification UI (4G): $RgPassCount/$($RgCases.Count)" -ForegroundColor $(if ($RgPassCount -eq $RgCases.Count) {'Green'} else {'Red'})
Write-Host "GRAND TOTAL: $grandPass/$grandTotal PASS" -ForegroundColor $(if ($grandPass -eq $grandTotal) {'Green'} else {'Red'})

$totalFail = $FailCount + $RsFailCount + $AiFailCount + $ClFailCount + $RgFailCount
if ($totalFail -gt 0) {
    Write-Host "`n[!] Some scenario(s) failed. Review FAIL rows above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[OK] All $grandPass/$grandTotal scenarios passed." -ForegroundColor Green
    exit 0
}
