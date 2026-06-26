#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Applies the 7 inactive business-ready VALIDATION workflow exports to the
# current local n8n instance, replacing only {name, nodes, connections,
# settings} on workflows that already exist by exact name. Does not create,
# delete, or activate any workflow, bind any credential, populate
# LIVE_CAMPAIGNS, or contact Instantly. This script must not be run until the
# offline gate below passes.

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$SidecarPrefix = "http://hmz-send-state:5681"
$GoogleChatExpr = '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}'
$InstantlyApiPrefix = "https://api.instantly.ai/"
$InstantlyCredentialNames = @("hmzInstantlyApi", "hmzInstantlyWebhookToken")
$ReviewCredentialNames = @("hmzReviewBasicAuth")

# Credential type by credentialPlaceholder name. hmzInstantlyApi and
# hmzInstantlyWebhookToken bind as httpHeaderAuth (Bearer / shared-secret
# header); hmzReviewBasicAuth binds as httpBasicAuth and is never routed
# through the Instantly credential map.
$CredentialTypeByPlaceholder = @{
    "hmzInstantlyApi"           = "httpHeaderAuth"
    "hmzInstantlyWebhookToken"  = "httpHeaderAuth"
    "hmzReviewBasicAuth"        = "httpBasicAuth"
}
$WorkflowDir = Join-Path $Project "workflows"
$ResultsPath = Join-Path $Project "verification\business-ready\offline-test-results.json"
$ReportPath = Join-Path $Project "reports\BUSINESS_READY_OFFLINE_BUILD.md"
$BackupRoot = Join-Path $Project "verification\business-ready\preapply-backup"
$LivePathResultsPath = Join-Path $Project "verification\business-ready\live-path-offline-results.json"
$ConfigPath = Join-Path $Project "config\business-ready.config.json"

$PlaceholderDecision = "__PLACEHOLDER_DECISION_ENGINE_WORKFLOW_ID__"
$PlaceholderSender = "__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__"
$PlaceholderError = "__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__"
$PlaceholderHumanApproval = "__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__"
$PlaceholderReviewCasesTable = "__PLACEHOLDER_REVIEW_CASES_DATA_TABLE_ID__"
$PlaceholderIdempotencyTable = "__PLACEHOLDER_IDEMPOTENCY_DATA_TABLE_ID__"

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
        Key = "HUMAN_APPROVAL"
        Name = "HMZ - Reply Human Approval - Validation"
        File = "07_reply_human_approval_validation.json"
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

function ConvertTo-JsLiteral {
    param($Value)

    if ($null -eq $Value) {
        return "null"
    }

    return (ConvertTo-Json -InputObject $Value -Depth 20 -Compress)
}

function Assert-OwnerInputsComplete {
    param([Parameter(Mandatory)]$Config)

    if ([string]$Config.owner_inputs_status -ne "COMPLETE") {
        throw "config.owner_inputs_status is not 'COMPLETE'. Owner inputs are incomplete (see BUSINESS_READY_OWNER_INPUTS.md); refusing to apply."
    }

    $ConfigJson = ConvertTo-Json -InputObject $Config -Depth 100 -Compress
    if ($ConfigJson -match '<REQUIRED_[A-Z0-9_]+>') {
        throw "config/business-ready.config.json still contains an unfilled <REQUIRED_*> placeholder despite owner_inputs_status='COMPLETE'. Refusing to apply."
    }
}

function Assert-NoRemainingPlaceholderTokens {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName
    )

    # Only the double-underscore __REQUIRED_*__ convention is a workflow-JSON
    # token resolved by Resolve-RequiredTokens (e.g. webhook paths). The
    # <REQUIRED_*> convention is config-level and is checked once, across the
    # whole config, by Assert-OwnerInputsComplete.
    $Json = ConvertTo-Json -InputObject $Workflow -Depth 100 -Compress
    if ($Json -match '__REQUIRED_[A-Z0-9_]+__') {
        throw "Workflow '$ExpectedName' still contains an unfilled __REQUIRED_*__ placeholder after config injection."
    }
}

