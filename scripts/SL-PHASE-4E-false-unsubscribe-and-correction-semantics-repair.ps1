#Requires -Version 7.0
<#
.SYNOPSIS
  SL-PHASE-4E — False-Unsubscribe & Correction-Semantics Repair

  Fixes four bugs confirmed by manual test MT-3 (case-fd6916f4):

  Bug 1 (Node B / Decision): LEGAL_PRIVACY_OR_COMPLAINT always returns micro_intent
    UNSUBSCRIBE_OR_COMPLAINT, even for GDPR/data/contract inquiries that contain no
    explicit stop/remove/unsubscribe language.
    Fix: split handling — only explicit unsubscribe language → UNSUBSCRIBE_OR_COMPLAINT;
    data/compliance inquiry → DATA_PRIVACY_INQUIRY; legal threat → LEGAL_COMPLAINT;
    other legal/privacy → LEGAL_PRIVACY_INQUIRY.

  Bug 2 (Node C / Decision): durable_dnc_intent is set to true whenever det-legal-001
    fires (any GDPR/data-protection mention), causing ORGANISATION_DNC suppression for
    interested prospects asking a compliance question.
    Fix: durable_dnc_intent = false for all LEGAL_PRIVACY_OR_COMPLAINT cases;
    address_suppression_intent = REVIEW_HOLD (human decides). Explicit unsubscribe
    (det-unsub-001) already sets category=UNSUBSCRIBE and is handled separately.

  Bug 3 (Node J / HumanApproval): Review form provides no guidance about blank corrected
    fields. Reviewers may blank a field intending to "clear" the classification, but
    blank = NO_CHANGE (original preserved). Help text is missing.
    Fix: add a one-line note below the corrected micro intent field.

  Bug 4 (SL-P2A / HumanApproval): When a reviewer writes a correction_reason but leaves
    corrected fields blank, the event is recorded as status="no_change", which loses the
    feedback signal. Fix: status="feedback_only" when correction_reason is non-empty but
    both corrected fields are blank.

  Workflows patched:
    Decision:      tgYmY97CG4Bm8snI  (Nodes B and C)
    HumanApproval: 9aPrt92jFhoYFxbs  (Nodes J and SL-P2A)

  Scope constraints:
    - Patches ONLY the 4 nodes above. No other nodes touched.
    - Preserves: ACTIVE_RULES injection, AI_COMMERCIAL_SUPERVISED, calendar link
      injection, rule candidate capture, duplicate signoff handling, all safety gates.
    - Does NOT modify: Sender, Intake, ErrorHandler, SLAWatchdog, FullTestHarness.
    - Does NOT enable autonomous mode or change operating mode.
    - Regression: new micro_intents (DATA_PRIVACY_INQUIRY, LEGAL_COMPLAINT,
      LEGAL_PRIVACY_INQUIRY) fall through to draftPolicyFor fallback → HUMAN_ONLY,
      which matches Node C plan for LEGAL_PRIVACY_OR_COMPLAINT.

.PARAMETER WhatIf
  Show diffs and describe changes. No production change.

.PARAMETER Apply
  Apply changes to production. Requires -OwnerConfirmedApply YES.

.PARAMETER OwnerConfirmedApply
  Must equal "YES" for -Apply to proceed.

.EXAMPLE
  .\SL-PHASE-4E-false-unsubscribe-and-correction-semantics-repair.ps1 -WhatIf
  .\SL-PHASE-4E-false-unsubscribe-and-correction-semantics-repair.ps1 -Apply -OwnerConfirmedApply YES
#>

param(
    [switch]$WhatIf,
    [switch]$Apply,
    [string]$OwnerConfirmedApply = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Safety guards ──────────────────────────────────────────────────────────────
# Check script path only (not content — content contains the guard strings themselves)
foreach ($term in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($term)) { Write-Error "SAFETY: forbidden term in script path."; exit 1 }
}

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: -WhatIf (preview) or -Apply -OwnerConfirmedApply YES (apply)" -ForegroundColor Yellow
    exit 0
}

if ($Apply -and $OwnerConfirmedApply -ne "YES") {
    Write-Error "BLOCKED: -Apply requires -OwnerConfirmedApply YES"
    exit 1
}

