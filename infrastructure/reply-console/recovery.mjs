// Compatibility facade for the canonical v2 inbound service.
//
// The production poll endpoint now calls createInboundService().runNormalPoll
// directly. These exports remain for CLI/tests and deliberately contain no
// category eligibility logic: every record returned by Instantly's received
// endpoint is delegated to the same canonical contract and transactional
// outbox as webhook and completeness-audit paths.

import { sanitizeChatText, buildNotificationText } from './inbound-contract.mjs';
import { createInboundService } from './inbound-service.mjs';
import { getPollState } from './inbound-store.mjs';

export function sanitizePreview(value, max = 700) {
  return sanitizeChatText(value, max);
}

export function getHighWaterMark(base) {
  const state = getPollState(base, 'normal-recovery-poll');
  return state ? {
    ts: state.cursor_timestamp,
    emailId: state.cursor_email_id,
    updatedAt: state.updated_at,
  } : { ts: null, emailId: null };
}

// Legacy helper retained only for callers that already hold a canonical
// context-shaped object. New code posts exclusively through the leased outbox.
export async function postRecoveredNotification(notifyUrl, record, doFetch = fetch, options = {}) {
  if (!notifyUrl) return null;
  let destination;
  try {
    destination = new URL(notifyUrl);
    destination.searchParams.set('messageReplyOption', 'REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD');
  } catch { return null; }
  try {
    const response = await doFetch(destination.toString(), {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: buildNotificationText(record, { recovered: true, probableDuplicate: options.probableDuplicate === true }),
        thread: { threadKey: record.threadKey },
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (response.status < 200 || response.status >= 300) return null;
    const payload = JSON.parse(await response.text());
    return payload && payload.name ? payload : null;
  } catch { return null; }
}

export async function pollRecover(base, {
  apiKey,
  apiBase = 'https://api.instantly.ai/api/v2',
  fetchImpl = fetch,
  notifyUrl = '',
  notifyFetch = fetch,
  overlapMs = 5 * 60_000,
  pageLimit = 100,
  maxPages = 10_000,
  campaignScope = null,
} = {}) {
  const service = createInboundService({
    stateDir: base, apiKey, apiBase, notifyUrl,
    fetchImpl, chatFetch: notifyFetch, allowMockChatUrl: true, pageLimit,
  });
  service.migrateLegacyAcknowledgements();
  const result = await service.runNormalPoll({ overlapMs, maxPages, campaign: campaignScope, indexingDelayMs: 0 });
  return {
    ...result,
    scanned: result.observed || 0,
    recovered: result.created || 0,
    alreadyPresent: Math.max(0, (result.observed || 0) - (result.created || 0)),
    retry: result.drain ? { attempted: result.drain.attempted, recovered: result.drain.notified } : { attempted: 0, recovered: 0 },
  };
}

export async function retryStuckNotifications(base, {
  notifyUrl = '', notifyFetch = fetch,
} = {}) {
  const service = createInboundService({ stateDir: base, notifyUrl, chatFetch: notifyFetch, allowMockChatUrl: true });
  service.migrateLegacyAcknowledgements();
  const result = await service.drainOutbox({ limit: 100, maxBatches: 10 });
  return { attempted: result.attempted, recovered: result.notified, ambiguous: result.ambiguous, retrying: result.retrying };
}