function Resolve-RequiredTokens {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][hashtable]$TokenMap
    )

    $Json = ConvertTo-Json -InputObject $Workflow -Depth 100
    foreach ($Token in $TokenMap.Keys) {
        $Value = [string]$TokenMap[$Token]
        if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '^<REQUIRED_[A-Z0-9_]+>$') {
            throw "No usable config value to resolve workflow token '$Token' (config value is '$Value')."
        }

        $Json = $Json.Replace($Token, $Value)
    }

    return $Json | ConvertFrom-Json -Depth 100
}

function Set-InjectedJsConstant {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$NodeName,
        [Parameter(Mandatory)][string]$MarkerName,
        [Parameter(Mandatory)][string]$VarName,
        [Parameter(Mandatory)]$Value
    )

    $Matches = @($Workflow.nodes | Where-Object { [string]$_.name -eq $NodeName })
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one node named '$NodeName' for HMZ_INJECT marker '$MarkerName', found $($Matches.Count)."
    }
    $Node = $Matches[0]

    $Code = [string]$Node.parameters.jsCode
    $BeginMarker = "// HMZ_INJECT_BEGIN:$MarkerName"
    $EndMarker = "// HMZ_INJECT_END:$MarkerName"
    $BeginIdx = $Code.IndexOf($BeginMarker)
    $EndIdx = $Code.IndexOf($EndMarker)
    if ($BeginIdx -lt 0 -or $EndIdx -lt 0 -or $EndIdx -le $BeginIdx) {
        throw "HMZ_INJECT markers for '$MarkerName' not found in node '$NodeName'."
    }

    $ValueLiteral = ConvertTo-JsLiteral -Value $Value
    $Replacement = "$BeginMarker`r`nconst $VarName = $ValueLiteral;`r`n$EndMarker"
    $EndOfEndMarker = $EndIdx + $EndMarker.Length
    $Node.parameters.jsCode = $Code.Substring(0, $BeginIdx) + $Replacement + $Code.Substring($EndOfEndMarker)
}

function Assert-InjectedConstantsMatchConfig {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName,
        [Parameter(Mandatory)][array]$Checks
    )

    foreach ($Check in $Checks) {
        $Matches = @($Workflow.nodes | Where-Object { [string]$_.name -eq $Check.NodeName })
        if ($Matches.Count -ne 1) {
            throw "Remote workflow '$ExpectedName' is missing node '$($Check.NodeName)' for HMZ_INJECT verification (found $($Matches.Count))."
        }

        $Code = [string]$Matches[0].parameters.jsCode
        $BeginMarker = "// HMZ_INJECT_BEGIN:$($Check.MarkerName)"
        $EndMarker = "// HMZ_INJECT_END:$($Check.MarkerName)"
        $BeginIdx = $Code.IndexOf($BeginMarker)
        $EndIdx = $Code.IndexOf($EndMarker)
        if ($BeginIdx -lt 0 -or $EndIdx -lt 0 -or $EndIdx -le $BeginIdx) {
            throw "Remote workflow '$ExpectedName' node '$($Check.NodeName)' is missing HMZ_INJECT markers for '$($Check.MarkerName)'."
        }

        $Block = $Code.Substring($BeginIdx, ($EndIdx + $EndMarker.Length) - $BeginIdx)
        $Pattern = "const $([regex]::Escape($Check.VarName)) = (?<value>[\s\S]+?);\s*$([regex]::Escape($EndMarker))"
        $Match = [regex]::Match($Block, $Pattern)
        if (-not $Match.Success) {
            throw "Remote workflow '$ExpectedName' node '$($Check.NodeName)' - could not parse injected '$($Check.VarName)'."
        }

        $Actual = ConvertFrom-Json -InputObject $Match.Groups['value'].Value -Depth 100 -NoEnumerate
        $ExpectedJson = ConvertTo-JsLiteral -Value $Check.Value
        $ActualJson = ConvertTo-Json -InputObject $Actual -Depth 100 -Compress
        if ($ActualJson -ne $ExpectedJson) {
            throw "Remote workflow '$ExpectedName' node '$($Check.NodeName)' - injected '$($Check.VarName)' does not match config.`nExpected: $ExpectedJson`nActual:   $ActualJson"
        }
    }
}

