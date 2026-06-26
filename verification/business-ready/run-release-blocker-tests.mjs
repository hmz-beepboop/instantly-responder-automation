// Business-ready RELEASE-BLOCKER - offline test suite.
//
// Pure Node.js (built-ins only). Statically validates the 8 release-blocker
// corrections (A-H) made by verification/business-ready/build-release-blocker-fixes.mjs
// and the manual follow-on edits to the 7 workflow JSON exports,
// apply-business-ready.ps1, run-controlled-live-acceptance.ps1, and
// run-local-runtime-acceptance.ps1; executes the relevant generated
// Code-node jsCode bodies in-process via `new Function(...)` (no n8n, no
// Docker, no network); and re-runs the full regression chain (Phase 4A
// 42/42, Phase 4B 31/31, integration-closure 16/16, business-ready 23/23,
// prior live-path 41/41). Makes no network call and never starts n8n.
// DRY_RUN remains true and LIVE_CAMPAIGNS remains [] throughout.
//
// Usage: node verification/business-ready/run-release-blocker-tests.mjs

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

const config = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'business-ready.config.json'), 'utf8'));

function getNode(wf, name) {
  const node = wf.nodes.find((n) => n.name === name);
  assert(node, `node not found: ${name}`);
  return node;
}
function hasNode(wf, name) {
  return !!wf.nodes.find((n) => n.name === name);
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

record('workflows_parse', 'All 7 workflow JSON files parse as valid JSON', parseError === null, parseError);

// =======================================================================
// Regression counts (5 tests).
// =======================================================================
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

runRegression('regression_phase4a', path.join(ROOT, 'verification', 'phase4a', 'run-offline-tests.mjs'), 42);
runRegression('regression_phase4b', path.join(ROOT, 'verification', 'phase4b', 'run-offline-tests.mjs'), 31);
runRegression('regression_integration_closure', path.join(ROOT, 'verification', 'integration-closure', 'run-offline-tests.mjs'), 16);
runRegression('regression_business_ready', path.join(ROOT, 'verification', 'business-ready', 'run-offline-tests.mjs'), 23);
runRegression('regression_live_path', path.join(ROOT, 'verification', 'business-ready', 'run-live-path-offline-tests.mjs'), 41);

// =======================================================================
// Blocker A: reply success classification (workflow 03) - 4 tests.
// =======================================================================
tryRecord('blocker_a_q_node_is_real_gated_reply_adapter', 'Q is a real httpRequest POST to https://api.instantly.ai/api/v2/emails/reply, gated via credentialPlaceholder hmzInstantlyApi, neverError+fullResponse, continueRegularOutput', () => {
  const q = getNode(wf03, 'Q. POST Reply to Instantly (Gated)');
  assert(q.type === 'n8n-nodes-base.httpRequest', 'Q must be httpRequest');
  assert(q.parameters.method === 'POST', 'Q must be POST');
  assert(q.parameters.url === 'https://api.instantly.ai/api/v2/emails/reply', `Q url mismatch: ${q.parameters.url}`);
  assert(q.credentialPlaceholder === 'hmzInstantlyApi', 'Q must carry credentialPlaceholder hmzInstantlyApi');
  assert(q.parameters.options && q.parameters.options.response && q.parameters.options.response.response.neverError === true, 'Q must set neverError=true');
  assert(q.parameters.options.response.response.fullResponse === true, 'Q must set fullResponse=true');
  assert(q.onError === 'continueRegularOutput', 'Q must continue on error');
});

tryRecord('blocker_a_r_classifies_valid_email_object_as_sent', 'R classifies HTTP 2xx with a valid Email object {id, message_id, thread_id} as terminal SENT, non-ambiguous', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 200, headers: {}, body: { id: 'email-abc', message_id: 'msg-123', thread_id: 'thread-abc' } } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'SENT', `expected SENT, got ${sc.final_state}`);
  assert(sc.ambiguous_side_effect === false, 'SENT must not be ambiguous');
});

tryRecord('blocker_a_r_classifies_invalid_2xx_contract_as_send_uncertain', 'R classifies HTTP 2xx without a valid {id, message_id, thread_id} body as terminal SEND_UNCERTAIN, ambiguous, never blindly retried', () => {
  const out = runCode(wf03, 'R. Classify Send Attempt', [{ json: { statusCode: 200, headers: {}, body: { status: 'sent' } } }], { 'O. Live Send Gate Evaluation (14 Gates)': { live_send_attempts: [] } });
  const sc = out[0].json.send_classification;
  assert(sc.final_state === 'SEND_UNCERTAIN', `expected SEND_UNCERTAIN, got ${sc.final_state}`);
  assert(sc.ambiguous_side_effect === true, 'SEND_UNCERTAIN must be ambiguous');
  assert(sc.retryable === false, 'SEND_UNCERTAIN must never be retried');
});

