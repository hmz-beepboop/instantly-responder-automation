// Sender retry, state and classification contract for V5 Layer 1.
//
// classifyOutcome() interprets a single attempt's raw transport outcome.
// sendReply() drives the bounded-attempt retry loop and never issues a
// second submission for an outcome where the side effect cannot be ruled
// out (SEND_UNCERTAIN).

export const STATES = Object.freeze({
  SENT: 'SENT',
  PERMANENT_FAILURE: 'PERMANENT_FAILURE',
  AUTH_OR_PLAN_FAILURE: 'AUTH_OR_PLAN_FAILURE',
  INVALID_REPLY_TARGET: 'INVALID_REPLY_TARGET',
  RETRY_EXHAUSTED: 'RETRY_EXHAUSTED',
  SEND_UNCERTAIN: 'SEND_UNCERTAIN',
  PRE_SUBMISSION_NETWORK_FAILURE: 'PRE_SUBMISSION_NETWORK_FAILURE',
});

export const MAX_ATTEMPTS = 3;
export const BASE_BACKOFF_MS = 100;
export const MAX_BACKOFF_MS = 2000;
export const RETRY_AFTER_CAP_MS = 5000;

// Deterministic jitter: no Math.random, fully reproducible.
export function defaultJitter(attemptNumber) {
  return (attemptNumber * 37) % 50;
}

function parseRetryAfterMs(headers) {
  if (!headers) return null;
  const raw = headers['retry-after'] ?? headers['Retry-After'];
  if (raw == null) return null;
  const seconds = Number(raw);
  if (!Number.isFinite(seconds) || seconds < 0) return null;
  return seconds * 1000;
}

function isValidSentContract(body) {
  return (
    !!body &&
    typeof body === 'object' &&
    body.status === 'sent' &&
    typeof body.messageId === 'string' &&
    body.messageId.length > 0
  );
}

// Network errorPhase values used by run-layer1.mjs:
//  - 'connection-refused'           : TCP connect refused, proven before submission
//  - 'pre-submission'               : failure before any request was dispatched
//  - 'connection-loss-before-confirmed' : connection lost, submission not confirmed
//  - 'connection-loss-after-submission' : connection lost after body was sent
//  - 'timeout-after-submission'     : no response received before client timeout
const RETRYABLE_NETWORK_PHASES = new Set(['connection-refused', 'pre-submission']);

export function classifyOutcome(outcome) {
  if (outcome.kind === 'http') {
    const { status, headers, body } = outcome;

    if (status === 400) {
      return { mode: 'terminal', state: STATES.PERMANENT_FAILURE, ambiguousSideEffect: false };
    }
    if (status === 401 || status === 402 || status === 403) {
      return { mode: 'terminal', state: STATES.AUTH_OR_PLAN_FAILURE, ambiguousSideEffect: false };
    }
    if (status === 404) {
      return { mode: 'terminal', state: STATES.INVALID_REPLY_TARGET, ambiguousSideEffect: false };
    }
    if (status === 429 || status === 500 || status === 502 || status === 503 || status === 504) {
      return {
        mode: 'retryable',
        exhaustedState: STATES.RETRY_EXHAUSTED,
        retryAfterMs: status === 429 ? parseRetryAfterMs(headers) : null,
        ambiguousSideEffect: false,
      };
    }
    if (status >= 200 && status < 300) {
      if (isValidSentContract(body)) {
        return { mode: 'terminal', state: STATES.SENT, ambiguousSideEffect: false };
      }
      // Malformed 2xx: cannot confirm the reply was actually accepted.
      return { mode: 'terminal', state: STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
    }
    // Any unexpected status: treat conservatively as uncertain.
    return { mode: 'terminal', state: STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
  }

  if (outcome.kind === 'network-error') {
    if (RETRYABLE_NETWORK_PHASES.has(outcome.errorPhase)) {
      return {
        mode: 'retryable',
        exhaustedState: STATES.PRE_SUBMISSION_NETWORK_FAILURE,
        retryAfterMs: null,
        ambiguousSideEffect: false,
      };
    }
    // connection-loss-* and timeout-after-submission: submission cannot be
    // safely ruled out, so do not retry.
    return { mode: 'terminal', state: STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
  }

  throw new Error(`Unknown outcome kind: ${outcome.kind}`);
}

function sanitizeOutcome(outcome) {
  return {
    kind: outcome.kind,
    status: outcome.status ?? null,
    errorPhase: outcome.errorPhase ?? null,
    serverReceived: !!outcome.serverReceived,
  };
}

// submit(attemptNumber) -> Promise<outcome>
// sleep(ms) -> Promise<void> (dependency-injected, may be a no-op for tests)
// jitter(attemptNumber) -> number (dependency-injected, deterministic)
export async function sendReply({ submit, sleep, jitter = defaultJitter, maxAttempts = MAX_ATTEMPTS }) {
  const attemptOutcomes = [];
  const backoffDelaysRequested = [];
  let postSubmissions = 0;
  let retried = false;
  let retryAfterHonoured = null;
  let duplicateRiskRetry = false;
  let finalState = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const outcome = await submit(attempt);
    attemptOutcomes.push(outcome);
    if (outcome.serverReceived) postSubmissions++;

    const classification = classifyOutcome(outcome);

    if (classification.mode === 'terminal') {
      finalState = classification.state;
      break;
    }

    // mode === 'retryable'
    if (classification.ambiguousSideEffect && outcome.serverReceived) {
      // Structural safety net: must never happen by construction.
      duplicateRiskRetry = true;
    }

    if (attempt === maxAttempts) {
      finalState = classification.exhaustedState;
      break;
    }

    let delayMs;
    if (classification.retryAfterMs != null) {
      delayMs = Math.min(classification.retryAfterMs, RETRY_AFTER_CAP_MS);
      if (retryAfterHonoured === null) retryAfterHonoured = true;
    } else {
      if (retryAfterHonoured === null) retryAfterHonoured = false;
      const exponential = BASE_BACKOFF_MS * 2 ** (attempt - 1);
      delayMs = Math.min(exponential + jitter(attempt), MAX_BACKOFF_MS);
    }

    backoffDelaysRequested.push(delayMs);
    retried = true;
    await sleep(delayMs);
  }

  return {
    finalState,
    attempts: attemptOutcomes.length,
    postSubmissions,
    retried,
    backoffDelaysRequested,
    retryAfterHonoured,
    humanReviewRequired: finalState !== STATES.SENT,
    duplicateRiskRetry,
    attemptOutcomes: attemptOutcomes.map(sanitizeOutcome),
  };
}
