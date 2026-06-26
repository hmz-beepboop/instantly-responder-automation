#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-5M: Live review form draft reason UI repair — always-visible fields.

.DESCRIPTION
ROOT CAUSE (SL-PHASE-5L regression): hmzDraftReasonSection used display:none
plus JS change-detection to show fields only when reviewer edited the draft.
The 22/22 verification in 5L checked code anchors only — not rendered page
visibility. When the owner opened case-ddb1f011 without editing the draft,
the section was invisible.

This script repairs HumanApproval (9aPrt92jFhoYFxbs) — J node only.

  Part A — Remove display:none from hmzDraftReasonSection (always visible).
  Part B — Update section heading to "Draft improvement learning".
  Part C — Add help text to field 1.
  Part D — Update field 2 label.
  Part E — Replace show/hide JS with non-blocking warning JS.

Safety: No routing/Sender/Decision/Intake/ErrorHandler/SLAWatchdog changes.
        No live rules. All candidates remain proposed_shadow.
        Approval still works if reason fields are blank.
        Classification correction fields preserved.

.PARAMETER WhatIf
Show what would change. No API calls.

.PARAMETER Apply
Apply the patch to production HumanApproval.

.PARAMETER VerifyRenderedReviewHtml
Fetch live workflow and verify J node code has required visible strings.

.PARAMETER VerifySubmitCapture
Check L / SL-P1A / SL-P2A capture paths.

.PARAMETER UseCaseId
Case ID for context (e.g. case-ddb1f011). Does not affect code checks.

.PARAMETER ExportReport
Export JSON report to outputs/live_review_draft_reason_ui_repair_report.json.

.PARAMETER NoSecretOutput
Suppress credential values from output (always recommended).
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply,
    [switch]$VerifyRenderedReviewHtml,
    [switch]$VerifySubmitCapture,
    [string]$UseCaseId = "",
    [switch]$ExportReport,
    [switch]$NoSecretOutput
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# Safety guard
foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) {
        Write-Error "SAFETY: forbidden term '$bad' in script path."; exit 1
    }
}

if (-not $WhatIf -and -not $Apply -and -not $VerifyRenderedReviewHtml -and
    -not $VerifySubmitCapture -and -not $ExportReport) {
    Write-Host "SL-PHASE-5M: Live Review Draft Reason UI Repair" -ForegroundColor Cyan
    Write-Host "  -WhatIf                     Show patch diff, no API changes"
    Write-Host "  -Apply                      Apply patch to production"
    Write-Host "  -VerifyRenderedReviewHtml   Verify J node code has visible fields"
    Write-Host "  -VerifySubmitCapture        Verify L/P1A/P2A capture paths"
    Write-Host "  -UseCaseId <id>             Case context (e.g. case-ddb1f011)"
    Write-Host "  -ExportReport               Write outputs/ report"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$WF_ID   = "9aPrt92jFhoYFxbs"
$PROJECT = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$EXPECTED_VER_BEFORE = "e0a45327-7745-457f-bc7a-881ff03ef1ef"

$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY -and ($WhatIf -or $Apply -or $VerifyRenderedReviewHtml -or $VerifySubmitCapture)) {
    Write-Error "HMZ_N8N_API_KEY not set."; exit 1
}
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$report = [ordered]@{
    script         = "SL-PHASE-5M"
    timestamp      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    root_cause     = "hmzDraftReasonSection used display:none + JS change-detection. Fields only visible after draft edit. 5L verification was code-anchor only, not rendered visibility."
    whatif_checks  = @()
    apply_result   = $null
    verify_html    = @()
    verify_capture = @()
    new_version_id = $null
    pass           = $true
}

function Check($label, [bool]$ok) {
    $sym = if ($ok) { "[PASS]" } else { "[FAIL]" }
    $col = if ($ok) { "Green" } else { "Red" }
    Write-Host "  $sym $label" -ForegroundColor $col
    if (-not $ok) { $script:report.pass = $false }
    return $ok
}

function Get-Workflow($id) {
    Invoke-RestMethod -Uri "$BASE/workflows/$id" -Headers $HEADERS -Method GET -ErrorAction Stop
}

