#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$SidecarPrefix = "http://hmz-send-state:5681"
$WorkflowDir = Join-Path $Project "workflows"
$ResultsPath = Join-Path $Project "verification\integration-closure\offline-test-results.json"
$ReportPath = Join-Path $Project "reports\INTEGRATION_CLOSURE_OFFLINE_BUILD.md"
$BackupRoot = Join-Path $Project "verification\integration-closure\preapply-backup"

$PlaceholderDecision = "__PLACEHOLDER_DECISION_ENGINE_WORKFLOW_ID__"
$PlaceholderSender = "__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__"
$PlaceholderError = "__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__"

$Specs = @(
    [pscustomobject]@{
        Key = "ERROR_HANDLER"
        Name = "HMZ - Reply Error Handler - Validation"
        File = "04_reply_error_handler_validation.json"
    },
    [pscustomobject]@{
        Key = "DECISION_ENGINE"
        Name = "HMZ - Reply Decision Engine - Validation"
        File = "02_reply_decision_engine_validation.json"
    },
    [pscustomobject]@{
        Key = "REPLY_SENDER"
        Name = "HMZ - Instantly Reply Sender - Validation"
        File = "03_reply_sender_validation.json"
    },
    [pscustomobject]@{
        Key = "SLA_WATCHDOG"
        Name = "HMZ - Reply SLA Watchdog - Validation"
        File = "05_reply_sla_watchdog_validation.json"
    },
    [pscustomobject]@{
        Key = "FULL_HARNESS"
        Name = "HMZ - Reply Full Test Harness - Validation"
        File = "06_reply_full_test_harness_validation.json"
    },
    [pscustomobject]@{
        Key = "INTAKE"
        Name = "HMZ - Instantly Reply Intake - Validation"
        File = "01_reply_intake_validation.json"
    }
)

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

function Invoke-N8nApi {
    param(
        [Parameter(Mandatory)][ValidateSet("GET","PUT")][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body = $null,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    $Uri = "$N8nUrl/api/v1$Path"

    if ($null -ne $Body) {
        $Json = $Body | ConvertTo-Json -Depth 100
        return Invoke-RestMethod `
            -Method $Method `
            -Uri $Uri `
            -Headers $Headers `
            -Body $Json `
            -ContentType "application/json"
    }

    return Invoke-RestMethod `
        -Method $Method `
        -Uri $Uri `
        -Headers $Headers
}

function Get-AllWorkflowSummaries {
    param([Parameter(Mandatory)][hashtable]$Headers)

    $Items = @()
    $Cursor = $null

    do {
        $Path = "/workflows?limit=250"
        if (-not [string]::IsNullOrWhiteSpace($Cursor)) {
            $Path += "&cursor=$([Uri]::EscapeDataString($Cursor))"
        }

        $Response = Invoke-N8nApi -Method GET -Path $Path -Headers $Headers
        $Data = Get-OptionalPropertyValue -Object $Response -Name "data"
        if ($null -ne $Data) {
            $Items += @($Data)
        }

        $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "nextCursor"
        if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) {
            $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "next_cursor"
        }

        $Cursor = if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) {
            $null
        }
        else {
            [string]$CursorValue
        }
    }
    while ($null -ne $Cursor)

    return @($Items)
}

function Assert-OfflineGate {
    if (-not (Test-Path -LiteralPath $ResultsPath -PathType Leaf)) {
        throw "Missing offline results: $ResultsPath"
    }

    $Results = Get-Content -LiteralPath $ResultsPath -Raw | ConvertFrom-Json
    if ([string]$Results.overall_result -ne "PASS") {
        throw "Offline integration suite is not PASS."
    }

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        throw "Missing offline build report: $ReportPath"
    }

    $Report = Get-Content -LiteralPath $ReportPath -Raw
    if ($Report -notmatch "INTEGRATION_CLOSURE_OFFLINE_READY") {
        throw "Offline build report does not contain INTEGRATION_CLOSURE_OFFLINE_READY."
    }
}

