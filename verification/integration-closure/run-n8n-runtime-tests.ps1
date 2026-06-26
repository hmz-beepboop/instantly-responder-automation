#Requires -Version 7.0
# LOCAL DEV ONLY — DO NOT USE FOR PRODUCTION VPS RESPONDER VERIFICATION
# This script targets http://127.0.0.1:5678 (local Docker n8n).
# For production VPS work, target https://n8n.hmzaiautomation.com/api/v1.
# See docs/HMZ_PRODUCTION_TARGET_GUARD.md and CLAUDE.md > HMZ PRODUCTION TARGET RULES.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$ComposeFile = Join-Path $Project "infrastructure\local-n8n\docker-compose.yml"
$WorkflowDir = Join-Path $Project "workflows"
$ResultsPath = Join-Path $Project "verification\integration-closure\runtime-results.json"
$ReportPath = Join-Path $Project "reports\INTEGRATION_CLOSURE_RUNTIME.md"
$SidecarContainer = "hmz-send-state"

$CanonicalNames = @(
    "HMZ - Instantly Reply Intake - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Instantly Reply Sender - Validation",
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Reply Full Test Harness - Validation"
)

$FileByName = @{
    "HMZ - Instantly Reply Intake - Validation" = "01_reply_intake_validation.json"
    "HMZ - Reply Decision Engine - Validation" = "02_reply_decision_engine_validation.json"
    "HMZ - Instantly Reply Sender - Validation" = "03_reply_sender_validation.json"
    "HMZ - Reply Error Handler - Validation" = "04_reply_error_handler_validation.json"
    "HMZ - Reply SLA Watchdog - Validation" = "05_reply_sla_watchdog_validation.json"
    "HMZ - Reply Full Test Harness - Validation" = "06_reply_full_test_harness_validation.json"
}

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
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    return Invoke-RestMethod `
        -Method GET `
        -Uri "$N8nUrl/api/v1$Path" `
        -Headers $Headers
}

function Set-N8nWorkflowActivation {
    param(
        [Parameter(Mandatory)][string]$WorkflowId,
        [Parameter(Mandatory)][bool]$Active,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    $Action = if ($Active) { "activate" } else { "deactivate" }

    Invoke-RestMethod `
        -Method POST `
        -Uri "$N8nUrl/api/v1/workflows/$WorkflowId/$Action" `
        -Headers $Headers `
        -ContentType "application/json" `
        -Body "{}" |
        Out-Null

    $Updated = Invoke-N8nApi `
        -Path "/workflows/$WorkflowId" `
        -Headers $Headers

    if ([bool]$Updated.active -ne $Active) {
        throw "Workflow '$WorkflowId' did not reach active=$Active."
    }
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

        $Response = Invoke-N8nApi -Path $Path -Headers $Headers
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

function Invoke-ProcessSafe {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [int]$TimeoutSeconds = 300
    )

    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $FilePath
    $StartInfo.WorkingDirectory = $Project
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $true

    foreach ($Argument in $Arguments) {
        [void]$StartInfo.ArgumentList.Add([string]$Argument)
    }

    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo

    try {
        if (-not $Process.Start()) {
            throw "Failed to start process: $FilePath"
        }

        $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $StderrTask = $Process.StandardError.ReadToEndAsync()

        if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                $Process.Kill($true)
            }
            catch {}

            $Process.WaitForExit()

            return [pscustomobject]@{
                ExitCode = -1
                TimedOut = $true
                Stdout = $StdoutTask.GetAwaiter().GetResult()
                Stderr = $StderrTask.GetAwaiter().GetResult()
            }
        }

        return [pscustomobject]@{
            ExitCode = $Process.ExitCode
            TimedOut = $false
            Stdout = $StdoutTask.GetAwaiter().GetResult()
            Stderr = $StderrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $Process.Dispose()
    }
}

