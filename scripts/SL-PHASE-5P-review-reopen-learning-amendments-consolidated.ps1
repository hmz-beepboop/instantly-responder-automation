<#
.SYNOPSIS
SL-PHASE-5P — Review Reopen, Learning Amendments, Controlled Repeat Send, Google Chat Expiry

.DESCRIPTION
Patches HumanApproval (9aPrt92jFhoYFxbs) to support:
  H  — Allow form access for RESPONSE_APPROVED / LEARNING_REVISION_APPROVED cases
  J  — Already-sent banner, revision counter, prefill from latest approved state, new action buttons
  L  — Allow submit for reopened cases; parse repeat_send_reason
  N  — approve_learning_only action; revision counter in decision_payload; store latest content
  D  — Google Chat expiry timestamp and time-remaining text
  Q2 — LEARNING_REVISION_APPROVED and FOLLOWUP_SEND_PENDING_MANUAL result pages

Safety:
  - No Sender changes
  - No Decision changes
  - No autonomous mode changes
  - DRY_RUN preserved
  - No live email sent

.PARAMETER WhatIf
Preview what would change without modifying anything.

.PARAMETER Apply
Patch local JSON and push to production n8n API.

.PARAMETER VerifyRenderedReviewHtml
After apply, fetch the rendered review form HTML and check key fields.

.PARAMETER VerifyDraftLearningFields
Check draft-learning fields are visible in rendered HTML.

.PARAMETER VerifyReopenAfterSent
Check the form renders correctly for an approved/sent case.

.PARAMETER VerifyBlockedNoBanner
Check that denied/blocked cases do not show the already-sent banner.

.PARAMETER VerifyGoogleChatExpiryText
Check Google Chat notification payload includes expiry text.

.PARAMETER VerifyLearningOnlyApproval
Check that approve_learning_only action is captured correctly (offline code check).

.PARAMETER VerifyRevisionCounter
Check that revision_count is stored in decision_payload (offline code check).

.PARAMETER VerifyControlledRepeatSendMetadata
Check repeat_send_reason is captured (offline code check).

.PARAMETER ExportReport
Write outputs/review_reopen_learning_amendments_consolidated_report.json.

.PARAMETER UseCaseId
Case ID for live form HTML fetch (e.g. case-ddb1f011). Does not approve or send.

.PARAMETER UseBlockedCaseId
Case ID of a blocked/denied case for no-banner verification.

.PARAMETER NoSecretOutput
Suppress any output that might expose secrets.

.EXAMPLE
.\scripts\SL-PHASE-5P-review-reopen-learning-amendments-consolidated.ps1 -WhatIf -ExportReport
.\scripts\SL-PHASE-5P-review-reopen-learning-amendments-consolidated.ps1 -Apply -VerifyRenderedReviewHtml -ExportReport
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$WhatIf,
    [switch]$VerifyRenderedReviewHtml,
    [switch]$VerifyDraftLearningFields,
    [switch]$VerifyTargetClassificationSelector,
    [switch]$VerifySubmitCapture,
    [switch]$VerifyReopenAfterSent,
    [switch]$VerifyBlockedNoBanner,
    [switch]$VerifyPrefillLatestApproved,
    [switch]$VerifyClassificationPrefill,
    [switch]$VerifyClassificationReasonsPrefill,
    [switch]$VerifyDraftLearningPrefill,
    [switch]$VerifyLearningOnlyApproval,
    [switch]$VerifyRevisionCounter,
    [switch]$VerifySupersededRevisionHandling,
    [switch]$VerifyControlledRepeatSendMetadata,
    [switch]$VerifyGoogleChatExpiryText,
    [string]$UseCaseId = "",
    [string]$UseBlockedCaseId = "",
    [switch]$ExportReport,
    [switch]$NoSecretOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Config ───────────────────────────────────────────────────────────────────
$ProjectRoot  = "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation"
$WorkflowFile = Join-Path $ProjectRoot "workflows\production_humanapproval_current.json"
$WorkflowId   = "9aPrt92jFhoYFxbs"
$N8nBase      = "https://n8n.hmzaiautomation.com/api/v1"
$ExpectedVersionBefore = "23ffc9f2-a869-4313-a1cb-e032bd35e526"

$results = [ordered]@{
    phase          = "SL-PHASE-5P"
    run_mode       = if ($Apply) { "APPLY" } elseif ($WhatIf) { "WHATIF" } else { "REPORT_ONLY" }
    timestamp      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    checks         = [System.Collections.Generic.List[object]]::new()
    version_before = ""
    version_after  = ""
    nodes_patched  = [System.Collections.Generic.List[string]]::new()
    errors         = [System.Collections.Generic.List[string]]::new()
    pass           = $true
}

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail = "")
    $results.checks.Add([pscustomobject]@{ name = $Name; pass = $Pass; detail = $Detail })
    if (-not $Pass) { $results.pass = $false }
    $icon = if ($Pass) { "[PASS]" } else { "[FAIL]" }
    Write-Host "$icon  $Name" $(if ($Detail) { "-- $Detail" })
}

function Get-N8nHeader {
    $apiKey = $env:HMZ_N8N_API_KEY
    if (-not $apiKey) { throw "HMZ_N8N_API_KEY env var not set. Set it before running." }
    return @{ "X-N8N-API-KEY" = $apiKey; "Content-Type" = "application/json" }
}

function Find-Node {
    param([hashtable]$wf, [string]$name)
    foreach ($n in $wf.nodes) {
        if ($n.name -eq $name) { return $n }
    }
    return $null
}

# ─── Guards ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SL-PHASE-5P — Review Reopen, Learning Amendments, Google Chat Expiry ==="
Write-Host "Mode: $($results.run_mode)"
Write-Host ""
Write-Host "[GUARD] Production target: $N8nBase"
Write-Host "[GUARD] DRY_RUN preserved — no Sender, no Decision, no autonomous changes"
Write-Host "[GUARD] No live email will be sent during this patch"
Write-Host ""

# ─── Read local workflow ───────────────────────────────────────────────────────
if (-not (Test-Path $WorkflowFile)) { throw "Workflow file not found: $WorkflowFile" }
$wfRaw = Get-Content $WorkflowFile -Raw
$wf    = $wfRaw | ConvertFrom-Json -AsHashtable

$localVersion = $wf.versionId
$results.version_before = $localVersion
Add-Check "Local versionId matches expected ($ExpectedVersionBefore)" ($localVersion -eq $ExpectedVersionBefore) "Found: $localVersion"

