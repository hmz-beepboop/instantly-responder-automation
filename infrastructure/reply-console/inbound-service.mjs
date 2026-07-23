// Shared inbound notification service used by webhook, poll, backfill and the
// independent completeness auditor. No function in this file can send a
// prospect email; the only outbound transport is the fixed Google Chat URL.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {
  normalizeInstantlyReceived, buildNotificationText, IDENTITY_KINDS,
} from './inbound-contract.mjs';
import {
  OUTBOX_STATES, registerInbound, registerInboundBatch, getInbound, getNotification,
  setLegacyContextId, updateInboundEnrichment, importAcknowledgedLegacy,
  acquireNamedLease, renewNamedLease, releaseNamedLease, claimNotifications,
  beginNotificationAttempts, finishNotificationAttempts, markProbableDuplicates,
  requeueUnacknowledged, getPollState, commitPollState, startAuditRun,
  recordAuditDiscrepancy, finishAuditRun, updateHeartbeat, persistAlert,
  resolveAlertsNotIn, incrementCounter, operationsSnapshot, integrityCheck,
  releaseExpiredNotificationLeases, openInboundStore, saveReconciliationSnapshot,
  watchdogFacts, notificationQueueDepth,
} from './inbound-store.mjs';
import {
  createContext, findByInstantlyEmailId, attachChatPost, readContext,
} from './store.mjs';
import {
  resolveSenderName, resolveProspectNameByLookup, getCachedAccount, normalizeName,
  resolveCampaignName, getCachedCampaignName,
} from './enrich.mjs';

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

function iso(ms) { return new Date(ms).toISOString(); }
function randomWorker(prefix) { return `${prefix}:${process.pid}:${crypto.randomBytes(6).toString('hex')}`; }
function hasDefiniteLegacyChatAcknowledgement(context) {
  return /^spaces\/[^/\s]+\/messages\/[^/\s]+$/.test(String(context?.chatMessageName || '').trim());
}
function legacyAcknowledgement(context) {
  return {
    messageName: String(context.chatMessageName).trim(),
    threadName: context.chatThreadName || null,
    httpStatus: context.chatStatus || 200,
    ackAt: context.chatNotifiedAt || context.notificationUpdatedAt || context.updatedAt || context.createdAt,
  };
}
function redactError(error) {
  const message = String(error?.message || error || 'unknown_error');
  return message.replace(/https?:\/\/\S+/gi, '<url-redacted>').replace(/Bearer\s+\S+/gi, 'Bearer <redacted>').slice(0, 180);
}

function validateChatDestination(url, allowMockChatUrl) {
  if (!url) return null;
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:') throw new Error('chat_destination_must_be_https');
  if (!allowMockChatUrl && parsed.hostname !== 'chat.googleapis.com') throw new Error('chat_destination_not_google_chat');
  parsed.searchParams.set('messageReplyOption', 'REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD');
  return parsed.toString();
}

async function responseJson(response, { maxBytes = 100_000 } = {}) {
  const declared = Number(response.headers?.get?.('content-length'));
  if (Number.isFinite(declared) && declared > maxBytes) {
    const error = new Error('response_too_large'); error.code = 'RESPONSE_TOO_LARGE'; throw error;
  }
  const reader = response.body?.getReader?.();
  if (!reader) {
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > maxBytes) {
      const error = new Error('response_too_large'); error.code = 'RESPONSE_TOO_LARGE'; throw error;
    }
    if (!text.trim()) return null;
    return JSON.parse(text);
  }
  const decoder = new TextDecoder();
  let text = '', bytes = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    bytes += value.byteLength;
    if (bytes > maxBytes) {
      await reader.cancel().catch(() => {});
      const error = new Error('response_too_large'); error.code = 'RESPONSE_TOO_LARGE'; throw error;
    }
    text += decoder.decode(value, { stream: true });
  }
  text += decoder.decode();
  if (!text.trim()) return null;
  return JSON.parse(text);
}

