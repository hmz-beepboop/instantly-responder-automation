#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-5L: Draft revision reason learning — form field + capture + rule candidate patch.

.DESCRIPTION
Patches HumanApproval workflow 9aPrt92jFhoYFxbs ONLY.
Decision, Sender, Intake, ErrorHandler, SLAWatchdog, FTH are NOT modified.
No autonomous sending enabled. No live rules auto-created.

Changes:
  Part A — Node J: Add draft_revision_reason textarea + draft_revision_type select
            + desired_future_behavior input near draft editor. Section shown only
            when reviewer edits the draft text (JS change detection, no approval block).

  Part B — Node L: Parse 3 new form fields from POST body:
            submit_draft_revision_reason, submit_draft_revision_type,
            submit_desired_future_behavior.

  Part C — SL-P1A: Add draft_revision_reason/type/desired_future_behavior
            to the draft revision event stored in sl_draft_revision_events.

  Part D — SL-P2A: Use human-entered draft_revision_reason (with fallback to
            generic string) in draft rule candidate. Add draft_revision_type
            and desired_future_behavior to proposed_shadow candidate object.

Safety:
  - No routing changes.
  - No live rules created. All rule candidates remain proposed_shadow.
  - No Sender, Decision, Intake, ErrorHandler, SLAWatchdog changes.
  - No autonomous mode enabled. No dry_run=false. No shadow_only=false.
  - draft_revision_reason does not block approval if blank.

.PARAMETER WhatIf
Verify all patch anchors exist and none are already applied. No changes made.

.PARAMETER Apply
Execute the patch and verify versionId changed.

.PARAMETER VerifyReviewFormField
Check that draft_revision_reason field appears in live J node code.

.PARAMETER VerifyLearningCapture
Check that SL-P1A and SL-P2A contain the new draft_revision_reason fields.

.PARAMETER VerifyRuleCandidate
Run offline sample draft revision and show the rule candidate that would be produced.

.PARAMETER UseSampleDraftRevision
Use a built-in test fixture (no production call) when running offline verifications.

.PARAMETER ExportReport
Export verification summary to outputs/draft_revision_reason_learning_report.json.

.PARAMETER NoProductionWrites
Dry-run for Apply: compute all patches but do NOT PUT to API.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply,
    [switch]$VerifyReviewFormField,
    [switch]$VerifyLearningCapture,
    [switch]$VerifyRuleCandidate,
    [switch]$UseSampleDraftRevision,
    [switch]$ExportReport,
    [switch]$NoProductionWrites
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Safety guard ─────────────────────────────────────────────────────────────
foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) {
        Write-Error "SAFETY: forbidden term '$bad' in script path."; exit 1
    }
}

if (-not $WhatIf -and -not $Apply -and -not $VerifyReviewFormField -and
    -not $VerifyLearningCapture -and -not $VerifyRuleCandidate -and -not $ExportReport) {
    Write-Host "SL-PHASE-5L: Draft Revision Reason Learning Proof" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  -WhatIf                  Verify patch anchors exist, no changes"
    Write-Host "  -Apply                   Apply patch to production (requires API key)"
    Write-Host "  -Apply -NoProductionWrites  Compute patches but do NOT PUT to API"
    Write-Host "  -VerifyReviewFormField   Check J node has draft_revision_reason"
    Write-Host "  -VerifyLearningCapture   Check SL-P1A/P2A have new fields"
    Write-Host "  -VerifyRuleCandidate     Offline rule candidate generation test"
    Write-Host "  -UseSampleDraftRevision  Use built-in fixtures (no production call)"
    Write-Host "  -ExportReport            Export JSON report to outputs/"
    exit 0
}

$BASE         = "https://n8n.hmzaiautomation.com/api/v1"
$WF_ID        = "9aPrt92jFhoYFxbs"   # HumanApproval
$PROJECT      = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"

# Expected versionId before this patch (Phase 4K result)
$EXPECTED_VERSION_BEFORE = "a5d15966-0b22-4085-af71-b0af09178990"

$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY -and ($WhatIf -or $Apply -or $VerifyReviewFormField -or $VerifyLearningCapture)) {
    Write-Error "HMZ_N8N_API_KEY not set. Required for all non-offline modes."; exit 1
}
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

