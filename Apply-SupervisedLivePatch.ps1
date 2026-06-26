#Requires -Version 7
<#
.SYNOPSIS
  HMZ Instantly Responder — Supervised-Live Production Patch
  Patch ID : SL-PATCH-1.0
  Date     : 2026-06-20

.DESCRIPTION
  Patches 6 production n8n workflows from DRY_RUN/VALIDATION mode to
  supervised-live mode. Applies 5 targeted code-level corrections, then
  activates workflows in dependency order. Full Test Harness stays inactive.

  WHAT THIS SCRIPT DOES
    Patch 1  Global config  — DRY_RUN false, transmission_disabled false,
                               external_actions_mocked false,
                               LIVE_CREDENTIAL_READY true,
                               operating_mode SUPERVISED_LIVE,
                               LIVE_CAMPAIGNS = [531e64ed-...] only
    Patch 2  Intake C2      — flat HTML body string hydration fallback
    Patch 3  DE B node      — classifier v8: flat body, INFORMATION_REQUEST,
                               v8_hydration_applied
    Patch 4  DE E node      — remove over-broad results_claim blocker only
    Patch 5  HA A node      — replace stale campaign ID
    G check  Intake G       — static detection only; no blind patch

  WHAT THIS SCRIPT DOES NOT DO
    - Does not approve any review case
    - Does not send any Instantly reply
    - Does not enable all campaigns globally
    - Does not activate Full Test Harness
    - Does not alter human-approval gates

  SAFETY
    Run with -WhatIf first. All 7 workflows are backed up before any change.
    Every targeted replacement reports PATCHED / ALREADY_PATCHED / NOT_FOUND.
    Activation is gated behind a confirmation prompt (bypass with -Force).

.PARAMETER WhatIf
  Audit-only mode. Fetches and inspects all workflows, prints what would change,
  writes backups, but applies no patches and does not activate.

.PARAMETER Force
  Skip interactive activation confirmation. Use only in CI or after reviewing
  the -WhatIf output.

.EXAMPLE
  # Step 1 — audit first
  $env:HMZ_N8N_API_KEY = '<your-key>'
  .\Apply-SupervisedLivePatch.ps1 -WhatIf

  # Step 2 — apply patches + activate
  .\Apply-SupervisedLivePatch.ps1
#>
param(
    [switch]$WhatIf,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── CONSTANTS ─────────────────────────────────────────────────────────────────

$N8N_BASE     = 'https://n8n.hmzaiautomation.com/api/v1'
$CAMPAIGN_ID  = '531e64ed-c225-4baf-97a9-4ec90dc34eb0'
$STALE_CID    = 'bcda01f7-21c9-4e12-9849-0a375b548467'

$WF = [ordered]@{
    Intake          = 'VtDQqw02Ux1TgjIH'
    DecisionEngine  = 'tgYmY97CG4Bm8snI'
    HumanApproval   = '9aPrt92jFhoYFxbs'
    Sender          = 'ePS5uBBxKxhFCYgU'
    ErrorHandler    = '2PR9YEkG4KyGdowa'
    SLAWatchdog     = '6a8ojyXCwMwI9nyF'
    FullTestHarness = 'RLUcJHQJPvLhw4mG'
}

# Activation order — Full Test Harness intentionally excluded
$ACT_ORDER = 'Sender', 'DecisionEngine', 'HumanApproval', 'ErrorHandler', 'SLAWatchdog', 'Intake'

$PRODUCTION_WFS = 'Intake', 'DecisionEngine', 'HumanApproval', 'Sender', 'ErrorHandler', 'SLAWatchdog'

# ── PRE-FLIGHT ────────────────────────────────────────────────────────────────

$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) {
    Write-Error 'HMZ_N8N_API_KEY environment variable is not set. Aborting.'
    exit 1
}

$HDR = @{
    'X-N8N-API-KEY' = $API_KEY
    'Content-Type'  = 'application/json'
    'Accept'        = 'application/json'
}

Write-Host "`n── SL-PATCH-1.0  HMZ Supervised-Live Production Patch ──" -ForegroundColor Cyan
if ($WhatIf) { Write-Host '  MODE: WhatIf (audit only — no changes will be applied)' -ForegroundColor Yellow }

# Health check
Write-Host "`nPre-flight: checking n8n API..." -NoNewline
try {
    $health = Invoke-RestMethod -Uri "$N8N_BASE/workflows?limit=1" -Headers $HDR -Method GET
    Write-Host ' OK' -ForegroundColor Green
} catch {
    Write-Error "n8n API unreachable at $N8N_BASE — $_"
    exit 1
}

# ── AUDIT RECORD ──────────────────────────────────────────────────────────────

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

$audit = [ordered]@{
    patch_id                  = 'SL-PATCH-1.0'
    generated_at              = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    whatif                    = $WhatIf.IsPresent
    backup_dir                = ''
    changed_workflows         = [System.Collections.Generic.List[string]]::new()
    changed_nodes             = [System.Collections.Generic.List[string]]::new()
    dry_run_false_audit       = [ordered]@{}
    live_cred_ready_audit     = [ordered]@{}
    campaign_allowlist_audit  = [ordered]@{}
    hydration_flat_body_audit = 'NOT_CHECKED'
    classifier_v8_audit       = 'NOT_CHECKED'
    result_blocker_audit      = 'NOT_CHECKED'
    stale_campaign_id_audit   = 'NOT_CHECKED'
    g_handoff_audit           = 'NOT_CHECKED'
    activation_summary        = [ordered]@{}
    test_harness_inactive     = 'NOT_VERIFIED'
    warnings                  = [System.Collections.Generic.List[string]]::new()
    errors                    = [System.Collections.Generic.List[string]]::new()
}

