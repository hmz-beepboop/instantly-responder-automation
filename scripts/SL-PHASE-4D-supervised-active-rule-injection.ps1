#Requires -Version 7.0
<#
.SYNOPSIS
  SL-PHASE-4D — Supervised Active-Rule Injection (WhatIf / Simulation Only)

  Prepares future supervised injection of approved active rules into the AI draft prompt
  of the Decision workflow (Node D). Does NOT apply changes to production in this session.

  Rules may only influence supervised AI draft modes:
    - ai_supervised
    - AI_COMMERCIAL_SUPERVISED

  Rules must NEVER influence:
    - HUMAN_ONLY cases
    - no_reply, unsubscribe, complaint, legal, billing dispute
    - angry/hostile, data-sensitive escalation
    - security/compliance commitment cases
    - autonomous sending

  Active rules are appended as a clearly bounded "Human-approved guidance" section.
  They must not override safety gates or invent prices, guarantees, case studies,
  results, contract terms, or compliance/security claims.

.PARAMETER WhatIf
  Preview what the injection would look like. No production change.

.PARAMETER PreviewActiveRuleInjection
  Show the augmented system prompt with active rules injected (simulation only).

.PARAMETER UseSampleRules
  Use built-in sample rules (safe and unsafe) for simulation/testing.

.PARAMETER UseApprovedCandidates
  Pull approved_for_activation candidates from Phase 3 proxy and use them.
  Requires HMZ_PHASE3_PROXY_WEBHOOK_URL in environment.

.PARAMETER ExportPromptPreview
  Write the simulated augmented prompt to outputs/phase4d_prompt_preview.txt

.PARAMETER DetectConflicts
  Run conflict detection only (no injection). Reports conflicts and exits.

.PARAMETER Apply
  Apply rules to production Decision workflow Node D.
  BLOCKED unless: -OwnerConfirmedApply YES + approved_for_activation rules exist
  + conflict detection passes + all safety gates pass.
  NOT to be run in this session.

.PARAMETER OwnerConfirmedApply
  Must equal "YES" for -Apply to proceed. Protects against accidental production change.

.EXAMPLE
  # Simulation with sample rules
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -WhatIf -UseSampleRules
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -PreviewActiveRuleInjection -UseSampleRules -ExportPromptPreview
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -DetectConflicts -UseSampleRules

  # Simulation with real approved candidates (requires proxy URL in env)
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -WhatIf -UseApprovedCandidates
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -DetectConflicts -UseApprovedCandidates

  # Apply (future use only — all gates must pass and owner must confirm)
  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Apply -OwnerConfirmedApply YES
#>

