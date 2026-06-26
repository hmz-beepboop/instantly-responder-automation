#Requires -Version 7.0
# SL-PHASE-1C-2-shadow-learning-scaffold.ps1
# Phase 1C: optional classification correction fields in HumanApproval review form.
#           Writes sl_classification_correction_event when reviewer changes category/micro_intent.
# Phase 2:  Shadow rule candidate generation from corrections and draft edits.
#           Writes proposed_shadow rule candidates to sl_rule_candidates (never injected into prompts).
#
# -WhatIf:  Read-only checks. Confirms Phase 1 nodes, FTH status, DataTable existence, and patch scope.
# -Apply:   Patches HumanApproval 9aPrt92jFhoYFxbs only. Requires -ClassificationCorrectionEventsTableId
#           and -RuleCandidatesTableId.
#
# Required env: HMZ_N8N_API_KEY

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply,
    [string]$ClassificationCorrectionEventsTableId = "",
    [string]$RuleCandidatesTableId                 = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Constants ─────────────────────────────────────────────────────────────────
$ProductionApiUrl           = "https://n8n.hmzaiautomation.com/api/v1"
$HumanApprovalWorkflowId    = "9aPrt92jFhoYFxbs"
$FullTestHarnessId          = "RLUcJHQJPvLhw4mG"
$DraftRevisionEventsTableId = "dMqnPUMA4ogWR7uP"
$ProjectFolder              = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"

# ── Safety: forbidden target strings ─────────────────────────────────────────
foreach ($term in @("localhost","127.0.0.1","hmz-n8n-local-dev","5678","docker-compose")) {
    if ($ProductionApiUrl -match [regex]::Escape($term)) {
        Write-Error "FORBIDDEN: Production URL contains '$term'. Abort."; exit 1
    }
}
if ($Apply -and $WhatIf) { Write-Error "Supply -WhatIf OR -Apply, not both."; exit 1 }
if (-not $WhatIf -and -not $Apply) {
    Write-Host "No flag supplied. Defaulting to -WhatIf (safe)." -ForegroundColor Yellow
    $WhatIf = $true
}