function Assert-OfflineGate {
    if (-not (Test-Path -LiteralPath $ResultsPath -PathType Leaf)) {
        throw "Missing offline results: $ResultsPath"
    }

    $Results = Get-Content -LiteralPath $ResultsPath -Raw | ConvertFrom-Json
    if ([string]$Results.overall_result -ne "PASS") {
        throw "Business-ready offline suite is not PASS."
    }

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        throw "Missing offline build report: $ReportPath"
    }

    $Report = Get-Content -LiteralPath $ReportPath -Raw
    if ($Report -match "BUSINESS_READY_OFFLINE_BLOCKED") {
        throw "Offline build report is BUSINESS_READY_OFFLINE_BLOCKED. Refusing to apply."
    }
    if (
        $Report -notmatch "BUSINESS_READY_OFFLINE_READY" -and
        $Report -notmatch "BUSINESS_READY_OFFLINE_PARTIAL"
    ) {
        throw "Offline build report does not contain a BUSINESS_READY_OFFLINE_READY or BUSINESS_READY_OFFLINE_PARTIAL verdict."
    }

    if (-not (Test-Path -LiteralPath $LivePathResultsPath -PathType Leaf)) {
        throw "Missing live-path offline results: $LivePathResultsPath"
    }

    $LivePathResults = Get-Content -LiteralPath $LivePathResultsPath -Raw | ConvertFrom-Json
    if ([string]$LivePathResults.overall_result -ne "PASS") {
        throw "Business-ready live-path offline suite is not PASS."
    }
}

function Test-AllowedHttpUrl {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Url,
        [Parameter(Mandatory)]$Node
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

    if ($Url.StartsWith($InstantlyApiPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        # The live-path build (verification/business-ready/build-live-path.mjs)
        # added real, gated Instantly adapters. They are allowed here only
        # when they carry the credentialPlaceholder/credential marking
        # "hmzInstantlyApi" and never throw the workflow on error; the
        # 14-gate live-send evaluation (workflow 03 node O) keeps them
        # structurally unreachable until the owner approves the live path.
        $Placeholder = [string](Get-OptionalPropertyValue -Object $Node -Name "credentialPlaceholder")
        $CredentialName = $null
        $Credentials = Get-OptionalPropertyValue -Object $Node -Name "credentials"
        if ($null -ne $Credentials) {
            $HttpHeaderAuth = Get-OptionalPropertyValue -Object $Credentials -Name "httpHeaderAuth"
            if ($null -ne $HttpHeaderAuth) {
                $CredentialName = [string](Get-OptionalPropertyValue -Object $HttpHeaderAuth -Name "name")
            }
        }

        $IsGatedInstantlyAdapter =
            ($Placeholder -eq "hmzInstantlyApi" -or $CredentialName -eq "hmzInstantlyApi") -and
            ([string](Get-OptionalPropertyValue -Object $Node -Name "onError")) -eq "continueRegularOutput"

        if ($IsGatedInstantlyAdapter) {
            return $true
        }
    }

    # Per-action suppression executors (workflow 02, G1h-G4h) derive their URL
    # at runtime from safety_action_plan.actions[].request_contract.url, which
    # is itself always an https://api.instantly.ai/... endpoint built by node
    # F (buildSafetyActionPlan); they are gated the same way as above.
    if ($Url.StartsWith('={{', [StringComparison]::OrdinalIgnoreCase) -and
        $Url.Contains('request_contract') -and
        $Url.Contains('.url')) {
        $Placeholder = [string](Get-OptionalPropertyValue -Object $Node -Name "credentialPlaceholder")
        $CredentialName = $null
        $Credentials = Get-OptionalPropertyValue -Object $Node -Name "credentials"
        if ($null -ne $Credentials) {
            $HttpHeaderAuth = Get-OptionalPropertyValue -Object $Credentials -Name "httpHeaderAuth"
            if ($null -ne $HttpHeaderAuth) {
                $CredentialName = [string](Get-OptionalPropertyValue -Object $HttpHeaderAuth -Name "name")
            }
        }

        $IsGatedInstantlyAdapterExpression =
            ($Placeholder -eq "hmzInstantlyApi" -or $CredentialName -eq "hmzInstantlyApi") -and
            ([string](Get-OptionalPropertyValue -Object $Node -Name "onError")) -eq "continueRegularOutput"

        if ($IsGatedInstantlyAdapterExpression) {
            return $true
        }
    }

    return $false
}

function Assert-NoUnexpectedCredentials {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName,
        [Parameter(Mandatory)][bool]$InstantlyReady,
        [Parameter(Mandatory)][bool]$ReviewBasicAuthReady
    )

    foreach ($Node in @($Workflow.nodes)) {
        $Credentials = Get-OptionalPropertyValue -Object $Node -Name "credentials"
        if ($null -eq $Credentials) {
            continue
        }

        foreach ($CredProp in $Credentials.PSObject.Properties) {
            $CredType = [string]$CredProp.Name
            $CredName = [string](Get-OptionalPropertyValue -Object $CredProp.Value -Name "name")

            if ($ReviewCredentialNames -contains $CredName) {
                if (-not $ReviewBasicAuthReady) {
                    throw "Workflow '$ExpectedName' node '$($Node.name)' has credential '$CredName', but config.live_credential_readiness.review_basic_auth is false."
                }
                if ($CredType -ne "httpBasicAuth") {
                    throw "Workflow '$ExpectedName' node '$($Node.name)' credential '$CredName' must be bound as httpBasicAuth, found '$CredType'."
                }
                continue
            }

            if ($InstantlyCredentialNames -contains $CredName) {
                if (-not $InstantlyReady) {
                    throw "Workflow '$ExpectedName' node '$($Node.name)' has credential '$CredName', but config.live_credential_readiness.instantly is false."
                }
                if ($CredType -ne "httpHeaderAuth") {
                    throw "Workflow '$ExpectedName' node '$($Node.name)' credential '$CredName' must be bound as httpHeaderAuth, found '$CredType'."
                }
                continue
            }

            throw "Workflow '$ExpectedName' node '$($Node.name)' has an unexpected credential '$CredName'."
        }
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

    # Local exports never carry a credentials object: gated live-path nodes
    # use credentialPlaceholder (hmzInstantlyApi / hmzInstantlyWebhookToken)
    # instead, resolved only at apply time when the owner has bound them.
    $Json = $Workflow | ConvertTo-Json -Depth 100 -Compress
    if ($Json -match '"credentials"\s*:') {
        throw "Local workflow '$ExpectedName' contains a credentials object."
    }

    foreach ($Node in @($Workflow.nodes)) {
        if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
            if (-not (Test-AllowedHttpUrl -Url $Url -Node $Node)) {
                throw "Workflow '$ExpectedName' has a disallowed HTTP target: $($Node.name) -> $Url"
            }
        }
    }
}

