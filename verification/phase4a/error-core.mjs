// Phase 4A Error Handler core logic.
//
// Pure, synchronous, n8n-Code-node-safe functions. build-workflows.mjs
// embeds these (via .toString()) as the bodies of the generated Error
// Handler workflow's Code nodes. run-offline-tests.mjs imports and tests
// them directly.

export const REDACT_KEY_PATTERN = /(authoriz|api[_-]?key|secret|token|password|cookie|bearer)/i;
export const MAX_STRING_LENGTH = 300;

// Redacts any key that looks like a credential and truncates long
// strings. Applied to the whole error record before persistence -
// secrets, Authorization values, full payloads, and long PII never reach
// hmz-send-state.
export function redactValue(value) {
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.slice(0, 20).map(redactValue);
  if (typeof value === 'object') {
    const out = {};
    for (const key of Object.keys(value)) {
      if (REDACT_KEY_PATTERN.test(key)) {
        out[key] = '<REDACTED>';
        continue;
      }
      out[key] = redactValue(value[key]);
    }
    return out;
  }
  if (typeof value === 'string' && value.length > MAX_STRING_LENGTH) {
    return `${value.slice(0, MAX_STRING_LENGTH)}...<TRUNCATED>`;
  }
  return value;
}

export const RETRYABLE_HTTP_STATUSES = [429, 500, 502, 503, 504];

export function classifyErrorClass(item) {
  const input = item || {};
  if (input.error_class) return input.error_class;

  // SEND_UNCERTAIN is a definitive ambiguous-outcome determination made by
  // the Sender workflow and must take priority over any http_status-based
  // inference, so error_class/retryable/operator_action stay consistent
  // (never RETRYABLE/MONITOR_RETRY for a SEND_UNCERTAIN record).
  if (input.send_state === 'SEND_UNCERTAIN') return 'SEND_UNCERTAIN';

  const status = input.http_status;
  if (status === 400) return 'PERMANENT_FAILURE';
  if (status === 401 || status === 402 || status === 403) return 'AUTH_OR_PLAN_FAILURE';
  if (status === 404) return 'INVALID_REPLY_TARGET';
  if (RETRYABLE_HTTP_STATUSES.includes(status)) return 'RETRYABLE';
  return 'UNKNOWN';
}

// SEND_UNCERTAIN must never be turned into a retry, regardless of any
// http_status also present on the item.
export function deriveRetryable(item) {
  const input = item || {};
  if (input.send_state === 'SEND_UNCERTAIN') return false;
  if (typeof input.retryable === 'boolean') return input.retryable;
  return classifyErrorClass(input) === 'RETRYABLE';
}

export const OPERATOR_ACTION_BY_CLASS = Object.freeze({
  PERMANENT_FAILURE: 'REVIEW_PAYLOAD',
  AUTH_OR_PLAN_FAILURE: 'CHECK_CREDENTIALS_AND_PLAN',
  INVALID_REPLY_TARGET: 'INVESTIGATE_REPLY_TARGET',
  RETRYABLE: 'MONITOR_RETRY',
  SEND_UNCERTAIN: 'MANUAL_RECONCILIATION_REQUIRED',
  UNKNOWN: 'MANUAL_REVIEW',
});

export function deriveOperatorAction(item) {
  const input = item || {};
  if (input.operator_action) return input.operator_action;
  const errorClass = classifyErrorClass(input);
  return OPERATOR_ACTION_BY_CLASS[errorClass] || 'MANUAL_REVIEW';
}

// A. Normalise workflow/execution/failed-node/intake/send identifiers.
// Accepts either a real n8n Error Trigger item shape
// ($json.execution / $json.workflow / $json.trigger) or a synthetic
// Execute Workflow Trigger item shape (flat fields), so the same Code
// node works for both entry points.
export function normalizeErrorEvent(item) {
  const input = item || {};
  const execution = input.execution || {};
  const workflowInfo = input.workflow || {};
  const trigger = input.trigger || {};
  const triggerError = trigger.error || {};

  const failedNode =
    input.failed_node || triggerError.node?.name || execution.lastNodeExecuted || null;

  const errorClass = classifyErrorClass(input);

  return {
    ...input,
    error_record: {
      schema_version: '1.0',
      workflow_id: workflowInfo.id || input.workflow_id || null,
      workflow_name: workflowInfo.name || input.workflow_name || null,
      execution_id: execution.id || input.execution_id || null,
      failed_node: failedNode,
      intake_id: input.intake_id || (input.nes && input.nes.intake_id) || null,
      send_key:
        input.send_key ||
        (input.acquisition && input.acquisition.sendKey) ||
        (input.send_identity && input.send_identity.sendKey) ||
        null,
      send_state: input.send_state || (input.terminal && input.terminal.send_state) || null,
      http_status: typeof input.http_status === 'number' ? input.http_status : null,
      error_class: errorClass,
      attempt: typeof input.attempt === 'number' ? input.attempt : null,
      retryable: deriveRetryable(input),
      operator_action: deriveOperatorAction(input),
    },
  };
}

// B. Redact secrets / Authorization / full payloads / long PII from the
// normalised error record before persistence.
export function redactErrorRecord(item) {
  const input = item || {};
  return {
    ...input,
    error_record: redactValue(input.error_record || {}),
  };
}

// D. Placeholder notification object only - never calls Slack, email,
// Sheets, or any other external service.
export function buildPlaceholderNotification(item) {
  const input = item || {};
  const record = input.error_record || {};
  return {
    ...input,
    notification: {
      schema_version: '1.0',
      surface: 'PLACEHOLDER_NOT_CONFIGURED',
      delivered: false,
      summary: `Error in ${record.workflow_name || 'unknown workflow'}: ${record.error_class || 'UNKNOWN'} at node ${record.failed_node || 'unknown'}`,
      operator_action: record.operator_action || 'MANUAL_REVIEW',
    },
  };
}

// C2. Merge the hmz-send-state /v1/error response (errorId) back onto
// the item.
export function attachErrorId(priorItem, persistResponse) {
  const input = priorItem || {};
  const response = persistResponse || {};
  return {
    ...input,
    persisted_error: {
      errorId: response.errorId || null,
    },
  };
}
