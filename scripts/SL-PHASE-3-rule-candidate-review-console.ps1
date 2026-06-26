<#
.SYNOPSIS
  SL-PHASE-3 — Rule Candidate Review Console.
  Read and update rule candidates in sl_rule_candidates DataTable (ID: CSdiTjXfi0tl0oZF).

  SETUP REQUIREMENT: The n8n REST API does not expose a DataTable rows endpoint.
  Read and write operations go through a proxy webhook workflow.
  Run -Setup first (one time, requires owner confirmation) to create the proxy workflow.
  After setup, all operations work via the proxy webhook.

  IMPORTANT: Approving a candidate sets status to approved_for_activation ONLY.
  It does NOT inject the rule into Decision, alter AI behaviour, alter classification,
  or enable autonomous sending. Active rule injection is a separate future phase.

.PARAMETER Setup
  Create the Phase 3 proxy n8n workflow (one-time step, requires owner confirmation).

.PARAMETER CheckSetup
  Check whether the proxy workflow is configured and reachable.

.PARAMETER ListCandidates
  List all rule candidates (read-only).

.PARAMETER ShowCandidate
  Show full detail for a specific rule_id (read-only).

.PARAMETER ApproveCandidate
  Set status to approved_for_activation.

.PARAMETER RejectCandidate
  Set status to rejected.

.PARAMETER DeprecateCandidate
  Set status to deprecated.

.PARAMETER RollbackCandidate
  Set status to rolled_back.

.PARAMETER Reviewer
  Required for mutating actions. Reviewer email.

.PARAMETER Reason
  Required for Reject, Deprecate, Rollback.

.PARAMETER WhatIf
  Preview the mutation without writing.

.EXAMPLE
  # First time: create the proxy workflow
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -Setup

  # Check proxy is up
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -CheckSetup

  # Read operations
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -ShowCandidate <rule_id>

  # Write operations (preview first)
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -ApproveCandidate <rule_id> -Reviewer you@example.com -WhatIf
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -ApproveCandidate <rule_id> -Reviewer you@example.com
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -RejectCandidate <rule_id> -Reviewer you@example.com -Reason "Not representative"
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -DeprecateCandidate <rule_id> -Reviewer you@example.com -Reason "Superseded"
  .\SL-PHASE-3-rule-candidate-review-console.ps1 -RollbackCandidate <rule_id> -Reviewer you@example.com -Reason "Caused regression"
#>

param(
    [switch]$Setup,
    [string]$OwnerConfirmedSetup = "",   # Pass "YES" to skip interactive Read-Host prompt
    [switch]$CheckSetup,
    [switch]$ListCandidates,
    [string]$ShowCandidate      = "",
    [string]$ApproveCandidate   = "",
    [string]$RejectCandidate    = "",
    [string]$DeprecateCandidate = "",
    [string]$RollbackCandidate  = "",
    [string]$Reviewer  = "",
    [string]$Reason    = "",
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ApiKey       = $env:HMZ_N8N_API_KEY
$Base         = "https://n8n.hmzaiautomation.com/api/v1"
$DtId         = "CSdiTjXfi0tl0oZF"
$HaWfId       = "9aPrt92jFhoYFxbs"
$Headers      = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }
$ProxyEnvKey  = "HMZ_PHASE3_PROXY_WEBHOOK_URL"
$ProxyReadUrl = $env:HMZ_PHASE3_PROXY_WEBHOOK_URL
$ValidStatuses = @("proposed_shadow","approved_for_activation","rejected","deprecated","rolled_back")

if (-not $ApiKey) { Write-Host "ERROR: HMZ_N8N_API_KEY not set."; exit 1 }

Write-Host "=== SL-PHASE-3 Rule Candidate Review Console ==="
Write-Host "DataTable: $DtId (sl_rule_candidates) | Production: $Base"
Write-Host ""

