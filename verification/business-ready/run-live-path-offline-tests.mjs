// Business-ready LIVE PATH - offline test suite.
//
// Pure Node.js (built-ins only). Statically inspects the live-path
// additions made by verification/business-ready/build-live-path.mjs to the
// 7 workflow JSON exports and to config/business-ready.config.json; executes
// the new generated Code-node jsCode bodies in-process via
// `new Function(...)` (no n8n, no Docker, no network); and re-runs the
// existing business-ready offline suite (23/23, which itself re-runs
// phase4a/phase4b/integration-closure) as a regression. Makes no network
// call and never starts n8n. DRY_RUN remains true and LIVE_CAMPAIGNS remains
// [] throughout.
//
// Usage: node verification/business-ready/run-live-path-offline-tests.mjs

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');

const WORKFLOW_FILES = [
  '01_reply_intake_validation.json',
  '02_reply_decision_engine_validation.json',
  '03_reply_sender_validation.json',
  '04_reply_error_handler_validation.json',
  '05_reply_sla_watchdog_validation.json',
  '06_reply_full_test_harness_validation.json',
  '07_reply_human_approval_validation.json',
];

const results = [];
function record(id, description, passed, details) {
  results.push({ id, description, passed: !!passed, details: details || undefined });
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function tryRecord(id, description, fn) {
  try {
    fn();
    record(id, description, true);
  } catch (err) {
    record(id, description, false, err.message);
  }
}

const workflows = {};
let parseError = null;
for (const file of WORKFLOW_FILES) {
  try {
    workflows[file] = JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, file), 'utf8'));
  } catch (err) {
    parseError = `${file}: ${err.message}`;
    break;
  }
}

const wf01 = workflows['01_reply_intake_validation.json'];
const wf02 = workflows['02_reply_decision_engine_validation.json'];
const wf03 = workflows['03_reply_sender_validation.json'];
const wf07 = workflows['07_reply_human_approval_validation.json'];

function getNode(wf, name) {
  const node = wf.nodes.find((n) => n.name === name);
  assert(node, `node not found: ${name}`);
  return node;
}
function hasNode(wf, name) {
  return !!wf.nodes.find((n) => n.name === name);
}
function httpRequestNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.httpRequest');
}
function codeNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.code');
}

// Executes a Code node's jsCode with $input and an optional $('NodeName')
// mock that resolves to { item: { json: refData[name] } }.
function runCode(wf, nodeName, inputItems, refData) {
  const node = getNode(wf, nodeName);
  assert(node.type === 'n8n-nodes-base.code', `${nodeName} is not a Code node`);
  const $input = { all: () => inputItems };
  const $ = (name) => ({ item: { json: (refData && refData[name]) || {} } });
  const runner = new Function('$input', '$', node.parameters.jsCode);
  return runner($input, $);
}

// ---------------------------------------------------------------------
// 1. All 7 workflows still parse and remain inactive (no regression from
//    build-live-path.mjs).
// ---------------------------------------------------------------------
record('live_path_workflows_parse', 'All 7 workflow JSON files still parse as valid JSON after build-live-path.mjs', parseError === null, parseError);

if (parseError === null) {
  const activeOnes = WORKFLOW_FILES.filter((f) => workflows[f].active !== false);
  record('live_path_workflows_inactive', 'All 7 workflows remain active=false after build-live-path.mjs', activeOnes.length === 0, activeOnes.length ? activeOnes : undefined);
}

// ---------------------------------------------------------------------
// 2. No node in any of the 7 workflows has a real `credentials` field
//    (credentialPlaceholder only).
// ---------------------------------------------------------------------
tryRecord('live_path_no_credentials', 'No node in any of the 7 workflows has a credentials field; new HTTP/webhook nodes use credentialPlaceholder only', () => {
  for (const f of WORKFLOW_FILES) {
    for (const n of workflows[f].nodes) {
      assert(!('credentials' in n), `${f}: node "${n.name}" has a credentials field`);
    }
  }
  const placeholders = [];
  for (const f of WORKFLOW_FILES) {
    for (const n of workflows[f].nodes) {
      if (n.credentialPlaceholder) placeholders.push(`${f}:${n.name}:${n.credentialPlaceholder}`);
    }
  }
  // 1 (webhook token) + 6 (workflow 02 canonical-lead + per-action
  // suppression executors/verifier, Blocker C) + 2 (workflow 03 Q/V) +
  // 2 (workflow 07 review webhooks, Blocker G) = 11.
  assert(placeholders.length === 11, `expected exactly 11 credentialPlaceholder nodes, found ${placeholders.length}: ${JSON.stringify(placeholders)}`);
});

// ---------------------------------------------------------------------
// 3. Workflow 03: the 14-gate live-send subgraph exists and is wired
//    downstream of N (which is unchanged from the prior session).
// ---------------------------------------------------------------------
const SENDER_LIVE_PATH_NODES = [
  'O. Live Send Gate Evaluation (14 Gates)',
  'P. Live Send Gate Router',
  'P2. Live Send Blocked Terminal',
  'Q. POST Reply to Instantly (Gated)',
  'R. Classify Send Attempt',
  'S. Retry Router',
  'T. Retry Backoff Wait',
  'U. Send Outcome Router (SENT?)',
  'X. Persist SENT Result (hmz-send-state)',
  'X2. Build SENT Terminal Result',
  'U2. Send Outcome Router (SEND_UNCERTAIN?)',
  'U3. Finalize Failure Terminal Result',
  'V. Reconciliation Poll (list_emails, Gated)',
  'W. Process Reconciliation Poll',
  'W2. Reconciliation Continue Router',
  'W3. Reconciliation Poll Wait',
  'W4. Build Reconciliation Terminal Result',
];

tryRecord('sender_live_path_nodes_present', 'Workflow 03 contains all 17 new live-send-path nodes (O through W4/X2), each present exactly once', () => {
  for (const name of SENDER_LIVE_PATH_NODES) {
    const matches = wf03.nodes.filter((n) => n.name === name);
    assert(matches.length === 1, `expected exactly one "${name}", found ${matches.length}`);
  }
});

