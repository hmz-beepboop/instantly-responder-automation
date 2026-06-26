// Phase 4B workflow builder.
//
// Deterministically generates the two Phase 4B workflow JSON exports from
// compact node definitions plus Code-node source embedded directly from
// verification/phase4a/sender-core.mjs, verification/phase4a/error-core.mjs,
// verification/phase4b/watchdog-core.mjs and verification/phase4b/harness-core.mjs
// (via Function.prototype.toString()), plus the fixtures/phase_4 fixture
// matrix embedded as a JSON literal. No hand-maintained giant JSON blobs.
//
// Usage: node verification/phase4b/build-workflows.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as sc from '../phase4a/sender-core.mjs';
import * as ec from '../phase4a/error-core.mjs';
import * as wc from './watchdog-core.mjs';
import * as hc from './harness-core.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const WORKFLOWS_DIR = path.join(PROJECT_ROOT, 'workflows');
const FIXTURES_DIR = path.join(PROJECT_ROOT, 'fixtures', 'phase_4');

// ---------------------------------------------------------------------
// Shared preambles: constants + helper functions embedded into every
// generated Code node that needs them. Built mechanically from the
// exported names of each core module - never hand-duplicated.
// ---------------------------------------------------------------------
const SENDER_CONST_NAMES = [
  'SENDER_CONFIG',
  'SEND_RESULT_STATES',
  'MAX_SEND_ATTEMPTS',
  'BASE_BACKOFF_MS',
  'MAX_BACKOFF_MS',
  'RETRY_AFTER_CAP_MS',
  'RECONCILE_STATES',
];
const SENDER_FN_NAMES = [
  'normalizeEmail',
  'djb2Hash',
  'deriveSendKey',
  'isValidSentContract',
  'deterministicJitter',
  'validateSenderInput',
  'runSendGates',
  'buildGateRejectionTerminal',
  'computeSendKey',
  'normalizeAcquisitionResult',
  'buildBlockedDuplicateTerminal',
  'mockSuppressionAdapter',
  'verifySuppressionResults',
  'buildSuppressionEscalationTerminal',
  'buildDryRunTerminal',
  'classifySendOutcome',
  'planSendAttempts',
  'reconcileMatches',
];

const ERROR_CONST_NAMES = ['REDACT_KEY_PATTERN', 'MAX_STRING_LENGTH', 'RETRYABLE_HTTP_STATUSES', 'OPERATOR_ACTION_BY_CLASS'];
const ERROR_FN_NAMES = [
  'redactValue',
  'classifyErrorClass',
  'deriveRetryable',
  'deriveOperatorAction',
  'normalizeErrorEvent',
  'redactErrorRecord',
  'buildPlaceholderNotification',
  'attachErrorId',
];

const WATCHDOG_CONST_NAMES = [
  'SEND_STATE_BASE_URL',
  'SLA_WARNING_THRESHOLD_SECONDS',
  'SLA_BREACH_THRESHOLD_SECONDS',
  'WATCHDOG_CATEGORIES',
  'TRANSMISSION_CATEGORIES',
  'SLO_TYPES',
  'SLA_STATUSES',
  'SEND_FAILURE_STATES',
];
const WATCHDOG_FN_NAMES = [
  'classifySendRecord',
  'classifyErrorRecord',
  'sloTypeForCategory',
  'timestampForSendRecord',
  'ageSeconds',
  'statusForAge',
  'evaluateUnfinishedRecords',
  'buildAlertKey',
  'buildAlertRecords',
  'mergeAlertDedupeResults',
  'buildWatchdogResult',
  'mergeUnfinishedResponse',
  'attachPhase4bResultId',
];

