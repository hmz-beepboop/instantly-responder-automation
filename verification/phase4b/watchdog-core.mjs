// Phase 4B SLA Watchdog core logic.
//
// Pure, synchronous, n8n-Code-node-safe functions (no Node built-ins, no
// fetch). build-workflows.mjs embeds these (via .toString()) as the bodies
// of the generated SLA Watchdog workflow's Code nodes.
// run-offline-tests.mjs imports and tests them directly.

export const SEND_STATE_BASE_URL = 'http://hmz-send-state:5681';

export const SLA_WARNING_THRESHOLD_SECONDS = 180;
export const SLA_BREACH_THRESHOLD_SECONDS = 300;

export const WATCHDOG_CATEGORIES = Object.freeze({
  AI_CLASSIFICATION_WAIT: 'AI_CLASSIFICATION_WAIT',
  API_RETRY: 'API_RETRY',
  HUMAN_REVIEW: 'HUMAN_REVIEW',
  SEND_FAILURE: 'SEND_FAILURE',
  SEND_UNCERTAIN: 'SEND_UNCERTAIN',
  SUPPRESSION_FAILURE: 'SUPPRESSION_FAILURE',
  UNKNOWN_STATE: 'UNKNOWN_STATE',
});

// Only SEND_UNCERTAIN records (a transmission attempt that has not yet been
// reconciled) belong to the Transmission SLO. Everything else - including
// every HUMAN_REVIEW item - belongs to the Processing SLO. A draft, queue
// item, approval request, or human-review item is never a transmission.
export const TRANSMISSION_CATEGORIES = Object.freeze([WATCHDOG_CATEGORIES.SEND_UNCERTAIN]);

export const SLO_TYPES = Object.freeze({
  PROCESSING: 'PROCESSING',
  TRANSMISSION: 'TRANSMISSION',
});

export const SLA_STATUSES = Object.freeze({
  OK: 'OK',
  WARNING: 'WARNING',
  BREACH: 'BREACH',
});

export const SEND_FAILURE_STATES = Object.freeze([
  'PERMANENT_FAILURE',
  'AUTH_OR_PLAN_FAILURE',
  'INVALID_REPLY_TARGET',
  'RETRY_EXHAUSTED',
]);

// ---------------------------------------------------------------------
// A. Classify an unfinished hmz-send-state send record.
// ---------------------------------------------------------------------
export function classifySendRecord(record) {
  const rec = record || {};
  switch (rec.state) {
    case 'LOCKED':
      return WATCHDOG_CATEGORIES.AI_CLASSIFICATION_WAIT;
    case 'SUBMITTING':
      return WATCHDOG_CATEGORIES.API_RETRY;
    case 'SENT':
    case 'SEND_UNCERTAIN':
      return WATCHDOG_CATEGORIES.SEND_UNCERTAIN;
    default:
      return WATCHDOG_CATEGORIES.UNKNOWN_STATE;
  }
}

// ---------------------------------------------------------------------
// A2. Classify an unresolved hmz-send-state error record.
// ---------------------------------------------------------------------
export function classifyErrorRecord(record) {
  const rec = record || {};
  const errorClass = rec.error_class;

  if (errorClass === 'SEND_UNCERTAIN') return WATCHDOG_CATEGORIES.SEND_UNCERTAIN;
  if (errorClass === 'RETRYABLE') return WATCHDOG_CATEGORIES.API_RETRY;
  if (SEND_FAILURE_STATES.includes(errorClass)) return WATCHDOG_CATEGORIES.SEND_FAILURE;
  if (rec.reason === 'suppression_verification_failed') return WATCHDOG_CATEGORIES.SUPPRESSION_FAILURE;
  if (rec.operator_action === 'MANUAL_REVIEW' || errorClass === 'UNKNOWN') {
    return rec.reason === undefined && errorClass === 'UNKNOWN'
      ? WATCHDOG_CATEGORIES.UNKNOWN_STATE
      : WATCHDOG_CATEGORIES.HUMAN_REVIEW;
  }
  return WATCHDOG_CATEGORIES.UNKNOWN_STATE;
}

export function sloTypeForCategory(category) {
  return TRANSMISSION_CATEGORIES.includes(category) ? SLO_TYPES.TRANSMISSION : SLO_TYPES.PROCESSING;
}

