#Requires -Version 7.0
[CmdletBinding(DefaultParameterSetName = 'PreflightOnly')]
param(
    [Parameter(ParameterSetName = 'PreflightOnly')]
    [switch]$PreflightOnly,

    [Parameter(ParameterSetName = 'AllowOneControlledReply', Mandatory)]
    [Alias("RunControlledLiveReply")]
    [switch]$AllowOneControlledReply,

    [Parameter(ParameterSetName = 'AllowOneControlledReply', Mandatory)]
    [string]$ConfirmationPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Controlled-live acceptance for the business-ready SUPERVISED_VALIDATION
# profile. Two modes:
#
#   -PreflightOnly (default; also the result of passing no parameters)
#     Read-only (GET) checks only. Never sends a reply, never updates lead
#     state, never modifies the blocklist, never changes config.dry_run or
#     config.operating_mode, never populates config.live_campaigns, never
#     applies/activates a workflow, and never POSTs to Instantly. Confirms
#     the stored config is in its safe baseline (operating_mode=VALIDATION,
#     dry_run=true, ready_for_controlled_live_test=true), that the n8n side
#     has all 7 business-ready workflows applied and inactive, and that the
#     Instantly side (API key valid, the owner-designated controlled-live
#     campaign exists, its workspace is non-empty, allowlisted, AND matches
#     config.allowlists.workspace_id exactly) is consistent BEFORE any live
#     action.
#
#   -AllowOneControlledReply -ConfirmationPhrase 'RUN-ONE-CONTROLLED-REPLY'
#     Performs ONE interactive, supervised, PRODUCTION-PATH controlled-live
#     acceptance run:
#       1. Re-runs the preflight above and verifies the public HTTPS n8n,
#          review, and production-Instantly-webhook URLs are reachable.
#       2. Backs up config/business-ready.config.json and the current remote
#          body of all 7 business-ready workflows.
#       3. Builds an in-memory TEMPORARY config that sets
#          operating_mode=SUPERVISED_VALIDATION, dry_run=false,
#          live_campaigns=[the one owner-designated campaign],
#          allowlists.campaign_ids=[same], and the three
#          live_credential_readiness flags required for the 14-gate
#          evaluation and credential binding, leaving every owner-supplied
#          allowlist/reviewer/sender value untouched, and writes it to
#          config/business-ready.config.json.
#       4. Runs apply-business-ready.ps1 (as a child process, so its own
#          env-var cleanup never strips this script's environment) to
#          re-embed the temporary LAUNCH_PROFILE/ALLOWLISTS/etc constants and
#          bind the hmzInstantlyApi / hmzInstantlyWebhookToken
#          (httpHeaderAuth) and hmzReviewBasicAuth (httpBasicAuth)
#          credentials from the supplied credential IDs.
#       5. Temporarily activates the 6 runtime workflows (Intake, Decision
#          Engine, Reply Sender, Error Handler, Human Approval, SLA
#          Watchdog). The Full Test Harness is NEVER activated by this
#          script and its inactive state is verified before and after.
#       6. Prints a unique marker and the exact owned test lead/campaign,
#          and instructs the operator to trigger a real reply from that lead
#          into the designated campaign, open the production Human Approval
#          review page, edit the draft to include the marker, and approve it
#          exactly once.
#       7. Waits for operator confirmation, then polls (a) the n8n
#          executions API for the Reply Sender workflow's terminal result
#          and (b) Instantly's GET /api/v2/emails for the resulting outbound
#          Email object. This script NEVER POSTs to the Instantly reply-send
#          endpoint directly - the only send path is the real, approved,
#          production n8n workflow chain. Unlike the prior implementation,
#          this script does NOT post a synthetic NES to the Intake
#          workflow's DEV-ONLY webhook (hmz-validation-reply-intake-dev); the
#          inbound reply is a real message the operator sends from the owned
#          test lead into the designated campaign. If the Sender reports
#          SEND_UNCERTAIN, this script performs reconciliation polling ONLY
#          and never a second send of any kind.
#       8. In `finally`, regardless of outcome: deactivates the 6 runtime
#          workflows, restores config/business-ready.config.json from the
#          step-2 backup (or, if the backup is unavailable, re-asserts the
#          safe defaults directly), reruns apply-business-ready.ps1 against
#          the restored safe config to re-embed the safe constants, verifies
#          config.dry_run=true / config.operating_mode=VALIDATION /
#          config.live_campaigns=[] and all 7 workflows inactive, and clears
#          every secret/controlled-live environment variable used by this
#          run.
#     Requires the confirmation phrase to be typed exactly, as a guard
#     against accidental invocation. Exactly one controlled-live attempt is
#     made per run: there is no retry loop.
#
# Neither mode implements PROVEN mode or any unattended auto-send. Both
# remain out of scope for this repository. This script must not be run
# during an offline build session.

$RequiredConfirmationPhrase = "RUN-ONE-CONTROLLED-REPLY"

if ($AllowOneControlledReply -and $ConfirmationPhrase -ne $RequiredConfirmationPhrase) {
    throw "-AllowOneControlledReply (alias: -RunControlledLiveReply) requires -ConfirmationPhrase '$RequiredConfirmationPhrase' typed exactly."
}

$Mode = if ($AllowOneControlledReply) { "RUN_CONTROLLED_LIVE_REPLY" } else { "PREFLIGHT_ONLY" }

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$InstantlyBaseUrl = "https://api.instantly.ai"
$ConfigPath = Join-Path $Project "config\business-ready.config.json"
$ApplyScriptPath = Join-Path $Project "verification\business-ready\apply-business-ready.ps1"
$ResultsPath = Join-Path $Project "verification\business-ready\controlled-live-acceptance-results.json"
$ReportPath = Join-Path $Project "reports\BUSINESS_READY_CONTROLLED_LIVE_ACCEPTANCE.md"
$BackupRoot = Join-Path $Project "verification\business-ready\controlled-live-backup"

# All 7 business-ready workflows, by exact n8n name.
$CanonicalNames = @(
    "HMZ - Instantly Reply Intake - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Instantly Reply Sender - Validation",
    "HMZ - Reply Human Approval - Validation",
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Reply Full Test Harness - Validation"
)

# The 6 workflows that must be ACTIVE during a controlled-live run. The Full
# Test Harness is deliberately excluded and must remain inactive throughout.
# Dependency-aware publication order proven against production n8n 2.25.7.
# Sender must be published before Human Approval. Decision Engine and Human
# Approval must both be published before Intake. Rollback uses the reverse
# dependency order so no published parent points to an unpublished child.
$RuntimeWorkflowActivationOrder = @(
    "HMZ - Instantly Reply Sender - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Reply Human Approval - Validation",
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Instantly Reply Intake - Validation"
)

$RuntimeWorkflowDeactivationOrder = @(
    "HMZ - Instantly Reply Intake - Validation",
    "HMZ - Reply SLA Watchdog - Validation",
    "HMZ - Reply Error Handler - Validation",
    "HMZ - Reply Human Approval - Validation",
    "HMZ - Reply Decision Engine - Validation",
    "HMZ - Instantly Reply Sender - Validation"
)
$FullTestHarnessName = "HMZ - Reply Full Test Harness - Validation"
$SenderName = "HMZ - Instantly Reply Sender - Validation"

# Reply Sender terminal nodes; whichever one fires carries the run's
# json.terminal result.
$TerminalNodeNames = @(
    "X2. Build SENT Terminal Result",
    "W4. Build Reconciliation Terminal Result",
    "U3. Finalize Failure Terminal Result",
    "K2. Build DRY_RUN Terminal Result",
    "P2. Live Send Blocked Terminal",
    "I2. Suppression Escalation Terminal",
    "F2. Blocked Duplicate or Rerun Terminal",
    "C2. Gate Rejection Terminal"
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

function Get-AllWorkflowSummaries {
    param([Parameter(Mandatory)][hashtable]$Headers)

    $Items = @()
    $Cursor = $null

    do {
        $Path = "/workflows?limit=250"
        if (-not [string]::IsNullOrWhiteSpace($Cursor)) {
            $Path += "&cursor=$([Uri]::EscapeDataString($Cursor))"
        }

        $Response = Invoke-RestMethod -Method GET -Uri "$N8nUrl/api/v1$Path" -Headers $Headers
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

function Get-WorkflowIdByName {
    param(
        [Parameter(Mandatory)][array]$Summaries,
        [Parameter(Mandatory)][string]$Name
    )

    $Matches = @($Summaries | Where-Object { [string]$_.name -eq $Name })
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one n8n workflow named '$Name', found $($Matches.Count)."
    }
    return [string]$Matches[0].id
}

function Test-PublicHttpsUrl {
    param([Parameter(Mandatory)][string]$Url)

    # Read-only reachability probe. Returns $true only for an https:// URL
    # that responds with any status below 500 (i.e. the endpoint exists and
    # is not erroring server-side); never throws.
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    try {
        $Uri = [Uri]$Url
        if ($Uri.Scheme -ne "https") { return $false }

        $Response = Invoke-WebRequest -Method GET -Uri $Url -SkipHttpErrorCheck -TimeoutSec 15
        return ([int]$Response.StatusCode -lt 500)
    }
    catch {
        return $false
    }
}

function Invoke-Preflight {
    $Results = [ordered]@{
        schemaVersion = "1.1"
        generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
        mode = $Mode
        configOperatingModeValidation = $false
        configDryRunTrue = $false
        configLiveCampaignsDeclared = @()
        configReadyFlagSet = $false
        n8nWorkflowsApplied = $false
        n8nWorkflowsInactive = $false
        instantlyApiReachable = $false
        designatedCampaignFound = $false
        designatedCampaignWorkspaceId = $null
        designatedCampaignWorkspaceNonEmpty = $false
        designatedCampaignInWorkspaceAllowlist = $false
        designatedCampaignWorkspaceMatchesConfigured = $false
        overallResult = "NOT_RUN"
    }

    try {
        if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
            throw "Missing config: $ConfigPath"
        }
        $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100

        $Results.configOperatingModeValidation = ([string]$Config.operating_mode -eq "VALIDATION")
        $Results.configDryRunTrue = ([bool]$Config.dry_run -eq $true)
        $Results.configLiveCampaignsDeclared = @($Config.live_campaigns)

        $ReadyFlag = Get-OptionalPropertyValue -Object $Config.live_credential_readiness -Name "ready_for_controlled_live_test"
        $Results.configReadyFlagSet = ([bool]$ReadyFlag -eq $true)

        if (-not $Results.configOperatingModeValidation) {
            throw "config.operating_mode must be 'VALIDATION' in the stored (safe) config. This script only enters SUPERVISED_VALIDATION temporarily, in-memory, during -AllowOneControlledReply."
        }

        if (-not $Results.configDryRunTrue) {
            throw "config.dry_run must be true in the stored (safe) config. This script does not permanently flip DRY_RUN; refusing to proceed against a non-DRY_RUN stored config."
        }

        if (-not $Results.configReadyFlagSet) {
            throw "config.live_credential_readiness.ready_for_controlled_live_test is not true. Set this only after the owner has reviewed BUSINESS_READY_OWNER_INPUTS.md and bound credentials out of band."
        }

        if ([string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
            throw "HMZ_N8N_API_KEY is not set in this PowerShell process."
        }
        if ([string]::IsNullOrWhiteSpace($env:HMZ_INSTANTLY_API_KEY)) {
            throw "HMZ_INSTANTLY_API_KEY is not set in this PowerShell process."
        }
        if ([string]::IsNullOrWhiteSpace($env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID)) {
            throw "HMZ_CONTROLLED_LIVE_CAMPAIGN_ID is not set. The owner must designate exactly one test campaign ID for controlled-live acceptance."
        }

        $N8nHeaders = @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY }
        $Summaries = Get-AllWorkflowSummaries -Headers $N8nHeaders

        $Found = @()
        $Inactive = @()
        foreach ($Name in $CanonicalNames) {
            $Matches = @($Summaries | Where-Object { [string]$_.name -eq $Name })
            if ($Matches.Count -eq 1) {
                $Found += $Name
                if (-not [bool]$Matches[0].active) { $Inactive += $Name }
            }
        }

        $Results.n8nWorkflowsApplied = ($Found.Count -eq $CanonicalNames.Count)
        $Results.n8nWorkflowsInactive = ($Inactive.Count -eq $CanonicalNames.Count)

        if (-not $Results.n8nWorkflowsApplied) {
            throw "Not all 7 business-ready workflows were found on the local n8n instance. Run apply-business-ready.ps1 first."
        }
        if (-not $Results.n8nWorkflowsInactive) {
            throw "One or more business-ready workflows are active. Controlled-live acceptance requires all 7 to be inactive before a run starts."
        }

        $InstantlyHeaders = @{ "Authorization" = "Bearer $($env:HMZ_INSTANTLY_API_KEY)" }
        $CampaignsResponse = Invoke-RestMethod -Method GET -Uri "$InstantlyBaseUrl/api/v2/campaigns?limit=100" -Headers $InstantlyHeaders
        $Results.instantlyApiReachable = $true

        $Campaigns = @(Get-OptionalPropertyValue -Object $CampaignsResponse -Name "items")
        if ($Campaigns.Count -eq 0) { $Campaigns = @($CampaignsResponse) }

        $DesignatedId = $env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID
        $Match = $Campaigns | Where-Object { [string](Get-OptionalPropertyValue -Object $_ -Name "id") -eq $DesignatedId }
        $Results.designatedCampaignFound = (@($Match).Count -ge 1)

        if (-not $Results.designatedCampaignFound) {
            throw "Designated campaign ID '$DesignatedId' was not found via GET /api/v2/campaigns for this workspace."
        }

        # Fail-closed workspace check (corrects the previous fail-open
        # `IsNullOrWhiteSpace -or ...` condition): a blank/missing campaign
        # workspace_id must BLOCK, never pass implicitly. The designated
        # campaign's workspace must be non-empty, present in
        # config.workspace_allowlist, AND equal to config.allowlists.workspace_id.
        $WorkspaceAllowlist = @($Config.workspace_allowlist)
        $ConfiguredWorkspaceId = [string](Get-OptionalPropertyValue -Object $Config.allowlists -Name "workspace_id")
                # Instantly campaign objects currently expose the workspace UUID as
        # `organization`. Retain compatibility with any response that still
        # supplies `workspace_id`, but fail closed if both are absent.
        $CampaignObject = @($Match)[0]
        $MatchWorkspace = [string](Get-OptionalPropertyValue -Object $CampaignObject -Name "workspace_id")
        if ([string]::IsNullOrWhiteSpace($MatchWorkspace)) {
            $MatchWorkspace = [string](Get-OptionalPropertyValue -Object $CampaignObject -Name "organization")
        }

        $Results.designatedCampaignWorkspaceId = $MatchWorkspace
        $Results.designatedCampaignWorkspaceNonEmpty = (-not [string]::IsNullOrWhiteSpace($MatchWorkspace))
        $Results.designatedCampaignInWorkspaceAllowlist = (
            $Results.designatedCampaignWorkspaceNonEmpty -and
            ($WorkspaceAllowlist -contains $MatchWorkspace)
        )
        $Results.designatedCampaignWorkspaceMatchesConfigured = (
            $Results.designatedCampaignWorkspaceNonEmpty -and
            (-not [string]::IsNullOrWhiteSpace($ConfiguredWorkspaceId)) -and
            ($MatchWorkspace -eq $ConfiguredWorkspaceId)
        )

        if (-not $Results.designatedCampaignWorkspaceNonEmpty) {
            throw "Designated campaign has a blank/missing workspace_id. Fail-closed: this blocks controlled-live acceptance."
        }
        if (-not $Results.designatedCampaignInWorkspaceAllowlist) {
            throw "Designated campaign's workspace_id is not present in config.workspace_allowlist."
        }
        if (-not $Results.designatedCampaignWorkspaceMatchesConfigured) {
            throw "Designated campaign's workspace_id does not exactly match config.allowlists.workspace_id."
        }

        $Results.overallResult = "READY"
    }
    catch {
        $Results.overallResult = "BLOCKED"
        $Results.error = $_.Exception.Message
    }

    return $Results
}

function Test-PublicEndpointsReady {
    param([Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Results)

    # Step 1 of the -AllowOneControlledReply procedure: confirm the public
    # HTTPS surfaces this run depends on are reachable BEFORE any config or
    # workflow state is touched. Read-only (GET, -SkipHttpErrorCheck).
    foreach ($VarName in @(
        "HMZ_N8N_PUBLIC_URL",
        "HMZ_REVIEW_PUBLIC_BASE_URL",
        "HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL"
    )) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($VarName))) {
            throw "$VarName is not set. The owner must designate the public HTTPS n8n editor URL, the public review-form base URL, and the production Instantly reply-intake webhook URL before a controlled-live run."
        }
    }

    $Results.n8nPublicUrlReachable = Test-PublicHttpsUrl -Url $env:HMZ_N8N_PUBLIC_URL
    $Results.reviewPublicUrlReachable = Test-PublicHttpsUrl -Url $env:HMZ_REVIEW_PUBLIC_BASE_URL
    $Results.productionInstantlyWebhookConfigured = Test-PublicHttpsUrl -Url $env:HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL

    if (-not $Results.n8nPublicUrlReachable) {
        throw "HMZ_N8N_PUBLIC_URL ('$($env:HMZ_N8N_PUBLIC_URL)') is not a reachable https:// URL."
    }
    if (-not $Results.reviewPublicUrlReachable) {
        throw "HMZ_REVIEW_PUBLIC_BASE_URL ('$($env:HMZ_REVIEW_PUBLIC_BASE_URL)') is not a reachable https:// URL."
    }
    if (-not $Results.productionInstantlyWebhookConfigured) {
        throw "HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL ('$($env:HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL)') is not a reachable https:// URL."
    }
}

