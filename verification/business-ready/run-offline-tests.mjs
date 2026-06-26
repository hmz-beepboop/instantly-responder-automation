// Business-ready VALIDATION profile - offline test suite.
//
// Pure Node.js (built-ins only). Statically inspects the 7 built workflow
// JSON files, the 4 business-ready PowerShell scripts, and
// config/business-ready.config.json; executes selected generated Code-node
// jsCode bodies in-process via `new Function(...)` (no n8n, no Docker, no
// network); and re-runs the phase4a / phase4b / integration-closure
// regression suites as subprocesses. Makes no network call and never starts
// n8n. DRY_RUN remains true and LIVE_CAMPAIGNS remains [] throughout.
//
// Usage: node verification/business-ready/run-offline-tests.mjs

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
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

const CANONICAL_NAMES = {
  '01_reply_intake_validation.json': 'HMZ - Instantly Reply Intake - Validation',
  '02_reply_decision_engine_validation.json': 'HMZ - Reply Decision Engine - Validation',
  '03_reply_sender_validation.json': 'HMZ - Instantly Reply Sender - Validation',
  '04_reply_error_handler_validation.json': 'HMZ - Reply Error Handler - Validation',
  '05_reply_sla_watchdog_validation.json': 'HMZ - Reply SLA Watchdog - Validation',
  '06_reply_full_test_harness_validation.json': 'HMZ - Reply Full Test Harness - Validation',
  '07_reply_human_approval_validation.json': 'HMZ - Reply Human Approval - Validation',
};

const GOOGLE_CHAT_EXPR = '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}';
const SIDECAR_PREFIX = 'http://hmz-send-state:5681';
const REVIEW_TABLE_PLACEHOLDER = '__PLACEHOLDER_REVIEW_CASES_DATA_TABLE_ID__';
const INSTANTLY_API_PREFIX = 'https://api.instantly.ai/';

const results = [];
function record(id, description, passed, details) {
  results.push({ id, description, passed: !!passed, details: details || undefined });
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

// ---------------------------------------------------------------------
// Load all 7 workflows up front.
// ---------------------------------------------------------------------
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

function getNode(file, name) {
  const node = workflows[file].nodes.find((n) => n.name === name);
  assert(node, `${file}: node not found: ${name}`);
  return node;
}

function executeGeneratedCodeNode(file, nodeName, inputItems) {
  const node = getNode(file, nodeName);
  assert(node.type === 'n8n-nodes-base.code', `${file}: ${nodeName} is not a Code node`);
  const $input = { all: () => inputItems };
  const runner = new Function('$input', node.parameters.jsCode);
  return runner($input);
}

function httpRequestNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.httpRequest');
}

function codeNodes(wf) {
  return wf.nodes.filter((n) => n.type === 'n8n-nodes-base.code');
}

// ---------------------------------------------------------------------
// 1. All 7 workflows parse, are inactive, and carry no credentials.
// ---------------------------------------------------------------------
record('workflows_parse', 'All 7 workflow JSON files parse as valid JSON', parseError === null, parseError);

