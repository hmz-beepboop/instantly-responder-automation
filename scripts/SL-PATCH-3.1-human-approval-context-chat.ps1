#Requires -Version 7
<#
.SYNOPSIS
  SL-PATCH-3.1 -- HumanApproval Google Chat context fields (surgical).

.DESCRIPTION
  SURGICAL patch -- only adds missing fields; never rewrites full node logic.

  Node A (Build Review Case Record):
    Inserts reply_from_name, reply_from_email, sender_name, sender_email
    into sanitized_context, immediately after recommended_action_plan.
    All other existing fields, CONFIG block, SENDER_CONFIG, token logic,
    sender_handoff, and review_case structure are untouched.

  Node D (Build Google Chat Notification Payload):
    Replaces the existing 4-line chat block with a 12-line block that adds:
    From, Sender, Micro intent, Draft policy, Draft source.
    ctx.reply_from_* and ctx.sender_* come from sanitized_context (Node A).
    rc.micro_intent / rc.draft_policy / rc.draft_source come from review_case
    which already has them as top-level fields.

  Only modifies workflow 9aPrt92jFhoYFxbs (HumanApproval).
  Backs up all 7 workflows before writing anything.

  Run -WhatIf first. Only run -Apply after WHATIF_OK is confirmed.

.PARAMETER WhatIf
  Validate only. Nothing is written.

.PARAMETER Apply
  Apply the patch: PUT HumanApproval, verify live markers, reactivate if needed.
#>
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not ($WhatIf -or $Apply)) {
    Write-Host "Usage:"
    Write-Host "  .\SL-PATCH-3.1-human-approval-context-chat.ps1 -WhatIf"
    Write-Host "  .\SL-PATCH-3.1-human-approval-context-chat.ps1 -Apply"
    exit 1
}
if ($WhatIf -and $Apply) {
    Write-Error "Specify -WhatIf OR -Apply, not both."; exit 1
}

# ── Constants ──────────────────────────────────────────────────────────────
$N8N_BASE = "https://n8n.hmzaiautomation.com/api/v1"
$HA_ID    = "9aPrt92jFhoYFxbs"
$FTH_ID   = "RLUcJHQJPvLhw4mG"
$MODE     = if ($Apply) { "APPLY" } else { "WHATIF" }

$ALL_WF = [ordered]@{
    Intake          = "VtDQqw02Ux1TgjIH"
    Decision        = "tgYmY97CG4Bm8snI"
    HumanApproval   = "9aPrt92jFhoYFxbs"
    Sender          = "ePS5uBBxKxhFCYgU"
    ErrorHandler    = "2PR9YEkG4KyGdowa"
    SLAWatchdog     = "6a8ojyXCwMwI9nyF"
    FullTestHarness = "RLUcJHQJPvLhw4mG"
}

Write-Host ""
Write-Host "========================================================================"
Write-Host "  SL-PATCH-3.1  HumanApproval Google Chat context fields (surgical)"
Write-Host "  Mode: $MODE"
Write-Host "========================================================================"

# ── n8n helpers ───────────────────────────────────────────────────────────
function Invoke-N8nGet([string]$Path) {
    $k = $env:HMZ_N8N_API_KEY
    if (-not $k) { throw "HMZ_N8N_API_KEY not set" }
    Invoke-RestMethod -Uri "$N8N_BASE$Path" `
        -Headers @{ "X-N8N-API-KEY" = $k } `
        -Method GET -ErrorAction Stop
}
function Invoke-N8nPut([string]$Path, [string]$Body) {
    $k = $env:HMZ_N8N_API_KEY
    Invoke-RestMethod -Uri "$N8N_BASE$Path" `
        -Headers @{ "X-N8N-API-KEY" = $k; "Content-Type" = "application/json" } `
        -Method PUT -Body $Body -ErrorAction Stop
}
function Invoke-N8nPost([string]$Path) {
    $k = $env:HMZ_N8N_API_KEY
    Invoke-RestMethod -Uri "$N8N_BASE$Path" `
        -Headers @{ "X-N8N-API-KEY" = $k; "Content-Type" = "application/json" } `
        -Method POST -Body '{}' -ErrorAction Stop
}

# ── [1/8] Auth ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[1/8] Auth check..."
if (-not $env:HMZ_N8N_API_KEY) {
    Write-Host ""
    Write-Host "STOP: HMZ_N8N_API_KEY is not set."
    Write-Host "Run this in your terminal, then retry:"
    Write-Host '  $env:HMZ_N8N_API_KEY = "<paste-key-here>"'
    exit 1
}
try {
    Invoke-N8nGet "/workflows?limit=1" | Out-Null
    Write-Host "  AUTH=OK"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host ""
    Write-Host "STOP: Auth failed (HTTP $code)."
    Write-Host "Reset the key in this terminal:"
    Write-Host '  $env:HMZ_N8N_API_KEY = "<paste-key-here>"'
    exit 1
}

