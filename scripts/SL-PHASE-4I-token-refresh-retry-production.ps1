#Requires -Version 7.0
<#
.SYNOPSIS
SL-PHASE-4I Part A: Production token-refresh retry for recoverable blocked sends.

.DESCRIPTION
Patches HumanApproval workflow 9aPrt92jFhoYFxbs ONLY.
Sender workflow is NOT modified.

Changes applied:
  Node H  — accept RETRY_NEEDED as valid status for GET token validation
  Node L  — accept RETRY_NEEDED as valid status for POST token validation
  Q conn  — reroute Q output from R to R0
  R0      — NEW: Classify sender result + check if blocked/recoverable
  R0-Route— NEW: IF blocked → retry path | NOT blocked → existing R
  R1-Route— NEW: IF recoverable → token path | nonrecoverable → R5b
  R-GenTok— NEW: Generate fresh review token + build retry URL
  R2      — NEW: DataTable update (status=RETRY_NEEDED, new token)
  R3      — NEW: Build retry Google Chat notification payload
  R4      — NEW: POST retry Google Chat webhook
  R5      — NEW: Build "retry link sent" result page HTML
  R5b     — NEW: Build nonrecoverable result page HTML

Safety guarantees:
  - Retry URL is ONLY generated when block is recoverable (not SENT, not DNC, etc.)
  - Duplicate-send prevention in Sender (all 14 gates) remains intact
  - If the case is already SENT or SENT_RECONCILED, retry is denied
  - Nonrecoverable blocks (duplicate_send_guard, send_key_conflict, SENT terminal) get no retry
  - Token TTL is honoured (same 60-minute window as initial token)
  - Learning capture (SL-P1A through SL-P2E) is preserved unchanged
  - Node Q validation override (Phase 4G) is preserved unchanged
  - Autonomous send is NOT enabled

Do NOT run against localhost / Docker. Production target only.

.PARAMETER WhatIf
Dry-run: verify patch targets exist, no changes made.

.PARAMETER Apply
Execute the patch and verify live versionId changed.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Apply
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

foreach ($bad in @("localhost","127.0.0.1","5678","docker")) {
    if ($PSCommandPath -match [regex]::Escape($bad)) { Write-Error "SAFETY: forbidden term '$bad' in script path."; exit 1 }
}

if (-not $WhatIf -and -not $Apply) {
    Write-Host "Usage: -WhatIf (dry-run) | -Apply (execute patch)"
    exit 0
}

$BASE    = "https://n8n.hmzaiautomation.com/api/v1"
$API_KEY = $env:HMZ_N8N_API_KEY
if (-not $API_KEY) { Write-Error "HMZ_N8N_API_KEY not set"; exit 1 }
$HEADERS = @{ "X-N8N-API-KEY" = $API_KEY; "Content-Type" = "application/json" }

$WF_HA                    = "9aPrt92jFhoYFxbs"
$EXPECTED_VERSION_BEFORE  = "7f23d288-c27e-4e88-ba5d-5afd96514c9b"   # Phase 4G result
$DT_CASES                 = "WMTmI6UNjZZgSU3h"                       # hmz-review-cases DataTable

function Get-Workflow($id) { Invoke-RestMethod -Uri "$BASE/workflows/$id" -Headers $HEADERS -Method GET }
function Find-Node($wf, $nameLike) {
    $n = $wf.nodes | Where-Object { $_.name -like $nameLike }
    if (-not $n) { throw "Node not found matching '$nameLike'" }
    $n
}

$pass = 0; $fail = 0
function Check($label, $cond) {
    if ($cond) { Write-Host "  PASS: $label"; $script:pass++ }
    else        { Write-Host "  FAIL: $label"; $script:fail++ }
}

# ─── Load ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-4I-A  WhatIf=$WhatIf  Apply=$Apply ==="
Write-Host "Production target: $BASE"
Write-Host ""
Write-Host "Loading HumanApproval $WF_HA ..."
$wfHA = Get-Workflow $WF_HA
Write-Host "  versionId: $($wfHA.versionId)"