export function timestampForSendRecord(record, sloType) {
  const rec = record || {};
  const details = rec.details || {};
  if (sloType === SLO_TYPES.TRANSMISSION) {
    return details.transmissionStartedAt || details.submissionStartedAt || rec.updatedAt || rec.createdAt || null;
  }
  return rec.createdAt || rec.updatedAt || null;
}

export function ageSeconds(timestampIso, nowIso) {
  const ts = Date.parse(timestampIso || '');
  const now = Date.parse(nowIso || '');
  if (!Number.isFinite(ts) || !Number.isFinite(now)) return null;
  return Math.max(0, Math.round((now - ts) / 1000));
}

export function statusForAge(age) {
  if (age === null) return SLA_STATUSES.OK;
  if (age >= SLA_BREACH_THRESHOLD_SECONDS) return SLA_STATUSES.BREACH;
  if (age >= SLA_WARNING_THRESHOLD_SECONDS) return SLA_STATUSES.WARNING;
  return SLA_STATUSES.OK;
}

// ---------------------------------------------------------------------
// A3. Merge the hmz-send-state /v1/unfinished response (sends/errors) onto
// the triggering item, preserving any test_overrides / synthetic flag from
// the trigger so evaluateUnfinishedRecords() can pick up test_overrides.now.
// ---------------------------------------------------------------------
export function mergeUnfinishedResponse(priorItem, unfinishedResponse) {
  const input = priorItem || {};
  const response = unfinishedResponse || {};
  if (!Array.isArray(response.sends) || !Array.isArray(response.errors)) {
    throw new Error('invalid_unfinished_response');
  }
  return {
    ...input,
    unfinished: {
      sends: response.sends,
      errors: response.errors,
    },
  };
}

// ---------------------------------------------------------------------
// B. Evaluate every unfinished record against the SLA thresholds.
//
// Input item shape: { unfinished: { sends: [...], errors: [...] }, now }.
// `now` is an ISO timestamp; for the Schedule Trigger path it is the
// workflow's wall clock, and for synthetic Execute Workflow Trigger tests
// it is supplied by test_overrides.now for determinism.
// ---------------------------------------------------------------------
export function evaluateUnfinishedRecords(item) {
  const input = item || {};
  const unfinished = input.unfinished || { sends: [], errors: [] };
  const now = (input.test_overrides && input.test_overrides.now) || input.now || new Date().toISOString();

  const records = [];

  for (const send of unfinished.sends || []) {
    const category = classifySendRecord(send);
    const sloType = sloTypeForCategory(category);
    const ageTimestamp = timestampForSendRecord(send, sloType);
    const age = ageSeconds(ageTimestamp, now);
    records.push({
      kind: 'send',
      identifier: send.sendKey || null,
      state: send.state || null,
      category,
      sloType,
      ageSeconds: age,
      status: statusForAge(age),
      createdAt: send.createdAt || null,
      updatedAt: send.updatedAt || null,
      ageTimestamp,
    });
  }

  for (const error of unfinished.errors || []) {
    const category = classifyErrorRecord(error);
    const sloType = sloTypeForCategory(category);
    const age = ageSeconds(error.recordedAt, now);
    records.push({
      kind: 'error',
      identifier: error.errorId || null,
      state: error.error_class || null,
      category,
      sloType,
      ageSeconds: age,
      status: statusForAge(age),
      updatedAt: error.recordedAt || null,
    });
  }

  const warnings = records.filter((r) => r.status === SLA_STATUSES.WARNING);
  const breaches = records.filter((r) => r.status === SLA_STATUSES.BREACH);

  const processing = records.filter((r) => r.sloType === SLO_TYPES.PROCESSING);
  const transmission = records.filter((r) => r.sloType === SLO_TYPES.TRANSMISSION);

  return {
    ...input,
    watchdog_evaluation: {
      schema_version: '1.0',
      synthetic: input.synthetic === true,
      now,
      warning_threshold_seconds: SLA_WARNING_THRESHOLD_SECONDS,
      breach_threshold_seconds: SLA_BREACH_THRESHOLD_SECONDS,
      records,
      warnings,
      breaches,
      processing_slo: {
        total: processing.length,
        warnings: processing.filter((r) => r.status === SLA_STATUSES.WARNING).length,
        breaches: processing.filter((r) => r.status === SLA_STATUSES.BREACH).length,
      },
      transmission_slo: {
        total: transmission.length,
        warnings: transmission.filter((r) => r.status === SLA_STATUSES.WARNING).length,
        breaches: transmission.filter((r) => r.status === SLA_STATUSES.BREACH).length,
      },
    },
  };
}