export async function fetchInstantlyReceivedRange({
  apiKey,
  apiBase = 'https://api.instantly.ai/api/v2',
  since,
  until,
  pageLimit = 100,
  maxPages = 10_000,
  campaign = null,
  fetchImpl = fetch,
  onPage = null,
} = {}) {
  if (!apiKey) return { ok: false, errorKind: 'INSTANTLY_NO_API_KEY', status: null, pages: 0, items: [] };
  if (!since || !until || !Number.isFinite(Date.parse(since)) || !Number.isFinite(Date.parse(until))) {
    return { ok: false, errorKind: 'INVALID_RANGE', status: null, pages: 0, items: [] };
  }
  const base = apiBase.replace(/\/$/, '');
  const all = [];
  const pageTokens = new Set();
  let startingAfter = null;
  let pages = 0;
  for (;;) {
    if (pages >= maxPages) {
      return { ok: false, errorKind: 'PAGINATION_SAFETY_LIMIT', status: null, pages, items: all };
    }
    const qs = new URLSearchParams({
      email_type: 'received', min_timestamp_created: since, max_timestamp_created: until,
      sort_order: 'asc', limit: String(Math.max(1, Math.min(100, Number(pageLimit) || 100))),
    });
    if (campaign) qs.set('campaign', campaign);
    if (startingAfter) qs.set('starting_after', startingAfter);
    let response;
    try {
      response = await fetchImpl(`${base}/emails?${qs}`, {
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        redirect: 'error',
        signal: AbortSignal.timeout(15_000),
      });
    } catch (error) {
      return { ok: false, errorKind: 'INSTANTLY_NETWORK_ERROR', safeDetail: redactError(error), status: null, pages, items: all };
    }
    if (response.status !== 200) {
      const kind = response.status === 401 ? 'INSTANTLY_401'
        : response.status === 429 ? 'INSTANTLY_429'
          : response.status >= 500 ? 'INSTANTLY_5XX' : `INSTANTLY_HTTP_${response.status}`;
      return { ok: false, errorKind: kind, status: response.status, pages, items: all };
    }
    let payload;
    try { payload = await responseJson(response, { maxBytes: 8 * 1024 * 1024 }); }
    catch (error) { return { ok: false,
      errorKind: error?.code === 'RESPONSE_TOO_LARGE' ? 'INSTANTLY_RESPONSE_TOO_LARGE' : 'INSTANTLY_INVALID_JSON',
      safeDetail: redactError(error), status: 200, pages, items: all }; }
    const hasItems = Array.isArray(payload?.items) || Array.isArray(payload?.data);
    if (!hasItems) return { ok: false, errorKind: 'INSTANTLY_INVALID_SCHEMA', status: 200, pages, items: all };
    const items = Array.isArray(payload?.items) ? payload.items : payload.data;
    pages += 1;
    all.push(...items);
    if (onPage) {
      try { await onPage(items, { page: pages, startingAfter }); }
      catch (error) { return { ok: false, errorKind: 'DURABLE_STORE_FAILURE', safeDetail: redactError(error), status: 200, pages, items: all }; }
    }
    const next = payload?.next_starting_after || payload?.starting_after || null;
    if (!next) return { ok: true, pages, items: all };
    if (pageTokens.has(next) || next === startingAfter) {
      return { ok: false, errorKind: 'PAGINATION_TOKEN_LOOP', status: 200, pages, items: all };
    }
    pageTokens.add(next);
    startingAfter = String(next);
  }
}

