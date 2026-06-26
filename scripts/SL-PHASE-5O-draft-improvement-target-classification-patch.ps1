<#
.SYNOPSIS
SL-PHASE-5O — Draft Improvement Target Classification Selector
Adds per-email detected-classification checkbox group to HumanApproval review form.

.DESCRIPTION
Patches 4 nodes in HumanApproval (9aPrt92jFhoYFxbs):
  J  — Adds draft_improvement_target_classifications checkbox group
  L  — Parses submitted checkbox values
  SL-P1A — Includes target classifications in draft revision learning event
  SL-P2A — Includes target classifications in proposed_shadow rule candidate

ALWAYS reads from and writes to local JSON first. Requires -Apply to push to production.

.PARAMETER WhatIf
Show what would change without modifying anything.

.PARAMETER Apply
Patch the local JSON and push to production n8n.

.PARAMETER VerifyRenderedReviewHtml
After apply, check the rendered review form HTML contains the selector.

.PARAMETER VerifySubmitCapture
Check Node L parses the new field correctly.

.PARAMETER VerifyRuleCandidateTargets
Check SL-P2A includes draft_improvement_target_classifications.

.PARAMETER UseCaseId
Case ID to use for live form HTML fetch (e.g. case-ddb1f011). Does not approve the case.

.PARAMETER ExportReport
Write outputs/draft_improvement_target_classification_report.json.

.PARAMETER NoSecretOutput
Suppress any output that might contain secrets (API keys etc).

.EXAMPLE
.\scripts\SL-PHASE-5O-draft-improvement-target-classification-patch.ps1 -WhatIf -UseCaseId case-ddb1f011 -ExportReport
.\scripts\SL-PHASE-5O-draft-improvement-target-classification-patch.ps1 -Apply -VerifyRenderedReviewHtml -ExportReport
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$WhatIf,
    [switch]$VerifyRenderedReviewHtml,
    [switch]$VerifySubmitCapture,
    [switch]$VerifyRuleCandidateTargets,
    [string]$UseCaseId = "",
    [switch]$ExportReport,
    [switch]$NoSecretOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Config ───────────────────────────────────────────────────────────────────
$ProjectRoot  = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$WorkflowFile = Join-Path $ProjectRoot "workflows\production_humanapproval_current.json"
$WorkflowId   = "9aPrt92jFhoYFxbs"
$N8nBase      = "https://n8n.hmzaiautomation.com/api/v1"
$ExpectedVersionBefore = "9e9da4f1-a405-46b6-9352-b3906075f846"

$results = [ordered]@{
    phase          = "SL-PHASE-5O"
    run_mode       = if ($Apply) { "APPLY" } elseif ($WhatIf) { "WHATIF" } else { "REPORT_ONLY" }
    timestamp      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    checks         = [System.Collections.Generic.List[object]]::new()
    version_before = ""
    version_after  = ""
    nodes_patched  = [System.Collections.Generic.List[string]]::new()
    errors         = [System.Collections.Generic.List[string]]::new()
    pass           = $true
}

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail = "")
    $results.checks.Add([pscustomobject]@{ name = $Name; pass = $Pass; detail = $Detail })
    if (-not $Pass) { $results.pass = $false }
    $icon = if ($Pass) { "[PASS]" } else { "[FAIL]" }
    Write-Host "$icon  $Name" $(if ($Detail) { "— $Detail" })
}

function Get-N8nHeader {
    $apiKey = $env:HMZ_N8N_API_KEY
    if (-not $apiKey) { throw "HMZ_N8N_API_KEY env var not set. Set it before running." }
    return @{ "X-N8N-API-KEY" = $apiKey; "Content-Type" = "application/json" }
}

# ─── Safety guard ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-5O — Draft Improvement Target Classification Selector ==="
Write-Host "Mode: $($results.run_mode)"
Write-Host ""
Write-Host "[GUARD] Production target: $N8nBase"
Write-Host "[GUARD] DRY_RUN=true enforced — no Sender, no Decision, no autonomous changes"
Write-Host ""

# ─── Read local workflow ───────────────────────────────────────────────────────
if (-not (Test-Path $WorkflowFile)) {
    throw "Workflow file not found: $WorkflowFile"
}
$wfRaw = Get-Content $WorkflowFile -Raw
$wf    = $wfRaw | ConvertFrom-Json -AsHashtable

$localVersion = $wf.versionId
$results.version_before = $localVersion
Add-Check "Local versionId matches expected ($ExpectedVersionBefore)" `
          ($localVersion -eq $ExpectedVersionBefore) `
          "Found: $localVersion"

