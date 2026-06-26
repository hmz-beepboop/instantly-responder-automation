#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.4 — Fix invalid OpenAI model string in Decision D.

.DESCRIPTION
    Root cause confirmed from case-478ee61b / decision execution 856:
      OpenAI returned HTTP 400 because model string was 'gpt-5-mini' (invalid).
      Correct model is 'gpt-5.4-mini'.

    Single change:
      Decision D — 'gpt-5-mini' → 'gpt-5.4-mini'

    Workflow patched:
      HMZ - Reply Decision Engine - Validation  (tgYmY97CG4Bm8snI)  — 1 change

    Everything else is verified preserved (not touched).

.PARAMETER WhatIf
    Validate in memory. No API writes. Backs up to disk. Prints WHATIF result.

.PARAMETER Apply
    Apply to production. Run only after WhatIf passes and user signals APPLY_PATCH_3_4.
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
$WHATIF_LIMIT = 12
$script:Calls = 0

$OLD_MODEL = "'gpt-5-mini'"
$NEW_MODEL = "'gpt-5.4-mini'"

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

# ── STEP 1: AUTH ───────────────────────────────────────────────────────────────
Write-Host "`n[$MODE] SL-PATCH-3.4 starting"
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
if (-not $fthMeta) {
    $fthMeta = Invoke-Prod 'GET' "/workflows/$WF_FTH"
}
if ($fthMeta.active -eq $true) {
    Write-Error "BLOCKED: Full Test Harness is ACTIVE. Patch refused."; exit 1
}
Write-Host "FTH_ACTIVE=false"

# ── STEP 4: FETCH ALL + BACKUP ─────────────────────────────────────────────────
$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.4-$ts"
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

# ── STEP 6: VERIFY OLD MODEL EXISTS EXACTLY ONCE ───────────────────────────────
$oldModelCount = ([regex]::Matches($codeDec, [regex]::Escape($OLD_MODEL))).Count
Write-Host "OLD_MODEL_OCCURRENCES=$oldModelCount  (expected 1)"
if ($oldModelCount -ne 1) {
    Write-Error "Expected exactly 1 occurrence of $OLD_MODEL in Decision D, found $oldModelCount. Aborting."; exit 1
}
Write-Host "ROOT_CAUSE_CONFIRMED: $OLD_MODEL found exactly once in Decision D"

# ── STEP 7: APPLY MODEL STRING PATCH ───────────────────────────────────────────
$patchedDec = $codeDec.Replace($OLD_MODEL, $NEW_MODEL)
Write-Host "MODEL_REPLACED: $OLD_MODEL → $NEW_MODEL"

# Verify the replacement took
$newModelCount = ([regex]::Matches($patchedDec, [regex]::Escape($NEW_MODEL))).Count
$oldModelStillPresent = $patchedDec.Contains($OLD_MODEL)
Write-Host "NEW_MODEL_OCCURRENCES=$newModelCount"
Write-Host "OLD_MODEL_STILL_PRESENT=$oldModelStillPresent"

# ── STEP 8: PRE-CHECKS ─────────────────────────────────────────────────────────
Write-Host "`n=== PRE-CHECKS ==="
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

# Model string checks
Check-Item 'dec_new_model_gpt_5_4_mini_present'      ($patchedDec -match [regex]::Escape($NEW_MODEL))
Check-Item 'dec_old_model_gpt_5_mini_absent'         (-not $patchedDec.Contains($OLD_MODEL))
Check-Item 'dec_new_model_exactly_once'              ($newModelCount -eq 1)

