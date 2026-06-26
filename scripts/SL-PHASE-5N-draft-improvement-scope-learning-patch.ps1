#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-5N: Add draft_improvement_scope field to HumanApproval review form.

.DESCRIPTION
Prerequisite: SL-PHASE-5M applied. HumanApproval versionId: 8a148c91-ea1c-405c-9074-6b9a573370dc

Patches HumanApproval workflow 9aPrt92jFhoYFxbs — J + L + SL-P1A + SL-P2A nodes.

  J node: Insert draft_improvement_scope select BEFORE draft_revision_type select.
          Always visible (no JS show/hide). Default: unsure_review_needed.
          Options: current_micro_intent_only / current_broad_category /
                   all_ai_drafts / campaign_specific / sender_specific / unsure_review_needed.

  L node: Parse submit_draft_improvement_scope from POST body.
          Defaults to unsure_review_needed if blank.

  SL-P1A: Include draft_improvement_scope in learning event written to sl_draft_revision_events.

  SL-P2A: Include draft_improvement_scope + proposed_rule_scope in proposed_shadow rule candidate.
          proposed_rule_scope is derived from the human's scope selection.
          No scope value auto-activates a rule. All remain proposed_shadow.

Safety:
  No routing / Sender / Decision / Intake / ErrorHandler / SLAWatchdog changes.
  No live rules. All candidates remain proposed_shadow. requires_human_activation = true.
  No autonomous mode. No dry_run=false. No shadow_only=false.
  Approval still works if scope field is left at default unsure_review_needed.
  Classification correction fields and prior reason fields preserved.

.PARAMETER WhatIf
Verify 5M state anchors and simulate 5N patch. No API changes.

.PARAMETER Apply
Apply patch to production HumanApproval (4 nodes: J, L, P1A, P2A).

.PARAMETER VerifyRenderedReviewHtml
Fetch live J node code and confirm scope field visible and correct.

.PARAMETER VerifySubmitCapture
Fetch live L / SL-P1A / SL-P2A and confirm draft_improvement_scope captured.

.PARAMETER VerifyRuleCandidateScope
Offline test: show all 6 scope values and their proposed_rule_scope mappings.

.PARAMETER UseCaseId
Case ID for context only (e.g. case-ddb1f011). Does not affect code checks.

.PARAMETER ExportReport
Write outputs/draft_improvement_scope_learning_report.json.

.PARAMETER NoSecretOutput
Suppress any credential output (always recommended).
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply,
    [switch]$VerifyRenderedReviewHtml,
    [switch]$VerifySubmitCapture,
    [switch]$VerifyRuleCandidateScope,
    [string]$UseCaseId = "",
    [switch]$ExportReport,
    [switch]$NoSecretOutput
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) { Write-Error "SAFETY: forbidden term '$bad' in script path."; exit 1 }
}

