param(
  [switch]$WhatIf,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

if (-not $WhatIf -and -not $Apply) {
  Write-Host "Usage:"
  Write-Host "  .\scripts\SL-PATCH-3.1-human-approval-context-chat.ps1 -WhatIf"
  Write-Host "  .\scripts\SL-PATCH-3.1-human-approval-context-chat.ps1 -Apply"
  return
}

if (-not $env:HMZ_N8N_API_KEY) {
  throw "STOP: HMZ_N8N_API_KEY is missing in this PowerShell session."
}

$BaseUrl = "https://n8n.hmzaiautomation.com/api/v1"
$Headers = @{
  "X-N8N-API-KEY" = $env:HMZ_N8N_API_KEY
  "Accept" = "application/json"
  "Content-Type" = "application/json"
}

$WorkflowIds = [ordered]@{
  Intake        = "VtDQqw02Ux1TgjIH"
  SLAWatchdog   = "6a8ojyXCwMwI9nyF"
  ErrorHandler  = "2PR9YEkG4KyGdowa"
  HumanApproval = "9aPrt92jFhoYFxbs"
  Decision      = "tgYmY97CG4Bm8snI"
  Sender        = "ePS5uBBxKxhFCYgU"
  TestHarness   = "RLUcJHQJPvLhw4mG"
}

$Ts = Get-Date -Format "yyyyMMddTHHmmssZ"
$BackupDir = Join-Path (Get-Location) "verification\patch-3.1-human-approval-context-chat\$Ts"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

function Get-Workflow($id) {
  Invoke-RestMethod -Method GET -Uri "$BaseUrl/workflows/$id" -Headers $Headers -TimeoutSec 40
}

function Save-WorkflowBackup($name, $wf) {
  $path = Join-Path $BackupDir "$name-$($wf.id).json"
  $wf | ConvertTo-Json -Depth 100 | Set-Content -Path $path -Encoding UTF8
  Write-Host "  BACKUP $name -> $path"
}

function Update-Workflow($id, $wf) {
  $body = [ordered]@{
    name = $wf.name
    nodes = $wf.nodes
    connections = $wf.connections
    settings = $wf.settings
  }

  if ($null -ne $wf.staticData) {
    $body["staticData"] = $wf.staticData
  }

  if ($null -ne $wf.pinData) {
    $body["pinData"] = $wf.pinData
  }

  $json = $body | ConvertTo-Json -Depth 100
  Invoke-RestMethod -Method PUT -Uri "$BaseUrl/workflows/$id" -Headers $Headers -Body $json -TimeoutSec 60
}

function Activate-IfNeeded($label, $id) {
  $wf = Get-Workflow $id
  if ($wf.active -eq $true) {
    Write-Host "  $label already active"
    return
  }

  Write-Host "  Activating $label"
  Invoke-RestMethod -Method POST -Uri "$BaseUrl/workflows/$id/activate" -Headers $Headers -TimeoutSec 40 | Out-Null
  Start-Sleep -Seconds 1

  $wf2 = Get-Workflow $id
  if ($wf2.active -ne $true) {
    throw "STOP: $label did not reactivate."
  }
}

Write-Host "=== SL-PATCH-3.1: HUMAN APPROVAL CONTEXT + CHAT PATCH ==="
Write-Host "Backup dir: $BackupDir"

Write-Host "`n[1/5] Backing up all 7 workflows..."
$all = @{}
foreach ($kv in $WorkflowIds.GetEnumerator()) {
  $wf = Get-Workflow $kv.Value
  $all[$kv.Key] = $wf
  Save-WorkflowBackup $kv.Key $wf
}

if ($all.TestHarness.active -eq $true) {
  throw "STOP: Full Test Harness is active. Refusing to patch."
}

$human = $all.HumanApproval
$caseNode = $human.nodes | Where-Object { $_.name -eq "A. Build Review Case Record" } | Select-Object -First 1
$chatNode = $human.nodes | Where-Object { $_.name -eq "D. Build Google Chat Notification Payload" } | Select-Object -First 1

if ($null -eq $caseNode) {
  throw "STOP: Could not find Human Approval node A. Build Review Case Record."
}

if ($null -eq $chatNode) {
  throw "STOP: Could not find Human Approval node D. Build Google Chat Notification Payload."
}

$oldCaseCode = [string]$caseNode.parameters.jsCode
$oldChatCode = [string]$chatNode.parameters.jsCode

if ($oldChatCode -match "From:" -and $oldChatCode -match "Sender:" -and $oldChatCode -match "micro_intent" -and $oldChatCode -match "draft_source") {
  Write-Host "`nPatch markers already present in Google Chat node."
}

$configBlock = "const CONFIG = {};"
if ($oldCaseCode -match "(?s)// HMZ_INJECT_BEGIN:RUNTIME_CONFIG.*?// HMZ_INJECT_END:RUNTIME_CONFIG") {
  $configBlock = $Matches[0]
}

$newCaseCode = @'
const items = $input.all();

// Runtime configuration is injected from config/business-ready.config.json at apply time.
__CONFIG_BLOCK__

function djb2Hash(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) + hash + str.charCodeAt(i);
    hash = hash & 0xffffffff;
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

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

function generateReviewToken() {
  return randomHex(16) + djb2Hash(String(Date.now()) + String(Math.random()));
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value === null || value === undefined) continue;
    const s = String(value).trim();
    if (s) return s;
  }
  return null;
}

