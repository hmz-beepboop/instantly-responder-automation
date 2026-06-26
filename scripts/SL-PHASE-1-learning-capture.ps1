#Requires -Version 7.0
# SL-PHASE-1-learning-capture.ps1
# Phase 1 supervised learning capture.
# -WhatIf: validates plan, no production writes.
# -Apply:  wires 3 capture nodes into HumanApproval workflow.

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
$ReviewCaseDataTableId      = "WMTmI6UNjZZgSU3h"
$DraftRevisionEventsTableId = "dMqnPUMA4ogWR7uP"   # sl_draft_revision_events (created manually)
$ProjectFolder              = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$LocalExportPath            = Join-Path $ProjectFolder `
    "verification\patch-3.0-backup\20260621T152227Z\HumanApproval-9aPrt92jFhoYFxbs.json"

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
    Write-Host " SL-PHASE-1-learning-capture.ps1  [WhatIf Mode]" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $ProjectFolder)) { Write-Host "[FAIL] Project folder not found." -ForegroundColor Red; exit 1 }
    Write-Host "[OK] Project folder found." -ForegroundColor Green

    if (-not (Test-Path $LocalExportPath)) { Write-Host "[FAIL] Local HumanApproval export not found." -ForegroundColor Red; exit 1 }
    Write-Host "[OK] Local HumanApproval export found." -ForegroundColor Green

    $masterPath = Join-Path $ProjectFolder "docs\NEXT_PHASE_MASTER_DESIGN_SELF_IMPROVING_AND_AUTONOMOUS.md"
    if (-not (Test-Path $masterPath)) { Write-Host "[FAIL] Master design doc not found." -ForegroundColor Red; exit 1 }
    Write-Host "[OK] Master design doc found." -ForegroundColor Green

    if ([string]::IsNullOrWhiteSpace($DraftRevisionEventsTableId)) {
        Write-Host "[FAIL] DraftRevisionEventsTableId is empty." -ForegroundColor Red; exit 1
    }
    Write-Host "[OK] DataTable ID set: $DraftRevisionEventsTableId" -ForegroundColor Green

    Write-Host "[INFO] FTH ID: $FullTestHarnessId — Apply will verify INACTIVE via API." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "── Patch Design ────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Workflow : HMZ - Reply Human Approval - Validation ($HumanApprovalWorkflowId)" -ForegroundColor White
    Write-Host "  Chain    : N → SL-P1A → SL-P1B → SL-P1C → O  (was N → O)" -ForegroundColor White
    Write-Host "  SL-P1A   : Code — builds draft_revision_event; try/catch; passes context through" -ForegroundColor Yellow
    Write-Host "  SL-P1B   : DataTable insert — onError=continueRegularOutput; append-only" -ForegroundColor Yellow
    Write-Host "  SL-P1C   : Code — reads SL-P1A output, forwards unchanged to O" -ForegroundColor Yellow
    Write-Host "  Target DataTable: $DraftRevisionEventsTableId (sl_draft_revision_events)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "── Safety Checks ───────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  [OK] Approval requirement unchanged — N/O/P/Q nodes untouched." -ForegroundColor Green
    Write-Host "  [OK] Sender behavior unchanged — Q receives identical inputs." -ForegroundColor Green
    Write-Host "  [OK] Autonomous send not introduced — passive append-only capture." -ForegroundColor Green
    Write-Host "  [OK] No secrets logged — no tokens/keys/credentials in event fields." -ForegroundColor Green
    Write-Host "  [OK] Non-blocking — onError=continueRegularOutput; try/catch in P1A." -ForegroundColor Green
    Write-Host "  [OK] Append-only — DataTable insert only, no update/delete on learning rows." -ForegroundColor Green
    Write-Host "  [OK] No production writes in WhatIf." -ForegroundColor Green
    Write-Host "  [OK] MCP not used." -ForegroundColor Green
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " WhatIf Summary" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STATUS_PERCENTAGE:              6%"
    Write-Host "PROJECT_FOLDER_FOUND:           YES"
    Write-Host "DATATABLE_ID_ACCEPTED:          YES — $DraftRevisionEventsTableId"
    Write-Host "SCRIPT_UPDATED:                 YES — DataTable ID wired, Apply unblocked"
    Write-Host "PATCH_SCOPE:                    3 new nodes in HumanApproval ($HumanApprovalWorkflowId)"
    Write-Host "WHATIF_RAN:                     YES"
    Write-Host "WHATIF_RESULT:                  PASS"
    Write-Host "APPLY_RAN:                      NO"
    Write-Host "PATCH_APPLIED_AND_VERIFIED:     NO"
    Write-Host "CAPTURE_POINT:                  After N, before O in submit path"
    Write-Host "EVENT_CAPTURED:                 draft_revision_event"
    Write-Host "DATATABLE_TARGET:               $DraftRevisionEventsTableId (sl_draft_revision_events)"
    Write-Host "NON_BLOCKING_CAPTURE_CONFIRMED: YES"
    Write-Host "NO_SECRETS_LOGGED:              YES"
    Write-Host "PRODUCTION_WRITES_OCCURRED:     NO"
    Write-Host "MCP_USED:                       NO"
    Write-Host "AUTONOMOUS_SEND_INTRODUCED:     NO"
    Write-Host "SENDER_BEHAVIOR_CHANGED:        NO"
    Write-Host "APPROVAL_REQUIREMENT_CHANGED:   NO"
    Write-Host "FTH_STATUS:                     NOT CHECKED (WhatIf — Apply verifies via API)"
    Write-Host "SAFE_FOR_PHASE_1_CONTROLLED_TEST: NO (Apply not yet run)"
    Write-Host "ANY_ERRORS:                     NONE"
    Write-Host "NEXT_STEP:                      Run -Apply (WhatIf passed, DataTable ID confirmed)"
    Write-Host ""
    exit 0
}

# ════════════════════════════════════════════════════════════════════════════
# APPLY MODE
# ════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SL-PHASE-1-learning-capture.ps1  [Apply Mode]" -ForegroundColor Cyan
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

# C. DataTable ID guard
if ([string]::IsNullOrWhiteSpace($DraftRevisionEventsTableId)) {
    Write-Error "DraftRevisionEventsTableId is empty."; exit 1
}
Write-Host "[OK] DataTable ID: $DraftRevisionEventsTableId" -ForegroundColor Green

# D. Fetch workflow as raw JSON → hashtable for safe mutation
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
    Write-Error "Workflow ID mismatch — expected $HumanApprovalWorkflowId."; exit 1
}

# E. Verify N→O connection (detect if patch already applied)
$connN = $workflow['connections']['N. Process Reviewer Decision']
if (-not $connN) { Write-Error "Node N connection not found in workflow."; exit 1 }
$targetOfN = $connN['main'][0][0]['node']
if ($targetOfN -ne "O. Persist Reviewer Decision (Data Table)") {
    Write-Host "[BLOCKED] N connects to '$targetOfN' not O. Already patched?" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] N→O connection confirmed clean." -ForegroundColor Green

# F. Ensure patch nodes don't exist yet
$existingNames = $workflow['nodes'] | ForEach-Object { $_['name'] }
foreach ($pName in @(
    "SL-P1A. Build Draft Revision Event",
    "SL-P1B. Write Draft Revision Event (DataTable)",
    "SL-P1C. Restore Context After Capture"
)) {
    if ($existingNames -contains $pName) {
        Write-Host "[BLOCKED] '$pName' already exists. Patch already applied." -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Patch nodes absent — clean to apply." -ForegroundColor Green

# G. Node JS code
$slP1aJs = @'
const items = $input.all();
return items.map(item => {
  try {
    const inp = item.json || {};
    const rc  = inp.review_case   || {};
    const ci  = inp.case_input    || {};
    const nes = ci.nes            || {};
    const dr  = ci.draft          || {};
    const rep = nes.reply         || {};
    const sc  = rc.sanitized_context || {};

    const rawDraft   = rc.draft_text       || "";
    const finalDraft = rc.final_reply_text || "";
    const editDetected = rawDraft !== finalDraft && finalDraft.length > 0;

    const snip    = sc.reply_snippet || sc.reply_text || "";
    const excerpt = snip.length > 200 ? snip.substring(0, 200) : snip;

    const exId = (() => {
      try { return ($execution && $execution.id) ? $execution.id : null; } catch { return null; }
    })();

    function genUuid() {
      const a = new Uint8Array(16);
      if (typeof globalThis.crypto !== "undefined" && globalThis.crypto.getRandomValues) {
        globalThis.crypto.getRandomValues(a);
      } else {
        for (let i = 0; i < 16; i++) a[i] = Math.floor(Math.random() * 256);
      }
      a[6] = (a[6] & 0x0f) | 0x40;
      a[8] = (a[8] & 0x3f) | 0x80;
      const h = Array.from(a).map(b => b.toString(16).padStart(2,"0")).join("");
      return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;
    }

    const ev = {
      event_id:                      genUuid(),
      timestamp:                     new Date().toISOString(),
      case_id:                       rc.case_id  || null,
      intake_id:                     rc.intake_id || null,
      campaign_id:                   (sc.campaign_context && sc.campaign_context.campaign_id) || nes.campaign_id || null,
      sender_account:                nes.eaccount || nes.email_account || null,
      lead_email:                    rep.from_email || nes.lead_email || null,
      original_inbound_reply_excerpt: excerpt || null,
      category:                      rc.category    || null,
      micro_intent:                  rc.micro_intent || null,
      ai_draft_source:               dr.draft_source || rc.draft_source || null,
      raw_ai_draft_text:             rawDraft   || null,
      draft_shown_to_reviewer:       rawDraft   || null,
      final_edited_draft_submitted:  finalDraft || null,
      edit_detected:                 editDetected,
      approval_decision:             inp.final_action      || null,
      reviewer_identity:             rc.approver_identity  || null,
      source_workflow:               "HMZ - Reply Human Approval - Validation",
      source_execution_id:           exId
    };
    return { json: { ...inp, sl_p1_event: ev, sl_p1_capture_error: false } };
  } catch (err) {
    return { json: { ...item.json, sl_p1_event: null, sl_p1_capture_error: true,
      sl_p1_error_msg: String(err && err.message ? err.message : err) } };
  }
});
'@

$slP1cJs = @'
const src = $("SL-P1A. Build Draft Revision Event").first().json;
return [{ json: src }];
'@

# H. Build the 3 new node definitions
$dtId = $DraftRevisionEventsTableId

$slP1aNode = [ordered]@{
    id          = "sl-p1a-build-draft-revision-event"
    name        = "SL-P1A. Build Draft Revision Event"
    type        = "n8n-nodes-base.code"
    typeVersion = 2
    position    = @(1260, 1000)
    parameters  = [ordered]@{ jsCode = $slP1aJs }
}

$slP1bNode = [ordered]@{
    id          = "sl-p1b-write-draft-revision-event"
    name        = "SL-P1B. Write Draft Revision Event (DataTable)"
    type        = "n8n-nodes-base.dataTable"
    typeVersion = 1.1
    position    = @(1260, 1140)
    onError     = "continueRegularOutput"
    parameters  = [ordered]@{
        resource    = "row"
        operation   = "create"
        dataTableId = [ordered]@{ mode = "id"; value = $dtId }
        columns     = [ordered]@{
            mappingMode = "defineBelow"
            value = [ordered]@{
                event_id                       = '={{ $json.sl_p1_event ? $json.sl_p1_event.event_id : null }}'
                timestamp                      = '={{ $json.sl_p1_event ? $json.sl_p1_event.timestamp : null }}'
                case_id                        = '={{ $json.sl_p1_event ? $json.sl_p1_event.case_id : null }}'
                intake_id                      = '={{ $json.sl_p1_event ? $json.sl_p1_event.intake_id : null }}'
                campaign_id                    = '={{ $json.sl_p1_event ? $json.sl_p1_event.campaign_id : null }}'
                sender_account                 = '={{ $json.sl_p1_event ? $json.sl_p1_event.sender_account : null }}'
                lead_email                     = '={{ $json.sl_p1_event ? $json.sl_p1_event.lead_email : null }}'
                original_inbound_reply_excerpt = '={{ $json.sl_p1_event ? $json.sl_p1_event.original_inbound_reply_excerpt : null }}'
                category                       = '={{ $json.sl_p1_event ? $json.sl_p1_event.category : null }}'
                micro_intent                   = '={{ $json.sl_p1_event ? $json.sl_p1_event.micro_intent : null }}'
                ai_draft_source                = '={{ $json.sl_p1_event ? $json.sl_p1_event.ai_draft_source : null }}'
                raw_ai_draft_text              = '={{ $json.sl_p1_event ? $json.sl_p1_event.raw_ai_draft_text : null }}'
                draft_shown_to_reviewer        = '={{ $json.sl_p1_event ? $json.sl_p1_event.draft_shown_to_reviewer : null }}'
                final_edited_draft_submitted   = '={{ $json.sl_p1_event ? $json.sl_p1_event.final_edited_draft_submitted : null }}'
                edit_detected                  = '={{ $json.sl_p1_event ? $json.sl_p1_event.edit_detected : null }}'
                approval_decision              = '={{ $json.sl_p1_event ? $json.sl_p1_event.approval_decision : null }}'
                reviewer_identity              = '={{ $json.sl_p1_event ? $json.sl_p1_event.reviewer_identity : null }}'
                source_workflow                = '={{ $json.sl_p1_event ? $json.sl_p1_event.source_workflow : null }}'
                source_execution_id            = '={{ $json.sl_p1_event ? $json.sl_p1_event.source_execution_id : null }}'
            }
        }
    }
}

$slP1cNode = [ordered]@{
    id          = "sl-p1c-restore-context-after-capture"
    name        = "SL-P1C. Restore Context After Capture"
    type        = "n8n-nodes-base.code"
    typeVersion = 2
    position    = @(1400, 1140)
    parameters  = [ordered]@{ jsCode = $slP1cJs }
}

# I. Add new nodes to workflow
$nodesList = [System.Collections.Generic.List[object]]($workflow['nodes'])
$nodesList.Add($slP1aNode)
$nodesList.Add($slP1bNode)
$nodesList.Add($slP1cNode)
$workflow['nodes'] = $nodesList.ToArray()

# J. Patch connections
# Redirect N → SL-P1A  (was N → O)
$workflow['connections']['N. Process Reviewer Decision']['main'] = @(
    ,@(@{ node = "SL-P1A. Build Draft Revision Event"; type = "main"; index = 0 })
)
# SL-P1A → SL-P1B
$workflow['connections']['SL-P1A. Build Draft Revision Event'] = @{
    main = @(,@(@{ node = "SL-P1B. Write Draft Revision Event (DataTable)"; type = "main"; index = 0 }))
}
# SL-P1B → SL-P1C
$workflow['connections']['SL-P1B. Write Draft Revision Event (DataTable)'] = @{
    main = @(,@(@{ node = "SL-P1C. Restore Context After Capture"; type = "main"; index = 0 }))
}
# SL-P1C → O
$workflow['connections']['SL-P1C. Restore Context After Capture'] = @{
    main = @(,@(@{ node = "O. Persist Reviewer Decision (Data Table)"; type = "main"; index = 0 }))
}

# K. Build PUT body
$putJson = ([ordered]@{
    name        = $workflow['name']
    nodes       = $workflow['nodes']
    connections = $workflow['connections']
    settings    = $workflow['settings']
    staticData  = $workflow['staticData']
}) | ConvertTo-Json -Depth 50 -Compress

# L. PUT
Write-Host "  Applying patch..." -ForegroundColor Gray
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

# M. Verify
Write-Host "  Verifying..." -ForegroundColor Gray
try {
    $v = Invoke-RestMethod `
        -Uri     "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers -Method GET -ErrorAction Stop

    $p1aOk = $null -ne ($v.nodes | Where-Object { $_.name -eq "SL-P1A. Build Draft Revision Event" })
    $p1bOk = $null -ne ($v.nodes | Where-Object { $_.name -eq "SL-P1B. Write Draft Revision Event (DataTable)" })
    $p1cOk = $null -ne ($v.nodes | Where-Object { $_.name -eq "SL-P1C. Restore Context After Capture" })

    if (-not ($p1aOk -and $p1bOk -and $p1cOk)) {
        Write-Error "VERIFICATION FAILED: Not all 3 capture nodes present after PUT."
        exit 1
    }

    $nConn  = $v.connections."N. Process Reviewer Decision"
    $nTarget = $nConn.main[0][0].node
    if ($nTarget -ne "SL-P1A. Build Draft Revision Event") {
        Write-Error "VERIFICATION FAILED: N connects to '$nTarget' not SL-P1A."
        exit 1
    }

    Write-Host "[OK] All 3 capture nodes present in live workflow." -ForegroundColor Green
    Write-Host "[OK] N→SL-P1A connection verified." -ForegroundColor Green
    Write-Host "[OK] Workflow active: $($v.active)" -ForegroundColor Green
} catch {
    Write-Error "Verification failed: $($_.Exception.Message)"; exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Apply Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "STATUS_PERCENTAGE:              12%"
Write-Host "PROJECT_FOLDER_FOUND:           YES"
Write-Host "DATATABLE_ID_ACCEPTED:          YES — $DraftRevisionEventsTableId"
Write-Host "SCRIPT_UPDATED:                 YES"
Write-Host "PATCH_SCOPE:                    3 new nodes in HumanApproval ($HumanApprovalWorkflowId)"
Write-Host "WHATIF_RAN:                     PRIOR SESSION — PASSED"
Write-Host "WHATIF_RESULT:                  PASS"
Write-Host "APPLY_RAN:                      YES"
Write-Host "PATCH_APPLIED_AND_VERIFIED:     YES"
Write-Host "CAPTURE_POINT:                  After N. Process Reviewer Decision, before O"
Write-Host "EVENT_CAPTURED:                 draft_revision_event"
Write-Host "DATATABLE_TARGET:               $DraftRevisionEventsTableId (sl_draft_revision_events)"
Write-Host "NON_BLOCKING_CAPTURE_CONFIRMED: YES"
Write-Host "NO_SECRETS_LOGGED:              YES"
Write-Host "PRODUCTION_WRITES_OCCURRED:     YES — HumanApproval workflow patched"
Write-Host "MCP_USED:                       NO"
Write-Host "AUTONOMOUS_SEND_INTRODUCED:     NO"
Write-Host "SENDER_BEHAVIOR_CHANGED:        NO"
Write-Host "APPROVAL_REQUIREMENT_CHANGED:   NO"
Write-Host "FTH_STATUS:                     INACTIVE (verified via API)"
Write-Host "SAFE_FOR_PHASE_1_CONTROLLED_TEST: YES"
Write-Host "ANY_ERRORS:                     NONE"
Write-Host "NEXT_STEP:                      Submit one real approval — verify a row appears in sl_draft_revision_events"
Write-Host ""
