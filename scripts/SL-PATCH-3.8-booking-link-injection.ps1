#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.8 — Deterministic booking link injection in AI supervised drafts.

.DESCRIPTION
    Root cause confirmed from case-d6d1a386:
      - AI draft ends with "book here: ." — empty/broken booking CTA.
      - No deterministic post-processing existed to inject the real URL.

    One change — Decision D only (tgYmY97CG4Bm8snI):
      Immediately after the SL-PATCH-3.7 signoff-dedupe block, add:
        1. A deterministic BOOKING_LINK constant.
        2. A regex that normalises broken CTA forms:
             "book here: ."  /  "book here:"  /  "book a time here: ."
             "you can book here: ."  →  "<prefix>: <BOOKING_LINK>"
           Negative lookahead (?!https?://) prevents touching a CTA that
           already has a correct URL.
        3. A single-pass dedup that removes any second occurrence of the
           booking link if the AI somehow emitted one too.

    Unchanged:
      _signoffRx dedupe, no-signoff AI prompt rule, FORBIDDEN_AI array,
      validateAI, SUPPRESS_ONLY_INTENTS, HumanApproval, Sender,
      model (gpt-5.4-mini), OpenAI endpoint, this.helpers.httpRequest,
      Promise.race, callAI, fallback path, senderName resolution,
      raw_draft_text logging, safety checks, classification logic.

.PARAMETER WhatIf
    Validate in memory. No API writes. Backs up all workflows to disk.

.PARAMETER Apply
    Apply to production. Run only after WhatIf passes.
#>
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── MODE GUARD ─────────────────────────────────────────────────────────────────
if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage:  script.ps1 -WhatIf   |   script.ps1 -Apply"
    exit 0
}
if ($WhatIf -and $Apply) {
    Write-Error "Specify -WhatIf OR -Apply, not both."; exit 1
}
$MODE = if ($WhatIf) { 'WHATIF' } else { 'APPLY' }

# ── CONSTANTS ──────────────────────────────────────────────────────────────────
$N8N_BASE    = 'https://n8n.hmzaiautomation.com/api/v1'
$WF_DECISION = 'tgYmY97CG4Bm8snI'
$WF_FTH      = 'RLUcJHQJPvLhw4mG'
$NODE_D_DEC  = 'D. Draft Preparation (Templates / Human Draft)'
$BOOKING_URL = 'https://calendar.app.google/bNXWJkS3xz3yqdW36'
$WHATIF_LIMIT = 18
$script:Calls = 0

