// Phase 4A Sender core logic.
//
// Pure, synchronous, n8n-Code-node-safe functions (no Node built-ins, no
// fetch). Each function takes a plain item object and returns a new plain
// object (spread + extra fields), matching the {...input, ...} pattern used
// throughout workflows 01/02. build-workflows.mjs embeds these functions
// (via .toString()) as the bodies of the generated Sender workflow's Code
// nodes. run-offline-tests.mjs imports and tests them directly.
//
// Hardcoded validation settings - no input path may override these.
export const OPERATING_MODE = 'VALIDATION';
export const DRY_RUN = true;
export const LIVE_CAMPAIGNS = [];
export const LIVE_CREDENTIAL_READY = false;

export const SENDER_CONFIG = Object.freeze({
  OPERATING_MODE,
  DRY_RUN,
  LIVE_CAMPAIGNS,
  LIVE_CREDENTIAL_READY,
});

export const SEND_STATE_BASE_URL = 'http://hmz-send-state:5681';

export function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

// Deterministic djb2 hash, same family as workflows 01/02's
// vendorPayloadHash/canonicalPayloadHash. n8n Code nodes cannot rely on
// node:crypto, so this informational key uses plain JS only. The
// authoritative send key is derived server-side by hmz-send-state
// (sha256, node:crypto) from the same identity tuple.
export function djb2Hash(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) + hash + str.charCodeAt(i);
    hash = hash & 0xffffffff;
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

// Stable across reruns: derived only from canonical inbound Email ID,
// sender, recipient, and policy/template identity. A random body marker
// is never an input, so reruns with a fresh marker yield the same key.
export function deriveSendKey({ inboundEmailId, sender, recipient, policyTemplateId }) {
  const raw = [
    'HMZ_PHASE4A_SEND',
    String(inboundEmailId ?? '').trim(),
    normalizeEmail(sender),
    normalizeEmail(recipient),
    String(policyTemplateId ?? '').trim(),
  ].join('|');
  return `send-${djb2Hash(raw)}`;
}

// ---------------------------------------------------------------------
// A. Validate Decision Engine output and required identifiers
// ---------------------------------------------------------------------
export function validateSenderInput(item) {
  const input = item || {};
  const nes = input.nes || {};
  const decision = input.decision || {};
  const validation = input.validation || {};
  const threading = nes.threading || {};

  const errors = [];

  if (validation.valid !== true) errors.push('validation.valid is not true');
  if (!threading.reply_to_uuid) errors.push('nes.threading.reply_to_uuid (inbound email id) is missing');
  if (!nes.eaccount || nes.eaccount === 'UNKNOWN') errors.push('nes.eaccount (sender) is missing or UNKNOWN');
  if (!nes.lead_email || nes.lead_email === 'UNKNOWN') errors.push('nes.lead_email (recipient) is missing or UNKNOWN');
  if (!nes.intake_id) errors.push('nes.intake_id is missing');
  if (typeof decision.reply_permitted !== 'boolean') errors.push('decision.reply_permitted is missing');
  if (decision.human_review_required !== true) errors.push('decision.human_review_required is not true');

  return {
    ...input,
    sender_validation: {
      valid: errors.length === 0,
      errors,
    },
  };
}