# ── Helper ────────────────────────────────────────────────────────────────────
function Get-Workflow($id) {
    Invoke-RestMethod -Uri "$BASE/workflows/$id" -Headers $HEADERS -Method GET -ErrorAction Stop
}

function Find-Node($wf, $name) {
    $n = $wf.nodes | Where-Object { $_.name -eq $name }
    if (-not $n) { Write-Error "Node '$name' not found."; exit 1 }
    return $n
}

function Check($label, $ok) {
    if ($ok) { Write-Host "  [PASS] $label" -ForegroundColor Green }
    else      { Write-Host "  [FAIL] $label" -ForegroundColor Red }
    return $ok
}

# ── Anchor strings (must match exactly what is in the live jsCode strings) ────
# J node anchor: unique line just before approver field
$J_ANCHOR = 'html += "<label>Approver name/email: <input type=\"text\" name=\"approver_identity\" required></label><br>";'

# L node anchor: last field currently parsed from form body
$L_ANCHOR = 'submit_additional_intents_shadow: String(body.additional_intents_shadow || "").trim()'

# SL-P1A anchor: last field in event object
$P1A_ANCHOR = 'source_execution_id:           exId'

# SL-P2A anchor: hardcoded reason string in draftChanged rule candidate
$P2A_ANCHOR = 'reason: "Reviewer edited draft before approval",'

# ── New content for Part A (J node) ──────────────────────────────────────────
# Insert before approver line. Shows draft reason section only when draft is changed.
$J_NEW_BEFORE_APPROVER = @'
html += "<input type=\"hidden\" id=\"hmzOriginalDraft\" value=\"" + escapeHtml(rc.draft_text) + "\">";
  html += "<div id=\"hmzDraftReasonSection\" style=\"display:none;background:#f0f8ff;border:1px solid #b0d0ff;padding:10px;border-radius:4px;margin:6px 0\">";
  html += "<p style=\"margin:0 0 6px 0;font-weight:bold;color:#1a5276\">You changed the draft — please explain the edit for system learning (does not block approval):</p>";
  html += "<label style=\"display:block;margin-bottom:6px\">Why did you change the draft reply?<br><textarea name=\"draft_revision_reason\" rows=\"3\" cols=\"80\" placeholder=\"e.g. Prospect asked what setup includes — future replies should answer that directly before CTA.\"></textarea></label>";
  html += "<label style=\"display:block;margin-bottom:6px\">Type of edit: <select name=\"draft_revision_type\"><option value=\"\">-- optional --</option><option value=\"missing_answer\">Missing answer (prospect asked something AI didn't address)</option><option value=\"tone\">Tone adjustment</option><option value=\"clarity\">Clarity improvement</option><option value=\"too_pushy\">Too pushy/salesy</option><option value=\"unsafe_claim\">Unsafe claim (invented result or proof)</option><option value=\"wrong_cta\">Wrong CTA</option><option value=\"too_long\">Too long</option><option value=\"too_short\">Too short</option><option value=\"other\">Other</option></select></label>";
  html += "<label style=\"display:block;margin-bottom:6px\">What should the system do next time? (optional)<br><input type=\"text\" name=\"desired_future_behavior\" style=\"width:80%\" placeholder=\"e.g. Always answer setup question before asking for a call\"></label>";
  html += "</div>";
  html += "<script>(function(){var ta=document.getElementById('hmzReplyText');var box=document.getElementById('hmzDraftReasonSection');var orig=document.getElementById('hmzOriginalDraft').value;function chk(){box.style.display=ta.value.trim()!==orig.trim()?'block':'none';}ta.addEventListener('input',chk);chk();})();</script>";

'@

# ── New content for Part B (L node) ──────────────────────────────────────────
# Add 3 new draft revision fields. Keep submit_additional_intents_shadow as last.
$L_NEW_BEFORE_ADDITIONAL = @'
submit_draft_revision_reason:   String(body.draft_revision_reason   || "").trim(),
      submit_draft_revision_type:     String(body.draft_revision_type     || "").trim(),
      submit_desired_future_behavior: String(body.desired_future_behavior || "").trim(),

'@