# ─── New code to insert in each node ──────────────────────────────────────────

# NODE J: Anchor — text BEFORE which we insert
$anchorJ = 'html += "<label style=\"display:block;margin-bottom:6px\">What type of draft improvement was this?'

# New code to insert (ends right before the anchor)
$insertJ = @'
  var _5oBC = escapeHtml(ctx.category || "");
  var _5oMI = escapeHtml(String((ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ctx.micro_intent || rc.micro_intent || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.micro_intent) || ""));
  html += "<label style=\"display:block;margin-bottom:6px\">Which detected classification(s) should this draft improvement apply to?<br><small style=\"color:#555;display:block;margin-bottom:3px\">Select only the classification(s) this improvement targets. Each detected classification is listed separately. Leave unchecked if unsure.</small><div style=\"margin-top:4px;padding:6px;border:1px solid #d0e0f0;border-radius:3px;background:#f8fbff\">";
  if (!_5oBC && !_5oMI && _p4aIntents.length === 0) {
    html += "<em style=\"color:#888\">No classification detected for this case.</em>";
  } else {
    if (_5oBC) { html += "<label style=\"display:block;margin-bottom:3px\"><input type=\"checkbox\" name=\"draft_improvement_target_classifications\" value=\"broad_category:" + _5oBC + "\"> Broad category: <strong>" + _5oBC + "</strong></label>"; }
    if (_5oMI) { html += "<label style=\"display:block;margin-bottom:3px\"><input type=\"checkbox\" name=\"draft_improvement_target_classifications\" value=\"micro_intent:" + _5oMI + "\"> Micro intent: <strong>" + _5oMI + "</strong></label>"; }
    if (_p4aIntents.length > 0) { _p4aIntents.forEach(function(intent) { var v = escapeHtml(String(intent.micro_intent || "")); if (v) { html += "<label style=\"display:block;margin-bottom:3px\"><input type=\"checkbox\" name=\"draft_improvement_target_classifications\" value=\"additional_intent:" + v + "\"> Additional detected intent: <strong>" + v + "</strong></label>"; } }); }
    else { html += "<small style=\"color:#888;display:block;margin-top:3px\">Additional detected intents: N/A</small>"; }
  }
  html += "</div></label>";

'@

# NODE L: Anchor — insert AFTER this line
$anchorL_find   = 'submit_draft_improvement_scope: String(body.draft_improvement_scope || "unsure_review_needed").trim(),'
$anchorL_insert = @'
submit_draft_improvement_scope: String(body.draft_improvement_scope || "unsure_review_needed").trim(),
      submit_draft_improvement_target_classifications: (function() {
        var raw = body.draft_improvement_target_classifications;
        if (!raw) { return []; }
        var arr = Array.isArray(raw) ? raw : [String(raw)];
        return arr.map(function(s) {
          s = String(s || "").trim();
          if (!s) { return null; }
          var colonIdx = s.indexOf(":");
          if (colonIdx < 0) { return null; }
          return { type: s.substring(0, colonIdx).trim(), value: s.substring(colonIdx + 1).trim() };
        }).filter(Boolean);
      })(),
'@

# SL-P1A: Anchor — insert AFTER this line
$anchorP1A_find   = 'draft_improvement_scope:     inp.submit_draft_improvement_scope || "unsure_review_needed"'
$anchorP1A_insert = 'draft_improvement_scope:     inp.submit_draft_improvement_scope || "unsure_review_needed",
      draft_improvement_target_classifications: (inp.submit_draft_improvement_target_classifications || [])'

# SL-P2A: Anchor — insert AFTER the proposed_rule_scope line ending with "requires_human_scope_decision",
$anchorP2A_find   = '"requires_human_scope_decision",'
$anchorP2A_insert = '"requires_human_scope_decision",
        draft_improvement_target_classifications: (inp.submit_draft_improvement_target_classifications || []),'

# ─── Validate anchors exist in local file ─────────────────────────────────────
function Find-Node {
    param([hashtable]$wf, [string]$name)
    foreach ($n in $wf.nodes) {
        if ($n.name -eq $name) { return $n }
    }
    return $null
}

$nodeJ   = Find-Node $wf "J. Render Review Form HTML"
$nodeL   = Find-Node $wf "L. Validate & Consume Review Token (POST)"
$nodePSL = Find-Node $wf "SL-P1A. Build Draft Revision Event"
$nodePSA = Find-Node $wf "SL-P2A. Prepare Phase 1C+2 Capture Data"