if (parseError === null) {
  const activeOnes = WORKFLOW_FILES.filter((f) => workflows[f].active !== false);
  record('workflows_inactive', 'All 7 workflows have active=false', activeOnes.length === 0, activeOnes.length ? activeOnes : undefined);

  const nameMismatches = WORKFLOW_FILES.filter((f) => workflows[f].name !== CANONICAL_NAMES[f]);
  record('workflow_names_canonical', 'Each workflow file has its expected canonical name', nameMismatches.length === 0, nameMismatches.length ? nameMismatches : undefined);

  const credentialNodes = [];
  for (const f of WORKFLOW_FILES) {
    for (const n of workflows[f].nodes) {
      if (n.credentials) credentialNodes.push(`${f}: ${n.name}`);
    }
  }
  record('no_credentials', 'No node in any of the 7 workflows has a credentials field', credentialNodes.length === 0, credentialNodes.length ? credentialNodes : undefined);

  // -------------------------------------------------------------------
  // 2. No mock-classifier remnants in workflow 02.
  // -------------------------------------------------------------------
  const wf02Text = JSON.stringify(workflows['02_reply_decision_engine_validation.json']);
  const hasMockClassifier = /mockSemanticClassify|Mock Semantic Classifier|"model"\s*:\s*"mock"/.test(wf02Text);
  const hasDeterministicClassifier = wf02Text.includes('deterministicHeuristicClassify') && wf02Text.includes('deterministic-heuristic-1.0');
  record(
    'no_mock_classifier_remnants',
    'Workflow 02 contains no mock-classifier naming and uses the deterministic-heuristic-1.0 classifier',
    !hasMockClassifier && hasDeterministicClassifier,
    { hasMockClassifier, hasDeterministicClassifier }
  );

  // -------------------------------------------------------------------
  // 3. Non-English reply routes to AMBIGUOUS / NON_ENGLISH_FALLBACK_T15.
  // -------------------------------------------------------------------
  try {
    const out = executeGeneratedCodeNode('02_reply_decision_engine_validation.json', 'B. Deterministic Reply Classifier', [
      {
        json: {
          deterministic: { flags: {}, operational_flags: {}, noop_match: false, deterministic_match: false },
          nes: {
            reply: { subject: 'Bonjour', text: 'Merci beaucoup, ce n\'est pas pour nous.', language: 'fr' },
            campaign_context: {},
            policy_version: 'policy-HMZ-1.2',
          },
        },
      },
    ]);
    const classifier = out[0].json.classifier;
    assert(classifier.category === 'AMBIGUOUS', `expected AMBIGUOUS, got ${classifier.category}`);
    assert(classifier.confidence === 0.3, `expected confidence 0.3, got ${classifier.confidence}`);
    assert(classifier.decision_trace.path === 'NON_ENGLISH_FALLBACK_T15', `expected NON_ENGLISH_FALLBACK_T15, got ${classifier.decision_trace.path}`);
    assert(classifier.classifier_version === 'deterministic-heuristic-1.0', 'classifier_version mismatch');

    // English path still reaches the deterministic heuristic classifier.
    const outEn = executeGeneratedCodeNode('02_reply_decision_engine_validation.json', 'B. Deterministic Reply Classifier', [
      {
        json: {
          deterministic: { flags: {}, operational_flags: {}, noop_match: false, deterministic_match: false },
          nes: {
            reply: { subject: 'Re: Intro', text: 'Sounds interesting, tell me more.', language: 'en' },
            campaign_context: {},
            policy_version: 'policy-HMZ-1.2',
          },
        },
      },
    ]);
    const classifierEn = outEn[0].json.classifier;
    assert(classifierEn.category === 'POSITIVE_INTEREST', `expected POSITIVE_INTEREST, got ${classifierEn.category}`);
    assert(classifierEn.decision_trace.path === 'DETERMINISTIC_HEURISTIC_CLASSIFIER', `expected DETERMINISTIC_HEURISTIC_CLASSIFIER, got ${classifierEn.decision_trace.path}`);

    record('non_english_reply_routes_to_t15', 'A non-English reply is classified AMBIGUOUS via NON_ENGLISH_FALLBACK_T15, while an English reply reaches the deterministic heuristic classifier', true);
  } catch (err) {
    record('non_english_reply_routes_to_t15', 'A non-English reply is classified AMBIGUOUS via NON_ENGLISH_FALLBACK_T15, while an English reply reaches the deterministic heuristic classifier', false, err.message);
  }

  // -------------------------------------------------------------------
  // 4. Safety action plan: built pre-approval, independent of approval.
  // -------------------------------------------------------------------
  try {
    const outRequired = executeGeneratedCodeNode('02_reply_decision_engine_validation.json', 'F. Safety Action Plan (Gated Contract, Pre-Approval)', [
      {
        json: {
          nes: { campaign_context: { campaign_id: 'camp-1' }, lead_email: 'lead@example.com' },
          decision: { stop_active_sequence: true, address_suppression_intent: 'GLOBAL_BLOCKLIST', category: 'NOT_INTERESTED' },
          // Deliberately no `approval` or `gates` field: the plan must not
          // depend on the prospect-reply human-approval gate.
        },
      },
    ]);
    const plan = outRequired[0].json.safety_action_plan;
    assert(plan.schema_version === '1.1', 'schema_version mismatch');
    assert(plan.required === true, 'expected required=true when suppression actions apply');
    assert(plan.requires_canonical_lead === false, 'expected requires_canonical_lead=false (config flags all false, so no enabled action requires the canonical lead id)');
    assert(plan.execution_order === 'BEFORE_REPLY_APPROVAL_GATE', 'execution_order mismatch');
    const actionNames = plan.actions.map((a) => a.action).sort();
    assert(
      JSON.stringify(actionNames) === JSON.stringify(['EXACT_EMAIL_BLOCKLIST', 'SOURCE_CAMPAIGN_STOP', 'SUBSEQUENCE_REMOVAL', 'UPDATE_INTEREST_STATUS']),
      `unexpected actions: ${JSON.stringify(actionNames)}`
    );
    for (const action of plan.actions) {
      assert(action.enabled === false, `${action.action}: expected enabled=false (config flags all false)`);
      assert(action.executed === false, `${action.action}: expected executed=false`);
      assert(action.verification_status === 'SUPPRESSION_ACTION_DISABLED_BY_CONFIG', `${action.action}: unexpected verification_status ${action.verification_status}`);
      assert(action.request_contract && action.request_contract.method && action.request_contract.url, `${action.action}: missing request_contract`);
    }
    assert(outRequired[0].json.approval === undefined, 'safety action plan output must not synthesize an approval field');

    const outNotRequired = executeGeneratedCodeNode('02_reply_decision_engine_validation.json', 'F. Safety Action Plan (Gated Contract, Pre-Approval)', [
      { json: { nes: {}, decision: {} } },
    ]);
    const planEmpty = outNotRequired[0].json.safety_action_plan;
    assert(planEmpty.required === false, 'expected required=false when no suppression action applies');
    assert(planEmpty.actions.length === 0, 'expected zero actions when no suppression action applies');

    record('safety_action_plan_pre_approval_independent', 'F. Safety Action Plan computes required suppression actions with a gated, unexecuted request contract, independent of the reply-approval gate', true);
  } catch (err) {
    record('safety_action_plan_pre_approval_independent', 'F. Safety Action Plan computes required suppression actions with a gated, unexecuted request contract, independent of the reply-approval gate', false, err.message);
  }

  // -------------------------------------------------------------------
  // 5. Live adapter additional_contracts cover the 5 extra V2 endpoints.
  // -------------------------------------------------------------------
  try {
    const out = executeGeneratedCodeNode('03_reply_sender_validation.json', 'N. Live Adapter Contract (Validation-Only, Unreachable)', [
      {
        json: {
          nes: {
            threading: { reply_to_uuid: 'uuid-1' },
            reply: { subject: 'Hello' },
            campaign_context: { campaign_id: 'camp-1' },
            lead_email: 'lead@example.com',
          },
          draft: {},
        },
      },
    ]);
    const ac = out[0].json.live_adapter_contract.additional_contracts;
    assert(ac.update_interest_status.method === 'POST' && /update-interest-status/.test(ac.update_interest_status.url), 'update_interest_status contract');
    assert(ac.remove_subsequence.method === 'POST' && /subsequence\/remove/.test(ac.remove_subsequence.url), 'remove_subsequence contract');
    assert(ac.add_to_blocklist.method === 'POST' && /blocklist/.test(ac.add_to_blocklist.url), 'add_to_blocklist contract');
    assert(ac.get_email.method === 'GET' && /emails\/uuid-1/.test(ac.get_email.url), 'get_email contract');
    assert(ac.list_emails.method === 'POST' && /emails\/list/.test(ac.list_emails.url), 'list_emails contract');
    assert(out[0].json.terminal.reason === 'LIVE_ADAPTER_UNREACHABLE_IN_VALIDATION', 'terminal reason mismatch');
    record('live_adapter_additional_contracts', 'The real (gated/unreachable) Instantly V2 adapter contract includes update-interest-status, remove-subsequence, add-to-blocklist, get-email, and list-emails', true);
  } catch (err) {
    record('live_adapter_additional_contracts', 'The real (gated/unreachable) Instantly V2 adapter contract includes update-interest-status, remove-subsequence, add-to-blocklist, get-email, and list-emails', false, err.message);
  }

  // -------------------------------------------------------------------
  // 6 / 7. Reply Sender approval gate blocks without approval and passes
  // via the Human Approval handoff mapping.
  // -------------------------------------------------------------------
  function runSenderGates(senderInput) {
    const afterA = executeGeneratedCodeNode('03_reply_sender_validation.json', 'A. Validate Decision Engine Output', [{ json: senderInput }]);
    return executeGeneratedCodeNode('03_reply_sender_validation.json', 'B. Re-run Send & Suppression Gates', [{ json: afterA[0].json }]);
  }

  const baseSenderInput = () => ({
    validation: { valid: true },
    nes: {
      threading: { reply_to_uuid: 'uuid-1' },
      eaccount: 'sender@example.com',
      lead_email: 'lead@example.com',
      intake_id: 'intake-001',
      campaign_id: 'camp-1',
    },
    decision: { reply_permitted: true, human_review_required: true },
    draft: { draft_text: 'Hello, thanks for the reply.' },
  });

  try {
    const blockedInput = { ...baseSenderInput(), approval: {} };
    const blocked = runSenderGates(blockedInput);
    const gatesBlocked = blocked[0].json.gates;
    assert(gatesBlocked.approval_gate_passed === false, 'expected approval_gate_passed=false');
    assert(gatesBlocked.passed === false, 'expected overall gates.passed=false');
    assert(gatesBlocked.reasons.includes('approval_missing'), 'expected reasons to include approval_missing');
    record('approval_gate_blocks_without_durable_approval', 'Without a durable approval record, the Reply Sender gates block with approval_gate_passed=false and reasons including approval_missing', true);
  } catch (err) {
    record('approval_gate_blocks_without_durable_approval', 'Without a durable approval record, the Reply Sender gates block with approval_gate_passed=false and reasons including approval_missing', false, err.message);
  }

  try {
    // Simulate workflow 07's "Q. Reply Sender Handoff (Approved)" workflowInputs
    // mapping: nes/decision/validation pass through, draft.draft_text is
    // overridden by the reviewer's edited final_reply_text, and approval is
    // synthesized from the durable review_case.
    const caseInput = { ...baseSenderInput(), draft: { draft_text: 'Original AI draft', cta_link: 'https://example.com/book' } };
    const reviewCase = {
      final_reply_text: 'Edited reply text from reviewer',
      approver_identity: 'reviewer@example.com',
      approved_at: '2026-06-15T12:00:00.000Z',
      case_id: 'case-abc123',
      policy_version: 'policy-HMZ-1.2',
    };
    const mapped = {
      nes: caseInput.nes,
      decision: caseInput.decision,
      draft: { ...caseInput.draft, draft_text: reviewCase.final_reply_text },
      validation: caseInput.validation,
      approval: {
        approved: true,
        approver_identity: reviewCase.approver_identity,
        approved_at: reviewCase.approved_at,
        case_id: reviewCase.case_id,
        policy_version: reviewCase.policy_version,
      },
    };
    const passedResult = runSenderGates(mapped);
    const gatesPassed = passedResult[0].json.gates;
    assert(passedResult[0].json.sender_validation.valid === true, 'sender_validation must be valid');
    assert(gatesPassed.approval_gate_passed === true, 'expected approval_gate_passed=true');
    assert(gatesPassed.passed === true, `expected overall gates.passed=true, reasons=${JSON.stringify(gatesPassed.reasons)}`);
    assert(passedResult[0].json.draft.draft_text === 'Edited reply text from reviewer', 'draft.draft_text must carry the reviewer-edited text');
    record('approval_gate_passes_via_human_approval_handoff', 'The Human Approval handoff mapping (Q) populates approval.approved=true and the reviewer-edited draft text, and the Reply Sender gates pass (gates.passed=true)', true);
  } catch (err) {
    record('approval_gate_passes_via_human_approval_handoff', 'The Human Approval handoff mapping (Q) populates approval.approved=true and the reviewer-edited draft text, and the Reply Sender gates pass (gates.passed=true)', false, err.message);
  }

  // -------------------------------------------------------------------
  // 8. Review token lifecycle: not found / wrong / expired / already
  // decided / valid (one-time).
  // -------------------------------------------------------------------
  try {
    const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();

    function validateGet(caseRow, query) {
      const out = executeGeneratedCodeNode('07_reply_human_approval_validation.json', 'H. Validate Review Token (GET)', [
        { json: { query, case_row: caseRow } },
      ]);
      return out[0].json;
    }

    const notFound = validateGet(null, { case: 'case-x', token: 'tok' });
    assert(notFound.token_valid === false && notFound.token_invalid_reason === 'CASE_NOT_FOUND', 'expected CASE_NOT_FOUND');

    const wrongToken = validateGet({ token: 'real-token', status: 'NEW', token_expires_at: future }, { case: 'case-x', token: 'wrong' });
    assert(wrongToken.token_valid === false && wrongToken.token_invalid_reason === 'WRONG_TOKEN', 'expected WRONG_TOKEN');

    const expired = validateGet({ token: 'tok', status: 'NEW', token_expires_at: past }, { case: 'case-x', token: 'tok' });
    assert(expired.token_valid === false && expired.token_invalid_reason === 'EXPIRED', 'expected EXPIRED');

    const alreadyDecided = validateGet({ token: 'tok', status: 'RESPONSE_APPROVED', token_expires_at: future }, { case: 'case-x', token: 'tok' });
    assert(alreadyDecided.token_valid === false && alreadyDecided.token_invalid_reason === 'ALREADY_DECIDED', 'expected ALREADY_DECIDED');

    const valid = validateGet({ token: 'tok', status: 'NEW', token_expires_at: future }, { case: 'case-x', token: 'tok' });
    assert(valid.token_valid === true && valid.token_invalid_reason === 'OK', 'expected a valid one-time token to pass');

    record('review_token_lifecycle', 'The review token validator correctly distinguishes not-found, wrong-token, expired, already-decided, and valid one-time tokens', true);
  } catch (err) {
    record('review_token_lifecycle', 'The review token validator correctly distinguishes not-found, wrong-token, expired, already-decided, and valid one-time tokens', false, err.message);
  }

  // -------------------------------------------------------------------
  // 9. Reviewer decision: approve (with edit + identity persisted),
  // deny (with reason), and blocked-missing-variables.
  // -------------------------------------------------------------------
  try {
    function processDecision(reviewCase, submit) {
      const out = executeGeneratedCodeNode('07_reply_human_approval_validation.json', 'N. Process Reviewer Decision', [
        { json: { review_case: reviewCase, ...submit } },
      ]);
      return out[0].json;
    }

    const approved = processDecision(
      { status: 'NEW', blocked_variables: [], draft_text: 'Original draft' },
      { submit_action: 'approve', submit_approver_identity: 'alice@example.com', submit_edited_text: 'Edited reply', submit_denial_reason: '' }
    );
    assert(approved.final_action === 'approve', 'expected final_action=approve');
    assert(approved.review_case.status === 'RESPONSE_APPROVED', 'expected status=RESPONSE_APPROVED');
    assert(approved.review_case.final_reply_text === 'Edited reply', 'expected final_reply_text to carry the reviewer edit');
    assert(approved.review_case.approver_identity === 'alice@example.com', 'expected approver_identity to persist');
    assert(typeof approved.review_case.approved_at === 'string' && approved.review_case.approved_at.length > 0, 'expected approved_at to be set');

    const denied = processDecision(
      { status: 'NEW', blocked_variables: [], draft_text: 'Original draft' },
      { submit_action: 'deny', submit_approver_identity: 'bob@example.com', submit_edited_text: '', submit_denial_reason: 'Lead asked to be removed' }
    );
    assert(denied.final_action === 'deny', 'expected final_action=deny');
    assert(denied.review_case.status === 'NO_REPLY_REQUIRED', 'expected status=NO_REPLY_REQUIRED');
    assert(denied.review_case.decision_payload.reason === 'Lead asked to be removed', 'expected denial reason to persist');

    const blocked = processDecision(
      { status: 'NEW', blocked_variables: ['bookingLink'], draft_text: 'Original draft' },
      { submit_action: 'approve', submit_approver_identity: 'carol@example.com', submit_edited_text: 'Edited reply', submit_denial_reason: '' }
    );
    assert(blocked.final_action === 'blocked', 'expected final_action=blocked when blocked_variables is non-empty');
    assert(blocked.review_case.status === 'BLOCKED_MISSING_VARIABLES', 'expected status=BLOCKED_MISSING_VARIABLES');
    assert(blocked.review_case.decision_payload.blocked_variables.includes('bookingLink'), 'expected blocked_variables to be recorded');

    record('reviewer_decision_approve_edit_identity_deny_blocked', 'Reviewer decisions correctly handle approve (with edited text and approver identity persisted), deny (with reason), and blocked-missing-variables', true);
  } catch (err) {
    record('reviewer_decision_approve_edit_identity_deny_blocked', 'Reviewer decisions correctly handle approve (with edited text and approver identity persisted), deny (with reason), and blocked-missing-variables', false, err.message);
  }

  // -------------------------------------------------------------------
  // 10. Fixed-template booking-link blocking, and human-only editable
  // draft, via "A. Build Review Case Record".
  // -------------------------------------------------------------------
  try {
    function buildReviewCase(caseInput) {
      const out = executeGeneratedCodeNode('07_reply_human_approval_validation.json', 'A. Build Review Case Record', [
        { json: { case_input: caseInput } },
      ]);
      return out[0].json.review_case;
    }

    // Fixed-template booking scenario with no sender mapping configured for
    // this eaccount -> bookingLink (and senderName) must be blocked.
    const bookingCase = buildReviewCase({
      intake_id: 'intake-booking-001',
      policy_version: 'policy-HMZ-1.2',
      nes: { eaccount: 'unmapped-sender@example.com', reply: { subject: 'Sure, send a link', text: 'Sure, send a link', snippet: 'Sure, send a link' }, campaign_context: {} },
      decision: { category: 'BOOKING_REQUEST', reply_mode: 'FIXED_TEMPLATE_APPROVAL', reply_template_id: 'T1_SCENARIO_A_BOOKING' },
      draft: { draft_text: 'Here is the booking link: [[bookingLink]]' },
    });
    assert(bookingCase.reply_mode === 'FIXED_TEMPLATE_APPROVAL', 'expected reply_mode=FIXED_TEMPLATE_APPROVAL');
    assert(bookingCase.blocked_variables.includes('bookingLink'), `expected bookingLink to be blocked, got ${JSON.stringify(bookingCase.blocked_variables)}`);

    // Human-only reply: blocked_variables must be empty regardless of
    // sender mapping, and the draft text is carried through verbatim for
    // the reviewer to edit.
    const humanOnlyCase = buildReviewCase({
      intake_id: 'intake-human-001',
      policy_version: 'policy-HMZ-1.2',
      nes: { eaccount: 'unmapped-sender@example.com', reply: { subject: 'A legal question', text: 'We may need to discuss a contract issue.', snippet: 'We may need to discuss a contract issue.' }, campaign_context: {} },
      decision: { category: 'LEGAL_PRIVACY_OR_COMPLAINT' },
      draft: { draft_text: '' },
    });
    assert(humanOnlyCase.reply_mode === 'HUMAN_ONLY', `expected reply_mode=HUMAN_ONLY, got ${humanOnlyCase.reply_mode}`);
    assert(humanOnlyCase.blocked_variables.length === 0, 'expected no blocked variables for a HUMAN_ONLY case');

    // The review form renders the draft text into an editable textarea.
    const formOut = executeGeneratedCodeNode('07_reply_human_approval_validation.json', 'J. Render Review Form HTML', [
      { json: { review_case: { ...humanOnlyCase, draft_text: 'Reviewer drafts the reply here', case_id: 'case-human-001', token: 'tok' } } },
    ]);
    const html = formOut[0].json.html;
    assert(html.includes('name="edited_reply_text"'), 'expected an editable textarea named edited_reply_text');
    assert(html.includes('Reviewer drafts the reply here'), 'expected the draft text to be pre-filled in the form');

    record('fixed_template_booking_link_blocks_and_human_only_editable', 'A fixed-template booking reply with no sender mapping blocks on bookingLink, while a HUMAN_ONLY reply has no blocked variables and renders an editable draft textarea', true);
  } catch (err) {
    record('fixed_template_booking_link_blocks_and_human_only_editable', 'A fixed-template booking reply with no sender mapping blocks on bookingLink, while a HUMAN_ONLY reply has no blocked variables and renders an editable draft textarea', false, err.message);
  }

  // -------------------------------------------------------------------
  // 11. Review case_id is idempotent per (intake_id, policy_version).
  // -------------------------------------------------------------------
  try {
    function caseIdFor(intakeId, policyVersion) {
      const out = executeGeneratedCodeNode('07_reply_human_approval_validation.json', 'A. Build Review Case Record', [
        { json: { case_input: { intake_id: intakeId, policy_version: policyVersion, nes: {}, decision: {}, draft: {} } } },
      ]);
      return out[0].json.review_case.case_id;
    }
    const idA1 = caseIdFor('intake-100', 'policy-HMZ-1.2');
    const idA2 = caseIdFor('intake-100', 'policy-HMZ-1.2');
    const idB = caseIdFor('intake-200', 'policy-HMZ-1.2');
    assert(idA1 === idA2, 'expected the same (intake_id, policy_version) to yield the same case_id');
    assert(idA1 !== idB, 'expected a different intake_id to yield a different case_id');
    assert(/^case-[0-9a-f]{8}$/.test(idA1), `expected case-<hex8> format, got ${idA1}`);
    record('review_case_id_idempotent', 'review_case.case_id is a deterministic, idempotent hash of (intake_id, policy_version)', true);
  } catch (err) {
    record('review_case_id_idempotent', 'review_case.case_id is a deterministic, idempotent hash of (intake_id, policy_version)', false, err.message);
  }

  // -------------------------------------------------------------------
  // 12. Static: approval handoff field mapping (Q node) and intake
  // routing to Human Approval (H node).
  // -------------------------------------------------------------------
  try {
    const q = getNode('07_reply_human_approval_validation.json', 'Q. Reply Sender Handoff (Approved)');
    assert(q.type === 'n8n-nodes-base.executeWorkflow', 'Q must be an Execute Sub-workflow node');
    const mapping = q.parameters.workflowInputs.value;
    assert(mapping.nes === '={{ $json.case_input.nes }}', 'Q.nes mapping mismatch');
    assert(mapping.decision === '={{ $json.case_input.decision }}', 'Q.decision mapping mismatch');
    assert(/final_reply_text/.test(mapping.draft), 'Q.draft mapping must use review_case.final_reply_text');
    assert(/case_input\.validation/.test(mapping.validation), 'Q.validation mapping mismatch');
    assert(/approved:\s*true/.test(mapping.approval), 'Q.approval mapping must set approved: true');
    assert(/approver_identity/.test(mapping.approval) && /approved_at/.test(mapping.approval) && /case_id/.test(mapping.approval) && /policy_version/.test(mapping.approval), 'Q.approval mapping must carry approver_identity/approved_at/case_id/policy_version');
    assert(q.parameters.workflowId.value === '__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__', 'Q must target the Reply Sender placeholder');

    const h = getNode('01_reply_intake_validation.json', 'H. Human Approval Handoff');
    assert(h.type === 'n8n-nodes-base.executeWorkflow', 'H must be an Execute Sub-workflow node');
    assert(h.parameters.workflowId.value === '__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__', 'H must target the Human Approval placeholder');
    assert(h.parameters.workflowId.cachedResultName === 'HMZ - Reply Human Approval - Validation', 'H cachedResultName mismatch');
    assert(h.parameters.workflowInputs.value.case_input === '={{ $json }}', 'H must pass the full intake item through as case_input');

    record('approval_handoff_field_mapping_and_intake_routing', 'Workflow 07\'s Reply Sender handoff maps nes/decision/validation through and synthesizes approval.approved=true with the edited draft text; Intake\'s H node routes to the Human Approval workflow', true);
  } catch (err) {
    record('approval_handoff_field_mapping_and_intake_routing', 'Workflow 07\'s Reply Sender handoff maps nes/decision/validation through and synthesizes approval.approved=true with the edited draft text; Intake\'s H node routes to the Human Approval workflow', false, err.message);
  }

  // -------------------------------------------------------------------
  // 13. Gated Google Chat notifications in 04 / 05 / 07.
  // -------------------------------------------------------------------
  try {
    const wf04 = workflows['04_reply_error_handler_validation.json'];
    const wf05 = workflows['05_reply_sla_watchdog_validation.json'];
    const wf07 = workflows['07_reply_human_approval_validation.json'];

    const wf04Chat = httpRequestNodes(wf04).find((n) => n.parameters.url === GOOGLE_CHAT_EXPR);
    const wf05Chat = httpRequestNodes(wf05).find((n) => n.parameters.url === GOOGLE_CHAT_EXPR);
    const wf07Chat = httpRequestNodes(wf07).find((n) => n.parameters.url === GOOGLE_CHAT_EXPR);

    assert(wf04Chat, 'workflow 04 must have a gated Google Chat httpRequest node');
    assert(wf05Chat, 'workflow 05 must have a gated Google Chat httpRequest node');
    assert(wf07Chat, 'workflow 07 must have a gated Google Chat httpRequest node');

    // Error Handler is terminal: must not loop back to itself on failure.
    assert(wf04Chat.onError === 'continueRegularOutput', 'workflow 04 Google Chat node must continue on error (terminal workflow)');
    // SLA Watchdog: failures must propagate to settings.errorWorkflow (Error Handler).
    assert(wf05Chat.onError === undefined, 'workflow 05 Google Chat node must not set onError (errors propagate to the Error Handler)');
    assert((wf05.settings || {}).errorWorkflow === '__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__', 'workflow 05 must route errors to the Error Handler');

    // Every httpRequest target across all 7 workflows is sidecar or gated Google Chat.
    // Every httpRequest target across all 7 workflows is the sidecar, the
    // gated Google Chat env var, or a gated (credentialPlaceholder
    // "hmzInstantlyApi", onError continueRegularOutput) live-path call to
    // the real Instantly API - the latter introduced by
    // build-live-path.mjs and remaining unreachable unless every one of
    // the 14 live-send gates (workflow 03) or the suppression-enablement
    // router (workflow 02) passes, which cannot happen with the shipped
    // (empty) launch profile.
    const badTargets = [];
    for (const f of WORKFLOW_FILES) {
      for (const n of httpRequestNodes(workflows[f])) {
        const url = (n.parameters && n.parameters.url) || '';
        const isGatedInstantlyCall =
          url.startsWith(INSTANTLY_API_PREFIX) &&
          n.credentialPlaceholder === 'hmzInstantlyApi' &&
          n.onError === 'continueRegularOutput';
        // Per-action suppression executors (workflow 02, G1h-G4h) derive
        // their URL at runtime from
        // safety_action_plan.actions[].request_contract.url, which is
        // itself always an https://api.instantly.ai/... endpoint built by
        // node F (buildSafetyActionPlan); they are gated the same way.
        const isGatedInstantlyCallExpression =
          url.startsWith('={{') &&
          url.includes('request_contract') &&
          url.includes('.url') &&
          n.credentialPlaceholder === 'hmzInstantlyApi' &&
          n.onError === 'continueRegularOutput';
        const ok = url.startsWith(SIDECAR_PREFIX) || url === GOOGLE_CHAT_EXPR || isGatedInstantlyCall || isGatedInstantlyCallExpression;
        if (!ok) badTargets.push(`${f}: ${n.name} -> ${url}`);
      }
    }
    assert(badTargets.length === 0, `unexpected HTTP targets: ${JSON.stringify(badTargets)}`);

    record('gated_google_chat_notifications', 'Workflows 04, 05, and 07 each contain a gated Google Chat httpRequest node ($env.GOOGLE_CHAT_WEBHOOK_URL); any other HTTP target is either the internal sidecar or a gated, credentialPlaceholder-marked live-path call to api.instantly.ai introduced by build-live-path.mjs', true);
  } catch (err) {
    record('gated_google_chat_notifications', 'Workflows 04, 05, and 07 each contain a gated Google Chat httpRequest node ($env.GOOGLE_CHAT_WEBHOOK_URL); any other HTTP target is either the internal sidecar or a gated, credentialPlaceholder-marked live-path call to api.instantly.ai introduced by build-live-path.mjs', false, err.message);
  }

  // -------------------------------------------------------------------
  // 14. Workflow 07 Data Table placeholder is consistent and patchable.
  // -------------------------------------------------------------------
  try {
    const wf07 = workflows['07_reply_human_approval_validation.json'];
    const dataTableNodes = wf07.nodes.filter((n) => n.type === 'n8n-nodes-base.dataTable');
    assert(dataTableNodes.length === 5, `expected 5 Data Table nodes in workflow 07, found ${dataTableNodes.length}`);
    const mismatched = dataTableNodes.filter((n) => n.parameters.dataTableId.value !== REVIEW_TABLE_PLACEHOLDER);
    assert(mismatched.length === 0, `all 5 Data Table nodes must reference ${REVIEW_TABLE_PLACEHOLDER}`);
    record('workflow07_data_table_placeholder_consistent', 'All 5 Data Table nodes in workflow 07 reference a single patchable __PLACEHOLDER_REVIEW_CASES_DATA_TABLE_ID__', true);
  } catch (err) {
    record('workflow07_data_table_placeholder_consistent', 'All 5 Data Table nodes in workflow 07 reference a single patchable __PLACEHOLDER_REVIEW_CASES_DATA_TABLE_ID__', false, err.message);
  }

  // -------------------------------------------------------------------
  // 15. All embedded Code nodes across all 7 workflows compile.
  // -------------------------------------------------------------------
  try {
    const codeErrors = [];
    for (const f of WORKFLOW_FILES) {
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
    assert(codeErrors.length === 0, JSON.stringify(codeErrors));
    record('embedded_code_nodes_compile', 'Every Code node jsCode body in all 7 workflows is syntactically valid JavaScript', true);
  } catch (err) {
    record('embedded_code_nodes_compile', 'Every Code node jsCode body in all 7 workflows is syntactically valid JavaScript', false, err.message);
  }
}

// ---------------------------------------------------------------------
// 16. config/business-ready.config.json safe defaults.
// ---------------------------------------------------------------------
try {
  const config = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'business-ready.config.json'), 'utf8'));
  assert(config.dry_run === true, 'config.dry_run must be true');
  assert(Array.isArray(config.live_campaigns) && config.live_campaigns.length === 0, 'config.live_campaigns must be []');
  const supp = config.suppression_action_enablement || {};
  for (const key of ['source_campaign_stop_enabled', 'interest_status_update_enabled', 'subsequence_removal_enabled', 'exact_email_blocklist_enabled']) {
    assert(supp[key] === false, `config.suppression_action_enablement.${key} must be false`);
  }
  assert(config.review && config.review.google_chat_configured === false, 'config.review.google_chat_configured must be false');
  const ready = config.live_credential_readiness || {};
  for (const key of ['instantly_api_key_bound', 'n8n_api_key_bound', 'ready_for_controlled_live_test']) {
    assert(ready[key] === false, `config.live_credential_readiness.${key} must be false`);
  }
  assert(typeof config.owner_inputs_status === 'string' && /INCOMPLETE/.test(config.owner_inputs_status), 'config.owner_inputs_status must record the INCOMPLETE state');
  record('config_safe_defaults', 'config/business-ready.config.json keeps DRY_RUN true, LIVE_CAMPAIGNS empty, all suppression/live-credential flags false, Google Chat not configured, and records owner inputs as incomplete', true);
} catch (err) {
  record('config_safe_defaults', 'config/business-ready.config.json keeps DRY_RUN true, LIVE_CAMPAIGNS empty, all suppression/live-credential flags false, Google Chat not configured, and records owner inputs as incomplete', false, err.message);
}