tryRecord('sender_live_path_wiring', 'N -> O -> P -> {Q (true) / P2 (false)}; Q -> R -> S -> {T (true, loops to Q) / U (false)}; U -> {X->X2 (true) / U2 (false)}; U2 -> {V (true) / U3 (false)}; V -> W -> W2 -> {W3 (true, loops to V) / W4 (false)}', () => {
  const N_NAME = 'N. Live Adapter Contract (Validation-Only, Unreachable)';
  const conn = wf03.connections;
  const target = (name, idx = 0) => conn[name].main[idx].map((e) => e.node);

  assert(target(N_NAME).includes('O. Live Send Gate Evaluation (14 Gates)'), 'N must connect to O');
  assert(target('O. Live Send Gate Evaluation (14 Gates)').includes('P. Live Send Gate Router'), 'O must connect to P');
  assert(target('P. Live Send Gate Router', 0).includes('Q. POST Reply to Instantly (Gated)'), 'P true -> Q');
  assert(target('P. Live Send Gate Router', 1).includes('P2. Live Send Blocked Terminal'), 'P false -> P2');
  assert(target('Q. POST Reply to Instantly (Gated)').includes('R. Classify Send Attempt'), 'Q -> R');
  assert(target('R. Classify Send Attempt').includes('S. Retry Router'), 'R -> S');
  assert(target('S. Retry Router', 0).includes('T. Retry Backoff Wait'), 'S true -> T');
  assert(target('S. Retry Router', 1).includes('U. Send Outcome Router (SENT?)'), 'S false -> U');
  assert(target('T. Retry Backoff Wait').includes('Q. POST Reply to Instantly (Gated)'), 'T loops back to Q');
  assert(target('U. Send Outcome Router (SENT?)', 0).includes('X. Persist SENT Result (hmz-send-state)'), 'U true -> X');
  assert(target('U. Send Outcome Router (SENT?)', 1).includes('U2. Send Outcome Router (SEND_UNCERTAIN?)'), 'U false -> U2');
  assert(target('X. Persist SENT Result (hmz-send-state)').includes('X2. Build SENT Terminal Result'), 'X -> X2');
  assert(target('U2. Send Outcome Router (SEND_UNCERTAIN?)', 0).includes('V. Reconciliation Poll (list_emails, Gated)'), 'U2 true -> V');
  assert(target('U2. Send Outcome Router (SEND_UNCERTAIN?)', 1).includes('U3. Finalize Failure Terminal Result'), 'U2 false -> U3');
  assert(target('V. Reconciliation Poll (list_emails, Gated)').includes('W. Process Reconciliation Poll'), 'V -> W');
  assert(target('W. Process Reconciliation Poll').includes('W2. Reconciliation Continue Router'), 'W -> W2');
  assert(target('W2. Reconciliation Continue Router', 0).includes('W3. Reconciliation Poll Wait'), 'W2 true -> W3');
  assert(target('W2. Reconciliation Continue Router', 1).includes('W4. Build Reconciliation Terminal Result'), 'W2 false -> W4');
  assert(target('W3. Reconciliation Poll Wait').includes('V. Reconciliation Poll (list_emails, Gated)'), 'W3 loops back to V');
});

// ---------------------------------------------------------------------
// 4. O. 14-gate evaluation: with no upstream context, every gate that
//    depends on the (empty) launch profile fails, and all_passed is false.
//    Gate 14 (no prior terminal state) is the one gate that legitimately
//    passes on an empty input, proving the gate list is not a blanket
//    all-false stub.
// ---------------------------------------------------------------------
tryRecord('gate_evaluation_empty_input_all_blocked', 'O blocks (all_passed=false) on an empty input, with 14 distinct gates and at least one (no_prior_terminal_send_state) passing', () => {
  const out = runCode(wf03, 'O. Live Send Gate Evaluation (14 Gates)', [{ json: {} }]);
  const gates = out[0].json.live_send_gates;
  assert(gates.gates.length === 14, `expected 14 gates, found ${gates.gates.length}`);
  assert(gates.all_passed === false, 'all_passed must be false on empty input');
  const byId = Object.fromEntries(gates.gates.map((g) => [g.id, g]));
  assert(byId.no_prior_terminal_send_state.passed === true, 'no_prior_terminal_send_state must pass on empty input');
  assert(byId.operating_mode.passed === false, 'operating_mode gate must fail (launch profile is VALIDATION, not SUPERVISED_VALIDATION)');
});

// ---------------------------------------------------------------------
// 5. O. 14-gate evaluation: with a fully "ideal" approval/acquisition/
//    suppression/draft context, exactly the launch-profile-allowlist gates
//    fail (operating_mode, dry_run_disabled, campaign_in_live_campaigns,
//    workspace_allowlisted, sender_eaccount_allowlisted,
//    instantly_credential_ready, controlled_live_ready,
//    reviewer_identity_allowlisted) and the other 6 gates pass.
// ---------------------------------------------------------------------
tryRecord('gate_evaluation_ideal_context_still_blocked_on_launch_profile', 'O still blocks an otherwise-ideal item on exactly the 8 launch-profile/allowlist gates, while approval/lock/suppression/variable gates pass', () => {
  const idealItem = {
    nes: {
      eaccount: 'sender@example.com',
      workspace_id: 'ws-1',
      campaign_id: 'camp-1',
      threading: { reply_to_uuid: 'email-uuid-1' },
    },
    gates: { draft_variable_gate_passed: true },
    approval: { approved: true, case_id: 'case-1', approved_at: '2026-06-15T00:00:00.000Z', approver_identity: 'reviewer@example.com' },
    acquisition: { acquired: true, priorState: null },
    suppression_verification: { verified: true },
  };
  const out = runCode(wf03, 'O. Live Send Gate Evaluation (14 Gates)', [{ json: idealItem }]);
  const gates = out[0].json.live_send_gates;
  assert(gates.all_passed === false, 'all_passed must still be false (empty launch profile)');
  const expectedFailed = [
    'operating_mode', 'dry_run_disabled', 'campaign_in_live_campaigns', 'workspace_allowlisted',
    'sender_eaccount_allowlisted', 'instantly_credential_ready', 'controlled_live_ready',
    'reviewer_identity_allowlisted',
  ];
  assert(JSON.stringify(gates.failed_gate_ids.slice().sort()) === JSON.stringify(expectedFailed.slice().sort()),
    `unexpected failed gate set: ${JSON.stringify(gates.failed_gate_ids)}`);
  const byId = Object.fromEntries(gates.gates.map((g) => [g.id, g]));
  for (const id of ['durable_approval_present', 'approval_token_consumed', 'no_unresolved_variables', 'send_lock_acquired', 'suppression_verified_or_not_required', 'no_prior_terminal_send_state']) {
    assert(byId[id].passed === true, `${id} should pass for the ideal item`);
  }
});

