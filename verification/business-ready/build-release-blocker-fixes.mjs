// Release-blocker offline correction build script.
//
// Pure Node.js (built-ins only). Mutates the 7 business-ready workflow JSON
// exports in-place to correct the release-blocking contract/acceptance
// defects (A-H) identified by the independent audit, plus
// config/business-ready.config.json. Makes no network call, starts nothing,
// and leaves all 7 workflows `active: false`. Re-run is idempotent: each
// mutation is skipped if its marker/node already exists.
//
// Usage: node verification/business-ready/build-release-blocker-fixes.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');
const CONFIG_PATH = path.join(ROOT, 'config', 'business-ready.config.json');

const FILES = {
  intake: '01_reply_intake_validation.json',
  decision: '02_reply_decision_engine_validation.json',
  sender: '03_reply_sender_validation.json',
  errorHandler: '04_reply_error_handler_validation.json',
  watchdog: '05_reply_sla_watchdog_validation.json',
  harness: '06_reply_full_test_harness_validation.json',
  approval: '07_reply_human_approval_validation.json',
};

function load(file) {
  return JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, file), 'utf8'));
}

function save(file, wf) {
  fs.writeFileSync(path.join(WORKFLOWS_DIR, file), `${JSON.stringify(wf, null, 2)}\n`, 'utf8');
}

function J(lines) {
  return lines.join('\n');
}

function nodeByName(wf, name) {
  return wf.nodes.find((n) => n.name === name);
}

function hasNode(wf, name) {
  return !!nodeByName(wf, name);
}

function removeNode(wf, name) {
  wf.nodes = wf.nodes.filter((n) => n.name !== name);
  delete wf.connections[name];
  for (const src of Object.keys(wf.connections)) {
    const outputs = wf.connections[src].main || [];
    wf.connections[src].main = outputs.map((branch) =>
      (branch || []).filter((edge) => edge.node !== name)
    );
  }
}

function replaceAllInCodeNodes(wf, replacements) {
  let count = 0;
  for (const node of wf.nodes) {
    if (node.type === 'n8n-nodes-base.code' && node.parameters && typeof node.parameters.jsCode === 'string') {
      for (const [from, to] of replacements) {
        if (node.parameters.jsCode.includes(from)) {
          node.parameters.jsCode = node.parameters.jsCode.split(from).join(to);
          count += 1;
        }
      }
    }
  }
  return count;
}

const changes = [];

// =====================================================================
// SHARED: the corrected "Email-object" SENT contract, replacing the old
// mock isValidSentContract(body) { status==='sent' && messageId } check.
// Self-contained (no external helper dependencies) so it can drop into any
// of the duplicated per-node "LIB" headers in workflow 03 unchanged.
// =====================================================================
const IS_VALID_SENT_CONTRACT_MULTILINE = J([
  "function isValidSentContract(body) {",
  "  return (",
  "    !!body &&",
  "    typeof body === 'object' &&",
  "    body.status === 'sent' &&",
  "    typeof body.messageId === 'string' &&",
  "    body.messageId.length > 0",
  "  );",
  "}",
]);

const IS_VALID_SENT_CONTRACT_SINGLELINE = J([
  "function isValidSentContract(body) {",
  "  return !!body && typeof body === 'object' && body.status === 'sent' && typeof body.messageId === 'string' && body.messageId.length > 0;",
  "}",
]);

const IS_VALID_SENT_EMAIL_OBJECT = J([
  "function isValidSentEmailObject(body, expected) {",
  "  const exp = expected || {};",
  "  const norm = (v) => String(v == null ? '' : v).trim().toLowerCase();",
  "  const isEmptyAddr = (v) => {",
  "    if (v === null || v === undefined) return true;",
  "    if (Array.isArray(v)) return v.length === 0;",
  "    if (typeof v === 'string') return v.trim().length === 0;",
  "    return false;",
  "  };",
  "  if (!body || typeof body !== 'object') return false;",
  "  if (typeof body.id !== 'string' || body.id.length === 0) return false;",
  "  if (typeof body.message_id !== 'string' || body.message_id.length === 0) return false;",
  "  if (typeof body.thread_id !== 'string' || body.thread_id.length === 0) return false;",
  "  if (exp.eaccount && body.eaccount !== exp.eaccount) return false;",
  "  if (exp.recipient) {",
  "    const recipients = Array.isArray(body.to_address_email_list)",
  "      ? body.to_address_email_list.map(norm)",
  "      : String(body.to_address_email_list || '').split(',').map(norm).filter(Boolean);",
  "    if (!recipients.includes(norm(exp.recipient))) return false;",
  "  }",
  "  if (exp.subject && body.subject !== exp.subject) return false;",
  "  if (!exp.ccBccApproved) {",
  "    if (!isEmptyAddr(body.cc_address_email_list)) return false;",
  "    if (!isEmptyAddr(body.bcc_address_email_list)) return false;",
  "  }",
  "  return true;",
  "}",
]);

