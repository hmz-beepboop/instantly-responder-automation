// Phase 4B Full Test Harness core logic.
//
// Pure, synchronous, n8n-Code-node-safe functions (no Node built-ins, no
// fetch). build-workflows.mjs embeds these (via .toString()) as the body of
// the generated Full Test Harness workflow's fixture-runner Code node,
// together with sender-core.mjs / error-core.mjs / watchdog-core.mjs and the
// full fixtures/phase_4 fixture matrix (embedded as a JSON literal).
// run-offline-tests.mjs imports and tests this module directly.
//
// classifyIntakeEvent() is a deterministic local reimplementation of the
// safety-critical subset of docs/HMZ_APPROVED_REPLY_RULES.md sections 3 and
// 5 (the prefilter + taxonomy action matrix), used because no shared
// "decision-core" module exists for workflows 01/02. Where a fixture would
// require executing those real sub-workflows (unknown-ID Execute Workflow
// calls), the fixture instead exercises this local contract and is marked
// accordingly; full sub-workflow integration is recorded as a Phase 5 task.

// ---------------------------------------------------------------------
// Deterministic intake/policy classifier (local contract; see header).
// ---------------------------------------------------------------------

export const CATEGORY_ACTION_DEFAULTS = Object.freeze({
  T1: { reply_mode: 'AI_DRAFT_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T2: { reply_mode: 'AI_DRAFT_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T3: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T4: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T5: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T6: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false, interest_status_update: 'NOT_INTERESTED' },
  T7: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'WORKSPACE_DNC', human_review_required: false, escalation_required: false },
  T8: { reply_mode: 'NO_REPLY', stop_sequence: false, pause_sequence: true, suppression_level: 'NONE', human_review_required: false, escalation_required: false },
  T9: { reply_mode: 'NO_REPLY', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: false, escalation_required: false, data_cleanup_required: true },
  T10: { reply_mode: 'FIXED_TEMPLATE_APPROVAL', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T11: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T12: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'REVIEW_HOLD', human_review_required: true, escalation_required: true },
  T13: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'REVIEW_HOLD', human_review_required: true, escalation_required: true },
  T14: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T15: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
  T16: { reply_mode: 'HUMAN_ONLY', stop_sequence: true, pause_sequence: false, suppression_level: 'NONE', human_review_required: true, escalation_required: false },
});

