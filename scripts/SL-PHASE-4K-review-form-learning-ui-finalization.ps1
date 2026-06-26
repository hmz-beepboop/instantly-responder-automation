#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-4K: Review form self-improvement UI finalization.

.DESCRIPTION
Patches HumanApproval workflow 9aPrt92jFhoYFxbs ONLY.
Decision, Sender, Intake, ErrorHandler, SLAWatchdog, FTH are NOT modified.

Changes:

Part A — Node J: Always show "Additional detected intents" line
  Current: conditional on _p4aIntents.length > 0 (invisible when no intents).
  Fix: always show, display "N/A" when no additional intents detected.

Part B — Node J: Add non-commercial AI-assisted draft warning banner
  Current: only AI_COMMERCIAL_SUPERVISED shows a review warning.
  Fix: ai_supervised / ai_supervised_or_template / ai_failed_fallback paths
       also show a non-commercial review warning.
  Commercial warning: unchanged.

Part C — Node J: Replace single correction_reason with 3 separate fields
  Current: one "Correction reason" field covers broad category, micro intent,
           and additional intents corrections.
  Fix: three separate reason fields:
       correction_reason_broad_category
       correction_reason_micro_intent
       correction_reason_additional_intents
  Backward compat: old correction_reason still extracted by Node L as fallback.

Part D — Node L: Extract 3 new correction reason fields from form body
  Old correction_reason still extracted for backward compatibility.

Part E — SL-P2A: Capture and emit the 3 separate correction reasons
  Falls back to combined correction_reason if specific fields are empty.
  Adds correction_reason_broad_category/micro_intent/additional_intents
  to the sl_p2_correction_event.

Safety:
  - No routing changes.
  - No live rules created.
  - No autonomous send.
  - Rule candidates remain proposed_shadow.
  - effectCat / effectMi (live routing) never blanked.
  - Blank/N/A additional_intents_shadow does not create destructive feedback.

.PARAMETER WhatIf
Verify all patch targets exist. No changes made.

.PARAMETER Apply
Execute the patch and verify versionId changed.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) { Write-Error "SAFETY: forbidden term '$bad' in script path."; exit 1 }
}

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: -WhatIf  (dry-run check)  or  -Apply  (execute patch)"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) { Write-Error "HMZ_N8N_API_KEY not set"; exit 1 }
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$WF_HUMANAPPROVAL         = "9aPrt92jFhoYFxbs"
$EXPECTED_VERSION_BEFORE  = "27ef843a-1291-4e6b-a25f-dbe1dd7c351a"   # Phase 4I result

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
    if (-not $n) { throw "Node not found matching '$nameLike'" }
    $n
}

$pass = 0; $fail = 0
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS: $label"; $script:pass++ }
    else        { Write-Host "  FAIL: $label"; $script:fail++ }
}

# ─── Load workflow ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-4K  WhatIf=$WhatIf  Apply=$Apply ==="
Write-Host "Production target: $BASE"
Write-Host ""
Write-Host "Loading HumanApproval $WF_HUMANAPPROVAL ..."
$wfHA = Get-Workflow $WF_HUMANAPPROVAL
Write-Host "  versionId: $($wfHA.versionId)"
Check "versionId matches Phase 4I expected" ($wfHA.versionId -eq $EXPECTED_VERSION_BEFORE)

$nodeJ   = Find-Node $wfHA "J. Render Review Form HTML"
$nodeL   = Find-Node $wfHA "L. Validate & Consume Review Token (POST)"
$nodeP2A = Find-Node $wfHA "SL-P2A*"

Check "Node J found"    ($nodeJ   -ne $null)
Check "Node L found"    ($nodeL   -ne $null)
Check "Node P2A found"  ($nodeP2A -ne $null)

$jCode   = $nodeJ.parameters.jsCode
$lCode   = $nodeL.parameters.jsCode
$p2aCode = $nodeP2A.parameters.jsCode

# ─── Define patch targets ──────────────────────────────────────────────────────

# Part A: Always show "Additional detected intents" (replace conditional with unconditional)
$PA_OLD = 'if (_p4aIntents.length > 0) { html += "<p><strong>Additional detected intents:</strong> " + escapeHtml(_p4aIntents.map(function(i){return i.micro_intent;}).join('' + '')) + "</p>"; }'

$PA_NEW = @'
const _p4aIntentsDisplay = _p4aIntents.length > 0 ? escapeHtml(_p4aIntents.map(function(i){return i.micro_intent;}).join(' + ')) : "N/A";
  html += "<p><strong>Additional detected intents:</strong> " + _p4aIntentsDisplay + "</p>";
'@

# Part B: Add non-commercial AI banner
# Anchor: the commercial banner block ends before the textarea label
$PB_OLD = @'
; } if (_p4aDS === 'ai_commercial_supervised') { html += "<p style=\"background:#d1ecf1;border:1px solid #bee5eb;padding:10px;border-radius:4px\"><strong>AI-assisted draft for human review. Edit before approving. Do not invent prices, contract terms, data guarantees, or results not yet proven.</strong></p>"; } html += "<label>Reply text (editable):<br><textarea
'@

