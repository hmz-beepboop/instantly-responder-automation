// Phase 4B offline test suite.
//
// Runs entirely offline: no network access beyond an in-process,
// ephemeral-port instance of the hmz-send-state sidecar started directly
// from infrastructure/send-state/server.mjs (127.0.0.1 only, never
// published). No Docker, no n8n, no Instantly. Exercises watchdog-core.mjs /
// harness-core.mjs / sender-core.mjs / error-core.mjs / state-store.mjs
// directly, and performs static safety checks on the generated workflow JSON
// and the compose file.
//
// Usage: node verification/phase4b/run-offline-tests.mjs

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as sc from '../phase4a/sender-core.mjs';
import * as ec from '../phase4a/error-core.mjs';
import * as wc from './watchdog-core.mjs';
import * as hc from './harness-core.mjs';
import * as store from '../../infrastructure/send-state/state-store.mjs';
import { createSendStateServer } from '../../infrastructure/send-state/server.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const WORKFLOWS_DIR = path.join(PROJECT_ROOT, 'workflows');
const FIXTURES_DIR = path.join(PROJECT_ROOT, 'fixtures', 'phase_4');
const RESULTS_PATH = path.join(SCRIPT_DIR, 'offline-test-results.json');
const COMPOSE_PATH = path.join(PROJECT_ROOT, 'infrastructure', 'local-n8n', 'docker-compose.yml');

const WATCHDOG_WF_PATH = path.join(WORKFLOWS_DIR, '05_reply_sla_watchdog_validation.json');
const HARNESS_WF_PATH = path.join(WORKFLOWS_DIR, '06_reply_full_test_harness_validation.json');

function loadAllFixtures() {
  const files = ['intake_fixtures.json', 'sender_fixtures.json', 'failure_fixtures.json', 'monitoring_fixtures.json'];
  const all = [];
  for (const file of files) {
    all.push(...JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, file), 'utf8')));
  }
  return all;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
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

let watchdogWorkflow;
let harnessWorkflow;
let allFixtures;

// --- fixture matrix (run first for clear diffs) -------------------------

test('fixtures-matrix-complete', 'The Phase 4 fixture matrix has exactly 60 synthetic fixtures across the required groups', () => {
  allFixtures = loadAllFixtures();
  assert(allFixtures.length === 60, `expected 60 fixtures, got ${allFixtures.length}`);
  assert(allFixtures.every((f) => f.synthetic === true), 'every fixture must be synthetic: true');
  const counts = {
    intake: allFixtures.filter((f) => f.group === 'intake').length,
    sender: allFixtures.filter((f) => f.group === 'sender').length,
    failure: allFixtures.filter((f) => f.group === 'failure').length,
    monitoring: allFixtures.filter((f) => f.group === 'monitoring').length,
  };
  assert(counts.intake === 23, `expected 23 intake fixtures, got ${counts.intake}`);
  assert(counts.sender === 10, `expected 10 sender fixtures, got ${counts.sender}`);
  assert(counts.failure === 19, `expected 19 failure fixtures, got ${counts.failure}`);
  assert(counts.monitoring === 8, `expected 8 monitoring fixtures, got ${counts.monitoring}`);
});

test('harness-core-fixture-matrix-all-pass', 'runFixtureMatrix() passes every fixture against the deterministic core modules', () => {
  const deps = { sc, ec, wc };
  const result = hc.runFixtureMatrix(allFixtures, deps);
  assert(result.total === 60, `expected total=60, got ${result.total}`);
  if (result.failed > 0) {
    const failures = result.results.filter((r) => !r.passed);
    throw new Error(`${result.failed} fixture(s) failed: ${JSON.stringify(failures)}`);
  }
  assert(result.overall_result === 'PASS', `expected overall_result=PASS, got ${result.overall_result}`);
});

// --- workflow JSON structural / safety tests -----------------------------

