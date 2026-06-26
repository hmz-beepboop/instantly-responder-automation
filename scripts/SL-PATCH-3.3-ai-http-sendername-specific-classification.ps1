#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    SL-PATCH-3.3 — Fix AI HTTP call, senderName resolution, and HA notification format.

.DESCRIPTION
    Three proven fixes from case-460c4317:
    A. Decision D callAI: replace global fetch with $helpers.httpRequest
       (fetch is not a global in n8n Code node sandbox)
    B. Decision D: resolve senderName from _instantly_hydrated_email or eaccount
       so fallback and AI drafts end with sender name
    C. HumanApproval D: show micro_intent as primary "Classification:" line

    WARNING: $helpers.httpRequest is the n8n-documented Code node HTTP method but
    was NOT found in any live Code node in this environment. SAFE_TO_APPLY is NO
    until proven. http_helper_proven_in_live_env pre-check reports this.

    Workflows patched:
      HMZ - Reply Decision Engine - Validation  (tgYmY97CG4Bm8snI)  — 4 changes
      HMZ - Reply Human Approval - Validation   (9aPrt92jFhoYFxbs)  — 1 change

.PARAMETER WhatIf
    Validate in memory. No API writes. Backs up to disk. Prints WHATIF result.

.PARAMETER Apply
    Apply to production. Run only after WhatIf and user signals APPLY_PATCH_3_3.
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
$WF_HA       = '9aPrt92jFhoYFxbs'
$WF_FTH      = 'RLUcJHQJPvLhw4mG'
$NODE_D_DEC  = 'D. Draft Preparation (Templates / Human Draft)'
$NODE_D_HA   = 'D. Build Google Chat Notification Payload'
$WHATIF_LIMIT = 12
$script:Calls = 0

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
Write-Host "`n[$MODE] SL-PATCH-3.3 starting"
Write-Host "TARGET: $N8N_BASE"
$authR = Invoke-Prod 'GET' '/workflows?limit=1'
if (-not $authR.data -or $authR.data.Count -eq 0) {
    Write-Error "Auth failed — no data returned."; exit 1
}
Write-Host "AUTH_OK first_workflow='$($authR.data[0].name)'"

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

# ── STEP 4: FETCH ALL + BACKUP + HTTP SCAN ─────────────────────────────────────
$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = "C:\Users\Hamzah Zahid\Downloads\n8n-backup-SL-PATCH-3.3-$ts"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "BACKUP_DIR=$backupDir"

$decisionWfFull  = $null
$haWfFull        = $null
$httpHelperFound = $false
$httpHelperHits  = @()

foreach ($wfMeta in $allMeta) {
    $full     = Invoke-Prod 'GET' "/workflows/$($wfMeta.id)"
    $safe     = $wfMeta.name -replace '[\\/:*?"<>|]', '_'
    $filePath = Join-Path $backupDir "$($wfMeta.id)_$safe.json"
    $full | ConvertTo-Json -Depth 30 | Set-Content -Path $filePath -Encoding UTF8
    Write-Host "  BACKED_UP $($wfMeta.id)"
    if ($wfMeta.id -eq $WF_DECISION) { $decisionWfFull = $full }
    if ($wfMeta.id -eq $WF_HA)       { $haWfFull       = $full }
    # HTTP helper scan
    $full.nodes | Where-Object { $_.type -match 'code|function' } | ForEach-Object {
        $cp = if ($_.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
        $c  = $_.parameters.$cp
        if ($c -and ($c -match '\$helpers\.httpRequest|this\.helpers\.httpRequest')) {
            $httpHelperFound = $true
            $httpHelperHits += "$($wfMeta.id)/$($_.name)"
            Write-Host "  HTTP_HELPER_FOUND wf=$($wfMeta.id) node='$($_.name)'"
        }
    }
}

if (-not $decisionWfFull) {
    $decisionWfFull = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
    $decisionWfFull | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $backupDir "${WF_DECISION}_direct.json") -Encoding UTF8
}
if (-not $haWfFull) {
    $haWfFull = Invoke-Prod 'GET' "/workflows/$WF_HA"
    $haWfFull | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $backupDir "${WF_HA}_direct.json") -Encoding UTF8
}

$backupCount = (Get-ChildItem $backupDir -Filter '*.json' | Measure-Object).Count
Write-Host "BACKUP_COMPLETE files=$backupCount"