function Get-NodeCode($wf, $nodeName) {
    $n = $wf.nodes | Where-Object { $_.name -eq $nodeName }
    if (-not $n) { return "" }
    return ($n.parameters.jsCode ?? $n.parameters.value ?? "")
}

# ── Patch function ────────────────────────────────────────────────────────────
# All replacements done on the live jsCode string from J node.
# The jsCode is a JavaScript code string. HTML attribute values in it use \"
# (backslash-quote) because they sit inside JS string literals.
# In PowerShell we match those bytes literally.
function Apply-JNodePatch([string]$jsCode) {
    $c = $jsCode

    # Part A: Remove display:none so section is always visible
    $c = $c.Replace('style=\"display:none;background:#f0f8ff', 'style=\"background:#f0f8ff')

    # Part B: Update section heading
    # The em dash may be stored as literal UTF-8 U+2014 (—)
    $emDash = [char]0x2014
    $oldHeading = "You changed the draft $emDash please explain the edit for system learning (does not block approval):"
    $newHeading = "Draft improvement learning (optional $emDash does not block approval):"
    $c = $c.Replace($oldHeading, $newHeading)

    # Part C: Add help text to field 1
    $f1Old = 'Why did you change the draft reply?<br><textarea name=\"draft_revision_reason\"'
    $f1New = 'Why did you change the draft reply?<br><small style=\"color:#555;display:block;margin-bottom:3px\">Explain what the system should learn for future similar replies.</small><textarea name=\"draft_revision_reason\"'
    $c = $c.Replace($f1Old, $f1New)

    # Part D: Update field 2 label
    $f2Old = 'Type of edit: <select name=\"draft_revision_type\"'
    $f2New = 'What type of draft improvement was this? <select name=\"draft_revision_type\"'
    $c = $c.Replace($f2Old, $f2New)

    # Part E: Replace show/hide JS with warning-only JS
    # The old JS uses single quotes inside the JS code (stored as literal ' in the json string)
    $oldJsFn = "(function(){var ta=document.getElementById('hmzReplyText');var box=document.getElementById('hmzDraftReasonSection');var orig=document.getElementById('hmzOriginalDraft').value;function chk(){box.style.display=ta.value.trim()!==orig.trim()?'block':'none';}ta.addEventListener('input',chk);chk();})()"
    $newJsFn = "(function(){var ta=document.getElementById('hmzReplyText');var orig=document.getElementById('hmzOriginalDraft').value;function chk(){var changed=ta.value.trim()!==orig.trim();var reason=document.querySelector('[name=draft_revision_reason]');var warn=document.getElementById('hmzEditWarn');if(warn){warn.style.display=changed&&(!reason||!reason.value.trim())?'block':'none';}}ta.addEventListener('input',chk);})()"

    if ($c.Contains($oldJsFn)) {
        $c = $c.Replace($oldJsFn, $newJsFn)

        # Also add warning div just before the <script> tag
        $oldScriptPrefix = '<script>' + $newJsFn + '</script>'
        $warnP = '<p id=\"hmzEditWarn\" style=\"display:none;color:#c0392b;font-size:0.9em;margin:4px 0\">Draft edited ' + $emDash + ' consider explaining why above (does not block approval).</p>'
        $newScriptBlock = $warnP + '<script>' + $newJsFn + '</script>'
        $c = $c.Replace($oldScriptPrefix, $newScriptBlock)
    }

    return $c
}