function Assert-RemoteSafe {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ExpectedName,
        [Parameter(Mandatory)][bool]$InstantlyReady,
        [Parameter(Mandatory)][bool]$ReviewBasicAuthReady
    )

    if ([string]$Workflow.name -ne $ExpectedName) {
        throw "Remote workflow name mismatch for '$ExpectedName'."
    }

    if ([bool]$Workflow.active) {
        throw "Remote workflow '$ExpectedName' is active. Refusing update."
    }

    Assert-NoUnexpectedCredentials -Workflow $Workflow -ExpectedName $ExpectedName -InstantlyReady $InstantlyReady -ReviewBasicAuthReady $ReviewBasicAuthReady

    foreach ($Node in @($Workflow.nodes)) {
        if ([string]$Node.type -eq "n8n-nodes-base.httpRequest") {
            $Url = [string](Get-OptionalPropertyValue -Object $Node.parameters -Name "url")
            if (-not (Test-AllowedHttpUrl -Url $Url -Node $Node)) {
                throw "Remote workflow '$ExpectedName' has a disallowed HTTP target."
            }
        }
    }
}

function Patch-WorkflowIds {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][hashtable]$Ids,
        [Parameter(Mandatory)][string]$ReviewCasesTableId,
        [Parameter(Mandatory)][string]$IdempotencyTableId
    )

    $Json = $Workflow | ConvertTo-Json -Depth 100
    $Json = $Json.Replace($PlaceholderDecision, [string]$Ids.DECISION_ENGINE)
    $Json = $Json.Replace($PlaceholderSender, [string]$Ids.REPLY_SENDER)
    $Json = $Json.Replace($PlaceholderError, [string]$Ids.ERROR_HANDLER)
    $Json = $Json.Replace($PlaceholderHumanApproval, [string]$Ids.HUMAN_APPROVAL)
    $Json = $Json.Replace($PlaceholderReviewCasesTable, $ReviewCasesTableId)
    $Json = $Json.Replace($PlaceholderIdempotencyTable, $IdempotencyTableId)

    if ($Json.Contains("__PLACEHOLDER_")) {
        throw "One or more workflow-ID or data-table-ID placeholders remain after patching."
    }

    return $Json | ConvertFrom-Json -Depth 100
}