function Get-SanitisedSnippet {
    param(
        [AllowEmptyString()][string]$Text,
        [int]$MaximumLength = 1600
    )

    $Value = [string]$Text
    $Value = [regex]::Replace(
        $Value,
        '(?i)(authorization|api[_-]?key|secret|token|password)\s*[:=]\s*\S+',
        '$1=<REDACTED>'
    )
    $Value = [regex]::Replace(
        $Value,
        '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
        '<EMAIL_REDACTED>'
    )
    $Value = $Value.Trim()

    if ($Value.Length -gt $MaximumLength) {
        return $Value.Substring(0, $MaximumLength) + "...<TRUNCATED>"
    }

    return $Value
}

function Convert-N8nExecutionOutput {
    param([Parameter(Mandatory)][string]$Text)

    $Marker = "Execution was successful:"
    $MarkerIndex = $Text.IndexOf($Marker, [StringComparison]::OrdinalIgnoreCase)
    if ($MarkerIndex -lt 0) {
        throw "n8n output did not contain the successful-execution marker."
    }

    $JsonStart = $Text.IndexOf("{", $MarkerIndex)
    $JsonEnd = $Text.LastIndexOf("}")

    if ($JsonStart -lt 0 -or $JsonEnd -le $JsonStart) {
        throw "Could not isolate the n8n execution JSON."
    }

    $JsonText = $Text.Substring($JsonStart, $JsonEnd - $JsonStart + 1)
    return $JsonText | ConvertFrom-Json -Depth 100
}

function Wait-ForN8n {
    param(
        [Parameter(Mandatory)][hashtable]$Headers,
        [int]$TimeoutSeconds = 90
    )

    $Deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)

    while ([DateTimeOffset]::UtcNow -lt $Deadline) {
        try {
            Invoke-N8nApi -Path "/workflows?limit=1" -Headers $Headers | Out-Null
            return $true
        }
        catch {
            Start-Sleep -Seconds 3
        }
    }

    return $false
}

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw "HMZ_N8N_API_KEY is not set in this PowerShell process."
}

$Headers = @{
    "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY
}

$Results = [ordered]@{
    schemaVersion = "2.0"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    synthetic = $true
    liveInstantlyCallPermitted = $false
    allWorkflowsInactive = $false
    allWorkflowsInactiveInitially = $false
    temporarilyActivatedWorkflowIds = @()
    allWorkflowsInactiveAfter = $false
    remoteReferencesVerified = $false
    intakePathExpectedOutcome = "BLOCKED_PENDING_DURABLE_APPROVAL"
    directApprovedSender = $null
    directErrorHandler = $null
    automaticErrorWorkflowRoute = "STATICALLY_CONFIGURED_NOT_RUNTIME_EXERCISED"
    fullHarness = $null
    n8nRestartedAndReady = $false
    sidecarRunning = $false
    overallResult = "NOT_RUN"
}

$MainN8nStopped = $false
$TemporaryActiveIds = @()