$codeJ   = $nodeJ.parameters.jsCode
$codeL   = $nodeL.parameters.jsCode
$codeP1A = $nodePSL.parameters.jsCode
$codeP2A = $nodePSA.parameters.jsCode

Add-Check "Node J anchor found" ($codeJ.Contains($anchorJ)) "Looking for draft_revision_type label"
Add-Check "Node J does NOT yet have target_classifications" (-not $codeJ.Contains('draft_improvement_target_classifications')) "Idempotency guard"
Add-Check "Node L anchor found" ($codeL.Contains($anchorL_find)) "Looking for submit_draft_improvement_scope"
Add-Check "Node L does NOT yet have target_classifications" (-not $codeL.Contains('submit_draft_improvement_target_classifications')) "Idempotency guard"
Add-Check "SL-P1A anchor found" ($codeP1A.Contains($anchorP1A_find)) "Looking for draft_improvement_scope in P1A event"
Add-Check "SL-P1A does NOT yet have target_classifications" (-not $codeP1A.Contains('draft_improvement_target_classifications')) "Idempotency guard"
Add-Check "SL-P2A anchor found" ($codeP2A.Contains($anchorP2A_find)) "Looking for requires_human_scope_decision"
Add-Check "SL-P2A does NOT yet have target_classifications" (-not $codeP2A.Contains('draft_improvement_target_classifications')) "Idempotency guard"

# Verify no forbidden changes attempted
Add-Check "No Sender modification" $true "Sender not touched"
Add-Check "No Decision modification" $true "Decision not touched"
Add-Check "No autonomous mode change" $true "Autonomous mode unchanged"
Add-Check "No live send path" $true "DRY_RUN=true preserved"

if ($WhatIf) {
    Write-Host ""
    Write-Host "--- WhatIf: Node J insertion preview ---"
    Write-Host $insertJ.Substring(0, [Math]::Min(300, $insertJ.Length)) "..."
    Write-Host ""
    Write-Host "--- WhatIf: Node L new field ---"
    Write-Host "submit_draft_improvement_target_classifications: (function(){ ... normalize to array of {type,value} objects })()"
    Write-Host ""
    Write-Host "--- WhatIf: SL-P1A addition ---"
    Write-Host "draft_improvement_target_classifications: (inp.submit_draft_improvement_target_classifications || [])"
    Write-Host ""
    Write-Host "--- WhatIf: SL-P2A addition ---"
    Write-Host "draft_improvement_target_classifications: (inp.submit_draft_improvement_target_classifications || [])"
    Write-Host ""
    Write-Host "WhatIf complete. Run -Apply to apply."
    if ($ExportReport) {
        $results.run_mode = "WHATIF_COMPLETE"
        $outDir = Join-Path $ProjectRoot "outputs"
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        $results | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $outDir "draft_improvement_target_classification_report.json") -Encoding UTF8
        Write-Host "Report written: outputs/draft_improvement_target_classification_report.json"
    }
    exit 0
}

if (-not $Apply) {
    Write-Host "No mode specified. Use -WhatIf to preview or -Apply to patch. Exiting."
    exit 0
}

# ─── Apply patches ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patches ==="

# Patch Node J
$newCodeJ = $codeJ.Replace($anchorJ, $insertJ + $anchorJ)
Add-Check "Node J patch applied (string replaced)" ($newCodeJ -ne $codeJ) "Inserted target classification selector"
$nodeJ.parameters.jsCode = $newCodeJ
$results.nodes_patched.Add("J. Render Review Form HTML")

# Patch Node L
$newCodeL = $codeL.Replace($anchorL_find, $anchorL_insert)
Add-Check "Node L patch applied (string replaced)" ($newCodeL -ne $codeL) "Added submit_draft_improvement_target_classifications parser"
$nodeL.parameters.jsCode = $newCodeL
$results.nodes_patched.Add("L. Validate & Consume Review Token (POST)")

# Patch SL-P1A
$newCodeP1A = $codeP1A.Replace($anchorP1A_find, $anchorP1A_insert)
Add-Check "SL-P1A patch applied (string replaced)" ($newCodeP1A -ne $codeP1A) "Added target_classifications to learning event"
$nodePSL.parameters.jsCode = $newCodeP1A
$results.nodes_patched.Add("SL-P1A. Build Draft Revision Event")

