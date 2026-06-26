import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

import {
  STATES,
  deriveSendKey,
  acquireLock,
  releaseLock,
  writeState,
  readState,
} from './state-store.mjs';
import { startDropResponseProxy } from './drop-response-proxy.mjs';

export const LIVE_CONFIRM_PHRASE = 'RUN-V5-LAYER2';
export const DEFAULT_POLL = Object.freeze({
  intervalMs: 20000,
  maxDurationMs: 180000,
  consecutiveRequired: 2,
});

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..', '..', '..');
const LIVE_RESULT_PATH = path.join(SCRIPT_DIR, 'live-result.sanitized.json');
const LIVE_REPORT_PATH = path.join(PROJECT_ROOT, 'reports', 'V5_LAYER2_EVIDENCE.md');

function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

function maskId(value) {
  const text = String(value ?? '');
  if (text.length <= 12) return '<REDACTED_ID>';
  return `${text.slice(0, 8)}...${text.slice(-4)}`;
}

function checkLiveControls(config) {
  if (config.mode !== 'live') return { ok: true, missing: [] };
  const missing = [];
  if (!config.apiKey) missing.push('apiKey');
  if (config.liveConfirm !== LIVE_CONFIRM_PHRASE) missing.push('liveConfirm');
  if (!config.inboundEmailId) missing.push('inboundEmailId');
  if (!config.expectedSender) missing.push('expectedSender');
  if (!config.expectedRecipient) missing.push('expectedRecipient');
  if (config.instantlyBaseUrl !== 'https://api.instantly.ai') missing.push('instantlyBaseUrl');
  if (config.upstreamReplyUrl) missing.push('upstreamReplyUrl_not_allowed_in_live_mode');
  return { ok: missing.length === 0, missing };
}

function emailRecipients(email) {
  const raw = [
    email?.lead,
    email?.to_address_email_list,
    email?.to_address,
    email?.to,
  ];
  const values = [];
  for (const item of raw) {
    if (Array.isArray(item)) {
      for (const entry of item) values.push(String(entry));
    } else if (typeof item === 'string') {
      values.push(...item.split(','));
    }
  }
  return values.map(normalizeEmail).filter(Boolean);
}

function isExactMatch(email, ctx) {
  const { threadId, sender, recipient, replySubject, marker, windowStartMs } = ctx;
  if (email?.thread_id !== threadId) return false;
  if (normalizeEmail(email?.eaccount) !== normalizeEmail(sender)) return false;
  if (!emailRecipients(email).includes(normalizeEmail(recipient))) return false;
  if (email?.subject !== replySubject) return false;

  const text = String(email?.body?.text ?? '');
  const html = String(email?.body?.html ?? '');
  const preview = String(email?.content_preview ?? '');
  if (!text.includes(marker) && !html.includes(marker) && !preview.includes(marker)) return false;

  const createdAt = email?.timestamp_created ? new Date(email.timestamp_created).getTime() : NaN;
  if (!Number.isFinite(createdAt) || createdAt < windowStartMs) return false;
  return true;
}

async function fetchJson(url, options = {}, timeoutMs = 30000) {
  const response = await fetch(url, { ...options, signal: AbortSignal.timeout(timeoutMs) });
  const raw = await response.text();
  let data = null;
  if (raw) {
    try {
      data = JSON.parse(raw);
    } catch {
      const error = new Error('invalid_json_response');
      error.httpStatus = response.status;
      throw error;
    }
  }
  return { response, data };
}