$nodeH    = Find-Node $wfHA "H. Validate Review Token (GET)"
$nodeL    = Find-Node $wfHA "L. Validate & Consume Review Token (POST)"
$nodeR    = Find-Node $wfHA "R. Build Approved Result Page"
$nodeQ    = Find-Node $wfHA "Q. Reply Sender Handoff*"
$nodeK3   = Find-Node $wfHA "K3. Respond Approved Result"

# ─── WhatIf checks ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Version check ---"
Check "versionId matches Phase 4G expected" ($wfHA.versionId -eq $EXPECTED_VERSION_BEFORE)

Write-Host ""
Write-Host "--- Node H (GET token validator) ---"
$hCode = $nodeH.parameters.jsCode
Check "Node H has jsCode"               ($hCode -ne $null -and $hCode.Length -gt 0)
Check "Node H checks IN_REVIEW status"  ($hCode -match '"IN_REVIEW"')
Check "Node H does NOT yet accept RETRY_NEEDED" ($hCode -notmatch '"RETRY_NEEDED"')

Write-Host ""
Write-Host "--- Node L (POST token validator) ---"
$lCode = $nodeL.parameters.jsCode
Check "Node L has jsCode"               ($lCode -ne $null -and $lCode.Length -gt 0)
Check "Node L checks IN_REVIEW status"  ($lCode -match '"IN_REVIEW"')
Check "Node L does NOT yet accept RETRY_NEEDED" ($lCode -notmatch '"RETRY_NEEDED"')

Write-Host ""
Write-Host "--- Node R (approved result page) ---"
$rCode = $nodeR.parameters.jsCode
Check "Node R has SEND_BLOCKED_RETRYABLE (Phase 4G applied)" ($rCode -match "SEND_BLOCKED_RETRYABLE")
Check "Node R does NOT yet generate review token"            ($rCode -notmatch "generateReviewToken")

Write-Host ""
Write-Host "--- New nodes do NOT already exist ---"
$r0Exists  = ($wfHA.nodes | Where-Object { $_.name -like "R0*" }) -ne $null
$r5Exists  = ($wfHA.nodes | Where-Object { $_.name -like "R5*" }) -ne $null
Check "R0 nodes not already present" (-not $r0Exists)
Check "R5 nodes not already present" (-not $r5Exists)

Write-Host ""
Write-Host "--- Node Q connection points to R (will be changed to R0) ---"
$qConn = $wfHA.connections."Q. Reply Sender Handoff (Approved)"
$qTarget = if ($qConn -and $qConn.main -and $qConn.main[0] -and $qConn.main[0][0]) { $qConn.main[0][0].node } else { "" }
Check "Q currently connects to R (not yet R0)" ($qTarget -eq "R. Build Approved Result Page")

Write-Host ""
Write-Host "--- WhatIf Summary: PASS=$pass  FAIL=$fail ---"

if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf complete. No changes made. Run -Apply to execute."
    exit ($fail -gt 0 ? 1 : 0)
}
if ($fail -gt 0) {
    Write-Error "WhatIf checks failed ($fail failures). Aborting Apply."
    exit 1
}

# ─── JavaScript code for new nodes ─────────────────────────────────────────────
$CODE_R0 = @'
// R0: Classify Sender Result
// Reads Sender terminal output and determines: is_blocked, is_recoverable, block details.
// Also restores case context from O1.
const items = $input.all();

function parseJson(v, fb) {
  if (v == null || v === "") return fb;
  if (typeof v === "object") return v;
  try { return JSON.parse(String(v)); } catch { return fb; }
}

let approvalCtx = {};
try { approvalCtx = $("O1. Restore Reviewer Decision Context").first().json || {}; } catch {}