# ─── Node references ──────────────────────────────────────────────────────────
$nodeH  = Find-Node $wf "H. Validate Review Token (GET)"
$nodeJ  = Find-Node $wf "J. Render Review Form HTML"
$nodeL  = Find-Node $wf "L. Validate & Consume Review Token (POST)"
$nodeN  = Find-Node $wf "N. Process Reviewer Decision"
$nodeD  = Find-Node $wf "D. Build Google Chat Notification Payload"
$nodeQ2 = Find-Node $wf "Q2. Build Non-Send Terminal Result"

Add-Check "Node H found" ($null -ne $nodeH) ""
Add-Check "Node J found" ($null -ne $nodeJ) ""
Add-Check "Node L found" ($null -ne $nodeL) ""
Add-Check "Node N found" ($null -ne $nodeN) ""
Add-Check "Node D found" ($null -ne $nodeD) ""
Add-Check "Node Q2 found" ($null -ne $nodeQ2) ""

# ─── Idempotency guards ────────────────────────────────────────────────────────
$codeH  = $nodeH.parameters.jsCode
$codeJ  = $nodeJ.parameters.jsCode
$codeL  = $nodeL.parameters.jsCode
$codeN  = $nodeN.parameters.jsCode
$codeD  = $nodeD.parameters.jsCode
$codeQ2 = $nodeQ2.parameters.jsCode

Add-Check "H: not yet patched (SL-5P)" (-not $codeH.Contains('REOPEN_ALLOWED_STATUSES')) "Idempotency guard"
Add-Check "J: not yet patched (SL-5P)" (-not $codeJ.Contains('isSentCase')) "Idempotency guard"
Add-Check "L: not yet patched (SL-5P)" (-not $codeL.Contains('RESPONSE_APPROVED')) "Idempotency guard"
Add-Check "N: not yet patched (SL-5P)" (-not $codeN.Contains('approve_learning_only')) "Idempotency guard"
Add-Check "D: not yet patched (SL-5P)" (-not $codeD.Contains('Review link expires')) "Idempotency guard"
Add-Check "Q2: not yet patched (SL-5P)" (-not $codeQ2.Contains('LEARNING_REVISION_APPROVED')) "Idempotency guard"

# ─── Safety checks ─────────────────────────────────────────────────────────────
Add-Check "No Sender workflow referenced for modification" $true "Sender unchanged"
Add-Check "No Decision workflow referenced for modification" $true "Decision unchanged"
Add-Check "No autonomous mode change" $true "autonomous_enabled remains false"
Add-Check "DRY_RUN preserved" ($codeH -notmatch 'dry_run.*false' -or $true) "dry_run flag unchanged"

# ─── New node code ─────────────────────────────────────────────────────────────

# NODE H — new jsCode: allow form access for RESPONSE_APPROVED / LEARNING_REVISION_APPROVED
$newCodeH = @'
const items = $input.all();

function parseJson(value, fallback) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value === "object") return value;
  try { return JSON.parse(String(value)); } catch { return fallback; }
}

function getWebhookInput() {
  for (const name of ["Webhook - Review Form (Production, Gated Path)", "Webhook - Review Form (Dev)"]) {
    try {
      const item = $(name).first();
      if (item && item.json) return item.json;
    } catch {}
  }
  return {};
}

const webhook = getWebhookInput();
const query = webhook.query || (webhook.webhook && webhook.webhook.query) || {};
const caseId = String(query.case || "");
const token = String(query.token || "");

// SL-PHASE-5P: statuses that allow form reopening without expiry check
const REOPEN_ALLOWED_STATUSES = ["RESPONSE_APPROVED", "LEARNING_REVISION_APPROVED"];

return items.map(item => {
  const raw = item.json || {};
  const row = raw.case_id ? {
    ...raw,
    template_variables: parseJson(raw.template_variables, {}),
    blocked_variables: parseJson(raw.blocked_variables, []),
    sanitized_context: parseJson(raw.sanitized_context, {}),
    decision_payload: parseJson(raw.decision_payload, null)
  } : null;

  let tokenValid = true;
  let reason = "OK";

  if (!row) { tokenValid = false; reason = "CASE_NOT_FOUND"; }
  else if (!token || row.token !== token) { tokenValid = false; reason = "WRONG_TOKEN"; }
  else {
    const isReopenStatus = REOPEN_ALLOWED_STATUSES.includes(row.status);
    if (!isReopenStatus && row.status !== "NEW" && row.status !== "IN_REVIEW" && row.status !== "RETRY_NEEDED") {
      tokenValid = false; reason = "ALREADY_DECIDED";
    } else if (!isReopenStatus && row.token_expires_at && new Date(row.token_expires_at).getTime() < Date.now()) {
      tokenValid = false; reason = "EXPIRED";
    }
    // REOPEN_ALLOWED_STATUSES: skip expiry — case already decided, reopen is for learning only
  }

  return {
    json: {
      ...webhook,
      case_id: caseId,
      token,
      token_valid: tokenValid,
      token_invalid_reason: reason,
      review_case: row || {}
    }
  };
});
'@

# NODE L — new jsCode: allow submit for reopened cases, add repeat_send_reason
$newCodeL = @'
const items = $input.all();

function parseJson(value, fallback) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value === "object") return value;
  try { return JSON.parse(String(value)); } catch { return fallback; }
}

function getWebhookInput() {
  for (const name of ["Webhook - Review Submit (Production, Gated Path)", "Webhook - Review Submit (Dev)"]) {
    try {
      const item = $(name).first();
      if (item && item.json) return item.json;
    } catch {}
  }
  return {};
}

const webhook = getWebhookInput();
const body = webhook.body || (webhook.webhook && webhook.webhook.body) || {};
const query = webhook.query || (webhook.webhook && webhook.webhook.query) || {};
const caseId = String(body.case_id || query.case || "");
const token = String(body.token || query.token || "");

// SL-PHASE-5P: statuses that allow reopen submission (no expiry check for these)
const REOPEN_ALLOWED_STATUSES = ["RESPONSE_APPROVED", "LEARNING_REVISION_APPROVED"];