const HARNESS_CONST_NAMES = [
  'CATEGORY_ACTION_DEFAULTS',
  'RULES_HARD_SAFETY',
  'RULES_BOUNCE_OOO',
  'RULES_PRICE_ATTACH',
  'RULES_STRONG',
  'RE_NOT_INTERESTED',
  'RE_TIMING',
  'RE_INFO_REQUEST',
  'RE_POSITIVE_CLEAR',
  'RE_POSITIVE_UNCLEAR',
];
const HARNESS_FN_NAMES = ['matchRule', 'classifyIntakeEvent', 'getPath', 'compareExpected', 'runFixture', 'runFixtureMatrix'];

// Serialises a constant to embeddable source, preserving RegExp literals at
// any depth (JSON.stringify alone would turn a RegExp into "{}").
function serializeEmbeddedConstant(value) {
  if (value instanceof RegExp) return value.toString();
  if (Array.isArray(value)) return `[${value.map(serializeEmbeddedConstant).join(', ')}]`;
  if (value !== null && typeof value === 'object') {
    const entries = Object.entries(value).map(([key, val]) => `${JSON.stringify(key)}: ${serializeEmbeddedConstant(val)}`);
    return `{${entries.join(', ')}}`;
  }
  return JSON.stringify(value);
}

function buildPreamble(constNames, fnNames, mod) {
  const constLines = constNames.map((name) => `const ${name} = ${serializeEmbeddedConstant(mod[name])};`);
  const fnLines = fnNames.map((name) => mod[name].toString());
  return [...constLines, ...fnLines].join('\n\n');
}

// Serialises an object whose values are functions (e.g. harness-core's
// CHECKS registry) as an object literal of inline function expressions.
function buildFunctionMapConst(name, obj) {
  const entries = Object.entries(obj).map(([key, fn]) => `  ${JSON.stringify(key)}: ${fn.toString()}`);
  return `const ${name} = {\n${entries.join(',\n')}\n};`;
}

const SENDER_PREAMBLE = buildPreamble(SENDER_CONST_NAMES, SENDER_FN_NAMES, sc);
const ERROR_PREAMBLE = buildPreamble(ERROR_CONST_NAMES, ERROR_FN_NAMES, ec);
const WATCHDOG_PREAMBLE = buildPreamble(WATCHDOG_CONST_NAMES, WATCHDOG_FN_NAMES, wc);
const HARNESS_PREAMBLE = [buildPreamble(HARNESS_CONST_NAMES, HARNESS_FN_NAMES, hc), buildFunctionMapConst('CHECKS', hc.CHECKS)].join('\n\n');

// ---------------------------------------------------------------------
// jsCode generators
// ---------------------------------------------------------------------

// One pure function (item) => item', applied to every input item.
function singleFnCode(preamble, fn) {
  return ['const items = $input.all();', '', preamble, '', fn.toString(), '', `return items.map(item => ({ json: ${fn.name}(item.json || {}) }));`].join('\n');
}

// Two-arg function (priorItem, currentItem) => item', where currentItem is
// this node's own input (e.g. an HTTP Request response) and priorItem is the
// matching item from an earlier named node.
function mergeFnCode(preamble, fn, priorNodeName) {
  return [
    'const items = $input.all();',
    `const priorItems = $('${priorNodeName}').all();`,
    '',
    preamble,
    '',
    fn.toString(),
    '',
    `return items.map((item, idx) => ({ json: ${fn.name}((priorItems[idx] && priorItems[idx].json) || {}, item.json || {}) }));`,
  ].join('\n');
}

// Passthrough used to capture trigger input under a single stable node name,
// regardless of which of two trigger nodes fired.
const PASSTHROUGH_CODE = 'return $input.all();';