export function createInboundService({
  stateDir,
  apiKey = '',
  apiBase = 'https://api.instantly.ai/api/v2',
  notifyUrl = '',
  fetchImpl = fetch,
  chatFetch = fetch,
  allowMockChatUrl = false,
  notificationEpoch = null,
  now = () => Date.now(),
  pageLimit = 100,
} = {}) {
  if (!stateDir) throw new Error('stateDir_required');
  openInboundStore(stateDir);
  const chatDestination = validateChatDestination(notifyUrl, allowMockChatUrl);
  const epochMs = notificationEpoch && Number.isFinite(Date.parse(notificationEpoch)) ? Date.parse(notificationEpoch) : null;

  function queuePolicyFor(record) {
    if (epochMs !== null && record.receivedAt && Date.parse(record.receivedAt) < epochMs) return 'HISTORICAL_OWNER_HOLD';
    return 'QUEUE';
  }

  // Resolves the three presentation fields a notification card needs, using the
  // authoritative Instantly sources and the durable caches. Never throws.
  async function resolvePresentationEnrichment(record) {
    let prospectName = record.prospectName;
    let prospectNameSource = prospectName ? 'WEBHOOK_OR_API' : 'UNAVAILABLE';
    let sender = { name: '', source: 'UNRESOLVED', eligible: false };
    let error = null;
    try {
      if (!prospectName && record.prospectEmail) {
        const prospect = await resolveProspectNameByLookup(record.prospectEmail, record.campaignId,
          { apiKey, apiBase, fetchImpl });
        prospectName = prospect.name || '';
        prospectNameSource = prospect.source || 'UNAVAILABLE';
      }
      sender = await resolveSenderName(stateDir, record.eaccount, { apiKey, apiBase, fetchImpl });
      // Warm the durable campaign cache here so the leased Chat drain stays
      // network-free and never issues a request per card.
      await resolveCampaignName(stateDir, record.campaignId, { apiKey, apiBase, fetchImpl });
    } catch (err) {
      error = redactError(err);
    }
    return { prospectName, prospectNameSource, sender, error };
  }

  async function enrichAndCreateLegacyContext(record) {
    const existing = record.instantlyEmailId ? findByInstantlyEmailId(stateDir, record.instantlyEmailId) : null;
    if (existing) {
      if (hasDefiniteLegacyChatAcknowledgement(existing)) {
        importAcknowledgedLegacy(stateDir, record, legacyAcknowledgement(existing), {
          contextId: existing.notificationId, now: now(),
        });
        return { ok: true, existing: true, acknowledgementImported: true, contextId: existing.notificationId };
      }
      setLegacyContextId(stateDir, record.identity, existing.notificationId);
      return { ok: true, existing: true, acknowledgementImported: false, contextId: existing.notificationId };
    }
    // Presentation-only enrichment. Persistence has already committed before
    // these optional API lookups. This runs for EVERY registered record,
    // including classifications that can never be replied to (automatic,
    // out-of-office, unsubscribe) — those cards still have to show the prospect
    // name and campaign display name. It grants no capability: the sendAllowed
    // gate below is unchanged and still refuses to create a reply context.
    const enriched = await resolvePresentationEnrichment(record);
    if (!record.sendAllowed) {
      updateInboundEnrichment(stateDir, record.identity, {
        ok: false, blocked: true, prospectName: enriched.prospectName,
        error: 'ROUTING_OR_CLASSIFICATION_BLOCKED',
      });
      return { ok: false, blocked: true, reason: 'SEND_NOT_SAFE' };
    }
    const { prospectName, prospectNameSource, sender } = enriched;
    updateInboundEnrichment(stateDir, record.identity, enriched.error
      ? { ok: false, prospectName, error: enriched.error }
      : { ok: true, prospectName });
    const created = createContext(stateDir, {
      replyToUuid: record.instantlyEmailId,
      instantlyEmailId: record.instantlyEmailId,
      eaccount: record.eaccount,
      prospectEmail: record.prospectEmail,
      subject: record.subject || '',
      campaignId: record.campaignId,
      campaignName: record.campaignName,
      uniboxUrl: record.uniboxUrl,
      authoritativeThreadId: record.threadId,
      receivedAt: record.receivedAt || record.observedAt,
      prospectName,
      prospectNameSource,
      senderName: sender.name || '',
      senderNameSource: sender.source || 'UNRESOLVED',
      senderEligible: sender.eligible === true,
      discoverySource: record.discoverySources?.includes('COMPLETENESS_AUDIT') ? 'COMPLETENESS_AUDIT' : record.discoverySources?.[0],
      preview: record.preview || '',
      threadKey: record.threadKey,
    });
    if (created.ok) {
      setLegacyContextId(stateDir, record.identity, created.context.notificationId);
      // A record that was already notified before it became reply-eligible
      // (automatic/OOO cards posted under the pre-r13 policy) keeps its original
      // Chat message. Link the stored acknowledgement to the context through the
      // same attachChatPost path the drain uses, so the existing thread resolves
      // for @Instantly. No repost, no card mutation, no new notification.
      const outbox = getNotification(stateDir, record.identity);
      if (outbox && outbox.ackMessageName) {
        attachChatPost(stateDir, created.context.notificationId, {
          chatMessageName: outbox.ackMessageName,
          chatThreadName: outbox.ackThreadName,
          chatStatus: outbox.ackHttpStatus || 200,
        });
      }
      return { ok: true, created: created.created, contextId: created.context.notificationId };
    }
    updateInboundEnrichment(stateDir, record.identity, { ok: false, prospectName, error: `CONTEXT_${created.reason || 'FAILED'}` });
    return { ok: false, reason: created.reason || 'CONTEXT_FAILED' };
  }

  async function registerReceived(raw, {
    authoritativeReceived = false,
    discoverySource = 'DISCOVERED_WEBHOOK',
    workspace = '',
    recovered = false,
    createLegacy = true,
  } = {}) {
    const normalized = normalizeInstantlyReceived(raw, {
      authoritativeReceived, discoverySource, workspace, observedAt: iso(now()),
    });
    if (!normalized.ok) return normalized;
    const registered = registerInbound(stateDir, normalized.record, {
      queuePolicy: queuePolicyFor(normalized.record), recovered, now: now(),
    });
    if (registered.created) {
      const metric = discoverySource === 'DISCOVERED_WEBHOOK' ? 'webhook_discovered'
        : discoverySource === 'NORMAL_POLL' ? 'normal_poll_recovered'
          : discoverySource === 'COMPLETENESS_AUDIT' ? 'completeness_audit_recovered' : 'inbound_registered';
      incrementCounter(stateDir, metric, 1, { now: now() });
    } else {
      incrementCounter(stateDir, 'duplicate_logical_events_suppressed', 1, { now: now() });
    }
    let legacy = null;
    if (createLegacy && registered.outbox.state !== OUTBOX_STATES.HISTORICAL_HOLD) {
      legacy = await enrichAndCreateLegacyContext(registered.record);
    }
    return { ok: true, notificationRequired: true, created: registered.created,
      record: getInbound(stateDir, registered.record.identity), outbox: getNotification(stateDir, registered.record.identity), legacy };
  }

  async function chatTransport(item, probableDuplicate) {
    if (!chatDestination) {
      return { acknowledged: false, ambiguous: false, errorKind: 'CHAT_DESTINATION_NOT_CONFIGURED' };
    }

    // Resolve the sending mailbox display name from the durable cache (no
    // network) so the live notification card shows it, not only the draft card.
    const acct = getCachedAccount(stateDir, item.record.eaccount);
    const senderName = acct && acct.found !== false ? normalizeName(acct.firstName, acct.lastName) : '';
    // Same contract for the campaign display name: durable cache, no network.
    const campaignName = getCachedCampaignName(stateDir, item.record.campaignId);

    let response;
    try {
      response = await chatFetch(chatDestination, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: buildNotificationText(item.record, {
            recovered: item.outbox.recovered,
            probableDuplicate,
            historicalBackfill: item.outbox.historicalBackfill,
            senderName,
            campaignName,
          }),
          thread: { threadKey: item.record.threadKey },
        }),
        redirect: 'error',
        signal: AbortSignal.timeout(10_000),
      });
    } catch (error) {
      return { acknowledged: false, ambiguous: true, errorKind: `CHAT_NETWORK_${redactError(error)}` };
    }

    let payload = null;
    try { payload = await responseJson(response); }
    catch (error) {
      return { acknowledged: false, ambiguous: response.status >= 200 && response.status < 300,
        httpStatus: response.status, errorKind: `CHAT_RESPONSE_${redactError(error)}` };
    }
    const name = typeof payload?.name === 'string' && payload.name ? payload.name : null;
    const threadName = typeof payload?.thread?.name === 'string' ? payload.thread.name : null;
    const acknowledged = response.status >= 200 && response.status < 300 && Boolean(name);
    return {
      acknowledged,
      ambiguous: response.status >= 200 && response.status < 300 && !name,
      httpStatus: response.status,
      messageName: name,
      threadName,
      errorKind: acknowledged ? null : (response.status >= 200 && response.status < 300 ? 'CHAT_ACK_ID_MISSING' : `CHAT_HTTP_${response.status}`),
      responseMetadata: payload ? { hasName: Boolean(name), hasThreadName: Boolean(threadName) } : null,
    };
  }

  async function drainOutbox({ limit = 25, maxBatches = 1, workerId = randomWorker('notify'), leaseMs = 30_000 } = {}) {
    releaseExpiredNotificationLeases(stateDir, { now: now() });
    let attempted = 0, notified = 0, ambiguous = 0, retrying = 0;
    for (let batch = 0; batch < maxBatches; batch++) {
      const claimed = claimNotifications(stateDir, workerId, { limit, leaseMs, now: now() });
      if (!claimed.length) break;
      const descriptors = claimed.map((item) => ({
        notificationId: item.outbox.notificationId,
        probableDuplicate: item.outbox.ambiguityCount > 0,
      }));
      const probableIds = descriptors.filter((item) => item.probableDuplicate).map((item) => item.notificationId);
      if (probableIds.length) {
        markProbableDuplicates(stateDir, probableIds, { now: now() });
        incrementCounter(stateDir, 'probable_duplicate_chat_posts', probableIds.length, { now: now() });
      }
      const begun = beginNotificationAttempts(stateDir, descriptors, workerId, { now: now() });
      const claimedById = new Map(claimed.map((item) => [item.outbox.notificationId, item]));
      const openAttempts = begun.filter((item) => item.ok);
      const transports = await Promise.all(openAttempts.map(async (attempt) => ({
        attempt,
        transport: await chatTransport(claimedById.get(attempt.notificationId),
          claimedById.get(attempt.notificationId).outbox.ambiguityCount > 0),
      })));
      const results = finishNotificationAttempts(stateDir, transports.map(({ attempt, transport }) => ({
        notificationId: attempt.notificationId,
        attemptId: attempt.attemptId,
        result: transport,
      })), workerId, { now: now() });
      for (const { attempt, transport } of transports) {
        const item = claimedById.get(attempt.notificationId);
        if (transport.acknowledged && item.record.legacyContextId) {
          attachChatPost(stateDir, item.record.legacyContextId, {
            chatMessageName: transport.messageName,
            chatThreadName: transport.threadName,
            chatStatus: transport.httpStatus,
          });
        }
      }
      attempted += results.length;
      for (const result of results) {
        if (result.state === OUTBOX_STATES.NOTIFIED) notified++;
        else if (result.state === OUTBOX_STATES.AMBIGUOUS) ambiguous++;
        else if (result.state === OUTBOX_STATES.RETRYING) retrying++;
      }
    }
    return { ok: true, attempted, notified, ambiguous, retrying,
      queueDepth: notificationQueueDepth(stateDir) };
  }

  function normalizePage(items, source) {
    const unique = new Map();
    let invalid = 0;
    for (const raw of items) {
      const normalized = normalizeInstantlyReceived(raw, {
        authoritativeReceived: true, discoverySource: source, observedAt: iso(now()),
      });
      if (!normalized.ok) { invalid++; continue; }
      unique.set(normalized.record.identity, normalized.record);
    }
    return { records: [...unique.values()], duplicateCount: items.length - unique.size - invalid, invalid };
  }

  function currentStateFor(records, duplicateLogicalCount = 0) {
    const metrics = {
      instantlyReceivedObserved: records.length,
      durableInboundPresent: 0, durableInboundMissing: 0,
      outboxPresent: 0, outboxMissing: 0,
      chatNotified: 0, queued: 0, retrying: 0, ambiguous: 0, historicalOwnerHold: 0,
      degradedMetadata: 0, autoReply: 0, ooo: 0, unsubscribe: 0, bounceSystem: 0,
      attachmentOnly: 0, surrogateIdentity: 0, duplicateLogicalCount,
      probableDuplicateChatPosts: 0,
    };
    for (const observed of records) {
      const inbound = getInbound(stateDir, observed.instantlyEmailId || observed.identity);
      if (!inbound) { metrics.durableInboundMissing++; continue; }
      metrics.durableInboundPresent++;
      if (inbound.degradedMetadata) metrics.degradedMetadata++;
      if (inbound.identityKind === IDENTITY_KINDS.SURROGATE) metrics.surrogateIdentity++;
      if (inbound.classification === 'automatic') metrics.autoReply++;
      if (inbound.classification === 'out_of_office') metrics.ooo++;
      if (inbound.classification === 'unsubscribe') metrics.unsubscribe++;
      if (inbound.classification === 'bounce' || inbound.classification === 'system') metrics.bounceSystem++;
      if (inbound.classification === 'attachment_only') metrics.attachmentOnly++;
      const outbox = getNotification(stateDir, inbound.identity);
      if (!outbox) { metrics.outboxMissing++; continue; }
      metrics.outboxPresent++;
      metrics.probableDuplicateChatPosts += outbox.probableDuplicateCount;
      if (outbox.state === OUTBOX_STATES.NOTIFIED) metrics.chatNotified++;
      else if (outbox.state === OUTBOX_STATES.RETRYING) metrics.retrying++;
      else if (outbox.state === OUTBOX_STATES.AMBIGUOUS) metrics.ambiguous++;
      else if (outbox.state === OUTBOX_STATES.HISTORICAL_HOLD) metrics.historicalOwnerHold++;
      else metrics.queued++;
    }
    return metrics;
  }

  async function runNormalPoll({ overlapMs = 5 * 60_000, initialWindowMs = DAY, indexingDelayMs = 15_000,
    maxPages = 10_000, campaign = null } = {}) {
    const owner = randomWorker('poll');
    if (!acquireNamedLease(stateDir, 'normal-recovery-poll', owner, { leaseMs: 5 * 60_000, now: now() })) {
      return { ok: false, reason: 'POLL_LEASE_BUSY' };
    }
    const state = getPollState(stateDir, 'normal-recovery-poll');
    const rangeEnd = iso(now() - indexingDelayMs);
    const rangeStart = state?.cursor_timestamp
      ? iso(Date.parse(state.cursor_timestamp) - overlapMs)
      : iso(now() - initialWindowMs);
    let pageCount = 0, observed = 0, created = 0, duplicates = 0;
    const observedRecords = new Map();
    let lastApiError = null;
    try {
      const fetched = await fetchInstantlyReceivedRange({ apiKey, apiBase, since: rangeStart, until: rangeEnd,
        pageLimit, maxPages, campaign, fetchImpl,
        onPage: async (items, page) => {
          pageCount = page.page;
          const normalized = normalizePage(items, 'NORMAL_POLL');
          duplicates += normalized.duplicateCount;
          const fresh = [];
          for (const record of normalized.records) {
            if (observedRecords.has(record.identity)) { duplicates++; continue; }
            observedRecords.set(record.identity, record);
            fresh.push(record);
          }
          observed = observedRecords.size;
          const results = registerInboundBatch(stateDir, fresh, {
            queuePolicyFor, recovered: true, now: now(),
          });
          for (const result of results) {
            if (result.created) { created++; incrementCounter(stateDir, 'normal_poll_recovered', 1, { now: now() }); }
            else incrementCounter(stateDir, 'duplicate_logical_events_suppressed', 1, { now: now() });
            if (result.outbox.state !== OUTBOX_STATES.HISTORICAL_HOLD) await enrichAndCreateLegacyContext(result.record);
          }
          if (!renewNamedLease(stateDir, 'normal-recovery-poll', owner, { leaseMs: 5 * 60_000, now: now() })) {
            throw new Error('POLL_LEASE_LOST');
          }
        },
      });
      if (!fetched.ok) {
        lastApiError = fetched.errorKind;
        updateHeartbeat(stateDir, 'recovery_poll', { rangeStart, rangeEnd, pageCount: fetched.pages,
          recordsObserved: observed, recordsRecovered: created, backlogCount: notificationQueueDepth(stateDir),
          lastApiError, safeDetails: { status: fetched.status } }, { success: false, now: now() });
        persistAlert(stateDir, { severity: fetched.errorKind === 'INSTANTLY_401' ? 'critical' : 'high',
          kind: fetched.errorKind, component: 'recovery_poll', safeDetails: { status: fetched.status } }, { now: now() });
        return { ok: false, reason: fetched.errorKind, pageCount: fetched.pages, observed, created, cursorAdvanced: false };
      }
      // The complete queried range is durably represented before this write.
      const lastObserved = [...observedRecords.values()].filter((record) => record.receivedAt)
        .sort((a, b) => a.receivedAt.localeCompare(b.receivedAt) || String(a.instantlyEmailId || a.identity).localeCompare(String(b.instantlyEmailId || b.identity))).at(-1);
      commitPollState(stateDir, 'normal-recovery-poll', { cursorTimestamp: rangeEnd,
        cursorEmailId: lastObserved?.instantlyEmailId || lastObserved?.identity || null,
        rangeStart, rangeEnd, pageCount, recordCount: observed }, { now: now() });
      const queue = notificationQueueDepth(stateDir);
      updateHeartbeat(stateDir, 'recovery_poll', { rangeStart, rangeEnd, pageCount, recordsObserved: observed,
        recordsMissing: created, recordsRecovered: created, backlogCount: queue,
        safeDetails: { duplicateLogicalEvents: duplicates } }, { success: true, now: now() });
      const drain = await drainOutbox({ limit: 25, maxBatches: 2 });
      const reconciliation = currentStateFor([...observedRecords.values()], duplicates);
      saveReconciliationSnapshot(stateDir, 'normal_poll', rangeStart, rangeEnd, reconciliation, { now: now() });
      return { ok: true, rangeStart, rangeEnd, pageCount, observed, created, duplicates,
        cursorAdvanced: true, cursorTimestamp: rangeEnd, drain, reconciliation };
    } catch (error) {
      lastApiError = redactError(error);
      updateHeartbeat(stateDir, 'recovery_poll', { rangeStart, rangeEnd, pageCount, recordsObserved: observed,
        recordsRecovered: created, backlogCount: notificationQueueDepth(stateDir), lastApiError }, { success: false, now: now() });
      persistAlert(stateDir, { severity: 'high', kind: 'POLL_DURABLE_FAILURE', component: 'recovery_poll',
        safeDetails: { error: lastApiError } }, { now: now() });
      return { ok: false, reason: 'POLL_DURABLE_FAILURE', pageCount, observed, created, cursorAdvanced: false };
    } finally {
      releaseNamedLease(stateDir, 'normal-recovery-poll', owner);
    }
  }

  async function runCompletenessAudit(auditName, {
    windowMs, overlapMs = 5 * 60_000, indexingDelayMs = 15_000, maxPages = 10_000,
    createLegacy = true,
  } = {}) {
    if (!windowMs) throw new Error('audit_window_required');
    const owner = randomWorker(`audit-${auditName}`);
    const leaseName = `completeness-audit:${auditName}`;
    if (!acquireNamedLease(stateDir, leaseName, owner, { leaseMs: 15 * 60_000, now: now() })) {
      return { ok: false, reason: 'AUDIT_LEASE_BUSY', auditName };
    }
    const rangeEnd = iso(now() - indexingDelayMs);
    const rangeStart = iso(Date.parse(rangeEnd) - windowMs - overlapMs);
    const runId = startAuditRun(stateDir, auditName, rangeStart, rangeEnd, { now: now() });
    let pageCount = 0, recordsObserved = 0, recordsMissing = 0, recordsRecovered = 0;
    let outboxMissing = 0, notificationsRequeued = 0, duplicateLogicalEvents = 0;
    const observedRecords = new Map();
    try {
      const fetched = await fetchInstantlyReceivedRange({ apiKey, apiBase, since: rangeStart, until: rangeEnd,
        pageLimit, maxPages, fetchImpl,
        onPage: async (items, page) => {
          pageCount = page.page;
          const normalized = normalizePage(items, 'COMPLETENESS_AUDIT');
          duplicateLogicalEvents += normalized.duplicateCount;
          for (const record of normalized.records) {
            if (observedRecords.has(record.identity)) { duplicateLogicalEvents++; continue; }
            observedRecords.set(record.identity, record);
            recordsObserved = observedRecords.size;
            const beforeInbound = getInbound(stateDir, record.instantlyEmailId || record.identity);
            const beforeOutbox = beforeInbound ? getNotification(stateDir, beforeInbound.identity) : null;
            if (!beforeInbound) recordsMissing++;
            if (beforeInbound && !beforeOutbox) outboxMissing++;
            const registered = registerInbound(stateDir, record, {
              queuePolicy: queuePolicyFor(record), recovered: true, now: now(),
            });
            if (!beforeInbound || !beforeOutbox) {
              recordsRecovered++;
              incrementCounter(stateDir, 'completeness_audit_recovered', 1, { now: now() });
              recordAuditDiscrepancy(stateDir, runId, { identity: registered.record.identity,
                instantlyEmailId: registered.record.instantlyEmailId,
                kind: !beforeInbound ? 'INSTANTLY_RECEIVED_MISSING_INBOUND' : 'INBOUND_MISSING_OUTBOX',
                recovered: true, resolution: 'DURABLY_REGISTERED_AND_OUTBOX_CREATED' }, { now: now() });
            }
            if (registered.outbox.state !== OUTBOX_STATES.NOTIFIED
              && registered.outbox.state !== OUTBOX_STATES.HISTORICAL_HOLD) {
              notificationsRequeued += requeueUnacknowledged(stateDir, [registered.record.identity], { now: now() });
            }
            if (createLegacy && registered.outbox.state !== OUTBOX_STATES.HISTORICAL_HOLD) await enrichAndCreateLegacyContext(registered.record);
          }
          if (!renewNamedLease(stateDir, leaseName, owner, { leaseMs: 15 * 60_000, now: now() })) throw new Error('AUDIT_LEASE_LOST');
        },
      });
      if (!fetched.ok) {
        const failed = { ok: false, pageCount: fetched.pages, recordsObserved, recordsMissing, recordsRecovered,
          outboxMissing, notificationsRequeued, lastApiError: fetched.errorKind };
        finishAuditRun(stateDir, runId, failed, { now: now() });
        updateHeartbeat(stateDir, `audit_${auditName}`, { rangeStart, rangeEnd, ...failed,
          backlogCount: notificationQueueDepth(stateDir), safeDetails: { status: fetched.status } }, { success: false, now: now() });
        persistAlert(stateDir, { severity: fetched.errorKind === 'INSTANTLY_401' ? 'critical' : 'high',
          kind: fetched.errorKind, component: `audit_${auditName}`, safeDetails: { status: fetched.status } }, { now: now() });
        return { ...failed, reason: fetched.errorKind, runId };
      }
      const result = { ok: true, pageCount, recordsObserved, recordsMissing, recordsRecovered,
        outboxMissing, notificationsRequeued, lastApiError: null };
      finishAuditRun(stateDir, runId, result, { now: now() });
      const backlogCount = notificationQueueDepth(stateDir);
      updateHeartbeat(stateDir, `audit_${auditName}`, { rangeStart, rangeEnd, ...result, backlogCount,
        safeDetails: { duplicateLogicalEvents } }, { success: true, now: now() });
      if (recordsMissing || outboxMissing) {
        persistAlert(stateDir, { severity: 'high', kind: 'COMPLETENESS_GAP_RECOVERED', component: `audit_${auditName}`,
          safeDetails: { recordsMissing, outboxMissing, recordsRecovered } }, { now: now() });
      }
      const drain = await drainOutbox({ limit: 25, maxBatches: 4 });
      const reconciliation = currentStateFor([...observedRecords.values()], duplicateLogicalEvents);
      saveReconciliationSnapshot(stateDir, `audit_${auditName}`, rangeStart, rangeEnd, reconciliation, { now: now() });
      return { ...result, runId, rangeStart, rangeEnd, duplicateLogicalEvents, backlogCount, drain, reconciliation };
    } catch (error) {
      const lastApiError = redactError(error);
      const failed = { ok: false, pageCount, recordsObserved, recordsMissing, recordsRecovered,
        outboxMissing, notificationsRequeued, lastApiError };
      finishAuditRun(stateDir, runId, failed, { now: now() });
      updateHeartbeat(stateDir, `audit_${auditName}`, { rangeStart, rangeEnd, ...failed,
        backlogCount: notificationQueueDepth(stateDir) }, { success: false, now: now() });
      persistAlert(stateDir, { severity: 'high', kind: 'AUDITOR_DURABLE_FAILURE', component: `audit_${auditName}`,
        safeDetails: { error: lastApiError } }, { now: now() });
      return { ...failed, reason: 'AUDITOR_DURABLE_FAILURE', runId };
    } finally {
      releaseNamedLease(stateDir, leaseName, owner);
    }
  }

  async function reconcileWindow({ since, until, repair = false, auditName = 'manual_reconciliation' } = {}) {
    const fetched = await fetchInstantlyReceivedRange({ apiKey, apiBase, since, until, pageLimit, fetchImpl });
    if (!fetched.ok) return { ok: false, reason: fetched.errorKind, status: fetched.status, since, until };
    const normalized = normalizePage(fetched.items, repair ? 'COMPLETENESS_AUDIT' : 'DIRECT_RECONCILIATION');
    let durableInboundPresent = 0, durableInboundMissing = 0, outboxPresent = 0, outboxMissing = 0;
    let chatNotified = 0, queued = 0, retrying = 0, ambiguous = 0, historicalHold = 0, recovered = 0;
    const missingIds = [];
    for (const record of normalized.records) {
      let inbound = getInbound(stateDir, record.instantlyEmailId || record.identity);
      let outbox = inbound ? getNotification(stateDir, inbound.identity) : null;
      if (!inbound) { durableInboundMissing++; missingIds.push(record.instantlyEmailId || record.identity); }
      else durableInboundPresent++;
      if (inbound && !outbox) outboxMissing++; else if (outbox) outboxPresent++;
      if (repair && (!inbound || !outbox)) {
        const result = registerInbound(stateDir, record, { queuePolicy: queuePolicyFor(record), recovered: true, now: now() });
        if (result.outbox.state !== OUTBOX_STATES.HISTORICAL_HOLD) await enrichAndCreateLegacyContext(result.record);
        inbound = result.record; outbox = result.outbox; recovered++;
      }
      if (outbox?.state === OUTBOX_STATES.NOTIFIED) chatNotified++;
      else if (outbox?.state === OUTBOX_STATES.QUEUED) queued++;
      else if (outbox?.state === OUTBOX_STATES.RETRYING) retrying++;
      else if (outbox?.state === OUTBOX_STATES.AMBIGUOUS) ambiguous++;
      else if (outbox?.state === OUTBOX_STATES.HISTORICAL_HOLD) historicalHold++;
    }
    const result = { ok: true, auditName, since, until, pageCount: fetched.pages,
      instantlyReceivedObserved: normalized.records.length, durableInboundPresent, durableInboundMissing,
      outboxPresent, outboxMissing, chatNotified, queued, retrying, ambiguous, historicalHold,
      duplicateLogicalEvents: normalized.duplicateCount, recovered, missingIds };
    const snapshotMetrics = currentStateFor(normalized.records, normalized.duplicateCount);
    saveReconciliationSnapshot(stateDir, auditName, since, until, snapshotMetrics, { now: now() });
    return { ...result, reconciliation: snapshotMetrics };
  }

  async function watchdog({ apiProbe = true } = {}) {
    const snapshot = operationsSnapshot(stateDir, { now: now() });
    const facts = watchdogFacts(stateDir, { now: now() });
    const alerts = [];
    const add = (severity, kind, component, safeDetails = {}) => alerts.push({
      key: `${component}:${kind}`, severity, kind, component, safeDetails,
    });
    const counts = snapshot.counts;
    if (counts.retrying) add('high', 'RETRY_BACKLOG', 'notification_outbox', { count: counts.retrying });
    if (counts.ambiguous) add('high', 'AMBIGUOUS_CHAT_RESPONSE', 'notification_outbox', { count: counts.ambiguous });
    if (facts.stuckPostingLease) add('high', 'STUCK_POSTING_LEASE', 'notification_outbox', { count: facts.stuckPostingLease });
    if (facts.surrogateUnreconciled) add('medium', 'SURROGATE_IDENTITY_UNRECONCILED', 'inbound_store', { count: facts.surrogateUnreconciled });
    if (facts.unacknowledgedMalformed) add('high', 'MALFORMED_RECORD_UNACKNOWLEDGED', 'inbound_store', { count: facts.unacknowledgedMalformed });
    if (facts.failedEnrichment) add('medium', 'FAILED_ENRICHMENT', 'inbound_store', { count: facts.failedEnrichment });
    if (snapshot.queueDepth > 100) add('high', 'EXCESSIVE_QUEUE_DEPTH', 'notification_outbox', { count: snapshot.queueDepth });
    const oldest = counts.oldest_unacknowledged_at && Date.parse(counts.oldest_unacknowledged_at);
    if (oldest && now() - oldest > 5 * 60_000) add('high', 'OLDEST_NOTIFICATION_AGE_EXCEEDED', 'notification_outbox', { ageMs: now() - oldest });
    if (facts.cursorTimestamp && now() - Date.parse(facts.cursorTimestamp) > 15 * 60_000) {
      add('high', 'RECOVERY_CURSOR_LAG', 'recovery_poll', { ageMs: now() - Date.parse(facts.cursorTimestamp) });
    }
    const integrity = integrityCheck(stateDir);
    if (!integrity.ok) add('critical', 'DURABLE_STORE_INTEGRITY', 'inbound_store', {
      missingOutbox: integrity.missingOutbox, orphanOutbox: integrity.orphanOutbox,
    });
    const thresholds = { recovery_poll: 10 * 60_000, audit_short: 12 * 60_000, audit_deep: 2 * HOUR, audit_daily: 30 * HOUR };
    for (const [component, threshold] of Object.entries(thresholds)) {
      const hb = snapshot.heartbeats.find((entry) => entry.component === component);
      if (!hb?.lastSuccessAt) add('high', 'HEARTBEAT_NEVER_SUCCEEDED', component);
      else if (now() - Date.parse(hb.lastSuccessAt) > threshold) add('high', 'HEARTBEAT_STALE', component,
        { ageMs: now() - Date.parse(hb.lastSuccessAt) });
      if (hb?.lastApiError) add('high', 'LAST_RUN_API_OR_STORE_ERROR', component, { errorKind: hb.lastApiError });
    }
    if (apiProbe && apiKey) {
      try {
        const response = await fetchImpl(`${apiBase.replace(/\/$/, '')}/accounts?limit=1`, {
          headers: { Authorization: `Bearer ${apiKey}` }, signal: AbortSignal.timeout(8_000),
        });
        if (response.status === 401) add('critical', 'INSTANTLY_401', 'instantly_api');
        else if (response.status === 429) add('high', 'INSTANTLY_429', 'instantly_api');
        else if (response.status >= 500) add('high', 'INSTANTLY_5XX', 'instantly_api', { status: response.status });
      } catch { add('high', 'INSTANTLY_NETWORK_ERROR', 'instantly_api'); }
    }
    for (const alert of alerts) persistAlert(stateDir, alert, { now: now() });
    resolveAlertsNotIn(stateDir, alerts.map((alert) => alert.key), { now: now() });
    updateHeartbeat(stateDir, 'watchdog', { backlogCount: snapshot.queueDepth,
      safeDetails: { alertCount: alerts.length } }, { success: true, now: now() });
    return { ok: true, generatedAt: iso(now()), alertCount: alerts.length, alerts,
      integrity, operations: operationsSnapshot(stateDir, { now: now() }) };
  }

  function migrateLegacyAcknowledgements() {
    const contextsDir = path.join(stateDir, 'contexts');
    if (!fs.existsSync(contextsDir)) return { scanned: 0, importedAcknowledged: 0, unacknowledgedSkipped: 0, syntheticSkipped: 0 };
    let scanned = 0, importedAcknowledged = 0, unacknowledgedSkipped = 0, syntheticSkipped = 0;
    for (const file of fs.readdirSync(contextsDir)) {
      if (!/^[0-9a-f]{32}\.json$/.test(file)) continue;
      const contextId = file.slice(0, 32);
      const context = readContext(stateDir, contextId);
      if (!context) continue;
      scanned++;
      const marker = String(context.replyToUuid || context.instantlyEmailId || '');
      if (/^SUPPRESS-SELFTEST/i.test(marker) || /@example\.com$/i.test(context.prospectEmail || '') || /@example\.com$/i.test(context.eaccount || '')) {
        syntheticSkipped++; continue;
      }
      const normalized = normalizeInstantlyReceived({
        id: context.instantlyEmailId || context.replyToUuid,
        ue_type: 2,
        eaccount: context.eaccount,
        from_address_email: context.prospectEmail,
        campaign_id: context.campaignId,
        thread_id: context.authoritativeThreadId,
        subject: context.subject,
        content_preview: context.preview,
        timestamp_created: context.receivedAt || context.createdAt,
      }, { authoritativeReceived: true, discoverySource: context.discoverySource || 'LEGACY_MIGRATION', observedAt: iso(now()) });
      if (!normalized.ok) continue;
      // Early console records predate notificationState, but a valid Google
      // Chat message resource name is itself the definite transport
      // acknowledgement. Requiring the newer state field would re-post those
      // already-visible notifications during migration/audit.
      if (hasDefiniteLegacyChatAcknowledgement(context)) {
        importAcknowledgedLegacy(stateDir, normalized.record, legacyAcknowledgement(context), { contextId, now: now() });
        importedAcknowledged++;
      } else {
        // A legacy context alone is not authoritative evidence that Instantly
        // exposed a production received record (test contexts exist). Direct
        // poll/auditor inventory will register and queue real rows shortly.
        unacknowledgedSkipped++;
      }
    }
    return { scanned, importedAcknowledged, unacknowledgedSkipped, syntheticSkipped };
  }

  return {
    registerReceived,
    drainOutbox,
    runNormalPoll,
    runCompletenessAudit,
    reconcileWindow,
    watchdog,
    migrateLegacyAcknowledgements,
    operations: () => operationsSnapshot(stateDir, { now: now() }),
    integrity: () => integrityCheck(stateDir),
    notification: (identityOrId) => getNotification(stateDir, identityOrId),
  };
}