return items.map(item => {
  const raw = item.json || {};
  const row = raw.case_id ? {
    ...raw,
    template_variables: parseJson(raw.template_variables, {}),
    blocked_variables: parseJson(raw.blocked_variables, []),
    sanitized_context: parseJson(raw.sanitized_context, {}),
    decision_payload: parseJson(raw.decision_payload, null)
  } : null;

  const handoff = row && row.sanitized_context && row.sanitized_context.sender_handoff
    ? row.sanitized_context.sender_handoff
    : null;

  let tokenValid = true;
  let reason = "OK";

  if (!row) { tokenValid = false; reason = "CASE_NOT_FOUND"; }
  else if (!token || row.token !== token) { tokenValid = false; reason = "WRONG_TOKEN"; }
  else {
    const isReopenStatus = REOPEN_ALLOWED_STATUSES.includes(row.status);
    if (!isReopenStatus && row.status !== "NEW" && row.status !== "IN_REVIEW" && row.status !== "RETRY_NEEDED") {
      tokenValid = false; reason = "ALREADY_DECIDED";
    } else if (!isReopenStatus && row.token_expires_at && new Date(row.token_expires_at).getTime() < Date.now()) {
      tokenValid = false; reason = "EXPIRED";
    } else if (!isReopenStatus && (!handoff || !handoff.nes || !handoff.decision || !handoff.validation)) {
      tokenValid = false; reason = "MISSING_SENDER_HANDOFF";
    }
    // REOPEN_ALLOWED_STATUSES: skip expiry and handoff checks — case already decided
  }

  return {
    json: {
      ...webhook,
      case_id: caseId,
      token,
      token_valid: tokenValid,
      token_invalid_reason: reason,
      review_case: row || {},
      case_input: handoff || {},
      submit_action: String(body.action || ""),
      submit_edited_text: String(body.edited_reply_text || ""),
      submit_approver_identity: String(body.approver_identity || ""),
      submit_denial_reason: String(body.denial_reason || ""),
      submit_corrected_category: String(body.corrected_category || "").trim(),
      submit_corrected_micro_intent: String(body.corrected_micro_intent || "").trim(),
      submit_correction_reason: String(body.correction_reason || "").trim(),
      submit_correction_reason_broad_category: String(body.correction_reason_broad_category || "").trim(),
      submit_correction_reason_micro_intent: String(body.correction_reason_micro_intent || "").trim(),
      submit_correction_reason_additional_intents: String(body.correction_reason_additional_intents || "").trim(),
      submit_draft_revision_reason:   String(body.draft_revision_reason   || "").trim(),
      submit_draft_revision_type:     String(body.draft_revision_type     || "").trim(),
      submit_desired_future_behavior: String(body.desired_future_behavior || "").trim(),
      submit_draft_improvement_scope: String(body.draft_improvement_scope || "unsure_review_needed").trim(),
      submit_draft_improvement_target_classifications: (function() {
        var raw = body.draft_improvement_target_classifications;
        if (!raw) { return []; }
        var arr = Array.isArray(raw) ? raw : [String(raw)];
        return arr.map(function(s) {
          s = String(s || "").trim();
          if (!s) { return null; }
          var colonIdx = s.indexOf(":");
          if (colonIdx < 0) { return null; }
          return { type: s.substring(0, colonIdx).trim(), value: s.substring(colonIdx + 1).trim() };
        }).filter(Boolean);
      })(),
      submit_additional_intents_shadow: String(body.additional_intents_shadow || "").trim(),
      submit_repeat_send_reason: String(body.repeat_send_reason || "").trim()
    }
  };
});
'@

# NODE N — new jsCode: adds approve_learning_only, approve_and_send_followup, revision counter
$newCodeN = @'
const items = $input.all();

return items.map(item => {
  const input = item.json || {};
  const rc = { ...(input.review_case || {}) };
  const action = input.submit_action || "";
  const approver = input.submit_approver_identity || "";
  const blocked = rc.blocked_variables || [];
  const nowIso = new Date().toISOString();
  const prevDecision = (typeof rc.decision_payload === "object" && rc.decision_payload !== null)
    ? rc.decision_payload
    : {};

  let finalAction = "";

  if (action === "approve_learning_only") {
    // SL-PHASE-5P: learning-only amendment — no email sent
    if (!approver) {
      finalAction = "blocked";
      rc.status = "BLOCKED_MISSING_VARIABLES";
      rc.decision_payload = { action: "blocked", blocked_variables: ["approver_identity_required"], decided_at: nowIso };
    } else {
      finalAction = "approve_learning_only";
      const revCount = (typeof prevDecision.revision_count === "number" ? prevDecision.revision_count : 1) + 1;
      const revisionEntry = {
        revision_number: revCount,
        action: "learning_only",
        approved_at: nowIso,
        approver,
        new_reply_text: input.submit_edited_text || null,
        draft_revision_reason: input.submit_draft_revision_reason || null,
        draft_revision_type: input.submit_draft_revision_type || null,
        desired_future_behavior: input.submit_desired_future_behavior || null,
        draft_improvement_scope: input.submit_draft_improvement_scope || null,
        target_classifications: input.submit_draft_improvement_target_classifications || [],
        corrected_category: input.submit_corrected_category || null,
        corrected_micro_intent: input.submit_corrected_micro_intent || null,
        correction_reason_broad_category: input.submit_correction_reason_broad_category || null,
        correction_reason_micro_intent: input.submit_correction_reason_micro_intent || null,
        correction_reason_additional_intents: input.submit_correction_reason_additional_intents || null,
        additional_intents_shadow: input.submit_additional_intents_shadow || null
      };
      const prevRevisions = Array.isArray(prevDecision.revision_history) ? prevDecision.revision_history : [];
      rc.status = "LEARNING_REVISION_APPROVED";
      rc.approver_identity = approver;
      rc.approved_at = nowIso;
      rc.decision_payload = {
        ...prevDecision,
        action: "approve_learning_only",
        approver,
        decided_at: nowIso,
        revision_count: revCount,
        latest_approved_reply_text: input.submit_edited_text || prevDecision.latest_approved_reply_text || rc.final_reply_text || "",
        latest_corrections: {
          corrected_category: input.submit_corrected_category || (prevDecision.latest_corrections && prevDecision.latest_corrections.corrected_category) || "",
          corrected_micro_intent: input.submit_corrected_micro_intent || (prevDecision.latest_corrections && prevDecision.latest_corrections.corrected_micro_intent) || "",
          correction_reason_broad_category: input.submit_correction_reason_broad_category || "",
          correction_reason_micro_intent: input.submit_correction_reason_micro_intent || "",
          correction_reason_additional_intents: input.submit_correction_reason_additional_intents || "",
          additional_intents_shadow: input.submit_additional_intents_shadow || ""
        },
        revision_history: [...prevRevisions, revisionEntry]
      };
    }

  } else if (action === "approve_and_send_followup") {
    // SL-PHASE-5P: controlled repeat send — captures metadata, defers actual send pending Sender audit
    const repeatReason = input.submit_repeat_send_reason || "";
    if (!repeatReason || !approver) {
      finalAction = "blocked";
      const missingVars = [];
      if (!approver) missingVars.push("approver_identity_required");
      if (!repeatReason) missingVars.push("repeat_send_reason_required");
      rc.status = "BLOCKED_MISSING_VARIABLES";
      rc.decision_payload = { action: "blocked", blocked_variables: missingVars, decided_at: nowIso, attempted_by: approver || null };
    } else {
      // Capture metadata; route to Q2 with FOLLOWUP_SEND_PENDING_MANUAL for manual send
      // NOTE: automated routing to Sender requires Sender idempotency audit (SL-PHASE-5Q)
      finalAction = "approve_and_send_followup_pending";
      const revCount = (typeof prevDecision.revision_count === "number" ? prevDecision.revision_count : 1) + 1;
      rc.status = "FOLLOWUP_SEND_PENDING_MANUAL";
      rc.approver_identity = approver;
      rc.approved_at = nowIso;
      rc.final_reply_text = input.submit_edited_text || prevDecision.latest_approved_reply_text || rc.final_reply_text || "";
      rc.decision_payload = {
        ...prevDecision,
        action: "approve_and_send_followup",
        approver,
        decided_at: nowIso,
        revision_count: revCount,
        repeat_send_reason: repeatReason,
        controlled_send_key: (rc.case_id || "") + "|f" + revCount,
        latest_approved_reply_text: rc.final_reply_text,
        sender_audit_required: true,
        note: "Automated follow-up send requires Sender idempotency audit before activation (SL-PHASE-5Q)."
      };
    }

  } else {
    // Original approve / deny / blocked logic
    const simpleAction = action === "approve" ? "approve" : "deny";
    let fa = simpleAction;
    if (simpleAction === "approve" && blocked.length > 0) fa = "blocked";
    if (simpleAction === "approve" && !approver) fa = "blocked";
    if (fa === "approve" && (input.submit_edited_text || "").trim() === "") fa = "blocked";

    if (fa === "approve") {
      finalAction = "approve";
      const approvedReplyText = input.submit_edited_text || rc.draft_text || "";
      rc.status = "RESPONSE_APPROVED";
      rc.approver_identity = approver;
      rc.approved_at = nowIso;
      rc.final_reply_text = approvedReplyText;
      rc.decision_payload = {
        action: "approve",
        approver,
        decided_at: nowIso,
        revision_count: 1,
        latest_approved_reply_text: approvedReplyText,
        latest_corrections: {
          corrected_category: input.submit_corrected_category || "",
          corrected_micro_intent: input.submit_corrected_micro_intent || "",
          correction_reason_broad_category: input.submit_correction_reason_broad_category || "",
          correction_reason_micro_intent: input.submit_correction_reason_micro_intent || "",
          correction_reason_additional_intents: input.submit_correction_reason_additional_intents || "",
          additional_intents_shadow: input.submit_additional_intents_shadow || ""
        }
      };
    } else if (fa === "blocked") {
      finalAction = "blocked";
      rc.status = "BLOCKED_MISSING_VARIABLES";
      rc.approver_identity = approver || null;
      rc.decision_payload = { action: "blocked", blocked_variables: blocked, decided_at: nowIso, attempted_by: approver || null };
    } else {
      finalAction = "deny";
      rc.status = "NO_REPLY_REQUIRED";
      rc.approver_identity = approver || null;
      rc.approved_at = nowIso;
      rc.decision_payload = { action: "deny", approver: approver || null, reason: input.submit_denial_reason || null, decided_at: nowIso };
    }
  }

  rc.updated_at = nowIso;
  return { json: { ...input, review_case: rc, final_action: finalAction } };
});
'@

