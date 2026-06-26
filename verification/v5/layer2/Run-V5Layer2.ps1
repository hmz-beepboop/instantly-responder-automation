#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Mask-Email([string]$Email) {
    if ([string]::IsNullOrWhiteSpace($Email) -or $Email -notmatch '^([^@]+)@(.+)$') {
        return '<INVALID_EMAIL>'
    }
    $local = $Matches[1]
    $domain = $Matches[2]
    $maskedLocal = if ($local.Length -le 1) { '*' } else { $local.Substring(0, 1) + ('*' * ($local.Length - 1)) }
    return "$maskedLocal@$domain"
}

function Mask-Id([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -le 12) { return '<REDACTED_ID>' }
    return "$($Value.Substring(0, 8))...$($Value.Substring($Value.Length - 4))"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunnerPath = Join-Path $ScriptDir 'run-layer2.mjs'
$StateDir = Join-Path $env:TEMP 'HMZ_V5_LAYER2_STATE'

$apiKeySecure = $null
$apiKeyPlainBstr = [IntPtr]::Zero
$apiKeyPlain = $null
$exitCode = 1

try {
    if (-not (Test-Path -LiteralPath $RunnerPath -PathType Leaf)) {
        throw "Missing runner: $RunnerPath"
    }
    if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        throw 'Node.js was not found.'
    }

    Write-Host '=== V5 Layer 2 controlled live verification ==='
    Write-Host 'This permits exactly one reply POST. The upstream response will be dropped,'
    Write-Host 'then the result will be reconciled read-only. Never rerun this test with the'
    Write-Host 'same inbound Email object ID.'
    Write-Host ''

    $apiKeySecure = Read-Host -Prompt 'Instantly API key' -AsSecureString
    $inboundEmailId = (Read-Host -Prompt 'Inbound Email object ID (reply_to_uuid)').Trim()
    $expectedRecipient = (Read-Host -Prompt 'Expected controlled recipient (lead email)').Trim()
    $expectedSender = (Read-Host -Prompt 'Expected connected sender (eaccount)').Trim()

    if ([string]::IsNullOrWhiteSpace($inboundEmailId)) { throw 'Inbound Email object ID is required.' }
    if ($expectedRecipient -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw 'Expected recipient is not a valid email address.' }
    if ($expectedSender -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw 'Expected sender is not a valid email address.' }
    if ($expectedRecipient.Equals($expectedSender, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Expected recipient and sender must differ.'
    }

    Write-Host ''
    Write-Host '=== Sanitised preflight ==='
    Write-Host "Base URL                : https://api.instantly.ai"
    Write-Host "Mode                    : live"
    Write-Host "Inbound Email ID        : $(Mask-Id $inboundEmailId)"
    Write-Host "Expected sender         : $(Mask-Email $expectedSender)"
    Write-Host "Expected recipient      : $(Mask-Email $expectedRecipient)"
    Write-Host "Durable state directory : $StateDir"
    Write-Host 'API key                 : hidden'
    Write-Host ''
    Write-Host 'The Node runner will retrieve the inbound Email object and refuse to send'
    Write-Host 'unless its ID, thread, sender, recipient, and subject verify correctly.'
    Write-Host ''

    $confirmation = Read-Host -Prompt 'Type RUN-V5-LAYER2 to proceed (anything else aborts)'
    if ($confirmation -cne 'RUN-V5-LAYER2') {
        Write-Host 'Confirmation phrase not matched. No request was sent.'
        exit 1
    }

    $apiKeyPlainBstr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($apiKeySecure)
    $apiKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($apiKeyPlainBstr)

    $env:V5_L2_MODE = 'live'
    $env:V5_L2_BASE_URL = 'https://api.instantly.ai'
    $env:V5_L2_API_KEY = $apiKeyPlain
    $env:V5_L2_LIVE_CONFIRM = 'RUN-V5-LAYER2'
    $env:V5_L2_INBOUND_EMAIL_ID = $inboundEmailId
    $env:V5_L2_EXPECTED_SENDER = $expectedSender
    $env:V5_L2_EXPECTED_RECIPIENT = $expectedRecipient
    $env:V5_L2_STATE_DIR = $StateDir
    $apiKeyPlain = $null

    Write-Host ''
    Write-Host 'Starting the single controlled live attempt...'
    & node $RunnerPath
    $exitCode = $LASTEXITCODE

    Write-Host ''
    Write-Host "Node exit code: $exitCode"
    Write-Host "Sanitised result: $ScriptDir\live-result.sanitized.json"
    Write-Host "Evidence report : $(Join-Path (Resolve-Path (Join-Path $ScriptDir '..\..\..')).Path 'reports\V5_LAYER2_EVIDENCE.md')"
}
finally {
    if ($apiKeyPlainBstr -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($apiKeyPlainBstr)
        $apiKeyPlainBstr = [IntPtr]::Zero
    }
    $apiKeyPlain = $null
    if ($null -ne $apiKeySecure) {
        $apiKeySecure.Dispose()
        $apiKeySecure = $null
    }
    Remove-Item Env:V5_L2_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_LIVE_CONFIRM -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_INBOUND_EMAIL_ID -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_EXPECTED_SENDER -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_EXPECTED_RECIPIENT -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:V5_L2_STATE_DIR -ErrorAction SilentlyContinue
    [System.GC]::Collect()
}

exit $exitCode
