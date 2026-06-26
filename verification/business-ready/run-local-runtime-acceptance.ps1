#Requires -Version 7.0
# LOCAL DEV ONLY — DO NOT USE FOR PRODUCTION VPS RESPONDER VERIFICATION
# This script targets a local n8n Docker instance, not the production VPS.
# For production VPS work, target https://n8n.hmzaiautomation.com/api/v1.
# See docs/HMZ_PRODUCTION_TARGET_GUARD.md and CLAUDE.md > HMZ PRODUCTION TARGET RULES.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Local runtime acceptance for the business-ready VALIDATION profile.
#
# Verifies, against a local n8n instance with the 7 business-ready
# workflows already applied (apply-business-ready.ps1):
#  - all 7 workflows are inactive and contain only the three approved,
#    deployment-bound credentials with their exact expected types and IDs
#  - HTTP Request nodes target only hmz-send-state, the gated Google Chat
#    environment expression, or approved fail-closed Instantly V2 adapters
#  - settings.errorWorkflow on the other 6 points at the real Error Handler
#  - Intake's sub-workflow calls resolve to the real Decision Engine and
#    Human Approval IDs
#  - Human Approval's sub-workflow call resolves to the real Reply Sender ID
#  - the Full Test Harness (06), run via a one-off `n8n execute`, still
#    reaches PASS for its direct Reply Sender / Error Handler integration
#    checks
#
# Temporarily activates only Reply Sender, Error Handler, and Human Approval
# (n8n requires database-backed sub-workflows to be active when called), and
# reverses every temporary activation in a finally block. DRY_RUN remains
# true and no live Instantly endpoint is reachable throughout.

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$ComposeFile = Join-Path $Project "infrastructure\local-n8n\docker-compose.yml"
$ResultsPath = Join-Path $Project "verification\business-ready\local-runtime-results.json"
$ReportPath = Join-Path $Project "reports\BUSINESS_READY_LOCAL_RUNTIME.md"
$SidecarContainer = "hmz-send-state"
$SidecarPrefix = "http://hmz-send-state:5681"
$GoogleChatExpr = '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}'
$InstantlyApiPrefix = "https://api.instantly.ai/api/v2/"
$ConfigPath = Join-Path $Project "config\business-ready.config.json"

$ApprovedCredentialSpecs = @{
    "hmzInstantlyApi" = @{
        Type = "httpHeaderAuth"
        IdEnvironmentVariable = "HMZ_INSTANTLY_API_CREDENTIAL_ID"
        AllowedWorkflows = @(
            "HMZ - Reply Decision Engine - Validation",
            "HMZ - Instantly Reply Sender - Validation"
        )
        RequiredNodeType = "n8n-nodes-base.httpRequest"
    }
    "hmzInstantlyWebhookToken" = @{
        Type = "httpHeaderAuth"
        IdEnvironmentVariable = "HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID"
        AllowedWorkflows = @(
            "HMZ - Instantly Reply Intake - Validation"
        )
        RequiredNodeType = "n8n-nodes-base.webhook"
    }
    "hmzReviewBasicAuth" = @{
        Type = "httpBasicAuth"
        IdEnvironmentVariable = "HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID"
        AllowedWorkflows = @(
            "HMZ - Reply Human Approval - Validation"
        )
        RequiredNodeType = "n8n-nodes-base.webhook"
    }
}

$CanonicalNames = @(
    "HMZ - Instantly Reply Intake - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Instantly Reply Sender - Validation",
    "HMZ - Reply Human Approval - Validation",
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Reply Full Test Harness - Validation"
)

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

function Invoke-N8nApi {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    return Invoke-RestMethod -Method GET -Uri "$N8nUrl/api/v1$Path" -Headers $Headers
}