# ========================
# SETUP
# ========================
if ($Setup) {
    Write-Host "=== -Setup: Create Phase 3 Proxy Workflow ==="
    Write-Host ""
    Write-Host "This will create a new n8n workflow 'SL-Phase3-RuleCandidate-Proxy' with:"
    Write-Host "  - Webhook GET /phase3-rc-read -> DataTable getAll -> Respond"
    Write-Host "  - Webhook POST /phase3-rc-write -> Code (validate) -> DataTable upsert -> Respond"
    Write-Host "  - Activated immediately (required for webhook to be reachable)"
    Write-Host ""
    Write-Host "This is a one-time setup step. The proxy workflow is a utility workflow,"
    Write-Host "not a responder workflow. It does not affect Decision, HumanApproval, or Sender."
    Write-Host ""
    if ($OwnerConfirmedSetup -eq "YES") {
        $confirm = "YES"
        Write-Host "[Non-interactive] -OwnerConfirmedSetup YES accepted."
    } else {
        $confirm = Read-Host "Type YES to create the proxy workflow, or anything else to cancel"
    }
    if ($confirm -ne "YES") { Write-Host "Cancelled."; exit 0 }

    $readWebhookPath  = "phase3-rc-read"
    $writeWebhookPath = "phase3-rc-write"

    # Raw JSON to avoid PowerShell @(@(...)) array-flattening in connections format.
    $validateJs = 'const b=JSON.parse($input.first().json.body||"{}");if(!b.rule_id||!b.status||!["proposed_shadow","approved_for_activation","rejected","deprecated","rolled_back"].includes(b.status)){throw new Error("Invalid: rule_id and valid status required");}const now=new Date().toISOString();return [{json:{rule_id:b.rule_id,status:b.status,approved_by:b.approved_by||"",approved_at:b.status==="approved_for_activation"?now:"",deprecated_at:["deprecated","rejected","rolled_back"].includes(b.status)?now:"",rollback_reason:b.rollback_reason||""}}];'
    $proxyWfBody = @"
{
  "name": "SL-Phase3-RuleCandidate-Proxy",
  "nodes": [
    {"id":"wh-read",  "name":"Webhook Read",   "type":"n8n-nodes-base.webhook",          "typeVersion":2,"position":[250,200],"parameters":{"path":"$readWebhookPath","httpMethod":"GET","responseMode":"responseNode","options":{}}},
    {"id":"dt-get",   "name":"DT GetAll",      "type":"n8n-nodes-base.dataTable",         "typeVersion":1,"position":[500,200],"parameters":{"resource":"row","operation":"getAll","dataTableId":{"mode":"id","value":"$DtId"},"returnAll":true}},
    {"id":"resp-r",   "name":"Respond Read",   "type":"n8n-nodes-base.respondToWebhook", "typeVersion":1,"position":[750,200],"parameters":{"respondWith":"allIncomingItems","options":{}}},
    {"id":"wh-write", "name":"Webhook Write",  "type":"n8n-nodes-base.webhook",          "typeVersion":2,"position":[250,400],"parameters":{"path":"$writeWebhookPath","httpMethod":"POST","responseMode":"responseNode","options":{}}},
    {"id":"code-v",   "name":"Validate Write", "type":"n8n-nodes-base.code",             "typeVersion":2,"position":[500,400],"parameters":{"jsCode":"$($validateJs -replace '"','\"')","mode":"runOnceForAllItems"}},
    {"id":"dt-ups",   "name":"DT Upsert",      "type":"n8n-nodes-base.dataTable",         "typeVersion":1,"position":[750,400],"parameters":{"resource":"row","operation":"upsert","dataTableId":{"mode":"id","value":"$DtId"},"filters":{"conditions":[{"keyName":"rule_id","condition":"eq","keyValue":"={{ `$json.rule_id }}"}]},"columns":{"mappingMode":"defineBelow","value":{"rule_id":"={{ `$json.rule_id }}","status":"={{ `$json.status }}","approved_by":"={{ `$json.approved_by }}","approved_at":"={{ `$json.approved_at }}","deprecated_at":"={{ `$json.deprecated_at }}","rollback_reason":"={{ `$json.rollback_reason }}"}}}},
    {"id":"resp-w",   "name":"Respond Write",  "type":"n8n-nodes-base.respondToWebhook", "typeVersion":1,"position":[1000,400],"parameters":{"respondWith":"allIncomingItems","options":{}}}
  ],
  "connections": {
    "Webhook Read":   {"main": [[{"node":"DT GetAll",      "type":"main","index":0}]]},
    "DT GetAll":      {"main": [[{"node":"Respond Read",   "type":"main","index":0}]]},
    "Webhook Write":  {"main": [[{"node":"Validate Write", "type":"main","index":0}]]},
    "Validate Write": {"main": [[{"node":"DT Upsert",      "type":"main","index":0}]]},
    "DT Upsert":      {"main": [[{"node":"Respond Write",  "type":"main","index":0}]]}
  },
  "settings": {"executionOrder":"v1"},
  "staticData": null
}
"@

    $created = Invoke-RestMethod -Uri "$Base/workflows" -Headers $Headers -Method POST -Body $proxyWfBody
    Write-Host "Created workflow: $($created.id) '$($created.name)'"

    $activated = Invoke-RestMethod -Uri "$Base/workflows/$($created.id)/activate" -Headers $Headers -Method POST
    Write-Host "Activated: $($activated.active)"

    $readUrl  = "https://n8n.hmzaiautomation.com/webhook/$readWebhookPath"
    $writeUrl = "https://n8n.hmzaiautomation.com/webhook/$writeWebhookPath"
    Write-Host ""
    Write-Host "=== SETUP COMPLETE ==="
    Write-Host "Proxy workflow ID: $($created.id)"
    Write-Host "Read webhook URL:  $readUrl"
    Write-Host "Write webhook URL: $writeUrl"
    Write-Host ""
    Write-Host "Set the following environment variable for future sessions:"
    Write-Host "  `$env:HMZ_PHASE3_PROXY_WEBHOOK_URL = '$readUrl'"
    Write-Host "  `$env:HMZ_PHASE3_PROXY_WRITE_URL   = '$writeUrl'"
    exit 0
}

