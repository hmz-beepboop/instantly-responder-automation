#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}


$N8N_URL = 'http://127.0.0.1:5678'
$ExpectedNames = @(
    'HMZ - Reply SLA Watchdog - Validation',
    'HMZ - Reply Full Test Harness - Validation'
)
$AllowedHttpPrefix = 'http://hmz-send-state:5681'

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw 'HMZ_N8N_API_KEY is not set in this PowerShell process.'
}

$ApiKey = $env:HMZ_N8N_API_KEY
$Headers = @{
    'X-N8N-API-KEY' = $ApiKey
    'Content-Type'  = 'application/json'
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$ResultsPath = Join-Path $RepoRoot 'verification/phase4b/offline-test-results.json'
$WatchdogPath = Join-Path $RepoRoot 'workflows/05_reply_sla_watchdog_validation.json'
$HarnessPath = Join-Path $RepoRoot 'workflows/06_reply_full_test_harness_validation.json'

function Assert-OfflineEvidence {
    if (-not (Test-Path -LiteralPath $ResultsPath -PathType Leaf)) {
        throw "Offline test results were not found: $ResultsPath"
    }

    $Results = Get-Content -LiteralPath $ResultsPath -Raw | ConvertFrom-Json
    if ($Results.total -lt 25 -or $Results.failed -ne 0 -or $Results.passed -ne $Results.total) {
        throw "Offline evidence is not acceptable. Expected at least 25 passing tests and zero failures; found passed=$($Results.passed), total=$($Results.total), failed=$($Results.failed)."
    }

    Write-Host "Offline tests: $($Results.passed)/$($Results.total) passed."
}

function Read-SafeWorkflow {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Workflow file not found: $Path"
    }

    $Raw = Get-Content -LiteralPath $Path -Raw
    $Workflow = $Raw | ConvertFrom-Json

    if ($Workflow.active -eq $true) {
        throw "Workflow '$($Workflow.name)' has active=true."
    }

    foreach ($Node in @($Workflow.nodes)) {
        if ($null -ne $Node.PSObject.Properties['credentials']) {
            throw "Workflow '$($Workflow.name)' node '$($Node.name)' contains credentials."
        }

        if ($Node.type -eq 'n8n-nodes-base.httpRequest') {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name 'url')
            if (-not $Url.StartsWith($AllowedHttpPrefix)) {
                throw "Workflow '$($Workflow.name)' node '$($Node.name)' targets a non-sidecar URL: $Url"
            }
        }
    }

    $Text = $Raw.ToLowerInvariant()
    if ($Text -match '"credentials"\s*:') {
        throw "Workflow '$($Workflow.name)' contains a credentials field."
    }
    if ($Text -match 'instantly\.ai') {
        throw "Workflow '$($Workflow.name)' references an external Instantly endpoint."
    }

    return $Workflow
}

function Get-AllN8nWorkflows {
    $Items = @()
    $Cursor = $null

    do {
        $Uri = "$N8N_URL/api/v1/workflows?limit=250"
        if (-not [string]::IsNullOrWhiteSpace($Cursor)) {
            $Uri += '&cursor=' + [uri]::EscapeDataString($Cursor)
        }

        $Response = Invoke-RestMethod -Uri $Uri -Method Get -Headers $Headers

        $DataValue = Get-OptionalPropertyValue -Object $Response -Name 'data'
        $ItemsValue = Get-OptionalPropertyValue -Object $Response -Name 'items'

        $PageItems = @()
        if ($null -ne $DataValue) {
            $PageItems = @($DataValue)
        }
        elseif ($null -ne $ItemsValue) {
            $PageItems = @($ItemsValue)
        }

        $Items += $PageItems

        $NextCursorValue = Get-OptionalPropertyValue -Object $Response -Name 'nextCursor'
        if ([string]::IsNullOrWhiteSpace([string]$NextCursorValue)) {
            $NextCursorValue = Get-OptionalPropertyValue -Object $Response -Name 'next_cursor'
        }

        $Cursor = if ([string]::IsNullOrWhiteSpace([string]$NextCursorValue)) {
            $null
        }
        else {
            [string]$NextCursorValue
        }
    } while (-not [string]::IsNullOrWhiteSpace($Cursor))

    return @($Items)
}

function Assert-NoExistingExactNames {
    $Existing = @(Get-AllN8nWorkflows)
    $Matches = @($Existing | Where-Object { $ExpectedNames -contains [string]$_.name })

    if ($Matches.Count -gt 0) {
        $Summary = ($Matches | ForEach-Object { "name='$($_.name)' id='$($_.id)' active='$($_.active)'" }) -join '; '
        throw "Refusing to create duplicate Phase 4B workflows. Existing exact-name match(es): $Summary"
    }

    Write-Host 'Duplicate-name preflight: passed.'
}

function New-InactiveWorkflow {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$SourcePath
    )

    $CreateBody = [ordered]@{
        name        = $Workflow.name
        nodes       = @($Workflow.nodes)
        connections = $Workflow.connections
        settings    = $Workflow.settings
    } | ConvertTo-Json -Depth 100

    $Response = Invoke-RestMethod -Uri "$N8N_URL/api/v1/workflows" -Method Post -Headers $Headers -Body $CreateBody

    $CreatedActive = Get-OptionalPropertyValue -Object $Response -Name 'active'
    $CreatedName = Get-OptionalPropertyValue -Object $Response -Name 'name'

    if ($CreatedActive -eq $true) {
        throw "Created workflow '$CreatedName' unexpectedly returned active=true. Stop and deactivate it manually."
    }

    return $Response
}

$Created = @()
try {
    Assert-OfflineEvidence

    $WatchdogWorkflow = Read-SafeWorkflow -Path $WatchdogPath
    $HarnessWorkflow = Read-SafeWorkflow -Path $HarnessPath

    if ($WatchdogWorkflow.name -ne $ExpectedNames[0] -or $HarnessWorkflow.name -ne $ExpectedNames[1]) {
        throw 'Workflow names do not match the required exact names.'
    }

    # Read-only connectivity and duplicate-name preflight before any write.
    Assert-NoExistingExactNames

    $Created += New-InactiveWorkflow -Workflow $WatchdogWorkflow -SourcePath $WatchdogPath
    $Created += New-InactiveWorkflow -Workflow $HarnessWorkflow -SourcePath $HarnessPath

    Write-Host ''
    Write-Host 'PHASE_4B_IMPORT_COMPLETE'
    foreach ($Workflow in $Created) {
        Write-Host ("Name: {0}`nID: {1}`nActive: {2}`n" -f $Workflow.name, $Workflow.id, $Workflow.active)
    }
    Write-Host 'No workflow was activated.'
}
catch {
    Write-Host ''
    Write-Host 'PHASE_4B_IMPORT_FAILED'
    if ($Created.Count -gt 0) {
        Write-Host 'A partial import occurred. Do not rerun automatically and do not delete anything until reviewed.'
        foreach ($Workflow in $Created) {
            Write-Host ("Created before failure: name='{0}' id='{1}' active='{2}'" -f $Workflow.name, $Workflow.id, $Workflow.active)
        }
    }
    throw
}
finally {
    $ApiKey = $null
    $Headers = $null
    $WatchdogWorkflow = $null
    $HarnessWorkflow = $null
}