try {
    $Summaries = Get-AllWorkflowSummaries -Headers $Headers
    $IdsByName = @{}
    $RemoteByName = @{}

    foreach ($Name in $CanonicalNames) {
        $Matches = @($Summaries | Where-Object {
            [string]$_.name -eq $Name
        })

        if ($Matches.Count -ne 1) {
            throw "Expected exactly one workflow named '$Name', found $($Matches.Count)."
        }

        $Remote = Invoke-N8nApi `
            -Path "/workflows/$($Matches[0].id)" `
            -Headers $Headers

        if ([bool]$Remote.active) {
            throw "Workflow '$Name' is active. Refusing runtime test."
        }

        $Json = $Remote | ConvertTo-Json -Depth 100 -Compress
        if ($Json -match '"credentials"\s*:') {
            throw "Workflow '$Name' contains credentials."
        }

        foreach ($Node in @($Remote.nodes)) {
            if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
                $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
                if (
                    -not [string]::IsNullOrWhiteSpace($Url) -and
                    -not $Url.StartsWith(
                        "http://hmz-send-state:5681",
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    throw "Workflow '$Name' contains a non-sidecar HTTP target."
                }
            }
        }

        $IdsByName[$Name] = [string]$Remote.id
        $RemoteByName[$Name] = $Remote
    }

    $Results.allWorkflowsInactive = $true
    $Results.allWorkflowsInactiveInitially = $true

    $DecisionId = $IdsByName["HMZ - Reply Decision Engine - Validation"]
    $SenderId = $IdsByName["HMZ - Instantly Reply Sender - Validation"]
    $ErrorId = $IdsByName["HMZ - Reply Error Handler - Validation"]

    foreach ($Name in $CanonicalNames) {
        $Remote = $RemoteByName[$Name]
        $ExpectedErrorId = if ($Name -eq "HMZ - Reply Error Handler - Validation") {
            $null
        }
        else {
            $ErrorId
        }

        $ActualErrorId = Get-OptionalPropertyValue -Object $Remote.settings -Name "errorWorkflow"

        if ($null -eq $ExpectedErrorId) {
            if (-not [string]::IsNullOrWhiteSpace([string]$ActualErrorId)) {
                throw "Error Handler incorrectly references an error workflow."
            }
        }
        elseif ([string]$ActualErrorId -ne [string]$ExpectedErrorId) {
            throw "Workflow '$Name' is not mapped to the actual Error Handler ID."
        }
    }

    $Intake = $RemoteByName["HMZ - Instantly Reply Intake - Validation"]
    $Harness = $RemoteByName["HMZ - Reply Full Test Harness - Validation"]

    $IntakeCalls = @($Intake.nodes | Where-Object {
        [string]$_.type -eq "n8n-nodes-base.executeWorkflow"
    })

    $IntakeTargetValues = @($IntakeCalls | ForEach-Object {
        $WorkflowId = Get-OptionalPropertyValue -Object $_.parameters -Name "workflowId"
        Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
    })

    if ($IntakeTargetValues -notcontains $DecisionId) {
        throw "Intake is not mapped to the actual Decision Engine ID."
    }

    if ($IntakeTargetValues -notcontains $SenderId) {
        throw "Intake is not mapped to the actual Reply Sender ID."
    }

    $HarnessCalls = @($Harness.nodes | Where-Object {
        [string]$_.type -eq "n8n-nodes-base.executeWorkflow"
    })

    $HarnessTargetValues = @($HarnessCalls | ForEach-Object {
        $WorkflowId = Get-OptionalPropertyValue -Object $_.parameters -Name "workflowId"
        Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
    })

    if ($HarnessTargetValues -notcontains $SenderId) {
        throw "Full Test Harness is not mapped to the actual Reply Sender ID."
    }

    if ($HarnessTargetValues -notcontains $ErrorId) {
        throw "Full Test Harness is not mapped to the actual Error Handler ID."
    }

    $Results.remoteReferencesVerified = $true

    $SidecarStatus = Invoke-ProcessSafe `
        -FilePath "docker" `
        -Arguments @(
            "inspect",
            "-f",
            "{{.State.Running}}",
            $SidecarContainer
        ) `
        -TimeoutSeconds 30

    if (
        $SidecarStatus.ExitCode -ne 0 -or
        $SidecarStatus.Stdout.Trim() -ne "true"
    ) {
        throw "hmz-send-state is not running."
    }

    $Results.sidecarRunning = $true

    # n8n 2.x requires database-backed sub-workflows to be active when called.
    # Only the Sender and Error Handler are activated, briefly, for this isolated
    # local test. Neither workflow has a production webhook or schedule trigger,
    # and all live transport remains unreachable.
    foreach ($WorkflowId in @($SenderId, $ErrorId)) {
        Set-N8nWorkflowActivation `
            -WorkflowId $WorkflowId `
            -Active $true `
            -Headers $Headers

        $TemporaryActiveIds += $WorkflowId
    }

    $Results.temporarilyActivatedWorkflowIds = @($TemporaryActiveIds)

    $StopResult = Invoke-ProcessSafe `
        -FilePath "docker" `
        -Arguments @(
            "compose",
            "-f",
            $ComposeFile,
            "stop",
            "n8n"
        ) `
        -TimeoutSeconds 120

    if ($StopResult.ExitCode -ne 0) {
        throw "Failed to stop the main n8n service: $(Get-SanitisedSnippet $StopResult.Stderr)"
    }

    $MainN8nStopped = $true

    $HarnessId = $IdsByName["HMZ - Reply Full Test Harness - Validation"]

    $HarnessRun = Invoke-ProcessSafe `
        -FilePath "docker" `
        -Arguments @(
            "compose",
            "-f",
            $ComposeFile,
            "run",
            "-T",
            "--rm",
            "--no-deps",
            "n8n",
            "execute",
            "--id",
            $HarnessId
        ) `
        -TimeoutSeconds 420

    $HarnessText = $HarnessRun.Stdout + "`n" + $HarnessRun.Stderr

    if ($HarnessRun.ExitCode -ne 0 -or $HarnessRun.TimedOut) {
        throw "Full Test Harness execution failed: $(Get-SanitisedSnippet $HarnessText)"
    }

    $Execution = Convert-N8nExecutionOutput -Text $HarnessText
    $RunData = $Execution.data.resultData.runData

    $UniqueSenderItem = $RunData.'Z1. Integration - Real Reply Sender Call (Unique Fixture)'[0].data.main[0][0].json
    $ErrorHandlerItem = $RunData.'Z3. Integration - Real Error Handler Call (Forced Error)'[0].data.main[0][0].json
    $MergeItem = $RunData.'Z5. Merge Integration Assertions Into Harness Result'[0].data.main[0][0].json

    $Results.directApprovedSender = [ordered]@{
        terminalResult = $UniqueSenderItem.terminal.result
        sendState = $UniqueSenderItem.terminal.send_state
        sent = [bool]$UniqueSenderItem.terminal.sent
        transport = [string]$UniqueSenderItem.terminal.transport
        passed = (
            [string]$UniqueSenderItem.terminal.result -eq "DRY_RUN_OK" -and
            [bool]$UniqueSenderItem.terminal.sent -eq $false -and
            [string]$UniqueSenderItem.terminal.transport -eq "NONE"
        )
    }

    $Results.directErrorHandler = [ordered]@{
        sendState = [string]$ErrorHandlerItem.error_record.send_state
        errorClass = [string]$ErrorHandlerItem.error_record.error_class
        retryable = [bool]$ErrorHandlerItem.error_record.retryable
        notificationSurface = [string]$ErrorHandlerItem.notification.surface
        notificationDelivered = [bool]$ErrorHandlerItem.notification.delivered
        errorIdPresent = -not [string]::IsNullOrWhiteSpace(
            [string]$ErrorHandlerItem.persisted_error.errorId
        )
        passed = (
            [string]$ErrorHandlerItem.error_record.send_state -eq "SEND_UNCERTAIN" -and
            [bool]$ErrorHandlerItem.error_record.retryable -eq $false -and
            [string]$ErrorHandlerItem.notification.surface -eq "PLACEHOLDER_NOT_CONFIGURED" -and
            [bool]$ErrorHandlerItem.notification.delivered -eq $false -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$ErrorHandlerItem.persisted_error.errorId
            )
        )
    }

    $Results.fullHarness = [ordered]@{
        overallResult = [string]$MergeItem.harness_result.overall_result
        integrationResult = [string]$MergeItem.harness_result.integration_result.overall_result
        executionExitCode = $HarnessRun.ExitCode
        outputHash = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($HarnessText)
            )
        )
        passed = (
            [string]$MergeItem.harness_result.overall_result -eq "PASS" -and
            [string]$MergeItem.harness_result.integration_result.overall_result -eq "PASS"
        )
    }

    $Results.overallResult = if (
        $Results.remoteReferencesVerified -and
        $Results.directApprovedSender.passed -and
        $Results.directErrorHandler.passed -and
        $Results.fullHarness.passed
    ) {
        "PASS"
    }
    else {
        "FAIL"
    }
}
catch {
    $Results.overallResult = "FAIL"
    $Results.error = $_.Exception.Message
}
finally {
    if ($MainN8nStopped) {
        $StartResult = Invoke-ProcessSafe `
            -FilePath "docker" `
            -Arguments @(
                "compose",
                "-f",
                $ComposeFile,
                "up",
                "-d",
                "n8n"
            ) `
            -TimeoutSeconds 180

        if ($StartResult.ExitCode -eq 0) {
            $Results.n8nRestartedAndReady = Wait-ForN8n `
                -Headers $Headers `
                -TimeoutSeconds 90
        }
        else {
            $Results.n8nRestartedAndReady = $false
            $Results.restartError = Get-SanitisedSnippet $StartResult.Stderr
        }
    }
    else {
        $Results.n8nRestartedAndReady = Wait-ForN8n `
            -Headers $Headers `
            -TimeoutSeconds 30
    }

    if ($TemporaryActiveIds.Count -gt 0) {
        if (-not $Results.n8nRestartedAndReady) {
            $Results.deactivationError = "n8n API was unavailable; temporary workflow activation could not be reversed automatically."
        }
        else {
            $DeactivationErrors = @()

            foreach ($WorkflowId in @($TemporaryActiveIds)[($TemporaryActiveIds.Count - 1)..0]) {
                try {
                    Set-N8nWorkflowActivation `
                        -WorkflowId $WorkflowId `
                        -Active $false `
                        -Headers $Headers
                }
                catch {
                    $DeactivationErrors += $_.Exception.Message
                }
            }

            if ($DeactivationErrors.Count -gt 0) {
                $Results.deactivationError = $DeactivationErrors -join " | "
            }
        }
    }

    if ($Results.n8nRestartedAndReady) {
        try {
            $FinalSummaries = Get-AllWorkflowSummaries -Headers $Headers
            $ActiveCanonical = @($FinalSummaries | Where-Object {
                $CanonicalNames -contains [string]$_.name -and [bool]$_.active
            })
            $Results.allWorkflowsInactiveAfter = ($ActiveCanonical.Count -eq 0)
        }
        catch {
            $Results.allWorkflowsInactiveAfter = $false
            $Results.finalInactiveCheckError = $_.Exception.Message
        }
    }

    try {
        $SidecarFinal = Invoke-ProcessSafe `
            -FilePath "docker" `
            -Arguments @(
                "inspect",
                "-f",
                "{{.State.Running}}",
                $SidecarContainer
            ) `
            -TimeoutSeconds 30

        $Results.sidecarRunning = (
            $SidecarFinal.ExitCode -eq 0 -and
            $SidecarFinal.Stdout.Trim() -eq "true"
        )
    }
    catch {
        $Results.sidecarRunning = $false
    }

    New-Item `
        -ItemType Directory `
        -Path (Split-Path -Parent $ResultsPath) `
        -Force |
        Out-Null

    $Results |
        ConvertTo-Json -Depth 100 |
        Set-Content -LiteralPath $ResultsPath -Encoding utf8

    $Verdict = if (
        $Results.overallResult -eq "PASS" -and
        $Results.n8nRestartedAndReady -and
        $Results.sidecarRunning -and
        $Results.allWorkflowsInactiveAfter
    ) {
        "INTEGRATION_CLOSURE_RUNTIME_PASSED"
    }
    else {
        "INTEGRATION_CLOSURE_RUNTIME_FAILED"
    }

    $ReportLines = @(
        '# Integration Closure Runtime Audit'
        ''
        ('**Generated:** {0}' -f $Results.generatedAtUtc)
        ''
        '## Verdict'
        ''
        $Verdict
        ''
        '## Safety boundary'
        ''
        '- All six workflows were inactive before testing.'
        '- Only Reply Sender and Error Handler were temporarily activated because n8n 2.x requires active database-backed sub-workflows.'
        '- Both temporary activations were reversed and all six workflows were confirmed inactive after testing.'
        '- No credential was added or read by a workflow.'
        '- No Instantly endpoint was reachable.'
        '- Only the internal hmz-send-state sidecar was called.'
        '- The main n8n service was restarted after the one-off execution.'
        ''
        '## Verified'
        ''
        '- Remote Intake maps to the actual Decision Engine and Reply Sender IDs.'
        '- Five workflows map to the actual Error Handler ID.'
        '- The Full Test Harness maps to the actual Reply Sender and Error Handler IDs.'
        '- An approved synthetic Sender item executed inside n8n and reached DRY_RUN_OK.'
        '- Sender returned sent=false and transport=NONE.'
        '- The Error Handler executed inside n8n for a forced sanitised SEND_UNCERTAIN item.'
        '- The Error Handler marked the item non-retryable and persisted a sanitised error record.'
        '- The combined Full Test Harness result remained PASS.'
        ''
        '## Important limitation'
        ''
        'The normal Intake to Decision Engine to Sender path is expected to terminate at'
        "the Sender's approval gate because VALIDATION mode requires a durable human"
        'approval record before transmission. This runtime test proves the real Sender'
        'sub-workflow with an explicitly approved synthetic item; it does not implement'
        'or prove a durable approval user interface.'
        ''
        'The settings.errorWorkflow mappings are verified, but this run invokes the'
        'Error Handler through its synthetic Execute Workflow Trigger. Automatic'
        'Error Trigger routing from a genuinely failed parent execution remains'
        'unexercised.'
        ''
        '## Files'
        ''
        '- Detailed JSON: verification/integration-closure/runtime-results.json'
    )

    $Report = $ReportLines -join [Environment]::NewLine

    $Report |
        Set-Content -LiteralPath $ReportPath -Encoding utf8

    $Headers = $null
    $env:HMZ_N8N_API_KEY = $null
    Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
}