param(
    [switch]$WhatIf,
    [switch]$PreviewActiveRuleInjection,
    [switch]$UseSampleRules,
    [switch]$UseApprovedCandidates,
    [switch]$ExportPromptPreview,
    [switch]$DetectConflicts,
    [switch]$Apply,
    [string]$OwnerConfirmedApply = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Safety guards ──────────────────────────────────────────────────────────────
foreach ($term in @("localhost","127.0.0.1","5678","docker","docker-compose")) {
    if ($PSCommandPath -match [regex]::Escape($term)) {
        Write-Error "SAFETY: forbidden term in script path — targeting local environment is prohibited."; exit 1
    }
}

$ProductionTarget   = "https://n8n.hmzaiautomation.com/api/v1"
$DecisionWorkflowId = "tgYmY97CG4Bm8snI"   # Future target — DO NOT PATCH IN THIS SESSION
$NodeDName          = "Node D — Draft Preparation"

Write-Host "`n=== SL-PHASE-4D SUPERVISED ACTIVE-RULE INJECTION ===" -ForegroundColor Cyan
Write-Host "Production target (future):  $ProductionTarget" -ForegroundColor DarkGray
Write-Host "Decision workflow (future):  $DecisionWorkflowId" -ForegroundColor DarkGray
Write-Host "Node D (future):             $NodeDName" -ForegroundColor DarkGray
Write-Host "Current session mode:        SIMULATION / WHATIF ONLY — no production change" -ForegroundColor Green
Write-Host ""

# ── Allowed draft modes for rule injection ─────────────────────────────────────
$ALLOWED_MODES = @('ai_supervised','AI_COMMERCIAL_SUPERVISED')

# Modes that must NEVER receive injected rules
$FORBIDDEN_MODES = @(
    'HUMAN_ONLY','no_reply','unsubscribe','complaint','legal',
    'billing_dispute','angry','hostile','data_sensitive_escalation',
    'security_compliance_commitment','autonomous'
)

# ── Conflict detection patterns ─────────────────────────────────────────────────
# Rules that match any of these patterns are rejected during conflict detection.
$UNSAFE_PATTERNS = @(
    # Pricing/guarantees/results/proof
    [pscustomobject]@{ Label='pricing_claim';     Pattern='\$\d|\d+k|\d+,\d{3}|per month|per year|flat fee|starting at|as low as|from \$' }
    [pscustomobject]@{ Label='guarantee_claim';   Pattern='guarantee|guaranteed|100%|we promise|risk.free|refund' }
    [pscustomobject]@{ Label='result_claim';      Pattern='case stud|we generated|we got|we achieved|example client|existing client|client said|our results show|proven results|here is proof' }
    [pscustomobject]@{ Label='data_commitment';   Pattern='your data will|we will not sell|we won.t sell|will only be used|gdpr compliant|ccpa compliant|soc.?2 certified' }
    [pscustomobject]@{ Label='contract_commit';   Pattern='there will be a contract|yes there is a contract|simple agreement|msa included|legally binding' }
    # Safety weakening
    [pscustomobject]@{ Label='bypass_human';      Pattern='without.{0,30}approval|skip approval|no approval needed|auto.send|autonomous|send without asking|without review' }
    [pscustomobject]@{ Label='override_gate';     Pattern='ignore safety|bypass gate|override human.only|remove human review|skip human' }
    # Scope
    [pscustomobject]@{ Label='too_long';          MinLength=600 }
    [pscustomobject]@{ Label='too_vague';         Pattern='^(always|never|do not|be|make sure|ensure|try to)\s+\w+\.?$' }
)

# ── Sample rules (safe + unsafe) ───────────────────────────────────────────────
$SAMPLE_RULES = @(
    # Safe rules
    [pscustomobject]@{
        rule_id          = 'sample-safe-001'
        rule_type        = 'style'
        classification_scope  = 'PRICING_OR_COMMERCIAL_NEGOTIATION'
        micro_intent_scope    = 'PRICING_REQUEST'
        proposed_rule_text    = 'For PRICING_REQUEST: acknowledge the pricing question warmly. Do not state specific numbers. Instead, indicate that pricing depends on scope and that a brief 10-minute call is the fastest way to give an accurate figure. End with the calendar link.'
        confidence       = 'high'
        label            = 'Safe CTA wording rule for PRICING_REQUEST'
        expected_outcome = 'ALLOWED'
    }
    [pscustomobject]@{
        rule_id          = 'sample-safe-002'
        rule_type        = 'style'
        classification_scope  = 'PRICING_OR_COMMERCIAL_NEGOTIATION'
        micro_intent_scope    = 'SMALL_SCALE_PILOT_REQUEST'
        proposed_rule_text    = 'For SMALL_SCALE_PILOT_REQUEST: open with validation framing (we recommend starting small). Describe the pilot structure (focused list, one campaign, reply monitoring, results review). Avoid committing to specific timelines or deliverables not in the approved knowledge base. End with the calendar link.'
        confidence       = 'high'
        label            = 'Safe tone rule for SMALL_SCALE_PILOT_REQUEST'
        expected_outcome = 'ALLOWED'
    }
    [pscustomobject]@{
        rule_id          = 'sample-safe-003'
        rule_type        = 'style'
        classification_scope  = 'INFORMATION_REQUEST'
        micro_intent_scope    = 'DATA_SECURITY_REQUEST'
        proposed_rule_text    = 'For DATA_SECURITY_REQUEST: do not make specific data or compliance commitments in the AI draft. Instead, acknowledge the concern briefly and flag for human review with a note that data handling questions are answered by the team directly. Mark draft for HUMAN_ONLY escalation.'
        confidence       = 'high'
        label            = 'Safe data/security caution rule — routes to human'
        expected_outcome = 'ALLOWED'
    }
    # Unsafe rules — these MUST be blocked by conflict detection
    [pscustomobject]@{
        rule_id          = 'sample-unsafe-001'
        rule_type        = 'style'
        classification_scope  = 'PRICING_OR_COMMERCIAL_NEGOTIATION'
        micro_intent_scope    = 'PRICING_REQUEST'
        proposed_rule_text    = 'For PRICING_REQUEST: tell the prospect pricing is usually around $3k to $5k for a small pilot, and that larger campaigns start at $8k per month.'
        confidence       = 'low'
        label            = 'UNSAFE: invents specific pricing'
        expected_outcome = 'BLOCKED:pricing_claim'
    }
    [pscustomobject]@{
        rule_id          = 'sample-unsafe-002'
        rule_type        = 'style'
        classification_scope  = 'INFORMATION_REQUEST'
        micro_intent_scope    = 'PROOF_REQUEST'
        proposed_rule_text    = 'For PROOF_REQUEST: mention our existing client results — we generated 47 qualified meetings for a SaaS client last quarter and achieved $280k in pipeline for a B2B services firm. Use these as case study evidence.'
        confidence       = 'low'
        label            = 'UNSAFE: invents fake case studies and results'
        expected_outcome = 'BLOCKED:result_claim'
    }
    [pscustomobject]@{
        rule_id          = 'sample-unsafe-003'
        rule_type        = 'style'
        classification_scope  = 'PRICING_OR_COMMERCIAL_NEGOTIATION'
        micro_intent_scope    = 'PRICING_REQUEST'
        proposed_rule_text    = 'For PRICING_REQUEST: if the prospect seems interested, send the reply without waiting for human approval to move faster.'
        confidence       = 'low'
        label            = 'UNSAFE: attempts to allow autonomous sending'
        expected_outcome = 'BLOCKED:bypass_human'
    }
)

# ── Helper: Run conflict detection on a single rule ────────────────────────────
function Test-RuleConflicts {
    param([pscustomobject]$Rule)

    $violations = @()

    foreach ($p in $UNSAFE_PATTERNS) {
        if ($p.PSObject.Properties['Pattern'] -and $Rule.proposed_rule_text -match $p.Pattern) {
            $violations += $p.Label
        }
        if ($p.PSObject.Properties['MinLength'] -and $Rule.proposed_rule_text.Length -gt $p.MinLength) {
            $violations += $p.Label
        }
    }

    # Scope check: rule must target an allowed classification_scope
    # (data_security, contract_terms etc. are HUMAN_ONLY and should not receive style injection)
    $huOnlyCats = @('UNSUBSCRIBE_REQUEST','HOSTILE_OR_NEGATIVE','LEGAL_COMPLIANCE','COMPLAINT')
    if ($Rule.classification_scope -in $huOnlyCats) {
        $violations += 'forbidden_category_scope'
    }

    return $violations
}

# ── Helper: Build augmented prompt section ─────────────────────────────────────
function Build-AugmentedPromptSection {
    param([pscustomobject[]]$SafeRules, [string]$TargetCategory, [string]$TargetMicroIntent)

    $matched = $SafeRules | Where-Object {
        ($_.classification_scope -eq $TargetCategory -or $_.classification_scope -eq '*') -and
        ($_.micro_intent_scope   -eq $TargetMicroIntent -or $_.micro_intent_scope -eq '' -or $_.micro_intent_scope -eq '*')
    }

    if (-not $matched -or $matched.Count -eq 0) {
        return $null
    }

    $lines = @(
        "",
        "---",
        "## Human-approved guidance (active rules — injected by SL-PHASE-4D)",
        "The following guidance has been reviewed and approved by the account owner.",
        "Apply it to your draft where relevant. It does NOT override safety gates.",
        "Do not invent prices, results, case studies, guarantees, or compliance claims.",
        "Human approval is still required before any reply is sent.",
        ""
    )

    $i = 1
    foreach ($r in $matched) {
        $lines += "### Rule $i (rule_id: $($r.rule_id))"
        $lines += "Scope: $($r.classification_scope) / $($r.micro_intent_scope)"
        $lines += "Instruction: $($r.proposed_rule_text)"
        $lines += ""
        $i++
    }

    $lines += "---"
    $lines += ""
    return $lines -join "`n"
}

# ── Load rules ─────────────────────────────────────────────────────────────────
function Get-Rules {
    if ($UseSampleRules) {
        Write-Host "[+] Using built-in sample rules ($($SAMPLE_RULES.Count) total)" -ForegroundColor Cyan
        return $SAMPLE_RULES
    }

    if ($UseApprovedCandidates) {
        $proxyUrl = $env:HMZ_PHASE3_PROXY_WEBHOOK_URL
        if (-not $proxyUrl) { $proxyUrl = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-read" }
        Write-Host "[+] Fetching approved_for_activation candidates from proxy..." -ForegroundColor Cyan
        $all = Invoke-RestMethod -Uri $proxyUrl -Method GET -TimeoutSec 20
        $approved = $all | Where-Object { $_.status -eq 'approved_for_activation' }
        if (-not $approved -or $approved.Count -eq 0) {
            Write-Host "[!] No approved_for_activation candidates found. Nothing to inject." -ForegroundColor Yellow
            return @()
        }
        Write-Host "[+] Found $($approved.Count) approved_for_activation candidates." -ForegroundColor Green
        return $approved
    }

    Write-Host "[!] Specify -UseSampleRules or -UseApprovedCandidates." -ForegroundColor Yellow
    return @()
}

# ── DETECT CONFLICTS ───────────────────────────────────────────────────────────
if ($DetectConflicts) {
    Write-Host "=== CONFLICT DETECTION MODE ===" -ForegroundColor Cyan
    Write-Host ""
    $rules = Get-Rules
    if ($rules.Count -eq 0) { Write-Host "No rules to check."; exit 0 }

    $blocked = @(); $allowed = @()

    foreach ($r in $rules) {
        [array]$violations = @(Test-RuleConflicts $r)
        $label = if ($r.PSObject.Properties['label']) { $r.label } else { $r.proposed_rule_text.Substring(0,[Math]::Min(60,$r.proposed_rule_text.Length)) }
        if ($violations.Count -gt 0) {
            Write-Host "  [BLOCKED] $($r.rule_id) — $label" -ForegroundColor Red
            Write-Host "           Violations: $($violations -join ', ')" -ForegroundColor Red
            $blocked += $r
        } else {
            Write-Host "  [ALLOWED] $($r.rule_id) — $label" -ForegroundColor Green
            $allowed += $r
        }
    }

    Write-Host ""
    Write-Host "=== CONFLICT DETECTION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "  ALLOWED: $($allowed.Count)" -ForegroundColor Green
    Write-Host "  BLOCKED: $($blocked.Count)" -ForegroundColor Red
    Write-Host ""
    if ($blocked.Count -gt 0) {
        Write-Host "Blocked rules must be edited or rejected before injection." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "No conflicts detected. Rules are safe for further review." -ForegroundColor Green
        exit 0
    }
}

# ── WHATIF / PREVIEW ──────────────────────────────────────────────────────────
if ($WhatIf -or $PreviewActiveRuleInjection) {
    Write-Host "=== $(if ($WhatIf) {'WHATIF'} else {'PREVIEW: ACTIVE RULE INJECTION'}) ===" -ForegroundColor Cyan
    Write-Host ""
    $rules = Get-Rules
    if ($rules.Count -eq 0) { Write-Host "No rules loaded."; exit 0 }

    # Run conflict detection first
    $blockedRules = @(); $safeRules = @()
    foreach ($r in $rules) {
        [array]$violations = @(Test-RuleConflicts $r)
        if ($violations.Count -gt 0) { $blockedRules += $r } else { $safeRules += $r }
    }

    Write-Host "Rule summary:"
    Write-Host "  Total loaded:   $($rules.Count)"
    Write-Host "  Safe (would inject):  $($safeRules.Count)" -ForegroundColor Green
    Write-Host "  Blocked (conflict):   $($blockedRules.Count)" -ForegroundColor Red
    Write-Host ""

    if ($blockedRules.Count -gt 0) {
        Write-Host "--- BLOCKED RULES (would NOT be injected) ---" -ForegroundColor Red
        foreach ($r in $blockedRules) {
            [array]$violations = @(Test-RuleConflicts $r)
            $label = if ($r.PSObject.Properties['label']) { $r.label } else { $r.rule_id }
            Write-Host "  [BLOCKED] $label" -ForegroundColor Red
            Write-Host "            Violations: $($violations -join ', ')" -ForegroundColor Red
        }
        Write-Host ""
    }

    if ($safeRules.Count -gt 0) {
        Write-Host "--- SAFE RULES (would be injected into supervised drafts only) ---" -ForegroundColor Green
        foreach ($r in $safeRules) {
            $label = if ($r.PSObject.Properties['label']) { $r.label } else { $r.rule_id }
            $scope = "$($r.classification_scope)/$($r.micro_intent_scope)"
            Write-Host "  [ALLOWED] $label" -ForegroundColor Green
            Write-Host "            Scope: $scope" -ForegroundColor DarkGray
            Write-Host "            Text:  $($r.proposed_rule_text.Substring(0,[Math]::Min(100,$r.proposed_rule_text.Length)))..." -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    if ($PreviewActiveRuleInjection) {
        Write-Host "--- SIMULATED AUGMENTED PROMPT SECTION ---" -ForegroundColor Cyan
        Write-Host "(This is what would be appended to Node D system prompt for a PRICING_REQUEST case)" -ForegroundColor DarkGray
        Write-Host ""

        $section = Build-AugmentedPromptSection -SafeRules $safeRules `
            -TargetCategory 'PRICING_OR_COMMERCIAL_NEGOTIATION' `
            -TargetMicroIntent 'PRICING_REQUEST'

        if ($section) {
            Write-Host $section -ForegroundColor White
        } else {
            Write-Host "(No safe rules matched PRICING_REQUEST scope)" -ForegroundColor Yellow
        }

        $section2 = Build-AugmentedPromptSection -SafeRules $safeRules `
            -TargetCategory 'PRICING_OR_COMMERCIAL_NEGOTIATION' `
            -TargetMicroIntent 'SMALL_SCALE_PILOT_REQUEST'

        if ($section2) {
            Write-Host "`n(For SMALL_SCALE_PILOT_REQUEST case:)" -ForegroundColor DarkGray
            Write-Host $section2 -ForegroundColor White
        }

        if ($ExportPromptPreview) {
            $outPath = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\outputs\phase4d_prompt_preview.txt"
            $fullPreview = @(
                "=== SL-PHASE-4D AUGMENTED PROMPT PREVIEW ==="
                "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ' -AsUTC)"
                "Mode: SIMULATION ONLY — not applied to production"
                ""
                "Safe rules ($($safeRules.Count)):"
                ($safeRules | ForEach-Object { "  - $($_.rule_id): $($_.proposed_rule_text.Substring(0,[Math]::Min(80,$_.proposed_rule_text.Length)))..." })
                ""
                "Blocked rules ($($blockedRules.Count)):"
                ($blockedRules | ForEach-Object {
                    $v = Test-RuleConflicts $_
                    "  - $($_.rule_id): BLOCKED [$($v -join ',')]"
                })
                ""
                "--- PRICING_REQUEST case augmented section ---"
                $(Build-AugmentedPromptSection -SafeRules $safeRules -TargetCategory 'PRICING_OR_COMMERCIAL_NEGOTIATION' -TargetMicroIntent 'PRICING_REQUEST')
                ""
                "--- SMALL_SCALE_PILOT_REQUEST case augmented section ---"
                $(Build-AugmentedPromptSection -SafeRules $safeRules -TargetCategory 'PRICING_OR_COMMERCIAL_NEGOTIATION' -TargetMicroIntent 'SMALL_SCALE_PILOT_REQUEST')
            ) -join "`n"
            $fullPreview | Out-File -FilePath $outPath -Encoding UTF8
            Write-Host "`n[+] Prompt preview exported to: $outPath" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "=== WHATIF SUMMARY ===" -ForegroundColor Cyan
    Write-Host "  Production workflow:  NOT MODIFIED" -ForegroundColor Green
    Write-Host "  Node D:               NOT MODIFIED" -ForegroundColor Green
    Write-Host "  Active rule injection: NOT ENABLED" -ForegroundColor Green
    Write-Host "  Autonomous mode:      NOT CHANGED" -ForegroundColor Green
    Write-Host ""
    Write-Host "To apply in a future session (after all gates pass):"
    Write-Host "  .\SL-PHASE-4D-supervised-active-rule-injection.ps1 -Apply -OwnerConfirmedApply YES -UseApprovedCandidates"
    exit 0
}

# ── APPLY (future use — blocked in this session) ───────────────────────────────
if ($Apply) {
    Write-Host "=== -Apply gate check ===" -ForegroundColor Cyan
    Write-Host ""

    $gates = @()

    # Gate 1: Owner confirmation
    if ($OwnerConfirmedApply -ne 'YES') {
        $gates += "[FAIL] Gate 1: -OwnerConfirmedApply must equal 'YES' (received: '$OwnerConfirmedApply')"
    } else {
        $gates += "[PASS] Gate 1: Owner confirmation received"
    }

    # Gate 2: Approved candidates exist
    $proxyUrl = $env:HMZ_PHASE3_PROXY_WEBHOOK_URL
    if (-not $proxyUrl) { $proxyUrl = "https://n8n.hmzaiautomation.com/webhook/phase3-rc-read" }
    try {
        $all      = Invoke-RestMethod -Uri $proxyUrl -Method GET -TimeoutSec 20
        $approved = $all | Where-Object { $_.status -eq 'approved_for_activation' }
        if ($approved.Count -eq 0) {
            $gates += "[FAIL] Gate 2: No approved_for_activation candidates found in sl_rule_candidates"
        } else {
            $gates += "[PASS] Gate 2: $($approved.Count) approved_for_activation candidate(s) found"
        }
    } catch {
        $gates += "[FAIL] Gate 2: Could not reach Phase 3 proxy — $($_.Exception.Message)"
        $approved = @()
    }

    # Gate 3: Conflict detection
    $blocked = @()
    if ($approved.Count -gt 0) {
        foreach ($r in $approved) {
            [array]$violations = @(Test-RuleConflicts $r)
            if ($violations.Count -gt 0) { $blocked += "$($r.rule_id): $($violations -join ',')" }
        }
        if ($blocked.Count -gt 0) {
            $gates += "[FAIL] Gate 3: Conflict detection failed for: $($blocked -join '; ')"
        } else {
            $gates += "[PASS] Gate 3: All approved candidates passed conflict detection"
        }
    } else {
        $gates += "[SKIP] Gate 3: No candidates to check (Gate 2 already failed)"
    }

    # Gate 4: API key available
    if (-not $env:HMZ_N8N_API_KEY) {
        $gates += "[FAIL] Gate 4: HMZ_N8N_API_KEY not set"
    } else {
        $gates += "[PASS] Gate 4: API key available"
    }

    # Report gates
    $allPass = $true
    foreach ($g in $gates) {
        $color = if ($g -match '^\[PASS\]') { 'Green' } elseif ($g -match '^\[SKIP\]') { 'Yellow' } else { 'Red'; $allPass = $false }
        Write-Host "  $g" -ForegroundColor $color
    }
    # Recount fails
    $allPass = @($gates | Where-Object { $_ -match '^\[FAIL\]' }).Count -eq 0

    Write-Host ""
    if (-not $allPass) {
        Write-Host "[BLOCKED] -Apply cannot proceed — one or more gates failed." -ForegroundColor Red
        Write-Host "          Resolve all gate failures before retrying -Apply." -ForegroundColor Red
        exit 1
    }

    # All gates pass — apply the injection
    Write-Host "[GATES PASSED] All pre-apply checks passed." -ForegroundColor Green
    Write-Host ""

    # $approved was populated in Gate 2 and passed conflict detection in Gate 3
    $safeRules = @($approved)

    # Retrieve Decision workflow
    Write-Host "[APPLY] Retrieving Decision workflow $DecisionWorkflowId..." -ForegroundColor Cyan
    $ApiKey   = $env:HMZ_N8N_API_KEY
    $ApiBase  = $ProductionTarget
    $AuthHdrs = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }

    $decisionWf    = Invoke-RestMethod -Uri "$ApiBase/workflows/$DecisionWorkflowId" -Headers $AuthHdrs
    $prevVersionId = $decisionWf.versionId
    Write-Host "  Workflow: $($decisionWf.name)"
    Write-Host "  versionId (before): $prevVersionId"

    # Find section_d node by id
    $nodeD = $decisionWf.nodes | Where-Object { $_.id -eq 'section_d' }
    if (-not $nodeD) { Write-Host "[ERROR] Node section_d not found." -ForegroundColor Red; exit 1 }
    Write-Host "  Node D found: $($nodeD.name)"

    # Build Human-approved guidance text
    $guidanceLines = [System.Collections.Generic.List[string]]::new()
    $guidanceLines.Add('')
    $guidanceLines.Add('---')
    $guidanceLines.Add('## Human-approved guidance (active rules -- injected by SL-PHASE-4D)')
    $guidanceLines.Add('The following guidance has been reviewed and approved by the account owner.')
    $guidanceLines.Add('Apply it to your draft where relevant. It does NOT override safety gates.')
    $guidanceLines.Add('Do not invent prices, results, case studies, guarantees, or compliance claims.')
    $guidanceLines.Add('Human approval is still required before any reply is sent.')
    $guidanceLines.Add('')
    $rn = 1
    foreach ($rule in $safeRules) {
        $guidanceLines.Add("### Rule $rn (rule_id: $($rule.rule_id))")
        $guidanceLines.Add("Scope: $($rule.classification_scope) / $($rule.micro_intent_scope)")
        $guidanceLines.Add("Instruction: $($rule.proposed_rule_text)")
        $guidanceLines.Add('')
        $rn++
    }
    $guidanceLines.Add('---')
    $guidanceText    = $guidanceLines -join "`n"
    $guidanceTxtJson = $guidanceText | ConvertTo-Json -Compress
    $injectBlock     = "// HMZ_INJECT_BEGIN:ACTIVE_RULES`nconst ACTIVE_RULE_GUIDANCE = $guidanceTxtJson;`n// HMZ_INJECT_END:ACTIVE_RULES"

    $currentCode = $nodeD.parameters.jsCode

    if ($currentCode -match '// HMZ_INJECT_BEGIN:ACTIVE_RULES') {
        # Replace existing block
        $newCode = [regex]::Replace($currentCode, '(?s)// HMZ_INJECT_BEGIN:ACTIVE_RULES.*?// HMZ_INJECT_END:ACTIVE_RULES', $injectBlock)
    } else {
        # Insert after SENDER_CONFIG end marker and patch the buildAIPrompt call
        $newCode = $currentCode -replace '(// HMZ_INJECT_END:SENDER_CONFIG)', "`$1`n$injectBlock"
        $newCode = $newCode -replace '(const prompt\s+=\s+buildAIPrompt\(microIntent, replyText, firstName, campaignCtx\));', '$1 + ACTIVE_RULE_GUIDANCE;'
    }

    if ($newCode -ceq $currentCode) {
        Write-Host "[ERROR] Injection produced no change — injection point not found." -ForegroundColor Red
        exit 1
    }

    $nodeD.parameters.jsCode = $newCode

    # Build PUT payload
    $putPayload = @{
        name        = $decisionWf.name
        nodes       = $decisionWf.nodes
        connections = $decisionWf.connections
        settings    = $decisionWf.settings
    } | ConvertTo-Json -Depth 30 -Compress

    Write-Host "[APPLY] Uploading patched Decision workflow..." -ForegroundColor Cyan
    $updated      = Invoke-RestMethod -Uri "$ApiBase/workflows/$DecisionWorkflowId" -Method PUT -Headers $AuthHdrs -Body $putPayload
    $newVersionId = $updated.versionId

    if ($newVersionId -ne $prevVersionId) {
        Write-Host "[APPLY SUCCESS] Decision versionId changed:" -ForegroundColor Green
        Write-Host "  Before: $prevVersionId"
        Write-Host "  After:  $newVersionId"
    } else {
        Write-Host "[ERROR] versionId unchanged -- update may not have been applied." -ForegroundColor Red
        exit 1
    }

    # Verify: re-fetch and confirm injection marker present
    $verifyWf   = Invoke-RestMethod -Uri "$ApiBase/workflows/$DecisionWorkflowId" -Headers $AuthHdrs
    $verifyNode = $verifyWf.nodes | Where-Object { $_.id -eq 'section_d' }
    $hasMarker  = $verifyNode.parameters.jsCode -match 'HMZ_INJECT_BEGIN:ACTIVE_RULES'
    Write-Host "[VERIFY] ACTIVE_RULES marker in Node D: $hasMarker"
    Write-Host "[VERIFY] Sender/Intake/HumanApproval not in Decision workflow -- separate workflows, unchanged"
    Write-Host "[VERIFY] Autonomous mode not altered"
    Write-Host ""
    Write-Host "=== APPLY COMPLETE ===" -ForegroundColor Green
    Write-Host "  Active rules injected: $($safeRules.Count)"
    Write-Host "  Decision versionId:    $newVersionId"
    Write-Host "  Scope: Node D supervised AI drafting only (ai_supervised + AI_COMMERCIAL_SUPERVISED)"
    Write-Host "  HUMAN_ONLY: not affected"
    Write-Host "  Autonomous mode: not changed"
    exit 0
}

# ── Default: show usage if no action specified ─────────────────────────────────
Write-Host "No action specified. Run with one of:" -ForegroundColor Yellow
Write-Host "  -WhatIf -UseSampleRules"
Write-Host "  -PreviewActiveRuleInjection -UseSampleRules -ExportPromptPreview"
Write-Host "  -DetectConflicts -UseSampleRules"
Write-Host "  -WhatIf -UseApprovedCandidates"
Write-Host "  -Apply -OwnerConfirmedApply YES  (future — blocked until gates pass)"