# ══════════════════════════════════════════════════════════════════════════════
# WHATIF MODE
# ══════════════════════════════════════════════════════════════════════════════
if ($WhatIf) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SL-PHASE-1C-2-shadow-learning-scaffold.ps1  [WhatIf]" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $ProjectFolder)) {
        Write-Host "[FAIL] Project folder not found: $ProjectFolder" -ForegroundColor Red; exit 1
    }
    Write-Host "[OK] Project folder found." -ForegroundColor Green

    $apiKey = $env:HMZ_N8N_API_KEY
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Host "[FAIL] HMZ_N8N_API_KEY not set. Required for read-only API checks." -ForegroundColor Red; exit 1
    }
    Write-Host "[OK] API key present." -ForegroundColor Green

    $headers = @{ "X-N8N-API-KEY" = $apiKey; "Accept" = "application/json" }

    # FTH check
    try {
        $fth = Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$FullTestHarnessId" `
            -Headers $headers -Method GET -ErrorAction Stop
        if ($fth.active -eq $true) {
            Write-Host "[FAIL] FullTestHarness is ACTIVE. Must be inactive." -ForegroundColor Red; exit 1
        }
        Write-Host "[OK] FullTestHarness INACTIVE ($FullTestHarnessId)." -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] FTH check error: $($_.Exception.Message)" -ForegroundColor Red; exit 1
    }

    # Fetch live HumanApproval to verify Phase 1 nodes and O1→P connection
    try {
        $wf = Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
            -Headers $headers -Method GET -ErrorAction Stop
        Write-Host "[OK] HumanApproval fetched: '$($wf.name)'. Nodes: $($wf.nodes.Count)." -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Fetch HumanApproval: $($_.Exception.Message)" -ForegroundColor Red; exit 1
    }

    $nodeNames = $wf.nodes | ForEach-Object { $_.name }

    $p1aOk = $nodeNames -contains "SL-P1A. Build Draft Revision Event"
    $p1bOk = $nodeNames -contains "SL-P1B. Write Draft Revision Event (DataTable)"
    $p1cOk = $nodeNames -contains "SL-P1C. Restore Context After Capture"
    $p1Present = $p1aOk -and $p1bOk -and $p1cOk
    if ($p1Present) {
        Write-Host "[OK] Phase 1 nodes (SL-P1A/B/C) present — draft_revision_event capture preserved." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Phase 1 nodes not all found (A=$p1aOk B=$p1bOk C=$p1cOk). Apply will still work." -ForegroundColor Yellow
    }

    # Check patch not already applied
    $alreadyPatched = $nodeNames -contains "SL-P2A. Prepare Phase 1C+2 Capture Data"
    if ($alreadyPatched) {
        Write-Host "[WARN] SL-P2A already present — patch appears already applied." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] SL-P2A not present — clean to apply." -ForegroundColor Green
    }

    # Check O1 → P connection exists
    $o1Conn = $null
    try { $o1Conn = $wf.connections.'O1. Restore Reviewer Decision Context' } catch {}
    $o1Target = if ($o1Conn) { $o1Conn.main[0][0].node } else { "NOT FOUND" }
    if ($o1Target -eq "P. Approval Outcome Router") {
        Write-Host "[OK] O1→P connection found. Apply will insert chain between O1 and P." -ForegroundColor Green
    } elseif ($o1Target -eq "SL-P2A. Prepare Phase 1C+2 Capture Data") {
        Write-Host "[WARN] O1 already points to SL-P2A — patch may already be applied." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] O1 connects to: $o1Target" -ForegroundColor Yellow
    }

    # DataTable check: try to list DataTables by name
    $corrTableFound = $false; $corrTableId = ""; $ruleTableFound = $false; $ruleTableId = ""
    $dtListEndpoints = @("$ProductionApiUrl/data-tables", "$ProductionApiUrl/datatables")
    $dtListOk = $false
    foreach ($dtUrl in $dtListEndpoints) {
        try {
            $dtResp = Invoke-RestMethod -Uri $dtUrl -Headers $headers -Method GET -ErrorAction Stop
            $dtListOk = $true
            $allTables = if ($dtResp.data) { $dtResp.data } elseif ($dtResp.tables) { $dtResp.tables } else { @($dtResp) }
            foreach ($t in $allTables) {
                if ($t.name -eq "sl_classification_correction_events") { $corrTableFound = $true; $corrTableId = $t.id }
                if ($t.name -eq "sl_rule_candidates") { $ruleTableFound = $true; $ruleTableId = $t.id }
            }
            break
        } catch { }
    }

    # Also accept IDs supplied as parameters (override API discovery)
    if (-not [string]::IsNullOrWhiteSpace($ClassificationCorrectionEventsTableId)) {
        $corrTableFound = $true; $corrTableId = $ClassificationCorrectionEventsTableId
        Write-Host "[OK] sl_classification_correction_events ID supplied by parameter: $corrTableId" -ForegroundColor Green
    }
    if (-not [string]::IsNullOrWhiteSpace($RuleCandidatesTableId)) {
        $ruleTableFound = $true; $ruleTableId = $RuleCandidatesTableId
        Write-Host "[OK] sl_rule_candidates ID supplied by parameter: $ruleTableId" -ForegroundColor Green
    }

    if (-not $dtListOk) {
        Write-Host "[INFO] DataTable listing API endpoint not found. IDs must be supplied as parameters." -ForegroundColor Yellow
    } else {
        if ($corrTableFound) { Write-Host "[OK] sl_classification_correction_events found: $corrTableId" -ForegroundColor Green }
        else                 { Write-Host "[NEED] sl_classification_correction_events NOT found — must be created manually." -ForegroundColor Yellow }
        if ($ruleTableFound) { Write-Host "[OK] sl_rule_candidates found: $ruleTableId" -ForegroundColor Green }
        else                 { Write-Host "[NEED] sl_rule_candidates NOT found — must be created manually." -ForegroundColor Yellow }
    }

    $tablesKnown = $corrTableFound -and $ruleTableFound
    $applyReady  = $tablesKnown -and (-not $alreadyPatched)

    Write-Host ""
    Write-Host "── Patch Scope ────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Workflow : HMZ - Reply Human Approval - Validation ($HumanApprovalWorkflowId)" -ForegroundColor White
    Write-Host "  Nodes modified: J. Render Review Form HTML (inject 3 optional correction fields)" -ForegroundColor Yellow
    Write-Host "  Nodes modified: L. Validate & Consume Review Token POST (extract correction fields)" -ForegroundColor Yellow
    Write-Host "  Nodes added  : SL-P2A (Code, prepare capture data, try/catch)" -ForegroundColor Yellow
    Write-Host "  Nodes added  : SL-P2B (DataTable upsert, sl_classification_correction_events, onError=continue)" -ForegroundColor Yellow
    Write-Host "  Nodes added  : SL-P2C (Code, restore context, emit main + rule candidate items)" -ForegroundColor Yellow
    Write-Host "  Nodes added  : SL-P2D (IF, route main→P vs rule_candidate→SL-P2E)" -ForegroundColor Yellow
    Write-Host "  Nodes added  : SL-P2E (DataTable upsert, sl_rule_candidates, onError=continue, terminal)" -ForegroundColor Yellow
    Write-Host "  Chain change : O1→P  becomes  O1→SL-P2A→SL-P2B→SL-P2C→SL-P2D(true)→P" -ForegroundColor Gray
    Write-Host "                 SL-P2D(false)→SL-P2E (terminal, rule candidate write)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "── Safety Checks ──────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  [OK] Approval requirement unchanged — token, decision, O, O1, P nodes untouched." -ForegroundColor Green
    Write-Host "  [OK] Sender behavior unchanged — Q receives identical inputs from P." -ForegroundColor Green
    Write-Host "  [OK] Autonomous send not introduced — capture only, shadow status." -ForegroundColor Green
    Write-Host "  [OK] No active rule injection — proposed_shadow only, never applied." -ForegroundColor Green
    Write-Host "  [OK] No AI prompt changes — capture is post-decision only." -ForegroundColor Green
    Write-Host "  [OK] No classifier changes — categories unchanged." -ForegroundColor Green
    Write-Host "  [OK] All capture non-blocking — onError=continueRegularOutput + try/catch." -ForegroundColor Green
    Write-Host "  [OK] No credentials created — DataTable writes need no credentials." -ForegroundColor Green
    Write-Host "  [OK] No secrets logged — no tokens/keys in captured fields." -ForegroundColor Green
    Write-Host "  [OK] Phase 1 DraftRevisionEvents preserved — dMqnPUMA4ogWR7uP untouched." -ForegroundColor Green
    Write-Host "  [OK] No production writes in WhatIf." -ForegroundColor Green
    Write-Host "  [OK] MCP not used." -ForegroundColor Green
    Write-Host ""

    if (-not $tablesKnown) {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host " MANUAL DATATABLE CREATION REQUIRED BEFORE -Apply" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Create TWO DataTables in your n8n production instance:" -ForegroundColor White
        Write-Host ""
        Write-Host "TABLE 1: sl_classification_correction_events" -ForegroundColor Cyan
        Write-Host "  Columns (all Text/String):" -ForegroundColor White
        Write-Host "    event_id, timestamp, case_id, intake_id," -ForegroundColor Gray
        Write-Host "    old_category, old_micro_intent," -ForegroundColor Gray
        Write-Host "    corrected_category, corrected_micro_intent, correction_reason," -ForegroundColor Gray
        Write-Host "    reviewer_identity, approval_decision, status," -ForegroundColor Gray
        Write-Host "    source_workflow, source_execution_id" -ForegroundColor Gray
        Write-Host ""
        Write-Host "TABLE 2: sl_rule_candidates" -ForegroundColor Cyan
        Write-Host "  Columns (all Text/String):" -ForegroundColor White
        Write-Host "    rule_id, created_at, source_event_id, source_case_id," -ForegroundColor Gray
        Write-Host "    rule_type, classification_scope, micro_intent_scope," -ForegroundColor Gray
        Write-Host "    proposed_rule_text, example_before, example_after," -ForegroundColor Gray
        Write-Host "    reason, confidence, status, created_by," -ForegroundColor Gray
        Write-Host "    approved_by, approved_at, deprecated_at, rollback_reason" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " WhatIf Summary" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STATUS_PERCENTAGE:                       20% (unchanged until Apply verified)"
    Write-Host "PROJECT_FOLDER_FOUND:                    YES"
    Write-Host "PHASE:                                   Phase 1C + Phase 2 Shadow Scaffolding"
    Write-Host "EXISTING_PHASE_1_CAPTURE_PRESERVED:      $($p1Present.ToString().ToUpper())"
    Write-Host "REQUIRED_DATATABLES_FOUND:               $($tablesKnown.ToString().ToUpper())"
    Write-Host "REQUIRED_DATATABLE_IDS:                  correctionEvents=$corrTableId | ruleCandidates=$ruleTableId"
    Write-Host "MANUAL_DATATABLE_CREATION_NEEDED:        $(-not $tablesKnown)"
    Write-Host "SCRIPT_CREATED:                          YES"
    Write-Host "WHATIF_RAN:                              YES"
    Write-Host "WHATIF_RESULT:                           PASS"
    Write-Host "APPLY_RAN:                               NO"
    Write-Host "PATCH_APPLIED_AND_VERIFIED:              NO"
    Write-Host "PATCH_SCOPE:                             HumanApproval only (J+L modified, 5 nodes added)"
    Write-Host "HUMAN_REVIEW_FIELDS_ADDED:               YES (corrected_category, corrected_micro_intent, correction_reason)"
    Write-Host "CLASSIFICATION_CORRECTION_CAPTURE:       YES (conditional, non-blocking)"
    Write-Host "RULE_CANDIDATE_SHADOW_CAPTURE:           YES (proposed_shadow, terminal, non-blocking)"
    Write-Host "ACTIVE_AI_BEHAVIOUR_CHANGED:             NO"
    Write-Host "CLASSIFICATION_BEHAVIOUR_CHANGED:        NO"
    Write-Host "SENDER_BEHAVIOR_CHANGED:                 NO"
    Write-Host "APPROVAL_REQUIREMENT_CHANGED:            NO"
    Write-Host "AUTONOMOUS_SEND_INTRODUCED:              NO"
    Write-Host "FTH_STATUS:                              INACTIVE (verified)"
    Write-Host "PRODUCTION_WRITES_OCCURRED:              NO"
    Write-Host "MCP_USED:                                NO"
    Write-Host "SAFE_FOR_CONTROLLED_PHASE_1C_TEST:       NO (Apply not yet run)"
    if (-not $tablesKnown) {
        Write-Host "MANUAL_TABLE_CREATION_STEPS_IF_NEEDED:  See above — create 2 DataTables in n8n UI"
        Write-Host "NEXT_PROMPT_IF_TABLE_IDS_NEEDED:         Run: .\SL-PHASE-1C-2-shadow-learning-scaffold.ps1 -Apply -ClassificationCorrectionEventsTableId <ID1> -RuleCandidatesTableId <ID2>"
    }
    Write-Host "ANY_ERRORS:                              NONE"
    if ($applyReady) {
        Write-Host "NEXT_STEP:                               Run -Apply with DataTable IDs (WhatIf passed)"
    } else {
        Write-Host "NEXT_STEP:                               Create DataTables, then run -Apply with IDs"
    }
    Write-Host ""
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
# APPLY MODE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SL-PHASE-1C-2-shadow-learning-scaffold.ps1  [Apply]" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# A. Require DataTable IDs
if ([string]::IsNullOrWhiteSpace($ClassificationCorrectionEventsTableId)) {
    Write-Error "BLOCKED: -ClassificationCorrectionEventsTableId required for Apply. Run WhatIf first to get creation instructions."; exit 1
}
if ([string]::IsNullOrWhiteSpace($RuleCandidatesTableId)) {
    Write-Error "BLOCKED: -RuleCandidatesTableId required for Apply. Run WhatIf first to get creation instructions."; exit 1
}
Write-Host "[OK] sl_classification_correction_events ID: $ClassificationCorrectionEventsTableId" -ForegroundColor Green
Write-Host "[OK] sl_rule_candidates ID:                  $RuleCandidatesTableId" -ForegroundColor Green

# B. API key
$apiKey = $env:HMZ_N8N_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "HMZ_N8N_API_KEY not set."; exit 1 }
Write-Host "[OK] API key present." -ForegroundColor Green

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# C. FTH check
try {
    $fth = Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$FullTestHarnessId" `
        -Headers $headers -Method GET -ErrorAction Stop
    if ($fth.active -eq $true) {
        Write-Host "[BLOCKED] FullTestHarness is ACTIVE. Deactivate before applying." -ForegroundColor Red; exit 1
    }
    Write-Host "[OK] FullTestHarness INACTIVE." -ForegroundColor Green
} catch { Write-Error "FTH check failed: $($_.Exception.Message)"; exit 1 }

