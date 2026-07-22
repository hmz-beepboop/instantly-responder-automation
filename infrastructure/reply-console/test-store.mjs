// Local safety-logic tests for the reply-console store. Built-ins only.
// Run: node test-store.mjs   (uses a throwaway temp state dir)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert';
import crypto from 'node:crypto';
import * as S from './store.mjs';

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-test-'));
let pass = 0; const results = []; const tests = [];
function t(name, fn) { tests.push([name, fn]); }   // registered; run sequentially below

const ctxInput = {
  replyToUuid: 'uuid-abc-123', eaccount: 'sender@hmz.example',
  prospectEmail: 'Prospect@Corp.com', subject: 'Re: quick question',
  campaignId: 'camp-1', campaignName: 'Val Q3', uniboxUrl: 'https://app.instantly.ai/app/unibox?x=1',
  receivedAt: new Date().toISOString(), sourcePayloadHash: 'deadbeef',
};

let id, threadKey;

t('create context', () => {
  const r = S.createContext(base, ctxInput);
  assert(r.ok && r.created, 'created');
  id = r.context.notificationId; threadKey = r.context.threadKey;
  assert(/^[0-9a-f]{32}$/.test(id), 'opaque id');
  assert(r.context.state === 'PENDING');
});

t('duplicate event => no duplicate context', () => {
  const r = S.createContext(base, ctxInput);
  assert(r.ok && r.created === false, 'dedup created=false');
  assert(r.context.notificationId === id, 'same id');
});

t('resolve by thread key', () => {
  const rec = S.resolveByThreadKey(base, threadKey);
  assert(rec && rec.notificationId === id);
});

t('unknown thread => null', () => {
  assert(S.resolveByThreadKey(base, 'nope-thread') === null);
});

t('empty draft rejected', () => {
  const r = S.createDraft(base, id, { body: '   ', author: 'owner' });
  assert(!r.ok && r.reason === 'EMPTY_BODY');
});

let token1, hash1;
t('valid draft => review token', () => {
  const r = S.createDraft(base, id, { body: 'Hello, happy to help. Best, HMZ', author: 'owner' });
  assert(r.ok && r.reviewToken && r.revision === 1);
  token1 = r.reviewToken; hash1 = r.bodyHash;
});

t('validate ok with token+hash', () => {
  const r = S.validateReview(base, id, { reviewToken: token1, bodyHash: hash1 });
  assert(r.ok, JSON.stringify(r));
});

t('body tamper fails', () => {
  const r = S.validateReview(base, id, { reviewToken: token1, bodyHash: 'ffff' });
  assert(!r.ok && r.reason === 'BODY_TAMPERED');
});

t('wrong token fails', () => {
  const r = S.validateReview(base, id, { reviewToken: 'wrong', bodyHash: hash1 });
  assert(!r.ok && r.reason === 'TOKEN_MISMATCH');
});

let token2, hash2;
t('edit => new revision invalidates old token', () => {
  const r = S.createDraft(base, id, { body: 'Hello — revised reply. Best, HMZ', author: 'owner', reason: 'edit' });
  assert(r.ok && r.revision === 2);
  token2 = r.reviewToken; hash2 = r.bodyHash;
  const old = S.validateReview(base, id, { reviewToken: token1, bodyHash: hash1 });
  assert(!old.ok, 'old token must fail after edit');
});