// Hard-safety rules (HMZ_APPROVED_REPLY_RULES.md §5.1). Evaluated in order;
// det-unsub-001 always first so it overrides every other category.
export const RULES_HARD_SAFETY = [
  { code: 'det-unsub-001', re: /(unsubscribe|remove me|take me off|opt out|stop emailing|stop contacting|do not contact me again|delete me from your outreach)/, category: 'T7' },
  { code: 'det-legal-001', re: /(gdpr|ccpa|hipaa|privacy act|data protection|right to be forgotten|where did you get my (email|data|info))/, category: 'T12', legal: true, privacy: true },
  { code: 'det-legal-002', re: /(attorney|lawyer|legal counsel|lawsuit|cease and desist|c&d)/, category: 'T12', legal: true },
  { code: 'det-regulator-001', re: /(ftc|\bico\b|reporting you to|filing a complaint with)/, category: 'T12', legal: true },
  { code: 'det-hostile-001', re: /(i'?m going to (find|hurt) you|i know where you (live|work)|extort|doxx)/, category: 'T13', legal: true, reputational: true },
  { code: 'det-hostile-002', re: /(fuck|asshole|idiot|you (will|are going to) regret)/, category: 'T13', reputational: true },
  { code: 'det-complaint-001', re: /(spam|reported you|reporting this to|continued contact after)/, category: 'T12', reputational: true },
];

// Bounce / OOO (§5.2). Bounce rules require explicit delivery-status
// evidence; without it, route to human review rather than auto-classify.
export const RULES_BOUNCE_OOO = [
  { code: 'det-bounce-001', re: /(mailer-daemon|postmaster)/, category: 'T9', needsEvidence: true },
  { code: 'det-bounce-002', re: /(undeliverable|delivery failed|returned mail|mailbox full)/, category: 'T9', needsEvidence: true },
  { code: 'det-ooo-001', re: /(out of office|on vacation|on (annual |parental )?leave|sabbatical|automatic reply|away from the office)/, category: 'T8' },
];

// Pricing / attachment (§5.3).
export const RULES_PRICE_ATTACH = [
  { code: 'det-price-001', re: /(your price|your cost|quote|\brfp\b|\brfi\b|\bcontract\b|\bmsa\b|\bsow\b|discount|enterprise pricing|pricing)/, category: 'T11' },
  { code: 'det-attach-001', re: /(see attached|attachment|attached (is|are|please|the|for))/, category: 'T14' },
];

// Strong-signal rules (§5.4).
export const RULES_STRONG = [
  { code: 'det-booking-001', re: /(book a time|send me your calendar|schedule a call|calendar link|calendly|free (on|at) \w+|what times work)/, category: 'T3' },
  { code: 'det-referral-001', re: /(please contact|reach out to|talk to .* instead|forward you to|the right person is|this is handled by)/, category: 'T5' },
  { code: 'det-wrong-001', re: /(wrong person|wrong address|not the right person|not in that role|no longer work here|not with that company)/, category: 'T10' },
];

export const RE_NOT_INTERESTED = /(not interested|no thanks|we'?re all set|not the right fit|thanks but no thanks|we already use)/;
export const RE_TIMING = /(not right now|maybe later|reach out again|try (q[1-4]|next quarter)|reconnect (next|in))/;
export const RE_INFO_REQUEST = /(how does (it|this) work|tell me more|send (me )?(more )?info|case stud|more information|what'?s the process)/;
export const RE_POSITIVE_CLEAR = /(happy to talk|let'?s chat|sounds good|i'?d be open to a call|open to a call)/;
export const RE_POSITIVE_UNCLEAR = /(interesting|possibly|go on|i may be interested)/;

export function matchRule(rules, text, evidence) {
  for (const rule of rules) {
    if (rule.needsEvidence && !evidence) continue;
    if (rule.re.test(text)) return rule;
  }
  return null;
}

// Single deterministic entry point. `event` is a synthetic NES-like object:
//   { event_type, is_auto_reply, lead_email, eaccount, campaign_known,
//     duplicate_of, duplicate_intake_id, malformed, delivery_status_evidence,
//     mock_ai_category, reply: { subject, text, has_attachments } }
export function classifyIntakeEvent(event) {
  const ev = event || {};
  const reply = ev.reply || {};
  const text = `${reply.subject || ''} ${reply.text || ''}`.toLowerCase();

  if (ev.malformed === true) {
    return {
      intake_outcome: 'MALFORMED_PAYLOAD_REJECTED',
      category: null,
      reply_mode: null,
      stop_sequence: false,
      pause_sequence: false,
      suppression_level: 'NONE',
      human_review_required: true,
      escalation_required: false,
      reason_codes: ['malformed_payload'],
    };
  }

  if (ev.event_type && ev.event_type !== 'reply_received') {
    return {
      intake_outcome: 'UNSUPPORTED_EVENT_NOOP',
      category: 'NOOP',
      reply_mode: 'NO_REPLY',
      stop_sequence: false,
      pause_sequence: false,
      suppression_level: 'NONE',
      human_review_required: false,
      escalation_required: false,
      reason_codes: ['unsupported_event_type'],
    };
  }

  if (
    ev.is_auto_reply === true ||
    (ev.lead_email && ev.eaccount && String(ev.lead_email).toLowerCase() === String(ev.eaccount).toLowerCase())
  ) {
    return {
      intake_outcome: 'SELF_SENT_NOOP',
      category: 'NOOP',
      reply_mode: 'NO_REPLY',
      stop_sequence: false,
      pause_sequence: false,
      suppression_level: 'NONE',
      human_review_required: false,
      escalation_required: false,
      reason_codes: ['self_sent_or_auto_reply'],
    };
  }

  if (ev.duplicate_of || ev.duplicate_intake_id) {
    return {
      intake_outcome: 'DUPLICATE_REJECTED',
      category: null,
      reply_mode: null,
      stop_sequence: false,
      pause_sequence: false,
      suppression_level: 'NONE',
      human_review_required: false,
      escalation_required: false,
      reason_codes: [ev.duplicate_intake_id ? 'repeated_execution_duplicate_intake_id' : 'duplicate_dedupe_key'],
    };
  }

  if (ev.campaign_known === false) {
    return {
      ...CATEGORY_ACTION_DEFAULTS.T16,
      intake_outcome: 'CAMPAIGN_UNKNOWN_HUMAN_REVIEW',
      category: 'T16',
      reason_codes: ['campaign_context_unknown'],
    };
  }

  if (!String(reply.text || '').trim() && reply.has_attachments !== true) {
    return {
      ...CATEGORY_ACTION_DEFAULTS.T15,
      intake_outcome: 'EMPTY_REPLY_ESCALATE',
      category: 'T15',
      reason_codes: ['empty_reply'],
    };
  }

  let hit = matchRule(RULES_HARD_SAFETY, text, true);
  if (hit) {
    return {
      ...CATEGORY_ACTION_DEFAULTS[hit.category],
      intake_outcome: 'ACCEPTED',
      category: hit.category,
      legal_review_required: hit.legal === true,
      privacy_review_required: hit.privacy === true,
      reputational_review_required: hit.reputational === true,
      reason_codes: [hit.code],
    };
  }

  if (reply.has_attachments === true) {
    return {
      ...CATEGORY_ACTION_DEFAULTS.T14,
      intake_outcome: 'ACCEPTED',
      category: 'T14',
      reason_codes: ['det-attach-001'],
    };
  }

  hit = matchRule(RULES_BOUNCE_OOO, text, ev.delivery_status_evidence === true);
  if (hit) {
    return {
      ...CATEGORY_ACTION_DEFAULTS[hit.category],
      intake_outcome: 'ACCEPTED',
      category: hit.category,
      reason_codes: [hit.code],
    };
  }

  hit = matchRule(RULES_PRICE_ATTACH, text, true);
  if (hit) {
    return {
      ...CATEGORY_ACTION_DEFAULTS[hit.category],
      intake_outcome: 'ACCEPTED',
      category: hit.category,
      reason_codes: [hit.code],
    };
  }

  hit = matchRule(RULES_STRONG, text, true);
  if (hit) {
    return {
      ...CATEGORY_ACTION_DEFAULTS[hit.category],
      intake_outcome: 'ACCEPTED',
      category: hit.category,
      reason_codes: [hit.code],
    };
  }

  if (RE_NOT_INTERESTED.test(text)) {
    return { ...CATEGORY_ACTION_DEFAULTS.T6, intake_outcome: 'ACCEPTED', category: 'T6', reason_codes: ['not_interested'] };
  }
  if (RE_TIMING.test(text)) {
    return { ...CATEGORY_ACTION_DEFAULTS.T4, intake_outcome: 'ACCEPTED', category: 'T4', reason_codes: ['timing_objection'] };
  }
  if (RE_INFO_REQUEST.test(text)) {
    return { ...CATEGORY_ACTION_DEFAULTS.T2, intake_outcome: 'ACCEPTED', category: 'T2', reason_codes: ['information_request'] };
  }
  if (RE_POSITIVE_CLEAR.test(text)) {
    return { ...CATEGORY_ACTION_DEFAULTS.T1, intake_outcome: 'ACCEPTED', category: 'T1', reply_mode: 'FIXED_TEMPLATE_APPROVAL', reason_codes: ['positive_interest_clear'] };
  }
  if (RE_POSITIVE_UNCLEAR.test(text)) {
    return { ...CATEGORY_ACTION_DEFAULTS.T1, intake_outcome: 'ACCEPTED', category: 'T1', reply_mode: 'AI_DRAFT_APPROVAL', reason_codes: ['positive_interest_unclear'] };
  }

  // Nothing deterministic matched: fall through to the (mocked) AI
  // classifier category, defaulting to T15 AMBIGUOUS (confidence < 0.60).
  const fallback = ev.mock_ai_category || 'T15';
  return {
    ...(CATEGORY_ACTION_DEFAULTS[fallback] || CATEGORY_ACTION_DEFAULTS.T15),
    intake_outcome: 'ACCEPTED',
    category: fallback,
    reason_codes: ['ai_classifier_fallback'],
  };
}

// ---------------------------------------------------------------------
// Generic dot-path comparator used by the fixture runner.
// ---------------------------------------------------------------------
export function getPath(obj, pathStr) {
  return String(pathStr)
    .split('.')
    .reduce((acc, key) => (acc === null || acc === undefined ? undefined : acc[key]), obj);
}

export function compareExpected(actual, expected) {
  const diffs = [];
  for (const [key, expectedValue] of Object.entries(expected || {})) {
    const actualValue = getPath(actual, key);
    if (JSON.stringify(actualValue) !== JSON.stringify(expectedValue)) {
      diffs.push({ path: key, expected: expectedValue, actual: actualValue });
    }
  }
  return { passed: diffs.length === 0, diffs };
}

// ---------------------------------------------------------------------
// Fixture-check registry. `deps` provides the embedded sender-core /
// error-core / watchdog-core function sets (sc / ec / wc). Two checks
// (sidecar_resolved_exclusion, sidecar_alert_dedupe) require the
// filesystem-backed sidecar store and are proven directly against
// infrastructure/send-state/state-store.mjs by run-offline-tests.mjs; inside
// the embedded (sandboxed) Code node they report `skipped: true`.
// ---------------------------------------------------------------------
export const CHECKS = Object.freeze({
  classify_intake: (fixture) => classifyIntakeEvent(fixture.input),

  sender_gates: (fixture, deps) => deps.sc.runSendGates(deps.sc.validateSenderInput(fixture.input)),

  sender_gate_rejection: (fixture, deps) => {
    const gated = deps.sc.runSendGates(deps.sc.validateSenderInput(fixture.input));
    return deps.sc.buildGateRejectionTerminal(gated);
  },

  sender_dry_run_terminal: (fixture, deps) => {
    const gated = deps.sc.runSendGates(deps.sc.validateSenderInput(fixture.input));
    const keyed = deps.sc.computeSendKey(gated);
    const acquired = deps.sc.normalizeAcquisitionResult(keyed, { acquired: true, sendKey: 'b'.repeat(64), state: 'LOCKED' });
    const suppressed = deps.sc.mockSuppressionAdapter(acquired);
    const verified = deps.sc.verifySuppressionResults(suppressed);
    return deps.sc.buildDryRunTerminal(verified, { state: 'DRY_RUN_OK' });
  },

  acquisition_terminal: (fixture, deps) => {
    const gated = deps.sc.runSendGates(deps.sc.validateSenderInput(fixture.input.decisionOutput));
    const keyed = deps.sc.computeSendKey(gated);
    const normalized = deps.sc.normalizeAcquisitionResult(keyed, fixture.input.acquireResponse);
    return deps.sc.buildBlockedDuplicateTerminal(normalized);
  },

  suppression: (fixture, deps) => {
    const gated = deps.sc.runSendGates(deps.sc.validateSenderInput(fixture.input));
    const suppressed = deps.sc.mockSuppressionAdapter(gated);
    const verified = deps.sc.verifySuppressionResults(suppressed);
    if (verified.suppression_verification.verified === false) {
      return deps.sc.buildSuppressionEscalationTerminal(verified);
    }
    return verified;
  },

  send_outcome: (fixture, deps) => deps.sc.classifySendOutcome(fixture.input.outcome),

  plan_attempts: (fixture, deps) => deps.sc.planSendAttempts(fixture.input.outcomes, fixture.input.options || {}),

  reconcile: (fixture, deps) => deps.sc.reconcileMatches(fixture.input.checks, fixture.input.options || {}),

  watchdog_evaluation: (fixture, deps) => deps.wc.evaluateUnfinishedRecords(fixture.input).watchdog_evaluation,

  error_record_sanitised: (fixture, deps) => deps.ec.redactErrorRecord(deps.ec.normalizeErrorEvent(fixture.input)).error_record,

  placeholder_routing: (fixture, deps) => {
    const evaluated = deps.wc.evaluateUnfinishedRecords(fixture.input);
    const withAlerts = deps.wc.buildAlertRecords(evaluated);
    return deps.wc.mergeAlertDedupeResults(withAlerts, fixture.input.dedupeResponse).notification;
  },

  send_uncertain_not_retryable: (fixture, deps) => deps.ec.normalizeErrorEvent(fixture.input).error_record,

  sidecar_resolved_exclusion: () => ({ skipped: true, note: 'verified against infrastructure/send-state/state-store.mjs in run-offline-tests.mjs' }),

  sidecar_alert_dedupe: () => ({ skipped: true, note: 'verified against infrastructure/send-state/state-store.mjs in run-offline-tests.mjs' }),
});

export function runFixture(fixture, deps) {
  const checkFn = CHECKS[fixture.check];
  if (!checkFn) {
    return { id: fixture.id, group: fixture.group, passed: false, error: `unknown check: ${fixture.check}` };
  }
  try {
    const actual = checkFn(fixture, deps);
    if (actual && actual.skipped === true) {
      return { id: fixture.id, group: fixture.group, passed: true, skipped: true, note: actual.note };
    }
    const { passed, diffs } = compareExpected(actual, fixture.expected || {});
    return passed
      ? { id: fixture.id, group: fixture.group, passed: true }
      : { id: fixture.id, group: fixture.group, passed: false, diffs };
  } catch (error) {
    return { id: fixture.id, group: fixture.group, passed: false, error: error && error.message ? error.message : String(error) };
  }
}

export function runFixtureMatrix(fixtures, deps) {
  const list = Array.isArray(fixtures) ? fixtures : [];
  const results = list.map((fixture) => runFixture(fixture, deps));
  const passed = results.filter((r) => r.passed).length;
  const failed = results.length - passed;
  return {
    schema_version: '1.0',
    synthetic: true,
    total: results.length,
    passed,
    failed,
    overall_result: failed === 0 ? 'PASS' : 'FAIL',
    results,
  };
}