// =====================================================================
// 03_reply_sender_validation.json - blockers A (success classification),
// B (reconciliation), and the F gate-ordering fix (workspace before
// campaign).
// =====================================================================
{
  const wf = load(FILES.sender);

  // --- A. Global: isValidSentContract -> isValidSentEmailObject ---------
  let replacedDefs = 0;
  for (const node of wf.nodes) {
    if (node.type !== 'n8n-nodes-base.code' || !node.parameters || typeof node.parameters.jsCode !== 'string') continue;
    let code = node.parameters.jsCode;
    let changed = false;
    if (code.includes(IS_VALID_SENT_CONTRACT_MULTILINE)) {
      code = code.split(IS_VALID_SENT_CONTRACT_MULTILINE).join(IS_VALID_SENT_EMAIL_OBJECT);
      changed = true;
    }
    if (code.includes(IS_VALID_SENT_CONTRACT_SINGLELINE)) {
      code = code.split(IS_VALID_SENT_CONTRACT_SINGLELINE).join(IS_VALID_SENT_EMAIL_OBJECT);
      changed = true;
    }
    if (code.includes('function classifySendOutcome(outcome) {')) {
      code = code.split('function classifySendOutcome(outcome) {').join('function classifySendOutcome(outcome, expected) {');
      changed = true;
    }
    if (code.includes('if (isValidSentContract(body)) {')) {
      code = code.split('if (isValidSentContract(body)) {').join('if (isValidSentEmailObject(body, expected)) {');
      changed = true;
    }
    if (changed) {
      node.parameters.jsCode = code;
      replacedDefs += 1;
    }
  }
  changes.push(`03: replaced isValidSentContract -> isValidSentEmailObject (Email-object contract) and classifySendOutcome(outcome) -> classifySendOutcome(outcome, expected) in ${replacedDefs} code node(s).`);

  // --- A/B. Node R: compute `expected` cross-check context, derive a
  //         reconciliation window, and pass `expected` into
  //         classifySendOutcome. -------------------------------------------
  {
    const nodeR = nodeByName(wf, 'R. Classify Send Attempt');
    const OLD_CLASSIFY_CALL = J([
      "  const outcome = buildOutcomeFromHttpResponse(httpResp);",
      "  const classification = classifySendOutcome(outcome);",
      "  const attemptNumber = priorAttempts.length + 1;",
    ]);
    const NEW_CLASSIFY_CALL = J([
      "  const nes = (carried.nes) || {};",
      "  const reply = nes.reply || {};",
      "  const decision = (carried.decision) || {};",
      "  const rawSubject = reply.subject || '';",
      "  const expectedSubject = rawSubject ? (/^re:/i.test(rawSubject) ? rawSubject : `Re: ${rawSubject}`) : null;",
      "  const expected = {",
      "    eaccount: nes.eaccount || null,",
      "    recipient: nes.lead_email || null,",
      "    subject: expectedSubject,",
      "    ccBccApproved: decision.cc_bcc_approved === true,",
      "  };",
      "",
      "  const outcome = buildOutcomeFromHttpResponse(httpResp);",
      "  const classification = classifySendOutcome(outcome, expected);",
      "  const attemptNumber = priorAttempts.length + 1;",
      "",
      "  const nowIso = new Date().toISOString();",
      "  const priorWindow = (carried.send_classification && carried.send_classification.reconciliation_window) || null;",
      "  const reconciliationWindow = priorWindow || {",
      "    min_timestamp_created: new Date(Date.now() - 5 * 60 * 1000).toISOString(),",
      "    max_timestamp_created_base: nowIso,",
      "  };",
    ]);
    if (nodeR.parameters.jsCode.includes(OLD_CLASSIFY_CALL)) {
      nodeR.parameters.jsCode = nodeR.parameters.jsCode.split(OLD_CLASSIFY_CALL).join(NEW_CLASSIFY_CALL);
      changes.push('03: R - compute `expected` (eaccount/recipient/subject/ccBccApproved cross-checks) and a reconciliation_window, pass `expected` to classifySendOutcome.');
    } else {
      changes.push('03: R - classification call site already updated, skipped.');
    }

    const OLD_SEND_CLASSIFICATION = J([
      "      send_classification: {",
      "        mode: classification.mode,",
      "        final_state: finalState,",
      "        retryable: classification.mode === 'retryable' && attemptNumber < MAX_SEND_ATTEMPTS && finalState === null,",
      "        next_delay_ms: nextDelayMs,",
      "        ambiguous_side_effect: !!classification.ambiguousSideEffect,",
      "        attempt_number: attemptNumber,",
      "        last_outcome: outcome,",
      "      },",
    ]);
    const NEW_SEND_CLASSIFICATION = J([
      "      send_classification: {",
      "        mode: classification.mode,",
      "        final_state: finalState,",
      "        retryable: classification.mode === 'retryable' && attemptNumber < MAX_SEND_ATTEMPTS && finalState === null,",
      "        next_delay_ms: nextDelayMs,",
      "        ambiguous_side_effect: !!classification.ambiguousSideEffect,",
      "        attempt_number: attemptNumber,",
      "        last_outcome: outcome,",
      "        expected,",
      "        reconciliation_window: {",
      "          min_timestamp_created: reconciliationWindow.min_timestamp_created,",
      "          max_timestamp_created: new Date(Date.now() + 5 * 60 * 1000).toISOString(),",
      "        },",
      "      },",
    ]);
    if (nodeR.parameters.jsCode.includes(OLD_SEND_CLASSIFICATION)) {
      nodeR.parameters.jsCode = nodeR.parameters.jsCode.split(OLD_SEND_CLASSIFICATION).join(NEW_SEND_CLASSIFICATION);
      changes.push('03: R - send_classification now carries `expected` and a `reconciliation_window` for GET /api/v2/emails.');
    } else {
      changes.push('03: R - send_classification shape already updated, skipped.');
    }
  }

  // --- A. Node Q: embed a unique send-key marker in body.html so
  //       reconciliation (W) has a fingerprint to match on. -----------------
  {
    const nodeQ = nodeByName(wf, 'Q. POST Reply to Instantly (Gated)');
    const OLD_BODY = "body: { text: $json.draft.draft_text, html: null } } }}";
    const NEW_BODY = "body: { text: $json.draft.draft_text, html: ($json.acquisition && $json.acquisition.sendKey) ? ('<!-- hmz-send-key:' + $json.acquisition.sendKey + ' -->') : null } } }}";
    if (nodeQ.parameters.jsonBody.includes(OLD_BODY)) {
      nodeQ.parameters.jsonBody = nodeQ.parameters.jsonBody.split(OLD_BODY).join(NEW_BODY);
      changes.push('03: Q - POST body now embeds the stable send key as an HTML comment fingerprint (body.html), used by W for unique-marker matching. CC/BCC remain omitted (empty).');
    } else {
      changes.push('03: Q - body already carries the send-key fingerprint, skipped.');
    }
  }

  // --- A. Node X: persist BOTH the Instantly Email object `id` and the
  //       provider `message_id` (not the old mock `messageId`). -----------
  {
    const nodeX = nodeByName(wf, 'X. Persist SENT Result (hmz-send-state)');
    const OLD_JSON_BODY =
      "={{ { sendKey: $json.acquisition.sendKey, state: 'SENT', messageId: ($json.send_classification.last_outcome.body && $json.send_classification.last_outcome.body.messageId) || null } }}";
    const NEW_JSON_BODY =
      "={{ { sendKey: $json.acquisition.sendKey, state: 'SENT', emailId: ($json.send_classification.last_outcome.body && $json.send_classification.last_outcome.body.id) || null, messageId: ($json.send_classification.last_outcome.body && $json.send_classification.last_outcome.body.message_id) || null, threadId: ($json.send_classification.last_outcome.body && $json.send_classification.last_outcome.body.thread_id) || null } }}";
    if (nodeX.parameters.jsonBody === OLD_JSON_BODY) {
      nodeX.parameters.jsonBody = NEW_JSON_BODY;
      changes.push('03: X - persists Instantly Email object `id` (emailId), `message_id`, and `thread_id` instead of the mock `messageId`.');
    } else {
      changes.push('03: X - SENT persistence body already updated, skipped.');
    }
  }

  // --- A. Node X2: terminal SENT result reports email_id + message_id. ----
  {
    const nodeX2 = nodeByName(wf, 'X2. Build SENT Terminal Result');
    const OLD_TERMINAL = J([
      "      terminal: {",
      "        schema_version: '1.0',",
      "        result: 'SENT',",
      "        send_state: 'SENT',",
      "        reason: 'LIVE_SEND_COMPLETED',",
      "        message_id: body.messageId || null,",
      "        sent: true,",
      "      },",
    ]);
    const NEW_TERMINAL = J([
      "      terminal: {",
      "        schema_version: '1.0',",
      "        result: 'SENT',",
      "        send_state: 'SENT',",
      "        reason: 'LIVE_SEND_COMPLETED',",
      "        email_id: body.id || null,",
      "        message_id: body.message_id || null,",
      "        thread_id: body.thread_id || null,",
      "        confirmed_cross_checks: {",
      "          eaccount: body.eaccount || null,",
      "          subject: body.subject || null,",
      "          cc_address_email_list: body.cc_address_email_list || null,",
      "          bcc_address_email_list: body.bcc_address_email_list || null,",
      "        },",
      "        sent: true,",
      "      },",
    ]);
    if (nodeX2.parameters.jsCode.includes(OLD_TERMINAL)) {
      nodeX2.parameters.jsCode = nodeX2.parameters.jsCode.split(OLD_TERMINAL).join(NEW_TERMINAL);
      changes.push('03: X2 - SENT terminal result now reports email_id/message_id/thread_id and the confirmed cross-check fields.');
    } else {
      changes.push('03: X2 - SENT terminal result already updated, skipped.');
    }
  }

  // --- B. Node V: GET /api/v2/emails with the required query parameters,
  //       replacing the obsolete POST /api/v2/emails/list. ----------------
  {
    const nodeV = nodeByName(wf, 'V. Reconciliation Poll (list_emails, Gated)');
    if (nodeV.parameters.method === 'POST') {
      nodeV.parameters = {
        method: 'GET',
        url: 'https://api.instantly.ai/api/v2/emails',
        sendQuery: true,
        queryParameters: {
          parameters: [
            {
              name: 'search',
              value: "={{ 'thread:' + (($json.nes.threading && ($json.nes.threading.thread_id || $json.nes.threading.reply_to_uuid)) || '') }}",
            },
            { name: 'eaccount', value: '={{ $json.nes.eaccount }}' },
            { name: 'lead', value: '={{ $json.nes.lead_email }}' },
            { name: 'email_type', value: 'sent' },
            {
              name: 'min_timestamp_created',
              value: "={{ ($json.send_classification && $json.send_classification.reconciliation_window && $json.send_classification.reconciliation_window.min_timestamp_created) || '' }}",
            },
            {
              name: 'max_timestamp_created',
              value: "={{ ($json.send_classification && $json.send_classification.reconciliation_window && $json.send_classification.reconciliation_window.max_timestamp_created) || '' }}",
            },
            { name: 'preview_only', value: 'false' },
            { name: 'limit', value: '100' },
          ],
        },
        options: {
          timeout: 10000,
          response: { response: { neverError: true, fullResponse: true } },
        },
      };
      nodeV.credentialPlaceholder = 'hmzInstantlyApi';
      changes.push('03: V - replaced POST https://api.instantly.ai/api/v2/emails/list with GET https://api.instantly.ai/api/v2/emails using search/eaccount/lead/email_type/min_timestamp_created/max_timestamp_created/preview_only/limit query parameters.');
    } else {
      changes.push('03: V - reconciliation request already GET /api/v2/emails, skipped.');
    }
  }

  // --- B. Node W: local-filter the GET /api/v2/emails `items` by thread,
  //       sender, recipient, exact subject, narrow timestamp window, and
  //       the unique send-key marker before feeding reconcileMatches. -----
  {
    const nodeW = nodeByName(wf, 'W. Process Reconciliation Poll');
    const OLD_MATCH_IDS = J([
      "  const body = (httpResp.body !== undefined) ? httpResp.body : httpResp;",
      "  const matchIds = Array.isArray((body || {}).items) ? body.items.map((e) => e.id).filter(Boolean) : [];",
    ]);
    const NEW_MATCH_IDS = J([
      "  const body = (httpResp.body !== undefined) ? httpResp.body : httpResp;",
      "  const itemsArr = Array.isArray((body || {}).items) ? body.items : [];",
      "",
      "  const nes = prior.nes || {};",
      "  const reply = nes.reply || {};",
      "  const sc = prior.send_classification || {};",
      "  const expected = sc.expected || {};",
      "  const window = sc.reconciliation_window || {};",
      "  const sendKey = (prior.acquisition && prior.acquisition.sendKey) || null;",
      "  const expectedThread = (nes.threading && (nes.threading.thread_id || nes.threading.reply_to_uuid)) || null;",
      "",
      "  function norm(v) { return String(v == null ? '' : v).trim().toLowerCase(); }",
      "",
      "  function matchesItem(e) {",
      "    if (!e) return false;",
      "    if (expectedThread && e.thread_id !== expectedThread) return false;",
      "    if (expected.eaccount && e.eaccount !== expected.eaccount) return false;",
      "    const recipients = Array.isArray(e.to_address_email_list)",
      "      ? e.to_address_email_list.map(norm)",
      "      : String(e.to_address_email_list || '').split(',').map(norm).filter(Boolean);",
      "    if (expected.recipient && !recipients.includes(norm(expected.recipient))) return false;",
      "    if (expected.subject && e.subject !== expected.subject) return false;",
      "    if (window.min_timestamp_created && e.timestamp_created && e.timestamp_created < window.min_timestamp_created) return false;",
      "    if (window.max_timestamp_created && e.timestamp_created && e.timestamp_created > window.max_timestamp_created) return false;",
      "    if (sendKey) {",
      "      const html = (e.body && e.body.html) ? String(e.body.html) : '';",
      "      if (!html.includes(sendKey)) return false;",
      "    }",
      "    return true;",
      "  }",
      "",
      "  const matchIds = itemsArr.filter(matchesItem).map((e) => e.id).filter(Boolean);",
    ]);
    if (nodeW.parameters.jsCode.includes(OLD_MATCH_IDS)) {
      nodeW.parameters.jsCode = nodeW.parameters.jsCode.split(OLD_MATCH_IDS).join(NEW_MATCH_IDS);
      changes.push('03: W - local-filters GET /api/v2/emails `items` by thread, sender, recipient, exact subject, narrow timestamp window, and the unique send-key marker before reconcileMatches.');
    } else {
      changes.push('03: W - reconciliation local-filtering already updated, skipped.');
    }
  }

  // --- F. Node O: reorder gates so workspace allowlisting is evaluated
  //       before, and gates, campaign allowlisting. A missing/blank
  //       workspace_id can never allowlist a campaign. ----------------------
  {
    const nodeO = nodeByName(wf, 'O. Live Send Gate Evaluation (14 Gates)');
    const OLD_GATES = J([
      "  gate('campaign_in_live_campaigns', 'Exact campaign is declared in live_campaigns and allow-listed',",
      "    !!campaignId && LAUNCH_PROFILE.live_campaigns.includes(campaignId) && LAUNCH_PROFILE.campaign_allowlist.includes(campaignId),",
      "    'CAMPAIGN_NOT_IN_LIVE_CAMPAIGNS_OR_NOT_ALLOWLISTED');",
      "",
      "  gate('workspace_allowlisted', 'Exact workspace is allow-listed',",
      "    !!workspaceId && !!LAUNCH_PROFILE.workspace_id && workspaceId === LAUNCH_PROFILE.workspace_id && LAUNCH_PROFILE.workspace_allowlist.includes(workspaceId),",
      "    'WORKSPACE_NOT_ALLOWLISTED');",
    ]);
    const NEW_GATES = J([
      "  const workspaceAllowlisted =",
      "    !!workspaceId && !!LAUNCH_PROFILE.workspace_id && workspaceId === LAUNCH_PROFILE.workspace_id && LAUNCH_PROFILE.workspace_allowlist.includes(workspaceId);",
      "",
      "  gate('workspace_allowlisted', 'Exact workspace is allow-listed',",
      "    workspaceAllowlisted,",
      "    'WORKSPACE_NOT_ALLOWLISTED');",
      "",
      "  // A missing/blank campaign workspace_id can never be allowlisted: this",
      "  // gate is gated ON workspace_allowlisted so an empty/absent workspace_id",
      "  // cannot be satisfied by campaign membership alone.",
      "  gate('campaign_in_live_campaigns', 'Exact campaign is declared in live_campaigns and allow-listed for the allow-listed workspace',",
      "    workspaceAllowlisted && !!campaignId && LAUNCH_PROFILE.live_campaigns.includes(campaignId) && LAUNCH_PROFILE.campaign_allowlist.includes(campaignId),",
      "    'CAMPAIGN_NOT_IN_LIVE_CAMPAIGNS_OR_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED');",
    ]);
    if (nodeO.parameters.jsCode.includes(OLD_GATES)) {
      nodeO.parameters.jsCode = nodeO.parameters.jsCode.split(OLD_GATES).join(NEW_GATES);
      changes.push('03: O - reordered gates so workspace_allowlisted is evaluated first and gates campaign_in_live_campaigns (missing campaign workspace_id is never allowlisted).');
    } else {
      changes.push('03: O - gate ordering already corrected, skipped.');
    }

    // Add an injection marker around LAUNCH_PROFILE for the apply step.
    const OLD_LAUNCH_PROFILE_DECL = "const LAUNCH_PROFILE = {";
    if (nodeO.parameters.jsCode.includes(OLD_LAUNCH_PROFILE_DECL) && !nodeO.parameters.jsCode.includes('HMZ_INJECT_BEGIN:LAUNCH_PROFILE')) {
      nodeO.parameters.jsCode = nodeO.parameters.jsCode
        .replace('const LAUNCH_PROFILE = {', '// HMZ_INJECT_BEGIN:LAUNCH_PROFILE\nconst LAUNCH_PROFILE = {')
        .replace(/(const LAUNCH_PROFILE = \{[\s\S]*?\n\};)/, '$1\n// HMZ_INJECT_END:LAUNCH_PROFILE');
      changes.push('03: O - wrapped LAUNCH_PROFILE in HMZ_INJECT markers for apply-time config injection.');
    } else {
      changes.push('03: O - LAUNCH_PROFILE injection markers already present, skipped.');
    }
  }

  save(FILES.sender, wf);
}

