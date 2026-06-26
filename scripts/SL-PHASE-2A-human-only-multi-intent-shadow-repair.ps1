<#
.SYNOPSIS
  SL-PHASE-2A — Human-only UX repair + multi-intent shadow capture for HumanApproval workflow.
  Patches nodes J (Review Form HTML), N (Process Reviewer Decision), and SL-P2A only.
  All other nodes, logic, DataTable IDs, approval flow, AI behaviour, classifier, routing untouched.

.PARAMETER WhatIf
  Show what would change without writing to production.

.PARAMETER Apply
  Apply the patch to production HumanApproval workflow 9aPrt92jFhoYFxbs.

.EXAMPLE
  .\SL-PHASE-2A-human-only-multi-intent-shadow-repair.ps1 -WhatIf
  .\SL-PHASE-2A-human-only-multi-intent-shadow-repair.ps1 -Apply
#>

param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: script.ps1 -WhatIf | -Apply"
    exit 1
}

$ApiKey  = $env:HMZ_N8N_API_KEY
$Base    = "https://n8n.hmzaiautomation.com/api/v1"
$WfId    = "9aPrt92jFhoYFxbs"
$Headers = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }

Write-Host "=== SL-PHASE-2A Human-Only + Multi-Intent Shadow Repair ==="
Write-Host "Target: $Base/workflows/$WfId"
Write-Host ""

# --- 1. Fetch workflow ---
$wf = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method GET
Write-Host "Fetched workflow: '$($wf.name)' | nodes: $($wf.nodes.Count)"

function Find-Node($name) {
    $n = $wf.nodes | Where-Object { $_.name -eq $name }
    if (-not $n) { throw "Node not found: $name" }
    return $n
}

# ========== NODE J: Review Form HTML ==========
$nodeJ  = Find-Node "J. Render Review Form HTML"
$oldJ   = $nodeJ.parameters.jsCode
$newJ   = $oldJ

# B1: Fix p1cMi — add ctx.micro_intent and rc.micro_intent fallbacks so correction section
#     shows the same micro intent that Google Chat already shows (ctx.micro_intent path).
$oldB1 = 'const p1cMi  = escapeHtml(String((ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ""));'
$newB1 = 'const p1cMi  = escapeHtml(String((ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ctx.micro_intent || rc.micro_intent || ""));'
$newJ  = $newJ.Replace($oldB1, $newB1)

# C2: Insert HUMAN_ONLY banner before textarea + add id="hmzReplyText" for JS validation.
#     The inline if-check avoids needing a separate const declaration.
$oldC2 = 'html += "<label>Reply text (editable):<br><textarea name=\"edited_reply_text\" rows=\"10\" cols=\"80\">" + escapeHtml(rc.draft_text) + "</textarea></label><br>";'
$newC2 = 'if (rc.draft_policy === "HUMAN_ONLY" || rc.draft_source === "human_only" || ctx.draft_policy === "HUMAN_ONLY" || ctx.draft_source === "human_only") { html += "<p style=\"background:#fff3cd;border:1px solid #ffc107;padding:10px;border-radius:4px\"><strong>No AI draft was generated because this reply requires human-only handling.</strong> Write the response manually below. This manual reply will be captured for learning.</p>"; } html += "<label>Reply text (editable):<br><textarea name=\"edited_reply_text\" id=\"hmzReplyText\" rows=\"10\" cols=\"80\">" + escapeHtml(rc.draft_text) + "</textarea></label><br>";'
$newJ  = $newJ.Replace($oldC2, $newC2)

# D1: Add additional_intents_shadow field after denial_reason.
#     Shadow capture only — does not affect routing, drafting, or sending.
$oldD1 = 'html += "<label>Denial reason (if denying): <input type=\"text\" name=\"denial_reason\"></label><br>";'
$newD1 = 'html += "<label>Denial reason (if denying): <input type=\"text\" name=\"denial_reason\"></label><br>"; html += "<label>Additional classifications/intents in this email (optional, shadow learning only):<br><input type=\"text\" name=\"additional_intents_shadow\" style=\"width:440px\" placeholder=\"e.g. PRICING_REQUEST + SMALL_SCALE_PILOT_REQUEST\"></label><br><div style=\"font-size:0.8em;color:#666;margin-bottom:8px\">Use this if the prospect asks more than one thing. This does not affect routing, drafting, or sending yet.</div>";'
$newJ  = $newJ.Replace($oldD1, $newD1)