# ── HELPERS ───────────────────────────────────────────────────────────────────

function Invoke-Get([string]$id) {
    return Invoke-RestMethod -Uri "$N8N_BASE/workflows/$id" -Headers $HDR -Method GET
}

function Invoke-Put([string]$id, [pscustomobject]$wfObj) {
    if ($WhatIf) {
        Write-Host "    [WhatIf] Would PUT workflow $id" -ForegroundColor Yellow
        return $wfObj
    }
    $json = $wfObj | ConvertTo-Json -Depth 30
    return Invoke-RestMethod -Uri "$N8N_BASE/workflows/$id" -Headers $HDR -Method PUT -Body $json
}

function Invoke-Activate([string]$id, [bool]$activate) {
    $ep = if ($activate) { 'activate' } else { 'deactivate' }
    if ($WhatIf) {
        Write-Host "    [WhatIf] Would POST $ep for $id" -ForegroundColor Yellow
        return
    }
    Invoke-RestMethod -Uri "$N8N_BASE/workflows/$id/$ep" -Headers $HDR -Method POST | Out-Null
}

function Get-CodeParam([pscustomobject]$node) {
    if ($null -ne $node.parameters.jsCode)       { return 'jsCode' }
    if ($null -ne $node.parameters.functionCode) { return 'functionCode' }
    return $null
}

# Apply one targeted regex replacement to JS code.
# Returns @{ Code = <new or original>; Status = 'PATCHED' | 'ALREADY_PATCHED' | 'NOT_FOUND' }
function Invoke-CodeReplace {
    param(
        [string]$Code,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Label,
        [string]$AlreadyPatchedCheck = ''
    )

    if ($AlreadyPatchedCheck -and ($Code -match $AlreadyPatchedCheck)) {
        return @{ Code = $Code; Status = "ALREADY_PATCHED:$Label" }
    }
    if ($Code -match $Pattern) {
        $opts  = [System.Text.RegularExpressions.RegexOptions]::Singleline
        $after = [regex]::Replace($Code, $Pattern, $Replacement, $opts)
        if ($after -eq $Code) {
            return @{ Code = $Code; Status = "REPLACE_NO_DIFF:$Label" }
        }
        return @{ Code = $after; Status = "PATCHED:$Label" }
    }
    return @{ Code = $Code; Status = "NOT_FOUND:$Label" }
}

# ── PHASE 0 — BACKUP ──────────────────────────────────────────────────────────

Write-Host "`n=== PHASE 0: BACKUP ===" -ForegroundColor Cyan

$backupDir = "backups/sl-patch-$ts"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$audit.backup_dir = $backupDir
Write-Host "  Directory: $backupDir"

$cache = [ordered]@{}
foreach ($key in $WF.Keys) {
    $id = $WF[$key]
    Write-Host "  Fetching $key ($id)..."
    try {
        $obj = Invoke-Get $id
        $cache[$key] = $obj
        $obj | ConvertTo-Json -Depth 30 | Out-File "$backupDir/${key}_${id}_backup.json" -Encoding utf8
    } catch {
        Write-Error "Failed to fetch $key ($id): $_"
        exit 1
    }
}
Write-Host "  All 7 workflows backed up." -ForegroundColor Green

# ── PHASE 1 — GLOBAL CONFIG PATCH ────────────────────────────────────────────

Write-Host "`n=== PHASE 1: GLOBAL CONFIG (all production workflows) ===" -ForegroundColor Cyan

# Each entry: Pattern (regex), Replacement, Label, AlreadyCheck
# Using capture-group style to avoid variable-length lookbehind edge cases.
$CONFIG_RULES = @(
    @{
        P = '((?:dry_run|DRY_RUN)\s*:\s*)true'
        R = '${1}false'
        L = 'dry_run_false'
        A = '(?:dry_run|DRY_RUN)\s*:\s*false'
    }
    @{
        P = '(transmission_disabled\s*:\s*)true'
        R = '${1}false'
        L = 'transmission_disabled_false'
        A = 'transmission_disabled\s*:\s*false'
    }
    @{
        P = '(external_actions_mocked\s*:\s*)true'
        R = '${1}false'
        L = 'external_actions_mocked_false'
        A = 'external_actions_mocked\s*:\s*false'
    }
    @{
        P = '(LIVE_CREDENTIAL_READY\s*:\s*)false'
        R = '${1}true'
        L = 'LIVE_CREDENTIAL_READY_true'
        A = 'LIVE_CREDENTIAL_READY\s*:\s*true'
    }
    @{
        P = "(operating_mode\s*:\s*[`"'])VALIDATION([`"'])"
        R = '${1}SUPERVISED_LIVE${2}'
        L = 'operating_mode_SUPERVISED_LIVE'
        A = "operating_mode\s*:\s*[`"']SUPERVISED_LIVE"
    }
    @{
        P = "(OPERATING_MODE\s*:\s*[`"'])VALIDATION([`"'])"
        R = '${1}SUPERVISED_LIVE${2}'
        L = 'OPERATING_MODE_SUPERVISED_LIVE'
        A = "OPERATING_MODE\s*:\s*[`"']SUPERVISED_LIVE"
    }
    @{
        # Replace ENTIRE live_campaigns array (empty or non-empty) with single target campaign.
        # Handles single-line arrays; (?s) handles multi-line in Invoke-CodeReplace.
        P = "(?i)(live_campaigns\s*:\s*)\[[^\]]*\]"
        R = "`${1}['$CAMPAIGN_ID']"
        L = 'live_campaigns_set'
        A = [regex]::Escape($CAMPAIGN_ID)
    }
    @{
        P = "(?i)(LIVE_CAMPAIGNS\s*:\s*)\[[^\]]*\]"
        R = "`${1}['$CAMPAIGN_ID']"
        L = 'LIVE_CAMPAIGNS_set'
        A = [regex]::Escape($CAMPAIGN_ID)
    }
)