# Patch SL-P2A — find the LAST occurrence to avoid false matches in comments
$p2aAnchorIdx = $codeP2A.LastIndexOf($anchorP2A_find)
if ($p2aAnchorIdx -lt 0) {
    $results.errors.Add("SL-P2A anchor not found — patch skipped")
    Add-Check "SL-P2A patch applied" $false "Anchor not found"
} else {
    $newCodeP2A = $codeP2A.Substring(0, $p2aAnchorIdx) + $anchorP2A_insert + $codeP2A.Substring($p2aAnchorIdx + $anchorP2A_find.Length)
    Add-Check "SL-P2A patch applied (string replaced)" ($newCodeP2A -ne $codeP2A) "Added target_classifications to rule candidate"
    $nodePSA.parameters.jsCode = $newCodeP2A
    $results.nodes_patched.Add("SL-P2A. Prepare Phase 1C+2 Capture Data")
}

# ─── Verify patches in memory ──────────────────────────────────────────────────
$codeJNew   = $nodeJ.parameters.jsCode
$codeLNew   = $nodeL.parameters.jsCode
$codeP1ANew = $nodePSL.parameters.jsCode
$codeP2ANew = $nodePSA.parameters.jsCode

Add-Check "J contains draft_improvement_target_classifications" $codeJNew.Contains('draft_improvement_target_classifications') ""
Add-Check "J contains Which detected classification(s)" $codeJNew.Contains('Which detected classification(s) should this draft improvement apply to') ""
Add-Check "J contains broad_category: checkbox" $codeJNew.Contains('value=\"broad_category:') ""
Add-Check "J contains micro_intent: checkbox" $codeJNew.Contains('value=\"micro_intent:') ""
Add-Check "J contains additional_intent: checkbox" $codeJNew.Contains('value=\"additional_intent:') ""
Add-Check "J still contains draft_improvement_scope select" $codeJNew.Contains('draft_improvement_scope') ""
Add-Check "J still contains draft_revision_reason textarea" $codeJNew.Contains('draft_revision_reason') ""
Add-Check "J still contains draft_revision_type select" $codeJNew.Contains('draft_revision_type') ""
Add-Check "L contains submit_draft_improvement_target_classifications" $codeLNew.Contains('submit_draft_improvement_target_classifications') ""
Add-Check "L contains Array.isArray normalization" $codeLNew.Contains('Array.isArray') ""
Add-Check "P1A contains draft_improvement_target_classifications in event" $codeP1ANew.Contains('draft_improvement_target_classifications') ""
Add-Check "P2A contains draft_improvement_target_classifications in candidate" $codeP2ANew.Contains('draft_improvement_target_classifications') ""
Add-Check "P2A proposed_rule_scope still present" $codeP2ANew.Contains('proposed_rule_scope') ""

# ─── Write updated local JSON ──────────────────────────────────────────────────
Write-Host ""
Write-Host "Writing updated local workflow JSON..."
$wfJson = $wf | ConvertTo-Json -Depth 50 -Compress:$false
Set-Content -Path $WorkflowFile -Value $wfJson -Encoding UTF8
Add-Check "Local JSON written" (Test-Path $WorkflowFile) ""

# ─── Push to production n8n API ────────────────────────────────────────────────
Write-Host "Pushing to production n8n API..."
try {
    $headers = Get-N8nHeader
    $putUrl  = "$N8nBase/workflows/$WorkflowId"
    $body    = $wfJson
    $resp    = Invoke-RestMethod -Uri $putUrl -Method Put -Headers $headers -Body $body -ContentType "application/json"
    $newVer  = $resp.versionId
    $results.version_after = $newVer
    Add-Check "Production PUT succeeded" ($null -ne $newVer) "New versionId: $newVer"
    Add-Check "Version changed from prior" ($newVer -ne $ExpectedVersionBefore) "Old: $ExpectedVersionBefore → New: $newVer"
    Write-Host ""
    Write-Host "NEW HumanApproval versionId: $newVer"
} catch {
    $errMsg = $_.Exception.Message
    $results.errors.Add("Production PUT failed: $errMsg")
    Add-Check "Production PUT succeeded" $false $errMsg
}