tryRecord('blocker_a_x2_terminal_carries_email_thread_message_ids', 'X2 builds terminal.result=SENT, send_state=SENT, sent=true, carrying email_id/message_id/thread_id and confirmed cross-checks from the Email object', () => {
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

// =======================================================================
// Blocker B: reconciliation GET contract (workflow 03) - 3 tests.
// =======================================================================
tryRecord('blocker_b_v_node_get_emails_with_required_query_params', 'V is a real httpRequest GET to https://api.instantly.ai/api/v2/emails carrying search/eaccount/lead/email_type=sent/min_timestamp_created/max_timestamp_created/preview_only=false/limit, gated the same as Q', () => {
  const v = getNode(wf03, 'V. Reconciliation Poll (list_emails, Gated)');
  assert(v.type === 'n8n-nodes-base.httpRequest', 'V must be httpRequest');
  assert(v.parameters.method === 'GET', 'V must be GET');
  assert(v.parameters.url === 'https://api.instantly.ai/api/v2/emails', `V url mismatch: ${v.parameters.url}`);
  assert(v.credentialPlaceholder === 'hmzInstantlyApi', 'V must carry credentialPlaceholder hmzInstantlyApi');
  assert(v.onError === 'continueRegularOutput', 'V must continue on error');
  const names = v.parameters.queryParameters.parameters.map((p) => p.name).sort();
  for (const expected of ['search', 'eaccount', 'lead', 'email_type', 'min_timestamp_created', 'max_timestamp_created', 'preview_only', 'limit']) {
    assert(names.includes(expected), `V query params must include ${expected}, got ${JSON.stringify(names)}`);
  }
  const emailType = v.parameters.queryParameters.parameters.find((p) => p.name === 'email_type');
  assert(emailType.value === 'sent', 'V email_type must be "sent"');
  const previewOnly = v.parameters.queryParameters.parameters.find((p) => p.name === 'preview_only');
  assert(previewOnly.value === 'false', 'V preview_only must be "false"');
});

tryRecord('blocker_b_reconciliation_single_match_then_consistent_reconciles', 'W reconciles to SENT_RECONCILED only after 2 consecutive single-match polls of the same id; the first single-match poll is HUMAN_REVIEW_ZERO_MATCHES (uncertain awaiting a second confirming poll)', () => {
  const out1 = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'email-abc' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: [] } });
  const rec1 = out1[0].json.reconciliation;
  assert(rec1.state === 'HUMAN_REVIEW_ZERO_MATCHES', `first poll: expected HUMAN_REVIEW_ZERO_MATCHES, got ${rec1.state}`);
  assert(rec1.polls_taken === 1 && rec1.max_polls === 2, 'first poll bookkeeping mismatch');

  const out2 = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'email-abc' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: out1[0].json.reconciliation_polls } });
  const rec2 = out2[0].json.reconciliation;
  assert(rec2.state === 'SENT_RECONCILED', `second consistent poll: expected SENT_RECONCILED, got ${rec2.state}`);
  assert(rec2.matchId === 'email-abc', 'matchId mismatch');
});

tryRecord('blocker_b_reconciliation_multiple_matches_human_review', 'W reconciles to HUMAN_REVIEW_MULTIPLE_MATCHES when a poll returns more than one match id', () => {
  const out = runCode(wf03, 'W. Process Reconciliation Poll', [{ json: { body: { items: [{ id: 'a' }, { id: 'b' }] } } }], { 'R. Classify Send Attempt': { reconciliation_polls: [] } });
  assert(out[0].json.reconciliation.state === 'HUMAN_REVIEW_MULTIPLE_MATCHES', `expected HUMAN_REVIEW_MULTIPLE_MATCHES, got ${out[0].json.reconciliation.state}`);
});