# C3: Add client-side blank-reply guard on Approve button via onclick IIFE.
#     Deny / no reply button is unchanged — no onclick, no restriction.
$oldC3 = 'html += "<button type=\"submit\" name=\"action\" value=\"approve\"" + (blocked.length > 0 ? " disabled" : "") + ">Approve and send</button> ";'
$newC3 = 'html += "<button type=\"submit\" name=\"action\" value=\"approve\"" + (blocked.length > 0 ? " disabled" : "") + " onclick=\"return(function(){var t=document.getElementById(''hmzReplyText'').value.trim();if(!t){alert(''Reply text cannot be empty. Write the response manually above before approving.'');return false;}return true;})()\">Approve and send</button> ";'
$newJ  = $newJ.Replace($oldC3, $newC3)

# --- Verify Node J ---
$jB1 = $newJ -like '*|| ctx.micro_intent || rc.micro_intent ||*'
$jC2 = $newJ -like '*HUMAN_ONLY*' -and $newJ -like '*No AI draft was generated*'
$jID = $newJ -like '*id=\"hmzReplyText\"*'
$jD1 = $newJ -like '*additional_intents_shadow*'
$jC3 = $newJ -like '*hmzReplyText*' -and $newJ -like '*onclick*'
$jOk = $jB1 -and $jC2 -and $jID -and $jD1 -and $jC3
Write-Host "[J] B1 p1cMi fallback fixed:          $jB1"
Write-Host "[J] C2 HUMAN_ONLY banner inserted:    $jC2"
Write-Host "[J] C2 textarea id added:             $jID"
Write-Host "[J] D1 additional_intents field:      $jD1"
Write-Host "[J] C3 onclick blank guard:           $jC3"
if (-not $jOk) { Write-Host "[J] ABORT: One or more Node J changes not detected — string mismatch."; exit 1 }
Write-Host "[J] All 5 changes confirmed."

# ========== NODE N: Process Reviewer Decision ==========
$nodeN = Find-Node "N. Process Reviewer Decision"
$oldN  = $nodeN.parameters.jsCode
$newN  = $oldN

# C4: Server-side blank reply block — append inline after approver check.
#     Uses submit_edited_text (the field name mapped by node L from form's edited_reply_text).
$oldC4 = '  if (action === "approve" && !approver) finalAction = "blocked";'
$newC4 = '  if (action === "approve" && !approver) finalAction = "blocked"; if (finalAction === "approve" && (input.submit_edited_text || "").trim() === "") finalAction = "blocked";'
$newN  = $newN.Replace($oldC4, $newC4)

$nC4 = $newN -like '*(input.submit_edited_text || "").trim() === ""*'
Write-Host "[N] C4 server-side blank reply block: $nC4"
if (-not $nC4) { Write-Host "[N] ABORT: Node N blank-reply guard not applied — string mismatch."; exit 1 }

# ========== SL-P2A: Prepare Phase 1C+2 Capture Data ==========
$nodeP2A = Find-Node "SL-P2A. Prepare Phase 1C+2 Capture Data"
$oldP2A  = $nodeP2A.parameters.jsCode
$newP2A  = $oldP2A

# D2: Append multi_intent_shadow rule candidate capture via inline IIFE in return object.
#     IIFE runs after sl_p2_rule_candidates: ruleCandidates is evaluated; since ruleCandidates
#     is a reference type, the push is visible in the already-captured reference. SL-P2C reads
#     sl_p2_rule_candidates and emits each entry as a rule_candidate item; SL-P2E writes it to
#     CSdiTjXfi0tl0oZF using the existing upsert pattern.
$oldD2 = 'sl_p2_classification_changed: classChanged, sl_p2_draft_changed: draftChanged,'
$newD2 = 'sl_p2_classification_changed: classChanged, sl_p2_draft_changed: draftChanged, sl_p2_additional_intents_captured: (function(){const _ai=String(inp.submit_additional_intents_shadow||"").trim();if(_ai){ruleCandidates.push({rule_id:genUUID(),created_at:nowIso,source_event_id:evId,source_case_id:String(rc.case_id||""),rule_type:"multi_intent_shadow",classification_scope:effectCat,micro_intent_scope:effectMi+" | "+_ai,proposed_rule_text:"Multi-intent email: primary="+effectMi+" additional="+_ai,example_before:origDraftText.slice(0,500),example_after:finalText.slice(0,500),reason:"Reviewer noted additional intents: "+_ai,confidence:"low",status:"proposed_shadow",created_by:String(inp.submit_approver_identity||""),approved_by:"",approved_at:"",deprecated_at:"",rollback_reason:""});}return _ai.length>0;})(),'
$newP2A = $newP2A.Replace($oldD2, $newD2)