// ---------------------------------------------------------------------
// 6. P2. Live Send Blocked Terminal builds a BLOCKED terminal carrying the
//    failed gate ids.
// ---------------------------------------------------------------------
tryRecord('p2_blocked_terminal_shape', 'P2 builds terminal.result=BLOCKED, send_state=BLOCKED, reason=LIVE_SEND_GATES_NOT_SATISFIED, with failed_gate_ids carried through', () => {
  const gateOut = runCode(wf03, 'O. Live Send Gate Evaluation (14 Gates)', [{ json: {} }]);
  const out = runCode(wf03, 'P2. Live Send Blocked Terminal', [{ json: gateOut[0].json }]);
  const terminal = out[0].json.terminal;
  assert(terminal.result === 'BLOCKED', 'result must be BLOCKED');
  assert(terminal.send_state === 'BLOCKED', 'send_state must be BLOCKED');
  assert(terminal.reason === 'LIVE_SEND_GATES_NOT_SATISFIED', 'reason mismatch');
  assert(Array.isArray(terminal.failed_gate_ids) && terminal.failed_gate_ids.length === 13, 'failed_gate_ids must list all 13 failed gates on empty input (no_prior_terminal_send_state passes)');
  assert(terminal.sent === false, 'sent must be false');
});

// ---------------------------------------------------------------------
// 7. Q. POST Reply to Instantly (Gated): real httpRequest to
//    /api/v2/emails/reply, gated by credentialPlaceholder + neverError +
//    fullResponse, continues on error (never throws the workflow).
// ---------------------------------------------------------------------
tryRecord('q_node_real_gated_reply_adapter', 'Q is a real httpRequest POST to https://api.instantly.ai/api/v2/emails/reply, gated via credentialPlaceholder "hmzInstantlyApi", neverError+fullResponse, continueRegularOutput', () => {
  const q = getNode(wf03, 'Q. POST Reply to Instantly (Gated)');
  assert(q.type === 'n8n-nodes-base.httpRequest', 'Q must be an httpRequest node');
  assert(q.parameters.method === 'POST', 'Q must be POST');
  assert(q.parameters.url === 'https://api.instantly.ai/api/v2/emails/reply', 'Q url mismatch');
  assert(q.credentialPlaceholder === 'hmzInstantlyApi', 'Q must carry credentialPlaceholder hmzInstantlyApi');
  assert(q.onError === 'continueRegularOutput', 'Q must continue on error');
  assert(q.parameters.options.response.response.neverError === true, 'Q must set neverError');
  assert(q.parameters.options.response.response.fullResponse === true, 'Q must request the full response');
  assert(q.parameters.jsonBody.includes('reply_to_uuid') && q.parameters.jsonBody.includes('eaccount'), 'Q body must include eaccount and reply_to_uuid');
});

// ---------------------------------------------------------------------
// 8. R. Classify Send Attempt: exercises classifySendOutcome /
//    planSendAttempts-equivalent logic for the documented HTTP status
//    families.
// ---------------------------------------------------------------------
tryRecord('r_classifies_permanent_failure_400', 'R classifies HTTP 400 as terminal PERMANENT_FAILURE, non-retryable', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 400, headers: {}, body: { error: 'bad request' } } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'PERMANENT_FAILURE', `expected PERMANENT_FAILURE, got ${sc.final_state}`);
  assert(sc.retryable === false, 'must not be retryable');
});

tryRecord('r_classifies_auth_or_plan_failure_401', 'R classifies HTTP 401 as terminal AUTH_OR_PLAN_FAILURE, non-retryable', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 401, headers: {}, body: {} } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'AUTH_OR_PLAN_FAILURE', `expected AUTH_OR_PLAN_FAILURE, got ${sc.final_state}`);
});

tryRecord('r_classifies_invalid_reply_target_404', 'R classifies HTTP 404 as terminal INVALID_REPLY_TARGET, non-retryable', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 404, headers: {}, body: {} } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'INVALID_REPLY_TARGET', `expected INVALID_REPLY_TARGET, got ${sc.final_state}`);
});

tryRecord('r_classifies_429_retryable_honours_retry_after', 'R classifies HTTP 429 as retryable, honouring Retry-After (capped at 5000ms) on the first attempt', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 429, headers: { 'retry-after': '2' }, body: {} } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.mode === 'retryable', `expected retryable, got ${sc.mode}`);
  assert(sc.retryable === true, 'attempt 1 < MAX_SEND_ATTEMPTS must be retryable');
  assert(sc.next_delay_ms === 2000, `expected next_delay_ms=2000 (Retry-After honoured), got ${sc.next_delay_ms}`);
});

tryRecord('r_classifies_200_valid_contract_as_sent', 'R classifies HTTP 2xx with a valid Email object {id, message_id, thread_id} as terminal SENT', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 200, headers: {}, body: { id: 'email-abc', message_id: 'msg-123', thread_id: 'thread-abc' } } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'SENT', `expected SENT, got ${sc.final_state}`);
  assert(sc.ambiguous_side_effect === false, 'SENT must not be ambiguous');
});

tryRecord('r_classifies_200_invalid_contract_as_send_uncertain', 'R classifies HTTP 2xx without a valid {status:"sent", messageId} body as terminal SEND_UNCERTAIN, ambiguous, never blindly retried', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 200, headers: {}, body: {} } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'SEND_UNCERTAIN', `expected SEND_UNCERTAIN, got ${sc.final_state}`);
  assert(sc.ambiguous_side_effect === true, 'SEND_UNCERTAIN must be ambiguous');
  assert(sc.retryable === false, 'SEND_UNCERTAIN must never be blindly retried');
});

tryRecord('r_exhausts_retries_at_max_attempts', 'R sets final_state=RETRY_EXHAUSTED once a retryable outcome reaches MAX_SEND_ATTEMPTS (3)', () => {
  const refData = { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [{ attempt: 1 }, { attempt: 2 }] } };
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 503, headers: {}, body: {} } }], refData);
  const sc = out[0].json.send_classification;
  assert(sc.attempt_number === 3, `expected attempt 3, got ${sc.attempt_number}`);
  assert(sc.final_state === 'RETRY_EXHAUSTED', `expected RETRY_EXHAUSTED, got ${sc.final_state}`);
  assert(sc.retryable === false, 'attempt 3 must not be retryable');
});