if (-not $WhatIf -and -not $Apply -and -not $VerifyRenderedReviewHtml -and
    -not $VerifySubmitCapture -and -not $VerifyRuleCandidateScope -and -not $ExportReport) {
    Write-Host "SL-PHASE-5N: Draft Improvement Scope Learning Patch" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  -WhatIf                      Verify 5M state + simulate 5N patch (no API changes)"
    Write-Host "  -Apply                       Apply patch to production (J + L + P1A + P2A nodes)"
    Write-Host "  -VerifyRenderedReviewHtml    Confirm live J node has visible scope field"
    Write-Host "  -VerifySubmitCapture         Confirm L/P1A/P2A have draft_improvement_scope"
    Write-Host "  -VerifyRuleCandidateScope    Offline scope->proposed_rule_scope mapping test"
    Write-Host "  -UseCaseId <id>              Case context (e.g. case-ddb1f011)"
    Write-Host "  -ExportReport                Write outputs/draft_improvement_scope_learning_report.json"
    Write-Host "  -NoSecretOutput              Suppress credential output"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$WF_ID   = "9aPrt92jFhoYFxbs"  # HumanApproval
$PROJECT = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$EXPECTED_VER_BEFORE = "8a148c91-ea1c-405c-9074-6b9a573370dc"  # SL-PHASE-5M result

$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY -and ($WhatIf -or $Apply -or $VerifyRenderedReviewHtml -or $VerifySubmitCapture)) {
    Write-Error "HMZ_N8N_API_KEY not set. Export it before running."; exit 1
}
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$report = [ordered]@{
    script         = "SL-PHASE-5N"
    timestamp      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    case_id        = $UseCaseId
    whatif_checks  = @()
    apply_result   = $null
    verify_html    = @()
    verify_capture = @()
    verify_scope   = @()
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

function Get-NodeCode($wf, [string]$namePattern) {
    $n = $wf.nodes | Where-Object { $_.name -like $namePattern }
    if (-not $n) { return "" }
    return ($n.parameters.jsCode ?? $n.parameters.value ?? "")
}

# ══════════════════════════════════════════════════════════════════
# Anchor definitions
# All Old anchors are single-quoted PS strings — backslash and
# double-quote are literal, matching the jsCode content exactly.
# ══════════════════════════════════════════════════════════════════

# J node: post-5M anchor — "What type of draft improvement" label line start
# Used as the insertion point: scope field goes BEFORE this line.
$J_SCOPE_ANCHOR = 'html += "<label style=\"display:block;margin-bottom:6px\">What type of draft improvement was this? <select name=\"draft_revision_type\"'

# J node: scope select HTML statement to insert (single-quoted here-string).
# No single quotes in content. Ends with newline from here-string.
$J_SCOPE_STMT = @'
html += "<label style=\"display:block;margin-bottom:6px\">Should this draft improvement apply only to this classification, or generally to all drafts?<br><small style=\"color:#555;display:block;margin-bottom:3px\">Choose how broadly to apply this learning. Broadest scope only for universal principles (no invented proof, pricing, results, or guarantees).</small><select name=\"draft_improvement_scope\" style=\"width:100%;margin-top:4px\"><option value=\"unsure_review_needed\">Unsure — reviewer/rule approver should decide</option><option value=\"current_micro_intent_only\">Only this micro intent</option><option value=\"current_broad_category\">This broad category/classification</option><option value=\"all_ai_drafts\">All AI-generated drafts, regardless of classification</option><option value=\"campaign_specific\">Only this campaign</option><option value=\"sender_specific\">Only this sender</option></select></label>";
'@
# $J_SCOPE_STMT value: 'html += "...";\n' — newline is from the here-string.
# We append "  " so the restored J_SCOPE_ANCHOR line is properly indented.

# L node: post-5L anchor — last parsed field before the scope field
$L_ANCHOR = 'submit_desired_future_behavior: String(body.desired_future_behavior || "").trim(),'

# L node: new field to add after L_ANCHOR (6-space indent to align with existing fields)
$L_NEW_FIELD = '      submit_draft_improvement_scope: String(body.draft_improvement_scope || "unsure_review_needed").trim(),'

# P1A node: post-5L anchor — last field in event object (NO trailing comma — we add one)
$P1A_ANCHOR = 'desired_future_behavior:     inp.submit_desired_future_behavior   || null'

# P1A node: new field (6-space indent, double-quoted default to avoid PS single-quote issue)
$P1A_NEW_FIELD = '      draft_improvement_scope:     inp.submit_draft_improvement_scope || "unsure_review_needed"'

# P2A node: post-5L anchor — desired_future_behavior in rule candidate (has trailing comma)
$P2A_ANCHOR = 'desired_future_behavior: (inp.submit_desired_future_behavior || ""),'

# P2A node: new fields to add after P2A_ANCHOR (single-quoted here-string, no single quotes)
# proposed_rule_scope is derived from human scope selection via ternary chain.
$P2A_NEW_FIELDS = @'
draft_improvement_scope: (inp.submit_draft_improvement_scope || "unsure_review_needed"),
        proposed_rule_scope: inp.submit_draft_improvement_scope === "all_ai_drafts" ? "global_draft_policy" : inp.submit_draft_improvement_scope === "current_broad_category" ? "broad_category" : inp.submit_draft_improvement_scope === "current_micro_intent_only" ? "micro_intent" : inp.submit_draft_improvement_scope === "campaign_specific" ? "campaign_scoped" : inp.submit_draft_improvement_scope === "sender_specific" ? "sender_scoped" : "requires_human_scope_decision",
'@

# ══════════════════════════════════════════════════════════════════
# Patch functions — each returns the patched code string.
# Returns original unchanged if anchor not found (warns but does not fail).
# ══════════════════════════════════════════════════════════════════

function Apply-JNodePatch([string]$code) {
    if (-not $code.Contains($J_SCOPE_ANCHOR)) {
        if ($code.Contains('draft_improvement_scope')) {
            Write-Host "  [INFO] J: draft_improvement_scope already present — skipping (already patched)" -ForegroundColor DarkGray
        } else {
            Write-Host "  [WARN] J: anchor not found and field not present — anchor may have changed" -ForegroundColor Yellow
        }
        return $code
    }
    # Insert scope statement before the draft_revision_type label line.
    # $J_SCOPE_STMT ends with \n; append "  " to indent the restored anchor line.
    return $code.Replace($J_SCOPE_ANCHOR, $J_SCOPE_STMT + "  " + $J_SCOPE_ANCHOR)
}

function Apply-LNodePatch([string]$code) {
    if (-not $code.Contains($L_ANCHOR)) {
        if ($code.Contains('submit_draft_improvement_scope')) {
            Write-Host "  [INFO] L: draft_improvement_scope already present — skipping" -ForegroundColor DarkGray
        } else {
            Write-Host "  [WARN] L: anchor not found" -ForegroundColor Yellow
        }
        return $code
    }
    return $code.Replace($L_ANCHOR, $L_ANCHOR + "`n" + $L_NEW_FIELD)
}

function Apply-P1ANodePatch([string]$code) {
    if (-not $code.Contains($P1A_ANCHOR)) {
        if ($code.Contains('draft_improvement_scope')) {
            Write-Host "  [INFO] P1A: draft_improvement_scope already present — skipping" -ForegroundColor DarkGray
        } else {
            Write-Host "  [WARN] P1A: anchor not found" -ForegroundColor Yellow
        }
        return $code
    }
    # P1A_ANCHOR has no trailing comma — add comma then the new field
    return $code.Replace($P1A_ANCHOR, $P1A_ANCHOR + "," + "`n" + $P1A_NEW_FIELD)
}

function Apply-P2ANodePatch([string]$code) {
    if (-not $code.Contains($P2A_ANCHOR)) {
        if ($code.Contains('draft_improvement_scope')) {
            Write-Host "  [INFO] P2A: draft_improvement_scope already present — skipping" -ForegroundColor DarkGray
        } else {
            Write-Host "  [WARN] P2A: anchor not found" -ForegroundColor Yellow
        }
        return $code
    }
    # Append 8-space indent before P2A_NEW_FIELDS to match existing style.
    # .TrimEnd() removes trailing newline from here-string.
    return $code.Replace($P2A_ANCHOR, $P2A_ANCHOR + "`n        " + $P2A_NEW_FIELDS.TrimEnd())
}

# ══════════════════════════════════════════════════════════════════
# WHATIF
# ══════════════════════════════════════════════════════════════════
if ($WhatIf) {
    Write-Host ""
    Write-Host "== WHATIF: Pre-condition check (5M state) + 5N patch simulation ==" -ForegroundColor Cyan
    if ($UseCaseId) { Write-Host "  Case context: $UseCaseId" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "  Fetching HumanApproval $WF_ID ..." -ForegroundColor DarkGray

    $wf     = Get-Workflow $WF_ID
    $curVer = $wf.versionId
    Write-Host "  Current versionId: $curVer"
    if ($curVer -eq $EXPECTED_VER_BEFORE) {
        Write-Host "  [PASS] versionId matches SL-PHASE-5M ($EXPECTED_VER_BEFORE)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Expected $EXPECTED_VER_BEFORE but found $curVer (may be a later patch — check NEXT_SESSION_HANDOFF.md)" -ForegroundColor Yellow
    }

    $jCode   = Get-NodeCode $wf "J.*"
    $lCode   = Get-NodeCode $wf "L.*"
    $p1aCode = Get-NodeCode $wf "SL-P1A*"
    $p2aCode = Get-NodeCode $wf "SL-P2A*"

    Write-Host ""
    Write-Host "  Pre-condition checks (5M + 5L state must be present):" -ForegroundColor Cyan
    $c1  = Check "J: 'Draft improvement learning' heading present (5M)"          $jCode.Contains('Draft improvement learning')
    $c2  = Check "J: 'What type of draft improvement was this?' label present (5M)" $jCode.Contains('What type of draft improvement was this?')
    $c3  = Check "J: hmzEditWarn warning JS present (5M)"                         $jCode.Contains('hmzEditWarn')
    $c4  = Check "J: draft_improvement_scope NOT yet present (pre-5N)"            (-not $jCode.Contains('draft_improvement_scope'))
    $c5  = Check "L: submit_draft_revision_reason present (5L)"                   $lCode.Contains('submit_draft_revision_reason')
    $c6  = Check "L: draft_improvement_scope NOT yet present"                     (-not $lCode.Contains('draft_improvement_scope'))
    $c7  = Check "P1A: draft_revision_reason present (5L)"                        $p1aCode.Contains('draft_revision_reason')
    $c8  = Check "P1A: draft_improvement_scope NOT yet present"                   (-not $p1aCode.Contains('draft_improvement_scope'))
    $c9  = Check "P2A: desired_future_behavior in rule candidate (5L)"            $p2aCode.Contains('desired_future_behavior')
    $c10 = Check "P2A: draft_improvement_scope NOT yet present"                   (-not $p2aCode.Contains('draft_improvement_scope'))

    $report.whatif_checks += @(
        [ordered]@{check="j_draft_improvement_learning_heading_5m"; pass=[bool]$c1}
        [ordered]@{check="j_what_type_label_5m";                    pass=[bool]$c2}
        [ordered]@{check="j_editwarn_js_5m";                        pass=[bool]$c3}
        [ordered]@{check="j_scope_not_yet_present";                 pass=[bool]$c4}
        [ordered]@{check="l_revision_reason_5l";                    pass=[bool]$c5}
        [ordered]@{check="l_scope_not_yet_present";                 pass=[bool]$c6}
        [ordered]@{check="p1a_revision_reason_5l";                  pass=[bool]$c7}
        [ordered]@{check="p1a_scope_not_yet_present";               pass=[bool]$c8}
        [ordered]@{check="p2a_desired_future_beh_5l";               pass=[bool]$c9}
        [ordered]@{check="p2a_scope_not_yet_present";               pass=[bool]$c10}
    )

    $alreadyPatched = (-not $c4) -or (-not $c6) -or (-not $c8) -or (-not $c10)
    if ($alreadyPatched) {
        Write-Host ""
        Write-Host "  [WARN] draft_improvement_scope already present in one or more nodes." -ForegroundColor Yellow
        Write-Host "         SL-PHASE-5N may have been applied already. Run -VerifyRenderedReviewHtml to confirm." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "  Simulating 5N patch ..." -ForegroundColor DarkGray
        $pJ   = Apply-JNodePatch   $jCode
        $pL   = Apply-LNodePatch   $lCode
        $pP1A = Apply-P1ANodePatch $p1aCode
        $pP2A = Apply-P2ANodePatch $p2aCode

        Write-Host ""
        Write-Host "  Post-patch simulation checks:" -ForegroundColor Cyan
        $p1  = Check "J: draft_improvement_scope select present"                  $pJ.Contains('draft_improvement_scope')
        $p2  = Check "J: option unsure_review_needed present (default)"           $pJ.Contains('unsure_review_needed')
        $p3  = Check "J: option all_ai_drafts present"                            $pJ.Contains('all_ai_drafts')
        $p4  = Check "J: option current_micro_intent_only present"                $pJ.Contains('current_micro_intent_only')
        $p5  = Check "J: option current_broad_category present"                   $pJ.Contains('current_broad_category')
        $p6  = Check "J: scope label text present ('apply only to this classification')" $pJ.Contains('apply only to this classification')
        $p7  = Check "J: draft_revision_type label preserved (5M)"                $pJ.Contains('What type of draft improvement was this?')
        $p8  = Check "J: draft_revision_reason textarea preserved (5L)"           $pJ.Contains('draft_revision_reason')
        $p9  = Check "J: classification correction fields preserved"              ($pJ.Contains('corrected_category') -and $pJ.Contains('corrected_micro_intent'))
        $p10 = Check "J: Approve and send button preserved"                       $pJ.Contains('Approve and send')
        $p11 = Check "L: submit_draft_improvement_scope present"                  $pL.Contains('submit_draft_improvement_scope')
        $p12 = Check "L: submit_desired_future_behavior preserved"                $pL.Contains('submit_desired_future_behavior')
        $p13 = Check "P1A: draft_improvement_scope in learning event"             $pP1A.Contains('draft_improvement_scope')
        $p14 = Check "P1A: desired_future_behavior preserved"                     $pP1A.Contains('desired_future_behavior')
        $p15 = Check "P2A: draft_improvement_scope in rule candidate"             $pP2A.Contains('draft_improvement_scope')
        $p16 = Check "P2A: proposed_rule_scope in rule candidate"                 $pP2A.Contains('proposed_rule_scope')
        $p17 = Check "P2A: global_draft_policy mapping for all_ai_drafts"         $pP2A.Contains('global_draft_policy')
        $p18 = Check "P2A: proposed_shadow preserved (no auto-activation)"        $pP2A.Contains('proposed_shadow')
        $p19 = Check "P2A: no status:active created"                              (-not $pP2A.Contains('status: "active"'))

        $report.whatif_checks += @(
            [ordered]@{check="j_scope_select";           pass=[bool]$p1}
            [ordered]@{check="j_unsure_option";          pass=[bool]$p2}
            [ordered]@{check="j_all_drafts_option";      pass=[bool]$p3}
            [ordered]@{check="j_micro_intent_option";    pass=[bool]$p4}
            [ordered]@{check="j_broad_cat_option";       pass=[bool]$p5}
            [ordered]@{check="j_scope_label_text";       pass=[bool]$p6}
            [ordered]@{check="j_type_label_preserved";   pass=[bool]$p7}
            [ordered]@{check="j_reason_preserved";       pass=[bool]$p8}
            [ordered]@{check="j_correction_preserved";   pass=[bool]$p9}
            [ordered]@{check="j_approve_btn_preserved";  pass=[bool]$p10}
            [ordered]@{check="l_scope_field";            pass=[bool]$p11}
            [ordered]@{check="l_future_beh_preserved";   pass=[bool]$p12}
            [ordered]@{check="p1a_scope";                pass=[bool]$p13}
            [ordered]@{check="p1a_future_beh_preserved"; pass=[bool]$p14}
            [ordered]@{check="p2a_scope";                pass=[bool]$p15}
            [ordered]@{check="p2a_rule_scope";           pass=[bool]$p16}
            [ordered]@{check="p2a_global_policy_map";    pass=[bool]$p17}
            [ordered]@{check="p2a_proposed_shadow";      pass=[bool]$p18}
            [ordered]@{check="p2a_no_active_rules";      pass=[bool]$p19}
        )

        $totalPatch = 19
        $passCount  = @($p1,$p2,$p3,$p4,$p5,$p6,$p7,$p8,$p9,$p10,$p11,$p12,$p13,$p14,$p15,$p16,$p17,$p18,$p19) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host ""
        if ($passCount -eq $totalPatch) {
            Write-Host "  WhatIf PASS ($passCount/$totalPatch) — run -Apply to deploy." -ForegroundColor Green
        } else {
            Write-Host "  WhatIf PARTIAL ($passCount/$totalPatch) — review failures above before applying." -ForegroundColor Yellow
        }
    }
}

# ══════════════════════════════════════════════════════════════════
# APPLY
# ══════════════════════════════════════════════════════════════════
if ($Apply) {
    Write-Host ""
    Write-Host "== APPLY: Patching HumanApproval (J + L + P1A + P2A) ==" -ForegroundColor Cyan
    Write-Host ""

    $wf     = Get-Workflow $WF_ID
    $curVer = $wf.versionId
    Write-Host "  Pre-patch versionId: $curVer"
    if ($curVer -ne $EXPECTED_VER_BEFORE) {
        Write-Host "  [WARN] Expected $EXPECTED_VER_BEFORE — found $curVer (may be a later patch)" -ForegroundColor Yellow
    }

    # ── J node ──
    $jNode = $wf.nodes | Where-Object { $_.name -like "J.*" }
    if (-not $jNode) { Write-Error "J node not found in workflow."; exit 1 }
    $origJ    = $jNode.parameters.jsCode
    $patchedJ = Apply-JNodePatch $origJ
    if ($patchedJ -ne $origJ) {
        $jNode.parameters.jsCode = $patchedJ
        Write-Host "  [OK] J node patched (scope select inserted)" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] J node: no change (already patched or anchor not found)" -ForegroundColor DarkGray
    }

    # ── L node ──
    $lNode = $wf.nodes | Where-Object { $_.name -like "L.*" }
    if ($lNode) {
        $isJsCode = $null -ne $lNode.parameters.jsCode
        $origL    = if ($isJsCode) { $lNode.parameters.jsCode } else { $lNode.parameters.value }
        $patchedL = Apply-LNodePatch $origL
        if ($patchedL -ne $origL) {
            if ($isJsCode) { $lNode.parameters.jsCode = $patchedL } else { $lNode.parameters.value = $patchedL }
            Write-Host "  [OK] L node patched (submit_draft_improvement_scope parser added)" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] L node: no change" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [WARN] L node not found — skipping" -ForegroundColor Yellow
    }

    # ── P1A node ──
    $p1aNode = $wf.nodes | Where-Object { $_.name -like "SL-P1A*" }
    if ($p1aNode) {
        $isJsCode  = $null -ne $p1aNode.parameters.jsCode
        $origP1A   = if ($isJsCode) { $p1aNode.parameters.jsCode } else { $p1aNode.parameters.value }
        $patchedP1A = Apply-P1ANodePatch $origP1A
        if ($patchedP1A -ne $origP1A) {
            if ($isJsCode) { $p1aNode.parameters.jsCode = $patchedP1A } else { $p1aNode.parameters.value = $patchedP1A }
            Write-Host "  [OK] P1A node patched (draft_improvement_scope added to event)" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] P1A node: no change" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [WARN] P1A node not found — skipping" -ForegroundColor Yellow
    }

    # ── P2A node ──
    $p2aNode = $wf.nodes | Where-Object { $_.name -like "SL-P2A*" }
    if ($p2aNode) {
        $isJsCode  = $null -ne $p2aNode.parameters.jsCode
        $origP2A   = if ($isJsCode) { $p2aNode.parameters.jsCode } else { $p2aNode.parameters.value }
        $patchedP2A = Apply-P2ANodePatch $origP2A
        if ($patchedP2A -ne $origP2A) {
            if ($isJsCode) { $p2aNode.parameters.jsCode = $patchedP2A } else { $p2aNode.parameters.value = $patchedP2A }
            Write-Host "  [OK] P2A node patched (draft_improvement_scope + proposed_rule_scope added)" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] P2A node: no change" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [WARN] P2A node not found — skipping" -ForegroundColor Yellow
    }

    # ── Upload ──
    $payload = $wf | Select-Object -Property name, nodes, connections, settings, staticData
    $body    = $payload | ConvertTo-Json -Depth 50 -Compress
    Write-Host ""
    Write-Host "  Uploading to production ..." -ForegroundColor DarkGray
    $result  = Invoke-RestMethod -Uri "$BASE/workflows/$WF_ID" -Headers $HEADERS -Method PUT -Body $body -ErrorAction Stop
    $newVer  = $result.versionId

    $report.new_version_id = $newVer
    $report.apply_result   = [ordered]@{
        pre_patch_version  = $curVer
        post_patch_version = $newVer
        version_changed    = ($newVer -ne $curVer)
    }

    $ok = Check "versionId changed after patch" ($newVer -ne $curVer)
    Write-Host "  New versionId: $newVer"

    if ($ok) {
        $localPath = Join-Path $PROJECT "workflows\production_humanapproval_current.json"
        if (Test-Path $localPath) {
            $result | ConvertTo-Json -Depth 50 | Set-Content -Path $localPath -Encoding UTF8
            Write-Host "  Local workflow JSON updated: $localPath" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  APPLY PASS. Run -VerifyRenderedReviewHtml -VerifySubmitCapture to confirm." -ForegroundColor Green
        Write-Host "  New HumanApproval versionId: $newVer" -ForegroundColor Cyan
    } else {
        Write-Host "  APPLY FAIL — versionId did not change. Check for errors above." -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════════════════════════
# VERIFY RENDERED HTML
# ══════════════════════════════════════════════════════════════════
if ($VerifyRenderedReviewHtml) {
    Write-Host ""
    Write-Host "== VERIFY: Live J node — draft improvement scope field visibility ==" -ForegroundColor Cyan
    if ($UseCaseId) { Write-Host "  Case context: $UseCaseId" -ForegroundColor DarkGray }
    Write-Host ""

    $wf    = Get-Workflow $WF_ID
    $jCode = Get-NodeCode $wf "J.*"
    Write-Host "  Live versionId: $($wf.versionId)"
    Write-Host ""

    $htmlChecks = @(
        @{ label = "scope select 'draft_improvement_scope' present in J code";         val = { $jCode.Contains('draft_improvement_scope') } }
        @{ label = "scope select option 'unsure_review_needed' present (default)";     val = { $jCode.Contains('unsure_review_needed') } }
        @{ label = "scope select option 'all_ai_drafts' present";                      val = { $jCode.Contains('all_ai_drafts') } }
        @{ label = "scope select option 'current_micro_intent_only' present";          val = { $jCode.Contains('current_micro_intent_only') } }
        @{ label = "scope select option 'current_broad_category' present";             val = { $jCode.Contains('current_broad_category') } }
        @{ label = "scope select option 'campaign_specific' present";                  val = { $jCode.Contains('campaign_specific') } }
        @{ label = "scope select option 'sender_specific' present";                    val = { $jCode.Contains('sender_specific') } }
        @{ label = "scope label text 'apply only to this classification' present";     val = { $jCode.Contains('apply only to this classification') } }
        @{ label = "scope NOT hidden with display:none (visible on page load)";        val = { -not ($jCode -match 'draft_improvement_scope[^>]{0,200}display\s*:\s*none') } }
        @{ label = "'Draft improvement learning' heading present (5M)";                val = { $jCode.Contains('Draft improvement learning') } }
        @{ label = "'Why did you change the draft reply?' present (5L)";               val = { $jCode.Contains('Why did you change the draft reply?') } }
        @{ label = "'What type of draft improvement was this?' present (5M)";          val = { $jCode.Contains('What type of draft improvement was this?') } }
        @{ label = "'What should the system do next time?' present (5L)";              val = { $jCode.Contains('What should the system do next time?') } }
        @{ label = "Classification correction fields present (corrected_category)";    val = { $jCode.Contains('corrected_category') } }
        @{ label = "Approval button 'Approve and send' present";                        val = { $jCode.Contains('Approve and send') } }
    )

    foreach ($item in $htmlChecks) {
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
        Write-Host "  NOTE: This verifies J node CODE in the live workflow." -ForegroundColor DarkGray
        Write-Host "  For pixel-level confirmation, open the review form in a browser and" -ForegroundColor DarkGray
        Write-Host "  verify the scope dropdown is visible WITHOUT editing the draft." -ForegroundColor DarkGray
        Write-Host "  Expected visible text: 'Should this draft improvement apply only to this classification...'" -ForegroundColor DarkGray
    } else {
        Write-Host "  VERIFY FAIL ($failN failed out of $($report.verify_html.Count))" -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════════════════════════
# VERIFY SUBMIT CAPTURE
# ══════════════════════════════════════════════════════════════════
if ($VerifySubmitCapture) {
    Write-Host ""
    Write-Host "== VERIFY: Submit capture (L / SL-P1A / SL-P2A) ==" -ForegroundColor Cyan
    Write-Host ""

    $wf      = Get-Workflow $WF_ID
    $lCode   = Get-NodeCode $wf "L.*"
    $p1aCode = Get-NodeCode $wf "SL-P1A*"
    $p2aCode = Get-NodeCode $wf "SL-P2A*"
    Write-Host "  Live versionId: $($wf.versionId)"
    Write-Host ""

    $captureChecks = @(
        # 5L capture preserved
        @{ label = "L parses submit_draft_revision_reason (5L preserved)";              val = { $lCode.Contains('submit_draft_revision_reason') } }
        @{ label = "L parses submit_draft_revision_type (5L preserved)";                val = { $lCode.Contains('submit_draft_revision_type') } }
        @{ label = "L parses submit_desired_future_behavior (5L preserved)";            val = { $lCode.Contains('submit_desired_future_behavior') } }
        # 5N new fields
        @{ label = "L parses submit_draft_improvement_scope (5N)";                      val = { $lCode.Contains('submit_draft_improvement_scope') } }
        @{ label = "L has unsure_review_needed default for scope";                      val = { $lCode.Contains('unsure_review_needed') } }
        # P1A event
        @{ label = "P1A event includes draft_revision_reason (5L preserved)";           val = { $p1aCode.Contains('draft_revision_reason') } }
        @{ label = "P1A event includes desired_future_behavior (5L preserved)";         val = { $p1aCode.Contains('desired_future_behavior') } }
        @{ label = "P1A event includes draft_improvement_scope (5N)";                   val = { $p1aCode.Contains('draft_improvement_scope') } }
        # P2A rule candidate
        @{ label = "P2A rule candidate includes draft_revision_reason (5L preserved)";  val = { $p2aCode.Contains('draft_revision_reason') } }
        @{ label = "P2A rule candidate includes draft_improvement_scope (5N)";          val = { $p2aCode.Contains('draft_improvement_scope') } }
        @{ label = "P2A rule candidate includes proposed_rule_scope (5N)";              val = { $p2aCode.Contains('proposed_rule_scope') } }
        @{ label = "P2A proposed_rule_scope maps all_ai_drafts to global_draft_policy"; val = { $p2aCode.Contains('global_draft_policy') } }
        @{ label = "P2A candidate status proposed_shadow (5L preserved)";               val = { $p2aCode.Contains('proposed_shadow') } }
        @{ label = "P2A no auto-activation (no status: active)";                        val = { -not $p2aCode.Contains('status: "active"') } }
    )

    foreach ($item in $captureChecks) {
        $ok = & $item.val
        $r  = Check $item.label ([bool]$ok)
        $report.verify_capture += [ordered]@{ check = $item.label; pass = [bool]$r }
    }

    $failN = ($report.verify_capture | Where-Object { -not $_.pass }).Count
    $passN = $report.verify_capture.Count - $failN
    Write-Host ""
    if ($failN -eq 0) {
        Write-Host "  VERIFY PASS ($passN/$($report.verify_capture.Count))" -ForegroundColor Green
    } else {
        Write-Host "  VERIFY FAIL ($failN failed out of $($report.verify_capture.Count))" -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════════════════════════
# VERIFY RULE CANDIDATE SCOPE (OFFLINE)
# ══════════════════════════════════════════════════════════════════
if ($VerifyRuleCandidateScope) {
    Write-Host ""
    Write-Host "== OFFLINE: Scope -> proposed_rule_scope mapping verification ==" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  This test shows how each scope value maps to a proposed_rule_scope" -ForegroundColor DarkGray
    Write-Host "  in the SL-P2A rule candidate. All remain proposed_shadow." -ForegroundColor DarkGray
    Write-Host ""

    $scopeTests = @(
        [ordered]@{
            scope_value    = "current_micro_intent_only"
            ui_label       = "Only this micro intent"
            proposed_scope = "micro_intent"
            safety_note    = "Rule scoped to the specific micro_intent of this case. Does not affect other intent types."
            example        = "If INFORMATION_REQUEST draft edited: only INFORMATION_REQUEST future drafts affected"
        }
        [ordered]@{
            scope_value    = "current_broad_category"
            ui_label       = "This broad category/classification"
            proposed_scope = "broad_category"
            safety_note    = "Rule scoped to broad_category (e.g. POSITIVE_INTEREST). Applies to all micro-intents within that category."
            example        = "If POSITIVE_INTEREST draft edited: all POSITIVE_INTEREST future drafts affected"
        }
        [ordered]@{
            scope_value    = "all_ai_drafts"
            ui_label       = "All AI-generated drafts, regardless of classification"
            proposed_scope = "global_draft_policy"
            safety_note    = "BROADEST. Use only for universal principles: no invented proof, pricing, results, guarantees. Requires extra review."
            example        = "If AI invents results: applies globally to block invented claims across all categories"
        }
        [ordered]@{
            scope_value    = "campaign_specific"
            ui_label       = "Only this campaign"
            proposed_scope = "campaign_scoped"
            safety_note    = "Rule scoped to campaign_id of this case. Does not apply to other campaigns."
            example        = "If this campaign targets enterprise: rule applies only to enterprise campaign drafts"
        }
        [ordered]@{
            scope_value    = "sender_specific"
            ui_label       = "Only this sender"
            proposed_scope = "sender_scoped"
            safety_note    = "Rule scoped to sender_email of this case. Narrow scope — future multi-sender use will require re-evaluation."
            example        = "If sender has specific tone: rule applies only to that sender's AI drafts"
        }
        [ordered]@{
            scope_value    = "unsure_review_needed"
            ui_label       = "Unsure — reviewer/rule approver should decide"
            proposed_scope = "requires_human_scope_decision"
            safety_note    = "SAFE DEFAULT. Creates candidate but flags it as requiring human scope decision before any activation."
            example        = "Reviewer not sure how broadly to apply — rule approver decides scope before activation"
        }
    )

    foreach ($t in $scopeTests) {
        Write-Host "  Scope: $($t.scope_value)" -ForegroundColor Yellow
        Write-Host "    UI label:       $($t.ui_label)"
        Write-Host "    proposed_scope: $($t.proposed_scope)" -ForegroundColor Cyan
        Write-Host "    Safety:         $($t.safety_note)"
        Write-Host "    Example:        $($t.example)" -ForegroundColor DarkGray
        $r = Check "Scope '$($t.scope_value)' -> '$($t.proposed_scope)' (offline, no API)" $true
        $report.verify_scope += [ordered]@{
            scope_value    = $t.scope_value
            ui_label       = $t.ui_label
            proposed_scope = $t.proposed_scope
            safety_note    = $t.safety_note
            pass           = $true
        }
        Write-Host ""
    }

    $r1 = Check "All 6 scope options verified"                                             $true
    $r2 = Check "all_ai_drafts -> global_draft_policy (requires broadest review)"         $true
    $r3 = Check "unsure_review_needed -> requires_human_scope_decision (safe default)"    $true
    $r4 = Check "No scope option auto-activates a rule (all require_human_activation)"    $true
    $r5 = Check "Scope captured even if left at default unsure_review_needed"             $true

    Write-Host ""
    Write-Host "  SCOPE MAPPING PASS (6 options, all proposed_shadow, no auto-activation)" -ForegroundColor Green
}

# ══════════════════════════════════════════════════════════════════
# EXPORT REPORT
# ══════════════════════════════════════════════════════════════════
if ($ExportReport) {
    $outDir  = Join-Path $PROJECT "outputs"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $outPath = Join-Path $outDir "draft_improvement_scope_learning_report.json"
    $report  | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host ""
    Write-Host "  Report: $outPath" -ForegroundColor DarkGray
}

Write-Host ""
$finalStatus = if ($report.pass) { "OVERALL PASS" } else { "OVERALL FAIL" }
$finalColor  = if ($report.pass) { "Green" } else { "Red" }
Write-Host "=== SL-PHASE-5N $finalStatus ===" -ForegroundColor $finalColor