// ---- owner authorisation (binding + bootstrap) ----
t('bootstrap: HUMAN owner email match -> captured, not authorized', () => {
  const r = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/999', userEmail: 'Humza@HmzAIautomation.com', space: 'spaces/X', displayName: 'Humza', domainId: 'dom1' });
  assert(!r.authorized && r.authzState === 'bootstrap_captured', JSON.stringify(r));
  const c = S.getCandidate(base);
  assert(c && c.userName === 'users/999' && c.userEmail === 'humza@hmzaiautomation.com', 'candidate normalised');
});
t('bootstrap: email mismatch -> denied, no capture', () => {
  const r = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/evil', userEmail: 'attacker@evil.com' });
  assert(!r.authorized && r.authzState === 'denied' && r.reason === 'email_mismatch', JSON.stringify(r));
});
t('bootstrap: non-human -> denied', () => {
  const r = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'BOT', userName: 'users/bot' });
  assert(!r.authorized && r.reason === 'not_human');
});
t('confirm binds candidate; then authorised only by stable user.name', () => {
  S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/999', userEmail: 'humza@hmzaiautomation.com', space: 'spaces/X' });
  const b = S.confirmOwner(base, {});
  assert(b.ok, JSON.stringify(b));
  const r = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/999', space: 'spaces/X' });
  assert(r.authorized && r.authzState === 'bound', JSON.stringify(r));
  const r2 = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/other', userEmail: 'humza@hmzaiautomation.com', space: 'spaces/X' });
  assert(!r2.authorized && r2.reason === 'user_not_bound_owner', JSON.stringify(r2));
  const r3 = S.authorizeIdentity(base, 'humza@hmzaiautomation.com', { userType: 'HUMAN', userName: 'users/999', space: 'spaces/WRONG' });
  assert(!r3.authorized && r3.reason === 'space_mismatch', JSON.stringify(r3));
  assert(S.getCandidate(base) === null, 'candidate cleared after binding');
});

t('stale (superseded) token rejected distinctly even while gate OFF', () => {
  const r = S.acquireSend(base, id, { reviewToken: token1, bodyHash: hash1 });
  assert(!r.acquired && r.reason === 'TOKEN_MISMATCH', r.reason);
});
t('default go-live OFF blocks acquire (valid token, no consume)', () => {
  const r = S.acquireSend(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(!r.acquired && r.reason === 'SEND_DISABLED_NOT_GO_LIVE', r.reason);
  const v = S.validateReview(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(v.ok, 'token preserved after blocked send');
  S.setGoLive(base, true, 'test-enable');   // enable for the remaining send-machinery tests
});

t('armed for a DIFFERENT context blocks send', () => {
  S.setGoLive(base, true, 'scoped-test', { contextId: 'someotherid', revision: 2 });
  const r = S.acquireSend(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(!r.acquired && r.reason === 'SEND_DISABLED_WRONG_CONTEXT', r.reason);
  // correctly armed for THIS context + revision -> allowed
  S.setGoLive(base, true, 'scoped-test', { contextId: id, revision: 2 });
  const ok = S.validateReview(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(ok.ok, 'still valid');
  // reset to enabled-unarmed so the remaining multi-context tests behave as before
  S.setGoLive(base, true, 'test-enable');
});
t('acquire send => authoritative routing, one lock', () => {
  const r = S.acquireSend(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(r.acquired, JSON.stringify(r));
  assert(r.routing.eaccount === 'sender@hmz.example', 'eaccount from server');
  assert(r.routing.reply_to_uuid === 'uuid-abc-123', 'reply uuid from server');
  assert(r.routing.body === 'Hello — revised reply. Best, HMZ', 'exact body');
});

t('duplicate send click => blocked, zero second acquire', () => {
  const r = S.acquireSend(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(!r.acquired, 'must not acquire twice');
  assert(['LOCK_ALREADY_HELD', 'STATE_CHANGED', 'TOKEN_USED', 'SEND_IN_PROGRESS'].includes(r.reason), r.reason);
});

t('finalize SENT_API_CONFIRMED terminal', () => {
  const r = S.finalizeSend(base, id, 'SENT_API_CONFIRMED', { instantlyMessageId: 'msg-1' });
  assert(r.ok && r.state === 'SENT_API_CONFIRMED');
  const rec = S.readContext(base, id);
  assert(S.isTerminal(rec.state));
});

t('no send after SENT_API_CONFIRMED', () => {
  const r = S.acquireSend(base, id, { reviewToken: token2, bodyHash: hash2 });
  assert(!r.acquired && ['ALREADY_SENT', 'NO_ACTIVE_DRAFT', 'STATE_CHANGED'].includes(r.reason), r.reason);
});

// ---- RECONCILING keeps lock (no auto re-POST) ----
t('RECONCILING keeps lock; no re-acquire', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-unc', prospectEmail: 'p2@corp.com', authoritativeThreadId: 'th-unc' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body: 'Body for reconciling', author: 'owner' });
  const acq = S.acquireSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash });
  assert(acq.acquired);
  // ambiguous transport result via performSend with a throwing fetch -> RECONCILING
  return; // superseded by performSend RECONCILING test below
});

// ---- cancel sends nothing ----
t('cancel invalidates tokens, sends nothing', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-cancel', prospectEmail: 'p3@corp.com' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body: 'to be cancelled', author: 'owner' });
  const can = S.cancel(base, cid);
  assert(can.ok && can.state === 'CANCELLED');
  const acq = S.acquireSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash });
  assert(!acq.acquired, 'cancelled cannot send');
});

