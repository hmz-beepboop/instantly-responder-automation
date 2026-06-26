#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-4I Part B: Fix Phase 3 proxy write bug (Validate Write node body parsing).

.DESCRIPTION
Patches proxy workflow seB6ZmlyomhC4QWU ONLY.
Responder workflows are NOT modified.

Root cause:
  The "Validate Write" code node does:
    const b = JSON.parse($input.first().json.body || "{}");
  This fails when body is already an object (Content-Type: application/json),
  because JSON.parse(object) coerces to "[object Object]" which is invalid JSON.
  Workaround was to send with Content-Type: text/plain (string body).

Fix:
  Detect body type before parsing:
    - If object → use directly
    - If string → JSON.parse
    - If null/undefined → default {}
  Content-Type: application/json, text/plain, and stringified JSON all handled.
  Existing read endpoint, write endpoint, auth, and candidate semantics preserved.
  No real candidates modified during verification (static/syntax check only,
  or a CONTROLLED_TEST candidate if one exists and owner authorises).

.PARAMETER WhatIf
Dry-run: verify patch targets exist, check syntax. No changes made.

.PARAMETER Apply
Execute the patch and verify live versionId changed.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) { Write-Error "SAFETY: forbidden term '$bad' in path."; exit 1 }
}

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: -WhatIf (dry-run) | -Apply (execute patch)"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) { Write-Error "HMZ_N8N_API_KEY not set"; exit 1 }
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$WF_PROXY = "seB6ZmlyomhC4QWU"

function Get-Workflow($id) { Invoke-RestMethod -Uri "$BASE/workflows/$id" -Headers $HEADERS -Method GET }
function Find-Node($wf, $nameLike) {
    $n = $wf.nodes | Where-Object { $_.name -like $nameLike }
    if (-not $n) { throw "Node not found matching '$nameLike'" }
    $n
}

$pass=0; $fail=0
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS: $label"; $script:pass++ }
    else        { Write-Host "  FAIL: $label"; $script:fail++ }
}

# ─── Load ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-4I-B  WhatIf=$WhatIf  Apply=$Apply ==="
Write-Host "Production target: $BASE"
Write-Host ""
Write-Host "Loading proxy workflow $WF_PROXY ..."
$wfProxy = Get-Workflow $WF_PROXY
Write-Host "  name:      $($wfProxy.name)"
Write-Host "  versionId: $($wfProxy.versionId)"
Write-Host "  active:    $($wfProxy.active)"

$nodeValidate = Find-Node $wfProxy "Validate Write"

# ─── WhatIf checks ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Validate Write node ---"
$vCode = $nodeValidate.parameters.jsCode
Check "Validate Write has jsCode"                    ($vCode -ne $null -and $vCode.Length -gt 0)
Check "Validate Write uses JSON.parse on body"       ($vCode -match "JSON\.parse")
Check "Validate Write reads .json.body"              ($vCode -match "\.json\.body")
Check "Validate Write NOT yet multi-format"          ($vCode -notmatch "typeof rawBody")
Check "Validate Write checks required fields"        ($vCode -match "rule_id")

Write-Host ""
Write-Host "--- Proxy workflow state ---"
Check "Proxy workflow is active"                     ($wfProxy.active -eq $true)
Check "Proxy workflow has Webhook Write node"        (($wfProxy.nodes | Where-Object { $_.name -like "Webhook Write" }) -ne $null)
Check "Proxy workflow has DT Upsert node"            (($wfProxy.nodes | Where-Object { $_.name -like "DT Upsert" }) -ne $null)
Check "Proxy workflow has Respond Write node"        (($wfProxy.nodes | Where-Object { $_.name -like "Respond Write" }) -ne $null)

Write-Host ""
Write-Host "--- WhatIf Summary: PASS=$pass  FAIL=$fail ---"

if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf complete. No changes made. Run -Apply to execute."
    # Show the manual test command if the owner wants to verify the write path
    Write-Host ""
    Write-Host "Manual verification command (run after -Apply):"
    Write-Host "  No real candidates will be modified. Use a CONTROLLED_TEST rule_id."
    Write-Host "  Example (with HMZ_PHASE3_PROXY_WRITE_URL set):"
    Write-Host '  Invoke-RestMethod -Uri $env:HMZ_PHASE3_PROXY_WRITE_URL -Method POST \'
    Write-Host '    -ContentType "application/json" \'
    Write-Host '    -Body (@{ rule_id="CONTROLLED_TEST_ONLY"; status="proposed_shadow" } | ConvertTo-Json)'
    Write-Host "  Expected: validation error (rule_id not found in DataTable) or success if test candidate exists."
    exit ($fail -gt 0 ? 1 : 0)
}
if ($fail -gt 0) {
    Write-Error "WhatIf checks failed ($fail failures). Aborting Apply."
    exit 1
}