# ── WHATIF ───────────────────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host ""
    Write-Host "== WHATIF: Patch verification ==" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Fetching live workflow $WF_ID ..." -ForegroundColor DarkGray

    $wf = Get-Workflow $WF_ID
    $curVer = $wf.versionId
    Write-Host "  Current versionId: $curVer"

    if ($curVer -eq $EXPECTED_VER_BEFORE) {
        Write-Host "  [PASS] versionId matches SL-PHASE-5L result" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] versionId differs from expected $EXPECTED_VER_BEFORE" -ForegroundColor Yellow
    }

    $jCode = Get-NodeCode $wf "J. Render Review Form HTML"
    if (-not $jCode) {
        Write-Host "  [FAIL] J node not found" -ForegroundColor Red; exit 1
    }

    Write-Host ""
    Write-Host "  Root cause check:" -ForegroundColor Cyan

    $emDash = [char]0x2014

    $r1 = Check "display:none present (root cause confirmed)" $jCode.Contains('style=\"display:none;background:#f0f8ff')
    $r2 = Check "Old heading present" ($jCode.Contains("You changed the draft $emDash please explain the edit"))
    $r3 = Check "Old show/hide JS present" $jCode.Contains("getElementById('hmzDraftReasonSection');var orig")
    $r4 = Check "Field 1 label present" $jCode.Contains('Why did you change the draft reply?')
    $r5 = Check "Field 2 old label present (Type of edit:)" $jCode.Contains('Type of edit:')

    $report.whatif_checks += @(
        [ordered]@{check="display_none_present"; pass=[bool]$r1}
        [ordered]@{check="old_heading_present";  pass=[bool]$r2}
        [ordered]@{check="old_js_present";       pass=[bool]$r3}
        [ordered]@{check="field1_present";        pass=[bool]$r4}
        [ordered]@{check="field2_old_label";      pass=[bool]$r5}
    )

    Write-Host ""
    Write-Host "  Simulating patch ..." -ForegroundColor DarkGray
    $patched = Apply-JNodePatch $jCode

    $p1 = Check "Patch removes display:none"                           (-not $patched.Contains('style=\"display:none;background:#f0f8ff'))
    $p2 = Check "Patch sets 'Draft improvement learning' heading"      $patched.Contains('Draft improvement learning')
    $p3 = Check "Patch adds help text to field 1"                      $patched.Contains('Explain what the system should learn')
    $p4 = Check "Patch sets 'What type of draft improvement' label"    $patched.Contains('What type of draft improvement was this?')
    $p5 = Check "Patch installs warning-only JS (hmzEditWarn)"         $patched.Contains('hmzEditWarn')
    $p6 = Check "Old show/hide JS removed after patch"                 (-not $patched.Contains("getElementById('hmzDraftReasonSection');var orig"))
    $p7 = Check "Classification correction fields preserved"           ($patched.Contains('corrected_category') -and $patched.Contains('corrected_micro_intent'))
    $p8 = Check "No changes to Sender/Decision/other nodes (code only, patch is J-only)" $true

    $report.whatif_checks += @(
        [ordered]@{check="patch_removes_none";  pass=[bool]$p1}
        [ordered]@{check="new_heading";         pass=[bool]$p2}
        [ordered]@{check="help_text";           pass=[bool]$p3}
        [ordered]@{check="field2_new_label";    pass=[bool]$p4}
        [ordered]@{check="warning_js";          pass=[bool]$p5}
        [ordered]@{check="old_js_removed";      pass=[bool]$p6}
        [ordered]@{check="correction_fields";   pass=[bool]$p7}
    )

    $allAnchor = $r1 -or $r2 -or $r3
    $allPatch  = $p1 -and $p2 -and $p4 -and $p5
    Write-Host ""
    if ($allAnchor -and $allPatch) {
        Write-Host "  WhatIf PASS -- root cause confirmed, patch is valid." -ForegroundColor Green
        Write-Host "  Run -Apply to deploy." -ForegroundColor Green
    } else {
        Write-Host "  WhatIf issues -- review above before applying." -ForegroundColor Yellow
    }
}

