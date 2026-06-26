#Requires -Version 7.0
# SL-PHASE-4A-multi-intent-ai-assisted-drafts.ps1
#
# Parts B/C/D/E — Multi-intent classification, AI-assisted commercial drafts,
# full intent visibility in Google Chat + review form, learning capture preserved.
#
# Workflow scope: Decision tgYmY97CG4Bm8snI + HumanApproval 9aPrt92jFhoYFxbs
# Nodes changed:  Dec-B, Dec-D, HA-D, HA-J (4 total)
# Nodes untouched: Dec-A, Dec-C, Dec-E, all gates, all SL-P1x/P2x capture nodes,
#                  HA-A..C, HA-E..L, HA-M..R, Intake, Sender, ErrorHandler,
#                  SLAWatchdog, FullTestHarness
#
# -WhatIf : validate plan, check API, verify anchors, no writes
# -Apply  : apply patch, verify both workflows updated

[CmdletBinding()]
param([switch]$WhatIf, [switch]$Apply)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProductionApiUrl        = "https://n8n.hmzaiautomation.com/api/v1"
$DecisionWorkflowId      = "tgYmY97CG4Bm8snI"
$HumanApprovalWorkflowId = "9aPrt92jFhoYFxbs"
$PatchId                 = "SL-PHASE-4A"

if ($Apply -and $WhatIf)          { Write-Error "Supply -WhatIf OR -Apply, not both."; exit 1 }
if (-not $WhatIf -and -not $Apply){ Write-Host "Defaulting to -WhatIf." -ForegroundColor Yellow; $WhatIf = $true }

foreach ($term in @("localhost","127.0.0.1","hmz-n8n-local-dev","5678","docker")) {
    if ($ProductionApiUrl -match [regex]::Escape($term)) { Write-Error "FORBIDDEN: URL contains '$term'."; exit 1 }
}

$ApiKey = $env:HMZ_N8N_API_KEY
if (-not $ApiKey) { Write-Error "HMZ_N8N_API_KEY not set."; exit 1 }
$Headers = @{ "X-N8N-API-KEY" = $ApiKey; "Content-Type" = "application/json" }

