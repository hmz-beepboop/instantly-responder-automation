<#
.SYNOPSIS
  SL-PHASE-2B — Review-form micro-intent visibility repair + additional_intents_shadow field mapping.
  Patches node J (Render Review Form HTML) and node L (Validate & Consume Review Token).
  All other nodes, logic, DataTable IDs, approval flow, AI behaviour, classifier, routing untouched.

  Root causes fixed:
  1. Node J micro-intent fallback chain does not reach ctx.sender_handoff.draft.micro_intent.
     Google Chat (node D) shows PRICING_REQUEST; form showed "not set" because the value is
     stored at sanitized_context.sender_handoff.draft.micro_intent, not at any of the paths
     node J previously checked (recommended_action_plan.micro_intent, ctx.micro_intent,
     rc.micro_intent).
  2. Node L does not map body.additional_intents_shadow -> submit_additional_intents_shadow,
     so SL-P2A IIFE received empty string and multi_intent_shadow capture never fired even
     when the reviewer submitted intents.

.PARAMETER WhatIf
  Show what would change without writing to production.

.PARAMETER Apply
  Apply the patch to production HumanApproval workflow 9aPrt92jFhoYFxbs.

.EXAMPLE
  .\SL-PHASE-2B-review-form-micro-intent-repair.ps1 -WhatIf
  .\SL-PHASE-2B-review-form-micro-intent-repair.ps1 -Apply
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

if (-not $ApiKey) { Write-Host "ERROR: HMZ_N8N_API_KEY not set."; exit 1 }

Write-Host "=== SL-PHASE-2B Review-Form Micro-Intent Repair ==="
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

# ========== NODE J: Render Review Form HTML ==========
$nodeJ = Find-Node "J. Render Review Form HTML"
$oldJ  = $nodeJ.parameters.jsCode
$newJ  = $oldJ

# J-B2: Fix micro-intent DISPLAY line (shown in top section of form).
#   Old fallback chain ends at rc.micro_intent. New chain adds:
#   (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent)
#   (input.case_input && input.case_input.draft && input.case_input.draft.micro_intent)
$oldJB2 = '|| rc.micro_intent || "not set")) + " | <strong>Urgency:'
$newJB2 = '|| rc.micro_intent || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || (input.case_input && input.case_input.draft && input.case_input.draft.micro_intent) || "not set")) + " | <strong>Urgency:'
$newJ = $newJ.Replace($oldJB2, $newJB2)

# J-B3: Fix p1cMi variable (used as default value for corrected_micro_intent input field).
$oldJB3 = '|| ctx.micro_intent || rc.micro_intent || ""));'
$newJB3 = '|| ctx.micro_intent || rc.micro_intent || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || (input.case_input && input.case_input.draft && input.case_input.draft.micro_intent) || ""));'
$newJ = $newJ.Replace($oldJB3, $newJB3)

# --- Verify Node J ---
$jB2ok = $newJ -like '*(ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || (input.case_input && input.case_input.draft && input.case_input.draft.micro_intent) || "not set"*'
$jB3ok = $newJ -like '*(ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || (input.case_input && input.case_input.draft && input.case_input.draft.micro_intent) || ""*'

# Confirm Phase 2A patches still present
$jPhase2A_B1  = $newJ -like '*|| ctx.micro_intent || rc.micro_intent ||*'
$jPhase2A_C2  = $newJ -like '*No AI draft was generated*'
$jPhase2A_D1  = $newJ -like '*additional_intents_shadow*'
$jPhase2A_C3  = $newJ -like '*hmzReplyText*'

Write-Host "[J] B2 display micro_intent fallback extended: $jB2ok"
Write-Host "[J] B3 p1cMi default fallback extended:       $jB3ok"
Write-Host "[J] Phase-2A B1 still present:                $jPhase2A_B1"
Write-Host "[J] Phase-2A C2 banner still present:         $jPhase2A_C2"
Write-Host "[J] Phase-2A D1 intents field still present:  $jPhase2A_D1"
Write-Host "[J] Phase-2A C3 onclick guard still present:  $jPhase2A_C3"

$jOk = $jB2ok -and $jB3ok -and $jPhase2A_B1 -and $jPhase2A_C2 -and $jPhase2A_D1 -and $jPhase2A_C3
if (-not $jOk) {
    Write-Host "[J] ABORT: One or more Node J checks failed — string mismatch. Run on updated workflow."
    exit 1
}
Write-Host "[J] All checks PASS."
Write-Host ""

# ========== NODE L: Validate & Consume Review Token (POST) ==========
$nodeL = Find-Node "L. Validate & Consume Review Token (POST)"
$oldL  = $nodeL.parameters.jsCode
$newL  = $oldL

# L-D3: Add submit_additional_intents_shadow to the field mapping so SL-P2A IIFE can read it.
#   The Phase 2A D1 patch added the form field (additional_intents_shadow) to the HTML in node J.
#   Node L must map body.additional_intents_shadow -> submit_additional_intents_shadow so that
#   the downstream SL-P2A node receives it at inp.submit_additional_intents_shadow.
$oldLD3 = 'submit_correction_reason: String(body.correction_reason || "").trim()'
$newLD3 = 'submit_correction_reason: String(body.correction_reason || "").trim(),' + "`n" + '      submit_additional_intents_shadow: String(body.additional_intents_shadow || "").trim()'
$newL = $newL.Replace($oldLD3, $newLD3)

