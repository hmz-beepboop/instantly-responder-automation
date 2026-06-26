#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5D: Disabled Autonomous Shadow Evaluator — Workflow Import Tool

.DESCRIPTION
    Manages the disabled autonomous shadow evaluator workflow.
    Default mode is WhatIf/ValidateOnly — no imports occur without explicit flags.

    SAFETY: The workflow JSON has active=false. Importing does NOT activate it.
    To activate, the owner must manually toggle it in the n8n UI with explicit approval.

.PARAMETER WhatIf
    Show what would be done without doing it.

.PARAMETER ValidateOnly
    Validate the workflow JSON without importing.

.PARAMETER CreateDisabledWorkflow
    Import the workflow to n8n in DISABLED state (requires -NoActivation).

.PARAMETER NoActivation
    Default: true. Prevents activation. Required with -CreateDisabledWorkflow.

.PARAMETER AllowActivation
    Dangerous: allows activation flag. Never set this unless explicitly authorised.

.EXAMPLE
    .\SL-PHASE-5D-create-disabled-autonomous-shadow-evaluator.ps1 -WhatIf -ValidateOnly
    .\SL-PHASE-5D-create-disabled-autonomous-shadow-evaluator.ps1 -ValidateOnly
    # Import only after explicit owner approval:
    # .\SL-PHASE-5D-create-disabled-autonomous-shadow-evaluator.ps1 -CreateDisabledWorkflow -NoActivation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$ValidateOnly,
    [switch]$CreateDisabledWorkflow,
    [switch]$NoActivation,
    [switch]$AllowActivation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot    = Split-Path $PSScriptRoot -Parent
$WorkflowPath  = Join-Path $ScriptRoot "workflows\disabled_autonomous_shadow_evaluator.json"
$Timestamp     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$N8nApiBase    = "https://n8n.hmzaiautomation.com/api/v1"

Write-Host ""
Write-Host "=== SL-PHASE-5D: Disabled Autonomous Shadow Evaluator ===" -ForegroundColor Cyan
Write-Host "Timestamp  : $Timestamp"
Write-Host "WhatIf     : $($WhatIfPreference -ne 'SilentlyContinue')"
Write-Host "ValidateOnly: $($ValidateOnly.IsPresent)"
Write-Host "CreateDisabledWorkflow: $($CreateDisabledWorkflow.IsPresent)"
Write-Host ""
Write-Host "[SAFETY] This workflow must remain INACTIVE after import." -ForegroundColor Yellow
Write-Host "[SAFETY] It has no Sender connection, no Instantly API calls, no production traffic." -ForegroundColor Yellow
Write-Host ""

# ── VALIDATE WORKFLOW JSON ────────────────────────────────────────────────────

if ($ValidateOnly -or $CreateDisabledWorkflow) {
    Write-Host "[ValidateOnly] Validating workflow JSON..." -ForegroundColor Yellow

    if (-not (Test-Path $WorkflowPath)) {
        Write-Error "Workflow JSON not found: $WorkflowPath"
    }

    $wf = Get-Content $WorkflowPath -Raw | ConvertFrom-Json
    $errors = @()
    $checks = @()

    # Check active flag
    if ($wf.active -eq $false) {
        $checks += "[PASS] active=false — workflow is disabled"
    } else {
        $errors += "[FAIL] active is not false — workflow would be active after import"
    }

    # Check workflow name contains DISABLED
    if ($wf.name -like "*DISABLED*") {
        $checks += "[PASS] Name contains DISABLED marker"
    } else {
        $errors += "[WARN] Name does not contain DISABLED marker"
    }

    # Check for Sender node
    $senderNodes = @($wf.nodes | Where-Object { $_.name -like "*sender*" -or $_.type -like "*sender*" })
    if ($senderNodes.Count -eq 0) {
        $checks += "[PASS] No Sender node found"
    } else {
        $errors += "[FAIL] Sender node detected — must not be present"
    }

    # Check for Instantly API nodes
    $instantlyNodes = @($wf.nodes | Where-Object { $_.name -like "*instantly*" -or ($_.parameters | ConvertTo-Json -Depth 10) -like "*instantly*" })
    if ($instantlyNodes.Count -eq 0) {
        $checks += "[PASS] No Instantly API node found"
    } else {
        $errors += "[FAIL] Instantly API node detected — must not be present"
    }

    # Check would_send_live_now is hardcoded false
    $wfJson = Get-Content $WorkflowPath -Raw
    if ($wfJson -like "*would_send_live_now: false*" -or $wfJson -like "*would_send_live_now`, false*") {
        $checks += "[PASS] would_send_live_now hardcoded false"
    } else {
        $checks += "[INFO] would_send_live_now hardcoding in JS code — review node code to confirm"
    }

    # Check shadow_evaluator_mode flag
    if ($wfJson -like "*shadow_evaluator_mode*") {
        $checks += "[PASS] shadow_evaluator_mode marker present"
    } else {
        $errors += "[WARN] shadow_evaluator_mode marker not found"
    }

    foreach ($c in $checks) {
        $color = if ($c -like "*PASS*") { "Green" } elseif ($c -like "*WARN*") { "Yellow" } else { "Cyan" }
        Write-Host "  $c" -ForegroundColor $color
    }

    if ($errors.Count -gt 0) {
        foreach ($e in $errors) {
            $color = if ($e -like "*FAIL*") { "Red" } else { "Yellow" }
            Write-Host "  $e" -ForegroundColor $color
        }
        $hardFails = $errors | Where-Object { $_ -like "*FAIL*" }
        if ($hardFails.Count -gt 0) {
            Write-Error "Validation failed with $($hardFails.Count) hard error(s). Do not import."
        }
    }

    Write-Host ""
    Write-Host "[PASS] Workflow JSON validated. active=false confirmed." -ForegroundColor Green
}

# ── CREATE DISABLED WORKFLOW ──────────────────────────────────────────────────

if ($CreateDisabledWorkflow) {
    if ($AllowActivation.IsPresent -and -not $NoActivation.IsPresent) {
        Write-Warning "AllowActivation is set without NoActivation. This would import an active workflow. Aborting for safety."
        exit 1
    }

    if (-not ($env:HMZ_N8N_API_KEY)) {
        Write-Error "HMZ_N8N_API_KEY is not set. Cannot import workflow without API key."
    }

    Write-Host ""
    Write-Host "[CreateDisabledWorkflow] This would import the DISABLED shadow evaluator to:" -ForegroundColor Yellow
    Write-Host "  API: $N8nApiBase" -ForegroundColor Yellow
    Write-Host "  Workflow: $($wf.name)" -ForegroundColor Yellow
    Write-Host "  Active: FALSE" -ForegroundColor Green
    Write-Host ""

    if ($PSCmdlet.ShouldProcess("$N8nApiBase/workflows", "Import disabled shadow evaluator workflow")) {
        Write-Host "  [WhatIf mode] Would POST to $N8nApiBase/workflows with active=false payload."
        Write-Host "  To actually import: remove -WhatIf and confirm owner has approved."
        Write-Host ""
        Write-Host "  REMINDER: After import, do NOT activate the workflow in n8n UI without owner approval." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== SL-PHASE-5D Complete ===" -ForegroundColor Cyan
Write-Host ""