const NONRECOVERABLE_DETAILS = [
  "duplicate_send_guard",
  "send_key_conflict",
  "unsubscribe",
  "dnc",
  "legal",
  "safety_block"
];

return items.map(item => {
  const input = item.json || {};
  const rc    = approvalCtx.review_case || {};

  const terminal    = input.terminal || {};
  const blockDetails = Array.isArray(terminal.details) ? terminal.details : [];

  const isSent = (
    terminal.result === "SENT"             ||
    terminal.send_state === "SENT"         ||
    terminal.terminal_status === "SENT"    ||
    terminal.terminal_status === "SENT_RECONCILED" ||
    rc.status === "SENT"                   ||
    rc.status === "SENT_RECONCILED"
  );

  const isBlocked = !isSent && (
    terminal.result === "BLOCKED"                      ||
    terminal.send_state === "BLOCKED"                  ||
    terminal.terminal_status === "SEND_BLOCKED"        ||
    terminal.terminal_status === "SEND_BLOCKED_RETRYABLE"
  );

  const hasNonrecoverableDetail = NONRECOVERABLE_DETAILS.some(d => blockDetails.includes(d));
  const isRecoverable = isBlocked && !hasNonrecoverableDetail;

  return {
    json: {
      ...input,
      review_case: rc,
      sender_block_classification: {
        is_blocked:        isBlocked,
        is_sent:           isSent,
        is_recoverable:    isRecoverable,
        is_nonrecoverable: isBlocked && !isRecoverable,
        block_details:     blockDetails,
        terminal_result:   terminal.result || terminal.terminal_status || "UNKNOWN",
        case_status_before: rc.status || "UNKNOWN"
      }
    }
  };
});
'@

$CODE_R_GENTOKEN = @'
// R-GenToken: Generate fresh review token for recoverable retry
const items = $input.all();

function randomHex(bytes) {
  let out = "";
  if (typeof globalThis.crypto !== "undefined" && typeof globalThis.crypto.getRandomValues === "function") {
    const arr = new Uint8Array(bytes);
    globalThis.crypto.getRandomValues(arr);
    for (const b of arr) out += b.toString(16).padStart(2, "0");
    return out;
  }
  for (let i = 0; i < bytes; i++) out += Math.floor(Math.random() * 256).toString(16).padStart(2, "0");
  return out;
}

function djb2Hash(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) + hash + str.charCodeAt(i);
    hash = hash & 0xffffffff;
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function generateReviewToken() {
  return randomHex(16) + djb2Hash(String(Date.now()) + String(Math.random()));
}

return items.map(item => {
  const input  = item.json || {};
  const rc     = input.review_case || {};
  const config = input.config || {};

  const TTL_MINUTES = (config.review && config.review.review_token_ttl_minutes) || 60;
  const nowIso      = new Date().toISOString();
  const expiresIso  = new Date(Date.now() + TTL_MINUTES * 60000).toISOString();
  const newToken    = generateReviewToken();
  const base        = String((config.review || {}).review_base_url || "").replace(/\/$/, "");
  const retryUrl    = base + "/review?case=" + encodeURIComponent(rc.case_id || "") + "&token=" + encodeURIComponent(newToken);

  return {
    json: {
      ...input,
      retry_token_context: {
        case_id:              rc.case_id || "",
        new_token:            newToken,
        new_token_expires_at: expiresIso,
        retry_url:            retryUrl,
        issued_at:            nowIso,
        block_classification: input.sender_block_classification || {}
      }
    }
  };
});
'@

$CODE_R3 = @'
// R3: Build retry Google Chat notification payload
const items = $input.all();

let priorCtx = {};
try { priorCtx = $("R-GenToken. Generate Retry Token").first().json || {}; } catch {}