function Assert-ControlledLiveEnvComplete {
    # Additional env vars required only for -AllowOneControlledReply, beyond
    # those already validated by Invoke-Preflight / Test-PublicEndpointsReady.
    foreach ($VarName in @(
        "HMZ_REVIEW_CASES_DATA_TABLE_ID",
        "HMZ_IDEMPOTENCY_DATA_TABLE_ID",
        "HMZ_INSTANTLY_API_CREDENTIAL_ID",
        "HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID",
        "HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID",
        "HMZ_CONTROLLED_LIVE_EACCOUNT",
        "HMZ_CONTROLLED_LIVE_LEAD_EMAIL",
        "HMZ_CONTROLLED_LIVE_REPLY_SUBJECT"
    )) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($VarName))) {
            throw "$VarName is not set. The owner must designate this value before -AllowOneControlledReply can proceed."
        }
    }
}

function Backup-ControlledLiveState {
    param([Parameter(Mandatory)][hashtable]$N8nHeaders)

    # Backs up config/business-ready.config.json and the current remote body
    # of all 7 business-ready workflows to a timestamped directory, for
    # audit and manual-recovery purposes. The tested restoration mechanism is
    # re-running apply-business-ready.ps1 against the restored safe config
    # (see Restore-SafeState); these backups are a belt-and-suspenders
    # snapshot only.
    $Stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    $BackupDir = Join-Path $BackupRoot $Stamp
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $BackupDir "business-ready.config.json") -Force

    $Summaries = Get-AllWorkflowSummaries -Headers $N8nHeaders
    foreach ($Name in $CanonicalNames) {
        $Id = Get-WorkflowIdByName -Summaries $Summaries -Name $Name
        $Body = Invoke-RestMethod -Method GET -Uri "$N8nUrl/api/v1/workflows/$Id" -Headers $N8nHeaders
        $SafeFileName = ($Name -replace '[^A-Za-z0-9\-]', '_') + ".json"
        $Body | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $BackupDir $SafeFileName) -Encoding utf8
    }

    return $BackupDir
}