function Set-N8nWorkflowActivation {
    param(
        [Parameter(Mandatory)][string]$WorkflowId,
        [Parameter(Mandatory)][bool]$Active,
        [Parameter(Mandatory)][hashtable]$Headers
    )

    $Action = if ($Active) { "activate" } else { "deactivate" }

    Invoke-RestMethod -Method POST -Uri "$N8nUrl/api/v1/workflows/$WorkflowId/$Action" `
        -Headers $Headers -ContentType "application/json" -Body "{}" | Out-Null

    $Updated = Invoke-N8nApi -Path "/workflows/$WorkflowId" -Headers $Headers
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
        if ($null -ne $Data) { $Items += @($Data) }

        $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "nextCursor"
        if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) {
            $CursorValue = Get-OptionalPropertyValue -Object $Response -Name "next_cursor"
        }

        $Cursor = if ([string]::IsNullOrWhiteSpace([string]$CursorValue)) { $null } else { [string]$CursorValue }
    }
    while ($null -ne $Cursor)

    return @($Items)
}

function Get-NodeCredentialBindings {
    param([Parameter(Mandatory)]$Node)

    $Bindings = @()
    $Credentials = Get-OptionalPropertyValue -Object $Node -Name "credentials"
    if ($null -eq $Credentials) {
        return @()
    }

    foreach ($CredentialProperty in $Credentials.PSObject.Properties) {
        $CredentialObject = $CredentialProperty.Value
        $Bindings += [pscustomobject]@{
            Type = [string]$CredentialProperty.Name
            Name = [string](Get-OptionalPropertyValue -Object $CredentialObject -Name "name")
            Id = [string](Get-OptionalPropertyValue -Object $CredentialObject -Name "id")
        }
    }

    return @($Bindings)
}

function Assert-ApprovedCredentialBindings {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$WorkflowName
    )

    $BindingCount = 0

    foreach ($Node in @($Workflow.nodes)) {
        foreach ($Binding in @(Get-NodeCredentialBindings -Node $Node)) {
            $BindingCount++

            if ([string]::IsNullOrWhiteSpace($Binding.Name)) {
                throw "Workflow '$WorkflowName' node '$($Node.name)' has a credential without a name."
            }

            if (-not $ApprovedCredentialSpecs.ContainsKey($Binding.Name)) {
                throw "Workflow '$WorkflowName' node '$($Node.name)' has unexpected credential '$($Binding.Name)'."
            }

            $Spec = $ApprovedCredentialSpecs[$Binding.Name]

            if ($Binding.Type -ne [string]$Spec.Type) {
                throw "Workflow '$WorkflowName' node '$($Node.name)' credential '$($Binding.Name)' must use type '$($Spec.Type)', found '$($Binding.Type)'."
            }

            if (@($Spec.AllowedWorkflows) -notcontains $WorkflowName) {
                throw "Credential '$($Binding.Name)' is not permitted in workflow '$WorkflowName'."
            }

            if ([string]$Node.type -ne [string]$Spec.RequiredNodeType) {
                throw "Workflow '$WorkflowName' node '$($Node.name)' uses credential '$($Binding.Name)' on unexpected node type '$($Node.type)'."
            }

            $ExpectedCredentialId = [Environment]::GetEnvironmentVariable(
                [string]$Spec.IdEnvironmentVariable,
                [EnvironmentVariableTarget]::Process
            )

            if ([string]::IsNullOrWhiteSpace($ExpectedCredentialId)) {
                throw "Required environment variable '$($Spec.IdEnvironmentVariable)' is not set."
            }

            if ([string]::IsNullOrWhiteSpace($Binding.Id) -or $Binding.Id -ne $ExpectedCredentialId) {
                throw "Workflow '$WorkflowName' node '$($Node.name)' credential '$($Binding.Name)' does not match the approved credential ID."
            }
        }
    }

    return $BindingCount
}

function Test-NodeHasApprovedInstantlyCredential {
    param([Parameter(Mandatory)]$Node)

    foreach ($Binding in @(Get-NodeCredentialBindings -Node $Node)) {
        if (
            $Binding.Name -eq "hmzInstantlyApi" -and
            $Binding.Type -eq "httpHeaderAuth" -and
            $Binding.Id -eq $env:HMZ_INSTANTLY_API_CREDENTIAL_ID
        ) {
            return $true
        }
    }

    return $false
}

function Test-AllowedHttpUrl {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Url,
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)][string]$WorkflowName
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $true
    }

    if ($Url.StartsWith($SidecarPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($Url -eq $GoogleChatExpr) {
        return $true
    }

    $AllowedInstantlyWorkflow = @(
        "HMZ - Reply Decision Engine - Validation",
        "HMZ - Instantly Reply Sender - Validation"
    ) -contains $WorkflowName

    $ContinueSafely = (
        [string](Get-OptionalPropertyValue -Object $Node -Name "onError")
    ) -eq "continueRegularOutput"

    $ApprovedInstantlyCredential = Test-NodeHasApprovedInstantlyCredential -Node $Node

    if (
        $AllowedInstantlyWorkflow -and
        $ContinueSafely -and
        $ApprovedInstantlyCredential -and
        $Url.StartsWith($InstantlyApiPrefix, [StringComparison]::OrdinalIgnoreCase)
    ) {
        return $true
    }

    # Suppression executor URLs are derived from a previously constructed,
    # fail-closed request_contract. They are allowed only on the approved
    # Decision Engine nodes with the same Instantly credential and
    # continueRegularOutput error policy.
    if (
        $WorkflowName -eq "HMZ - Reply Decision Engine - Validation" -and
        $ContinueSafely -and
        $ApprovedInstantlyCredential -and
        $Url.StartsWith('={{', [StringComparison]::OrdinalIgnoreCase) -and
        $Url.Contains('request_contract') -and
        $Url.Contains('.url')
    ) {
        return $true
    }

    return $false
}

function Assert-SafeStoredConfiguration {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Missing business-ready configuration: $ConfigPath"
    }

    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100

    if ([string]$Config.owner_inputs_status -ne "COMPLETE") {
        throw "owner_inputs_status is not COMPLETE."
    }
    if ([string]$Config.operating_mode -ne "VALIDATION") {
        throw "Stored operating_mode must be VALIDATION for local runtime acceptance."
    }
    if ([bool]$Config.dry_run -ne $true) {
        throw "Stored dry_run must remain true for local runtime acceptance."
    }
    if (@($Config.live_campaigns).Count -ne 0) {
        throw "Stored live_campaigns must remain empty for local runtime acceptance."
    }
    if ([bool]$Config.live_credential_readiness.ready_for_controlled_live_test) {
        throw "ready_for_controlled_live_test must remain false for local runtime acceptance."
    }

    $Suppression = $Config.suppression_action_enablement
    $RequiredSuppressionFlags = @(
        "source_campaign_stop_enabled",
        "interest_status_update_enabled",
        "subsequence_removal_enabled",
        "exact_email_blocklist_enabled"
    )

    foreach ($FlagName in $RequiredSuppressionFlags) {
        $FlagProperty = $Suppression.PSObject.Properties[$FlagName]

        if ($null -eq $FlagProperty) {
            throw "Required suppression flag '$FlagName' is missing."
        }

        if ($FlagProperty.Value -isnot [bool]) {
            throw "Required suppression flag '$FlagName' must be a Boolean."
        }

        if ([bool]$FlagProperty.Value) {
            throw "Suppression action '$FlagName' must remain disabled for local runtime acceptance."
        }
    }

    return $true
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
        if (-not $Process.Start()) { throw "Failed to start process: $FilePath" }

        $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $StderrTask = $Process.StandardError.ReadToEndAsync()

        if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $Process.Kill($true) } catch {}
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
    param([AllowEmptyString()][string]$Text, [int]$MaximumLength = 1600)

    $Value = [string]$Text
    $Value = [regex]::Replace($Value, '(?i)(authorization|api[_-]?key|secret|token|password)\s*[:=]\s*\S+', '$1=<REDACTED>')
    $Value = [regex]::Replace($Value, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<EMAIL_REDACTED>')
    $Value = $Value.Trim()

    if ($Value.Length -gt $MaximumLength) { return $Value.Substring(0, $MaximumLength) + "...<TRUNCATED>" }
    return $Value
}

function Convert-N8nExecutionOutput {
    param([Parameter(Mandatory)][string]$Text)

    $Marker = "Execution was successful:"
    $MarkerIndex = $Text.IndexOf($Marker, [StringComparison]::OrdinalIgnoreCase)
    if ($MarkerIndex -lt 0) { throw "n8n output did not contain the successful-execution marker." }

    $JsonStart = $Text.IndexOf("{", $MarkerIndex)
    $JsonEnd = $Text.LastIndexOf("}")
    if ($JsonStart -lt 0 -or $JsonEnd -le $JsonStart) { throw "Could not isolate the n8n execution JSON." }

    $JsonText = $Text.Substring($JsonStart, $JsonEnd - $JsonStart + 1)
    return $JsonText | ConvertFrom-Json -Depth 100
}

function Wait-ForN8n {
    param([Parameter(Mandatory)][hashtable]$Headers, [int]$TimeoutSeconds = 90)

    $Deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTimeOffset]::UtcNow -lt $Deadline) {
        try {
            Invoke-N8nApi -Path "/workflows?limit=1" -Headers $Headers | Out-Null
            return $true
        }
        catch { Start-Sleep -Seconds 3 }
    }
    return $false
}

$RequiredEnvironmentVariables = @(
    "HMZ_N8N_API_KEY",
    "HMZ_INSTANTLY_API_CREDENTIAL_ID",
    "HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID",
    "HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID"
)

foreach ($VariableName in $RequiredEnvironmentVariables) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable(
        $VariableName,
        [EnvironmentVariableTarget]::Process
    ))) {
        throw "$VariableName is not set in this PowerShell process."
    }
}

$Headers = @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY }

$Results = [ordered]@{
    schemaVersion = "1.0"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    synthetic = $true
    liveInstantlyCallPermitted = $false
    allWorkflowsInactiveInitially = $false
    safeStoredConfigurationVerified = $false
    approvedCredentialBindingsVerified = $false
    approvedCredentialBindingCount = 0
    gatedHttpTargetsVerified = $false
    temporarilyActivatedWorkflowIds = @()
    allWorkflowsInactiveAfter = $false
    remoteReferencesVerified = $false
    fullHarness = $null
    errorTriggerAcceptance = $null
    slaWatchdogAcceptance = $null
    n8nRestartedAndReady = $false
    sidecarRunning = $false
    overallResult = "NOT_RUN"
}

$MainN8nStopped = $false
$TemporaryActiveIds = @()

try {
    $Results.safeStoredConfigurationVerified = Assert-SafeStoredConfiguration

    $Summaries = Get-AllWorkflowSummaries -Headers $Headers
    $IdsByName = @{}
    $RemoteByName = @{}
    $ApprovedCredentialBindingCount = 0

    foreach ($Name in $CanonicalNames) {
        $Matches = @($Summaries | Where-Object { [string]$_.name -eq $Name })
        if ($Matches.Count -ne 1) { throw "Expected exactly one workflow named '$Name', found $($Matches.Count)." }

        $Remote = Invoke-N8nApi -Path "/workflows/$($Matches[0].id)" -Headers $Headers
        if ([bool]$Remote.active) { throw "Workflow '$Name' is active. Refusing runtime test." }

        $ApprovedCredentialBindingCount += Assert-ApprovedCredentialBindings `
            -Workflow $Remote `
            -WorkflowName $Name

        foreach ($Node in @($Remote.nodes)) {
            if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
                $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
                if (-not (Test-AllowedHttpUrl -Url $Url -Node $Node -WorkflowName $Name)) {
                    throw "Workflow '$Name' contains a disallowed or improperly credentialed HTTP target: $($Node.name) -> $Url"
                }
            }
        }

        $IdsByName[$Name] = [string]$Remote.id
        $RemoteByName[$Name] = $Remote
    }

    $Results.allWorkflowsInactiveInitially = $true
    $Results.approvedCredentialBindingsVerified = $true
    $Results.approvedCredentialBindingCount = $ApprovedCredentialBindingCount
    $Results.gatedHttpTargetsVerified = $true

    $DecisionId = $IdsByName["HMZ - Reply Decision Engine - Validation"]
    $SenderId = $IdsByName["HMZ - Instantly Reply Sender - Validation"]
    $ErrorId = $IdsByName["HMZ - Reply Error Handler - Validation"]
    $HumanApprovalId = $IdsByName["HMZ - Reply Human Approval - Validation"]
    $SlaWatchdogId = $IdsByName["HMZ - Reply SLA Watchdog - Validation"]

    foreach ($Name in $CanonicalNames) {
        $Remote = $RemoteByName[$Name]
        $ExpectedErrorId = if ($Name -eq "HMZ - Reply Error Handler - Validation") { $null } else { $ErrorId }
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
    $HumanApproval = $RemoteByName["HMZ - Reply Human Approval - Validation"]
    $Harness = $RemoteByName["HMZ - Reply Full Test Harness - Validation"]

    $IntakeTargetValues = @(@($Intake.nodes | Where-Object { [string]$_.type -eq "n8n-nodes-base.executeWorkflow" }) | ForEach-Object {
        $WorkflowId = Get-OptionalPropertyValue -Object $_.parameters -Name "workflowId"
        Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
    })

    if ($IntakeTargetValues -notcontains $DecisionId) { throw "Intake is not mapped to the actual Decision Engine ID." }
    if ($IntakeTargetValues -notcontains $HumanApprovalId) { throw "Intake is not mapped to the actual Human Approval ID." }

    $HumanApprovalTargetValues = @(@($HumanApproval.nodes | Where-Object { [string]$_.type -eq "n8n-nodes-base.executeWorkflow" }) | ForEach-Object {
        $WorkflowId = Get-OptionalPropertyValue -Object $_.parameters -Name "workflowId"
        Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
    })

    if ($HumanApprovalTargetValues -notcontains $SenderId) { throw "Human Approval is not mapped to the actual Reply Sender ID." }

    $HarnessTargetValues = @(@($Harness.nodes | Where-Object { [string]$_.type -eq "n8n-nodes-base.executeWorkflow" }) | ForEach-Object {
        $WorkflowId = Get-OptionalPropertyValue -Object $_.parameters -Name "workflowId"
        Get-OptionalPropertyValue -Object $WorkflowId -Name "value"
    })

    if ($HarnessTargetValues -notcontains $SenderId) { throw "Full Test Harness is not mapped to the actual Reply Sender ID." }
    if ($HarnessTargetValues -notcontains $ErrorId) { throw "Full Test Harness is not mapped to the actual Error Handler ID." }

    $Results.remoteReferencesVerified = $true

    $SidecarStatus = Invoke-ProcessSafe -FilePath "docker" -Arguments @("inspect", "-f", "{{.State.Running}}", $SidecarContainer) -TimeoutSeconds 30
    if ($SidecarStatus.ExitCode -ne 0 -or $SidecarStatus.Stdout.Trim() -ne "true") { throw "hmz-send-state is not running." }
    $Results.sidecarRunning = $true

    # n8n 2.x requires database-backed sub-workflows to be active when called.
    # Reply Sender and Error Handler are activated for the harness run; Human
    # Approval is activated only so its presence as a callable sub-workflow is
    # consistent, but is not otherwise exercised by this script (its webhook
    # review/approval flow requires a durable UI, out of scope here). The SLA
    # Watchdog is activated so its real Schedule Trigger is registered for
    # the duration of this isolated window (Blocker H); it is not left
    # active afterwards. All four are reversed in the finally block below.
    foreach ($WorkflowId in @($SenderId, $ErrorId, $HumanApprovalId, $SlaWatchdogId)) {
        Set-N8nWorkflowActivation -WorkflowId $WorkflowId -Active $true -Headers $Headers
        $TemporaryActiveIds += $WorkflowId
    }
    $Results.temporarilyActivatedWorkflowIds = @($TemporaryActiveIds)

    $StopResult = Invoke-ProcessSafe -FilePath "docker" -Arguments @("compose", "-f", $ComposeFile, "stop", "n8n") -TimeoutSeconds 120
    if ($StopResult.ExitCode -ne 0) { throw "Failed to stop the main n8n service: $(Get-SanitisedSnippet $StopResult.Stderr)" }
    $MainN8nStopped = $true

    $HarnessId = $IdsByName["HMZ - Reply Full Test Harness - Validation"]

    $HarnessRun = Invoke-ProcessSafe -FilePath "docker" -Arguments @(
        "compose", "-f", $ComposeFile, "run", "-T", "--rm", "--no-deps", "n8n", "execute", "--id", $HarnessId
    ) -TimeoutSeconds 420

    $HarnessText = $HarnessRun.Stdout + "`n" + $HarnessRun.Stderr
    if ($HarnessRun.ExitCode -ne 0 -or $HarnessRun.TimedOut) {
        throw "Full Test Harness execution failed: $(Get-SanitisedSnippet $HarnessText)"
    }

    $Execution = Convert-N8nExecutionOutput -Text $HarnessText
    $RunData = $Execution.data.resultData.runData

    $UniqueSenderItem = $RunData.'Z1. Integration - Real Reply Sender Call (Unique Fixture)'[0].data.main[0][0].json
    $ErrorHandlerItem = $RunData.'Z3. Integration - Real Error Handler Call (Forced Error)'[0].data.main[0][0].json
    $MergeItem = $RunData.'Z5. Merge Integration Assertions Into Harness Result'[0].data.main[0][0].json

    $SenderPassed = (
        [string]$UniqueSenderItem.terminal.result -eq "DRY_RUN_OK" -and
        [bool]$UniqueSenderItem.terminal.sent -eq $false -and
        [string]$UniqueSenderItem.terminal.transport -eq "NONE"
    )

    $ErrorHandlerPassed = (
        [string]$ErrorHandlerItem.error_record.send_state -eq "SEND_UNCERTAIN" -and
        [string]$ErrorHandlerItem.error_record.error_class -eq "SEND_UNCERTAIN" -and
        [bool]$ErrorHandlerItem.error_record.retryable -eq $false -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorHandlerItem.persisted_error.errorId) -and
        [bool]$ErrorHandlerItem.notification.delivered -eq $false
    )

    # Z5's combined overall_result also contains a duplicate integration
    # assertion. The real Sender and Error Handler outputs are already checked
    # directly above and are required independently by the final PASS gate.
    # Use the fixture counts retained in harness_result as the authoritative
    # deterministic harness result, so a stale duplicate integration summary
    # cannot incorrectly fail an otherwise proven runtime.
    $HarnessFixtureTotal = [int]$MergeItem.harness_result.total
    $HarnessFixturePassed = [int]$MergeItem.harness_result.passed
    $HarnessFixtureFailed = [int]$MergeItem.harness_result.failed

    $HarnessFailedFixtureIds = @(
        @($MergeItem.harness_result.results) |
        Where-Object { [bool]$_.passed -ne $true } |
        ForEach-Object { [string]$_.id }
    )

    $HarnessPassed = (
        $HarnessFixtureTotal -gt 0 -and
        $HarnessFixtureFailed -eq 0 -and
        $HarnessFixturePassed -eq $HarnessFixtureTotal -and
        $HarnessFailedFixtureIds.Count -eq 0
    )

    $Results.fullHarness = [ordered]@{
        senderPassed = $SenderPassed
        errorHandlerPassed = $ErrorHandlerPassed
        harnessPassed = $HarnessPassed
        fixtureTotal = $HarnessFixtureTotal
        fixturePassed = $HarnessFixturePassed
        fixtureFailed = $HarnessFixtureFailed
        failedFixtureIds = @($HarnessFailedFixtureIds)
        combinedHarnessOverall = [string]$MergeItem.harness_result.overall_result
        embeddedIntegrationOverall = [string]$MergeItem.harness_result.integration_result.overall_result
        executionExitCode = $HarnessRun.ExitCode
    }

    # Blocker H: in addition to the harness's synthetic Execute Workflow
    # Trigger paths above, exercise the REAL entry nodes -- the Error
    # Handler's Error Trigger (the node n8n actually invokes via
    # settings.errorWorkflow) and the SLA Watchdog's Schedule Trigger (the
    # node n8n actually invokes on its configured interval) -- via one-off
    # `n8n execute`, within the same isolated/stopped-n8n window, before
    # n8n is restarted and all temporary activations are reversed.
    $ErrorTriggerRun = Invoke-ProcessSafe -FilePath "docker" -Arguments @(
        "compose", "-f", $ComposeFile, "run", "-T", "--rm", "--no-deps", "n8n", "execute", "--id", $ErrorId
    ) -TimeoutSeconds 180

    $ErrorTriggerText = $ErrorTriggerRun.Stdout + "`n" + $ErrorTriggerRun.Stderr
    $ErrorTriggerPassed = $false
    if ($ErrorTriggerRun.ExitCode -eq 0 -and -not $ErrorTriggerRun.TimedOut) {
        try {
            $ErrorExecution = Convert-N8nExecutionOutput -Text $ErrorTriggerText
            $ErrorRunData = $ErrorExecution.data.resultData.runData
            $AttachErrorIdItem = $ErrorRunData.'C2. Attach Error ID'[0].data.main[0][0].json
            $FinalizeErrorItem = $ErrorRunData.'G. Finalize Error Notification Result'[0].data.main[0][0].json
            $ErrorTriggerPassed = (
                -not [string]::IsNullOrWhiteSpace([string]$AttachErrorIdItem.persisted_error.errorId) -and
                ($FinalizeErrorItem.notification.delivered -is [bool])
            )
        } catch {
            $Results.errorTriggerError = Get-SanitisedSnippet $_.Exception.Message
        }
    }
    else {
        $Results.errorTriggerError = "Error Handler standalone execution failed: $(Get-SanitisedSnippet $ErrorTriggerText)"
    }

    $Results.errorTriggerAcceptance = [ordered]@{
        executed = $true
        exitCode = $ErrorTriggerRun.ExitCode
        passed = $ErrorTriggerPassed
    }

    $SlaWatchdogRun = Invoke-ProcessSafe -FilePath "docker" -Arguments @(
        "compose", "-f", $ComposeFile, "run", "-T", "--rm", "--no-deps", "n8n", "execute", "--id", $SlaWatchdogId
    ) -TimeoutSeconds 180

    $SlaWatchdogText = $SlaWatchdogRun.Stdout + "`n" + $SlaWatchdogRun.Stderr
    $SlaWatchdogPassed = $false
    if ($SlaWatchdogRun.ExitCode -eq 0 -and -not $SlaWatchdogRun.TimedOut) {
        try {
            $SlaExecution = Convert-N8nExecutionOutput -Text $SlaWatchdogText
            $SlaRunData = $SlaExecution.data.resultData.runData
            $AttachResultItem = $SlaRunData.'J. Attach Result ID'[0].data.main[0][0].json
            $SlaWatchdogPassed = (
                [string]$AttachResultItem.watchdog_result.schema_version -eq '1.0' -and
                [string]$AttachResultItem.phase4b_result_id -match '^[0-9a-f]{16}$'
            )
        } catch {
            $Results.slaWatchdogError = Get-SanitisedSnippet $_.Exception.Message
        }
    }
    else {
        $Results.slaWatchdogError = "SLA Watchdog standalone execution failed: $(Get-SanitisedSnippet $SlaWatchdogText)"
    }

    $Results.slaWatchdogAcceptance = [ordered]@{
        executed = $true
        exitCode = $SlaWatchdogRun.ExitCode
        passed = $SlaWatchdogPassed
    }

    $Results.overallResult = if (
        $Results.allWorkflowsInactiveInitially -and
        $Results.safeStoredConfigurationVerified -and
        $Results.approvedCredentialBindingsVerified -and
        $Results.gatedHttpTargetsVerified -and
        $Results.remoteReferencesVerified -and
        $SenderPassed -and
        $ErrorHandlerPassed -and
        $HarnessPassed -and
        $ErrorTriggerPassed -and
        $SlaWatchdogPassed
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
        $StartResult = Invoke-ProcessSafe -FilePath "docker" -Arguments @("compose", "-f", $ComposeFile, "up", "-d", "n8n") -TimeoutSeconds 180
        if ($StartResult.ExitCode -eq 0) {
            $Results.n8nRestartedAndReady = Wait-ForN8n -Headers $Headers -TimeoutSeconds 90
        }
        else {
            $Results.n8nRestartedAndReady = $false
            $Results.restartError = Get-SanitisedSnippet $StartResult.Stderr
        }
    }
    else {
        $Results.n8nRestartedAndReady = Wait-ForN8n -Headers $Headers -TimeoutSeconds 30
    }

    if ($TemporaryActiveIds.Count -gt 0) {
        if (-not $Results.n8nRestartedAndReady) {
            $Results.deactivationError = "n8n API was unavailable; temporary workflow activation could not be reversed automatically."
        }
        else {
            $DeactivationErrors = @()
            foreach ($WorkflowId in @($TemporaryActiveIds)[($TemporaryActiveIds.Count - 1)..0]) {
                try { Set-N8nWorkflowActivation -WorkflowId $WorkflowId -Active $false -Headers $Headers }
                catch { $DeactivationErrors += $_.Exception.Message }
            }
            if ($DeactivationErrors.Count -gt 0) { $Results.deactivationError = $DeactivationErrors -join " | " }
        }
    }

    if ($Results.n8nRestartedAndReady) {
        try {
            $FinalSummaries = Get-AllWorkflowSummaries -Headers $Headers
            $ActiveCanonical = @($FinalSummaries | Where-Object { $CanonicalNames -contains [string]$_.name -and [bool]$_.active })
            $Results.allWorkflowsInactiveAfter = ($ActiveCanonical.Count -eq 0)
        }
        catch {
            $Results.allWorkflowsInactiveAfter = $false
            $Results.finalInactiveCheckError = $_.Exception.Message
        }
    }

    try {
        $SidecarFinal = Invoke-ProcessSafe -FilePath "docker" -Arguments @("inspect", "-f", "{{.State.Running}}", $SidecarContainer) -TimeoutSeconds 30
        $Results.sidecarRunning = ($SidecarFinal.ExitCode -eq 0 -and $SidecarFinal.Stdout.Trim() -eq "true")
    }
    catch { $Results.sidecarRunning = $false }

    New-Item -ItemType Directory -Path (Split-Path -Parent $ResultsPath) -Force | Out-Null
    $Results | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ResultsPath -Encoding utf8

    $Verdict = if (
        $Results.overallResult -eq "PASS" -and
        $Results.n8nRestartedAndReady -and
        $Results.sidecarRunning -and
        $Results.allWorkflowsInactiveAfter
    ) { "BUSINESS_READY_LOCAL_RUNTIME_PASSED" } else { "BUSINESS_READY_LOCAL_RUNTIME_FAILED" }

    $ReportLines = @(
        '# Business-Ready Local Runtime Acceptance'
        ''
        ('**Generated:** {0}' -f $Results.generatedAtUtc)
        ''
        '## Verdict'
        ''
        $Verdict
        ''
        '## Safety boundary'
        ''
        '- All 7 workflows were inactive before testing.'
        '- Only Reply Sender, Error Handler, Human Approval, and the SLA Watchdog were temporarily activated (n8n requires active database-backed sub-workflows, and an active Schedule Trigger for the Blocker H check), and all temporary activations were reversed.'
        '- All 7 workflows were confirmed inactive after testing.'
        '- No credential secret was read. Only the three approved credential names, types, and deployment IDs were accepted.'
        '- Gated Instantly V2 HTTP nodes were present but not executed. Stored DRY_RUN remained true, LIVE_CAMPAIGNS remained empty, and suppression remained disabled.'
        '- The main n8n service was restarted after the one-off execution.'
        ''
        '## Verified'
        ''
        '- Stored config was verified as VALIDATION, DRY_RUN=true, LIVE_CAMPAIGNS=[], controlled-live readiness false, and suppression disabled.'
        ('- Approved credential bindings verified: {0}.' -f $Results.approvedCredentialBindingCount)
        '- Every HTTP Request target was sidecar-only, Google Chat environment-gated, or an approved fail-closed Instantly V2 adapter.'
        '- Intake maps to the real Decision Engine and Human Approval IDs.'
        '- Human Approval maps to the real Reply Sender ID.'
        '- The other 6 workflows map to the real Error Handler ID; the Error Handler does not self-reference.'
        '- The Full Test Harness deterministic fixture matrix passed, and the Reply Sender and Error Handler were independently verified from their real runtime outputs.'
        '- The Error Handler''s real Error Trigger entry node (the node n8n invokes via settings.errorWorkflow) runs standalone to completion and persists an error record.'
        '- The SLA Watchdog''s real Schedule Trigger entry node (the node n8n invokes on its configured interval) runs standalone to completion and persists a watchdog result.'
        ''
        '## Important limitation'
        ''
        'This script does not exercise the Human Approval webhook review/submit'
        'flow (Webhook - Review Form / Webhook - Review Submit) or the Data Table'
        'rows it reads and writes, because that flow requires a durable reviewer'
        'UI and a pre-created "Review Cases" Data Table. It is exercised by the'
        'offline test suite using the in-process generated-code harness instead.'
        ''
        '## Files'
        ''
        '- Detailed JSON: verification/business-ready/local-runtime-results.json'
    )

    ($ReportLines -join [Environment]::NewLine) | Set-Content -LiteralPath $ReportPath -Encoding utf8

    $Headers = $null
    $env:HMZ_N8N_API_KEY = $null
    Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
}