// ---------------------------------------------------------------------
// B. Re-run configuration, approval, campaign, sender, draft,
//    template-variable and safety gates
// ---------------------------------------------------------------------
export function runSendGates(item) {
  const input = item || {};
  const cfg = SENDER_CONFIG;
  const reasons = [];

  if (input.sender_validation && input.sender_validation.valid !== true) {
    reasons.push('sender_validation_failed');
  }

  const configGatePassed =
    cfg.OPERATING_MODE === 'VALIDATION' &&
    cfg.DRY_RUN === true &&
    Array.isArray(cfg.LIVE_CAMPAIGNS) &&
    cfg.LIVE_CAMPAIGNS.length === 0;
  if (!configGatePassed) reasons.push('config_gate_failed');

  const approval = input.approval || {};
  const approvalGatePassed = approval.approved === true;
  if (!approvalGatePassed) reasons.push('approval_missing');

  const nes = input.nes || {};
  const campaignId = nes.campaign_id || null;
  const liveCampaignSendAllowed = cfg.LIVE_CAMPAIGNS.includes(campaignId);
  if (!liveCampaignSendAllowed) reasons.push('live_campaigns_empty_live_send_blocked');

  const senderGatePassed = !!nes.eaccount && nes.eaccount !== 'UNKNOWN';
  if (!senderGatePassed) reasons.push('sender_gate_failed');

  const draft = input.draft || {};
  const draftText = typeof draft.draft_text === 'string' ? draft.draft_text : null;
  const unresolvedTokens = draftText ? draftText.match(/\[\[[^\]]+\]\]|<<[^>]+>>/g) || [] : [];
  const draftVariableGatePassed = draftText === null || unresolvedTokens.length === 0;
  if (!draftVariableGatePassed) reasons.push('unresolved_template_variables');

  const decision = input.decision || {};
  const suppressionRequired =
    decision.address_suppression_intent === 'ORGANISATION_DNC' ||
    decision.address_suppression_intent === 'GLOBAL_BLOCKLIST' ||
    decision.durable_dnc_intent === true;

  const dryRunGatePassed = cfg.DRY_RUN === true;
  if (!dryRunGatePassed) reasons.push('dry_run_gate_failed');

  const passed =
    (input.sender_validation ? input.sender_validation.valid === true : true) &&
    configGatePassed &&
    approvalGatePassed &&
    senderGatePassed &&
    draftVariableGatePassed &&
    dryRunGatePassed;

  return {
    ...input,
    gates: {
      config_gate_passed: configGatePassed,
      approval_gate_passed: approvalGatePassed,
      live_campaign_send_allowed: liveCampaignSendAllowed,
      sender_gate_passed: senderGatePassed,
      draft_variable_gate_passed: draftVariableGatePassed,
      unresolved_tokens: unresolvedTokens,
      suppression_required: suppressionRequired,
      dry_run_gate_passed: dryRunGatePassed,
      passed,
      reasons,
    },
  };
}

export function buildGateRejectionTerminal(item) {
  const input = item || {};
  const gates = input.gates || {};
  return {
    ...input,
    terminal: {
      schema_version: '1.0',
      result: 'BLOCKED',
      send_state: 'BLOCKED',
      reason: 'send_gates_failed',
      details: gates.reasons || [],
      sent: false,
    },
  };
}

// ---------------------------------------------------------------------
// D. Compute stable send key
// ---------------------------------------------------------------------
export function computeSendKey(item) {
  const input = item || {};
  const nes = input.nes || {};
  const threading = nes.threading || {};
  const decision = input.decision || {};

  const inboundEmailId = threading.reply_to_uuid || null;
  const sender = nes.eaccount || null;
  const recipient = nes.lead_email || null;
  const policyTemplateId = decision.reply_template_id || 'NO_TEMPLATE';

  return {
    ...input,
    send_identity: {
      inboundEmailId,
      sender,
      recipient,
      policyTemplateId,
      sendKey: deriveSendKey({ inboundEmailId, sender, recipient, policyTemplateId }),
    },
  };
}

// ---------------------------------------------------------------------
// E2. Normalise the hmz-send-state /v1/send/acquire response
// ---------------------------------------------------------------------
export function normalizeAcquisitionResult(priorItem, acquireResponse) {
  const input = priorItem || {};
  const response = acquireResponse || {};
  const acquired = response.acquired === true;

  return {
    ...input,
    acquisition: {
      acquired,
      blocked: !acquired,
      reason: response.reason || null,
      priorState: response.priorState || null,
      sendKey: response.sendKey || (input.send_identity && input.send_identity.sendKey) || null,
    },
  };
}

export function buildBlockedDuplicateTerminal(item) {
  const input = item || {};
  const acquisition = input.acquisition || {};
  return {
    ...input,
    terminal: {
      schema_version: '1.0',
      result: 'BLOCKED',
      send_state: 'BLOCKED',
      reason: acquisition.reason || 'SEND_OWNERSHIP_NOT_ACQUIRED',
      prior_state: acquisition.priorState || null,
      send_key: acquisition.sendKey || null,
      sent: false,
    },
  };
}

