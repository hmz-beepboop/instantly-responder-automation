#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Project = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$N8nUrl = "http://127.0.0.1:5678"
$ComposeFile = Join-Path $Project "infrastructure\local-n8n\docker-compose.yml"
$MainContainer = "hmz-n8n-local-dev"
$ReportDir = Join-Path $Project "reports"
$VerificationDir = Join-Path $Project "verification\phase5"
$JsonPath = Join-Path $VerificationDir "mechanical-audit.json"
$MarkdownPath = Join-Path $ReportDir "PHASE_5_MECHANICAL_AUDIT.md"

$WorkflowTargets = @(
    [pscustomobject]@{ Name="HMZ - Instantly Reply Intake - Validation"; Id="cCcpFfi6iovWS94T"; File="workflows\01_reply_intake_validation.json" },
    [pscustomobject]@{ Name="HMZ - Reply Decision Engine - Validation"; Id="NJcnNQoJ5nSIWYte"; File="workflows\02_reply_decision_engine_validation.json" },
    [pscustomobject]@{ Name="HMZ - Instantly Reply Sender - Validation"; Id="OzYLWuCF6DoU7Iw9"; File="workflows\03_reply_sender_validation.json" },
    [pscustomobject]@{ Name="HMZ - Reply Error Handler - Validation"; Id="koyKIaY2ExF3yhx7"; File="workflows\04_reply_error_handler_validation.json" },
    [pscustomobject]@{ Name="HMZ - Reply SLA Watchdog - Validation"; Id="37p0OPzfDxlPvYQo"; File="workflows\05_reply_sla_watchdog_validation.json" },
    [pscustomobject]@{ Name="HMZ - Reply Full Test Harness - Validation"; Id="gu9Ede8IM5cHGtKK"; File="workflows\06_reply_full_test_harness_validation.json" }
)

$KnownSyntheticSecretFiles = @(
    "verification\phase4a\run-offline-tests.mjs",
    "verification\phase4b\run-offline-tests.mjs"
)

function Get-Sha256Text {
    param([AllowEmptyString()][string]$Text)

    $Bytes = [Text.Encoding]::UTF8.GetBytes([string]$Text)
    $Hash = [Security.Cryptography.SHA256]::HashData($Bytes)
    return [Convert]::ToHexString($Hash)
}