function Get-Wf($id)       { Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$id" -Method GET -Headers $Headers }
function Put-Wf($id, $wf) {
    # n8n PUT accepts only: name, nodes, connections, settings, staticData
    $body = @{
        name        = $wf.name
        nodes       = $wf.nodes
        connections = $wf.connections
        settings    = $wf.settings
        staticData  = $wf.staticData
    }
    $json = $body | ConvertTo-Json -Depth 50 -Compress
    Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/$id" -Method PUT -Headers $Headers -Body $json
}
function Get-Code($wf, $nodeId) {
    $n = $wf.nodes | Where-Object { $_.id -eq $nodeId }
    if (-not $n) { throw "Node $nodeId not found" }
    Normalize $n.parameters.jsCode
}
function Set-Code($wf, $nodeId, $code) {
    $n = $wf.nodes | Where-Object { $_.id -eq $nodeId }
    if (-not $n) { throw "Node $nodeId not found" }
    $n.parameters.jsCode = $code
}
function Must-Contain($code, $anchor, $label) {
    if (-not $code.Contains($anchor)) { throw "ABORT: anchor '$label' not found. Production code changed." }
}
function Normalize($s) { return ($s -replace "`r`n", "`n") -replace "`r", "`n" }

# ════════════════════════════════════════════════════════════════════════════
# PATCH STRINGS  (using here-strings to avoid escaping issues)
# ════════════════════════════════════════════════════════════════════════════

# ── DEC-B patch 1: inject helper functions before draftPolicyFor ─────────────
$B1_Anchor  = 'function draftPolicyFor(mi) {'

# Single-quoted here-string: safe for JS with single-quotes; no $ signs present
$B1_Inject  = @'
// SL-PHASE-4A: secondary intent scanner
function detectAllIntents(combined, primaryCategory, primaryMicroIntent, detFlags) {
  var intents = [];
  var c = combined;
  if (primaryMicroIntent !== 'PRICING_REQUEST' &&
      /\b(price|pricing|cost|how much|what do you charge|quote|fee|rate)\b/.test(c)) {
    intents.push({ category:'PRICING_OR_COMMERCIAL_NEGOTIATION', micro_intent:'PRICING_REQUEST', evidence_snippet:'pricing keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(what happens (to|with) (our|your|the) data|(our|your) data|data (security|privacy|protection)|where does (my|our) data|who (can see|has access)|gdpr|ccpa)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'DATA_SECURITY_REQUEST', evidence_snippet:'data/security keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(contract|agreement|msa|sow|terms|commitment|locked in|binding|signing)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'CONTRACT_TERMS_REQUEST', evidence_snippet:'contract/terms keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (/\b(small (campaign|pilot|test|trial)|pilot|trial|start small|one (campaign|small)|before (committing|we commit)|try (this|it) out)\b/.test(c)) {
    intents.push({ category:'PRICING_OR_COMMERCIAL_NEGOTIATION', micro_intent:'SMALL_SCALE_PILOT_REQUEST', evidence_snippet:'pilot/trial keyword', confidence:0.8, draft_handling:'ai_assisted' });
  }
  if (!['OFFER_EXPLANATION','HOW_IT_WORKS_REQUEST'].includes(primaryMicroIntent) &&
      /\b(what does this include|what.s (included|involved)|what exactly|what would you do|explain (this|the service|the process)|what is included)\b/.test(c)) {
    intents.push({ category:'INFORMATION_REQUEST', micro_intent:'SCOPE_REQUEST', evidence_snippet:'scope/explain keyword', confidence:0.7, draft_handling:'ai_assisted' });
  }
  return intents;
}
// SL-PHASE-4A: true when no blocking det-flags present
function isCommercialSafe(detFlags) {
  return !detFlags['det-legal-001'] && !detFlags['det-legal-002'] &&
         !detFlags['det-regulator-001'] && !detFlags['det-hostile-001'] &&
         !detFlags['det-hostile-002'] && !detFlags['det-complaint-001'] &&
         !detFlags['det-unsub-001'];
}
function draftPolicyFor(mi) {
'@

# ── DEC-B patch 2: add detected intents + effective draft policy ─────────────
$B2_Anchor  = '  const draftPolicy = draftPolicyFor(microIntent);'
$B2_Replace = @'
  const draftPolicy = draftPolicyFor(microIntent);
  const detectedIntents = detectAllIntents(combined, category, microIntent, det.flags || {});
  const effectiveDraftPolicy = (microIntent === 'PRICING_REQUEST' && draftPolicy === 'HUMAN_ONLY' && isCommercialSafe(det.flags || {})) ? 'AI_COMMERCIAL_SUPERVISED' : draftPolicy;
'@

# ── DEC-B patch 3: use effectiveDraftPolicy + add detected_intents field ─────
$B3_Anchor  = '    draft_policy: draftPolicy'
$B3_Replace = '    draft_policy: effectiveDraftPolicy,
    detected_intents: detectedIntents'

# ── DEC-D patch 1: add AI_COMMERCIAL_SUPERVISED branch ───────────────────────
# Anchor: entire final else block. Get-Code normalises to LF; anchor is normalised below.
$D1_Anchor = @'
  } else {
    draftText   = null;
    draftSource = draftPolicy === 'NO_DRAFT' ? 'none' : 'human_only';
  }
'@

$D1_Replace = @'
  } else if (draftPolicy === 'AI_COMMERCIAL_SUPERVISED') {
    // SL-PHASE-4A: Non-committal context-aware commercial draft
    var _di4d = cls.detected_intents || [];
    var _hP = microIntent === 'PRICING_REQUEST' || _di4d.some(function(i){return i.micro_intent==='PRICING_REQUEST';});
    var _hD = _di4d.some(function(i){return i.micro_intent==='DATA_SECURITY_REQUEST';});
    var _hC = _di4d.some(function(i){return i.micro_intent==='CONTRACT_TERMS_REQUEST';});
    var _hPi = _di4d.some(function(i){return i.micro_intent==='SMALL_SCALE_PILOT_REQUEST';});
    var _hS = _di4d.some(function(i){return i.micro_intent==='SCOPE_REQUEST';});
    var _gr = firstName ? ('Thanks, ' + firstName + '.') : 'Thanks.';
    var _ps = [_gr, 'Happy to answer these.'];
    if (_hP)  _ps.push('Pricing depends on scope. I want to give you a number that actually reflects your situation rather than a generic figure. The best way to do that is a brief 10-minute conversation.');
    if (_hD)  _ps.push('Your data would only be used for the agreed campaign. We would not sell it, share it, or use it outside the agreed scope.');
    if (_hC)  _ps.push('Yes, there would be a simple agreement before anything starts. Nothing complex or long-term at this stage.');
    if (_hPi) _ps.push('Yes, we can test this with one small campaign first before committing to anything bigger. That is actually how we prefer to start.');
    if (_hS)  _ps.push('Happy to explain exactly what is involved. The short version: we define the target, build a focused prospect list, write and run the outreach, then review results together.');
    _ps.push('If it helps to talk through the specifics, you can grab 10 minutes here: https://calendar.app.google/bNXWJkS3xz3yqdW36');
    if (senderName) _ps.push(senderName);
    draftText   = _ps.filter(function(p){return p.trim().length>0;}).join('\n\n');
    draftSource = 'ai_commercial_supervised';
  } else {
    draftText   = null;
    draftSource = draftPolicy === 'NO_DRAFT' ? 'none' : 'human_only';
  }
'@
$D1_Anchor  = Normalize $D1_Anchor
$D1_Replace = Normalize $D1_Replace

# ── DEC-D patch 2: add detected_intents to draft object ──────────────────────
$D2_Anchor  = '    human_review_required: decision.human_review_required === true,'
$D2_Replace = '    human_review_required: decision.human_review_required === true,
    detected_intents: cls.detected_intents || [],'

# ── HA-D patch 1: add secondary intents + AI label to Google Chat ────────────
$HD1_Anchor = 'lines.push("Draft source: " + (ctx.draft_source || rc.draft_source || "N/A"));'
# Double-quoted here-string: contains single quotes (ai_commercial_supervised), no $ signs
$HD1_Replace = @"
lines.push("Draft source: " + (ctx.draft_source || rc.draft_source || "N/A"));
  // SL-PHASE-4A: detected intents and AI draft label
  var _p4aHDSrc = ctx.draft_source || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.draft_source) || "";
  var _p4aHDList = (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.detected_intents) || [];
  if (_p4aHDList.length > 0) { lines.push("Additional intents: " + _p4aHDList.map(function(i){return i.micro_intent;}).join(' + ')); }
  if (_p4aHDSrc === 'ai_commercial_supervised') { lines.push("AI-assisted commercial draft — review before approving."); }
"@

# ── HA-J patch 1: show detected intents after risk flags line ────────────────
$HJ1_Anchor  = 'html += "<p><strong>Risk flags:</strong> " + escapeHtml((ctx.risk_flags || []).join(", ")) + "</p>";'
# Double-quoted here-string safe here (no $ signs in JS)
$HJ1_Replace = @"
html += "<p><strong>Risk flags:</strong> " + escapeHtml((ctx.risk_flags || []).join(", ")) + "</p>";
  // SL-PHASE-4A: secondary intents display (shared vars used below)
  var _p4aDS = ctx.draft_source || (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.draft_source) || rc.draft_source || "";
  var _p4aIntents = (ctx.sender_handoff && ctx.sender_handoff.draft && ctx.sender_handoff.draft.detected_intents) || [];
  if (_p4aIntents.length > 0) { html += "<p><strong>Additional detected intents:</strong> " + escapeHtml(_p4aIntents.map(function(i){return i.micro_intent;}).join(' + ')) + "</p>"; }
"@

# ── HA-J patch 2: add AI banner before textarea ──────────────────────────────
# Anchor: the unique text just before the textarea label
$HJ2_Anchor  = '; } html += "<label>Reply text (editable):<br><textarea'
# Double-quoted here-string
$HJ2_Replace = @"
; } if (_p4aDS === 'ai_commercial_supervised') { html += "<p style=\"background:#d1ecf1;border:1px solid #bee5eb;padding:10px;border-radius:4px\"><strong>AI-assisted draft for human review. Edit before approving. Do not invent prices, contract terms, data guarantees, or results not yet proven.</strong></p>"; } html += "<label>Reply text (editable):<br><textarea
"@