function Assert-WorkflowBodySafe {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName
    )

    if ([string]$Workflow.name -ne $ExpectedName) {
        throw "Local workflow name mismatch. Expected '$ExpectedName', got '$($Workflow.name)'."
    }

    if ([bool]$Workflow.active) {
        throw "Local workflow '$ExpectedName' has active=true."
    }

    $Json = $Workflow | ConvertTo-Json -Depth 100 -Compress
    if ($Json -match '"credentials"\s*:') {
        throw "Local workflow '$ExpectedName' contains a credentials object."
    }

    foreach ($Node in @($Workflow.nodes)) {
        if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
            if (
                -not [string]::IsNullOrWhiteSpace($Url) -and
                -not $Url.StartsWith($SidecarPrefix, [StringComparison]::OrdinalIgnoreCase)
            ) {
                throw "Workflow '$ExpectedName' has a non-sidecar HTTP target: $($Node.name) -> $Url"
            }
        }
    }
}

function Assert-RemoteSafe {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName
    )

    if ([string]$Workflow.name -ne $ExpectedName) {
        throw "Remote workflow name mismatch for '$ExpectedName'."
    }

    if ([bool]$Workflow.active) {
        throw "Remote workflow '$ExpectedName' is active. Refusing update."
    }

    $Json = $Workflow | ConvertTo-Json -Depth 100 -Compress
    if ($Json -match '"credentials"\s*:') {
        throw "Remote workflow '$ExpectedName' contains a credentials object."
    }

    foreach ($Node in @($Workflow.nodes)) {
        if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
            if (
                -not [string]::IsNullOrWhiteSpace($Url) -and
                -not $Url.StartsWith($SidecarPrefix, [StringComparison]::OrdinalIgnoreCase)
            ) {
                throw "Remote workflow '$ExpectedName' has a non-sidecar HTTP target."
            }
        }
    }
}

function Patch-WorkflowIds {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][hashtable]$Ids
    )

    $Json = $Workflow | ConvertTo-Json -Depth 100
    $Json = $Json.Replace($PlaceholderDecision, [string]$Ids.DECISION_ENGINE)
    $Json = $Json.Replace($PlaceholderSender, [string]$Ids.REPLY_SENDER)
    $Json = $Json.Replace($PlaceholderError, [string]$Ids.ERROR_HANDLER)

    if ($Json.Contains("__PLACEHOLDER_")) {
        throw "One or more workflow-ID placeholders remain after patching."
    }

    return $Json | ConvertFrom-Json -Depth 100
}

function Assert-PatchedRemoteReferences {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][hashtable]$Ids,
        [Parameter(Mandatory)][string]$SpecKey
    )

    $Json = $Workflow | ConvertTo-Json -Depth 100 -Compress
    if ($Json.Contains("__PLACEHOLDER_")) {
        throw "Remote workflow '$($Workflow.name)' still contains a placeholder."
    }

    if ($SpecKey -ne "ERROR_HANDLER") {
        $ErrorWorkflow = Get-OptionalPropertyValue -Object $Workflow.settings -Name "errorWorkflow"
        if ([string]$ErrorWorkflow -ne [string]$Ids.ERROR_HANDLER) {
            throw "Remote workflow '$($Workflow.name)' is not assigned to the real Error Handler ID."
        }
    }
    else {
        $SelfErrorWorkflow = Get-OptionalPropertyValue -Object $Workflow.settings -Name "errorWorkflow"
        if (-not [string]::IsNullOrWhiteSpace([string]$SelfErrorWorkflow)) {
            throw "Error Handler must not reference itself as errorWorkflow."
        }
    }

    foreach ($Node in @($Workflow.nodes | Where-Object {
        [string]$_.type -eq "n8n-nodes-base.executeWorkflow"
    })) {
        $WorkflowId = Get-OptionalPropertyValue -Object $Node.parameters -Name "workflowId"
        $Value = if ($null -ne $WorkflowId) {
            Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
        }
        else {
            $null
        }

        if ([string]::IsNullOrWhiteSpace([string]$Value)) {
            throw "Execute Sub-workflow node '$($Node.name)' has no workflow ID."
        }
    }
}