# Preservation checks — nothing else changed
Check-Item 'dec_this_helpers_httpRequest_present'    ($patchedDec -match 'this\.helpers\.httpRequest\(')
Check-Item 'dec_fetch_absent_from_openai_call'       ($patchedDec -notmatch 'const _fetchPromise\s*=\s*fetch\(')
Check-Item 'dec_dollar_helpers_httpRequest_absent'   ($patchedDec -notmatch '\$helpers\.httpRequest')
Check-Item 'dec_AbortController_absent'              ($patchedDec -notmatch 'new AbortController\(\)')
Check-Item 'dec_openai_responses_endpoint_present'   ($patchedDec -match 'api\.openai\.com/v1/responses')
Check-Item 'dec_OPENAI_API_KEY_present'              ($patchedDec -match 'OPENAI_API_KEY')
Check-Item 'dec_promise_race_timeout_present'        ($patchedDec -match 'Promise\.race\(')
Check-Item 'dec_input_context_spread_present'        ($patchedDec -match '\.\.\.input')
Check-Item 'dec_ai_supervised_present'               ($patchedDec -match "'ai_supervised'")
Check-Item 'dec_ai_failed_fallback_present'          ($patchedDec -match "'ai_failed_fallback'")
Check-Item 'dec_senderName_resolution_present'       ($patchedDec -match 'to_address_json\[0\]')
Check-Item 'dec_signature_append_dedupe_present'     ($patchedDec -match '_lastLine.*senderName')

Write-Host ""
Write-Host "STRUCTURAL_CHECKS: $(if ($script:structuralPass){'PASS'}else{'FAIL'}) ($($script:passCount)/$($script:totalCount))"

$safeToApply = $script:structuralPass
Write-Host "SAFE_TO_APPLY: $(if ($safeToApply){'YES'}else{'NO'})"

if (-not $script:structuralPass) {
    if ($WhatIf) {
        Write-Host "`nWHATIF_RESULT: STRUCTURAL_FAIL"
        Write-Host "SAFE_TO_APPLY: NO"
        Write-Host "API_CALLS_USED=$($script:Calls)/$WHATIF_LIMIT"
        exit 1
    }
    Write-Error "Structural pre-checks FAILED. Patch is not safe to apply."; exit 1
}

# ── WHATIF EXIT ────────────────────────────────────────────────────────────────
if ($WhatIf) {
    if ($safeToApply) {
        Write-Host "`nWHATIF_RESULT: WHATIF_OK"
        Write-Host "SAFE_TO_APPLY: YES"
        Write-Host "To apply, type exactly: APPLY_PATCH_3_4"
    } else {
        Write-Host "`nWHATIF_RESULT: STRUCTURAL_FAIL"
        Write-Host "SAFE_TO_APPLY: NO"
    }
    Write-Host "API_CALLS_USED=$($script:Calls)/$WHATIF_LIMIT"
    Write-Host "BACKUP_DIR=$backupDir"
    Write-Host "No production changes made."
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
# APPLY MODE — only reached with -Apply flag after WhatIf passes
# ══════════════════════════════════════════════════════════════════════════════
if (-not $safeToApply) {
    Write-Error "SAFE_TO_APPLY is NO. Run WhatIf first and resolve blocker."; exit 1
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

# Verify post-PUT
Write-Host "Verifying Decision post-PUT..."
$verDec   = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
$vDec     = $verDec.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
$vDecCp   = if ($vDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vDecCode = $vDec.parameters.$vDecCp

$postPass = $true
$postChecks = [ordered]@{
    'live_new_model_present'              = ($vDecCode -match [regex]::Escape($NEW_MODEL))
    'live_old_model_absent'               = (-not $vDecCode.Contains($OLD_MODEL))
    'live_this_helpers_httpRequest'       = ($vDecCode -match 'this\.helpers\.httpRequest\(')
    'live_openai_responses_endpoint'      = ($vDecCode -match 'api\.openai\.com/v1/responses')
    'live_OPENAI_API_KEY_present'         = ($vDecCode -match 'OPENAI_API_KEY')
    'live_promise_race_present'           = ($vDecCode -match 'Promise\.race\(')
    'live_ai_supervised_present'          = ($vDecCode -match "'ai_supervised'")
    'live_ai_failed_fallback_present'     = ($vDecCode -match "'ai_failed_fallback'")
}
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

# FTH post-check
$fthPost = Invoke-Prod 'GET' "/workflows/$WF_FTH"
if ($fthPost.active -eq $true) {
    Write-Error "POST-PATCH: Full Test Harness is ACTIVE — unexpected. Review immediately."; exit 1
}
Write-Host "FTH_STILL_INACTIVE=YES"

Write-Host "`nPATCH_APPLIED_AND_VERIFIED"
Write-Host "PATCH_SCOPE: Decision D model string only — gpt-5-mini → gpt-5.4-mini"
Write-Host "API_CALLS_USED=$($script:Calls)"
