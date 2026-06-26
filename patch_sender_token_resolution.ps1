<#
.SYNOPSIS
  SL-PATCH-1.1 — Sender Node B: add resolveTokens() before runSendGates()
  Resolves <<senderName>> from draft.sender_config.senderName.
  Resolves <<firstName>> from nes.lead_first_name (empty fallback when absent).

  DIAGNOSIS: Sender returns BLOCKED because draft.draft_text contains
  unresolved template tokens <<firstName>> and <<senderName>>.
  Node B gate check detects them → draft_variable_gate_passed = false → C2 → BLOCKED.

.PARAMETER WhatIf
  Preview all actions without executing them.

.PARAMETER Apply
  Execute the patch.
#>
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: .\patch_sender_token_resolution.ps1 -WhatIf   (preview)"
    Write-Host "       .\patch_sender_token_resolution.ps1 -Apply    (execute)"
    exit 0
}

$apiKey = $env:HMZ_N8N_API_KEY
if (-not $apiKey) { throw "HMZ_N8N_API_KEY env var not set." }

$headers = @{
    "X-N8N-API-KEY" = $apiKey
    "Content-Type"  = "application/json"
}
$base = "https://n8n.hmzaiautomation.com/api/v1"

$WF = @{
    Intake          = "VtDQqw02Ux1TgjIH"
    DecisionEngine  = "tgYmY97CG4Bm8snI"
    HumanApproval   = "9aPrt92jFhoYFxbs"
    Sender          = "ePS5uBBxKxhFCYgU"
    ErrorHandler    = "2PR9YEkG4KyGdowa"
    SLAWatchdog     = "6a8ojyXCwMwI9nyF"
    FullTestHarness = "RLUcJHQJPvLhw4mG"
}

$deactivateOrder  = @("Intake","SLAWatchdog","ErrorHandler","HumanApproval","DecisionEngine","Sender")
$reactivateOrder  = @("Sender","DecisionEngine","HumanApproval","ErrorHandler","SLAWatchdog","Intake")
$productionNames  = @("Intake","DecisionEngine","HumanApproval","Sender","ErrorHandler","SLAWatchdog")

# ── helpers ──────────────────────────────────────────────────────────────────

function Invoke-N8n($method, $path, $body = $null) {
    $uri = "$base$path"
    if ($body) {
        return Invoke-RestMethod -Uri $uri -Headers $headers -Method $method `
            -Body ($body | ConvertTo-Json -Depth 30 -Compress) -ContentType "application/json"
    }
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method $method
}

function Step($msg) { Write-Host "`n=== $msg ===" }

# ── STEP 1: Backup ────────────────────────────────────────────────────────────
Step "1. BACKUP ALL 7 WORKFLOWS"

$backupDir = ".\backup_SL-PATCH-1.1_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

foreach ($entry in $WF.GetEnumerator()) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would backup $($entry.Key) ($($entry.Value)) -> $backupDir\$($entry.Key).json"
    } else {
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $data = Invoke-N8n GET "/workflows/$($entry.Value)"
        $data | ConvertTo-Json -Depth 30 | Set-Content "$backupDir\$($entry.Key).json" -Encoding UTF8
        Write-Host "  Backed up: $($entry.Key)"
    }
}

# ── STEP 2: Deactivate ────────────────────────────────────────────────────────
Step "2. DEACTIVATE PRODUCTION WORKFLOWS"

foreach ($name in $deactivateOrder) {
    $id = $WF[$name]
    if ($WhatIf) {
        Write-Host "[WhatIf] Would deactivate $name ($id)"
    } else {
        try {
            Invoke-N8n POST "/workflows/$id/deactivate" | Out-Null
            Write-Host "  Deactivated: $name"
        } catch {
            Write-Host "  Note: $name may already be inactive — continuing. ($_)"
        }
    }
}

# ── STEP 3: Build patch ───────────────────────────────────────────────────────
Step "3. BUILD PATCH: Sender Node B — add resolveTokens()"

# Exact string to find (last line of Node B jsCode)
$OLD_LINE = 'return items.map(item => ({ json: runSendGates(item.json || {}) }));'

# Replacement: inject resolveTokens before runSendGates call
$NEW_BLOCK = @'
function resolveTokens(input) {
  const d = input.draft || {};
  const sc = d.sender_config || {};
  const nes = input.nes || {};
  if (typeof d.draft_text === 'string') {
    d.draft_text = d.draft_text
      .replace(/<<senderName>>/g, sc.senderName || sc.sender_name || '')
      .replace(/<<firstName>>/g, nes.lead_first_name || '');
    // clean up orphaned punctuation from empty substitutions (e.g. ", ." -> ".")
    d.draft_text = d.draft_text.replace(/,\s*\./g, '.').replace(/^,\s*/gm, '');
  }
  return input;
}