# ── STEP 5: HTTP HELPER SCAN RESULT ────────────────────────────────────────────
Write-Host "`n=== HTTP HELPER SCAN ==="
if ($httpHelperFound) {
    Write-Host "HTTP_HELPER_PROVEN=YES found_in=$($httpHelperHits -join ',')"
} else {
    Write-Host "HTTP_HELPER_PROVEN=NO — zero live Code nodes use `$helpers.httpRequest"
    Write-Host "  PATCH uses `$helpers.httpRequest as best-available n8n-documented method."
    Write-Host "  SAFE_TO_APPLY will be NO until proven in this environment."
}

# ── STEP 6: EXTRACT DECISION NODE D ────────────────────────────────────────────
$nodeDDec = $decisionWfFull.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
if (-not $nodeDDec) {
    Write-Error "Decision Node D not found. Available: $($decisionWfFull.nodes.name -join ', ')"; exit 1
}
$cpDec   = if ($nodeDDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$codeDec = $nodeDDec.parameters.$cpDec
$codeDec = $codeDec.Replace("`r`n", "`n").Replace("`r", "`n")
Write-Host "DECISION_NODE_D_FOUND code_len=$($codeDec.Length)"

# ── STEP 7: EXTRACT HA NODE D ──────────────────────────────────────────────────
$nodeDHA = $haWfFull.nodes | Where-Object { $_.name -eq $NODE_D_HA }
if (-not $nodeDHA) {
    Write-Error "HA Node D not found. Available: $($haWfFull.nodes.name -join ', ')"; exit 1
}
$cpHA   = if ($nodeDHA.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$codeHA = $nodeDHA.parameters.$cpHA
$codeHA = $codeHA.Replace("`r`n", "`n").Replace("`r", "`n")
Write-Host "HA_NODE_D_FOUND code_len=$($codeHA.Length)"

# ── STEP 8: PATCH DECISION NODE D (4 changes) ──────────────────────────────────
Write-Host "`n=== PATCHING DECISION D ==="
$patchedDec = $codeDec

# 8A: replace global fetch with $helpers.httpRequest
$old_8A = (@'
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

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      return { ok:false, error:'OpenAI HTTP ' + resp.status + ': ' + errText.slice(0,200), provider:'openai' };
    }

    const data = await resp.json();
'@).Replace("`r`n", "`n")

$new_8A = (@'
    const _httpPromise    = $helpers.httpRequest({
      method:  'POST',
      url:     'https://api.openai.com/v1/responses',
      headers: { 'Content-Type':'application/json', 'Authorization':'Bearer ' + apiKey },
      body:    reqBody,
      json:    true
    });
    const _timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('AI request timed out after ' + AI_DRAFT_TIMEOUT_MS + 'ms')), AI_DRAFT_TIMEOUT_MS);
    });
    const data = await Promise.race([_httpPromise, _timeoutPromise]);
    clearTimeout(timer);
'@).Replace("`r`n", "`n")

if (-not $patchedDec.Contains($old_8A)) {
    Write-Error "8A: fetch block not found in Decision D — code may have changed."; exit 1
}
$patchedDec = $patchedDec.Replace($old_8A, $new_8A)
Write-Host "  8A APPLIED (fetch → `$helpers.httpRequest) delta=$(($new_8A.Length - $old_8A.Length))"