// ---------------------------------------------------------------------
// 17. The 4 business-ready PowerShell scripts exist and are fail-closed.
// ---------------------------------------------------------------------
try {
  const psDir = __dirname;
  const scripts = {
    apply: 'apply-business-ready.ps1',
    localRuntime: 'run-local-runtime-acceptance.ps1',
    controlledLive: 'run-controlled-live-acceptance.ps1',
    rollback: 'rollback-business-ready.ps1',
  };
  const texts = {};
  for (const [key, file] of Object.entries(scripts)) {
    const p = path.join(psDir, file);
    assert(fs.existsSync(p), `missing script: ${file}`);
    texts[key] = fs.readFileSync(p, 'utf8');
  }

  const applyChecks = {
    requires_n8n_api_key: /HMZ_N8N_API_KEY/.test(texts.apply),
    requires_data_table_id: /HMZ_REVIEW_CASES_DATA_TABLE_ID/.test(texts.apply),
    covers_seven_workflows: WORKFLOW_FILES.every((f) => texts.apply.includes(f)),
    patches_human_approval_placeholder: texts.apply.includes('__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__'),
    patches_review_table_placeholder: texts.apply.includes(REVIEW_TABLE_PLACEHOLDER),
    allows_gated_google_chat: texts.apply.includes(GOOGLE_CHAT_EXPR),
    requires_offline_ready_marker: /BUSINESS_READY_OFFLINE_READY/.test(texts.apply) && /BUSINESS_READY_OFFLINE_PARTIAL/.test(texts.apply) && /BUSINESS_READY_OFFLINE_BLOCKED/.test(texts.apply),
    keeps_inactive: /active\s*=\s*\$false|active=False/i.test(texts.apply),
    clears_key_in_finally: /finally/i.test(texts.apply) && /HMZ_N8N_API_KEY/.test(texts.apply),
  };
  assert(Object.values(applyChecks).every(Boolean), `apply-business-ready.ps1: ${JSON.stringify(applyChecks)}`);

  const localChecks = {
    requires_n8n_api_key: /HMZ_N8N_API_KEY/.test(texts.localRuntime),
    reverses_temporary_activation: /Set-N8nWorkflowActivation/.test(texts.localRuntime) && /finally/i.test(texts.localRuntime),
    covers_human_approval: texts.localRuntime.includes('HMZ - Reply Human Approval - Validation'),
  };
  assert(Object.values(localChecks).every(Boolean), `run-local-runtime-acceptance.ps1: ${JSON.stringify(localChecks)}`);

  const liveChecks = {
    read_only_get_campaigns: /GET.*\/api\/v2\/campaigns|Method GET.*campaigns/.test(texts.controlledLive),
    preflight_only_by_default: /PreflightOnly/.test(texts.controlledLive) && /DefaultParameterSetName\s*=\s*'PreflightOnly'/.test(texts.controlledLive),
    one_controlled_reply_gated_by_confirmation:
      /hmz-validation-reply-intake-dev/.test(texts.controlledLive) &&
      /AllowOneControlledReply/.test(texts.controlledLive) &&
      /RUN-ONE-CONTROLLED-REPLY/.test(texts.controlledLive) &&
      !/api\/v2\/emails\/reply/.test(texts.controlledLive),
    no_suppression_endpoints: !/update-interest-status|subsequence\/remove|\/blocklist/.test(texts.controlledLive),
    requires_dry_run_true: /dry_run.*true|configDryRunTrue/.test(texts.controlledLive),
    no_proven_mode: /PROVEN mode/i.test(texts.controlledLive),
  };
  assert(Object.values(liveChecks).every(Boolean), `run-controlled-live-acceptance.ps1: ${JSON.stringify(liveChecks)}`);

  const rollbackChecks = {
    requires_n8n_api_key: /HMZ_N8N_API_KEY/.test(texts.rollback),
    restores_from_backup: /preapply-backup/.test(texts.rollback),
    covers_seven_workflows: WORKFLOW_FILES.every((f) => texts.rollback.includes(f)),
    deactivates_if_active: /deactivate/i.test(texts.rollback),
  };
  assert(Object.values(rollbackChecks).every(Boolean), `rollback-business-ready.ps1: ${JSON.stringify(rollbackChecks)}`);

  record('powershell_scripts_present_and_fail_closed', 'All 4 business-ready PowerShell scripts (apply, local runtime acceptance, controlled-live acceptance, rollback) exist, require HMZ_N8N_API_KEY where applicable, cover all 7 workflows, patch all placeholders, and the controlled-live script performs read-only checks only', true);
} catch (err) {
  record('powershell_scripts_present_and_fail_closed', 'All 4 business-ready PowerShell scripts (apply, local runtime acceptance, controlled-live acceptance, rollback) exist, require HMZ_N8N_API_KEY where applicable, cover all 7 workflows, patch all placeholders, and the controlled-live script performs read-only checks only', false, err.message);
}

// ---------------------------------------------------------------------
// 18-20. Regression: phase4a (42), phase4b (31), integration-closure (16).
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

runRegression('regression_phase4a', path.join(ROOT, 'verification', 'phase4a', 'run-offline-tests.mjs'), 42);
runRegression('regression_phase4b', path.join(ROOT, 'verification', 'phase4b', 'run-offline-tests.mjs'), 31);
runRegression('regression_integration_closure', path.join(ROOT, 'verification', 'integration-closure', 'run-offline-tests.mjs'), 16);

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