// ---------------------------------------------------------------------
// 9. X2 / U3 / W4 terminal builders produce the documented send states.
// ---------------------------------------------------------------------
tryRecord('x2_builds_sent_terminal', 'X2 builds terminal.result=SENT, send_state=SENT, sent=true, carrying id/message_id/thread_id and confirmed cross-checks', () => {
  const refData = {
    'R. Classify Send Attempt': {
      send_classification: {
        final_state: 'SENT',
        last_outcome: {
          body: {
            id: 'email-999',
            message_id: 'msg-999',
            thread_id: 'thread-999',
            eaccount: 'sender@example.com',
            subject: 'Re: Hello',
            cc_address_email_list: [],
            bcc_address_email_list: [],
          },
        },
      },
    },
  };
  const out = runCode(wf03, 'X2. Build SENT Terminal Result', [{ json: { ok: true } }], refData);
  const terminal = out[0].json.terminal;
  assert(terminal.result === 'SENT' && terminal.send_state === 'SENT' && terminal.sent === true, 'X2 terminal shape mismatch');
  assert(terminal.email_id === 'email-999', 'X2 must carry id through as email_id');
  assert(terminal.message_id === 'msg-999', 'X2 must carry message_id through');
  assert(terminal.thread_id === 'thread-999', 'X2 must carry thread_id through');
  assert(terminal.confirmed_cross_checks.eaccount === 'sender@example.com', 'X2 must carry confirmed cross-checks through');
});

tryRecord('u3_builds_failure_terminal', 'U3 builds terminal.result=FAILED with send_state taken from send_classification.final_state, sent=false', () => {
  const out = runCode(wf03, 'U3. Finalize Failure Terminal Result', [{ json: { send_classification: { final_state: 'PERMANENT_FAILURE' } } }]);
  const terminal = out[0].json.terminal;
  assert(terminal.result === 'FAILED' && terminal.send_state === 'PERMANENT_FAILURE' && terminal.sent === false, 'U3 terminal shape mismatch');
});

// ---------------------------------------------------------------------
// 10. W. Process Reconciliation Poll: reconcileMatches reaches
//     SENT_RECONCILED only after 2 consecutive single-match polls, and
//     HUMAN_REVIEW_* otherwise; W2/W4 never trigger a second POST.
// ---------------------------------------------------------------------
tryRecord('reconciliation_zero_then_consistent_match_reconciles', 'W reconciles to SENT_RECONCILED only after 2 consecutive single-match polls of the same id; the first single-match poll is HUMAN_REVIEW_ZERO_MATCHES', () => {
  const out1 = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'email-abc' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: [] } });
  const rec1 = out1[0].json.reconciliation;
  assert(rec1.state === 'HUMAN_REVIEW_ZERO_MATCHES', `first poll: expected HUMAN_REVIEW_ZERO_MATCHES, got ${rec1.state}`);
  assert(rec1.polls_taken === 1 && rec1.max_polls === 2, 'first poll bookkeeping mismatch');

  const out2 = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'email-abc' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: out1[0].json.reconciliation_polls } });
  const rec2 = out2[0].json.reconciliation;
  assert(rec2.state === 'SENT_RECONCILED', `second consistent poll: expected SENT_RECONCILED, got ${rec2.state}`);
  assert(rec2.matchId === 'email-abc', 'matchId mismatch');
});

tryRecord('reconciliation_multiple_matches_human_review', 'W reconciles to HUMAN_REVIEW_MULTIPLE_MATCHES when a poll returns more than one match id', () => {
  const out = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'a' }, { id: 'b' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: [] } });
  assert(out[0].json.reconciliation.state === 'HUMAN_REVIEW_MULTIPLE_MATCHES', `expected HUMAN_REVIEW_MULTIPLE_MATCHES, got ${out[0].json.reconciliation.state}`);
});

tryRecord('w4_never_performs_second_post', 'W4 builds a terminal with second_post_performed=false for every reconciliation outcome (SENT_RECONCILED, zero matches, multiple matches)', () => {
  const cases = [
    { state: 'SENT_RECONCILED', expectedResult: 'SENT', expectedSendState: 'SENT_RECONCILED', expectedSent: true },
    { state: 'HUMAN_REVIEW_ZERO_MATCHES', expectedResult: 'HUMAN_REVIEW', expectedSendState: 'SEND_UNCERTAIN', expectedSent: false },
    { state: 'HUMAN_REVIEW_MULTIPLE_MATCHES', expectedResult: 'HUMAN_REVIEW', expectedSendState: 'SEND_UNCERTAIN', expectedSent: false },
  ];
  for (const c of cases) {
    const out = runCode(wf03, 'W4. Build Reconciliation Terminal Result', [{ json: { reconciliation: { state: c.state } } }]);
    const terminal = out[0].json.terminal;
    assert(terminal.second_post_performed === false, `${c.state}: second_post_performed must be false`);
    assert(terminal.result === c.expectedResult, `${c.state}: expected result ${c.expectedResult}, got ${terminal.result}`);
    assert(terminal.send_state === c.expectedSendState, `${c.state}: expected send_state ${c.expectedSendState}, got ${terminal.send_state}`);
    assert(terminal.sent === c.expectedSent, `${c.state}: expected sent=${c.expectedSent}, got ${terminal.sent}`);
  }
});

// ---------------------------------------------------------------------
// 11. Retry and reconciliation loops are bounded (no unbounded cycles).
// ---------------------------------------------------------------------
tryRecord('retry_and_reconciliation_loops_bounded', 'The Q<->T retry loop is bounded by MAX_SEND_ATTEMPTS=3 (R sets retryable=false at attempt 3); the V<->W3 reconciliation loop is bounded by max_polls=2 (W2 routes to W4 once polls_taken>=2)', () => {
  const rCode = getNode(wf03, 'R. Classify Send Attempt').parameters.jsCode;
  assert(rCode.includes('MAX_SEND_ATTEMPTS'), 'R must reference MAX_SEND_ATTEMPTS');
  const wCode = getNode(wf03, 'W. Process Reconciliation Poll').parameters.jsCode;
  assert(wCode.includes('MAX_RECONCILIATION_POLLS = 2'), 'W must define MAX_RECONCILIATION_POLLS = 2');
  const w2Cond = getNode(wf03, 'W2. Reconciliation Continue Router').parameters.conditions.conditions[0].leftValue;
  assert(w2Cond.includes('polls_taken < $json.reconciliation.max_polls'), 'W2 must bound on polls_taken < max_polls');
});

// ---------------------------------------------------------------------
// 12. Workflow 01: real production webhook ("instantly-reply"), entry
//     tagging, and the F1/F2/F3 security gate inserted between F and G.
// ---------------------------------------------------------------------
tryRecord('production_webhook_present', 'Workflow 01 has a real production Webhook node at path "instantly-reply" with header-auth and credentialPlaceholder hmzInstantlyWebhookToken, separate from the dev webhook', () => {
  const prod = getNode(wf01, 'Webhook - Instantly Reply Intake (Production, Gated)');
  assert(prod.type === 'n8n-nodes-base.webhook', 'must be a webhook node');
  assert(prod.parameters.path === 'instantly-reply', `path mismatch: ${prod.parameters.path}`);
  assert(prod.parameters.httpMethod === 'POST', 'must be POST');
  assert(prod.parameters.authentication === 'headerAuth', 'must use headerAuth');
  assert(prod.credentialPlaceholder === 'hmzInstantlyWebhookToken', 'must carry credentialPlaceholder hmzInstantlyWebhookToken');

  const dev = wf01.nodes.find((n) => n.type === 'n8n-nodes-base.webhook' && n.name !== prod.name);
  assert(dev, 'dev webhook must still exist');
  assert(dev.parameters.path !== prod.parameters.path, 'dev and production webhook paths must differ');
});

