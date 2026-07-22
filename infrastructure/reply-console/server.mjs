// hmz-reply-console: internal HTTP sidecar for the Google Chat supervised
// reply console. Binds 0.0.0.0:5691 inside the container; NOT published to the
// host. n8n reaches it as http://hmz-reply-console:5691 on the compose network.
//
// Responsibilities:
//   1. Verify Google Chat bearer tokens (google-auth-library) — POST /v1/verify
//   2. Durable context / draft / one-use-token / send-state store (store.mjs)
//
// It never receives or stores Instantly/n8n API keys or webhook secrets.

import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { verifyChatBearer } from './verify.mjs';
import {
  createContext, readContext, resolveByThreadKey, attachChatPost,
  createDraft, validateReview, acquireSend, finalizeSend, cancel,
  getBinding, setBinding, deriveThreadKey, deriveContextKey,
  getGoLive, setGoLive,
  authorizeIdentity, getCandidate, confirmOwner, clearCandidate,
  resetContext, performSend, reconcileOnce, expireReconciliation, makeRateLimiter,
  reconcileEmailSent, SEND_STATES, DELIVERED_STATES,
  setNotificationState, listUnnotified, findByInstantlyEmailId, setTestSuppress, getSuppressSet, refreshLatestCard,
} from './store.mjs';
import { resolveSenderName, prospectNameFromPayload, prospectDisplay, resolveProspectNameByLookup } from './enrich.mjs';
import { pollRecover, getHighWaterMark } from './recovery.mjs';
import { createInboundService } from './inbound-service.mjs';
import * as T from './telemetry.mjs';

const PORT = Number(process.env.PORT || 5691);
const HOST = '0.0.0.0';
const STATE_DIR = process.env.STATE_DIR || '/data';
const AUDIENCE = process.env.CHAT_AUDIENCE || '';   // fixed to the interaction URL via compose
const PROJECT_NUMBER = process.env.CHAT_PROJECT_NUMBER || ''; // fixed via compose (mode B)
const OWNER_ALLOWED_EMAIL = process.env.OWNER_ALLOWED_EMAIL || ''; // fixed via compose
const INSTANTLY_API_KEY = process.env.INSTANTLY_API_KEY || '';    // root-owned env; never logged
const INSTANTLY_API_BASE = process.env.INSTANTLY_API_BASE || 'https://api.instantly.ai/api/v2';
const GCHAT_NOTIFY_URL = process.env.GCHAT_NOTIFY_URL || ''; // incoming webhook (one-way) for async status posts
const INBOUND_NOTIFICATION_EPOCH = process.env.INBOUND_NOTIFICATION_EPOCH || '';
const ENABLE_TEST_CONTROLS = process.env.ENABLE_TEST_CONTROLS === '1';
// One shared token-bucket across all reconciliation (Instantly /emails: 20/min).
const RECON_LIMITER = makeRateLimiter({ capacity: 20, refillPerSec: 20 / 60 });
let POLL_HEARTBEAT = { at: null, result: null };
const INBOUND = createInboundService({
  stateDir: STATE_DIR,
  apiKey: INSTANTLY_API_KEY,
  apiBase: INSTANTLY_API_BASE,
  notifyUrl: GCHAT_NOTIFY_URL,
  notificationEpoch: INBOUND_NOTIFICATION_EPOCH || null,
});
let INBOUND_SWEEP_RUNNING = false;

// Async status push into the prospect's Chat thread via the one-way incoming
// webhook (no app auth). Posts a threaded, plain-text confirmation so the owner
// is informed automatically without clicking "Check status".
async function postThreadStatus(threadKey, state) {
  if (!GCHAT_NOTIFY_URL || !threadKey) return;
  let text;
  if (state === 'SENT_RECONCILED_READBACK' || state === 'SENT_RECONCILED_WEBHOOK') text = '✅ Sent — confirmed in Instantly.';
  else if (state === 'MANUAL_RECONCILIATION_REQUIRED') text = '⚠️ Delivery could not be confirmed automatically. Open Instantly to verify. Do not resend.';
  else return;
  try {
    await fetch(GCHAT_NOTIFY_URL + '&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, thread: { threadKey } }), signal: AbortSignal.timeout(8000),
    });
  } catch { /* best-effort */ }
}

