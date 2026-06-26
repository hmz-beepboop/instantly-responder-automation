#Requires -Version 7
<#
.SYNOPSIS
    SL-PHASE-5B: Autonomous Config and Working-Hours Schema Tool

.DESCRIPTION
    Manages the HMZ Autonomous Responder config schema, sample config, and validation.
    All operations are offline by default. No production writes occur unless -AllowProductionWrites is specified.

    SAFETY: Default config has autonomous_enabled=false, shadow_only=true, dry_run=true.
    Live autonomous sends cannot occur with the sample config.

.PARAMETER WhatIf
    Show what would be done without doing it.

.PARAMETER ValidateConfig
    Validate the config file against the schema.

.PARAMETER ExportSchema
    Export the JSON schema to outputs/autonomous_config_schema.json.

.PARAMETER ExportSampleConfig
    Export the sample config to outputs/autonomous_sample_config.json.

.PARAMETER UseSampleConfig
    Use the sample config for validation instead of a custom config file.

.PARAMETER ConfigPath
    Path to a custom config file for validation.

.PARAMETER NoProductionWrites
    Default: true. Prevents any writes to production n8n. Always enabled unless explicitly overridden.

.PARAMETER AllowProductionWrites
    Dangerous: allows production writes. Requires explicit use. Not used in normal operation.

.EXAMPLE
    .\SL-PHASE-5B-autonomous-config-and-hours.ps1 -UseSampleConfig -ValidateConfig -ExportSchema -ExportSampleConfig
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$ValidateConfig,
    [switch]$ExportSchema,
    [switch]$ExportSampleConfig,
    [switch]$UseSampleConfig,
    [string]$ConfigPath = "",
    [switch]$NoProductionWrites,
    [switch]$AllowProductionWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot   = Split-Path $PSScriptRoot -Parent
$OutputsDir   = Join-Path $ScriptRoot "outputs"
$SchemaPath   = Join-Path $OutputsDir "autonomous_config_schema.json"
$SamplePath   = Join-Path $OutputsDir "autonomous_sample_config.json"
$ReportPath   = Join-Path $OutputsDir "autonomous_config_validation_report.json"

$ProductionWrites = $AllowProductionWrites.IsPresent -and -not $NoProductionWrites.IsPresent
$Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

Write-Host ""
Write-Host "=== SL-PHASE-5B: Autonomous Config and Working-Hours Schema Tool ===" -ForegroundColor Cyan
Write-Host "Timestamp : $Timestamp"
Write-Host "Production writes: $ProductionWrites"
if (-not $ProductionWrites) {
    Write-Host "[SAFE] No production writes will occur." -ForegroundColor Green
}
Write-Host ""

# ── SAMPLE CONFIG DEFINITION ──────────────────────────────────────────────────

$SampleConfig = [ordered]@{
    "_comment"                             = "HMZ Autonomous Responder SAMPLE CONFIG (Shadow Mode). All defaults are disabled. No live sends possible."
    "_version"                             = "1.0.0"
    "_date"                                = "2026-06-24"
    "_mode"                                = "SHADOW_ONLY"

    "autonomous_enabled"                   = $false
    "shadow_only"                          = $true
    "dry_run"                              = $true
    "owner_approval_required"              = $true
    "emergency_disabled"                   = $true

    "reviewer_timezone"                    = "America/New_York"
    "working_days"                         = @("Monday","Tuesday","Wednesday","Thursday","Friday")
    "working_hours_start"                  = "09:00"
    "working_hours_end"                    = "18:00"
    "prospect_timezone_strategy"           = "reviewer_only"
    "blackout_dates"                       = @()
    "holiday_calendar_placeholder"         = "US_FEDERAL"

    "campaign_allowlist"                   = @()
    "sender_allowlist"                     = @()
    "intent_allowlist"                     = @()
    "micro_intent_allowlist"               = @()

    "additional_intent_blocklist"          = @(
        "PRICING_REQUEST","PRICING_NEGOTIATION","CONTRACT_TERMS",
        "GDPR_REQUEST","SOC2_REQUEST","DATA_SECURITY_REQUEST",
        "PRIVACY_QUESTION","COMPLIANCE_QUESTION","LEGAL_COMPLAINT",
        "CUSTOM_PROPOSAL_REQUEST","ENTERPRISE_REQUEST","SENSITIVE_PERSONAL_DATA"
    )
    "risk_blocklist"                       = @("UNSUBSCRIBE","DNC","OPT_OUT","HOSTILE","COMPLAINT","BILLING","REFUND")

    "confidence_threshold"                 = 0.85
    "max_autonomous_sends_per_day"         = 0
    "max_autonomous_sends_per_campaign_per_day" = 0
    "max_autonomous_sends_per_sender_per_day"   = 0

    "require_post_action_review"           = $true
    "digest_frequency"                     = "daily"
    "escalation_channels"                  = @()
    "rollback_mode"                        = "manual"
    "live_pilot_daily_cap"                 = 1
    "live_pilot_requires_owner_toggle"     = $true
}

