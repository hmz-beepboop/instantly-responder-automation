##############################################################################
# HMZ-Fix-DE-DraftPrep-SyntaxError-v5.ps1
#
# ROOT CAUSE: Decision Engine node "D. Draft Preparation (Templates / Human Draft)"
# contains a JavaScript SyntaxError:
#   [[ + key + : unresolved]]
# This should be:
#   `[[${key}: unresolved]]`
# The SyntaxError causes D to always fail. When D fails n8n outputs { error },
# wiping all prior context (nes, decision, raw_payload, etc.). Downstream nodes
# F, G-chain, and E lose nes and a valid decision object. E's output validation
# fails (26 required fields missing). Human Approval receives case_input with no
# nes and empty decision.category -> Google Chat card shows UNKNOWN and blank.
#
# PATCH: Fix only the SyntaxError in Decision Engine node D.
#
# Usage:
#   -WhatIf  Dry run - show what would change, make no API calls
#   (no flag) Apply the patch
##############################################################################
param(
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BASE_URL   = "https://n8n.hmzaiautomation.com/api/v1"
$API_KEY    = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) { throw "HMZ_N8N_API_KEY env var is not set." }

$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$WORKFLOW_IDS = [ordered]@{
    Intake         = "VtDQqw02Ux1TgjIH"
    DecisionEngine = "tgYmY97CG4Bm8snI"
    HumanApproval  = "9aPrt92jFhoYFxbs"
    Sender         = "ePS5uBBxKxhFCYgU"
    ErrorHandler   = "2PR9YEkG4KyGdowa"
    SLAWatchdog    = "6a8ojyXCwMwI9nyF"
    FullTestHarness = "RLUcJHQJPvLhw4mG"
}

$DEACTIVATION_ORDER = @("Intake","SLAWatchdog","ErrorHandler","HumanApproval","DecisionEngine","Sender")
$REACTIVATION_ORDER = @("Sender","DecisionEngine","HumanApproval","ErrorHandler","SLAWatchdog","Intake")

$BACKUP_DIR = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\backups\de-draftprep-fix-v5-$(Get-Date -Format 'yyyyMMdd_HHmmss')"

$OLD_SNIPPET = ': [[ + key + : unresolved]]'
$NEW_SNIPPET = ': `[[${key}: unresolved]]`'

# ── helpers ──────────────────────────────────────────────────────────────────

function Invoke-N8N($method, $path, $body = $null) {
    $uri = "$BASE_URL$path"
    if ($body) {
        return Invoke-RestMethod -Uri $uri -Headers $HEADERS -Method $method -Body ($body | ConvertTo-Json -Depth 50 -Compress)
    }
    return Invoke-RestMethod -Uri $uri -Headers $HEADERS -Method $method
}

function Get-Workflow($id) { return Invoke-N8N "GET" "/workflows/$id" }

function Set-WorkflowActive($id, $active) {
    $wf = Get-Workflow $id
    $wf.active = $active
    $body = @{ active = $active }
    Invoke-N8N "PATCH" "/workflows/$id" $body | Out-Null
}