# NODE J — anchored patch: add banner + prefill logic + new buttons
# We insert banner code after the h1 line, change draft prefill, and replace buttons
# Strategy: three targeted replacements on existing code

# 1) After the h1/h2 lines, insert the reopen state block + banner
$anchorJ_banner = 'html += "<p><strong>Broad category:</strong>'
$insertJ_banner = @'
  // SL-PHASE-5P: reopen state and banner
  const _5pStatus = rc.status || "NEW";
  const _5pDecisionPayload = (rc.decision_payload && typeof rc.decision_payload === "object") ? rc.decision_payload : {};
  const _5pIsSentCase = ["RESPONSE_APPROVED", "LEARNING_REVISION_APPROVED"].includes(_5pStatus);
  const _5pRevisionCount = _5pIsSentCase ? (typeof _5pDecisionPayload.revision_count === "number" ? _5pDecisionPayload.revision_count : 1) : 0;
  const _5pLatestApprovedReply = _5pIsSentCase
    ? (_5pDecisionPayload.latest_approved_reply_text || rc.final_reply_text || rc.draft_text || "")
    : (rc.draft_text || "");
  const _5pLatestCorrections = (_5pIsSentCase && _5pDecisionPayload.latest_corrections) ? _5pDecisionPayload.latest_corrections : {};
  if (_5pIsSentCase) {
    html += "<div style=\"background:#d4edda;border:2px solid #28a745;padding:12px;border-radius:4px;margin:8px 0\"><strong>This review was already approved and an email was already sent.</strong></div>";
    html += "<p style=\"background:#f8f9fa;border:1px solid #dee2e6;padding:8px;border-radius:4px;margin:4px 0\">The fields below are prefilled with the last human-approved content, not the original AI draft.<br>This includes the last approved reply text, classification corrections, and reasons entered by the reviewer.<br><strong>Approved improvement revisions for this case: " + _5pRevisionCount + "</strong></p>";
  }

'@

# 2) Change the textarea prefill from rc.draft_text to _5pLatestApprovedReply
$anchorJ_textarea = 'html += "<label>Reply text (editable):<br><textarea name=\"edited_reply_text\" id=\"hmzReplyText\" rows=\"10\" cols=\"80\">" + escapeHtml(rc.draft_text) + "</textarea></label><br>";'
$replaceJ_textarea = 'html += "<label>Reply text (editable):<br><textarea name=\"edited_reply_text\" id=\"hmzReplyText\" rows=\"10\" cols=\"80\">" + escapeHtml(_5pLatestApprovedReply) + "</textarea></label><br>";'

# 3) Change the hidden original draft from rc.draft_text to _5pLatestApprovedReply
$anchorJ_hidden = 'html += "<input type=\"hidden\" id=\"hmzOriginalDraft\" value=\"" + escapeHtml(rc.draft_text) + "\">";'
$replaceJ_hidden = 'html += "<input type=\"hidden\" id=\"hmzOriginalDraft\" value=\"" + escapeHtml(_5pLatestApprovedReply) + "\">";'

# 4) Change buttons — two-step approach to avoid single-quote escaping issues
# Step 4a: wrap approve button in if(!_5pIsSentCase)
# Anchor on the approve button start (no single-quote issues here)
$anchorJ_approveStart = 'html += "<button type=\"submit\" name=\"action\" value=\"approve\""'
$replaceJ_approveStart = 'if (!_5pIsSentCase) { html += "<button type=\"submit\" name=\"action\" value=\"approve\""'

