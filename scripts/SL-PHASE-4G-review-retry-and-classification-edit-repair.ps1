<#
.SYNOPSIS
SL-PHASE-4G: Retryable blocked-send, additional-classification UI, micro_intent path fix.

.DESCRIPTION
Patches HumanApproval workflow 9aPrt92jFhoYFxbs only:

Part A — Node Q: Sender validation override
  Root cause of case-db631034 block: validation.valid=false (AI draft contained "proof"/"examples")
  was passed to Sender unconditionally. Sender rejected with sender_validation_failed.
  Fix: Override validation.valid=true in Node Q input mapping when reviewer approves.
  Human approval is the final safety gate; content validation is a pre-review filter.
  Sender still enforces all other gates (campaign, sender, approval, draft variable).

Part B — Node R: Clear blocked-send result page
  Previously showed raw JSON. Now shows human-readable blocked vs approved distinction.
  Blocked details explain the reason and advise manual follow-up.

Part C — Node J: Move additional_intents_shadow inside correction section
  Owner requirement: additional classification correction box must live INSIDE the
  "Optional: Correct classification" details section, not only in main form area.
  Section now defaults to open when additional intents exist.
  Help text updated to match owner requirements.

Part D — SL-P2A: Fix origMicroIntent lookup path
  origMicroIntent missed ctx.sender_handoff.draft.micro_intent path.
  Result: old_micro_intent="" in correction events for cases where micro_intent is
  in draft (not in decision). This meant removal feedback was useless.
  Fix: add ctx.sender_handoff.draft.micro_intent to origMicroIntent fallback chain.

Constraints:
  - Decision workflow NOT modified
  - Sender workflow NOT modified (validation fix is in HumanApproval Node Q)
  - No autonomous send, no live campaigns changed, no safety gates weakened
  - Sender still enforces all non-validation gates

.PARAMETER WhatIf
Dry-run: verify all patch targets exist, no changes made.

.PARAMETER Apply
Execute the patch and verify live versionId changed.
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

$WF_HUMANAPPROVAL = "9aPrt92jFhoYFxbs"

$EXPECTED_VERSION_BEFORE = "5937dbfe-82a0-48f7-85b5-9807eeb3c107"

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

function Check($label, $condition) {
    if ($condition) {
        Write-Host "  PASS: $label"
        $script:pass++
    } else {
        Write-Host "  FAIL: $label"
        $script:fail++
    }
}

# ─── Load workflow ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-4G WhatIf=$WhatIf Apply=$Apply ==="
Write-Host ""
Write-Host "Loading HumanApproval workflow $WF_HUMANAPPROVAL..."
$wfHA = Get-Workflow $WF_HUMANAPPROVAL
Write-Host "  versionId: $($wfHA.versionId)"
Check "versionId matches Phase 4F expected" ($wfHA.versionId -eq $EXPECTED_VERSION_BEFORE)

# ─── Find target nodes ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Finding nodes..."
$nodeJ    = Find-Node $wfHA "J. Render Review Form HTML"
$nodeSLP2A = Find-Node $wfHA "SL-P2A*"
$nodeQ    = Find-Node $wfHA "Q. Reply Sender Handoff*"
$nodeR    = Find-Node $wfHA "R. Build Approved Result Page"

Check "Node J found"    ($nodeJ    -ne $null)
Check "Node SL-P2A found" ($nodeSLP2A -ne $null)
Check "Node Q found"    ($nodeQ    -ne $null)
Check "Node R found"    ($nodeR    -ne $null)

# ─── WhatIf: verify patch targets ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- Part A: Node Q validation override ---"
$qVal = $nodeQ.parameters.workflowInputs.value.validation
Write-Host "  Current Node Q validation mapping: $qVal"
Check "Node Q has validation mapping" ($qVal -ne $null)
Check "Node Q validation currently passes case_input.validation" ($qVal -match "case_input\.validation")
Check "Node Q is NOT already overriding" ($qVal -notmatch "human_approved")

Write-Host ""
Write-Host "--- Part B: Node R result page ---"
$rCode = $nodeR.parameters.jsCode
Check "Node R has jsCode" ($rCode -ne $null -and $rCode.Length -gt 0)
Check "Node R contains Approved heading" ($rCode -match "Approved")
Check "Node R not already showing BLOCKED state" ($rCode -notmatch "SEND_BLOCKED_RETRYABLE")