# ========================
# CHECK SETUP
# ========================
if ($CheckSetup) {
    Write-Host "=== -CheckSetup ==="
    if (-not $ProxyReadUrl) {
        Write-Host "HMZ_PHASE3_PROXY_WEBHOOK_URL not set. Run -Setup first."
        exit 1
    }
    try {
        $r = Invoke-RestMethod -Uri $ProxyReadUrl -Method GET -TimeoutSec 10
        Write-Host "Proxy read endpoint reachable. Candidate count: $($r.Count)"
        exit 0
    } catch {
        Write-Host "ERROR: Proxy not reachable at $ProxyReadUrl — $($_.Exception.Message)"
        exit 1
    }
}

# ========================
# HELPERS
# ========================
function Assert-ProxyReady {
    if (-not $env:HMZ_PHASE3_PROXY_WEBHOOK_URL) {
        Write-Host "ERROR: Proxy not set up. Run: .\SL-PHASE-3-rule-candidate-review-console.ps1 -Setup"
        exit 1
    }
}

function Get-AllCandidates {
    Assert-ProxyReady
    $r = Invoke-RestMethod -Uri $env:HMZ_PHASE3_PROXY_WEBHOOK_URL -Method GET -TimeoutSec 15
    return $r
}

function Get-CandidateById([string]$ruleId) {
    $all = Get-AllCandidates
    return $all | Where-Object { $_.rule_id -eq $ruleId }
}

function Format-Candidate($row) {
    Write-Host "  rule_id:            $($row.rule_id)"
    Write-Host "  status:             $($row.status)"
    Write-Host "  rule_type:          $($row.rule_type)"
    Write-Host "  classification:     $($row.classification_scope)"
    Write-Host "  micro_intent_scope: $($row.micro_intent_scope)"
    Write-Host "  proposed_rule_text: $($row.proposed_rule_text)"
    Write-Host "  confidence:         $($row.confidence)"
    Write-Host "  source_case_id:     $($row.source_case_id)"
    Write-Host "  created_at:         $($row.created_at)"
    Write-Host "  created_by:         $($row.created_by)"
    Write-Host "  approved_by:        $($row.approved_by)"
    Write-Host "  approved_at:        $($row.approved_at)"
    Write-Host "  deprecated_at:      $($row.deprecated_at)"
    Write-Host "  rollback_reason:    $($row.rollback_reason)"
    Write-Host "  reason:             $($row.reason)"
}