// =======================================================================
// Blocker C: suppression plan/execution per-action gating (workflow 02)
// - 4 tests.
// =======================================================================
tryRecord('blocker_c_safety_action_plan_four_actions_with_request_contracts', 'F (Safety Action Plan) emits schema_version 1.1 with exactly the 4 named actions, each carrying enabled/executed/verification_status/request_contract, plus requires_canonical_lead', () => {
  const out = runCode(wf02, 'F. Safety Action Plan (Gated Contract, Pre-Approval)', [{ json: {
    nes: { campaign_context: { campaign_id: 'camp-1' }, lead_email: 'lead@example.com' },
    decision: { stop_active_sequence: true, address_suppression_intent: 'GLOBAL_BLOCKLIST' },
  } }]);
  const plan = out[0].json.safety_action_plan;
  assert(plan.schema_version === '1.1', `schema_version mismatch: ${plan.schema_version}`);
  assert(plan.execution_order === 'BEFORE_REPLY_APPROVAL_GATE', 'execution_order mismatch');
  assert('requires_canonical_lead' in plan, 'plan must declare requires_canonical_lead');
  const actionNames = plan.actions.map((a) => a.action).sort();
  assert(
    JSON.stringify(actionNames) === JSON.stringify(['EXACT_EMAIL_BLOCKLIST', 'SOURCE_CAMPAIGN_STOP', 'SUBSEQUENCE_REMOVAL', 'UPDATE_INTEREST_STATUS']),
    `unexpected actions: ${JSON.stringify(actionNames)}`
  );
  for (const action of plan.actions) {
    assert('enabled' in action && 'executed' in action && 'verification_status' in action, `${action.action}: missing enabled/executed/verification_status`);
    assert(action.request_contract && action.request_contract.method && action.request_contract.url, `${action.action}: missing request_contract`);
  }
});

tryRecord('blocker_c_per_action_chain_g0_through_g6_present', 'Workflow 02 has the per-action gated chain G0g/G0h/G0r, G1g-G4g (gate/execute/record per action), G5g/G5h/G5r (blocklist verification), G6 (aggregator); every gate is an IF node and every httpRequest carries credentialPlaceholder hmzInstantlyApi and continueRegularOutput', () => {
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
  for (const name of [
    'G0h. Get Canonical Lead',
    'G1h. Execute SOURCE_CAMPAIGN_STOP',
    'G2h. Execute UPDATE_INTEREST_STATUS',
    'G3h. Execute SUBSEQUENCE_REMOVAL',
    'G4h. Execute EXACT_EMAIL_BLOCKLIST',
    'G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)',
  ]) {
    const n = getNode(wf02, name);
    assert(n.type === 'n8n-nodes-base.httpRequest', `${name} must be httpRequest`);
    assert(n.credentialPlaceholder === 'hmzInstantlyApi', `${name} must carry credentialPlaceholder hmzInstantlyApi`);
    assert(n.onError === 'continueRegularOutput', `${name} must continue on error`);
  }
  assert(getNode(wf02, 'G0r. Record Canonical Lead Retrieval').type === 'n8n-nodes-base.code', 'G0r must be a Code node');
  assert(getNode(wf02, 'G5r. Record EXACT_EMAIL_BLOCKLIST Verification').type === 'n8n-nodes-base.code', 'G5r must be a Code node');
  assert(getNode(wf02, 'G6. Build Suppression Execution Result').type === 'n8n-nodes-base.code', 'G6 must be a Code node');
});

tryRecord('blocker_c_per_action_chain_fully_connected', 'F -> G0g -> ... -> G6 -> E. Output Validation forms one fully-connected chain with no orphaned gate/record nodes (each Gn record feeds the next gate)', () => {
  const conn = wf02.connections;
  const target = (name, idx = 0) => (conn[name] && conn[name].main[idx] ? conn[name].main[idx].map((e) => e.node) : []);

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
  for (const [gate, http, record_, nextGate] of chain) {
    assert(target(gate, 0).includes(http), `${gate} true -> ${http}`);
    assert(target(gate, 1).includes(record_), `${gate} false -> ${record_}`);
    assert(target(http).includes(record_), `${http} -> ${record_}`);
    assert(target(record_).includes(nextGate), `${record_} -> ${nextGate}`);
  }

  assert(target('G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', 0).includes('G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)'), 'G5g true -> G5h');
  assert(target('G5g. EXACT_EMAIL_BLOCKLIST Verification Gate', 1).includes('G5r. Record EXACT_EMAIL_BLOCKLIST Verification'), 'G5g false -> G5r');
  assert(target('G5h. Verify EXACT_EMAIL_BLOCKLIST (block-lists-entries)').includes('G5r. Record EXACT_EMAIL_BLOCKLIST Verification'), 'G5h -> G5r');
  assert(target('G5r. Record EXACT_EMAIL_BLOCKLIST Verification').includes('G6. Build Suppression Execution Result'), 'G5r -> G6');
  assert(target('G6. Build Suppression Execution Result').includes('E. Output Validation'), 'G6 -> E');
});

