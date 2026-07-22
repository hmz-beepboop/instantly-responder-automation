// hmz-reply-console durable store.
//
// Adapted from infrastructure/send-state/state-store.mjs: identical atomic
// open('wx') lock + write-tmp-then-rename pattern. Node built-ins only.
//
// Holds the server-side supervised-reply context for the Google Chat console:
// one context per genuine Instantly reply_received event, immutable draft
// revisions, one-use action tokens, and a forward-only per-context send state.
//
// NEVER stores API keys, bearer tokens, or webhook secrets. The reply body is
// the owner's own human-written text and is stored deliberately so the exact
// outgoing body can be shown before Send and hash-checked at Send time.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import * as T from './telemetry.mjs';

// ---- durability parameters -------------------------------------------------
export const CONTEXT_TTL_MS = 7 * 24 * 60 * 60 * 1000;   // pending context: 7 days
export const DRAFT_TTL_MS = 6 * 60 * 60 * 1000;          // draft + review token: 6 hours
export const AUDIT_RETENTION_MS = 30 * 24 * 60 * 60 * 1000; // terminal records kept 30 days

// Durable per-context send state.
export const SEND_STATES = Object.freeze({
  PENDING: 'PENDING',                  // context created, no draft approved yet
  APPROVED: 'APPROVED',                // a draft revision approved for send (reviewable)
  SENDING: 'SENDING',                  // Instantly POST in flight (lock held)
  SENT_API_CONFIRMED: 'SENT_API_CONFIRMED',        // definitive 2xx (terminal, delivered)
  SENT_RECONCILED_WEBHOOK: 'SENT_RECONCILED_WEBHOOK', // proven delivered via email_sent (terminal)
  SENT_RECONCILED_READBACK: 'SENT_RECONCILED_READBACK', // proven delivered via /emails readback (terminal)
  RECONCILING: 'RECONCILING',          // ambiguous POST result; delivery being verified; NEVER re-POSTs
  MANUAL_RECONCILIATION_REQUIRED: 'MANUAL_RECONCILIATION_REQUIRED', // window exhausted / multiple candidates (terminal, lock held)
  FAILED_DEFINITIVE: 'FAILED_DEFINITIVE',  // definitive non-retryable rejection, no delivery
  RETRYABLE: 'RETRYABLE',              // failed WITHOUT delivery; retry needs a FRESH draft + token
  CANCELLED: 'CANCELLED',
  EXPIRED: 'EXPIRED',
});

// Any state proving the email is delivered (never re-POST, never reopen).
export const DELIVERED_STATES = ['SENT_API_CONFIRMED', 'SENT_RECONCILED_WEBHOOK', 'SENT_RECONCILED_READBACK'];

// Permanent defence-in-depth: pre-console-epoch / historical-backfill records can
// NEVER create tokens/drafts, expose Send/Edit, arm, or invoke the reply endpoint.
// Identified by EXPLICIT_BACKFILL discovery source or receipt before the epoch.
const HISTORICAL_NOTIFICATION_EPOCH = process.env.INBOUND_NOTIFICATION_EPOCH || '2026-07-18T18:33:00Z';
const HISTORICAL_EPOCH_MS = Date.parse(HISTORICAL_NOTIFICATION_EPOCH);
export function isHistoricalActor(x) {
  if (!x || typeof x !== 'object') return false;
  if (x.discoverySource === 'EXPLICIT_BACKFILL') return true;
  const t = x.receivedAt ? Date.parse(x.receivedAt) : NaN;
  return Number.isFinite(t) && Number.isFinite(HISTORICAL_EPOCH_MS) && t < HISTORICAL_EPOCH_MS;
}

// Individual send-attempt outcomes recorded (immutably, append-only) in sendAttempts[].
export const SEND_OUTCOMES = Object.freeze({
  SENT_API_CONFIRMED: 'SENT_API_CONFIRMED',
  SENT_RECONCILED_WEBHOOK: 'SENT_RECONCILED_WEBHOOK',
  SENT_RECONCILED_READBACK: 'SENT_RECONCILED_READBACK',
  FAILED_DEFINITIVE: 'FAILED_DEFINITIVE',
  RECONCILING: 'RECONCILING',
  MANUAL_RECONCILIATION_REQUIRED: 'MANUAL_RECONCILIATION_REQUIRED',
});

// Specific transport classifications for ambiguous POST results (audit only).
export const TRANSPORT_FAULTS = Object.freeze({
  ETIMEDOUT: 'ETIMEDOUT', ECONNRESET: 'ECONNRESET', RESPONSE_PARSE_FAILURE: 'RESPONSE_PARSE_FAILURE',
  CHAT_RESPONSE_DEADLINE: 'CHAT_RESPONSE_DEADLINE', UPSTREAM_5XX: 'UPSTREAM_5XX',
  UNKNOWN_TRANSPORT_FAILURE: 'UNKNOWN_TRANSPORT_FAILURE',
});

export const ALLOWED_TRANSITIONS = Object.freeze({
  PENDING: ['APPROVED', 'CANCELLED', 'EXPIRED'],
  APPROVED: ['SENDING', 'CANCELLED', 'EXPIRED'],
  SENDING: ['SENT_API_CONFIRMED', 'RECONCILING', 'FAILED_DEFINITIVE', 'RETRYABLE'],
  RECONCILING: ['SENT_RECONCILED_WEBHOOK', 'SENT_RECONCILED_READBACK', 'MANUAL_RECONCILIATION_REQUIRED'],
  RETRYABLE: ['APPROVED', 'CANCELLED', 'EXPIRED'],  // a fresh draft re-approves; failed attempts stay audited
  SENT_API_CONFIRMED: [],
  SENT_RECONCILED_WEBHOOK: [],
  SENT_RECONCILED_READBACK: [],
  MANUAL_RECONCILIATION_REQUIRED: [],
  FAILED_DEFINITIVE: [],
  CANCELLED: [],
  EXPIRED: [],
});

const DRAFTABLE_STATES = ['PENDING', 'APPROVED', 'RETRYABLE'];

export function isTerminal(state) {
  return Object.prototype.hasOwnProperty.call(ALLOWED_TRANSITIONS, state)
    && ALLOWED_TRANSITIONS[state].length === 0;
}

function canTransition(from, to) {
  const allowed = ALLOWED_TRANSITIONS[from];
  return Array.isArray(allowed) && allowed.includes(to);
}

function nowIso() { return new Date().toISOString(); }
function sha256(s) { return crypto.createHash('sha256').update(String(s ?? ''), 'utf8').digest('hex'); }
function randId(bytes = 16) { return crypto.randomBytes(bytes).toString('hex'); }

export function ensureDir(dir) { fs.mkdirSync(dir, { recursive: true }); }
function contextsDir(base) { return path.join(base, 'contexts'); }
function threadIndexDir(base) { return path.join(base, 'thread-index'); }
function contextPath(base, id) { return path.join(contextsDir(base), `${id}.json`); }
function threadIndexPath(base, threadKey) {
  return path.join(threadIndexDir(base), `${sha256(threadKey)}.json`);
}

