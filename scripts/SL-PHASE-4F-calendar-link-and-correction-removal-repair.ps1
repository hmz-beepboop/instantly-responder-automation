<#
.SYNOPSIS
SL-PHASE-4F: Calendar link fix, primary classification removal feedback, and editable additional intents comparison.

.DESCRIPTION
Patches:
  Decision  tgYmY97CG4Bm8snI  Node D  — Part A: calendar link fix
  HumanApproval 9aPrt92jFhoYFxbs  Node J  — Parts B+C: help text updates
  HumanApproval 9aPrt92jFhoYFxbs  SL-P2A  — Parts B+C: removal feedback + additional intents comparison

Part A  — Fix empty calendar link in AI supervised drafts:
  Root cause: bookingLink=null (SENDER_CONFIG empty) → '' after replace → _ctaRx regex missed "book time here" (no "a").
  Fix 1: Change bookingLink||'' to bookingLink||'<HARDCODED>' so AI <<bookingLink>> always resolves.
  Fix 2: Broaden _ctaRx to also match "book time" (without "a").

Part B  — Primary classification removal feedback:
  If reviewer blanks corrected_broad_category + gives correction_reason → remove_association_feedback (not blank live routing).
  If reviewer blanks corrected_micro_intent + gives correction_reason → remove_primary_micro_intent_association feedback.
  Empty fields with empty reason = no_change.
  effectCat/effectMi always fall back to originals (never blank).

Part C  — Editable additional intents comparison:
  Parse original vs submitted additional intents.
  Compute added/removed/final.
  Removals with reason → negative learning rule candidates.
  Additions → positive learning rule candidates.
  Does NOT affect routing or active AI.

.PARAMETER WhatIf
Dry-run: verify all patch targets exist, no changes made.

.PARAMETER Apply
Execute the patch and verify live versionIds changed.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: -WhatIf  (dry-run check)  or  -Apply  (execute patch)"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) { Write-Error "HMZ_N8N_API_KEY not set"; exit 1 }
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$WF_DECISION      = "tgYmY97CG4Bm8snI"
$WF_HUMANAPPROVAL = "9aPrt92jFhoYFxbs"

$BOOKING_LINK = "https://calendar.app.google/bNXWJkS3xz3yqdW36"

# ─── helper ───────────────────────────────────────────────────────────────────
function Get-Workflow($id) {
    Invoke-RestMethod -Uri "$BASE/workflows/$id" -Headers $HEADERS -Method GET
}
function Put-Workflow($id, $wf) {
    $slim = @{
        name        = $wf.name
        nodes       = $wf.nodes
        connections = $wf.connections
        settings    = $wf.settings
        staticData  = $wf.staticData
    }
    $body = $slim | ConvertTo-Json -Depth 20 -Compress
    Invoke-RestMethod -Uri "$BASE/workflows/$id" -Method PUT -Headers $HEADERS -Body $body -ContentType "application/json"
}
function Find-Node($wf, $nameLike) {
    $n = $wf.nodes | Where-Object { $_.name -like $nameLike }
    if (-not $n) { throw "Node not found matching '$nameLike' in workflow $($wf.id)" }
    $n
}

$pass = 0
$fail = 0
function Check($label, $expr) {
    if ($expr) { Write-Host "  [PASS] $label"; $script:pass++ }
    else        { Write-Host "  [FAIL] $label"; $script:fail++ }
}

Write-Host ""
Write-Host "=== SL-PHASE-4F WhatIf/Apply ==="
Write-Host "Mode: $(if ($WhatIf) { 'WhatIf (dry-run)' } else { 'Apply' })"
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# FETCH BOTH WORKFLOWS
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "Fetching Decision workflow $WF_DECISION..."
$decWf = Get-Workflow $WF_DECISION
$decVersionBefore = $decWf.versionId
Write-Host "  versionId: $decVersionBefore"

Write-Host "Fetching HumanApproval workflow $WF_HUMANAPPROVAL..."
$haWf = Get-Workflow $WF_HUMANAPPROVAL
$haVersionBefore = $haWf.versionId
Write-Host "  versionId: $haVersionBefore"

# ═══════════════════════════════════════════════════════════════════════════════
# PART A — NODE D: CALENDAR LINK FIX
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Part A: Node D calendar link fix ---"