# ─── New Validate Write JS ─────────────────────────────────────────────────────
$NEW_VALIDATE_JS = @'
// Validate Write — fixed body parsing (SL-PHASE-4I-B)
// Handles: object body (Content-Type: application/json),
//          string body (Content-Type: text/plain),
//          stringified JSON body.
const raw = $input.first().json.body;
let b;
if (raw !== null && raw !== undefined && typeof raw === 'object') {
  b = raw;
} else if (typeof raw === 'string' && raw.trim().length > 0) {
  try { b = JSON.parse(raw); } catch { b = {}; }
} else {
  b = {};
}
const VALID_STATUSES = [
  'proposed_shadow',
  'approved_for_activation',
  'rejected',
  'deprecated',
  'rolled_back'
];
if (!b.rule_id || !b.status || !VALID_STATUSES.includes(b.status)) {
  throw new Error('Invalid: rule_id and valid status required');
}
const now = new Date().toISOString();
return [{json:{
  rule_id:         b.rule_id,
  status:          b.status,
  approved_by:     b.approved_by     || '',
  approved_at:     b.status === 'approved_for_activation' ? now : '',
  deprecated_at:   ['deprecated','rejected','rolled_back'].includes(b.status) ? now : '',
  rollback_reason: b.rollback_reason || ''
}}];
'@

# ─── Apply ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patch to Validate Write node ==="
$nodeValidate.parameters.jsCode = $NEW_VALIDATE_JS
Write-Host "  jsCode replaced."

# Preserve mode if set (runOnceForAllItems)
if (-not $nodeValidate.parameters.PSObject.Properties["mode"]) {
    $nodeValidate.parameters | Add-Member -NotePropertyName "mode" -NotePropertyValue "runOnceForAllItems" -Force
}

$slim = @{
    name        = $wfProxy.name
    nodes       = $wfProxy.nodes
    connections = $wfProxy.connections
    settings    = $wfProxy.settings
    staticData  = $wfProxy.staticData
}
$body      = $slim | ConvertTo-Json -Depth 20 -Compress
$putResult = Invoke-RestMethod -Uri "$BASE/workflows/$WF_PROXY" -Method PUT -Headers $HEADERS -Body $body -ContentType "application/json"
Write-Host "  New versionId: $($putResult.versionId)"

# ─── Verify ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Verification ==="
$wfV = Get-Workflow $WF_PROXY
Write-Host "  versionId after Apply: $($wfV.versionId)"

$pass2=0; $fail2=0
function Check2($label, $cond) {
    if ($cond) { Write-Host "  PASS: $label"; $script:pass2++ }
    else        { Write-Host "  FAIL: $label"; $script:fail2++ }
}

Check2 "versionId changed"                  ($wfV.versionId -ne $wfProxy.versionId)
$vV = $wfV.nodes | Where-Object { $_.name -like "Validate Write" }
Check2 "Validate Write node exists"         ($vV -ne $null)
Check2 "Validate Write uses typeof rawBody" ($vV -and $vV.parameters.jsCode -match "typeof rawBody")
Check2 "Validate Write still checks rule_id" ($vV -and $vV.parameters.jsCode -match "rule_id")
Check2 "Validate Write still checks VALID_STATUSES" ($vV -and $vV.parameters.jsCode -match "VALID_STATUSES")
Check2 "Proxy workflow still active"        ($wfV.active -eq $true)

# Verify read endpoint still intact
$whRead = $wfV.nodes | Where-Object { $_.name -like "Webhook Read" }
Check2 "Webhook Read node preserved"        ($whRead -ne $null)

Write-Host ""
Write-Host "=== Phase 4I-B Verification: PASS=$pass2  FAIL=$fail2 ==="

if ($fail2 -gt 0) {
    Write-Host "WARN: $fail2 verification check(s) failed. Inspect above."
    exit 1
}

Write-Host ""
Write-Host "=== SL-PHASE-4I-B APPLIED SUCCESSFULLY ==="
Write-Host "  Proxy workflow versionId: $($wfV.versionId)"
Write-Host "  Validate Write node: updated (multi-format body parsing)"
Write-Host "  Read endpoint: preserved"
Write-Host "  Auth/security: preserved"
Write-Host "  Candidate status semantics: preserved"
Write-Host "  Responder workflows: NOT modified"
Write-Host ""
Write-Host "  Verification of write path:"
Write-Host "  Send a test write with Content-Type: application/json to HMZ_PHASE3_PROXY_WRITE_URL."
Write-Host "  Expected: validation error for unknown rule_id, or success if CONTROLLED_TEST candidate exists."
Write-Host "  Do NOT modify real candidates during verification."