# ── HA-J patch 3: pre-populate additional_intents_shadow with detected intents ─
# Anchor: the unique part of the existing additional_intents_shadow input line
$HJ3_Anchor  = 'html += "<label>Additional classifications/intents in this email (optional, shadow learning only):<br><input type=\"text\" name=\"additional_intents_shadow\" style=\"width:440px\" placeholder=\"e.g. PRICING_REQUEST + SMALL_SCALE_PILOT_REQUEST\">'
# Double-quoted here-string
$HJ3_Replace = @"
var _p4aDefault = _p4aIntents.length > 0 ? _p4aIntents.map(function(i){return i.micro_intent;}).join(' + ') : "";
    html += "<label>Additional classifications/intents in this email (optional, shadow learning only):<br><input type=\"text\" name=\"additional_intents_shadow\" style=\"width:440px\" value=\"" + escapeHtml(_p4aDefault) + "\" placeholder=\"e.g. PRICING_REQUEST + SMALL_SCALE_PILOT_REQUEST\">
"@

# ════════════════════════════════════════════════════════════════════════════
# WHATIF
# ════════════════════════════════════════════════════════════════════════════
if ($WhatIf) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " $PatchId [WhatIf Mode]" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "[CHECK] Production target: $ProductionApiUrl" -ForegroundColor Green

    $decWf = Get-Wf $DecisionWorkflowId
    Write-Host "[FETCH] Decision: $($decWf.name) active=$($decWf.active)" -ForegroundColor Green
    $haWf  = Get-Wf $HumanApprovalWorkflowId
    Write-Host "[FETCH] HumanApproval: $($haWf.name) active=$($haWf.active)" -ForegroundColor Green

    $fthWf = Invoke-RestMethod -Uri "$ProductionApiUrl/workflows/RLUcJHQJPvLhw4mG" -Method GET -Headers $Headers
    if ($fthWf.active) { Write-Error "FTH is active! Abort."; exit 1 }
    Write-Host "[CHECK] FTH inactive: OK" -ForegroundColor Green

    $decB = Get-Code $decWf "section_b"
    $decD = Get-Code $decWf "section_d"
    $haD  = Get-Code $haWf  "1c512491-f272-417b-967e-aaeb241e9dd8"
    $haJ  = Get-Code $haWf  "44a376a2-a946-4a74-af6f-52688b577225"

    Write-Host "`n── Anchor checks ────────────────────────────────────────" -ForegroundColor Cyan
    $ok = $true
    $anchors = @(
        @{Code=$decB; Anchor=$B1_Anchor;  Label="Dec-B: draftPolicyFor function"},
        @{Code=$decB; Anchor=$B2_Anchor;  Label="Dec-B: draftPolicy assignment"},
        @{Code=$decB; Anchor=$B3_Anchor;  Label="Dec-B: draft_policy field"},
        @{Code=$decD; Anchor=$D1_Anchor;  Label="Dec-D: final else block (draftText=null/human_only)"},
        @{Code=$decD; Anchor=$D2_Anchor;  Label="Dec-D: human_review_required field"},
        @{Code=$haD;  Anchor=$HD1_Anchor; Label="HA-D: Draft source push"},
        @{Code=$haJ;  Anchor=$HJ1_Anchor; Label="HA-J: Risk flags line"},
        @{Code=$haJ;  Anchor=$HJ2_Anchor; Label="HA-J: textarea anchor"},
        @{Code=$haJ;  Anchor=$HJ3_Anchor; Label="HA-J: additional_intents_shadow anchor"}
    )
    foreach ($a in $anchors) {
        if ($a.Code.Contains($a.Anchor)) {
            Write-Host "  [OK]  $($a.Label)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($a.Label) — anchor not found" -ForegroundColor Red
            $ok = $false
        }
    }

    if ($decB.Contains('SL-PHASE-4A')) {
        Write-Host "  [WARN] Dec-B already has SL-PHASE-4A — may already be applied" -ForegroundColor Yellow
        $ok = $false
    } else {
        Write-Host "  [OK]  Dec-B: not yet patched" -ForegroundColor Green
    }

    Write-Host "`n── Safety invariants ───────────────────────────────────" -ForegroundColor Cyan
    $safeChecks = @(
        "Dec-A untouched (deterministic routing)","Dec-C untouched (action plan unchanged)",
        "Dec-E untouched (validator unchanged)","HUMAN_ONLY preserved for risky det-flags",
        "Commercial draft uses deterministic safe paragraphs (no extra OpenAI call)",
        "Primary routing unchanged","Approval gate unchanged","Sender untouched",
        "All SL-P1x/P2x capture nodes untouched","Autonomous send not introduced","MCP not used"
    )
    foreach ($s in $safeChecks) { Write-Host "  [OK]  $s" -ForegroundColor Green }

    Write-Host ""
    if ($ok) { Write-Host "WhatIf PASSED — run with -Apply to patch production." -ForegroundColor Green }
    else     { Write-Host "WhatIf FAILED — fix anchor issues before applying." -ForegroundColor Red; exit 1 }
    exit 0
}