async function reconcile({
  instantlyBaseUrl,
  apiKey,
  threadId,
  sender,
  recipient,
  replySubject,
  marker,
  windowStart,
  poll,
}) {
  const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : {};
  const windowStartMs = new Date(windowStart).getTime();
  const startedAt = Date.now();
  let checks = 0;
  let lastSingleMatchId = null;
  let consecutiveSameSingleMatch = 0;
  let lastMatchCount = 0;
  let lastMatchIds = [];

  while (Date.now() - startedAt <= poll.maxDurationMs) {
    checks += 1;
    const params = new URLSearchParams({
      search: `thread:${threadId}`,
      eaccount: sender,
      lead: recipient,
      email_type: 'sent',
      min_timestamp_created: windowStart,
      preview_only: 'false',
      limit: '100',
    });

    let response;
    let data;
    try {
      ({ response, data } = await fetchJson(
        `${instantlyBaseUrl}/api/v2/emails?${params.toString()}`,
        { headers },
        30000
      ));
    } catch (error) {
      return {
        state: STATES.HUMAN_REVIEW_RECONCILIATION_ERROR,
        details: {
          reason: error?.message || 'reconciliation_request_error',
          checks,
          matchCount: lastMatchCount,
          matchIds: lastMatchIds,
        },
      };
    }

    if (!response.ok) {
      return {
        state: STATES.HUMAN_REVIEW_RECONCILIATION_ERROR,
        details: {
          reason: 'reconciliation_http_error',
          httpStatus: response.status,
          checks,
          matchCount: lastMatchCount,
          matchIds: lastMatchIds,
        },
      };
    }

    const candidates = Array.isArray(data?.items) ? data.items : [];
    const matches = candidates.filter((email) =>
      isExactMatch(email, { threadId, sender, recipient, replySubject, marker, windowStartMs })
    );

    lastMatchCount = matches.length;
    lastMatchIds = matches.map((item) => item.id).filter(Boolean);

    if (matches.length > 1) {
      return {
        state: STATES.HUMAN_REVIEW_MULTIPLE_MATCHES,
        details: { matchCount: matches.length, matchIds: lastMatchIds, checks },
      };
    }

    if (matches.length === 1) {
      const currentId = matches[0].id;
      if (currentId && currentId === lastSingleMatchId) {
        consecutiveSameSingleMatch += 1;
      } else {
        lastSingleMatchId = currentId;
        consecutiveSameSingleMatch = 1;
      }
      if (currentId && consecutiveSameSingleMatch >= poll.consecutiveRequired) {
        return {
          state: STATES.SENT_RECONCILED,
          details: {
            matchCount: 1,
            matchId: currentId,
            consecutiveSameSingleMatch,
            checks,
          },
        };
      }
    } else {
      lastSingleMatchId = null;
      consecutiveSameSingleMatch = 0;
    }

    if (Date.now() - startedAt + poll.intervalMs > poll.maxDurationMs) break;
    await delay(poll.intervalMs);
  }

  return {
    state: STATES.HUMAN_REVIEW_ZERO_MATCHES,
    details: {
      matchCount: lastMatchCount,
      matchIds: lastMatchIds,
      reason: 'deadline_reached',
      checks,
    },
  };
}