function New-ControlledLiveConfig {
    param([Parameter(Mandatory)]$Config)

    # Deep clone, then override ONLY the fields needed to pass the 14-gate
    # live-send evaluation and the production security gate for exactly one
    # designated campaign/workspace/sender. Every owner-supplied allowlist,
    # reviewer-allowlist, sender-mapping, and policy value is left untouched.
    $Temp = $Config | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100

    $Temp.operating_mode = "SUPERVISED_VALIDATION"
    $Temp.dry_run = $false
    $Temp.live_campaigns = @($env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID)

    $Temp.launch_profile.required_operating_mode = "SUPERVISED_VALIDATION"

    $Temp.allowlists.campaign_ids = @($env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID)

    $Temp.live_credential_readiness.instantly = $true
    $Temp.live_credential_readiness.review_basic_auth = $true
    $Temp.live_credential_readiness.ready_for_controlled_live_test = $true

    return $Temp
}

function Invoke-ApplyBusinessReady {
    param([Parameter(Mandatory)][hashtable]$AdditionalEnv)

    # Runs apply-business-ready.ps1 as a CHILD PROCESS so that its own
    # `finally` block (which clears HMZ_N8N_API_KEY / HMZ_*_CREDENTIAL_ID /
    # HMZ_REVIEW_CASES_DATA_TABLE_ID from its own process environment) never
    # strips the environment variables this orchestration script still needs
    # for n8n activation/polling and for the eventual restore re-run.
    foreach ($Key in $AdditionalEnv.Keys) {
        Set-Item -Path "Env:$Key" -Value $AdditionalEnv[$Key]
    }

    $Proc = Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile", "-File", $ApplyScriptPath) -NoNewWindow -Wait -PassThru
    if ($Proc.ExitCode -ne 0) {
        throw "apply-business-ready.ps1 exited with non-zero code $($Proc.ExitCode)."
    }
}