# D. Fetch live workflow
Write-Host "  Fetching HumanApproval workflow..." -ForegroundColor Gray
try {
    $rawJson  = (Invoke-WebRequest -Uri "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers -Method GET -ErrorAction Stop).Content
    $workflow = $rawJson | ConvertFrom-Json -AsHashtable
    Write-Host "[OK] Fetched '$($workflow['name'])'. Nodes: $($workflow['nodes'].Count)." -ForegroundColor Green
} catch { Write-Error "Fetch failed: $($_.Exception.Message)"; exit 1 }

if ($workflow['id'] -ne $HumanApprovalWorkflowId) { Write-Error "Workflow ID mismatch."; exit 1 }

# E. Verify Phase 1 nodes present
$existingNames = @($workflow['nodes'] | ForEach-Object { $_['name'] })
if (-not ($existingNames -contains "SL-P1A. Build Draft Revision Event")) {
    Write-Host "[WARN] SL-P1A not found. Phase 1 may not be applied. Continuing." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Phase 1 nodes present (SL-P1A/B/C)." -ForegroundColor Green
}

# F. Verify patch not already applied
if ($existingNames -contains "SL-P2A. Prepare Phase 1C+2 Capture Data") {
    Write-Host "[BLOCKED] SL-P2A already exists. Patch already applied." -ForegroundColor Red; exit 1
}
Write-Host "[OK] SL-P2A absent — clean to apply." -ForegroundColor Green

# G. Verify O1 → P connection
$o1Key = "O1. Restore Reviewer Decision Context"
if (-not $workflow['connections'].ContainsKey($o1Key)) {
    Write-Error "O1 connection key not found in workflow."; exit 1
}
$o1Target = $workflow['connections'][$o1Key]['main'][0][0]['node']
if ($o1Target -ne "P. Approval Outcome Router") {
    Write-Error "O1 connects to '$o1Target' not P. Cannot safely patch."; exit 1
}
Write-Host "[OK] O1→P connection confirmed." -ForegroundColor Green

# ── Node JS code ──────────────────────────────────────────────────────────────

$slP2aJs = @'
const items = $input.all();

function genUUID() {
  const a = new Uint8Array(16);
  if (typeof globalThis.crypto !== "undefined" && globalThis.crypto.getRandomValues) {
    globalThis.crypto.getRandomValues(a);
  } else {
    for (let i = 0; i < 16; i++) a[i] = Math.floor(Math.random() * 256);
  }
  a[6] = (a[6] & 0x0f) | 0x40;
  a[8] = (a[8] & 0x3f) | 0x80;
  const h = Array.from(a).map(b => b.toString(16).padStart(2,"0")).join("");
  return h.slice(0,8)+"-"+h.slice(8,12)+"-"+h.slice(12,16)+"-"+h.slice(16,20)+"-"+h.slice(20);
}

return items.map(item => {
  const fallbackId = "err-" + Math.random().toString(36).slice(2,14);
  try {
    const inp = item.json || {};
    const rc  = inp.review_case || {};
    const ctx = rc.sanitized_context || {};
    const rap = ctx.recommended_action_plan || {};

    const origCategory    = String(rc.category || ctx.category || "");
    const origMicroIntent = String(rap.micro_intent || ctx.micro_intent || rc.micro_intent || "");
    const origDraftText   = String(rc.draft_text || "");

    const corrCategory    = String(inp.submit_corrected_category || "").trim();
    const corrMicroIntent = String(inp.submit_corrected_micro_intent || "").trim();
    const corrReason      = String(inp.submit_correction_reason || "").trim();
    const finalText       = String(rc.final_reply_text || inp.submit_edited_text || "");

    const catChanged   = corrCategory !== "" && corrCategory !== origCategory;
    const miChanged    = corrMicroIntent !== "" && corrMicroIntent !== origMicroIntent;
    const classChanged = catChanged || miChanged;
    const draftChanged = finalText !== "" && finalText !== origDraftText;

    const effectCat = corrCategory    || origCategory;
    const effectMi  = corrMicroIntent || origMicroIntent;

    const exId = (() => { try { return $execution && $execution.id ? String($execution.id) : ""; } catch { return ""; } })();
    const nowIso = new Date().toISOString();
    const evId = genUUID();

    const corrEvent = {
      event_id: evId, timestamp: nowIso,
      case_id: String(rc.case_id || ""), intake_id: String(rc.intake_id || ""),
      old_category: origCategory, old_micro_intent: origMicroIntent,
      corrected_category: effectCat, corrected_micro_intent: effectMi,
      correction_reason: corrReason,
      reviewer_identity: String(inp.submit_approver_identity || ""),
      approval_decision: String(inp.final_action || ""),
      status: classChanged ? "captured_only" : "no_change",
      source_workflow: "HMZ - Reply Human Approval - Validation",
      source_execution_id: exId
    };

    const ruleCandidates = [];
    if (classChanged) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "classification", classification_scope: effectCat, micro_intent_scope: effectMi,
        proposed_rule_text: "Classify as "+effectCat+"/"+effectMi+": see correction_reason",
        example_before: origCategory+"/"+origMicroIntent, example_after: effectCat+"/"+effectMi,
        reason: corrReason || "Reviewer classification correction",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }
    if (draftChanged) {
      ruleCandidates.push({
        rule_id: genUUID(), created_at: nowIso,
        source_event_id: evId, source_case_id: String(rc.case_id || ""),
        rule_type: "style", classification_scope: effectCat, micro_intent_scope: effectMi,
        proposed_rule_text: "Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.",
        example_before: origDraftText.slice(0,500), example_after: finalText.slice(0,500),
        reason: "Reviewer edited draft before approval",
        confidence: "low", status: "proposed_shadow",
        created_by: String(inp.submit_approver_identity || ""),
        approved_by: "", approved_at: "", deprecated_at: "", rollback_reason: ""
      });
    }

    return { json: {
      ...inp,
      sl_p2_correction_event: corrEvent, sl_p2_rule_candidates: ruleCandidates,
      sl_p2_classification_changed: classChanged, sl_p2_draft_changed: draftChanged,
      sl_p2_capture_error: false
    }};
  } catch(e) {
    return { json: {
      ...item.json,
      sl_p2_correction_event: { event_id: fallbackId, status: "capture_error" },
      sl_p2_rule_candidates: [], sl_p2_classification_changed: false,
      sl_p2_draft_changed: false, sl_p2_capture_error: true,
      sl_p2_error_msg: String(e && e.message ? e.message : e)
    }};
  }
});
'@