// n8n's static Code-node validator can mistake helper-function `return {}`
// statements for the node's top-level output and report
// "Array items must be objects with json property". Preserve runtime
// semantics while making helper object returns unambiguous to the analyser:
// `return { ... }` becomes `return Object.assign({}, { ... })`.
function rewriteBareObjectReturns(source) {
  const text = String(source || '');
  const edits = [];

  function isIdentChar(ch) {
    return /[A-Za-z0-9_$]/.test(ch || '');
  }

  function findMatchingBrace(openIndex) {
    let depth = 0;
    let mode = 'normal';
    let escaped = false;

    for (let i = openIndex; i < text.length; i += 1) {
      const ch = text[i];
      const next = text[i + 1];

      if (mode === 'lineComment') {
        if (ch === '\n') mode = 'normal';
        continue;
      }
      if (mode === 'blockComment') {
        if (ch === '*' && next === '/') {
          mode = 'normal';
          i += 1;
        }
        continue;
      }
      if (mode === 'single') {
        if (escaped) escaped = false;
        else if (ch === '\\') escaped = true;
        else if (ch === "'") mode = 'normal';
        continue;
      }
      if (mode === 'double') {
        if (escaped) escaped = false;
        else if (ch === '\\') escaped = true;
        else if (ch === '"') mode = 'normal';
        continue;
      }
      if (mode === 'template') {
        if (escaped) escaped = false;
        else if (ch === '\\') escaped = true;
        else if (ch === '`') mode = 'normal';
        continue;
      }

      if (ch === '/' && next === '/') {
        mode = 'lineComment';
        i += 1;
        continue;
      }
      if (ch === '/' && next === '*') {
        mode = 'blockComment';
        i += 1;
        continue;
      }
      if (ch === "'") {
        mode = 'single';
        continue;
      }
      if (ch === '"') {
        mode = 'double';
        continue;
      }
      if (ch === '`') {
        mode = 'template';
        continue;
      }

      if (ch === '{') depth += 1;
      else if (ch === '}') {
        depth -= 1;
        if (depth === 0) return i;
      }
    }
    throw new Error(`unmatched object-return brace at index ${openIndex}`);
  }

  for (let i = 0; i < text.length; i += 1) {
    if (!text.startsWith('return', i)) continue;
    if (isIdentChar(text[i - 1]) || isIdentChar(text[i + 6])) continue;

    let cursor = i + 6;
    while (/\s/.test(text[cursor] || '')) cursor += 1;
    if (text[cursor] !== '{') continue;

    const close = findMatchingBrace(cursor);
    edits.push({ start: i, open: cursor, close });
    i = close;
  }

  const events = [];
  for (const edit of edits) {
    events.push({ pos: edit.close + 1, end: edit.close + 1, value: ')' });
    events.push({ pos: edit.start, end: edit.open + 1, value: 'return Object.assign({}, {' });
  }
  events.sort((a, b) => b.pos - a.pos || b.end - a.end);

  let output = text;
  for (const event of events) {
    output = output.slice(0, event.pos) + event.value + output.slice(event.end);
  }
  return output;
}

// ---------------------------------------------------------------------
// Node factories (compact node definitions)
// ---------------------------------------------------------------------
function sticky(id, name, position, content, opts = {}) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.stickyNote',
    typeVersion: 1,
    position,
    parameters: {
      content,
      height: opts.height ?? 400,
      width: opts.width ?? 380,
      color: opts.color ?? 4,
    },
  };
}

function manualTrigger(id, name, position) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.manualTrigger',
    typeVersion: 1,
    position,
    parameters: {},
  };
}

function scheduleTrigger(id, name, position) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.scheduleTrigger',
    typeVersion: 1.2,
    position,
    parameters: {
      rule: { interval: [{ field: 'minutes', minutesInterval: 5 }] },
    },
  };
}

function executeWorkflowTrigger(id, name, position) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.executeWorkflowTrigger',
    typeVersion: 1.1,
    position,
    parameters: { inputSource: 'passthrough' },
  };
}

function codeNode(id, name, position, jsCode) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position,
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode: rewriteBareObjectReturns(jsCode),
    },
  };
}

function httpRequestNode(id, name, position, method, url, jsonBodyExpression) {
  const params = {
    method,
    url,
    options: { timeout: 5000 },
  };
  if (method !== 'GET' && jsonBodyExpression) {
    params.sendBody = true;
    params.specifyBody = 'json';
    params.jsonBody = jsonBodyExpression;
  }
  return {
    id,
    name,
    type: 'n8n-nodes-base.httpRequest',
    typeVersion: 4.2,
    position,
    parameters: params,
  };
}

