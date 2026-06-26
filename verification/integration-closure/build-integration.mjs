// Post-Phase-6 Integration Closure - offline build script.
//
// Pure Node.js (built-ins only). Loads each of the six workflow JSON files,
// applies a fixed set of in-memory mutations that close the four integration
// defects, and writes the files back with the same 2-space/LF/trailing-newline
// formatting. Idempotent: re-running after a successful build is a no-op
// (every mutation first checks whether it has already been applied).
//
// Does not contact n8n, Instantly, or any network service.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');

// Placeholder workflow IDs. These are not real n8n IDs (real IDs are 16
// alphanumeric characters). apply-integration-closure.ps1 discovers the
// actual post-import IDs by exact canonical name and globally replaces these
// tokens, so the JSON committed here never embeds any current-instance ID.
export const PLACEHOLDER_IDS = {
  DECISION_ENGINE: '__PLACEHOLDER_DECISION_ENGINE_WORKFLOW_ID__',
  REPLY_SENDER: '__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__',
  ERROR_HANDLER: '__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__',
};

export const CANONICAL_NAMES = {
  INTAKE: 'HMZ - Instantly Reply Intake - Validation',
  DECISION_ENGINE: 'HMZ - Reply Decision Engine - Validation',
  REPLY_SENDER: 'HMZ - Instantly Reply Sender - Validation',
  ERROR_HANDLER: 'HMZ - Reply Error Handler - Validation',
  SLA_WATCHDOG: 'HMZ - Reply SLA Watchdog - Validation',
  FULL_HARNESS: 'HMZ - Reply Full Test Harness - Validation',
};

// Fresh-install creation order (defect #4). All Execute Sub-workflow
// targets and settings.errorWorkflow values are placeholders patched in a
// single global pass after every workflow has been created, so this order
// only needs to be sensible (leaf workflows first, the entry point last),
// not a strict topological sort of the errorWorkflow assignments.
export const DEPENDENCY_ORDER = [
  CANONICAL_NAMES.DECISION_ENGINE,
  CANONICAL_NAMES.ERROR_HANDLER,
  CANONICAL_NAMES.REPLY_SENDER,
  CANONICAL_NAMES.SLA_WATCHDOG,
  CANONICAL_NAMES.FULL_HARNESS,
  CANONICAL_NAMES.INTAKE,
];

const FILES = {
  INTAKE: '01_reply_intake_validation.json',
  DECISION_ENGINE: '02_reply_decision_engine_validation.json',
  REPLY_SENDER: '03_reply_sender_validation.json',
  ERROR_HANDLER: '04_reply_error_handler_validation.json',
  SLA_WATCHDOG: '05_reply_sla_watchdog_validation.json',
  FULL_HARNESS: '06_reply_full_test_harness_validation.json',
};

function loadWorkflow(file) {
  const full = path.join(WORKFLOWS_DIR, file);
  return JSON.parse(fs.readFileSync(full, 'utf8'));
}

function saveWorkflow(file, wf) {
  const full = path.join(WORKFLOWS_DIR, file);
  fs.writeFileSync(full, `${JSON.stringify(wf, null, 2)}\n`, 'utf8');
}

function findNode(wf, name) {
  return wf.nodes.find((n) => n.name === name);
}

function setErrorWorkflow(wf, applies) {
  const changed = [];
  wf.settings = wf.settings || {};
  if (wf.settings.errorWorkflow !== PLACEHOLDER_IDS.ERROR_HANDLER) {
    wf.settings.errorWorkflow = PLACEHOLDER_IDS.ERROR_HANDLER;
    changed.push('settings.errorWorkflow');
  }
  return changed;
}