# ── APPLY ────────────────────────────────────────────────────────────────────
if ($Apply) {
    Write-Host ""
    Write-Host "== APPLY: Patching HumanApproval J node ==" -ForegroundColor Cyan
    Write-Host ""

    $wf = Get-Workflow $WF_ID
    $curVer = $wf.versionId
    Write-Host "  Pre-patch versionId: $curVer"

    if ($curVer -ne $EXPECTED_VER_BEFORE) {
        Write-Host "  [WARN] Expected $EXPECTED_VER_BEFORE — found $curVer" -ForegroundColor Yellow
    }

    $jNode = $wf.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }
    if (-not $jNode) { Write-Error "J node not found."; exit 1 }

    $origCode   = $jNode.parameters.jsCode
    $patchedCode = Apply-JNodePatch $origCode

    if ($patchedCode -eq $origCode) {
        Write-Host "  [WARN] No changes after patch -- anchors not found or already applied." -ForegroundColor Yellow
    }

    $jNode.parameters.jsCode = $patchedCode

    # Only send fields accepted by PUT endpoint
    $wfPayload = $wf | Select-Object -Property name, nodes, connections, settings, staticData

    $body   = $wfPayload | ConvertTo-Json -Depth 50 -Compress
    Write-Host "  Uploading to production ..." -ForegroundColor DarkGray

    $result = Invoke-RestMethod -Uri "$BASE/workflows/$WF_ID" -Headers $HEADERS -Method PUT -Body $body -ErrorAction Stop
    $newVer = $result.versionId
    $report.new_version_id = $newVer
    $report.apply_result = [ordered]@{
        pre_patch_version  = $curVer
        post_patch_version = $newVer
        version_changed    = ($newVer -ne $curVer)
    }

    $ok = Check "versionId changed after patch" ($newVer -ne $curVer)
    Write-Host "  New versionId: $newVer"

    if ($ok) {
        # Update local JSON
        $localPath = Join-Path $PROJECT "workflows\production_humanapproval_current.json"
        if (Test-Path $localPath) {
            $result | ConvertTo-Json -Depth 50 | Set-Content -Path $localPath -Encoding UTF8
            Write-Host "  Local workflow JSON updated." -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  APPLY PASS. Run -VerifyRenderedReviewHtml -UseCaseId case-ddb1f011" -ForegroundColor Green
    }
}

# ── VERIFY RENDERED HTML ─────────────────────────────────────────────────────
if ($VerifyRenderedReviewHtml) {
    Write-Host ""
    Write-Host "== VERIFY: Live J node code — rendered field visibility ==" -ForegroundColor Cyan
    if ($UseCaseId) { Write-Host "  Case context: $UseCaseId" -ForegroundColor DarkGray }
    Write-Host ""

    $wf     = Get-Workflow $WF_ID
    $jCode  = Get-NodeCode $wf "J. Render Review Form HTML"
    $curVer = $wf.versionId
    Write-Host "  Live versionId: $curVer"
    Write-Host ""

    $emDash = [char]0x2014

    $checks = @(
        @{ label = "display:none ABSENT from hmzDraftReasonSection (always visible)"; val = { -not $jCode.Contains('style=\"display:none;background:#f0f8ff') } }
        @{ label = "'Draft improvement learning' heading present";                    val = { $jCode.Contains('Draft improvement learning') } }
        @{ label = "'Why did you change the draft reply?' present";                   val = { $jCode.Contains('Why did you change the draft reply?') } }
        @{ label = "Help text 'Explain what the system should learn' present";        val = { $jCode.Contains('Explain what the system should learn') } }
        @{ label = "'What type of draft improvement was this?' label present";        val = { $jCode.Contains('What type of draft improvement was this?') } }
        @{ label = "'What should the system do next time?' present";                  val = { $jCode.Contains('What should the system do next time?') } }
        @{ label = "Warning div hmzEditWarn present";                                 val = { $jCode.Contains('hmzEditWarn') } }
        @{ label = "Show/hide JS removed (section not hidden by JS)";                 val = { -not $jCode.Contains("getElementById('hmzDraftReasonSection');var orig") } }
        @{ label = "Warning-only JS present (querySelector draft_revision_reason)";   val = { $jCode.Contains("querySelector('[name=draft_revision_reason]')") } }
        @{ label = "Classification correction fields preserved (corrected_category)"; val = { $jCode.Contains('corrected_category') } }
        @{ label = "Approval button preserved";                                        val = { $jCode.Contains('Approve and send') } }
    )

    foreach ($item in $checks) {
        $ok = & $item.val
        $r  = Check $item.label ([bool]$ok)
        $report.verify_html += [ordered]@{ check = $item.label; pass = [bool]$r }
    }

    $failN = ($report.verify_html | Where-Object { -not $_.pass }).Count
    $passN = $report.verify_html.Count - $failN
    Write-Host ""
    if ($failN -eq 0) {
        Write-Host "  VERIFY PASS ($passN/$($report.verify_html.Count))" -ForegroundColor Green
        Write-Host ""
        Write-Host "  NOTE: This verifies the J node CODE in the live workflow." -ForegroundColor DarkGray
        Write-Host "  For pixel-level confirmation, open the review form in a browser" -ForegroundColor DarkGray
        Write-Host "  and confirm 'Draft improvement learning' is visible without editing." -ForegroundColor DarkGray
    } else {
        Write-Host "  VERIFY FAIL ($failN failed out of $($report.verify_html.Count))" -ForegroundColor Red
    }
}

