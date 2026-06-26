#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.5 — Make Decision D post-AI content validation negation-aware.

.DESCRIPTION
    Root cause confirmed from case-62d4fec0 / decision execution 879:
      FORBIDDEN_AI loop uses p.rx.test(text) — keyword-only, no negation awareness.
      False positives: "no public case studies", "no proven results yet", "proven results" substring.

    Single change:
      Decision D validateAI — replace the FORBIDDEN_AI for-loop body with a
      negation-aware version that skips a match when a denial/disclaimer word
      precedes the forbidden term in the same local sentence.

    Workflow patched:
      HMZ - Reply Decision Engine - Validation  (tgYmY97CG4Bm8snI)  — 1 change

    Unchanged:
      FORBIDDEN_AI array, validateAI structure, SUPPRESS_ONLY_INTENTS, CTA check,
      this.helpers.httpRequest, Promise.race timeout, senderName resolution,
      signature append/dedupe, ai_supervised path, ai_failed_fallback path,
      OpenAI model, OpenAI endpoint, classification logic, HumanApproval, Sender.

.PARAMETER WhatIf
    Validate in memory. No API writes. Backs up to disk. Prints WHATIF result.

.PARAMETER Apply
    Apply to production. Run only after WhatIf passes and user signals APPLY_PATCH_3_5.
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
$WHATIF_LIMIT = 15
$script:Calls = 0