$PB_NEW = @'
; } if (_p4aDS === 'ai_commercial_supervised') { html += "<p style=\"background:#d1ecf1;border:1px solid #bee5eb;padding:10px;border-radius:4px\"><strong>AI-assisted draft for human review. Edit before approving. Do not invent prices, contract terms, data guarantees, or results not yet proven.</strong></p>"; } else if (_p4aDS === 'ai_supervised' || _p4aDS === 'ai_supervised_or_template' || _p4aDS === 'ai_failed_fallback') { html += "<p style=\"background:#fff3cd;border:1px solid #ffc107;padding:10px;border-radius:4px\"><strong>AI-assisted draft for human review. Edit before approving. Do not invent proof, customer examples, case studies, results, pricing, contract terms, data guarantees, or claims not yet proven.</strong></p>"; } html += "<label>Reply text (editable):<br><textarea
'@

# Part C: Replace single correction_reason with 3 separate reason fields
$PC_OLD = 'html += "<label>Correction reason: <input type=\"text\" name=\"correction_reason\" style=\"width:360px\" placeholder=\"Why was the classification wrong?\"></label>";'

$PC_NEW = @'
html += "<label style=\"display:block;margin-top:6px\">Broad category correction reason: <input type=\"text\" name=\"correction_reason_broad_category\" style=\"width:360px\" placeholder=\"Why was the broad category wrong?\"></label><br>";
  html += "<label style=\"display:block;margin-top:4px\">Micro intent correction reason: <input type=\"text\" name=\"correction_reason_micro_intent\" style=\"width:360px\" placeholder=\"Why was the micro intent wrong?\"></label><br>";
  html += "<label style=\"display:block;margin-top:4px\">Additional intents correction reason: <input type=\"text\" name=\"correction_reason_additional_intents\" style=\"width:360px\" placeholder=\"Why add/remove additional intents?\"></label>";
'@

# Part D: Node L — add 3 new correction reason fields
$PD_OLD = 'submit_correction_reason: String(body.correction_reason || "").trim(),
      submit_additional_intents_shadow: String(body.additional_intents_shadow || "").trim()'

$PD_NEW = @'
submit_correction_reason: String(body.correction_reason || "").trim(),
      submit_correction_reason_broad_category: String(body.correction_reason_broad_category || "").trim(),
      submit_correction_reason_micro_intent: String(body.correction_reason_micro_intent || "").trim(),
      submit_correction_reason_additional_intents: String(body.correction_reason_additional_intents || "").trim(),
      submit_additional_intents_shadow: String(body.additional_intents_shadow || "").trim()
'@

# Part E: SL-P2A — add separate reason variables
$PE_OLD = 'const corrReason      = String(inp.submit_correction_reason || "").trim();'

$PE_NEW = @'
const corrReason      = String(inp.submit_correction_reason || "").trim();
    const corrReasonBroadCategory    = String(inp.submit_correction_reason_broad_category    || inp.submit_correction_reason || "").trim();
    const corrReasonMicroIntent      = String(inp.submit_correction_reason_micro_intent      || inp.submit_correction_reason || "").trim();
    const corrReasonAdditionalIntents = String(inp.submit_correction_reason_additional_intents || "").trim();
'@

# Part E2: SL-P2A — add separate reasons to corrEvent
$PE2_OLD = '      correction_reason: corrReason,'

$PE2_NEW = @'
      correction_reason: corrReason,
      correction_reason_broad_category: corrReasonBroadCategory,
      correction_reason_micro_intent: corrReasonMicroIntent,
      correction_reason_additional_intents: corrReasonAdditionalIntents,
'@

# ─── WhatIf: verify all patch targets exist ────────────────────────────────────
Write-Host ""
Write-Host "--- Part A: Additional detected intents always-show ---"
Check "Node J: intents conditional display present (target found)" ($jCode.Contains($PA_OLD.Trim()))
Check "Node J: not already patched (4K not already applied)" (-not $jCode.Contains("_p4aIntentsDisplay"))

Write-Host ""
Write-Host "--- Part B: Non-commercial AI banner ---"
Check "Node J: commercial banner anchor present" ($jCode.Contains("ai_commercial_supervised"))
Check "Node J: commercial banner → textarea anchor present" ($jCode.Contains('; } if (_p4aDS === ''ai_commercial_supervised'''))
Check "Node J: not already patched (non-commercial banner absent)" (-not $jCode.Contains("ai_supervised_or_template"))

Write-Host ""
Write-Host "--- Part C: Separate correction reason fields in form ---"
Check "Node J: single correction_reason input present" ($jCode.Contains($PC_OLD.Trim()))
Check "Node J: not already patched" (-not $jCode.Contains("correction_reason_broad_category"))