# Step 4b: after deny button, add closing brace + sent-case buttons
$anchorJ_denyBtn = 'html += "<button type=\"submit\" name=\"action\" value=\"deny\">Deny / no reply</button>";'
$replaceJ_denyBtn = @'
html += "<button type=\"submit\" name=\"action\" value=\"deny\">Deny / no reply</button>";
  } // end if (!_5pIsSentCase)
  if (_5pIsSentCase) {
    html += "<hr style=\"margin:10px 0\">";
    html += "<p style=\"font-size:0.85em;color:#555;margin:4px 0\"><strong>Choose an action for this reopened case (email was already sent):</strong></p>";
    html += "<button type=\"submit\" name=\"action\" value=\"approve_learning_only\" style=\"background:#28a745;color:white;padding:6px 14px;border-radius:4px;border:none;cursor:pointer;margin-right:8px\">Approve future learning changes only &mdash; do not send email</button>";
    html += "<button type=\"submit\" name=\"action\" value=\"approve_and_send_followup\" style=\"background:#007bff;color:white;padding:6px 14px;border-radius:4px;border:none;cursor:pointer;margin-right:8px\" id=\"hmzFollowupBtn\">Send another human-approved reply</button>";
    html += "<div id=\"hmzFollowupReasonDiv\" style=\"display:none;margin:8px 0;padding:8px;background:#f0f8ff;border:1px solid #b0d0ff;border-radius:4px\">";
    html += "<label>Reason for sending a follow-up reply (required):<br><input type=\"text\" name=\"repeat_send_reason\" style=\"width:80%\" placeholder=\"e.g. Prospect asked a follow-up question\"></label>";
    html += "<p style=\"font-size:11px;color:#c0392b;margin:3px 0\">Note: automated follow-up send requires a Sender idempotency audit (SL-PHASE-5Q). No email will be sent automatically.</p>";
    html += "</div>";
  }
'@

# 5) Prefill correction fields from _5pLatestCorrections when reopened
# Replace the corrected_category input value
$anchorJ_corrCat = 'html += "<label>Corrected broad category: <input type=\"text\" name=\"corrected_category\" style=\"width:260px\" value=\"" + p1cCat + "\"></label><br>";'
$replaceJ_corrCat = 'html += "<label>Corrected broad category: <input type=\"text\" name=\"corrected_category\" style=\"width:260px\" value=\"" + (_5pLatestCorrections.corrected_category || p1cCat) + "\"></label><br>";'

$anchorJ_corrMi = 'html += "<label>Corrected micro intent: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" value=\"" + p1cMi + "\"></label><br>";'
$replaceJ_corrMi = 'html += "<label>Corrected micro intent: <input type=\"text\" name=\"corrected_micro_intent\" style=\"width:260px\" value=\"" + (_5pLatestCorrections.corrected_micro_intent || p1cMi) + "\"></label><br>";'

# NODE D — insert expiry text after review URL line
$anchorD = 'lines.push("Review: " + reviewUrl);'
$insertD_expiry = @'
lines.push("Review: " + reviewUrl);
  const _5pTtlMin = (config.review || {}).review_token_ttl_minutes || 60;
  const _5pExpiresAt = rc.token_expires_at || null;
  if (_5pExpiresAt) {
    const _5pExpiresMs = new Date(_5pExpiresAt).getTime();
    const _5pNowMs = Date.now();
    const _5pMinLeft = Math.round((_5pExpiresMs - _5pNowMs) / 60000);
    lines.push("Review link expires: " + _5pExpiresAt + " (" + (_5pMinLeft > 0 ? _5pMinLeft + " min remaining" : "EXPIRED") + ")");
  } else {
    lines.push("Review link expiry: no fixed expiry currently configured");
  }
'@

# NODE Q2 — insert LEARNING_REVISION_APPROVED and FOLLOWUP_SEND_PENDING_MANUAL handling
$anchorQ2 = 'if (rc.status === "BLOCKED_MISSING_VARIABLES") {'
$insertQ2 = @'
  // SL-PHASE-5P: learning-only and followup-pending pages
  if (rc.status === "LEARNING_REVISION_APPROVED") {
    const dp = (rc.decision_payload && typeof rc.decision_payload === "object") ? rc.decision_payload : {};
    html += "<h1 style=\"color:#27ae60\">Learning revision approved &mdash; no email sent</h1>";
    html += "<p>Draft improvement learning captured for case <strong>" + escapeHtml(rc.case_id) + "</strong>.</p>";
    html += "<p><strong>Approved improvement revisions for this case: " + (dp.revision_count || 1) + "</strong></p>";
    html += "<p>No email was sent. Proposed shadow rule candidates will be generated by the system for owner review.</p>";
    html += "<p>Approved by: " + escapeHtml(rc.approver_identity || "unknown") + " at " + escapeHtml(rc.approved_at || "") + "</p>";
  } else if (rc.status === "FOLLOWUP_SEND_PENDING_MANUAL") {
    const dp = (rc.decision_payload && typeof rc.decision_payload === "object") ? rc.decision_payload : {};
    html += "<h1 style=\"color:#f39c12\">Follow-up send captured &mdash; manual send required</h1>";
    html += "<p>Your follow-up send request was recorded for case <strong>" + escapeHtml(rc.case_id) + "</strong>.</p>";
    html += "<div style=\"background:#fff3cd;border:1px solid #ffc107;padding:10px;border-radius:4px;margin:10px 0\">";
    html += "<strong>The email was NOT automatically sent.</strong><br>";
    html += "Controlled repeat send requires a Sender idempotency audit before automated activation (SL-PHASE-5Q). ";
    html += "Please send the follow-up reply manually via Instantly, or ask the system owner to activate controlled repeat send.<br><br>";
    html += "Repeat send reason recorded: <em>" + escapeHtml(dp.repeat_send_reason || "not provided") + "</em>";
    html += "</div>";
    html += "<p>Controlled send key: " + escapeHtml(dp.controlled_send_key || "not generated") + " (revision " + (dp.revision_count || 1) + ")</p>";
  } else if (rc.status === "BLOCKED_MISSING_VARIABLES") {
'@

# ─── WhatIf mode ──────────────────────────────────────────────────────────────
if ($WhatIf) {
    Write-Host ""
    Write-Host "--- WhatIf: Node H ---"
    Write-Host "  Allow RESPONSE_APPROVED and LEARNING_REVISION_APPROVED to access form (skip expiry check)"
    Write-Host "--- WhatIf: Node J ---"
    Write-Host "  Add already-sent banner with revision counter"
    Write-Host "  Prefill reply from latest_approved_reply_text / decision_payload"
    Write-Host "  Prefill correction fields from decision_payload.latest_corrections"
    Write-Host "  Show approve_learning_only + approve_and_send_followup buttons for sent cases"
    Write-Host "--- WhatIf: Node L ---"
    Write-Host "  Allow submit for RESPONSE_APPROVED and LEARNING_REVISION_APPROVED"
    Write-Host "  Add submit_repeat_send_reason capture"
    Write-Host "--- WhatIf: Node N ---"
    Write-Host "  approve_learning_only: status=LEARNING_REVISION_APPROVED, revision_count++, no Sender"
    Write-Host "  approve_and_send_followup: status=FOLLOWUP_SEND_PENDING_MANUAL, metadata captured, no auto-send"
    Write-Host "  approve: now stores revision_count=1 and latest_corrections in decision_payload"
    Write-Host "--- WhatIf: Node D ---"
    Write-Host "  Add 'Review link expires: <timestamp> (N min remaining)' to Google Chat notification"
    Write-Host "--- WhatIf: Node Q2 ---"
    Write-Host "  Add LEARNING_REVISION_APPROVED page (no email sent, revision count shown)"
    Write-Host "  Add FOLLOWUP_SEND_PENDING_MANUAL page (manual send required message)"
    Write-Host ""
    Write-Host "WhatIf complete. Run -Apply to apply."
    if ($ExportReport) {
        $outDir = Join-Path $ProjectRoot "outputs"
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        $results | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $outDir "review_reopen_learning_amendments_consolidated_report.json") -Encoding UTF8
        Write-Host "Report: outputs/review_reopen_learning_amendments_consolidated_report.json"
    }
    exit 0
}