# 8B: senderName resolution with fallback chain
$old_8B = (@'
  const senderName  = sCfg && sCfg.senderName  ? sCfg.senderName  : null;
'@).Replace("`r`n", "`n")

$new_8B = (@'
  let   senderName  = (sCfg && (sCfg.senderName || sCfg.sender_name)) || null;
  if (!senderName) {
    const _toJson = input.raw_payload &&
      input.raw_payload._instantly_hydrated_email &&
      Array.isArray(input.raw_payload._instantly_hydrated_email.to_address_json) &&
      input.raw_payload._instantly_hydrated_email.to_address_json[0];
    if (_toJson && typeof _toJson.name === 'string' && _toJson.name.trim()) {
      senderName = _toJson.name.trim().split(/\s+/)[0];
    }
  }
  if (!senderName && eKey) {
    const _lp = eKey.split('@')[0];
    if (_lp) senderName = _lp.charAt(0).toUpperCase() + _lp.slice(1);
  }
'@).Replace("`r`n", "`n")

if (-not $patchedDec.Contains($old_8B)) {
    Write-Error "8B: senderName const line not found in Decision D."; exit 1
}
$patchedDec = $patchedDec.Replace($old_8B, $new_8B)
Write-Host "  8B APPLIED (senderName resolution) delta=$(($new_8B.Length - $old_8B.Length))"

# 8C: remove [[senderName: not configured]] from renderTemplate subs
$old_8C = (@'
  const subs = { firstName:useName?firstName:'', senderName:senderName||'[[senderName: not configured]]', bookingLink:bookingLink||'' };
'@).Replace("`r`n", "`n")

$new_8C = (@'
  const subs = { firstName:useName?firstName:'', senderName:senderName||'', bookingLink:bookingLink||'' };
'@).Replace("`r`n", "`n")

if (-not $patchedDec.Contains($old_8C)) {
    Write-Error "8C: renderTemplate subs line not found in Decision D."; exit 1
}
$patchedDec = $patchedDec.Replace($old_8C, $new_8C)
Write-Host "  8C APPLIED (renderTemplate senderName fallback cleared)"

# 8D: AI draft senderName replace fallback + signature append/dedup
$old_8D = (@'
          .replace(/<<senderName>>/g,  senderName  || '[[senderName: not configured]]')
          .replace(/<<bookingLink>>/g, bookingLink || '');
        draftText   = resolved;
        draftSource = 'ai_supervised';
      } else {
'@).Replace("`r`n", "`n")

$new_8D = (@'
          .replace(/<<senderName>>/g,  senderName  || '')
          .replace(/<<bookingLink>>/g, bookingLink || '');
        draftText   = resolved;
        draftSource = 'ai_supervised';
        if (senderName) {
          const _lastLine = draftText.trim().split(/\n+/).pop().trim();
          if (_lastLine !== senderName) draftText = draftText.trimEnd() + '\n\n' + senderName;
        }
      } else {
'@).Replace("`r`n", "`n")

if (-not $patchedDec.Contains($old_8D)) {
    Write-Error "8D: AI draft senderName replace block not found in Decision D."; exit 1
}
$patchedDec = $patchedDec.Replace($old_8D, $new_8D)
Write-Host "  8D APPLIED (AI draft senderName replace + signature append) delta=$(($new_8D.Length - $old_8D.Length))"

Write-Host "PATCHED_DECISION_D_LEN=$($patchedDec.Length)"

# ── STEP 9: PATCH HA NODE D (1 change) ────────────────────────────────────────
Write-Host "`n=== PATCHING HA NODE D ==="

$old_9A = (@'
  lines.push("Category: " + (ctx.category || rc.category || "UNKNOWN") + " | Urgency: " + (ctx.urgency || rc.urgency || "routine"));
  // HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT_INTENT
  lines.push("Micro intent: " + (ctx.micro_intent || rc.micro_intent || "N/A"));
'@).Replace("`r`n", "`n")

$new_9A = (@'
  lines.push("Classification: " + (ctx.micro_intent || rc.micro_intent || "N/A"));
  // HMZ_INJECT_BEGIN:SL_PATCH_3_1_CHAT_INTENT
  lines.push("Broad category: " + (ctx.category || rc.category || "UNKNOWN") + " | Urgency: " + (ctx.urgency || rc.urgency || "routine"));
'@).Replace("`r`n", "`n")

if (-not $codeHA.Contains($old_9A)) {
    Write-Error "9A: Category/Micro-intent block not found in HA Node D."; exit 1
}
$patchedHA = $codeHA.Replace($old_9A, $new_9A)
Write-Host "  9A APPLIED (Classification primary, Broad category secondary)"
Write-Host "PATCHED_HA_D_LEN=$($patchedHA.Length)"

# ── STEP 10: PRE-CHECKS ────────────────────────────────────────────────────────
Write-Host "`n=== PRE-CHECKS ==="
$script:structuralPass = $true
$script:passCount      = 0
$script:totalCount     = 0

function Check-Item {
    param([string]$Name, [bool]$Pass, [bool]$IsWarning = $false)
    $script:totalCount++
    if ($Pass) {
        $script:passCount++
        Write-Host "  [PASS] $Name"
    } elseif ($IsWarning) {
        Write-Host "  [WARN] $Name"
    } else {
        $script:structuralPass = $false
        Write-Host "  [FAIL] $Name"
    }
}

# Decision D structural checks
Check-Item 'dec_no_bare_fetch_for_openai'        ($patchedDec -notmatch 'const _fetchPromise\s*=\s*fetch\(')
Check-Item 'dec_helpers_httpRequest_present'     ($patchedDec -match '\$helpers\.httpRequest\(')
Check-Item 'dec_promise_race_present'            ($patchedDec -match 'Promise\.race\(')
Check-Item 'dec_no_AbortController'              ($patchedDec -notmatch 'new AbortController\(\)')
Check-Item 'dec_openai_endpoint_present'         ($patchedDec -match 'api\.openai\.com/v1/responses')
Check-Item 'dec_OPENAI_API_KEY_present'          ($patchedDec -match 'OPENAI_API_KEY')
Check-Item 'dec_gpt5mini_present'                ($patchedDec -match "'gpt-5-mini'")
Check-Item 'dec_ai_supervised_present'           ($patchedDec -match "'ai_supervised'")
Check-Item 'dec_ai_failed_fallback_present'      ($patchedDec -match "'ai_failed_fallback'")
Check-Item 'dec_input_spread_present'            ($patchedDec -match '\.\.\.input')
Check-Item 'dec_senderName_resolution_added'     ($patchedDec -match 'to_address_json\[0\]')
Check-Item 'dec_senderName_placeholder_gone'     ($patchedDec -notmatch '\[\[senderName: not configured\]\]')
Check-Item 'dec_signature_append_logic_present'  ($patchedDec -match '_lastLine.*senderName')
# HA Node D structural checks
Check-Item 'ha_classification_primary_present'   ($patchedHA -match '"Classification: "')
Check-Item 'ha_broad_category_present'           ($patchedHA -match '"Broad category: "')
Check-Item 'ha_micro_intent_line_removed'        ($patchedHA -notmatch '"Micro intent: "')
Check-Item 'ha_review_url_present'               ($patchedHA -match 'reviewUrl')
Check-Item 'ha_from_line_present'                ($patchedHA -match '"From: "')
Check-Item 'ha_sender_line_present'              ($patchedHA -match '"Sender: "')
Check-Item 'ha_draft_policy_present'             ($patchedHA -match '"Draft policy: "')
Check-Item 'ha_draft_source_present'             ($patchedHA -match '"Draft source: "')
Check-Item 'ha_reply_excerpt_present'            ($patchedHA -match '"Reply excerpt: "')
# HTTP helper proof (warning — not a structural failure but blocks apply)
Check-Item 'http_helper_proven_in_live_env'      $httpHelperFound -IsWarning:(-not $httpHelperFound)

Write-Host ""
Write-Host "STRUCTURAL_CHECKS: $(if ($script:structuralPass){'PASS'}else{'FAIL'}) ($($script:passCount)/$($script:totalCount))"
Write-Host "HTTP_HELPER_PROVEN: $(if ($httpHelperFound){'YES'}else{'NO'})"

$safeToApply = $script:structuralPass -and $httpHelperFound
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
    if ($httpHelperFound) {
        Write-Host "`nWHATIF_RESULT: WHATIF_OK"
        Write-Host "SAFE_TO_APPLY: YES"
    } else {
        Write-Host "`nWHATIF_RESULT: STRUCTURAL_OK_HTTP_HELPER_UNPROVEN"
        Write-Host "SAFE_TO_APPLY: NO"
        Write-Host "BLOCKER: `$helpers.httpRequest not found in any live Code node."
        Write-Host "  To unblock: verify `$helpers.httpRequest works in a test Code node"
        Write-Host "  on this n8n instance, then confirm to proceed."
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
    Write-Error "SAFE_TO_APPLY is NO (HTTP helper unproven). Run WhatIf first and resolve blocker."; exit 1
}

Write-Host "`n=== APPLYING PATCH ==="

# Apply Decision D patch
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

# Verify Decision D
Write-Host "Verifying Decision post-PUT..."
$verDec  = Invoke-Prod 'GET' "/workflows/$WF_DECISION"
$vDec    = $verDec.nodes | Where-Object { $_.name -eq $NODE_D_DEC }
$vDecCp  = if ($vDec.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vDecCode = $vDec.parameters.$vDecCp

$postDecPass = $true
$postDecChecks = [ordered]@{
    'live_dec_no_bare_fetch'        = ($vDecCode -notmatch 'const _fetchPromise\s*=\s*fetch\(')
    'live_dec_helpers_httpRequest'  = ($vDecCode -match '\$helpers\.httpRequest\(')
    'live_dec_promise_race'         = ($vDecCode -match 'Promise\.race\(')
    'live_dec_openai_endpoint'      = ($vDecCode -match 'api\.openai\.com/v1/responses')
    'live_dec_OPENAI_API_KEY'       = ($vDecCode -match 'OPENAI_API_KEY')
    'live_dec_senderName_resolution'= ($vDecCode -match 'to_address_json\[0\]')
    'live_dec_placeholder_gone'     = ($vDecCode -notmatch '\[\[senderName: not configured\]\]')
}
foreach ($k in $postDecChecks.Keys) {
    $v = $postDecChecks[$k]
    $sym = if ($v) { 'PASS' } else { $postDecPass = $false; 'FAIL' }
    Write-Host "  [$sym] $k"
}
if (-not $postDecPass) {
    Write-Error "POST-PATCH Decision verification FAILED. Investigate immediately."; exit 1
}

if ($verDec.active -ne $true) {
    Invoke-Prod 'POST' "/workflows/$WF_DECISION/activate" | Out-Null
    Write-Host "DECISION_ACTIVATED=YES"
} else {
    Write-Host "DECISION_ACTIVE=YES"
}

# Apply HumanApproval D patch
$nodeDHA.parameters.$cpHA = $patchedHA
$putHABody = [ordered]@{
    name        = $haWfFull.name
    nodes       = $haWfFull.nodes
    connections = $haWfFull.connections
    settings    = $haWfFull.settings
}
if ($null -ne $haWfFull.staticData) { $putHABody['staticData'] = $haWfFull.staticData }
if ($null -ne $haWfFull.pinData)    { $putHABody['pinData']    = $haWfFull.pinData }

Write-Host "Uploading patched HumanApproval workflow..."
$putHAR = Invoke-Prod 'PUT' "/workflows/$WF_HA" $putHABody
Write-Host "PUT_HA_OK id=$($putHAR.id) name='$($putHAR.name)'"

# Verify HA D
Write-Host "Verifying HumanApproval post-PUT..."
$verHA   = Invoke-Prod 'GET' "/workflows/$WF_HA"
$vHA     = $verHA.nodes | Where-Object { $_.name -eq $NODE_D_HA }
$vHACp   = if ($vHA.parameters.PSObject.Properties.Name -contains 'jsCode') { 'jsCode' } else { 'code' }
$vHACode = $vHA.parameters.$vHACp

$postHAPass = $true
$postHAChecks = [ordered]@{
    'live_ha_classification_present' = ($vHACode -match '"Classification: "')
    'live_ha_broad_category_present' = ($vHACode -match '"Broad category: "')
    'live_ha_micro_intent_removed'   = ($vHACode -notmatch '"Micro intent: "')
    'live_ha_review_url_present'     = ($vHACode -match 'reviewUrl')
}
foreach ($k in $postHAChecks.Keys) {
    $v = $postHAChecks[$k]
    $sym = if ($v) { 'PASS' } else { $postHAPass = $false; 'FAIL' }
    Write-Host "  [$sym] $k"
}
if (-not $postHAPass) {
    Write-Error "POST-PATCH HumanApproval verification FAILED. Investigate immediately."; exit 1
}

if ($verHA.active -ne $true) {
    Invoke-Prod 'POST' "/workflows/$WF_HA/activate" | Out-Null
    Write-Host "HA_ACTIVATED=YES"
} else {
    Write-Host "HA_ACTIVE=YES"
}

# FTH post-check
$fthPost = Invoke-Prod 'GET' "/workflows/$WF_FTH"
if ($fthPost.active -eq $true) {
    Write-Error "POST-PATCH: Full Test Harness is ACTIVE — unexpected. Review immediately."; exit 1
}
Write-Host "FTH_STILL_INACTIVE=YES"

Write-Host "`nPATCH_APPLIED_AND_VERIFIED"
Write-Host "API_CALLS_USED=$($script:Calls)"