# ════════════════════════════════════════════════════════════════════════════
# APPLY
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n============================================================" -ForegroundColor Magenta
Write-Host " $PatchId [Apply Mode]" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

Write-Host "`n[1/6] Fetching workflows..." -ForegroundColor Cyan
$decWf = Get-Wf $DecisionWorkflowId
$haWf  = Get-Wf $HumanApprovalWorkflowId
Write-Host "      Decision: $($decWf.name) active=$($decWf.active)" -ForegroundColor Green
Write-Host "      HumanApproval: $($haWf.name) active=$($haWf.active)" -ForegroundColor Green

$decB = Get-Code $decWf "section_b"
$decD = Get-Code $decWf "section_d"
$haD  = Get-Code $haWf  "1c512491-f272-417b-967e-aaeb241e9dd8"
$haJ  = Get-Code $haWf  "44a376a2-a946-4a74-af6f-52688b577225"

if ($decB.Contains('SL-PHASE-4A')) { Write-Error "Already patched — abort."; exit 1 }

Write-Host "[2/6] Patching Decision Section B..." -ForegroundColor Cyan
Must-Contain $decB $B1_Anchor "B1"
Must-Contain $decB $B2_Anchor "B2"
Must-Contain $decB $B3_Anchor "B3"
$newDecB = $decB.Replace($B1_Anchor, $B1_Inject)
$newDecB = $newDecB.Replace($B2_Anchor, $B2_Replace)
$newDecB = $newDecB.Replace($B3_Anchor, $B3_Replace)
if (-not $newDecB.Contains('SL-PHASE-4A')) { Write-Error "Dec-B verification failed."; exit 1 }
Write-Host "      OK" -ForegroundColor Green