test('wf-json-parses', 'Both generated workflow files parse as valid JSON', () => {
  watchdogWorkflow = JSON.parse(fs.readFileSync(WATCHDOG_WF_PATH, 'utf8'));
  harnessWorkflow = JSON.parse(fs.readFileSync(HARNESS_WF_PATH, 'utf8'));
});

test('wf-names', 'Workflows have the required names', () => {
  assert(watchdogWorkflow.name === 'HMZ - Reply SLA Watchdog - Validation', 'watchdog workflow name mismatch');
  assert(harnessWorkflow.name === 'HMZ - Reply Full Test Harness - Validation', 'harness workflow name mismatch');
});

test('wf-inactive', 'Both workflows are inactive', () => {
  assert(watchdogWorkflow.active === false, 'watchdog workflow must be active:false');
  assert(harnessWorkflow.active === false, 'harness workflow must be active:false');
});

test('wf-no-credentials', 'No node in either workflow has a credentials object', () => {
  for (const [label, wf] of [['watchdog', watchdogWorkflow], ['harness', harnessWorkflow]]) {
    for (const node of wf.nodes) {
      assert(!('credentials' in node), `${label} workflow node "${node.name}" has a credentials object`);
    }
  }
});

const SECRET_LIKE_PATTERN =
  /(sk-[A-Za-z0-9]{10,}|AKIA[A-Z0-9]{12,}|xox[baprs]-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{20,}|"Authorization"\s*:\s*"(?!<REDACTED>)[^"\s]{5,}")/;

test('wf-no-secret-values', 'Neither workflow JSON contains secret-like literal values', () => {
  for (const [label, wfPath] of [['watchdog', WATCHDOG_WF_PATH], ['harness', HARNESS_WF_PATH]]) {
    const text = fs.readFileSync(wfPath, 'utf8');
    assert(!SECRET_LIKE_PATTERN.test(text), `${label} workflow contains a secret-like literal value`);
  }
});

test('wf-no-live-external-request', 'Every httpRequest node targets only the internal hmz-send-state sidecar', () => {
  for (const [label, wf] of [['watchdog', watchdogWorkflow], ['harness', harnessWorkflow]]) {
    for (const node of wf.nodes) {
      if (node.type !== 'n8n-nodes-base.httpRequest') continue;
      const url = node.parameters && node.parameters.url;
      assert(typeof url === 'string', `${label} workflow node "${node.name}" httpRequest has no url`);
      const isSidecar = url.startsWith('http://hmz-send-state:5681');
      const isGatedGoogleChat = url === '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}';
      assert(isSidecar || isGatedGoogleChat, `${label} workflow node "${node.name}" url is neither the internal sidecar nor the gated Google Chat env var: ${url}`);
      assert(!url.includes('instantly.ai'), `${label} workflow node "${node.name}" url references instantly.ai`);
    }
  }
});

test('wf-no-real-notification-service', 'Neither workflow references a real notification surface; placeholder only', () => {
  for (const [label, wf] of [['watchdog', watchdogWorkflow], ['harness', harnessWorkflow]]) {
    for (const node of wf.nodes) {
      if (node.type === 'n8n-nodes-base.stickyNote') continue;
      const text = JSON.stringify(node).toLowerCase();
      for (const forbidden of ['slack', 'sendgrid', 'smtp', 'sheets.googleapis', 'mailgun', 'twilio']) {
        assert(!text.includes(forbidden), `${label} workflow node "${node.name}" unexpectedly references "${forbidden}"`);
      }
    }
  }
  const watchdogCode = watchdogWorkflow.nodes.filter((n) => n.type === 'n8n-nodes-base.code').map((n) => n.parameters.jsCode).join('\n');
  assert(watchdogCode.includes("surface: 'PLACEHOLDER_NOT_CONFIGURED'"), 'watchdog code must build a PLACEHOLDER_NOT_CONFIGURED notification');
  assert(watchdogCode.includes('delivered: false'), 'watchdog notification must never be delivered');
});