// ---- expired token fails ----
t('expired draft token fails validate', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-exp', prospectEmail: 'p4@corp.com' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body: 'expiring', author: 'owner' });
  // force-expire the draft token by rewriting the record
  const cp = path.join(base, 'contexts', `${cid}.json`);
  const rec = JSON.parse(fs.readFileSync(cp, 'utf8'));
  rec.drafts[0].tokenExpiresAt = new Date(Date.now() - 1000).toISOString();
  fs.writeFileSync(cp, JSON.stringify(rec));
  const r = S.validateReview(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash });
  assert(!r.ok && r.reason === 'TOKEN_EXPIRED', r.reason);
});

// ---- expired context blocked ----
t('expired context blocks draft', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-ctxexp', prospectEmail: 'p5@corp.com' });
  const cid = c.context.notificationId;
  const cp = path.join(base, 'contexts', `${cid}.json`);
  const rec = JSON.parse(fs.readFileSync(cp, 'utf8'));
  rec.expiresAt = new Date(Date.now() - 1000).toISOString();
  fs.writeFileSync(cp, JSON.stringify(rec));
  const read = S.readContext(base, cid);
  assert(read.state === 'EXPIRED', 'auto-expired on read');
  const d = S.createDraft(base, cid, { body: 'x', author: 'owner' });
  assert(!d.ok, 'no draft on expired context');
});

t('malformed context id => null', () => {
  assert(S.readContext(base, 'not-a-valid-id') === null);
});

t('missing required field rejected', () => {
  const r = S.createContext(base, { eaccount: 'a@b.com' });
  assert(!r.ok && r.reason === 'INVALID_CONTEXT_INPUT');
});

t('supplied threadKey honoured + resolvable', () => {
  const tk = 'hmz-reply-supplied-999';
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-tk', prospectEmail: 'p6@corp.com', threadKey: tk });
  assert(c.ok && c.context.threadKey === tk, 'uses supplied threadKey');
  const rec = S.resolveByThreadKey(base, tk);
  assert(rec && rec.notificationId === c.context.notificationId, 'resolvable by supplied threadKey');
});

t('attachChatPost indexes by chat thread resource name', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-rn', prospectEmail: 'p7@corp.com', threadKey: 'hmz-reply-rn' });
  const cid = c.context.notificationId;
  const resourceName = 'spaces/AAA/threads/BBB';
  S.attachChatPost(base, cid, { chatMessageName: 'spaces/AAA/messages/CCC', chatThreadName: resourceName });
  const byRes = S.resolveByThreadKey(base, resourceName);   // Chat MESSAGE events carry the resource name
  assert(byRes && byRes.notificationId === cid, 'resolvable by chat thread resource name');
  const byKey = S.resolveByThreadKey(base, 'hmz-reply-rn');
  assert(byKey && byKey.notificationId === cid, 'still resolvable by client threadKey');
});