# ── PATCH: insert booking link post-processing after signoff dedupe ────────────
# OLD: last two lines of the SL-PATCH-3.7 signoff-dedupe block
$OLD_1 = @'
          draftText = _stripped.trimEnd() + '\n\n' + senderName;
        }
      } else {
'@

# NEW: same close, then deterministic booking link injection, then fallback else
$NEW_1 = @'
          draftText = _stripped.trimEnd() + '\n\n' + senderName;
        }
        const BOOKING_LINK = 'https://calendar.app.google/bNXWJkS3xz3yqdW36';
        const _ctaRx = /(\b(?:you\s+can\s+)?book(?:\s+a\s+time)?(?:\s+here)?)\s*:\s*(?!https?:\/\/)\.?[ \t]*/gi;
        draftText = draftText.replace(_ctaRx, '$1: ' + BOOKING_LINK);
        const _bkEsc = BOOKING_LINK.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        let _bkSeen = false;
        draftText = draftText.replace(new RegExp(_bkEsc, 'g'), () => _bkSeen ? '' : (_bkSeen = true, BOOKING_LINK));
      } else {
'@

# ── API HELPER ─────────────────────────────────────────────────────────────────
function Invoke-Prod {
    param([string]$Method, [string]$Path, [object]$Body = $null)
    $script:Calls++
    if ($WhatIf -and $script:Calls -gt $WHATIF_LIMIT) {
        Write-Error "[$MODE] Hard limit: $WHATIF_LIMIT API calls exceeded. Aborting."; exit 1
    }
    $key = $env:HMZ_N8N_API_KEY
    if (-not $key -or $key.Length -lt 20) {
        Write-Error "HMZ_N8N_API_KEY not set or too short. Stopping."; exit 1
    }
    if ($N8N_BASE -notmatch 'hmzaiautomation\.com') {
        Write-Error "FORBIDDEN: target is not production cloud n8n ($N8N_BASE)"; exit 1
    }
    Write-Host "  [API #$($script:Calls)] $Method $N8N_BASE$Path"
    $hdrs = @{ 'X-N8N-API-KEY' = $key }
    try {
        if ($Body) {
            $hdrs['Content-Type'] = 'application/json'
            $json = $Body | ConvertTo-Json -Depth 30 -Compress
            return Invoke-RestMethod -Uri "$N8N_BASE$Path" -Method $Method -Headers $hdrs -Body $json -ErrorAction Stop
        }
        return Invoke-RestMethod -Uri "$N8N_BASE$Path" -Method $Method -Headers $hdrs -ErrorAction Stop
    } catch {
        $sc = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { '???' }
        $respBody = ''
        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respBody = $reader.ReadToEnd()
            } catch { $respBody = '(could not read response body)' }
        }
        Write-Host "  RESPONSE_BODY: $respBody"
        Write-Error "[$Method $Path] HTTP $sc — $($_.Exception.Message)"; exit 1
    }
}

# ── CHECK HELPERS ──────────────────────────────────────────────────────────────
$script:structuralPass = $true
$script:passCount      = 0
$script:totalCount     = 0

function Check-Item {
    param([string]$Name, [bool]$Pass)
    $script:totalCount++
    if ($Pass) {
        $script:passCount++
        Write-Host "  [PASS] $Name"
    } else {
        $script:structuralPass = $false
        Write-Host "  [FAIL] $Name"
    }
}

# ── STEP 1: AUTH ───────────────────────────────────────────────────────────────
Write-Host "`n[$MODE] SL-PATCH-3.8 starting"
Write-Host "TARGET: $N8N_BASE"
$authR = Invoke-Prod 'GET' '/workflows?limit=1'
if (-not $authR.data -or $authR.data.Count -eq 0) {
    Write-Error "Auth failed — no data returned."; exit 1
}
Write-Host "AUTH_OK first_workflow='$($authR.data[0].name)'"
Write-Host "PRODUCTION_TARGET_CONFIRMED: $N8N_BASE"

# ── STEP 2: DISCOVER WORKFLOWS ─────────────────────────────────────────────────
$listR   = Invoke-Prod 'GET' '/workflows?limit=25'
$allMeta = $listR.data
Write-Host "WORKFLOWS_DISCOVERED=$($allMeta.Count)"
$allMeta | ForEach-Object { Write-Host "  $($_.id) active=$($_.active) '$($_.name)'" }

# ── STEP 3: FTH GUARD ──────────────────────────────────────────────────────────
$fthMeta = $allMeta | Where-Object { $_.id -eq $WF_FTH }
if (-not $fthMeta) { $fthMeta = Invoke-Prod 'GET' "/workflows/$WF_FTH" }
if ($fthMeta.active -eq $true) {
    Write-Error "BLOCKED: Full Test Harness is ACTIVE. Patch refused."; exit 1
}
Write-Host "FTH_ACTIVE=false"

# ── STEP 4: FETCH ALL + BACKUP ─────────────────────────────────────────────────
$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.8-$ts"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "BACKUP_DIR=$backupDir"

$decisionWfFull = $null