// ---------------------------------------------------------------------
// C. Build sanitised warning/breach alert records with a stable alert key
// (category + SLO type + record identifier + status), independent of any
// random marker. The identifier is already a hash (sendKey/errorId) - no
// message bodies, no raw email addresses.
// ---------------------------------------------------------------------
export function buildAlertKey(record) {
  const rec = record || {};
  return ['WATCHDOG_ALERT', rec.sloType, rec.category, rec.kind, rec.identifier, rec.status].join('|');
}

export function buildAlertRecords(item) {
  const input = item || {};
  const evaluation = input.watchdog_evaluation || { warnings: [], breaches: [] };
  const candidates = [...(evaluation.warnings || []), ...(evaluation.breaches || [])];

  const alerts = candidates.map((record) => ({
    schema_version: '1.0',
    alert_key: buildAlertKey(record),
    severity: record.status,
    sloType: record.sloType,
    category: record.category,
    kind: record.kind,
    identifier: record.identifier,
    ageSeconds: record.ageSeconds,
  }));

  return {
    ...input,
    alert_candidates: alerts,
  };
}

// ---------------------------------------------------------------------
// D. Merge the sidecar's /v1/alert/dedupe response (one entry per
// alert_key, in the same order as alert_candidates) and route only to a
// placeholder notification object - no real notification call.
// ---------------------------------------------------------------------
export function mergeAlertDedupeResults(priorItem, dedupeResponse) {
  const input = priorItem || {};
  const candidates = input.alert_candidates || [];
  const response = dedupeResponse || {};
  if (!Array.isArray(response.results) || response.results.length !== candidates.length) {
    throw new Error('invalid_alert_dedupe_response');
  }
  const results = response.results;
  for (const result of results) {
    if (typeof result?.deduped !== 'boolean') {
      throw new Error('invalid_alert_dedupe_item');
    }
  }

  const alerts = candidates.map((candidate, idx) => {
    const dedupe = results[idx];
    return {
      ...candidate,
      deduped: dedupe.deduped === true,
      first_seen_at: dedupe.firstSeenAt || null,
    };
  });

  const toNotify = alerts.filter((a) => a.deduped !== true);

  return {
    ...input,
    alerts,
    notification: {
      schema_version: '1.0',
      surface: 'PLACEHOLDER_NOT_CONFIGURED',
      delivered: false,
      alert_count: toNotify.length,
      deduped_count: alerts.length - toNotify.length,
    },
  };
}

// ---------------------------------------------------------------------
// E. Build the final sanitised watchdog result for persistence.
// ---------------------------------------------------------------------
export function buildWatchdogResult(item) {
  const input = item || {};
  const evaluation = input.watchdog_evaluation || {};
  const alerts = input.alerts || [];
  const notification = input.notification || { surface: 'PLACEHOLDER_NOT_CONFIGURED', delivered: false };

  return {
    ...input,
    watchdog_result: {
      schema_version: '1.0',
      synthetic: evaluation.synthetic === true,
      validation_mode: true,
      now: evaluation.now || null,
      processing_slo: evaluation.processing_slo || { total: 0, warnings: 0, breaches: 0 },
      transmission_slo: evaluation.transmission_slo || { total: 0, warnings: 0, breaches: 0 },
      alerts: alerts.map((a) => ({
        alert_key: a.alert_key,
        severity: a.severity,
        sloType: a.sloType,
        category: a.category,
        kind: a.kind,
        identifier: a.identifier,
        ageSeconds: a.ageSeconds,
        deduped: a.deduped === true,
      })),
      notification,
    },
  };
}

// ---------------------------------------------------------------------
// F. Merge the hmz-send-state /v1/phase4b/result response (resultId) onto
// the item. Generic enough to be reused by the Full Test Harness workflow.
// ---------------------------------------------------------------------
export function attachPhase4bResultId(priorItem, persistResponse) {
  const input = priorItem || {};
  const response = persistResponse || {};
  if (!/^[0-9a-f]{16}$/.test(String(response.resultId || ''))) {
    throw new Error('invalid_phase4b_persist_response');
  }
  return {
    ...input,
    phase4b_result_id: response.resultId,
  };
}