function asObj(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function getCaseInput(input) {
  const direct = asObj(input.case_input);
  if (Object.keys(direct).length > 0) return direct;
  const nested = asObj(input.json && input.json.case_input);
  if (Object.keys(nested).length > 0) return nested;
  return input;
}

function resolveSenderConfig(eaccount, draft, config) {
  const draftConfig = asObj(draft.sender_config);
  const mapping = asObj(config.sender_mapping || {});
  const mapped = eaccount ? asObj(mapping[String(eaccount).toLowerCase()]) : {};

  const senderName = firstNonEmpty(
    draftConfig.senderName,
    draftConfig.sender_name,
    mapped.senderName,
    mapped.sender_name
  );

  const bookingLink = firstNonEmpty(
    draftConfig.bookingLink,
    draftConfig.booking_link,
    mapped.bookingLink,
    mapped.booking_link
  );

  return {
    senderName,
    sender_name: senderName,
    bookingLink,
    booking_link: bookingLink
  };
}

return items.map(item => {
  const input = item.json || {};
  const caseInput = getCaseInput(input);

  const nes = asObj(caseInput.nes || input.nes);
  const classifier = asObj(caseInput.classifier || input.classifier);
  const decision = asObj(caseInput.decision || input.decision || caseInput.safety_action_plan || input.safety_action_plan);
  const draft = asObj(caseInput.draft || input.draft);
  const validation = asObj(caseInput.validation || input.validation);

  const reply = asObj(nes.reply || caseInput.reply || input.reply);
  const campaignContext = asObj(nes.campaign_context || caseInput.campaign_context || input.campaign_context);

  const intakeId = firstNonEmpty(caseInput.intake_id, input.intake_id, nes.intake_id, reply.message_id, "UNKNOWN_INTAKE");
  const policyVersion = firstNonEmpty(caseInput.policy_version, input.policy_version, nes.policy_version, CONFIG.policy_version, "policy-HMZ-1.2");
  const caseId = "case-" + djb2Hash(intakeId + "|" + policyVersion);

  const ttlRaw = CONFIG.review && CONFIG.review.review_token_ttl_minutes;
  const ttlDefault = CONFIG.review && CONFIG.review.review_token_ttl_minutes_default;
  const ttlMinutes = (typeof ttlRaw === "number" && ttlRaw > 0) ? ttlRaw : ((typeof ttlDefault === "number" && ttlDefault > 0) ? ttlDefault : 120);

  const nowIso = new Date().toISOString();
  const expiresIso = new Date(Date.now() + ttlMinutes * 60000).toISOString();
  const token = generateReviewToken();

  const eaccount = firstNonEmpty(nes.eaccount, nes.email_account, nes.sender_email, caseInput.eaccount, input.eaccount, "");
  const senderConfig = resolveSenderConfig(eaccount, draft, CONFIG);

  const firstName = firstNonEmpty(caseInput.first_name, caseInput.First_name, nes.lead_first_name, nes.first_name, reply.from_address_name);
  const templateVariables = {
    firstName: firstName || null,
    senderName: senderConfig.senderName || null,
    bookingLink: senderConfig.bookingLink || null
  };

  const category = firstNonEmpty(decision.category, classifier.category, caseInput.category, input.category, "UNKNOWN");
  const microIntent = firstNonEmpty(decision.micro_intent, classifier.micro_intent, caseInput.micro_intent, input.micro_intent);
  const draftPolicy = firstNonEmpty(decision.draft_policy, classifier.draft_policy, caseInput.draft_policy, input.draft_policy);
  const draftSource = firstNonEmpty(draft.draft_source, decision.draft_source, caseInput.draft_source, input.draft_source);

  const replyText = firstNonEmpty(reply.text, reply.body, reply.plain_text, caseInput.reply_text, input.reply_text);
  const replySnippet = firstNonEmpty(reply.snippet, caseInput.reply_snippet, input.reply_snippet, replyText);

  const replyMode = firstNonEmpty(decision.reply_mode, caseInput.reply_mode, input.reply_mode, "HUMAN_ONLY");
  const templateId = firstNonEmpty(decision.reply_template_id, draft.template_id, "");

  const blockedVariables = [];
  const sendableMode = replyMode === "FIXED_TEMPLATE_APPROVAL" || replyMode === "AI_DRAFT_APPROVAL";
  if (sendableMode && !templateVariables.senderName) blockedVariables.push("senderName");
  if (/BOOKING|T1_SCENARIO_A|T3_/.test(templateId) && !templateVariables.bookingLink) blockedVariables.push("bookingLink");

  const draftText = firstNonEmpty(draft.draft_text, caseInput.draft_text, input.draft_text, "");

  const sanitizedContext = {
    intake_id: intakeId,
    category,
    micro_intent: microIntent,
    draft_policy: draftPolicy,
    draft_source: draftSource,
    confidence: caseInput.confidence ?? decision.confidence ?? classifier.confidence ?? null,
    urgency: firstNonEmpty(caseInput.urgency, decision.priority, decision.urgency, "routine"),
    risk_flags: safeArray(caseInput.risk_flags || decision.risk_flags || classifier.risk_flags),
    campaign_context: campaignContext,
    reply_subject: reply.subject || null,
    reply_text: replyText || null,
    reply_snippet: replySnippet || null,
    reply_from_name: firstNonEmpty(reply.from_address_name, reply.from_name, reply.name),
    reply_from_email: firstNonEmpty(reply.from_address_email, reply.from_email, reply.email, nes.lead_email),
    sender_email: eaccount || null,
    sender_name: senderConfig.senderName || null,
    template_variables: templateVariables,
    draft_status: firstNonEmpty(draft.draft_status, decision.reply_draft_status),
    ai_attempt: draft.ai_attempt || decision.ai_attempt || null,
    recommended_action_plan: decision || {},
    sender_handoff: {
      nes,
      classifier,
      decision,
      draft,
      validation
    }
  };

  return {
    json: {
      ...input,
      config: CONFIG,
      review_case: {
        case_id: caseId,
        intake_id: intakeId,
        token,
        token_expires_at: expiresIso,
        status: "NEW",
        category,
        urgency: sanitizedContext.urgency,
        reply_mode: replyMode,
        draft_text: draftText,
        template_variables: templateVariables,
        blocked_variables: blockedVariables,
        sanitized_context: sanitizedContext,
        policy_version: policyVersion,
        kb_version: caseInput.kb_version || input.kb_version || CONFIG.kb_version,
        notification_status: "PENDING",
        approver_identity: null,
        approved_at: null,
        final_reply_text: null,
        decision_payload: {
          nes,
          classifier,
          decision,
          draft,
          validation
        },
        created_at: nowIso,
        updated_at: nowIso
      }
    }
  };
});
'@

$newCaseCode = $newCaseCode.Replace("__CONFIG_BLOCK__", $configBlock)

$newChatCode = @'
const items = $input.all();

function parseJson(value, fallback) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value === "object") return value;
  try { return JSON.parse(String(value)); } catch { return fallback; }
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value === null || value === undefined) continue;
    const s = String(value).trim();
    if (s) return s;
  }
  return null;
}