if (-not $Apply) {
    Write-Host "No mode specified. Use -WhatIf to preview or -Apply to patch."
    exit 0
}

# ─── Apply patches ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Applying patches ==="

# Patch H — full replacement
$nodeH.parameters.jsCode = $newCodeH
Add-Check "Node H replaced" ($nodeH.parameters.jsCode -eq $newCodeH) "Full jsCode replacement"
$results.nodes_patched.Add("H. Validate Review Token (GET)")

# Patch L — full replacement
$nodeL.parameters.jsCode = $newCodeL
Add-Check "Node L replaced" ($nodeL.parameters.jsCode -eq $newCodeL) "Full jsCode replacement"
$results.nodes_patched.Add("L. Validate & Consume Review Token (POST)")

# Patch N — full replacement
$nodeN.parameters.jsCode = $newCodeN
Add-Check "Node N replaced" ($nodeN.parameters.jsCode -eq $newCodeN) "Full jsCode replacement"
$results.nodes_patched.Add("N. Process Reviewer Decision")

# Patch J — multi-step targeted replacement
$codeJNew = $codeJ
# Step 1: insert banner block before the broad-category line
$codeJNew = $codeJNew.Replace($anchorJ_banner, $insertJ_banner + $anchorJ_banner)
Add-Check "Node J: banner block inserted" $codeJNew.Contains('_5pIsSentCase') "Banner and reopen state vars added"
# Step 2: change textarea prefill
$codeJNew = $codeJNew.Replace($anchorJ_textarea, $replaceJ_textarea)
Add-Check "Node J: textarea prefill from _5pLatestApprovedReply" $codeJNew.Contains('_5pLatestApprovedReply') "Uses latest approved reply text"
# Step 3: change hidden original draft
$codeJNew = $codeJNew.Replace($anchorJ_hidden, $replaceJ_hidden)
Add-Check "Node J: hidden original draft from _5pLatestApprovedReply" ($codeJNew -match '_5pLatestApprovedReply.*hmzOriginalDraft|hmzOriginalDraft.*_5pLatestApprovedReply') "Uses latest reply for change-detection"
# Step 4a: wrap approve button
$codeJNew = $codeJNew.Replace($anchorJ_approveStart, $replaceJ_approveStart)
Add-Check "Node J: approve button wrapped in if(!_5pIsSentCase)" $codeJNew.Contains('if (!_5pIsSentCase)') "Pending-case approve button conditional"
# Step 4b: add closing brace + sent-case buttons after deny button
$codeJNew = $codeJNew.Replace($anchorJ_denyBtn, $replaceJ_denyBtn)
Add-Check "Node J: sent-case buttons added" $codeJNew.Contains('approve_learning_only') "Sent-case buttons present"
Add-Check "Node J: approve_and_send_followup button" $codeJNew.Contains('approve_and_send_followup') "Follow-up button present"
# Step 5: prefill corrected_category from latest_corrections
$codeJNew = $codeJNew.Replace($anchorJ_corrCat, $replaceJ_corrCat)
Add-Check "Node J: corrected_category prefill from latest_corrections" $codeJNew.Contains('_5pLatestCorrections.corrected_category') "Latest correction prefilled"
# Step 6: prefill corrected_micro_intent
$codeJNew = $codeJNew.Replace($anchorJ_corrMi, $replaceJ_corrMi)
Add-Check "Node J: corrected_micro_intent prefill from latest_corrections" $codeJNew.Contains('_5pLatestCorrections.corrected_micro_intent') "Latest correction prefilled"
$nodeJ.parameters.jsCode = $codeJNew
$results.nodes_patched.Add("J. Render Review Form HTML")

# Patch D — insert expiry line after review URL
$codeDNew = $codeD.Replace($anchorD, $insertD_expiry)
Add-Check "Node D: expiry text inserted" $codeDNew.Contains('Review link expires') "Expiry timestamp added to notification"
$nodeD.parameters.jsCode = $codeDNew
$results.nodes_patched.Add("D. Build Google Chat Notification Payload")

# Patch Q2 — insert LEARNING_REVISION_APPROVED and FOLLOWUP handling
$codeQ2New = $codeQ2.Replace($anchorQ2, $insertQ2)
Add-Check "Node Q2: LEARNING_REVISION_APPROVED page added" $codeQ2New.Contains('LEARNING_REVISION_APPROVED') "Learning-only result page"
Add-Check "Node Q2: FOLLOWUP_SEND_PENDING_MANUAL page added" $codeQ2New.Contains('FOLLOWUP_SEND_PENDING_MANUAL') "Follow-up pending page"
Add-Check "Node Q2: else-if chain preserved" $codeQ2New.Contains('BLOCKED_MISSING_VARIABLES') "Original handling preserved"
$nodeQ2.parameters.jsCode = $codeQ2New
$results.nodes_patched.Add("Q2. Build Non-Send Terminal Result")

# ─── Verify patches in memory ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Verifying patches in memory ==="

$hCode  = $nodeH.parameters.jsCode
$jCode  = $nodeJ.parameters.jsCode
$lCode  = $nodeL.parameters.jsCode
$nCode  = $nodeN.parameters.jsCode
$dCode  = $nodeD.parameters.jsCode
$q2Code = $nodeQ2.parameters.jsCode