# ── Constants ──────────────────────────────────────────────────────────────────
$N8N_BASE       = "https://n8n.hmzaiautomation.com/api/v1"
if ($N8N_BASE -notmatch "hmzaiautomation\.com") { Write-Error "SAFETY: N8N_BASE must target hmzaiautomation.com"; exit 1 }
$WF_DECISION    = "tgYmY97CG4Bm8snI"
$WF_APPROVAL    = "9aPrt92jFhoYFxbs"
$NODE_B_NAME    = "B. Deterministic Reply Classifier"
$NODE_C_NAME    = "C. Decision Policy"
$NODE_J_NAME    = "J. Render Review Form HTML"
$NODE_P2A_NAME  = "SL-P2A. Prepare Phase 1C+2 Capture Data"

$EXPECTED_DECISION_VERSION  = "b91c4abc-a4f1-4937-badc-5dabec1a24ec"
$EXPECTED_APPROVAL_VERSION  = "8430c40d-9ad6-4294-bfaf-5538203f45bf"

# ── API helpers ────────────────────────────────────────────────────────────────
function Get-Headers {
    if (-not $env:HMZ_N8N_API_KEY) { Write-Error "HMZ_N8N_API_KEY not set"; exit 1 }
    return @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY; "Content-Type" = "application/json" }
}

function Get-Workflow($id) {
    $h = Get-Headers
    return Invoke-RestMethod -Uri "$N8N_BASE/workflows/$id" -Headers $h -Method GET
}

function Patch-Workflow($id, $body) {
    $h = Get-Headers
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    return Invoke-RestMethod -Uri "$N8N_BASE/workflows/$id" -Headers $h -Method PUT -Body $json
}

function Find-Node($wf, $name) {
    $node = $wf.nodes | Where-Object { $_.name -eq $name }
    if (-not $node) { Write-Error "Node not found: $name"; exit 1 }
    return $node
}