# ── EXPORT SAMPLE CONFIG ──────────────────────────────────────────────────────

if ($ExportSampleConfig) {
    Write-Host "[ExportSampleConfig] Exporting sample config..." -ForegroundColor Yellow
    if ($PSCmdlet.ShouldProcess($SamplePath, "Write sample config")) {
        $SampleConfig | ConvertTo-Json -Depth 10 | Set-Content $SamplePath -Encoding UTF8
        Write-Host "  Written: $SamplePath" -ForegroundColor Green
    }
}

# ── EXPORT SCHEMA ─────────────────────────────────────────────────────────────

if ($ExportSchema) {
    Write-Host "[ExportSchema] Schema is pre-generated at $SchemaPath" -ForegroundColor Yellow
    if (Test-Path $SchemaPath) {
        Write-Host "  Schema exists: $SchemaPath" -ForegroundColor Green
    } else {
        Write-Warning "  Schema file not found at $SchemaPath. It should have been created by the session. Re-run session or create manually."
    }
}

# ── LOAD CONFIG FOR VALIDATION ────────────────────────────────────────────────

$ConfigToValidate = $null

if ($UseSampleConfig) {
    Write-Host "[UseSampleConfig] Using built-in sample config for validation." -ForegroundColor Yellow
    $ConfigToValidate = $SampleConfig
} elseif ($ConfigPath -ne "" -and (Test-Path $ConfigPath)) {
    Write-Host "[ConfigPath] Loading config from: $ConfigPath" -ForegroundColor Yellow
    $ConfigToValidate = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
} elseif (Test-Path $SamplePath) {
    Write-Host "[Auto] Loading sample config from: $SamplePath" -ForegroundColor Yellow
    $ConfigToValidate = Get-Content $SamplePath -Raw | ConvertFrom-Json -AsHashtable
}

# ── VALIDATE CONFIG ───────────────────────────────────────────────────────────

$Checks  = [System.Collections.Generic.List[hashtable]]::new()
$Passed  = 0
$Failed  = 0
$Overall = "PASS"

function Add-Check {
    param([string]$Check, $Value, [string]$Result, [string]$Note = "")
    $script:Checks.Add(@{ check = $Check; value = $Value; result = $Result; note = $Note })
    if ($Result -eq "PASS") { $script:Passed++ } else { $script:Failed++; $script:Overall = "FAIL" }
    $color = if ($Result -eq "PASS") { "Green" } else { "Red" }
    Write-Host ("  [{0}] {1} = {2}" -f $Result, $Check, $Value) -ForegroundColor $color
}