// ---------------------------------------------------------------------
// G. Suppression actions (mock adapter only)
// ---------------------------------------------------------------------
export function mockSuppressionAdapter(item) {
  const input = item || {};
  const decision = input.decision || {};

  const required =
    decision.address_suppression_intent === 'ORGANISATION_DNC' ||
    decision.address_suppression_intent === 'GLOBAL_BLOCKLIST' ||
    decision.durable_dnc_intent === true;

  if (!required) {
    return {
      ...input,
      suppression: {
        required: false,
        source_campaign_action: { performed: false, status: 'NOT_REQUIRED' },
        workspace_blocklist_action: { performed: false, status: 'NOT_REQUIRED' },
      },
    };
  }

  // Deterministic mock adapter. test_overrides lets the offline harness
  // exercise the partial-failure / escalation path without any network
  // access.
  const overrides = input.test_overrides || {};
  const sourceStatus = overrides.source_campaign_action_status || 'VERIFIED';
  const blocklistStatus = overrides.workspace_blocklist_action_status || 'VERIFIED';

  return {
    ...input,
    suppression: {
      required: true,
      source_campaign_action: {
        performed: true,
        status: sourceStatus,
        action: 'update_interest_status_and_remove_subsequence',
      },
      workspace_blocklist_action: {
        performed: true,
        status: blocklistStatus,
        action: 'exact_email_blocklist_insert',
      },
    },
  };
}

// ---------------------------------------------------------------------
// H. Verify suppression results
// ---------------------------------------------------------------------
export function verifySuppressionResults(item) {
  const input = item || {};
  const suppression = input.suppression || {};

  if (!suppression.required) {
    return {
      ...input,
      suppression_verification: {
        verified: true,
        escalate: false,
        source_campaign_verified: true,
        workspace_blocklist_verified: true,
        reason: 'NOT_REQUIRED',
      },
    };
  }

  const sourceOk = (suppression.source_campaign_action || {}).status === 'VERIFIED';
  const blocklistOk = (suppression.workspace_blocklist_action || {}).status === 'VERIFIED';
  const verified = sourceOk && blocklistOk;

  return {
    ...input,
    suppression_verification: {
      verified,
      escalate: !verified,
      source_campaign_verified: sourceOk,
      workspace_blocklist_verified: blocklistOk,
      reason: verified ? 'BOTH_ACTIONS_VERIFIED' : 'PARTIAL_OR_FAILED_SUPPRESSION',
    },
  };
}

export function buildSuppressionEscalationTerminal(item) {
  const input = item || {};
  return {
    ...input,
    terminal: {
      schema_version: '1.0',
      result: 'ESCALATED',
      send_state: 'BLOCKED',
      reason: 'suppression_verification_failed',
      details: input.suppression_verification || {},
      sent: false,
    },
  };
}

// ---------------------------------------------------------------------
// K. DRY_RUN result (after hmz-send-state transition to DRY_RUN_OK)
// ---------------------------------------------------------------------
export function buildDryRunTerminal(priorItem, transitionResponse) {
  const input = priorItem || {};
  const response = transitionResponse || {};
  const decision = input.decision || {};
  const suppressionVerification = input.suppression_verification || { verified: true };

  // T7 unsubscribe confirmation may be transmitted (even in a later live
  // phase) only once both suppression actions are verified.
  const replyPermittedAfterSuppression =
    decision.reply_permitted === true && suppressionVerification.verified === true;

  const acquisition = input.acquisition || {};

  return {
    ...input,
    terminal: {
      schema_version: '1.0',
      result: 'DRY_RUN_OK',
      send_state: response.state || 'DRY_RUN_OK',
      operating_mode: SENDER_CONFIG.OPERATING_MODE,
      dry_run: SENDER_CONFIG.DRY_RUN,
      send_key: acquisition.sendKey || (input.send_identity && input.send_identity.sendKey) || null,
      category: decision.category || null,
      reply_permitted_after_suppression: replyPermittedAfterSuppression,
      transport: 'NONE',
      sent: false,
      reason: 'DRY_RUN=true: no transport attempted; ownership acquired and recorded as DRY_RUN_OK.',
    },
  };
}

// ---------------------------------------------------------------------
// N. Live adapter contract (validation-only, unreachable)
//
// Documents the verified V3 Instantly reply contract and the verified V5
// retry/classification/reconciliation contracts WITHOUT binding
// credentials or making any HTTP request. This node is wired only on the
// DRY_RUN-gate "false" branch, which is never taken because
// SENDER_CONFIG.DRY_RUN is hardcoded true.
// ---------------------------------------------------------------------
export const SEND_RESULT_STATES = Object.freeze({
  SENT: 'SENT',
  PERMANENT_FAILURE: 'PERMANENT_FAILURE',
  AUTH_OR_PLAN_FAILURE: 'AUTH_OR_PLAN_FAILURE',
  INVALID_REPLY_TARGET: 'INVALID_REPLY_TARGET',
  RETRY_EXHAUSTED: 'RETRY_EXHAUSTED',
  SEND_UNCERTAIN: 'SEND_UNCERTAIN',
});