t('definitive-fail send -> RETRYABLE, audited, re-draftable; SENT never resettable', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-retry', prospectEmail: 'pr@corp.com' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body: 'attempt one', author: 'o' });
  const acq = S.acquireSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }); // go-live enabled-unarmed
  assert(acq.acquired, JSON.stringify(acq));
  S.finalizeSend(base, cid, 'FAILED_DEFINITIVE', { httpStatus: 400, detail: 'http_400' });
  const rec = S.readContext(base, cid);
  assert(rec.state === 'RETRYABLE', rec.state);
  assert(rec.sendAttempts.length === 1 && rec.sendAttempts[0].outcome === 'FAILED_DEFINITIVE', 'attempt audited');
  const d2 = S.createDraft(base, cid, { body: 'attempt two', author: 'o' });   // fresh draft + fresh token
  assert(d2.ok && d2.revision >= 2, 'RETRYABLE is re-draftable');
  const old = S.acquireSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash });
  assert(!old.acquired, 'old failed-attempt token cannot send');
  const r2 = S.resetContext(base, id);   // id is SENT_API_CONFIRMED -> never resettable
  assert(!r2.ok && r2.reason === 'NOT_RESETTABLE', JSON.stringify(r2));
});

// ---- multiline body preservation (no whitespace collapse) ----
t('createDraft preserves exact multiline body + hash', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-ml', prospectEmail: 'ml@corp.com' });
  const cid = c.context.notificationId;
  const bodyExact = 'Hey,\n\nHow are you?\n\nHamza';
  const d = S.createDraft(base, cid, { body: bodyExact, author: 'o' });
  const rec = S.readContext(base, cid);
  const draft = rec.drafts.find((x) => x.revision === d.revision);
  assert(draft.body === bodyExact, 'body stored byte-for-byte with newlines');

  const h = crypto.createHash('sha256').update(bodyExact).digest('hex');
  assert(draft.bodyHash === h && d.bodyHash === h, 'hash over exact canonical body');
});
t('toHtml escapes + maps each LF to <br>, preserves blank lines', () => {
  assert(S.toHtml('Hey,\n\nHow are you?\n\nHamza') === 'Hey,<br><br>How are you?<br><br>Hamza');
  assert(S.toHtml('<b>x</b> & "q"') === '&lt;b&gt;x&lt;/b&gt; &amp; &quot;q&quot;');
});

// ---- performSend + reconciliation fault-injection suite (Phase 9) ----
// A reusable harness: fresh context+draft, a counting mock fetch for both the
// reply POST and the /emails readback. Proves exactly-one POST in every case.
let seq = 0;
function freshDraft(threadId, body = 'Hi,\n\nThanks.\n\nHamza', subject = 'Capacity Question') {
  seq++;
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'u-ps-' + seq, prospectEmail: 'ps' + seq + '@corp.com', subject, authoritativeThreadId: threadId });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body, author: 'o' });
  return { cid, d, body, subject };
}
// Attempt shape derived from a context+draft (mirrors what acquireSend records),
// usable in matching tests that don't go through performSend.
function attemptOf(cid) {
  const rec = S.readContext(base, cid);
  if (rec.currentAttempt) return rec.currentAttempt;
  const draft = rec.drafts.find((x) => x.revision === rec.activeDraftRevision) || rec.drafts.at(-1);
  return { startedAt: new Date().toISOString(), reply_to_uuid: rec.replyToUuid, eaccount: rec.eaccount,
    recipient: rec.prospectEmail, subject: 'Re: ' + rec.subject, bodyHash: draft.bodyHash, bodyText: draft.body,
    authoritativeThreadId: rec.authoritativeThreadId };
}
// Build a readback email object that matches an attempt (thread+account+recipient+subject+ts+body).
function sentEmail(cid, body, subject, tsOffsetMs = 3000) {
  const at = attemptOf(cid);
  return { id: 'em-' + Math.random().toString(16).slice(2, 8), thread_id: at.authoritativeThreadId,
    ue_type: 3, eaccount: at.eaccount, to_address_email_list: [at.recipient], subject: 'Re: ' + subject,
    timestamp_created: new Date(Date.parse(at.startedAt) + tsOffsetMs).toISOString(),
    body: { text: body } };
}