return items.map(item => ({ json: runSendGates(resolveTokens(item.json || {})) }));
'@

if ($WhatIf) {
    Write-Host "[WhatIf] Would inject resolveTokens() into Sender Node B jsCode."
    Write-Host "  Resolves: <<senderName>> from draft.sender_config.senderName"
    Write-Host "  Resolves: <<firstName>> from nes.lead_first_name (empty fallback)"
    Write-Host "  Cleans:   orphaned punctuation after empty substitution"
} else {
    $senderWf = Invoke-N8n GET "/workflows/$($WF.Sender)"

    # Locate Node B
    $nodeBIdx = -1
    for ($i = 0; $i -lt $senderWf.nodes.Count; $i++) {
        if ($senderWf.nodes[$i].name -eq "B. Re-run Send & Suppression Gates") {
            $nodeBIdx = $i; break
        }
    }
    if ($nodeBIdx -lt 0) { throw "Could not find 'B. Re-run Send & Suppression Gates' in Sender workflow." }

    $currentCode = $senderWf.nodes[$nodeBIdx].parameters.jsCode
    if ($currentCode -notlike "*$OLD_LINE*") {
        throw "Anchor line not found in Node B jsCode — patch may already be applied or code changed."
    }

    $patchedCode = $currentCode.Replace($OLD_LINE, $NEW_BLOCK.Trim())
    $senderWf.nodes[$nodeBIdx].parameters.jsCode = $patchedCode

    # PUT full workflow back
    Invoke-N8n PUT "/workflows/$($WF.Sender)" $senderWf | Out-Null
    Write-Host "  Patched: Sender Node B (resolveTokens added)"
}

# ── STEP 4: Reactivate ────────────────────────────────────────────────────────
Step "4. REACTIVATE PRODUCTION WORKFLOWS"

foreach ($name in $reactivateOrder) {
    $id = $WF[$name]
    if ($WhatIf) {
        Write-Host "[WhatIf] Would reactivate $name ($id)"
    } else {
        Invoke-N8n POST "/workflows/$id/activate" | Out-Null
        Write-Host "  Activated: $name"
    }
}

# ── STEP 5: Verify ────────────────────────────────────────────────────────────
Step "5. VERIFY"

$allPass = $true

# 5a. Full Test Harness must be inactive
$fth = Invoke-N8n GET "/workflows/$($WF.FullTestHarness)"
if ($fth.active -eq $true) {
    Write-Host "  FAIL: Full Test Harness is ACTIVE — must be inactive!"
    $allPass = $false
} else {
    Write-Host "  OK: Full Test Harness inactive"
}

if (-not $WhatIf) {
    # 5b. Six production workflows must be active
    foreach ($name in $productionNames) {
        $wfCheck = Invoke-N8n GET "/workflows/$($WF[$name])"
        if ($wfCheck.active -ne $true) {
            Write-Host "  FAIL: $name is not active"
            $allPass = $false
        } else {
            Write-Host "  OK: $name active"
        }
    }

    # 5c. Verify resolveTokens is present in Sender Node B
    $senderCheck = Invoke-N8n GET "/workflows/$($WF.Sender)"
    $nodeBCheck = $senderCheck.nodes | Where-Object { $_.name -eq "B. Re-run Send & Suppression Gates" }
    if ($nodeBCheck.parameters.jsCode -notlike "*resolveTokens*") {
        Write-Host "  FAIL: resolveTokens not found in Sender Node B jsCode"
        $allPass = $false
    } else {
        Write-Host "  OK: resolveTokens present in Sender Node B"
    }

    # 5d. Verify <<senderName>> and <<firstName>> resolution branches present
    if ($nodeBCheck.parameters.jsCode -like "*sc.senderName*" -and
        $nodeBCheck.parameters.jsCode -like "*nes.lead_first_name*") {
        Write-Host "  OK: senderName and firstName resolution branches confirmed"
    } else {
        Write-Host "  FAIL: resolution branches incomplete in patched code"
        $allPass = $false
    }
}

Write-Host ""
if ($allPass) {
    if ($WhatIf) {
        Write-Host "WHATIF_COMPLETE — no changes made. Run with -Apply to execute."
    } else {
        Write-Host "PATCH_APPLIED_AND_VERIFIED"
        Write-Host ""
        Write-Host "KNOWN LIMITATION: <<firstName>> resolves to empty string when nes.lead_first_name"
        Write-Host "is absent (not in Instantly webhook payload). T6 template text 'Understood, .'"
        Write-Host "will be cleaned to 'Understood.' by the orphaned-punctuation cleaner."
        Write-Host "Permanent fix: add lead first name to NES pipeline or revise T6 template."
    }
} else {
    Write-Host "VERIFICATION FAILED — review errors above before live testing."
    exit 1
}