Assert-OfflineGate

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw "HMZ_N8N_API_KEY is not set in this PowerShell process."
}

$Headers = @{
    "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY
}

$Timestamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
$BackupDir = Join-Path $BackupRoot $Timestamp
$Status = [ordered]@{}

try {
    $Summaries = Get-AllWorkflowSummaries -Headers $Headers
    $RemoteByKey = @{}
    $LocalByKey = @{}
    $Ids = @{}

    foreach ($Spec in $Specs) {
        $Matches = @($Summaries | Where-Object {
            [string]$_.name -eq [string]$Spec.Name
        })

        if ($Matches.Count -ne 1) {
            throw "Expected exactly one existing workflow named '$($Spec.Name)' (refusing to proceed on zero matches or duplicate matches), found $($Matches.Count). This audited script updates the current validated instance only."
        }

        $Remote = Invoke-N8nApi `
            -Method GET `
            -Path "/workflows/$($Matches[0].id)" `
            -Headers $Headers

        Assert-RemoteSafe -Workflow $Remote -ExpectedName $Spec.Name

        $LocalPath = Join-Path $WorkflowDir $Spec.File
        if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
            throw "Missing local workflow export: $LocalPath"
        }

        $Local = Get-Content -LiteralPath $LocalPath -Raw | ConvertFrom-Json -Depth 100
        Assert-WorkflowBodySafe -Workflow $Local -ExpectedName $Spec.Name

        $RemoteByKey[$Spec.Key] = $Remote
        $LocalByKey[$Spec.Key] = $Local
        $Ids[$Spec.Key] = [string]$Remote.id
        $Status[$Spec.Key] = "PREFLIGHT_OK"
    }

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    foreach ($Spec in $Specs) {
        $BackupPath = Join-Path $BackupDir $Spec.File
        $RemoteByKey[$Spec.Key] |
            ConvertTo-Json -Depth 100 |
            Set-Content -LiteralPath $BackupPath -Encoding utf8
    }

    foreach ($Spec in $Specs) {
        $Patched = Patch-WorkflowIds -Workflow $LocalByKey[$Spec.Key] -Ids $Ids

        $Body = @{
            name = $Patched.name
            nodes = $Patched.nodes
            connections = $Patched.connections
            settings = $Patched.settings
        }

        Invoke-N8nApi `
            -Method PUT `
            -Path "/workflows/$($Ids[$Spec.Key])" `
            -Body $Body `
            -Headers $Headers |
            Out-Null

        $Status[$Spec.Key] = "UPDATED"
    }

    foreach ($Spec in $Specs) {
        $Remote = Invoke-N8nApi `
            -Method GET `
            -Path "/workflows/$($Ids[$Spec.Key])" `
            -Headers $Headers

        Assert-RemoteSafe -Workflow $Remote -ExpectedName $Spec.Name
        Assert-PatchedRemoteReferences `
            -Workflow $Remote `
            -Ids $Ids `
            -SpecKey $Spec.Key

        $Status[$Spec.Key] = "UPDATED_AND_VERIFIED"
    }

    Write-Host ""
    Write-Host "INTEGRATION_CLOSURE_APPLY_COMPLETE"
    Write-Host ("Backup directory: {0}" -f $BackupDir)

    foreach ($Spec in $Specs) {
        Write-Host ("{0}: {1} | ID={2} | Active=False" -f
            $Spec.Name,
            $Status[$Spec.Key],
            $Ids[$Spec.Key]
        )
    }
}
catch {
    Write-Host ""
    Write-Host "INTEGRATION_CLOSURE_APPLY_FAILED"
    Write-Host ("Reason: {0}" -f $_.Exception.Message)

    foreach ($Spec in $Specs) {
        $Current = if ($Status.Contains($Spec.Key)) {
            $Status[$Spec.Key]
        }
        else {
            "NOT_STARTED"
        }

        Write-Host ("{0}: {1}" -f $Spec.Name, $Current)
    }

    throw
}
finally {
    $Headers = $null
    $env:HMZ_N8N_API_KEY = $null
    Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
}