Write-Host ""
Write-Host "--- Part D: Node L new reason fields ---"
Check "Node L: submit_correction_reason present" ($lCode.Contains('submit_correction_reason:'))
Check "Node L: submit_additional_intents_shadow present" ($lCode.Contains('submit_additional_intents_shadow'))
Check "Node L: not already patched" (-not $lCode.Contains('submit_correction_reason_broad_category'))

Write-Host ""
Write-Host "--- Part E: SL-P2A separate reason capture ---"
Check "SL-P2A: corrReason line present" ($p2aCode.Contains($PE_OLD.Trim()))
Check "SL-P2A: correction_reason in corrEvent" ($p2aCode.Contains($PE2_OLD.Trim()))
Check "SL-P2A: not already patched" (-not $p2aCode.Contains("corrReasonBroadCategory"))

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

# ─── Apply patches ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patches ==="

# Part A
Write-Host "Part A: Patching Node J — always show additional detected intents..."
$jCode = $jCode.Replace($PA_OLD.Trim(), $PA_NEW.Trim())
if (-not $jCode.Contains("_p4aIntentsDisplay")) {
    Write-Error "Part A replacement failed — _p4aIntentsDisplay not found after replace."
    exit 1
}
Write-Host "  Done."

# Part B
Write-Host "Part B: Patching Node J — add non-commercial AI banner..."
$PB_OLD_TRIM = $PB_OLD.Trim()
$PB_NEW_TRIM = $PB_NEW.Trim()
if (-not $jCode.Contains($PB_OLD_TRIM)) {
    # Try without leading/trailing newline
    Write-Error "Part B anchor not found in Node J code. Aborting."
    exit 1
}
$jCode = $jCode.Replace($PB_OLD_TRIM, $PB_NEW_TRIM)
if (-not $jCode.Contains("ai_supervised_or_template")) {
    Write-Error "Part B replacement failed — ai_supervised_or_template not found after replace."
    exit 1
}
Write-Host "  Done."

# Part C
Write-Host "Part C: Patching Node J — 3 separate correction reason fields..."
$jCode = $jCode.Replace($PC_OLD.Trim(), $PC_NEW.Trim())
if (-not $jCode.Contains("correction_reason_broad_category")) {
    Write-Error "Part C replacement failed."
    exit 1
}
Write-Host "  Done."

$nodeJ.parameters.jsCode = $jCode

# Part D
Write-Host "Part D: Patching Node L — 3 new correction reason fields..."
$lCode = $lCode.Replace($PD_OLD.Trim(), $PD_NEW.Trim())
if (-not $lCode.Contains("submit_correction_reason_broad_category")) {
    Write-Error "Part D replacement failed."
    exit 1
}
$nodeL.parameters.jsCode = $lCode
Write-Host "  Done."

# Part E
Write-Host "Part E: Patching SL-P2A — separate reason variables and corrEvent fields..."
$p2aCode = $p2aCode.Replace($PE_OLD.Trim(), $PE_NEW.Trim())
if (-not $p2aCode.Contains("corrReasonBroadCategory")) {
    Write-Error "Part E (variable declarations) replacement failed."
    exit 1
}
$p2aCode = $p2aCode.Replace($PE2_OLD.Trim(), $PE2_NEW.Trim())
if (-not $p2aCode.Contains("correction_reason_broad_category:")) {
    Write-Error "Part E2 (corrEvent fields) replacement failed."
    exit 1
}
$nodeP2A.parameters.jsCode = $p2aCode
Write-Host "  Done."

# ─── PUT workflow back ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Sending updated HumanApproval to production..."
$versionBefore = $wfHA.versionId
$result = Put-Workflow $WF_HUMANAPPROVAL $wfHA
$versionAfter = $result.versionId
Write-Host "  versionId before: $versionBefore"
Write-Host "  versionId after:  $versionAfter"

if ($versionAfter -eq $versionBefore) {
    Write-Error "versionId did not change — PUT may have failed."
    exit 1
}
if (-not $versionAfter) {
    Write-Error "No versionId returned from PUT."
    exit 1
}

# ─── Verify unchanged workflows ───────────────────────────────────────────────
Write-Host ""
Write-Host "Verifying no other production workflows were changed..."
$decisionCheck = Get-Workflow "tgYmY97CG4Bm8snI"
$proxyCheck    = Get-Workflow "seB6ZmlyomhC4QWU"
Check "Decision workflow versionId unchanged" ($decisionCheck.versionId -eq "85f51eb4-bf8f-4d17-9883-52d7c2f11225")
Check "Proxy workflow versionId unchanged"    ($proxyCheck.versionId    -eq "47dbb8bd-ebbb-4a10-a39b-a1fb83be36ac")

Write-Host ""
Write-Host "=== SL-PHASE-4K APPLY COMPLETE ==="
Write-Host "  HumanApproval new versionId: $versionAfter"
Write-Host "  PASS: $pass  FAIL: $fail"
Write-Host ""
Write-Host "Update memory/project_prod_workflow_ids.md with new HumanApproval versionId."
Write-Host "Update NEXT_SESSION_HANDOFF.md."