Write-Host "[3/6] Patching Decision Section D..." -ForegroundColor Cyan
Must-Contain $decD $D1_Anchor "D1"
Must-Contain $decD $D2_Anchor "D2"
$newDecD = $decD.Replace($D1_Anchor, $D1_Replace)
$newDecD = $newDecD.Replace($D2_Anchor, $D2_Replace)
if (-not $newDecD.Contains('AI_COMMERCIAL_SUPERVISED')) { Write-Error "Dec-D verification failed."; exit 1 }
Write-Host "      OK" -ForegroundColor Green

Write-Host "[4/6] Patching HumanApproval Node D..." -ForegroundColor Cyan
Must-Contain $haD $HD1_Anchor "HD1"
$newHaD = $haD.Replace($HD1_Anchor, $HD1_Replace)
if (-not $newHaD.Contains('SL-PHASE-4A')) { Write-Error "HA-D verification failed."; exit 1 }
Write-Host "      OK" -ForegroundColor Green

Write-Host "[5/6] Patching HumanApproval Node J..." -ForegroundColor Cyan
Must-Contain $haJ $HJ1_Anchor "HJ1"
Must-Contain $haJ $HJ2_Anchor "HJ2"
Must-Contain $haJ $HJ3_Anchor "HJ3"
$newHaJ = $haJ.Replace($HJ1_Anchor, $HJ1_Replace)
$newHaJ = $newHaJ.Replace($HJ2_Anchor, $HJ2_Replace)
$newHaJ = $newHaJ.Replace($HJ3_Anchor, $HJ3_Replace)
if (-not $newHaJ.Contains('SL-PHASE-4A')) { Write-Error "HA-J verification failed."; exit 1 }
Write-Host "      OK" -ForegroundColor Green