export const MAX_SEND_ATTEMPTS = 3;
export const BASE_BACKOFF_MS = 100;
export const MAX_BACKOFF_MS = 2000;
export const RETRY_AFTER_CAP_MS = 5000;

export function deterministicJitter(attemptNumber) {
  return (attemptNumber * 37) % 50;
}

export function isValidSentContract(body) {
  return (
    !!body &&
    typeof body === 'object' &&
    body.status === 'sent' &&
    typeof body.messageId === 'string' &&
    body.messageId.length > 0
  );
}

// Single-attempt classification, ported from
// verification/v5/layer1/sender-policy.mjs classifyOutcome().
export function classifySendOutcome(outcome) {
  const out = outcome || {};

  if (out.kind === 'http') {
    const status = out.status;
    const body = out.body;
    const headers = out.headers || {};

    if (status === 400) {
      return { mode: 'terminal', state: SEND_RESULT_STATES.PERMANENT_FAILURE, ambiguousSideEffect: false };
    }
    if (status === 401 || status === 402 || status === 403) {
      return { mode: 'terminal', state: SEND_RESULT_STATES.AUTH_OR_PLAN_FAILURE, ambiguousSideEffect: false };
    }
    if (status === 404) {
      return { mode: 'terminal', state: SEND_RESULT_STATES.INVALID_REPLY_TARGET, ambiguousSideEffect: false };
    }
    if (status === 429 || status === 500 || status === 502 || status === 503 || status === 504) {
      const retryAfterRaw = headers['retry-after'] ?? headers['Retry-After'] ?? null;
      const retryAfterSeconds = retryAfterRaw == null ? null : Number(retryAfterRaw);
      const retryAfterMs =
        status === 429 && Number.isFinite(retryAfterSeconds) && retryAfterSeconds >= 0
          ? retryAfterSeconds * 1000
          : null;
      return {
        mode: 'retryable',
        exhaustedState: SEND_RESULT_STATES.RETRY_EXHAUSTED,
        retryAfterMs,
        ambiguousSideEffect: false,
      };
    }
    if (status >= 200 && status < 300) {
      if (isValidSentContract(body)) {
        return { mode: 'terminal', state: SEND_RESULT_STATES.SENT, ambiguousSideEffect: false };
      }
      return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
    }
    return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
  }

  if (out.kind === 'network-error') {
    const retryablePhases = ['connection-refused', 'pre-submission'];
    if (retryablePhases.includes(out.errorPhase)) {
      return {
        mode: 'retryable',
        exhaustedState: SEND_RESULT_STATES.RETRY_EXHAUSTED,
        retryAfterMs: null,
        ambiguousSideEffect: false,
      };
    }
    return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
  }

  return { mode: 'terminal', state: SEND_RESULT_STATES.SEND_UNCERTAIN, ambiguousSideEffect: true };
}

