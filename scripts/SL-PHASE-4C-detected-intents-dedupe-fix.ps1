#Requires -Version 7.0
# SL-PHASE-4C-detected-intents-dedupe-fix.ps1
#
# Fixes the detectAllIntents de-duplication gap in the Decision workflow.
# Problem: detectAllIntents() returns secondary intents that duplicate the primary.
# Fix:     Filter detected intents where micro_intent === primaryMicroIntent before
#          assigning to detectedIntents.
#
# Scope: Decision workflow (tgYmY97CG4Bm8snI), Code node "B. Classify ..." only.
# Does NOT modify: Sender, HumanApproval, Intake, ErrorHandler, SLAWatchdog, FTH.
# Does NOT change: AI behaviour, routing, suppression, autonomous mode.
#
# Usage:
#   .\SL-PHASE-4C-detected-intents-dedupe-fix.ps1 -WhatIf    # preview only
#   .\SL-PHASE-4C-detected-intents-dedupe-fix.ps1 -Apply     # apply to production

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($WhatIf -and $Apply)  { Write-Error "Use -WhatIf OR -Apply, not both."; exit 1 }
if (-not $WhatIf -and -not $Apply) { Write-Error "Specify -WhatIf or -Apply."; exit 1 }

$ApiKey         = $env:HMZ_N8N_API_KEY
$Base           = "https://n8n.hmzaiautomation.com/api/v1"
$DecisionWfId   = "tgYmY97CG4Bm8snI"
$ProhibitedWfIds = @("9aPrt92jFhoYFxbs","ePS5uBBxKxhFCYgU","RLUcJHQJPvLhw4mG")
$Headers        = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }

# ── Safety guard ─────────────────────────────────────────────────────────────
if (-not $ApiKey) { Write-Error "HMZ_N8N_API_KEY not set."; exit 1 }

Write-Host "`n=== SL-PHASE-4C Detected-Intents De-dup Fix ===" -ForegroundColor Cyan
Write-Host "Mode:   $(if ($WhatIf) { 'WhatIf (no production changes)' } else { 'Apply (production)' })" -ForegroundColor $(if ($WhatIf) {'Yellow'} else {'Red'})
Write-Host "Target: Decision workflow $DecisionWfId"
Write-Host "Target: https://n8n.hmzaiautomation.com"
Write-Host ""

# ── Fetch Decision workflow ───────────────────────────────────────────────────
Write-Host "Fetching Decision workflow..." -ForegroundColor Gray
$wf = Invoke-RestMethod -Uri "$Base/workflows/$DecisionWfId" -Headers $Headers -Method GET -TimeoutSec 20
Write-Host "[OK] Fetched: '$($wf.name)' | active=$($wf.active) | versionId=$($wf.versionId)" -ForegroundColor Green

# ── Safety: confirm we are on Decision, not a prohibited workflow ─────────────
if ($wf.id -in $ProhibitedWfIds) {
    Write-Error "SAFETY: Attempted to patch a prohibited workflow ($($wf.id)). Aborting."; exit 1
}

# ── Find the Code node in DEC-B that contains detectAllIntents ───────────────
$SEARCH_PATTERN = 'detectAllIntents(combined, category, microIntent, det.flags'
$DEDUP_ANCHOR   = 'const detectedIntents = detectAllIntents(combined, category, microIntent, det.flags || {});'
$DEDUP_REPLACE  = 'const detectedIntents = detectAllIntents(combined, category, microIntent, det.flags || {}).filter(function(i){ return i.micro_intent !== microIntent; });'

$targetNode = $null
$targetIdx  = -1
for ($i = 0; $i -lt $wf.nodes.Count; $i++) {
    $node = $wf.nodes[$i]
    if ($node.type -eq 'n8n-nodes-base.code') {
        $jsCode = if ($node.parameters.jsCode) { $node.parameters.jsCode }
                  elseif ($node.parameters.code) { $node.parameters.code }
                  else { "" }
        if ($jsCode -match [regex]::Escape($SEARCH_PATTERN)) {
            $targetNode = $node
            $targetIdx  = $i
            break
        }
    }
}

if ($null -eq $targetNode) {
    Write-Error "Could not find the Code node containing '$SEARCH_PATTERN'. Has the production code changed?"; exit 1
}
Write-Host "[OK] Found target Code node: '$($targetNode.name)' (index $targetIdx)" -ForegroundColor Green

$currentCode = if ($targetNode.parameters.jsCode) { $targetNode.parameters.jsCode }
               else { $targetNode.parameters.code }

# ── Check if fix is already applied ──────────────────────────────────────────
if ($currentCode -match [regex]::Escape($DEDUP_REPLACE)) {
    Write-Host "[OK] De-dup fix already present. Nothing to do." -ForegroundColor Green
    exit 0
}

# ── Verify the anchor exists ──────────────────────────────────────────────────
if (-not ($currentCode -match [regex]::Escape($DEDUP_ANCHOR))) {
    Write-Error "Anchor not found in node '$($targetNode.name)'. Expected:`n  $DEDUP_ANCHOR`n`nProduction code may have changed. Inspect before proceeding."; exit 1
}
Write-Host "[OK] Anchor found in node '$($targetNode.name)'" -ForegroundColor Green