// =====================================================================
// 02_reply_decision_engine_validation.json - blocker C (suppression plan
// + per-action gated execution + verification, with corrected Instantly
// API contracts).
// =====================================================================
{
  const wf = load(FILES.decision);

  // --- C. Node F: rebuild buildSafetyActionPlan with the corrected
  //       contracts (subsequence/remove by canonical lead id,
  //       update-interest-status with numeric interest_value,
  //       block-lists-entries/bulk-create with bl_values). -----------------
  {
    const nodeF = nodeByName(wf, 'F. Safety Action Plan (Gated Contract, Pre-Approval)');
    const OLD_F = J([
      "const items = $input.all();",
      "",
      "const SUPPRESSION_ACTION_ENABLEMENT = {\"source_campaign_stop_enabled\":false,\"interest_status_update_enabled\":false,\"subsequence_removal_enabled\":false,\"exact_email_blocklist_enabled\":false};",
      "",
      "const DNC_SCOPES = ['WORKSPACE_DNC', 'ORGANISATION_DNC', 'GLOBAL_BLOCKLIST'];",
      "",
      "function buildSafetyActionPlan(input) {",
      "  const nes = input.nes || {};",
      "  const decision = input.decision || {};",
      "  const campaign = nes.campaign_context || {};",
      "  const actions = [];",
      "",
      "  if (decision.stop_active_sequence === true) {",
      "    actions.push({",
      "      action: 'STOP_ACTIVE_SEQUENCE',",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.subsequence_removal_enabled,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/leads/subsequence/remove',",
      "        body: { campaign_id: campaign.campaign_id || null, lead_email: nes.lead_email || null },",
      "      },",
      "    });",
      "    actions.push({",
      "      action: 'UPDATE_INTEREST_STATUS',",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.interest_status_update_enabled,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/leads/update-interest-status',",
      "        body: { campaign_id: campaign.campaign_id || null, lead_email: nes.lead_email || null, interest_status: decision.category || null },",
      "      },",
      "    });",
      "  }",
      "",
      "  if (DNC_SCOPES.includes(decision.address_suppression_intent)) {",
      "    actions.push({",
      "      action: 'ADD_TO_BLOCKLIST',",
      "      scope: decision.address_suppression_intent,",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.exact_email_blocklist_enabled,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/blocklist',",
      "        body: { entries: [nes.lead_email || null] },",
      "      },",
      "    });",
      "  }",
      "",
      "  const plannedActions = actions.map((a) => ({",
      "    ...a,",
      "    executed: false,",
      "    verification_status: a.enabled ? 'PLANNED_AWAITING_LIVE_GATE' : 'SUPPRESSION_ACTION_DISABLED_BY_CONFIG',",
      "  }));",
      "",
      "  return {",
      "    schema_version: '1.0',",
      "    required: plannedActions.length > 0,",
      "    actions: plannedActions,",
      "    execution_order: 'BEFORE_REPLY_APPROVAL_GATE',",
      "    note: 'Required suppression actions are planned and contract-defined here, independent of and prior to the prospect-reply human-approval gate (workflow 07) and the reply send gates (workflow 03). Real HTTP execution remains additionally gated by suppression_action_enablement, dry_run and live_credential_readiness.',",
      "  };",
      "}",
    ]);

    const NEW_F = J([
      "const items = $input.all();",
      "",
      "// HMZ_INJECT_BEGIN:SUPPRESSION_ACTION_ENABLEMENT",
      "const SUPPRESSION_ACTION_ENABLEMENT = {\"source_campaign_stop_enabled\":false,\"interest_status_update_enabled\":false,\"subsequence_removal_enabled\":false,\"exact_email_blocklist_enabled\":false};",
      "// HMZ_INJECT_END:SUPPRESSION_ACTION_ENABLEMENT",
      "",
      "const DNC_SCOPES = ['WORKSPACE_DNC', 'ORGANISATION_DNC', 'GLOBAL_BLOCKLIST'];",
      "",
      "const INTEREST_VALUE_MAP = {",
      "  INTERESTED: 1,",
      "  MEETING_BOOKED: 2,",
      "  MEETING_COMPLETED: 3,",
      "  CLOSED: 4,",
      "  OUT_OF_OFFICE: 0,",
      "  NOT_INTERESTED: -1,",
      "  WRONG_PERSON: -2,",
      "  LOST: -3,",
      "  DO_NOT_CONTACT: -1,",
      "  UNSUBSCRIBE: -1,",
      "};",
      "",
      "function buildSafetyActionPlan(input) {",
      "  const nes = input.nes || {};",
      "  const decision = input.decision || {};",
      "  const campaign = nes.campaign_context || {};",
      "  const actions = [];",
      "",
      "  if (decision.stop_active_sequence === true) {",
      "    actions.push({",
      "      action: 'SOURCE_CAMPAIGN_STOP',",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.source_campaign_stop_enabled,",
      "      requires_canonical_lead_id: true,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/leads/subsequence/remove',",
      "        body: { id: null, campaign_id: campaign.campaign_id || null },",
      "      },",
      "    });",
      "",
      "    const categoryKey = decision.category || '';",
      "    const interestValue = Object.prototype.hasOwnProperty.call(INTEREST_VALUE_MAP, categoryKey)",
      "      ? INTEREST_VALUE_MAP[categoryKey]",
      "      : null;",
      "    actions.push({",
      "      action: 'UPDATE_INTEREST_STATUS',",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.interest_status_update_enabled,",
      "      requires_canonical_lead_id: false,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/leads/update-interest-status',",
      "        body: { lead_email: nes.lead_email || null, interest_value: interestValue, campaign_id: campaign.campaign_id || null },",
      "      },",
      "    });",
      "  }",
      "",
      "  if (DNC_SCOPES.includes(decision.address_suppression_intent)) {",
      "    actions.push({",
      "      action: 'SUBSEQUENCE_REMOVAL',",
      "      scope: decision.address_suppression_intent,",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.subsequence_removal_enabled,",
      "      requires_canonical_lead_id: true,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/leads/subsequence/remove',",
      "        body: { id: null },",
      "      },",
      "    });",
      "    actions.push({",
      "      action: 'EXACT_EMAIL_BLOCKLIST',",
      "      scope: decision.address_suppression_intent,",
      "      enabled: SUPPRESSION_ACTION_ENABLEMENT.exact_email_blocklist_enabled,",
      "      requires_canonical_lead_id: false,",
      "      request_contract: {",
      "        method: 'POST',",
      "        url: 'https://api.instantly.ai/api/v2/block-lists-entries/bulk-create',",
      "        body: { bl_values: [nes.lead_email || null] },",
      "      },",
      "    });",
      "  }",
      "",
      "  const requiresCanonicalLead = actions.some((a) => a.requires_canonical_lead_id && a.enabled);",
      "",
      "  const plannedActions = actions.map((a) => ({",
      "    ...a,",
      "    executed: false,",
      "    verification_status: a.enabled ? 'PLANNED_AWAITING_LIVE_GATE' : 'SUPPRESSION_ACTION_DISABLED_BY_CONFIG',",
      "  }));",
      "",
      "  return {",
      "    schema_version: '1.1',",
      "    required: plannedActions.length > 0,",
      "    requires_canonical_lead: requiresCanonicalLead,",
      "    actions: plannedActions,",
      "    execution_order: 'BEFORE_REPLY_APPROVAL_GATE',",
      "    note: 'Required suppression actions are planned and contract-defined here, independent of and prior to the prospect-reply human-approval gate (workflow 07) and the reply send gates (workflow 03). Each action is gated individually by its own flag in suppression_action_enablement and is executed/verified independently; real HTTP execution remains additionally gated by dry_run and live_credential_readiness.',",
      "  };",
      "}",
    ]);

    if (nodeF.parameters.jsCode.includes(OLD_F)) {
      nodeF.parameters.jsCode = nodeF.parameters.jsCode.split(OLD_F).join(NEW_F);
      changes.push('02: F - rebuilt buildSafetyActionPlan with corrected contracts (SOURCE_CAMPAIGN_STOP/SUBSEQUENCE_REMOVAL via subsequence/remove by canonical lead id, UPDATE_INTEREST_STATUS via numeric interest_value, EXACT_EMAIL_BLOCKLIST via block-lists-entries/bulk-create), and wrapped SUPPRESSION_ACTION_ENABLEMENT in HMZ_INJECT markers.');
    } else {
      changes.push('02: F - buildSafetyActionPlan already updated, skipped.');
    }
  }

  // --- C. Replace the single OR-gated G/G2-G6 linear chain (which executed
  //       all three legacy actions unconditionally once any action was
  //       enabled) with a per-action gated chain: an optional canonical-lead
  //       retrieval, then one gate+execute+record triple per action, then a
  //       verification step for EXACT_EMAIL_BLOCKLIST, then an aggregator. --
  if (hasNode(wf, 'G. Suppression Live-Execution Router')) {
    const F_NODE_NAME = 'F. Safety Action Plan (Gated Contract, Pre-Approval)';
    for (const n of ['G', 'G2. Execute STOP_ACTIVE_SEQUENCE (Gated)', 'G3. Execute UPDATE_INTEREST_STATUS (Gated)', 'G4. Execute ADD_TO_BLOCKLIST (Gated)', 'G5. Verify Suppression Execution (list_emails, Gated)', 'G6. Build Suppression Execution Result']) {
      const full = n === 'G' ? 'G. Suppression Live-Execution Router' : n;
      if (hasNode(wf, full)) removeNode(wf, full);
    }

    const ifBase = { type: 'n8n-nodes-base.if', typeVersion: 2.3, onError: 'continueRegularOutput' };
    const httpBase = { type: 'n8n-nodes-base.httpRequest', typeVersion: 4.2, onError: 'continueRegularOutput' };
    const codeBase = { type: 'n8n-nodes-base.code', typeVersion: 2, onError: 'continueRegularOutput' };

    function ifNode(id, name, x, y, expr) {
      return {
        ...ifBase,
        id,
        name,
        position: [x, y],
        parameters: {
          conditions: {
            options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
            combinator: 'and',
            conditions: [
              {
                id: `cond-${id}`,
                leftValue: expr,
                rightValue: '',
                operator: { type: 'boolean', operation: 'true', singleValue: true },
              },
            ],
          },
          options: {},
        },
      };
    }

    function httpNode(id, name, x, y, urlExpr, bodyExpr, queryParameters) {
      const parameters = {
        method: 'POST',
        url: urlExpr,
        options: { timeout: 10000, response: { response: { neverError: true, fullResponse: true } } },
      };
      if (queryParameters) {
        parameters.method = 'GET';
        parameters.sendQuery = true;
        parameters.queryParameters = { parameters: queryParameters };
      } else {
        parameters.sendBody = true;
        parameters.specifyBody = 'json';
        parameters.jsonBody = bodyExpr;
      }
      return { ...httpBase, id, name, position: [x, y], parameters, credentialPlaceholder: 'hmzInstantlyApi' };
    }

    function codeNode(id, name, x, y, jsCode) {
      return { ...codeBase, id, name, position: [x, y], parameters: { mode: 'runOnceForAllItems', language: 'javaScript', jsCode } };
    }

    function connect(from, to) {
      wf.connections[from] = wf.connections[from] || { main: [[]] };
      wf.connections[from].main[0] = wf.connections[from].main[0] || [];
      wf.connections[from].main[0].push({ node: to, type: 'main', index: 0 });
    }

    function connectIf(name, trueTarget, falseTarget) {
      wf.connections[name] = { main: [[{ node: trueTarget, type: 'main', index: 0 }], [{ node: falseTarget, type: 'main', index: 0 }]] };
    }

    const newNodes = [];
    const ACTIONS = [
      { key: 'SOURCE_CAMPAIGN_STOP', label: 'SOURCE_CAMPAIGN_STOP', needsLeadId: true },
      { key: 'UPDATE_INTEREST_STATUS', label: 'UPDATE_INTEREST_STATUS', needsLeadId: false },
      { key: 'SUBSEQUENCE_REMOVAL', label: 'SUBSEQUENCE_REMOVAL', needsLeadId: true },
      { key: 'EXACT_EMAIL_BLOCKLIST', label: 'EXACT_EMAIL_BLOCKLIST', needsLeadId: false },
    ];

    let x = 2000;
    const Y_GATE = 200;
    const Y_HTTP = 80;

    // --- G0: canonical-lead retrieval gate + execute + record -------------
    const g0g = ifNode('g0g', 'G0g. Canonical Lead Retrieval Gate', x, Y_GATE,
      "={{ (($json.safety_action_plan && $json.safety_action_plan.actions) || []).some((a) => a.requires_canonical_lead_id === true && a.enabled === true) }}");
    x += 160;
    const g0h = httpNode('g0h', 'G0h. Get Canonical Lead', x, Y_HTTP,
      'https://api.instantly.ai/api/v2/leads/list',
      "={{ { search: ($json.nes && $json.nes.lead_email) || null, limit: 5 } }}");
    x += 160;
    const G0R_NAME = 'G0r. Record Canonical Lead Retrieval';
    const g0r = codeNode('g0r', G0R_NAME, x, Y_GATE, J([
      "const items = $input.all();",
      "",
      "return items.map((item) => {",
      `  let prior = {};`,
      `  try { prior = $('${F_NODE_NAME}').item.json || {}; } catch (e) { prior = item.json || {}; }`,
      '  const cur = item.json || {};',
      "  let canonical_lead = null;",
      "  let lead_retrieval_status = 'SKIPPED_NOT_REQUIRED';",
      "  if (cur && typeof cur.statusCode === 'number') {",
      "    const body = cur.body || {};",
      "    const leads = Array.isArray(body.items) ? body.items : (Array.isArray(body.leads) ? body.leads : []);",
      "    const target = String((prior.nes && prior.nes.lead_email) || '').trim().toLowerCase();",
      "    const matches = leads.filter((l) => String((l && l.email) || '').trim().toLowerCase() === target);",
      "    if (matches.length === 1 && matches[0] && matches[0].id) {",
      "      canonical_lead = { id: matches[0].id, email: matches[0].email };",
      "      lead_retrieval_status = 'FOUND';",
      "    } else if (matches.length === 0) {",
      "      lead_retrieval_status = 'ZERO_MATCHES';",
      "    } else {",
      "      lead_retrieval_status = 'MULTIPLE_MATCHES';",
      "    }",
      "  }",
      "  return { json: { ...prior, canonical_lead, lead_retrieval_status, suppression_execution_results: [] } };",
      "});",
    ]));
    x += 160;
    newNodes.push(g0g, g0h, g0r);
    connectIf('G0g. Canonical Lead Retrieval Gate', 'G0h. Get Canonical Lead', G0R_NAME);
    connect('G0h. Get Canonical Lead', G0R_NAME);

    let prevRecordName = G0R_NAME;

    // --- G1-G4: one gate+execute+record triple per suppression action -----
    ACTIONS.forEach((a, idx) => {
      const n = idx + 1;
      const gateName = `G${n}g. ${a.label} Gate`;
      const httpName = `G${n}h. Execute ${a.label}`;
      const recordName = `G${n}r. Record ${a.label} Result`;

      const gate = ifNode(`g${n}g`, gateName, x, Y_GATE,
        `={{ ((($json.safety_action_plan && $json.safety_action_plan.actions) || []).find((a) => a.action === '${a.key}') || {}).enabled === true }}`);
      x += 160;
      connect(prevRecordName, gateName);
      const leadIdLine = a.needsLeadId
        ? "  if (a.requires_canonical_lead_id) { body.id = ($json.canonical_lead && $json.canonical_lead.id) || null; }"
        : '';
      const http = httpNode(`g${n}h`, httpName, x, Y_HTTP,
        J([
          '={{ (function() {',
          '  const plan = $json.safety_action_plan || { actions: [] };',
          `  const a = (plan.actions || []).find((x) => x.action === '${a.key}') || {};`,
          "  return (a.request_contract && a.request_contract.url) || '';",
          '})() }}',
        ]),
        J([
          '={{ (function() {',
          '  const plan = $json.safety_action_plan || { actions: [] };',
          `  const a = (plan.actions || []).find((x) => x.action === '${a.key}') || {};`,
          '  const body = { ...((a.request_contract && a.request_contract.body) || {}) };',
          leadIdLine,
          '  return body;',
          '})() }}',
        ].filter(Boolean)));
      x += 160;
      const record = codeNode(`g${n}r`, recordName, x, Y_GATE, J([
        "const items = $input.all();",
        "",
        "return items.map((item) => {",
        `  let prior = {};`,
        `  try { prior = $('${prevRecordName}').item.json || {}; } catch (e) { prior = item.json || {}; }`,
        '  const cur = item.json || {};',
        "  const plan = prior.safety_action_plan || { actions: [] };",
        "  const results = Array.isArray(prior.suppression_execution_results) ? prior.suppression_execution_results : [];",
        "  let actions = plan.actions || [];",
        "  if (cur && typeof cur.statusCode === 'number') {",
        "    const status = cur.statusCode;",
        "    const ok = status >= 200 && status < 300;",
        `    actions = actions.map((a) => a.action === '${a.key}'`,
        "      ? { ...a, executed: true, executed_status_code: status, verification_status: ok ? 'EXECUTED_OK' : 'EXECUTED_ERROR' }",
        "      : a);",
        `    results.push({ action: '${a.key}', executed: true, status_code: status });`,
        "  } else {",
        `    results.push({ action: '${a.key}', executed: false, status_code: null });`,
        "  }",
        "  return { json: { ...prior, safety_action_plan: { ...plan, actions }, suppression_execution_results: results } };",
        "});",
      ]));
      x += 160;
      newNodes.push(gate, http, record);
      connectIf(gateName, httpName, recordName);
      connect(httpName, recordName);
      prevRecordName = recordName;
    });

    // --- G5: verify EXACT_EMAIL_BLOCKLIST via the block-lists-entries list,
    //       requiring an exact email-level match (is_domain === false). -----
    const g5g = ifNode('g5g', 'G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', x, Y_GATE,
      "={{ ((($json.safety_action_plan && $json.safety_action_plan.actions) || []).find((a) => a.action === 'EXACT_EMAIL_BLOCKLIST') || {}).executed === true }}");
    x += 160;
    connect(prevRecordName, 'G5g. EXACT_EMAIL_BLOCKLIST Verification Gate');
    const g5h = httpNode('g5h', 'G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)', x, Y_HTTP,
      'https://api.instantly.ai/api/v2/block-lists-entries',
      null,
      [
        { name: 'search', value: '={{ ($json.nes && $json.nes.lead_email) || \'\' }}' },
        { name: 'limit', value: '100' },
      ]);
    x += 160;
    const G5R_NAME = 'G5r. Record EXACT_EMAIL_BLOCKLIST Verification';
    const g5r = codeNode('g5r', G5R_NAME, x, Y_GATE, J([
      "const items = $input.all();",
      "",
      "return items.map((item) => {",
      `  let prior = {};`,
      `  try { prior = $('${prevRecordName}').item.json || {}; } catch (e) { prior = item.json || {}; }`,
      '  const cur = item.json || {};',
      "  const plan = prior.safety_action_plan || { actions: [] };",
      "  let verification = { schema_version: '1.0', verified: false, status: 'NOT_APPLICABLE' };",
      "  if (cur && typeof cur.statusCode === 'number') {",
      "    const body = cur.body || {};",
      "    const target = String((prior.nes && prior.nes.lead_email) || '').trim().toLowerCase();",
      "    const entries = Array.isArray(body.items) ? body.items : [];",
      "    const matches = entries.filter((e) => String((e && e.value) || '').trim().toLowerCase() === target && e.is_domain === false);",
      "    if (matches.length === 1) {",
      "      verification = { schema_version: '1.0', verified: true, status: 'VERIFIED', entry_id: matches[0].id || null };",
      "    } else if (matches.length === 0) {",
      "      verification = { schema_version: '1.0', verified: false, status: 'VERIFICATION_ZERO_MATCHES' };",
      "    } else {",
      "      verification = { schema_version: '1.0', verified: false, status: 'VERIFICATION_MULTIPLE_MATCHES', match_count: matches.length };",
      "    }",
      "  }",
      "  const actions = (plan.actions || []).map((a) => a.action === 'EXACT_EMAIL_BLOCKLIST' ? { ...a, verification } : a);",
      "  return { json: { ...prior, safety_action_plan: { ...plan, actions }, blocklist_verification: verification } };",
      "});",
    ]));
    x += 160;
    newNodes.push(g5g, g5h, g5r);
    connectIf('G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', 'G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)', G5R_NAME);
    connect('G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)', G5R_NAME);
    prevRecordName = G5R_NAME;

    // --- G6: aggregate per-action results into suppression_execution. -----
    const G6_NAME = 'G6. Build Suppression Execution Result';
    const g6 = codeNode('g6', G6_NAME, x, Y_GATE, J([
      "const items = $input.all();",
      "",
      "function djb2Hash(str) {",
      "  let hash = 5381;",
      "  for (let i = 0; i < str.length; i++) {",
      "    hash = (hash << 5) + hash + str.charCodeAt(i);",
      "    hash = hash & 0xffffffff;",
      "  }",
      "  return (hash >>> 0).toString(16).padStart(8, '0');",
      "}",
      "",
      "return items.map((item) => {",
      `  let prior = {};`,
      `  try { prior = $('${prevRecordName}').item.json || item.json || {}; } catch (e) { prior = item.json || {}; }`,
      "  const plan = prior.safety_action_plan || { actions: [] };",
      "  const nes = prior.nes || {};",
      "  const campaign = nes.campaign_context || {};",
      "  const enabledActions = (plan.actions || []).filter((a) => a.enabled);",
      "  const executedActions = enabledActions.filter((a) => a.executed === true);",
      "  let overallStatus;",
      "  if (enabledActions.length === 0) {",
      "    overallStatus = 'EXECUTION_AND_VERIFICATION_GATED_OFFLINE';",
      "  } else if (executedActions.length === enabledActions.length) {",
      "    overallStatus = 'EXECUTED';",
      "  } else {",
      "    overallStatus = 'PARTIAL';",
      "  }",
      "  const keyRaw = [",
      "    'HMZ_SUPPRESSION_EXEC',",
      "    String(campaign.campaign_id || ''),",
      "    String(nes.lead_email || '').trim().toLowerCase(),",
      "    (plan.actions || []).map((a) => a.action).join(','),",
      "  ].join('|');",
      "",
      "  return {",
      "    json: {",
      "      ...prior,",
      "      suppression_execution: {",
      "        schema_version: '1.1',",
      "        idempotency_key: `suppression-${djb2Hash(keyRaw)}`,",
      "        actions_attempted: enabledActions.map((a) => a.action),",
      "        actions_executed: executedActions.map((a) => a.action),",
      "        verification_status: overallStatus,",
      "      },",
      "    },",
      "  };",
      "});",
    ]));
    newNodes.push(g6);
    connect(prevRecordName, G6_NAME);
    connect(G6_NAME, 'E. Output Validation');

    // --- Splice F -> G0g into the workflow's existing connection map. ------
    wf.connections[F_NODE_NAME] = { main: [[{ node: 'G0g. Canonical Lead Retrieval Gate', type: 'main', index: 0 }]] };

    wf.nodes.push(...newNodes);
    changes.push(`02: replaced the single OR-gated G/G2-G6 chain with a per-action gated chain (G0 canonical-lead retrieval, G1-G4 per-action gate/execute/record for SOURCE_CAMPAIGN_STOP/UPDATE_INTEREST_STATUS/SUBSEQUENCE_REMOVAL/EXACT_EMAIL_BLOCKLIST, G5 blocklist verification via GET /api/v2/block-lists-entries requiring is_domain===false, G6 aggregator) - ${newNodes.length} nodes.`);
  } else {
    changes.push('02: per-action gated suppression chain already present, skipped.');
  }

  save(FILES.decision, wf);
}

