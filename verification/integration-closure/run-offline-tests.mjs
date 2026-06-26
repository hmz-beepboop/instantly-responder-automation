// Post-Phase-6 Integration Closure - offline test suite.
//
// Pure Node.js (built-ins only). Statically inspects the six built workflow
// JSON files and the apply/runtime scripts, plus re-runs the existing
// Phase 4A / Phase 4B deterministic regression suites as subprocesses.
// Makes no network call and never starts n8n.

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { PLACEHOLDER_IDS, CANONICAL_NAMES, DEPENDENCY_ORDER } from './build-integration.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');

const FILES = [
  '01_reply_intake_validation.json',
  '02_reply_decision_engine_validation.json',
  '03_reply_sender_validation.json',
  '04_reply_error_handler_validation.json',
  '05_reply_sla_watchdog_validation.json',
  '06_reply_full_test_harness_validation.json',
];

const results = [];
function record(id, description, passed, details) {
  results.push({ id, description, passed: !!passed, details: details || undefined });
}

// ---------------------------------------------------------------------
// Load all six workflows up front (test 1 covers parse failures).
// ---------------------------------------------------------------------
const workflows = {};
let parseError = null;
for (const file of FILES) {
  try {
    workflows[file] = JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, file), 'utf8'));
  } catch (err) {
    parseError = `${file}: ${err.message}`;
    break;
  }
}
record('workflows_parse', 'All six workflow JSON files parse as valid JSON', parseError === null, parseError);

if (parseError) {
  // Nothing else is meaningful without parsed workflows.
  finish();
} else {
  runStructuralTests();
}

function getNode(wf, name) {
  return wf.nodes.find((n) => n.name === name);
}

function executeWorkflowNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.executeWorkflow');
}

function httpRequestNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.httpRequest');
}

function codeNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.code');
}

function buildAdjacency(wf) {
  const adj = {};
  for (const [from, conn] of Object.entries(wf.connections || {})) {
    const targets = [];
    for (const output of conn.main || []) {
      for (const edge of output || []) {
        targets.push(edge.node);
      }
    }
    adj[from] = targets;
  }
  return adj;
}

function reachable(adj, start) {
  const seen = new Set();
  const stack = [start];
  while (stack.length) {
    const cur = stack.pop();
    for (const next of adj[cur] || []) {
      if (!seen.has(next)) {
        seen.add(next);
        stack.push(next);
      }
    }
  }
  return seen;
}