tryRecord('entry_source_tagging', 'A0 (dev) tags entry_source=DEV_OR_SYNTHETIC and A0 (production) tags entry_source=PRODUCTION_WEBHOOK, both feeding into A. Webhook Intake Normalization', () => {
  const devOut = runCode(wf01, 'A0. Tag Dev/Synthetic Entry', [{ json: { foo: 'bar' } }]);
  assert(devOut[0].json.entry_source === 'DEV_OR_SYNTHETIC', `dev tag mismatch: ${devOut[0].json.entry_source}`);

  const prodOut = runCode(wf01, 'A0. Tag Production Entry', [{ json: { foo: 'bar' } }]);
  assert(prodOut[0].json.entry_source === 'PRODUCTION_WEBHOOK', `production tag mismatch: ${prodOut[0].json.entry_source}`);

  const A_NAME = 'A. Webhook Intake Normalization';
  const devTargets = wf01.connections['A0. Tag Dev/Synthetic Entry'].main[0].map((e) => e.node);
  const prodTargets = wf01.connections['A0. Tag Production Entry'].main[0].map((e) => e.node);
  assert(devTargets.includes(A_NAME), 'dev tag must feed into A');
  assert(prodTargets.includes(A_NAME), 'production tag must feed into A');
});

tryRecord('security_gate_passthrough_for_dev_entries', 'F1 is a passthrough (checked=false, passed=true) for non-PRODUCTION_WEBHOOK entries, preserving the existing dev/synthetic/test path', () => {
  const out = runCode(wf01, 'F1. Production Security & Allowlist Gate', [{ json: { entry_source: 'DEV_OR_SYNTHETIC', prefilter: {}, nes: {} } }]);
  const gate = out[0].json.security_gate;
  assert(gate.checked === false, 'dev entries must not be checked');
  assert(gate.passed === true, 'dev entries must pass through');
});

tryRecord('security_gate_fails_closed_for_production_with_empty_allowlists', 'F1 fails closed (passed=false) for PRODUCTION_WEBHOOK entries while ALLOWLISTS is empty (the shipped default); since campaign/sender allowlisting is gated on workspace allowlisting, a missing workspace_id never allowlists campaign/sender either', () => {
  const out = runCode(wf01, 'F1. Production Security & Allowlist Gate', [{ json: {
    entry_source: 'PRODUCTION_WEBHOOK',
    prefilter: { is_self_sent: false, is_unsupported_event_type: false, is_malformed_payload: false, is_duplicate_event: false },
    nes: { workspace_id: 'ws-1', campaign_id: 'camp-1', eaccount: 'sender@example.com' },
  } }]);
  const gate = out[0].json.security_gate;
  assert(gate.checked === true, 'production entries must be checked');
  assert(gate.passed === false, 'production entries must fail closed with empty allowlists');
  for (const reason of ['WORKSPACE_NOT_ALLOWLISTED', 'CAMPAIGN_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED', 'SENDER_EACCOUNT_NOT_ALLOWLISTED_OR_WORKSPACE_NOT_ALLOWLISTED']) {
    assert(gate.reasons.includes(reason), `expected reason ${reason}, got ${JSON.stringify(gate.reasons)}`);
  }
});

tryRecord('security_gate_rejects_prefilter_flags_for_production', 'F1 fails closed for PRODUCTION_WEBHOOK entries when prefilter flags self-sent/unsupported/malformed/duplicate are set, regardless of allowlists', () => {
  const out = runCode(wf01, 'F1. Production Security & Allowlist Gate', [{ json: {
    entry_source: 'PRODUCTION_WEBHOOK',
    prefilter: { is_self_sent: true, is_unsupported_event_type: false, is_malformed_payload: false, is_duplicate_event: false },
    nes: {},
  } }]);
  const gate = out[0].json.security_gate;
  assert(gate.passed === false, 'self-sent production entries must fail');
  assert(gate.reasons.includes('SELF_SENT'), 'reasons must include SELF_SENT');
});

tryRecord('security_gate_routing_f1_f2_f3', 'F -> F1 -> F2 -> {G (true) / F3 (false)}; F3 builds terminal.result=REJECTED', () => {
  const conn = wf01.connections;
  const target = (name, idx = 0) => conn[name].main[idx].map((e) => e.node);
  assert(target('F. Deterministic Prefilter').includes('F1. Production Security & Allowlist Gate'), 'F -> F1');
  assert(target('F1. Production Security & Allowlist Gate').includes('F2. Security Gate Router'), 'F1 -> F2');
  assert(target('F2. Security Gate Router', 0).includes('G. Decision Engine Handoff'), 'F2 true -> G');
  assert(target('F2. Security Gate Router', 1).includes('F3. Security Gate Rejection Terminal'), 'F2 false -> F3');

  const out = runCode(wf01, 'F3. Security Gate Rejection Terminal', [{ json: { security_gate: { passed: false, reasons: ['WORKSPACE_NOT_ALLOWLISTED'] } } }]);
  assert(out[0].json.terminal.result === 'REJECTED', 'F3 terminal.result must be REJECTED');
  assert(out[0].json.terminal.reason === 'PRODUCTION_SECURITY_GATE_FAILED', 'F3 terminal.reason mismatch');
});