function Resolve-CredentialPlaceholders {
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][bool]$InstantlyReady,
        [Parameter(Mandatory)][bool]$ReviewBasicAuthReady,
        [Parameter(Mandatory)][hashtable]$CredentialIds
    )

    foreach ($Node in @($Workflow.nodes)) {
        $Placeholder = [string](Get-OptionalPropertyValue -Object $Node -Name "credentialPlaceholder")
        if ([string]::IsNullOrWhiteSpace($Placeholder)) {
            continue
        }

        $CredType = [string]$CredentialTypeByPlaceholder[$Placeholder]
        if ([string]::IsNullOrWhiteSpace($CredType)) {
            throw "Unknown credential type for credentialPlaceholder '$Placeholder' on node '$($Node.name)'."
        }

        $Ready = if ($CredType -eq "httpBasicAuth") { $ReviewBasicAuthReady } else { $InstantlyReady }
        if (-not $Ready) {
            # Leave credentialPlaceholder as-is. The 14-gate live-send
            # evaluation (workflow 03 node O), the production security gate
            # (workflow 01 node F1), and the reviewer-allowlist gate
            # (workflow 07 node M1) keep these nodes structurally
            # unreachable/unauthenticated until the owner sets the matching
            # config.live_credential_readiness.* flag.
            continue
        }

        $CredentialId = [string]$CredentialIds[$Placeholder]
        if ([string]::IsNullOrWhiteSpace($CredentialId)) {
            throw "Required readiness flag is true but no credential ID was supplied for credentialPlaceholder '$Placeholder' on node '$($Node.name)'."
        }

        $CredentialsObject = if ($CredType -eq "httpBasicAuth") {
            [pscustomobject]@{
                httpBasicAuth = [pscustomobject]@{
                    id   = $CredentialId
                    name = $Placeholder
                }
            }
        }
        else {
            [pscustomobject]@{
                httpHeaderAuth = [pscustomobject]@{
                    id   = $CredentialId
                    name = $Placeholder
                }
            }
        }

        $Node | Add-Member -NotePropertyName "credentials" -Force -NotePropertyValue $CredentialsObject

        if ($Node.PSObject.Properties.Match("credentialPlaceholder").Count -gt 0) {
            $Node.PSObject.Properties.Remove("credentialPlaceholder")
        }
    }

    return $Workflow
}

# Assert-PatchedRemoteReferences performs the final structural-safety checks
# on a patched remote workflow body before it is considered ready:
#   - no remaining __PLACEHOLDER_* tokens survived ID patching;
#   - settings.errorWorkflow points at the real Error Handler workflow ID
#     (except the Error Handler itself, which must not self-reference);
#   - every Execute Workflow node carries a resolved sub-workflow ID; and
#   - every Data Table node carries a resolved data table ID.
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

    foreach ($Node in @($Workflow.nodes | Where-Object {
        [string]$_.type -eq "n8n-nodes-base.dataTable"
    })) {
        $DataTableId = Get-OptionalPropertyValue -Object $Node.parameters -Name "dataTableId"
        $Value = if ($null -ne $DataTableId) {
            Get-OptionalPropertyValue -Object $DataTableId -Name "value"
        }
        else {
            $null
        }

        if ([string]::IsNullOrWhiteSpace([string]$Value)) {
            throw "Data Table node '$($Node.name)' has no data table ID."
        }
    }
}

Assert-OfflineGate

if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
    throw "HMZ_N8N_API_KEY is not set in this PowerShell process."
}

