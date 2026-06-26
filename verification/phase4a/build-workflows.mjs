// Phase 4A workflow builder.
//
// Deterministically generates the two Phase 4A workflow JSON exports from
// compact node definitions plus Code-node source embedded directly from
// sender-core.mjs / error-core.mjs (via Function.prototype.toString()).
// No hand-maintained giant JSON blobs.
//
// Usage: node verification/phase4a/build-workflows.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as sc from './sender-core.mjs';
import * as ec from './error-core.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const WORKFLOWS_DIR = path.join(PROJECT_ROOT, 'workflows');

// ---------------------------------------------------------------------
// Shared preambles: constants + helper functions embedded into every
// generated Code node that needs them. Built mechanically from the
// exported names of sender-core.mjs / error-core.mjs - never
// hand-duplicated.
// ---------------------------------------------------------------------
const SENDER_CONST_NAMES = [
  'OPERATING_MODE',
  'DRY_RUN',
  'LIVE_CAMPAIGNS',
  'LIVE_CREDENTIAL_READY',
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
  'classifySendOutcome',
  'planSendAttempts',
  'reconcileMatches',
  'liveAdapterContract',
];

const ERROR_CONST_NAMES = [
  'REDACT_KEY_PATTERN',
  'MAX_STRING_LENGTH',
  'RETRYABLE_HTTP_STATUSES',
  'OPERATOR_ACTION_BY_CLASS',
];
const ERROR_FN_NAMES = [
  'redactValue',
  'classifyErrorClass',
  'deriveRetryable',
  'deriveOperatorAction',
];

function serializeEmbeddedConstant(value) {
  if (value instanceof RegExp) return value.toString();
  return JSON.stringify(value);
}

function buildPreamble(constNames, fnNames, mod) {
  const constLines = constNames.map((name) => `const ${name} = ${serializeEmbeddedConstant(mod[name])};`);
  const fnLines = fnNames.map((name) => mod[name].toString());
  return [...constLines, ...fnLines].join('\n\n');
}

const SENDER_PREAMBLE = buildPreamble(SENDER_CONST_NAMES, SENDER_FN_NAMES, sc);
const ERROR_PREAMBLE = buildPreamble(ERROR_CONST_NAMES, ERROR_FN_NAMES, ec);

// ---------------------------------------------------------------------
// jsCode generators
// ---------------------------------------------------------------------

// One pure function (item) => item', applied to every input item.
function singleFnCode(preamble, fn) {
  return [
    'const items = $input.all();',
    '',
    preamble,
    '',
    fn.toString(),
    '',
    `return items.map(item => ({ json: ${fn.name}(item.json || {}) }));`,
  ].join('\n');
}

// Two-arg function (priorItem, currentItem) => item', where currentItem
// is this node's own input (e.g. an HTTP Request response) and priorItem
// is the matching item from an earlier named node.
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

// ---------------------------------------------------------------------
// Node factories (compact node definitions)
// ---------------------------------------------------------------------
let conditionCounter = 0;
function nextConditionId() {
  conditionCounter += 1;
  return `cond-${conditionCounter}`;
}

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

function errorTrigger(id, name, position) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.errorTrigger',
    typeVersion: 1,
    position,
    parameters: {},
  };
}

function codeNode(id, name, position, jsCode) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position,
    onError: 'continueRegularOutput',
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode,
    },
  };
}

function ifNode(id, name, position, leftExpression) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.if',
    typeVersion: 2.3,
    position,
    parameters: {
      conditions: {
        options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
        combinator: 'and',
        conditions: [
          {
            id: nextConditionId(),
            leftValue: leftExpression,
            rightValue: '',
            operator: { type: 'boolean', operation: 'true', singleValue: true },
          },
        ],
      },
      options: {},
    },
  };
}

function httpRequestNode(id, name, position, url, jsonBodyExpression) {
  return {
    id,
    name,
    type: 'n8n-nodes-base.httpRequest',
    typeVersion: 4.2,
    position,
    onError: 'continueRegularOutput',
    parameters: {
      method: 'POST',
      url,
      sendBody: true,
      specifyBody: 'json',
      jsonBody: jsonBodyExpression,
      options: {
        timeout: 5000,
      },
    },
  };
}