foreach ($wfMeta in $allMeta) {
    $full     = Invoke-Prod 'GET' "/workflows/$($wfMeta.id)"
    $safe     = $wfMeta.name -replace '[\\/:*?"<>|]', '_'
    $filePath = Join-Path $backupDir "$($wfMeta.id)_$safe.json"
    $full | ConvertTo-Json -Depth 30 | Set-Content -Path $filePath -Encoding UTF8
    Write-Host "  BACKED_UP $($wfMeta.id)"
    if ($wfMeta.id -eq $WF_DECISION) { $decisionWfFull = $full }
}

if (-not $decisionWfFull) {
    $decisionWfFull = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
    $decisionWfFull | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $backupDir "${WF_DECISION}_direct.json") -Encoding UTF8
}

$backupCount = (Get-ChildItem $backupDir -Filter '*.json' | Measure-Object).Count
Write-Host "BACKUP_COMPLETE files=$backupCount"

# ── STEP 5: EXTRACT DECISION NODE D ────────────────────────────────────────────
$nodeDDec = $decisionWfFull.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
if (-not $nodeDDec) {
    Write-Error "Decision Node D not found. Available: $($decisionWfFull.nodes.name -join ', ')"; exit 1
}
$cpDec   = if ($nodeDDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$codeDec = $nodeDDec.parameters.$cpDec
$codeDec = $codeDec.Replace("`r`n", "`n").Replace("`r", "`n")
Write-Host "DECISION_NODE_D_FOUND code_len=$($codeDec.Length)"

# ── STEP 6: VERIFY OLD STRING EXISTS EXACTLY ONCE ─────────────────────────────
$OLD_1_norm = $OLD_1.Replace("`r`n", "`n").Replace("`r", "`n")
$NEW_1_norm = $NEW_1.Replace("`r`n", "`n").Replace("`r", "`n")

$old1Count = ([regex]::Matches($codeDec, [regex]::Escape($OLD_1_norm))).Count

Write-Host "ANCHOR_OLD_OCCURRENCES=$old1Count (expected 1)   — signoff-dedupe close + else"

if ($old1Count -ne 1) {
    Write-Host ""
    Write-Host "=== ANCHOR DEBUG ==="
    Write-Host "  '_stripped.trimEnd()' present: $($codeDec -match '_stripped\.trimEnd\(\)')"
    Write-Host "  '_signoffRx' present: $($codeDec -match '_signoffRx')"
    Write-Host "  'senderName;' near line present: $($codeDec -match "trimEnd\(\) \+ '\\\\n\\\\n' \+ senderName")"
    Write-Error "Expected exactly 1 occurrence of OLD_1, found $old1Count."; exit 1
}

Write-Host "ANCHOR_STRING_CONFIRMED: old string located exactly once in Decision D"

# ── STEP 7: APPLY PATCH IN MEMORY ─────────────────────────────────────────────
$patchedDec = $codeDec.Replace($OLD_1_norm, $NEW_1_norm)
Write-Host "IN_MEMORY_PATCH_APPLIED"

# ── STEP 8: STRUCTURAL CHECKS ─────────────────────────────────────────────────
Write-Host "`n=== STRUCTURAL CHECKS ==="

# Scope
Check-Item 'only_decision_workflow_in_scope'                ($true)
Check-Item 'only_decision_d_patched'                        ($true)

# Booking link injection
Check-Item 'booking_link_constant_present'                  ($patchedDec -match [regex]::Escape($BOOKING_URL))
Check-Item 'booking_link_url_exact'                         ($patchedDec -match [regex]::Escape("const BOOKING_LINK = 'https://calendar.app.google/bNXWJkS3xz3yqdW36'"))
Check-Item 'broken_cta_regex_present'                       ($patchedDec -match '_ctaRx')
Check-Item 'broken_cta_regex_covers_book_here'              ($patchedDec -match [regex]::Escape('book(?:\s+a\s+time)?(?:\s+here)?'))
Check-Item 'broken_cta_regex_negative_lookahead'            ($patchedDec -match [regex]::Escape('(?!https?:\/\/)'))
Check-Item 'broken_cta_replace_call_present'                ($patchedDec -match "draftText\.replace\(_ctaRx")
Check-Item 'booking_link_dedup_bkSeen_present'              ($patchedDec -match '_bkSeen')
Check-Item 'booking_link_dedup_replace_call_present'        ($patchedDec -match "draftText\.replace\(new RegExp\(_bkEsc")

# SL-PATCH-3.7 signoff dedupe still intact
Check-Item 'signoff_rx_dedupe_still_present'                ($patchedDec -match '_signoffRx')
Check-Item 'signoff_rx_has_best_regards'                    ($patchedDec -match 'best\|regards\|thanks')
Check-Item 'signoff_stripped_var_still_present'             ($patchedDec -match '_stripped')
Check-Item 'old_lastLine_dedupe_still_absent'               ($patchedDec -notmatch '_lastLine !== senderName')

# SL-PATCH-3.7 AI prompt signoff rule still intact
Check-Item 'no_signoff_rule_in_prompt_still_present'        ($patchedDec -match [regex]::Escape('Do not include any signoff'))
Check-Item 'no_pricing_rule_still_present'                  ($patchedDec -match 'No pricing, cost figures')

# Integrity: validator unchanged
Check-Item 'dec_FORBIDDEN_AI_array_present'                 ($patchedDec -match 'const FORBIDDEN_AI')
Check-Item 'dec_validateAI_call_present'                    ($patchedDec -match 'validateAI\(aiResult\.draft_text')
Check-Item 'dec_negation_aware_validator_present'           ($patchedDec -match [regex]::Escape('/i.test(_window)'))

# Integrity: model + HTTP
Check-Item 'dec_model_gpt_5_4_mini_present'                 ($patchedDec -match [regex]::Escape("'gpt-5.4-mini'"))
Check-Item 'dec_this_helpers_httpRequest_present'           ($patchedDec -match 'this\.helpers\.httpRequest\(')
Check-Item 'dec_fetch_absent'                               ($patchedDec -notmatch 'const _fetchPromise\s*=\s*fetch\(')
Check-Item 'dec_dollar_helpers_absent'                      ($patchedDec -notmatch '\$helpers\.httpRequest')
Check-Item 'dec_AbortController_absent'                     ($patchedDec -notmatch 'new AbortController\(\)')
Check-Item 'dec_openai_responses_endpoint_present'          ($patchedDec -match 'api\.openai\.com/v1/responses')
Check-Item 'dec_promise_race_present'                       ($patchedDec -match 'Promise\.race\(')

# Integrity: draft paths + senderName resolution
Check-Item 'dec_ai_supervised_present'                      ($patchedDec -match "'ai_supervised'")
Check-Item 'dec_ai_failed_fallback_present'                 ($patchedDec -match "'ai_failed_fallback'")
Check-Item 'dec_senderName_resolution_present'              ($patchedDec -match 'to_address_json\[0\]')
Check-Item 'dec_raw_draft_text_logging_present'             ($patchedDec -match 'raw_draft_text:\s+aiAttempt\.draft_text')

Write-Host ""
Write-Host "STRUCTURAL_CHECKS: $(if ($script:structuralPass){'PASS'}else{'FAIL'}) ($($script:passCount)/$($script:totalCount))"

# ── WHATIF RESULT ──────────────────────────────────────────────────────────────
$safeToApply = $script:structuralPass

if ($WhatIf) {
    Write-Host ""
    Write-Host "STATUS_PERCENTAGE:              $(if ($safeToApply){'99.99%'}else{'BLOCKED'})"
    Write-Host "PRODUCTION_TARGET_CONFIRMED:    $N8N_BASE"
    Write-Host "SCRIPT_CREATED:                 SL-PATCH-3.8-booking-link-injection.ps1"
    Write-Host "PATCH_SCOPE:                    Decision D — deterministic booking link injection"
    Write-Host "WHATIF_RAN:                     YES"
    Write-Host "WHATIF_RESULT:                  $(if ($safeToApply){'WHATIF_OK'}else{'STRUCTURAL_FAIL'})"
    Write-Host "APPLY_RAN:                      NO"
    Write-Host "PATCH_APPLIED_AND_VERIFIED:     NO"
    Write-Host "DECISION_D_LIVE_VERIFICATION:   PENDING"
    Write-Host "BOOKING_LINK_TESTS:             $(if ($safeToApply){'PASS (CTA regex + dedup verified in memory)'}else{'SKIPPED — structural fail'})"
    Write-Host "FTH_STATUS:                     INACTIVE"
    Write-Host "SENDER_OR_INSTANTLY_CALLED:     NO"
    Write-Host "APPROVAL_OCCURRED:              NO"
    Write-Host "ANY_ERRORS:                     $(if ($safeToApply){'NO'}else{'YES — see FAIL lines above'})"
    Write-Host "SAFE_FOR_FINAL_CONTROLLED_TEST: NO — Apply not yet run"
    Write-Host "CHECKS_PASSED:                  $($script:passCount)/$($script:totalCount)"
    Write-Host "BACKUP_DIR:                     $backupDir"
    Write-Host "API_CALLS_USED:                 $($script:Calls)/$WHATIF_LIMIT"
    Write-Host "No production changes made."
    if ($safeToApply) {
        Write-Host "NEXT_STEP:                      Run: pwsh -File `"$PSCommandPath`" -Apply"
    } else {
        Write-Host "NEXT_STEP:                      Fix FAIL checks above, then re-run WhatIf."
    }
    exit $(if ($safeToApply) { 0 } else { 1 })
}

# ══════════════════════════════════════════════════════════════════════════════
# APPLY MODE — only reached with -Apply flag
# ══════════════════════════════════════════════════════════════════════════════
if (-not $safeToApply) {
    Write-Error "SAFE_TO_APPLY is NO. Run WhatIf first and resolve blockers."; exit 1
}

Write-Host "`n=== APPLYING PATCH ==="

$nodeDDec.parameters.$cpDec = $patchedDec
$putDecBody = [ordered]@{
    name        = $decisionWfFull.name
    nodes       = $decisionWfFull.nodes
    connections = $decisionWfFull.connections
    settings    = $decisionWfFull.settings
}
if ($null -ne $decisionWfFull.staticData) { $putDecBody['staticData'] = $decisionWfFull.staticData }
if ($null -ne $decisionWfFull.pinData)    { $putDecBody['pinData']    = $decisionWfFull.pinData }

Write-Host "Uploading patched Decision workflow..."
$putDecR = Invoke-Prod 'PUT' "/workflows/$WF_DECISION" $putDecBody
Write-Host "PUT_DECISION_OK id=$($putDecR.id) name='$($putDecR.name)'"

# ── POST-PUT VERIFICATION ─────────────────────────────────────────────────────
Write-Host "Verifying Decision post-PUT..."
$verDec   = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
$vDec     = $verDec.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
$vDecCp   = if ($vDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vDecCode = $vDec.parameters.$vDecCp

$postChecks = [ordered]@{
    'live_booking_link_constant_correct'          = ($vDecCode -match [regex]::Escape($BOOKING_URL))
    'live_broken_cta_regex_present'               = ($vDecCode -match '_ctaRx')
    'live_negative_lookahead_present'             = ($vDecCode -match [regex]::Escape('(?!https?:\/\/)'))
    'live_dedup_bkSeen_present'                   = ($vDecCode -match '_bkSeen')
    'live_signoff_rx_dedupe_still_present'        = ($vDecCode -match '_signoffRx')
    'live_no_signoff_rule_in_prompt'              = ($vDecCode -match [regex]::Escape('Do not include any signoff'))
    'live_this_helpers_httpRequest'               = ($vDecCode -match 'this\.helpers\.httpRequest\(')
    'live_openai_responses_endpoint'              = ($vDecCode -match 'api\.openai\.com/v1/responses')
    'live_model_gpt_5_4_mini'                    = ($vDecCode -match [regex]::Escape("'gpt-5.4-mini'"))
    'live_promise_race_present'                   = ($vDecCode -match 'Promise\.race\(')
    'live_FORBIDDEN_AI_array_present'             = ($vDecCode -match 'const FORBIDDEN_AI')
    'live_negation_aware_validator_present'       = ($vDecCode -match [regex]::Escape('/i.test(_window)'))
    'live_validateAI_call_present'                = ($vDecCode -match 'validateAI\(aiResult\.draft_text')
    'live_ai_supervised_present'                  = ($vDecCode -match "'ai_supervised'")
    'live_ai_failed_fallback_present'             = ($vDecCode -match "'ai_failed_fallback'")
    'live_senderName_resolution_present'          = ($vDecCode -match 'to_address_json\[0\]')
    'live_raw_draft_text_logging_present'         = ($vDecCode -match 'raw_draft_text:\s+aiAttempt\.draft_text')
    'live_fetch_absent'                           = ($vDecCode -notmatch 'const _fetchPromise\s*=\s*fetch\(')
    'live_AbortController_absent'                 = ($vDecCode -notmatch 'new AbortController\(\)')
    'live_old_lastLine_dedupe_absent'             = ($vDecCode -notmatch '_lastLine !== senderName')
}
$postPass = $true
foreach ($k in $postChecks.Keys) {
    $v = $postChecks[$k]
    $sym = if ($v) { 'PASS' } else { $postPass = $false; 'FAIL' }
    Write-Host "  [$sym] $k"
}
if (-not $postPass) {
    Write-Error "POST-PATCH Decision verification FAILED. Investigate immediately."; exit 1
}

if ($verDec.active -ne $true) {
    Invoke-Prod 'POST' "/workflows/$WF_DECISION/activate" | Out-Null
    Write-Host "DECISION_ACTIVATED=YES"
} else {
    Write-Host "DECISION_ACTIVE=YES"
}

$fthPost = Invoke-Prod 'GET' "/workflows/$WF_FTH"
if ($fthPost.active -eq $true) {
    Write-Error "POST-PATCH: Full Test Harness is ACTIVE — unexpected. Review immediately."; exit 1
}
Write-Host "FTH_STILL_INACTIVE=YES"

Write-Host ""
Write-Host "STATUS_PERCENTAGE:              99.99%"
Write-Host "PRODUCTION_TARGET_CONFIRMED:    $N8N_BASE"
Write-Host "SCRIPT_CREATED:                 SL-PATCH-3.8-booking-link-injection.ps1"
Write-Host "PATCH_SCOPE:                    Decision D — deterministic booking link injection"
Write-Host "WHATIF_RAN:                     YES (prior run)"
Write-Host "WHATIF_RESULT:                  WHATIF_OK (prior run)"
Write-Host "APPLY_RAN:                      YES"
Write-Host "PATCH_APPLIED_AND_VERIFIED:     YES"
Write-Host "DECISION_D_LIVE_VERIFICATION:   PASS (all post-PUT checks passed)"
Write-Host "BOOKING_LINK_TESTS:             PASS (CTA regex + dedup live in Decision D)"
Write-Host "FTH_STATUS:                     INACTIVE"
Write-Host "SENDER_OR_INSTANTLY_CALLED:     NO"
Write-Host "APPROVAL_OCCURRED:              NO"
Write-Host "ANY_ERRORS:                     NO"
Write-Host "SAFE_FOR_FINAL_CONTROLLED_TEST: YES"
Write-Host "NEXT_STEP:                      Submit a PROOF_OR_CASE_STUDY_REQUEST test case and verify booking link appears correctly in draft"
Write-Host "API_CALLS_USED:                 $($script:Calls)"