tryRecord('blocker_c_actions_disabled_by_default_config', 'With the shipped suppression_action_enablement (all false), every planned action has enabled=false and verification_status=SUPPRESSION_ACTION_DISABLED_BY_CONFIG, and execution remains gated offline', () => {
  const out = runCode(wf02, 'F. Safety Action Plan (Gated Contract, Pre-Approval)', [{ json: {
    nes: { campaign_context: { campaign_id: 'camp-1' }, lead_email: 'lead@example.com' },
    decision: { stop_active_sequence: true, address_suppression_intent: 'GLOBAL_BLOCKLIST' },
  } }]);
  const plan = out[0].json.safety_action_plan;
  assert(plan.requires_canonical_lead === false, 'expected requires_canonical_lead=false (config flags all false)');
  for (const action of plan.actions) {
    assert(action.enabled === false, `${action.action}: expected enabled=false (config flags all false)`);
    assert(action.executed === false, `${action.action}: expected executed=false`);
    assert(action.verification_status === 'SUPPRESSION_ACTION_DISABLED_BY_CONFIG', `${action.action}: unexpected verification_status ${action.verification_status}`);
  }
  for (const key of ['source_campaign_stop_enabled', 'interest_status_update_enabled', 'subsequence_removal_enabled', 'exact_email_blocklist_enabled']) {
    assert(config.suppression_action_enablement[key] === false, `config.suppression_action_enablement.${key} must be false in the shipped config`);
  }
});

// =======================================================================
// Blocker D: apply script config-as-source-of-truth, fail-closed - 4 tests.
// =======================================================================
const applyScriptSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'apply-business-ready.ps1'), 'utf8');

tryRecord('blocker_d_apply_script_parses', 'apply-business-ready.ps1 is syntactically valid PowerShell', () => {
  const proc = spawnSync('pwsh', ['-NoProfile', '-Command',
    "$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('verification/business-ready/apply-business-ready.ps1', [ref]$null, [ref]$e); if ($e) { $e | ForEach-Object { Write-Output $_.Message } } else { Write-Output 'OK' }"
  ], { cwd: ROOT, encoding: 'utf8' });
  assert(proc.status === 0, `pwsh exited ${proc.status}: ${proc.stderr}`);
  assert(proc.stdout.includes('OK'), `parse errors: ${proc.stdout}`);
});

tryRecord('blocker_d_assert_owner_inputs_complete_fails_closed', 'Assert-OwnerInputsComplete throws unless config.owner_inputs_status === "COMPLETE" and no <REQUIRED_*> placeholders remain', () => {
  assert(/function Assert-OwnerInputsComplete/.test(applyScriptSrc), 'Assert-OwnerInputsComplete must be defined');
  assert(/owner_inputs_status -ne "COMPLETE"/.test(applyScriptSrc), 'must check owner_inputs_status === COMPLETE');
  assert(/<REQUIRED_\[A-Z0-9_\]\+>/.test(applyScriptSrc), 'must reject remaining <REQUIRED_*> placeholders');
  assert(/Assert-OwnerInputsComplete -Config \$Config/.test(applyScriptSrc), 'Assert-OwnerInputsComplete must be invoked against the loaded config');
});

tryRecord('blocker_d_injected_constants_match_config', 'config/business-ready.config.json is injected as the source of truth for LAUNCH_PROFILE (wf03 O), ALLOWLISTS (wf01 F1), REVIEWER_ALLOWLIST (wf07 M1), and SUPPRESSION_ACTION_ENABLEMENT (wf02 F) via HMZ_INJECT markers', () => {
  const checks = [
    [wf03, 'O. Live Send Gate Evaluation (14 Gates)', 'LAUNCH_PROFILE'],
    [wf01, 'F1. Production Security & Allowlist Gate', 'ALLOWLISTS'],
    [wf07, 'M1. Reviewer Identity Allowlist Check', 'REVIEWER_ALLOWLIST'],
    [wf02, 'F. Safety Action Plan (Gated Contract, Pre-Approval)', 'SUPPRESSION_ACTION_ENABLEMENT'],
  ];
  for (const [wf, nodeName, marker] of checks) {
    const code = getNode(wf, nodeName).parameters.jsCode;
    assert(code.includes(`// HMZ_INJECT_BEGIN:${marker}`) && code.includes(`// HMZ_INJECT_END:${marker}`), `${nodeName} missing HMZ_INJECT markers for ${marker}`);
  }
  assert(/Set-InjectedJsConstant/.test(applyScriptSrc), 'apply script must define/use Set-InjectedJsConstant');
  assert(/Assert-InjectedConstantsMatchConfig/.test(applyScriptSrc), 'apply script must define/use Assert-InjectedConstantsMatchConfig');
  for (const marker of ['LAUNCH_PROFILE', 'ALLOWLISTS', 'REVIEWER_ALLOWLIST', 'SUPPRESSION_ACTION_ENABLEMENT']) {
    assert(applyScriptSrc.includes(`MarkerName = "${marker}"`), `apply script must declare an injection spec for ${marker}`);
  }
});