# ── Show diff helper ───────────────────────────────────────────────────────────
function Show-Diff($label, $oldSnippet, $newSnippet) {
    Write-Host ""
    Write-Host "  [CHANGE] $label" -ForegroundColor Yellow
    Write-Host "  OLD:" -ForegroundColor Red
    $oldSnippet -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host "  NEW:" -ForegroundColor Green
    $newSnippet -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

# ── Define patches ─────────────────────────────────────────────────────────────

# Patch 1: Node B — detectMicroIntent LEGAL_PRIVACY_OR_COMPLAINT handling
$P1_OLD = "  if (category === 'UNSUBSCRIBE' || category === 'LEGAL_PRIVACY_OR_COMPLAINT') return 'UNSUBSCRIBE_OR_COMPLAINT';"
$P1_NEW = @"
  if (category === 'UNSUBSCRIBE') return 'UNSUBSCRIBE_OR_COMPLAINT';
  if (category === 'LEGAL_PRIVACY_OR_COMPLAINT') {
    const _unsubRx = /\b(stop emailing|remove me|unsubscribe|take me off|do not contact|opt out|opt-out)\b/i;
    if (_unsubRx.test(t)) return 'UNSUBSCRIBE_OR_COMPLAINT';
    const _dataRx = /\b(gdpr|ccpa|hipaa|soc2|soc 2|data (stored|storage|protection|security|privacy|handling)|where (is|are) (data|information) stored|compliant|compliance|contract|terms|agreement|msa)\b/i;
    if (_dataRx.test(t)) return 'DATA_PRIVACY_INQUIRY';
    const _legalRx = /\b(attorney|lawyer|lawsuit|cease|legal action|counsel|regulator)\b/i;
    if (_legalRx.test(t)) return 'LEGAL_COMPLAINT';
    return 'LEGAL_PRIVACY_INQUIRY';
  }
"@

# Patch 2: Node C — durable_dnc_intent override in LEGAL_PRIVACY block
$P2_OLD = @"
      plan.durable_dnc_intent = !!detFlags['det-legal-001'];
      plan.address_suppression_intent = plan.durable_dnc_intent ? 'ORGANISATION_DNC' : 'REVIEW_HOLD';
"@
$P2_NEW = @"
      // GDPR/data-inquiry (det-legal-001) is not an opt-out; do not auto-suppress.
      // Explicit unsubscribe (det-unsub-001) would already set category=UNSUBSCRIBE.
      plan.durable_dnc_intent = false;
      plan.address_suppression_intent = 'REVIEW_HOLD';
"@

# Patch 3: Node J — help text after corrected micro intent field
$P3_OLD = "  html += `"<label>Corrected micro intent: <input type=\`"text\`" name=\`"corrected_micro_intent\`" style=\`"width:260px\`" value=\`"\`" + p1cMi + \`"\`"></label><br>\`";"
# Build the exact string as it appears in the JS code (with escaped quotes)
$P3_OLD_STR = 'html += "<label>Corrected micro intent: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" value=\"" + p1cMi + "\"></label><br>";'
$P3_NEW_STR = 'html += "<label>Corrected micro intent: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" value=\"" + p1cMi + "\"></label><br>";' + "`n" +
              '  html += "<p style=\"font-size:11px;color:#777;margin:3px 0 8px\">Leave corrected fields blank to preserve original classification. To correct, enter a replacement value — do not blank fields to remove a classification.</p>";'

# Patch 4: SL-P2A — feedback_only status when correction_reason given but fields blank
$P4_OLD_STR = '      status: classChanged ? "captured_only" : "no_change",'
$P4_NEW_STR = '      status: classChanged ? "captured_only" : (corrReason && corrCategory === "" && corrMicroIntent === "" ? "feedback_only" : "no_change"),'

Write-Host ""
Write-Host "=== SL-PHASE-4E: FALSE-UNSUBSCRIBE & CORRECTION-SEMANTICS REPAIR ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($WhatIf) { 'WHATIF (no production change)' } else { 'APPLY' })" -ForegroundColor $(if ($WhatIf) { 'Yellow' } else { 'Red' })
Write-Host ""

# ── Fetch workflows ────────────────────────────────────────────────────────────
Write-Host "Fetching Decision workflow ($WF_DECISION)..." -ForegroundColor Gray
$wfD = Get-Workflow $WF_DECISION
Write-Host "  versionId: $($wfD.versionId)"
if ($wfD.versionId -ne $EXPECTED_DECISION_VERSION) {
    Write-Error "BLOCKED: Decision versionId $($wfD.versionId) does not match expected $EXPECTED_DECISION_VERSION. Run was likely already applied or workflow was modified externally."
    exit 1
}

Write-Host "Fetching HumanApproval workflow ($WF_APPROVAL)..." -ForegroundColor Gray
$wfA = Get-Workflow $WF_APPROVAL
Write-Host "  versionId: $($wfA.versionId)"
if ($wfA.versionId -ne $EXPECTED_APPROVAL_VERSION) {
    Write-Error "BLOCKED: HumanApproval versionId $($wfA.versionId) does not match expected $EXPECTED_APPROVAL_VERSION."
    exit 1
}

# ── Validate patches find their targets ───────────────────────────────────────
Write-Host ""
Write-Host "Validating patch targets..." -ForegroundColor Cyan

$nodeBobj  = Find-Node $wfD $NODE_B_NAME
$nodeCobj  = Find-Node $wfD $NODE_C_NAME
$nodeJobj  = Find-Node $wfA $NODE_J_NAME
$nodeP2Aobj = Find-Node $wfA $NODE_P2A_NAME

$codeB  = $nodeBobj.parameters.jsCode
$codeC  = $nodeCobj.parameters.jsCode
$codeJ  = $nodeJobj.parameters.jsCode
$codeP2A = $nodeP2Aobj.parameters.jsCode

$errors = 0

if (-not $codeB.Contains($P1_OLD)) {
    Write-Host "  [FAIL] Patch 1 target not found in Node B" -ForegroundColor Red
    $errors++
} else {
    Write-Host "  [OK] Patch 1 target found in Node B" -ForegroundColor Green
}

if (-not $codeC.Contains($P2_OLD)) {
    Write-Host "  [FAIL] Patch 2 target not found in Node C" -ForegroundColor Red
    $errors++
} else {
    Write-Host "  [OK] Patch 2 target found in Node C" -ForegroundColor Green
}

if (-not $codeJ.Contains($P3_OLD_STR)) {
    Write-Host "  [FAIL] Patch 3 target not found in Node J" -ForegroundColor Red
    $errors++
} else {
    Write-Host "  [OK] Patch 3 target found in Node J" -ForegroundColor Green
}

if (-not $codeP2A.Contains($P4_OLD_STR)) {
    Write-Host "  [FAIL] Patch 4 target not found in SL-P2A" -ForegroundColor Red
    $errors++
} else {
    Write-Host "  [OK] Patch 4 target found in SL-P2A" -ForegroundColor Green
}

# Safety: ensure new strings are NOT already present (idempotency check)
foreach ($pair in @(
    @{ label="Patch 1 (Node B)"; code=$codeB; new="DATA_PRIVACY_INQUIRY" },
    @{ label="Patch 2 (Node C)"; code=$codeC; new="GDPR/data-inquiry (det-legal-001) is not an opt-out" },
    @{ label="Patch 3 (Node J)"; code=$codeJ; new="Leave corrected fields blank" },
    @{ label="Patch 4 (SL-P2A)"; code=$codeP2A; new="feedback_only" }
)) {
    if ($pair.code.Contains($pair.new)) {
        Write-Host "  [SKIP] $($pair.label): patch already applied (idempotency)" -ForegroundColor Yellow
    }
}

if ($errors -gt 0) {
    Write-Error "BLOCKED: $errors patch target(s) not found. Aborting."
    exit 1
}

# ── Safety: verify new code does NOT touch forbidden paths ───────────────────
$forbidden = @("Sender","Intake","ErrorHandler","SLAWatchdog","FullTestHarness","autonomous","DRY_RUN=false","LIVE_CAMPAIGNS")
foreach ($f in $forbidden) {
    if ($P1_NEW.Contains($f) -or $P2_NEW.Contains($f) -or $P3_NEW_STR.Contains($f) -or $P4_NEW_STR.Contains($f)) {
        Write-Error "SAFETY: new patch code references forbidden term '$f'"; exit 1
    }
}
Write-Host "  [OK] No forbidden terms in new patch code" -ForegroundColor Green

# ── Apply patches to code strings ────────────────────────────────────────────
$newCodeB   = $codeB.Replace($P1_OLD, $P1_NEW)
$newCodeC   = $codeC.Replace($P2_OLD, $P2_NEW)
$newCodeJ   = $codeJ.Replace($P3_OLD_STR, $P3_NEW_STR)
$newCodeP2A = $codeP2A.Replace($P4_OLD_STR, $P4_NEW_STR)

# Verify replacements actually changed the code
$changed = @()
if ($newCodeB -ne $codeB)   { $changed += "Node B" }
if ($newCodeC -ne $codeC)   { $changed += "Node C" }
if ($newCodeJ -ne $codeJ)   { $changed += "Node J" }
if ($newCodeP2A -ne $codeP2A) { $changed += "SL-P2A" }

Write-Host ""
Write-Host "Patches that would change code: $($changed -join ', ')" -ForegroundColor Cyan

# ── WhatIf output ─────────────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host ""
    Write-Host "=== WHATIF DIFF ===" -ForegroundColor Cyan

    Show-Diff "Node B: detectMicroIntent — LEGAL_PRIVACY_OR_COMPLAINT handling" `
        $P1_OLD $P1_NEW

    Show-Diff "Node C: LEGAL_PRIVACY_OR_COMPLAINT override — durable_dnc_intent" `
        $P2_OLD $P2_NEW

    Show-Diff "Node J: Corrected micro intent field — add help text" `
        "(corrected_micro_intent input, then correction_reason input)" `
        "(corrected_micro_intent input, then help text paragraph, then correction_reason input)"

    Show-Diff "SL-P2A: correction event status — add feedback_only" `
        $P4_OLD_STR $P4_NEW_STR

    Write-Host ""
    Write-Host "WhatIf complete. No production changes made." -ForegroundColor Green
    Write-Host "Run with -Apply -OwnerConfirmedApply YES to apply." -ForegroundColor Yellow
    exit 0
}

# ── Apply ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Applying patches..." -ForegroundColor Red

# --- Decision workflow: update Node B and Node C ---
$wfDNodes = $wfD.nodes | ForEach-Object {
    if ($_.name -eq $NODE_B_NAME) {
        $n = [pscustomobject]($_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $n.parameters.jsCode = $newCodeB
        return $n
    } elseif ($_.name -eq $NODE_C_NAME) {
        $n = [pscustomobject]($_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $n.parameters.jsCode = $newCodeC
        return $n
    }
    return $_
}

$wfDBody = @{
    name       = $wfD.name
    nodes      = $wfDNodes
    connections = $wfD.connections
    settings   = $wfD.settings
    staticData = $wfD.staticData
}

Write-Host "  Patching Decision workflow..." -ForegroundColor Gray
$wfDResult = Patch-Workflow $WF_DECISION $wfDBody
Write-Host "  Decision versionId after: $($wfDResult.versionId)" -ForegroundColor Green

# --- HumanApproval workflow: update Node J and SL-P2A ---
$wfANodes = $wfA.nodes | ForEach-Object {
    if ($_.name -eq $NODE_J_NAME) {
        $n = [pscustomobject]($_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $n.parameters.jsCode = $newCodeJ
        return $n
    } elseif ($_.name -eq $NODE_P2A_NAME) {
        $n = [pscustomobject]($_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $n.parameters.jsCode = $newCodeP2A
        return $n
    }
    return $_
}

$wfABody = @{
    name       = $wfA.name
    nodes      = $wfANodes
    connections = $wfA.connections
    settings   = $wfA.settings
    staticData = $wfA.staticData
}

Write-Host "  Patching HumanApproval workflow..." -ForegroundColor Gray
$wfAResult = Patch-Workflow $WF_APPROVAL $wfABody
Write-Host "  HumanApproval versionId after: $($wfAResult.versionId)" -ForegroundColor Green

# ── Post-apply verification ───────────────────────────────────────────────────
Write-Host ""
Write-Host "Verifying applied patches..." -ForegroundColor Cyan

$wfDCheck = Get-Workflow $WF_DECISION
$wfACheck = Get-Workflow $WF_APPROVAL

$nodeBCheck  = Find-Node $wfDCheck $NODE_B_NAME
$nodeCCheck  = Find-Node $wfDCheck $NODE_C_NAME
$nodeJCheck  = Find-Node $wfACheck $NODE_J_NAME
$nodeP2ACheck = Find-Node $wfACheck $NODE_P2A_NAME

$verifyErrors = 0

if (-not $nodeBCheck.parameters.jsCode.Contains("DATA_PRIVACY_INQUIRY")) {
    Write-Host "  [FAIL] Node B: DATA_PRIVACY_INQUIRY not found after apply" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] Node B: DATA_PRIVACY_INQUIRY present" -ForegroundColor Green }

if ($nodeBCheck.parameters.jsCode.Contains("category === 'UNSUBSCRIBE' || category === 'LEGAL_PRIVACY_OR_COMPLAINT'")) {
    Write-Host "  [FAIL] Node B: old combined condition still present" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] Node B: old combined condition removed" -ForegroundColor Green }

if (-not $nodeCCheck.parameters.jsCode.Contains("GDPR/data-inquiry (det-legal-001) is not an opt-out")) {
    Write-Host "  [FAIL] Node C: fix comment not found" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] Node C: durable_dnc_intent fix present" -ForegroundColor Green }

if ($nodeCCheck.parameters.jsCode.Contains("plan.durable_dnc_intent = !!detFlags['det-legal-001']")) {
    Write-Host "  [FAIL] Node C: old durable_dnc line still present" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] Node C: old durable_dnc line removed" -ForegroundColor Green }

if (-not $nodeJCheck.parameters.jsCode.Contains("Leave corrected fields blank")) {
    Write-Host "  [FAIL] Node J: help text not found" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] Node J: help text present" -ForegroundColor Green }

if (-not $nodeP2ACheck.parameters.jsCode.Contains("feedback_only")) {
    Write-Host "  [FAIL] SL-P2A: feedback_only not found" -ForegroundColor Red
    $verifyErrors++
} else { Write-Host "  [OK] SL-P2A: feedback_only status present" -ForegroundColor Green }

Write-Host ""
if ($verifyErrors -gt 0) {
    Write-Host "VERIFICATION FAILED: $verifyErrors check(s) failed. Investigate before retrying." -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== APPLY COMPLETE ===" -ForegroundColor Green
    Write-Host "Decision versionId:      $($wfDCheck.versionId)" -ForegroundColor Cyan
    Write-Host "HumanApproval versionId: $($wfACheck.versionId)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Nodes patched:" -ForegroundColor Cyan
    Write-Host "  Decision / Node B:   detectMicroIntent — LEGAL_PRIVACY now returns DATA_PRIVACY_INQUIRY / LEGAL_COMPLAINT / LEGAL_PRIVACY_INQUIRY" -ForegroundColor White
    Write-Host "  Decision / Node C:   durable_dnc_intent = false for LEGAL_PRIVACY_OR_COMPLAINT (REVIEW_HOLD, not ORGANISATION_DNC)" -ForegroundColor White
    Write-Host "  HumanApproval / J:   Help text added — blank corrected fields = no change" -ForegroundColor White
    Write-Host "  HumanApproval / P2A: correction_reason-only capture → status=feedback_only" -ForegroundColor White
    Write-Host ""
    Write-Host "Nodes NOT patched (intentional):" -ForegroundColor Gray
    Write-Host "  Sender, Intake, ErrorHandler, SLAWatchdog, FullTestHarness, Node D, Node A" -ForegroundColor Gray
}