t('FI-1 normal 2xx -> SENT_API_CONFIRMED, one POST', async () => {
  const { cid, d, body } = freshDraft('th1');
  let posts = 0; let seen = null;
  const mock = async (url, opts) => { if (url.includes('/emails/reply')) { posts++; seen = { url, opts }; return { status: 200, text: async () => JSON.stringify({ id: 'm1' }) }; } };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.ok && r.outcome === 'SENT_API_CONFIRMED' && posts === 1, JSON.stringify(r));
  assert(seen.opts.headers.Authorization === 'Bearer K', 'Bearer once');
  const sent = JSON.parse(seen.opts.body);
  assert(sent.body.text === body && sent.body.html === 'Hi,<br><br>Thanks.<br><br>Hamza');
  const r2 = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(!r2.ok && posts === 1, 'no second POST after confirmed');
});

t('FI-2 accepted but response dropped -> RECONCILING -> readback SENT_RECONCILED_READBACK, one POST', async () => {
  const { cid, d, body, subject } = freshDraft('th2');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; return { status: 200, text: async () => '{}' }; }
    // readback: the email exists (send really happened)
    return { status: 200, text: async () => JSON.stringify({ items: [sentEmail(cid, body, subject)] }) };
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash },
    { apiKey: 'K', fetchImpl: mock, faultInject: 'drop_response' });
  assert(r.state === 'SENT_RECONCILED_READBACK' && posts === 1, JSON.stringify(r) + ' posts=' + posts);
});

t('FI-3/4 timeout after accept -> RECONCILING -> reconciled, one POST', async () => {
  const { cid, d, body, subject } = freshDraft('th3');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; const e = new Error('t'); e.name = 'TimeoutError'; throw e; }
    return { status: 200, text: async () => JSON.stringify({ items: [sentEmail(cid, body, subject)] }) };
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.state === 'SENT_RECONCILED_READBACK' && posts === 1, JSON.stringify(r));
  const rec = S.readContext(base, cid);
  assert(rec.sendAttempts.some((a) => a.transportFault === 'ETIMEDOUT'), 'ETIMEDOUT recorded');
});

t('FI ambiguous + readback empty -> stays RECONCILING (no re-POST)', async () => {
  const { cid, d } = freshDraft('th4');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; const e = new Error('t'); e.name = 'TimeoutError'; throw e; }
    return { status: 200, text: async () => JSON.stringify({ items: [] }) };  // not indexed yet
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.state === 'RECONCILING' && posts === 1, JSON.stringify(r));
  // a later readback finds it -> reconciled, still zero extra POSTs
  const { cid: _c } = { cid };
  const later = async () => ({ status: 200, text: async () => JSON.stringify({ items: [sentEmail(cid, d ? 'Hi,\n\nThanks.\n\nHamza' : '', 'Capacity Question')] }) });
  const rr = await S.reconcileOnce(base, cid, { apiKey: 'K', fetchImpl: later });
  assert(rr.state === 'SENT_RECONCILED_READBACK' && posts === 1, JSON.stringify(rr));
});

t('FI readback 429 -> stays RECONCILING (retriable), no re-POST', async () => {
  const { cid, d } = freshDraft('th5');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; const e = new Error('t'); e.name = 'TimeoutError'; throw e; }
    return { status: 429, text: async () => 'rate limited' };
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.state === 'RECONCILING' && posts === 1, JSON.stringify(r));
});