function Set-RuntimeWorkflowsActive {
    param(
        [Parameter(Mandatory)][hashtable]$Headers,
        [Parameter(Mandatory)][bool]$Active
    )

    $Summaries = Get-AllWorkflowSummaries -Headers $Headers
    $Order = if ($Active) {
        @($RuntimeWorkflowActivationOrder)
    }
    else {
        @($RuntimeWorkflowDeactivationOrder)
    }

    $ActivatedDuringThisCall = [System.Collections.Generic.List[string]]::new()
    $Failures = [System.Collections.Generic.List[string]]::new()

    try {
        foreach ($Name in $Order) {
            $Id = Get-WorkflowIdByName -Summaries $Summaries -Name $Name
            $Action = if ($Active) { "activate" } else { "deactivate" }

            try {
                if ($Active) {
                    Invoke-RestMethod `
                        -Method POST `
                        -Uri "$N8nUrl/api/v1/workflows/$Id/$Action" `
                        -Headers $Headers `
                        -ContentType "application/json" `
                        -Body "{}" |
                        Out-Null
                }
                else {
                    Invoke-RestMethod `
                        -Method POST `
                        -Uri "$N8nUrl/api/v1/workflows/$Id/$Action" `
                        -Headers $Headers |
                        Out-Null
                }

                $Updated = Invoke-RestMethod `
                    -Method GET `
                    -Uri "$N8nUrl/api/v1/workflows/$Id" `
                    -Headers $Headers

                if ([bool]$Updated.active -ne $Active) {
                    throw "Workflow did not reach active=$Active."
                }

                if ($Active) {
                    $ActivatedDuringThisCall.Add($Name)
                }
            }
            catch {
                $Failures.Add("${Name}: $($_.Exception.Message)")
                if ($Active) {
                    throw
                }
            }
        }
    }
    catch {
        # Transactional rollback for a partial activation. Deactivate only the
        # workflows that this call already published, in reverse dependency order.
        if ($Active -and $ActivatedDuringThisCall.Count -gt 0) {
            foreach ($RollbackName in $RuntimeWorkflowDeactivationOrder) {
                if ($ActivatedDuringThisCall -notcontains $RollbackName) {
                    continue
                }

                try {
                    $RollbackId = Get-WorkflowIdByName -Summaries $Summaries -Name $RollbackName
                    Invoke-RestMethod `
                        -Method POST `
                        -Uri "$N8nUrl/api/v1/workflows/$RollbackId/deactivate" `
                        -Headers $Headers |
                        Out-Null
                }
                catch {
                    $Failures.Add("Rollback ${RollbackName}: $($_.Exception.Message)")
                }
            }
        }

        throw ("Dependency-aware runtime activation failed. " + ($Failures -join " | "))
    }

    if (-not $Active -and $Failures.Count -gt 0) {
        throw ("One or more runtime workflows failed to deactivate. " + ($Failures -join " | "))
    }

    # The Full Test Harness must never be activated by this script.
    $HarnessId = Get-WorkflowIdByName -Summaries $Summaries -Name $FullTestHarnessName
    $Harness = Invoke-RestMethod `
        -Method GET `
        -Uri "$N8nUrl/api/v1/workflows/$HarnessId" `
        -Headers $Headers

    if ([bool]$Harness.active) {
        Invoke-RestMethod `
            -Method POST `
            -Uri "$N8nUrl/api/v1/workflows/$HarnessId/deactivate" `
            -Headers $Headers |
            Out-Null
    }
}
function Wait-ForControlledReplyOutcome {
    param(
        [Parameter(Mandatory)][hashtable]$N8nHeaders,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Results,
        [Parameter(Mandatory)][DateTimeOffset]$WindowStartUtc
    )

    $N8nSummaries = Get-AllWorkflowSummaries -Headers $N8nHeaders
    $SenderId = Get-WorkflowIdByName -Summaries $N8nSummaries -Name $SenderName

    $RequestStartUtc = $WindowStartUtc
    $Terminal = $null
    $Deadline = (Get-Date).AddMinutes(30)

    Write-Host ""
    Write-Host "Waiting for the approved reply to be sent via the real production workflow chain..."
    Write-Host "(polling n8n executions for '$SenderName', up to 30 minutes)"

    while ((Get-Date) -lt $Deadline -and $null -eq $Terminal) {
        Start-Sleep -Seconds 10

        $ExecList = Invoke-RestMethod -Method GET -Uri "$N8nUrl/api/v1/executions?workflowId=$SenderId&limit=10" -Headers $N8nHeaders
        $Candidates = @(Get-OptionalPropertyValue -Object $ExecList -Name "data")

        foreach ($Exec in $Candidates) {
            $StartedAt = [string](Get-OptionalPropertyValue -Object $Exec -Name "startedAt")
            if ([string]::IsNullOrWhiteSpace($StartedAt)) { continue }
            if ([DateTimeOffset]::Parse($StartedAt) -lt $RequestStartUtc) { continue }

            $ExecId = [string](Get-OptionalPropertyValue -Object $Exec -Name "id")
            $Detail = Invoke-RestMethod -Method GET -Uri "$N8nUrl/api/v1/executions/$ExecId`?includeData=true" -Headers $N8nHeaders
            $ExecData = Get-OptionalPropertyValue -Object $Detail -Name "data"
            $ResultData = Get-OptionalPropertyValue -Object $ExecData -Name "resultData"
            $RunData = Get-OptionalPropertyValue -Object $ResultData -Name "runData"
            if ($null -eq $RunData) { continue }

            foreach ($NodeName in $TerminalNodeNames) {
                $NodeRuns = Get-OptionalPropertyValue -Object $RunData -Name $NodeName
                if ($null -eq $NodeRuns) { continue }

                $LastRun = @($NodeRuns)[-1]
                $OutputJson = $LastRun.data.main[0][0].json
                if ($null -eq $OutputJson) { continue }

                $Terminal = Get-OptionalPropertyValue -Object $OutputJson -Name "terminal"
                if ($null -ne $Terminal) { break }
            }

            if ($null -ne $Terminal) { break }
        }
    }

    if ($null -eq $Terminal) {
        $Results.liveSendResult = "FAILED"
        $Results.error = "No terminal n8n execution result was observed for '$SenderName' within the 30-minute polling window."
        return
    }

    $SendState = [string](Get-OptionalPropertyValue -Object $Terminal -Name "send_state")
    $Results.liveSendResult = if ([string]::IsNullOrWhiteSpace($SendState)) { "FAILED" } else { $SendState }
    $Results.liveSendEmailId = Get-OptionalPropertyValue -Object $Terminal -Name "email_id"
    $Results.liveSendMessageId = Get-OptionalPropertyValue -Object $Terminal -Name "message_id"
    $Results.liveSendThreadId = Get-OptionalPropertyValue -Object $Terminal -Name "thread_id"

    if ($Results.liveSendResult -eq "SEND_UNCERTAIN") {
        $Results.reconciliationOnly = $true
        $Results.reconciliationNote = "send_state=SEND_UNCERTAIN: this script performs reconciliation reads only (GET /api/v2/emails) and will NOT attempt a second send of any kind."
    }

    if ($Results.liveSendResult -ne "SENT" -and $Results.liveSendResult -ne "SEND_UNCERTAIN") {
        # BLOCKED / DRY_RUN_OK / FAILED / gate-rejection outcomes: nothing was
        # sent, so there is nothing to verify against Instantly.
        return
    }

    # Independent confirmation against Instantly. Read-only
    # GET /api/v2/emails - this script never POSTs to the Instantly reply-send endpoint.
    $InstantlyHeaders = @{ "Authorization" = "Bearer $($env:HMZ_INSTANTLY_API_KEY)" }
    $QueryBase = "$InstantlyBaseUrl/api/v2/emails" +
        "?eaccount=$([Uri]::EscapeDataString($env:HMZ_CONTROLLED_LIVE_EACCOUNT))" +
        "&lead=$([Uri]::EscapeDataString($env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL))" +
        "&email_type=sent&preview_only=false&limit=10" +
        "&min_timestamp_created=$([Uri]::EscapeDataString($RequestStartUtc.ToString("o")))"

    function Get-MatchingOutboundEmails {
        $Response = Invoke-RestMethod -Method GET -Uri $QueryBase -Headers $InstantlyHeaders
        $Items = @(Get-OptionalPropertyValue -Object $Response -Name "items")
        if ($Items.Count -eq 0) { $Items = @(Get-OptionalPropertyValue -Object $Response -Name "data") }

        return @($Items | Where-Object {
            $Subject = [string](Get-OptionalPropertyValue -Object $_ -Name "subject")
            $ThreadId = [string](Get-OptionalPropertyValue -Object $_ -Name "thread_id")
            $Eaccount = [string](Get-OptionalPropertyValue -Object $_ -Name "eaccount")
            $Lead = [string](Get-OptionalPropertyValue -Object $_ -Name "lead")
            $ToList = @(Get-OptionalPropertyValue -Object $_ -Name "to_address_email_list")
            $Body = Get-OptionalPropertyValue -Object $_ -Name "body"
            $Html = [string](Get-OptionalPropertyValue -Object $Body -Name "html")
            $Text = [string](Get-OptionalPropertyValue -Object $Body -Name "text")

            $RecipientMatches = (
                $Lead -eq $env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL -or
                @($ToList | Where-Object { [string]$_ -eq $env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL }).Count -gt 0
            )

            ($Eaccount -eq $env:HMZ_CONTROLLED_LIVE_EACCOUNT) -and
            $RecipientMatches -and
            ($Subject -eq $env:HMZ_CONTROLLED_LIVE_REPLY_SUBJECT) -and
            (-not [string]::IsNullOrWhiteSpace($Results.liveSendThreadId)) -and
            ($ThreadId -eq $Results.liveSendThreadId) -and
            (($Html -like "*$($Results.controlledLiveMarker)*") -or ($Text -like "*$($Results.controlledLiveMarker)*"))
        })
    }

    $FirstPoll = @(Get-MatchingOutboundEmails)
    $Results.matchingOutboundEmailCountFirstPoll = $FirstPoll.Count

    Start-Sleep -Seconds 60
    $SecondPoll = @(Get-MatchingOutboundEmails)
    $Results.matchingOutboundEmailCountSecondPoll = $SecondPoll.Count

    $Results.exactlyOneOutboundEmailConfirmed = ($FirstPoll.Count -eq 1)

    $FirstId = if ($FirstPoll.Count -eq 1) {
        [string](Get-OptionalPropertyValue -Object $FirstPoll[0] -Name "id")
    } else { "" }

    $SecondId = if ($SecondPoll.Count -eq 1) {
        [string](Get-OptionalPropertyValue -Object $SecondPoll[0] -Name "id")
    } else { "" }

    $Results.noDuplicateAfterObservationWindow = (
        $FirstPoll.Count -eq 1 -and
        $SecondPoll.Count -eq 1 -and
        -not [string]::IsNullOrWhiteSpace($FirstId) -and
        $FirstId -eq $SecondId
    )

    if ($Results.exactlyOneOutboundEmailConfirmed) {
        $Confirmed = $FirstPoll[0]
        $ConfirmedId = [string](Get-OptionalPropertyValue -Object $Confirmed -Name "id")
        $ConfirmedMessageId = [string](Get-OptionalPropertyValue -Object $Confirmed -Name "message_id")
        $ConfirmedEaccount = [string](Get-OptionalPropertyValue -Object $Confirmed -Name "eaccount")
        $ConfirmedLead = [string](Get-OptionalPropertyValue -Object $Confirmed -Name "lead")
        $ConfirmedRecipients = @(Get-OptionalPropertyValue -Object $Confirmed -Name "to_address_email_list")
        $CcList = @(Get-OptionalPropertyValue -Object $Confirmed -Name "cc_address_email_list")
        $BccList = @(Get-OptionalPropertyValue -Object $Confirmed -Name "bcc_address_email_list")

        $Results.outboundEmailCcBccEmpty = (
            @($CcList | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0 -and
            @($BccList | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0
        )
        $Results.outboundEmailSenderEaccount = $ConfirmedEaccount
        $Results.outboundEmailRecipients = $ConfirmedRecipients
        $Results.outboundEmailSenderMatches = ($ConfirmedEaccount -eq $env:HMZ_CONTROLLED_LIVE_EACCOUNT)
        $Results.outboundEmailRecipientMatches = (
            $ConfirmedLead -eq $env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL -or
            @($ConfirmedRecipients | Where-Object { [string]$_ -eq $env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL }).Count -gt 0
        )
        $Results.confirmedEmailIdMatchesTerminal = (
            -not [string]::IsNullOrWhiteSpace([string]$Results.liveSendEmailId) -and
            $ConfirmedId -eq [string]$Results.liveSendEmailId
        )
        $Results.confirmedMessageIdMatchesTerminal = (
            -not [string]::IsNullOrWhiteSpace([string]$Results.liveSendMessageId) -and
            $ConfirmedMessageId -eq [string]$Results.liveSendMessageId
        )
    }
}

function Restore-SafeState {
    param(
        [Parameter(Mandatory)][string]$BackupDir,
        [Parameter(Mandatory)][bool]$RuntimeWorkflowsWereActivated
    )

    $Warnings = @()

    # Preflight already confirmed all 7 business-ready workflows were inactive before this run.
    # Deactivating the 6 temporarily-activated runtime workflows here will restore the Intake workflow to its prior active state (inactive), along with the other 5 runtime workflows.
    if (-not [string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
        try {
            $N8nHeaders = @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY }

            if ($RuntimeWorkflowsWereActivated) {
                Set-RuntimeWorkflowsActive -Headers $N8nHeaders -Active $false
            }
        }
        catch {
            $Warnings += "Failed to deactivate runtime workflows: $($_.Exception.Message)"
        }
    }
    else {
        $Warnings += "HMZ_N8N_API_KEY not set during restore; could not deactivate runtime workflows via the n8n API."
    }

    # Restore config/business-ready.config.json from the pre-run backup. If
    # the backup is unavailable for any reason, re-assert the safe defaults
    # directly rather than leaving a live-mode config on disk.
    try {
        if (-not [string]::IsNullOrWhiteSpace($BackupDir) -and (Test-Path -LiteralPath (Join-Path $BackupDir "business-ready.config.json") -PathType Leaf)) {
            Copy-Item -LiteralPath (Join-Path $BackupDir "business-ready.config.json") -Destination $ConfigPath -Force
        }
        else {
            $RestoreConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100
            $RestoreConfig.operating_mode = "VALIDATION"
            $RestoreConfig.dry_run = $true
            $RestoreConfig | Add-Member -NotePropertyName "live_campaigns" -NotePropertyValue @() -Force
            $RestoreConfig.allowlists.campaign_ids = @()
            $RestoreConfig.live_credential_readiness.instantly = $false
            $RestoreConfig.live_credential_readiness.review_basic_auth = $false
            $RestoreConfig.live_credential_readiness.ready_for_controlled_live_test = $false
            $RestoreConfig | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
            $Warnings += "Config backup unavailable; re-asserted safe defaults directly instead of restoring from backup."
        }
    }
    catch {
        $Warnings += "Failed to restore config/business-ready.config.json: $($_.Exception.Message)"
    }

    # Re-run apply-business-ready.ps1 against the restored safe config to
    # re-embed the safe LAUNCH_PROFILE/ALLOWLISTS/etc constants into the 7
    # remote workflows. With instantly=false and review_basic_auth=false, no
    # credential IDs are required for this rerun.
    try {
        if (-not [string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY) -and -not [string]::IsNullOrWhiteSpace($env:HMZ_REVIEW_CASES_DATA_TABLE_ID) -and -not [string]::IsNullOrWhiteSpace($env:HMZ_IDEMPOTENCY_DATA_TABLE_ID)) {
            Invoke-ApplyBusinessReady -AdditionalEnv @{}
        }
        else {
            $Warnings += "Could not rerun apply-business-ready.ps1 during restore: HMZ_N8N_API_KEY, HMZ_REVIEW_CASES_DATA_TABLE_ID, and/or HMZ_IDEMPOTENCY_DATA_TABLE_ID not set."
        }
    }
    catch {
        $Warnings += "Failed to rerun apply-business-ready.ps1 during restore: $($_.Exception.Message)"
    }

    # Final verification.
    $FinalConfigSafe = $false
    $FinalAllInactive = $false
    try {
        $FinalConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100
        $FinalConfigSafe = (
            ([string]$FinalConfig.operating_mode -eq "VALIDATION") -and
            ([bool]$FinalConfig.dry_run -eq $true) -and
            (@($FinalConfig.live_campaigns).Count -eq 0)
        )
    }
    catch {
        $Warnings += "Failed to verify restored config: $($_.Exception.Message)"
    }

    try {
        if (-not [string]::IsNullOrWhiteSpace($env:HMZ_N8N_API_KEY)) {
            $N8nHeaders = @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY }
            $Summaries = Get-AllWorkflowSummaries -Headers $N8nHeaders
            $InactiveCount = 0
            foreach ($Name in $CanonicalNames) {
                $Matches = @($Summaries | Where-Object { [string]$_.name -eq $Name })
                if ($Matches.Count -eq 1 -and -not [bool]$Matches[0].active) { $InactiveCount += 1 }
            }
            $FinalAllInactive = ($InactiveCount -eq $CanonicalNames.Count)
        }
    }
    catch {
        $Warnings += "Failed to verify all 7 workflows inactive: $($_.Exception.Message)"
    }

    # Clear every secret / controlled-live environment variable used by this
    # run, regardless of outcome.
    foreach ($VarName in @(
        "HMZ_N8N_API_KEY",
        "HMZ_INSTANTLY_API_KEY",
        "HMZ_INSTANTLY_API_CREDENTIAL_ID",
        "HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID",
        "HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID",
        "HMZ_REVIEW_CASES_DATA_TABLE_ID",
        "HMZ_IDEMPOTENCY_DATA_TABLE_ID",
        "HMZ_CONTROLLED_LIVE_CAMPAIGN_ID",
        "HMZ_CONTROLLED_LIVE_EACCOUNT",
        "HMZ_CONTROLLED_LIVE_LEAD_EMAIL",
        "HMZ_CONTROLLED_LIVE_REPLY_SUBJECT",
        "HMZ_N8N_PUBLIC_URL",
        "HMZ_REVIEW_PUBLIC_BASE_URL",
        "HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL"
    )) {
        Remove-Item "Env:\$VarName" -ErrorAction SilentlyContinue
    }

    return [ordered]@{
        configRestoredSafe = $FinalConfigSafe
        allWorkflowsInactiveAfter = $FinalAllInactive
        warnings = $Warnings
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$Results = Invoke-Preflight

if ($Mode -eq "PREFLIGHT_ONLY") {
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $ResultsPath) -Force | Out-Null
        $Results | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ResultsPath -Encoding utf8

        $Verdict = if ($Results.overallResult -eq "READY") {
            "CONTROLLED_LIVE_ACCEPTANCE_READY"
        } else {
            "CONTROLLED_LIVE_ACCEPTANCE_BLOCKED"
        }

        $ReportLines = @(
            '# Business-Ready Controlled-Live Acceptance'
            ''
            ('**Generated:** {0}' -f $Results.generatedAtUtc)
            ('**Mode:** {0}' -f $Mode)
            ''
            '## Verdict'
            ''
            $Verdict
            ''
            '## What this script does NOT do (preflight)'
            ''
            '- Never POSTs to the Instantly API; the only Instantly traffic is the read-only GET /api/v2/campaigns check.'
            '- Never changes config.operating_mode, config.dry_run, or config.live_campaigns.'
            '- Never applies, activates, or deactivates any workflow.'
            ''
            '## Preflight checks performed (read-only)'
            ''
            ('- config.operating_mode === "VALIDATION" (stored/safe): {0}' -f $Results.configOperatingModeValidation)
            ('- config.dry_run === true (stored/safe): {0}' -f $Results.configDryRunTrue)
            ('- config.live_credential_readiness.ready_for_controlled_live_test === true: {0}' -f $Results.configReadyFlagSet)
            ('- All 7 business-ready workflows present on local n8n: {0}' -f $Results.n8nWorkflowsApplied)
            ('- All 7 business-ready workflows inactive: {0}' -f $Results.n8nWorkflowsInactive)
            ('- Instantly API reachable with provided key (GET /api/v2/campaigns): {0}' -f $Results.instantlyApiReachable)
            ('- Designated controlled-live campaign found: {0}' -f $Results.designatedCampaignFound)
            ('- Designated campaign workspace_id non-empty: {0}' -f $Results.designatedCampaignWorkspaceNonEmpty)
            ('- Designated campaign workspace_id in config.workspace_allowlist: {0}' -f $Results.designatedCampaignInWorkspaceAllowlist)
            ('- Designated campaign workspace_id matches config.allowlists.workspace_id exactly: {0}' -f $Results.designatedCampaignWorkspaceMatchesConfigured)
            ''
            '## Next step if READY'
            ''
            'Re-run this script as:'
            '  ./run-controlled-live-acceptance.ps1 -AllowOneControlledReply -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY"'
            'after the owner has set every HMZ_CONTROLLED_LIVE_* / HMZ_*_CREDENTIAL_ID /'
            'HMZ_REVIEW_CASES_DATA_TABLE_ID / HMZ_N8N_PUBLIC_URL / HMZ_REVIEW_PUBLIC_BASE_URL /'
            'HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL environment variable required for the'
            'real, supervised, production-path controlled-live run.'
            ''
            '## Files'
            ''
            '- Detailed JSON: verification/business-ready/controlled-live-acceptance-results.json'
        )

        ($ReportLines -join [Environment]::NewLine) | Set-Content -LiteralPath $ReportPath -Encoding utf8
    }
    finally {
        Remove-Item Env:\HMZ_N8N_API_KEY -ErrorAction SilentlyContinue
        Remove-Item Env:\HMZ_INSTANTLY_API_KEY -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "=== BUSINESS-READY CONTROLLED-LIVE ACCEPTANCE ($Mode) ==="
    Write-Host ("Overall result: {0}" -f $Results.overallResult)
    Write-Host ("Report: {0}" -f $ReportPath)

    if ($Results.overallResult -ne "READY") { exit 1 }
    exit 0
}

# -AllowOneControlledReply -------------------------------------------------

$Results.controlledLiveMarker = "HMZ-CTRL-" + [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmss") + "-" + (
    -join ((1..6) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
)
$Results.liveSendPerformed = $false
$Results.liveSendResult = "NOT_ATTEMPTED"
$Results.liveSendEmailId = $null
$Results.liveSendMessageId = $null
$Results.liveSendThreadId = $null
$Results.controlledWindowStartUtc = $null
$Results.exactlyOneOutboundEmailConfirmed = $false
$Results.noDuplicateAfterObservationWindow = $false
$Results.outboundEmailCcBccEmpty = $false
$Results.outboundEmailSenderMatches = $false
$Results.outboundEmailRecipientMatches = $false
$Results.confirmedEmailIdMatchesTerminal = $false
$Results.confirmedMessageIdMatchesTerminal = $false
$Results.configRestoredSafe = $false
$Results.allWorkflowsInactiveAfter = $false
$Results.restorationWarnings = @()

$BackupDir = $null
$RuntimeWorkflowsWereActivated = $false

try {
    if ($Results.overallResult -ne "READY") {
        throw "Preflight is not READY. Resolve all preflight findings before -AllowOneControlledReply."
    }

    # Step 1: public HTTPS endpoint checks.
    Test-PublicEndpointsReady -Results $Results

    # Additional env vars for this mode.
    Assert-ControlledLiveEnvComplete

    $N8nHeaders = @{ "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY }

    # Step 2: back up config + all 7 remote workflow bodies.
    $BackupDir = Backup-ControlledLiveState -N8nHeaders $N8nHeaders
    $Results.backupDirectory = $BackupDir

    # Step 3: build the temporary live-mode config and write it to disk.
    $StoredConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -Depth 100
    $TempConfig = New-ControlledLiveConfig -Config $StoredConfig
    $TempConfig | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigPath -Encoding utf8

    # Step 4: apply (re-embed temporary constants, bind credentials).
    Invoke-ApplyBusinessReady -AdditionalEnv @{}

    # Step 5: activate the 6 runtime workflows (Full Test Harness excluded).
    Set-RuntimeWorkflowsActive -Headers $N8nHeaders -Active $true
    $RuntimeWorkflowsWereActivated = $true

    # Step 6: start the acceptance observation window BEFORE the operator
    # triggers the inbound reply or approves the review case. Otherwise the
    # resulting Sender execution can begin before polling starts and be missed.
    $ControlledWindowStartUtc = [DateTimeOffset]::UtcNow
    $Results.controlledWindowStartUtc = $ControlledWindowStartUtc.ToString("o")

    # Print operator instructions.
    Write-Host ""
    Write-Host "=== CONTROLLED-LIVE REPLY: OPERATOR ACTION REQUIRED ==="
    Write-Host ""
    Write-Host "Marker (include this verbatim in the approved reply body):"
    Write-Host ("  {0}" -f $Results.controlledLiveMarker)
    Write-Host ""
    Write-Host ("Designated campaign ID:  {0}" -f $env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID)
    Write-Host ("Designated workspace ID: {0}" -f $StoredConfig.allowlists.workspace_id)
    Write-Host ("Connected sender:        {0}" -f $env:HMZ_CONTROLLED_LIVE_EACCOUNT)
    Write-Host ("Owned test lead email:   {0}" -f $env:HMZ_CONTROLLED_LIVE_LEAD_EMAIL)
    Write-Host ("Expected reply subject:  {0}" -f $env:HMZ_CONTROLLED_LIVE_REPLY_SUBJECT)
    Write-Host ""
    Write-Host "Steps:"
    Write-Host "  1. From the owned test lead, send a real reply into the designated"
    Write-Host "     campaign so it arrives via the production Instantly webhook."
    Write-Host "  2. Open the production Human Approval review page at:"
    Write-Host ("       {0}" -f $env:HMZ_REVIEW_PUBLIC_BASE_URL)
    Write-Host "  3. Locate the review case for this reply, edit the draft reply text"
    Write-Host "     to include the marker above verbatim, and approve it EXACTLY ONCE."
    Write-Host ""

    Read-Host "Press Enter once you have approved the review case in the review page" | Out-Null

    # Step 7: poll for the outcome. No reply POST is ever issued from here.
    Wait-ForControlledReplyOutcome -N8nHeaders $N8nHeaders -Results $Results -WindowStartUtc $ControlledWindowStartUtc
    $Results.liveSendPerformed = $true
}
catch {
    if ($Results.liveSendResult -eq "NOT_ATTEMPTED") { $Results.liveSendResult = "FAILED" }
    $Results.error = $_.Exception.Message
}
finally {
    # Step 8: restore safe state regardless of outcome.
    $Restoration = Restore-SafeState -BackupDir $BackupDir -RuntimeWorkflowsWereActivated $RuntimeWorkflowsWereActivated
    $Results.configRestoredSafe = $Restoration.configRestoredSafe
    $Results.allWorkflowsInactiveAfter = $Restoration.allWorkflowsInactiveAfter
    $Results.restorationWarnings = $Restoration.warnings
}

New-Item -ItemType Directory -Path (Split-Path -Parent $ResultsPath) -Force | Out-Null
$Results | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ResultsPath -Encoding utf8

$AcceptanceFullyVerified = (
    $Results.liveSendResult -eq "SENT" -and
    [bool]$Results.exactlyOneOutboundEmailConfirmed -eq $true -and
    [bool]$Results.noDuplicateAfterObservationWindow -eq $true -and
    [bool]$Results.outboundEmailCcBccEmpty -eq $true -and
    [bool]$Results.outboundEmailSenderMatches -eq $true -and
    [bool]$Results.outboundEmailRecipientMatches -eq $true -and
    [bool]$Results.confirmedEmailIdMatchesTerminal -eq $true -and
    [bool]$Results.confirmedMessageIdMatchesTerminal -eq $true -and
    [bool]$Results.configRestoredSafe -eq $true -and
    [bool]$Results.allWorkflowsInactiveAfter -eq $true -and
    @($Results.restorationWarnings).Count -eq 0
)

$Verdict = switch ($true) {
    ($Results.overallResult -ne "READY") { "CONTROLLED_LIVE_REPLY_NOT_ATTEMPTED_BLOCKED"; break }
    ($AcceptanceFullyVerified) { "CONTROLLED_LIVE_REPLY_SENT"; break }
    ($Results.liveSendResult -eq "SENT") { "CONTROLLED_LIVE_REPLY_SENT_UNCONFIRMED"; break }
    ($Results.liveSendResult -eq "SEND_UNCERTAIN") { "CONTROLLED_LIVE_REPLY_SEND_UNCERTAIN"; break }
    default { "CONTROLLED_LIVE_REPLY_FAILED" }
}

$ReportLines = @(
    '# Business-Ready Controlled-Live Acceptance'
    ''
    ('**Generated:** {0}' -f $Results.generatedAtUtc)
    ('**Mode:** {0}' -f $Mode)
    ('**Marker:** {0}' -f $Results.controlledLiveMarker)
    ''
    '## Verdict'
    ''
    $Verdict
    ''
    '## What this run did'
    ''
    ('- Backup directory: {0}' -f $Results.backupDirectory)
    ('- Live send performed via the real, approved, production n8n workflow chain: {0}' -f $Results.liveSendPerformed)
    ('- Result (terminal.send_state from the Reply Sender workflow): {0}' -f $Results.liveSendResult)
    ('- Email ID / Message ID / Thread ID: {0} / {1} / {2}' -f $Results.liveSendEmailId, $Results.liveSendMessageId, $Results.liveSendThreadId)
    ('- Exactly one outbound Email object confirmed via GET /api/v2/emails: {0}' -f $Results.exactlyOneOutboundEmailConfirmed)
    ('- No duplicate after a 60-second observation window: {0}' -f $Results.noDuplicateAfterObservationWindow)
    ('- Correct sender confirmed locally: {0}' -f $Results.outboundEmailSenderMatches)
    ('- Correct recipient confirmed locally: {0}' -f $Results.outboundEmailRecipientMatches)
    ('- CC/BCC empty: {0}' -f $Results.outboundEmailCcBccEmpty)
    ('- Confirmed Email ID matches Sender terminal: {0}' -f $Results.confirmedEmailIdMatchesTerminal)
    ('- Confirmed message ID matches Sender terminal: {0}' -f $Results.confirmedMessageIdMatchesTerminal)
    ''
    '## What this script never does'
    ''
    '- Never POSTs to the Instantly reply-send endpoint directly; the only send path is the real, approved, production n8n workflow chain.'
    '- Never performs a second send attempt, including on SEND_UNCERTAIN (reconciliation reads only).'
    '- Never leaves config.dry_run=false, config.operating_mode=SUPERVISED_VALIDATION, or a non-empty config.live_campaigns on disk (restored in `finally`).'
    '- Never leaves any of the 7 business-ready workflows active, including the 6 temporarily activated for this run (restored in `finally`). The Full Test Harness is never activated.'
    ''
    '## Restoration'
    ''
    ('- config restored to safe defaults (operating_mode=VALIDATION, dry_run=true, live_campaigns=[]): {0}' -f $Results.configRestoredSafe)
    ('- All 7 workflows inactive after restore: {0}' -f $Results.allWorkflowsInactiveAfter)
)

if (@($Results.restorationWarnings).Count -gt 0) {
    $ReportLines += ''
    $ReportLines += '## Restoration warnings'
    $ReportLines += ''
    foreach ($Warning in @($Results.restorationWarnings)) {
        $ReportLines += "- $Warning"
    }
}

$ReportLines += @(
    ''
    '## Files'
    ''
    '- Detailed JSON: verification/business-ready/controlled-live-acceptance-results.json'
)

($ReportLines -join [Environment]::NewLine) | Set-Content -LiteralPath $ReportPath -Encoding utf8

Write-Host ""
Write-Host "=== BUSINESS-READY CONTROLLED-LIVE ACCEPTANCE ($Mode) ==="
Write-Host ("Overall result: {0}" -f $Results.overallResult)
Write-Host ("Live send result: {0}" -f $Results.liveSendResult)
Write-Host ("Verdict: {0}" -f $Verdict)
Write-Host ("Config restored safe: {0}" -f $Results.configRestoredSafe)
Write-Host ("All workflows inactive after: {0}" -f $Results.allWorkflowsInactiveAfter)
Write-Host ("Report: {0}" -f $ReportPath)

if ($Verdict -ne "CONTROLLED_LIVE_REPLY_SENT") { exit 1 }
exit 0