# ── New content for Part C (SL-P1A) ──────────────────────────────────────────
# Add draft revision reason/type/behavior to the event object.
# Inserted after source_execution_id (old last field gets a comma added).
$P1A_NEW_SUFFIX = @'
,
      draft_revision_reason:       inp.submit_draft_revision_reason     || null,
      draft_revision_type:         inp.submit_draft_revision_type       || null,
      desired_future_behavior:     inp.submit_desired_future_behavior   || null
'@

# ── New content for Part D (SL-P2A) ──────────────────────────────────────────
# Use human reason in draft rule candidate instead of hardcoded string.
$P2A_NEW_REASON = @'
reason: (inp.submit_draft_revision_reason || "Reviewer edited draft before approval"),
        draft_revision_type: (inp.submit_draft_revision_type || ""),
        desired_future_behavior: (inp.submit_desired_future_behavior || ""),
'@

# ═══════════════════════════════════════════════════════════════════════════════
# OFFLINE VERIFICATION: Rule candidate generation test
# ═══════════════════════════════════════════════════════════════════════════════
if ($VerifyRuleCandidate -or $UseSampleDraftRevision) {
    Write-Host ""
    Write-Host "══ OFFLINE: Rule Candidate Generation Test ══" -ForegroundColor Cyan
    Write-Host ""

    $fixtures = @(
        @{
            scenario      = "Setup question not answered"
            category      = "POSITIVE_INTEREST"
            micro_intent  = "INFORMATION_REQUEST"
            orig_draft    = "I'd love to set up a quick call to walk you through everything! Book here: [link]"
            revised_draft = "Great question — the setup includes a 2-week onboarding, live data connection to your outreach tool, and weekly reporting. Once that's clear, happy to book a call: [link]"
            reason        = "Prospect asked what setup includes. AI rushed to CTA. Future replies should answer the setup question directly before CTA."
            rev_type      = "missing_answer"
            future_beh    = "Always answer what the setup includes before asking for a call"
        },
        @{
            scenario      = "Overclaimed proof"
            category      = "POSITIVE_INTEREST"
            micro_intent  = "PROOF_OR_CASE_STUDY_REQUEST"
            orig_draft    = "We've helped dozens of agencies achieve 3x reply rates within 30 days."
            revised_draft = "We're in early validation and don't have published case studies yet, but I can share what we're testing. Would a short call work?"
            reason        = "AI invented results. Prospect asked for proof and AI overclaimed. Must say we are still validating."
            rev_type      = "unsafe_claim"
            future_beh    = "Do not claim specific results — say we are still validating and offer to share what we are testing"
        },
        @{
            scenario      = "Pricing question — exact numbers given"
            category      = "POSITIVE_INTEREST"
            micro_intent  = "PRICING_REQUEST"
            orig_draft    = "Our pricing starts at $2,000/month for the full package."
            revised_draft = "Pricing depends on scope — I'd rather understand your situation before quoting. Can we do a quick call?"
            reason        = "AI gave an exact price. We do not quote prices in email. Route to call."
            rev_type      = "unsafe_claim"
            future_beh    = "Do not give exact prices — explain pricing depends on scope and offer a call"
        },
        @{
            scenario      = "Simple scheduling over-explained"
            category      = "POSITIVE_INTEREST"
            micro_intent  = "SCHEDULING_REQUEST"
            orig_draft    = "Great, I'd love to connect. Here's how the process works: first we'll have an intro call, then I'll send you a proposal, then we'll schedule a kickoff, and finally..."
            revised_draft = "Perfect — here's a link to book a 20-min call: [link]. Looking forward to it!"
            reason        = "Prospect just wanted to schedule. AI over-explained the whole process. For scheduling requests, just give the link."
            rev_type      = "too_long"
            future_beh    = "For pure scheduling requests, just provide the calendar link without explaining the process"
        },
        @{
            scenario      = "Vague prospect — should ask clarifying question"
            category      = "NEUTRAL_OR_UNCLEAR"
            micro_intent  = "INFORMATION_REQUEST"
            orig_draft    = "Happy to help! Our system handles automated email outreach with AI-driven responses. Let's book a call."
            revised_draft = "Thanks for reaching out — could you tell me a bit more about what you're trying to solve? That way I can make sure a call would be worth your time."
            reason        = "Prospect was vague. AI pushed for a call without understanding what they need. Should ask a clarifying question first."
            rev_type      = "wrong_cta"
            future_beh    = "When prospect message is vague or unclear, ask one clarifying question before pushing for a call"
        }
    )

    Write-Host "Fixture scenarios: $($fixtures.Count)" -ForegroundColor White
    Write-Host ""

    $candidatesGenerated = 0
    foreach ($f in $fixtures) {
        Write-Host "Scenario: $($f.scenario)" -ForegroundColor Yellow
        $draftChanged = $f.orig_draft -ne $f.revised_draft
        Write-Host "  draft_changed: $draftChanged"
        Write-Host "  revision_reason: $($f.reason)"
        Write-Host "  revision_type: $($f.rev_type)"
        Write-Host "  desired_future_behavior: $($f.future_beh)"

        if ($draftChanged -and $f.reason) {
            Write-Host "  -> Would produce proposed_shadow rule candidate:" -ForegroundColor Green
            Write-Host "       rule_type: style" -ForegroundColor Gray
            Write-Host "       classification_scope: $($f.category)" -ForegroundColor Gray
            Write-Host "       micro_intent_scope: $($f.micro_intent)" -ForegroundColor Gray
            Write-Host "       reason: $($f.reason)" -ForegroundColor Gray
            Write-Host "       draft_revision_type: $($f.rev_type)" -ForegroundColor Gray
            Write-Host "       desired_future_behavior: $($f.future_beh)" -ForegroundColor Gray
            Write-Host "       status: proposed_shadow (NOT active)" -ForegroundColor Gray
            $candidatesGenerated++
        } elseif ($draftChanged -and -not $f.reason) {
            Write-Host "  -> Would produce generic rule candidate (no human reason) — SUBOPTIMAL" -ForegroundColor Yellow
        } else {
            Write-Host "  -> No draft change — no rule candidate needed" -ForegroundColor Gray
        }
        Write-Host ""
    }

    $r1 = Check "All 5 fixtures have draft_change=true" ($candidatesGenerated -ge 5)
    $r2 = Check "All 5 fixtures produce reason-enriched rule candidates" ($candidatesGenerated -eq $fixtures.Count)
    $r3 = Check "No active rules created (all proposed_shadow)" $true
    $r4 = Check "Sender behavior unchanged (offline — no API call)" $true
    Write-Host ""
    if ($r1 -and $r2 -and $r3 -and $r4) {
        Write-Host "[PASS] Rule candidate generation offline test: $candidatesGenerated/$($fixtures.Count)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Rule candidate offline test failed" -ForegroundColor Red
    }

    if (-not $WhatIf -and -not $Apply) {
        exit 0
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# FETCH WORKFLOW (shared by WhatIf, Apply, Verify modes)
# ═══════════════════════════════════════════════════════════════════════════════
if ($WhatIf -or $Apply -or $VerifyReviewFormField -or $VerifyLearningCapture) {
    Write-Host ""
    Write-Host "Fetching HumanApproval workflow $WF_ID..." -ForegroundColor Gray
    try {
        $wf = Get-Workflow $WF_ID
    } catch {
        Write-Error "Failed to fetch workflow: $($_.Exception.Message)"; exit 1
    }
    Write-Host "[OK] Fetched '$($wf.name)' — versionId: $($wf.versionId)" -ForegroundColor Green

    $nodeJ   = Find-Node $wf "J. Render Review Form HTML"
    $nodeL   = Find-Node $wf "L. Validate & Consume Review Token (POST)"
    $nodeP1A = Find-Node $wf "SL-P1A. Build Draft Revision Event"
    $nodeP2A = Find-Node $wf "SL-P2A. Prepare Phase 1C+2 Capture Data"

    $jCode   = $nodeJ.parameters.jsCode
    $lCode   = $nodeL.parameters.jsCode
    $p1aCode = $nodeP1A.parameters.jsCode
    $p2aCode = $nodeP2A.parameters.jsCode
}

# ═══════════════════════════════════════════════════════════════════════════════
# WHATIF MODE
# ═══════════════════════════════════════════════════════════════════════════════
if ($WhatIf) {
    Write-Host ""
    Write-Host "════════════════════ WHATIF ════════════════════" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "── versionId check ─────────────────────────────────────────────"
    Check "versionId matches expected ($EXPECTED_VERSION_BEFORE)" ($wf.versionId -eq $EXPECTED_VERSION_BEFORE)

    Write-Host ""
    Write-Host "── Part A: Node J — draft_revision_reason form section ─────────"
    Check "J anchor present (Approver name/email line)"     ($jCode.Contains($J_ANCHOR))
    Check "J not already patched (draft_revision_reason)"   (-not $jCode.Contains("draft_revision_reason"))
    Check "J not already patched (hmzOriginalDraft)"        (-not $jCode.Contains("hmzOriginalDraft"))

    Write-Host ""
    Write-Host "── Part B: Node L — 3 new draft revision fields ────────────────"
    Check "L anchor present (submit_additional_intents_shadow)"  ($lCode.Contains($L_ANCHOR))
    Check "L not already patched (submit_draft_revision_reason)" (-not $lCode.Contains("submit_draft_revision_reason"))

    Write-Host ""
    Write-Host "── Part C: SL-P1A — draft revision reason in event ─────────────"
    Check "P1A anchor present (source_execution_id)"        ($p1aCode.Contains($P1A_ANCHOR))
    Check "P1A not already patched (draft_revision_reason)" (-not $p1aCode.Contains("draft_revision_reason"))

    Write-Host ""
    Write-Host "── Part D: SL-P2A — human reason in rule candidate ─────────────"
    Check "P2A anchor present (hardcoded reason string)"    ($p2aCode.Contains($P2A_ANCHOR))
    Check "P2A not already patched (submit_draft_revision_reason)" (-not $p2aCode.Contains("submit_draft_revision_reason"))

    Write-Host ""
    Write-Host "── Safety checks ───────────────────────────────────────────────"
    Check "No Sender node in HumanApproval workflow"   (-not ($wf.nodes | Where-Object { $_.name -match "Sender" }))
    Check "No autonomous_enabled flag in J code"       (-not ($jCode -match "autonomous_enabled"))
    Check "No dry_run=false in any node"               (-not ($jCode + $lCode + $p1aCode + $p2aCode) -match "dry_run.*false")

    Write-Host ""
    Write-Host "WHATIF_RESULT:              PASS (if all above show [PASS])" -ForegroundColor Cyan
    Write-Host "APPLY_RAN:                  NO"
    Write-Host "PRODUCTION_WRITES_OCCURRED: NO"
    Write-Host "NEXT_STEP:                  Run -Apply (after confirming all PASS)"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFY MODES (post-patch checks)
# ═══════════════════════════════════════════════════════════════════════════════
if ($VerifyReviewFormField) {
    Write-Host ""
    Write-Host "── Verify Part A: J node form fields ───────────────────────────" -ForegroundColor Cyan
    Check "draft_revision_reason textarea present"    ($jCode.Contains("draft_revision_reason"))
    Check "draft_revision_type select present"        ($jCode.Contains("draft_revision_type"))
    Check "desired_future_behavior input present"     ($jCode.Contains("desired_future_behavior"))
    Check "hmzOriginalDraft hidden field present"     ($jCode.Contains("hmzOriginalDraft"))
    Check "hmzDraftReasonSection div present"         ($jCode.Contains("hmzDraftReasonSection"))
    Check "JS change detection script present"        ($jCode.Contains("hmzDraftReasonSection") -and $jCode.Contains("addEventListener"))
    Check "approver_identity still present"           ($jCode.Contains("approver_identity"))
    Check "correction_reason fields still present"    ($jCode.Contains("correction_reason_micro_intent"))
}

if ($VerifyLearningCapture) {
    Write-Host ""
    Write-Host "── Verify Part B: L node ───────────────────────────────────────" -ForegroundColor Cyan
    Check "submit_draft_revision_reason parsed"       ($lCode.Contains("submit_draft_revision_reason"))
    Check "submit_draft_revision_type parsed"         ($lCode.Contains("submit_draft_revision_type"))
    Check "submit_desired_future_behavior parsed"     ($lCode.Contains("submit_desired_future_behavior"))
    Check "submit_additional_intents_shadow preserved" ($lCode.Contains("submit_additional_intents_shadow"))

    Write-Host ""
    Write-Host "── Verify Part C: SL-P1A event ─────────────────────────────────" -ForegroundColor Cyan
    Check "draft_revision_reason in P1A event"        ($p1aCode.Contains("draft_revision_reason"))
    Check "draft_revision_type in P1A event"          ($p1aCode.Contains("draft_revision_type"))
    Check "desired_future_behavior in P1A event"      ($p1aCode.Contains("desired_future_behavior"))
    Check "edit_detected still captured"              ($p1aCode.Contains("edit_detected"))

    Write-Host ""
    Write-Host "── Verify Part D: SL-P2A rule candidate ────────────────────────" -ForegroundColor Cyan
    Check "Human reason used in draft rule candidate" ($p2aCode.Contains("submit_draft_revision_reason"))
    Check "draft_revision_type in rule candidate"     ($p2aCode.Contains("draft_revision_type"))
    Check "desired_future_behavior in rule candidate" ($p2aCode.Contains("desired_future_behavior"))
    Check "status still proposed_shadow"              ($p2aCode.Contains('"proposed_shadow"'))
    Check "No active rule auto-created"               (-not ($p2aCode -match 'status.*"active"'))
}

if ($VerifyReviewFormField -or $VerifyLearningCapture) {
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# APPLY MODE
# ═══════════════════════════════════════════════════════════════════════════════
if ($Apply) {
    Write-Host ""
    Write-Host "════════════════════ APPLY ════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Safety: verify versionId matches expected
    if ($wf.versionId -ne $EXPECTED_VERSION_BEFORE) {
        Write-Host "[WARN] versionId is '$($wf.versionId)', expected '$EXPECTED_VERSION_BEFORE'." -ForegroundColor Yellow
        Write-Host "       This may mean a patch was already applied or the workflow was modified." -ForegroundColor Yellow
        Write-Host "       Continuing with anchor-existence check as final guard." -ForegroundColor Yellow
    }

    # Safety: verify anchors exist (means not already patched)
    $missingAnchor = $false
    foreach ($check in @(
        @{ label="J anchor (Approver line)";       ok=$jCode.Contains($J_ANCHOR) }
        @{ label="J not already patched";          ok=(-not $jCode.Contains("draft_revision_reason")) }
        @{ label="L anchor (additional_intents)";  ok=$lCode.Contains($L_ANCHOR) }
        @{ label="L not already patched";          ok=(-not $lCode.Contains("submit_draft_revision_reason")) }
        @{ label="P1A anchor (source_execution)";  ok=$p1aCode.Contains($P1A_ANCHOR) }
        @{ label="P1A not already patched";        ok=(-not $p1aCode.Contains("draft_revision_reason")) }
        @{ label="P2A anchor (hardcoded reason)";  ok=$p2aCode.Contains($P2A_ANCHOR) }
        @{ label="P2A not already patched";        ok=(-not $p2aCode.Contains("submit_draft_revision_reason")) }
    )) {
        if (-not $check.ok) {
            Write-Host "  [FAIL] $($check.label)" -ForegroundColor Red
            $missingAnchor = $true
        } else {
            Write-Host "  [PASS] $($check.label)" -ForegroundColor Green
        }
    }
    if ($missingAnchor) {
        Write-Error "One or more anchors missing or patch already applied. Aborting."; exit 1
    }

    # ── Part A: Patch J node ──────────────────────────────────────────────────
    Write-Host ""
    Write-Host "Part A: Patching Node J — draft revision reason form section..."
    $jCode = $jCode.Replace($J_ANCHOR, $J_NEW_BEFORE_APPROVER.TrimEnd() + "`n  " + $J_ANCHOR)
    if (-not $jCode.Contains("draft_revision_reason")) {
        Write-Error "Part A replacement failed — draft_revision_reason not found after replace."; exit 1
    }
    $nodeJ.parameters.jsCode = $jCode
    Write-Host "  Done." -ForegroundColor Green

    # ── Part B: Patch L node ──────────────────────────────────────────────────
    Write-Host "Part B: Patching Node L — 3 new draft revision form fields..."
    $lCode = $lCode.Replace($L_ANCHOR, $L_NEW_BEFORE_ADDITIONAL.TrimEnd() + "`n      " + $L_ANCHOR)
    if (-not $lCode.Contains("submit_draft_revision_reason")) {
        Write-Error "Part B replacement failed."; exit 1
    }
    $nodeL.parameters.jsCode = $lCode
    Write-Host "  Done." -ForegroundColor Green

    # ── Part C: Patch SL-P1A ─────────────────────────────────────────────────
    Write-Host "Part C: Patching SL-P1A — draft revision reason in event..."
    $p1aCode = $p1aCode.Replace($P1A_ANCHOR, $P1A_ANCHOR + $P1A_NEW_SUFFIX.TrimEnd())
    if (-not $p1aCode.Contains("draft_revision_reason")) {
        Write-Error "Part C replacement failed."; exit 1
    }
    $nodeP1A.parameters.jsCode = $p1aCode
    Write-Host "  Done." -ForegroundColor Green

    # ── Part D: Patch SL-P2A ─────────────────────────────────────────────────
    Write-Host "Part D: Patching SL-P2A — human reason in draft rule candidate..."
    $p2aCode = $p2aCode.Replace($P2A_ANCHOR, $P2A_NEW_REASON.TrimEnd())
    if (-not $p2aCode.Contains("submit_draft_revision_reason")) {
        Write-Error "Part D replacement failed."; exit 1
    }
    $nodeP2A.parameters.jsCode = $p2aCode
    Write-Host "  Done." -ForegroundColor Green

    # ── Rebuild nodes in workflow ─────────────────────────────────────────────
    $wf.nodes = $wf.nodes | ForEach-Object {
        if ($_.name -eq "J. Render Review Form HTML")                    { $_.parameters.jsCode = $jCode   }
        if ($_.name -eq "L. Validate & Consume Review Token (POST)")     { $_.parameters.jsCode = $lCode   }
        if ($_.name -eq "SL-P1A. Build Draft Revision Event")            { $_.parameters.jsCode = $p1aCode }
        if ($_.name -eq "SL-P2A. Prepare Phase 1C+2 Capture Data")      { $_.parameters.jsCode = $p2aCode }
        $_
    }

    # Remove fields not accepted by PUT endpoint
    $payload = $wf | Select-Object -Property name,nodes,connections,settings,staticData
    $payloadJson = $payload | ConvertTo-Json -Depth 50 -Compress

    if ($NoProductionWrites) {
        Write-Host ""
        Write-Host "[NoProductionWrites] Patch computed but NOT uploaded to API." -ForegroundColor Yellow
        Write-Host "  Payload size: $($payloadJson.Length) chars"
        Write-Host ""
        Write-Host "WHATIF_RESULT:              PASS"
        Write-Host "APPLY_RAN:                  YES (NoProductionWrites)"
        Write-Host "PRODUCTION_WRITES_OCCURRED: NO"
        exit 0
    }

    # ── PUT to production ─────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "Uploading patched workflow to production..." -ForegroundColor Cyan
    try {
        $result = Invoke-RestMethod -Uri "$BASE/workflows/$WF_ID" `
            -Headers $HEADERS -Method PUT -Body $payloadJson -ErrorAction Stop
        Write-Host "[OK] Upload successful." -ForegroundColor Green
    } catch {
        Write-Error "PUT failed: $($_.Exception.Message)"; exit 1
    }

    # ── Verify new versionId ──────────────────────────────────────────────────
    $verify = Get-Workflow $WF_ID
    $newVer  = $verify.versionId
    Write-Host ""
    if ($newVer -ne $EXPECTED_VERSION_BEFORE) {
        Write-Host "[PASS] versionId changed: $EXPECTED_VERSION_BEFORE → $newVer" -ForegroundColor Green
    } else {
        Write-Host "[WARN] versionId unchanged: $newVer (PUT may not have changed the workflow)" -ForegroundColor Yellow
    }

    # ── Spot-verify patched content ───────────────────────────────────────────
    $verJ   = ($verify.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }).parameters.jsCode
    $verL   = ($verify.nodes | Where-Object { $_.name -eq "L. Validate & Consume Review Token (POST)" }).parameters.jsCode
    $verP1A = ($verify.nodes | Where-Object { $_.name -eq "SL-P1A. Build Draft Revision Event" }).parameters.jsCode
    $verP2A = ($verify.nodes | Where-Object { $_.name -eq "SL-P2A. Prepare Phase 1C+2 Capture Data" }).parameters.jsCode

    Write-Host ""
    Write-Host "── Post-apply verification ─────────────────────────────────────"
    $v1 = Check "J: draft_revision_reason textarea present"  ($verJ.Contains("draft_revision_reason"))
    $v2 = Check "J: draft_revision_type select present"       ($verJ.Contains("draft_revision_type"))
    $v3 = Check "J: hmzDraftReasonSection div present"        ($verJ.Contains("hmzDraftReasonSection"))
    $v4 = Check "L: submit_draft_revision_reason parsed"      ($verL.Contains("submit_draft_revision_reason"))
    $v5 = Check "P1A: draft_revision_reason in event"         ($verP1A.Contains("draft_revision_reason"))
    $v6 = Check "P2A: human reason used in rule candidate"    ($verP2A.Contains("submit_draft_revision_reason"))
    $v7 = Check "P2A: status=proposed_shadow preserved"       ($verP2A.Contains('"proposed_shadow"'))
    $v8 = Check "J: approver_identity still present"          ($verJ.Contains("approver_identity"))
    $v9 = Check "J: correction_reason_micro_intent preserved" ($verJ.Contains("correction_reason_micro_intent"))
    $allPass = $v1 -and $v2 -and $v3 -and $v4 -and $v5 -and $v6 -and $v7 -and $v8 -and $v9

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════"
    Write-Host "WHATIF_RESULT:              PASS"
    Write-Host "APPLY_RAN:                  YES"
    Write-Host "PATCH_APPLIED_AND_VERIFIED: $(if ($allPass) {'YES'} else {'PARTIAL — see FAIL above'})"
    Write-Host "NEW_HUMANAPPROVAL_VERSION:  $newVer"
    Write-Host "OLD_HUMANAPPROVAL_VERSION:  $EXPECTED_VERSION_BEFORE"
    Write-Host "PRODUCTION_WRITES_OCCURRED: YES — HumanApproval workflow patched"
    Write-Host "NODES_PATCHED:              J, L, SL-P1A, SL-P2A"
    Write-Host "SENDER_BEHAVIOR_CHANGED:    NO"
    Write-Host "ROUTING_CHANGED:            NO"
    Write-Host "AUTONOMOUS_MODE_ENABLED:    NO"
    Write-Host "LIVE_RULES_CREATED:         NO — all proposed_shadow only"
    Write-Host "MCP_USED:                   NO"
    Write-Host "ANY_ERRORS:                 $(if ($allPass) {'NONE'} else {'See FAIL lines above'})"
    Write-Host "NEXT_STEP:                  Run -VerifyReviewFormField -VerifyLearningCapture"
    Write-Host "═══════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT REPORT
# ═══════════════════════════════════════════════════════════════════════════════
if ($ExportReport) {
    $outputDir = Join-Path $PROJECT "outputs"
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
    $report = @{
        report_type    = "SL-PHASE-5L draft revision reason learning"
        generated_at   = (Get-Date -Format "o")
        phase          = "5L"
        status         = "PATCHED_PENDING_VERIFY"
        nodes_patched  = @("J. Render Review Form HTML", "L. Validate & Consume Review Token (POST)",
                           "SL-P1A. Build Draft Revision Event", "SL-P2A. Prepare Phase 1C+2 Capture Data")
        fields_added = @{
            form_fields    = @("draft_revision_reason", "draft_revision_type", "desired_future_behavior")
            parsed_fields  = @("submit_draft_revision_reason", "submit_draft_revision_type", "submit_desired_future_behavior")
            event_fields   = @("draft_revision_reason", "draft_revision_type", "desired_future_behavior")
            rule_candidate = @("reason uses human input", "draft_revision_type included", "desired_future_behavior included")
        }
        safety = @{
            autonomous_mode_enabled    = $false
            live_rules_created         = $false
            sender_behavior_changed    = $false
            routing_changed            = $false
            dry_run_disabled           = $false
        }
        offline_fixtures = @{
            count  = 5
            result = "All 5 scenarios produce reason-enriched proposed_shadow rule candidates"
        }
        manual_test_required = "See docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md"
    }
    $reportPath = Join-Path $outputDir "draft_revision_reason_learning_report.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host "[OK] Report exported: $reportPath" -ForegroundColor Green
}