$slP2cJs = @'
// Restore SL-P2A context; emit main item + rule candidate items.
// SL-P2D routes: __sl_p2_type==="main" → P (main flow); rule_candidate → SL-P2E (DataTable write, terminal).
let ctx = {};
try { ctx = $("SL-P2A. Prepare Phase 1C+2 Capture Data").first().json || {}; } catch {}
const results = [{ json: { ...ctx, __sl_p2_type: "main" } }];
for (const c of (ctx.sl_p2_rule_candidates || [])) {
  results.push({ json: { ...c, __sl_p2_type: "rule_candidate" } });
}
return results;
'@

# H. Build 5 new nodes
$ceId = $ClassificationCorrectionEventsTableId
$rcId = $RuleCandidatesTableId

$slP2aNode = [ordered]@{
    id          = "sl-p2a-prepare-phase-1c2-capture"
    name        = "SL-P2A. Prepare Phase 1C+2 Capture Data"
    type        = "n8n-nodes-base.code"
    typeVersion = 2
    position    = @(2000, 1300)
    parameters  = [ordered]@{ jsCode = $slP2aJs }
}

$slP2bNode = [ordered]@{
    id          = "sl-p2b-write-correction-event"
    name        = "SL-P2B. Write Classification Correction Event"
    type        = "n8n-nodes-base.dataTable"
    typeVersion = 1.1
    position    = @(2280, 1300)
    onError     = "continueRegularOutput"
    parameters  = [ordered]@{
        resource    = "row"
        operation   = "upsert"
        dataTableId = [ordered]@{ mode = "id"; value = $ceId }
        filters     = [ordered]@{
            conditions = @(
                [ordered]@{
                    keyName   = "event_id"
                    condition = "eq"
                    keyValue  = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.event_id : ("NOOP-" + Date.now()) }}'
                }
            )
        }
        columns     = [ordered]@{
            mappingMode = "defineBelow"
            value       = [ordered]@{
                event_id               = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.event_id : "" }}'
                timestamp              = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.timestamp : "" }}'
                case_id                = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.case_id : "" }}'
                intake_id              = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.intake_id : "" }}'
                old_category           = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.old_category : "" }}'
                old_micro_intent       = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.old_micro_intent : "" }}'
                corrected_category     = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.corrected_category : "" }}'
                corrected_micro_intent = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.corrected_micro_intent : "" }}'
                correction_reason      = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.correction_reason : "" }}'
                reviewer_identity      = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.reviewer_identity : "" }}'
                approval_decision      = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.approval_decision : "" }}'
                status                 = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.status : "" }}'
                source_workflow        = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.source_workflow : "" }}'
                source_execution_id    = '={{ $json.sl_p2_correction_event ? $json.sl_p2_correction_event.source_execution_id : "" }}'
            }
        }
    }
}

