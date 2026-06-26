#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$N8N_URL = 'http://127.0.0.1:5678'
$WatchdogId = '37p0OPzfDxlPvYQo'
$HarnessId = 'gu9Ede8IM5cHGtKK'
$Expected = @(
    [pscustomobject]@{
        Id = $WatchdogId
        Name = 'HMZ - Reply SLA Watchdog - Validation'
        RelativePath = 'workflows/05_reply_sla_watchdog_validation.json'
    },
    [pscustomobject]@{
        Id = $HarnessId
        Name = 'HMZ - Reply Full Test Harness - Validation'
        RelativePath = 'workflows/06_reply_full_test_harness_validation.json'
    }
)

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw 'HMZ_N8N_API_KEY is not set in this PowerShell process.'
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$ApiKey = $env:HMZ_N8N_API_KEY
$Headers = @{
    'X-N8N-API-KEY' = $ApiKey
    'Content-Type'  = 'application/json'
}

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $null }
    return $Property.Value
}

function Assert-LocalWorkflowSafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedName
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Workflow file not found: $Path"
    }

    $Raw = Get-Content -LiteralPath $Path -Raw
    $Workflow = $Raw | ConvertFrom-Json

    if ([string]$Workflow.name -ne $ExpectedName) {
        throw "Workflow name mismatch in $Path."
    }
    if ($Workflow.active -eq $true) {
        throw "Workflow '$ExpectedName' has active=true."
    }

    foreach ($Node in @($Workflow.nodes)) {
        if ($null -ne $Node.PSObject.Properties['credentials']) {
            throw "Workflow '$ExpectedName' node '$($Node.name)' contains credentials."
        }
        if ($Node.type -eq 'n8n-nodes-base.httpRequest') {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name 'url')
            if (-not $Url.StartsWith('http://hmz-send-state:5681')) {
                throw "Workflow '$ExpectedName' has a non-sidecar HTTP URL: $Url"
            }
        }
        if ($Node.type -eq 'n8n-nodes-base.code') {
            $Code = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name 'jsCode')
            if ($Code -match '\breturn\s*\{') {
                throw "Workflow '$ExpectedName' node '$($Node.name)' still contains a validator-ambiguous bare return-object pattern."
            }
        }
    }

    $Lower = $Raw.ToLowerInvariant()
    if ($Lower -match 'instantly\.ai') {
        throw "Workflow '$ExpectedName' contains an Instantly reference."
    }
    if ($Lower -match '"credentials"\s*:') {
        throw "Workflow '$ExpectedName' contains a credentials field."
    }

    return $Workflow
}

function Get-RemoteWorkflow {
    param([Parameter(Mandatory)][string]$Id)
    return Invoke-RestMethod -Uri "$N8N_URL/api/v1/workflows/$Id" -Method Get -Headers $Headers
}

function Update-RemoteWorkflow {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)]$Workflow
    )

    $Body = [ordered]@{
        name        = $Workflow.name
        nodes       = @($Workflow.nodes)
        connections = $Workflow.connections
        settings    = $Workflow.settings
    } | ConvertTo-Json -Depth 100

    return Invoke-RestMethod -Uri "$N8N_URL/api/v1/workflows/$Id" -Method Put -Headers $Headers -Body $Body
}

$Updated = @()
try {
    Write-Host 'Running local Phase 4B audited tests...'
    & node (Join-Path $RepoRoot 'verification/phase4b/run-offline-tests.mjs')
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4B offline tests failed with exit code $LASTEXITCODE."
    }

    foreach ($Item in $Expected) {
        $LocalPath = Join-Path $RepoRoot $Item.RelativePath
        $Local = Assert-LocalWorkflowSafe -Path $LocalPath -ExpectedName $Item.Name

        $RemoteBefore = Get-RemoteWorkflow -Id $Item.Id
        if ([string]$RemoteBefore.name -ne $Item.Name) {
            throw "Remote workflow $($Item.Id) name mismatch."
        }
        if ($RemoteBefore.active -eq $true) {
            throw "Remote workflow '$($Item.Name)' is active. Refusing update."
        }

        $UpdatedResponse = Update-RemoteWorkflow -Id $Item.Id -Workflow $Local
        if ([string]$UpdatedResponse.id -ne $Item.Id) {
            throw "Update response ID mismatch for '$($Item.Name)'."
        }

        $RemoteAfter = Get-RemoteWorkflow -Id $Item.Id
        if ($RemoteAfter.active -eq $true) {
            throw "Workflow '$($Item.Name)' became active after update."
        }

        $Updated += [pscustomobject]@{
            Name = [string]$RemoteAfter.name
            Id = [string]$RemoteAfter.id
            Active = [bool]$RemoteAfter.active
        }
    }

    Write-Host ''
    Write-Host 'PHASE_4B_VALIDATOR_FIX_UPDATE_COMPLETE'
    foreach ($Workflow in $Updated) {
        Write-Host ("Name: {0}`nID: {1}`nActive: {2}`n" -f $Workflow.Name, $Workflow.Id, $Workflow.Active)
    }
    Write-Host 'No workflow was activated.'
}
catch {
    Write-Host ''
    Write-Host 'PHASE_4B_VALIDATOR_FIX_UPDATE_FAILED'
    if ($Updated.Count -gt 0) {
        Write-Host 'A partial update occurred. Do not rerun automatically.'
        foreach ($Workflow in $Updated) {
            Write-Host ("Updated before failure: name='{0}' id='{1}' active='{2}'" -f $Workflow.Name, $Workflow.Id, $Workflow.Active)
        }
    }
    throw
}
finally {
    $ApiKey = $null
    $Headers = $null
}
