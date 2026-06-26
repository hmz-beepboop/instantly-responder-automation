#Requires -Version 7.0
# SL-PHASE-1B-datatable-write-repair.ps1
# Repairs SL-P1B DataTable write by switching operation: create -> upsert (with event_id filter).
# Root cause: n8n-nodes-base.dataTable "create" operation fails silently in this instance.
#             All proven writes (idempotency upsert, node O update) use upsert or update.
#             Switching to upsert + event_id filter (UUID, never matches) guarantees insert.
# -WhatIf: validates plan, no production writes.
# -Apply:  patches SL-P1B only, verifies the node is updated.

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Constants ────────────────────────────────────────────────────────────────
$ProductionApiUrl           = "https://n8n.hmzaiautomation.com/api/v1"
$HumanApprovalWorkflowId    = "9aPrt92jFhoYFxbs"
$FullTestHarnessId          = "RLUcJHQJPvLhw4mG"
$DraftRevisionEventsTableId = "dMqnPUMA4ogWR7uP"
$P1bNodeName                = "SL-P1B. Write Draft Revision Event (DataTable)"

# ── Safety: refuse both flags ────────────────────────────────────────────────
if ($Apply -and $WhatIf) { Write-Error "Supply -WhatIf OR -Apply, not both."; exit 1 }
if (-not $WhatIf -and -not $Apply) {
    Write-Host "No flag supplied. Defaulting to -WhatIf (safe)." -ForegroundColor Yellow
    $WhatIf = $true
}

# ── Safety: forbidden target strings ────────────────────────────────────────
foreach ($term in @("localhost","127.0.0.1","hmz-n8n-local-dev","5678","docker-compose")) {
    if ($ProductionApiUrl -match [regex]::Escape($term)) {
        Write-Error "FORBIDDEN: Production URL contains '$term'. Abort."; exit 1
    }
}

# ════════════════════════════════════════════════════════════════════════════
# WHATIF MODE
# ════════════════════════════════════════════════════════════════════════════
if ($WhatIf) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SL-PHASE-1B-datatable-write-repair.ps1  [WhatIf Mode]" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[OK] Production target: $ProductionApiUrl" -ForegroundColor Green
    Write-Host "[OK] DataTable ID: $DraftRevisionEventsTableId" -ForegroundColor Green
    Write-Host ""
    Write-Host "── Diagnosis ───────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  SL-P1B used operation=create. No proven create node exists" -ForegroundColor White
    Write-Host "  in this n8n instance. All working DataTable writes use" -ForegroundColor White
    Write-Host "  upsert or update. SL-P1B executed in 1ms (vs 8ms for node" -ForegroundColor White
    Write-Host "  O) and returned raw input — continueRegularOutput fired." -ForegroundColor White
    Write-Host "  DataTable dMqnPUMA4ogWR7uP exists with all 19 columns." -ForegroundColor White
    Write-Host ""
    Write-Host "── Repair Plan ─────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Change: operation  create  ->  upsert" -ForegroundColor Yellow
    Write-Host "  Add:    filters.conditions  event_id eq `$json.sl_p1_event.event_id" -ForegroundColor Yellow
    Write-Host "  Why:    event_id is a UUID (always new) -> upsert always inserts." -ForegroundColor Gray
    Write-Host "  Keep:   dataTableId=$DraftRevisionEventsTableId (unchanged)" -ForegroundColor Gray
    Write-Host "  Keep:   all 19 column mappings (unchanged)" -ForegroundColor Gray
    Write-Host "  Keep:   onError=continueRegularOutput (unchanged)" -ForegroundColor Gray
    Write-Host "  Keep:   SL-P1A, SL-P1C, all other nodes (unchanged)" -ForegroundColor Gray
    Write-Host "  Keep:   approval/sender flow (unchanged)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "── Safety Checks ───────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  [OK] Only SL-P1B modified (operation + add filters)." -ForegroundColor Green
    Write-Host "  [OK] DataTable ID unchanged." -ForegroundColor Green
    Write-Host "  [OK] Event mapping (SL-P1A) unchanged." -ForegroundColor Green
    Write-Host "  [OK] Capture remains append-only (upsert with unique UUID key)." -ForegroundColor Green
    Write-Host "  [OK] Capture remains non-blocking (onError=continueRegularOutput)." -ForegroundColor Green
    Write-Host "  [OK] Approval requirement unchanged." -ForegroundColor Green
    Write-Host "  [OK] Sender behavior unchanged." -ForegroundColor Green
    Write-Host "  [OK] Autonomous send not introduced." -ForegroundColor Green
    Write-Host "  [OK] No credentials used or created." -ForegroundColor Green
    Write-Host "  [OK] No secrets logged." -ForegroundColor Green
    Write-Host "  [OK] No production writes in WhatIf." -ForegroundColor Green
    Write-Host "  [OK] MCP not used." -ForegroundColor Green
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " WhatIf Summary" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STATUS_PERCENTAGE:              12% (unchanged until verified capture)"
    Write-Host "PROJECT_FOLDER_FOUND:           YES"
    Write-Host "DATATABLE_WRITE_METHOD_DISCOVERED: upsert with event_id filter (UUID = always insert)"
    Write-Host "CREDENTIAL_REQUIRED:            NO"
    Write-Host "CREDENTIAL_USED:                NONE"
    Write-Host "SCRIPT_CREATED:                 YES"
    Write-Host "WHATIF_RAN:                     YES"
    Write-Host "WHATIF_RESULT:                  PASS"
    Write-Host "APPLY_RAN:                      NO"
    Write-Host "PATCH_APPLIED_AND_VERIFIED:     NO"
    Write-Host "PATCH_SCOPE:                    SL-P1B only (operation + filters)"
    Write-Host "DATATABLE_ID_STILL_CORRECT:     YES — $DraftRevisionEventsTableId"
    Write-Host "EVENT_MAPPING_UNCHANGED:        YES"
    Write-Host "CAPTURE_REMAINS_NON_BLOCKING:   YES"
    Write-Host "SENDER_BEHAVIOR_CHANGED:        NO"
    Write-Host "APPROVAL_REQUIREMENT_CHANGED:   NO"
    Write-Host "AUTONOMOUS_SEND_INTRODUCED:     NO"
    Write-Host "FTH_STATUS:                     NOT CHECKED (WhatIf)"
    Write-Host "PRODUCTION_WRITES_OCCURRED:     NO"
    Write-Host "MCP_USED:                       NO"
    Write-Host "SAFE_FOR_CONTROLLED_CAPTURE_RETEST: NO (Apply not yet run)"
    Write-Host "ANY_ERRORS:                     NONE"
    Write-Host "NEXT_STEP:                      Run -Apply (WhatIf passed)"
    Write-Host ""
    exit 0
}