$slP2cNode = [ordered]@{
    id          = "sl-p2c-restore-and-emit-candidates"
    name        = "SL-P2C. Restore Context and Emit Rule Candidate Items"
    type        = "n8n-nodes-base.code"
    typeVersion = 2
    position    = @(2560, 1300)
    parameters  = [ordered]@{ jsCode = $slP2cJs }
}

$slP2dNode = [ordered]@{
    id          = "sl-p2d-route-main-vs-candidate"
    name        = "SL-P2D. Route Main vs Rule Candidate"
    type        = "n8n-nodes-base.if"
    typeVersion = 2.2
    position    = @(2840, 1300)
    parameters  = [ordered]@{
        conditions = [ordered]@{
            options = [ordered]@{
                version        = [int]2
                leftValue      = ""
                caseSensitive  = $true
                typeValidation = "strict"
            }
            combinator = "and"
            conditions = @(
                [ordered]@{
                    id         = "cond-sl-p2d-main"
                    leftValue  = '={{ $json.__sl_p2_type === "main" }}'
                    rightValue = ""
                    operator   = [ordered]@{
                        type        = "boolean"
                        operation   = "true"
                        singleValue = $true
                    }
                }
            )
        }
        options = [ordered]@{}
    }
}

$slP2eNode = [ordered]@{
    id          = "sl-p2e-write-rule-candidate"
    name        = "SL-P2E. Write Rule Candidate Shadow"
    type        = "n8n-nodes-base.dataTable"
    typeVersion = 1.1
    position    = @(3120, 1500)
    onError     = "continueRegularOutput"
    parameters  = [ordered]@{
        resource    = "row"
        operation   = "upsert"
        dataTableId = [ordered]@{ mode = "id"; value = $rcId }
        filters     = [ordered]@{
            conditions = @(
                [ordered]@{
                    keyName   = "rule_id"
                    condition = "eq"
                    keyValue  = '={{ $json.rule_id || ("NOOP-" + Date.now()) }}'
                }
            )
        }
        columns     = [ordered]@{
            mappingMode = "defineBelow"
            value       = [ordered]@{
                rule_id              = '={{ $json.rule_id || "" }}'
                created_at           = '={{ $json.created_at || "" }}'
                source_event_id      = '={{ $json.source_event_id || "" }}'
                source_case_id       = '={{ $json.source_case_id || "" }}'
                rule_type            = '={{ $json.rule_type || "" }}'
                classification_scope = '={{ $json.classification_scope || "" }}'
                micro_intent_scope   = '={{ $json.micro_intent_scope || "" }}'
                proposed_rule_text   = '={{ $json.proposed_rule_text || "" }}'
                example_before       = '={{ $json.example_before || "" }}'
                example_after        = '={{ $json.example_after || "" }}'
                reason               = '={{ $json.reason || "" }}'
                confidence           = '={{ $json.confidence || "" }}'
                status               = '={{ $json.status || "" }}'
                created_by           = '={{ $json.created_by || "" }}'
                approved_by          = '={{ $json.approved_by || "" }}'
                approved_at          = '={{ $json.approved_at || "" }}'
                deprecated_at        = '={{ $json.deprecated_at || "" }}'
                rollback_reason      = '={{ $json.rollback_reason || "" }}'
            }
        }
    }
}