t('FI candidate matching rejects wrong thread / body / account', () => {
  const { cid, body, subject } = freshDraft('th6');
  const at = attemptOf(cid);
  const good = sentEmail(cid, body, subject);
  assert(S.matchesAttempt(good, at), 'good matches');
  assert(!S.matchesAttempt({ ...good, thread_id: 'other' }, at), 'wrong thread');
  assert(!S.matchesAttempt({ ...good, body: { text: 'different body' } }, at), 'wrong body');
  assert(!S.matchesAttempt({ ...good, eaccount: 'other@x.com' }, at), 'wrong account');
  assert(!S.matchesAttempt({ ...good, ue_type: 2 }, at), 'not sent type');
  assert(!S.matchesAttempt({ ...good, timestamp_created: new Date(Date.parse(at.startedAt) - 60000).toISOString() }, at), 'before attempt');
});

t('FI multiple candidates -> MANUAL_RECONCILIATION_REQUIRED, lock held', async () => {
  const { cid, d, body, subject } = freshDraft('th7');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; const e = new Error('t'); e.name = 'TimeoutError'; throw e; }
    return { status: 200, text: async () => JSON.stringify({ items: [sentEmail(cid, body, subject, 2000), sentEmail(cid, body, subject, 4000)] }) };
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.state === 'MANUAL_RECONCILIATION_REQUIRED' && posts === 1, JSON.stringify(r));
});

t('FI HTML-derived body still matches (html-only readback)', () => {
  const { cid, body, subject } = freshDraft('th8');
  const at = attemptOf(cid);
  const htmlEmail = { id: 'e', thread_id: at.authoritativeThreadId, ue_type: 3, eaccount: at.eaccount,
    to_address_email_list: [at.recipient], subject: 'Re: ' + subject,
    timestamp_created: new Date(Date.parse(at.startedAt) + 3000).toISOString(),
    body: { html: S.toHtml(body) } };
  assert(S.matchesAttempt(htmlEmail, at), 'html-derived text hash matches');
});

t('FI wrapped-html readback (Instantly full-document body) still matches', () => {
  const { cid, body, subject } = freshDraft('thwrap', 'This is a controlled reconciliation acceptance test.\n\nNo action needed.');
  const at = attemptOf(cid);
  // Instantly wraps the sent html in a full document + whitespace (real behaviour)
  const wrapped = '<!DOCTYPE html>\n<html>\n  <head>\n    <meta charset="UTF-8">\n    <title>Re: ' + subject + '</title>\n  </head>\n  <body>\n  This is a controlled reconciliation acceptance test. <br><br>No action needed.</body>\n</html>';
  const email = { id: 'ew', thread_id: at.authoritativeThreadId, ue_type: 3, eaccount: at.eaccount,
    to_address_email_list: [at.recipient], subject: 'Re: ' + subject,
    timestamp_created: new Date(Date.parse(at.startedAt) + 2000).toISOString(), body: { html: wrapped } };
  assert(S.matchesAttempt(email, at), 'structural match survives Instantly html wrapping');
  // and a DIFFERENT body in the same wrapper must NOT match
  const wrong = { ...email, body: { html: wrapped.replace('acceptance test', 'totally different message') } };
  assert(!S.matchesAttempt(wrong, at), 'different body rejected');
});
t('FI rate limiter: token bucket depletes and blocks', () => {
  let t = 0; const lim = S.makeRateLimiter({ capacity: 2, refillPerSec: 0, now: () => t });
  assert(lim.tryTake() && lim.tryTake() && !lim.tryTake(), 'two then blocked');
});

