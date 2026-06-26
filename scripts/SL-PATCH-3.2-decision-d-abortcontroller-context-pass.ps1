#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.2 — Replace AbortController with Promise.race in Decision node D.

.DESCRIPTION
    Root cause proven in exec 666: node "D. Draft Preparation (Templates / Human Draft)"
    crashes with "AbortController is not defined [line 194]" because AbortController is a
    browser/Node18+ global not available in n8n's Code node environment.

    Fix: replace the AbortController-based timeout (lines 194-195 + signal on line 209)
    with a Promise.race timeout pattern. No new dependencies. No stub/polyfill.

    Context pass-through is already correct: line 346 does results.push({ json: { ...input, draft } })
    so all upstream fields (nes, intake_id, classifier, decision, validation, config,
    security_gate, prefilter) flow through once the crash is removed.

    Target:  https://n8n.hmzaiautomation.com/api/v1
    Workflow: HMZ - Reply Decision Engine - Validation  (tgYmY97CG4Bm8snI)
    Node:     D. Draft Preparation (Templates / Human Draft)

.PARAMETER WhatIf
    Validate the patch in memory. No API writes. Prints WHATIF_OK if all checks pass.

.PARAMETER Apply
    Apply the patch to production. Run only after WhatIf succeeds and user types APPLY_PATCH_3_2.

.EXAMPLE
    pwsh -File .\SL-PATCH-3.2-decision-d-abortcontroller-context-pass.ps1 -WhatIf
#>
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── MODE GUARD ────────────────────────────────────────────────────────────────
if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage:  script.ps1 -WhatIf   |   script.ps1 -Apply"
    exit 0
}
if ($WhatIf -and $Apply) {
    Write-Error "Specify -WhatIf OR -Apply, not both."; exit 1
}
$MODE = if ($WhatIf) { 'WHATIF' } else { 'APPLY' }

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
$N8N_BASE     = 'https://n8n.hmzaiautomation.com/api/v1'
$WF_DECISION  = 'tgYmY97CG4Bm8snI'
$WF_FTH       = 'RLUcJHQJPvLhw4mG'
$NODE_D_NAME  = 'D. Draft Preparation (Templates / Human Draft)'
$WHATIF_LIMIT = 12
$script:Calls = 0

# ── API HELPER ────────────────────────────────────────────────────────────────
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
        Write-Error "[$Method $Path] HTTP $sc — $($_.Exception.Message)"; exit 1
    }
}

# ── STEP 1: AUTH ──────────────────────────────────────────────────────────────
Write-Host "`n[$MODE] SL-PATCH-3.2 starting"
Write-Host "TARGET: $N8N_BASE"
$authR = Invoke-Prod 'GET' '/workflows?limit=1'
if (-not $authR.data -or $authR.data.Count -eq 0) {
    Write-Error "Auth failed — no data returned. Stopping."; exit 1
}
Write-Host "AUTH_OK first_workflow='$($authR.data[0].name)'"

# ── STEP 2: DISCOVER WORKFLOWS ────────────────────────────────────────────────
$listR    = Invoke-Prod 'GET' '/workflows?limit=25'
$allMeta  = $listR.data
Write-Host "WORKFLOWS_DISCOVERED=$($allMeta.Count)"
$allMeta | ForEach-Object { Write-Host "  $($_.id) active=$($_.active) '$($_.name)'" }

# ── STEP 3: FTH GUARD ─────────────────────────────────────────────────────────
$fthMeta = $allMeta | Where-Object { $_.id -eq $WF_FTH }
if (-not $fthMeta) {
    Write-Host "  FTH not in list — fetching directly"
    $fthMeta = Invoke-Prod 'GET' "/workflows/$WF_FTH"
}
if ($fthMeta.active -eq $true) {
    Write-Error "BLOCKED: Full Test Harness is ACTIVE. Patch refused."; exit 1
}
Write-Host "FTH_ACTIVE=false — safe to proceed"

# ── STEP 4: BACKUP ALL WORKFLOWS ──────────────────────────────────────────────
$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.2-$ts"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "BACKUP_DIR=$backupDir"

$decisionWfFull = $null
foreach ($wfMeta in $allMeta) {
    $full     = Invoke-Prod 'GET' "/workflows/$($wfMeta.id)"
    $safe     = $wfMeta.name -replace '[\\/:*?"<>|]', '_'
    $filePath = Join-Path $backupDir "$($wfMeta.id)_$safe.json"
    $full | ConvertTo-Json -Depth 30 | Set-Content -Path $filePath -Encoding UTF8
    Write-Host "  BACKED_UP $($wfMeta.id) → $(Split-Path $filePath -Leaf)"
    if ($wfMeta.id -eq $WF_DECISION) { $decisionWfFull = $full }
}