# ── [2/8] FTH guard ───────────────────────────────────────────────────────
Write-Host "[2/8] Full Test Harness guard..."
$fthCheck = Invoke-N8nGet "/workflows/$FTH_ID"
if ($fthCheck.active -eq $true) {
    Write-Error "STOP: Full Test Harness ($FTH_ID) is ACTIVE. Deactivate it before patching."
    exit 1
}
Write-Host "  FTH_ACTIVE=false  OK"

# ── [3/8] Backup all 7 workflows ──────────────────────────────────────────
Write-Host "[3/8] Backing up all 7 workflows..."
$ts     = Get-Date -Format "yyyyMMdd_HHmmss"
$bakDir = "C:\Users\Hamzah Zahid\Downloads\n8n_backups\SL-PATCH-3.1_$ts"
New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
foreach ($wfName in $ALL_WF.Keys) {
    $id = $ALL_WF[$wfName]
    $wf = Invoke-N8nGet "/workflows/$id"
    $wf | ConvertTo-Json -Depth 30 |
        Set-Content -Path "$bakDir\${wfName}_${id}.json" -Encoding utf8
    Write-Host "  BACKED_UP: $wfName ($id)"
}
Write-Host "  BACKUP_DIR: $bakDir"

# ── [4/8] Load HumanApproval ──────────────────────────────────────────────
Write-Host "[4/8] Loading HumanApproval ($HA_ID)..."
$ha = Invoke-N8nGet "/workflows/$HA_ID"
Write-Host "  HA_ACTIVE=$($ha.active)  HA_NODES=$($ha.nodes.Count)"

# ── [5/8] Locate nodes by index ───────────────────────────────────────────
Write-Host "[5/8] Locating nodes A and D..."
$idxA = -1; $idxD = -1
for ($i = 0; $i -lt $ha.nodes.Count; $i++) {
    if ($ha.nodes[$i].name -eq "A. Build Review Case Record")               { $idxA = $i }
    if ($ha.nodes[$i].name -eq "D. Build Google Chat Notification Payload") { $idxD = $i }
}
if ($idxA -lt 0) {
    Write-Error "STOP: 'A. Build Review Case Record' not found in HA nodes."; exit 1
}
if ($idxD -lt 0) {
    Write-Error "STOP: 'D. Build Google Chat Notification Payload' not found in HA nodes."; exit 1
}
Write-Host "  NODE_A=idx[$idxA]  NODE_D=idx[$idxD]"

# ── [6/8] Idempotency + anchor validation ─────────────────────────────────
Write-Host "[6/8] Idempotency and anchor checks..."

# Normalise to LF to match JSON-parsed strings
$jsA = $ha.nodes[$idxA].parameters.jsCode -replace "`r`n", "`n"
$jsD = $ha.nodes[$idxD].parameters.jsCode -replace "`r`n", "`n"

if ($jsA -match "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CTX") {
    Write-Host "  SKIPPED: Node A already patched (SL_PATCH_3_1_CTX marker present)."
    Write-Host "WHATIF_OK=SKIPPED_ALREADY_PATCHED"
    exit 0
}
if ($jsD -match "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT") {
    Write-Host "  SKIPPED: Node D already patched (SL_PATCH_3_1_CHAT marker present)."
    Write-Host "WHATIF_OK=SKIPPED_ALREADY_PATCHED"
    exit 0
}

# ── Anchor strings (single-quoted = no PowerShell interpolation) ──────────
# Node A: unique 2-line sequence at end of sanitized_context
$anchorA_old = @(
    '    recommended_action_plan: decision || {},'
    '    sender_handoff: {'
) -join "`n"

# Node D: exact 4-line block currently in production
$anchorD_old = @(
    '  lines.push("New reply review case: " + (rc.case_id || "UNKNOWN_CASE"));'
    '  lines.push("Category: " + (ctx.category || rc.category || "UNKNOWN") + " | Urgency: " + (ctx.urgency || rc.urgency || "routine"));'
    '  lines.push("Reply excerpt: " + snippet);'
    '  lines.push("Review: " + reviewUrl);'
) -join "`n"

if ($jsA.IndexOf($anchorA_old) -lt 0) {
    Write-Error "STOP: Node A anchor not found. jsCode may have changed. Safe-abort."
    exit 1
}
Write-Host "  NODE_A_ANCHOR=found (unique)"

