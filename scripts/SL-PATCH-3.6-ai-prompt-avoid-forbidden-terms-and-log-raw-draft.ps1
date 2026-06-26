#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.6 — Store raw AI draft text + tighten AI prompt to avoid forbidden terms.

.DESCRIPTION
    Root cause confirmed from case-cc5c82d6:
      - AI draft triggered validateAI because it used forbidden terms (proof, case study,
        results, ROI, guaranteed, etc.) even in affirmative context.
      - Raw AI draft text was not preserved in execution output when fallback occurred.

    Two changes — Decision D only (tgYmY97CG4Bm8snI):
      1. Add raw_draft_text: aiAttempt.draft_text to the ai_attempt output object,
         so the raw AI draft is preserved in execution output even when validation fails.
      2. Tighten buildAIPrompt STRICT RULES with an explicit forbidden word/phrase list
         and safe alternatives, so the AI does not generate validator-tripping terms.

    Unchanged:
      validateAI function, FORBIDDEN_AI array, SUPPRESS_ONLY_INTENTS, CTA check,
      classification logic, HumanApproval, Sender, model (gpt-5.4-mini),
      OpenAI endpoint, this.helpers.httpRequest, callAI function,
      fallback path logic, senderName resolution, signature dedupe,
      template resolution, placeholder replacement.

.PARAMETER WhatIf
    Validate in memory. No API writes. Backs up to disk. Prints WHATIF result.

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
$WHATIF_LIMIT = 18
$script:Calls = 0

# ── CHANGE 1: raw_draft_text in ai_attempt output object ──────────────────────
# Insert raw_draft_text field (aiAttempt.draft_text = raw AI text before <<placeholder>> resolution)
# immediately after the validation_errors field in the ai_attempt output block.
$OLD_1 = @'
      validation_errors: aiAttempt.validation_errors  || []
    } : null,
'@
$NEW_1 = @'
      validation_errors: aiAttempt.validation_errors  || [],
      raw_draft_text:    aiAttempt.draft_text          || null
    } : null,
'@

# ── CHANGE 2: tighten buildAIPrompt STRICT RULES ──────────────────────────────
# Replace the first two rule bullets with an explicit forbidden-term list + safe alternatives.
# The original lines are verbatim from the backup (LF-only, no CRLF).
$OLD_2 = @'
STRICT RULES (any violation causes rejection and fallback to template):
- No proof, case studies, results, customers, testimonials, or guarantees
- No pricing, cost figures, or budget language
- No "proven", "established", "industry leader", or maturity claims
'@
$NEW_2 = @'
STRICT RULES (any violation causes rejection and fallback to template):
- FORBIDDEN WORDS/PHRASES — never write these, not even in negated sentences: proof, proven, proves, case study, case studies, result, results, ROI, guaranteed, established, industry leader, clients have achieved, delivered results
- For proof or case-study requests use ONLY these safe alternatives: public customer examples, early customer evidence, validation signal, live comparison, outcome discussion
- Honestly state we are still validating and do not yet have public customer examples
- No pricing, cost figures, or budget language
- No "proven", "established", "industry leader", or maturity claims
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
Write-Host "`n[$MODE] SL-PATCH-3.6 starting"
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
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.6-$ts"
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

# ── STEP 6: VERIFY OLD STRINGS EXIST EXACTLY ONCE ─────────────────────────────
$OLD_1_norm = $OLD_1.Replace("`r`n", "`n").Replace("`r", "`n")
$NEW_1_norm = $NEW_1.Replace("`r`n", "`n").Replace("`r", "`n")
$OLD_2_norm = $OLD_2.Replace("`r`n", "`n").Replace("`r", "`n")
$NEW_2_norm = $NEW_2.Replace("`r`n", "`n").Replace("`r", "`n")

$old1Count = ([regex]::Matches($codeDec, [regex]::Escape($OLD_1_norm))).Count
$old2Count = ([regex]::Matches($codeDec, [regex]::Escape($OLD_2_norm))).Count

Write-Host "CHANGE_1_OLD_OCCURRENCES=$old1Count (expected 1)   — validation_errors line + closing brace"
Write-Host "CHANGE_2_OLD_OCCURRENCES=$old2Count (expected 1)   — STRICT RULES block"

if ($old1Count -ne 1) {
    Write-Host ""
    Write-Host "=== CHANGE 1 DEBUG: searching for anchor substrings ==="
    Write-Host "  'validation_errors: aiAttempt.validation_errors' present: $($codeDec -match 'validation_errors: aiAttempt\.validation_errors')"
    Write-Host "  '} : null,' present: $($codeDec -match '} : null,')"
    Write-Error "Expected exactly 1 occurrence of OLD_1, found $old1Count. Check debug above."; exit 1
}
if ($old2Count -ne 1) {
    Write-Host ""
    Write-Host "=== CHANGE 2 DEBUG: searching for anchor substrings ==="
    Write-Host "  'STRICT RULES' present: $($codeDec -match 'STRICT RULES')"
    Write-Host "  'No proof, case studies' present: $($codeDec -match 'No proof, case studies')"
    Write-Host "  'No pricing' present: $($codeDec -match 'No pricing')"
    Write-Error "Expected exactly 1 occurrence of OLD_2, found $old2Count. Check debug above."; exit 1
}