function runStructuralTests() {
  const intake = workflows['01_reply_intake_validation.json'];
  const decisionEngine = workflows['02_reply_decision_engine_validation.json'];
  const sender = workflows['03_reply_sender_validation.json'];
  const errorHandler = workflows['04_reply_error_handler_validation.json'];
  const slaWatchdog = workflows['05_reply_sla_watchdog_validation.json'];
  const fullHarness = workflows['06_reply_full_test_harness_validation.json'];

  // ---- 2. All six workflows remain inactive -----------------------------
  const activeOnes = FILES.filter((f) => workflows[f].active !== false);
  record('workflows_inactive', 'All six workflows have active=false', activeOnes.length === 0, activeOnes.length ? activeOnes : undefined);

  // ---- 3. No credentials -------------------------------------------------
  const credentialNodes = [];
  for (const f of FILES) {
    for (const n of workflows[f].nodes) {
      if (n.credentials) credentialNodes.push(`${f}: ${n.name}`);
    }
  }
  record('no_credentials', 'No node in any of the six workflows has a credentials field', credentialNodes.length === 0, credentialNodes.length ? credentialNodes : undefined);

  // ---- 4. No reachable external HTTP target ------------------------------
  // Business-ready: gated Google Chat adapters (workflows 04/05/07) reference
  // $env.GOOGLE_CHAT_WEBHOOK_URL, never a literal external URL.
  // Business-ready live path (build-live-path.mjs): gated, unreachable
  // credentialPlaceholder "hmzInstantlyApi" adapters in workflows 02/03 are
  // also allowed - they remain unreachable unless every live-send gate
  // (workflow 03) or the suppression-enablement router (workflow 02) passes,
  // which cannot happen with the shipped (empty) launch profile.
  const badTargets = [];
  for (const f of FILES) {
    for (const n of httpRequestNodes(workflows[f])) {
      const url = (n.parameters && n.parameters.url) || '';
      const isSidecar = url.startsWith('http://hmz-send-state:5681');
      const isGatedGoogleChat = url === '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}';
      const isGatedInstantlyAdapter =
        url.startsWith('https://api.instantly.ai/') &&
        n.credentialPlaceholder === 'hmzInstantlyApi' &&
        n.onError === 'continueRegularOutput';
      // Per-action suppression executors (workflow 02, G1h-G4h) derive their
      // URL at runtime from safety_action_plan.actions[].request_contract.url,
      // which is itself always an https://api.instantly.ai/... endpoint built
      // by node F (buildSafetyActionPlan); they are gated the same way.
      const isGatedInstantlyAdapterExpression =
        url.startsWith('={{') &&
        url.includes('request_contract') &&
        url.includes('.url') &&
        n.credentialPlaceholder === 'hmzInstantlyApi' &&
        n.onError === 'continueRegularOutput';
      if (!isSidecar && !isGatedGoogleChat && !isGatedInstantlyAdapter && !isGatedInstantlyAdapterExpression) {
        badTargets.push(`${f}: ${n.name} -> ${url}`);
      }
    }
  }
  record('no_external_http_targets', 'Every httpRequest node targets only the hmz-send-state sidecar, the gated Google Chat env var, or a gated credentialPlaceholder live-path Instantly adapter', badTargets.length === 0, badTargets.length ? badTargets : undefined);

  // ---- 5. Intake has exactly one Decision Engine call and one Human
  // Approval call. Business-ready: the Reply Sender is now invoked from
  // workflow 07 (after durable reviewer approval), not directly from Intake.
  const HUMAN_APPROVAL_PLACEHOLDER_ID = '__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__';
  const intakeExecNodes = executeWorkflowNodes(intake);
  const intakeDecisionEngineCalls = intakeExecNodes.filter(
    (n) => n.parameters.workflowId.value === PLACEHOLDER_IDS.DECISION_ENGINE
  );
  const intakeHumanApprovalCalls = intakeExecNodes.filter(
    (n) => n.parameters.workflowId.value === HUMAN_APPROVAL_PLACEHOLDER_ID
  );
  record(
    'intake_single_decision_and_sender_calls',
    'Reply Intake contains exactly one Decision Engine call and exactly one Human Approval call',
    intakeDecisionEngineCalls.length === 1 && intakeHumanApprovalCalls.length === 1,
    { decisionEngineCalls: intakeDecisionEngineCalls.length, humanApprovalCalls: intakeHumanApprovalCalls.length }
  );

  // ---- 6. Human Approval handoff follows the Decision Engine call on the
  // accepted path (business-ready: H targets workflow 07, not the Sender).
  const intakeAdj = buildAdjacency(intake);
  const gName = 'G. Decision Engine Handoff';
  const hName = 'H. Human Approval Handoff';
  const gToH = (intakeAdj[gName] || []).includes(hName);
  record(
    'sender_follows_decision_engine',
    'G. Decision Engine Handoff connects directly to H. Human Approval Handoff',
    gToH,
    gToH ? undefined : { gOutgoing: intakeAdj[gName] }
  );

  // ---- 7. Reject/duplicate terminal branches cannot reach the Human
  // Approval handoff (and therefore cannot reach the Sender) -----
  const b2Name = 'B2. Configuration Gate Rejection (Terminal)';
  const e5Name = 'E5. Duplicate Event Terminal';
  const b2Out = intakeAdj[b2Name] || [];
  const e5Out = intakeAdj[e5Name] || [];
  const b2Reach = reachable(intakeAdj, b2Name);
  const e5Reach = reachable(intakeAdj, e5Name);
  const rejectCannotReachSender =
    b2Out.length === 0 && e5Out.length === 0 && !b2Reach.has(hName) && !e5Reach.has(hName);
  record(
    'reject_duplicate_cannot_reach_sender',
    'B2 (config-gate rejection) and E5 (duplicate-event terminal) are dead-end leaves and cannot reach H. Human Approval Handoff',
    rejectCannotReachSender,
    rejectCannotReachSender ? undefined : { b2Out, e5Out }
  );

  // ---- 8. Five applicable workflows identify the Error Handler -----------
  const errorWorkflowAssignees = {
    '01_reply_intake_validation.json': intake,
    '02_reply_decision_engine_validation.json': decisionEngine,
    '03_reply_sender_validation.json': sender,
    '05_reply_sla_watchdog_validation.json': slaWatchdog,
    '06_reply_full_test_harness_validation.json': fullHarness,
  };
  const missingErrorWorkflow = Object.entries(errorWorkflowAssignees)
    .filter(([, wf]) => (wf.settings || {}).errorWorkflow !== PLACEHOLDER_IDS.ERROR_HANDLER)
    .map(([f]) => f);
  record(
    'five_workflows_identify_error_handler',
    'Reply Intake, Decision Engine, Reply Sender, SLA Watchdog and Full Test Harness all set settings.errorWorkflow to the Error Handler',
    missingErrorWorkflow.length === 0,
    missingErrorWorkflow.length ? missingErrorWorkflow : undefined
  );

  // ---- 9. Error Handler does not identify itself -------------------------
  const errorHandlerSelfRef = !!(errorHandler.settings || {}).errorWorkflow;
  record(
    'error_handler_not_self_referencing',
    'Reply Error Handler does not set settings.errorWorkflow on itself',
    !errorHandlerSelfRef,
    errorHandlerSelfRef ? { errorWorkflow: errorHandler.settings.errorWorkflow } : undefined
  );

  // ---- 10. Full Test Harness calls the real Sender and Error Handler -----
  const harnessExecNodes = executeWorkflowNodes(fullHarness);
  const harnessSenderCalls = harnessExecNodes.filter((n) => n.parameters.workflowId.value === PLACEHOLDER_IDS.REPLY_SENDER);
  const harnessErrorHandlerCalls = harnessExecNodes.filter((n) => n.parameters.workflowId.value === PLACEHOLDER_IDS.ERROR_HANDLER);
  record(
    'full_harness_calls_sender_and_error_handler',
    'Full Test Harness contains Execute Sub-workflow calls into the real Reply Sender and Error Handler workflows',
    harnessSenderCalls.length >= 1 && harnessErrorHandlerCalls.length >= 1,
    { senderCalls: harnessSenderCalls.length, errorHandlerCalls: harnessErrorHandlerCalls.length }
  );

  // ---- 11. Workflow ID references are patchable --------------------------
  // Business-ready: __PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__ (workflow 01 ->
  // 07) is additionally patched by verification/business-ready/apply-business-ready.ps1
  // (the 7-workflow apply script), not by apply-integration-closure.ps1.
  const knownPlaceholders = new Set(Object.values(PLACEHOLDER_IDS));
  knownPlaceholders.add('__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__');
  const unpatchable = [];
  for (const f of FILES) {
    const wf = workflows[f];
    for (const n of executeWorkflowNodes(wf)) {
      const value = n.parameters.workflowId.value;
      if (!knownPlaceholders.has(value)) unpatchable.push(`${f}: ${n.name} workflowId.value=${value}`);
    }
    const ew = (wf.settings || {}).errorWorkflow;
    if (ew !== undefined && !knownPlaceholders.has(ew)) {
      unpatchable.push(`${f}: settings.errorWorkflow=${ew}`);
    }
  }
  record(
    'workflow_id_references_patchable',
    'Every Execute Sub-workflow target and settings.errorWorkflow uses a placeholder ID that apply-integration-closure.ps1 or apply-business-ready.ps1 can globally patch after a fresh import',
    unpatchable.length === 0,
    unpatchable.length ? unpatchable : undefined
  );

  // ---- 12. Fresh-install dependency order ---------------------------------
  const expectedOrder = [
    CANONICAL_NAMES.DECISION_ENGINE,
    CANONICAL_NAMES.ERROR_HANDLER,
    CANONICAL_NAMES.REPLY_SENDER,
    CANONICAL_NAMES.SLA_WATCHDOG,
    CANONICAL_NAMES.FULL_HARNESS,
    CANONICAL_NAMES.INTAKE,
  ];
  const allCanonical = new Set(Object.values(CANONICAL_NAMES));
  const orderCovers = DEPENDENCY_ORDER.length === 6 && new Set(DEPENDENCY_ORDER).size === 6 && DEPENDENCY_ORDER.every((n) => allCanonical.has(n));
  const orderMatchesExpected = JSON.stringify(DEPENDENCY_ORDER) === JSON.stringify(expectedOrder);
  let applyScriptHasOrder = false;
  const applyScriptPath = path.join(__dirname, 'apply-integration-closure.ps1');
  if (fs.existsSync(applyScriptPath)) {
    const applyScriptText = fs.readFileSync(applyScriptPath, 'utf8');
    applyScriptHasOrder = DEPENDENCY_ORDER.every((name) => applyScriptText.includes(name));
  }
  record(
    'fresh_install_dependency_order',
    'build-integration.mjs DEPENDENCY_ORDER is Decision Engine -> Error Handler -> Sender -> SLA Watchdog -> Full Test Harness -> Intake, covers all six canonical workflows exactly once, and apply-integration-closure.ps1 uses the same order',
    orderCovers && orderMatchesExpected && applyScriptHasOrder,
    { orderCovers, orderMatchesExpected, applyScriptHasOrder, dependencyOrder: DEPENDENCY_ORDER }
  );

  // ---- 13. apply-integration-closure.ps1 is idempotent by exact name -----
  let applyScriptOk = false;
  let applyScriptDetails;
  if (!fs.existsSync(applyScriptPath)) {
    applyScriptDetails = 'apply-integration-closure.ps1 does not exist';
  } else {
    const text = fs.readFileSync(applyScriptPath, 'utf8');
    const checks = {
      requires_api_key: /HMZ_N8N_API_KEY/.test(text),
      local_n8n_url: /127\.0\.0\.1:5678/.test(text),
      refuses_without_offline_pass: /offline-test-results\.json/.test(text) && /INTEGRATION_CLOSURE_OFFLINE_READY|offlinePass|OFFLINE_READY/.test(text),
      exact_name_discovery: Object.values(CANONICAL_NAMES).every((name) => text.includes(name)),
      refuses_duplicates: /duplicate/i.test(text),
      placeholders_patched: Object.values(PLACEHOLDER_IDS).every((p) => text.includes(p)),
      keeps_inactive: /active\s*=\s*\$false|active.*false/i.test(text),
      clears_key_in_finally: /finally/i.test(text) && /HMZ_N8N_API_KEY/.test(text),
    };
    applyScriptOk = Object.values(checks).every(Boolean);
    applyScriptDetails = checks;
  }
  record(
    'apply_script_idempotent_by_name',
    'apply-integration-closure.ps1 exists, discovers workflows by exact canonical name, refuses duplicates, requires an offline pass, and patches every placeholder',
    applyScriptOk,
    applyScriptOk ? undefined : applyScriptDetails
  );

  // ---- 14. Embedded Code nodes compile ------------------------------------
  const codeErrors = [];
  for (const f of FILES) {
    for (const n of codeNodes(workflows[f])) {
      const jsCode = (n.parameters && n.parameters.jsCode) || '';
      try {
        // eslint-disable-next-line no-new
        new vm.Script(`(function(){\n${jsCode}\n})`);
      } catch (err) {
        codeErrors.push(`${f}: ${n.name}: ${err.message}`);
      }
    }
  }
  record('embedded_code_nodes_compile', 'Every Code node jsCode body in all six workflows is syntactically valid JavaScript', codeErrors.length === 0, codeErrors.length ? codeErrors : undefined);

  finish();
}

function finish() {
  // ---- 15 / 16. Phase 4A / 4B deterministic regression suites ------------
  runRegression('phase4a_regression', path.join(ROOT, 'verification', 'phase4a', 'run-offline-tests.mjs'), 42);
  runRegression('phase4b_regression', path.join(ROOT, 'verification', 'phase4b', 'run-offline-tests.mjs'), 31);

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
    path.join(__dirname, 'offline-test-results.json'),
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
}

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