if ([string]::IsNullOrWhiteSpace($env:HMZ_REVIEW_CASES_DATA_TABLE_ID)) {
    throw "HMZ_REVIEW_CASES_DATA_TABLE_ID is not set. Create the 'Review Cases' Data Table in n8n first (see docs/BUSINESS_READY_OWNER_INPUTS_REFERENCE.md), then set this env var to its ID."
}

if ([string]::IsNullOrWhiteSpace($env:HMZ_IDEMPOTENCY_DATA_TABLE_ID)) {
    throw "HMZ_IDEMPOTENCY_DATA_TABLE_ID is not set. Create the 'hmz_validation_reply_intake_idempotency' Data Table in n8n first, then set this env var to its ID."
}

$ReviewCasesTableId = $env:HMZ_REVIEW_CASES_DATA_TABLE_ID
$IdempotencyTableId = $env:HMZ_IDEMPOTENCY_DATA_TABLE_ID

$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100
Assert-OwnerInputsComplete -Config $Config
$InstantlyCredentialReady = [bool]$Config.live_credential_readiness.instantly
$ReviewBasicAuthReady = [bool](Get-OptionalPropertyValue -Object $Config.live_credential_readiness -Name "review_basic_auth")

# config/business-ready.config.json is injected as the single source of
# truth for the gate-evaluation/allowlist/suppression constants that the
# offline build wrapped in "// HMZ_INJECT_BEGIN:<NAME>" / "// HMZ_INJECT_END:<NAME>"
# marker comments. Each entry below is re-embedded verbatim into the named
# code node before the workflow ID/credential placeholders are resolved, and
# is re-verified against config after the remote update (Assert-InjectedConstantsMatchConfig).
# Transform the owner-approved config sender mapping into the camelCase shape
# consumed by Workflow 02's draft preparation node. The account email remains
# the lookup key, so the draft signature and booking link follow the exact
# Instantly eaccount that received the reply. There is no default/fallback.
$DecisionSenderConfig = [ordered]@{}
foreach ($SenderProperty in $Config.sender_mapping.PSObject.Properties) {
    $SenderKey = ([string]$SenderProperty.Name).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($SenderKey)) {
        throw "config.sender_mapping contains a blank sender key."
    }
    $SenderValue = $SenderProperty.Value
    $SenderName = [string](Get-OptionalPropertyValue -Object $SenderValue -Name "sender_name")
    $BookingLink = [string](Get-OptionalPropertyValue -Object $SenderValue -Name "booking_link")
    if ([string]::IsNullOrWhiteSpace($SenderName) -or [string]::IsNullOrWhiteSpace($BookingLink)) {
        throw "config.sender_mapping entry '$SenderKey' is missing sender_name or booking_link."
    }
    $DecisionSenderConfig[$SenderKey] = [ordered]@{
        senderName  = $SenderName
        bookingLink = $BookingLink
    }
}