$nodeD = Find-Node $decWf "D.*Draft*"
Write-Host "  Node: $($nodeD.name)"
$dCode = $nodeD.parameters.jsCode

# Fix 1: change bookingLink||'' to bookingLink||'<HARDCODED>'
$q = "'"
$A_OLD1 = ".replace(/<<bookingLink>>/g, bookingLink || $q$q)"
$A_NEW1 = ".replace(/<<bookingLink>>/g, bookingLink || ${q}$BOOKING_LINK${q})"

# Fix 2: broaden _ctaRx regex (add optional "a" before "time")
$A_OLD2 = 'book(?:\s+a\s+time)?'
$A_NEW2 = 'book(?:\s+(?:a\s+)?time)?'

Check "A1 target found (bookingLink||'')" ($dCode.Contains($A_OLD1))
Check "A2 target found (_ctaRx with a\\s+time)" ($dCode.Contains($A_OLD2))
Check "A hardcoded BOOKING_LINK already present" ($dCode.Contains($BOOKING_LINK))

# ═══════════════════════════════════════════════════════════════════════════════
# PART B+C — NODE J: HELP TEXT UPDATES
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Parts B+C: Node J help text updates ---"

$nodeJ = Find-Node $haWf "J.*Render*"
Write-Host "  Node: $($nodeJ.name)"
$jCode = $nodeJ.parameters.jsCode

# Part B: primary classification removal help text
$B_OLD = "Leave corrected fields blank to preserve original classification. To correct, enter a replacement value — do not blank fields to remove a classification."
$B_NEW = "To remove an incorrect classification association, clear the field and explain why below. This creates removal feedback but does not blank the live routing category. To correct a misclassification, enter the replacement value. If both fields are blank with no reason, no change is recorded."

# Part C: additional intents help text
$C_OLD = "Use this if the prospect asks more than one thing. This does not affect routing, drafting, or sending yet."
$C_NEW = "Add, remove, or replace additional classifications. Removals with a reason create negative learning feedback. Additions create positive learning feedback. Does not affect routing or sending."

Check "B target found (classification help text)" ($jCode.Contains($B_OLD))
Check "C target found (additional intents help text)" ($jCode.Contains($C_OLD))

# ═══════════════════════════════════════════════════════════════════════════════
# PART B+C — NODE SL-P2A: REMOVAL FEEDBACK + ADDITIONAL INTENTS COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Parts B+C: Node SL-P2A code replacement ---"

$nodeP2A = Find-Node $haWf "SL-P2A*"
Write-Host "  Node: $($nodeP2A.name)"
$p2aCode = $nodeP2A.parameters.jsCode

# Verify unique markers before replacement
$P2A_MARKER1 = 'const classChanged = catChanged || miChanged;'
$P2A_MARKER2 = 'sl_p2_additional_intents_captured: (function(){'
$P2A_MARKER3 = 'status: classChanged ? "captured_only" : (corrReason && corrCategory === "" && corrMicroIntent === "" ? "feedback_only" : "no_change"),'

Check "P2A marker 1 found (classChanged)" ($p2aCode.Contains($P2A_MARKER1))
Check "P2A marker 2 found (IIFE for additional_intents)" ($p2aCode.Contains($P2A_MARKER2))
Check "P2A marker 3 found (status line)" ($p2aCode.Contains($P2A_MARKER3))

Write-Host ""
Write-Host "=== WhatIf check results: PASS=$pass FAIL=$fail ==="