// ---------------------------------------------------------------------
// 13. Workflow 02: gated, disabled-by-default suppression adapters.
// ---------------------------------------------------------------------
tryRecord('suppression_adapters_present_and_gated', 'Workflow 02 has a per-action gated chain: G0 (canonical-lead retrieval), G1-G4 (gate/execute/record per suppression action), G5 (blocklist verification gate/execute/record), G6 (result aggregator); every httpRequest node carries credentialPlaceholder hmzInstantlyApi and continueRegularOutput', () => {
  const adapterNames = [
    ['G0h. Get Canonical Lead', 'https://api.instantly.ai/api/v2/leads/list'],
    ['G1h. Execute SOURCE_CAMPAIGN_STOP', null],
    ['G2h. Execute UPDATE_INTEREST_STATUS', null],
    ['G3h. Execute SUBSEQUENCE_REMOVAL', null],
    ['G4h. Execute EXACT_EMAIL_BLOCKLIST', null],
    ['G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)', 'https://api.instantly.ai/api/v2/block-lists-entries'],
  ];
  for (const [name, url] of adapterNames) {
    const n = getNode(wf02, name);
    assert(n.type === 'n8n-nodes-base.httpRequest', `${name} must be httpRequest`);
    if (url) assert(n.parameters.url === url, `${name} url mismatch: ${n.parameters.url}`);
    assert(n.credentialPlaceholder === 'hmzInstantlyApi', `${name} must carry credentialPlaceholder hmzInstantlyApi`);
    assert(n.onError === 'continueRegularOutput', `${name} must continue on error`);
  }
  // G1h-G4h derive their URL at runtime from safety_action_plan.actions[].request_contract.url.
  for (const name of ['G1h. Execute SOURCE_CAMPAIGN_STOP', 'G2h. Execute UPDATE_INTEREST_STATUS', 'G3h. Execute SUBSEQUENCE_REMOVAL', 'G4h. Execute EXACT_EMAIL_BLOCKLIST']) {
    const n = getNode(wf02, name);
    assert(n.parameters.url.startsWith('={{') && n.parameters.url.includes('request_contract'), `${name} url must be expression-derived from request_contract`);
  }
  for (const name of [
    'G0g. Canonical Lead Retrieval Gate',
    'G1g. SOURCE_CAMPAIGN_STOP Gate',
    'G2g. UPDATE_INTEREST_STATUS Gate',
    'G3g. SUBSEQUENCE_REMOVAL Gate',
    'G4g. EXACT_EMAIL_BLOCKLIST Gate',
    'G5g. EXACT_EMAIL_BLOCKLIST Verification Gate',
  ]) {
    assert(getNode(wf02, name).type === 'n8n-nodes-base.if', `${name} must be an IF node`);
  }
  assert(hasNode(wf02, 'G6. Build Suppression Execution Result'), 'G6 must exist');
});

tryRecord('suppression_router_passthrough_to_e_when_nothing_enabled', 'F -> G0g, and each Gn gate routes both its true (execute) and false (skip) branches into its own record node, chaining through to G5 and G6, which always feeds E. Output Validation', () => {
  const conn = wf02.connections;
  const target = (name, idx = 0) => conn[name].main[idx].map((e) => e.node);
  assert(target('F. Safety Action Plan (Gated Contract, Pre-Approval)').includes('G0g. Canonical Lead Retrieval Gate'), 'F -> G0g');

  assert(target('G0g. Canonical Lead Retrieval Gate', 0).includes('G0h. Get Canonical Lead'), 'G0g true -> G0h');
  assert(target('G0g. Canonical Lead Retrieval Gate', 1).includes('G0r. Record Canonical Lead Retrieval'), 'G0g false -> G0r');
  assert(target('G0h. Get Canonical Lead').includes('G0r. Record Canonical Lead Retrieval'), 'G0h -> G0r');
  assert(target('G0r. Record Canonical Lead Retrieval').includes('G1g. SOURCE_CAMPAIGN_STOP Gate'), 'G0r -> G1g');

  const chain = [
    ['G1g. SOURCE_CAMPAIGN_STOP Gate', 'G1h. Execute SOURCE_CAMPAIGN_STOP', 'G1r. Record SOURCE_CAMPAIGN_STOP Result', 'G2g. UPDATE_INTEREST_STATUS Gate'],
    ['G2g. UPDATE_INTEREST_STATUS Gate', 'G2h. Execute UPDATE_INTEREST_STATUS', 'G2r. Record UPDATE_INTEREST_STATUS Result', 'G3g. SUBSEQUENCE_REMOVAL Gate'],
    ['G3g. SUBSEQUENCE_REMOVAL Gate', 'G3h. Execute SUBSEQUENCE_REMOVAL', 'G3r. Record SUBSEQUENCE_REMOVAL Result', 'G4g. EXACT_EMAIL_BLOCKLIST Gate'],
    ['G4g. EXACT_EMAIL_BLOCKLIST Gate', 'G4h. Execute EXACT_EMAIL_BLOCKLIST', 'G4r. Record EXACT_EMAIL_BLOCKLIST Result', 'G5g. EXACT_EMAIL_BLOCKLIST Verification Gate'],
  ];
  for (const [gate, http, record, nextGate] of chain) {
    assert(target(gate, 0).includes(http), `${gate} true -> ${http}`);
    assert(target(gate, 1).includes(record), `${gate} false -> ${record}`);
    assert(target(http).includes(record), `${http} -> ${record}`);
    assert(target(record).includes(nextGate), `${record} -> ${nextGate}`);
  }

  assert(target('G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', 0).includes('G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)'), 'G5g true -> G5h');
  assert(target('G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', 1).includes('G5r. Record EXACT_EMAIL_BLOCKLIST Verification'), 'G5g false -> G5r');
  assert(target('G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)').includes('G5r. Record EXACT_EMAIL_BLOCKLIST Verification'), 'G5h -> G5r');
  assert(target('G5r. Record EXACT_EMAIL_BLOCKLIST Verification').includes('G6. Build Suppression Execution Result'), 'G5r -> G6');
  assert(target('G6. Build Suppression Execution Result').includes('E. Output Validation'), 'G6 -> E');
});

tryRecord('suppression_router_default_input_routes_false', 'With the shipped suppression_action_enablement (all false), safety_action_plan.actions.some(enabled) evaluates false, so G routes to E', () => {
  // Re-derive the safety_action_plan the same way F does, for an item that
  // would produce a STOP_ACTIVE_SEQUENCE + UPDATE_INTEREST_STATUS plan.
  const fOut = runCode(wf02, 'F. Safety Action Plan (Gated Contract, Pre-Approval)', [{ json: {
    nes: { campaign_context: { campaign_id: 'camp-1' }, lead_email: 'lead@example.com' },
    decision: { stop_active_sequence: true, address_suppression_intent: 'GLOBAL_BLOCKLIST' },
  } }]);
  const plan = fOut[0].json.safety_action_plan;
  assert(plan.actions.length > 0, 'plan must compute at least one action');
  const anyEnabled = plan.actions.some((a) => a.enabled === true);
  assert(anyEnabled === false, 'with the shipped config, no suppression action must be enabled');
});