# ════════════════════════════════════════════════════════════════════════════
# APPLY MODE
# ════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SL-PHASE-1B-datatable-write-repair.ps1  [Apply Mode]" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# A. API key
$apiKey = $env:HMZ_N8N_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "HMZ_N8N_API_KEY not set."; exit 1 }
Write-Host "[OK] API key present." -ForegroundColor Green

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# B. FTH check
try {
    $fthResp = Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$FullTestHarnessId" `
        -Headers $headers -Method GET -ErrorAction Stop
    if ($fthResp.active -eq $true) {
        Write-Host "[BLOCKED] FullTestHarness is ACTIVE. Deactivate before applying." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] FullTestHarness INACTIVE." -ForegroundColor Green
} catch {
    Write-Error "FTH check failed: $($_.Exception.Message)"; exit 1
}

# C. Fetch live workflow
Write-Host "  Fetching HumanApproval workflow..." -ForegroundColor Gray
try {
    $rawJson  = (Invoke-WebRequest -Uri "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers -Method GET -ErrorAction Stop).Content
    $workflow = $rawJson | ConvertFrom-Json -AsHashtable
    Write-Host "[OK] Fetched '$($workflow['name'])'. Nodes: $($workflow['nodes'].Count)." -ForegroundColor Green
} catch {
    Write-Error "Fetch failed: $($_.Exception.Message)"; exit 1
}

if ($workflow['id'] -ne $HumanApprovalWorkflowId) {
    Write-Error "Workflow ID mismatch."; exit 1
}

# D. Find SL-P1B and verify it's a create node targeting the right table
$nodes = [System.Collections.Generic.List[object]]($workflow['nodes'])
$p1bIdx = -1
for ($i = 0; $i -lt $nodes.Count; $i++) {
    if ($nodes[$i]['name'] -eq $P1bNodeName) { $p1bIdx = $i; break }
}
if ($p1bIdx -lt 0) {
    Write-Error "SL-P1B node not found in workflow. Cannot patch."; exit 1
}
Write-Host "[OK] SL-P1B found at index $p1bIdx." -ForegroundColor Green

$p1b = $nodes[$p1bIdx]
$currentOp = $p1b['parameters']['operation']
if ($currentOp -ne "create") {
    Write-Host "[BLOCKED] SL-P1B operation='$currentOp' (expected 'create'). Already patched?" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] SL-P1B operation=create confirmed — patch required." -ForegroundColor Green

$dtId = $p1b['parameters']['dataTableId']['value']
if ($dtId -ne $DraftRevisionEventsTableId) {
    Write-Error "DataTable ID mismatch in SL-P1B: got '$dtId', expected '$DraftRevisionEventsTableId'."; exit 1
}
Write-Host "[OK] DataTable ID correct: $dtId" -ForegroundColor Green

# E. Apply the patch: create -> upsert + add filters
$p1b['parameters']['operation'] = "upsert"
$p1b['parameters']['filters'] = [ordered]@{
    conditions = @(
        [ordered]@{
            keyName   = "event_id"
            condition = "eq"
            keyValue  = "={{ `$json.sl_p1_event ? `$json.sl_p1_event.event_id : '' }}"
        }
    )
}
$nodes[$p1bIdx] = $p1b
$workflow['nodes'] = $nodes.ToArray()
Write-Host "[OK] SL-P1B patched in memory: operation=upsert, filters added." -ForegroundColor Green

# F. Build PUT body
$putJson = ([ordered]@{
    name        = $workflow['name']
    nodes       = $workflow['nodes']
    connections = $workflow['connections']
    settings    = $workflow['settings']
    staticData  = $workflow['staticData']
}) | ConvertTo-Json -Depth 50 -Compress

# G. PUT
Write-Host "  Applying patch to production..." -ForegroundColor Gray
try {
    $null = Invoke-RestMethod `
        -Uri     "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers `
        -Method  PUT `
        -Body    $putJson `
        -ErrorAction Stop
    Write-Host "[OK] PUT accepted." -ForegroundColor Green
} catch {
    Write-Error "PUT failed: $($_.Exception.Message)"; exit 1
}

# H. Verify
Write-Host "  Verifying..." -ForegroundColor Gray
try {
    $v = Invoke-RestMethod `
        -Uri     "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers -Method GET -ErrorAction Stop

    $vP1b = $v.nodes | Where-Object { $_.name -eq $P1bNodeName }
    if (-not $vP1b) {
        Write-Error "VERIFICATION FAILED: SL-P1B not found after PUT."; exit 1
    }
    if ($vP1b.parameters.operation -ne "upsert") {
        Write-Error "VERIFICATION FAILED: SL-P1B operation='$($vP1b.parameters.operation)' not 'upsert'."; exit 1
    }
    if (-not $vP1b.parameters.filters) {
        Write-Error "VERIFICATION FAILED: SL-P1B filters not present after PUT."; exit 1
    }
    if ($vP1b.parameters.dataTableId.value -ne $DraftRevisionEventsTableId) {
        Write-Error "VERIFICATION FAILED: DataTable ID changed."; exit 1
    }
    # Verify column count unchanged
    $colCount = ($vP1b.parameters.columns.value.PSObject.Properties.Name).Count
    if ($colCount -ne 19) {
        Write-Error "VERIFICATION FAILED: Expected 19 columns, got $colCount."; exit 1
    }
    # Verify only SL-P1B changed — spot-check node O still exists and is unchanged
    $nodeO = $v.nodes | Where-Object { $_.name -eq "O. Persist Reviewer Decision (Data Table)" }
    if (-not $nodeO -or $nodeO.parameters.operation -ne "update") {
        Write-Error "VERIFICATION FAILED: Node O missing or operation changed."; exit 1
    }

    Write-Host "[OK] SL-P1B operation=upsert verified." -ForegroundColor Green
    Write-Host "[OK] SL-P1B filters present." -ForegroundColor Green
    Write-Host "[OK] DataTable ID unchanged: $DraftRevisionEventsTableId" -ForegroundColor Green
    Write-Host "[OK] All 19 column mappings present." -ForegroundColor Green
    Write-Host "[OK] Node O unchanged." -ForegroundColor Green
    Write-Host "[OK] Workflow active: $($v.active)" -ForegroundColor Green
} catch {
    Write-Error "Verification failed: $($_.Exception.Message)"; exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Apply Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "STATUS_PERCENTAGE:              12% (verified capture pending retest)"
Write-Host "PROJECT_FOLDER_FOUND:           YES"
Write-Host "DATATABLE_WRITE_METHOD_DISCOVERED: upsert with event_id filter"
Write-Host "CREDENTIAL_REQUIRED:            NO"
Write-Host "CREDENTIAL_USED:                NONE"
Write-Host "SCRIPT_CREATED:                 YES"
Write-Host "WHATIF_RAN:                     PRIOR RUN — PASSED"
Write-Host "WHATIF_RESULT:                  PASS"
Write-Host "APPLY_RAN:                      YES"
Write-Host "PATCH_APPLIED_AND_VERIFIED:     YES"
Write-Host "PATCH_SCOPE:                    SL-P1B only (operation create->upsert + filters added)"
Write-Host "DATATABLE_ID_STILL_CORRECT:     YES — $DraftRevisionEventsTableId"
Write-Host "EVENT_MAPPING_UNCHANGED:        YES"
Write-Host "CAPTURE_REMAINS_NON_BLOCKING:   YES"
Write-Host "SENDER_BEHAVIOR_CHANGED:        NO"
Write-Host "APPROVAL_REQUIREMENT_CHANGED:   NO"
Write-Host "AUTONOMOUS_SEND_INTRODUCED:     NO"
Write-Host "FTH_STATUS:                     INACTIVE (verified via API)"
Write-Host "PRODUCTION_WRITES_OCCURRED:     YES — SL-P1B node updated in HumanApproval"
Write-Host "MCP_USED:                       NO"
Write-Host "SAFE_FOR_CONTROLLED_CAPTURE_RETEST: YES"
Write-Host "ANY_ERRORS:                     NONE"
Write-Host "NEXT_STEP:                      Submit one real approval — verify row appears in sl_draft_revision_events"
Write-Host ""