const built = $("A. Build Review Case Record").first().json || {};
const baseCase = built.review_case || {};
const config = built.config || {};

return items.map(item => {
  const row = item.json || {};
  const rc = {
    ...baseCase,
    ...row,
    template_variables: parseJson(row.template_variables, baseCase.template_variables || {}),
    blocked_variables: parseJson(row.blocked_variables, baseCase.blocked_variables || []),
    sanitized_context: parseJson(row.sanitized_context, baseCase.sanitized_context || {}),
    decision_payload: parseJson(row.decision_payload, baseCase.decision_payload || null)
  };

  const ctx = rc.sanitized_context || {};
  const base = String((config.review || {}).review_base_url || "").replace(/\/$/, "");
  const reviewUrl = base + "/review?case=" + encodeURIComponent(rc.case_id || "") + "&token=" + encodeURIComponent(rc.token || "");

  const category = firstNonEmpty(ctx.category, rc.category, "UNKNOWN");
  const urgency = firstNonEmpty(ctx.urgency, rc.urgency, "routine");
  const microIntent = firstNonEmpty(ctx.micro_intent, "UNKNOWN");
  const draftSource = firstNonEmpty(ctx.draft_source, "UNKNOWN");
  const senderName = firstNonEmpty(ctx.sender_name, (rc.template_variables || {}).senderName, "UNKNOWN");
  const senderEmail = firstNonEmpty(ctx.sender_email, "UNKNOWN");
  const fromName = firstNonEmpty(ctx.reply_from_name, "");
  const fromEmail = firstNonEmpty(ctx.reply_from_email, "UNKNOWN");
  const fromLine = fromName ? `${fromName} <${fromEmail}>` : fromEmail;
  const snippet = String(firstNonEmpty(ctx.reply_snippet, ctx.reply_text, "") || "").slice(0, 240);

  const lines = [];
  lines.push("New reply review case: " + (rc.case_id || "UNKNOWN_CASE"));
  lines.push("From: " + fromLine);
  lines.push("Sender: " + senderName + " <" + senderEmail + ">");
  lines.push("Category: " + category + " | Micro intent: " + microIntent + " | Urgency: " + urgency);
  lines.push("Draft source: " + draftSource);
  lines.push("Reply excerpt: " + (snippet || "[blank]"));
  lines.push("Review: " + reviewUrl);

  return {
    json: {
      ...built,
      review_case: rc,
      chat_notification: {
        payload: { text: lines.join("\n") },
        review_url: reviewUrl
      }
    }
  };
});
'@