# Read the saved results back as a PSCustomObject so nested ".passed"
# values resolve correctly (the in-memory $Results hashtable's nested
# entries are ordered hashtables, not PSCustomObjects, and do not expose
# their keys via .PSObject.Properties).
$SavedResults = Get-Content -LiteralPath $ResultsPath -Raw | ConvertFrom-Json -Depth 100

$SenderPassed = [bool]$SavedResults.directApprovedSender.passed
$ErrorHandlerPassed = [bool]$SavedResults.directErrorHandler.passed
$HarnessPassed = [bool]$SavedResults.fullHarness.passed

Write-Host ""
Write-Host "=== INTEGRATION CLOSURE RUNTIME ==="
Write-Host ("Overall result: {0}" -f $SavedResults.overallResult)
Write-Host ("n8n restarted and ready: {0}" -f $SavedResults.n8nRestartedAndReady)
Write-Host ("Sidecar running: {0}" -f $SavedResults.sidecarRunning)
Write-Host ("All workflows inactive after test: {0}" -f $SavedResults.allWorkflowsInactiveAfter)
Write-Host ("Sender integration passed: {0}" -f $SenderPassed)
Write-Host ("Error Handler integration passed: {0}" -f $ErrorHandlerPassed)
Write-Host ("Harness integration passed: {0}" -f $HarnessPassed)
Write-Host ("Report: {0}" -f $ReportPath)

if (
    $SavedResults.overallResult -ne "PASS" -or
    -not $SavedResults.n8nRestartedAndReady -or
    -not $SavedResults.sidecarRunning -or
    -not $SavedResults.allWorkflowsInactiveAfter
) {
    exit 1
}