if (-not $decisionWfFull) {
    Write-Host "  Decision not in list — fetching directly"
    $decisionWfFull = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
    $safe     = $decisionWfFull.name -replace '[\\/:*?"<>|]', '_'
    $filePath = Join-Path $backupDir "${WF_DECISION}_$safe.json"
    $decisionWfFull | ConvertTo-Json -Depth 30 | Set-Content -Path $filePath -Encoding UTF8
    Write-Host "  BACKED_UP $WF_DECISION → $(Split-Path $filePath -Leaf)"
}

$backupCount = (Get-ChildItem $backupDir -Filter '*.json' | Measure-Object).Count
Write-Host "BACKUP_COMPLETE files=$backupCount"

# ── STEP 5: LOCATE NODE D ─────────────────────────────────────────────────────
$nodeD = $decisionWfFull.nodes | Where-Object { $_.name -eq $NODE_D_NAME }
if (-not $nodeD) {
    Write-Error "Node '$NODE_D_NAME' not found."
    Write-Host "Available nodes: $($decisionWfFull.nodes | ForEach-Object { $_.name })"
    exit 1
}
Write-Host "NODE_D_FOUND=YES type=$($nodeD.type)"

$codeParam = if ($nodeD.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$origCode  = $nodeD.parameters.$codeParam
Write-Host "CODE_PARAM=$codeParam CODE_LEN=$($origCode.Length)"

# ── STEP 6: VERIFY AbortController PRESENT ────────────────────────────────────
if ($origCode -notmatch 'new AbortController\(\)') {
    Write-Error "AbortController not found in live node D code — patch may already be applied or code has changed."; exit 1
}
Write-Host "ABORTCONTROLLER_CONFIRMED_IN_LIVE_CODE=YES"

# ── STEP 7: BUILD PATCHED CODE ────────────────────────────────────────────────
# Normalize to LF (API uses LF; PowerShell here-strings on Windows use CRLF)
$codeLF = $origCode.Replace("`r`n", "`n").Replace("`r", "`n")

# OLD: lines 194-211 (2-space indent for callAI body, 4-space for try block)
$oldBlock = (@'
  const ctrl  = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), AI_DRAFT_TIMEOUT_MS);
  try {
    const reqBody = {
      model:              AI_DRAFT_MODEL,
      max_output_tokens:  AI_DRAFT_MAX_OUTPUT_TOKENS,
      input: [{ role:'user', content:prompt }]
    };
    // Temperature: included by default; if model rejects it the error falls back to deterministic
    if (typeof AI_DRAFT_TEMPERATURE === 'number') reqBody.temperature = AI_DRAFT_TEMPERATURE;

    const resp = await fetch('https://api.openai.com/v1/responses', {
      method:  'POST',
      headers: { 'Content-Type':'application/json', 'Authorization':'Bearer ' + apiKey },
      body:    JSON.stringify(reqBody),
      signal:  ctrl.signal
    });
    clearTimeout(timer);
'@).Replace("`r`n", "`n")

# NEW: same block with Promise.race replacing AbortController
$newBlock = (@'
  let timer;
  try {
    const reqBody = {
      model:              AI_DRAFT_MODEL,
      max_output_tokens:  AI_DRAFT_MAX_OUTPUT_TOKENS,
      input: [{ role:'user', content:prompt }]
    };
    // Temperature: included by default; if model rejects it the error falls back to deterministic
    if (typeof AI_DRAFT_TEMPERATURE === 'number') reqBody.temperature = AI_DRAFT_TEMPERATURE;

    const _fetchPromise   = fetch('https://api.openai.com/v1/responses', {
      method:  'POST',
      headers: { 'Content-Type':'application/json', 'Authorization':'Bearer ' + apiKey },
      body:    JSON.stringify(reqBody)
    });
    const _timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('AI request timed out after ' + AI_DRAFT_TIMEOUT_MS + 'ms')), AI_DRAFT_TIMEOUT_MS);
    });
    const resp = await Promise.race([_fetchPromise, _timeoutPromise]);
    clearTimeout(timer);
'@).Replace("`r`n", "`n")