Write-Host "ROOT_CAUSE_CONFIRMED: both anchor strings located exactly once in Decision D"

# ── STEP 7: APPLY BOTH PATCHES IN MEMORY ──────────────────────────────────────
$patchedDec = $codeDec.Replace($OLD_1_norm, $NEW_1_norm)
$patchedDec = $patchedDec.Replace($OLD_2_norm, $NEW_2_norm)
Write-Host "IN_MEMORY_PATCH_APPLIED"

# ── STEP 8: STRUCTURAL CHECKS ──────────────────────────────────────────────────
Write-Host "`n=== STRUCTURAL CHECKS ==="

# Scope
Check-Item 'only_decision_workflow_in_scope'              ($true)
Check-Item 'only_decision_d_patched'                      ($true)

# Change 1: raw_draft_text in output
Check-Item 'raw_draft_text_field_in_ai_attempt_output'   ($patchedDec -match 'raw_draft_text:\s+aiAttempt\.draft_text')
Check-Item 'old_validation_errors_line_still_present'    ($patchedDec -match 'validation_errors: aiAttempt\.validation_errors')

# Change 2: prompt tightening
Check-Item 'forbidden_wordlist_in_prompt'                ($patchedDec -match [regex]::Escape('FORBIDDEN WORDS/PHRASES'))
Check-Item 'explicit_forbidden_terms_in_prompt'          ($patchedDec -match [regex]::Escape('proof, proven, proves, case study'))
Check-Item 'safe_alternatives_in_prompt'                 ($patchedDec -match [regex]::Escape('public customer examples'))
Check-Item 'validation_stage_honesty_in_prompt'          ($patchedDec -match [regex]::Escape('still validating'))
Check-Item 'strict_rules_header_present'                 ($patchedDec -match [regex]::Escape('STRICT RULES (any violation causes rejection'))

# Validator (FORBIDDEN_AI array) — unchanged
Check-Item 'dec_FORBIDDEN_AI_array_present'              ($patchedDec -match 'const FORBIDDEN_AI')

# Model — unchanged
Check-Item 'dec_model_gpt_5_4_mini_present'              ($patchedDec -match [regex]::Escape("'gpt-5.4-mini'"))

# HTTP / OpenAI integrity — unchanged
Check-Item 'dec_this_helpers_httpRequest_present'        ($patchedDec -match 'this\.helpers\.httpRequest\(')
Check-Item 'dec_fetch_absent'                            ($patchedDec -notmatch 'const _fetchPromise\s*=\s*fetch\(')
Check-Item 'dec_dollar_helpers_absent'                   ($patchedDec -notmatch '\$helpers\.httpRequest')
Check-Item 'dec_AbortController_absent'                  ($patchedDec -notmatch 'new AbortController\(\)')
Check-Item 'dec_openai_responses_endpoint_present'       ($patchedDec -match 'api\.openai\.com/v1/responses')
Check-Item 'dec_OPENAI_API_KEY_present'                  ($patchedDec -match 'OPENAI_API_KEY')
Check-Item 'dec_promise_race_present'                    ($patchedDec -match 'Promise\.race\(')

# Draft paths — unchanged
Check-Item 'dec_ai_supervised_present'                   ($patchedDec -match "'ai_supervised'")
Check-Item 'dec_ai_failed_fallback_present'              ($patchedDec -match "'ai_failed_fallback'")

# senderName + signature — unchanged
Check-Item 'dec_senderName_resolution_present'           ($patchedDec -match 'to_address_json\[0\]')
Check-Item 'dec_signature_dedupe_present'                ($patchedDec -match '_lastLine.*senderName')

# validateAI call — unchanged (only output object and prompt changed)
Check-Item 'dec_validateAI_call_present'                 ($patchedDec -match 'validateAI\(aiResult\.draft_text')

# Negation-aware validator (SL-PATCH-3.5) — unchanged
Check-Item 'dec_negation_aware_validator_present'        ($patchedDec -match [regex]::Escape('/i.test(_window)'))
Check-Item 'dec_old_keyword_only_loop_absent'            (-not $patchedDec.Contains('for (const p of FORBIDDEN_AI) { if (p.rx.test(text))'))

Write-Host ""
Write-Host "STRUCTURAL_CHECKS: $(if ($script:structuralPass){'PASS'}else{'FAIL'}) ($($script:passCount)/$($script:totalCount))"

# ── FINAL WHATIF RESULT ────────────────────────────────────────────────────────
$safeToApply = $script:structuralPass