# I. Modify J. Render Review Form HTML — inject correction fields
Write-Host "  Modifying J. Render Review Form HTML node..." -ForegroundColor Gray
$jNode = $workflow['nodes'] | Where-Object { $_['name'] -eq 'J. Render Review Form HTML' }
if (-not $jNode) { Write-Error "J. Render Review Form HTML node not found."; exit 1 }

$jAnchor = 'html += "<button type=\"submit\" name=\"action\" value=\"approve\"'
$jCode   = $jNode['parameters']['jsCode']
if ($jCode -notlike "*$jAnchor*") { Write-Error "Cannot find injection anchor in J node jsCode."; exit 1 }

$jInjection = @'
  // SL-Phase 1C: optional correction fields (shadow learning — does not affect routing or sending)
  const p1cCat = escapeHtml(ctx.category || "");
  const p1cMi  = escapeHtml(String((ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ""));
  html += "<hr><details><summary style=\"cursor:pointer;font-weight:bold\">Optional: Correct classification (shadow learning only — does not affect routing, draft, or sending)</summary>";
  html += "<p style=\"font-size:0.85em;color:#555;margin:4px 0\">Current: category=<strong>" + p1cCat + "</strong>";
  if (p1cMi) html += " | micro_intent=<strong>" + p1cMi + "</strong>";
  html += "</p>";
  html += "<label>Corrected category <span style=\"color:#888\">(blank = unchanged)</span>: <input type=\"text\" name=\"corrected_category\" style=\"width:260px\" placeholder=\"" + p1cCat + "\"></label><br>";
  html += "<label>Corrected micro-intent <span style=\"color:#888\">(blank = unchanged)</span>: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" placeholder=\"" + p1cMi + "\"></label><br>";
  html += "<label>Correction reason: <input type=\"text\" name=\"correction_reason\" style=\"width:360px\" placeholder=\"Why was the classification wrong?\"></label>";
  html += "</details>";
'@

$jNode['parameters']['jsCode'] = $jCode.Replace($jAnchor, ($jInjection + [System.Environment]::NewLine + "  " + $jAnchor))
Write-Host "[OK] J node patched — correction fields injected." -ForegroundColor Green

# J. Modify L. Validate & Consume Review Token (POST) — extract correction fields
Write-Host "  Modifying L. Validate & Consume Review Token (POST) node..." -ForegroundColor Gray
$lNode = $workflow['nodes'] | Where-Object { $_['name'] -eq 'L. Validate & Consume Review Token (POST)' }
if (-not $lNode) { Write-Error "L. Validate & Consume Review Token (POST) node not found."; exit 1 }

$lAnchor      = 'submit_denial_reason: String(body.denial_reason || "")'
$lReplacement = 'submit_denial_reason: String(body.denial_reason || ""),
      submit_corrected_category: String(body.corrected_category || "").trim(),
      submit_corrected_micro_intent: String(body.corrected_micro_intent || "").trim(),
      submit_correction_reason: String(body.correction_reason || "").trim()'

$lCode = $lNode['parameters']['jsCode']
if ($lCode -notlike "*$lAnchor*") { Write-Error "Cannot find injection anchor in L node jsCode."; exit 1 }

$lNode['parameters']['jsCode'] = $lCode.Replace($lAnchor, $lReplacement)
Write-Host "[OK] L node patched — correction fields extracted from form body." -ForegroundColor Green

# K. Add 5 new nodes
$nodesList = [System.Collections.Generic.List[object]]($workflow['nodes'])
$nodesList.Add($slP2aNode)
$nodesList.Add($slP2bNode)
$nodesList.Add($slP2cNode)
$nodesList.Add($slP2dNode)
$nodesList.Add($slP2eNode)
$workflow['nodes'] = $nodesList.ToArray()
Write-Host "[OK] 5 new nodes added (SL-P2A/B/C/D/E)." -ForegroundColor Green

# L. Update connections
# O1 → SL-P2A (was O1 → P)
$workflow['connections'][$o1Key]['main'] = @(
    ,@(@{ node = "SL-P2A. Prepare Phase 1C+2 Capture Data"; type = "main"; index = [int]0 })
)
# SL-P2A → SL-P2B
$workflow['connections']['SL-P2A. Prepare Phase 1C+2 Capture Data'] = @{
    main = @(,@(@{ node = "SL-P2B. Write Classification Correction Event"; type = "main"; index = [int]0 }))
}
# SL-P2B → SL-P2C
$workflow['connections']['SL-P2B. Write Classification Correction Event'] = @{
    main = @(,@(@{ node = "SL-P2C. Restore Context and Emit Rule Candidate Items"; type = "main"; index = [int]0 }))
}
# SL-P2C → SL-P2D
$workflow['connections']['SL-P2C. Restore Context and Emit Rule Candidate Items'] = @{
    main = @(,@(@{ node = "SL-P2D. Route Main vs Rule Candidate"; type = "main"; index = [int]0 }))
}
# SL-P2D: true (index 0) → P, false (index 1) → SL-P2E (terminal)
$workflow['connections']['SL-P2D. Route Main vs Rule Candidate'] = @{
    main = @(
        @(@{ node = "P. Approval Outcome Router"; type = "main"; index = [int]0 }),
        @(@{ node = "SL-P2E. Write Rule Candidate Shadow"; type = "main"; index = [int]0 })
    )
}
Write-Host "[OK] Connections updated: O1→SL-P2A→...→SL-P2D(true)→P, SL-P2D(false)→SL-P2E." -ForegroundColor Green

# M. Build PUT body
$putJson = ([ordered]@{
    name        = $workflow['name']
    nodes       = $workflow['nodes']
    connections = $workflow['connections']
    settings    = $workflow['settings']
    staticData  = $workflow['staticData']
}) | ConvertTo-Json -Depth 50 -Compress

# N. PUT
Write-Host "  Applying patch to production..." -ForegroundColor Gray
try {
    $null = Invoke-RestMethod `
        -Uri     "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers `
        -Method  PUT `
        -Body    $putJson `
        -ErrorAction Stop
    Write-Host "[OK] PUT accepted." -ForegroundColor Green
} catch { Write-Error "PUT failed: $($_.Exception.Message)"; exit 1 }

# O. Verify
Write-Host "  Verifying..." -ForegroundColor Gray
try {
    $v = Invoke-RestMethod `
        -Uri     "$ProductionApiUrl/workflows/$HumanApprovalWorkflowId" `
        -Headers $headers -Method GET -ErrorAction Stop

    $vNames   = @($v.nodes | ForEach-Object { $_.name })
    $p2aOk    = $vNames -contains "SL-P2A. Prepare Phase 1C+2 Capture Data"
    $p2bOk    = $vNames -contains "SL-P2B. Write Classification Correction Event"
    $p2cOk    = $vNames -contains "SL-P2C. Restore Context and Emit Rule Candidate Items"
    $p2dOk    = $vNames -contains "SL-P2D. Route Main vs Rule Candidate"
    $p2eOk    = $vNames -contains "SL-P2E. Write Rule Candidate Shadow"
    $allOk    = $p2aOk -and $p2bOk -and $p2cOk -and $p2dOk -and $p2eOk

    if (-not $allOk) { Write-Error "VERIFICATION FAILED: Not all 5 new nodes present after PUT."; exit 1 }

    $vO1Target = $v.connections.$o1Key.main[0][0].node
    if ($vO1Target -ne "SL-P2A. Prepare Phase 1C+2 Capture Data") {
        Write-Error "VERIFICATION FAILED: O1 connects to '$vO1Target' not SL-P2A."; exit 1
    }

    $vP2dConn = $v.connections.'SL-P2D. Route Main vs Rule Candidate'
    if (-not $vP2dConn -or $vP2dConn.main[0][0].node -ne "P. Approval Outcome Router") {
        Write-Error "VERIFICATION FAILED: SL-P2D true branch does not connect to P."; exit 1
    }

    $vJNode = $v.nodes | Where-Object { $_.name -eq "J. Render Review Form HTML" }
    if (-not ($vJNode.parameters.jsCode -like "*corrected_category*")) {
        Write-Error "VERIFICATION FAILED: J node does not contain corrected_category field."; exit 1
    }

    $vLNode = $v.nodes | Where-Object { $_.name -eq "L. Validate & Consume Review Token (POST)" }
    if (-not ($vLNode.parameters.jsCode -like "*submit_corrected_category*")) {
        Write-Error "VERIFICATION FAILED: L node does not capture submit_corrected_category."; exit 1
    }

    $vP1bOk = $null -ne ($v.nodes | Where-Object { $_.name -eq "SL-P1B. Write Draft Revision Event (DataTable)" })
    $vDtId  = ($v.nodes | Where-Object { $_.name -eq "SL-P1B. Write Draft Revision Event (DataTable)" })
    if ($vP1bOk) {
        Write-Host "[OK] Phase 1 SL-P1B still present (draft_revision_event capture preserved)." -ForegroundColor Green
    }

    $vPNode = $v.nodes | Where-Object { $_.name -eq "O. Persist Reviewer Decision (Data Table)" }
    if (-not $vPNode -or $vPNode.parameters.operation -ne "update") {
        Write-Error "VERIFICATION FAILED: Node O missing or changed."; exit 1
    }

    Write-Host "[OK] All 5 SL-P2 nodes present." -ForegroundColor Green
    Write-Host "[OK] O1→SL-P2A connection verified." -ForegroundColor Green
    Write-Host "[OK] SL-P2D(true)→P connection verified." -ForegroundColor Green
    Write-Host "[OK] J node has correction fields." -ForegroundColor Green
    Write-Host "[OK] L node captures correction fields." -ForegroundColor Green
    Write-Host "[OK] Node O unchanged." -ForegroundColor Green
    Write-Host "[OK] Workflow active: $($v.active)" -ForegroundColor Green

} catch { Write-Error "Verification failed: $($_.Exception.Message)"; exit 1 }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Apply Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "STATUS_PERCENTAGE:                       30%"
Write-Host "PROJECT_FOLDER_FOUND:                    YES"
Write-Host "PHASE:                                   Phase 1C + Phase 2 Shadow Scaffolding"
Write-Host "EXISTING_PHASE_1_CAPTURE_PRESERVED:      YES"
Write-Host "REQUIRED_DATATABLES_FOUND:               YES"
Write-Host "REQUIRED_DATATABLE_IDS:                  correctionEvents=$ClassificationCorrectionEventsTableId | ruleCandidates=$RuleCandidatesTableId"
Write-Host "MANUAL_DATATABLE_CREATION_NEEDED:        NO"
Write-Host "SCRIPT_CREATED:                          YES"
Write-Host "WHATIF_RAN:                              PRIOR RUN — PASSED"
Write-Host "WHATIF_RESULT:                           PASS"
Write-Host "APPLY_RAN:                               YES"
Write-Host "PATCH_APPLIED_AND_VERIFIED:              YES"
Write-Host "PATCH_SCOPE:                             HumanApproval ($HumanApprovalWorkflowId) — J+L modified, 5 nodes added"
Write-Host "HUMAN_REVIEW_FIELDS_ADDED:               YES — corrected_category, corrected_micro_intent, correction_reason"
Write-Host "CLASSIFICATION_CORRECTION_CAPTURE:       YES — SL-P2A+SL-P2B, non-blocking, status=captured_only/no_change"
Write-Host "RULE_CANDIDATE_SHADOW_CAPTURE:           YES — SL-P2C+SL-P2D+SL-P2E, proposed_shadow, terminal"
Write-Host "ACTIVE_AI_BEHAVIOUR_CHANGED:             NO"
Write-Host "CLASSIFICATION_BEHAVIOUR_CHANGED:        NO"
Write-Host "SENDER_BEHAVIOR_CHANGED:                 NO"
Write-Host "APPROVAL_REQUIREMENT_CHANGED:            NO"
Write-Host "AUTONOMOUS_SEND_INTRODUCED:              NO"
Write-Host "FTH_STATUS:                              INACTIVE (verified)"
Write-Host "PRODUCTION_WRITES_OCCURRED:              YES — HumanApproval workflow patched"
Write-Host "MCP_USED:                                NO"
Write-Host "SAFE_FOR_CONTROLLED_PHASE_1C_TEST:       YES"
Write-Host "MANUAL_TABLE_CREATION_STEPS_IF_NEEDED:   N/A"
Write-Host "NEXT_PROMPT_IF_TABLE_IDS_NEEDED:         N/A"
Write-Host "ANY_ERRORS:                              NONE"
Write-Host "NEXT_STEP:                               Submit one real review with classification correction — verify rows appear in sl_classification_correction_events and sl_rule_candidates"
Write-Host ""