foreach ($wfKey in $PRODUCTION_WFS) {
    Write-Host "`n  [$wfKey]"
    $wfObj     = $cache[$wfKey]
    $wfDirty   = $false
    $dryAudit  = [System.Collections.Generic.List[string]]::new()
    $credAudit = [System.Collections.Generic.List[string]]::new()
    $campAudit = [System.Collections.Generic.List[string]]::new()

    foreach ($node in $wfObj.nodes) {
        $cp = Get-CodeParam $node
        if (-not $cp) { continue }

        $code     = $node.parameters.$cp
        $nodeDirt = $false

        foreach ($rule in $CONFIG_RULES) {
            $r = Invoke-CodeReplace -Code $code -Pattern $rule.P -Replacement $rule.R `
                                    -Label $rule.L -AlreadyPatchedCheck $rule.A
            if ($r.Status -like 'PATCHED:*') {
                $code     = $r.Code
                $nodeDirt = $true
                Write-Host "    $($node.name): $($r.Status)"
                $audit.changed_nodes.Add("$wfKey/$($node.name)/$($r.Status)")
            } elseif ($r.Status -notlike 'NOT_FOUND:*' -and $r.Status -notlike 'ALREADY_PATCHED:*') {
                $audit.warnings.Add("$wfKey/$($node.name): $($r.Status)")
            }
        }

        if ($nodeDirt) {
            $node.parameters.$cp = $code
            $wfDirty = $true
        }

        # Audit state after patching
        if ($code -match '(?:dry_run|DRY_RUN)\s*:\s*true') {
            $dryAudit.Add("STILL_TRUE:$($node.name)")
        } elseif ($code -match '(?:dry_run|DRY_RUN)') {
            $dryAudit.Add("OK:$($node.name)")
        }
        if ($code -match 'LIVE_CREDENTIAL_READY\s*:\s*false') {
            $credAudit.Add("STILL_FALSE:$($node.name)")
        } elseif ($code -match 'LIVE_CREDENTIAL_READY') {
            $credAudit.Add("OK:$($node.name)")
        }
        if ($code -match '(?i)live_campaigns') {
            if ($code -match [regex]::Escape($CAMPAIGN_ID)) {
                $campAudit.Add("TARGET_CAMPAIGN_PRESENT:$($node.name)")
            } else {
                $campAudit.Add("TARGET_CAMPAIGN_MISSING:$($node.name)")
                $audit.warnings.Add("$wfKey/$($node.name): live_campaigns present but target campaign not found after patch")
            }
        }
    }

    $audit.dry_run_false_audit[$wfKey]      = ($dryAudit.Count -gt 0) ? ($dryAudit -join ' | ') : 'NO_CONFIG_NODE'
    $audit.live_cred_ready_audit[$wfKey]    = ($credAudit.Count -gt 0) ? ($credAudit -join ' | ') : 'NO_CONFIG_NODE'
    $audit.campaign_allowlist_audit[$wfKey] = ($campAudit.Count -gt 0) ? ($campAudit -join ' | ') : 'NO_CONFIG_NODE'

    if ($wfDirty) {
        Write-Host "    -> Uploading $wfKey..."
        try {
            Invoke-Put $WF[$wfKey] $wfObj | Out-Null
            $audit.changed_workflows.Add($wfKey)
            if (-not $WhatIf) { $cache[$wfKey] = Invoke-Get $WF[$wfKey] }
        } catch {
            $msg = "PUT failed for $wfKey : $_"
            $audit.errors.Add($msg)
            Write-Host "    ERROR: $msg" -ForegroundColor Red
        }
    } else {
        Write-Host "    -> No config changes needed."
    }
}

# ── PHASE 2 — INTAKE C2: FLAT BODY HYDRATION ─────────────────────────────────

Write-Host "`n=== PHASE 2: INTAKE C2 — FLAT BODY STRING HYDRATION ===" -ForegroundColor Cyan

$intake      = $cache['Intake']
$c2Changed   = $false
$c2Status    = 'NODE_NOT_FOUND'

foreach ($node in $intake.nodes) {
    $cp = Get-CodeParam $node
    if (-not $cp) { continue }
    $code = $node.parameters.$cp

    # Identify C2 node: handles reply_text AND references hydration or email_id
    $isC2 = ($node.name -match 'C2|[Hh]ydrat') -or
             (($code -match 'reply_text') -and ($code -match 'hydrat|email_id|email\.body'))
    if (-not $isC2) { continue }

    Write-Host "  Candidate C2 node: '$($node.name)'"

    # Already patched?
    if ($code -match "typeof\s+email\.body\s*===\s*[`"']string[`"']") {
        $c2Status = "ALREADY_PATCHED: flat body string check present in '$($node.name)'"
        Write-Host "  -> $c2Status" -ForegroundColor Green
        break
    }

    # Patch: inject flat body fallback after the first replyText / reply_text assignment.
    # Anchor on: let/const/var replyText = ...; OR reply_text = ...;
    $anchor = '((const|let|var)\s+reply[_]?[Tt]ext\s*=[^;\n]+;)'
    if ($code -notmatch $anchor) {
        # Broader anchor: any assignment from webhook.reply_text or event.reply_text
        $anchor = '([\w.]+\.reply_text[^;\n]*;)'
    }

    $flatBodyCode = @'

  // SL-PATCH-1.0 C2: Instantly v2 flat HTML body string fallback
  if (!replyText && email && typeof email.body === 'string' && email.body.trim()) {
    replyText = email.body
      .replace(/<[^>]+>/g, ' ')
      .replace(/&(?:amp|lt|gt|quot|#\d+);/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (typeof hydrationSource !== 'undefined') hydrationSource = 'flat_body_string';
  }
'@

    $r = Invoke-CodeReplace -Code $code -Pattern $anchor `
             -Replacement "`$1$flatBodyCode" -Label 'C2_FLAT_BODY'
    if ($r.Status -like 'PATCHED:*') {
        $node.parameters.$cp = $r.Code
        $c2Changed = $true
        $c2Status  = "PATCHED: flat body string fallback injected in '$($node.name)'"
        $audit.changed_nodes.Add("Intake/$($node.name)/C2_FLAT_BODY")
    } else {
        $c2Status = "NOT_FOUND: no replyText assignment anchor in '$($node.name)' — manual inspection required"
        $audit.warnings.Add("C2 hydration: $c2Status")
    }
    Write-Host "  -> $c2Status"
    break
}

$audit.hydration_flat_body_audit = $c2Status

if ($c2Changed) {
    Write-Host "  -> Uploading patched Intake..."
    try {
        Invoke-Put $WF['Intake'] $intake | Out-Null
        if (-not $audit.changed_workflows.Contains('Intake')) { $audit.changed_workflows.Add('Intake') }
        if (-not $WhatIf) { $cache['Intake'] = Invoke-Get $WF['Intake'] }
    } catch {
        $audit.errors.Add("PUT failed for Intake (C2): $_")
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

# ── PHASE 3 — DECISION ENGINE B: CLASSIFIER V8 ───────────────────────────────

Write-Host "`n=== PHASE 3: DECISION ENGINE B — CLASSIFIER V8 ===" -ForegroundColor Cyan

$de        = $cache['DecisionEngine']
$deChanged = $false
$bStatuses = [System.Collections.Generic.List[string]]::new()
$bNode     = $null

foreach ($node in $de.nodes) {
    $cp = Get-CodeParam $node
    if (-not $cp) { continue }
    $code = $node.parameters.$cp
    $isB  = ($node.name -match '^B\.|[Cc]lassif') -or ($code -match 'classifier_version|deterministic')
    if (-not $isB) { continue }
    Write-Host "  Candidate B node: '$($node.name)'"
    $bNode = $node
    break
}

if ($bNode) {
    $cp   = Get-CodeParam $bNode
    $code = $bNode.parameters.$cp

    # 3a. Bump classifier_version to v8
    $r3a = Invoke-CodeReplace -Code $code `
        -Pattern "(classifier_version\s*:\s*[`"']deterministic-heuristic-1\.0)(?:-v\d+)?([`"'])" `
        -Replacement '${1}-v8${2}' -Label 'VERSION_V8' `
        -AlreadyPatchedCheck 'deterministic-heuristic-1\.0-v8'
    if ($r3a.Status -like 'PATCHED:*') { $code = $r3a.Code; $deChanged = $true }
    $bStatuses.Add($r3a.Status)

    # 3b. Add v8_hydration_applied: true alongside classifier_version (if absent)
    if ($code -notmatch 'v8_hydration_applied') {
        $r3b = Invoke-CodeReplace -Code $code `
            -Pattern '(classifier_version\s*:[^,\n\r}]+)' `
            -Replacement '${1}, v8_hydration_applied: true' -Label 'V8_HYDRATION_APPLIED'
        if ($r3b.Status -like 'PATCHED:*') { $code = $r3b.Code; $deChanged = $true }
        $bStatuses.Add($r3b.Status)
    } else {
        $bStatuses.Add('ALREADY_PRESENT:v8_hydration_applied')
    }

    # 3c. Flat body fallback for classifier text input (when inputText/text is empty)
    if ($code -notmatch "typeof\s+(?:body|email\.body)\s*===\s*[`"']string[`"']") {
        # Anchor: first text variable assignment in the classifier
        $r3c = Invoke-CodeReplace -Code $code `
            -Pattern '((const|let|var)\s+(inputText|classifyText|rawText|bodyText|text)\s*=[^;\n]+;)' `
            -Replacement ('${1}' + "`n  // v8 flat body fallback`n  if (!`${3} && typeof body === 'string') { `${3} = body.replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').trim(); }") `
            -Label 'B_FLAT_BODY_FALLBACK'
        if ($r3c.Status -like 'PATCHED:*') { $code = $r3c.Code; $deChanged = $true }
        elseif ($r3c.Status -like 'NOT_FOUND:*') {
            $audit.warnings.Add("B classifier: flat body fallback anchor not found in '$($bNode.name)'. Manual review required.")
        }
        $bStatuses.Add($r3c.Status)
    } else {
        $bStatuses.Add('ALREADY_PRESENT:flat_body_fallback')
    }

    # 3d. Ensure "this is interesting / how would it work" → INFORMATION_REQUEST, not UNKNOWN
    $interestPattern = '(?:this is interesting|how would it work|sounds interesting|tell me more|curious about)'
    if ($code -match $interestPattern) {
        # Phrase already in code — check if it's mapped to a positive type
        if ($code -notmatch "INFORMATION_REQUEST|POSITIVE_CURIOSITY|positive_inquiry") {
            $audit.warnings.Add("B classifier: positive curiosity phrase detected but no INFORMATION_REQUEST mapping found. Manual review of '$($bNode.name)' required.")
            $bStatuses.Add("WARNING:interest_phrase_needs_INFORMATION_REQUEST_mapping")
        } else {
            $bStatuses.Add('ALREADY_MAPPED:INFORMATION_REQUEST')
        }
    } else {
        # Inject INFORMATION_REQUEST guard before the UNKNOWN fallback
        $r3d = Invoke-CodeReplace -Code $code `
            -Pattern "(//\s*[Dd]efault[^\n]*\n\s*(?:return\s+\{[^}]*type\s*:\s*[`"']UNKNOWN[`"']|(?:type|classification)\s*=\s*[`"']UNKNOWN[`"']))" `
            -Replacement ("// v8: positive curiosity guard`n  if (/(?:this is interesting|how would it work|sounds interesting|tell me more)/i.test(inputText || text || '')) {`n    return { type: 'INFORMATION_REQUEST', confidence: 0.82, classifier_version: 'deterministic-heuristic-1.0-v8', v8_hydration_applied: true };`n  }`n  " + '${1}') `
            -Label 'IR_GUARD_BEFORE_UNKNOWN'
        if ($r3d.Status -like 'PATCHED:*') { $code = $r3d.Code; $deChanged = $true }
        elseif ($r3d.Status -like 'NOT_FOUND:*') {
            $audit.warnings.Add("B classifier: UNKNOWN fallback anchor not found for IR guard injection. Manual mapping required in '$($bNode.name)'.")
        }
        $bStatuses.Add($r3d.Status)
    }

    if ($deChanged) { $bNode.parameters.$cp = $code }

    foreach ($s in $bStatuses) { $audit.changed_nodes.Add("DecisionEngine/$($bNode.name)/$s") }
    $classifierResult = $bStatuses -join ' | '
} else {
    $classifierResult = 'NODE_NOT_FOUND: no B/classifier node identified in Decision Engine'
    $audit.warnings.Add($classifierResult)
}

Write-Host "  -> $classifierResult"
$audit.classifier_v8_audit = $classifierResult

# ── PHASE 4 — DECISION ENGINE E: REMOVE RESULTS CLAIM BLOCKER ────────────────

Write-Host "`n=== PHASE 4: DECISION ENGINE E — RESULTS CLAIM BLOCKER ===" -ForegroundColor Cyan

$eStatus = 'NODE_NOT_FOUND'

foreach ($node in $de.nodes) {
    $cp = Get-CodeParam $node
    if (-not $cp) { continue }
    $code  = $node.parameters.$cp
    $isE   = ($node.name -match '^E\.|[Oo]utput.?[Vv]al|[Dd]raft.?[Vv]al') -or
             ($code -match 'results_claim|result_claim')
    if (-not $isE) { continue }
    Write-Host "  Candidate E node: '$($node.name)'"

    # Remove ONLY the results_claim-labelled block.
    # Safety: we do NOT remove fake_case_study, guarantee, or unsafe_claim checks.
    # Pattern: a comment+if block whose body assigns/pushes 'results_claim' or 'result_claim'
    $r4 = Invoke-CodeReplace -Code $code `
        -Pattern '(?ms)(?:[ \t]*//[^\n]*(?:result|proof)[^\n]*\n)?[ \t]*if\s*\([^{]{1,200}\)\s*\{[^}]{0,400}(?:results_claim|result_claim)[^}]{0,200}\}[ \t]*\n?' `
        -Replacement '' -Label 'RESULTS_CLAIM_BLOCK'

    if ($r4.Status -like 'PATCHED:*') {
        $node.parameters.$cp = $r4.Code
        $deChanged = $true
        $eStatus   = "PATCHED: results_claim blocker removed from '$($node.name)'"
        $audit.changed_nodes.Add("DecisionEngine/$($node.name)/RESULTS_CLAIM_REMOVED")
    } elseif ($r4.Status -like 'NOT_FOUND:*') {
        # Fallback: look for broad proof/result regex used as disqualifier
        $r4b = Invoke-CodeReplace -Code $code `
            -Pattern '(?ms)(?:[ \t]*//[^\n]*\n)?[ \t]*(const|let|var)\s+\w+\s*=\s*/[^/\n]*\b(?:proven|established|results?)\b[^/\n]*/[gimsuy]*\s*;\s*\n[ \t]*if\s*\(\w+\.test\([^)]+\)\s*\)\s*\{[^}]{0,300}block[^}]{0,200}\}[ \t]*\n?' `
            -Replacement '' -Label 'PROOF_REGEX_BLOCKER'
        if ($r4b.Status -like 'PATCHED:*') {
            $node.parameters.$cp = $r4b.Code
            $deChanged = $true
            $eStatus   = "PATCHED (fallback pattern): results/proof regex blocker removed from '$($node.name)'"
            $audit.changed_nodes.Add("DecisionEngine/$($node.name)/PROOF_BLOCKER_REMOVED")
        } else {
            $eStatus = "NOT_FOUND: no results_claim blocker matched in '$($node.name)' — manual inspection required"
            $audit.warnings.Add("E output validator: $eStatus")
        }
    }
    Write-Host "  -> $eStatus"
    break
}

$audit.result_blocker_audit = $eStatus

# Upload Decision Engine if changed by phases 3 or 4
if ($deChanged) {
    Write-Host "`n  -> Uploading patched DecisionEngine..."
    try {
        Invoke-Put $WF['DecisionEngine'] $de | Out-Null
        if (-not $audit.changed_workflows.Contains('DecisionEngine')) { $audit.changed_workflows.Add('DecisionEngine') }
        if (-not $WhatIf) { $cache['DecisionEngine'] = Invoke-Get $WF['DecisionEngine'] }
    } catch {
        $audit.errors.Add("PUT failed for DecisionEngine: $_")
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

# ── PHASE 5 — HUMAN APPROVAL: STALE CAMPAIGN ID ──────────────────────────────

Write-Host "`n=== PHASE 5: HUMAN APPROVAL — STALE CAMPAIGN ID ===" -ForegroundColor Cyan

$ha        = $cache['HumanApproval']
$haChanged = $false
$staleCnt  = 0

foreach ($node in $ha.nodes) {
    # Inspect code parameters
    $cp = Get-CodeParam $node
    if ($cp) {
        $code = $node.parameters.$cp
        if ($code -match [regex]::Escape($STALE_CID)) {
            $newCode = $code -replace [regex]::Escape($STALE_CID), $CAMPAIGN_ID
            if ($newCode -ne $code) {
                $node.parameters.$cp = $newCode
                $haChanged = $true
                $staleCnt++
                $audit.changed_nodes.Add("HumanApproval/$($node.name)/STALE_CAMPAIGN_REPLACED_CODE")
                Write-Host "  Replaced in code: '$($node.name)'"
            }
        }
    }

    # Inspect all other string parameters (Set, HTTP Request, etc.)
    $paramStr = $node.parameters | ConvertTo-Json -Depth 10
    if ($paramStr -match [regex]::Escape($STALE_CID)) {
        $newParamStr = $paramStr -replace [regex]::Escape($STALE_CID), $CAMPAIGN_ID
        if ($newParamStr -ne $paramStr) {
            $node.parameters = $newParamStr | ConvertFrom-Json
            $haChanged = $true
            $staleCnt++
            $audit.changed_nodes.Add("HumanApproval/$($node.name)/STALE_CAMPAIGN_REPLACED_PARAM")
            Write-Host "  Replaced in params: '$($node.name)'"
        }
    }
}

if ($staleCnt -eq 0) {
    $audit.stale_campaign_id_audit = "NOT_FOUND: $STALE_CID not present — already clean or uses different structure"
} else {
    $audit.stale_campaign_id_audit = "PATCHED: $staleCnt replacement(s) of $STALE_CID -> $CAMPAIGN_ID"
    $haChanged = $true
}
Write-Host "  -> $($audit.stale_campaign_id_audit)"

if ($haChanged) {
    Write-Host "  -> Uploading patched HumanApproval..."
    try {
        Invoke-Put $WF['HumanApproval'] $ha | Out-Null
        if (-not $audit.changed_workflows.Contains('HumanApproval')) { $audit.changed_workflows.Add('HumanApproval') }
        if (-not $WhatIf) { $cache['HumanApproval'] = Invoke-Get $WF['HumanApproval'] }
    } catch {
        $audit.errors.Add("PUT failed for HumanApproval: $_")
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

# ── PHASE 6 — INTAKE G HANDOFF: STATIC CHECK (CONDITIONAL PATCH) ─────────────

Write-Host "`n=== PHASE 6: INTAKE G HANDOFF (static check) ===" -ForegroundColor Cyan

# Reload Intake from cache (might have been updated by Phase 2)
$intake = $cache['Intake']
$gNode  = $intake.nodes | Where-Object {
    $_.name -match 'G\.|[Hh]andoff|Decision.*Engine|executeWorkflow' -or
    $_.type -match 'executeWorkflow'
} | Select-Object -First 1

if ($gNode) {
    Write-Host "  G candidate: '$($gNode.name)' (type: $($gNode.type))"

    # Static detection: defineBelow + empty value = confirmed empty input passthrough
    $mappingMode = $gNode.parameters.workflowInputs.mappingMode
    $inputValue  = $gNode.parameters.workflowInputs.value

    if ($mappingMode -eq 'defineBelow') {
        $valueJson = $inputValue | ConvertTo-Json -Compress -Depth 5
        if ($valueJson -in '{}', '[]', 'null', $null) {
            $audit.g_handoff_audit = "EMPTY_INPUT_DETECTED: G node '$($gNode.name)' has mappingMode=defineBelow with value=$valueJson. " +
                "Patch: change workflowInputs.mappingMode to 'autoMapInputData'. " +
                "Not auto-applied — confirm with one live execution trace before patching. CONDITIONAL_FOLLOW_UP."
            $audit.warnings.Add("G handoff: empty input detected statically. mappingMode='defineBelow', value=$valueJson. " +
                "Apply fix manually: set workflowInputs.mappingMode='autoMapInputData' in node '$($gNode.name)' after first live run confirms issue.")
            Write-Host "  -> WARNING: $($audit.g_handoff_audit)" -ForegroundColor Yellow
        } else {
            $audit.g_handoff_audit = "defineBelow_WITH_VALUE: G node '$($gNode.name)' has mappingMode=defineBelow with non-empty value=$valueJson. " +
                "Input may be intentionally explicit-mapped. Execution-history verification deferred."
            Write-Host "  -> $($audit.g_handoff_audit)"
        }
    } elseif ($mappingMode -eq 'autoMapInputData') {
        $audit.g_handoff_audit = "OK: G node '$($gNode.name)' uses mappingMode=autoMapInputData — passes current item to Decision Engine."
        Write-Host "  -> $($audit.g_handoff_audit)" -ForegroundColor Green
    } elseif ($mappingMode -eq 'passthrough') {
        $audit.g_handoff_audit = "OK: G node '$($gNode.name)' uses mappingMode=passthrough."
        Write-Host "  -> $($audit.g_handoff_audit)" -ForegroundColor Green
    } else {
        $audit.g_handoff_audit = "UNKNOWN_MAPPING_MODE: '$mappingMode' in '$($gNode.name)'. Execution-history verification deferred — CONDITIONAL_FOLLOW_UP."
        $audit.warnings.Add("G handoff: unrecognised mappingMode '$mappingMode'. Manual review required.")
        Write-Host "  -> $($audit.g_handoff_audit)" -ForegroundColor Yellow
    }
} else {
    $audit.g_handoff_audit = "NODE_NOT_FOUND: no executeWorkflow G node found in Intake. Manual inspection required."
    $audit.warnings.Add($audit.g_handoff_audit)
    Write-Host "  -> WARNING: $($audit.g_handoff_audit)" -ForegroundColor Yellow
}

# ── PHASE 7 — FULL TEST HARNESS: ENSURE INACTIVE ─────────────────────────────

Write-Host "`n=== PHASE 7: FULL TEST HARNESS — ENSURE INACTIVE ===" -ForegroundColor Cyan

$fth = $cache['FullTestHarness']
if ($fth.active -eq $true) {
    Write-Host "  Full Test Harness is ACTIVE — deactivating..." -ForegroundColor Yellow
    try {
        Invoke-Activate $WF['FullTestHarness'] $false
        $audit.test_harness_inactive = 'DEACTIVATED: was active, now deactivated'
    } catch {
        $audit.errors.Add("Failed to deactivate Full Test Harness: $_")
        $audit.test_harness_inactive = "DEACTIVATION_FAILED: $_"
    }
} else {
    $audit.test_harness_inactive = 'CONFIRMED_INACTIVE: was already inactive before patch'
}
Write-Host "  -> $($audit.test_harness_inactive)"

# ── PHASE 8 — ACTIVATION ─────────────────────────────────────────────────────

Write-Host "`n=== PHASE 8: ACTIVATE PRODUCTION WORKFLOWS ===" -ForegroundColor Cyan
Write-Host "  Order: $($ACT_ORDER -join ' -> ')"

if (-not $WhatIf -and -not $Force) {
    Write-Host "`n  READY TO ACTIVATE 6 PRODUCTION WORKFLOWS." -ForegroundColor Yellow
    Write-Host "  Full Test Harness will remain inactive." -ForegroundColor Yellow
    Write-Host "  Human approval gates are preserved — no auto-send." -ForegroundColor Yellow
    $confirm = Read-Host "`n  Type ACTIVATE to proceed, or press Enter to skip"
    if ($confirm -ne 'ACTIVATE') {
        Write-Host "  Activation skipped by user." -ForegroundColor Yellow
        foreach ($key in $ACT_ORDER) { $audit.activation_summary[$key] = 'SKIPPED_BY_USER' }
        $audit.warnings.Add('Activation skipped at confirmation prompt. Re-run with -Force or type ACTIVATE.')
    }
}

if ($WhatIf -or ($confirm -eq 'ACTIVATE') -or $Force) {
    foreach ($key in $ACT_ORDER) {
        Write-Host "  Activating $key ($($WF[$key]))..." -NoNewline
        try {
            Invoke-Activate $WF[$key] $true
            $audit.activation_summary[$key] = 'ACTIVATED'
            Write-Host ' OK' -ForegroundColor Green
        } catch {
            $msg = "ERROR: $_"
            $audit.activation_summary[$key] = $msg
            $audit.errors.Add("Activation failed for $key : $_")
            Write-Host " $msg" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 500
    }
}

# Final verification: confirm Full Test Harness is still inactive
if (-not $WhatIf) {
    try {
        $fthFinal = Invoke-Get $WF['FullTestHarness']
        if ($fthFinal.active -eq $true) {
            $audit.test_harness_inactive = 'CRITICAL_STILL_ACTIVE_AFTER_ACTIVATION'
            $audit.errors.Add('Full Test Harness is active after activation pass. Deactivate immediately.')
            Write-Host "`n  CRITICAL: Full Test Harness is active! Deactivating now..." -ForegroundColor Red
            Invoke-Activate $WF['FullTestHarness'] $false
        } else {
            if ($audit.test_harness_inactive -notmatch 'FAILED') {
                $audit.test_harness_inactive += ' | FINAL_CONFIRMED_INACTIVE'
            }
        }
    } catch {
        $audit.warnings.Add("Could not verify Full Test Harness state post-activation: $_")
    }
}

# ── AUDIT REPORT ──────────────────────────────────────────────────────────────

$auditPath = "$backupDir/audit-report-$ts.json"
$audit | ConvertTo-Json -Depth 10 | Out-File $auditPath -Encoding utf8

$hr = '─' * 66

Write-Host "`n`n$hr" -ForegroundColor Cyan
Write-Host "  SL-PATCH-1.0  AUDIT REPORT" -ForegroundColor Cyan
Write-Host "$hr`n" -ForegroundColor Cyan

Write-Host "BACKUP DIRECTORY   : $($audit.backup_dir)"
Write-Host "AUDIT REPORT FILE  : $auditPath"
Write-Host "CHANGED WORKFLOWS  : $(if ($audit.changed_workflows.Count -eq 0) { 'none' } else { $audit.changed_workflows -join ', ' })"
Write-Host "CHANGED NODES      : $($audit.changed_nodes.Count) node-level changes"
if ($audit.changed_nodes.Count -gt 0) {
    $audit.changed_nodes | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "`nDRY_RUN=false AUDIT :"
$audit.dry_run_false_audit.GetEnumerator() | ForEach-Object {
    $color = if ($_.Value -match 'STILL_TRUE|NO_CONFIG') { 'Yellow' } else { 'Green' }
    Write-Host "  $($_.Key.PadRight(18)) $($_.Value)" -ForegroundColor $color
}

Write-Host "`nLIVE_CREDENTIAL_READY=true AUDIT :"
$audit.live_cred_ready_audit.GetEnumerator() | ForEach-Object {
    $color = if ($_.Value -match 'STILL_FALSE|NO_CONFIG') { 'Yellow' } else { 'Green' }
    Write-Host "  $($_.Key.PadRight(18)) $($_.Value)" -ForegroundColor $color
}

Write-Host "`nCAMPAIGN ALLOWLIST AUDIT (target: $CAMPAIGN_ID) :"
$audit.campaign_allowlist_audit.GetEnumerator() | ForEach-Object {
    $color = if ($_.Value -match 'MISSING|NO_CONFIG') { 'Yellow' } else { 'Green' }
    Write-Host "  $($_.Key.PadRight(18)) $($_.Value)" -ForegroundColor $color
}

Write-Host "`nHYDRATION FLAT BODY : $($audit.hydration_flat_body_audit)"
Write-Host "CLASSIFIER V8       : $($audit.classifier_v8_audit)"
Write-Host "RESULT BLOCKER      : $($audit.result_blocker_audit)"
Write-Host "STALE CAMPAIGN ID   : $($audit.stale_campaign_id_audit)"
Write-Host "G HANDOFF CHECK     : $($audit.g_handoff_audit)"

Write-Host "`nACTIVATION SUMMARY :"
$audit.activation_summary.GetEnumerator() | ForEach-Object {
    $color = switch -Wildcard ($_.Value) {
        'ACTIVATED' { 'Green' }
        'SKIPPED*'  { 'Yellow' }
        default     { 'Red' }
    }
    Write-Host "  $($_.Key.PadRight(18)) $($_.Value)" -ForegroundColor $color
}

Write-Host "`nFULL TEST HARNESS   : $($audit.test_harness_inactive)"

if ($audit.warnings.Count -gt 0) {
    Write-Host "`nWARNINGS ($($audit.warnings.Count)) :" -ForegroundColor Yellow
    $audit.warnings | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow }
}

if ($audit.errors.Count -gt 0) {
    Write-Host "`nERRORS ($($audit.errors.Count)) :" -ForegroundColor Red
    $audit.errors | ForEach-Object { Write-Host "  x $_" -ForegroundColor Red }
}

Write-Host "`n$hr" -ForegroundColor Cyan
if ($audit.errors.Count -eq 0 -and $audit.warnings.Count -eq 0) {
    Write-Host '  PATCH COMPLETE — no errors, no warnings.' -ForegroundColor Green
} elseif ($audit.errors.Count -eq 0) {
    Write-Host "  PATCH COMPLETE WITH $($audit.warnings.Count) WARNING(S). Review before first live run." -ForegroundColor Yellow
} else {
    Write-Host "  PATCH COMPLETED WITH $($audit.errors.Count) ERROR(S). Investigate before activating." -ForegroundColor Red
}
Write-Host "$hr`n" -ForegroundColor Cyan