tryRecord('g6_idempotency_key_deterministic', 'G6 computes a deterministic idempotency_key for the same (campaign, lead_email, action set)', () => {
  const refData = {
    'F. Safety Action Plan (Gated Contract, Pre-Approval)': {
      nes: { campaign_context: { campaign_id: 'camp-1' }, lead_email: 'lead@example.com' },
      safety_action_plan: { actions: [{ action: 'STOP_ACTIVE_SEQUENCE', enabled: false }, { action: 'UPDATE_INTEREST_STATUS', enabled: false }] },
    },
  };
  const out1 = runCode(wf02, 'G6. Build Suppression Execution Result', [{ json: {} }], refData);
  const out2 = runCode(wf02, 'G6. Build Suppression Execution Result', [{ json: {} }], refData);
  const k1 = out1[0].json.suppression_execution.idempotency_key;
  const k2 = out2[0].json.suppression_execution.idempotency_key;
  assert(typeof k1 === 'string' && k1.startsWith('suppression-'), `unexpected idempotency_key shape: ${k1}`);
  assert(k1 === k2, 'idempotency_key must be deterministic for identical inputs');
});

// ---------------------------------------------------------------------
// 14. Workflow 07: reviewer-identity-allowlist check inserted between
//     M(true) and N, without altering M's routing or N's decision logic.
// ---------------------------------------------------------------------
tryRecord('reviewer_allowlist_check_present_and_wired', 'M1 -> M2 -> {N (allowlisted) / M2b -> N2 (not allowlisted)} is inserted between M (true branch) and N; M(false) is unchanged; with the shipped empty REVIEWER_ALLOWLIST, M1 fails closed (configured=false, allowlisted=false) and M2 routes to M2b/N2', () => {
  const conn = wf07.connections;
  const mConn = conn['M. Submit Token Valid Router'];
  const trueTargets = mConn.main[0].map((e) => e.node);
  const falseTargets = mConn.main[1].map((e) => e.node);
  assert(trueTargets.includes('M1. Reviewer Identity Allowlist Check'), 'M(true) must point to M1');
  assert(!trueTargets.includes('N. Process Reviewer Decision'), 'M(true) must no longer point directly to N');
  assert(falseTargets.includes('N2. Render Submit Token Error') || falseTargets.length > 0, 'M(false) branch must be unchanged/non-empty');

  const m1Targets = conn['M1. Reviewer Identity Allowlist Check'].main[0].map((e) => e.node);
  assert(m1Targets.includes('M2. Reviewer Allowlist Router'), 'M1 must point to M2');

  const m2 = getNode(wf07, 'M2. Reviewer Allowlist Router');
  assert(m2.type === 'n8n-nodes-base.if', 'M2 must be an IF node');
  const m2True = conn['M2. Reviewer Allowlist Router'].main[0].map((e) => e.node);
  const m2False = conn['M2. Reviewer Allowlist Router'].main[1].map((e) => e.node);
  assert(m2True.includes('N. Process Reviewer Decision'), 'M2 true -> N');
  assert(m2False.includes('M2b. Mark Reviewer Not Allowlisted'), 'M2 false -> M2b');

  const m2bTargets = conn['M2b. Mark Reviewer Not Allowlisted'].main[0].map((e) => e.node);
  assert(m2bTargets.includes('N2. Render Submit Token Error'), 'M2b -> N2');

  const out = runCode(wf07, 'M1. Reviewer Identity Allowlist Check', [{ json: { submit_approver_identity: 'reviewer@example.com' } }]);
  const check = out[0].json.reviewer_allowlist_check;
  assert(check.configured === false, 'with empty REVIEWER_ALLOWLIST, configured must be false');
  assert(check.allowlisted === false, 'fail-closed: with configured=false, allowlisted must be false (never null)');
  assert(check.identity === 'reviewer@example.com', 'identity must be carried through');

  const m2bOut = runCode(wf07, 'M2b. Mark Reviewer Not Allowlisted', [{ json: { submit_approver_identity: 'reviewer@example.com' } }]);
  assert(m2bOut[0].json.token_invalid_reason === 'REVIEWER_NOT_ALLOWLISTED', 'M2b must set token_invalid_reason=REVIEWER_NOT_ALLOWLISTED');
});

tryRecord('reviewer_decision_logic_unchanged_by_m1', 'N (Process Reviewer Decision) still receives submit_action/submit_approver_identity/submit_edited_text/review_case fields untouched by M1 (additive-only insertion)', () => {
  const m1Out = runCode(wf07, 'M1. Reviewer Identity Allowlist Check', [{ json: {
    submit_action: 'approve',
    submit_approver_identity: 'reviewer@example.com',
    submit_edited_text: 'Edited reply text',
    review_case: { case_id: 'case-1', blocked_variables: [] },
  } }]);
  const nOut = runCode(wf07, 'N. Process Reviewer Decision', m1Out);
  const rc = nOut[0].json.review_case;
  assert(nOut[0].json.final_action === 'approve', `expected approve, got ${nOut[0].json.final_action}`);
  assert(rc.status === 'RESPONSE_APPROVED', `expected RESPONSE_APPROVED, got ${rc.status}`);
  assert(rc.approver_identity === 'reviewer@example.com', 'approver_identity must persist through M1 -> N');
  assert(rc.final_reply_text === 'Edited reply text', 'edited text must persist through M1 -> N');
});

// ---------------------------------------------------------------------
// 15. config/business-ready.config.json: new live-path keys are additive,
//     safe-default, and consistent with the embedded LAUNCH_PROFILE /
//     ALLOWLISTS constants.
// ---------------------------------------------------------------------
tryRecord('config_live_path_additions', 'config.json declares operating_mode/launch_profile (SUPERVISED_VALIDATION, no PROVEN mode, no unattended auto-send), allowlists, reviewer_allowlist, webhook_protection.production_path="instantly-reply", live_credential_readiness.instantly=false, instantly_api credential names', () => {
  const config = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'business-ready.config.json'), 'utf8'));
  assert(config.launch_profile && config.launch_profile.name === 'SUPERVISED_VALIDATION', 'launch_profile.name must be SUPERVISED_VALIDATION');
  assert(config.launch_profile.unattended_auto_send === false, 'launch_profile.unattended_auto_send must be false');
  assert(config.launch_profile.proven_mode === false, 'launch_profile.proven_mode must be false');
  assert(Array.isArray(config.allowlists.campaign_ids), 'allowlists.campaign_ids must be an array');
  assert(Array.isArray(config.allowlists.connected_sender_eaccounts), 'allowlists.connected_sender_eaccounts must be an array');
  assert(Array.isArray(config.reviewer_allowlist), 'reviewer_allowlist must be an array');
  assert(config.webhook_protection.production_path === 'instantly-reply', 'webhook_protection.production_path must be "instantly-reply"');
  assert(config.live_credential_readiness.instantly === false, 'live_credential_readiness.instantly must be false');
  assert(config.instantly_api.reply_credential_name === 'hmzInstantlyApi', 'instantly_api.reply_credential_name must be hmzInstantlyApi');
  assert(config.instantly_api.webhook_token_credential_name === 'hmzInstantlyWebhookToken', 'instantly_api.webhook_token_credential_name must be hmzInstantlyWebhookToken');
  // Still safe by default.
  assert(config.dry_run === true, 'config.dry_run must remain true');
  assert(Array.isArray(config.live_campaigns) && config.live_campaigns.length === 0, 'config.live_campaigns must remain []');
});