function sendJson(res, status, body) {
  const j = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(j) });
  res.end(j);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 2_000_000) { reject(new Error('payload_too_large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { reject(new Error('invalid_json_body')); }
    });
    req.on('error', reject);
  });
}

export function createServer() {
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://hmz-reply-console');
      const p = url.pathname;

      if (req.method === 'GET' && p === '/health') {
        const inbound = INBOUND.integrity();
        return sendJson(res, inbound.ok ? 200 : 503, {
          status: inbound.ok ? 'ok' : 'degraded', audienceConfigured: Boolean(AUDIENCE),
          inboundSchemaVersion: 2, inboundStoreIntegrity: inbound.ok,
        });
      }

      // ---- canonical inbound + transactional outbox (v2) -----------------
      // These endpoints are reachable only on the private compose network.
      // They can post to the one fixed Google Chat URL but contain no code path
      // capable of sending a prospect email.
      if (req.method === 'POST' && p === '/v2/inbound') {
        const body = await readBody(req);
        const result = await INBOUND.registerReceived(body, {
          authoritativeReceived: false,
          discoverySource: 'DISCOVERED_WEBHOOK',
          recovered: false,
        });
        if (!result.ok && result.reason === 'NOT_INSTANTLY_RECEIVED') {
          return sendJson(res, 200, { ok: true, ignored: true, reason: result.reason });
        }
        if (!result.ok) return sendJson(res, 400, { ok: false, reason: result.reason || 'INVALID_INBOUND' });
        const drain = await INBOUND.drainOutbox({ limit: 10, maxBatches: 1 });
        const notification = INBOUND.notification(result.record.identity);
        return sendJson(res, 200, {
          ok: true,
          notificationRequired: true,
          created: result.created,
          identity: result.record.identity,
          instantlyEmailId: result.record.instantlyEmailId,
          identityKind: result.record.identityKind,
          classification: result.record.classification,
          degradedMetadata: result.record.degradedMetadata,
          sendAllowed: result.record.sendAllowed,
          notificationState: notification?.state || result.outbox.state,
          drain,
        });
      }
      if (req.method === 'POST' && p === '/v2/poll') {
        const result = await INBOUND.runNormalPoll();
        POLL_HEARTBEAT = { at: new Date().toISOString(), result: {
          ok: result.ok, scanned: result.observed, recovered: result.created,
        } };
        return sendJson(res, result.ok ? 200 : 503, result);
      }
      { const auditMatch = p.match(/^\/v2\/audit\/(short|deep|daily)$/);
      if (req.method === 'POST' && auditMatch) {
        const mode = auditMatch[1];
        const windows = { short: 2 * 60 * 60 * 1000, deep: 24 * 60 * 60 * 1000, daily: 7 * 24 * 60 * 60 * 1000 };
        const result = await INBOUND.runCompletenessAudit(mode, { windowMs: windows[mode] });
        return sendJson(res, result.ok ? 200 : 503, result);
      } }
      if (req.method === 'POST' && p === '/v2/outbox/drain') {
        return sendJson(res, 200, await INBOUND.drainOutbox({ limit: 25, maxBatches: 4 }));
      }
      if (req.method === 'GET' && p === '/v2/operations') {
        return sendJson(res, 200, INBOUND.operations());
      }
      if (req.method === 'GET' && p === '/v2/watchdog') {
        return sendJson(res, 200, await INBOUND.watchdog());
      }

      // ---- Google request verification -------------------------------------
      if (req.method === 'POST' && p === '/v1/verify') {
        const body = await readBody(req);
        const result = await verifyChatBearer(body.token, AUDIENCE, PROJECT_NUMBER);
        // never echo the token; return only the minimal verified/unverified
        // result (plus a sanitized diag on failure to aid live diagnosis).
        if (result.verified && body.event && typeof body.event === 'object') {
          // The request is proven to be from Google Chat; the HUMAN operator
          // identity comes solely from the event body (never the token).
          const authz = authorizeIdentity(STATE_DIR, OWNER_ALLOWED_EMAIL, body.event);
          Object.assign(result, authz);
        }
        return sendJson(res, result.verified ? 200 : 401, result);
      }

      // health also reports which verification modes are configured (no secrets)
      if (req.method === 'GET' && p === '/v1/verify-config') {
        return sendJson(res, 200, { ok: true, audienceConfigured: Boolean(AUDIENCE),
          projectNumberConfigured: Boolean(PROJECT_NUMBER), debug: process.env.CHAT_VERIFY_DEBUG === '1' });
      }

      // ---- sender-name resolution (Instantly Account, cached) --------------
      if (req.method === 'GET' && p === '/v1/sender-name') {
        const eaccount = url.searchParams.get('eaccount') || '';
        const r = await resolveSenderName(STATE_DIR, eaccount,
          { apiKey: INSTANTLY_API_KEY, apiBase: INSTANTLY_API_BASE });
        T.record(STATE_DIR, 'name_source', { kind: 'sender', source: r.found ? (r.name ? r.source : 'NOT_CONFIGURED') : r.source });
        return sendJson(res, 200, { ok: true, ...r });
      }
      // ---- prospect-name resolve (payload first, optional lookup fallback) --
      if (req.method === 'POST' && p === '/v1/prospect-name') {
        const body = await readBody(req);
        let r = prospectNameFromPayload(body.payload || {});
        if (!r.name && body.email) {
          const lk = await resolveProspectNameByLookup(body.email, body.campaignId,
            { apiKey: INSTANTLY_API_KEY, apiBase: INSTANTLY_API_BASE });
          if (lk.name) r = lk; else r.source = lk.source || r.source;
        }
        T.record(STATE_DIR, 'name_source', { kind: 'prospect', source: r.source });
        return sendJson(res, 200, { ok: true, name: r.name, source: r.source, display: prospectDisplay(r.name, body.email || '') });
      }
      // ---- reliability report (telemetry) ----------------------------------
      if (req.method === 'GET' && p === '/v1/report') {
        const days = Math.min(90, Math.max(1, Number(url.searchParams.get('days') || 30)));
        return sendJson(res, 200, T.report(STATE_DIR, days));
      }

      // ---- dual-path inbound recovery (scheduled poll calls this) ----------
      if (req.method === 'POST' && p === '/v1/poll-recover') {
        const r = await INBOUND.runNormalPoll();
        POLL_HEARTBEAT = { at: new Date().toISOString(), result: { ok: r.ok, scanned: r.observed, recovered: r.created,
          retried: r.drain && r.drain.attempted, retryRecovered: r.drain && r.drain.notified } };
        return sendJson(res, r.ok ? 200 : 503, r);
      }
      if (req.method === 'GET' && p === '/v1/poll-heartbeat') {
        return sendJson(res, 200, { ok: true, heartbeat: POLL_HEARTBEAT, highWaterMark: getHighWaterMark(STATE_DIR) });
      }
      // ---- watchdog: aggregate operational alerts (no send, no bodies) -----
      if (req.method === 'GET' && p === '/v1/watchdog') {
        return sendJson(res, 200, await INBOUND.watchdog());
      }
      // ---- watchdog: unnotified contexts (no send, no bodies) --------------
      if (req.method === 'GET' && p === '/v1/unnotified') {
        const olderThanMs = Number(url.searchParams.get('olderThanMs') || 0);
        return sendJson(res, 200, { ok: true, unnotified: listUnnotified(STATE_DIR, { olderThanMs }) });
      }

      // ---- test-only: suppress webhook-path notification for one email id --
      if (req.method === 'POST' && p === '/v1/test-suppress') {
        if (!ENABLE_TEST_CONTROLS) return sendJson(res, 404, { ok: false, reason: 'not_found' });
        const body = await readBody(req);
        const r = setTestSuppress(STATE_DIR, body.emailId, body.on !== false);
        return sendJson(res, 200, r);
      }
      if (req.method === 'GET' && p === '/v1/test-suppress') {
        if (!ENABLE_TEST_CONTROLS) return sendJson(res, 404, { ok: false, reason: 'not_found' });
        return sendJson(res, 200, { ok: true, suppressed: Object.keys(getSuppressSet(STATE_DIR)) });
      }
      // ---- inbound dedup lookup by Instantly email id (poll recovery) ------
      { const mm = p.match(/^\/v1\/inbound-by-email\/([^/]+)$/);
      if (req.method === 'GET' && mm) {
        const rec = findByInstantlyEmailId(STATE_DIR, decodeURIComponent(mm[1]));
        return sendJson(res, rec ? 200 : 404, rec ? { ok: true, notificationId: rec.notificationId, state: rec.notificationState } : { ok: false, reason: 'NOT_FOUND' });
      } }

      // ---- context ---------------------------------------------------------
      if (req.method === 'POST' && p === '/v1/context') {
        const body = await readBody(req);
        const r = createContext(STATE_DIR, body);
        return sendJson(res, r.ok ? 200 : 400, r);
      }
      let m;
      if (req.method === 'GET' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})$/))) {
        const rec = readContext(STATE_DIR, m[1]);
        return rec ? sendJson(res, 200, { ok: true, context: publicView(rec) })
          : sendJson(res, 404, { ok: false, reason: 'NOT_FOUND' });
      }
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/chat$/))) {
        const body = await readBody(req);
        const r = attachChatPost(STATE_DIR, m[1], body);
        return sendJson(res, r.ok ? 200 : 404, r);
      }
      if (req.method === 'GET' && p === '/v1/context/by-thread') {
        const threadKey = url.searchParams.get('threadKey') || '';
        const rec = resolveByThreadKey(STATE_DIR, threadKey);
        return rec ? sendJson(res, 200, { ok: true, context: publicView(rec) })
          : sendJson(res, 404, { ok: false, reason: 'NO_CONTEXT_FOR_THREAD' });
      }

      // ---- draft / review / edit ------------------------------------------
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/draft$/))) {
        const body = await readBody(req);
        const r = createDraft(STATE_DIR, m[1], body);
        return sendJson(res, r.ok ? 200 : 400, r);
      }
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/validate$/))) {
        const body = await readBody(req);
        const r = validateReview(STATE_DIR, m[1], body);
        return sendJson(res, r.ok ? 200 : 409, r);
      }

      // ---- atomic send (acquire -> ONE Instantly POST -> reconcile) -------
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/send$/))) {
        const body = await readBody(req);
        // test-only fault injection applies ONLY to the exact armed context.
        const gl = getGoLive(STATE_DIR);
        const faultInject = (gl.faultInject && gl.armedContextId === m[1]) ? gl.faultInject : null;
        const r = await performSend(STATE_DIR, m[1], body,
          { apiKey: INSTANTLY_API_KEY, apiBase: INSTANTLY_API_BASE, limiter: RECON_LIMITER, faultInject });
        return sendJson(res, (r.ok || r.state === SEND_STATES.RECONCILING) ? 200 : 409, r);
      }
      // ---- check status / one rate-limited reconciliation (no POST) -------
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/reconcile$/))) {
        const r = await reconcileOnce(STATE_DIR, m[1],
          { apiKey: INSTANTLY_API_KEY, apiBase: INSTANTLY_API_BASE, limiter: RECON_LIMITER }); // check-status is synchronous; no async notify
        return sendJson(res, 200, r);
      }
      // ---- Phase 4: email_sent webhook reconciliation (no POST, no notify) -
      if (req.method === 'POST' && p === '/v1/email-sent') {
        const body = await readBody(req);
        const r = await reconcileEmailSent(STATE_DIR, body.event || body, { notify: postThreadStatus });
        return sendJson(res, 200, { ok: true, ...r });
      }
      // non-secret fingerprint of the injected send key (SHA-256 prefix + len)
      if (req.method === 'GET' && p === '/v1/instantly-fingerprint') {
        return sendJson(res, 200, { ok: true, configured: Boolean(INSTANTLY_API_KEY),
          sha256_12: INSTANTLY_API_KEY ? crypto.createHash('sha256').update(INSTANTLY_API_KEY).digest('hex').slice(0, 12) : null,
          len: INSTANTLY_API_KEY.length, apiBase: INSTANTLY_API_BASE });
      }
      // ---- send acquire / finalize (kept for tests/diagnostics) -----------
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/send\/acquire$/))) {
        const body = await readBody(req);
        const r = acquireSend(STATE_DIR, m[1], body);
        return sendJson(res, r.acquired ? 200 : 409, r);
      }
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/send\/finalize$/))) {
        const body = await readBody(req);
        const r = finalizeSend(STATE_DIR, m[1], body.toState, body.details || {});
        return sendJson(res, r.ok ? 200 : 409, r);
      }
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/cancel$/))) {
        const r = cancel(STATE_DIR, m[1]);
        return sendJson(res, r.ok ? 200 : 409, r);
      }
      // stale-card recovery / refresh: re-issue the latest revision token (no send)
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/refresh-card$/))) {
        const r = refreshLatestCard(STATE_DIR, m[1]);
        return sendJson(res, r.ok ? 200 : 409, r);
      }
      if (req.method === 'POST' && (m = p.match(/^\/v1\/context\/([0-9a-f]{32})\/reset$/))) {
        const r = resetContext(STATE_DIR, m[1]);
        return sendJson(res, r.ok ? 200 : 409, r);
      }

      // ---- owner binding + bootstrap candidate -----------------------------
      if (req.method === 'GET' && p === '/v1/owner-binding') {
        const b = getBinding(STATE_DIR);
        return sendJson(res, 200, { ok: true, bound: Boolean(b), binding: b ? redactBinding(b) : null });
      }
      if (req.method === 'POST' && p === '/v1/owner-binding') {
        const body = await readBody(req);
        const r = setBinding(STATE_DIR, body);
        return sendJson(res, r.ok ? 200 : 409, r);
      }
      // non-secret alignment check: does a given space equal the bound space?
      if (req.method === 'GET' && p === '/v1/space-check') {
        const b = getBinding(STATE_DIR);
        const space = url.searchParams.get('space') || '';
        return sendJson(res, 200, { ok: true, bound: Boolean(b && b.space),
          matches: Boolean(b && b.space && space && b.space === space) });
      }
      if (req.method === 'GET' && p === '/v1/owner-candidate') {
        const c = getCandidate(STATE_DIR);
        return sendJson(res, 200, { ok: true, candidate: c ? redactCandidate(c) : null });
      }
      // capture a candidate directly from a retained/known identity (used to
      // seed from an already-retained genuine event without another mention).
      if (req.method === 'POST' && p === '/v1/authorize') {
        const body = await readBody(req);
        const r = authorizeIdentity(STATE_DIR, OWNER_ALLOWED_EMAIL, body.event || body);
        return sendJson(res, 200, { ok: true, ...r });
      }
      // explicit in-session confirmation -> bind stable user + space.
      if (req.method === 'POST' && p === '/v1/owner-confirm') {
        const body = await readBody(req);
        const r = confirmOwner(STATE_DIR, body);
        if (!r.ok) return sendJson(res, 409, r);
        return sendJson(res, 200, { ok: true, bound: true, binding: redactBinding(getBinding(STATE_DIR)) });
      }

      // ---- go-live gate (default OFF) --------------------------------------
      if (req.method === 'GET' && p === '/v1/go-live') {
        return sendJson(res, 200, { ok: true, ...getGoLive(STATE_DIR) });
      }
      if (req.method === 'POST' && p === '/v1/go-live') {
        const body = await readBody(req);
        const rec = setGoLive(STATE_DIR, body.enabled === true, body.note,
          { contextId: body.contextId, revision: body.revision, faultInject: body.faultInject });
        return sendJson(res, 200, { ok: true, ...rec });
      }

      // ---- helpers for the notification workflow ---------------------------
      if (req.method === 'POST' && p === '/v1/derive-keys') {
        const body = await readBody(req);
        const contextKey = deriveContextKey(body);
        return sendJson(res, 200, { ok: true, contextKey, threadKey: deriveThreadKey(contextKey) });
      }

      return sendJson(res, 404, { ok: false, reason: 'not_found' });
    } catch (err) {
      return sendJson(res, 400, { ok: false, reason: 'bad_request', message: err?.message || 'error' });
    }
  });
}