Write-Host "`n[2/5] Patch plan..."
Write-Host "  PATCH: HumanApproval node A. Build Review Case Record"
Write-Host "  PATCH: HumanApproval node D. Build Google Chat Notification Payload"
Write-Host "  NO TOUCH: Intake, Decision, Sender, ErrorHandler, SLAWatchdog, TestHarness"

$caseNode.parameters.jsCode = $newCaseCode
$chatNode.parameters.jsCode = $newChatCode

Write-Host "`n[3/5] Verifying patched workflow object before write..."
$humanJson = $human | ConvertTo-Json -Depth 100

$requiredMarkers = @(
  "reply_from_email",
  "sender_name",
  "micro_intent",
  "draft_source",
  "From:",
  "Sender:",
  "Draft source:"
)

foreach ($m in $requiredMarkers) {
  if ($humanJson -notlike "*$m*") {
    throw "STOP: Missing patch marker before write: $m"
  }
  Write-Host "  OK marker: $m"
}

if ($WhatIf) {
  Write-Host "`n[WHATIF] No changes applied."
  Write-Host "WHATIF_OK"
  return
}

Write-Host "`n[4/5] Applying patch to HumanApproval only..."
$updated = Update-Workflow $WorkflowIds.HumanApproval $human
Write-Host "  PUT HumanApproval complete"

Start-Sleep -Seconds 2

Write-Host "`n[5/5] Verifying live HumanApproval after patch..."
$live = Get-Workflow $WorkflowIds.HumanApproval
$liveJson = $live | ConvertTo-Json -Depth 100

foreach ($m in $requiredMarkers) {
  if ($liveJson -notlike "*$m*") {
    throw "STOP: Missing patch marker after write: $m"
  }
  Write-Host "  PASS live marker: $m"
}

Activate-IfNeeded "HumanApproval" $WorkflowIds.HumanApproval

$th = Get-Workflow $WorkflowIds.TestHarness
if ($th.active -eq $true) {
  throw "STOP: Full Test Harness became active."
}
Write-Host "  PASS Full Test Harness inactive"

foreach ($name in @("Intake","Decision","HumanApproval","Sender")) {
  $wf = Get-Workflow $WorkflowIds[$name]
  Write-Host "  STATE $name active=$($wf.active)"
}

Write-Host "`nPATCH_APPLIED_AND_VERIFIED"