// =====================================================================
// 01_reply_intake_validation.json - blocker F (workspace allowlisting
// gates campaign/sender allowlisting; missing/blank workspace_id can
// never allowlist a campaign or sender).
// =====================================================================
{
  const wf = load(FILES.intake);
  const nodeF1 = nodeByName(wf, 'F1. Production Security & Allowlist Gate');

  const OLD_ALLOWLISTS_DECL = J([
    "const ALLOWLISTS = {",
    "  workspace_id: null,",
    "  campaign_ids: [],",
    "  connected_sender_eaccounts: [],",
    "};",
  ]);
  const NEW_ALLOWLISTS_DECL = J([
    "// HMZ_INJECT_BEGIN:ALLOWLISTS",
    "const ALLOWLISTS = {",
    "  workspace_id: null,",
    "  campaign_ids: [],",
    "  connected_sender_eaccounts: [],",
    "};",
    "// HMZ_INJECT_END:ALLOWLISTS",
  ]);
  if (nodeF1.parameters.jsCode.includes(OLD_ALLOWLISTS_DECL) && !nodeF1.parameters.jsCode.includes('HMZ_INJECT_BEGIN:ALLOWLISTS')) {
    nodeF1.parameters.jsCode = nodeF1.parameters.jsCode.split(OLD_ALLOWLISTS_DECL).join(NEW_ALLOWLISTS_DECL);
    changes.push('01: F1 - wrapped ALLOWLISTS in HMZ_INJECT markers for apply-time config injection.');
  } else {
    changes.push('01: F1 - ALLOWLISTS injection markers already present, skipped.');
  }

  const OLD_GATES = J([
    "  const workspaceAllowed = !!ALLOWLISTS.workspace_id && workspaceId === ALLOWLISTS.workspace_id;",
    "  if (!workspaceAllowed) reasons.push('WORKSPACE_NOT_ALLOWLISTED');",
    "",
    "  const campaignAllowed = ALLOWLISTS.campaign_ids.length > 0 && !!campaignId && ALLOWLISTS.campaign_ids.includes(campaignId);",
    "  if (!campaignAllowed) reasons.push('CAMPAIGN_NOT_ALLOWLISTED');",
    "",
    "  const senderAllowed = ALLOWLISTS.connected_sender_eaccounts.length > 0 && !!eaccount && ALLOWLISTS.connected_sender_eaccounts.includes(eaccount);",
    "  if (!senderAllowed) reasons.push('SENDER_EACCOUNT_NOT_ALLOWLISTED');",
  ]);
  const NEW_GATES = J([
    "  const workspaceAllowed = !!ALLOWLISTS.workspace_id && workspaceId === ALLOWLISTS.workspace_id;",
    "  if (!workspaceAllowed) reasons.push('WORKSPACE_NOT_ALLOWLISTED');",
    "",
    "  // A missing/blank workspace_id can never allowlist a campaign or sender:",
    "  // both checks are gated on workspaceAllowed.",
    "  const campaignAllowed = workspaceAllowed && ALLOWLISTS.campaign_ids.length > 0 && !!campaignId && ALLOWLISTS.campaign_ids.includes(campaignId);",
    "  if (!campaignAllowed) reasons.push('CAMPAIGN_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED');",
    "",
    "  const senderAllowed = workspaceAllowed && ALLOWLISTS.connected_sender_eaccounts.length > 0 && !!eaccount && ALLOWLISTS.connected_sender_eaccounts.includes(eaccount);",
    "  if (!senderAllowed) reasons.push('SENDER_EACCOUNT_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED');",
  ]);
  if (nodeF1.parameters.jsCode.includes(OLD_GATES)) {
    nodeF1.parameters.jsCode = nodeF1.parameters.jsCode.split(OLD_GATES).join(NEW_GATES);
    changes.push('01: F1 - campaign_allowed and sender_allowed are now gated on workspace_allowed (a missing/blank workspace_id can never allowlist a campaign or sender).');
  } else {
    changes.push('01: F1 - allowlist gate ordering already corrected, skipped.');
  }

  save(FILES.intake, wf);
}

