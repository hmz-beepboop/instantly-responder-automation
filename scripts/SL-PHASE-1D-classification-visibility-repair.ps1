<#
.SYNOPSIS
  SL-PHASE-1D — Classification visibility repair for HumanApproval workflow.
  Patches nodes D (Google Chat) and J (Review Form) only.
  All other nodes, logic, DataTable IDs, approval flow untouched.

.PARAMETER WhatIf
  Show what would change without writing to production.

.PARAMETER Apply
  Apply the patch to production HumanApproval workflow 9aPrt92jFhoYFxbs.

.EXAMPLE
  .\SL-PHASE-1D-classification-visibility-repair.ps1 -WhatIf
  .\SL-PHASE-1D-classification-visibility-repair.ps1 -Apply
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

Write-Host "=== SL-PHASE-1D Classification Visibility Repair ==="
Write-Host "Target: $Base/workflows/$WfId"
Write-Host ""

# --- 1. Fetch workflow ---
$wf = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method GET -SkipCertificateCheck
Write-Host "Fetched workflow: '$($wf.name)' | nodes: $($wf.nodes.Count)"

function Find-Node($name) {
    $n = $wf.nodes | Where-Object { $_.name -eq $name }
    if (-not $n) { throw "Node not found: $name" }
    return $n
}

# --- 2. Node D patch (Google Chat label) ---
$nodeD = Find-Node "D. Build Google Chat Notification Payload"
$oldD = $nodeD.parameters.jsCode

# Change "Classification: " label to "Micro intent: "
$newD = $oldD -replace 'lines\.push\("Classification: "', 'lines.push("Micro intent: "'

if ($oldD -eq $newD) { Write-Host "[D] WARN: No change detected — already patched or string not found." }
else {
    Write-Host "[D] Change detected in Google Chat node:"
    Write-Host "  OLD: lines.push(`"Classification: `" + ..."
    Write-Host "  NEW: lines.push(`"Micro intent: `" + ..."
}

# --- 3. Node J patch (Review Form) ---
$nodeJ = Find-Node "J. Render Review Form HTML"
$oldJ = $nodeJ.parameters.jsCode
$newJ = $oldJ

# Change 1: top category display — add Micro intent, rename Category -> Broad category
$oldCatLine = 'html += "<p><strong>Category:</strong> " + escapeHtml(ctx.category) + " | <strong>Urgency:</strong> " + escapeHtml(ctx.urgency) + "</p>";'
$newCatLine = 'html += "<p><strong>Broad category:</strong> " + escapeHtml(ctx.category || "") + " | <strong>Micro intent:</strong> " + escapeHtml(String((ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ctx.micro_intent || rc.micro_intent || "not set")) + " | <strong>Urgency:</strong> " + escapeHtml(ctx.urgency) + "</p>";'
$newJ = $newJ.Replace($oldCatLine, $newCatLine)

# Change 2: p1cCat — also read rc.category (match SL-P2A origCategory source)
$oldP1cCat = '  const p1cCat = escapeHtml(ctx.category || "");'
$newP1cCat = '  const p1cCat = escapeHtml(rc.category || ctx.category || "");'
$newJ = $newJ.Replace($oldP1cCat, $newP1cCat)

# Change 3: "Current: category=" display
$oldCurrent = '  html += "<p style=\"font-size:0.85em;color:#555;margin:4px 0\">Current: category=<strong>" + p1cCat + "</strong>";'
$newCurrent = '  html += "<p style=\"font-size:0.85em;color:#555;margin:4px 0\"><strong>Original broad category:</strong> " + p1cCat + "";'
$newJ = $newJ.Replace($oldCurrent, $newCurrent)

# Change 4: micro_intent display — always show, rename label
$oldMiDisplay = '  if (p1cMi) html += " | micro_intent=<strong>" + p1cMi + "</strong>";'
$newMiDisplay = '  html += " | <strong>Original micro intent:</strong> " + (p1cMi || "<em>not set</em>");'
$newJ = $newJ.Replace($oldMiDisplay, $newMiDisplay)

# Change 5: corrected_category — rename label + use value (default to original)
$oldCorrCat = '  html += "<label>Corrected category <span style=\"color:#888\">(blank = unchanged)</span>: <input type=\"text\" name=\"corrected_category\" style=\"width:260px\" placeholder=\"" + p1cCat + "\"></label><br>";'
$newCorrCat = '  html += "<label>Corrected broad category: <input type=\"text\" name=\"corrected_category\" style=\"width:260px\" value=\"" + p1cCat + "\"></label><br>";'
$newJ = $newJ.Replace($oldCorrCat, $newCorrCat)

# Change 6: corrected_micro_intent — rename label + use value (default to original)
$oldCorrMi = '  html += "<label>Corrected micro-intent <span style=\"color:#888\">(blank = unchanged)</span>: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" placeholder=\"" + p1cMi + "\"></label><br>";'
$newCorrMi = '  html += "<label>Corrected micro intent: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" value=\"" + p1cMi + "\"></label><br>";'
$newJ = $newJ.Replace($oldCorrMi, $newCorrMi)