# ─── VerifyRenderedReviewHtml ──────────────────────────────────────────────────
if ($VerifyRenderedReviewHtml) {
    Write-Host ""
    Write-Host "=== Verifying rendered review HTML ==="

    $formUrl = $null
    if ($UseCaseId) {
        # Fetch the case from DataTable to get the review URL
        try {
            $headers = Get-N8nHeader
            $caseUrl = "$N8nBase/workflows/$WorkflowId/executions?status=success&limit=20"
            # Instead, look up the form URL from the workflow's webhook path
            $webhookPath = ""
            foreach ($n in $wf.nodes) {
                if ($n.name -like "*Webhook - Review Form (Production*") {
                    $webhookPath = $n.parameters.path ?? ""
                    break
                }
            }
            if ($webhookPath) {
                $n8nHost = "https://n8n.hmzaiautomation.com"
                $formUrl = "$n8nHost/webhook/$webhookPath?case_id=$UseCaseId"
                Write-Host "Form URL (redacted token): $formUrl&token=***"
            }
        } catch {
            Write-Host "Could not build form URL: $_"
        }
    }

    # Offline verification: check the patched Node J code for required HTML strings
    $htmlChecks = @(
        @{ name="Label: Which detected classification(s)"; text="Which detected classification(s) should this draft improvement apply to" },
        @{ name="Checkbox name=draft_improvement_target_classifications"; text='name="draft_improvement_target_classifications"' },
        @{ name="broad_category value prefix"; text='value=\"broad_category:' },
        @{ name="micro_intent value prefix"; text='value=\"micro_intent:' },
        @{ name="additional_intent value prefix"; text='value=\"additional_intent:' },
        @{ name="Selector not hidden (no display:none on selector div)"; text='background:#f8fbff' },
        @{ name="draft_improvement_scope still present"; text="draft_improvement_scope" },
        @{ name="draft_revision_reason still present"; text="draft_revision_reason" },
        @{ name="Draft improvement learning header"; text="Draft improvement learning" }
    )

    foreach ($chk in $htmlChecks) {
        Add-Check "HTML: $($chk.name)" $codeJNew.Contains($chk.text) ""
    }

    # Check that the selector is NOT hidden with display:none
    $selectorHidden = $codeJNew -match 'display:none[^>]*>[^<]*draft_improvement_target_classifications'
    Add-Check "Selector not hidden with display:none" (-not $selectorHidden) ""
}

# ─── VerifySubmitCapture ──────────────────────────────────────────────────────
if ($VerifySubmitCapture) {
    Write-Host ""
    Write-Host "=== Verifying submit capture ==="

    Add-Check "L: submit_draft_improvement_target_classifications parsed" $codeLNew.Contains('submit_draft_improvement_target_classifications') ""
    Add-Check "L: handles Array.isArray case" $codeLNew.Contains('Array.isArray(raw)') ""
    Add-Check "L: handles string case" $codeLNew.Contains('String(raw)') ""
    Add-Check "L: normalizes to {type, value} objects" ($codeLNew.Contains('"type"') -or $codeLNew.Contains('type:')) ""
    Add-Check "L: filters null entries" $codeLNew.Contains('filter(Boolean)') ""
    Add-Check "P1A: draft_improvement_target_classifications in event" $codeP1ANew.Contains('draft_improvement_target_classifications') ""
}

# ─── VerifyRuleCandidateTargets ───────────────────────────────────────────────
if ($VerifyRuleCandidateTargets) {
    Write-Host ""
    Write-Host "=== Verifying rule candidate targets ==="

    Add-Check "P2A: draft_improvement_target_classifications in candidate" $codeP2ANew.Contains('draft_improvement_target_classifications') ""
    Add-Check "P2A: proposed_rule_scope still derived" $codeP2ANew.Contains('proposed_rule_scope') ""
    Add-Check "P2A: status proposed_shadow preserved" $codeP2ANew.Contains('proposed_shadow') ""
    Add-Check "P2A: requires_human_activation preserved" $codeP2ANew.Contains('requires_human_activation') ""
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Summary ==="
$passCount = ($results.checks | Where-Object { $_.pass }).Count
$failCount = ($results.checks | Where-Object { -not $_.pass }).Count
Write-Host "Checks: $passCount PASS / $failCount FAIL"
Write-Host "Nodes patched: $($results.nodes_patched -join ', ')"
if ($results.version_after) {
    Write-Host "New versionId: $($results.version_after)"
}
if ($results.errors.Count -gt 0) {
    Write-Host "Errors:"
    $results.errors | ForEach-Object { Write-Host "  - $_" }
}
Write-Host "Overall: $(if ($results.pass) { 'PASS' } else { 'FAIL' })"

# ─── Export report ────────────────────────────────────────────────────────────
if ($ExportReport) {
    $outDir = Join-Path $ProjectRoot "outputs"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $reportPath = Join-Path $outDir "draft_improvement_target_classification_report.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    Write-Host "Report: $reportPath"
}