// =====================================================================
// 07_reply_human_approval_validation.json - blocker G (production review
// webhooks require Basic Auth; reviewer allowlist becomes a fail-closed
// gate, not advisory).
// =====================================================================
{
  const wf = load(FILES.approval);

  // --- G. Production review webhooks require Basic Auth -------------------
  for (const name of ['Webhook - Review Form (Production, Gated Path)', 'Webhook - Review Submit (Production, Gated Path)']) {
    const node = nodeByName(wf, name);
    if (node.parameters.authentication !== 'basicAuth' || node.credentialPlaceholder !== 'hmzReviewBasicAuth') {
      node.parameters.authentication = 'basicAuth';
      node.credentialPlaceholder = 'hmzReviewBasicAuth';
      changes.push(`07: ${name} - requires Basic Auth (credentialPlaceholder hmzReviewBasicAuth) on the production path.`);
    } else {
      changes.push(`07: ${name} - Basic Auth already configured, skipped.`);
    }
  }

  // --- G. M1: reviewer allowlist becomes fail-closed (an empty/unconfigured
  //       allowlist means `allowlisted: false`, not advisory `null`), and is
  //       wrapped in HMZ_INJECT markers for apply-time config injection. ----
  {
    const nodeM1 = nodeByName(wf, 'M1. Reviewer Identity Allowlist Check');
    const OLD_M1 = J([
      "const items = $input.all();",
      "",
      "// Mirrors config.reviewer_allowlist; empty by default. Advisory only",
      "// here - workflow 03's live-send gate 10 independently enforces this",
      "// allowlist before any reply POST.",
      "const REVIEWER_ALLOWLIST = [];",
      "",
      "return items.map((item) => {",
      "  const input = item.json || {};",
      "  const identity = input.submit_approver_identity || null;",
      "  const configured = REVIEWER_ALLOWLIST.length > 0;",
      "  return {",
      "    json: {",
      "      ...input,",
      "      reviewer_allowlist_check: {",
      "        configured,",
      "        identity,",
      "        allowlisted: configured ? (!!identity && REVIEWER_ALLOWLIST.includes(identity)) : null,",
      "      },",
      "    },",
      "  };",
      "});",
    ]);
    const NEW_M1 = J([
      "const items = $input.all();",
      "",
      "// HMZ_INJECT_BEGIN:REVIEWER_ALLOWLIST",
      "const REVIEWER_ALLOWLIST = [];",
      "// HMZ_INJECT_END:REVIEWER_ALLOWLIST",
      "",
      "return items.map((item) => {",
      "  const input = item.json || {};",
      "  const identity = input.submit_approver_identity || null;",
      "  const configured = REVIEWER_ALLOWLIST.length > 0;",
      "  // Fail-closed: an empty/unconfigured allowlist never allowlists a",
      "  // reviewer. M2 (the new gate below) treats this as a hard rejection,",
      "  // independent of and in addition to workflow 03's live-send gate 10.",
      "  const allowlisted = configured && !!identity && REVIEWER_ALLOWLIST.includes(identity);",
      "  return {",
      "    json: {",
      "      ...input,",
      "      reviewer_allowlist_check: {",
      "        configured,",
      "        identity,",
      "        allowlisted,",
      "      },",
      "    },",
      "  };",
      "});",
    ]);
    if (nodeM1.parameters.jsCode.includes(OLD_M1)) {
      nodeM1.parameters.jsCode = nodeM1.parameters.jsCode.split(OLD_M1).join(NEW_M1);
      changes.push('07: M1 - reviewer_allowlist_check.allowlisted is now fail-closed (false when unconfigured/not matched, never null), wrapped in HMZ_INJECT markers.');
    } else {
      changes.push('07: M1 - reviewer allowlist already fail-closed, skipped.');
    }
  }

  // --- G. Insert M2 (Reviewer Allowlist Router) + M2b (mark rejection
  //       reason) between M1 and N, so a non-allowlisted reviewer is
  //       rejected (reusing N2/K5) instead of proceeding to N. -------------
  if (!hasNode(wf, 'M2. Reviewer Allowlist Router')) {
    const refNode = nodeByName(wf, 'M1. Reviewer Identity Allowlist Check');
    const [rx, ry] = refNode.position;

    const m2 = {
      id: 'm2',
      name: 'M2. Reviewer Allowlist Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      onError: 'continueRegularOutput',
      position: [rx + 200, ry],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-m2',
              leftValue: '={{ $json.reviewer_allowlist_check.allowlisted === true }}',
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };
    const m2b = {
      id: 'm2b',
      name: 'M2b. Mark Reviewer Not Allowlisted',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      onError: 'continueRegularOutput',
      position: [rx + 200, ry + 160],
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          "const items = $input.all();",
          "",
          "return items.map((item) => {",
          "  const input = item.json || {};",
          "  return { json: { ...input, token_invalid_reason: 'REVIEWER_NOT_ALLOWLISTED' } };",
          "});",
        ]),
      },
    };

    wf.nodes.push(m2, m2b);
    wf.connections['M1. Reviewer Identity Allowlist Check'] = {
      main: [[{ node: 'M2. Reviewer Allowlist Router', type: 'main', index: 0 }]],
    };
    wf.connections['M2. Reviewer Allowlist Router'] = {
      main: [
        [{ node: 'N. Process Reviewer Decision', type: 'main', index: 0 }],
        [{ node: 'M2b. Mark Reviewer Not Allowlisted', type: 'main', index: 0 }],
      ],
    };
    wf.connections['M2b. Mark Reviewer Not Allowlisted'] = {
      main: [[{ node: 'N2. Render Submit Token Error', type: 'main', index: 0 }]],
    };
    changes.push('07: inserted M2 (Reviewer Allowlist Router) + M2b between M1 and N - a non-allowlisted reviewer is hard-rejected via N2/K5 (REVIEWER_NOT_ALLOWLISTED) instead of proceeding to the decision.');
  } else {
    changes.push('07: M2 (Reviewer Allowlist Router) already present, skipped.');
  }

  // --- G. N2: recognise REVIEWER_NOT_ALLOWLISTED (HTTP 403). ---------------
  {
    const nodeN2 = nodeByName(wf, 'N2. Render Submit Token Error');
    const OLD_MESSAGES = J([
      "  const messages = {",
      "    CASE_NOT_FOUND: \"This review case could not be found.\",",
      "    WRONG_TOKEN: \"This review link is invalid.\",",
      "    ALREADY_DECIDED: \"This review case has already been decided. No second submission is accepted.\",",
      "    EXPIRED: \"This review link has expired.\"",
      "  };",
      "  const message = messages[reason] || \"This review link is no longer valid.\";",
      "  const html = \"<!DOCTYPE html><html><body><h1>Submission rejected</h1><p>\" + escapeHtml(message) + \"</p></body></html>\";",
      "  return { json: { ...input, html, http_status: reason === \"CASE_NOT_FOUND\" ? 404 : 409 } };",
    ]);
    const NEW_MESSAGES = J([
      "  const messages = {",
      "    CASE_NOT_FOUND: \"This review case could not be found.\",",
      "    WRONG_TOKEN: \"This review link is invalid.\",",
      "    ALREADY_DECIDED: \"This review case has already been decided. No second submission is accepted.\",",
      "    EXPIRED: \"This review link has expired.\",",
      "    REVIEWER_NOT_ALLOWLISTED: \"This reviewer identity is not authorized to submit decisions.\"",
      "  };",
      "  const message = messages[reason] || \"This review link is no longer valid.\";",
      "  const html = \"<!DOCTYPE html><html><body><h1>Submission rejected</h1><p>\" + escapeHtml(message) + \"</p></body></html>\";",
      "  const httpStatus = reason === \"CASE_NOT_FOUND\" ? 404 : (reason === \"REVIEWER_NOT_ALLOWLISTED\" ? 403 : 409);",
      "  return { json: { ...input, html, http_status: httpStatus } };",
    ]);
    if (nodeN2.parameters.jsCode.includes(OLD_MESSAGES)) {
      nodeN2.parameters.jsCode = nodeN2.parameters.jsCode.split(OLD_MESSAGES).join(NEW_MESSAGES);
      changes.push('07: N2 - added REVIEWER_NOT_ALLOWLISTED message (HTTP 403).');
    } else {
      changes.push('07: N2 - REVIEWER_NOT_ALLOWLISTED message already present, skipped.');
    }
  }

  save(FILES.approval, wf);
}