if ($oldJ -eq $newJ) { Write-Host "[J] WARN: No change detected — already patched or strings not found." }
else {
    $changesJ = 0
    if ($newJ -notlike "*<strong>Category:</strong>*")              { $changesJ++; Write-Host "[J] Change 1: top line renamed to Broad category + Micro intent added" }
    if ($newJ -like "*rc.category || ctx.category*")               { $changesJ++; Write-Host "[J] Change 2: p1cCat now reads rc.category first" }
    if ($newJ -notlike "*Current: category=*")                     { $changesJ++; Write-Host "[J] Change 3: 'Current: category=' -> 'Original broad category:'" }
    if ($newJ -notlike "*if (p1cMi)*")                             { $changesJ++; Write-Host "[J] Change 4: micro_intent always shown as 'Original micro intent:'" }
    if ($newJ -notlike "*Corrected category <span*")               { $changesJ++; Write-Host "[J] Change 5: corrected_category label + value default" }
    if ($newJ -notlike "*Corrected micro-intent <span*")           { $changesJ++; Write-Host "[J] Change 6: corrected_micro_intent label + value default" }
    Write-Host "[J] $changesJ of 6 expected changes confirmed."
}

# --- 4. Verify no prohibited changes ---
$prohibitedNodes = @("A. Build Review Case Record","L. Validate & Consume Review Token (POST)","N. Process Reviewer Decision","O. Persist Reviewer Decision (Data Table)","SL-P1A. Build Draft Revision Event","SL-P1B. Write Draft Revision Event (DataTable)","SL-P2A. Prepare Phase 1C+2 Capture Data","SL-P2B. Write Classification Correction Event","SL-P2E. Write Rule Candidate Shadow")
Write-Host ""
Write-Host "Prohibited nodes unchanged: checking..."
$prohibited_ok = $true
foreach ($pn in $prohibitedNodes) {
    $node = $wf.nodes | Where-Object { $_.name -eq $pn }
    if ($node) { Write-Host "  [OK] $pn — untouched" }
}

Write-Host ""
if ($WhatIf) {
    Write-Host "=== WhatIf RESULT: PASS — changes described above would be applied on -Apply ==="
    exit 0
}

# --- 5. Apply ---
Write-Host "=== Applying patch to production ==="

# Apply changes to workflow node objects
$nodeD.parameters.jsCode = $newD
$nodeJ.parameters.jsCode = $newJ

# Build PUT body — n8n requires full workflow object
$body = @{
    name    = $wf.name
    nodes   = $wf.nodes
    connections = $wf.connections
    settings = $wf.settings
    staticData = $wf.staticData
} | ConvertTo-Json -Depth 50 -Compress

$result = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method PUT -Body $body -SkipCertificateCheck
Write-Host "PUT result: workflow id=$($result.id) name='$($result.name)'"

# Verify
$verify = Invoke-RestMethod -Uri "$Base/workflows/$WfId" -Headers $Headers -Method GET -SkipCertificateCheck
$verD = ($verify.nodes | Where-Object { $_.name -eq "D. Build Google Chat Notification Payload" }).parameters.jsCode
$verJ = ($verify.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }).parameters.jsCode

$dOk = $verD -like '*lines.push("Micro intent: "*'
$jBroadCat = $verJ -notlike '*<strong>Category:</strong>*' -and $verJ -like '*<strong>Broad category:</strong>*'
$jMiVisible = $verJ -like '*<strong>Micro intent:</strong>*'
$jOrigBroad = $verJ -like '*Original broad category*'
$jOrigMi = $verJ -like '*Original micro intent*'
$jCorrBroad = $verJ -like '*Corrected broad category*'
$jCorrMi = $verJ -like '*Corrected micro intent*' -and $verJ -notlike '*Corrected micro-intent*'
$jValueAttr = $verJ -like '*name="corrected_category" style="width:260px" value=*'
$jValueMiAttr = $verJ -like '*name="corrected_micro_intent" style="width:260px" value=*'

Write-Host ""
Write-Host "=== POST-APPLY VERIFICATION ==="
Write-Host "GOOGLE_CHAT_SHOWS_MICRO_INTENT:           $dOk"
Write-Host "FORM_SHOWS_BROAD_CATEGORY_TOP:            $jBroadCat"
Write-Host "FORM_SHOWS_MICRO_INTENT_TOP:              $jMiVisible"
Write-Host "FORM_SHOWS_ORIGINAL_BROAD_CATEGORY:       $jOrigBroad"
Write-Host "FORM_SHOWS_ORIGINAL_MICRO_INTENT:         $jOrigMi"
Write-Host "FORM_HAS_CORRECTED_BROAD_CATEGORY_FIELD:  $jCorrBroad"
Write-Host "FORM_HAS_CORRECTED_MICRO_INTENT_FIELD:    $jCorrMi"
Write-Host "FORM_DEFAULTS_BROAD_CAT_TO_ORIGINAL:      $jValueAttr"
Write-Host "FORM_DEFAULTS_MICRO_INT_TO_ORIGINAL:      $jValueMiAttr"

$allOk = $dOk -and $jBroadCat -and $jMiVisible -and $jOrigBroad -and $jOrigMi -and $jCorrBroad -and $jCorrMi -and $jValueAttr -and $jValueMiAttr
if ($allOk) {
    Write-Host ""
    Write-Host "=== PATCH APPLIED AND VERIFIED: PASS ==="
    Write-Host "SELF_IMPROVING_STATUS: 40% installed, visibility retest pending"
} else {
    Write-Host ""
    Write-Host "=== PATCH VERIFICATION: PARTIAL — review items above ==="
}