return items.map(item => {
  const input = item.json || {};
  const rc    = priorCtx.review_case || input.review_case || {};
  const rtc   = priorCtx.retry_token_context || input.retry_token_context || {};
  const ctx   = rc.sanitized_context || {};
  const bCls  = priorCtx.sender_block_classification || input.sender_block_classification || {};
  const bd    = (bCls.block_details || []).join(", ") || bCls.terminal_result || "see logs";
  const snip  = String(ctx.reply_snippet || ctx.reply_text || "").replace(/\s+/g, " ").trim().slice(0, 120);

  const lines = [
    "RETRY NEEDED — case: " + (rc.case_id || "UNKNOWN"),
    "Send blocked: " + bd,
    "Prospect did NOT receive a reply. New review link issued.",
    "From: " + (ctx.reply_from_name
      ? (ctx.reply_from_name + " <" + (ctx.reply_from_email || "?") + ">")
      : (ctx.reply_from_email || "UNKNOWN")),
    "Micro intent: " + (ctx.micro_intent || rc.micro_intent || "N/A"),
    snip ? ("Excerpt: " + snip) : null,
    "Retry review: " + (rtc.retry_url || "URL unavailable")
  ].filter(Boolean);

  return {
    json: {
      ...priorCtx,
      ...input,
      review_case:             rc,
      retry_token_context:     rtc,
      retry_chat_notification: { payload: { text: lines.join("\n") } }
    }
  };
});
'@

$CODE_R5 = @'
// R5: Build "retry link sent" result page (recoverable path)
const items = $input.all();