// ---------------------------------------------------------------------
// 01. Reply Intake - add the missing Sender handoff (defect #1), remap
// the Decision Engine reference to a placeholder (defect #4), and assign
// the Error Handler (defect #2).
// ---------------------------------------------------------------------
function buildIntake(wf) {
  const changes = [];

  const decisionEngineNode = findNode(wf, 'G. Decision Engine Handoff');
  if (!decisionEngineNode) {
    throw new Error('01: "G. Decision Engine Handoff" node not found');
  }
  if (decisionEngineNode.parameters.workflowId.value !== PLACEHOLDER_IDS.DECISION_ENGINE) {
    decisionEngineNode.parameters.workflowId.value = PLACEHOLDER_IDS.DECISION_ENGINE;
    decisionEngineNode.parameters.workflowId.cachedResultName = CANONICAL_NAMES.DECISION_ENGINE;
    changes.push('G. Decision Engine Handoff workflowId -> placeholder');
  }

  const senderHandoffName = 'H. Reply Sender Handoff';
  if (!findNode(wf, senderHandoffName)) {
    wf.nodes.push({
      id: 'b6f1c3a2-7d4e-4a1f-9c2b-3e5f6a7b8c9d',
      name: senderHandoffName,
      type: 'n8n-nodes-base.executeWorkflow',
      typeVersion: 1.3,
      position: [3160, 0],
      parameters: {
        source: 'database',
        workflowId: {
          mode: 'list',
          value: PLACEHOLDER_IDS.REPLY_SENDER,
          cachedResultName: CANONICAL_NAMES.REPLY_SENDER,
        },
        workflowInputs: {
          mappingMode: 'defineBelow',
          value: {},
        },
        mode: 'each',
        options: {},
      },
    });
    changes.push(`added node "${senderHandoffName}"`);
  }

  // G only has an outgoing connection on the accepted, non-duplicate path
  // (B1/E4 terminal branches B2/E5 are dead-end leaves), so wiring G -> H
  // here is sufficient to satisfy "reject/duplicate branches cannot reach
  // the Sender" without any additional routing logic.
  const existingGConn = wf.connections['G. Decision Engine Handoff'];
  const alreadyWired =
    existingGConn &&
    existingGConn.main &&
    existingGConn.main[0] &&
    existingGConn.main[0].some((c) => c.node === senderHandoffName);
  if (!alreadyWired) {
    wf.connections['G. Decision Engine Handoff'] = {
      main: [[{ node: senderHandoffName, type: 'main', index: 0 }]],
    };
    changes.push('connected G. Decision Engine Handoff -> H. Reply Sender Handoff');
  }

  changes.push(...setErrorWorkflow(wf).map((c) => `01: ${c}`));
  return changes;
}

// ---------------------------------------------------------------------
// 02. Reply Decision Engine - assign the Error Handler (defect #2).
// ---------------------------------------------------------------------
function buildDecisionEngine(wf) {
  return setErrorWorkflow(wf).map((c) => `02: ${c}`);
}

// ---------------------------------------------------------------------
// 03. Reply Sender - assign the Error Handler (defect #2).
// ---------------------------------------------------------------------
function buildReplySender(wf) {
  return setErrorWorkflow(wf).map((c) => `03: ${c}`);
}

// ---------------------------------------------------------------------
// 04. Reply Error Handler - intentionally untouched (must not be its own
// error workflow).
// ---------------------------------------------------------------------
function buildErrorHandler(_wf) {
  return [];
}

// ---------------------------------------------------------------------
// 05. SLA Watchdog - assign the Error Handler (defect #2).
// ---------------------------------------------------------------------
function buildSlaWatchdog(wf) {
  return setErrorWorkflow(wf).map((c) => `05: ${c}`);
}