$InjectionsBySpecKey = @{
    REPLY_SENDER = @(
        [pscustomobject]@{
            NodeName = "O. Live Send Gate Evaluation (14 Gates)"
            MarkerName = "LAUNCH_PROFILE"
            VarName = "LAUNCH_PROFILE"
            Value = [ordered]@{
                required_operating_mode    = [string]$Config.launch_profile.required_operating_mode
                operating_mode             = [string]$Config.operating_mode
                dry_run                    = [bool]$Config.dry_run
                live_campaigns             = @($Config.live_campaigns)
                campaign_allowlist         = @($Config.allowlists.campaign_ids)
                workspace_id               = [string]$Config.allowlists.workspace_id
                workspace_allowlist        = @($Config.workspace_allowlist)
                connected_sender_eaccounts = @($Config.allowlists.connected_sender_eaccounts)
                live_credential_readiness  = [ordered]@{
                    instantly                       = [bool]$Config.live_credential_readiness.instantly
                    ready_for_controlled_live_test  = [bool]$Config.live_credential_readiness.ready_for_controlled_live_test
                }
                reviewer_allowlist = @($Config.reviewer_allowlist)
            }
        }
    )
    INTAKE = @(
        [pscustomobject]@{
            NodeName = "F1. Production Security & Allowlist Gate"
            MarkerName = "ALLOWLISTS"
            VarName = "ALLOWLISTS"
            Value = [ordered]@{
                workspace_id               = [string]$Config.allowlists.workspace_id
                campaign_ids               = @($Config.allowlists.campaign_ids)
                connected_sender_eaccounts = @($Config.allowlists.connected_sender_eaccounts)
            }
        }
    )
    HUMAN_APPROVAL = @(
        [pscustomobject]@{
            NodeName = "A. Build Review Case Record"
            MarkerName = "RUNTIME_CONFIG"
            VarName = "CONFIG"
            Value = $Config
        },
        [pscustomobject]@{
            NodeName = "M1. Reviewer Identity Allowlist Check"
            MarkerName = "REVIEWER_ALLOWLIST"
            VarName = "REVIEWER_ALLOWLIST"
            Value = @($Config.reviewer_allowlist)
        }
    )
    DECISION_ENGINE = @(
        [pscustomobject]@{
            NodeName = "D. Draft Preparation (Templates / Human Draft)"
            MarkerName = "SENDER_CONFIG"
            VarName = "SENDER_CONFIG"
            Value = $DecisionSenderConfig
        },
        [pscustomobject]@{
            NodeName = "F. Safety Action Plan (Gated Contract, Pre-Approval)"
            MarkerName = "SUPPRESSION_ACTION_ENABLEMENT"
            VarName = "SUPPRESSION_ACTION_ENABLEMENT"
            Value = [ordered]@{
                source_campaign_stop_enabled   = [bool]$Config.suppression_action_enablement.source_campaign_stop_enabled
                interest_status_update_enabled = [bool]$Config.suppression_action_enablement.interest_status_update_enabled
                subsequence_removal_enabled    = [bool]$Config.suppression_action_enablement.subsequence_removal_enabled
                exact_email_blocklist_enabled  = [bool]$Config.suppression_action_enablement.exact_email_blocklist_enabled
            }
        }
    )
    ERROR_HANDLER = @(
        [pscustomobject]@{
            NodeName = "D. Build Notification Payload (Gated)"
            MarkerName = "RUNTIME_CONFIG"
            VarName = "CONFIG"
            Value = $Config
        }
    )
    SLA_WATCHDOG = @(
        [pscustomobject]@{
            NodeName = "G. Merge Alert Dedupe Results"
            MarkerName = "RUNTIME_CONFIG"
            VarName = "CONFIG"
            Value = $Config
        }
    )
}

# __REQUIRED_*__ tokens embedded directly in workflow JSON (e.g. webhook
# paths), resolved from config rather than HMZ_INJECT code-node markers.
$RequiredTokenMapBySpecKey = @{
    HUMAN_APPROVAL = @{
        "__REQUIRED_PRODUCTION_REVIEW_FORM_PATH__"   = [string]$Config.review.production_review_form_path
        "__REQUIRED_PRODUCTION_REVIEW_SUBMIT_PATH__" = [string]$Config.review.production_review_submit_path
    }
}

$CredentialIds = @{}
if ($InstantlyCredentialReady) {
    if ([string]::IsNullOrWhiteSpace($env:HMZ_INSTANTLY_API_CREDENTIAL_ID)) {
        throw "config.live_credential_readiness.instantly is true but HMZ_INSTANTLY_API_CREDENTIAL_ID is not set. Bind the 'hmzInstantlyApi' credential (httpHeaderAuth) in n8n and set this env var to its credential ID."
    }
    if ([string]::IsNullOrWhiteSpace($env:HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID)) {
        throw "config.live_credential_readiness.instantly is true but HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID is not set. Bind the 'hmzInstantlyWebhookToken' credential (httpHeaderAuth) in n8n and set this env var to its credential ID."
    }

    $CredentialIds["hmzInstantlyApi"] = $env:HMZ_INSTANTLY_API_CREDENTIAL_ID
    $CredentialIds["hmzInstantlyWebhookToken"] = $env:HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID
}

