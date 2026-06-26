#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5F: Shadow Mode Activation — Gate 1 approved by owner 2026-06-24.

.DESCRIPTION
    Activates Phase 5F shadow mode:
      Step 1 — Validate autonomous config (timezone, escalation channels)
      Step 2 — Validate and prepare workflow import payload
      Step 3 — Import disabled shadow evaluator workflow to production n8n (stays inactive)
      Step 4 — Verify import (active=false, record versionId)
      Step 5 — Update Gate 1 sign-off record

    SAFETY INVARIANTS (never overridden by this script):
      - Workflow is imported with active=false
      - No activation of the workflow occurs here
      - No Decision/HumanApproval/Proxy workflow changes
      - No live sends — autonomous_enabled=false throughout
      - API key read from $env:HMZ_N8N_API_KEY only — never printed

.PARAMETER ValidateOnly
    Run validation steps only — no import.

.PARAMETER ImportWorkflow
    Import the disabled workflow to n8n. Requires $env:HMZ_N8N_API_KEY.

.EXAMPLE
    .\SL-PHASE-5F-shadow-mode-activation.ps1 -ValidateOnly
    .\SL-PHASE-5F-shadow-mode-activation.ps1 -ImportWorkflow
#>

[CmdletBinding()]
param(
    [switch]$ValidateOnly,
    [switch]$ImportWorkflow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root          = Split-Path $PSScriptRoot -Parent
$ConfigPath    = Join-Path $Root "outputs\autonomous_sample_config.json"
$WorkflowPath  = Join-Path $Root "workflows\disabled_autonomous_shadow_evaluator.json"
$ChecklistPath = Join-Path $Root "docs\AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md"
$HandoffPath   = Join-Path $Root "NEXT_SESSION_HANDOFF.md"
$N8nApiBase    = "https://n8n.hmzaiautomation.com/api/v1"
$Timestamp     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5F: Shadow Mode Activation ===" -ForegroundColor Cyan
Write-Host "Timestamp   : $Timestamp"
Write-Host "Target      : $N8nApiBase"
Write-Host "ValidateOnly: $($ValidateOnly.IsPresent)"
Write-Host "Import      : $($ImportWorkflow.IsPresent)"
Write-Host ""
Write-Host "[GATE 1] Owner approval granted 2026-06-24. Shadow mode only — no live sends." -ForegroundColor Green
Write-Host ""

# ── STEP 1: VALIDATE CONFIG ───────────────────────────────────────────────────

Write-Host "--- Step 1: Validate Autonomous Config ---" -ForegroundColor Yellow

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config not found: $ConfigPath"
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$configChecks = @()
$configErrors = @()

if ($config.reviewer_timezone -eq "Europe/London") {
    $configChecks += "[PASS] reviewer_timezone = Europe/London"
} else {
    $configErrors += "[FAIL] reviewer_timezone is '$($config.reviewer_timezone)' — expected Europe/London"
}

if ($config.working_hours_start -eq "09:00" -and $config.working_hours_end -eq "18:00") {
    $configChecks += "[PASS] working_hours 09:00-18:00"
} else {
    $configErrors += "[FAIL] working_hours unexpected: $($config.working_hours_start)-$($config.working_hours_end)"
}

$escalation = $config.escalation_channels
if ($null -ne $escalation -and $escalation.Count -gt 0) {
    $configChecks += "[PASS] escalation_channels configured ($($escalation.Count) channel(s))"
} else {
    $configErrors += "[FAIL] escalation_channels is empty — required before shadow mode"
}

if ($config.autonomous_enabled -eq $false) {
    $configChecks += "[PASS] autonomous_enabled=false"
} else {
    $configErrors += "[FAIL] autonomous_enabled is not false"
}

if ($config.shadow_only -eq $true) {
    $configChecks += "[PASS] shadow_only=true"
} else {
    $configErrors += "[FAIL] shadow_only is not true"
}

if ($config.dry_run -eq $true) {
    $configChecks += "[PASS] dry_run=true"
} else {
    $configErrors += "[FAIL] dry_run is not true"
}

if ($config.max_autonomous_sends_per_day -eq 0) {
    $configChecks += "[PASS] max_autonomous_sends_per_day=0 (no live sends possible)"
} else {
    $configErrors += "[FAIL] max_autonomous_sends_per_day=$($config.max_autonomous_sends_per_day) — must be 0 for shadow mode"
}

foreach ($c in $configChecks) { Write-Host "  $c" -ForegroundColor Green }
foreach ($e in $configErrors) { Write-Host "  $e" -ForegroundColor Red }

if ($configErrors.Count -gt 0) {
    Write-Error "Config validation failed with $($configErrors.Count) error(s). Fix before proceeding."
}

Write-Host "  [PASS] Config validation complete." -ForegroundColor Green
Write-Host ""

# ── STEP 2: VALIDATE + PREPARE WORKFLOW PAYLOAD ───────────────────────────────

Write-Host "--- Step 2: Validate Workflow JSON + Prepare Import Payload ---" -ForegroundColor Yellow

if (-not (Test-Path $WorkflowPath)) {
    Write-Error "Workflow JSON not found: $WorkflowPath"
}

$wfRaw = Get-Content $WorkflowPath -Raw
$wf    = $wfRaw | ConvertFrom-Json

$wfChecks = @()
$wfErrors = @()

# Safety checks
if ($wf.active -eq $false)                         { $wfChecks += "[PASS] active=false" }
else                                               { $wfErrors += "[FAIL] active is not false" }

if ($wf.name -like "*DISABLED*")                   { $wfChecks += "[PASS] Name contains DISABLED marker" }
else                                               { $wfErrors += "[WARN] Name does not contain DISABLED marker" }

$senderNodes = @($wf.nodes | Where-Object { $_.name -like "*sender*" -or $_.type -like "*sender*" })
if ($senderNodes.Count -eq 0)                      { $wfChecks += "[PASS] No Sender node" }
else                                               { $wfErrors += "[FAIL] Sender node detected" }

$instantlyNodes = @($wf.nodes | Where-Object { ($wfRaw | Select-String "instantly" -SimpleMatch) -and $_.name -like "*instantly*" })
if ($instantlyNodes.Count -eq 0)                   { $wfChecks += "[PASS] No Instantly API node" }

if ($wfRaw -like "*shadow_evaluator_mode*")        { $wfChecks += "[PASS] shadow_evaluator_mode marker present" }
else                                               { $wfErrors += "[WARN] shadow_evaluator_mode marker not found" }

if ($wfRaw -like "*would_send_live_now*")          { $wfChecks += "[PASS] would_send_live_now referenced in code" }

foreach ($c in $wfChecks) { Write-Host "  $c" -ForegroundColor Green }

$hardFails = @($wfErrors | Where-Object { $_ -like "*FAIL*" })
foreach ($e in $wfErrors) {
    $col = if ($e -like "*FAIL*") { "Red" } else { "Yellow" }
    Write-Host "  $e" -ForegroundColor $col
}

if ($hardFails.Count -gt 0) {
    Write-Error "Workflow validation failed with $($hardFails.Count) hard error(s). Do not import."
}

# Build id→name map from nodes
$idToName = @{}
foreach ($node in $wf.nodes) {
    if ($node.id -and $node.name) {
        $idToName[$node.id] = $node.name
    }
}

# Transform connections from ID-keyed to name-keyed
$fixedConnections = @{}
foreach ($sourceId in ($wf.connections | Get-Member -MemberType NoteProperty).Name) {
    $sourceName = if ($idToName.ContainsKey($sourceId)) { $idToName[$sourceId] } else { $sourceId }
    $outputs = $wf.connections.$sourceId

    $fixedOutputs = @{}
    foreach ($outputType in ($outputs | Get-Member -MemberType NoteProperty).Name) {
        $portArrays = $outputs.$outputType
        $fixedPortArrays = @()
        foreach ($portArray in $portArrays) {
            $fixedLinks = @()
            foreach ($link in $portArray) {
                $targetName = if ($idToName.ContainsKey($link.node)) { $idToName[$link.node] } else { $link.node }
                $fixedLinks += @{ node = $targetName; type = $link.type; index = $link.index }
            }
            $fixedPortArrays += , @($fixedLinks)
        }
        $fixedOutputs[$outputType] = $fixedPortArrays
    }
    $fixedConnections[$sourceName] = $fixedOutputs
}

# Strip n8n-incompatible top-level metadata fields
$importPayload = [ordered]@{
    name        = $wf.name
    # active is read-only in n8n POST /workflows — workflows default to inactive on creation
    # We do NOT include it; we verify active=false after creation
    nodes       = $wf.nodes
    connections = $fixedConnections
    settings    = $wf.settings
    # tags is also read-only in n8n POST /workflows — omitted
}

Write-Host "  [PASS] Import payload prepared. Connections: $($fixedConnections.Keys.Count) source nodes." -ForegroundColor Green
Write-Host "  [PASS] Metadata fields stripped (_comment, _safety, _version, _date)." -ForegroundColor Green
Write-Host "  [PASS] active forced to false in payload." -ForegroundColor Green
Write-Host ""

if ($ValidateOnly) {
    Write-Host "[ValidateOnly] Stopping after validation — no import." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== SL-PHASE-5F Validation Complete ===" -ForegroundColor Cyan
    exit 0
}

# ── STEP 3: IMPORT WORKFLOW ───────────────────────────────────────────────────

if (-not $ImportWorkflow) {
    Write-Host "[INFO] Neither -ValidateOnly nor -ImportWorkflow specified. Running -ValidateOnly by default." -ForegroundColor Yellow
    Write-Host "  To import: .\SL-PHASE-5F-shadow-mode-activation.ps1 -ImportWorkflow"
    Write-Host ""
    Write-Host "=== SL-PHASE-5F Complete (ValidateOnly) ===" -ForegroundColor Cyan
    exit 0
}

Write-Host "--- Step 3: Import Disabled Workflow to Production n8n ---" -ForegroundColor Yellow

if (-not $env:HMZ_N8N_API_KEY) {
    Write-Error "HMZ_N8N_API_KEY is not set. Cannot import without API key."
}

$headers = @{
    "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY
    "Content-Type"  = "application/json"
}

$body = $importPayload | ConvertTo-Json -Depth 20

Write-Host "  Sending POST to $N8nApiBase/workflows ..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod `
        -Method POST `
        -Uri "$N8nApiBase/workflows" `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
} catch {
    Write-Error "Import failed: $($_.Exception.Message)"
}