function connectMain(map, fromName, toName, outputIndex = 0) {
  if (!map[fromName]) map[fromName] = { main: [] };
  while (map[fromName].main.length <= outputIndex) map[fromName].main.push([]);
  map[fromName].main[outputIndex].push({ node: toName, type: 'main', index: 0 });
}

// ---------------------------------------------------------------------
// SLA Watchdog workflow: HMZ - Reply SLA Watchdog - Validation
// ---------------------------------------------------------------------
function buildWatchdogWorkflow() {
  const UNFINISHED_URL = `${wc.SEND_STATE_BASE_URL}/v1/unfinished`;
  const DEDUPE_URL = `${wc.SEND_STATE_BASE_URL}/v1/alert/dedupe`;
  const RESULT_URL = `${wc.SEND_STATE_BASE_URL}/v1/phase4b/result`;

  const nodes = [];
  const connections = {};

  nodes.push(
    sticky(
      'sticky_overview',
      'Overview',
      [-40, -440],
      '# HMZ - Reply SLA Watchdog - Validation (Phase 4B)\n\n' +
        'WHAT: Periodically (Schedule Trigger, eventual) or on demand (Execute ' +
        'Workflow Trigger, synthetic tests) reads every unfinished hmz-send-state ' +
        'send/error record from GET /v1/unfinished, classifies each into a ' +
        'watchdog category (AI_CLASSIFICATION_WAIT, API_RETRY, HUMAN_REVIEW, ' +
        'SEND_FAILURE, SEND_UNCERTAIN, SUPPRESSION_FAILURE, UNKNOWN_STATE), and ' +
        'compares its age against the WARNING (180s) and BREACH (300s) ' +
        'thresholds.\n\n' +
        'SLOs: only SEND_UNCERTAIN records belong to the Transmission SLO ' +
        '(an attempted send awaiting reconciliation). Every other category - ' +
        'including every HUMAN_REVIEW item - belongs to the Processing SLO. A ' +
        'draft, queue item, approval request, or human-review item is never ' +
        'counted as transmitted.\n\n' +
        'ALERTING: warning/breach records are reduced to sanitised alert ' +
        'candidates (category + SLO type + record identifier + status) and ' +
        'deduplicated atomically via POST /v1/alert/dedupe before routing to a ' +
        'PLACEHOLDER_NOT_CONFIGURED notification object only - no real ' +
        'notification call.\n\n' +
        'VALIDATION MODE: hardcoded (watchdog_result.validation_mode = true). ' +
        'SIDECAR: http://hmz-send-state:5681 (internal Docker network only).\n\n' +
        'INACTIVE: this workflow must remain inactive after import and after ' +
        'every test.',
      { height: 460, width: 940, color: 7 }
    )
  );

  nodes.push(scheduleTrigger('trigger_schedule', 'Schedule Trigger (Eventual)', [0, -120]));
  nodes.push(executeWorkflowTrigger('trigger_synthetic', 'Execute Workflow Trigger (Synthetic Test Entry)', [0, 140]));

  nodes.push(codeNode('node_a', 'A. Capture Trigger Input', [280, 0], PASSTHROUGH_CODE));

  nodes.push(httpRequestNode('node_b_http', 'B. Get Unfinished Records (hmz-send-state)', [560, 0], 'GET', UNFINISHED_URL, null));

  nodes.push(codeNode('node_c', 'C. Build Evaluation Input', [840, 0], mergeFnCode('', wc.mergeUnfinishedResponse, 'A. Capture Trigger Input')));

  nodes.push(codeNode('node_d', 'D. Evaluate Unfinished Records', [1120, 0], singleFnCode(WATCHDOG_PREAMBLE, wc.evaluateUnfinishedRecords)));

  nodes.push(codeNode('node_e', 'E. Build Alert Records', [1400, 0], singleFnCode(WATCHDOG_PREAMBLE, wc.buildAlertRecords)));

  nodes.push(
    httpRequestNode(
      'node_f_http',
      'F. Dedupe Alerts (hmz-send-state)',
      [1680, 0],
      'POST',
      DEDUPE_URL,
      '={{ { alertKeys: $json.alert_candidates.map(a => a.alert_key) } }}'
    )
  );

  nodes.push(codeNode('node_g', 'G. Merge Alert Dedupe Results', [1960, 0], mergeFnCode(WATCHDOG_PREAMBLE, wc.mergeAlertDedupeResults, 'E. Build Alert Records')));

  nodes.push(codeNode('node_h', 'H. Build Watchdog Result', [2240, 0], singleFnCode(WATCHDOG_PREAMBLE, wc.buildWatchdogResult)));

  nodes.push(httpRequestNode('node_i_http', 'I. Persist Watchdog Result (hmz-send-state)', [2520, 0], 'POST', RESULT_URL, '={{ $json.watchdog_result }}'));

  nodes.push(codeNode('node_j', 'J. Attach Result ID', [2800, 0], mergeFnCode('', wc.attachPhase4bResultId, 'H. Build Watchdog Result')));

  nodes.push(
    sticky(
      'sticky_evaluation',
      'Evaluate, Alert, Persist (notes)',
      [840, 240],
      '## C-J. Evaluation, Alerting, Persistence\n\n' +
        'C merges GET /v1/unfinished (sends/errors) onto the triggering item, ' +
        'preserving any test_overrides.now / synthetic flag from the Execute ' +
        'Workflow Trigger so synthetic runs are deterministic. D classifies and ' +
        'ages every record (warning_threshold_seconds=180, ' +
        'breach_threshold_seconds=300) and splits Processing vs Transmission ' +
        'SLO totals.\n\n' +
        'E builds one sanitised alert candidate per warning/breach record ' +
        '(stable alert_key = category + SLO type + kind + identifier + status, ' +
        'no message bodies, no raw email addresses - identifiers are already ' +
        'sha256 hashes). F atomically records each alert_key at most once via ' +
        'POST /v1/alert/dedupe (open(\'wx\')); G merges the dedupe response so a ' +
        'repeated alert is never re-notified.\n\n' +
        'H builds the final sanitised watchdog_result (validation_mode=true, ' +
        'notification.surface=PLACEHOLDER_NOT_CONFIGURED, delivered=false - no ' +
        'real notification call). I persists it via POST /v1/phase4b/result; J ' +
        'attaches the returned resultId.',
      { height: 460, width: 1180, color: 5 }
    )
  );

  connectMain(connections, 'Schedule Trigger (Eventual)', 'A. Capture Trigger Input');
  connectMain(connections, 'Execute Workflow Trigger (Synthetic Test Entry)', 'A. Capture Trigger Input');
  connectMain(connections, 'A. Capture Trigger Input', 'B. Get Unfinished Records (hmz-send-state)');
  connectMain(connections, 'B. Get Unfinished Records (hmz-send-state)', 'C. Build Evaluation Input');
  connectMain(connections, 'C. Build Evaluation Input', 'D. Evaluate Unfinished Records');
  connectMain(connections, 'D. Evaluate Unfinished Records', 'E. Build Alert Records');
  connectMain(connections, 'E. Build Alert Records', 'F. Dedupe Alerts (hmz-send-state)');
  connectMain(connections, 'F. Dedupe Alerts (hmz-send-state)', 'G. Merge Alert Dedupe Results');
  connectMain(connections, 'G. Merge Alert Dedupe Results', 'H. Build Watchdog Result');
  connectMain(connections, 'H. Build Watchdog Result', 'I. Persist Watchdog Result (hmz-send-state)');
  connectMain(connections, 'I. Persist Watchdog Result (hmz-send-state)', 'J. Attach Result ID');

  return {
    name: 'HMZ - Reply SLA Watchdog - Validation',
    active: false,
    nodes,
    connections,
    settings: {
      executionOrder: 'v1',
      saveDataErrorExecution: 'all',
      saveDataSuccessExecution: 'all',
      saveManualExecutions: true,
      saveExecutionProgress: true,
    },
  };
}