if ($ReviewBasicAuthReady) {
    if ([string]::IsNullOrWhiteSpace($env:HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID)) {
        throw "config.live_credential_readiness.review_basic_auth is true but HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID is not set. Bind the 'hmzReviewBasicAuth' credential (httpBasicAuth) in n8n and set this env var to its credential ID."
    }

    $CredentialIds["hmzReviewBasicAuth"] = $env:HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID
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

        Assert-RemoteSafe -Workflow $Remote -ExpectedName $Spec.Name -InstantlyReady $InstantlyCredentialReady -ReviewBasicAuthReady $ReviewBasicAuthReady

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
        # Deep-clone so config injection mutates a fresh copy, not the
        # cached preflight $LocalByKey entry.
        $Patched = ConvertTo-Json -InputObject $LocalByKey[$Spec.Key] -Depth 100 | ConvertFrom-Json -Depth 100

        foreach ($Injection in @($InjectionsBySpecKey[$Spec.Key])) {
            if ($null -eq $Injection) { continue }
            Set-InjectedJsConstant -Workflow $Patched -NodeName $Injection.NodeName -MarkerName $Injection.MarkerName -VarName $Injection.VarName -Value $Injection.Value
        }

        $TokenMap = $RequiredTokenMapBySpecKey[$Spec.Key]
        if ($null -ne $TokenMap) {
            $Patched = Resolve-RequiredTokens -Workflow $Patched -TokenMap $TokenMap
        }

        Assert-NoRemainingPlaceholderTokens -Workflow $Patched -ExpectedName $Spec.Name

        $Patched = Patch-WorkflowIds -Workflow $Patched -Ids $Ids -ReviewCasesTableId $ReviewCasesTableId -IdempotencyTableId $IdempotencyTableId
        Assert-WorkflowBodySafe -Workflow $Patched -ExpectedName $Spec.Name
        $Patched = Resolve-CredentialPlaceholders -Workflow $Patched -InstantlyReady $InstantlyCredentialReady -ReviewBasicAuthReady $ReviewBasicAuthReady -CredentialIds $CredentialIds

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

        Assert-RemoteSafe -Workflow $Remote -ExpectedName $Spec.Name -InstantlyReady $InstantlyCredentialReady -ReviewBasicAuthReady $ReviewBasicAuthReady
        Assert-PatchedRemoteReferences `
            -Workflow $Remote `
            -Ids $Ids `
            -SpecKey $Spec.Key

        $Injections = @(@($InjectionsBySpecKey[$Spec.Key]) | Where-Object { $null -ne $_ })
        if ($Injections.Count -gt 0) {
            Assert-InjectedConstantsMatchConfig -Workflow $Remote -ExpectedName $Spec.Name -Checks $Injections
        }

        $Status[$Spec.Key] = "UPDATED_AND_VERIFIED"
    }

    Write-Host ""
    Write-Host "BUSINESS_READY_APPLY_COMPLETE"
    Write-Host ("Backup directory: {0}" -f $BackupDir)
    Write-Host "All 7 workflows remain Active=False. No workflow was activated. No Instantly endpoint was contacted."
    if ($InstantlyCredentialReady) {
        Write-Host "config.live_credential_readiness.instantly=true: credentialPlaceholder nodes (hmzInstantlyApi / hmzInstantlyWebhookToken) were bound as httpHeaderAuth to the supplied credential IDs. All live-send/suppression paths remain blocked by the 14-gate evaluation and DRY_RUN/LIVE_CAMPAIGNS until the owner separately completes the controlled-live acceptance steps."
    }
    else {
        Write-Host "config.live_credential_readiness.instantly=false: no credential was created, read, or bound. credentialPlaceholder nodes were left unresolved and remain structurally unreachable."
    }
    if ($ReviewBasicAuthReady) {
        Write-Host "config.live_credential_readiness.review_basic_auth=true: credentialPlaceholder nodes (hmzReviewBasicAuth) were bound as httpBasicAuth to the supplied credential ID."
    }
    else {
        Write-Host "config.live_credential_readiness.review_basic_auth=false: no credential was created, read, or bound. hmzReviewBasicAuth credentialPlaceholder nodes were left unresolved."
    }

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
    Write-Host "BUSINESS_READY_APPLY_FAILED"
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
    $CredentialIds = $null
    $env:HMZ_N8N_API_KEY = $null
    Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\HMZ_INSTANTLY_API_CREDENTIAL_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID -ErrorAction SilentlyContinue
}