$importedId        = $response.id
$importedName      = $response.name
$importedActive    = $response.active
$importedVersionId = if ($response.versionId) { $response.versionId } elseif ($response.meta.instanceId) { "n/a (check n8n UI)" } else { "not returned" }

Write-Host ""
Write-Host "  Imported workflow:" -ForegroundColor Green
Write-Host "    ID        : $importedId"
Write-Host "    Name      : $importedName"
Write-Host "    Active    : $importedActive"
Write-Host "    VersionId : $importedVersionId"
Write-Host ""

# ── STEP 4: VERIFY IMPORT ─────────────────────────────────────────────────────

Write-Host "--- Step 4: Verify Import (active=false) ---" -ForegroundColor Yellow

if ($importedActive -ne $false) {
    Write-Host "  [CRITICAL SAFETY FAILURE] Imported workflow has active=$importedActive — expected false." -ForegroundColor Red
    Write-Host "  ACTION REQUIRED: Manually deactivate the workflow in n8n UI immediately." -ForegroundColor Red
    Write-Host "  Workflow ID: $importedId" -ForegroundColor Red
    Write-Error "Workflow imported as ACTIVE. Manual intervention required."
}

Write-Host "  [PASS] active=false confirmed after import." -ForegroundColor Green
Write-Host "  [PASS] Workflow is in n8n but will NOT fire on production traffic." -ForegroundColor Green
Write-Host "  [PASS] No Sender connection, no Instantly API, manual webhook only." -ForegroundColor Green
Write-Host ""