function Apply-StatusUpdate([string]$ruleId, [string]$newStatus, [string]$reviewer, [string]$reason) {
    if (-not $env:HMZ_PHASE3_PROXY_WRITE_URL) {
        Write-Host "ERROR: HMZ_PHASE3_PROXY_WRITE_URL not set. Run -Setup first."
        exit 1
    }

    $row = Get-CandidateById $ruleId
    if (-not $row) { Write-Host "ERROR: rule_id '$ruleId' not found."; exit 1 }

    Write-Host ""
    Write-Host "=== Candidate ==="
    Format-Candidate $row
    Write-Host ""
    Write-Host "  Proposed change:"
    Write-Host "    status: $($row.status) -> $newStatus"
    if ($reviewer) { Write-Host "    approved_by: $reviewer" }
    if ($reason)   { Write-Host "    rollback_reason: $reason" }
    Write-Host ""
    Write-Host "  SAFETY: This update sets status only. It does NOT inject the rule into Decision,"
    Write-Host "          alter AI behaviour, alter classification, or enable autonomous sending."
    Write-Host ""

    if ($WhatIf) { Write-Host "=== WhatIf: no write performed. ==="; return }

    $writeBody = @{
        rule_id         = $ruleId
        status          = $newStatus
        approved_by     = $reviewer
        rollback_reason = $reason
    } | ConvertTo-Json -Compress

    $result = Invoke-RestMethod -Uri $env:HMZ_PHASE3_PROXY_WRITE_URL -Method POST `
        -Headers @{ "Content-Type" = "application/json" } -Body $writeBody -TimeoutSec 15
    Write-Host "Write result: $($result | ConvertTo-Json -Compress)"

    $verify = Get-CandidateById $ruleId
    $ok = $verify.status -eq $newStatus
    Write-Host "Post-update status: $($verify.status) | Expected: $newStatus | Match: $ok"
    if ($ok) { Write-Host "=== UPDATE APPLIED AND VERIFIED: PASS ===" }
    else      { Write-Host "=== UPDATE VERIFICATION FAILED — check manually ==="; exit 1 }
}

# ========================
# MAIN ACTIONS
# ========================

# Default: list
if (-not $ListCandidates -and -not $ShowCandidate -and -not $ApproveCandidate -and -not $RejectCandidate -and -not $DeprecateCandidate -and -not $RollbackCandidate) {
    Write-Host "No action specified. Defaulting to -ListCandidates."
    Write-Host "(Run -Setup if you haven't set up the proxy workflow yet.)"
    Write-Host ""
    $ListCandidates = $true
}

if ($ListCandidates) {
    Write-Host "=== Rule Candidates (sl_rule_candidates: $DtId) ==="
    $rows = Get-AllCandidates
    if (-not $rows -or $rows.Count -eq 0) { Write-Host "No candidates found."; exit 0 }
    foreach ($row in $rows) {
        $text = if ($row.proposed_rule_text) { $row.proposed_rule_text.Substring(0, [Math]::Min(55, $row.proposed_rule_text.Length)) } else { "" }
        Write-Host "  [$($row.status.PadRight(28))] [$($row.rule_type.PadRight(20))] $($row.rule_id) | $text"
    }
    Write-Host ""; Write-Host "Total: $($rows.Count)"
    exit 0
}

if ($ShowCandidate) {
    Write-Host "=== Rule Candidate Detail: $ShowCandidate ==="
    $row = Get-CandidateById $ShowCandidate
    if (-not $row) { Write-Host "Not found: $ShowCandidate"; exit 1 }
    Format-Candidate $row
    exit 0
}

if ($ApproveCandidate) {
    if (-not $Reviewer) { Write-Host "ERROR: -Reviewer required."; exit 1 }
    Apply-StatusUpdate $ApproveCandidate "approved_for_activation" $Reviewer ""
    exit 0
}

if ($RejectCandidate) {
    if (-not $Reviewer) { Write-Host "ERROR: -Reviewer required."; exit 1 }
    if (-not $Reason)   { Write-Host "ERROR: -Reason required."; exit 1 }
    Apply-StatusUpdate $RejectCandidate "rejected" $Reviewer $Reason
    exit 0
}

if ($DeprecateCandidate) {
    if (-not $Reviewer) { Write-Host "ERROR: -Reviewer required."; exit 1 }
    if (-not $Reason)   { Write-Host "ERROR: -Reason required."; exit 1 }
    Apply-StatusUpdate $DeprecateCandidate "deprecated" $Reviewer $Reason
    exit 0
}

if ($RollbackCandidate) {
    if (-not $Reviewer) { Write-Host "ERROR: -Reviewer required."; exit 1 }
    if (-not $Reason)   { Write-Host "ERROR: -Reason required."; exit 1 }
    Apply-StatusUpdate $RollbackCandidate "rolled_back" $Reviewer $Reason
    exit 0
}