// ---------------------------------------------------------------------
// Full Test Harness workflow: HMZ - Reply Full Test Harness - Validation
// ---------------------------------------------------------------------
function loadFixtureMatrix() {
  const files = ['intake_fixtures.json', 'sender_fixtures.json', 'failure_fixtures.json', 'monitoring_fixtures.json'];
  const all = [];
  for (const file of files) {
    const fixtures = JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, file), 'utf8'));
    all.push(...fixtures);
  }
  return all;
}

function buildRunFixtureMatrixCode(fixtures) {
  return [
    `const FIXTURES = ${JSON.stringify(fixtures)};`,
    '',
    SENDER_PREAMBLE,
    '',
    ERROR_PREAMBLE,
    '',
    WATCHDOG_PREAMBLE,
    '',
    HARNESS_PREAMBLE,
    '',
    'const sc = {',
    `  ${SENDER_FN_NAMES.join(',\n  ')},`,
    '};',
    'const ec = {',
    `  ${ERROR_FN_NAMES.join(',\n  ')},`,
    '};',
    'const wc = {',
    `  ${WATCHDOG_FN_NAMES.join(',\n  ')},`,
    '};',
    '',
    'const harness_result = runFixtureMatrix(FIXTURES, { sc, ec, wc });',
    '',
    'return [{ json: { schema_version: \'1.0\', synthetic: true, validation_mode: true, harness_result } }];',
  ].join('\n');
}