if ($jsD.IndexOf($anchorD_old) -lt 0) {
    Write-Error "STOP: Node D anchor not found. jsCode may have changed. Safe-abort."
    exit 1
}
Write-Host "  NODE_D_ANCHOR=found (unique)"

# ── [7/8] Build patch strings ─────────────────────────────────────────────
Write-Host "[7/8] Building patches..."

# ── Node A replacement ────────────────────────────────────────────────────
# Inserts 4 new fields into sanitized_context immediately before sender_handoff.
# micro_intent/draft_policy/draft_source stay in review_case (already present).
# Multiple reply.from* paths tried in order -- graceful null if none match.
$anchorA_new = @(
    '    recommended_action_plan: decision || {},'
    '    // HMZ_INJECT_BEGIN:SL_PATCH_3_1_CTX'
    '    reply_from_name: (reply.from_address_name || reply.from_name || reply.name || nes.contact_name || nes.from_name || caseInput.first_name) || null,'
    '    reply_from_email: (reply.from_address_email || reply.from_address || reply.from_email || reply.from || nes.prospect_email || nes.from_email || nes.from || (caseInput.raw_payload && (caseInput.raw_payload.from_address || caseInput.raw_payload.from))) || null,'
    '    sender_name: templateVariables.senderName || null,'
    '    sender_email: eaccount || null,'
    '    // HMZ_INJECT_END:SL_PATCH_3_1_CTX'
    '    sender_handoff: {'
) -join "`n"

# ── Node D replacement ────────────────────────────────────────────────────
# Replaces the 4-line block with a 12-line block.
# ctx.reply_from_* / ctx.sender_* -- from sanitized_context (Node A adds them).
# rc.micro_intent / rc.draft_policy / rc.draft_source -- from review_case top-level
#   (already present as review_case.micro_intent etc from prior patches).
$anchorD_new = @(
    '  lines.push("New reply review case: " + (rc.case_id || "UNKNOWN_CASE"));'
    '  // HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT'
    '  lines.push("From: " + (ctx.reply_from_name ? (ctx.reply_from_name + " <" + (ctx.reply_from_email || "?") + ">") : (ctx.reply_from_email || "UNKNOWN")));'
    '  lines.push("Sender: " + (ctx.sender_name || "?") + " <" + (ctx.sender_email || "?") + ">");'
    '  // HMZ_INJECT_END:SL_PATCH_3_1_CHAT'
    '  lines.push("Category: " + (ctx.category || rc.category || "UNKNOWN") + " | Urgency: " + (ctx.urgency || rc.urgency || "routine"));'
    '  // HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT_INTENT'
    '  lines.push("Micro intent: " + (ctx.micro_intent || rc.micro_intent || "N/A"));'
    '  lines.push("Draft policy: " + (ctx.draft_policy || rc.draft_policy || "N/A"));'
    '  lines.push("Draft source: " + (ctx.draft_source || rc.draft_source || "N/A"));'
    '  // HMZ_INJECT_END:SL_PATCH_3_1_CHAT_INTENT'
    '  lines.push("Reply excerpt: " + snippet);'
    '  lines.push("Review: " + reviewUrl);'
) -join "`n"

$patchedA = $jsA.Replace($anchorA_old, $anchorA_new)
$patchedD = $jsD.Replace($anchorD_old, $anchorD_new)

# Verify replacements produced actual changes
if ($patchedA -ceq $jsA) {
    Write-Error "STOP: Node A replacement produced no change. Anchor mismatch."; exit 1
}
if ($patchedD -ceq $jsD) {
    Write-Error "STOP: Node D replacement produced no change. Anchor mismatch."; exit 1
}
Write-Host "  NODE_A_DELTA=+$($patchedA.Length - $jsA.Length) chars"
Write-Host "  NODE_D_DELTA=+$($patchedD.Length - $jsD.Length) chars"

# Verify patch markers are present in patched strings
if ($patchedA -notmatch "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CTX") {
    Write-Error "STOP: Node A marker missing from patched code. Aborting."; exit 1
}
if ($patchedA -notmatch "HMZ_INJECT_END:SL_PATCH_3_1_CTX") {
    Write-Error "STOP: Node A end-marker missing from patched code. Aborting."; exit 1
}
if ($patchedD -notmatch "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT") {
    Write-Error "STOP: Node D begin-marker missing from patched code. Aborting."; exit 1
}
if ($patchedD -notmatch "HMZ_INJECT_END:SL_PATCH_3_1_CHAT_INTENT") {
    Write-Error "STOP: Node D end-marker missing from patched code. Aborting."; exit 1
}
Write-Host "  MARKERS=verified (begin + end for both nodes)"