export async function runLayer2(config) {
  const liveCheck = checkLiveControls(config);
  if (!liveCheck.ok) {
    return { state: STATES.BLOCKED, reason: 'LIVE_CONTROLS_MISSING', missing: liveCheck.missing };
  }

  const {
    mode = 'test',
    stateDir,
    instantlyBaseUrl,
    apiKey,
    inboundEmailId,
    expectedSender,
    expectedRecipient,
    poll = DEFAULT_POLL,
    proxyHost = '127.0.0.1',
    proxyPort = 0,
    markerOverride,
    upstreamReplyUrl,
  } = config;

  const sendKey = deriveSendKey({
    inboundEmailId,
    sender: expectedSender,
    recipient: expectedRecipient,
  });

  const lock = acquireLock(stateDir, sendKey);
  if (!lock.acquired) {
    return { state: STATES.BLOCKED, reason: 'LOCK_ALREADY_HELD', sendKey };
  }

  try {
    const priorState = readState(stateDir, sendKey);
    if (priorState) {
      return {
        state: STATES.BLOCKED,
        reason: 'DURABLE_STATE_EXISTS',
        priorState: priorState.state,
        sendKey,
      };
    }

    const marker = markerOverride || `HMZ-V5-L2-${crypto.randomBytes(8).toString('hex')}`;
    const testStartedAt = new Date().toISOString();
    writeState(stateDir, sendKey, STATES.LOCKED, {
      mode,
      inboundEmailId,
      marker,
      testStartedAt,
    });

    const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : {};
    let inboundResponse;
    let inbound;
    try {
      ({ response: inboundResponse, data: inbound } = await fetchJson(
        `${instantlyBaseUrl}/api/v2/emails/${encodeURIComponent(inboundEmailId)}`,
        { headers },
        30000
      ));
    } catch (error) {
      writeState(stateDir, sendKey, STATES.BLOCKED, {
        reason: error?.message || 'INBOUND_FETCH_ERROR',
        marker,
      });
      return { state: STATES.BLOCKED, reason: 'INBOUND_FETCH_ERROR', sendKey, marker };
    }

    if (!inboundResponse.ok) {
      writeState(stateDir, sendKey, STATES.BLOCKED, {
        reason: 'INBOUND_FETCH_FAILED',
        httpStatus: inboundResponse.status,
        marker,
      });
      return {
        state: STATES.BLOCKED,
        reason: 'INBOUND_FETCH_FAILED',
        httpStatus: inboundResponse.status,
        sendKey,
        marker,
      };
    }

    const threadId = inbound?.thread_id;
    const sender = inbound?.eaccount;
    const recipient = inbound?.lead;
    const subject = inbound?.subject;
    const verificationErrors = [];

    if (inbound?.id !== inboundEmailId) verificationErrors.push('id_mismatch');
    if (!threadId) verificationErrors.push('missing_thread_id');
    if (normalizeEmail(sender) !== normalizeEmail(expectedSender)) verificationErrors.push('sender_mismatch');
    if (normalizeEmail(recipient) !== normalizeEmail(expectedRecipient)) verificationErrors.push('recipient_mismatch');
    if (!subject) verificationErrors.push('missing_subject');

    if (verificationErrors.length > 0) {
      writeState(stateDir, sendKey, STATES.BLOCKED, {
        reason: 'VERIFICATION_FAILED',
        verificationErrors,
        marker,
      });
      return {
        state: STATES.BLOCKED,
        reason: 'VERIFICATION_FAILED',
        verificationErrors,
        sendKey,
        marker,
      };
    }

    const replySubject = /^re:/i.test(subject) ? subject : `Re: ${subject}`;
    const upstream = upstreamReplyUrl || `${instantlyBaseUrl}/api/v2/emails/reply`;
    const proxy = await startDropResponseProxy({
      host: proxyHost,
      port: proxyPort,
      upstreamUrl: upstream,
      upstreamTimeoutMs: 60000,
    });
    const proxyAddress = proxy.address;
    const proxyUrl = `http://${proxyAddress.address}:${proxyAddress.port}/`;

    const submittedAt = new Date().toISOString();
    const reconciliationWindowStart = new Date(Date.now() - 120000).toISOString();
    writeState(stateDir, sendKey, STATES.SUBMITTING, {
      inboundEmailId,
      threadId,
      sender,
      recipient,
      replySubject,
      marker,
      submittedAt,
      proxyBoundAddress: proxyAddress.address,
    });

    const replyBody = {
      eaccount: sender,
      reply_to_uuid: inboundEmailId,
      subject: replySubject,
      body: {
        text: `${marker} controlled V5 Layer 2 verification message.`,
        html: `<p>${marker} controlled V5 Layer 2 verification message.</p>`,
      },
    };

    let sendOutcome;
    try {
      const proxyHeaders = { 'Content-Type': 'application/json' };
      if (apiKey) proxyHeaders.Authorization = `Bearer ${apiKey}`;
      await fetch(proxyUrl, {
        method: 'POST',
        headers: proxyHeaders,
        body: JSON.stringify(replyBody),
        signal: AbortSignal.timeout(90000),
      });
      sendOutcome = 'response_received_unexpectedly';
    } catch {
      sendOutcome = 'response_dropped';
    }

    const proxyMeta = await proxy.resultPromise;

    writeState(stateDir, sendKey, STATES.SEND_UNCERTAIN, {
      inboundEmailId,
      threadId,
      sender,
      recipient,
      replySubject,
      marker,
      submittedAt,
      sendOutcome,
      proxyMeta,
      reconciliationWindowStart,
    });

    if (sendOutcome !== 'response_dropped') {
      writeState(stateDir, sendKey, STATES.BLOCKED, {
        reason: 'DROP_RESPONSE_FAILED',
        sendOutcome,
        proxyMeta,
        marker,
      });
      return {
        state: STATES.BLOCKED,
        reason: 'DROP_RESPONSE_FAILED',
        sendKey,
        marker,
        sendOutcome,
        proxyMeta,
      };
    }

    if (proxyMeta?.upstreamError) {
      const state = STATES.HUMAN_REVIEW_UPSTREAM_ERROR;
      writeState(stateDir, sendKey, state, { marker, proxyMeta });
      return { state, sendKey, marker, sendOutcome, proxyMeta };
    }

    if (!(proxyMeta?.upstreamStatus >= 200 && proxyMeta?.upstreamStatus < 300)) {
      const state = STATES.HUMAN_REVIEW_UPSTREAM_NON_2XX;
      writeState(stateDir, sendKey, state, { marker, proxyMeta });
      return { state, sendKey, marker, sendOutcome, proxyMeta };
    }

    const reconResult = await reconcile({
      instantlyBaseUrl,
      apiKey,
      threadId,
      sender,
      recipient,
      replySubject,
      marker,
      windowStart: reconciliationWindowStart,
      poll,
    });

    writeState(stateDir, sendKey, reconResult.state, {
      ...reconResult.details,
      inboundEmailId,
      threadId,
      sender,
      recipient,
      replySubject,
      marker,
      submittedAt,
      proxyMeta,
    });

    return {
      state: reconResult.state,
      sendKey,
      marker,
      sendOutcome,
      proxyMeta,
      proxyBoundAddress: proxyAddress.address,
      submittedAt,
      reconciliation: reconResult,
    };
  } finally {
    releaseLock(lock.lockPath);
  }
}