if (-not $codeLF.Contains($oldBlock)) {
    Write-Error "Cannot locate target block in node D code. Code may differ from expected."
    Write-Host "Expected block begins: $(($oldBlock -split "`n") | Select-Object -First 3 | ForEach-Object { '  ' + $_ })"
    exit 1
}

$patchedCode  = $codeLF.Replace($oldBlock, $newBlock)
$codeDelta    = $patchedCode.Length - $codeLF.Length
Write-Host "REPLACEMENT_SUCCESS old_block_len=$($oldBlock.Length) new_block_len=$($newBlock.Length) code_delta=+$codeDelta"

# ── STEP 8: PRE-CHECKS ────────────────────────────────────────────────────────
Write-Host "`n=== PRE-CHECKS ==="
$allPass = $true
$checks  = [ordered]@{
    'no_AbortController_in_patched'        = ($patchedCode -notmatch 'new AbortController\(\)')
    'no_ctrl_signal_in_patched'            = ($patchedCode -notmatch 'ctrl\.signal')
    'Promise_race_present'                 = ($patchedCode -match 'Promise\.race\(')
    '_timeoutPromise_defined'              = ($patchedCode -match '_timeoutPromise')
    '_fetchPromise_defined'                = ($patchedCode -match '_fetchPromise')
    'let_timer_before_try'                 = ($patchedCode -match 'let timer;')
    'catch_block_clearTimeout_present'     = ($patchedCode -match 'catch\(e\)')
    'openai_endpoint_present'              = ($patchedCode -match 'api\.openai\.com/v1/responses')
    'OPENAI_API_KEY_reference_present'     = ($patchedCode -match 'OPENAI_API_KEY')
    'AI_DRAFT_MODEL_gpt5mini_present'      = ($patchedCode -match "'gpt-5-mini'")
    'ai_supervised_source_present'         = ($patchedCode -match "'ai_supervised'")
    'ai_failed_fallback_source_present'    = ($patchedCode -match "'ai_failed_fallback'")
    'deterministic_template_source_present'= ($patchedCode -match "'deterministic_template'")
    'input_spread_on_results_push'         = ($patchedCode -match '\.\.\.input')
    'no_bare_error_only_return_from_node'  = ($patchedCode -notmatch 'return\s*\[\s*\{\s*json\s*:\s*\{\s*error')
}
foreach ($k in $checks.Keys) {
    $v   = $checks[$k]
    $sym = if ($v) { 'PASS' } else { $allPass = $false; 'FAIL' }
    Write-Host "  [$sym] $k"
}

if (-not $allPass) {
    Write-Error "One or more pre-checks FAILED. Patch is NOT safe to apply."; exit 1
}
Write-Host "ALL_PRE_CHECKS=PASSED"

# ── WHATIF EXIT ───────────────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host "`nWHATIF_OK"
    Write-Host "API_CALLS_USED=$($script:Calls) / $WHATIF_LIMIT"
    Write-Host "BACKUP_DIR=$backupDir"
    Write-Host "No production changes made."
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
# APPLY MODE — only reached with -Apply flag
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== APPLYING PATCH ==="
$nodeD.parameters.$codeParam = $patchedCode

Write-Host "Uploading patched Decision workflow..."
$putR = Invoke-Prod 'PUT' "/workflows/$WF_DECISION" $decisionWfFull
Write-Host "PUT_OK id=$($putR.id) name='$($putR.name)'"

Write-Host "Verifying live code post-PUT..."
$verWf  = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
$vNodeD = $verWf.nodes | Where-Object { $_.name -eq $NODE_D_NAME }
$vParam = if ($vNodeD.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vCode  = $vNodeD.parameters.$vParam

$postPass = $true
$postChecks = [ordered]@{
    'live_no_AbortController'  = ($vCode -notmatch 'new AbortController\(\)')
    'live_Promise_race_present'= ($vCode -match 'Promise\.race\(')
    'live_openai_endpoint'     = ($vCode -match 'api\.openai\.com/v1/responses')
    'live_OPENAI_API_KEY'      = ($vCode -match 'OPENAI_API_KEY')
}
foreach ($k in $postChecks.Keys) {
    $v   = $postChecks[$k]
    $sym = if ($v) { 'PASS' } else { $postPass = $false; 'FAIL' }
    Write-Host "  [$sym] $k"
}
if (-not $postPass) {
    Write-Error "POST-PATCH verification FAILED. Investigate production immediately."; exit 1
}

if ($verWf.active -ne $true) {
    Write-Host "Decision inactive after PUT — activating..."
    Invoke-Prod 'POST' "/workflows/$WF_DECISION/activate" | Out-Null
    Write-Host "ACTIVATED=YES"
} else {
    Write-Host "DECISION_ACTIVE=YES (already active)"
}

$fthPost = Invoke-Prod 'GET' "/workflows/$WF_FTH"
if ($fthPost.active -eq $true) {
    Write-Error "POST-PATCH: Full Test Harness is ACTIVE — unexpected. Review immediately."; exit 1
}
Write-Host "FTH_STILL_INACTIVE=YES"

Write-Host "`nPATCH_APPLIED_AND_VERIFIED"
Write-Host "API_CALLS_USED=$($script:Calls)"