// Bounded-attempt retry plan over a precomputed list of per-attempt
// outcomes (deterministic - no real submission, no sleep). Mirrors
// verification/v5/layer1/sender-policy.mjs sendReply() loop semantics:
// stops at the first terminal outcome, never issues a further attempt
// once SEND_UNCERTAIN (or any other terminal state) is reached.
export function planSendAttempts(outcomes, options) {
  const opts = options || {};
  const jitter = opts.jitter || deterministicJitter;
  const maxAttempts = opts.maxAttempts || MAX_SEND_ATTEMPTS;
  const list = Array.isArray(outcomes) ? outcomes : [];

  const attemptOutcomes = [];
  const backoffDelaysRequested = [];
  let postSubmissions = 0;
  let retried = false;
  let retryAfterHonoured = null;
  let finalState = null;
  let secondPostAfterUncertain = false;

  for (let attempt = 1; attempt <= Math.min(maxAttempts, list.length || maxAttempts); attempt++) {
    const outcome = list[attempt - 1] || { kind: 'network-error', errorPhase: 'pre-submission', serverReceived: false };
    attemptOutcomes.push(outcome);
    if (outcome.serverReceived) postSubmissions++;

    const classification = classifySendOutcome(outcome);

    if (classification.mode === 'terminal') {
      finalState = classification.state;
      if (finalState === SEND_RESULT_STATES.SEND_UNCERTAIN && attempt < list.length) {
        secondPostAfterUncertain = true;
      }
      break;
    }

    if (attempt === maxAttempts || attempt === list.length) {
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
  }

  return {
    finalState,
    attempts: attemptOutcomes.length,
    postSubmissions,
    retried,
    backoffDelaysRequested,
    retryAfterHonoured,
    secondPostAfterUncertain,
    humanReviewRequired: finalState !== SEND_RESULT_STATES.SENT,
  };
}

// Read-only reconciliation contract. `checks` is an array of arrays of
// matched sent-Email ids, one entry per poll (oldest first).
export const RECONCILE_STATES = Object.freeze({
  SENT_RECONCILED: 'SENT_RECONCILED',
  HUMAN_REVIEW_ZERO_MATCHES: 'HUMAN_REVIEW_ZERO_MATCHES',
  HUMAN_REVIEW_MULTIPLE_MATCHES: 'HUMAN_REVIEW_MULTIPLE_MATCHES',
});

export function reconcileMatches(checks, options) {
  const opts = options || {};
  const consecutiveRequired = opts.consecutiveRequired || 2;
  const polls = Array.isArray(checks) ? checks : [];

  let lastSingleMatchId = null;
  let consecutiveSameSingleMatch = 0;

  for (const matchIds of polls) {
    const ids = Array.isArray(matchIds) ? matchIds : [];
    if (ids.length > 1) {
      return { state: RECONCILE_STATES.HUMAN_REVIEW_MULTIPLE_MATCHES, matchCount: ids.length, matchIds: ids };
    }
    if (ids.length === 1) {
      const currentId = ids[0];
      if (currentId === lastSingleMatchId) {
        consecutiveSameSingleMatch += 1;
      } else {
        lastSingleMatchId = currentId;
        consecutiveSameSingleMatch = 1;
      }
      if (consecutiveSameSingleMatch >= consecutiveRequired) {
        return { state: RECONCILE_STATES.SENT_RECONCILED, matchCount: 1, matchId: currentId };
      }
    } else {
      lastSingleMatchId = null;
      consecutiveSameSingleMatch = 0;
    }
  }

  return { state: RECONCILE_STATES.HUMAN_REVIEW_ZERO_MATCHES, matchCount: 0, matchIds: [] };
}

// Wraps liveAdapterContract() with the single structured terminal object
// required of every Sender path. Unreachable in Phase 4A (see above).
export function buildLiveAdapterTerminal(item) {
  const withContract = liveAdapterContract(item);
  return {
    ...withContract,
    terminal: {
      schema_version: '1.0',
      result: 'BLOCKED',
      send_state: 'BLOCKED',
      reason: 'LIVE_ADAPTER_UNREACHABLE_IN_VALIDATION',
      live_adapter_contract: withContract.live_adapter_contract,
      sent: false,
    },
  };
}

export function liveAdapterContract(item) {
  const input = item || {};
  const nes = input.nes || {};
  const threading = nes.threading || {};
  const reply = nes.reply || {};
  const draft = input.draft || {};

  const subject = reply.subject || null;
  const replySubject = subject ? (/^re:/i.test(subject) ? subject : `Re: ${subject}`) : null;

  return {
    ...input,
    live_adapter_contract: {
      reachable: false,
      blocked: true,
      reason: 'VALIDATION_MODE_LIVE_ADAPTER_UNREACHABLE',
      // Verified V3 contract: POST /api/v2/emails/reply with eaccount,
      // reply_to_uuid, subject, body.text/html. Never sent in Phase 4A.
      request_contract: {
        method: 'POST',
        url: 'https://api.instantly.ai/api/v2/emails/reply',
        body: {
          eaccount: nes.eaccount || null,
          reply_to_uuid: threading.reply_to_uuid || null,
          subject: replySubject,
          body: {
            text: draft.draft_text || null,
            html: null,
          },
        },
      },
      retry_policy: {
        max_attempts: MAX_SEND_ATTEMPTS,
        base_backoff_ms: BASE_BACKOFF_MS,
        max_backoff_ms: MAX_BACKOFF_MS,
        retry_after_cap_ms: RETRY_AFTER_CAP_MS,
      },
      classification_contract: 'classifySendOutcome',
      reconciliation_contract: 'reconcileMatches',
    },
  };
}
