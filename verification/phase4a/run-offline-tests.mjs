// Phase 4A offline test suite.
//
// Runs entirely offline: no network access, no Docker, no n8n. Exercises
// sender-core.mjs / error-core.mjs / state-store.mjs directly, and performs
// static safety checks on the generated workflow JSON and the compose file.
//
// Usage: node verification/phase4a/run-offline-tests.mjs

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as sc from './sender-core.mjs';
import * as ec from './error-core.mjs';
import * as store from '../../infrastructure/send-state/state-store.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const WORKFLOWS_DIR = path.join(PROJECT_ROOT, 'workflows');
const FIXTURES_DIR = path.join(PROJECT_ROOT, 'fixtures', 'phase_4a');
const RESULTS_PATH = path.join(SCRIPT_DIR, 'offline-test-results.json');
const COMPOSE_PATH = path.join(PROJECT_ROOT, 'infrastructure', 'local-n8n', 'docker-compose.yml');

const SENDER_WF_PATH = path.join(WORKFLOWS_DIR, '03_reply_sender_validation.json');
const ERROR_WF_PATH = path.join(WORKFLOWS_DIR, '04_reply_error_handler_validation.json');

function loadFixture(name) {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function walkNodes(value, visit) {
  if (Array.isArray(value)) {
    for (const item of value) walkNodes(item, visit);
    return;
  }
  if (value && typeof value === 'object') {
    visit(value);
    for (const key of Object.keys(value)) walkNodes(value[key], visit);
  }
}


function executeGeneratedCodeNode(workflow, nodeName, inputItems, priorByNode = {}) {
  const node = workflow.nodes.find((candidate) => candidate.name === nodeName);
  assert(node, `generated workflow node not found: ${nodeName}`);
  assert(node.type === 'n8n-nodes-base.code', `${nodeName} is not a Code node`);
  const $input = { all: () => inputItems };
  const $ = (priorNodeName) => ({ all: () => priorByNode[priorNodeName] || [] });
  const runner = new Function('$input', '$', node.parameters.jsCode);
  return runner($input, $);
}

// ---------------------------------------------------------------------
// Test registry
// ---------------------------------------------------------------------
const tests = [];
function test(id, description, run) {
  tests.push({ id, description, run });
}

let senderWorkflow;
let errorWorkflow;

// --- Workflow JSON structural / safety tests ---------------------------

test('wf-json-parses', 'Both generated workflow files parse as valid JSON', () => {
  senderWorkflow = JSON.parse(fs.readFileSync(SENDER_WF_PATH, 'utf8'));
  errorWorkflow = JSON.parse(fs.readFileSync(ERROR_WF_PATH, 'utf8'));
});

test('wf-names', 'Workflows have the required names', () => {
  assert(senderWorkflow.name === 'HMZ - Instantly Reply Sender - Validation', 'sender workflow name mismatch');
  assert(errorWorkflow.name === 'HMZ - Reply Error Handler - Validation', 'error handler workflow name mismatch');
});

test('wf-inactive', 'Both workflows are inactive', () => {
  assert(senderWorkflow.active === false, 'sender workflow must be active:false');
  assert(errorWorkflow.active === false, 'error handler workflow must be active:false');
});

test('wf-no-credentials', 'No node in either workflow has a credentials object', () => {
  for (const [label, wf] of [['sender', senderWorkflow], ['error', errorWorkflow]]) {
    for (const node of wf.nodes) {
      assert(!('credentials' in node), `${label} workflow node "${node.name}" has a credentials object`);
    }
  }
});

const SECRET_LIKE_PATTERN =
  /(sk-[A-Za-z0-9]{10,}|AKIA[A-Z0-9]{12,}|xox[baprs]-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{20,}|"Authorization"\s*:\s*"(?!<REDACTED>)[^"\s]{5,}")/;

test('wf-no-secret-values', 'Neither workflow JSON contains secret-like literal values', () => {
  for (const [label, wfPath] of [['sender', SENDER_WF_PATH], ['error', ERROR_WF_PATH]]) {
    const text = fs.readFileSync(wfPath, 'utf8');
    assert(!SECRET_LIKE_PATTERN.test(text), `${label} workflow contains a secret-like literal value`);
  }
});

test('wf-no-live-instantly-request', 'No httpRequest node targets a live Instantly endpoint unless gated by a credentialPlaceholder live-path adapter', () => {
  for (const [label, wf] of [['sender', senderWorkflow], ['error', errorWorkflow]]) {
    for (const node of wf.nodes) {
      if (node.type !== 'n8n-nodes-base.httpRequest') continue;
      const url = node.parameters && node.parameters.url;
      assert(typeof url === 'string', `${label} workflow node "${node.name}" httpRequest has no url`);
      const isSidecar = url.startsWith('http://hmz-send-state:5681');
      const isGatedGoogleChat = url === '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}';
      const isGatedInstantlyAdapter =
        url.startsWith('https://api.instantly.ai/') &&
        node.credentialPlaceholder === 'hmzInstantlyApi' &&
        node.onError === 'continueRegularOutput';
      assert(isSidecar || isGatedGoogleChat || isGatedInstantlyAdapter, `${label} workflow node "${node.name}" url is neither the internal sidecar, the gated Google Chat env var, nor a gated credentialPlaceholder live-path Instantly adapter: ${url}`);
    }
  }
});

test('wf-live-instantly-only-in-contract-string', 'api.instantly.ai appears only inside Code node source as a documented (non-executed) string literal, or in a gated credentialPlaceholder live-path adapter node', () => {
  const text = fs.readFileSync(SENDER_WF_PATH, 'utf8');
  assert(text.includes("'https://api.instantly.ai/api/v2/emails/reply'"), 'expected the documented V3 reply contract URL as a string literal');
  for (const node of senderWorkflow.nodes) {
    const url = node.parameters && node.parameters.url;
    if (typeof url === 'string' && url.includes('instantly.ai')) {
      const isGatedInstantlyAdapter =
        url.startsWith('https://api.instantly.ai/') &&
        node.credentialPlaceholder === 'hmzInstantlyApi' &&
        node.onError === 'continueRegularOutput';
      assert(isGatedInstantlyAdapter, `node "${node.name}" has a non-Code-node, non-gated url referencing instantly.ai`);
    }
  }
});

test('wf-error-handler-no-external-notification-services', 'Error handler workflow never calls Slack/email/Sheets', () => {
  for (const node of errorWorkflow.nodes) {
    if (node.type === 'n8n-nodes-base.stickyNote') continue;
    const text = JSON.stringify(node).toLowerCase();
    for (const forbidden of ['slack', 'sendgrid', 'smtp', 'sheets.googleapis', 'mailgun']) {
      assert(!text.includes(forbidden), `error handler node "${node.name}" unexpectedly references "${forbidden}"`);
    }
  }
});

test('wf-hardcoded-validation-config', 'Sender workflow hardcodes OPERATING_MODE=VALIDATION, DRY_RUN=true, LIVE_CAMPAIGNS=[], LIVE_CREDENTIAL_READY=false', () => {
  const code = senderWorkflow.nodes
    .filter((node) => node.type === 'n8n-nodes-base.code')
    .map((node) => node.parameters.jsCode)
    .join('\n');
  assert(code.includes('OPERATING_MODE = "VALIDATION"'), 'OPERATING_MODE constant not found');
  assert(code.includes('DRY_RUN = true'), 'DRY_RUN constant not found');
  assert(code.includes('LIVE_CAMPAIGNS = []'), 'LIVE_CAMPAIGNS constant not found');
  assert(code.includes('LIVE_CREDENTIAL_READY = false'), 'LIVE_CREDENTIAL_READY constant not found');
});


// --- generated workflow runtime smoke tests ----------------------------

test('wf-generated-code-compiles', 'Every generated Code node compiles as standalone n8n JavaScript', () => {
  for (const workflow of [senderWorkflow, errorWorkflow]) {
    for (const node of workflow.nodes.filter((candidate) => candidate.type === 'n8n-nodes-base.code')) {
      try {
        new Function('$input', '$', node.parameters.jsCode);
      } catch (error) {
        throw new Error(`${workflow.name} / ${node.name} failed to compile: ${error.message}`);
      }
    }
  }
});

test('wf-generated-error-handler-runtime-smoke', 'Generated Error Handler Code nodes execute a synthetic SEND_UNCERTAIN pipeline', () => {
  const source = [{ json: {
    workflow_id: 'wf-test', workflow_name: 'HMZ - Instantly Reply Sender - Validation',
    execution_id: 'exec-test', failed_node: 'Mock Send', intake_id: 'intake-test',
    send_key: 'a'.repeat(64), send_state: 'SEND_UNCERTAIN', http_status: 503,
    attempt: 1, Authorization: 'Bearer must-not-survive'
  }}];
  const normalized = executeGeneratedCodeNode(errorWorkflow, 'A. Normalize Error Event', source);
  assert(normalized[0].json.error_record.error_class === 'SEND_UNCERTAIN', 'generated Normalize node misclassified SEND_UNCERTAIN');
  assert(normalized[0].json.error_record.retryable === false, 'generated Normalize node marked SEND_UNCERTAIN retryable');
  const redacted = executeGeneratedCodeNode(errorWorkflow, 'B. Redact Sensitive Data', normalized);
  assert(!JSON.stringify(redacted[0].json.error_record).includes('must-not-survive'), 'generated Redact node leaked a secret');
  const attached = executeGeneratedCodeNode(errorWorkflow, 'C2. Attach Error ID', [{ json: { errorId: '0123456789abcdef' } }], { 'B. Redact Sensitive Data': redacted });
  assert(attached[0].json.persisted_error.errorId === '0123456789abcdef', 'generated Attach Error ID node failed');
  const notified = executeGeneratedCodeNode(errorWorkflow, 'D. Build Notification Payload (Gated)', attached);
  assert(notified[0].json.notification.surface === 'NOT_CONFIGURED', 'generated notification node returned the wrong surface');
  assert(notified[0].json.notification.delivered === false, 'generated notification node must remain undelivered');
});

test('wf-generated-sender-runtime-smoke', 'Generated Sender Code nodes execute the validation DRY_RUN path', () => {
  const fixture = loadFixture('decision_engine_output_valid.json');
  const validated = executeGeneratedCodeNode(senderWorkflow, 'A. Validate Decision Engine Output', [{ json: fixture }]);
  assert(validated[0].json.sender_validation.valid === true, 'generated Sender validation node rejected the valid fixture');
  const gated = executeGeneratedCodeNode(senderWorkflow, 'B. Re-run Send & Suppression Gates', validated);
  assert(gated[0].json.gates.passed === true, 'generated Sender gates did not pass the valid DRY_RUN fixture');
  const keyed = executeGeneratedCodeNode(senderWorkflow, 'D. Compute Stable Send Key', gated);
  assert(keyed[0].json.send_identity.sendKey.startsWith('send-'), 'generated Sender key node did not produce an informational key');
  const acquired = executeGeneratedCodeNode(senderWorkflow, 'E2. Normalize Acquisition Result', [{ json: { acquired: true, blocked: false, sendKey: 'b'.repeat(64), state: 'LOCKED' } }], { 'D. Compute Stable Send Key': keyed });
  const suppressed = executeGeneratedCodeNode(senderWorkflow, 'G. Suppression Actions (Mock Adapter)', acquired);
  const verified = executeGeneratedCodeNode(senderWorkflow, 'H. Verify Suppression Results', suppressed);
  assert(verified[0].json.suppression_verification.verified === true, 'generated Sender suppression verification failed');
  const terminal = executeGeneratedCodeNode(senderWorkflow, 'K2. Build DRY_RUN Terminal Result', [{ json: { ok: true, sendKey: 'b'.repeat(64), state: 'DRY_RUN_OK' } }], { 'H. Verify Suppression Results': verified });
  assert(terminal[0].json.terminal.send_state === 'DRY_RUN_OK', 'generated Sender did not end in DRY_RUN_OK');
  assert(terminal[0].json.terminal.sent === false, 'generated Sender claimed a send in DRY_RUN');
});

// --- send key stability ------------------------------------------------

test('send-key-stable-ignores-random-marker', 'computeSendKey() and the sidecar deriveSendKey() ignore the random body marker', () => {
  const base = loadFixture('decision_engine_output_valid.json');
  const withDifferentMarker = { ...base, random_marker: 'marker-ZZZZ' };

  const a = sc.computeSendKey(base);
  const b = sc.computeSendKey(withDifferentMarker);
  assert(a.send_identity.sendKey === b.send_identity.sendKey, 'n8n-side sendKey changed when only the random marker changed');

  const identity = {
    inboundEmailId: a.send_identity.inboundEmailId,
    sender: a.send_identity.sender,
    recipient: a.send_identity.recipient,
    policyTemplateId: a.send_identity.policyTemplateId,
  };
  const sidecarKey1 = store.deriveSendKey(identity);
  const sidecarKey2 = store.deriveSendKey(identity);
  assert(sidecarKey1 === sidecarKey2, 'sidecar sendKey is not deterministic for the same identity');
  assert(/^[0-9a-f]{64}$/.test(sidecarKey1), 'sidecar sendKey is not a 64-hex sha256 digest');
});

// --- sidecar atomic acquisition / forward-only state machine -----------

let tmpStateDir;

test('sidecar-acquire-and-concurrent-lock', 'Concurrent second acquisition for the same identity is blocked (LOCK_ALREADY_HELD)', () => {
  tmpStateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-send-state-test-'));
  const identity = {
    inboundEmailId: '11111111-1111-1111-1111-111111111111',
    sender: 'sender@example.com',
    recipient: 'lead@example.com',
    policyTemplateId: 'template-abc',
  };

  const first = store.acquireSend(tmpStateDir, identity);
  assert(first.acquired === true, 'first acquisition should succeed');
  assert(first.state === store.SEND_STATES.LOCKED, 'first acquisition should write state LOCKED');

  const second = store.acquireSend(tmpStateDir, identity);
  assert(second.acquired === false, 'second concurrent acquisition should be blocked');
  assert(second.blocked === true, 'second concurrent acquisition should report blocked=true');
  assert(second.reason === 'LOCK_ALREADY_HELD', `expected LOCK_ALREADY_HELD, got ${second.reason}`);
  assert(second.sendKey === first.sendKey, 'blocked acquisition should report the same sendKey');
});


test('sidecar-state-does-not-store-raw-email-identifiers', 'Sidecar durable state stores hashes instead of raw sender/recipient identifiers', () => {
  const identity = {
    inboundEmailId: 'pii-test-inbound-id',
    sender: 'sender-sensitive@example.test',
    recipient: 'recipient-sensitive@example.test',
    policyTemplateId: 'template-sensitive',
  };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-send-state-pii-test-'));
  try {
    const acquired = store.acquireSend(dir, identity);
    assert(acquired.acquired === true, 'PII state test acquisition failed');
    const saved = store.readState(dir, acquired.sendKey);
    const text = JSON.stringify(saved);
    assert(!text.includes(identity.inboundEmailId), 'raw inbound Email ID was stored');
    assert(!text.includes(identity.sender), 'raw sender email was stored');
    assert(!text.includes(identity.recipient), 'raw recipient email was stored');
    assert(!text.includes(identity.policyTemplateId), 'raw policy/template identifier was stored');
    assert(/^[0-9a-f]{64}$/.test(saved.details.senderHash), 'senderHash is missing or invalid');
    assert(/^[0-9a-f]{64}$/.test(saved.details.recipientHash), 'recipientHash is missing or invalid');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('sidecar-sequential-rerun-blocked-after-terminal', 'A later sequential rerun for the same identity is blocked (DURABLE_STATE_EXISTS)', () => {
  const identity = {
    inboundEmailId: '11111111-1111-1111-1111-111111111111',
    sender: 'sender@example.com',
    recipient: 'lead@example.com',
    policyTemplateId: 'template-abc',
  };
  const sendKey = store.deriveSendKey(identity);

  // Transition the still-LOCKED record from the previous test to a
  // terminal state, releasing the lock.
  const transition = store.transitionSend(tmpStateDir, sendKey, store.SEND_STATES.DRY_RUN_OK, { reason: 'dry_run_validation' });
  assert(transition.ok === true, `transition to DRY_RUN_OK should succeed, got ${JSON.stringify(transition)}`);
  assert(store.isTerminal(transition.state) === true, 'DRY_RUN_OK should be a terminal state');

  const rerun = store.acquireSend(tmpStateDir, identity);
  assert(rerun.acquired === false, 'sequential rerun should be blocked');
  assert(rerun.blocked === true, 'sequential rerun should report blocked=true');
  assert(rerun.reason === 'DURABLE_STATE_EXISTS', `expected DURABLE_STATE_EXISTS, got ${rerun.reason}`);
  assert(rerun.priorState === store.SEND_STATES.DRY_RUN_OK, `expected priorState DRY_RUN_OK, got ${rerun.priorState}`);
});

test('sidecar-no-transition-from-uncertain-to-submission', 'No transition is allowed from SEND_UNCERTAIN back to SUBMITTING', () => {
  assert(store.canTransition('SEND_UNCERTAIN', 'SUBMITTING') === false, 'SEND_UNCERTAIN -> SUBMITTING must be rejected');
  assert(store.canTransition('SEND_UNCERTAIN', 'SENT_RECONCILED') === true, 'SEND_UNCERTAIN -> SENT_RECONCILED must be allowed');
  assert(store.canTransition('SEND_UNCERTAIN', 'HUMAN_REVIEW_ZERO_MATCHES') === true, 'SEND_UNCERTAIN -> HUMAN_REVIEW_ZERO_MATCHES must be allowed');
});

// --- gate logic ----------------------------------------------------------

test('gate-dry-run-prevents-transport', 'DRY_RUN gate passes and the DRY_RUN terminal never sets transport other than NONE', () => {
  const item = sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_valid.json')));
  assert(item.gates.dry_run_gate_passed === true, 'dry_run_gate_passed should be true when DRY_RUN=true');
  assert(item.gates.passed === true, 'a fully valid item should pass all gates');

  const withAcquisition = { ...item, acquisition: { sendKey: 'send-deadbeef' }, suppression_verification: { verified: true } };
  const terminal = sc.buildDryRunTerminal(withAcquisition, { state: 'DRY_RUN_OK' });
  assert(terminal.terminal.result === 'DRY_RUN_OK', 'expected result DRY_RUN_OK');
  assert(terminal.terminal.transport === 'NONE', 'expected transport NONE');
  assert(terminal.terminal.sent === false, 'expected sent=false');
});

test('gate-missing-approval-blocks', 'A missing approval blocks the send gates', () => {
  const item = sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_no_approval.json')));
  assert(item.gates.approval_gate_passed === false, 'approval_gate_passed should be false');
  assert(item.gates.passed === false, 'gates.passed should be false');
  assert(item.gates.reasons.includes('approval_missing'), 'reasons should include approval_missing');

  const terminal = sc.buildGateRejectionTerminal(item);
  assert(terminal.terminal.result === 'BLOCKED', 'rejection terminal result should be BLOCKED');
});

test('gate-empty-live-campaigns-blocks-live-send', 'LIVE_CAMPAIGNS=[] always blocks live campaign sends', () => {
  const item = sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_valid.json')));
  assert(item.gates.live_campaign_send_allowed === false, 'live_campaign_send_allowed should be false when LIVE_CAMPAIGNS=[]');
  assert(sc.LIVE_CAMPAIGNS.length === 0, 'LIVE_CAMPAIGNS must be empty');
});

test('gate-unresolved-template-variable-blocks', 'An unresolved [[token]] in draft_text blocks the draft variable gate', () => {
  const item = sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_unresolved_template.json')));
  assert(item.gates.draft_variable_gate_passed === false, 'draft_variable_gate_passed should be false');
  assert(item.gates.unresolved_tokens.includes('[[first_name]]'), 'unresolved_tokens should include [[first_name]]');
  assert(item.gates.passed === false, 'gates.passed should be false');
});

test('gate-invalid-decision-engine-output-rejected', 'An invalid Decision Engine output fails validateSenderInput and the gate router', () => {
  const validated = sc.validateSenderInput(loadFixture('decision_engine_output_invalid.json'));
  assert(validated.sender_validation.valid === false, 'sender_validation.valid should be false');
  assert(validated.sender_validation.errors.length > 0, 'sender_validation.errors should be non-empty');

  const item = sc.runSendGates(validated);
  assert(item.gates.passed === false, 'gates.passed should be false for invalid input');
  assert(item.gates.reasons.includes('sender_validation_failed'), 'reasons should include sender_validation_failed');
});

// --- acquisition / blocked duplicate routing ----------------------------

test('acquisition-blocked-duplicate-terminal', 'A blocked acquisition produces a single BLOCKED terminal with no further action', () => {
  const item = sc.computeSendKey(sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_valid.json'))));
  const normalized = sc.normalizeAcquisitionResult(item, { acquired: false, reason: 'DURABLE_STATE_EXISTS', priorState: 'DRY_RUN_OK', sendKey: 'send-deadbeef' });
  assert(normalized.acquisition.acquired === false, 'acquisition.acquired should be false');
  assert(normalized.acquisition.blocked === true, 'acquisition.blocked should be true');

  const terminal = sc.buildBlockedDuplicateTerminal(normalized);
  assert(terminal.terminal.result === 'BLOCKED', 'expected result BLOCKED');
  assert(terminal.terminal.reason === 'DURABLE_STATE_EXISTS', 'expected reason DURABLE_STATE_EXISTS');
  assert(terminal.terminal.sent === false, 'expected sent=false');
});

// --- suppression ----------------------------------------------------------

test('suppression-unsubscribe-requires-both-actions-verified', 'Unsubscribe confirmation is only permitted once both suppression actions are verified', () => {
  const item = sc.runSendGates(sc.validateSenderInput(loadFixture('decision_engine_output_unsubscribe.json')));
  assert(item.gates.suppression_required === true, 'suppression_required should be true for ORGANISATION_DNC');

  const withSuppression = sc.mockSuppressionAdapter(item);
  assert(withSuppression.suppression.required === true, 'suppression.required should be true');
  assert(withSuppression.suppression.source_campaign_action.status === 'VERIFIED', 'source_campaign_action should be VERIFIED by default');
  assert(withSuppression.suppression.workspace_blocklist_action.status === 'VERIFIED', 'workspace_blocklist_action should be VERIFIED by default');

  const verification = sc.verifySuppressionResults(withSuppression);
  assert(verification.suppression_verification.verified === true, 'suppression_verification.verified should be true');
  assert(verification.suppression_verification.escalate === false, 'suppression_verification.escalate should be false');

  const acquisitionItem = { ...verification, acquisition: { sendKey: 'send-deadbeef' } };
  const terminal = sc.buildDryRunTerminal(acquisitionItem, { state: 'DRY_RUN_OK' });
  assert(terminal.terminal.reply_permitted_after_suppression === true, 'unsubscribe confirmation should be permitted once both suppression actions are verified');
});

test('suppression-partial-failure-escalates', 'A partial suppression failure escalates instead of confirming unsubscribe', () => {
  const base = loadFixture('decision_engine_output_unsubscribe.json');
  const withOverride = { ...base, test_overrides: { workspace_blocklist_action_status: 'FAILED' } };
  const item = sc.runSendGates(sc.validateSenderInput(withOverride));

  const withSuppression = sc.mockSuppressionAdapter(item);
  assert(withSuppression.suppression.workspace_blocklist_action.status === 'FAILED', 'workspace_blocklist_action should reflect test_overrides');

  const verification = sc.verifySuppressionResults(withSuppression);
  assert(verification.suppression_verification.verified === false, 'suppression_verification.verified should be false');
  assert(verification.suppression_verification.escalate === true, 'suppression_verification.escalate should be true');

  const terminal = sc.buildSuppressionEscalationTerminal(verification);
  assert(terminal.terminal.result === 'ESCALATED', 'expected result ESCALATED');
  assert(terminal.terminal.send_state === 'BLOCKED', 'expected send_state BLOCKED');
});

// --- send outcome classification -----------------------------------------

test('classify-permanent-failure-400', 'HTTP 400 classifies as terminal PERMANENT_FAILURE', () => {
  const result = sc.classifySendOutcome({ kind: 'http', status: 400, body: {}, headers: {} });
  assert(result.mode === 'terminal' && result.state === 'PERMANENT_FAILURE', `unexpected: ${JSON.stringify(result)}`);
});

test('classify-auth-or-plan-failure-401-403', 'HTTP 401/402/403 classify as terminal AUTH_OR_PLAN_FAILURE', () => {
  for (const status of [401, 402, 403]) {
    const result = sc.classifySendOutcome({ kind: 'http', status, body: {}, headers: {} });
    assert(result.mode === 'terminal' && result.state === 'AUTH_OR_PLAN_FAILURE', `status ${status}: unexpected ${JSON.stringify(result)}`);
  }
});

test('classify-invalid-reply-target-404', 'HTTP 404 classifies as terminal INVALID_REPLY_TARGET', () => {
  const result = sc.classifySendOutcome({ kind: 'http', status: 404, body: {}, headers: {} });
  assert(result.mode === 'terminal' && result.state === 'INVALID_REPLY_TARGET', `unexpected: ${JSON.stringify(result)}`);
});

test('classify-retryable-429-honours-retry-after', 'HTTP 429 with Retry-After is retryable and honours Retry-After (capped)', () => {
  const result = sc.classifySendOutcome({ kind: 'http', status: 429, body: {}, headers: { 'retry-after': '10' } });
  assert(result.mode === 'retryable', `unexpected mode: ${result.mode}`);
  assert(result.retryAfterMs === 10000, `expected retryAfterMs=10000, got ${result.retryAfterMs}`);

  const planned = sc.planSendAttempts(
    [
      { kind: 'http', status: 429, body: {}, headers: { 'retry-after': String(sc.RETRY_AFTER_CAP_MS / 1000 + 100) } },
      { kind: 'http', status: 200, body: { status: 'sent', messageId: 'm-1' }, headers: {} },
    ],
    {}
  );
  assert(planned.retryAfterHonoured === true, 'retryAfterHonoured should be true');
  assert(planned.backoffDelaysRequested[0] === sc.RETRY_AFTER_CAP_MS, `Retry-After should be capped at ${sc.RETRY_AFTER_CAP_MS}, got ${planned.backoffDelaysRequested[0]}`);
  assert(planned.finalState === 'SENT', `expected SENT after retry, got ${planned.finalState}`);
});

test('classify-retryable-5xx', 'HTTP 500/502/503/504 classify as retryable', () => {
  for (const status of [500, 502, 503, 504]) {
    const result = sc.classifySendOutcome({ kind: 'http', status, body: {}, headers: {} });
    assert(result.mode === 'retryable', `status ${status}: unexpected mode ${result.mode}`);
    assert(result.exhaustedState === 'RETRY_EXHAUSTED', `status ${status}: unexpected exhaustedState ${result.exhaustedState}`);
  }
});

test('classify-malformed-2xx-and-timeout-are-uncertain', 'A malformed 2xx body and a timeout both classify as SEND_UNCERTAIN', () => {
  const malformed = sc.classifySendOutcome({ kind: 'http', status: 200, body: { ok: true }, headers: {} });
  assert(malformed.mode === 'terminal' && malformed.state === 'SEND_UNCERTAIN', `malformed 2xx: unexpected ${JSON.stringify(malformed)}`);
  assert(malformed.ambiguousSideEffect === true, 'malformed 2xx should have ambiguousSideEffect=true');

  const timeout = sc.classifySendOutcome({ kind: 'network-error', errorPhase: 'timeout' });
  assert(timeout.mode === 'terminal' && timeout.state === 'SEND_UNCERTAIN', `timeout: unexpected ${JSON.stringify(timeout)}`);
});

test('valid-sent-contract-2xx', 'A well-formed 2xx body (status=sent, messageId) classifies as terminal SENT', () => {
  const result = sc.classifySendOutcome({ kind: 'http', status: 200, body: { status: 'sent', messageId: 'm-123' }, headers: {} });
  assert(result.mode === 'terminal' && result.state === 'SENT', `unexpected: ${JSON.stringify(result)}`);
});

test('no-retry-after-send-uncertain', 'SEND_UNCERTAIN is terminal: no further POST is attempted even if outcomes remain', () => {
  const planned = sc.planSendAttempts(
    [
      { kind: 'http', status: 200, body: { ok: true }, headers: {}, serverReceived: true },
      { kind: 'http', status: 200, body: { status: 'sent', messageId: 'm-2' }, headers: {}, serverReceived: true },
    ],
    {}
  );
  assert(planned.finalState === 'SEND_UNCERTAIN', `expected SEND_UNCERTAIN, got ${planned.finalState}`);
  assert(planned.attempts === 1, `expected exactly 1 attempt, got ${planned.attempts}`);
  assert(planned.postSubmissions === 1, `expected exactly 1 server-received submission, got ${planned.postSubmissions}`);
  assert(planned.humanReviewRequired === true, 'humanReviewRequired should be true');
});

// --- reconciliation ---------------------------------------------------

test('reconcile-zero-matches-human-review', 'Zero matches reconciles to HUMAN_REVIEW_ZERO_MATCHES', () => {
  const result = sc.reconcileMatches([[], []]);
  assert(result.state === 'HUMAN_REVIEW_ZERO_MATCHES', `unexpected: ${JSON.stringify(result)}`);
});

test('reconcile-multiple-matches-human-review', 'Multiple matches in a single poll reconciles to HUMAN_REVIEW_MULTIPLE_MATCHES', () => {
  const result = sc.reconcileMatches([['m-1', 'm-2']]);
  assert(result.state === 'HUMAN_REVIEW_MULTIPLE_MATCHES', `unexpected: ${JSON.stringify(result)}`);
  assert(result.matchCount === 2, `expected matchCount=2, got ${result.matchCount}`);
});

test('reconcile-repeated-single-match-sent-reconciled', 'The same single match on two consecutive polls reconciles to SENT_RECONCILED', () => {
  const result = sc.reconcileMatches([['m-1'], ['m-1']]);
  assert(result.state === 'SENT_RECONCILED', `unexpected: ${JSON.stringify(result)}`);
  assert(result.matchId === 'm-1', `expected matchId=m-1, got ${result.matchId}`);
});

// --- error handler --------------------------------------------------------

test('error-record-normalised-and-sanitised', 'Error records are normalised, classified, and have secrets/long values redacted', () => {
  const longBody = 'x'.repeat(1000);
  const syntheticEvent = {
    workflow_id: 'wf-03',
    workflow_name: 'HMZ - Instantly Reply Sender - Validation',
    execution_id: 'exec-1',
    failed_node: 'E. Acquire Send Ownership (hmz-send-state)',
    intake_id: 'intake-0001',
    send_key: 'send-deadbeef',
    send_state: 'BLOCKED',
    http_status: 503,
    attempt: 2,
    headers: { Authorization: 'Bearer super-secret-token', apiKey: 'sk-test-123456789' },
    raw_response_body: longBody,
  };

  const normalized = ec.normalizeErrorEvent(syntheticEvent);
  assert(normalized.error_record.error_class === 'RETRYABLE', `expected RETRYABLE, got ${normalized.error_record.error_class}`);
  assert(normalized.error_record.retryable === true, 'retryable should be true for a 503 with no send_state');
  assert(normalized.error_record.operator_action === 'MONITOR_RETRY', `expected MONITOR_RETRY, got ${normalized.error_record.operator_action}`);

  const redacted = ec.redactErrorRecord(normalized);
  const text = JSON.stringify(redacted.error_record);
  assert(!text.includes('super-secret-token'), 'redacted error record must not contain the Authorization token');
  assert(!text.includes('sk-test-123456789'), 'redacted error record must not contain the apiKey value');
  assert(!text.includes('x'.repeat(400)), 'redacted error record must not contain the full long raw response body');
});

test('error-send-uncertain-never-retried', 'SEND_UNCERTAIN error records are never marked retryable, regardless of http_status', () => {
  const event = { send_state: 'SEND_UNCERTAIN', http_status: 503, workflow_name: 'wf', failed_node: 'node' };
  const normalized = ec.normalizeErrorEvent(event);
  assert(normalized.error_record.error_class === 'SEND_UNCERTAIN', `expected SEND_UNCERTAIN class even with http_status=503, got ${normalized.error_record.error_class}`);
  assert(normalized.error_record.retryable === false, 'SEND_UNCERTAIN must never be retryable');
  assert(normalized.error_record.operator_action === 'MANUAL_RECONCILIATION_REQUIRED', `expected MANUAL_RECONCILIATION_REQUIRED, got ${normalized.error_record.operator_action}`);
});

test('error-placeholder-notification-only', 'The error handler produces only a placeholder notification', () => {
  const event = { send_state: 'SEND_UNCERTAIN', http_status: 200, workflow_name: 'HMZ - Instantly Reply Sender - Validation', failed_node: 'K. Transition' };
  const result = ec.buildPlaceholderNotification(ec.redactErrorRecord(ec.normalizeErrorEvent(event)));
  assert(result.notification.surface === 'PLACEHOLDER_NOT_CONFIGURED', 'notification.surface must be PLACEHOLDER_NOT_CONFIGURED');
  assert(result.notification.delivered === false, 'notification.delivered must be false');
});

test('error-id-attached-from-sidecar', 'attachErrorId() merges the sidecar errorId onto the item, and writeErrorRecord round-trips', () => {
  const event = { workflow_name: 'wf', failed_node: 'node', http_status: 500 };
  const normalized = ec.redactErrorRecord(ec.normalizeErrorEvent(event));

  const written = store.writeErrorRecord(tmpStateDir, normalized.error_record);
  assert(/^[0-9a-f]{16}$/.test(written.errorId), `errorId should be 16 hex chars, got ${written.errorId}`);

  const merged = ec.attachErrorId(normalized, { errorId: written.errorId });
  assert(merged.persisted_error.errorId === written.errorId, 'persisted_error.errorId should match the written record');

  const reread = store.readErrorRecord(tmpStateDir, written.errorId);
  assert(reread.errorId === written.errorId, 'readErrorRecord should round-trip the stored record');
});

// --- docker compose --------------------------------------------------------

test('compose-no-host-port-for-sidecar', 'docker-compose.yml does not publish a host port for hmz-send-state', () => {
  const text = fs.readFileSync(COMPOSE_PATH, 'utf8');
  const lines = text.split(/\r?\n/);
  const startIdx = lines.findIndex((line) => /^\s{2}hmz-send-state:\s*$/.test(line));
  assert(startIdx !== -1, 'hmz-send-state service not found in docker-compose.yml');

  let endIdx = lines.length;
  for (let i = startIdx + 1; i < lines.length; i++) {
    if (/^\S/.test(lines[i]) || /^\s{2}\S/.test(lines[i])) {
      endIdx = i;
      break;
    }
  }

  const serviceBlock = lines.slice(startIdx, endIdx).join('\n');
  assert(!/\bports:/.test(serviceBlock), 'hmz-send-state service block must not contain a ports: key');
});

test('compose-sidecar-volume-named', 'hmz_send_state_data is declared as a named volume', () => {
  const text = fs.readFileSync(COMPOSE_PATH, 'utf8');
  assert(text.includes('hmz_send_state_data:'), 'hmz_send_state_data volume not declared');
  assert(text.includes('name: hmz_send_state_data'), 'hmz_send_state_data volume should have an explicit name');
});

// ---------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------
function main() {
  const results = [];
  let passed = 0;
  let failed = 0;

  for (const { id, description, run } of tests) {
    try {
      run();
      results.push({ id, description, status: 'pass' });
      passed += 1;
    } catch (error) {
      results.push({ id, description, status: 'fail', error: error?.message || String(error) });
      failed += 1;
    }
  }

  if (tmpStateDir) {
    fs.rmSync(tmpStateDir, { recursive: true, force: true });
  }

  const summary = {
    generatedAt: new Date().toISOString(),
    nodeVersion: process.version,
    total: tests.length,
    passed,
    failed,
    results,
  };

  fs.writeFileSync(RESULTS_PATH, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');

  for (const result of results) {
    const marker = result.status === 'pass' ? 'PASS' : 'FAIL';
    console.log(`[${marker}] ${result.id} - ${result.description}${result.error ? ` :: ${result.error}` : ''}`);
  }
  console.log(`\n${passed}/${tests.length} passed, ${failed} failed`);

  if (failed > 0) process.exitCode = 1;
}

main();