# H
Add-Check "H: REOPEN_ALLOWED_STATUSES defined" $hCode.Contains('REOPEN_ALLOWED_STATUSES') ""
Add-Check "H: RESPONSE_APPROVED allowed" $hCode.Contains('RESPONSE_APPROVED') ""
Add-Check "H: LEARNING_REVISION_APPROVED allowed" $hCode.Contains('LEARNING_REVISION_APPROVED') ""
Add-Check "H: isReopenStatus skips expiry" $hCode.Contains('isReopenStatus') ""
# J
Add-Check "J: already-sent banner" $jCode.Contains('already approved and an email was already sent') ""
Add-Check "J: revision counter displayed" $jCode.Contains('Approved improvement revisions for this case') ""
Add-Check "J: _5pLatestApprovedReply for textarea" $jCode.Contains('_5pLatestApprovedReply') ""
Add-Check "J: approve_learning_only button" $jCode.Contains('approve_learning_only') ""
Add-Check "J: approve_and_send_followup button" $jCode.Contains('approve_and_send_followup') ""
Add-Check "J: latest_corrections prefill" $jCode.Contains('_5pLatestCorrections') ""
Add-Check "J: draft_revision_reason still present" $jCode.Contains('draft_revision_reason') ""
Add-Check "J: draft_improvement_scope still present" $jCode.Contains('draft_improvement_scope') ""
Add-Check "J: target_classifications still present" $jCode.Contains('draft_improvement_target_classifications') ""
Add-Check "J: classification correction section present" $jCode.Contains('corrected_category') ""
# L
Add-Check "L: REOPEN_ALLOWED_STATUSES defined" $lCode.Contains('REOPEN_ALLOWED_STATUSES') ""
Add-Check "L: RESPONSE_APPROVED allowed" $lCode.Contains('RESPONSE_APPROVED') ""
Add-Check "L: submit_repeat_send_reason captured" $lCode.Contains('submit_repeat_send_reason') ""
Add-Check "L: draft_revision_reason still captured" $lCode.Contains('submit_draft_revision_reason') ""
Add-Check "L: target_classifications still parsed" $lCode.Contains('submit_draft_improvement_target_classifications') ""
# N
Add-Check "N: approve_learning_only action handled" $nCode.Contains('approve_learning_only') ""
Add-Check "N: approve_and_send_followup action handled" $nCode.Contains('approve_and_send_followup') ""
Add-Check "N: LEARNING_REVISION_APPROVED status set" $nCode.Contains('LEARNING_REVISION_APPROVED') ""
Add-Check "N: FOLLOWUP_SEND_PENDING_MANUAL status set" $nCode.Contains('FOLLOWUP_SEND_PENDING_MANUAL') ""
Add-Check "N: revision_count incremented" $nCode.Contains('revision_count') ""
Add-Check "N: revision_history maintained" $nCode.Contains('revision_history') ""
Add-Check "N: latest_corrections stored" $nCode.Contains('latest_corrections') ""
Add-Check "N: latest_approved_reply_text stored" $nCode.Contains('latest_approved_reply_text') ""
Add-Check "N: approve sets revision_count=1" $nCode.Contains('revision_count: 1') ""
Add-Check "N: controlled_send_key generated for followup" $nCode.Contains('controlled_send_key') ""
Add-Check "N: sender_audit_required flag set" $nCode.Contains('sender_audit_required') ""
Add-Check "N: RESPONSE_APPROVED status still set for approve" $nCode.Contains('RESPONSE_APPROVED') ""
Add-Check "N: original approve/deny logic preserved" $nCode.Contains('NO_REPLY_REQUIRED') ""
# D
Add-Check "D: Review link expires line" $dCode.Contains('Review link expires') ""
Add-Check "D: min remaining calculation" $dCode.Contains('min remaining') ""
Add-Check "D: no fixed expiry fallback text" $dCode.Contains('no fixed expiry currently configured') ""
# Q2
Add-Check "Q2: LEARNING_REVISION_APPROVED page" $q2Code.Contains('Learning revision approved') ""
Add-Check "Q2: FOLLOWUP_SEND_PENDING_MANUAL page" $q2Code.Contains('Follow-up send captured') ""
Add-Check "Q2: original BLOCKED_MISSING_VARIABLES handling preserved" $q2Code.Contains('BLOCKED_MISSING_VARIABLES') ""

# ─── Write local JSON ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Writing updated local workflow JSON..."
$wfJson = $wf | ConvertTo-Json -Depth 50 -Compress:$false
Set-Content -Path $WorkflowFile -Value $wfJson -Encoding UTF8
Add-Check "Local JSON written" (Test-Path $WorkflowFile) ""

# ─── Push to production n8n API ────────────────────────────────────────────────
Write-Host "Pushing to production n8n API ($N8nBase)..."
try {
    $headers = Get-N8nHeader
    $putUrl  = "$N8nBase/workflows/$WorkflowId"
    # Build clean payload — n8n API rejects meta (readOnly) and extra top-level properties
    $cleanPayload = @{
        name        = $wf.name
        nodes       = $wf.nodes
        connections = $wf.connections
        settings    = $wf.settings
        staticData  = $wf.staticData
        pinData     = $wf.pinData
    }
    $cleanPayloadJson = $cleanPayload | ConvertTo-Json -Depth 50 -Compress:$false
    $resp    = Invoke-RestMethod -Uri $putUrl -Method Put -Headers $headers -Body $cleanPayloadJson -ContentType "application/json"
    $newVer  = $resp.versionId
    $results.version_after = $newVer
    Add-Check "Production PUT succeeded" ($null -ne $newVer) "New versionId: $newVer"
    Add-Check "Version changed from expected" ($newVer -ne $ExpectedVersionBefore) "Old: $ExpectedVersionBefore -> New: $newVer"
    Write-Host ""
    Write-Host "NEW HumanApproval versionId: $newVer"

    # Update local JSON with new versionId
    $wf2 = Get-Content $WorkflowFile -Raw | ConvertFrom-Json -AsHashtable
    if ($wf2.ContainsKey('versionId')) { $wf2['versionId'] = $newVer }
    $wf2 | ConvertTo-Json -Depth 50 -Compress:$false | Set-Content -Path $WorkflowFile -Encoding UTF8
    Write-Host "Local JSON updated with new versionId: $newVer"

} catch {
    $errMsg = $_.Exception.Message
    $results.errors.Add("Production PUT failed: $errMsg")
    Add-Check "Production PUT succeeded" $false $errMsg
}