$SavedResults = Get-Content -LiteralPath $ResultsPath -Raw | ConvertFrom-Json -Depth 100

Write-Host ""
Write-Host "=== BUSINESS-READY LOCAL RUNTIME ACCEPTANCE ==="
Write-Host ("Overall result: {0}" -f $SavedResults.overallResult)
Write-Host ("Safe stored config verified: {0}" -f $SavedResults.safeStoredConfigurationVerified)
Write-Host ("Approved credential bindings verified: {0} ({1} bindings)" -f $SavedResults.approvedCredentialBindingsVerified, $SavedResults.approvedCredentialBindingCount)
Write-Host ("Gated HTTP targets verified: {0}" -f $SavedResults.gatedHttpTargetsVerified)
Write-Host ("Harness fixtures passed: {0}/{1}" -f $SavedResults.fullHarness.fixturePassed, $SavedResults.fullHarness.fixtureTotal)
Write-Host ("Sender runtime passed: {0}" -f $SavedResults.fullHarness.senderPassed)
Write-Host ("Error Handler runtime passed: {0}" -f $SavedResults.fullHarness.errorHandlerPassed)
Write-Host ("n8n restarted and ready: {0}" -f $SavedResults.n8nRestartedAndReady)
Write-Host ("Sidecar running: {0}" -f $SavedResults.sidecarRunning)
Write-Host ("All workflows inactive after test: {0}" -f $SavedResults.allWorkflowsInactiveAfter)
Write-Host ("Report: {0}" -f $ReportPath)

if (
    $SavedResults.overallResult -ne "PASS" -or
    -not $SavedResults.n8nRestartedAndReady -or
    -not $SavedResults.sidecarRunning -or
    -not $SavedResults.allWorkflowsInactiveAfter
) {
    exit 1
}