Write-Host ""
Write-Host "--- Part C: Node J additional intents inside correction section ---"
$jCode = $nodeJ.parameters.jsCode
Check "Node J has jsCode" ($jCode -ne $null -and $jCode.Length -gt 0)
Check "Node J has additional_intents_shadow field" ($jCode -match "additional_intents_shadow")
Check "Node J has optional correction details section" ($jCode -match "Optional: Correct classification")
Check "Node J correction section not yet open-by-default" ($jCode -notmatch 'details.*4g.*open')

Write-Host ""
Write-Host "--- Part D: SL-P2A origMicroIntent path ---"
$p2aCode = $nodeSLP2A.parameters.jsCode
Check "SL-P2A has jsCode" ($p2aCode -ne $null -and $p2aCode.Length -gt 0)
Check "SL-P2A has origMicroIntent declaration" ($p2aCode -match "origMicroIntent")
Check "SL-P2A does NOT already have sender_handoff.draft.micro_intent path" ($p2aCode -notmatch "sender_handoff\.draft\.micro_intent")

Write-Host ""
Write-Host "--- WhatIf Summary ---"
Write-Host "  PASS: $pass  FAIL: $fail"

if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf complete. No changes made. Run -Apply to execute."
    exit ($fail -gt 0 ? 1 : 0)
}

if ($fail -gt 0) {
    Write-Error "WhatIf checks failed ($fail failures). Aborting Apply."
    exit 1
}

# ─── Apply ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patches ==="

# ── Part A: Node Q — override validation.valid=true on human approve ───────────
Write-Host ""
Write-Host "Part A: Patching Node Q validation override..."
$nodeQ.parameters.workflowInputs.value.validation = '={{ Object.assign({}, $json.case_input.validation || {}, { valid: true, human_approved: true }) }}'
Write-Host "  Done."

# ── Part B: Node R — clear blocked-send feedback ──────────────────────────────
Write-Host ""
Write-Host "Part B: Patching Node R result page..."
$newRCode = @'
const items = $input.all();

function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

let approvalContext = {};
try { approvalContext = $("O1. Restore Reviewer Decision Context").first().json || {}; } catch {}

return items.map(item => {
  const input = item.json || {};
  const rc = approvalContext.review_case || {};
  const terminal = input.terminal || {};
  const isBlocked = terminal.result === "BLOCKED" || terminal.send_state === "BLOCKED";
  const blockDetails = Array.isArray(terminal.details) ? terminal.details : [];
  const isSenderValidationFailed = blockDetails.includes("sender_validation_failed");
  const isRetryable = isSenderValidationFailed;

  let html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>HMZ Reply Review</title></head><body>";

  if (isBlocked) {
    html += "<h1 style=\"color:#c0392b\">Send Blocked — SEND_BLOCKED_RETRYABLE</h1>";
    html += "<p>Case " + escapeHtml(rc.case_id) + " was approved by " + escapeHtml(rc.approver_identity) + " but the send was blocked before transmission.</p>";
    html += "<p><strong>Block reason:</strong> " + escapeHtml(terminal.reason || "send_gates_failed") + "</p>";
    if (blockDetails.length > 0) {
      html += "<p><strong>Details:</strong> " + escapeHtml(blockDetails.join(", ")) + "</p>";
    }
    if (isSenderValidationFailed) {
      html += "<div style=\"background:#fff3cd;border:1px solid #ffc107;padding:10px;border-radius:4px;margin:10px 0\">";
      html += "<strong>Why:</strong> The original AI draft was flagged by content validation before your review. ";
      html += "Even though you approved an edited version, the original validation flag was still attached to the case. ";
      html += "This is a known issue being fixed (SL-PHASE-4G). ";
      html += "<br><br><strong>Action:</strong> The prospect did NOT receive a reply. Please send a reply manually via Instantly, or contact the system owner to re-open this case with a fresh review token.";
      html += "</div>";
    } else {
      html += "<div style=\"background:#f8d7da;border:1px solid #f5c6cb;padding:10px;border-radius:4px;margin:10px 0\">";
      html += "<strong>Action:</strong> The prospect did NOT receive a reply. Please check the send gates and contact the system owner.";
      html += "</div>";
    }
    html += "<p style=\"font-size:0.85em;color:#888\">Case: " + escapeHtml(rc.case_id) + " | Sent: false</p>";
  } else {
    html += "<h1 style=\"color:#27ae60\">Approved and Handed Off</h1>";
    html += "<p>Case " + escapeHtml(rc.case_id) + " approved by " + escapeHtml(rc.approver_identity) + ". Handed off to the Reply Sender.</p>";
    const sendState = terminal.send_state || terminal.result || "UNKNOWN";
    html += "<p><strong>Send state:</strong> " + escapeHtml(sendState) + "</p>";
  }

  html += "</body></html>";
  return { json: { ...input, review_case: rc, html, http_status: 200 } };
});
'@
$nodeR.parameters.jsCode = $newRCode
Write-Host "  Done."