tryRecord('blocker_d_test_allowed_http_url_covers_per_action_executors', "Test-AllowedHttpUrl in apply-business-ready.ps1 allows G1h-G4h's expression-derived request_contract.url targets (Blocker C) in addition to literal https://api.instantly.ai/... targets, so Assert-WorkflowBodySafe does not reject workflow 02", () => {
  assert(/function Test-AllowedHttpUrl/.test(applyScriptSrc), 'Test-AllowedHttpUrl must be defined');
  assert(/request_contract/.test(applyScriptSrc) && /IsGatedInstantlyAdapterExpression/.test(applyScriptSrc), 'Test-AllowedHttpUrl must recognise expression-derived request_contract.url targets');

  const helperPath = path.join(ROOT, 'tmp', '_release_blocker_apply_funcs.ps1');
  fs.writeFileSync(helperPath, applyScriptSrc.split('\n').slice(0, 588).join('\n'), 'utf8');
  try {
    const proc = spawnSync('pwsh', ['-NoProfile', '-Command',
      `. '${helperPath}'; ` +
      "$wf02 = Get-Content -Raw 'workflows/02_reply_decision_engine_validation.json' | ConvertFrom-Json -Depth 100; " +
      "$bad = @(); foreach ($n in $wf02.nodes) { if ([string]$n.type -eq 'n8n-nodes-base.httpRequest') { $url = [string]$n.parameters.url; if (-not (Test-AllowedHttpUrl -Url $url -Node $n)) { $bad += $n.name } } }; " +
      "if ($bad.Count -eq 0) { Write-Output 'ALL_ALLOWED' } else { Write-Output ('DISALLOWED:' + ($bad -join ',')) }; " +
      "try { Assert-WorkflowBodySafe -Workflow $wf02 -ExpectedName $wf02.name; Write-Output 'BODY_SAFE_OK' } catch { Write-Output ('BODY_SAFE_THREW:' + $_.Exception.Message) }"
    ], { cwd: ROOT, encoding: 'utf8' });
    assert(proc.status === 0, `pwsh exited ${proc.status}: ${proc.stderr}`);
    assert(proc.stdout.includes('ALL_ALLOWED'), `some httpRequest nodes in workflow 02 were disallowed: ${proc.stdout}`);
    assert(proc.stdout.includes('BODY_SAFE_OK'), `Assert-WorkflowBodySafe threw for workflow 02: ${proc.stdout}`);
  } finally {
    fs.rmSync(helperPath, { force: true });
  }
});

// =======================================================================
// Blocker E: controlled-live acceptance invokes n8n, not Instantly directly
// - 3 tests.
// =======================================================================
const controlledLiveSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'run-controlled-live-acceptance.ps1'), 'utf8');

tryRecord('blocker_e_controlled_live_invokes_n8n_not_instantly_directly', "run-controlled-live-acceptance.ps1 uses the real production reply plus authenticated human-approval path, polls n8n/Instantly read-only for the result, and never POSTs directly to /api/v2/emails/reply or to the dev Intake webhook", () => {
  assert(!/Invoke-RestMethod[\s\S]{0,240}-Method\s+POST[\s\S]{0,240}hmz-validation-reply-intake-dev/i.test(controlledLiveSrc), 'must not POST a synthetic NES payload to the Intake dev webhook');
  assert(!/api\/v2\/emails\/reply/.test(controlledLiveSrc), 'must never reference /api/v2/emails/reply directly');
  assert(/send a real reply into the designated/i.test(controlledLiveSrc), 'must instruct the operator to create a genuine owned-inbox reply');
  assert(/approve it EXACTLY ONCE/i.test(controlledLiveSrc), 'must require the production human-approval path');
  assert(/executions\?workflowId=/.test(controlledLiveSrc) || /\/api\/v1\/executions/.test(controlledLiveSrc), 'must poll n8n executions for the Sender workflow');
  assert(/terminal\.send_state|\.terminal/.test(controlledLiveSrc), 'must read terminal.* from the Sender workflow execution');
});