// ---------------------------------------------------------------------
// 06. Full Test Harness - assign the Error Handler (defect #2) and add the
// synthetic integration route that exercises the real Reply Sender and
// Error Handler sub-workflows (defect #3), each via placeholder workflow
// IDs (defect #4).
// ---------------------------------------------------------------------
function buildFullHarness(wf) {
  const changes = [];
  changes.push(...setErrorWorkflow(wf).map((c) => `06: ${c}`));

  const z0aName = 'Z0a. Build Sender Integration Input (Unique Fixture)';
  const z1Name = 'Z1. Integration - Real Reply Sender Call (Unique Fixture)';
  const z0bName = 'Z0b. Build Sender Integration Input (Stable Rerun Fixture)';
  const z1bName = 'Z1b. Integration - Real Reply Sender Call (Stable Rerun Fixture)';
  const z0cName = 'Z0c. Build Error Handler Integration Input (Forced SEND_UNCERTAIN)';
  const z3Name = 'Z3. Integration - Real Error Handler Call (Forced Error)';
  const z5Name = 'Z5. Merge Integration Assertions Into Harness Result';

  if (findNode(wf, z1Name)) {
    // Already built; nothing further to do.
    return changes;
  }

  const z0aCode = `const executionId = ($execution && $execution.id) ? String($execution.id) : String(Date.now());
const uniqueSuffix = \`\${executionId}-\${Date.now()}\`;

return [{
  json: {
    synthetic: true,
    integration_fixture: 'sender_unique',
    validation: { valid: true, errors: [], checked_at: new Date().toISOString() },
    nes: {
      intake_id: \`intake-integration-\${uniqueSuffix}\`,
      eaccount: 'sender@hmz-validation.test',
      lead_email: \`lead-\${uniqueSuffix}@hmz-validation.test\`,
      campaign_id: 'campaign-integration-validation',
      threading: { reply_to_uuid: \`reply-\${uniqueSuffix}\` },
    },
    decision: {
      category: 'T1',
      confidence: 0.91,
      reply_permitted: true,
      human_review_required: true,
      address_suppression_intent: 'NONE',
      durable_dnc_intent: false,
      reply_template_id: 'tmpl-integration-validation',
    },
    draft: {
      template_id: 'tmpl-integration-validation',
      draft_text: 'Thanks for your reply - a member of our team will follow up shortly.',
    },
    approval: { approved: true },
  },
}];`;

  const z0bCode = `return [{
  json: {
    synthetic: true,
    integration_fixture: 'sender_stable_rerun',
    validation: { valid: true, errors: [], checked_at: new Date().toISOString() },
    nes: {
      intake_id: 'intake-integration-stable-rerun-fixture',
      eaccount: 'sender@hmz-validation.test',
      lead_email: 'lead-stable-rerun-fixture@hmz-validation.test',
      campaign_id: 'campaign-integration-validation',
      threading: { reply_to_uuid: 'reply-stable-rerun-fixture' },
    },
    decision: {
      category: 'T1',
      confidence: 0.91,
      reply_permitted: true,
      human_review_required: true,
      address_suppression_intent: 'NONE',
      durable_dnc_intent: false,
      reply_template_id: 'tmpl-integration-validation',
    },
    draft: {
      template_id: 'tmpl-integration-validation',
      draft_text: 'Thanks for your reply - a member of our team will follow up shortly.',
    },
    approval: { approved: true },
  },
}];`;

  const z0cCode = `const executionId = ($execution && $execution.id) ? String($execution.id) : String(Date.now());
const uniqueSuffix = \`\${executionId}-\${Date.now()}\`;

return [{
  json: {
    synthetic: true,
    integration_fixture: 'error_handler_forced',
    workflow_id: 'integration-closure-synthetic',
    workflow_name: 'HMZ - Instantly Reply Sender - Validation',
    execution_id: executionId,
    failed_node: 'E. Acquire Send Ownership (hmz-send-state)',
    intake_id: \`intake-integration-error-\${uniqueSuffix}\`,
    send_key: \`send-integration-error-\${uniqueSuffix}\`,
    send_state: 'SEND_UNCERTAIN',
    http_status: 200,
    attempt: 1,
  },
}];`;

  const z5Code = `const harnessItem = $('A. Run Fixture Matrix').first();
const harnessResult = (harnessItem && harnessItem.json && harnessItem.json.harness_result) || {};

const senderItem = $('${z1Name}').first();
const senderJson = (senderItem && senderItem.json) || {};
const senderTerminal = senderJson.terminal || {};

const senderRerunItem = $('${z1bName}').first();
const senderRerunJson = (senderRerunItem && senderRerunItem.json) || {};
const senderRerunTerminal = senderRerunJson.terminal || {};

const errorJson = $json;
const errorRecord = errorJson.error_record || {};
const notification = errorJson.notification || {};
const persistedError = errorJson.persisted_error || {};

const senderAssertion = {
  ran_inside_n8n: true,
  terminal_result: senderTerminal.result || null,
  send_state: senderTerminal.send_state || null,
  sent: senderTerminal.sent === true,
  transport: senderTerminal.transport || null,
  passed:
    senderTerminal.result === 'DRY_RUN_OK' &&
    senderTerminal.sent === false &&
    senderTerminal.transport === 'NONE',
};

const senderRerunAssertion = {
  ran_inside_n8n: true,
  terminal_result: senderRerunTerminal.result || null,
  send_state: senderRerunTerminal.send_state || null,
  acquisition_acquired:
    senderRerunJson.acquisition ? senderRerunJson.acquisition.acquired === true : null,
  note: 'Stable identity fixture; sequential-rerun blocking (acquisition.acquired=false on a repeat execution) is proven across repeated runs by run-n8n-runtime-tests.ps1.',
};

const errorAssertion = {
  ran_inside_n8n: true,
  error_record_created: typeof persistedError.errorId === 'string' && persistedError.errorId.length > 0,
  send_state: errorRecord.send_state || null,
  error_class: errorRecord.error_class || null,
  retryable: errorRecord.retryable,
  notification_surface: notification.surface || null,
  notification_delivered: notification.delivered === true,
  passed:
    errorRecord.send_state === 'SEND_UNCERTAIN' &&
    errorRecord.error_class === 'SEND_UNCERTAIN' &&
    errorRecord.retryable === false &&
    notification.surface === 'PLACEHOLDER_NOT_CONFIGURED' &&
    notification.delivered === false &&
    typeof persistedError.errorId === 'string' &&
    persistedError.errorId.length > 0,
};

const integrationPassed = senderAssertion.passed && errorAssertion.passed;

const integration_result = {
  schema_version: '1.0',
  synthetic: true,
  sender_integration: senderAssertion,
  sender_rerun_integration: senderRerunAssertion,
  error_handler_integration: errorAssertion,
  overall_result: integrationPassed ? 'PASS' : 'FAIL',
};

const combined_harness_result = {
  ...harnessResult,
  integration_result,
  overall_result:
    harnessResult.overall_result === 'PASS' && integration_result.overall_result === 'PASS'
      ? 'PASS'
      : 'FAIL',
};

return [{ json: { harness_result: combined_harness_result } }];`;

  const codeNode = (id, name, position, jsCode) => ({
    id,
    name,
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position,
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode,
    },
  });

  const execWorkflowNode = (id, name, position, value, cachedResultName) => ({
    id,
    name,
    type: 'n8n-nodes-base.executeWorkflow',
    typeVersion: 1.3,
    position,
    parameters: {
      source: 'database',
      workflowId: { mode: 'list', value, cachedResultName },
      workflowInputs: { mappingMode: 'defineBelow', value: {} },
      mode: 'each',
      options: {},
    },
  });

  wf.nodes.push(codeNode('c1d2e3f4-0001-4a2b-8c3d-4e5f6a7b8c01', z0aName, [280, 480], z0aCode));
  wf.nodes.push(
    execWorkflowNode('c1d2e3f4-0002-4a2b-8c3d-4e5f6a7b8c02', z1Name, [560, 480], PLACEHOLDER_IDS.REPLY_SENDER, CANONICAL_NAMES.REPLY_SENDER)
  );
  wf.nodes.push(codeNode('c1d2e3f4-0003-4a2b-8c3d-4e5f6a7b8c03', z0bName, [840, 480], z0bCode));
  wf.nodes.push(
    execWorkflowNode('c1d2e3f4-0004-4a2b-8c3d-4e5f6a7b8c04', z1bName, [1120, 480], PLACEHOLDER_IDS.REPLY_SENDER, CANONICAL_NAMES.REPLY_SENDER)
  );
  wf.nodes.push(codeNode('c1d2e3f4-0005-4a2b-8c3d-4e5f6a7b8c05', z0cName, [1400, 480], z0cCode));
  wf.nodes.push(
    execWorkflowNode('c1d2e3f4-0006-4a2b-8c3d-4e5f6a7b8c06', z3Name, [1680, 480], PLACEHOLDER_IDS.ERROR_HANDLER, CANONICAL_NAMES.ERROR_HANDLER)
  );
  wf.nodes.push(codeNode('c1d2e3f4-0007-4a2b-8c3d-4e5f6a7b8c07', z5Name, [1960, 480], z5Code));
  changes.push(`added integration route nodes ${z0aName} .. ${z5Name}`);

  // Rewire: A used to flow directly into B; now A -> Z0a -> Z1 -> Z0b ->
  // Z1b -> Z0c -> Z3 -> Z5 -> B (B and C are otherwise unchanged).
  const nodeA = 'A. Run Fixture Matrix';
  const nodeB = 'B. Persist Harness Result (hmz-send-state)';
  const nodeC = 'C. Attach Result ID';

  wf.connections[nodeA] = { main: [[{ node: z0aName, type: 'main', index: 0 }]] };
  wf.connections[z0aName] = { main: [[{ node: z1Name, type: 'main', index: 0 }]] };
  wf.connections[z1Name] = { main: [[{ node: z0bName, type: 'main', index: 0 }]] };
  wf.connections[z0bName] = { main: [[{ node: z1bName, type: 'main', index: 0 }]] };
  wf.connections[z1bName] = { main: [[{ node: z0cName, type: 'main', index: 0 }]] };
  wf.connections[z0cName] = { main: [[{ node: z3Name, type: 'main', index: 0 }]] };
  wf.connections[z3Name] = { main: [[{ node: z5Name, type: 'main', index: 0 }]] };
  wf.connections[z5Name] = { main: [[{ node: nodeB, type: 'main', index: 0 }]] };
  changes.push(`rewired ${nodeA} -> integration route -> ${nodeB} -> ${nodeC}`);

  // C reads harness_result/its wrapper from the node immediately preceding
  // B in the original graph (A). Repoint that lookup at Z5 so the final
  // output (and the persisted phase4b_result_id wrapper) reflects the
  // combined harness_result including integration_result.
  const nodeCObj = findNode(wf, nodeC);
  if (nodeCObj && nodeCObj.parameters && typeof nodeCObj.parameters.jsCode === 'string') {
    const before = nodeCObj.parameters.jsCode;
    const after = before.replace("$('A. Run Fixture Matrix')", `$('${z5Name}')`);
    if (after !== before) {
      nodeCObj.parameters.jsCode = after;
      changes.push(`${nodeC}: repointed prior-item lookup at ${z5Name}`);
    }
  }

  return changes;
}