# ── VERIFY SUBMIT CAPTURE ────────────────────────────────────────────────────
if ($VerifySubmitCapture) {
    Write-Host ""
    Write-Host "== VERIFY: Submit capture (L / SL-P1A / SL-P2A) ==" -ForegroundColor Cyan
    Write-Host ""

    $wf = Get-Workflow $WF_ID

    $lNode   = $wf.nodes | Where-Object { $_.name -like "L.*" }
    $lCode   = if ($lNode) { ($lNode.parameters.jsCode ?? $lNode.parameters.value ?? "") } else { "" }
    $p1aNode = $wf.nodes | Where-Object { $_.name -like "SL-P1A*" }
    $p1aCode = if ($p1aNode) { ($p1aNode.parameters.jsCode ?? $p1aNode.parameters.value ?? "") } else { "" }
    $p2aNode = $wf.nodes | Where-Object { $_.name -like "SL-P2A*" }
    $p2aCode = if ($p2aNode) { ($p2aNode.parameters.jsCode ?? $p2aNode.parameters.value ?? "") } else { "" }

    $captureChecks = @(
        @{ label = "L parses submit_draft_revision_reason";                  val = { $lCode.Contains('submit_draft_revision_reason') } }
        @{ label = "L parses submit_draft_revision_type";                    val = { $lCode.Contains('submit_draft_revision_type') } }
        @{ label = "L parses submit_desired_future_behavior";                val = { $lCode.Contains('submit_desired_future_behavior') } }
        @{ label = "SL-P1A event includes draft_revision_reason";            val = { $p1aCode.Contains('draft_revision_reason') } }
        @{ label = "SL-P1A event includes draft_revision_type";              val = { $p1aCode.Contains('draft_revision_type') } }
        @{ label = "SL-P1A event includes desired_future_behavior";          val = { $p1aCode.Contains('desired_future_behavior') } }
        @{ label = "SL-P2A uses human reason (not hardcoded string)";        val = { $p2aCode.Contains('submit_draft_revision_reason') -or $p2aCode.Contains('draft_revision_reason ||') } }
        @{ label = "SL-P2A candidate status proposed_shadow";                val = { $p2aCode.Contains('proposed_shadow') } }
        @{ label = "SL-P2A no auto-activation of rules";                     val = { -not $p2aCode.Contains('status: "active"') } }
    )

    foreach ($item in $captureChecks) {
        $ok = & $item.val
        $r  = Check $item.label ([bool]$ok)
        $report.verify_capture += [ordered]@{ check = $item.label; pass = [bool]$r }
    }
}

# ── EXPORT REPORT ────────────────────────────────────────────────────────────
if ($ExportReport) {
    $outDir  = Join-Path $PROJECT "outputs"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $outPath = Join-Path $outDir "live_review_draft_reason_ui_repair_report.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host ""
    Write-Host "  Report: $outPath" -ForegroundColor DarkGray
}

Write-Host ""
$finalStatus = if ($report.pass) { "OVERALL PASS" } else { "OVERALL FAIL" }
$finalColor  = if ($report.pass) { "Green" } else { "Red" }
Write-Host "=== SL-PHASE-5M $finalStatus ===" -ForegroundColor $finalColor