if ($ValidateConfig -and $ConfigToValidate) {
    Write-Host ""
    Write-Host "[ValidateConfig] Running safety gate checks..." -ForegroundColor Yellow
    Write-Host ""

    $c = $ConfigToValidate

    # Safety gate checks
    Add-Check "autonomous_enabled is false"           $c["autonomous_enabled"]         $(if (-not $c["autonomous_enabled"]) {"PASS"} else {"FAIL"}) "Live sends blocked"
    Add-Check "shadow_only is true"                   $c["shadow_only"]                $(if ($c["shadow_only"]) {"PASS"} else {"WARN"})             "Shadow mode"
    Add-Check "dry_run is true"                       $c["dry_run"]                    $(if ($c["dry_run"]) {"PASS"} else {"WARN"})                  "No real sends"
    Add-Check "emergency_disabled is true"            $c["emergency_disabled"]         $(if ($c["emergency_disabled"]) {"PASS"} else {"WARN"})       "Kill switch active"
    Add-Check "campaign_allowlist is empty"           ($c["campaign_allowlist"].Count)  $(if ($c["campaign_allowlist"].Count -eq 0) {"PASS"} else {"WARN"}) "No campaigns approved"
    Add-Check "sender_allowlist is empty"             ($c["sender_allowlist"].Count)    $(if ($c["sender_allowlist"].Count -eq 0) {"PASS"} else {"WARN"}) "No senders approved"
    Add-Check "intent_allowlist is empty"             ($c["intent_allowlist"].Count)    $(if ($c["intent_allowlist"].Count -eq 0) {"PASS"} else {"WARN"}) "No intents approved"
    Add-Check "max_autonomous_sends_per_day is 0"    $c["max_autonomous_sends_per_day"] $(if ($c["max_autonomous_sends_per_day"] -eq 0) {"PASS"} else {"WARN"}) "Zero sends allowed"
    Add-Check "confidence_threshold >= 0.85"          $c["confidence_threshold"]        $(if ($c["confidence_threshold"] -ge 0.85) {"PASS"} else {"FAIL"}) "Minimum threshold"
    Add-Check "require_post_action_review is true"    $c["require_post_action_review"]  $(if ($c["require_post_action_review"]) {"PASS"} else {"FAIL"}) "Reviews required"
    Add-Check "owner_approval_required is true"       $c["owner_approval_required"]     $(if ($c["owner_approval_required"]) {"PASS"} else {"WARN"}) "Owner approval required"
    Add-Check "live_pilot_requires_owner_toggle is true" $c["live_pilot_requires_owner_toggle"] $(if ($c["live_pilot_requires_owner_toggle"]) {"PASS"} else {"WARN"}) "Toggle required"

    # Working hours checks
    $hoursValid = ($c["working_hours_start"] -match "^\d{2}:\d{2}$") -and ($c["working_hours_end"] -match "^\d{2}:\d{2}$")
    Add-Check "working_hours format valid"            "$($c['working_hours_start'])-$($c['working_hours_end'])" $(if ($hoursValid) {"PASS"} else {"FAIL"}) "HH:MM format"

    $startH, $startM = $c["working_hours_start"].Split(":") | ForEach-Object { [int]$_ }
    $endH,   $endM   = $c["working_hours_end"].Split(":")   | ForEach-Object { [int]$_ }
    $startMins = $startH * 60 + $startM
    $endMins   = $endH * 60 + $endM
    Add-Check "working_hours_start before working_hours_end" "$startMins < $endMins"  $(if ($startMins -lt $endMins) {"PASS"} else {"FAIL"}) "Start must precede end"

    Add-Check "reviewer_timezone set"                 $c["reviewer_timezone"]          $(if ($c["reviewer_timezone"] -ne "") {"PASS"} else {"FAIL"}) "Required"

    Write-Host ""
    Write-Host "Passed: $Passed  Failed: $Failed  Overall: $Overall" -ForegroundColor $(if ($Overall -eq "PASS") {"Green"} else {"Red"})

    # Determine if live autonomy is possible
    $liveAutonomyPossible = (
        $c["autonomous_enabled"] -eq $true -and
        $c["shadow_only"] -eq $false -and
        $c["dry_run"] -eq $false -and
        $c["emergency_disabled"] -eq $false -and
        $c["campaign_allowlist"].Count -gt 0 -and
        $c["sender_allowlist"].Count -gt 0 -and
        $c["intent_allowlist"].Count -gt 0 -and
        $c["max_autonomous_sends_per_day"] -gt 0
    )

    Write-Host ""
    if ($liveAutonomyPossible) {
        Write-Host "[WARNING] This config COULD enable live autonomous sends if imported. Review carefully." -ForegroundColor Red
    } else {
        Write-Host "[SAFE] Live autonomous sends are IMPOSSIBLE with this config." -ForegroundColor Green
    }

    # Write report
    $Report = @{
        validation_run          = $Timestamp
        script                  = "SL-PHASE-5B-autonomous-config-and-hours.ps1"
        flags                   = "-UseSampleConfig -ValidateConfig -ExportSchema -ExportSampleConfig"
        config_source           = if ($UseSampleConfig) {"built-in sample"} else {$ConfigPath}
        overall_result          = $Overall
        production_writes       = $ProductionWrites
        checks_passed           = $Passed
        checks_failed           = $Failed
        live_autonomy_possible  = $liveAutonomyPossible
        checks                  = $Checks
    }

    $Report | ConvertTo-Json -Depth 10 | Set-Content $ReportPath -Encoding UTF8
    Write-Host "  Report written: $ReportPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SL-PHASE-5B Complete ===" -ForegroundColor Cyan
Write-Host ""