export function buildAll() {
  const allChanges = [];

  const intake = loadWorkflow(FILES.INTAKE);
  allChanges.push(...buildIntake(intake));
  saveWorkflow(FILES.INTAKE, intake);

  const decisionEngine = loadWorkflow(FILES.DECISION_ENGINE);
  allChanges.push(...buildDecisionEngine(decisionEngine));
  saveWorkflow(FILES.DECISION_ENGINE, decisionEngine);

  const replySender = loadWorkflow(FILES.REPLY_SENDER);
  allChanges.push(...buildReplySender(replySender));
  saveWorkflow(FILES.REPLY_SENDER, replySender);

  const errorHandler = loadWorkflow(FILES.ERROR_HANDLER);
  allChanges.push(...buildErrorHandler(errorHandler));
  saveWorkflow(FILES.ERROR_HANDLER, errorHandler);

  const slaWatchdog = loadWorkflow(FILES.SLA_WATCHDOG);
  allChanges.push(...buildSlaWatchdog(slaWatchdog));
  saveWorkflow(FILES.SLA_WATCHDOG, slaWatchdog);

  const fullHarness = loadWorkflow(FILES.FULL_HARNESS);
  allChanges.push(...buildFullHarness(fullHarness));
  saveWorkflow(FILES.FULL_HARNESS, fullHarness);

  return allChanges;
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const changes = buildAll();
  if (changes.length === 0) {
    console.log('build-integration: no changes (already applied).');
  } else {
    console.log('build-integration: applied changes:');
    for (const c of changes) console.log(`  - ${c}`);
  }
}