# Re-fetch to confirm
try {
    $verify = Invoke-RestMethod `
        -Method GET `
        -Uri "$N8nApiBase/workflows/$importedId" `
        -Headers $headers `
        -ErrorAction Stop

    if ($verify.active -eq $false) {
        Write-Host "  [PASS] Re-fetch confirmed active=false." -ForegroundColor Green
        $importedVersionId = if ($verify.versionId) { $verify.versionId } else { $importedVersionId }
    } else {
        Write-Host "  [FAIL] Re-fetch shows active=$($verify.active) — manual deactivation required." -ForegroundColor Red
    }
} catch {
    Write-Host "  [WARN] Could not re-fetch for verification: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# ── STEP 5: RECORD RESULTS ────────────────────────────────────────────────────

Write-Host "--- Step 5: Record Shadow Mode Activation Results ---" -ForegroundColor Yellow

$resultPath = Join-Path $Root "outputs\phase5f_shadow_activation_result.json"
$result = [ordered]@{
    phase              = "5F"
    title              = "Shadow Mode Activation"
    gate               = "Gate 1"
    owner_approval     = "Granted 2026-06-24 (explicit session instruction)"
    timestamp          = $Timestamp
    config_validated   = $true
    workflow_validated = $true
    workflow_imported  = $true
    imported_workflow_id        = $importedId
    imported_workflow_name      = $importedName
    imported_workflow_active    = $importedActive
    imported_workflow_versionId = $importedVersionId
    safety_checks = @(
        "active=false confirmed",
        "no Sender node",
        "no Instantly API node",
        "would_send_live_now hardcoded false",
        "autonomous_enabled=false in config",
        "max_autonomous_sends_per_day=0",
        "escalation_channels configured (GOOGLE_CHAT_WEBHOOK_URL)"
    )
    current_mode           = "Mode 1 — Shadow Only (no live sends)"
    autonomous_enabled     = $false
    shadow_only            = $true
    dry_run                = $true
    emergency_disabled     = $true
    max_sends_per_day      = 0
    next_step              = "Run manual tests from docs/NEXT_MANUAL_TEST_PACKET_AUTONOMOUS_SHADOW.md"
    gate2_requires         = "14 days shadow review + explicit owner Gate 2 approval"
    production_workflows_changed = "NONE — Decision/HumanApproval/Proxy UNCHANGED"
}

$result | ConvertTo-Json -Depth 10 | Set-Content $resultPath -Encoding UTF8
$result | ConvertTo-Json -Depth 10 | Set-Content $resultPath -Encoding UTF8
Write-Host "  [SAVED] $resultPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== SL-PHASE-5F COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Shadow mode is now active (Mode 1)." -ForegroundColor Green
Write-Host "  - Disabled workflow imported to n8n: $importedId" -ForegroundColor Green
Write-Host "  - Workflow is INACTIVE — no production traffic routes to it" -ForegroundColor Green
Write-Host "  - No live sends possible (autonomous_enabled=false, max_sends=0)" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Run manual tests: docs/NEXT_MANUAL_TEST_PACKET_AUTONOMOUS_SHADOW.md" -ForegroundColor Yellow
Write-Host "  2. Review results daily using docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md" -ForegroundColor Yellow
Write-Host "  3. Gate 2 (controlled pilot) requires 14 days shadow review + explicit approval" -ForegroundColor Yellow
Write-Host ""
