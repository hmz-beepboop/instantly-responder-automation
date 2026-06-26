#Requires -Version 7.0
# SL-PHASE-4C-active-rule-governance-scaffold.ps1
#
# Governance scaffold for future active rule injection.
# Works offline or against sl_rule_candidates (read-only) when proxy is set up.
#
# IMPORTANT: This script does NOT inject rules into any workflow. It only reads
# approved_for_activation candidates, detects conflicts, and exports a local
# preview file. No production writes. No AI prompt changes.
#
# Usage:
#   -ListApprovedForActivation    List candidates with status=approved_for_activation
#   -PreviewActiveRules           Show what rules would look like if activated
#   -DetectRuleConflicts          Check for conflicts in approved candidates
#   -ExportProposedActiveRulesJson Export preview to outputs/proposed_active_rules_preview.json
#   -WhatIf                       Confirm no production writes will occur (safety check)

[CmdletBinding()]
param(
    [switch]$ListApprovedForActivation,
    [switch]$PreviewActiveRules,
    [switch]$DetectRuleConflicts,
    [switch]$ExportProposedActiveRulesJson,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProxyReadUrl = $env:HMZ_PHASE3_PROXY_WEBHOOK_URL
$OutputDir    = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\outputs"
$OutputFile   = Join-Path $OutputDir "proposed_active_rules_preview.json"

# ── Safety banner ─────────────────────────────────────────────────────────────
Write-Host "`n=== SL-PHASE-4C Active Rule Governance Scaffold ===" -ForegroundColor Cyan
Write-Host "Mode:   READ-ONLY scaffold (no production writes, no workflow modifications)" -ForegroundColor Green
Write-Host "Target: sl_rule_candidates DataTable (via proxy, read-only)" -ForegroundColor Gray
Write-Host ""
Write-Host "GOVERNANCE: approved_for_activation is a review status ONLY." -ForegroundColor Yellow
Write-Host "  It does NOT inject rules into Decision, alter AI, or enable autonomous sending." -ForegroundColor Yellow
Write-Host "  Active injection requires a separate future phase (Phase 4D)." -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) {
    Write-Host "=== -WhatIf confirmed: this script makes no production writes ===" -ForegroundColor Green
    Write-Host "  - No workflow modifications" -ForegroundColor Green
    Write-Host "  - No n8n credential changes" -ForegroundColor Green
    Write-Host "  - No AI prompt changes" -ForegroundColor Green
    Write-Host "  - No autonomous sending enabled" -ForegroundColor Green
    Write-Host "  - Only local file writes (outputs/) when -ExportProposedActiveRulesJson is used" -ForegroundColor Green
    Write-Host ""
    if (-not $ListApprovedForActivation -and -not $PreviewActiveRules -and
        -not $DetectRuleConflicts -and -not $ExportProposedActiveRulesJson) {
        Write-Host "Specify an action flag to proceed (-ListApprovedForActivation, -PreviewActiveRules, etc.)."
        exit 0
    }
}

# ── Helper: load candidates ───────────────────────────────────────────────────
function Get-ApprovedCandidates {
    if (-not $ProxyReadUrl) {
        Write-Host "[WARN] HMZ_PHASE3_PROXY_WEBHOOK_URL not set — using sample data." -ForegroundColor Yellow
        Write-Host "       Run: .\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -Setup" -ForegroundColor Gray
        Write-Host "       Then set: `$env:HMZ_PHASE3_PROXY_WEBHOOK_URL = '<url>'" -ForegroundColor Gray
        Write-Host ""
        # Return sample data for offline/local demonstration
        return @(
            [PSCustomObject]@{
                rule_id             = "SAMPLE-001"
                rule_type           = "classification"
                classification_scope = "INFORMATION_REQUEST"
                micro_intent_scope  = "PROOF_REQUEST"
                proposed_rule_text  = "[SAMPLE] Classify PROOF_REQUEST when prospect mentions 'case study', 'results', or 'proof'."
                confidence          = "high"
                status              = "approved_for_activation"
                approved_by         = "hamzah@example.com"
                approved_at         = "2026-06-23T10:00:00Z"
                source_case_id      = "case-SAMPLE"
            },
            [PSCustomObject]@{
                rule_id             = "SAMPLE-002"
                rule_type           = "style"
                classification_scope = "PRICING_OR_COMMERCIAL_NEGOTIATION"
                micro_intent_scope  = "PRICING_REQUEST"
                proposed_rule_text  = "[SAMPLE] Draft should acknowledge pricing interest and direct to calendar without quoting figures."
                confidence          = "medium"
                status              = "approved_for_activation"
                approved_by         = "hamzah@example.com"
                approved_at         = "2026-06-23T10:00:00Z"
                source_case_id      = "case-SAMPLE2"
            }
        )
    }
    Write-Host "Reading approved candidates from proxy..." -ForegroundColor Gray
    $all = Invoke-RestMethod -Uri $ProxyReadUrl -Method GET -TimeoutSec 15
    $approved = @($all | Where-Object { $_.status -eq 'approved_for_activation' })
    Write-Host "[OK] Total candidates: $($all.Count) | Approved for activation: $($approved.Count)" -ForegroundColor Green
    return $approved
}