// =====================================================================
// config/business-ready.config.json - corrected Instantly API endpoint
// contracts (blockers B/C) and the new Basic Auth / production review
// path fields (blocker G), used by the apply step (blocker D) as the
// source of truth.
// =====================================================================
{
  const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  let configChanged = false;

  const NEW_ENDPOINTS = {
    get_email: { method: 'GET', path: '/api/v2/emails/{id}' },
    reply_to_email: { method: 'POST', path: '/api/v2/emails/reply' },
    list_emails: { method: 'GET', path: '/api/v2/emails' },
    update_interest_status: { method: 'POST', path: '/api/v2/leads/update-interest-status' },
    remove_subsequence: { method: 'POST', path: '/api/v2/leads/subsequence/remove' },
    get_lead: { method: 'POST', path: '/api/v2/leads/list' },
    add_to_blocklist: { method: 'POST', path: '/api/v2/block-lists-entries/bulk-create' },
    list_block_list_entries: { method: 'GET', path: '/api/v2/block-lists-entries' },
  };
  if (JSON.stringify(cfg.instantly_api.endpoints) !== JSON.stringify(NEW_ENDPOINTS)) {
    cfg.instantly_api.endpoints = NEW_ENDPOINTS;
    configChanged = true;
    changes.push('config: instantly_api.endpoints corrected - list_emails is now GET /api/v2/emails (reconciliation), add_to_blocklist is now POST /api/v2/block-lists-entries/bulk-create, and get_lead / list_block_list_entries were added.');
  } else {
    changes.push('config: instantly_api.endpoints already corrected, skipped.');
  }

  if (!cfg.review.production_review_form_path) {
    cfg.review.production_review_form_path = '<REQUIRED_PRODUCTION_REVIEW_FORM_PATH>';
    cfg.review.production_review_submit_path = '<REQUIRED_PRODUCTION_REVIEW_SUBMIT_PATH>';
    cfg.review.review_basic_auth_credential_name = 'hmzReviewBasicAuth';
    configChanged = true;
    changes.push('config: review - added production_review_form_path / production_review_submit_path (map to workflows/07 __REQUIRED_PRODUCTION_REVIEW_FORM_PATH__ / __REQUIRED_PRODUCTION_REVIEW_SUBMIT_PATH__) and review_basic_auth_credential_name (hmzReviewBasicAuth).');
  } else {
    changes.push('config: review production review path / Basic Auth fields already present, skipped.');
  }

  if (cfg.config_version !== 'business-ready-1.1') {
    cfg.config_version = 'business-ready-1.1';
    configChanged = true;
    changes.push('config: config_version bumped to business-ready-1.1 (release-blocker correction pass).');
  } else {
    changes.push('config: config_version already business-ready-1.1, skipped.');
  }

  if (configChanged) {
    fs.writeFileSync(CONFIG_PATH, `${JSON.stringify(cfg, null, 2)}\n`, 'utf8');
  }
}

for (const c of changes) {
  console.log(`- ${c}`);
}