function Write-Log($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" }

# ── STOP CONDITION: Full Test Harness must stay inactive ──────────────────────

function Assert-FullTestHarnessInactive {
    Write-Log "Checking Full Test Harness is inactive..."
    $fth = Get-Workflow $WORKFLOW_IDS.FullTestHarness
    if ($fth.active -eq $true) {
        throw "STOP: Full Test Harness (RLUcJHQJPvLhw4mG) is ACTIVE. Refusing to proceed."
    }
    Write-Log "  Full Test Harness inactive: OK"
}

# ── Phase 0: pre-flight ───────────────────────────────────────────────────────

Write-Log "=== HMZ De-DraftPrep-SyntaxError v5 ==="
if ($WhatIf) { Write-Log "*** WHATIF MODE - no changes will be made ***" }

Assert-FullTestHarnessInactive

# ── Phase 1: backup ───────────────────────────────────────────────────────────

if (-not $WhatIf) {
    Write-Log "Creating backup dir: $BACKUP_DIR"
    New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
}

foreach ($name in $WORKFLOW_IDS.Keys) {
    $id = $WORKFLOW_IDS[$name]
    Write-Log "Backing up $name ($id)..."
    $wf = Get-Workflow $id
    if (-not $WhatIf) {
        $wf | ConvertTo-Json -Depth 50 | Set-Content -Encoding UTF8 "$BACKUP_DIR\$name-$id-backup.json"
        Write-Log "  -> $BACKUP_DIR\$name-$id-backup.json"
    } else {
        Write-Log "  [WhatIf] would backup to $BACKUP_DIR\$name-$id-backup.json"
    }
}

# ── Phase 2: verify Decision Engine D has the known SyntaxError ──────────────

Write-Log "Verifying Decision Engine D node contains the known SyntaxError..."
$de = Get-Workflow $WORKFLOW_IDS.DecisionEngine
$nodeD = $de.nodes | Where-Object { $_.name -eq "D. Draft Preparation (Templates / Human Draft)" }
if (-not $nodeD) {
    throw "STOP: Node 'D. Draft Preparation (Templates / Human Draft)' not found in Decision Engine."
}
$currentCode = $nodeD.parameters.jsCode
if (-not $currentCode.Contains($OLD_SNIPPET)) {
    Write-Log "WARNING: Known SyntaxError snippet not found in current D code."
    Write-Log "Snippet searched: $OLD_SNIPPET"
    Write-Log "This patch may already have been applied or the code has changed."
    throw "STOP: Pre-patch assertion failed - old snippet not found. Inspect manually."
}
Write-Log "  SyntaxError confirmed in D node: OK"

# ── Phase 3: deactivate workflows ─────────────────────────────────────────────

foreach ($name in $DEACTIVATION_ORDER) {
    $id = $WORKFLOW_IDS[$name]
    Write-Log "Deactivating $name ($id)..."
    if (-not $WhatIf) {
        Set-WorkflowActive $id $false
        Start-Sleep -Milliseconds 300
        $check = Get-Workflow $id
        if ($check.active -eq $true) { throw "STOP: Failed to deactivate $name." }
        Write-Log "  Deactivated: OK"
    } else {
        Write-Log "  [WhatIf] would deactivate $name"
    }
}

# ── Phase 4: apply patch to Decision Engine D ─────────────────────────────────

Write-Log "Patching Decision Engine D node SyntaxError..."

$patchedCode = $currentCode.Replace($OLD_SNIPPET, $NEW_SNIPPET)

if ($patchedCode -eq $currentCode) {
    throw "STOP: Replace had no effect - patch did not apply."
}

if (-not $WhatIf) {
    # Re-fetch full DE workflow to build a valid update body
    $deFull = Get-Workflow $WORKFLOW_IDS.DecisionEngine
    $nodeDFull = $deFull.nodes | Where-Object { $_.name -eq "D. Draft Preparation (Templates / Human Draft)" }
    $nodeDFull.parameters.jsCode = $patchedCode

    # Build minimal update payload (PUT requires full workflow)
    $updateBody = @{
        name        = $deFull.name
        nodes       = $deFull.nodes
        connections = $deFull.connections
        settings    = $deFull.settings
        staticData  = $deFull.staticData
    }

    Invoke-N8N "PUT" "/workflows/$($WORKFLOW_IDS.DecisionEngine)" $updateBody | Out-Null
    Write-Log "  PUT /workflows/DecisionEngine: OK"

    # Verify patch landed
    $deVerify = Get-Workflow $WORKFLOW_IDS.DecisionEngine
    $nodeDVerify = $deVerify.nodes | Where-Object { $_.name -eq "D. Draft Preparation (Templates / Human Draft)" }
    if ($nodeDVerify.parameters.jsCode.Contains($OLD_SNIPPET)) {
        throw "STOP: Patch verification failed - old SyntaxError snippet still present after PUT."
    }
    if (-not $nodeDVerify.parameters.jsCode.Contains($NEW_SNIPPET)) {
        throw "STOP: Patch verification failed - new snippet not found after PUT."
    }
    Write-Log "  Patch verified in live workflow: OK"
} else {
    Write-Log "  [WhatIf] would replace in D node code:"
    Write-Log "    OLD: $OLD_SNIPPET"
    Write-Log "    NEW: $NEW_SNIPPET"
    Write-Log "  [WhatIf] would PUT /workflows/$($WORKFLOW_IDS.DecisionEngine)"
}

# ── Phase 5: assert Full Test Harness still inactive ─────────────────────────

if (-not $WhatIf) {
    Assert-FullTestHarnessInactive
}

# ── Phase 6: reactivate workflows ────────────────────────────────────────────

foreach ($name in $REACTIVATION_ORDER) {
    $id = $WORKFLOW_IDS[$name]
    Write-Log "Reactivating $name ($id)..."
    if (-not $WhatIf) {
        Set-WorkflowActive $id $true
        Start-Sleep -Milliseconds 300
        $check = Get-Workflow $id
        if ($check.active -ne $true) { throw "STOP: Failed to reactivate $name." }
        Write-Log "  Reactivated: OK"
    } else {
        Write-Log "  [WhatIf] would reactivate $name"
    }
}

# ── Phase 7: final verification ──────────────────────────────────────────────

if (-not $WhatIf) {
    Write-Log "Running final verification..."

    # 1. D node no longer has SyntaxError
    $deFinal = Get-Workflow $WORKFLOW_IDS.DecisionEngine
    $nodeDFinal = $deFinal.nodes | Where-Object { $_.name -eq "D. Draft Preparation (Templates / Human Draft)" }
    if ($nodeDFinal.parameters.jsCode.Contains($OLD_SNIPPET)) {
        throw "FAIL: Final check - old SyntaxError still present."
    }
    Write-Log "  [PASS] D node SyntaxError removed"

    # 2. New snippet is present
    if (-not $nodeDFinal.parameters.jsCode.Contains($NEW_SNIPPET)) {
        throw "FAIL: Final check - new template literal not found."
    }
    Write-Log "  [PASS] D node template literal present"

    # 3. Full Test Harness still inactive
    $fthFinal = Get-Workflow $WORKFLOW_IDS.FullTestHarness
    if ($fthFinal.active -eq $true) {
        throw "FAIL: Final check - Full Test Harness is active!"
    }
    Write-Log "  [PASS] Full Test Harness inactive"

    # 4. All 6 workflows active
    foreach ($name in $REACTIVATION_ORDER) {
        $id = $WORKFLOW_IDS[$name]
        $wf = Get-Workflow $id
        if ($wf.active -ne $true) {
            throw "FAIL: Final check - $name is not active."
        }
        Write-Log "  [PASS] $name is active"
    }

    Write-Log ""
    Write-Log "PATCH_APPLIED_AND_VERIFIED"
    Write-Log "Backups saved to: $BACKUP_DIR"
} else {
    Write-Log ""
    Write-Log "[WhatIf] Dry run complete. No changes were made."
    Write-Log "Run without -WhatIf to apply."
}