t('FI two simultaneous send calls -> exactly one POST', async () => {
  const { cid, d, body, subject } = freshDraft('th9');
  let posts = 0;
  const mock = async (url) => { if (url.includes('/emails/reply')) { posts++; return { status: 200, text: async () => '{"id":"m"}' }; } return { status: 200, text: async () => JSON.stringify({ items: [sentEmail(cid, body, subject)] }) }; };
  const [a, b] = await Promise.all([
    S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock }),
    S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock }),
  ]);
  assert(posts === 1, 'exactly one POST under concurrency; got ' + posts);
  const okOne = [a, b].filter((x) => x.state && x.state.startsWith('SENT')).length >= 1;
  assert(okOne, 'at least one reports sent/reconciled');
});

t('FI-6/7 email_sent webhook reconciles an open RECONCILING attempt', async () => {
  const { cid, d, body, subject } = freshDraft('thw');
  let posts = 0;
  const mock = async (url) => {
    if (url.includes('/emails/reply')) { posts++; const e = new Error('t'); e.name = 'TimeoutError'; throw e; }
    return { status: 200, text: async () => JSON.stringify({ items: [] }) };  // readback empty
  };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r.state === 'RECONCILING' && posts === 1, JSON.stringify(r));
  const at = attemptOf(cid);
  // email_sent event arrives for this exact send
  const evt = { eaccount: at.eaccount, thread_id: at.authoritativeThreadId, email_id: 'emx',
    to_address_email_list: [at.recipient], subject: 'Re: ' + subject,
    timestamp: new Date(Date.parse(at.startedAt) + 2000).toISOString(), email_text: body };
  const w = await S.reconcileEmailSent(base, evt);
  assert(w.matched && w.contextId === cid && w.state === 'SENT_RECONCILED_WEBHOOK', JSON.stringify(w));
  // a duplicate email_sent must NOT reopen it
  const w2 = await S.reconcileEmailSent(base, evt);
  assert(!w2.matched, 'duplicate webhook does not reopen');
});
t('FI-12/13/15 unrelated / wrong-thread / wrong-account email_sent ignored', async () => {
  const { cid, d, body, subject } = freshDraft('thw2');
  const mock = async (url) => { if (url.includes('/emails/reply')) { const e = new Error('t'); e.name = 'TimeoutError'; throw e; } return { status: 200, text: async () => JSON.stringify({ items: [] }) }; };
  await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  const at = attemptOf(cid);
  assert(!(await S.reconcileEmailSent(base, { eaccount: at.eaccount, thread_id: 'other-thread', to_address_email_list: [at.recipient], subject: 'Re: ' + subject, timestamp: new Date(Date.parse(at.startedAt) + 2000).toISOString(), email_text: body })).matched, 'wrong thread ignored');
  assert(!(await S.reconcileEmailSent(base, { eaccount: 'someone@else.com', thread_id: at.authoritativeThreadId, to_address_email_list: ['x@y.com'], subject: 'Re: other', timestamp: new Date().toISOString(), email_text: 'unrelated' })).matched, 'unrelated ignored');
  assert(S.readContext(base, cid).state === 'RECONCILING', 'still reconciling after non-matches');
});

t('FI expireReconciliation escalates to MANUAL after window', () => {
  const { cid, d } = freshDraft('th10');
  // force RECONCILING with an old reconcileStartedAt
  const mockThrow = async () => { const e = new Error('t'); e.name = 'TimeoutError'; throw e; };
  return (async () => {
    await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: mockThrow, syncReadback: false });
    const cp = base + '/contexts/' + cid + '.json';
    const rec = JSON.parse(fs.readFileSync(cp, 'utf8')); rec.reconcileStartedAt = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    fs.writeFileSync(cp, JSON.stringify(rec));
    const e = await S.expireReconciliation(base, cid, { windowMs: 6 * 60 * 1000 });
    assert(e.state === 'MANUAL_RECONCILIATION_REQUIRED' && e.expired, JSON.stringify(e));
  })();
});