function connectMain(map, fromName, toName, outputIndex = 0) {
  if (!map[fromName]) map[fromName] = { main: [] };
  while (map[fromName].main.length <= outputIndex) map[fromName].main.push([]);
  map[fromName].main[outputIndex].push({ node: toName, type: 'main', index: 0 });
}

// ---------------------------------------------------------------------
// Sender workflow: HMZ - Instantly Reply Sender - Validation
// ---------------------------------------------------------------------
function buildSenderWorkflow() {
  const ACQUIRE_URL = `${sc.SEND_STATE_BASE_URL}/v1/send/acquire`;
  const TRANSITION_URL = `${sc.SEND_STATE_BASE_URL}/v1/send/transition`;

  const nodes = [];
  const connections = {};

  nodes.push(
    sticky(
      'sticky_overview',
      'Overview',
      [-40, -440],
      '# HMZ - Instantly Reply Sender - Validation (Phase 4A)\n\n' +
        'WHAT: Sub-workflow invoked with the Reply Decision Engine output ' +
        '(workflow NJcnNQoJ5nSIWYte). Re-validates required identifiers, re-runs ' +
        'every send/suppression/safety gate, derives a stable send key, acquires ' +
        'durable ownership from the hmz-send-state sidecar, runs suppression ' +
        'actions via a mock adapter only, and - because DRY_RUN=true is hardcoded - ' +
        'transitions to DRY_RUN_OK and returns one structured terminal object. ' +
        'No external HTTP call to Instantly is ever made.\n\n' +
        'HARDCODED: OPERATING_MODE=VALIDATION, DRY_RUN=true, LIVE_CAMPAIGNS=[], ' +
        'LIVE_CREDENTIAL_READY=false. No input path may override these.\n\n' +
        'SIDECAR: http://hmz-send-state:5681 (internal Docker network only, ' +
        'not published to the host). Provides atomic send-ownership and ' +
        'forward-only send state. See infrastructure/send-state/README.md.\n\n' +
        'INACTIVE: this workflow must remain inactive after import and after ' +
        'every test.',
      { height: 420, width: 900, color: 7 }
    )
  );

  nodes.push(
    executeWorkflowTrigger('trigger_entry', 'When Called With Decision Engine Output', [0, 0])
  );

  nodes.push(
    codeNode(
      'node_a',
      'A. Validate Decision Engine Output',
      [280, 0],
      singleFnCode(SENDER_PREAMBLE, sc.validateSenderInput)
    )
  );

  nodes.push(
    codeNode(
      'node_b',
      'B. Re-run Send & Suppression Gates',
      [560, 0],
      singleFnCode(SENDER_PREAMBLE, sc.runSendGates)
    )
  );

  nodes.push(ifNode('if_gates', 'C. Send Gates Router', [840, 0], '={{ $json.gates.passed }}'));

  nodes.push(
    codeNode(
      'node_c2',
      'C2. Gate Rejection Terminal',
      [1120, 220],
      singleFnCode(SENDER_PREAMBLE, sc.buildGateRejectionTerminal)
    )
  );

  nodes.push(
    codeNode(
      'node_d',
      'D. Compute Stable Send Key',
      [1120, -120],
      singleFnCode(SENDER_PREAMBLE, sc.computeSendKey)
    )
  );

  nodes.push(
    httpRequestNode(
      'node_e_http',
      'E. Acquire Send Ownership (hmz-send-state)',
      [1400, -120],
      ACQUIRE_URL,
      '={{ { inboundEmailId: $json.send_identity.inboundEmailId, sender: $json.send_identity.sender, recipient: $json.send_identity.recipient, policyTemplateId: $json.send_identity.policyTemplateId } }}'
    )
  );

  nodes.push(
    codeNode(
      'node_e2',
      'E2. Normalize Acquisition Result',
      [1680, -120],
      mergeFnCode(SENDER_PREAMBLE, sc.normalizeAcquisitionResult, 'D. Compute Stable Send Key')
    )
  );

  nodes.push(
    ifNode('if_acq', 'F. Acquisition Router', [1960, -120], '={{ $json.acquisition.acquired }}')
  );

  nodes.push(
    codeNode(
      'node_f2',
      'F2. Blocked Duplicate or Rerun Terminal',
      [2240, 100],
      singleFnCode(SENDER_PREAMBLE, sc.buildBlockedDuplicateTerminal)
    )
  );

  nodes.push(
    codeNode(
      'node_g',
      'G. Suppression Actions (Mock Adapter)',
      [2240, -200],
      singleFnCode(SENDER_PREAMBLE, sc.mockSuppressionAdapter)
    )
  );

  nodes.push(
    codeNode(
      'node_h',
      'H. Verify Suppression Results',
      [2520, -200],
      singleFnCode(SENDER_PREAMBLE, sc.verifySuppressionResults)
    )
  );

  nodes.push(
    ifNode(
      'if_supp',
      'I. Suppression Verified Router',
      [2800, -200],
      '={{ $json.suppression_verification.verified }}'
    )
  );

  nodes.push(
    codeNode(
      'node_i2',
      'I2. Suppression Escalation Terminal',
      [3080, 60],
      singleFnCode(SENDER_PREAMBLE, sc.buildSuppressionEscalationTerminal)
    )
  );

  nodes.push(
    ifNode(
      'if_dryrun',
      'J. DRY_RUN Gate',
      [3080, -280],
      '={{ $json.gates.dry_run_gate_passed }}'
    )
  );

  nodes.push(
    httpRequestNode(
      'node_k_http',
      'K. Transition to DRY_RUN_OK (hmz-send-state)',
      [3360, -280],
      TRANSITION_URL,
      "={{ { sendKey: $json.acquisition.sendKey, toState: 'DRY_RUN_OK', details: { category: $json.decision.category, intakeId: $json.nes.intake_id, reason: 'dry_run_validation' } } }}"
    )
  );

  nodes.push(
    codeNode(
      'node_k2',
      'K2. Build DRY_RUN Terminal Result',
      [3640, -280],
      mergeFnCode(SENDER_PREAMBLE, sc.buildDryRunTerminal, 'H. Verify Suppression Results')
    )
  );

  nodes.push(
    codeNode(
      'node_n',
      'N. Live Adapter Contract (Validation-Only, Unreachable)',
      [3360, 60],
      singleFnCode(SENDER_PREAMBLE, sc.buildLiveAdapterTerminal)
    )
  );

  nodes.push(
    sticky(
      'sticky_sidecar',
      'Send Ownership & Suppression (notes)',
      [1100, 340],
      '## D-I. Send Key, Ownership, Suppression\n\n' +
        'D computes a stable send key from the canonical inbound Email ID, ' +
        'sender, recipient and the resolved reply_template_id - never from a ' +
        'random body marker. E POSTs to hmz-send-state /v1/send/acquire ' +
        '(internal Docker network only). A concurrent second acquisition for ' +
        'the same identity returns acquired=false, reason=LOCK_ALREADY_HELD; a ' +
        'later sequential rerun returns reason=DURABLE_STATE_EXISTS. F routes ' +
        'blocked results to a terminal no-send result (F2) without any further ' +
        'action.\n\n' +
        'G runs only a mock suppression adapter (source-campaign action plus ' +
        'exact workspace email block-list action) - no live Instantly call. H ' +
        'verifies both actions; any partial/uncertain result escalates (I2) and ' +
        'is never sent as an unsubscribe confirmation.',
      { height: 420, width: 940, color: 5 }
    )
  );

  nodes.push(
    sticky(
      'sticky_dryrun',
      'DRY_RUN Gate & Live Adapter Contract (notes)',
      [3060, 340],
      '## J-N. DRY_RUN Gate and Live Adapter Contract\n\n' +
        'J checks gates.dry_run_gate_passed, which is true only when ' +
        'SENDER_CONFIG.DRY_RUN === true (hardcoded). K transitions the ' +
        'hmz-send-state record from LOCKED to DRY_RUN_OK (a terminal state) and ' +
        'K2 returns one structured terminal object with sent=false, ' +
        'transport=NONE.\n\n' +
        'N (Live Adapter Contract) is wired only to the J "false" branch, which ' +
        'is never taken because DRY_RUN is hardcoded true - it documents the ' +
        'verified V3 POST /api/v2/emails/reply contract (eaccount, ' +
        'reply_to_uuid, subject, body.text/html) plus the V5 retry/' +
        'classification (classifySendOutcome, planSendAttempts) and read-only ' +
        'reconciliation (reconcileMatches) contracts as deterministic code, ' +
        'without binding credentials or making any HTTP request. ' +
        'LIVE_CREDENTIAL_READY=false and LIVE_CAMPAIGNS=[] additionally block it ' +
        'if it were ever reached.',
      { height: 420, width: 760, color: 6 }
    )
  );

  connectMain(connections, 'When Called With Decision Engine Output', 'A. Validate Decision Engine Output');
  connectMain(connections, 'A. Validate Decision Engine Output', 'B. Re-run Send & Suppression Gates');
  connectMain(connections, 'B. Re-run Send & Suppression Gates', 'C. Send Gates Router');
  connectMain(connections, 'C. Send Gates Router', 'D. Compute Stable Send Key', 0);
  connectMain(connections, 'C. Send Gates Router', 'C2. Gate Rejection Terminal', 1);
  connectMain(connections, 'D. Compute Stable Send Key', 'E. Acquire Send Ownership (hmz-send-state)');
  connectMain(connections, 'E. Acquire Send Ownership (hmz-send-state)', 'E2. Normalize Acquisition Result');
  connectMain(connections, 'E2. Normalize Acquisition Result', 'F. Acquisition Router');
  connectMain(connections, 'F. Acquisition Router', 'G. Suppression Actions (Mock Adapter)', 0);
  connectMain(connections, 'F. Acquisition Router', 'F2. Blocked Duplicate or Rerun Terminal', 1);
  connectMain(connections, 'G. Suppression Actions (Mock Adapter)', 'H. Verify Suppression Results');
  connectMain(connections, 'H. Verify Suppression Results', 'I. Suppression Verified Router');
  connectMain(connections, 'I. Suppression Verified Router', 'J. DRY_RUN Gate', 0);
  connectMain(connections, 'I. Suppression Verified Router', 'I2. Suppression Escalation Terminal', 1);
  connectMain(connections, 'J. DRY_RUN Gate', 'K. Transition to DRY_RUN_OK (hmz-send-state)', 0);
  connectMain(connections, 'J. DRY_RUN Gate', 'N. Live Adapter Contract (Validation-Only, Unreachable)', 1);
  connectMain(connections, 'K. Transition to DRY_RUN_OK (hmz-send-state)', 'K2. Build DRY_RUN Terminal Result');

  return {
    name: 'HMZ - Instantly Reply Sender - Validation',
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
// Error Handler workflow: HMZ - Reply Error Handler - Validation
// ---------------------------------------------------------------------
function buildErrorHandlerWorkflow() {
  const ERROR_URL = `${sc.SEND_STATE_BASE_URL}/v1/error`;

  const nodes = [];
  const connections = {};

  nodes.push(
    sticky(
      'sticky_overview',
      'Overview',
      [-40, -420],
      '# HMZ - Reply Error Handler - Validation (Phase 4A)\n\n' +
        'WHAT: Begins with an n8n Error Trigger (any other Phase 4A workflow ' +
        'execution failure) and an Execute Workflow Trigger for synthetic ' +
        'tests. Normalises workflow/execution/failed-node/intake/send-key/' +
        'send-state/HTTP-status/error-class/attempt/retryable/operator-action ' +
        'fields, redacts secrets/Authorization/full payloads/long PII, persists ' +
        'the sanitised record to the hmz-send-state sidecar, and returns a ' +
        'placeholder notification object only.\n\n' +
        'NEVER: calls Slack, email, Sheets, or any other external service. ' +
        'NEVER: converts a SEND_UNCERTAIN record into a retry (retryable is ' +
        'forced false whenever send_state=SEND_UNCERTAIN).\n\n' +
        'SIDECAR: http://hmz-send-state:5681 (internal Docker network only).\n\n' +
        'INACTIVE: this workflow must remain inactive after import and after ' +
        'every test.',
      { height: 400, width: 900, color: 7 }
    )
  );

  nodes.push(errorTrigger('trigger_error', 'Error Trigger', [0, 0]));
  nodes.push(
    executeWorkflowTrigger('trigger_synthetic', 'Execute Workflow Trigger (Synthetic Test Entry)', [0, 220])
  );

  nodes.push(
    codeNode(
      'node_a',
      'A. Normalize Error Event',
      [320, 100],
      singleFnCode(ERROR_PREAMBLE, ec.normalizeErrorEvent)
    )
  );

  nodes.push(
    codeNode(
      'node_b',
      'B. Redact Sensitive Data',
      [600, 100],
      singleFnCode(ERROR_PREAMBLE, ec.redactErrorRecord)
    )
  );

  nodes.push(
    httpRequestNode(
      'node_c_http',
      'C. Persist Error Record (hmz-send-state)',
      [880, 100],
      ERROR_URL,
      '={{ $json.error_record }}'
    )
  );

  nodes.push(
    codeNode(
      'node_c2',
      'C2. Attach Error ID',
      [1160, 100],
      mergeFnCode(ERROR_PREAMBLE, ec.attachErrorId, 'B. Redact Sensitive Data')
    )
  );

  nodes.push(
    codeNode(
      'node_d',
      'D. Build Placeholder Notification',
      [1440, 100],
      singleFnCode(ERROR_PREAMBLE, ec.buildPlaceholderNotification)
    )
  );

  nodes.push(
    sticky(
      'sticky_flow',
      'Normalise, Redact, Persist (notes)',
      [280, 340],
      '## A-D. Error Record Pipeline\n\n' +
        'A accepts either a real Error Trigger item ($json.execution / ' +
        '$json.workflow / $json.trigger.error) or a synthetic Execute Workflow ' +
        'Trigger item (flat fields: workflow_id, workflow_name, execution_id, ' +
        'failed_node, intake_id, send_key, send_state, http_status, attempt) and ' +
        'derives error_class / retryable / operator_action deterministically ' +
        '(400=PERMANENT_FAILURE, 401/402/403=AUTH_OR_PLAN_FAILURE, ' +
        '404=INVALID_REPLY_TARGET, 429/5xx=RETRYABLE, ' +
        'send_state=SEND_UNCERTAIN=>SEND_UNCERTAIN with retryable forced false).\n\n' +
        'B redacts any key matching authorization/api-key/secret/token/password/' +
        'cookie/bearer and truncates strings over 300 chars. C persists the ' +
        'sanitised error_record via POST hmz-send-state /v1/error (internal ' +
        'network only, no credentials). D returns a placeholder notification ' +
        'object only - never Slack/email/Sheets.',
      { height: 420, width: 1180, color: 5 }
    )
  );

  connectMain(connections, 'Error Trigger', 'A. Normalize Error Event');
  connectMain(connections, 'Execute Workflow Trigger (Synthetic Test Entry)', 'A. Normalize Error Event');
  connectMain(connections, 'A. Normalize Error Event', 'B. Redact Sensitive Data');
  connectMain(connections, 'B. Redact Sensitive Data', 'C. Persist Error Record (hmz-send-state)');
  connectMain(connections, 'C. Persist Error Record (hmz-send-state)', 'C2. Attach Error ID');
  connectMain(connections, 'C2. Attach Error ID', 'D. Build Placeholder Notification');

  return {
    name: 'HMZ - Reply Error Handler - Validation',
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
  const sender = buildSenderWorkflow();
  const errorHandler = buildErrorHandlerWorkflow();

  fs.mkdirSync(WORKFLOWS_DIR, { recursive: true });
  fs.writeFileSync(
    path.join(WORKFLOWS_DIR, '03_reply_sender_validation.json'),
    `${JSON.stringify(sender, null, 2)}\n`,
    'utf8'
  );
  fs.writeFileSync(
    path.join(WORKFLOWS_DIR, '04_reply_error_handler_validation.json'),
    `${JSON.stringify(errorHandler, null, 2)}\n`,
    'utf8'
  );

  console.log('Wrote workflows/03_reply_sender_validation.json');
  console.log('Wrote workflows/04_reply_error_handler_validation.json');
}

main();