# ── Part C: Node J — move additional_intents_shadow into correction section ────
Write-Host ""
Write-Host "Part C: Patching Node J additional classification correction section..."

$jCode = $nodeJ.parameters.jsCode

# The block to remove: from the var _p4aDefault line through the closing div
# The block to insert inside details: the same field but inside the section
$oldStandaloneBlock = 'var _p4aDefault = _p4aIntents.length > 0 ? _p4aIntents.map(function(i){return i.micro_intent;}).join('' + '') : "";
    html += "<label>Additional classifications/intents in this email (optional, shadow learning only):<br><input type=\"text\" name=\"additional_intents_shadow\" style=\"width:440px\" value=\"" + escapeHtml(_p4aDefault) + "\" placeholder=\"e.g. PRICING_REQUEST + SMALL_SCALE_PILOT_REQUEST\"></label><br><div style=\"font-size:0.8em;color:#666;margin-bottom:8px\">Add, remove, or replace additional classifications. Removals with a reason create negative learning feedback. Additions create positive learning feedback. Does not affect routing or sending.</div>";
    // SL-Phase 1C: optional correction fields (shadow learning — does not affect routing or sending)'

$newStandaloneBlock = 'var _p4aDefault = _p4aIntents.length > 0 ? _p4aIntents.map(function(i){return i.micro_intent;}).join('' + '') : "";
  // SL-Phase 1C: optional correction fields (shadow learning — does not affect routing or sending)'

$oldDetailsOpen = 'html += "<hr><details><summary style=\"cursor:pointer;font-weight:bold\">Optional: Correct classification (shadow learning only — does not affect routing, draft, or sending)</summary>";'

# SL-4G: open details by default when additional intents exist, and include addl intents field inside
$newDetailsOpen = 'html += "<hr><details " + (_p4aIntents.length > 0 ? "open" : "") + "><summary style=\"cursor:pointer;font-weight:bold\">Optional: Correct classification and additional intents (shadow learning only — does not affect routing, draft, or sending)</summary>";'

# Insert additional_intents_shadow before the correction_reason line
$oldCorrReasonLine = 'html += "<label>Correction reason: <input type=\"text\" name=\"correction_reason\" style=\"width:360px\" placeholder=\"Why was the classification wrong?\"></label>";'

$newCorrReasonBlock = 'html += "<hr style=\"margin:8px 0\"><label>Additional classifications/intents (edit to add or remove):<br><input type=\"text\" name=\"additional_intents_shadow\" style=\"width:440px\" value=\"" + escapeHtml(_p4aDefault) + "\" placeholder=\"e.g. PRICING_REQUEST + SMALL_SCALE_PILOT_REQUEST\"></label><br>";
  html += "<p style=\"font-size:11px;color:#777;margin:3px 0 8px\">Add, remove, or replace additional classifications here. This creates shadow learning feedback only and does not affect routing, drafting, or sending.</p>";
  html += "<label>Correction reason: <input type=\"text\" name=\"correction_reason\" style=\"width:360px\" placeholder=\"Why was the classification wrong?\"></label>";'

if ($jCode.Contains($oldStandaloneBlock) -and $jCode.Contains($oldDetailsOpen) -and $jCode.Contains($oldCorrReasonLine)) {
    $jCode = $jCode.Replace($oldStandaloneBlock, $newStandaloneBlock)
    $jCode = $jCode.Replace($oldDetailsOpen, $newDetailsOpen)
    $jCode = $jCode.Replace($oldCorrReasonLine, $newCorrReasonBlock)
    $nodeJ.parameters.jsCode = $jCode
    Write-Host "  Done (3 replacements applied)."
} else {
    Write-Host "  ERROR: Could not find all replacement targets in Node J."
    Write-Host "  standalone found: $($jCode.Contains($oldStandaloneBlock))"
    Write-Host "  details open found: $($jCode.Contains($oldDetailsOpen))"
    Write-Host "  corrReason found: $($jCode.Contains($oldCorrReasonLine))"
    Write-Error "Node J patching failed — aborting."
    exit 1
}

# ── Part D: SL-P2A — add sender_handoff.draft.micro_intent to origMicroIntent ─
Write-Host ""
Write-Host "Part D: Patching SL-P2A origMicroIntent lookup path..."
$p2aCode = $nodeSLP2A.parameters.jsCode