// public view withholds token secrets but keeps routing fields needed to
// render the review card (from/to/subject) and the exact draft body.
function publicView(rec) {
  const { activeReviewToken, ...rest } = rec;
  const activeDraft = (rec.drafts || []).find((d) => d.revision === rec.activeDraftRevision) || null;
  return {
    ...rest,
    hasActiveToken: Boolean(activeReviewToken),
    activeDraft: activeDraft
      ? { revision: activeDraft.revision, body: activeDraft.body, bodyHash: activeDraft.bodyHash }
      : null,
  };
}

function redactCandidate(c) {
  const e = String(c.userEmail || '');
  const [u, d] = e.split('@');
  return {
    userName: c.userName ? `${String(c.userName).slice(0, 10)}***` : null,
    userEmail: c.userEmail ? (d ? `${u.slice(0, 3)}***@${d}` : '<redacted>') : '(absent)',
    displayName: c.displayName ? `${String(c.displayName).slice(0, 4)}***` : null,
    domainId: c.domainId ? `${String(c.domainId).slice(0, 4)}***` : null,
    space: c.space ? `${String(c.space).slice(0, 10)}***` : null,
    thread: c.thread ? `${String(c.thread).slice(0, 10)}***` : null,
    capturedAt: c.capturedAt,
  };
}