function Get-OptionalProperty {
    param($Object, [string]$Name)

    if ($null -eq $Object) {
        return $null
    }

    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function Get-CommandResult {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [int]$TimeoutSeconds = 300
    )

    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $FilePath
    $StartInfo.WorkingDirectory = (Get-Location).Path
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $true

    foreach ($Argument in $ArgumentList) {
        [void]$StartInfo.ArgumentList.Add([string]$Argument)
    }

    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo

    try {
        if (-not $Process.Start()) {
            throw "Failed to start command: $FilePath"
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
        [int]$MaxLength = 1000
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

    if ($Value.Length -gt $MaxLength) {
        return $Value.Substring(0, $MaxLength) + '...<TRUNCATED>'
    }

    return $Value
}

function Test-WorkflowRemoteLocal {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)]$Remote
    )

    $LocalPath = Join-Path $Project $Target.File
    if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
        throw "Missing local workflow export: $LocalPath"
    }

    $Local = Get-Content -LiteralPath $LocalPath -Raw | ConvertFrom-Json
    $LocalNodes = @($Local.nodes)
    $RemoteNodes = @($Remote.nodes)
    $Mismatches = @()

    if ([string]$Remote.name -ne $Target.Name) {
        $Mismatches += "remote_name_mismatch"
    }

    if ($LocalNodes.Count -ne $RemoteNodes.Count) {
        $Mismatches += "node_count_mismatch"
    }

    foreach ($LocalNode in $LocalNodes) {
        $Matches = @($RemoteNodes | Where-Object { $_.name -eq $LocalNode.name })

        if ($Matches.Count -ne 1) {
            $Mismatches += "node_match_count:$($LocalNode.name):$($Matches.Count)"
            continue
        }

        $RemoteNode = $Matches[0]

        if ([string]$LocalNode.type -ne [string]$RemoteNode.type) {
            $Mismatches += "node_type:$($LocalNode.name)"
        }

        if ([string]$LocalNode.typeVersion -ne [string]$RemoteNode.typeVersion) {
            $Mismatches += "node_version:$($LocalNode.name)"
        }

        if ($LocalNode.type -eq 'n8n-nodes-base.code') {
            $LocalCode = [string](Get-OptionalProperty $LocalNode.parameters 'jsCode')
            $RemoteCode = [string](Get-OptionalProperty $RemoteNode.parameters 'jsCode')

            if ((Get-Sha256Text $LocalCode) -ne (Get-Sha256Text $RemoteCode)) {
                $Mismatches += "code_hash:$($LocalNode.name)"
            }
        }

        if ($LocalNode.type -eq 'n8n-nodes-base.httpRequest') {
            $LocalUrl = [string](Get-OptionalProperty $LocalNode.parameters 'url')
            $RemoteUrl = [string](Get-OptionalProperty $RemoteNode.parameters 'url')

            if ($LocalUrl -ne $RemoteUrl) {
                $Mismatches += "http_url:$($LocalNode.name)"
            }
        }
    }

    $RemoteJson = $Remote | ConvertTo-Json -Depth 100 -Compress
    $HasCredentials = $RemoteJson -match '"credentials"\s*:'
    $ExternalHttpTargets = @()

    foreach ($Node in $RemoteNodes | Where-Object { $_.type -eq 'n8n-nodes-base.httpRequest' }) {
        $Url = [string](Get-OptionalProperty $Node.parameters 'url')

        if (
            -not [string]::IsNullOrWhiteSpace($Url) -and
            -not $Url.StartsWith(
                'http://hmz-send-state:5681',
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            $ExternalHttpTargets += "$($Node.name):$Url"
        }
    }

    return [pscustomobject]@{
        name = $Target.Name
        id = $Target.Id
        active = [bool]$Remote.active
        nodeCountLocal = $LocalNodes.Count
        nodeCountRemote = $RemoteNodes.Count
        localMatchesRemote = ($Mismatches.Count -eq 0)
        mismatches = @($Mismatches)
        credentialsBound = $HasCredentials
        externalHttpTargets = @($ExternalHttpTargets)
    }
}

function Wait-ForN8n {
    param(
        [Parameter(Mandatory)][hashtable]$Headers,
        [int]$TimeoutSeconds = 90
    )

    $Deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)

    while ([DateTimeOffset]::UtcNow -lt $Deadline) {
        try {
            Invoke-RestMethod `
                -Uri "$N8nUrl/api/v1/workflows/cCcpFfi6iovWS94T" `
                -Method Get `
                -Headers $Headers `
                -TimeoutSec 5 |
                Out-Null

            return $true
        }
        catch {
            Start-Sleep -Seconds 3
        }
    }

    return $false
}

function Replace-KnownHistoricalOwnerEmail {
    $File = Join-Path $Project "reports\PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md"

    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        return 0
    }

    $Original = Get-Content -LiteralPath $File -Raw
    $EmailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    $ReplacementCount = 0
    $Updated = $Original

    $Matches = @([regex]::Matches($Original, $EmailPattern))

    foreach ($Match in $Matches) {
        $Value = $Match.Value.ToLowerInvariant()
        $Synthetic =
            $Value.EndsWith('.test') -or
            $Value.EndsWith('@example.com') -or
            $Value.EndsWith('@example.test') -or
            $Value.EndsWith('@ourdomain.com')

        if ($Synthetic) {
            continue
        }

        $Updated = $Updated.Replace(
            $Match.Value,
            '<LOCAL_N8N_OWNER_EMAIL>',
            [StringComparison]::Ordinal
        )
        $ReplacementCount++
    }

    if ($Updated -ne $Original) {
        Set-Content -LiteralPath $File -Value $Updated -Encoding utf8
    }

    return $ReplacementCount
}

New-Item -ItemType Directory -Path $VerificationDir, $ReportDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $ComposeFile -PathType Leaf)) {
    throw "Missing Docker Compose file: $ComposeFile"
}

$SecureKey = Read-Host "Enter the local n8n API key" -AsSecureString
$Pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureKey)
$ApiKey = $null
$Headers = $null