function buildHarnessWorkflow() {
  const RESULT_URL = `${wc.SEND_STATE_BASE_URL}/v1/phase4b/result`;
  const fixtures = loadFixtureMatrix();

  const nodes = [];
  const connections = {};

  nodes.push(
    sticky(
      'sticky_overview',
      'Overview',
      [-40, -440],
      '# HMZ - Reply Full Test Harness - Validation (Phase 4B)\n\n' +
        `WHAT: On demand (Manual Trigger or Execute Workflow Trigger), runs the ` +
        `complete Phase 4 synthetic fixture matrix (${fixtures.length} fixtures ` +
        'across intake/policy, sender/suppression, failure-policy, and ' +
        'monitoring/error-handling groups) against the deterministic Phase 4A/4B ' +
        'core modules (sender-core, error-core, watchdog-core, harness-core) ' +
        'embedded directly into this workflow. Every fixture is synthetic ' +
        '(synthetic: true); no fixture ever calls Instantly or uses credentials.\n\n' +
        'ASSERTIONS: each fixture declares a `check` (which deterministic core ' +
        'function(s) to run) and an `expected` object compared by dot-path ' +
        'against the actual result. harness_result.overall_result is FAIL if any ' +
        'fixture fails.\n\n' +
        'LOCAL CONTRACT: classify_intake fixtures exercise ' +
        'classifyIntakeEvent() - a local deterministic reimplementation of the ' +
        'safety-critical subset of HMZ_APPROVED_REPLY_RULES.md sections 3 and 5, ' +
        'used because no shared decision-core module exists for workflows 01/02. ' +
        'Two monitoring fixtures (sidecar_resolved_exclusion, ' +
        'sidecar_alert_dedupe) report skipped:true here and are proven directly ' +
        'against infrastructure/send-state/state-store.mjs by ' +
        'run-offline-tests.mjs. Full sub-workflow integration (Execute Workflow ' +
        'calls into workflows 01-06 by ID) is recorded as a Phase 5 task.\n\n' +
        'VALIDATION MODE: hardcoded (validation_mode = true, synthetic = true). ' +
        'SIDECAR: http://hmz-send-state:5681 (internal Docker network only, used ' +
        'only to persist the sanitised harness_result).\n\n' +
        'INACTIVE: this workflow must remain inactive after import and after ' +
        'every test.',
      { height: 520, width: 980, color: 7 }
    )
  );

  nodes.push(manualTrigger('trigger_manual', 'Manual Trigger', [0, -120]));
  nodes.push(executeWorkflowTrigger('trigger_synthetic', 'Execute Workflow Trigger (Synthetic Test Entry)', [0, 140]));

  nodes.push(codeNode('node_a', 'A. Run Fixture Matrix', [280, 0], buildRunFixtureMatrixCode(fixtures)));

  nodes.push(httpRequestNode('node_b_http', 'B. Persist Harness Result (hmz-send-state)', [560, 0], 'POST', RESULT_URL, '={{ $json.harness_result }}'));

  nodes.push(codeNode('node_c', 'C. Attach Result ID', [840, 0], mergeFnCode('', wc.attachPhase4bResultId, 'A. Run Fixture Matrix')));

  nodes.push(
    sticky(
      'sticky_matrix',
      'Fixture Matrix (notes)',
      [280, 240],
      '## A. Embedded Fixture Matrix\n\n' +
        `${fixtures.length} fixtures embedded as a JSON literal from ` +
        'fixtures/phase_4/{intake,sender,failure,monitoring}_fixtures.json:\n\n' +
        `- intake (policy/intake): ${fixtures.filter((f) => f.group === 'intake').length}\n` +
        `- sender (sender/suppression): ${fixtures.filter((f) => f.group === 'sender').length}\n` +
        `- failure (failure policy): ${fixtures.filter((f) => f.group === 'failure').length}\n` +
        `- monitoring (monitoring/error handling): ${fixtures.filter((f) => f.group === 'monitoring').length}\n\n` +
        'runFixtureMatrix() runs every fixture through its declared `check` ' +
        '(see harness-core.mjs CHECKS) and compares the result to `expected` by ' +
        'dot path. B persists the sanitised harness_result (schema_version, ' +
        'synthetic, total, passed, failed, overall_result, per-fixture results) ' +
        'via POST /v1/phase4b/result; C attaches the returned resultId.',
      { height: 380, width: 900, color: 5 }
    )
  );

  connectMain(connections, 'Manual Trigger', 'A. Run Fixture Matrix');
  connectMain(connections, 'Execute Workflow Trigger (Synthetic Test Entry)', 'A. Run Fixture Matrix');
  connectMain(connections, 'A. Run Fixture Matrix', 'B. Persist Harness Result (hmz-send-state)');
  connectMain(connections, 'B. Persist Harness Result (hmz-send-state)', 'C. Attach Result ID');

  return {
    name: 'HMZ - Reply Full Test Harness - Validation',
    active: false,
    nodes,
    connections,
    settings: {
      executionOrder: 'v1',
      saveDataErrorExecution: 'all',
      saveDataSuccessExecution: 'all',
      saveManualExecutions: true,
      saveExecutionProgress: true,
    },
  };
}

// ---------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------
function main() {
  const watchdog = buildWatchdogWorkflow();
  const harness = buildHarnessWorkflow();

  fs.mkdirSync(WORKFLOWS_DIR, { recursive: true });
  fs.writeFileSync(path.join(WORKFLOWS_DIR, '05_reply_sla_watchdog_validation.json'), `${JSON.stringify(watchdog, null, 2)}\n`, 'utf8');
  fs.writeFileSync(path.join(WORKFLOWS_DIR, '06_reply_full_test_harness_validation.json'), `${JSON.stringify(harness, null, 2)}\n`, 'utf8');

  console.log('Wrote workflows/05_reply_sla_watchdog_validation.json');
  console.log('Wrote workflows/06_reply_full_test_harness_validation.json');
}

main();