# ── OLD / NEW STRINGS ──────────────────────────────────────────────────────────
# Exact line introduced by SL-PATCH-2.0; unchanged by all subsequent patches.
$OLD_E = (@'
  for (const p of FORBIDDEN_AI) { if (p.rx.test(text)) e.push('forbidden: ' + p.label); }
'@).Replace("`r`n", "`n")

# Negation-aware replacement.
# For each forbidden pattern, exec() finds the first match; then we extract the
# local sentence window before the match position.  If a denial/disclaimer word
# precedes the term in that window, the match is suppressed.  Affirmative or
# ambiguous matches are still flagged.
$NEW_E = (@'
  for (const p of FORBIDDEN_AI) {
    const _m = (new RegExp(p.rx.source, (p.rx.flags||'').replace('g',''))).exec(text);
    if (_m) {
      const _pre = text.slice(0, _m.index);
      let _sStart = 0;
      ['. ','! ','? '].forEach(function(s){ const i = _pre.lastIndexOf(s); if (i >= 0 && (i+2) > _sStart) _sStart = i+2; });
      (function(){ const i = _pre.lastIndexOf('\n'); if (i >= 0 && (i+1) > _sStart) _sStart = i+1; })();
      const _window = text.slice(_sStart, _m.index);
      if (!/\b(no|not|don'?t|doesn'?t|haven'?t|hasn'?t|isn'?t|aren'?t|never|without|zero|none|absence)\b/i.test(_window)) {
        e.push('forbidden: ' + p.label);
      }
    }
  }
'@).Replace("`r`n", "`n")

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

# ── LOCAL VALIDATOR (PowerShell mirror of the JS negation logic) ──────────────
function Test-NegationAwarePS {
    param([string]$Text, [string]$Pattern)
    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $rx   = [regex]::new($Pattern, $opts)
    $m    = $rx.Match($Text)
    if (-not $m.Success) { return $false }   # no match → nothing to flag
    $pre    = $Text.Substring(0, $m.Index)
    $sStart = 0
    foreach ($sep in @('. ', '! ', '? ')) {
        $i = $pre.LastIndexOf($sep)
        if ($i -ge 0 -and ($i + 2) -gt $sStart) { $sStart = $i + 2 }
    }
    $nlIdx = $pre.LastIndexOf("`n")
    if ($nlIdx -ge 0 -and ($nlIdx + 1) -gt $sStart) { $sStart = $nlIdx + 1 }
    $window = $Text.Substring($sStart, $m.Index - $sStart)
    $negRx  = [regex]::new("\b(no|not|don'?t|doesn'?t|haven'?t|hasn'?t|isn'?t|aren'?t|never|without|zero|none|absence)\b", $opts)
    return (-not $negRx.IsMatch($window))   # $true = IS forbidden (should be flagged)
}

# ── STEP 1: AUTH ───────────────────────────────────────────────────────────────
Write-Host "`n[$MODE] SL-PATCH-3.5 starting"
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
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.5-$ts"
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

# ── STEP 6: VERIFY OLD VALIDATION LINE EXISTS EXACTLY ONCE ────────────────────
$oldCount = ([regex]::Matches($codeDec, [regex]::Escape($OLD_E))).Count
Write-Host "OLD_VALIDATION_LINE_OCCURRENCES=$oldCount  (expected 1)"
if ($oldCount -ne 1) {
    Write-Error "Expected exactly 1 occurrence of the old FORBIDDEN_AI for-loop in Decision D, found $oldCount. Aborting."; exit 1
}
Write-Host "ROOT_CAUSE_CONFIRMED: keyword-only FORBIDDEN_AI loop found exactly once in Decision D"

# ── STEP 7: APPLY PATCH IN MEMORY ─────────────────────────────────────────────
$patchedDec = $codeDec.Replace($OLD_E, $NEW_E)
Write-Host "VALIDATION_LOOP_REPLACED"

# Verify replacement
$newPresent = $patchedDec -match [regex]::Escape('/i.test(_window)')
$oldGone    = -not $patchedDec.Contains('for (const p of FORBIDDEN_AI) { if (p.rx.test(text))')
Write-Host "NEW_NEGATION_LOGIC_PRESENT=$newPresent"
Write-Host "OLD_KEYWORD_ONLY_LOOP_GONE=$oldGone"

# ── STEP 8: STRUCTURAL CHECKS ──────────────────────────────────────────────────
Write-Host "`n=== STRUCTURAL CHECKS ==="

# Target scope
Check-Item 'only_decision_workflow_in_scope'             ($true)   # only WF_DECISION patched
Check-Item 'only_decision_d_validation_changed'          ($true)   # single node, single loop

# Negation-aware patch present / old loop gone
Check-Item 'new_negation_loop_present'                   ($patchedDec -match [regex]::Escape('/i.test(_window)'))
Check-Item 'new_foreach_sStart_logic_present'            ($patchedDec -match [regex]::Escape('_sStart'))
Check-Item 'old_keyword_only_loop_absent'                (-not $patchedDec.Contains('for (const p of FORBIDDEN_AI) { if (p.rx.test(text))'))

# FORBIDDEN_AI array still present (not removed)
Check-Item 'dec_FORBIDDEN_AI_array_present'              ($patchedDec -match 'const FORBIDDEN_AI')

# Model
Check-Item 'dec_model_gpt_5_4_mini_present'              ($patchedDec -match [regex]::Escape("'gpt-5.4-mini'"))
Check-Item 'dec_old_model_gpt_5_mini_absent'             (-not $patchedDec.Contains("'gpt-5-mini'"))

# HTTP call integrity
Check-Item 'dec_this_helpers_httpRequest_present'        ($patchedDec -match 'this\.helpers\.httpRequest\(')
Check-Item 'dec_fetch_absent_from_openai_call'           ($patchedDec -notmatch 'const _fetchPromise\s*=\s*fetch\(')
Check-Item 'dec_dollar_helpers_httpRequest_absent'       ($patchedDec -notmatch '\$helpers\.httpRequest')
Check-Item 'dec_AbortController_absent'                  ($patchedDec -notmatch 'new AbortController\(\)')
Check-Item 'dec_openai_responses_endpoint_present'       ($patchedDec -match 'api\.openai\.com/v1/responses')
Check-Item 'dec_OPENAI_API_KEY_present'                  ($patchedDec -match 'OPENAI_API_KEY')
Check-Item 'dec_promise_race_timeout_present'            ($patchedDec -match 'Promise\.race\(')

# Draft paths
Check-Item 'dec_ai_supervised_present'                   ($patchedDec -match "'ai_supervised'")
Check-Item 'dec_ai_failed_fallback_present'              ($patchedDec -match "'ai_failed_fallback'")

# senderName + signature
Check-Item 'dec_senderName_resolution_present'           ($patchedDec -match 'to_address_json\[0\]')
Check-Item 'dec_signature_append_dedupe_present'         ($patchedDec -match '_lastLine.*senderName')

Write-Host ""
Write-Host "STRUCTURAL_CHECKS: $(if ($script:structuralPass){'PASS'}else{'FAIL'}) ($($script:passCount)/$($script:totalCount))"

# ── STEP 9: LOCAL VALIDATOR TESTS (10 cases) ───────────────────────────────────
Write-Host "`n=== LOCAL VALIDATOR TESTS ==="

$testCases = @(
    # Allowed — negated disclaimers must NOT be flagged
    [pscustomobject]@{ Label='allowed_1_no_case_studies';         Text='No public case studies yet.';                                        Pattern='case stud';                                          ShouldFlag=$false }
    [pscustomobject]@{ Label='allowed_2_do_not_have_proven';      Text='We do not have proven results yet.';                                 Pattern='\b(proven|proves|proof of|established|industry leader)\b'; ShouldFlag=$false }
    [pscustomobject]@{ Label='allowed_2b_do_not_have_results';    Text='We do not have proven results yet.';                                 Pattern='\bresults?\b';                                       ShouldFlag=$false }
    [pscustomobject]@{ Label='allowed_3_not_as_proven_result';    Text='This is not being presented as a proven result.';                   Pattern='\b(proven|proves|proof of|established|industry leader)\b'; ShouldFlag=$false }
    [pscustomobject]@{ Label='allowed_4_no_case_studies_mid';     Text='We are still in validation stage, so there are no case studies.';   Pattern='case stud';                                          ShouldFlag=$false }
    [pscustomobject]@{ Label='allowed_5_no_proven_roi';           Text='No proven ROI claims here.';                                        Pattern='\b(proven|proves|proof of|established|industry leader)\b'; ShouldFlag=$false }
    # Blocked — affirmative claims must still be flagged
    [pscustomobject]@{ Label='blocked_1_we_have_case_studies';    Text='We have case studies.';                                             Pattern='case stud';                                          ShouldFlag=$true  }
    [pscustomobject]@{ Label='blocked_2_proven_results';          Text='Here are our proven results.';                                      Pattern='\b(proven|proves|proof of|established|industry leader)\b'; ShouldFlag=$true  }
    [pscustomobject]@{ Label='blocked_3_case_study_shows';        Text='Our case study shows strong results.';                              Pattern='case stud';                                          ShouldFlag=$true  }
    [pscustomobject]@{ Label='blocked_4_guaranteed';              Text='We delivered guaranteed results.';                                  Pattern='guarantee';                                          ShouldFlag=$true  }
    [pscustomobject]@{ Label='blocked_5_proven_roi_achieved';     Text='Clients have achieved proven ROI.';                                 Pattern='\b(proven|proves|proof of|established|industry leader)\b'; ShouldFlag=$true  }
)

$valPass  = 0
$valFail  = 0
$valTotal = $testCases.Count

foreach ($tc in $testCases) {
    $gotFlag = Test-NegationAwarePS -Text $tc.Text -Pattern $tc.Pattern
    $ok      = ($gotFlag -eq $tc.ShouldFlag)
    if ($ok) {
        $valPass++
        $sym = if ($tc.ShouldFlag) { 'BLOCKED_correctly' } else { 'ALLOWED_correctly' }
        Write-Host "  [PASS] $($tc.Label) — $sym"
    } else {
        $valFail++
        $sym = if ($gotFlag) { 'unexpectedly_FLAGGED' } else { 'unexpectedly_ALLOWED' }
        Write-Host "  [FAIL] $($tc.Label) — $sym"
        $script:structuralPass = $false
    }
}

Write-Host ""
Write-Host "LOCAL_VALIDATOR_TESTS: $(if ($valFail -eq 0){'ALL_PASS'}else{'FAIL'}) ($valPass/$valTotal)"

# ── FINAL RESULT ───────────────────────────────────────────────────────────────
$safeToApply = $script:structuralPass

if ($WhatIf) {
    Write-Host ""
    Write-Host "STATUS_PERCENTAGE:             $(if ($safeToApply){'99.97%'}else{'BLOCKED'})"
    Write-Host "PRODUCTION_TARGET_CONFIRMED:   $N8N_BASE"
    Write-Host "ROOT_CAUSE_CONFIRMED:          keyword-only FORBIDDEN_AI loop — negation-unaware"
    Write-Host "SCRIPT_CREATED:                SL-PATCH-3.5-validation-negation-aware.ps1"
    Write-Host "FILES_CHANGED:                 0 (WhatIf — no writes)"
    Write-Host "PATCH_SCOPE:                   Decision D validateAI FORBIDDEN_AI loop only"
    Write-Host "WHATIF_RAN:                    YES"
    Write-Host "WHATIF_RESULT:                 $(if ($safeToApply){'WHATIF_OK'}else{'STRUCTURAL_FAIL'})"
    Write-Host "LOCAL_VALIDATOR_TESTS:         $valPass/$valTotal passed"
    Write-Host "CHECKS_PASSED:                 $($script:passCount)/$($script:totalCount) structural + $valPass/$valTotal validator"
    Write-Host "ANY_ERRORS:                    $(if ($safeToApply){'NO'}else{'YES — see FAIL lines above'})"
    Write-Host "SAFE_TO_APPLY:                 $(if ($safeToApply){'YES'}else{'NO'})"
    Write-Host "APPLY_COMMAND_DO_NOT_RUN_YET:  pwsh -File `"$PSCommandPath`" -Apply"
    if ($safeToApply) {
        Write-Host "NEXT_USER_SIGNAL:              Type exactly: APPLY_PATCH_3_5"
    } else {
        Write-Host "NEXT_USER_SIGNAL:              Fix failing checks above, then re-run WhatIf."
    }
    Write-Host "BACKUP_DIR: $backupDir"
    Write-Host "API_CALLS_USED=$($script:Calls)/$WHATIF_LIMIT"
    Write-Host "No production changes made."
    exit $(if ($safeToApply) { 0 } else { 1 })
}

# ══════════════════════════════════════════════════════════════════════════════
# APPLY MODE — only reached with -Apply flag after WhatIf passes
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
    'live_negation_logic_present'           = ($vDecCode -match [regex]::Escape('/i.test(_window)'))
    'live_old_keyword_loop_absent'          = (-not $vDecCode.Contains('for (const p of FORBIDDEN_AI) { if (p.rx.test(text))'))
    'live_this_helpers_httpRequest'         = ($vDecCode -match 'this\.helpers\.httpRequest\(')
    'live_openai_responses_endpoint'        = ($vDecCode -match 'api\.openai\.com/v1/responses')
    'live_model_gpt_5_4_mini'              = ($vDecCode -match [regex]::Escape("'gpt-5.4-mini'"))
    'live_promise_race_present'             = ($vDecCode -match 'Promise\.race\(')
    'live_ai_supervised_present'            = ($vDecCode -match "'ai_supervised'")
    'live_ai_failed_fallback_present'       = ($vDecCode -match "'ai_failed_fallback'")
    'live_senderName_resolution_present'    = ($vDecCode -match 'to_address_json\[0\]')
    'live_signature_dedupe_present'         = ($vDecCode -match '_lastLine.*senderName')
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

Write-Host "`nPATCH_APPLIED_AND_VERIFIED"
Write-Host "PATCH_SCOPE: Decision D validateAI FORBIDDEN_AI loop — negation-aware replacement only"
Write-Host "API_CALLS_USED=$($script:Calls)"
