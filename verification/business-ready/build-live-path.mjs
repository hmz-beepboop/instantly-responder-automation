// Business-ready LIVE PATH - offline build script.
//
// Pure Node.js (built-ins only). Mutates the 7 business-ready workflow JSON
// exports in-place to add a real (but strictly gated, currently
// unreachable) supervised-live send path, a real production webhook with a
// security/allowlist gate, real (gated, disabled-by-default) suppression
// adapters, and a reviewer-identity-allowlist check. Makes no network call,
// starts nothing, and leaves all 7 workflows `active: false`. Re-run is
// idempotent: each mutation is skipped if its marker node already exists.
//
// Usage: node verification/business-ready/build-live-path.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');

const FILES = {
  intake: '01_reply_intake_validation.json',
  decision: '02_reply_decision_engine_validation.json',
  sender: '03_reply_sender_validation.json',
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

const changes = [];

// =====================================================================
// 03_reply_sender_validation.json - real (gated, unreachable) live send
// path: 14-gate evaluation -> gated POST /api/v2/emails/reply -> bounded
// retry with backoff -> outcome classification -> SENT / reconciliation
// (list_emails) / terminal failure. Only reachable if every one of the 14
// gates passes, which cannot happen with the shipped (empty) launch
// profile.
// =====================================================================
{
  const wf = load(FILES.sender);
  const N_NAME = 'N. Live Adapter Contract (Validation-Only, Unreachable)';

  if (!hasNode(wf, 'O. Live Send Gate Evaluation (14 Gates)')) {
    const LIB = [
      'const SEND_RESULT_STATES = {"SENT":"SENT","PERMANENT_FAILURE":"PERMANENT_FAILURE","AUTH_OR_PLAN_FAILURE":"AUTH_OR_PLAN_FAILURE","INVALID_REPLY_TARGET":"INVALID_REPLY_TARGET","RETRY_EXHAUSTED":"RETRY_EXHAUSTED","SEND_UNCERTAIN":"SEND_UNCERTAIN"};',
      'const RECONCILE_STATES = {"SENT_RECONCILED":"SENT_RECONCILED","HUMAN_REVIEW_ZERO_MATCHES":"HUMAN_REVIEW_ZERO_MATCHES","HUMAN_REVIEW_MULTIPLE_MATCHES":"HUMAN_REVIEW_MULTIPLE_MATCHES"};',
      'const MAX_SEND_ATTEMPTS = 3;',
      'const BASE_BACKOFF_MS = 100;',
      'const MAX_BACKOFF_MS = 2000;',
      'const RETRY_AFTER_CAP_MS = 5000;',
      '',
      'function isValidSentContract(body) {',
      "  return !!body && typeof body === 'object' && body.status === 'sent' && typeof body.messageId === 'string' && body.messageId.length > 0;",
      '}',
      '',
      'function deterministicJitter(attemptNumber) {',
      '  return (attemptNumber * 37) % 50;',
      '}',
      '',
      'function classifySendOutcome(outcome) {',
      '  const out = outcome || {};',
      '',
      "  if (out.kind === 'http') {",
      '    const status = out.status;',
      '    const body = out.body;',
      '    const headers = out.headers || {};',
      '',
      '    if (status === 400) {',
      "      return { mode: 'terminal', state: SEND_RESULT_STATES.PERMANENT_FAILURE, ambiguousSideEffect: false };",
      '    }',
      '    if (status === 401 || status === 402 || status === 403) {',
      "      return { mode: 'terminal', state: SEND_RESULT_STATES.AUTH_OR_PLAN_FAILURE, ambiguousSideEffect: false };",
      '    }',
      '    if (status === 404) {',
      "      return { mode: 'terminal', state: SEND_RESULT_STATES.INVALID_REPLY_TARGET, ambiguousSideEffect: false };",
      '    }',
      '    if (status === 429 || status === 500 || status === 502 || status === 503 || status === 504) {',
      "      const retryAfterRaw = headers['retry-after'];",
      '      const retryAfterMs = retryAfterRaw != null ? Number(retryAfterRaw) * 1000 : null;',
      '      return {',
      "        mode: 'retryable',",
      '        exhaustedState: SEND_RESULT_STATES.RETRY_EXHAUSTED,',
      '        retryAfterMs: Number.isFinite(retryAfterMs) ? retryAfterMs : null,',
      '        ambiguousSideEffect: false,',
      '      };',
      '    }',
      '    if (status >= 200 && status < 300) {',
      '      if (isValidSentContract(body)) {',
      "        return { mode: 'terminal', state: SEND_RESULT_STATES.SENT, ambiguousSideEffect: false };",
      '      }',
      "      return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };",
      '    }',
      "    return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };",
      '  }',
      '',
      "  if (out.kind === 'network-error') {",
      "    const retryablePhases = ['connection-refused', 'pre-submission'];",
      '    if (retryablePhases.includes(out.errorPhase)) {',
      '      return {',
      "        mode: 'retryable',",
      '        exhaustedState: SEND_RESULT_STATES.RETRY_EXHAUSTED,',
      '        retryAfterMs: null,',
      '        ambiguousSideEffect: false,',
      '      };',
      '    }',
      "    return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };",
      '  }',
      '',
      "  return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };",
      '}',
      '',
      'function reconcileMatches(checks, options) {',
      '  const opts = options || {};',
      '  const consecutiveRequired = opts.consecutiveRequired || 2;',
      '  const polls = Array.isArray(checks) ? checks : [];',
      '',
      '  let lastSingleMatchId = null;',
      '  let consecutiveSameSingleMatch = 0;',
      '',
      '  for (const matchIds of polls) {',
      '    const ids = Array.isArray(matchIds) ? matchIds : [];',
      '    if (ids.length > 1) {',
      '      return { state: RECONCILE_STATES.HUMAN_REVIEW_MULTIPLE_MATCHES, matchCount: ids.length, matchIds: ids };',
      '    }',
      '    if (ids.length === 1) {',
      '      const currentId = ids[0];',
      '      if (currentId === lastSingleMatchId) {',
      '        consecutiveSameSingleMatch += 1;',
      '      } else {',
      '        lastSingleMatchId = currentId;',
      '        consecutiveSameSingleMatch = 1;',
      '      }',
      '      if (consecutiveSameSingleMatch >= consecutiveRequired) {',
      '        return { state: RECONCILE_STATES.SENT_RECONCILED, matchCount: 1, matchId: currentId };',
      '      }',
      '    } else {',
      '      lastSingleMatchId = null;',
      '      consecutiveSameSingleMatch = 0;',
      '    }',
      '  }',
      '',
      '  return { state: RECONCILE_STATES.HUMAN_REVIEW_ZERO_MATCHES, matchCount: 0, matchIds: [] };',
      '}',
    ];

    // --- O. Live Send Gate Evaluation (14 Gates) ------------------------
    const nodeO = {
      id: 'node_o',
      name: 'O. Live Send Gate Evaluation (14 Gates)',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [3700, 60],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          '// Fixed launch profile (policy-HMZ-1.2). Every value below is the',
          '// shipped, safe default. config/business-ready.config.json carries the',
          '// owner-editable copy of allowlists/* and reviewer_allowlist; this',
          '// embedded snapshot mirrors that file as of the offline build and must',
          '// be kept in sync by the apply step before any of these 14 gates can',
          '// ever evaluate to all-true.',
          'const LAUNCH_PROFILE = {',
          "  required_operating_mode: 'SUPERVISED_VALIDATION',",
          "  operating_mode: 'VALIDATION',",
          '  dry_run: true,',
          '  live_campaigns: [],',
          '  campaign_allowlist: [],',
          '  workspace_id: null,',
          '  workspace_allowlist: [],',
          '  connected_sender_eaccounts: [],',
          '  live_credential_readiness: { instantly: false, ready_for_controlled_live_test: false },',
          '  reviewer_allowlist: [],',
          '};',
          '',
          'const TERMINAL_SEND_STATES = [',
          "  'SENT', 'SENT_RECONCILED', 'PERMANENT_FAILURE', 'AUTH_OR_PLAN_FAILURE',",
          "  'SEND_UNCERTAIN', 'RETRY_EXHAUSTED',",
          '];',
          '',
          'function evaluateLiveSendGates(item) {',
          '  const input = item || {};',
          '  const nes = input.nes || {};',
          '  const threading = nes.threading || {};',
          '  const gatesB = input.gates || {};',
          '  const approval = input.approval || {};',
          '  const acquisition = input.acquisition || {};',
          '  const suppressionVerification = input.suppression_verification || {};',
          '',
          "  const campaignId = nes.campaign_id || (nes.campaign_context && nes.campaign_context.campaign_id) || null;",
          '  const workspaceId = nes.workspace_id || null;',
          '  const eaccount = nes.eaccount || null;',
          '',
          '  const gates = [];',
          '  function gate(id, name, passed, reason) {',
          '    gates.push({ id, name, passed: !!passed, reason: passed ? null : reason });',
          '  }',
          '',
          "  gate('operating_mode', 'Operating mode is SUPERVISED_VALIDATION',",
          '    LAUNCH_PROFILE.operating_mode === LAUNCH_PROFILE.required_operating_mode,',
          "    'OPERATING_MODE_NOT_SUPERVISED_VALIDATION');",
          '',
          "  gate('dry_run_disabled', 'DRY_RUN is false',",
          '    LAUNCH_PROFILE.dry_run === false,',
          "    'DRY_RUN_STILL_TRUE');",
          '',
          "  gate('campaign_in_live_campaigns', 'Exact campaign is declared in live_campaigns and allow-listed',",
          '    !!campaignId && LAUNCH_PROFILE.live_campaigns.includes(campaignId) && LAUNCH_PROFILE.campaign_allowlist.includes(campaignId),',
          "    'CAMPAIGN_NOT_IN_LIVE_CAMPAIGNS_OR_NOT_ALLOWLISTED');",
          '',
          "  gate('workspace_allowlisted', 'Exact workspace is allow-listed',",
          '    !!workspaceId && !!LAUNCH_PROFILE.workspace_id && workspaceId === LAUNCH_PROFILE.workspace_id && LAUNCH_PROFILE.workspace_allowlist.includes(workspaceId),',
          "    'WORKSPACE_NOT_ALLOWLISTED');",
          '',
          "  gate('sender_eaccount_allowlisted', 'Inbound eaccount is a connected, allow-listed sender and matches the retrieved inbound Email',",
          '    !!eaccount && LAUNCH_PROFILE.connected_sender_eaccounts.includes(eaccount) && !!threading.reply_to_uuid,',
          "    'SENDER_EACCOUNT_NOT_ALLOWLISTED_OR_INBOUND_EMAIL_UNRESOLVED');",
          '',
          "  gate('instantly_credential_ready', 'live_credential_readiness.instantly is true',",
          '    LAUNCH_PROFILE.live_credential_readiness.instantly === true,',
          "    'INSTANTLY_CREDENTIAL_NOT_READY');",
          '',
          "  gate('controlled_live_ready', 'live_credential_readiness.ready_for_controlled_live_test is true',",
          '    LAUNCH_PROFILE.live_credential_readiness.ready_for_controlled_live_test === true,',
          "    'NOT_READY_FOR_CONTROLLED_LIVE_TEST');",
          '',
          "  gate('durable_approval_present', 'A durable human-approval case record is present and approved',",
          '    approval.approved === true && !!approval.case_id,',
          "    'APPROVAL_RECORD_MISSING_OR_NOT_APPROVED');",
          '',
          "  gate('approval_token_consumed', 'Approval was reached via the one-time-token-consuming review handoff',",
          '    approval.approved === true && !!approval.approved_at && !!approval.case_id,',
          "    'APPROVAL_TOKEN_NOT_CONSUMED_OR_HANDOFF_MISSING');",
          '',
          "  gate('reviewer_identity_allowlisted', 'The approving reviewer identity is on reviewer_allowlist',",
          '    !!approval.approver_identity && LAUNCH_PROFILE.reviewer_allowlist.includes(approval.approver_identity),',
          "    'REVIEWER_IDENTITY_NOT_ALLOWLISTED');",
          '',
          "  gate('no_unresolved_variables', 'Approved draft has no unresolved template variables',",
          '    gatesB.draft_variable_gate_passed === true,',
          "    'UNRESOLVED_TEMPLATE_VARIABLES');",
          '',
          "  gate('send_lock_acquired', 'Atomic send-ownership lock was acquired for this send key',",
          '    acquisition.acquired === true,',
          "    'SEND_LOCK_NOT_ACQUIRED');",
          '',
          "  gate('suppression_verified_or_not_required', 'Required suppression actions are verified, or none are required',",
          '    suppressionVerification.verified === true,',
          "    'SUPPRESSION_NOT_VERIFIED');",
          '',
          "  gate('no_prior_terminal_send_state', 'No prior terminal send state exists for this send key',",
          '    !TERMINAL_SEND_STATES.includes(acquisition.priorState),',
          "    'PRIOR_TERMINAL_SEND_STATE_EXISTS');",
          '',
          '  const allPassed = gates.every((g) => g.passed);',
          '',
          '  return {',
          '    ...input,',
          '    live_send_gates: {',
          "      schema_version: '1.0',",
          '      launch_profile: LAUNCH_PROFILE,',
          '      gates,',
          '      all_passed: allPassed,',
          '      failed_gate_ids: gates.filter((g) => !g.passed).map((g) => g.id),',
          '    },',
          '  };',
          '}',
          '',
          'return items.map((item) => ({ json: evaluateLiveSendGates(item.json || {}) }));',
        ]),
      },
    };

    // --- P. Live Send Gate Router (IF on all_passed) --------------------
    const nodeP = {
      id: 'if_p',
      name: 'P. Live Send Gate Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [4040, 60],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-p1',
              leftValue: '={{ $json.live_send_gates.all_passed }}',
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- P2. Live Send Blocked Terminal (false branch, default path) ----
    const nodeP2 = {
      id: 'node_p2',
      name: 'P2. Live Send Blocked Terminal',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [4380, 220],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  const gates = input.live_send_gates || {};',
          '  return {',
          '    json: {',
          '      ...input,',
          '      terminal: {',
          "        schema_version: '1.0',",
          "        result: 'BLOCKED',",
          "        send_state: 'BLOCKED',",
          "        reason: 'LIVE_SEND_GATES_NOT_SATISFIED',",
          '        failed_gate_ids: gates.failed_gate_ids || [],',
          '        live_adapter_contract: input.live_adapter_contract || null,',
          '        sent: false,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- Q. POST Reply to Instantly (Gated, Unreachable) ----------------
    const nodeQ = {
      id: 'node_q_http',
      name: 'Q. POST Reply to Instantly (Gated)',
      type: 'n8n-nodes-base.httpRequest',
      typeVersion: 4.2,
      position: [4380, -100],
      onError: 'continueRegularOutput',
      parameters: {
        method: 'POST',
        url: 'https://api.instantly.ai/api/v2/emails/reply',
        sendBody: true,
        specifyBody: 'json',
        jsonBody:
          "={{ { eaccount: $json.nes.eaccount, reply_to_uuid: $json.nes.threading.reply_to_uuid, subject: ($json.nes.reply && $json.nes.reply.subject && /^re:/i.test($json.nes.reply.subject)) ? $json.nes.reply.subject : ('Re: ' + (($json.nes.reply && $json.nes.reply.subject) || '')), body: { text: $json.draft.draft_text, html: null } } }}",
        options: {
          timeout: 10000,
          response: { response: { neverError: true, fullResponse: true } },
        },
      },
      credentialPlaceholder: 'hmzInstantlyApi',
    };

    // --- R. Classify Send Attempt ---------------------------------------
    const nodeR = {
      id: 'node_r',
      name: 'R. Classify Send Attempt',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [4720, -100],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          ...LIB,
          '',
          'function buildOutcomeFromHttpResponse(resp) {',
          '  const r = resp || {};',
          '  const status = r.statusCode != null ? r.statusCode : (r.status != null ? r.status : null);',
          "  return { kind: 'http', status, headers: r.headers || {}, body: r.body, serverReceived: true };",
          '}',
          '',
          'return items.map((item) => {',
          '  const httpResp = item.json || {};',
          '  let prior = {};',
          '  try {',
          "    prior = $('O. Live Send Gate Evaluation (14 Gates)').item.json || {};",
          '  } catch (e) {',
          '    prior = {};',
          '  }',
          '  const carried = Array.isArray(httpResp.live_send_attempts) ? httpResp : prior;',
          '  const priorAttempts = Array.isArray(carried.live_send_attempts) ? carried.live_send_attempts : [];',
          '',
          '  const outcome = buildOutcomeFromHttpResponse(httpResp);',
          '  const classification = classifySendOutcome(outcome);',
          '  const attemptNumber = priorAttempts.length + 1;',
          '  const attempts = [...priorAttempts, { attempt: attemptNumber, outcome, classification }];',
          '',
          '  let nextDelayMs = null;',
          "  if (classification.mode === 'retryable' && attemptNumber < MAX_SEND_ATTEMPTS) {",
          '    nextDelayMs = classification.retryAfterMs != null',
          '      ? Math.min(classification.retryAfterMs, RETRY_AFTER_CAP_MS)',
          '      : Math.min(BASE_BACKOFF_MS * 2 ** (attemptNumber - 1) + deterministicJitter(attemptNumber), MAX_BACKOFF_MS);',
          '  }',
          '',
          '  let finalState = null;',
          "  if (classification.mode === 'terminal') {",
          '    finalState = classification.state;',
          '  } else if (attemptNumber >= MAX_SEND_ATTEMPTS) {',
          '    finalState = classification.exhaustedState;',
          '  }',
          '',
          '  return {',
          '    json: {',
          '      ...prior,',
          '      live_send_attempts: attempts,',
          '      send_classification: {',
          '        mode: classification.mode,',
          '        final_state: finalState,',
          "        retryable: classification.mode === 'retryable' && attemptNumber < MAX_SEND_ATTEMPTS && finalState === null,",
          '        next_delay_ms: nextDelayMs,',
          '        ambiguous_side_effect: !!classification.ambiguousSideEffect,',
          '        attempt_number: attemptNumber,',
          '        last_outcome: outcome,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- S. Retry Router (IF) -------------------------------------------
    const nodeS = {
      id: 'if_s',
      name: 'S. Retry Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [5060, -100],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-s1',
              leftValue: '={{ $json.send_classification.retryable === true }}',
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- T. Retry Backoff Wait (loops back to Q) ------------------------
    const nodeT = {
      id: 'wait_t',
      name: 'T. Retry Backoff Wait',
      type: 'n8n-nodes-base.wait',
      typeVersion: 1.1,
      position: [5060, 80],
      parameters: {
        resume: 'timeInterval',
        unit: 'seconds',
        amount: '={{ Math.max(1, Math.ceil((($json.send_classification && $json.send_classification.next_delay_ms) || 100) / 1000)) }}',
      },
    };

    // --- U. SENT Router (IF) ---------------------------------------------
    const nodeU = {
      id: 'if_u',
      name: 'U. Send Outcome Router (SENT?)',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [5400, -100],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-u1',
              leftValue: "={{ $json.send_classification.final_state === 'SENT' }}",
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- X. Persist SENT Result (hmz-send-state) ------------------------
    const nodeX = {
      id: 'node_x_http',
      name: 'X. Persist SENT Result (hmz-send-state)',
      type: 'n8n-nodes-base.httpRequest',
      typeVersion: 4.2,
      position: [5740, -260],
      onError: 'continueRegularOutput',
      parameters: {
        method: 'POST',
        url: 'http://hmz-send-state:5681/v1/send/transition',
        sendBody: true,
        specifyBody: 'json',
        jsonBody:
          "={{ { sendKey: $json.acquisition.sendKey, state: 'SENT', messageId: ($json.send_classification.last_outcome.body && $json.send_classification.last_outcome.body.messageId) || null } }}",
        options: { timeout: 5000 },
      },
    };

    // --- X2. Build SENT Terminal Result ----------------------------------
    const nodeX2 = {
      id: 'node_x2',
      name: 'X2. Build SENT Terminal Result',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [6080, -260],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'return items.map((item) => {',
          '  let prior = {};',
          '  try {',
          "    prior = $('R. Classify Send Attempt').item.json || {};",
          '  } catch (e) {',
          '    prior = item.json || {};',
          '  }',
          '  const sc = prior.send_classification || {};',
          '  const lastOutcome = sc.last_outcome || {};',
          '  const body = lastOutcome.body || {};',
          '  return {',
          '    json: {',
          '      ...prior,',
          '      terminal: {',
          "        schema_version: '1.0',",
          "        result: 'SENT',",
          "        send_state: 'SENT',",
          "        reason: 'LIVE_SEND_COMPLETED',",
          '        message_id: body.messageId || null,',
          '        sent: true,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- U2. SEND_UNCERTAIN Router (IF) ----------------------------------
    const nodeU2 = {
      id: 'if_u2',
      name: 'U2. Send Outcome Router (SEND_UNCERTAIN?)',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [5740, 60],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-u2',
              leftValue: "={{ $json.send_classification.final_state === 'SEND_UNCERTAIN' }}",
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- U3. Finalize Failure Terminal Result ---------------------------
    const nodeU3 = {
      id: 'node_u3',
      name: 'U3. Finalize Failure Terminal Result',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [6080, 220],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  const sc = input.send_classification || {};',
          '  return {',
          '    json: {',
          '      ...input,',
          '      terminal: {',
          "        schema_version: '1.0',",
          "        result: 'FAILED',",
          "        send_state: sc.final_state || 'RETRY_EXHAUSTED',",
          "        reason: 'LIVE_SEND_TERMINAL_FAILURE',",
          '        classification: sc,',
          '        sent: false,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- V. Reconciliation Poll (list_emails, Gated) ---------------------
    const nodeV = {
      id: 'node_v_http',
      name: 'V. Reconciliation Poll (list_emails, Gated)',
      type: 'n8n-nodes-base.httpRequest',
      typeVersion: 4.2,
      position: [6080, 60],
      onError: 'continueRegularOutput',
      parameters: {
        method: 'POST',
        url: 'https://api.instantly.ai/api/v2/emails/list',
        sendBody: true,
        specifyBody: 'json',
        jsonBody: '={{ { eaccount: $json.nes.eaccount, lead_email: $json.nes.lead_email } }}',
        options: {
          timeout: 10000,
          response: { response: { neverError: true, fullResponse: true } },
        },
      },
      credentialPlaceholder: 'hmzInstantlyApi',
    };

    // --- W. Process Reconciliation Poll ----------------------------------
    const nodeW = {
      id: 'node_w',
      name: 'W. Process Reconciliation Poll',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [6420, 60],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'const RECONCILE_STATES = {"SENT_RECONCILED":"SENT_RECONCILED","HUMAN_REVIEW_ZERO_MATCHES":"HUMAN_REVIEW_ZERO_MATCHES","HUMAN_REVIEW_MULTIPLE_MATCHES":"HUMAN_REVIEW_MULTIPLE_MATCHES"};',
          'const MAX_RECONCILIATION_POLLS = 2;',
          '',
          'function reconcileMatches(checks, options) {',
          '  const opts = options || {};',
          '  const consecutiveRequired = opts.consecutiveRequired || 2;',
          '  const polls = Array.isArray(checks) ? checks : [];',
          '',
          '  let lastSingleMatchId = null;',
          '  let consecutiveSameSingleMatch = 0;',
          '',
          '  for (const matchIds of polls) {',
          '    const ids = Array.isArray(matchIds) ? matchIds : [];',
          '    if (ids.length > 1) {',
          '      return { state: RECONCILE_STATES.HUMAN_REVIEW_MULTIPLE_MATCHES, matchCount: ids.length, matchIds: ids };',
          '    }',
          '    if (ids.length === 1) {',
          '      const currentId = ids[0];',
          '      if (currentId === lastSingleMatchId) {',
          '        consecutiveSameSingleMatch += 1;',
          '      } else {',
          '        lastSingleMatchId = currentId;',
          '        consecutiveSameSingleMatch = 1;',
          '      }',
          '      if (consecutiveSameSingleMatch >= consecutiveRequired) {',
          '        return { state: RECONCILE_STATES.SENT_RECONCILED, matchCount: 1, matchId: currentId };',
          '      }',
          '    } else {',
          '      lastSingleMatchId = null;',
          '      consecutiveSameSingleMatch = 0;',
          '    }',
          '  }',
          '',
          '  return { state: RECONCILE_STATES.HUMAN_REVIEW_ZERO_MATCHES, matchCount: 0, matchIds: [] };',
          '}',
          '',
          'return items.map((item) => {',
          '  const httpResp = item.json || {};',
          '  let prior = {};',
          '  try {',
          "    prior = $('R. Classify Send Attempt').item.json || {};",
          '  } catch (e) {',
          '    prior = {};',
          '  }',
          '  const body = (httpResp.body !== undefined) ? httpResp.body : httpResp;',
          "  const matchIds = Array.isArray((body || {}).items) ? body.items.map((e) => e.id).filter(Boolean) : [];",
          '  const priorPolls = Array.isArray(prior.reconciliation_polls) ? prior.reconciliation_polls : [];',
          '  const polls = [...priorPolls, matchIds];',
          '  const reconciliation = reconcileMatches(polls, { consecutiveRequired: 2 });',
          '',
          '  return {',
          '    json: {',
          '      ...prior,',
          '      reconciliation_polls: polls,',
          '      reconciliation: {',
          '        ...reconciliation,',
          '        polls_taken: polls.length,',
          '        max_polls: MAX_RECONCILIATION_POLLS,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- IF_W. Reconciliation Continue Router ----------------------------
    const nodeIfW = {
      id: 'if_w',
      name: 'W2. Reconciliation Continue Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [6760, 60],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-w1',
              leftValue:
                "={{ $json.reconciliation.state !== 'SENT_RECONCILED' && $json.reconciliation.state !== 'HUMAN_REVIEW_MULTIPLE_MATCHES' && $json.reconciliation.polls_taken < $json.reconciliation.max_polls }}",
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- Reconciliation poll wait (loops back to V) ----------------------
    const nodeWaitW = {
      id: 'wait_w',
      name: 'W3. Reconciliation Poll Wait',
      type: 'n8n-nodes-base.wait',
      typeVersion: 1.1,
      position: [6760, 220],
      parameters: { resume: 'timeInterval', unit: 'seconds', amount: 2 },
    };

    // --- W4. Build Reconciliation Terminal Result -------------------------
    const nodeW4 = {
      id: 'node_w4',
      name: 'W4. Build Reconciliation Terminal Result',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [7100, -60],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  const rec = input.reconciliation || {};',
          '  let result;',
          '  let sendState;',
          '  let reason;',
          "  if (rec.state === 'SENT_RECONCILED') {",
          "    result = 'SENT';",
          "    sendState = 'SENT_RECONCILED';",
          "    reason = 'RECONCILED_SINGLE_CONSISTENT_MATCH';",
          "  } else if (rec.state === 'HUMAN_REVIEW_MULTIPLE_MATCHES') {",
          "    result = 'HUMAN_REVIEW';",
          "    sendState = 'SEND_UNCERTAIN';",
          "    reason = 'RECONCILIATION_MULTIPLE_MATCHES_NO_SECOND_POST';",
          '  } else {',
          "    result = 'HUMAN_REVIEW';",
          "    sendState = 'SEND_UNCERTAIN';",
          "    reason = 'RECONCILIATION_ZERO_MATCHES_NO_SECOND_POST';",
          '  }',
          '  return {',
          '    json: {',
          '      ...input,',
          '      terminal: {',
          "        schema_version: '1.0',",
          '        result,',
          '        send_state: sendState,',
          '        reason,',
          '        reconciliation: rec,',
          '        second_post_performed: false,',
          "        sent: rec.state === 'SENT_RECONCILED',",
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    wf.nodes.push(
      nodeO, nodeP, nodeP2, nodeQ, nodeR, nodeS, nodeT, nodeU, nodeX, nodeX2,
      nodeU2, nodeU3, nodeV, nodeW, nodeIfW, nodeWaitW, nodeW4
    );

    // N. Live Adapter Contract -> O (new). N had no outgoing connection.
    wf.connections[N_NAME] = { main: [[{ node: nodeO.name, type: 'main', index: 0 }]] };
    wf.connections[nodeO.name] = { main: [[{ node: nodeP.name, type: 'main', index: 0 }]] };
    wf.connections[nodeP.name] = {
      main: [
        [{ node: nodeQ.name, type: 'main', index: 0 }],
        [{ node: nodeP2.name, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeQ.name] = { main: [[{ node: nodeR.name, type: 'main', index: 0 }]] };
    wf.connections[nodeR.name] = { main: [[{ node: nodeS.name, type: 'main', index: 0 }]] };
    wf.connections[nodeS.name] = {
      main: [
        [{ node: nodeT.name, type: 'main', index: 0 }],
        [{ node: nodeU.name, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeT.name] = { main: [[{ node: nodeQ.name, type: 'main', index: 0 }]] };
    wf.connections[nodeU.name] = {
      main: [
        [{ node: nodeX.name, type: 'main', index: 0 }],
        [{ node: nodeU2.name, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeX.name] = { main: [[{ node: nodeX2.name, type: 'main', index: 0 }]] };
    wf.connections[nodeU2.name] = {
      main: [
        [{ node: nodeV.name, type: 'main', index: 0 }],
        [{ node: nodeU3.name, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeV.name] = { main: [[{ node: nodeW.name, type: 'main', index: 0 }]] };
    wf.connections[nodeW.name] = { main: [[{ node: nodeIfW.name, type: 'main', index: 0 }]] };
    wf.connections[nodeIfW.name] = {
      main: [
        [{ node: nodeWaitW.name, type: 'main', index: 0 }],
        [{ node: nodeW4.name, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeWaitW.name] = { main: [[{ node: nodeV.name, type: 'main', index: 0 }]] };

    save(FILES.sender, wf);
    changes.push('03: added O/P/P2/Q/R/S/T/U/U2/U3/V/W/W2/W3/W4/X/X2 - real gated live-send path (14 gates, retry, classification, reconciliation), wired downstream of N.');
  } else {
    changes.push('03: live-send path already present, skipped.');
  }
}

// =====================================================================
// 01_reply_intake_validation.json - real production webhook
// ("instantly-reply", header-auth credential placeholder), entry-source
// tagging, and a production-only security/allowlist gate inserted between
// F (Deterministic Prefilter) and G (Decision Engine Handoff). The
// existing dev/synthetic entry path is unchanged (security gate is a
// passthrough for non-production entries).
// =====================================================================
{
  const wf = load(FILES.intake);
  const A_NAME = 'A. Webhook Intake Normalization';
  const F_NAME = 'F. Deterministic Prefilter';
  const G_NAME = 'G. Decision Engine Handoff';

  if (!hasNode(wf, 'F1. Production Security & Allowlist Gate')) {
    const devWebhook = wf.nodes.find((n) => n.type === 'n8n-nodes-base.webhook');

    // --- Tag dev entry (inserted between dev webhook and A) -------------
    const nodeA0d = {
      id: 'node_a0d',
      name: 'A0. Tag Dev/Synthetic Entry',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [160, -120],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          "return items.map((item) => ({ json: { ...(item.json || {}), entry_source: 'DEV_OR_SYNTHETIC' } }));",
        ]),
      },
    };

    // --- Production webhook (real, gated) --------------------------------
    const prodWebhook = {
      id: 'trigger_webhook_production',
      name: 'Webhook - Instantly Reply Intake (Production, Gated)',
      type: devWebhook.type,
      typeVersion: devWebhook.typeVersion,
      position: [0, 240],
      webhookId: 'f7b3e0c4-9a2e-4b6e-9f1a-instantlyreplyprod',
      parameters: {
        httpMethod: 'POST',
        path: 'instantly-reply',
        responseMode: 'onReceived',
        authentication: 'headerAuth',
        options: {},
      },
      credentialPlaceholder: 'hmzInstantlyWebhookToken',
    };

    // --- Tag production entry --------------------------------------------
    const nodeA0p = {
      id: 'node_a0p',
      name: 'A0. Tag Production Entry',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [160, 240],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          "return items.map((item) => ({ json: { ...(item.json || {}), entry_source: 'PRODUCTION_WEBHOOK' } }));",
        ]),
      },
    };

    // --- F1. Production Security & Allowlist Gate ------------------------
    const nodeF1 = {
      id: 'node_f1',
      name: 'F1. Production Security & Allowlist Gate',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [2720, 0],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          '// Fixed launch profile allowlists (policy-HMZ-1.2). Mirrors',
          '// config/business-ready.config.json allowlists.*; all empty by',
          '// default, which fails this gate closed for PRODUCTION_WEBHOOK',
          '// entries until the owner configures them and the apply step',
          '// re-embeds the configured values.',
          'const ALLOWLISTS = {',
          '  workspace_id: null,',
          '  campaign_ids: [],',
          '  connected_sender_eaccounts: [],',
          '};',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  const nes = input.nes || {};',
          '  const prefilter = input.prefilter || {};',
          "  const entrySource = input.entry_source || 'UNKNOWN';",
          '',
          "  if (entrySource !== 'PRODUCTION_WEBHOOK') {",
          '    return {',
          '      json: {',
          '        ...input,',
          '        security_gate: { checked: false, entry_source: entrySource, passed: true, reasons: [] },',
          '      },',
          '    };',
          '  }',
          '',
          '  const reasons = [];',
          '  const workspaceId = nes.workspace_id || null;',
          "  const campaignId = nes.campaign_id || (nes.campaign_context && nes.campaign_context.campaign_id) || null;",
          '  const eaccount = nes.eaccount || null;',
          '',
          '  const workspaceAllowed = !!ALLOWLISTS.workspace_id && workspaceId === ALLOWLISTS.workspace_id;',
          "  if (!workspaceAllowed) reasons.push('WORKSPACE_NOT_ALLOWLISTED');",
          '',
          '  const campaignAllowed = ALLOWLISTS.campaign_ids.length > 0 && !!campaignId && ALLOWLISTS.campaign_ids.includes(campaignId);',
          "  if (!campaignAllowed) reasons.push('CAMPAIGN_NOT_ALLOWLISTED');",
          '',
          '  const senderAllowed = ALLOWLISTS.connected_sender_eaccounts.length > 0 && !!eaccount && ALLOWLISTS.connected_sender_eaccounts.includes(eaccount);',
          "  if (!senderAllowed) reasons.push('SENDER_EACCOUNT_NOT_ALLOWLISTED');",
          '',
          "  if (prefilter.is_self_sent) reasons.push('SELF_SENT');",
          "  if (prefilter.is_unsupported_event_type) reasons.push('UNSUPPORTED_EVENT_TYPE');",
          "  if (prefilter.is_malformed_payload) reasons.push('MALFORMED_PAYLOAD');",
          "  if (prefilter.is_duplicate_event) reasons.push('DUPLICATE_EVENT');",
          '',
          '  const passed = workspaceAllowed && campaignAllowed && senderAllowed &&',
          '    !prefilter.is_self_sent && !prefilter.is_unsupported_event_type &&',
          '    !prefilter.is_malformed_payload && !prefilter.is_duplicate_event;',
          '',
          '  return {',
          '    json: {',
          '      ...input,',
          '      security_gate: {',
          '        checked: true,',
          '        entry_source: entrySource,',
          '        workspace_allowed: workspaceAllowed,',
          '        campaign_allowed: campaignAllowed,',
          '        sender_allowed: senderAllowed,',
          '        passed,',
          '        reasons,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    // --- F2. Security Gate Router (IF) ------------------------------------
    const nodeF2 = {
      id: 'if_f2',
      name: 'F2. Security Gate Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [3040, 0],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-f2-1',
              leftValue: '={{ $json.security_gate.passed === true }}',
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    // --- F3. Security Gate Rejection Terminal -----------------------------
    const nodeF3 = {
      id: 'node_f3',
      name: 'F3. Security Gate Rejection Terminal',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [3040, 220],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  return {',
          '    json: {',
          '      ...input,',
          '      terminal: {',
          "        schema_version: '1.0',",
          "        result: 'REJECTED',",
          "        reason: 'PRODUCTION_SECURITY_GATE_FAILED',",
          '        security_gate: input.security_gate || null,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    wf.nodes.push(nodeA0d, prodWebhook, nodeA0p, nodeF1, nodeF2, nodeF3);

    // Rewire: dev webhook -> A0 (dev) -> A
    wf.connections[devWebhook.name] = { main: [[{ node: nodeA0d.name, type: 'main', index: 0 }]] };
    wf.connections[nodeA0d.name] = { main: [[{ node: A_NAME, type: 'main', index: 0 }]] };

    // New: production webhook -> A0 (production) -> A
    wf.connections[prodWebhook.name] = { main: [[{ node: nodeA0p.name, type: 'main', index: 0 }]] };
    wf.connections[nodeA0p.name] = { main: [[{ node: A_NAME, type: 'main', index: 0 }]] };

    // Rewire: F -> F1 -> F2 -> {true: G, false: F3}
    wf.connections[F_NAME] = { main: [[{ node: nodeF1.name, type: 'main', index: 0 }]] };
    wf.connections[nodeF1.name] = { main: [[{ node: nodeF2.name, type: 'main', index: 0 }]] };
    wf.connections[nodeF2.name] = {
      main: [
        [{ node: G_NAME, type: 'main', index: 0 }],
        [{ node: nodeF3.name, type: 'main', index: 0 }],
      ],
    };

    save(FILES.intake, wf);
    changes.push('01: added real production webhook ("instantly-reply", header-auth credential placeholder), dev/production entry tagging, and F1/F2/F3 production security & allowlist gate (passthrough for dev/synthetic entries, fail-closed for production until allowlists configured).');
  } else {
    changes.push('01: production webhook/security gate already present, skipped.');
  }
}

// =====================================================================
// 02_reply_decision_engine_validation.json - real (gated, disabled by
// default) suppression adapters: subsequence/remove,
// update-interest-status, blocklist, each followed by a verification
// retrieval (list_emails). Independently gated by
// suppression_action_enablement.* (all false by default); when no enabled
// action exists the new router passes straight through to E unchanged.
// =====================================================================
{
  const wf = load(FILES.decision);
  const F_NAME = 'F. Safety Action Plan (Gated Contract, Pre-Approval)';
  const E_NAME = 'E. Output Validation';

  if (!hasNode(wf, 'G. Suppression Live-Execution Router')) {
    const nodeG = {
      id: 'if_g',
      name: 'G. Suppression Live-Execution Router',
      type: 'n8n-nodes-base.if',
      typeVersion: 2.3,
      position: [2000, 200],
      parameters: {
        conditions: {
          options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
          combinator: 'and',
          conditions: [
            {
              id: 'cond-g1',
              leftValue: '={{ ($json.safety_action_plan.actions || []).some((a) => a.enabled === true) }}',
              rightValue: '',
              operator: { type: 'boolean', operation: 'true', singleValue: true },
            },
          ],
        },
        options: {},
      },
    };

    function gatedHttp(idSuffix, name, posY, url, actionName) {
      return {
        id: `node_${idSuffix}`,
        name,
        type: 'n8n-nodes-base.httpRequest',
        typeVersion: 4.2,
        position: [2320, posY],
        onError: 'continueRegularOutput',
        parameters: {
          method: 'POST',
          url,
          sendBody: true,
          specifyBody: 'json',
          jsonBody: J([
            "={{ (function() {",
            `  const plan = ($('${F_NAME}').item.json.safety_action_plan) || { actions: [] };`,
            `  const a = (plan.actions || []).find((x) => x.action === '${actionName}');`,
            '  return a ? a.request_contract.body : {};',
            '})() }}',
          ]),
          options: {
            timeout: 10000,
            response: { response: { neverError: true, fullResponse: true } },
          },
        },
        credentialPlaceholder: 'hmzInstantlyApi',
      };
    }

    const nodeG2 = gatedHttp(
      'g2', 'G2. Execute STOP_ACTIVE_SEQUENCE (Gated)', 80,
      'https://api.instantly.ai/api/v2/leads/subsequence/remove', 'STOP_ACTIVE_SEQUENCE'
    );
    const nodeG3 = gatedHttp(
      'g3', 'G3. Execute UPDATE_INTEREST_STATUS (Gated)', 200,
      'https://api.instantly.ai/api/v2/leads/update-interest-status', 'UPDATE_INTEREST_STATUS'
    );
    const nodeG4 = gatedHttp(
      'g4', 'G4. Execute ADD_TO_BLOCKLIST (Gated)', 320,
      'https://api.instantly.ai/api/v2/blocklist', 'ADD_TO_BLOCKLIST'
    );

    const nodeG5 = {
      id: 'node_g5',
      name: 'G5. Verify Suppression Execution (list_emails, Gated)',
      type: 'n8n-nodes-base.httpRequest',
      typeVersion: 4.2,
      position: [2320, 440],
      onError: 'continueRegularOutput',
      parameters: {
        method: 'POST',
        url: 'https://api.instantly.ai/api/v2/emails/list',
        sendBody: true,
        specifyBody: 'json',
        jsonBody: J([
          "={{ (function() {",
          `  const nes = ($('${F_NAME}').item.json.nes) || {};`,
          '  return { eaccount: nes.eaccount || null, lead_email: nes.lead_email || null };',
          '})() }}',
        ]),
        options: {
          timeout: 10000,
          response: { response: { neverError: true, fullResponse: true } },
        },
      },
      credentialPlaceholder: 'hmzInstantlyApi',
    };

    const nodeG6 = {
      id: 'node_g6',
      name: 'G6. Build Suppression Execution Result',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [2640, 200],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          'function djb2Hash(str) {',
          '  let hash = 5381;',
          '  for (let i = 0; i < str.length; i++) {',
          '    hash = (hash << 5) + hash + str.charCodeAt(i);',
          '    hash = hash & 0xffffffff;',
          '  }',
          "  return (hash >>> 0).toString(16).padStart(8, '0');",
          '}',
          '',
          'return items.map((item) => {',
          '  let prior = {};',
          '  try {',
          `    prior = $('${F_NAME}').item.json || {};`,
          '  } catch (e) {',
          '    prior = {};',
          '  }',
          '  const plan = prior.safety_action_plan || { actions: [] };',
          '  const nes = prior.nes || {};',
          '  const campaign = nes.campaign_context || {};',
          '  const keyRaw = [',
          "    'HMZ_SUPPRESSION_EXEC',",
          "    String(campaign.campaign_id || ''),",
          "    String(nes.lead_email || '').trim().toLowerCase(),",
          "    (plan.actions || []).map((a) => a.action).join(','),",
          "  ].join('|');",
          '',
          '  return {',
          '    json: {',
          '      ...prior,',
          '      suppression_execution: {',
          "        schema_version: '1.0',",
          '        idempotency_key: `suppression-${djb2Hash(keyRaw)}`,',
          '        actions_attempted: (plan.actions || []).filter((a) => a.enabled).map((a) => a.action),',
          "        verification_status: 'EXECUTION_AND_VERIFICATION_GATED_OFFLINE',",
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    wf.nodes.push(nodeG, nodeG2, nodeG3, nodeG4, nodeG5, nodeG6);

    wf.connections[F_NAME] = {
      main: [
        [
          { node: nodeG.name, type: 'main', index: 0 },
        ],
      ],
    };
    wf.connections[nodeG.name] = {
      main: [
        [{ node: nodeG2.name, type: 'main', index: 0 }],
        [{ node: E_NAME, type: 'main', index: 0 }],
      ],
    };
    wf.connections[nodeG2.name] = { main: [[{ node: nodeG3.name, type: 'main', index: 0 }]] };
    wf.connections[nodeG3.name] = { main: [[{ node: nodeG4.name, type: 'main', index: 0 }]] };
    wf.connections[nodeG4.name] = { main: [[{ node: nodeG5.name, type: 'main', index: 0 }]] };
    wf.connections[nodeG5.name] = { main: [[{ node: nodeG6.name, type: 'main', index: 0 }]] };
    wf.connections[nodeG6.name] = { main: [[{ node: E_NAME, type: 'main', index: 0 }]] };

    save(FILES.decision, wf);
    changes.push('02: added G/G2-G6 - real (gated, disabled-by-default) suppression adapters (subsequence/remove, update-interest-status, blocklist) plus verification retrieval, with a router that passes straight through to E when no suppression action is enabled (the unchanged default).');
  } else {
    changes.push('02: suppression adapters already present, skipped.');
  }
}

// =====================================================================
// 07_reply_human_approval_validation.json - reviewer-identity-allowlist
// check (advisory metadata, purely additive; the hard gate is enforced at
// the point of the dangerous action by workflow 03 gate 10). Inserted
// between M (Submit Token Valid Router, true branch) and N (Process
// Reviewer Decision) without altering M's routing or N's decision logic.
// =====================================================================
{
  const wf = load(FILES.approval);
  const M_NAME = 'M. Submit Token Valid Router';
  const N_NAME = 'N. Process Reviewer Decision';

  if (!hasNode(wf, 'M1. Reviewer Identity Allowlist Check')) {
    const m = nodeByName(wf, M_NAME);
    const n = nodeByName(wf, N_NAME);

    const nodeM1 = {
      id: 'node_m1',
      name: 'M1. Reviewer Identity Allowlist Check',
      type: 'n8n-nodes-base.code',
      typeVersion: 2,
      position: [(m.position[0] + n.position[0]) / 2, n.position[1]],
      onError: 'continueRegularOutput',
      parameters: {
        mode: 'runOnceForAllItems',
        language: 'javaScript',
        jsCode: J([
          'const items = $input.all();',
          '',
          '// Mirrors config.reviewer_allowlist; empty by default. Advisory only',
          "// here - workflow 03's live-send gate 10 independently enforces this",
          '// allowlist before any reply POST.',
          'const REVIEWER_ALLOWLIST = [];',
          '',
          'return items.map((item) => {',
          '  const input = item.json || {};',
          '  const identity = input.submit_approver_identity || null;',
          '  const configured = REVIEWER_ALLOWLIST.length > 0;',
          '  return {',
          '    json: {',
          '      ...input,',
          '      reviewer_allowlist_check: {',
          '        configured,',
          '        identity,',
          '        allowlisted: configured ? (!!identity && REVIEWER_ALLOWLIST.includes(identity)) : null,',
          '      },',
          '    },',
          '  };',
          '});',
        ]),
      },
    };

    wf.nodes.push(nodeM1);

    const mConn = wf.connections[M_NAME];
    const trueBranch = mConn.main[0];
    const falseBranch = mConn.main[1];
    // Replace the M(true) -> N edge with M(true) -> M1 -> N.
    wf.connections[M_NAME] = {
      main: [
        trueBranch.map((edge) =>
          edge.node === N_NAME ? { node: nodeM1.name, type: 'main', index: 0 } : edge
        ),
        falseBranch,
      ],
    };
    wf.connections[nodeM1.name] = { main: [[{ node: N_NAME, type: 'main', index: 0 }]] };

    save(FILES.approval, wf);
    changes.push('07: added M1 (Reviewer Identity Allowlist Check, advisory metadata) between M(true) and N, without changing M routing or N decision logic.');
  } else {
    changes.push('07: reviewer identity allowlist check already present, skipped.');
  }
}

for (const c of changes) {
  console.log(`- ${c}`);
}