tryRecord('blocker_e_controlled_live_two_modes_and_confirmation_phrase', 'run-controlled-live-acceptance.ps1 supports -PreflightOnly (default, read-only) and -AllowOneControlledReply (requires -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY" typed exactly)', () => {
  assert(/PreflightOnly/.test(controlledLiveSrc), 'must support -PreflightOnly');
  assert(/AllowOneControlledReply/.test(controlledLiveSrc), 'must support -AllowOneControlledReply');
  assert(/RUN-ONE-CONTROLLED-REPLY/.test(controlledLiveSrc), 'must require the literal confirmation phrase RUN-ONE-CONTROLLED-REPLY');
  assert(/ConfirmationPhrase -ne \$RequiredConfirmationPhrase/.test(controlledLiveSrc), 'must compare ConfirmationPhrase against the required phrase');
});

tryRecord('blocker_e_controlled_live_restores_workflow_activation_state', 'run-controlled-live-acceptance.ps1 temporarily activates the six required runtime workflows, keeps the Full Test Harness inactive, and restores safe config plus all-workflows-inactive in finally', () => {
  assert(/\$RuntimeWorkflowNames\s*=\s*@\([\s\S]*Reply Intake[\s\S]*Decision Engine[\s\S]*Reply Sender[\s\S]*Error Handler[\s\S]*Human Approval[\s\S]*SLA Watchdog[\s\S]*\)/.test(controlledLiveSrc), 'must define the six required runtime workflows');
  assert(/\$FullTestHarnessName/.test(controlledLiveSrc), 'must track the Full Test Harness separately');
  assert(/Set-RuntimeWorkflowsActive -Headers \$N8nHeaders -Active \$true/.test(controlledLiveSrc), 'must temporarily activate the runtime workflow set');
  assert(/finally\s*\{/.test(controlledLiveSrc), 'must have a finally block');
  assert(/Restore-SafeState/.test(controlledLiveSrc), 'finally must restore the safe state');
  assert(/Set-RuntimeWorkflowsActive -Headers \$N8nHeaders -Active \$false/.test(controlledLiveSrc), 'safe-state restoration must deactivate the runtime workflow set');
  assert(/RestoreConfig\.dry_run = \$true/.test(controlledLiveSrc), 'restoration must re-assert dry_run=true');
  assert(/live_campaigns["']? -NotePropertyValue @\(\)/.test(controlledLiveSrc), 'restoration must re-assert live_campaigns=[]');
  assert(/allWorkflowsInactiveAfter/.test(controlledLiveSrc), 'final result must verify all workflows inactive');
});

// =======================================================================
// Blocker F: fail-closed preflight (workflow 01 F1) - 3 tests.
// =======================================================================
tryRecord('blocker_f_security_gate_dev_passthrough', 'F1 is a passthrough (checked=false, passed=true) for non-PRODUCTION_WEBHOOK entries, preserving the dev/synthetic/test path', () => {
  const out = runCode(wf01, 'F1. Production Security & Allowlist Gate', [{ json: { entry_source: 'DEV_OR_SYNTHETIC', prefilter: {}, nes: {} } }]);
  const gate = out[0].json.security_gate;
  assert(gate.checked === false, 'dev entries must not be checked');
  assert(gate.passed === true, 'dev entries must pass through');
});

tryRecord('blocker_f_security_gate_empty_allowlists_fails_closed', 'F1 fails closed (passed=false) for PRODUCTION_WEBHOOK entries while ALLOWLISTS is empty (the shipped default); a missing/non-allowlisted workspace_id means campaign and sender allowlisting can never succeed either', () => {
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
  // The shipped F1 node embeds an empty ALLOWLISTS constant (workspace_id: '',
  // campaign_ids: [], connected_sender_eaccounts: []) via the HMZ_INJECT
  // marker; config/business-ready.config.json itself still carries
  // <REQUIRED_*> owner-input placeholders until apply time.
  const code = getNode(wf01, 'F1. Production Security & Allowlist Gate').parameters.jsCode;
  assert(code.includes('// HMZ_INJECT_BEGIN:ALLOWLISTS'), 'F1 must carry the ALLOWLISTS injection marker');
});

tryRecord('blocker_f_security_gate_routing_f1_f2_f3', 'F -> F1 -> F2 -> {G (true) / F3 (false)}; F3 builds terminal.result=REJECTED with reason PRODUCTION_SECURITY_GATE_FAILED', () => {
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

// =======================================================================
// Blocker G: reviewer auth (Basic Auth) + fail-closed reviewer allowlist
// (workflow 07) - 4 tests.
// =======================================================================
tryRecord('blocker_g_review_webhooks_use_basic_auth_credential', 'The production review-form and review-submit webhooks in workflow 07 require Basic Auth via credentialPlaceholder hmzReviewBasicAuth, separate from the unauthenticated dev webhooks', () => {
  for (const name of ['Webhook - Review Form (Production, Gated Path)', 'Webhook - Review Submit (Production, Gated Path)']) {
    const n = getNode(wf07, name);
    assert(n.type === 'n8n-nodes-base.webhook', `${name} must be a webhook node`);
    assert(n.parameters.authentication === 'basicAuth', `${name} must use basicAuth`);
    assert(n.credentialPlaceholder === 'hmzReviewBasicAuth', `${name} must carry credentialPlaceholder hmzReviewBasicAuth`);
  }
  for (const name of ['Webhook - Review Form (Dev)', 'Webhook - Review Submit (Dev)']) {
    const n = getNode(wf07, name);
    assert(!n.credentialPlaceholder, `${name} (dev) must remain unauthenticated`);
  }
});

tryRecord('blocker_g_reviewer_allowlist_fails_closed_when_empty', 'M1 (Reviewer Identity Allowlist Check) is fail-closed: with the shipped empty REVIEWER_ALLOWLIST, configured=false and allowlisted=false (never null/true)', () => {
  const code = getNode(wf07, 'M1. Reviewer Identity Allowlist Check').parameters.jsCode;
  assert(code.includes('// HMZ_INJECT_BEGIN:REVIEWER_ALLOWLIST'), 'M1 must carry the REVIEWER_ALLOWLIST injection marker');
  const out = runCode(wf07, 'M1. Reviewer Identity Allowlist Check', [{ json: { submit_approver_identity: 'reviewer@example.com' } }]);
  const check = out[0].json.reviewer_allowlist_check;
  assert(check.configured === false, 'with empty REVIEWER_ALLOWLIST, configured must be false');
  assert(check.allowlisted === false, 'fail-closed: with configured=false, allowlisted must be false (never null)');
  assert(check.identity === 'reviewer@example.com', 'identity must be carried through');
});

tryRecord('blocker_g_reviewer_allowlist_router_rejects_non_allowlisted', 'M2 (Reviewer Allowlist Router) routes allowlisted=true to N and allowlisted=false to M2b -> N2 (REVIEWER_NOT_ALLOWLISTED), inserted between M(true) and N without altering M(false)', () => {
  const conn = wf07.connections;
  const mConn = conn['M. Submit Token Valid Router'];
  const trueTargets = mConn.main[0].map((e) => e.node);
  assert(trueTargets.includes('M1. Reviewer Identity Allowlist Check'), 'M(true) must point to M1');
  assert(!trueTargets.includes('N. Process Reviewer Decision'), 'M(true) must no longer point directly to N');

  assert(conn['M1. Reviewer Identity Allowlist Check'].main[0].map((e) => e.node).includes('M2. Reviewer Allowlist Router'), 'M1 -> M2');
  const m2 = getNode(wf07, 'M2. Reviewer Allowlist Router');
  assert(m2.type === 'n8n-nodes-base.if', 'M2 must be an IF node');
  assert(conn['M2. Reviewer Allowlist Router'].main[0].map((e) => e.node).includes('N. Process Reviewer Decision'), 'M2 true -> N');
  assert(conn['M2. Reviewer Allowlist Router'].main[1].map((e) => e.node).includes('M2b. Mark Reviewer Not Allowlisted'), 'M2 false -> M2b');
  assert(conn['M2b. Mark Reviewer Not Allowlisted'].main[0].map((e) => e.node).includes('N2. Render Submit Token Error'), 'M2b -> N2');

  const m2bOut = runCode(wf07, 'M2b. Mark Reviewer Not Allowlisted', [{ json: { submit_approver_identity: 'reviewer@example.com' } }]);
  assert(m2bOut[0].json.token_invalid_reason === 'REVIEWER_NOT_ALLOWLISTED', 'M2b must set token_invalid_reason=REVIEWER_NOT_ALLOWLISTED');
});

tryRecord('blocker_g_reviewer_decision_logic_unchanged', 'N (Process Reviewer Decision) still receives submit_action/submit_approver_identity/submit_edited_text/review_case fields untouched by the M1/M2 insertion', () => {
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

// =======================================================================
// Blocker H: error/schedule trigger acceptance in an isolated activation
// window with restore-to-inactive - 3 tests.
// =======================================================================
const localRuntimeSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'run-local-runtime-acceptance.ps1'), 'utf8');

tryRecord('blocker_h_local_runtime_acceptance_covers_error_and_sla_workflows', "run-local-runtime-acceptance.ps1 temporarily activates the SLA Watchdog (in addition to Sender/Error Handler/Human Approval) and, within the same isolated window, runs standalone n8n execute for both the Error Handler's real Error Trigger and the SLA Watchdog's real Schedule Trigger, recording errorTriggerAcceptance/slaWatchdogAcceptance", () => {
  assert(/\$SlaWatchdogId\s*=\s*\$IdsByName\["HMZ - Reply SLA Watchdog - Validation"\]/.test(localRuntimeSrc), 'must resolve the SLA Watchdog workflow id');
  assert(/@\(\$SenderId,\s*\$ErrorId,\s*\$HumanApprovalId,\s*\$SlaWatchdogId\)/.test(localRuntimeSrc), 'temporary activation loop must include the SLA Watchdog');
  assert(/errorTriggerAcceptance\s*=\s*\$null/.test(localRuntimeSrc), 'Results schema must declare errorTriggerAcceptance');
  assert(/slaWatchdogAcceptance\s*=\s*\$null/.test(localRuntimeSrc), 'Results schema must declare slaWatchdogAcceptance');
  assert(/n8n", "execute", "--id", \$ErrorId/.test(localRuntimeSrc), 'must run standalone n8n execute for the Error Handler (real Error Trigger)');
  assert(/n8n", "execute", "--id", \$SlaWatchdogId/.test(localRuntimeSrc), 'must run standalone n8n execute for the SLA Watchdog (real Schedule Trigger)');
  assert(/persisted_error\.errorId/.test(localRuntimeSrc), 'Error Trigger acceptance must check persisted_error.errorId');
  assert(/watchdog_result\.schema_version/.test(localRuntimeSrc), 'SLA Watchdog acceptance must check watchdog_result.schema_version');
  assert(/ErrorTriggerPassed -and \$SlaWatchdogPassed/.test(localRuntimeSrc), 'overallResult must require both new acceptance checks to pass');
});

tryRecord('blocker_h_local_runtime_acceptance_restores_inactive_state', 'run-local-runtime-acceptance.ps1 reverses all temporary activations (including the SLA Watchdog) in a finally block and verifies allWorkflowsInactiveAfter, regardless of success or failure', () => {
  assert(/finally\s*\{/.test(localRuntimeSrc), 'must have a finally block');
  assert(/foreach \(\$WorkflowId in @\(\$TemporaryActiveIds\)/.test(localRuntimeSrc), 'finally block must iterate temporarily-activated workflow ids');
  assert(/Set-N8nWorkflowActivation -WorkflowId \$WorkflowId -Active \$false/.test(localRuntimeSrc), 'finally block must deactivate each temporarily-activated workflow');
  assert(/allWorkflowsInactiveAfter/.test(localRuntimeSrc), 'must record allWorkflowsInactiveAfter');
});

tryRecord('blocker_h_config_safe_defaults_unchanged', 'config/business-ready.config.json remains safe-by-default after all A-H corrections: dry_run=true, live_campaigns=[], operating_mode/launch_profile remain SUPERVISED_VALIDATION, no unattended auto-send', () => {
  assert(config.dry_run === true, 'config.dry_run must remain true');
  assert(Array.isArray(config.live_campaigns) && config.live_campaigns.length === 0, 'config.live_campaigns must remain []');
  assert(config.launch_profile && config.launch_profile.name === 'SUPERVISED_VALIDATION', 'launch_profile.name must be SUPERVISED_VALIDATION');
  assert(config.launch_profile.unattended_auto_send === false, 'launch_profile.unattended_auto_send must be false');
  assert(config.launch_profile.proven_mode === false, 'launch_profile.proven_mode must be false');
  assert(config.live_credential_readiness.instantly === false, 'config.live_credential_readiness.instantly must be false');
});

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
  path.join(__dirname, 'release-blocker-results.json'),
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