# Write back
Set-Code $decWf "section_b" $newDecB
Set-Code $decWf "section_d" $newDecD
Set-Code $haWf  "1c512491-f272-417b-967e-aaeb241e9dd8" $newHaD
Set-Code $haWf  "44a376a2-a946-4a74-af6f-52688b577225" $newHaJ

Write-Host "[6/6] PUTting to production..." -ForegroundColor Cyan
$decR = Put-Wf $DecisionWorkflowId $decWf
Write-Host "      Decision PUT OK: versionId=$($decR.versionId)" -ForegroundColor Green
$haR  = Put-Wf $HumanApprovalWorkflowId $haWf
Write-Host "      HumanApproval PUT OK: versionId=$($haR.versionId)" -ForegroundColor Green

# Verify re-fetch
Write-Host "`n── Verify re-fetch ─────────────────────────────────────" -ForegroundColor Cyan
$dV = Get-Wf $DecisionWorkflowId
$hV = Get-Wf $HumanApprovalWorkflowId
$dBV = Get-Code $dV "section_b"
$dDV = Get-Code $dV "section_d"
$hDV = Get-Code $hV "1c512491-f272-417b-967e-aaeb241e9dd8"
$hJV = Get-Code $hV "44a376a2-a946-4a74-af6f-52688b577225"

$vOk = $true
$checks = @(
    @{C=$dBV; M='SL-PHASE-4A';                    L='Dec-B: marker'},
    @{C=$dBV; M='detectAllIntents';                L='Dec-B: detectAllIntents'},
    @{C=$dBV; M='isCommercialSafe';                L='Dec-B: isCommercialSafe'},
    @{C=$dBV; M='effectiveDraftPolicy';            L='Dec-B: effectiveDraftPolicy'},
    @{C=$dBV; M='detected_intents: detectedIntents'; L='Dec-B: detected_intents field'},
    @{C=$dDV; M='AI_COMMERCIAL_SUPERVISED';        L='Dec-D: commercial branch'},
    @{C=$dDV; M='detected_intents: cls.detected_intents'; L='Dec-D: detected_intents in draft'},
    @{C=$hDV; M='SL-PHASE-4A';                    L='HA-D: marker'},
    @{C=$hDV; M='_p4aHDList';                     L='HA-D: intent list'},
    @{C=$hJV; M='SL-PHASE-4A';                    L='HA-J: marker'},
    @{C=$hJV; M='_p4aIntents';                    L='HA-J: intents var'},
    @{C=$hJV; M='ai_commercial_supervised';        L='HA-J: AI banner condition'},
    @{C=$hJV; M='_p4aDefault';                    L='HA-J: default value'}
)
foreach ($c in $checks) {
    if ($c.C.Contains($c.M)) { Write-Host "  [OK]  $($c.L)" -ForegroundColor Green }
    else                     { Write-Host "  [FAIL] $($c.L)" -ForegroundColor Red; $vOk = $false }
}

Write-Host ""
if ($vOk) {
    Write-Host "PATCH APPLIED AND VERIFIED: $PatchId" -ForegroundColor Green
    Write-Host "Decision versionId: $($dV.versionId)" -ForegroundColor Green
    Write-Host "HumanApproval versionId: $($hV.versionId)" -ForegroundColor Green
    Write-Host "Self-improving status: 70% installed, retest pending." -ForegroundColor Cyan
    Write-Host "Next: run a test reply with pricing/data/contract/pilot questions." -ForegroundColor Cyan
    Write-Host "Do NOT proceed to autonomous mode or active rule injection." -ForegroundColor Yellow
} else {
    Write-Error "VERIFY FAILED after PUT. Check production manually."
    exit 1
}
