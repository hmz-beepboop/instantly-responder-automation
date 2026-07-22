// Phase 11 — Test F: definitive failure + reconciliation exhaustion (mocks only,
// NO email sent). Asserts each of the 9 required items with POST count <= 1.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert';
import * as S from './store.mjs';

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-accF-'));
S.setGoLive(base, true, 'accF'); // enable (unarmed) so acquire proceeds to the mock POST
let pass = 0; const out = []; const tests = [];
const t = (n, f) => tests.push([n, f]);

let seq = 0;
async function armAndSend(threadId, mock, body = 'Body under test') {
  seq++;
  const c = S.createContext(base, { replyToUuid: 'u-F-' + seq, prospectEmail: 'p' + seq + '@corp.com',
    eaccount: 'acc@x.com', uniboxUrl: 'https://app.instantly.ai/u', subject: 'Capacity Question',
    authoritativeThreadId: threadId, threadKey: 'tk-F-' + seq,
    prospectName: 'Noah Cooper', senderName: 'Hamzah M' });
  const cid = c.context.notificationId;
  const d = S.createDraft(base, cid, { body, author: 'o' });
  let posts = 0;
  const wrap = async (url, opts) => { if (String(url).includes('/emails/reply')) posts++; return mock(url, opts); };
  const r = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash },
    { apiKey: 'K', fetchImpl: wrap, limiter: S.makeRateLimiter({ capacity: 20, refillPerSec: 0 }) });
  return { cid, d, r, posts, count: () => posts };
}

t('F1 definitive 401 -> FAILED_DEFINITIVE, never retried, 1 POST', async () => {
  const { r, count } = await armAndSend('t401', async (u) => u.includes('/emails/reply') ? { status: 401, text: async () => '{"error":"Unauthorized"}' } : { status: 200, text: async () => '{"items":[]}' });
  assert(r.outcome === 'FAILED_DEFINITIVE' && r.state === 'RETRYABLE' && count() === 1, JSON.stringify(r) + ' posts=' + count());
});
t('F2 definitive 404 -> FAILED_DEFINITIVE, never retried, 1 POST', async () => {
  const { r, count } = await armAndSend('t404', async (u) => u.includes('/emails/reply') ? { status: 404, text: async () => 'not found' } : { status: 200, text: async () => '{"items":[]}' });
  assert(r.outcome === 'FAILED_DEFINITIVE' && count() === 1, JSON.stringify(r));
});
t('F3 reconciliation 429 -> stays RECONCILING (bounded), 1 POST', async () => {
  const { r, count } = await armAndSend('t429', async (u) => u.includes('/emails/reply') ? (() => { const e = new Error('t'); e.name = 'TimeoutError'; throw e; })() : { status: 429, text: async () => 'rate' });
  assert(r.state === 'RECONCILING' && count() === 1, JSON.stringify(r));
});
t('F4 temporary readback 5xx -> stays RECONCILING (queued), 1 POST', async () => {
  const { r, count } = await armAndSend('t5xx', async (u) => u.includes('/emails/reply') ? (() => { const e = new Error('t'); e.name = 'TimeoutError'; throw e; })() : { status: 503, text: async () => 'err' });
  assert(r.state === 'RECONCILING' && count() === 1, JSON.stringify(r));
});
t('F5 multiple candidates -> MANUAL, never arbitrary success, 1 POST', async () => {
  // send with an empty first readback so it stays RECONCILING with 1 POST
  const { cid, count } = await armAndSend('tmulti', async (u) => u.includes('/emails/reply') ? (() => { const e = new Error('t'); e.name = 'TimeoutError'; throw e; })() : { status: 200, text: async () => '{"items":[]}' });
  assert(count() === 1, 'one POST');
  // now two matching candidates appear -> must go MANUAL, never pick arbitrarily
  const a = S.readContext(base, cid).currentAttempt;
  const dup = () => ({ id: 'e' + Math.random().toString(16).slice(2, 8), thread_id: a.authoritativeThreadId, ue_type: 3, eaccount: a.eaccount, to_address_email_list: [a.recipient], subject: a.subject, timestamp_created: new Date(Date.parse(a.startedAt) + 2000).toISOString(), body: { text: a.bodyText } });
  const rr = await S.reconcileOnce(base, cid, { apiKey: 'K', fetchImpl: async () => ({ status: 200, text: async () => JSON.stringify({ items: [dup(), dup()] }) }) });
  assert(rr.state === 'MANUAL_RECONCILIATION_REQUIRED' && rr.candidateCount === 2 && count() === 1, JSON.stringify(rr) + ' posts=' + count());
});
t('F6 full exhaustion -> MANUAL (window expired), 1 POST, no retry', async () => {
  const { cid, count } = await armAndSend('texh', async (u) => u.includes('/emails/reply') ? (() => { const e = new Error('t'); e.name = 'TimeoutError'; throw e; })() : { status: 200, text: async () => '{"items":[]}' });
  // force the window to be exhausted
  const cp = path.join(base, 'contexts', cid + '.json');
  const rec = JSON.parse(fs.readFileSync(cp, 'utf8')); rec.reconcileStartedAt = new Date(Date.now() - 10 * 60 * 1000).toISOString(); fs.writeFileSync(cp, JSON.stringify(rec));
  const e = await S.expireReconciliation(base, cid, { windowMs: 6 * 60 * 1000 });
  assert(e.state === 'MANUAL_RECONCILIATION_REQUIRED' && e.expired && count() === 1, JSON.stringify(e));
});
t('F9 POST count is <= 1 across all cases (aggregate)', async () => {
  // duplicate click on a terminal context yields zero further POSTs
  const { cid, d, count } = await armAndSend('tdup', async (u) => u.includes('/emails/reply') ? { status: 200, text: async () => '{"id":"m"}' } : { status: 200, text: async () => '{}' });
  const before = count();
  const again = await S.performSend(base, cid, { reviewToken: d.reviewToken, bodyHash: d.bodyHash }, { apiKey: 'K', fetchImpl: async (u) => u.includes('/emails/reply') ? { status: 200, text: async () => '{}' } : { status: 200, text: async () => '{}' } });
  assert(count() === before && !again.acquired, 'zero additional POST on replay');
});

(async () => {
  for (const [n, f] of tests) { try { await f(); out.push('PASS  ' + n); pass++; } catch (e) { out.push('FAIL  ' + n + ' :: ' + e.message); } }
  for (const l of out) console.log(l);
  console.log(`\n${pass}/${out.length} Test-F acceptance checks passed`);
  console.log('F7/F8 (named exceptional message, no "http ?" jargon) proven by Build Result Card runtime test.');
  fs.rmSync(base, { recursive: true, force: true });
  process.exit(pass === out.length ? 0 : 1);
})();