test('wf-hardcoded-validation-mode', 'Both workflows hardcode validation_mode/synthetic in generated Code nodes', () => {
  const watchdogCode = watchdogWorkflow.nodes.filter((n) => n.type === 'n8n-nodes-base.code').map((n) => n.parameters.jsCode).join('\n');
  assert(watchdogCode.includes('validation_mode: true'), 'watchdog code must hardcode validation_mode: true');

  const harnessCode = harnessWorkflow.nodes.filter((n) => n.type === 'n8n-nodes-base.code').map((n) => n.parameters.jsCode).join('\n');
  assert(harnessCode.includes("validation_mode: true, harness_result"), 'harness code must hardcode validation_mode: true');
  assert(harnessCode.includes("synthetic: true, validation_mode"), 'harness code must hardcode synthetic: true');
});


test('wf-code-validator-return-shape-compatible', 'Generated Code nodes contain no helper-level bare return-object pattern that n8n misclassifies as node output', () => {
  for (const workflow of [watchdogWorkflow, harnessWorkflow]) {
    for (const node of workflow.nodes.filter((candidate) => candidate.type === 'n8n-nodes-base.code')) {
      assert(!/\breturn\s*\{/.test(node.parameters.jsCode),
        `${workflow.name} / ${node.name} contains a bare return-object pattern`);
    }
  }
});

test('wf-generated-code-compiles', 'Every generated Code node compiles as standalone n8n JavaScript', () => {
  for (const workflow of [watchdogWorkflow, harnessWorkflow]) {
    for (const node of workflow.nodes.filter((candidate) => candidate.type === 'n8n-nodes-base.code')) {
      try {
        new Function('$input', '$', node.parameters.jsCode);
      } catch (error) {
        throw new Error(`${workflow.name} / ${node.name} failed to compile: ${error.message}`);
      }
    }
  }
});


test('wf-no-continue-on-error', 'Phase 4B workflows stop on Code/HTTP failures instead of producing successful-looking output', () => {
  for (const [label, workflow] of [['watchdog', watchdogWorkflow], ['harness', harnessWorkflow]]) {
    for (const node of workflow.nodes.filter((candidate) =>
      candidate.type === 'n8n-nodes-base.code' || candidate.type === 'n8n-nodes-base.httpRequest')) {
      assert(node.onError !== 'continueRegularOutput' && node.onError !== 'continueErrorOutput',
        `${label} workflow node "${node.name}" must not continue after a failure`);
    }
  }
});

test('watchdog-rejects-malformed-sidecar-responses', 'Watchdog merge helpers reject malformed sidecar responses instead of silently treating them as empty/successful', () => {
  let unfinishedRejected = false;
  try {
    wc.mergeUnfinishedResponse({}, { error: 'sidecar_unavailable' });
  } catch (error) {
    unfinishedRejected = error.message === 'invalid_unfinished_response';
  }
  assert(unfinishedRejected, 'malformed unfinished response must be rejected');

  let dedupeRejected = false;
  try {
    wc.mergeAlertDedupeResults({ alert_candidates: [{ alert_key: 'x' }] }, { error: 'sidecar_unavailable' });
  } catch (error) {
    dedupeRejected = error.message === 'invalid_alert_dedupe_response';
  }
  assert(dedupeRejected, 'malformed dedupe response must be rejected');

  let persistRejected = false;
  try {
    wc.attachPhase4bResultId({}, { error: 'sidecar_unavailable' });
  } catch (error) {
    persistRejected = error.message === 'invalid_phase4b_persist_response';
  }
  assert(persistRejected, 'malformed persist response must be rejected');
});

// --- SLA Watchdog generated-code runtime smoke ---------------------------

test('wf05-generated-runtime-smoke', 'Generated SLA Watchdog Code nodes evaluate a synthetic warning record end to end', () => {
  const triggerInput = [{ json: { synthetic: true, test_overrides: { now: '2026-06-14T12:00:00.000Z' } } }];
  const captured = executeGeneratedCodeNode(watchdogWorkflow, 'A. Capture Trigger Input', triggerInput);

  const unfinishedResponse = [
    {
      json: {
        sends: [{
          sendKey: 'f'.repeat(64),
          state: 'SUBMITTING',
          createdAt: '2026-06-14T11:57:00.000Z',
          updatedAt: '2026-06-14T11:59:30.000Z',
          details: {},
        }],
        errors: [],
      },
    },
  ];
  const evalInput = executeGeneratedCodeNode(watchdogWorkflow, 'C. Build Evaluation Input', unfinishedResponse, {
    'A. Capture Trigger Input': captured,
  });
  assert(evalInput[0].json.unfinished.sends.length === 1, 'expected one unfinished send merged onto the item');
  assert(evalInput[0].json.test_overrides.now === '2026-06-14T12:00:00.000Z', 'test_overrides.now should be preserved from the trigger');

  const evaluated = executeGeneratedCodeNode(watchdogWorkflow, 'D. Evaluate Unfinished Records', evalInput);
  const record = evaluated[0].json.watchdog_evaluation.records[0];
  assert(record.category === 'API_RETRY', `expected category API_RETRY, got ${record.category}`);
  assert(record.sloType === 'PROCESSING', `expected sloType PROCESSING, got ${record.sloType}`);
  assert(record.status === 'WARNING', `expected status WARNING at age 180, got ${record.status}`);

  const alerts = executeGeneratedCodeNode(watchdogWorkflow, 'E. Build Alert Records', evaluated);
  assert(alerts[0].json.alert_candidates.length === 1, 'expected one alert candidate');

  const dedupeResponse = [{ json: { results: [{ deduped: false, firstSeenAt: '2026-06-14T12:00:00.000Z' }] } }];
  const merged = executeGeneratedCodeNode(watchdogWorkflow, 'G. Merge Alert Dedupe Results', dedupeResponse, {
    'E. Build Alert Records': alerts,
  });
  assert(merged[0].json.notification.alert_count === 1, 'expected alert_count=1');
  assert(merged[0].json.notification.deduped_count === 0, 'expected deduped_count=0');

  const result = executeGeneratedCodeNode(watchdogWorkflow, 'H. Build Watchdog Result', merged);
  assert(result[0].json.watchdog_result.validation_mode === true, 'watchdog_result.validation_mode must be true');
  assert(result[0].json.watchdog_result.notification.surface === 'NOT_CONFIGURED', 'notification surface must be NOT_CONFIGURED when google_chat_configured is false');
  assert(result[0].json.watchdog_result.processing_slo.warnings === 1, 'expected processing_slo.warnings=1');
  assert(result[0].json.watchdog_result.transmission_slo.warnings === 0, 'expected transmission_slo.warnings=0');

  const persistResponse = [{ json: { resultId: '0123456789abcdef' } }];
  const attached = executeGeneratedCodeNode(watchdogWorkflow, 'J. Attach Result ID', persistResponse, {
    'H. Build Watchdog Result': result,
  });
  assert(attached[0].json.phase4b_result_id === '0123456789abcdef', 'expected phase4b_result_id to be attached');
});

// --- Full Test Harness generated-code runtime smoke ----------------------

test('wf06-generated-runtime-smoke', 'Generated Full Test Harness Code node runs the embedded fixture matrix end to end', () => {
  const ran = executeGeneratedCodeNode(harnessWorkflow, 'A. Run Fixture Matrix', [{ json: {} }]);
  assert(ran[0].json.synthetic === true, 'harness output must be synthetic: true');
  assert(ran[0].json.validation_mode === true, 'harness output must be validation_mode: true');

  const result = ran[0].json.harness_result;
  assert(result.total === 60, `expected harness_result.total=60, got ${result.total}`);
  assert(result.failed === 0, `expected harness_result.failed=0, got ${result.failed}: ${JSON.stringify(result.results.filter((r) => !r.passed))}`);
  assert(result.overall_result === 'PASS', `expected overall_result=PASS, got ${result.overall_result}`);

  const persistResponse = [{ json: { resultId: 'fedcba9876543210' } }];
  const attached = executeGeneratedCodeNode(harnessWorkflow, 'C. Attach Result ID', persistResponse, {
    'A. Run Fixture Matrix': ran,
  });
  assert(attached[0].json.phase4b_result_id === 'fedcba9876543210', 'expected phase4b_result_id to be attached');
});

// --- watchdog-core unit tests ---------------------------------------------

test('watchdog-classify-send-record-categories', 'classifySendRecord() maps every non-terminal send state to the right watchdog category', () => {
  assert(wc.classifySendRecord({ state: 'LOCKED' }) === 'AI_CLASSIFICATION_WAIT', 'LOCKED should map to AI_CLASSIFICATION_WAIT');
  assert(wc.classifySendRecord({ state: 'SUBMITTING' }) === 'API_RETRY', 'SUBMITTING should map to API_RETRY');
  assert(wc.classifySendRecord({ state: 'SENT' }) === 'SEND_UNCERTAIN', 'SENT should map to SEND_UNCERTAIN');
  assert(wc.classifySendRecord({ state: 'SEND_UNCERTAIN' }) === 'SEND_UNCERTAIN', 'SEND_UNCERTAIN should map to SEND_UNCERTAIN');
  assert(wc.classifySendRecord({ state: 'WAT' }) === 'UNKNOWN_STATE', 'unknown states should map to UNKNOWN_STATE');
});

test('watchdog-classify-error-record-categories', 'classifyErrorRecord() maps error records to the right watchdog category', () => {
  assert(wc.classifyErrorRecord({ error_class: 'SEND_UNCERTAIN' }) === 'SEND_UNCERTAIN', 'SEND_UNCERTAIN error_class should map to SEND_UNCERTAIN');
  assert(wc.classifyErrorRecord({ error_class: 'RETRYABLE' }) === 'API_RETRY', 'RETRYABLE error_class should map to API_RETRY');
  assert(wc.classifyErrorRecord({ error_class: 'PERMANENT_FAILURE' }) === 'SEND_FAILURE', 'PERMANENT_FAILURE should map to SEND_FAILURE');
  assert(wc.classifyErrorRecord({ error_class: 'UNKNOWN', reason: 'suppression_verification_failed' }) === 'SUPPRESSION_FAILURE', 'suppression_verification_failed reason should map to SUPPRESSION_FAILURE');
  assert(wc.classifyErrorRecord({ error_class: 'UNKNOWN', operator_action: 'MANUAL_REVIEW', reason: 'needs_human_judgement' }) === 'HUMAN_REVIEW', 'UNKNOWN + MANUAL_REVIEW + reason should map to HUMAN_REVIEW');
  assert(wc.classifyErrorRecord({ error_class: 'UNKNOWN' }) === 'UNKNOWN_STATE', 'bare UNKNOWN with no reason should map to UNKNOWN_STATE');
});

test('watchdog-sla-thresholds-boundary', 'statusForAge() applies the 180s warning / 300s breach thresholds at their exact boundaries', () => {
  assert(wc.statusForAge(179) === 'OK', '179s should be OK');
  assert(wc.statusForAge(180) === 'WARNING', '180s should be WARNING');
  assert(wc.statusForAge(299) === 'WARNING', '299s should be WARNING');
  assert(wc.statusForAge(300) === 'BREACH', '300s should be BREACH');
});

test('watchdog-transmission-slo-only-send-uncertain', 'Only SEND_UNCERTAIN belongs to the Transmission SLO; everything else (including HUMAN_REVIEW) is Processing', () => {
  assert(wc.sloTypeForCategory('SEND_UNCERTAIN') === 'TRANSMISSION', 'SEND_UNCERTAIN must be TRANSMISSION');
  for (const category of Object.values(wc.WATCHDOG_CATEGORIES)) {
    if (category === 'SEND_UNCERTAIN') continue;
    assert(wc.sloTypeForCategory(category) === 'PROCESSING', `${category} must be PROCESSING`);
  }
});


test('watchdog-processing-age-does-not-reset-on-transition', 'Processing SLO age uses durable createdAt rather than the latest transition time', () => {
  const evaluated = wc.evaluateUnfinishedRecords({
    test_overrides: { now: '2026-06-14T12:00:00.000Z' },
    unfinished: {
      sends: [{
        sendKey: 'e'.repeat(64),
        state: 'LOCKED',
        createdAt: '2026-06-14T11:54:00.000Z',
        updatedAt: '2026-06-14T11:59:50.000Z',
        details: {},
      }],
      errors: [],
    },
  }).watchdog_evaluation;
  assert(evaluated.records[0].ageSeconds === 360,
    `expected durable age 360 seconds, got ${evaluated.records[0].ageSeconds}`);
  assert(evaluated.records[0].status === 'BREACH', 'createdAt-based age should produce BREACH');
});

test('watchdog-alert-key-stable-and-sanitised', 'buildAlertKey() is stable and contains no message bodies or raw email addresses', () => {
  const record = { sloType: 'PROCESSING', category: 'API_RETRY', kind: 'send', identifier: 'a'.repeat(64), status: 'WARNING' };
  const key1 = wc.buildAlertKey(record);
  const key2 = wc.buildAlertKey({ ...record });
  assert(key1 === key2, 'buildAlertKey should be deterministic for the same record');
  assert(!key1.includes('@'), 'alert key must not contain an email address');
});

// --- sidecar Phase 4A regression + Phase 4B extensions --------------------

let tmpStateDir;

test('sidecar-phase4a-regression-acquire-and-lock', 'Phase 4A acquire/lock/forward-only state machine still works unchanged', () => {
  tmpStateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-send-state-4b-test-'));
  const identity = { inboundEmailId: 'i-1', sender: 'a@example.com', recipient: 'b@example.com', policyTemplateId: 'tpl-1' };
  const first = store.acquireSend(tmpStateDir, identity);
  assert(first.acquired === true, 'first acquisition should succeed');
  const second = store.acquireSend(tmpStateDir, identity);
  assert(second.acquired === false && second.reason === 'LOCK_ALREADY_HELD', 'concurrent acquisition should be blocked');

  const transition = store.transitionSend(tmpStateDir, first.sendKey, 'SUBMITTING', {});
  assert(transition.ok === true, 'LOCKED -> SUBMITTING should be allowed');
});


test('sidecar-created-at-persists-and-details-merge', 'Send state preserves createdAt and prior safe details across transitions', () => {
  const identity = { inboundEmailId: 'created-1', sender: 'created@example.com', recipient: 'recipient@example.com', policyTemplateId: 'tpl-created' };
  const acquired = store.acquireSend(tmpStateDir, identity);
  assert(acquired.acquired === true, 'createdAt test acquisition should succeed');
  const before = store.readState(tmpStateDir, acquired.sendKey);
  store.transitionSend(tmpStateDir, acquired.sendKey, 'SUBMITTING', { submissionStartedAt: '2026-06-14T12:00:00.000Z' });
  const after = store.readState(tmpStateDir, acquired.sendKey);
  assert(after.createdAt === before.createdAt, 'createdAt must survive transition');
  assert(after.details.submissionStartedAt === '2026-06-14T12:00:00.000Z', 'transition detail should be retained');
  assert(typeof after.details.senderHash === 'string', 'prior hashed identity details should be retained');
});

test('sidecar-redacts-content-and-raw-email-values', 'Sidecar sanitisation blocks raw bodies, subjects, and email addresses in arbitrary records', () => {
  const record = store.writeErrorRecord(tmpStateDir, {
    workflow_name: 'wf-safe',
    email: 'person@example.com',
    subject: 'Sensitive subject',
    body: 'Sensitive message body',
    nested: { recipient: 'other@example.com', reply_text: 'Sensitive reply' },
  });
  const text = JSON.stringify(record);
  assert(!text.includes('person@example.com') && !text.includes('other@example.com'), 'raw email must not survive sanitisation');
  assert(!text.includes('Sensitive subject') && !text.includes('Sensitive message body') && !text.includes('Sensitive reply'),
    'raw content must not survive sanitisation');
});

test('sidecar-unfinished-listing-excludes-terminal', 'listUnfinishedSends() returns only non-terminal records (LOCKED/SUBMITTING/SENT/SEND_UNCERTAIN)', () => {
  const identity2 = { inboundEmailId: 'i-2', sender: 'c@example.com', recipient: 'd@example.com', policyTemplateId: 'tpl-2' };
  const acquired2 = store.acquireSend(tmpStateDir, identity2);
  assert(acquired2.acquired === true, 'second acquisition should succeed');
  store.transitionSend(tmpStateDir, acquired2.sendKey, 'DRY_RUN_OK', {});

  const unfinished = store.listUnfinishedSends(tmpStateDir);
  const states = unfinished.map((r) => r.state);
  assert(states.includes('SUBMITTING'), 'SUBMITTING record (from the prior test) should be unfinished');
  assert(!states.includes('DRY_RUN_OK'), 'DRY_RUN_OK is terminal and must be excluded from unfinished');
});

test('sidecar-resolved-error-record-excluded', 'A resolved error record is excluded from listUnresolvedErrors()', () => {
  const a = store.writeErrorRecord(tmpStateDir, { workflow_name: 'wf-a', failed_node: 'node-a', http_status: 500 });
  const b = store.writeErrorRecord(tmpStateDir, { workflow_name: 'wf-b', failed_node: 'node-b', http_status: 503 });

  const before = store.listUnresolvedErrors(tmpStateDir).map((r) => r.errorId);
  assert(before.includes(a.errorId) && before.includes(b.errorId), 'both new error records should be unresolved initially');

  const resolved = store.resolveErrorRecord(tmpStateDir, a.errorId);
  assert(resolved.resolved === true, 'resolveErrorRecord should mark the record resolved');

  const after = store.listUnresolvedErrors(tmpStateDir).map((r) => r.errorId);
  assert(!after.includes(a.errorId), 'resolved record must be excluded from listUnresolvedErrors');
  assert(after.includes(b.errorId), 'unresolved record must remain listed');
});

test('sidecar-alert-dedupe-atomic', 'recordAlertOnce() records an alertKey at most once (atomic open(\'wx\'))', () => {
  const alertKey = 'WATCHDOG_ALERT|PROCESSING|API_RETRY|send|' + 'a'.repeat(64) + '|BREACH';
  const first = store.recordAlertOnce(tmpStateDir, alertKey, { note: 'first' });
  assert(first.deduped === false, 'first recording should not be deduped');

  const second = store.recordAlertOnce(tmpStateDir, alertKey, { note: 'second' });
  assert(second.deduped === true, 'repeated recording of the same alertKey should be deduped');
  assert(second.firstSeenAt === first.firstSeenAt, 'deduped result should report the original firstSeenAt');
});

test('sidecar-phase4b-result-roundtrip', 'writePhase4bResult()/readPhase4bResult() round-trip a sanitised result with a 16-hex resultId', () => {
  const written = store.writePhase4bResult(tmpStateDir, { schema_version: '1.0', synthetic: true, total: 60, passed: 60, failed: 0, overall_result: 'PASS' });
  assert(/^[0-9a-f]{16}$/.test(written.resultId), `resultId should be 16 hex chars, got ${written.resultId}`);

  const reread = store.readPhase4bResult(tmpStateDir, written.resultId);
  assert(reread.resultId === written.resultId, 'readPhase4bResult should round-trip the stored record');
  assert(reread.overall_result === 'PASS', 'round-tripped record should preserve overall_result');
});

// --- in-process sidecar HTTP server (ephemeral, 127.0.0.1 only) -----------

test('server-http-endpoints-end-to-end', 'hmz-send-state HTTP endpoints (Phase 4A + Phase 4B) work end to end on an ephemeral local port', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-send-state-4b-http-'));
  const server = createSendStateServer(dir);
  try {
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    const base = `http://127.0.0.1:${port}`;

    const health = await (await fetch(`${base}/health`)).json();
    assert(health.status === 'ok', 'GET /health should report ok');

    const acquire = await (await fetch(`${base}/v1/send/acquire`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ inboundEmailId: 'http-1', sender: 'x@example.com', recipient: 'y@example.com', policyTemplateId: 'tpl-http' }),
    })).json();
    assert(acquire.acquired === true, 'POST /v1/send/acquire should succeed for a new identity');

    const unfinishedBefore = await (await fetch(`${base}/v1/unfinished`)).json();
    assert(unfinishedBefore.sends.some((s) => s.sendKey === acquire.sendKey), 'GET /v1/unfinished should list the newly-acquired LOCKED send');

    const errorPost = await (await fetch(`${base}/v1/error`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ workflow_name: 'wf-http', failed_node: 'node-http', http_status: 503, Authorization: 'Bearer must-not-survive' }),
    })).json();
    assert(/^[0-9a-f]{16}$/.test(errorPost.errorId), 'POST /v1/error should return a 16-hex errorId');

    const errorGet = await (await fetch(`${base}/v1/error/${errorPost.errorId}`)).json();
    assert(JSON.stringify(errorGet).includes('must-not-survive') === false, 'stored error record must not contain a raw Authorization value');

    const resolved = await (await fetch(`${base}/v1/error/${errorPost.errorId}/resolve`, { method: 'POST' })).json();
    assert(resolved.resolved === true, 'POST /v1/error/:id/resolve should mark the record resolved');

    const unfinishedAfter = await (await fetch(`${base}/v1/unfinished`)).json();
    assert(!unfinishedAfter.errors.some((e) => e.errorId === errorPost.errorId), 'resolved error must be excluded from GET /v1/unfinished');

    const dedupe1 = await (await fetch(`${base}/v1/alert/dedupe`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ alertKey: 'WATCHDOG_ALERT|PROCESSING|API_RETRY|send|' + 'b'.repeat(64) + '|WARNING' }),
    })).json();
    assert(dedupe1.results[0].deduped === false, 'first /v1/alert/dedupe call should not be deduped');

    const dedupe2 = await (await fetch(`${base}/v1/alert/dedupe`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ alertKey: 'WATCHDOG_ALERT|PROCESSING|API_RETRY|send|' + 'b'.repeat(64) + '|WARNING' }),
    })).json();
    assert(dedupe2.results[0].deduped === true, 'repeated /v1/alert/dedupe call should be deduped');

    const resultPost = await (await fetch(`${base}/v1/phase4b/result`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ schema_version: '1.0', synthetic: true, overall_result: 'PASS' }),
    })).json();
    assert(/^[0-9a-f]{16}$/.test(resultPost.resultId), 'POST /v1/phase4b/result should return a 16-hex resultId');

    const resultGet = await (await fetch(`${base}/v1/phase4b/result/${resultPost.resultId}`)).json();
    assert(resultGet.found === true && resultGet.overall_result === 'PASS', 'GET /v1/phase4b/result/:id should round-trip the stored record');
  } finally {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

// --- docker compose (regression) -------------------------------------------

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

// ---------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------
async function main() {
  const results = [];
  let passed = 0;
  let failed = 0;

  for (const { id, description, run } of tests) {
    try {
      await run();
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