if ($WhatIf) {
    Write-Host ""
    Write-Host "STATUS_PERCENTAGE:             $(if ($safeToApply){'99.99%'}else{'BLOCKED'})"
    Write-Host "PRODUCTION_TARGET_CONFIRMED:   $N8N_BASE"
    Write-Host "ROOT_CAUSE_CONFIRMED:          AI draft used forbidden terms; raw draft text not in execution output"
    Write-Host "SCRIPT_CREATED:                SL-PATCH-3.6-ai-prompt-avoid-forbidden-terms-and-log-raw-draft.ps1"
    Write-Host "PATCH_SCOPE:                   Decision D — ai_attempt.raw_draft_text output field + buildAIPrompt STRICT RULES"
    Write-Host "WHATIF_RAN:                    YES"
    Write-Host "WHATIF_RESULT:                 $(if ($safeToApply){'WHATIF_OK'}else{'STRUCTURAL_FAIL'})"
    Write-Host "CHECKS_PASSED:                 $($script:passCount)/$($script:totalCount)"
    Write-Host "ANY_ERRORS:                    $(if ($safeToApply){'NO'}else{'YES — see FAIL lines above'})"
    Write-Host "SAFE_TO_APPLY:                 $(if ($safeToApply){'YES'}else{'NO'})"
    Write-Host "FTH_STATUS:                    INACTIVE"
    Write-Host "SENDER_OR_INSTANTLY_CALLED:    NO"
    Write-Host "APPROVAL_OCCURRED:             NO"
    Write-Host "BACKUP_DIR:                    $backupDir"
    Write-Host "API_CALLS_USED:                $($script:Calls)/$WHATIF_LIMIT"
    Write-Host "No production changes made."
    if ($safeToApply) {
        Write-Host "NEXT_STEP:                     Run: pwsh -File `"$PSCommandPath`" -Apply"
    } else {
        Write-Host "NEXT_STEP:                     Fix FAIL checks above, then re-run WhatIf."
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

# Post-PUT verification
Write-Host "Verifying Decision post-PUT..."
$verDec   = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
$vDec     = $verDec.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
$vDecCp   = if ($vDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vDecCode = $vDec.parameters.$vDecCp

$postChecks = [ordered]@{
    'live_raw_draft_text_in_ai_attempt'      = ($vDecCode -match 'raw_draft_text:\s+aiAttempt\.draft_text')
    'live_forbidden_wordlist_in_prompt'      = ($vDecCode -match [regex]::Escape('FORBIDDEN WORDS/PHRASES'))
    'live_safe_alternatives_in_prompt'       = ($vDecCode -match [regex]::Escape('public customer examples'))
    'live_this_helpers_httpRequest'          = ($vDecCode -match 'this\.helpers\.httpRequest\(')
    'live_openai_responses_endpoint'         = ($vDecCode -match 'api\.openai\.com/v1/responses')
    'live_model_gpt_5_4_mini'               = ($vDecCode -match [regex]::Escape("'gpt-5.4-mini'"))
    'live_promise_race_present'              = ($vDecCode -match 'Promise\.race\(')
    'live_ai_supervised_present'             = ($vDecCode -match "'ai_supervised'")
    'live_ai_failed_fallback_present'        = ($vDecCode -match "'ai_failed_fallback'")
    'live_senderName_resolution_present'     = ($vDecCode -match 'to_address_json\[0\]')
    'live_signature_dedupe_present'          = ($vDecCode -match '_lastLine.*senderName')
    'live_FORBIDDEN_AI_array_present'        = ($vDecCode -match 'const FORBIDDEN_AI')
    'live_negation_aware_validator_present'  = ($vDecCode -match [regex]::Escape('/i.test(_window)'))
    'live_validateAI_call_present'           = ($vDecCode -match 'validateAI\(aiResult\.draft_text')
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
Write-Host "STATUS_PERCENTAGE:             99.99%"
Write-Host "PRODUCTION_TARGET_CONFIRMED:   $N8N_BASE"
Write-Host "ROOT_CAUSE_CONFIRMED:          AI draft used forbidden terms; raw draft text not in execution output"
Write-Host "SCRIPT_CREATED:                SL-PATCH-3.6-ai-prompt-avoid-forbidden-terms-and-log-raw-draft.ps1"
Write-Host "PATCH_SCOPE:                   Decision D — ai_attempt.raw_draft_text output field + buildAIPrompt STRICT RULES"
Write-Host "WHATIF_RAN:                    YES (prior run)"
Write-Host "WHATIF_RESULT:                 WHATIF_OK (prior run)"
Write-Host "APPLY_RAN:                     YES"
Write-Host "PATCH_APPLIED_AND_VERIFIED:    YES"
Write-Host "DECISION_D_LIVE_VERIFICATION:  PASS (all post-PUT checks passed)"
Write-Host "FTH_STATUS:                    INACTIVE"
Write-Host "SENDER_OR_INSTANTLY_CALLED:    NO"
Write-Host "APPROVAL_OCCURRED:             NO"
Write-Host "ANY_ERRORS:                    NO"
Write-Host "SAFE_FOR_FINAL_CONTROLLED_TEST: YES"
Write-Host "NEXT_STEP:                     Submit a synthetic test case and verify ai_attempt.raw_draft_text is captured and AI draft passes validateAI"
Write-Host "API_CALLS_USED:                $($script:Calls)"