if ($fail -gt 0) {
    Write-Host "WhatIf FAILED — $fail targets not found. Do not Apply."
    exit 1
}
if ($WhatIf) {
    Write-Host "WhatIf PASSED — all $pass targets found. Safe to run -Apply."
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# APPLY
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "=== APPLYING PATCHES ==="

# --- A1: booking link empty-string fix ---
$dCode = $dCode.Replace($A_OLD1, $A_NEW1)
Write-Host "[A1] Booking link empty-string fix applied."

# --- A2: broaden _ctaRx ---
$dCode = $dCode.Replace($A_OLD2, $A_NEW2)
Write-Host "[A2] _ctaRx regex broadened (optional 'a' before 'time')."

$nodeD.parameters.jsCode = $dCode

# --- B: classification removal help text ---
$jCode = $jCode.Replace($B_OLD, $B_NEW)
Write-Host "[B] Classification removal help text updated in Node J."

# --- C: additional intents help text ---
$jCode = $jCode.Replace($C_OLD, $C_NEW)
Write-Host "[C] Additional intents help text updated in Node J."

$nodeJ.parameters.jsCode = $jCode

# --- SL-P2A: full code replacement (Parts B+C logic) ---
# New code: adds catBlanked/miBlanked, new status, removal rule candidates,
# additional intents comparison (added/removed/final), and new output fields.
$newP2ACode = @'
const items = $input.all();

function genUUID() {
  const a = new Uint8Array(16);
  if (typeof globalThis.crypto !== "undefined" && globalThis.crypto.getRandomValues) {
    globalThis.crypto.getRandomValues(a);
  } else {
    for (let i = 0; i < 16; i++) a[i] = Math.floor(Math.random() * 256);
  }
  a[6] = (a[6] & 0x0f) | 0x40;
  a[8] = (a[8] & 0x3f) | 0x80;
  const h = Array.from(a).map(b => b.toString(16).padStart(2,"0")).join("");
  return h.slice(0,8)+"-"+h.slice(8,12)+"-"+h.slice(12,16)+"-"+h.slice(16,20)+"-"+h.slice(20);
}

return items.map(item => {
  const fallbackId = "err-" + Math.random().toString(36).slice(2,14);
  try {
    const inp = item.json || {};
    const rc  = inp.review_case || {};
    const ctx = rc.sanitized_context || {};
    const rap = ctx.recommended_action_plan || {};

    const origCategory    = String(rc.category || ctx.category || "");
    const origMicroIntent = String(rap.micro_intent || ctx.micro_intent || rc.micro_intent || "");
    const origDraftText   = String(rc.draft_text || "");

    const corrCategory    = String(inp.submit_corrected_category || "").trim();
    const corrMicroIntent = String(inp.submit_corrected_micro_intent || "").trim();
    const corrReason      = String(inp.submit_correction_reason || "").trim();
    const finalText       = String(rc.final_reply_text || inp.submit_edited_text || "");

    const catChanged   = corrCategory !== "" && corrCategory !== origCategory;
    const miChanged    = corrMicroIntent !== "" && corrMicroIntent !== origMicroIntent;
    const classChanged = catChanged || miChanged;
    // Part B: removal feedback — blank field + reason means "do not associate this classification"
    const catBlanked   = corrCategory === "" && corrReason !== "";
    const miBlanked    = corrMicroIntent === "" && corrReason !== "";
    const draftChanged = finalText !== "" && finalText !== origDraftText;

    // effectCat/effectMi always fall back to originals — never blank live routing
    const effectCat = corrCategory    || origCategory;
    const effectMi  = corrMicroIntent || origMicroIntent;

    const exId = (() => { try { return $execution && $execution.id ? String($execution.id) : ""; } catch { return ""; } })();
    const nowIso = new Date().toISOString();
    const evId = genUUID();

    const corrEvent = {
      event_id: evId, timestamp: nowIso,
      case_id: String(rc.case_id || ""), intake_id: String(rc.intake_id || ""),
      old_category: origCategory, old_micro_intent: origMicroIntent,
      corrected_category: effectCat, corrected_micro_intent: effectMi,
      correction_reason: corrReason,
      reviewer_identity: String(inp.submit_approver_identity || ""),
      approval_decision: String(inp.final_action || ""),
      status: classChanged ? "captured_only" : ((catBlanked || miBlanked) ? "remove_association_feedback" : (corrReason !== "" ? "feedback_only" : "no_change")),
      source_workflow: "HMZ - Reply Human Approval - Validation",
      source_execution_id: exId
    };

    const ruleCandidates = [];

    if (classChanged) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "classification", classification_scope: effectCat, micro_intent_scope: effectMi,
        proposed_rule_text: "Classify as "+effectCat+"/"+effectMi+": see correction_reason",
        example_before: origCategory+"/"+origMicroIntent, example_after: effectCat+"/"+effectMi,
        reason: corrReason || "Reviewer classification correction",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    if (draftChanged) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "style", classification_scope: effectCat, micro_intent_scope: effectMi,
        proposed_rule_text: "Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.",
        example_before: origDraftText.slice(0,500), example_after: finalText.slice(0,500),
        reason: "Reviewer edited draft before approval",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    // Part B: primary classification removal feedback (proposed_shadow, never active)
    if (catBlanked) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "classification_removal_feedback",
        classification_scope: origCategory, micro_intent_scope: origMicroIntent,
        proposed_rule_text: "Do not associate category "+origCategory+" with similar emails. Reason: "+corrReason,
        example_before: origCategory+"/"+origMicroIntent, example_after: "[removed_category_association]",
        reason: corrReason, confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    if (miBlanked) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "micro_intent_removal_feedback",
        classification_scope: origCategory, micro_intent_scope: origMicroIntent,
        proposed_rule_text: "Do not associate micro_intent "+origMicroIntent+" with similar emails. Reason: "+corrReason,
        example_before: origCategory+"/"+origMicroIntent, example_after: "[removed_micro_intent_association]",
        reason: corrReason, confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    // Part C: additional intents comparison — parse original vs submitted, compute added/removed/final
    const _detectedIntents = (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.detected_intents) || [];
    const _origAddlIntents = _detectedIntents.map(function(i){ return String(i.micro_intent || "").trim().toUpperCase(); }).filter(Boolean);
    const _submittedAddlRaw = String(inp.submit_additional_intents_shadow || "").trim();
    const _submittedAddlIntents = _submittedAddlRaw
      ? _submittedAddlRaw.split(/[\s,+|]+/).map(function(s){ return s.trim().toUpperCase(); }).filter(Boolean)
      : [];
    const _addedIntents   = _submittedAddlIntents.filter(function(i){ return _origAddlIntents.indexOf(i) < 0; });
    const _removedIntents = _origAddlIntents.filter(function(i){ return _submittedAddlIntents.indexOf(i) < 0; });
    const _finalAddlIntents = _submittedAddlIntents;

    if (_submittedAddlRaw) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "multi_intent_shadow",
        classification_scope: effectCat, micro_intent_scope: effectMi+" | "+_submittedAddlRaw,
        proposed_rule_text: "Multi-intent email: primary="+effectMi+" additional="+_submittedAddlRaw,
        example_before: origDraftText.slice(0,500), example_after: finalText.slice(0,500),
        reason: "Reviewer noted additional intents: "+_submittedAddlRaw,
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    for (var _ri = 0; _ri < _removedIntents.length; _ri++) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "additional_intent_removal_feedback",
        classification_scope: effectCat, micro_intent_scope: _removedIntents[_ri],
        proposed_rule_text: "Do not associate additional intent "+_removedIntents[_ri]+" with similar emails. Reason: "+corrReason,
        example_before: _removedIntents[_ri], example_after: "[removed_additional_intent]",
        reason: corrReason || "Reviewer removed additional intent",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    for (var _ai2 = 0; _ai2 < _addedIntents.length; _ai2++) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "additional_intent_addition_feedback",
        classification_scope: effectCat, micro_intent_scope: _addedIntents[_ai2],
        proposed_rule_text: "Associate additional intent "+_addedIntents[_ai2]+" with similar emails.",
        example_before: "", example_after: _addedIntents[_ai2],
        reason: "Reviewer added additional intent",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    return { json: {
      ...inp,
      sl_p2_correction_event: corrEvent,
      sl_p2_rule_candidates: ruleCandidates,
      sl_p2_classification_changed: classChanged,
      sl_p2_draft_changed: draftChanged,
      sl_p2_additional_intents_captured: (_submittedAddlIntents.length > 0 || _origAddlIntents.length > 0),
      sl_p2_added_additional_intents: _addedIntents,
      sl_p2_removed_additional_intents: _removedIntents,
      sl_p2_final_additional_intents: _finalAddlIntents,
      sl_p2_capture_error: false
    }};
  } catch(e) {
    return { json: {
      ...item.json,
      sl_p2_correction_event: { event_id: fallbackId, status: "capture_error" },
      sl_p2_rule_candidates: [], sl_p2_classification_changed: false,
      sl_p2_draft_changed: false, sl_p2_capture_error: true,
      sl_p2_error_msg: String(e && e.message ? e.message : e)
    }};
  }
});
'@

$nodeP2A.parameters.jsCode = $newP2ACode
Write-Host "[P2A] SL-P2A node code replaced (catBlanked/miBlanked, removal candidates, addl intents comparison)."

# ═══════════════════════════════════════════════════════════════════════════════
# PUT WORKFLOWS
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "PUTting Decision workflow..."
$decResp = Put-Workflow $WF_DECISION $decWf
$decVersionAfter = $decResp.versionId
Write-Host "  versionId before: $decVersionBefore"
Write-Host "  versionId after:  $decVersionAfter"

Write-Host "PUTting HumanApproval workflow..."
$haResp = Put-Workflow $WF_HUMANAPPROVAL $haWf
$haVersionAfter = $haResp.versionId
Write-Host "  versionId before: $haVersionBefore"
Write-Host "  versionId after:  $haVersionAfter"

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFY
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "=== POST-APPLY VERIFICATION ==="
$pass = 0; $fail = 0

Check "Decision versionId changed"      ($decVersionAfter -ne $decVersionBefore)
Check "HumanApproval versionId changed" ($haVersionAfter  -ne $haVersionBefore)

# Re-fetch and verify Node D
$decCheck = Get-Workflow $WF_DECISION
$nodeDCheck = $decCheck.nodes | Where-Object { $_.name -like "D.*Draft*" }
$dCodeCheck = $nodeDCheck.parameters.jsCode
Check "A1 bookingLink fallback uses hardcoded URL" ($dCodeCheck.Contains("bookingLink || '$BOOKING_LINK'"))
Check "A1 old empty-string fallback gone"          (-not $dCodeCheck.Contains($A_OLD1))
Check "A2 broadened regex present"                  ($dCodeCheck.Contains($A_NEW2))

# Re-fetch and verify Node J
$haCheck = Get-Workflow $WF_HUMANAPPROVAL
$nodeJCheck = $haCheck.nodes | Where-Object { $_.name -like "J.*Render*" }
$jCodeCheck = $nodeJCheck.parameters.jsCode
Check "B new removal help text present"             ($jCodeCheck.Contains("clear the field and explain why below"))
Check "B old blank-field help text gone"            (-not $jCodeCheck.Contains("do not blank fields to remove"))
Check "C new additional intents help text present"  ($jCodeCheck.Contains("Removals with a reason create negative learning feedback"))

# Re-fetch and verify Node SL-P2A
$nodeP2ACheck = $haCheck.nodes | Where-Object { $_.name -like "SL-P2A*" }
$p2aCodeCheck = $nodeP2ACheck.parameters.jsCode
Check "P2A catBlanked defined"                      ($p2aCodeCheck.Contains("const catBlanked"))
Check "P2A miBlanked defined"                       ($p2aCodeCheck.Contains("const miBlanked"))
Check "P2A remove_association_feedback status"       ($p2aCodeCheck.Contains("remove_association_feedback"))
Check "P2A classification_removal_feedback RC"       ($p2aCodeCheck.Contains("classification_removal_feedback"))
Check "P2A micro_intent_removal_feedback RC"         ($p2aCodeCheck.Contains("micro_intent_removal_feedback"))
Check "P2A additional_intent_removal_feedback RC"    ($p2aCodeCheck.Contains("additional_intent_removal_feedback"))
Check "P2A additional_intent_addition_feedback RC"   ($p2aCodeCheck.Contains("additional_intent_addition_feedback"))
Check "P2A sl_p2_added_additional_intents field"     ($p2aCodeCheck.Contains("sl_p2_added_additional_intents"))
Check "P2A sl_p2_removed_additional_intents field"   ($p2aCodeCheck.Contains("sl_p2_removed_additional_intents"))
Check "P2A sl_p2_final_additional_intents field"     ($p2aCodeCheck.Contains("sl_p2_final_additional_intents"))
Check "P2A old IIFE for additional_intents gone"     (-not $p2aCodeCheck.Contains("sl_p2_additional_intents_captured: (function()"))
Check "P2A effectCat still falls back to origCategory" ($p2aCodeCheck.Contains("corrCategory    || origCategory"))

Write-Host ""
Write-Host "=== APPLY RESULT: PASS=$pass FAIL=$fail ==="
if ($fail -gt 0) { Write-Host "APPLY has failures — investigate before next test"; exit 1 }
Write-Host "SL-PHASE-4F Apply COMPLETE."
Write-Host "Decision  versionId: $decVersionAfter"
Write-Host "HumanApproval versionId: $haVersionAfter"