try {
    $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Pointer)
    $Headers = @{ "X-N8N-API-KEY" = $ApiKey }

    Set-Location $Project

    $Results = [ordered]@{
        schemaVersion = "2.0"
        generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
        mode = "SYNTHETIC_RUNTIME_AND_READ_ONLY_REMOTE_AUDIT"
        externalInstantlyCallsPermitted = $false
        historicalOwnerEmailReplacements = 0
        workflowChecks = @()
        commands = [ordered]@{}
        projectScan = [ordered]@{}
        final = [ordered]@{}
    }

    $Results.historicalOwnerEmailReplacements = Replace-KnownHistoricalOwnerEmail

    $Phase4A = Get-CommandResult `
        -FilePath "node" `
        -ArgumentList @(".\verification\phase4a\run-offline-tests.mjs") `
        -TimeoutSeconds 300

    $Results.commands.phase4a = [ordered]@{
        exitCode = $Phase4A.ExitCode
        timedOut = $Phase4A.TimedOut
        passedMarker = ($Phase4A.Stdout -match '42/42 passed, 0 failed')
        outputHash = Get-Sha256Text $Phase4A.Stdout
        errorSnippet = Get-SanitisedSnippet $Phase4A.Stderr
    }

    $Phase4B = Get-CommandResult `
        -FilePath "node" `
        -ArgumentList @(".\verification\phase4b\run-offline-tests.mjs") `
        -TimeoutSeconds 300

    $Results.commands.phase4b = [ordered]@{
        exitCode = $Phase4B.ExitCode
        timedOut = $Phase4B.TimedOut
        passedMarker = ($Phase4B.Stdout -match '31/31 passed, 0 failed')
        outputHash = Get-Sha256Text $Phase4B.Stdout
        errorSnippet = Get-SanitisedSnippet $Phase4B.Stderr
    }

    $Health = Get-CommandResult `
        -FilePath "docker" `
        -ArgumentList @(
            "exec",
            $MainContainer,
            "node",
            "-e",
            "fetch('http://hmz-send-state:5681/health').then(async r=>{const t=await r.text();console.log(t);if(!r.ok)process.exit(2)}).catch(e=>{console.error(e.message);process.exit(1)})"
        ) `
        -TimeoutSeconds 60

    $Results.commands.sidecarHealth = [ordered]@{
        exitCode = $Health.ExitCode
        timedOut = $Health.TimedOut
        okMarker = ($Health.Stdout -match '"status"\s*:\s*"ok"')
        outputSnippet = Get-SanitisedSnippet $Health.Stdout
        errorSnippet = Get-SanitisedSnippet $Health.Stderr
    }

    foreach ($Target in $WorkflowTargets) {
        $Remote = Invoke-RestMethod `
            -Uri "$N8nUrl/api/v1/workflows/$($Target.Id)" `
            -Method Get `
            -Headers $Headers

        $Results.workflowChecks += Test-WorkflowRemoteLocal `
            -Target $Target `
            -Remote $Remote
    }

    $Audit = Get-CommandResult `
        -FilePath "docker" `
        -ArgumentList @(
            "exec",
            "-u",
            "node",
            $MainContainer,
            "n8n",
            "audit"
        ) `
        -TimeoutSeconds 180

    $AuditCombined = $Audit.Stdout + "`n" + $Audit.Stderr

    $Results.commands.n8nSecurityAudit = [ordered]@{
        exitCode = $Audit.ExitCode
        timedOut = $Audit.TimedOut
        outputHash = Get-Sha256Text $AuditCombined
        outputSnippet = Get-SanitisedSnippet $AuditCombined 1600
    }

    $StopResult = Get-CommandResult `
        -FilePath "docker" `
        -ArgumentList @(
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

    try {
        $Harness = Get-CommandResult `
            -FilePath "docker" `
            -ArgumentList @(
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
                "gu9Ede8IM5cHGtKK"
            ) `
            -TimeoutSeconds 360

        $HarnessCombined = $Harness.Stdout + "`n" + $Harness.Stderr

        $Results.commands.fullTestHarnessRuntime = [ordered]@{
            exitCode = $Harness.ExitCode
            timedOut = $Harness.TimedOut
            passMarker = (
                $HarnessCombined -match '(?is)overall_result.{0,120}PASS' -or
                $HarnessCombined -match '(?i)execution was successful' -or
                $HarnessCombined -match '(?i)workflow executed successfully'
            )
            failedZeroMarker = ($HarnessCombined -match '(?is)failed.{0,30}0')
            outputHash = Get-Sha256Text $HarnessCombined
            outputSnippet = Get-SanitisedSnippet $HarnessCombined 1400
        }

        $Watchdog = Get-CommandResult `
            -FilePath "docker" `
            -ArgumentList @(
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
                "37p0OPzfDxlPvYQo"
            ) `
            -TimeoutSeconds 240

        $WatchdogCombined = $Watchdog.Stdout + "`n" + $Watchdog.Stderr

        $Results.commands.watchdogRuntime = [ordered]@{
            exitCode = $Watchdog.ExitCode
            timedOut = $Watchdog.TimedOut
            successMarker = (
                $WatchdogCombined -match '(?i)execution was successful' -or
                $WatchdogCombined -match '(?i)workflow executed successfully' -or
                $WatchdogCombined -match '(?is)watchdog_result'
            )
            outputHash = Get-Sha256Text $WatchdogCombined
            outputSnippet = Get-SanitisedSnippet $WatchdogCombined 1400
        }
    }
    finally {
        $StartResult = Get-CommandResult `
            -FilePath "docker" `
            -ArgumentList @(
                "compose",
                "-f",
                $ComposeFile,
                "up",
                "-d",
                "n8n"
            ) `
            -TimeoutSeconds 180

        if ($StartResult.ExitCode -ne 0) {
            throw "Failed to restart the main n8n service: $(Get-SanitisedSnippet $StartResult.Stderr)"
        }

        if (-not (Wait-ForN8n -Headers $Headers -TimeoutSeconds 90)) {
            throw "The main n8n service did not become API-ready after restart."
        }
    }

    $TextFiles = Get-ChildItem -LiteralPath $Project -File -Recurse |
        Where-Object {
            $_.FullName -notmatch '\\.git\\' -and
            $_.Extension -notin @(
                '.zip',
                '.docx',
                '.png',
                '.jpg',
                '.jpeg',
                '.pdf'
            )
        }

    $RealEmailHits = @()
    $UnexpectedSecretPatternHits = @()
    $SyntheticSecretPatternHits = @()

    foreach ($File in $TextFiles) {
        $Content = Get-Content `
            -LiteralPath $File.FullName `
            -Raw `
            -ErrorAction SilentlyContinue

        if ($null -eq $Content) {
            continue
        }

        $Relative = $File.FullName.Substring($Project.Length).TrimStart('\')

        $EmailMatches = [regex]::Matches(
            $Content,
            '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
        )

        foreach ($Match in $EmailMatches) {
            $Value = $Match.Value.ToLowerInvariant()
            $Synthetic =
                $Value.EndsWith('.test') -or
                $Value.EndsWith('@example.com') -or
                $Value.EndsWith('@example.test') -or
                $Value.EndsWith('@ourdomain.com')

            if (-not $Synthetic) {
                $RealEmailHits += $Relative
            }
        }

        if ($Content -match '(?i)(sk-[A-Za-z0-9_-]{10,}|Bearer\s+[A-Za-z0-9._-]{16,})') {
            if ($KnownSyntheticSecretFiles -contains $Relative) {
                $SyntheticSecretPatternHits += $Relative
            }
            else {
                $UnexpectedSecretPatternHits += $Relative
            }
        }
    }

    $Results.projectScan.realEmailHitCount = @(
        $RealEmailHits |
            Sort-Object -Unique
    ).Count

    $Results.projectScan.realEmailFiles = @(
        $RealEmailHits |
            Sort-Object -Unique
    )

    $Results.projectScan.syntheticSecretPatternHitCount = @(
        $SyntheticSecretPatternHits |
            Sort-Object -Unique
    ).Count

    $Results.projectScan.syntheticSecretPatternFiles = @(
        $SyntheticSecretPatternHits |
            Sort-Object -Unique
    )

    $Results.projectScan.unexpectedSecretPatternHitCount = @(
        $UnexpectedSecretPatternHits |
            Sort-Object -Unique
    ).Count

    $Results.projectScan.unexpectedSecretPatternFiles = @(
        $UnexpectedSecretPatternHits |
            Sort-Object -Unique
    )

    $AllInactive = @(
        $Results.workflowChecks |
            Where-Object { $_.active }
    ).Count -eq 0

    $AllRemoteMatch = @(
        $Results.workflowChecks |
            Where-Object { -not $_.localMatchesRemote }
    ).Count -eq 0

    $NoCredentials = @(
        $Results.workflowChecks |
            Where-Object { $_.credentialsBound }
    ).Count -eq 0

    $NoExternalHttp = @(
        $Results.workflowChecks |
            Where-Object { $_.externalHttpTargets.Count -gt 0 }
    ).Count -eq 0

    $HarnessPassed =
        $Results.commands.fullTestHarnessRuntime.exitCode -eq 0 -and
        -not $Results.commands.fullTestHarnessRuntime.timedOut

    $WatchdogPassed =
        $Results.commands.watchdogRuntime.exitCode -eq 0 -and
        -not $Results.commands.watchdogRuntime.timedOut

    $MechanicalPass =
        $Results.commands.phase4a.passedMarker -and
        $Results.commands.phase4b.passedMarker -and
        $Results.commands.sidecarHealth.okMarker -and
        $AllInactive -and
        $AllRemoteMatch -and
        $NoCredentials -and
        $NoExternalHttp -and
        $HarnessPassed -and
        $WatchdogPassed -and
        $Results.projectScan.realEmailHitCount -eq 0 -and
        $Results.projectScan.unexpectedSecretPatternHitCount -eq 0

    $Results.final.allInactive = $AllInactive
    $Results.final.allRemoteMatch = $AllRemoteMatch
    $Results.final.noCredentials = $NoCredentials
    $Results.final.noExternalHttpTargets = $NoExternalHttp
    $Results.final.harnessRuntimePassed = $HarnessPassed
    $Results.final.watchdogRuntimePassed = $WatchdogPassed
    $Results.final.mechanicalPass = $MechanicalPass
    $Results.final.verdict = if ($MechanicalPass) {
        "PHASE_5_MECHANICAL_AUDIT_PASSED"
    }
    else {
        "PHASE_5_MECHANICAL_AUDIT_FAILED"
    }

    $Results |
        ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $JsonPath -Encoding utf8

    $WorkflowRows = foreach ($Check in $Results.workflowChecks) {
        "| $($Check.name) | $($Check.id) | $($Check.active) | $($Check.localMatchesRemote) | $($Check.credentialsBound) | $($Check.externalHttpTargets.Count) |"
    }

    $Phase4AExit = $Results.commands.phase4a.exitCode
    $Phase4APass = $Results.commands.phase4a.passedMarker
    $Phase4BExit = $Results.commands.phase4b.exitCode
    $Phase4BPass = $Results.commands.phase4b.passedMarker
    $HealthExit = $Results.commands.sidecarHealth.exitCode
    $HealthPass = $Results.commands.sidecarHealth.okMarker
    $HarnessExit = $Results.commands.fullTestHarnessRuntime.exitCode
    $HarnessTimeout = $Results.commands.fullTestHarnessRuntime.timedOut
    $HarnessMarker = $Results.commands.fullTestHarnessRuntime.passMarker
    $HarnessSnippet = $Results.commands.fullTestHarnessRuntime.outputSnippet
    $WatchdogExit = $Results.commands.watchdogRuntime.exitCode
    $WatchdogTimeout = $Results.commands.watchdogRuntime.timedOut
    $WatchdogMarker = $Results.commands.watchdogRuntime.successMarker
    $WatchdogSnippet = $Results.commands.watchdogRuntime.outputSnippet
    $SecurityExit = $Results.commands.n8nSecurityAudit.exitCode
    $SecurityTimeout = $Results.commands.n8nSecurityAudit.timedOut
    $SecuritySnippet = $Results.commands.n8nSecurityAudit.outputSnippet
    $RealEmailCount = $Results.projectScan.realEmailHitCount
    $RealEmailFiles = $Results.projectScan.realEmailFiles -join ', '
    $SyntheticSecretCount = $Results.projectScan.syntheticSecretPatternHitCount
    $SyntheticSecretFiles = $Results.projectScan.syntheticSecretPatternFiles -join ', '
    $UnexpectedSecretCount = $Results.projectScan.unexpectedSecretPatternHitCount
    $UnexpectedSecretFiles = $Results.projectScan.unexpectedSecretPatternFiles -join ', '
    $FinalVerdict = $Results.final.verdict

    $Markdown = @"
# Phase 5 Mechanical Audit

**Generated:** $($Results.generatedAtUtc)

## Safety boundary

- No live Instantly call was made.
- No workflow was activated or modified.
- The main n8n service was temporarily stopped only to avoid the documented task-broker port conflict during CLI execution.
- The main n8n service was restarted and confirmed API-ready.
- The n8n workflow executions were synthetic/local only.

## Workflow checks

| Workflow | ID | Active | Local matches remote | Credentials | External HTTP targets |
|---|---|---:|---:|---:|---:|
$($WorkflowRows -join "`n")

## Deterministic suites

- Phase 4A exit: $Phase4AExit
- Phase 4A pass marker: $Phase4APass
- Phase 4B exit: $Phase4BExit
- Phase 4B pass marker: $Phase4BPass
- Sidecar health exit: $HealthExit
- Sidecar healthy: $HealthPass

## Actual n8n runtime

### Full Test Harness

- Exit code: $HarnessExit
- Timed out: $HarnessTimeout
- PASS/success marker observed: $HarnessMarker
- Sanitised output snippet:

    $($HarnessSnippet -replace "`n", "`n    ")

### SLA Watchdog

- Exit code: $WatchdogExit
- Timed out: $WatchdogTimeout
- Success marker observed: $WatchdogMarker
- Sanitised output snippet:

    $($WatchdogSnippet -replace "`n", "`n    ")

## n8n security audit

- Exit code: $SecurityExit
- Timed out: $SecurityTimeout
- Sanitised output snippet:

    $($SecuritySnippet -replace "`n", "`n    ")

## Project scan

- Historical owner-email replacements made: $($Results.historicalOwnerEmailReplacements)
- Real-email hit count after cleanup: $RealEmailCount
- Real-email files after cleanup: $RealEmailFiles
- Known synthetic secret-pattern hit count: $SyntheticSecretCount
- Known synthetic secret-pattern files: $SyntheticSecretFiles
- Unexpected secret-pattern hit count: $UnexpectedSecretCount
- Unexpected secret-pattern files: $UnexpectedSecretFiles

## Mechanical verdict

$FinalVerdict

## Known limitations

- The Phase 4B n8n-MCP static-validator exception remains documented.
- Intake and Decision Engine runtime acceptance is inherited from Phase 3 evidence.
- Sender/Error Handler Code-node runtime and sidecar contracts are inherited from the audited Phase 4A suite.
- A controlled live Instantly send remains outside Phase 5 and is prohibited.
"@

    $Markdown |
        Set-Content -LiteralPath $MarkdownPath -Encoding utf8

    Write-Host ""
    Write-Host "=== PHASE 5 MECHANICAL AUDIT V2 ==="
    Write-Host ("Verdict: {0}" -f $Results.final.verdict)
    Write-Host ("All workflows inactive: {0}" -f $Results.final.allInactive)
    Write-Host ("Remote/local match: {0}" -f $Results.final.allRemoteMatch)
    Write-Host ("No credentials: {0}" -f $Results.final.noCredentials)
    Write-Host ("No external HTTP targets: {0}" -f $Results.final.noExternalHttpTargets)
    Write-Host ("Harness runtime exit: {0}" -f $Results.commands.fullTestHarnessRuntime.exitCode)
    Write-Host ("Watchdog runtime exit: {0}" -f $Results.commands.watchdogRuntime.exitCode)
    Write-Host ("Real-email hit count: {0}" -f $Results.projectScan.realEmailHitCount)
    Write-Host ("Unexpected secret-pattern hit count: {0}" -f $Results.projectScan.unexpectedSecretPatternHitCount)
    Write-Host ("Known synthetic secret-pattern files: {0}" -f $Results.projectScan.syntheticSecretPatternHitCount)
    Write-Host ("JSON: {0}" -f $JsonPath)
    Write-Host ("Report: {0}" -f $MarkdownPath)
}
finally {
    if ($Pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Pointer)
    }

    $ApiKey = $null
    $Headers = $null
    $SecureKey = $null
}