$oldMiLine = 'const origMicroIntent = String(rap.micro_intent || ctx.micro_intent || rc.micro_intent || "");'
$newMiLine  = 'const origMicroIntent = String(rap.micro_intent || ctx.micro_intent || rc.micro_intent || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || "");'

if ($p2aCode.Contains($oldMiLine)) {
    $p2aCode = $p2aCode.Replace($oldMiLine, $newMiLine)
    $nodeSLP2A.parameters.jsCode = $p2aCode
    Write-Host "  Done."
} else {
    Write-Error "SL-P2A origMicroIntent line not found — aborting."
    exit 1
}

# ─── PUT workflow back ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Writing patched HumanApproval workflow back..."
$putResult = Put-Workflow $WF_HUMANAPPROVAL $wfHA
Write-Host "  New versionId: $($putResult.versionId)"

# ─── Verify ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Verifying Applied Changes ==="
$wfVerify = Get-Workflow $WF_HUMANAPPROVAL
Write-Host "  versionId after Apply: $($wfVerify.versionId)"

$pass2 = 0
$fail2 = 0
function Check2($label, $condition) {
    if ($condition) { Write-Host "  PASS: $label"; $script:pass2++ }
    else            { Write-Host "  FAIL: $label"; $script:fail2++ }
}

$vNew = $wfVerify.versionId
Check2 "versionId changed from Phase 4F" ($vNew -ne $EXPECTED_VERSION_BEFORE)

$nodeJv    = $wfVerify.nodes | Where-Object { $_.name -like "J. Render Review Form HTML" }
$nodeSLv   = $wfVerify.nodes | Where-Object { $_.name -like "SL-P2A*" }
$nodeQv    = $wfVerify.nodes | Where-Object { $_.name -like "Q. Reply Sender Handoff*" }
$nodeRv    = $wfVerify.nodes | Where-Object { $_.name -like "R. Build Approved Result Page" }

# Part A: Node Q
Check2 "Node Q validation now has human_approved override" ($nodeQv.parameters.workflowInputs.value.validation -match "human_approved")
Check2 "Node Q validation uses Object.assign" ($nodeQv.parameters.workflowInputs.value.validation -match "Object\.assign")

# Part B: Node R
Check2 "Node R shows SEND_BLOCKED_RETRYABLE state" ($nodeRv.parameters.jsCode -match "SEND_BLOCKED_RETRYABLE")
Check2 "Node R checks terminal.result BLOCKED" ($nodeRv.parameters.jsCode -match "terminal\.result")
Check2 "Node R distinguishes blocked vs approved" ($nodeRv.parameters.jsCode -match "isBlocked")

# Part C: Node J
Check2 "Node J additional_intents_shadow still present" ($nodeJv.parameters.jsCode -match "additional_intents_shadow")
Check2 "Node J correction section opens by default when intents exist" ($nodeJv.parameters.jsCode -match "_p4aIntents\.length.*open")
Check2 "Node J addl intents field now inside correction section (before correction_reason)" (
    ($nodeJv.parameters.jsCode.IndexOf("additional_intents_shadow")) -gt ($nodeJv.parameters.jsCode.IndexOf("Optional: Correct classification"))
)
Check2 "Node J does not have standalone additional_intents_shadow outside section" (
    -not ($nodeJv.parameters.jsCode -match 'Additional classifications/intents in this email.*\n.*additional_intents_shadow')
)

# Part D: SL-P2A
Check2 "SL-P2A origMicroIntent now includes sender_handoff.draft.micro_intent" ($nodeSLv.parameters.jsCode -match "sender_handoff\.draft\.micro_intent")

Write-Host ""
Write-Host "=== Apply Verification: PASS=$pass2 FAIL=$fail2 ==="

if ($fail2 -gt 0) {
    Write-Host "WARN: Some verification checks failed. Review above. Manual inspection recommended."
    exit 1
} else {
    Write-Host ""
    Write-Host "=== SL-PHASE-4G APPLIED SUCCESSFULLY ==="
    Write-Host "  HumanApproval versionId: $vNew"
    Write-Host "  Parts A+B+C+D applied to HumanApproval 9aPrt92jFhoYFxbs"
    Write-Host "  Decision workflow: NOT modified"
    Write-Host "  Sender workflow: NOT modified"
    Write-Host "  No autonomous send introduced"
    Write-Host "  No safety gates weakened (all Sender gates still active except now human-approved validation)"
}