// atomic write-tmp-then-rename
function atomicWrite(finalPath, obj) {
  ensureDir(path.dirname(finalPath));
  const tmp = `${finalPath}.${process.pid}.${Date.now()}.${randId(4)}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2), 'utf8');
  fs.renameSync(tmp, finalPath);
  return obj;
}

function readJson(p) {
  if (!fs.existsSync(p)) return null;
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

// ---- deterministic context key --------------------------------------------
// Stable across restarts: same reply event => same context key => dedup.
export function deriveContextKey({ replyToUuid, prospectEmail, eaccount }) {
  const raw = ['HMZ_GCHAT_CONSOLE_CTX',
    String(replyToUuid ?? '').trim(),
    String(prospectEmail ?? '').trim().toLowerCase(),
    String(eaccount ?? '').trim().toLowerCase()].join('|');
  return sha256(raw);
}

// Deterministic Google Chat thread key derived from the context key.
export function deriveThreadKey(contextKey) {
  return `hmz-reply-${contextKey.slice(0, 24)}`;
}

// ---- create / dedup context ------------------------------------------------
// Idempotent: a duplicate Instantly event (same derived key) returns the
// existing context and { created:false } so no duplicate notification is sent.
// Test-only suppression (Phase 11 Test B). Suppresses the WEBHOOK path context
// creation for exactly one Instantly email id so the scheduled poll recovers it.
// NEVER affects the readback/recovery path (discoverySource DISCOVERED_READBACK).
function suppressPath(base) { return path.join(base, 'test-suppress.json'); }
export function getSuppressSet(base) { try { return JSON.parse(fs.readFileSync(suppressPath(base), 'utf8')); } catch { return {}; } }
export function setTestSuppress(base, emailId, on) {
  const set = getSuppressSet(base);
  const key = String(emailId).toLowerCase(); if (on) set[key] = new Date().toISOString(); else delete set[key];
  const tmp = suppressPath(base) + '.tmp'; fs.writeFileSync(tmp, JSON.stringify(set)); fs.renameSync(tmp, suppressPath(base));
  return { ok: true, suppressed: Object.keys(set) };
}

export function createContext(base, input) {
  // Webhook-path test suppression: refuse to create (and post) for a flagged
  // email id, but ALWAYS allow the readback recovery path through.
  if ((input.discoverySource || 'DISCOVERED_WEBHOOK') !== 'DISCOVERED_READBACK') {
    const set = getSuppressSet(base);
    const eid = String(input.instantlyEmailId || input.replyToUuid || '');
    const pem = String(input.prospectEmail || '').toLowerCase();
    if ((eid && set[eid]) || (pem && set[pem])) {
      return { ok: true, created: false, suppressedForTest: true };
    }
  }
  // Defence-in-depth: never create an actionable context for a historical record.
  if (isHistoricalActor(input)) {
    T.record(base, 'historical_context_creation_blocked', { source: input.discoverySource || null });
    return { ok: false, reason: 'HISTORICAL_NON_ACTIONABLE' };
  }
  const required = ['replyToUuid', 'eaccount', 'prospectEmail', 'uniboxUrl'];
  for (const k of required) {
    if (!input[k] || typeof input[k] !== 'string' || !input[k].trim()) {
      return { ok: false, reason: 'INVALID_CONTEXT_INPUT', missing: k };
    }
  }
  const contextKey = deriveContextKey(input);
  // The notification workflow computes a stable threadKey with its own pure-JS
  // hash (the n8n task runner blocks crypto), so it can post the threaded Chat
  // message without depending on this sidecar. Accept that supplied key; only
  // fall back to our own derivation if none was provided.
  const threadKey = (typeof input.threadKey === 'string' && input.threadKey.trim())
    ? input.threadKey.trim()
    : deriveThreadKey(contextKey);

  // dedup via deterministic id file (open wx)
  const detIdPath = path.join(contextsDir(base), `key-${contextKey}.ref`);
  ensureDir(contextsDir(base));
  let notificationId;
  try {
    const fd = fs.openSync(detIdPath, 'wx');
    notificationId = randId(16);
    try { fs.writeFileSync(fd, notificationId, 'utf8'); } finally { fs.closeSync(fd); }
  } catch (e) {
    if (e?.code === 'EEXIST') {
      notificationId = fs.readFileSync(detIdPath, 'utf8').trim();
      const existing = readContext(base, notificationId);
      if (existing) { T.record(base, 'inbound_duplicate_suppressed', { source: 'DISCOVERED_WEBHOOK' }); return { ok: true, created: false, context: publicContext(existing) }; }
    } else { throw e; }
  }

  const record = {
    notificationId,
    contextKey,
    threadKey,
    replyToUuid: input.replyToUuid,
    eaccount: input.eaccount,
    prospectEmail: input.prospectEmail,
    subject: input.subject || '',
    campaignId: input.campaignId || null,
    campaignName: input.campaignName || null,
    uniboxUrl: input.uniboxUrl,
    receivedAt: input.receivedAt || nowIso(),
    preview: input.preview || '',
    isAutoReply: input.isAutoReply === true,
    sourcePayloadHash: input.sourcePayloadHash || null,
    // Authoritative routing verified from Instantly readback before Send is
    // offered (Phase 3). Never trusted from Chat card params.
    authoritativeThreadId: input.authoritativeThreadId || null,
    threadVerifiedAt: input.authoritativeThreadId ? nowIso() : null,
    // enrichment snapshots (Phase 5/6) — names never inferred from local parts
    prospectName: input.prospectName || '',
    prospectNameSource: input.prospectNameSource || 'UNAVAILABLE',
    senderName: input.senderName || '',
    senderNameSource: input.senderNameSource || 'UNRESOLVED',
    senderEligible: input.senderEligible === true,
    // inbound notification state machine (Phase 3)
    discoverySource: input.discoverySource || 'DISCOVERED_WEBHOOK',
    notificationState: 'DISCOVERED',
    instantlyEmailId: input.instantlyEmailId || input.replyToUuid || null,
    chatMessageName: null,
    chatThreadName: null,
    state: SEND_STATES.PENDING,
    createdAt: nowIso(),
    updatedAt: nowIso(),
    expiresAt: new Date(Date.now() + CONTEXT_TTL_MS).toISOString(),
    drafts: [],            // immutable revisions
    activeReviewToken: null,
    activeDraftRevision: null,
  };
  atomicWrite(contextPath(base, notificationId), record);
  // thread index (thread -> context) for MESSAGE resolution
  atomicWrite(threadIndexPath(base, threadKey), { threadKey, notificationId, createdAt: nowIso() });
  T.record(base, 'inbound_applicable', { source: record.discoverySource });
  return { ok: true, created: true, context: publicContext(record) };
}

export function readContext(base, id) {
  if (!id || !/^[0-9a-f]{32}$/.test(id)) return null;
  const rec = readJson(contextPath(base, id));
  if (!rec) return null;
  return maybeExpire(base, rec);
}

export function resolveByThreadKey(base, threadKey) {
  const idx = readJson(threadIndexPath(base, threadKey));
  if (!idx) return null;
  return readContext(base, idx.notificationId);
}

function maybeExpire(base, rec) {
  if (!isTerminal(rec.state) && Date.parse(rec.expiresAt) < Date.now()) {
    rec.state = SEND_STATES.EXPIRED;
    rec.activeReviewToken = null;
    rec.updatedAt = nowIso();
    atomicWrite(contextPath(base, rec.notificationId), rec);
  }
  return rec;
}

// public view: never exposes internal token secrets in bulk reads
function publicContext(rec) {
  const { activeReviewToken, ...rest } = rec;
  return { ...rest, hasActiveToken: Boolean(activeReviewToken) };
}

// attach Google Chat post identifiers after the notification is posted
export function attachChatPost(base, id, { chatMessageName, chatThreadName, chatStatus }) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  rec.chatMessageName = chatMessageName || rec.chatMessageName;
  rec.chatThreadName = chatThreadName || rec.chatThreadName;
  // Notification state machine: a 2xx with a returned message name == CHAT_NOTIFIED;
  // a 2xx without message name is treated as ambiguous; an explicit failure is
  // recorded so the watchdog can see it. Never silently mark ambiguous as notified.
  const st = Number(chatStatus);
  if (rec.chatMessageName && (!chatStatus || (st >= 200 && st < 300))) rec.notificationState = 'CHAT_NOTIFIED';
  else if (chatStatus && st >= 200 && st < 300) rec.notificationState = 'CHAT_POST_AMBIGUOUS';
  else if (chatStatus && st >= 400) rec.notificationState = 'CHAT_POST_FAILED_DEFINITIVE';
  if (rec.notificationState === 'CHAT_NOTIFIED' && !rec.chatNotifiedAt) rec.chatNotifiedAt = nowIso();
  rec.chatPostCount = (rec.chatPostCount || 0) + 1;
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  if (rec.notificationState === 'CHAT_NOTIFIED') T.record(base, 'inbound_notified', { latencyMs: Date.parse(rec.chatNotifiedAt) - Date.parse(rec.createdAt) });
  else if (rec.notificationState === 'CHAT_POST_AMBIGUOUS') T.record(base, 'inbound_notify_ambiguous', {});
  else if (rec.notificationState === 'CHAT_POST_FAILED_DEFINITIVE') T.record(base, 'inbound_notify_failed', {});
  // Google Chat MESSAGE events identify the thread by its resource name
  // (spaces/.../threads/...), which is not necessarily our client threadKey.
  // Index by the resource name too so the interaction workflow can resolve
  // the pending context from an incoming reply.
  if (rec.chatThreadName) {
    atomicWrite(threadIndexPath(base, rec.chatThreadName),
      { threadKey: rec.chatThreadName, notificationId: id, createdAt: nowIso() });
  }
  return { ok: true, context: publicContext(rec) };
}

// Set/advance the inbound notification state explicitly (used by recovery/watchdog).
export function setNotificationState(base, id, state, meta = {}) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  rec.notificationState = state;
  if (state === 'CHAT_NOTIFIED' && !rec.chatNotifiedAt) rec.chatNotifiedAt = nowIso();
  if (meta.detail) rec.notificationDetail = String(meta.detail).slice(0, 200);
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  return { ok: true, state };
}

// List contexts whose notification never reached CHAT_NOTIFIED (for the watchdog).
export function listUnnotified(base, { olderThanMs = 0 } = {}) {
  const dir = contextsDir(base);
  if (!fs.existsSync(dir)) return [];
  const now = Date.now(); const out = [];
  for (const f of fs.readdirSync(dir)) {
    if (!/^[0-9a-f]{32}\.json$/.test(f)) continue;
    const rec = readContext(base, f.slice(0, 32));
    if (!rec) continue;
    if (rec.notificationState && rec.notificationState !== 'CHAT_NOTIFIED'
      && (now - Date.parse(rec.createdAt || rec.updatedAt)) >= olderThanMs) {
      out.push({ notificationId: rec.notificationId, notificationState: rec.notificationState,
        createdAt: rec.createdAt, chatPostCount: rec.chatPostCount || 0 });
    }
  }
  return out;
}

// Look up a context by the Instantly email id (inbound dedup primary key).
export function findByInstantlyEmailId(base, emailId) {
  if (!emailId) return null;
  const dir = contextsDir(base);
  if (!fs.existsSync(dir)) return null;
  for (const f of fs.readdirSync(dir)) {
    if (!/^[0-9a-f]{32}\.json$/.test(f)) continue;
    const rec = readContext(base, f.slice(0, 32));
    if (rec && String(rec.instantlyEmailId || rec.replyToUuid) === String(emailId)) return rec;
  }
  return null;
}

// ---- draft revisions + one-use review token --------------------------------
export function createDraft(base, id, { body, author, reason }) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (isHistoricalActor(rec)) return { ok: false, reason: 'HISTORICAL_NON_ACTIONABLE', state: rec.state };
  if (!DRAFTABLE_STATES.includes(rec.state)) {
    return { ok: false, reason: rec.state === SEND_STATES.SENDING ? 'SEND_IN_PROGRESS' : 'CONTEXT_NOT_DRAFTABLE', state: rec.state };
  }
  const text = typeof body === 'string' ? body : '';
  const trimmed = text.trim();
  if (!trimmed) return { ok: false, reason: 'EMPTY_BODY' };
  if (text.length > 8000) return { ok: false, reason: 'BODY_TOO_LONG' };

  const revision = rec.drafts.length + 1;
  const reviewToken = randId(24);           // one-use, opaque
  const draft = {
    draftId: randId(16),
    revision,
    body: text,                             // exact, unaltered
    bodyHash: sha256(text),
    author: author || null,
    reason: reason || 'reply',
    createdAt: nowIso(),
    tokenHash: sha256(reviewToken),
    tokenExpiresAt: new Date(Date.now() + DRAFT_TTL_MS).toISOString(),
    tokenUsed: false,
    superseded: false,
  };
  // supersede prior drafts + invalidate prior token
  rec.drafts = rec.drafts.map((d) => ({ ...d, superseded: true }));
  rec.drafts.push(draft);
  rec.activeDraftRevision = revision;
  rec.activeReviewToken = reviewToken;       // stored so Send can match; internal only
  rec.state = SEND_STATES.APPROVED;          // a reviewable draft exists (not yet sending)
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  T.record(base, 'draft_created', { revision });
  return {
    ok: true,
    draftId: draft.draftId,
    revision,
    bodyHash: draft.bodyHash,
    reviewToken,                             // returned once to the interaction flow
    tokenExpiresAt: draft.tokenExpiresAt,
  };
}
// (telemetry) record after a successful draft is created


// Re-issue the latest revision's review token so a stale card can recover to the
// current draft. Does NOT create a revision or change the body. Returns the data
// needed to render the latest Review card with a fresh one-use token.
export function refreshLatestCard(base, id) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (![SEND_STATES.PENDING, SEND_STATES.APPROVED, SEND_STATES.RETRYABLE].includes(rec.state)) {
    return { ok: false, reason: 'NOT_REVIEWABLE', state: rec.state };
  }
  const draft = rec.drafts.find((d) => d.revision === rec.activeDraftRevision);
  if (!draft) return { ok: false, reason: 'NO_ACTIVE_DRAFT' };
  const newToken = randId(24);
  draft.tokenHash = sha256(newToken);
  draft.tokenUsed = false;
  draft.tokenExpiresAt = new Date(Date.now() + DRAFT_TTL_MS).toISOString();
  draft.superseded = false;
  rec.activeReviewToken = newToken;
  rec.state = SEND_STATES.APPROVED;
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  return {
    ok: true, revision: draft.revision, reviewToken: newToken, bodyHash: draft.bodyHash,
    body: draft.body, prospectName: rec.prospectName, prospectEmail: rec.prospectEmail,
    senderName: rec.senderName, eaccount: rec.eaccount, subject: rec.subject, uniboxUrl: rec.uniboxUrl,
  };
}

// validate a Send click's token + body hash without consuming it
export function validateReview(base, id, { reviewToken, bodyHash }) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (isHistoricalActor(rec)) return { ok: false, reason: 'HISTORICAL_NON_ACTIONABLE' };
  if (rec.state === SEND_STATES.SENDING) return { ok: false, reason: 'SEND_IN_PROGRESS' };
  if (rec.state === SEND_STATES.SENT) return { ok: false, reason: 'ALREADY_SENT' };
  if (rec.state === SEND_STATES.SEND_UNCERTAIN) return { ok: false, reason: 'SEND_UNCERTAIN' };
  if (rec.state !== SEND_STATES.APPROVED) return { ok: false, reason: 'NO_ACTIVE_DRAFT', state: rec.state };
  const draft = rec.drafts.find((d) => d.revision === rec.activeDraftRevision);
  if (!draft) return { ok: false, reason: 'NO_ACTIVE_DRAFT' };
  if (draft.tokenUsed) return { ok: false, reason: 'TOKEN_USED' };
  if (Date.parse(draft.tokenExpiresAt) < Date.now()) return { ok: false, reason: 'TOKEN_EXPIRED' };
  if (!reviewToken || draft.tokenHash !== sha256(reviewToken)) return { ok: false, reason: 'TOKEN_MISMATCH' };
  if (bodyHash && bodyHash !== draft.bodyHash) return { ok: false, reason: 'BODY_TAMPERED' };
  return { ok: true, revision: draft.revision, bodyHash: draft.bodyHash };
}

// ---- atomic send acquire (one Instantly POST maximum) ----------------------
// APPROVED -> SENDING under an exclusive lock. Resolves authoritative routing
// server-side (eaccount, reply_to_uuid, subject, body) — the caller/card never
// supplies these. A duplicate click hits LOCK_ALREADY_HELD or a non-APPROVED
// state and returns blocked, guaranteeing zero second POSTs.
function lockPath(base, id) { return path.join(contextsDir(base), `${id}.send.lock`); }

export function acquireSend(base, id, { reviewToken, bodyHash }) {
  // 1) Side-effect-free validation FIRST: a stale/superseded/tampered/expired
  // token is rejected distinctly even while the send gate is OFF (this consumes
  // nothing and transitions no state).
  const check = validateReview(base, id, { reviewToken, bodyHash });
  if (!check.ok) {
    if (check.reason === 'TOKEN_MISMATCH' || check.reason === 'BODY_TAMPERED' || check.reason === 'TOKEN_EXPIRED') T.record(base, 'send_stale_blocked', { reason: check.reason });
    else if (check.reason === 'ALREADY_SENT' || check.reason === 'SEND_IN_PROGRESS') T.record(base, 'send_duplicate_blocked', { reason: check.reason });
    return { ...check, acquired: false };
  }

  // 2) Default-OFF go-live gate. A VALID latest token is still refused here,
  // without consuming the token or transitioning state — the deliberately
  // blocked send adapter. Only a valid token + explicit go-live proceeds, and
  // only for the exact armed context + revision when arming is scoped.
  const gl = getGoLive(base);
  if (!gl.enabled) return { ok: false, acquired: false, reason: 'SEND_DISABLED_NOT_GO_LIVE' };
  if (gl.armedContextId && gl.armedContextId !== id) {
    return { ok: false, acquired: false, reason: 'SEND_DISABLED_WRONG_CONTEXT' };
  }
  if (gl.armedRevision && gl.armedRevision !== check.revision) {
    return { ok: false, acquired: false, reason: 'SEND_DISABLED_WRONG_REVISION' };
  }

  ensureDir(contextsDir(base));
  let fd;
  try {
    fd = fs.openSync(lockPath(base, id), 'wx');
  } catch (e) {
    if (e?.code === 'EEXIST') { T.record(base, 'send_duplicate_blocked', { reason: 'LOCK_ALREADY_HELD' }); return { ok: false, acquired: false, reason: 'LOCK_ALREADY_HELD' }; }
    throw e;
  }
  try {
    fs.writeFileSync(fd, JSON.stringify({ pid: process.pid, at: nowIso() }), 'utf8');
  } finally { fs.closeSync(fd); }

  // re-read under lock and transition
  const rec = readContext(base, id);
  if (!rec || rec.state !== SEND_STATES.APPROVED) {
    releaseLock(base, id);
    return { ok: false, acquired: false, reason: 'STATE_CHANGED', state: rec?.state };
  }
  const draft = rec.drafts.find((d) => d.revision === rec.activeDraftRevision);
  if (!draft || draft.tokenUsed || draft.tokenHash !== sha256(reviewToken)) {
    releaseLock(base, id);
    return { ok: false, acquired: false, reason: 'TOKEN_INVALID_UNDER_LOCK' };
  }
  draft.tokenUsed = true;
  rec.activeReviewToken = null;
  rec.state = SEND_STATES.SENDING;
  // Open an attempt record atomically BEFORE the POST (Phase 2 rule 1-2), so a
  // sidecar/n8n restart during SENDING still shows an in-flight attempt and
  // never permits another POST.
  const attemptId = randId(8);
  const subjectOut = /^re:/i.test(String(rec.subject || '')) ? rec.subject : ('Re: ' + String(rec.subject || ''));
  rec.currentAttempt = {
    attemptId, revision: draft.revision, startedAt: nowIso(),
    reply_to_uuid: rec.replyToUuid, eaccount: rec.eaccount, recipient: rec.prospectEmail,
    subject: subjectOut, bodyHash: draft.bodyHash, bodyText: draft.body, authoritativeThreadId: rec.authoritativeThreadId,
    postCount: 0,
  };
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  return {
    ok: true,
    acquired: true,
    attemptId,
    routing: {                       // authoritative, resolved server-side
      eaccount: rec.eaccount,
      reply_to_uuid: rec.replyToUuid,
      subject: rec.subject,
      body: draft.body,
      bodyHash: draft.bodyHash,
      revision: draft.revision,
    },
    uniboxUrl: rec.uniboxUrl,
  };
}

function releaseLock(base, id) {
  try { fs.unlinkSync(lockPath(base, id)); } catch (e) { if (e?.code !== 'ENOENT') throw e; }
}

// Record the POST result and move state (from SENDING or RECONCILING):
//   SENT_API_CONFIRMED       -> terminal, lock released
//   FAILED_DEFINITIVE (4xx)  -> RETRYABLE, lock released (fresh draft needed)
//   RECONCILING (ambiguous)  -> lock HELD; delivery verified by webhook/readback; never re-POST
//   SENT_RECONCILED_*        -> terminal, lock released
//   MANUAL_RECONCILIATION_REQUIRED -> terminal, lock HELD
export function finalizeSend(base, id, outcome, details = {}) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (rec.state !== SEND_STATES.SENDING && rec.state !== SEND_STATES.RECONCILING) {
    return { ok: false, reason: 'NOT_IN_SEND_FLOW', state: rec.state };
  }
  if (!Object.prototype.hasOwnProperty.call(SEND_OUTCOMES, outcome)) {
    return { ok: false, reason: 'UNKNOWN_OUTCOME', outcome };
  }
  const attempt = {
    attemptId: (rec.currentAttempt && rec.currentAttempt.attemptId) || randId(8),
    revision: rec.currentAttempt ? rec.currentAttempt.revision : rec.activeDraftRevision,
    outcome, at: nowIso(),
    httpStatus: Number.isInteger(details.httpStatus) ? details.httpStatus : null,
    transportFault: typeof details.transportFault === 'string' ? details.transportFault : null,
    detail: typeof details.detail === 'string' ? details.detail.slice(0, 300) : null,
    instantlyMessageId: typeof details.instantlyMessageId === 'string' ? details.instantlyMessageId : null,
    reconciledEmailId: typeof details.reconciledEmailId === 'string' ? details.reconciledEmailId : null,
  };
  if (!Array.isArray(rec.sendAttempts)) rec.sendAttempts = [];
  rec.sendAttempts.push(attempt);
  rec.lastOutcome = outcome;

  const lockReleasing = [SEND_OUTCOMES.SENT_API_CONFIRMED, SEND_OUTCOMES.SENT_RECONCILED_WEBHOOK,
    SEND_OUTCOMES.SENT_RECONCILED_READBACK, SEND_OUTCOMES.FAILED_DEFINITIVE];

  rec.state = outcome;                                   // outcome name == state name by design
  if (outcome === SEND_OUTCOMES.FAILED_DEFINITIVE) {
    rec.activeReviewToken = null; rec.activeDraftRevision = null; rec.state = SEND_STATES.RETRYABLE;
  }
  if (DELIVERED_STATES.includes(outcome)) rec.currentAttempt = null;
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  if (lockReleasing.includes(outcome)) releaseLock(base, id);
  return { ok: true, state: rec.state, outcome };
}

// Move SENDING -> RECONCILING (ambiguous POST). Keeps the lock; records the
// specific transport fault. The attempt (and its one POST) is preserved.
function toReconciling(base, id, transportFault, httpStatus) {
  const rec = readContext(base, id);
  if (!rec || rec.state !== SEND_STATES.SENDING) return { ok: false, state: rec?.state };
  if (!Array.isArray(rec.sendAttempts)) rec.sendAttempts = [];
  rec.sendAttempts.push({
    attemptId: (rec.currentAttempt && rec.currentAttempt.attemptId) || randId(8),
    revision: rec.currentAttempt ? rec.currentAttempt.revision : rec.activeDraftRevision,
    outcome: SEND_OUTCOMES.RECONCILING, at: nowIso(),
    httpStatus: Number.isInteger(httpStatus) ? httpStatus : null,
    transportFault: transportFault || TRANSPORT_FAULTS.UNKNOWN_TRANSPORT_FAILURE, detail: null,
  });
  rec.state = SEND_STATES.RECONCILING;
  rec.reconcileStartedAt = (rec.currentAttempt && rec.currentAttempt.startedAt) || nowIso();
  rec.lastOutcome = SEND_OUTCOMES.RECONCILING;
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);          // lock intentionally retained
  return { ok: true, state: rec.state };
}

// ---- reconciliation: candidate matching (pure, testable) ------------------
// Normalise a reviewed/canonical body for hashing: LF only, trim outer boundary.
export function canonicalBody(text) {
  return String(text == null ? '' : text).replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/^\s+/, '').replace(/\s+$/, '');
}
export function bodyHashOf(text) { return sha256(canonicalBody(text)); }

// Recover plain text from an Instantly email's stored html (<br>/<p> -> \n, tags
// stripped, entities decoded) so it can be structurally compared to body.text.
export function htmlToText(html) {
  return String(html == null ? '' : html)
    .replace(/\r\n/g, '\n')
    .replace(/<\s*head[\s\S]*?<\/\s*head\s*>/gi, ' ')
    .replace(/<\s*(style|script)[\s\S]*?<\/\s*\1\s*>/gi, ' ')
    .replace(/<\s*br\s*\/?>/gi, '\n').replace(/<\/\s*p\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>').replace(/&quot;/gi, '"').replace(/&#39;/gi, "'");
}
function normSubject(s) { return String(s || '').replace(/^\s*re:\s*/i, '').trim().toLowerCase(); }
function normEmailAddr(e) { return String(e || '').trim().toLowerCase(); }
// Collapse whitespace runs to single spaces + trim for structural body match (survives Instantly html wrapping).
export function normalizeForMatch(text) { return String(text == null ? '' : text).replace(/\s+/g, ' ').trim(); }

// Decide whether one Instantly email object is THE delivered reply for an
// attempt. Requires ALL of: same thread, sent type, same account, same sender,
// same recipient, normalised subject, timestamp within window, and an exact
// canonical body hash (text hash OR html-derived-text hash). Never matches on
// subject/recipient/preview alone.
export function matchesAttempt(email, attempt, opts = {}) {
  const windowMs = opts.windowMs || 10 * 60 * 1000;
  const startMs = Date.parse(attempt.startedAt || 0) - (opts.clockSkewMs || 5000);
  const ts = Date.parse(email.timestamp_created || email.timestamp_email || 0);
  if (!(email && typeof email === 'object')) return false;
  if (String(email.thread_id || '') !== String(attempt.authoritativeThreadId || ' ')) return false;
  if (Number(email.ue_type) !== 3) return false;                       // 3 == sent/outbound
  if (normEmailAddr(email.eaccount) !== normEmailAddr(attempt.eaccount)) return false;
  const to = Array.isArray(email.to_address_email_list) ? email.to_address_email_list[0]
    : (email.to_address_email_list || email.to_address_email || '');
  if (attempt.recipient && normEmailAddr(to) && normEmailAddr(to) !== normEmailAddr(attempt.recipient)) return false;
  if (normSubject(email.subject) !== normSubject(attempt.subject)) return false;
  if (!Number.isFinite(ts) || ts < startMs || ts > startMs + windowMs) return false;
  const bodyText = email.body && typeof email.body === 'object' ? email.body.text : email.body_text;
  const bodyHtml = email.body && typeof email.body === 'object' ? email.body.html : email.body_html;
  // exact-hash fast path (clean text / unwrapped html)
  if (attempt.bodyHash && (attempt.bodyHash === (bodyText != null ? bodyHashOf(bodyText) : null)
    || attempt.bodyHash === (bodyHtml != null ? bodyHashOf(htmlToText(bodyHtml)) : null))) return true;
  // structural equivalence: reviewed body text present in the sent body
  // (robust to Instantly's full-document html wrapping + appended tracking).
  const reviewed = normalizeForMatch(attempt.bodyText || '');
  if (!reviewed) return false;
  const sent = normalizeForMatch(htmlToText(bodyHtml != null ? bodyHtml : (bodyText || '')));
  return sent.includes(reviewed);
}

// From a list of candidate emails, return {count, match?} — exactly-one required.
export function selectCandidate(emails, attempt, opts = {}) {
  const hits = (Array.isArray(emails) ? emails : []).filter((e) => matchesAttempt(e, attempt, opts));
  return { count: hits.length, match: hits.length === 1 ? hits[0] : null, hits };
}

// ---- shared token-bucket limiter (Instantly /emails: 20 req/min) ----------
export function makeRateLimiter({ capacity = 20, refillPerSec = 20 / 60, now = () => Date.now() } = {}) {
  let tokens = capacity; let last = now();
  return {
    tryTake() {
      const t = now(); tokens = Math.min(capacity, tokens + ((t - last) / 1000) * refillPerSec); last = t;
      if (tokens >= 1) { tokens -= 1; return true; }
      return false;
    },
    available() { return Math.floor(tokens); },
  };
}

// ---- reconciliation driver ------------------------------------------------
// One rate-limited /emails readback for a RECONCILING (or freshly ambiguous)
// attempt. Transitions to SENT_RECONCILED_READBACK (exactly-one match),
// MANUAL_RECONCILIATION_REQUIRED (multiple), or leaves RECONCILING (none yet).
// NEVER issues a reply POST.
export async function reconcileOnce(base, id, { apiKey, apiBase, fetchImpl, limiter, notify }) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (rec.state !== SEND_STATES.RECONCILING) {
    return { ok: true, state: rec.state, terminal: DELIVERED_STATES.includes(rec.state) || isTerminal(rec.state) };
  }
  const threadKey = rec.threadKey;
  const fireNotify = async (state) => { if (notify) { try { await notify(threadKey, state); } catch { /* notify best-effort */ } } };
  const attempt = rec.currentAttempt || (rec.sendAttempts || []).slice(-1)[0];
  if (!attempt || !attempt.authoritativeThreadId) {
    return { ok: false, reason: 'NO_AUTHORITATIVE_THREAD', state: rec.state };
  }
  if (limiter && !limiter.tryTake()) return { ok: true, state: rec.state, rateLimited: true };

  const doFetch = fetchImpl || fetch;
  const base2 = (apiBase || 'https://api.instantly.ai/api/v2').replace(/\/$/, '');
  const startIso = new Date(Date.parse(attempt.startedAt) - 5000).toISOString();
  const qs = new URLSearchParams({
    search: 'thread:' + attempt.authoritativeThreadId, eaccount: attempt.eaccount,
    email_type: 'sent', min_timestamp_created: startIso, sort_order: 'desc', limit: '10',
  });
  let status = 0; let items = [];
  try {
    const resp = await doFetch(base2 + '/emails?' + qs.toString(), {
      headers: { Authorization: 'Bearer ' + apiKey, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(12000),
    });
    status = resp.status;
    if (status >= 200 && status < 300) {
      const j = JSON.parse(await resp.text());
      items = j.items || j.data || (Array.isArray(j) ? j : []);
    }
  } catch { status = 0; }
  if (status === 429 || status >= 500 || status === 0) {
    return { ok: true, state: rec.state, readbackStatus: status, retriable: true };  // stay RECONCILING
  }

  const sel = selectCandidate(items, attempt, {});
  if (sel.count === 1) {
    finalizeSend(base, id, SEND_OUTCOMES.SENT_RECONCILED_READBACK,
      { reconciledEmailId: String(sel.match.id || ''), instantlyMessageId: String(sel.match.message_id || sel.match.id || '') });
    await fireNotify(SEND_STATES.SENT_RECONCILED_READBACK);
    T.record(base, 'send_outcome', { outcome: 'SENT_RECONCILED_READBACK' });
    T.record(base, 'send_confirmed', { latencyMs: Date.parse(nowIso()) - Date.parse(attempt.startedAt || nowIso()) });
    return { ok: true, state: SEND_STATES.SENT_RECONCILED_READBACK, emailId: String(sel.match.id || '') };
  }
  if (sel.count > 1) {
    finalizeSend(base, id, SEND_OUTCOMES.MANUAL_RECONCILIATION_REQUIRED, { detail: 'candidates:' + sel.count });
    await fireNotify(SEND_STATES.MANUAL_RECONCILIATION_REQUIRED);
    T.record(base, 'send_outcome', { outcome: 'MANUAL_RECONCILIATION_REQUIRED', candidates: sel.count });
    return { ok: true, state: SEND_STATES.MANUAL_RECONCILIATION_REQUIRED, candidateCount: sel.count };
  }
  return { ok: true, state: SEND_STATES.RECONCILING, candidateCount: 0 };   // not found yet
}

// Phase 4: reconcile an Instantly email_sent event against OPEN RECONCILING
// attempts. Cheap + bounded: immediately ignore unless a candidate could match.
// Correlates on account+recipient+subject+body hash+timestamp+thread; requires
// the event's thread_id to equal the stored authoritative thread. Never reopens
// a delivered/failed attempt; never sends. Scans only RECONCILING contexts.
export async function reconcileEmailSent(base, evt = {}, { notify } = {}) {
  const eaccount = normEmailAddr(evt.eaccount || evt.email_account);
  if (!eaccount) return { matched: false, reason: 'NO_EACCOUNT' };
  // build a synthetic email object from the event for matchesAttempt()
  const email = {
    id: String(evt.email_id || evt.id || ''),
    message_id: String(evt.message_id || ''),
    thread_id: String(evt.thread_id || ''),
    ue_type: 3,
    eaccount,
    to_address_email_list: evt.to_address_email_list
      || (evt.lead_email ? [evt.lead_email] : (evt.to_email ? [evt.to_email] : [])),
    subject: evt.subject || evt.reply_subject || '',
    timestamp_created: evt.timestamp || evt.timestamp_created || new Date().toISOString(),
    body: { text: evt.email_text != null ? evt.email_text : undefined, html: evt.email_html },
  };
  const dir = contextsDir(base);
  if (!fs.existsSync(dir)) return { matched: false, reason: 'NO_CONTEXTS' };
  for (const f of fs.readdirSync(dir)) {
    if (!/^[0-9a-f]{32}\.json$/.test(f)) continue;
    const id = f.slice(0, 32);
    const rec = readContext(base, id);
    if (!rec || rec.state !== SEND_STATES.RECONCILING) continue;    // only open attempts
    const attempt = rec.currentAttempt || (rec.sendAttempts || []).slice(-1)[0];
    if (!attempt || !attempt.authoritativeThreadId) continue;
    if (String(email.thread_id) !== String(attempt.authoritativeThreadId)) continue;  // thread must match
    if (matchesAttempt(email, attempt, {})) {
      finalizeSend(base, id, SEND_OUTCOMES.SENT_RECONCILED_WEBHOOK,
        { reconciledEmailId: email.id || null, instantlyMessageId: email.message_id || email.id || null });
      if (notify) { try { await notify(rec.threadKey, SEND_STATES.SENT_RECONCILED_WEBHOOK); } catch { /* best-effort */ } }
      T.record(base, 'send_outcome', { outcome: 'SENT_RECONCILED_WEBHOOK' });
      return { matched: true, contextId: id, state: SEND_STATES.SENT_RECONCILED_WEBHOOK };
    }
  }
  return { matched: false, reason: 'NO_OPEN_CANDIDATE' };
}

// Escalate a still-RECONCILING attempt to MANUAL once its window is exhausted.
export async function expireReconciliation(base, id, { windowMs = 6 * 60 * 1000, notify } = {}) {
  const rec = readContext(base, id);
  if (!rec || rec.state !== SEND_STATES.RECONCILING) return { ok: false, state: rec?.state };
  if (Date.now() - Date.parse(rec.reconcileStartedAt || rec.updatedAt) < windowMs) {
    return { ok: true, state: rec.state, expired: false };
  }
  finalizeSend(base, id, SEND_OUTCOMES.MANUAL_RECONCILIATION_REQUIRED, { detail: 'window_exhausted' });
  if (notify) { try { await notify(rec.threadKey, SEND_STATES.MANUAL_RECONCILIATION_REQUIRED); } catch { /* best-effort */ } }
  T.record(base, 'send_outcome', { outcome: 'MANUAL_RECONCILIATION_REQUIRED', reason: 'window_exhausted' });
  return { ok: true, state: SEND_STATES.MANUAL_RECONCILIATION_REQUIRED, expired: true };
}

// Escape user text for Google Chat / HTML email, preserving line + blank-line
// structure by mapping each LF to <br> (repeated blanks -> repeated <br>).
export function toHtml(text) {
  return String(text == null ? '' : text)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;')
    .replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    .replace(/\n/g, '<br>');
}

// Atomic single-POST send with reconciliation. validate+gate+arm+lock -> ONE
// reply POST (Bearer formed HERE, once) -> classify:
//   2xx            -> SENT_API_CONFIRMED
//   401/403/4xx    -> FAILED_DEFINITIVE (-> RETRYABLE)
//   timeout/reset/parse/5xx/no-response -> RECONCILING (then bounded readback)
// A test-only faultInject can drop the response AFTER the genuine POST completes.
// Resolve + persist the authoritative thread_id for a context that lacks one
// (webhook payloads omit thread_id). Looked up once from the reply_to_uuid via
// the authenticated /emails/{id} endpoint so reconciliation can match later.
export async function ensureThreadId(base, id, { apiKey, apiBase, fetchImpl } = {}) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (rec.authoritativeThreadId) return { ok: true, threadId: rec.authoritativeThreadId, source: 'stored' };
  if (!apiKey || !rec.replyToUuid) return { ok: false, reason: 'CANNOT_RESOLVE' };
  const doFetch = fetchImpl || fetch;
  const base2 = (apiBase || 'https://api.instantly.ai/api/v2').replace(/\/$/, '');
  try {
    const r = await doFetch(`${base2}/emails/${encodeURIComponent(rec.replyToUuid)}`, {
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(8000) });
    if (r.status !== 200) return { ok: false, reason: 'EMAIL_' + r.status };
    const j = JSON.parse(await r.text());
    if (!j.thread_id) return { ok: false, reason: 'NO_THREAD_ID' };
    const cur = readContext(base, id);
    cur.authoritativeThreadId = j.thread_id; cur.threadVerifiedAt = nowIso(); cur.updatedAt = nowIso();
    atomicWrite(contextPath(base, id), cur);
    return { ok: true, threadId: j.thread_id, source: 'resolved' };
  } catch { return { ok: false, reason: 'LOOKUP_ERROR' }; }
}

export async function performSend(base, id, { reviewToken, bodyHash }, opts) {
  const { apiKey, apiBase, fetchImpl, limiter, faultInject, syncReadback = true, notify } = opts || {};
  if (!apiKey) return { ok: false, acquired: false, reason: 'NO_API_KEY_CONFIGURED' };
  if (isHistoricalActor(readContext(base, id))) return { ok: false, acquired: false, reason: 'HISTORICAL_NON_ACTIONABLE' };
  const acq = acquireSend(base, id, { reviewToken, bodyHash });
  if (!acq.acquired) {
    // Stale/outdated card: recover by surfacing the current latest Review card
    // with a fresh one-use token. Never sends; never treats the stale click as
    // approval for the newer revision.
    if (acq.reason === 'TOKEN_MISMATCH' || acq.reason === 'BODY_TAMPERED' || acq.reason === 'NO_ACTIVE_DRAFT') {
      const latest = refreshLatestCard(base, id);
      if (latest.ok) return { ok: false, reason: 'STALE_CARD', staleRecovery: latest };
    }
    return { ok: false, ...acq };                             // blocked BEFORE any POST
  }

  // ensure reconciliation can match later (webhook contexts lack thread_id)
  await ensureThreadId(base, id, { apiKey, apiBase, fetchImpl });
  // refresh the attempt's thread from the (possibly newly resolved) context
  { const cx = readContext(base, id); if (cx && cx.currentAttempt && cx.authoritativeThreadId && !cx.currentAttempt.authoritativeThreadId) { cx.currentAttempt.authoritativeThreadId = cx.authoritativeThreadId; atomicWrite(contextPath(base, id), cx); } }

  const r = acq.routing;
  T.record(base, 'send_post', { revision: r.revision });      // exactly one POST is about to be made
  const text = canonicalBody(r.body);                         // exact reviewed body (LF, trimmed)
  const html = toHtml(text);
  const subject = /^re:/i.test(String(r.subject || '')) ? r.subject : ('Re: ' + String(r.subject || ''));
  const doFetch = fetchImpl || fetch;
  const base2 = (apiBase || 'https://api.instantly.ai/api/v2').replace(/\/$/, '');

  let status = 0; let respText = ''; let fault = null;
  try {
    const resp = await doFetch(base2 + '/emails/reply', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ eaccount: r.eaccount, reply_to_uuid: r.reply_to_uuid, subject, body: { text, html } }),
      signal: AbortSignal.timeout(20000),
    });
    // test-only: genuine POST completed upstream, but we lose the response here
    if (faultInject === 'drop_response') { fault = TRANSPORT_FAULTS.RESPONSE_PARSE_FAILURE; throw new Error('injected_response_loss'); }
    status = resp.status;
    respText = (await resp.text().catch(() => { throw new Error('parse'); })).slice(0, 400);
  } catch (e) {
    const name = String((e && e.name) || '');
    if (fault) { /* keep injected fault */ }
    else if (/TimeoutError|AbortError/.test(name)) fault = TRANSPORT_FAULTS.ETIMEDOUT;
    else if (/parse/i.test(String(e && e.message))) fault = TRANSPORT_FAULTS.RESPONSE_PARSE_FAILURE;
    else if (/ECONNRESET|reset/i.test(name + String(e && e.message))) fault = TRANSPORT_FAULTS.ECONNRESET;
    else fault = TRANSPORT_FAULTS.UNKNOWN_TRANSPORT_FAILURE;
    status = 0;
  }

  // classify
  if (status >= 200 && status < 300) {
    let msgId = null;
    try { const j = JSON.parse(respText); msgId = String(j.id || j.message_id || j.email_id || '') || null; } catch { /* ignore */ }
    finalizeSend(base, id, SEND_OUTCOMES.SENT_API_CONFIRMED, { httpStatus: status, instantlyMessageId: msgId });
    T.record(base, 'send_outcome', { outcome: 'SENT_API_CONFIRMED' });
    T.record(base, 'send_confirmed', { latencyMs: 0 });
    return { ok: true, outcome: SEND_OUTCOMES.SENT_API_CONFIRMED, httpStatus: status, state: SEND_STATES.SENT_API_CONFIRMED, uniboxUrl: acq.uniboxUrl };
  }
  if (status >= 400 && status < 500) {
    const detail = 'http_' + status + (respText ? (': ' + respText.replace(/\s+/g, ' ').slice(0, 120)) : '');
    finalizeSend(base, id, SEND_OUTCOMES.FAILED_DEFINITIVE, { httpStatus: status, detail });
    T.record(base, 'send_outcome', { outcome: 'FAILED_DEFINITIVE', httpStatus: status });
    return { ok: false, outcome: SEND_OUTCOMES.FAILED_DEFINITIVE, httpStatus: status, state: SEND_STATES.RETRYABLE, uniboxUrl: acq.uniboxUrl };
  }
  // ambiguous (timeout/reset/parse/5xx/no-response): RECONCILING, keep lock, verify
  if (status >= 500) fault = TRANSPORT_FAULTS.UPSTREAM_5XX;
  toReconciling(base, id, fault || TRANSPORT_FAULTS.UNKNOWN_TRANSPORT_FAILURE, status || null);

  // bounded synchronous readback attempts within the Chat window
  if (syncReadback && apiKey) {
    const rr = await reconcileOnce(base, id, { apiKey, apiBase, fetchImpl, limiter }); // sync: card shows result, no async notify
    if (DELIVERED_STATES.includes(rr.state) || rr.state === SEND_STATES.MANUAL_RECONCILIATION_REQUIRED) {
      return { ok: rr.state === SEND_STATES.SENT_RECONCILED_READBACK, outcome: rr.state, state: rr.state, reconciled: true, uniboxUrl: acq.uniboxUrl, emailId: rr.emailId };
    }
  }
  return { ok: false, outcome: SEND_OUTCOMES.RECONCILING, httpStatus: status, transportFault: fault, state: SEND_STATES.RECONCILING, uniboxUrl: acq.uniboxUrl };
}

export function cancel(base, id) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (rec.state === SEND_STATES.SENDING) return { ok: false, reason: 'SEND_IN_PROGRESS' };
  // A possibly-delivered send in RECONCILING must NOT be cancellable.
  if (rec.state === SEND_STATES.RECONCILING) return { ok: false, reason: 'RECONCILING_IN_PROGRESS' };
  if (isTerminal(rec.state) && rec.state !== SEND_STATES.EXPIRED) {
    return { ok: false, reason: 'ALREADY_TERMINAL', state: rec.state };
  }
  rec.drafts = rec.drafts.map((d) => ({ ...d, superseded: true, tokenUsed: true }));
  rec.activeReviewToken = null;
  rec.activeDraftRevision = null;
  rec.state = SEND_STATES.CANCELLED;
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  return { ok: true, state: rec.state };
}

// Reset only CANCELLED / EXPIRED contexts back to PENDING. Any delivered or
// in-flight state (SENDING, RECONCILING, SENT_*, MANUAL_RECONCILIATION_REQUIRED)
// is NEVER resettable; RETRYABLE is already directly draftable. The append-only
// sendAttempts[] audit is always preserved.
export function resetContext(base, id) {
  const rec = readContext(base, id);
  if (!rec) return { ok: false, reason: 'NOT_FOUND' };
  if (!['CANCELLED', 'EXPIRED'].includes(rec.state)) {
    return { ok: false, reason: 'NOT_RESETTABLE', state: rec.state };
  }
  rec.state = SEND_STATES.PENDING;
  rec.activeReviewToken = null;
  rec.activeDraftRevision = null;
  rec.expiresAt = new Date(Date.now() + CONTEXT_TTL_MS).toISOString();
  rec.updatedAt = nowIso();
  atomicWrite(contextPath(base, id), rec);
  releaseLock(base, id);
  return { ok: true, state: rec.state };
}

// ---- authorized-user binding ----------------------------------------------
function bindingPath(base) { return path.join(base, 'owner-binding.json'); }

export function getBinding(base) { return readJson(bindingPath(base)); }

export function setBinding(base, { email, userResourceName, domain, space }) {
  const existing = getBinding(base);
  if (existing && existing.userResourceName && existing.userResourceName !== userResourceName) {
    return { ok: false, reason: 'BINDING_CONFLICT', existing: redactEmail(existing.email) };
  }
  const rec = {
    email: String(email || '').toLowerCase(),
    userResourceName: userResourceName || null,
    domain: domain || null,
    space: space || null,
    boundAt: existing?.boundAt || nowIso(),
    confirmedAt: nowIso(),
  };
  atomicWrite(bindingPath(base), rec);
  return { ok: true, binding: { ...rec, email: redactEmail(rec.email) } };
}

// ---- owner authorisation: binding + bootstrap capture ---------------------
// Identity separation: the bearer token proves the caller is Google Chat
// (service account chat@system…). The HUMAN operator identity comes ONLY from
// the interaction event (user.name / user.type / user.email). We authorise on
// the stable user.name after an explicit owner binding; the allowed Workspace
// email is bootstrap evidence, normalised trim+lowercase, HUMAN-only.
function candidatePath(base) { return path.join(base, 'owner-candidate.json'); }

export function getCandidate(base) { return readJson(candidatePath(base)); }
function setCandidate(base, c) { atomicWrite(candidatePath(base), c); return c; }
export function clearCandidate(base) {
  try { fs.unlinkSync(candidatePath(base)); } catch (e) { if (e?.code !== 'ENOENT') throw e; }
}

const normEmail = (s) => String(s || '').trim().toLowerCase();

export function authorizeIdentity(base, allowedEmail, identity = {}) {
  const allowed = normEmail(allowedEmail);
  const uType = identity.userType;
  const uName = identity.userName || '';
  const uEmail = identity.userEmail ? normEmail(identity.userEmail) : '';

  const binding = getBinding(base);
  // Once bound, authorise strictly on the stable canonical user resource name
  // AND the bound space (when a space was bound). Never by display name.
  if (binding && binding.userResourceName) {
    const userOk = uType === 'HUMAN' && uName && uName === binding.userResourceName;
    const spaceOk = !binding.space || (identity.space && identity.space === binding.space);
    const authorized = userOk && spaceOk;
    let reason = null;
    if (!authorized) reason = uType !== 'HUMAN' ? 'not_human'
      : (!userOk ? 'user_not_bound_owner' : 'space_mismatch');
    return {
      authorized, authzState: authorized ? 'bound' : 'denied', reason, bound: true,
      spaceMatches: binding.space ? spaceOk : null,
    };
  }

  // No binding yet -> bootstrap capture, permitted ONLY while the send gate is
  // OFF. Never returns authorized:true; capture awaits explicit confirmation.
  if (getGoLive(base).enabled) {
    return { authorized: false, authzState: 'denied', reason: 'no_owner_binding' };
  }
  if (uType !== 'HUMAN') return { authorized: false, authzState: 'denied', reason: 'not_human' };
  // If the event carries an email, it must match the allowed owner. If absent,
  // still capture one HUMAN candidate for confirmation (do not weaken).
  if (identity.userEmail && allowed && uEmail !== allowed) {
    return { authorized: false, authzState: 'denied', reason: 'email_mismatch' };
  }
  setCandidate(base, {
    userName: uName || null,
    userEmail: identity.userEmail ? uEmail : null,
    displayName: identity.displayName || null,
    domainId: identity.domainId || null,
    space: identity.space || null,
    thread: identity.thread || null,
    capturedAt: nowIso(),
  });
  return { authorized: false, authzState: 'bootstrap_captured' };
}

// Bind the captured candidate after explicit owner confirmation in-session.
export function confirmOwner(base, { userName, space } = {}) {
  const c = getCandidate(base);
  if (!c) return { ok: false, reason: 'NO_CANDIDATE' };
  const resolvedUser = userName || c.userName;
  if (!resolvedUser) return { ok: false, reason: 'NO_USER_RESOURCE_NAME' };
  const email = c.userEmail || '';
  const domain = email.includes('@') ? email.split('@')[1] : (c.domainId || null);
  const b = setBinding(base, {
    email, userResourceName: resolvedUser, domain, space: space || c.space || null,
  });
  clearCandidate(base);   // auto-disable bootstrap capture after binding
  return b;
}

// ---- go-live gate (default OFF) -------------------------------------------
function goLivePath(base) { return path.join(base, 'go-live.json'); }

export function getGoLive(base) {
  const rec = readJson(goLivePath(base));
  if (!rec || typeof rec !== 'object') return { enabled: false };
  return {
    enabled: rec.enabled === true, note: rec.note || null, at: rec.at || null,
    armedContextId: rec.armedContextId || null, armedRevision: rec.armedRevision || null,
    faultInject: rec.faultInject || null,
  };
}

// Optionally arm for exactly one context + revision (opts.contextId, opts.revision).
// opts.faultInject (test-only) is applied by the send path ONLY for the armed
// context — the genuine POST still completes; only the response is discarded.
export function setGoLive(base, enabled, note, opts = {}) {
  // Defence-in-depth: refuse to arm a historical/backfill context.
  let armContextId = opts.contextId || null;
  if (armContextId && isHistoricalActor(readContext(base, armContextId))) {
    T.record(base, 'historical_arm_blocked', {});
    armContextId = null;
  }
  const rec = {
    enabled: enabled === true, note: note ? String(note).slice(0, 200) : null, at: nowIso(),
    armedContextId: armContextId,
    armedRevision: Number.isInteger(opts.revision) ? opts.revision : null,
    faultInject: (opts.faultInject === 'drop_response') ? 'drop_response' : null,
  };
  atomicWrite(goLivePath(base), rec);
  return rec;
}

function redactEmail(e) {
  const s = String(e || '');
  const [u, d] = s.split('@');
  if (!d) return '<redacted>';
  return `${u.slice(0, 2)}***@${d}`;
}