// ---- Edit-flow repair: mutation-free open, atomic edit, stale-card recovery ----
t('createDraft is atomic: new revision + new token committed together', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-edit1', prospectEmail: 'e1@corp.com' });
  const cid = c.context.notificationId;
  const d1 = S.createDraft(base, cid, { body: 'rev one', author: 'o' });
  const d2 = S.createDraft(base, cid, { body: 'rev two', author: 'o', reason: 'edit' });
  const rec = S.readContext(base, cid);
  assert(rec.activeDraftRevision === 2 && rec.drafts.length === 2, 'two revisions');
  assert(rec.drafts[0].superseded === true && rec.drafts[1].superseded === false, 'old superseded, new latest');
  // old token stale only AFTER new committed
  const oldv = S.validateReview(base, cid, { reviewToken: d1.reviewToken, bodyHash: d1.bodyHash });
  assert(!oldv.ok && oldv.reason === 'NO_ACTIVE_DRAFT' || oldv.reason === 'TOKEN_MISMATCH', JSON.stringify(oldv));
  const newv = S.validateReview(base, cid, { reviewToken: d2.reviewToken, bodyHash: d2.bodyHash });
  assert(newv.ok, 'new token valid');
});
t('stale-card Send -> STALE_CARD recovery with fresh token, zero POST', async () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-stale', prospectEmail: 'st@corp.com', subject: 'Q', authoritativeThreadId: 'th-st' });
  const cid = c.context.notificationId;
  const d1 = S.createDraft(base, cid, { body: 'first', author: 'o' });
  const d2 = S.createDraft(base, cid, { body: 'second (latest)', author: 'o', reason: 'edit' });
  let posts = 0;
  const mock = async (u) => { if (String(u).includes('/emails/reply')) posts++; return { status: 200, text: async () => '{}' }; };
  // Send with the STALE (revision-1) token
  const r = await S.performSend(base, cid, { reviewToken: d1.reviewToken, bodyHash: d1.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(!r.ok && r.reason === 'STALE_CARD' && r.staleRecovery && r.staleRecovery.revision === 2, JSON.stringify({ reason: r.reason, rev: r.staleRecovery && r.staleRecovery.revision }));
  assert(r.staleRecovery.body === 'second (latest)', 'recovery shows latest body');
  assert(posts === 0, 'zero POSTs on stale-card send');
  // the fresh recovery token can then send the latest (when armed)
  const r2 = await S.performSend(base, cid, { reviewToken: r.staleRecovery.reviewToken, bodyHash: r.staleRecovery.bodyHash }, { apiKey: 'K', fetchImpl: mock });
  assert(r2.ok && r2.outcome === 'SENT_API_CONFIRMED' && posts === 1, JSON.stringify(r2) + ' posts=' + posts);
});
t('refreshLatestCard: no revision created, rotates token, preserves body', () => {
  const c = S.createContext(base, { ...ctxInput, replyToUuid: 'uuid-refr', prospectEmail: 'rf@corp.com' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body: 'hello\n\nworld', author: 'o' });
  const before = S.readContext(base, cid).drafts.length;
  const r = S.refreshLatestCard(base, cid);
  const after = S.readContext(base, cid).drafts.length;
  assert(r.ok && after === before, 'no new revision');
  assert(r.body === 'hello\n\nworld', 'exact body preserved');
  assert(r.reviewToken && r.reviewToken !== d.reviewToken, 'fresh token issued');
  // old token no longer valid; new token valid
  assert(!S.validateReview(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }).ok, 'old token stale');
  assert(S.validateReview(base, cid, { reviewToken: r.reviewToken, bodyHash: r.bodyHash }).ok, 'new token valid');
});


(async () => {
  for (const [name, fn] of tests) {
    try { await fn(); results.push(['PASS', name]); pass++; }
    catch (e) { results.push(['FAIL', name + ' :: ' + e.message]); }
  }
  for (const [st, name] of results) console.log(`${st}  ${name}`);
  console.log(`\n${pass}/${results.length} store tests passed`);
  fs.rmSync(base, { recursive: true, force: true });
  process.exit(pass === results.length ? 0 : 1);
})();