# ── Conflict detection ────────────────────────────────────────────────────────
$UNSAFE_PATTERNS = @(
    @{ Pattern = 'autonomous'; Description = 'Suggests autonomous sending' },
    @{ Pattern = 'auto.send|auto_send|send automatically'; Description = 'Suggests auto-send' },
    @{ Pattern = 'guaranteed|guarantee|proven|proof|result'; Description = 'Invented claims/guarantees (forbidden)' },
    @{ Pattern = '\$[0-9]+|per month|per seat|pricing'; Description = 'Contains pricing figures (human-only)' },
    @{ Pattern = 'bypass|skip.*approval|without approval'; Description = 'Suggests bypassing human approval' },
    @{ Pattern = 'lower.*confidence|reduce.*threshold'; Description = 'Weakens confidence threshold' }
)

function Test-ConflictsInCandidates([array]$candidates) {
    [array]$conflicts = @()
    if (-not $candidates -or $candidates.Count -eq 0) { return $conflicts }

    # Check 1: Same scope, contradictory rule text
    $byScope = @{}
    foreach ($c in $candidates) {
        $key = "$($c.rule_type)|$($c.micro_intent_scope)"
        if (-not $byScope.ContainsKey($key)) { $byScope[$key] = @() }
        $byScope[$key] += $c
    }
    foreach ($key in $byScope.Keys) {
        if ($byScope[$key].Count -gt 1) {
            $conflicts += [PSCustomObject]@{
                Type        = "DUPLICATE_SCOPE"
                Severity    = "WARNING"
                Description = "Multiple approved rules for scope '$key'. Review for contradictions before activation."
                RuleIds     = ($byScope[$key] | ForEach-Object { $_.rule_id }) -join ', '
            }
        }
    }

    # Check 2: Unsafe wording patterns
    foreach ($c in $candidates) {
        foreach ($p in $UNSAFE_PATTERNS) {
            $text = "$($c.proposed_rule_text)"
            if ($text -match $p.Pattern) {
                $conflicts += [PSCustomObject]@{
                    Type        = "UNSAFE_WORDING"
                    Severity    = "BLOCK"
                    Description = "$($p.Description): found in rule $($c.rule_id)"
                    RuleIds     = $c.rule_id
                }
            }
        }
    }

    return $conflicts
}