# Verify key field names appear in patched strings
foreach ($f in @("reply_from_name", "reply_from_email", "sender_name", "sender_email")) {
    if ($patchedA -notmatch $f) {
        Write-Error "STOP: Field '$f' missing from patched Node A code."; exit 1
    }
}
foreach ($f in @('"From: "', '"Sender: "', '"Micro intent: "', '"Draft policy: "', '"Draft source: "')) {
    if ($patchedD -notmatch [regex]::Escape($f)) {
        Write-Error "STOP: Line '$f' missing from patched Node D code."; exit 1
    }
}
Write-Host "  FIELD_NAMES=verified in both nodes"

# ── WhatIf exits here ──────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host ""
    Write-Host "------------------------------------------------------------------------"
    Write-Host "  WHATIF_OK"
    Write-Host "  No changes were written."
    Write-Host ""
    Write-Host "  Node A will gain in sanitized_context:"
    Write-Host "    reply_from_name, reply_from_email, sender_name, sender_email"
    Write-Host ""
    Write-Host "  Node D Google Chat will show:"
    Write-Host "    From: <prospect name/email>"
    Write-Host "    Sender: <sender name> <sender email>"
    Write-Host "    Category: ... | Urgency: ..."
    Write-Host "    Micro intent: ..."
    Write-Host "    Draft policy: ..."
    Write-Host "    Draft source: ..."
    Write-Host "    Reply excerpt: ..."
    Write-Host "    Review: <url>"
    Write-Host "------------------------------------------------------------------------"
    exit 0
}

# ── [8/8] Apply ───────────────────────────────────────────────────────────
Write-Host "[8/8] Applying patch to HumanApproval only..."

$ha.nodes[$idxA].parameters.jsCode = $patchedA
$ha.nodes[$idxD].parameters.jsCode = $patchedD

# Build PUT body: send only the fields n8n expects for workflow updates
$putBody = [ordered]@{
    name        = $ha.name
    nodes       = $ha.nodes
    connections = $ha.connections
    settings    = $ha.settings
}
if ($null -ne $ha.staticData) { $putBody["staticData"] = $ha.staticData }
if ($null -ne $ha.pinData)    { $putBody["pinData"]    = $ha.pinData }

$putJson = $putBody | ConvertTo-Json -Depth 30 -Compress

Write-Host "  Sending PUT /workflows/$HA_ID ..."
$putResult = Invoke-N8nPut "/workflows/$HA_ID" $putJson
Write-Host "  PUT_OK  returned_name=$($putResult.name)"

# Verify markers in live workflow
Write-Host "  Verifying live markers via GET..."
$haVerify = Invoke-N8nGet "/workflows/$HA_ID"
$liveA = $haVerify.nodes | Where-Object { $_.name -eq "A. Build Review Case Record" }
$liveD = $haVerify.nodes | Where-Object { $_.name -eq "D. Build Google Chat Notification Payload" }
if ($liveA.parameters.jsCode -notmatch "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CTX") {
    Write-Error "STOP: Node A marker NOT found in live workflow after PUT."; exit 1
}
if ($liveD.parameters.jsCode -notmatch "HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT") {
    Write-Error "STOP: Node D marker NOT found in live workflow after PUT."; exit 1
}
Write-Host "  NODE_A_MARKER=verified_live"
Write-Host "  NODE_D_MARKER=verified_live"

# Reactivate if PUT deactivated the workflow
if (-not $haVerify.active) {
    Write-Host "  HA went inactive after PUT -- reactivating..."
    Invoke-N8nPost "/workflows/$HA_ID/activate" | Out-Null
    $haFinal = Invoke-N8nGet "/workflows/$HA_ID"
    if (-not $haFinal.active) {
        Write-Error "STOP: HumanApproval failed to reactivate after PUT. Investigate immediately."
        exit 1
    }
    Write-Host "  HA_REACTIVATED=true"
} else {
    Write-Host "  HA_ACTIVE=true (unchanged)"
}

# Final FTH guard
$fthFinal = Invoke-N8nGet "/workflows/$FTH_ID"
if ($fthFinal.active -eq $true) {
    Write-Warning "WARNING: Full Test Harness is now ACTIVE -- deactivate it immediately."
} else {
    Write-Host "  FTH_STILL_INACTIVE=true"
}

Write-Host ""
Write-Host "========================================================================"
Write-Host "  PATCH_APPLIED_AND_VERIFIED"
Write-Host "  Workflow patched: HumanApproval ($HA_ID)"
Write-Host "  Nodes changed: A (sanitized_context +4 fields) + D (chat +5 lines)"
Write-Host "  Backup: $bakDir"
Write-Host "========================================================================"
Write-Host ""
Write-Host "DO NOT run a live email send test."
Write-Host "NEXT: Run one fresh controlled responder test (webhook replay only)."