# ── Show the diff ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "── Change ──────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Node:    $($targetNode.name)" -ForegroundColor White
Write-Host "  BEFORE:  $DEDUP_ANCHOR" -ForegroundColor Yellow
Write-Host "  AFTER:   $DEDUP_REPLACE" -ForegroundColor Green
Write-Host ""
Write-Host "── Safety ──────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  [OK] Only Decision workflow $DecisionWfId modified." -ForegroundColor Green
Write-Host "  [OK] Single line change: add .filter() to detectedIntents assignment." -ForegroundColor Green
Write-Host "  [OK] Primary routing (primaryMicroIntent) unchanged." -ForegroundColor Green
Write-Host "  [OK] AI_COMMERCIAL_SUPERVISED upgrade gate unchanged." -ForegroundColor Green
Write-Host "  [OK] No Sender, HumanApproval, or other workflow changes." -ForegroundColor Green
Write-Host "  [OK] No autonomous sending enabled." -ForegroundColor Green
Write-Host "  [OK] No safety gates weakened." -ForegroundColor Green
Write-Host ""

# Verify key features still present.
# Node-B checks: search patched node B code only.
# Cross-workflow checks: search ALL nodes in the workflow (calendar link and raw_draft_text live in node D).
$patchedCode = $currentCode -replace [regex]::Escape($DEDUP_ANCHOR), $DEDUP_REPLACE
$allNodesCode = ($wf.nodes | ForEach-Object {
    $n = $_
    $c = ""
    try { if ($n.parameters.jsCode) { $c = $n.parameters.jsCode } } catch {}
    try { if (-not $c -and $n.parameters.code) { $c = $n.parameters.code } } catch {}
    $c
}) -join "`n"
# For node B, also apply the simulated patch
$allNodesCode = $allNodesCode -replace [regex]::Escape($DEDUP_ANCHOR), $DEDUP_REPLACE

$checks = @(
    @{ M='detectAllIntents';           L='detectAllIntents still present (node B)';   Scope=$patchedCode },
    @{ M='isCommercialSafe';           L='isCommercialSafe still present (node B)';    Scope=$patchedCode },
    @{ M='AI_COMMERCIAL_SUPERVISED';   L='AI_COMMERCIAL_SUPERVISED still present';     Scope=$allNodesCode },
    @{ M='bNXWJkS3xz3yqdW36';         L='Calendar link still present (node D)';       Scope=$allNodesCode },
    @{ M='raw_draft_text';             L='raw_draft_text logging still present (node D)'; Scope=$allNodesCode },
    @{ M='PRICING_REQUEST';            L='PRICING_REQUEST routing still present (node B)'; Scope=$patchedCode }
)
$allChecksPass = $true
foreach ($c in $checks) {
    if ($c.Scope -match [regex]::Escape($c.M)) {
        Write-Host "  [OK] $($c.L)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($c.L)" -ForegroundColor Red
        $allChecksPass = $false
    }
}

if (-not $allChecksPass) {
    Write-Error "Pre-apply checks failed. Aborting."; exit 1
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "=== WhatIf: PASS — No production changes made. Run -Apply to apply. ===" -ForegroundColor Yellow
    exit 0
}

# ── Apply the patch ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Applying patch to production Decision workflow..." -ForegroundColor Yellow

# Update node code in-memory
if ($targetNode.parameters.jsCode) {
    $wf.nodes[$targetIdx].parameters.jsCode = $patchedCode
} else {
    $wf.nodes[$targetIdx].parameters.code = $patchedCode
}

$putBody = [ordered]@{
    name        = $wf.name
    nodes       = $wf.nodes
    connections = $wf.connections
    settings    = $wf.settings
    staticData  = $wf.staticData
} | ConvertTo-Json -Depth 50 -Compress

try {
    $updated = Invoke-RestMethod -Uri "$Base/workflows/$DecisionWfId" -Headers $Headers -Method PUT -Body $putBody -TimeoutSec 30
    Write-Host "[OK] PUT accepted. New versionId: $($updated.versionId)" -ForegroundColor Green
} catch {
    Write-Error "PUT failed: $($_.Exception.Message)"; exit 1
}

# ── Verify ───────────────────────────────────────────────────────────────────
Write-Host "Verifying production state..." -ForegroundColor Gray
$v = Invoke-RestMethod -Uri "$Base/workflows/$DecisionWfId" -Headers $Headers -Method GET -TimeoutSec 20
$vNode = $v.nodes[$targetIdx]
$vCode = if ($vNode.parameters.jsCode) { $vNode.parameters.jsCode } else { $vNode.parameters.code }

if ($vCode -match [regex]::Escape($DEDUP_REPLACE)) {
    Write-Host "[OK] De-dup filter VERIFIED in production node '$($vNode.name)'" -ForegroundColor Green
} else {
    Write-Error "VERIFICATION FAILED: De-dup filter not found after PUT. Check production manually."; exit 1
}
if ($vCode -match [regex]::Escape($DEDUP_ANCHOR)) {
    Write-Error "VERIFICATION FAILED: Old anchor still present — replace did not work."; exit 1
}

Write-Host ""
Write-Host "=== SL-PHASE-4C De-dup Fix: APPLIED AND VERIFIED ===" -ForegroundColor Green
Write-Host "  Decision versionId: $($v.versionId)" -ForegroundColor Green
Write-Host "  Change: detected intents now exclude primary micro intent from secondary list." -ForegroundColor Green
Write-Host "  Run harness to confirm: scripts\SL-PHASE-4B-offline-commercial-scenario-harness.ps1" -ForegroundColor Gray