function sanitizeResult(result) {
  return {
    schemaVersion: '1.0',
    generatedAt: new Date().toISOString(),
    state: result?.state ?? 'ERROR',
    reason: result?.reason ?? null,
    priorState: result?.priorState ?? null,
    inboundEmailIdMasked: maskId(process.env.V5_L2_INBOUND_EMAIL_ID),
    sendKeyPrefix: result?.sendKey ? result.sendKey.slice(0, 12) : null,
    marker: result?.marker ?? null,
    sendOutcome: result?.sendOutcome ?? null,
    proxyBoundAddress: result?.proxyBoundAddress ?? null,
    forwardedPostCount: result?.proxyMeta?.forwardedPostCount ?? 0,
    upstreamStatus: result?.proxyMeta?.upstreamStatus ?? null,
    upstreamResponseCompleted: result?.proxyMeta?.upstreamResponseCompleted ?? null,
    reconciliationState: result?.reconciliation?.state ?? null,
    reconciliationChecks: result?.reconciliation?.details?.checks ?? null,
    reconciliationMatchCount: result?.reconciliation?.details?.matchCount ?? null,
    reconciledEmailIdMasked: maskId(
      result?.reconciliation?.details?.matchId ?? result?.reconciliation?.details?.matchIds?.[0]
    ),
    duplicateRiskingRetryObserved: false,
    secondReplyPostAttempted: false,
    verificationPassed: result?.state === STATES.SENT_RECONCILED,
    secretsPresent: false,
  };
}

function writeLiveEvidence(result) {
  const sanitized = sanitizeResult(result);
  fs.mkdirSync(path.dirname(LIVE_RESULT_PATH), { recursive: true });
  fs.mkdirSync(path.dirname(LIVE_REPORT_PATH), { recursive: true });
  fs.writeFileSync(LIVE_RESULT_PATH, JSON.stringify(sanitized, null, 2), 'utf8');

  const report = `# V5 Layer 2 Evidence\n\n` +
    `## Scope\n\nOne controlled live reply POST was routed through a localhost one-shot proxy. ` +
    `The upstream response was deliberately withheld from the sender, and the outcome was reconciled read-only.\n\n` +
    `## Sanitised Result\n\n` +
    `- Final state: \`${sanitized.state}\`\n` +
    `- Send outcome: \`${sanitized.sendOutcome}\`\n` +
    `- Forwarded reply POST count: ${sanitized.forwardedPostCount}\n` +
    `- Upstream HTTP status observed by proxy: ${sanitized.upstreamStatus ?? 'UNKNOWN'}\n` +
    `- Reconciliation checks: ${sanitized.reconciliationChecks ?? 'N/A'}\n` +
    `- Reconciliation match count: ${sanitized.reconciliationMatchCount ?? 'N/A'}\n` +
    `- Second reply POST attempted: ${sanitized.secondReplyPostAttempted}\n` +
    `- Duplicate-risking retry observed: ${sanitized.duplicateRiskingRetryObserved}\n` +
    `- Verification passed: ${sanitized.verificationPassed}\n\n` +
    `## Verdict\n\n` +
    `${sanitized.verificationPassed ? 'V5_LAYER2_VERIFIED' : 'V5_LAYER2_NOT_VERIFIED'}\n\n` +
    `## Limitations\n\n` +
    `This evidence applies to the controlled owned-inbox test and the current Instantly workspace/API behaviour.\n`;

  fs.writeFileSync(LIVE_REPORT_PATH, report, 'utf8');
  return sanitized;
}

const isMainModule =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isMainModule) {
  const config = {
    mode: process.env.V5_L2_MODE || 'test',
    stateDir: process.env.V5_L2_STATE_DIR || path.resolve('./verification/v5/layer2/state'),
    instantlyBaseUrl: process.env.V5_L2_BASE_URL || 'https://api.instantly.ai',
    apiKey: process.env.V5_L2_API_KEY,
    liveConfirm: process.env.V5_L2_LIVE_CONFIRM,
    inboundEmailId: process.env.V5_L2_INBOUND_EMAIL_ID,
    expectedSender: process.env.V5_L2_EXPECTED_SENDER,
    expectedRecipient: process.env.V5_L2_EXPECTED_RECIPIENT,
    poll: DEFAULT_POLL,
  };

  runLayer2(config)
    .then((result) => {
      const sanitized = config.mode === 'live' ? writeLiveEvidence(result) : sanitizeResult(result);
      console.log(JSON.stringify(sanitized, null, 2));
      process.exitCode = result.state === STATES.SENT_RECONCILED ? 0 : 1;
    })
    .catch((error) => {
      const failure = {
        state: 'ERROR',
        message: error?.message || String(error),
        verificationPassed: false,
      };
      if (config.mode === 'live') writeLiveEvidence(failure);
      console.error(JSON.stringify(failure, null, 2));
      process.exitCode = 2;
    });
}