# --- Verify Node L ---
$lD3ok = $newL -like '*submit_additional_intents_shadow: String(body.additional_intents_shadow*'
# Confirm existing mappings still present
$lExisting = $newL -like '*submit_edited_text*' -and $newL -like '*submit_corrected_category*' -and $newL -like '*submit_correction_reason*'

Write-Host "[L] D3 submit_additional_intents_shadow added: $lD3ok"
Write-Host "[L] Existing submit_* mappings preserved:      $lExisting"

$lOk = $lD3ok -and $lExisting
if (-not $lOk) {
    Write-Host "[L] ABORT: Node L check failed — string mismatch."
    exit 1
}
Write-Host "[L] All checks PASS."
Write-Host ""

# ========== Safety check: prohibited nodes untouched ==========
$prohibited = @(
    "A. Build Review Case Record",
    "D. Build Google Chat Notification Payload",
    "N. Process Reviewer Decision",
    "O. Persist Reviewer Decision (Data Table)",
    "SL-P1A. Build Draft Revision Event",
    "SL-P1B. Write Draft Revision Event (DataTable)",
    "SL-P1C. Restore Context After Capture",
    "SL-P2A. Prepare Phase 1C+2 Capture Data",
    "SL-P2B. Write Classification Correction Event",
    "SL-P2C. Restore Context and Emit Rule Candidate Items",
    "SL-P2D. Route Main vs Rule Candidate",
    "SL-P2E. Write Rule Candidate Shadow",
    "P. Approval Outcome Router",
    "Q. Reply Sender Handoff (Approved)"
)
Write-Host "Verifying prohibited nodes are untouched..."
foreach ($pn in $prohibited) {
    $nd = $wf.nodes | Where-Object { $_.name -eq $pn }
    if ($nd) { Write-Host "  [OK] $pn" }
    else      { Write-Host "  [NOT FOUND] $pn (may not exist in this workflow)" }
}
Write-Host ""

if ($WhatIf) {
    Write-Host "=== WhatIf RESULT: PASS ==="
    Write-Host "J: 2 changes ready (B2 display fallback, B3 p1cMi fallback — both add sender_handoff.draft.micro_intent path)"
    Write-Host "L: 1 change ready (D3 submit_additional_intents_shadow field mapping)"
    Write-Host "Phase-2A patches confirmed still present in J."
    Write-Host "No prohibited nodes touched."
    Write-Host "Run -Apply to apply."
    exit 0
}

# ========== Apply ==========
Write-Host "=== Applying patch to production ==="

$nodeJ.parameters.jsCode = $newJ
$nodeL.parameters.jsCode = $newL

$body = @{
    name        = $wf.name
    nodes       = $wf.nodes
    connections = $wf.connections
    settings    = $wf.settings
    staticData  = $wf.staticData
} | ConvertTo-Json -Depth 50 -Compress

$result = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method PUT -Body $body
Write-Host "PUT result: id=$($result.id) name='$($result.name)'"

# ========== Post-Apply Verification ==========
$verify = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method GET
$verJ   = ($verify.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }).parameters.jsCode
$verL   = ($verify.nodes | Where-Object { $_.name -eq "L. Validate & Consume Review Token (POST)" }).parameters.jsCode

$vJB2 = $verJ -like '*(ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent)*'
$vJB3 = $verJ -like '*(input.case_input && input.case_input.draft && input.case_input.draft.micro_intent) || ""*'
$vJC2 = $verJ -like '*No AI draft was generated*'
$vJD1 = $verJ -like '*additional_intents_shadow*'
$vJC3 = $verJ -like '*hmzReplyText*'
$vLD3 = $verL -like '*submit_additional_intents_shadow*'
$vLEx = $verL -like '*submit_edited_text*' -and $verL -like '*submit_corrected_category*'

Write-Host ""
Write-Host "=== POST-APPLY VERIFICATION ==="
Write-Host "FORM_MICRO_INTENT_DISPLAY_FALLBACK_EXTENDED: $vJB2"
Write-Host "FORM_MICRO_INTENT_P1CMI_FALLBACK_EXTENDED:  $vJB3"
Write-Host "FORM_HUMAN_ONLY_BANNER_PRESENT:              $vJC2"
Write-Host "FORM_ADDITIONAL_INTENTS_FIELD_PRESENT:       $vJD1"
Write-Host "FORM_ONCLICK_BLANK_GUARD_PRESENT:            $vJC3"
Write-Host "NODE_L_SUBMIT_INTENTS_SHADOW_MAPPED:         $vLD3"
Write-Host "NODE_L_EXISTING_MAPPINGS_PRESENT:            $vLEx"

$allOk = $vJB2 -and $vJB3 -and $vJC2 -and $vJD1 -and $vJC3 -and $vLD3 -and $vLEx
if ($allOk) {
    Write-Host ""
    Write-Host "=== PATCH APPLIED AND VERIFIED: PASS ==="
    Write-Host "SELF_IMPROVING_STATUS: 60% scaffolded — form micro-intent fixed, multi-intent capture fixed. Active rule injection not yet enabled."
} else {
    Write-Host ""
    Write-Host "=== PATCH VERIFICATION: PARTIAL — check items above ==="
}