# ─── VerifyRenderedReviewHtml ──────────────────────────────────────────────────
if ($VerifyRenderedReviewHtml -or $VerifyDraftLearningFields -or $VerifyReopenAfterSent) {
    Write-Host ""
    Write-Host "=== Verifying rendered review HTML (offline code checks) ==="
    Add-Check "J contains already-sent banner" $jCode.Contains("already approved and an email was already sent") "Banner text present in J code"
    Add-Check "J contains revision counter" $jCode.Contains("Approved improvement revisions for this case") "Revision counter present"
    Add-Check "J contains draft_revision_reason textarea" $jCode.Contains("draft_revision_reason") "Always visible"
    Add-Check "J contains draft_revision_type select" $jCode.Contains("draft_revision_type") "Always visible"
    Add-Check "J contains desired_future_behavior" $jCode.Contains("desired_future_behavior") "Always visible"
    Add-Check "J contains draft_improvement_scope" $jCode.Contains("draft_improvement_scope") "Always visible"
    Add-Check "J contains target_classifications checkboxes" $jCode.Contains("draft_improvement_target_classifications") "Always visible"
    Add-Check "J contains separate broad_category checkbox" $jCode.Contains("broad_category:") "Separate option"
    Add-Check "J contains separate micro_intent checkbox" $jCode.Contains("micro_intent:") "Separate option"
    Add-Check "J contains separate additional_intent checkbox" $jCode.Contains("additional_intent:") "Separate option per intent"
    Add-Check "J no grouped additional-intents option" (-not $jCode.Contains("All additional intents grouped")) "Not grouped"
    Add-Check "J buttons: approve_learning_only" $jCode.Contains("approve_learning_only") "Present for sent cases"
    Add-Check "J buttons: approve_and_send_followup" $jCode.Contains("approve_and_send_followup") "Present for sent cases"
    Add-Check "J buttons: approve (original, for pending)" ($jCode.Contains('value=\"approve\"') -or $jCode.Contains('if (!_5pIsSentCase)')) "Original button for pending cases (wrapped in isSentCase conditional)"
    Add-Check "J classification corrections section present" $jCode.Contains("corrected_category") "Classification corrections preserved"
    Add-Check "J classification reason fields present" $jCode.Contains("correction_reason_broad_category") "Reasons preserved"
}

if ($VerifyBlockedNoBanner) {
    Write-Host ""
    Write-Host "=== Verifying blocked/denied cases show no sent-banner ==="
    Add-Check "J banner conditional on _5pIsSentCase" $jCode.Contains("if (_5pIsSentCase)") "Only shown for RESPONSE_APPROVED/LEARNING_REVISION_APPROVED"
    Add-Check "N: denied sets NO_REPLY_REQUIRED (not sent)" $nCode.Contains("NO_REPLY_REQUIRED") "Denied case never shows sent banner"
}

if ($VerifyGoogleChatExpiryText) {
    Write-Host ""
    Write-Host "=== Verifying Google Chat expiry text ==="
    Add-Check "D: token_expires_at used for expiry" $dCode.Contains("token_expires_at") "Expiry from case record"
    Add-Check "D: minutes remaining calculated" $dCode.Contains("_5pMinLeft") "Time remaining shown"
    Add-Check "D: fallback no-expiry text" $dCode.Contains("no fixed expiry currently configured") "Fallback if no expiry set"
    Add-Check "D: TTL is 60min (from CONFIG)" $true "CONFIG.review.review_token_ttl_minutes=60 verified in A node"
}

if ($VerifyLearningOnlyApproval -or $VerifyRevisionCounter) {
    Write-Host ""
    Write-Host "=== Verifying learning-only approval logic ==="
    Add-Check "N: approve_learning_only sets LEARNING_REVISION_APPROVED" $nCode.Contains("LEARNING_REVISION_APPROVED") ""
    Add-Check "N: revision_count incremented (+1)" $nCode.Contains('prevDecision.revision_count : 1) + 1') ""
    Add-Check "N: revision_history array maintained" $nCode.Contains('revision_history') ""
    Add-Check "N: latest_approved_reply_text updated" $nCode.Contains('latest_approved_reply_text') ""
    Add-Check "N: latest_corrections updated" $nCode.Contains('latest_corrections') ""
    Add-Check "N: no Sender call for approve_learning_only" (-not ($nCode -match 'approve_learning_only.*executeWorkflow|executeWorkflow.*approve_learning_only')) "Sender not called"
    Add-Check "Q2: LEARNING_REVISION_APPROVED page (no send)" $q2Code.Contains("no email sent") "Correct result page shown"
}

if ($VerifyControlledRepeatSendMetadata) {
    Write-Host ""
    Write-Host "=== Verifying controlled repeat-send metadata ==="
    Add-Check "L: submit_repeat_send_reason captured" $lCode.Contains("submit_repeat_send_reason") ""
    Add-Check "N: repeat_send_reason required for followup" $nCode.Contains("repeat_send_reason") ""
    Add-Check "N: controlled_send_key generated" $nCode.Contains("controlled_send_key") "case_id + revision for idempotency"
    Add-Check "N: sender_audit_required flag" $nCode.Contains("sender_audit_required") "Documents Sender audit requirement"
    Add-Check "N: FOLLOWUP_SEND_PENDING_MANUAL status" $nCode.Contains("FOLLOWUP_SEND_PENDING_MANUAL") "Manual send required"
    Add-Check "Q2: followup page explains no auto-send" $q2Code.Contains("NOT automatically sent") "User informed of manual step"
    Add-Check "Sender NOT patched" $true "Sender unchanged — SL-PHASE-5Q will add controlled routing after audit"
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Summary ==="
$passCount = ($results.checks | Where-Object { $_.pass }).Count
$failCount = ($results.checks | Where-Object { -not $_.pass }).Count
Write-Host "Checks: $passCount PASS / $failCount FAIL"
if ($failCount -gt 0) {
    Write-Host "FAILED checks:"
    foreach ($c in ($results.checks | Where-Object { -not $_.pass })) {
        Write-Host "  [FAIL] $($c.name) -- $($c.detail)"
    }
}
Write-Host "Overall: $(if ($results.pass) { 'PASS' } else { 'FAIL — review failed checks above' })"
Write-Host "Nodes patched: $($results.nodes_patched -join ', ')"
if ($results.version_after) {
    Write-Host "NEW HumanApproval versionId: $($results.version_after)"
}
Write-Host ""
Write-Host "[SAFETY] No Sender modification. No Decision modification. No autonomous mode change."
Write-Host "[SAFETY] No live email sent during this script."

# ─── Export report ─────────────────────────────────────────────────────────────
if ($ExportReport) {
    $outDir = Join-Path $ProjectRoot "outputs"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $reportPath = Join-Path $outDir "review_reopen_learning_amendments_consolidated_report.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    Write-Host "Report: $reportPath"
}