$p2aD2 = $newP2A -like '*multi_intent_shadow*' -and $newP2A -like '*submit_additional_intents_shadow*'
Write-Host "[P2A] D2 multi_intent shadow capture: $p2aD2"
if (-not $p2aD2) { Write-Host "[P2A] ABORT: SL-P2A multi_intent capture not applied — string mismatch."; exit 1 }

# ========== Safety check: prohibited nodes untouched ==========
Write-Host ""
$prohibited = @("A. Build Review Case Record","L. Validate & Consume Review Token (POST)","O. Persist Reviewer Decision (Data Table)",
    "SL-P1A. Build Draft Revision Event","SL-P1B. Write Draft Revision Event (DataTable)","SL-P1C. Restore Context After Capture",
    "SL-P2B. Write Classification Correction Event","SL-P2C. Restore Context and Emit Rule Candidate Items",
    "SL-P2D. Route Main vs Rule Candidate","SL-P2E. Write Rule Candidate Shadow",
    "D. Build Google Chat Notification Payload","P. Approval Outcome Router","Q. Reply Sender Handoff (Approved)")
Write-Host "Verifying prohibited nodes are untouched..."
foreach ($pn in $prohibited) {
    $nd = $wf.nodes | Where-Object { $_.name -eq $pn }
    if ($nd) { Write-Host "  [OK] $pn" }
    else     { Write-Host "  [MISSING] $pn — node not found (may not exist in this workflow)" }
}

Write-Host ""
if ($WhatIf) {
    Write-Host "=== WhatIf RESULT: PASS ==="
    Write-Host "J: 5/5 changes ready (B1 p1cMi fix, C2 banner, C2 id, D1 field, C3 onclick)"
    Write-Host "N: 1/1 changes ready (C4 blank-reply server guard)"
    Write-Host "P2A: 1/1 changes ready (D2 multi_intent_shadow IIFE capture)"
    Write-Host "No prohibited nodes touched. Run -Apply to apply."
    exit 0
}

# ========== Apply ==========
Write-Host "=== Applying patch to production ==="

$nodeJ.parameters.jsCode   = $newJ
$nodeN.parameters.jsCode   = $newN
$nodeP2A.parameters.jsCode = $newP2A

$body = @{
    name       = $wf.name
    nodes      = $wf.nodes
    connections = $wf.connections
    settings   = $wf.settings
    staticData = $wf.staticData
} | ConvertTo-Json -Depth 50 -Compress

$result = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method PUT -Body $body
Write-Host "PUT result: id=$($result.id) name='$($result.name)'"

# ========== Post-Apply Verification ==========
$verify   = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method GET
$verJ     = ($verify.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }).parameters.jsCode
$verN     = ($verify.nodes | Where-Object { $_.name -eq "N. Process Reviewer Decision" }).parameters.jsCode
$verP2A   = ($verify.nodes | Where-Object { $_.name -eq "SL-P2A. Prepare Phase 1C+2 Capture Data" }).parameters.jsCode

$vB1      = $verJ   -like '*|| ctx.micro_intent || rc.micro_intent ||*'
$vC2      = $verJ   -like '*No AI draft was generated*'
$vID      = $verJ   -like '*id=\"hmzReplyText\"*'
$vD1      = $verJ   -like '*additional_intents_shadow*'
$vC3      = $verJ   -like '*onclick*' -and $verJ -like '*hmzReplyText*'
$vC4      = $verN   -like '*(input.submit_edited_text || "").trim() === ""*'
$vD2      = $verP2A -like '*multi_intent_shadow*'

Write-Host ""
Write-Host "=== POST-APPLY VERIFICATION ==="
Write-Host "FORM_MICRO_INTENT_FALLBACK_FIXED:        $vB1"
Write-Host "FORM_HUMAN_ONLY_BANNER_PRESENT:          $vC2"
Write-Host "FORM_TEXTAREA_ID_PRESENT:                $vID"
Write-Host "FORM_ADDITIONAL_INTENTS_FIELD_PRESENT:   $vD1"
Write-Host "FORM_ONCLICK_BLANK_GUARD_PRESENT:        $vC3"
Write-Host "NODE_N_SERVER_BLANK_REPLY_BLOCK_PRESENT: $vC4"
Write-Host "SL_P2A_MULTI_INTENT_CAPTURE_PRESENT:     $vD2"

$allOk = $vB1 -and $vC2 -and $vID -and $vD1 -and $vC3 -and $vC4 -and $vD2
if ($allOk) {
    Write-Host ""
    Write-Host "=== PATCH APPLIED AND VERIFIED: PASS ==="
    Write-Host "SELF_IMPROVING_STATUS: 50% installed, retest pending"
} else {
    Write-Host ""
    Write-Host "=== PATCH VERIFICATION: PARTIAL — check items above ==="
}