# ── -ListApprovedForActivation ────────────────────────────────────────────────
if ($ListApprovedForActivation) {
    Write-Host "=== Candidates with status=approved_for_activation ===" -ForegroundColor Cyan
    [array]$approved = @(Get-ApprovedCandidates)
    if ($approved.Count -eq 0) {
        Write-Host "No candidates with status=approved_for_activation found." -ForegroundColor Yellow
        Write-Host "Use the Phase 3 console to review candidates." -ForegroundColor Gray
    } else {
    foreach ($c in $approved) {
        $text = if ($c.proposed_rule_text) { $c.proposed_rule_text.Substring(0, [Math]::Min(70, $c.proposed_rule_text.Length)) } else { "" }
        Write-Host "  [$($c.rule_id)] [$($c.rule_type)] [$($c.micro_intent_scope)] $text" -ForegroundColor White
        Write-Host "    approved_by=$($c.approved_by) at=$($c.approved_at)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Total approved: $($approved.Count)" -ForegroundColor Green
    Write-Host "REMINDER: approved_for_activation is INACTIVE until Phase 4D is implemented and owner-approved." -ForegroundColor Yellow
    }  # end else (approved.Count > 0)
}

# ── -PreviewActiveRules ───────────────────────────────────────────────────────
if ($PreviewActiveRules) {
    Write-Host "=== Preview: What Active Rules Would Look Like ===" -ForegroundColor Cyan
    Write-Host "(This is a READ-ONLY preview. No rules are injected.)" -ForegroundColor Green
    [array]$approved = @(Get-ApprovedCandidates)
    if ($approved.Count -eq 0) {
        Write-Host "No candidates with status=approved_for_activation." -ForegroundColor Yellow
    } else {
    $i = 1
    foreach ($c in $approved) {
        Write-Host ""
        Write-Host "Active Rule #$i — PREVIEW ONLY" -ForegroundColor Yellow
        Write-Host "  rule_id:        $($c.rule_id)"
        Write-Host "  type:           $($c.rule_type)"
        Write-Host "  scope:          $($c.classification_scope) / $($c.micro_intent_scope)"
        Write-Host "  rule_text:      $($c.proposed_rule_text)"
        Write-Host "  confidence:     $($c.confidence)"
        Write-Host "  approved_by:    $($c.approved_by)"
        Write-Host "  would_inject:   Into AI prompt context when micro_intent=$($c.micro_intent_scope)"
        Write-Host "  would_affect:   AI_COMMERCIAL_SUPERVISED and ai_supervised drafts only"
        Write-Host "  would_NOT_affect: routing, suppression, HUMAN_ONLY cases, autonomous mode"
        $i++
    }
    Write-Host ""
    Write-Host "Total that would be active: $($approved.Count)" -ForegroundColor Cyan
    Write-Host "REMINDER: None of these are active yet. Phase 4D required." -ForegroundColor Yellow
    }  # end else (approved.Count > 0)
}

# ── -DetectRuleConflicts ──────────────────────────────────────────────────────
if ($DetectRuleConflicts) {
    Write-Host "=== Conflict Detection ===" -ForegroundColor Cyan
    [array]$approved = @(Get-ApprovedCandidates)
    if ($approved.Count -eq 0) {
        Write-Host "No approved candidates to check." -ForegroundColor Yellow
    }
    [array]$conflicts = @(Test-ConflictsInCandidates $approved)
    if ($conflicts.Count -eq 0) {
        Write-Host "[OK] No conflicts detected in $($approved.Count) approved candidate(s)." -ForegroundColor Green
    } else {
        Write-Host "Conflicts found:" -ForegroundColor Yellow
        foreach ($cf in $conflicts) {
            $color = if ($cf.Severity -eq 'BLOCK') { 'Red' } else { 'Yellow' }
            Write-Host "  [$($cf.Severity)] $($cf.Type): $($cf.Description)" -ForegroundColor $color
            Write-Host "    Rule IDs: $($cf.RuleIds)" -ForegroundColor Gray
        }
        Write-Host ""
        $blockers = @($conflicts | Where-Object { $_.Severity -eq 'BLOCK' })
        $warnings = @($conflicts | Where-Object { $_.Severity -eq 'WARNING' })
        Write-Host "  BLOCK issues:   $($blockers.Count) (must resolve before any activation)" -ForegroundColor Red
        Write-Host "  WARNING issues: $($warnings.Count) (review before activation)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Conflict detection rules:" -ForegroundColor Gray
    $UNSAFE_PATTERNS | ForEach-Object { Write-Host "  - $($_.Description)" -ForegroundColor Gray }
}

# ── -ExportProposedActiveRulesJson ────────────────────────────────────────────
if ($ExportProposedActiveRulesJson) {
    Write-Host "=== Export Proposed Active Rules (local file only) ===" -ForegroundColor Cyan
    [array]$approved = @(Get-ApprovedCandidates)
    [array]$conflicts = @(Test-ConflictsInCandidates $approved)
    [array]$blockers  = @($conflicts | Where-Object { $_.Severity -eq 'BLOCK' })
    [array]$warnings  = @($conflicts | Where-Object { $_.Severity -eq 'WARNING' })

    $export = [ordered]@{
        generated_at        = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ' -AsUTC)
        status              = "PREVIEW_ONLY - NOT_ACTIVE"
        governance_note     = "approved_for_activation is inactive. Phase 4D required for injection. No autonomous mode."
        proposed_count      = $approved.Count
        conflict_blockers   = $blockers.Count
        conflict_warnings   = $warnings.Count
        activation_blocked  = ($blockers.Count -gt 0)
        proposed_rules      = @($approved | ForEach-Object {
            [ordered]@{
                rule_id              = $_.rule_id
                rule_type            = $_.rule_type
                classification_scope = $_.classification_scope
                micro_intent_scope   = $_.micro_intent_scope
                proposed_rule_text   = $_.proposed_rule_text
                confidence           = $_.confidence
                approved_by          = $_.approved_by
                approved_at          = $_.approved_at
                source_case_id       = $_.source_case_id
                injection_gate       = "AI_COMMERCIAL_SUPERVISED or ai_supervised drafts only — never HUMAN_ONLY, no_reply, or autonomous"
            }
        })
        conflicts           = @($conflicts | ForEach-Object {
            [ordered]@{ type=$_.Type; severity=$_.Severity; description=$_.Description; rule_ids=$_.RuleIds }
        })
    }

    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
    $export | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "[OK] Exported to: $OutputFile" -ForegroundColor Green
    Write-Host "  Proposed rules: $($approved.Count)" -ForegroundColor White
    Write-Host "  Blockers:       $($blockers.Count) | Warnings: $($warnings.Count)" -ForegroundColor $(if ($blockers.Count -gt 0) {'Red'} else {'Green'})
    Write-Host "  IMPORTANT: This file is a local preview only. No production changes." -ForegroundColor Yellow
}

if (-not $ListApprovedForActivation -and -not $PreviewActiveRules -and
    -not $DetectRuleConflicts -and -not $ExportProposedActiveRulesJson -and -not $WhatIf) {
    Write-Host "Specify an action:"
    Write-Host "  -ListApprovedForActivation"
    Write-Host "  -PreviewActiveRules"
    Write-Host "  -DetectRuleConflicts"
    Write-Host "  -ExportProposedActiveRulesJson"
    Write-Host "  -WhatIf  (confirm read-only safety)"
    exit 1
}