function redactBinding(b) {
  const s = String(b.email || '');
  const [u, d] = s.split('@');
  return {
    email: d ? `${u.slice(0, 2)}***@${d}` : '<redacted>',
    userResourceName: b.userResourceName ? `${String(b.userResourceName).slice(0, 10)}***` : null,
    domain: b.domain, space: b.space ? `${String(b.space).slice(0, 8)}***` : null,
    boundAt: b.boundAt, confirmedAt: b.confirmedAt,
  };
}

// Durable background reconciliation sweep. Survives restart: on each tick it
// scans persisted contexts still in RECONCILING, runs one rate-limited readback
// each, and escalates to MANUAL_RECONCILIATION_REQUIRED once the window expires.
// It NEVER issues a reply POST.
async function reconciliationSweep() {
  try {
    const dir = path.join(STATE_DIR, 'contexts');
    if (!fs.existsSync(dir)) return;
    for (const f of fs.readdirSync(dir)) {
      if (!/^[0-9a-f]{32}\.json$/.test(f)) continue;
      const id = f.slice(0, 32);
      const rec = readContext(STATE_DIR, id);
      if (!rec || rec.state !== SEND_STATES.RECONCILING) continue;
      if (INSTANTLY_API_KEY) {
        await reconcileOnce(STATE_DIR, id, { apiKey: INSTANTLY_API_KEY, apiBase: INSTANTLY_API_BASE, limiter: RECON_LIMITER, notify: postThreadStatus });
      }
      await expireReconciliation(STATE_DIR, id, { windowMs: 6 * 60 * 1000, notify: postThreadStatus });
    }
  } catch { /* never throw from the sweep */ }
}

if (process.argv[1] && process.argv[1].endsWith('server.mjs')) {
  const migration = INBOUND.migrateLegacyAcknowledgements();
  createServer().listen(PORT, HOST, () => {
    console.log(`hmz-reply-console listening on ${HOST}:${PORT}, inbound schema v2, legacy ack imported ${migration.importedAcknowledged}`);
  });
  setInterval(() => { reconciliationSweep(); }, 30_000).unref();
  setInterval(async () => {
    if (INBOUND_SWEEP_RUNNING) return;
    INBOUND_SWEEP_RUNNING = true;
    try { await INBOUND.drainOutbox({ limit: 25, maxBatches: 2 }); }
    catch { /* durable attempts and watchdog preserve the failure */ }
    finally { INBOUND_SWEEP_RUNNING = false; }
  }, 5_000).unref();
}