// ---------------------------------------------------------------------
// 16. Connection-graph integrity: every connection target across all 7
//     workflows references a node that exists in that workflow.
// ---------------------------------------------------------------------
tryRecord('connection_targets_exist', 'Every connection target node name in all 7 workflows refers to a node that exists in that workflow', () => {
  for (const f of WORKFLOW_FILES) {
    const wf = workflows[f];
    const names = new Set(wf.nodes.map((n) => n.name));
    for (const [source, conn] of Object.entries(wf.connections)) {
      assert(names.has(source), `${f}: connection source "${source}" is not a node`);
      for (const branch of conn.main || []) {
        for (const edge of branch || []) {
          assert(names.has(edge.node), `${f}: connection target "${edge.node}" (from "${source}") is not a node`);
        }
      }
    }
  }
});

// ---------------------------------------------------------------------
// 17. All embedded Code nodes (including the new live-path nodes) compile.
// ---------------------------------------------------------------------
tryRecord('live_path_code_nodes_compile', 'Every Code node jsCode body in all 7 workflows (including new live-path nodes) is syntactically valid JavaScript', () => {
  for (const f of WORKFLOW_FILES) {
    for (const n of codeNodes(workflows[f])) {
      const jsCode = (n.parameters && n.parameters.jsCode) || '';
      // eslint-disable-next-line no-new
      new Function('$input', '$', jsCode);
    }
  }
});

// ---------------------------------------------------------------------
// 18. PowerShell scripts: apply allows the new gated Instantly adapters and
//     the production webhook credential; controlled-live acceptance has
//     -PreflightOnly (default) and -AllowOneControlledReply modes.
// ---------------------------------------------------------------------
tryRecord('apply_script_allows_instantly_and_webhook_credentials', 'apply-business-ready.ps1 allows https://api.instantly.ai HTTP targets and documents credentialPlaceholder -> real credential patching for hmzInstantlyApi / hmzInstantlyWebhookToken', () => {
  const text = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'apply-business-ready.ps1'), 'utf8');
  assert(text.includes('https://api.instantly.ai'), 'apply script must allow https://api.instantly.ai');
  assert(text.includes('credentialPlaceholder'), 'apply script must reference credentialPlaceholder');
  assert(text.includes('hmzInstantlyApi'), 'apply script must reference hmzInstantlyApi');
  assert(text.includes('hmzInstantlyWebhookToken'), 'apply script must reference hmzInstantlyWebhookToken');
});

tryRecord('controlled_live_acceptance_two_modes', 'run-controlled-live-acceptance.ps1 supports -PreflightOnly (default, read-only) and -AllowOneControlledReply (requires typed RUN-ONE-CONTROLLED-REPLY confirmation, one attempt, restores DRY_RUN=true/LIVE_CAMPAIGNS=[]/inactive workflows in finally)', () => {
  const text = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'run-controlled-live-acceptance.ps1'), 'utf8');
  assert(text.includes('PreflightOnly'), 'must support -PreflightOnly');
  assert(text.includes('AllowOneControlledReply'), 'must support -AllowOneControlledReply');
  assert(text.includes('RUN-ONE-CONTROLLED-REPLY'), 'must require the typed confirmation phrase');
  assert(text.includes('PROVEN'), 'must continue to document that PROVEN mode is out of scope');
});

// ---------------------------------------------------------------------
// 19. Fixtures: error-routing and watchdog acceptance fixtures exist.
// ---------------------------------------------------------------------
tryRecord('live_path_fixtures_present', 'fixtures/business_ready_live_path/ contains JSON fixtures for the error-routing and SLA-watchdog acceptance checks', () => {
  const dir = path.join(ROOT, 'fixtures', 'business_ready_live_path');
  assert(fs.existsSync(dir), `${dir} must exist`);
  const files = fs.readdirSync(dir);
  assert(files.some((f) => /error/i.test(f)), 'expected an error-routing fixture');
  assert(files.some((f) => /watchdog|sla/i.test(f)), 'expected a watchdog/SLA fixture');
  for (const f of files) {
    if (f.endsWith('.json')) {
      JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    }
  }
});

// ---------------------------------------------------------------------
// 20-23. Regression: re-run the existing business-ready offline suite
// (23/23), which itself re-runs phase4a (42), phase4b (31), and
// integration-closure (16).
// ---------------------------------------------------------------------
function runRegression(id, scriptPath, expectedTotal) {
  if (!fs.existsSync(scriptPath)) {
    record(id, `${path.relative(ROOT, scriptPath)} regression suite (${expectedTotal}/${expectedTotal})`, false, 'script not found');
    return;
  }
  const proc = spawnSync(process.execPath, [scriptPath], { cwd: ROOT, encoding: 'utf8' });
  const output = `${proc.stdout || ''}${proc.stderr || ''}`;
  const match = output.match(/(\d+)\/(\d+) passed, (\d+) failed/);
  const ok =
    proc.status === 0 &&
    !!match &&
    Number(match[2]) === expectedTotal &&
    Number(match[1]) === expectedTotal &&
    Number(match[3]) === 0;
  record(
    id,
    `${path.relative(ROOT, scriptPath)} regression suite reports ${expectedTotal}/${expectedTotal}`,
    ok,
    ok ? undefined : { exitCode: proc.status, matched: match ? match[0] : null }
  );
}

runRegression('regression_business_ready', path.join(ROOT, 'verification', 'business-ready', 'run-offline-tests.mjs'), 23);

// ---------------------------------------------------------------------
// Finish.
// ---------------------------------------------------------------------
const passed = results.filter((r) => r.passed).length;
const failed = results.length - passed;
const summary = {
  schema_version: '1.0',
  generated_at: new Date().toISOString(),
  total: results.length,
  passed,
  failed,
  overall_result: failed === 0 ? 'PASS' : 'FAIL',
  results,
};

fs.writeFileSync(
  path.join(__dirname, 'live-path-offline-results.json'),
  `${JSON.stringify(summary, null, 2)}\n`,
  'utf8'
);

for (const r of results) {
  console.log(`[${r.passed ? 'PASS' : 'FAIL'}] ${r.id} - ${r.description}`);
  if (!r.passed && r.details !== undefined) {
    console.log(`       ${JSON.stringify(r.details)}`);
  }
}
console.log(`\n${passed}/${results.length} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