function escapeHtml(v) {
  return String(v == null ? "" : v)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

let genCtx = {};
try { genCtx = $("R-GenToken. Generate Retry Token").first().json || {}; } catch {}

return items.map(item => {
  const input = item.json || {};
  const rc    = genCtx.review_case || input.review_case || {};
  const rtc   = genCtx.retry_token_context || input.retry_token_context || {};
  const bCls  = genCtx.sender_block_classification || input.sender_block_classification || {};
  const bd    = (bCls.block_details || []).join(", ") || bCls.terminal_result || "see logs";

  let html = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>HMZ Reply Review</title></head><body>';
  html += '<h1 style="color:#c0392b">Send Blocked — New Review Link Sent</h1>';
  html += '<p>Case <strong>' + escapeHtml(rc.case_id) + '</strong> was approved but the send was blocked before transmission.</p>';
  html += '<p><strong>Block details:</strong> ' + escapeHtml(bd) + '</p>';
  html += '<div style="background:#d4edda;border:1px solid #c3e6cb;padding:10px;border-radius:4px;margin:10px 0">';
  html += '<strong>The prospect did NOT receive a reply.</strong><br>';
  html += 'A new review link has been sent to Google Chat. Please check Google Chat and use the new link to re-approve the reply.';
  html += '</div>';
  html += '<p style="font-size:0.85em;color:#888">Case: ' + escapeHtml(rc.case_id) + ' | New token issued: ' + escapeHtml(rtc.issued_at || "") + '</p>';
  html += '</body></html>';

  return { json: { ...input, review_case: rc, html, http_status: 200 } };
});
'@

$CODE_R5B = @'
// R5b: Build nonrecoverable blocked result page
const items = $input.all();

function escapeHtml(v) {
  return String(v == null ? "" : v)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

return items.map(item => {
  const input = item.json || {};
  const rc    = input.review_case || {};
  const bCls  = input.sender_block_classification || {};
  const bd    = (bCls.block_details || []).join(", ") || bCls.terminal_result || "nonrecoverable block";

  let html = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>HMZ Reply Review</title></head><body>';

  if (bCls.is_sent) {
    html += '<h1 style="color:#27ae60">Sent</h1>';
    html += '<p>Case ' + escapeHtml(rc.case_id) + ' appears to have already been sent. This looks like a re-submission of a completed case.</p>';
    html += '<p>The prospect already received the reply. No action needed.</p>';
  } else {
    html += '<h1 style="color:#721c24">Send Blocked — No Retry Available</h1>';
    html += '<p>Case <strong>' + escapeHtml(rc.case_id) + '</strong> was blocked with a nonrecoverable reason.</p>';
    html += '<p><strong>Block details:</strong> ' + escapeHtml(bd) + '</p>';
    html += '<div style="background:#f8d7da;border:1px solid #f5c6cb;padding:10px;border-radius:4px;margin:10px 0">';
    html += '<strong>Contact the system owner.</strong> Do NOT attempt to send manually unless you have verified no reply was sent via Instantly Unibox.';
    html += '</div>';
  }

  html += '<p style="font-size:0.85em;color:#888">Case: ' + escapeHtml(rc.case_id) + '</p>';
  html += '</body></html>';

  return { json: { ...input, review_case: rc, html, http_status: 200 } };
});
'@

# ─── Apply ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patches ==="

# ── 1. Modify Node H ──────────────────────────────────────────────────────────
Write-Host "Part 1: Patching Node H (GET token validator)..."
$OLD_H_COND = 'else if (row.status !== "NEW" && row.status !== "IN_REVIEW") { tokenValid = false; reason = "ALREADY_DECIDED"; }'
$NEW_H_COND = 'else if (row.status !== "NEW" && row.status !== "IN_REVIEW" && row.status !== "RETRY_NEEDED") { tokenValid = false; reason = "ALREADY_DECIDED"; }'
if (-not $nodeH.parameters.jsCode.Contains($OLD_H_COND)) {
    Write-Error "Node H: expected condition string not found. Aborting."
    exit 1
}
$nodeH.parameters.jsCode = $nodeH.parameters.jsCode.Replace($OLD_H_COND, $NEW_H_COND)
Write-Host "  Done."

# ── 2. Modify Node L ──────────────────────────────────────────────────────────
Write-Host "Part 2: Patching Node L (POST token validator)..."
$OLD_L_COND = 'else if (row.status !== "NEW" && row.status !== "IN_REVIEW") { tokenValid = false; reason = "ALREADY_DECIDED"; }'
$NEW_L_COND = 'else if (row.status !== "NEW" && row.status !== "IN_REVIEW" && row.status !== "RETRY_NEEDED") { tokenValid = false; reason = "ALREADY_DECIDED"; }'
if (-not $nodeL.parameters.jsCode.Contains($OLD_L_COND)) {
    Write-Error "Node L: expected condition string not found. Aborting."
    exit 1
}
$nodeL.parameters.jsCode = $nodeL.parameters.jsCode.Replace($OLD_L_COND, $NEW_L_COND)
Write-Host "  Done."

# ── 3. Build new node objects ─────────────────────────────────────────────────
Write-Host "Part 3: Building new node objects..."

function New-N8nNode($id, $name, $type, $typeVersion, $position, $parameters, $extras = @{}) {
    $n = [PSCustomObject]@{
        id          = $id
        name        = $name
        type        = $type
        typeVersion = $typeVersion
        position    = $position
        parameters  = $parameters
    }
    foreach ($k in $extras.Keys) { $n | Add-Member -NotePropertyName $k -NotePropertyValue $extras[$k] -Force }
    $n
}

$nodeR0 = New-N8nNode "r0-check-sender-result" "R0. Check Sender Result" `
    "n8n-nodes-base.code" 2 @(2100, 580) @{ jsCode = $CODE_R0 }

$nodeR0Route = New-N8nNode "r0-route-sender-block" "R0-Route. Sender Block Router" `
    "n8n-nodes-base.if" 2.2 @(2340, 580) @{
    conditions = [PSCustomObject]@{
        options    = [PSCustomObject]@{ version=2; leftValue=""; caseSensitive=$true; typeValidation="strict" }
        combinator = "and"
        conditions = @(
            [PSCustomObject]@{
                id        = "cond-r0-blocked"
                leftValue = '={{ $json.sender_block_classification.is_blocked === true }}'
                rightValue = ""
                operator  = [PSCustomObject]@{ type="boolean"; operation="true"; singleValue=$true }
            }
        )
    }
    options = [PSCustomObject]@{}
}

$nodeR1Route = New-N8nNode "r1-route-retry-safety" "R1-Route. Retry Safety Router" `
    "n8n-nodes-base.if" 2.2 @(2580, 440) @{
    conditions = [PSCustomObject]@{
        options    = [PSCustomObject]@{ version=2; leftValue=""; caseSensitive=$true; typeValidation="strict" }
        combinator = "and"
        conditions = @(
            [PSCustomObject]@{
                id        = "cond-r1-recoverable"
                leftValue = '={{ $json.sender_block_classification.is_recoverable === true }}'
                rightValue = ""
                operator  = [PSCustomObject]@{ type="boolean"; operation="true"; singleValue=$true }
            }
        )
    }
    options = [PSCustomObject]@{}
}

$nodeRGenToken = New-N8nNode "r-gen-retry-token" "R-GenToken. Generate Retry Token" `
    "n8n-nodes-base.code" 2 @(2820, 340) @{ jsCode = $CODE_R_GENTOKEN }

$nodeR2 = New-N8nNode "r2-update-case-retry-needed" "R2. Update Case RETRY_NEEDED" `
    "n8n-nodes-base.dataTable" 1.1 @(3060, 340) @{
    resource    = "row"
    operation   = "update"
    dataTableId = [PSCustomObject]@{ mode="id"; value=$DT_CASES }
    filters     = [PSCustomObject]@{
        conditions = @(
            [PSCustomObject]@{
                keyName   = "case_id"
                condition = "eq"
                keyValue  = '={{ $json.retry_token_context.case_id }}'
            }
        )
    }
    columns = [PSCustomObject]@{
        mappingMode = "defineBelow"
        value       = [PSCustomObject]@{
            status           = "RETRY_NEEDED"
            token            = '={{ $json.retry_token_context.new_token }}'
            token_expires_at = '={{ $json.retry_token_context.new_token_expires_at }}'
            updated_at       = '={{ new Date().toISOString() }}'
        }
    }
}

$nodeR3 = New-N8nNode "r3-build-retry-chat" "R3. Build Retry Chat Message" `
    "n8n-nodes-base.code" 2 @(3300, 340) @{ jsCode = $CODE_R3 }

$nodeR4 = New-N8nNode "r4-post-retry-chat" "R4. POST Retry Chat Webhook" `
    "n8n-nodes-base.httpRequest" 4.2 @(3540, 340) `
    @{
        method      = "POST"
        url         = '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}'
        sendBody    = $true
        specifyBody = "json"
        jsonBody    = '={{ JSON.stringify($json.retry_chat_notification.payload) }}'
        options     = [PSCustomObject]@{ timeout = 5000 }
    } `
    @{ onError = "continueRegularOutput" }

$nodeR5 = New-N8nNode "r5-build-retryable-page" "R5. Build Retryable Result Page" `
    "n8n-nodes-base.code" 2 @(3780, 340) @{ jsCode = $CODE_R5 }

$nodeR5b = New-N8nNode "r5b-build-nonrec-page" "R5b. Build Nonrecoverable Result Page" `
    "n8n-nodes-base.code" 2 @(2820, 620) @{ jsCode = $CODE_R5B }

$newNodes = @($nodeR0, $nodeR0Route, $nodeR1Route, $nodeRGenToken, $nodeR2, $nodeR3, $nodeR4, $nodeR5, $nodeR5b)
Write-Host "  9 new nodes built."

# ── 4. Add new nodes to workflow ──────────────────────────────────────────────
Write-Host "Part 4: Adding new nodes to workflow..."
$allNodes = [System.Collections.Generic.List[object]]@($wfHA.nodes)
foreach ($n in $newNodes) { [void]$allNodes.Add($n) }
Write-Host "  Total nodes: $($allNodes.Count)"

# ── 5. Build updated connections ──────────────────────────────────────────────
Write-Host "Part 5: Building updated connections..."

# Convert existing connections to hashtable for manipulation
$connJson = $wfHA.connections | ConvertTo-Json -Depth 20
$conn     = $connJson | ConvertFrom-Json -AsHashtable

# Helper: build a single-output connection entry
function C1($targetNode) {
    @{ main = @(, @(@{ node=$targetNode; type="main"; index=0 })) }
}
# Helper: build a two-output (IF) connection entry
function C2($trueNode, $falseNode) {
    @{ main = @(
        @(@{ node=$trueNode;  type="main"; index=0 }),
        @(@{ node=$falseNode; type="main"; index=0 })
    )}
}

# Change Q → R  to  Q → R0
$conn["Q. Reply Sender Handoff (Approved)"] = C1 "R0. Check Sender Result"

# New connections
$conn["R0. Check Sender Result"]        = C1 "R0-Route. Sender Block Router"
$conn["R0-Route. Sender Block Router"]  = C2 "R1-Route. Retry Safety Router" "R. Build Approved Result Page"
$conn["R1-Route. Retry Safety Router"]  = C2 "R-GenToken. Generate Retry Token" "R5b. Build Nonrecoverable Result Page"
$conn["R-GenToken. Generate Retry Token"] = C1 "R2. Update Case RETRY_NEEDED"
$conn["R2. Update Case RETRY_NEEDED"]   = C1 "R3. Build Retry Chat Message"
$conn["R3. Build Retry Chat Message"]   = C1 "R4. POST Retry Chat Webhook"
$conn["R4. POST Retry Chat Webhook"]    = C1 "R5. Build Retryable Result Page"
$conn["R5. Build Retryable Result Page"]        = C1 "K3. Respond Approved Result"
$conn["R5b. Build Nonrecoverable Result Page"]  = C1 "K3. Respond Approved Result"

Write-Host "  Connections updated."

# ── 6. PUT workflow back ──────────────────────────────────────────────────────
Write-Host "Part 6: Writing patched workflow back..."
$slim = @{
    name        = $wfHA.name
    nodes       = $allNodes.ToArray()
    connections = $conn
    settings    = $wfHA.settings
    staticData  = $wfHA.staticData
}
$body      = $slim | ConvertTo-Json -Depth 40 -Compress
$putResult = Invoke-RestMethod -Uri "$BASE/workflows/$WF_HA" -Method PUT -Headers $HEADERS -Body $body -ContentType "application/json"
Write-Host "  New versionId: $($putResult.versionId)"

# ─── Verify ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Verification ==="
$wfV = Get-Workflow $WF_HA
Write-Host "  versionId after Apply: $($wfV.versionId)"

$pass2=0; $fail2=0
function Check2($label, $cond) {
    if ($cond) { Write-Host "  PASS: $label"; $script:pass2++ }
    else        { Write-Host "  FAIL: $label"; $script:fail2++ }
}

Check2 "versionId changed from Phase 4G baseline" ($wfV.versionId -ne $EXPECTED_VERSION_BEFORE)

$hV  = $wfV.nodes | Where-Object { $_.name -eq "H. Validate Review Token (GET)" }
$lV  = $wfV.nodes | Where-Object { $_.name -eq "L. Validate & Consume Review Token (POST)" }
$r0V = $wfV.nodes | Where-Object { $_.name -eq "R0. Check Sender Result" }
$r0rV= $wfV.nodes | Where-Object { $_.name -eq "R0-Route. Sender Block Router" }
$r1rV= $wfV.nodes | Where-Object { $_.name -eq "R1-Route. Retry Safety Router" }
$rgV = $wfV.nodes | Where-Object { $_.name -eq "R-GenToken. Generate Retry Token" }
$r2V = $wfV.nodes | Where-Object { $_.name -eq "R2. Update Case RETRY_NEEDED" }
$r3V = $wfV.nodes | Where-Object { $_.name -eq "R3. Build Retry Chat Message" }
$r4V = $wfV.nodes | Where-Object { $_.name -eq "R4. POST Retry Chat Webhook" }
$r5V = $wfV.nodes | Where-Object { $_.name -eq "R5. Build Retryable Result Page" }
$r5bV= $wfV.nodes | Where-Object { $_.name -eq "R5b. Build Nonrecoverable Result Page" }

Check2 "Node H accepts RETRY_NEEDED"       ($hV  -and $hV.parameters.jsCode  -match '"RETRY_NEEDED"')
Check2 "Node L accepts RETRY_NEEDED"       ($lV  -and $lV.parameters.jsCode  -match '"RETRY_NEEDED"')
Check2 "Node R0 exists"                    ($r0V  -ne $null)
Check2 "Node R0-Route exists"              ($r0rV -ne $null)
Check2 "Node R1-Route exists"              ($r1rV -ne $null)
Check2 "Node R-GenToken exists"            ($rgV  -ne $null)
Check2 "Node R-GenToken has generateReviewToken" ($rgV -and $rgV.parameters.jsCode -match "generateReviewToken")
Check2 "Node R2 exists (DataTable)"        ($r2V  -ne $null)
Check2 "Node R3 exists (Chat build)"       ($r3V  -ne $null)
Check2 "Node R4 exists (Chat POST)"        ($r4V  -ne $null)
Check2 "Node R5 exists (retry page)"       ($r5V  -ne $null)
Check2 "Node R5b exists (nonrec page)"     ($r5bV -ne $null)

# Verify connections
$qConnV = $wfV.connections."Q. Reply Sender Handoff (Approved)"
$qTargetV = if ($qConnV -and $qConnV.main -and $qConnV.main[0] -and $qConnV.main[0][0]) { $qConnV.main[0][0].node } else { "" }
Check2 "Q now connects to R0" ($qTargetV -eq "R0. Check Sender Result")

$r0ConnV = $wfV.connections."R0. Check Sender Result"
Check2 "R0 connects to R0-Route" ($r0ConnV -and $r0ConnV.main -and $r0ConnV.main[0] -and $r0ConnV.main[0][0] -and $r0ConnV.main[0][0].node -eq "R0-Route. Sender Block Router")

# Verify Node R still has Phase 4G code (preserved)
$rStill = $wfV.nodes | Where-Object { $_.name -eq "R. Build Approved Result Page" }
Check2 "Node R still has SEND_BLOCKED_RETRYABLE (preserved)" ($rStill -and $rStill.parameters.jsCode -match "SEND_BLOCKED_RETRYABLE")

# Verify no autonomous send, no sender modification
$senderNode = $wfV.nodes | Where-Object { $_.name -like "*Sender*" -and $_.type -notmatch "executeWorkflow" }
Check2 "No rogue Sender modification" ($senderNode -eq $null)

Write-Host ""
Write-Host "=== Phase 4I Apply Verification: PASS=$pass2  FAIL=$fail2 ==="

if ($fail2 -gt 0) {
    Write-Host "WARN: $fail2 verification check(s) failed. Inspect above. Manual review recommended."
    exit 1
}

Write-Host ""
Write-Host "=== SL-PHASE-4I-A APPLIED SUCCESSFULLY ==="
Write-Host "  HumanApproval versionId: $($wfV.versionId)"
Write-Host "  Nodes modified: H, L"
Write-Host "  Nodes added: R0, R0-Route, R1-Route, R-GenToken, R2, R3, R4, R5, R5b"
Write-Host "  Q connection rerouted: R → R0"
Write-Host "  Sender workflow: NOT modified"
Write-Host "  Autonomous send: NOT enabled"
Write-Host "  Safety gates: intact"
Write-Host ""
Write-Host "  IMPORTANT: Do not approve live review cases to test retry until a controlled"
Write-Host "  recoverable block is confirmed. Use the offline harness (RB-1 to RB-12) first."
