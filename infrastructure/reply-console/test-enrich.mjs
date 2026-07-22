// Tests for prospect/sender name enrichment. Built-ins only.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert';
import * as E from './enrich.mjs';

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-enrich-'));
let pass = 0; const out = []; const tests = [];
const t = (n, f) => tests.push([n, f]);

// ---- prospect name from payload ----
t('prospect name from First_name/Last_name (webhook casing)', () => {
  const r = E.prospectNameFromPayload({ First_name: 'Ada', Last_name: 'Lovelace' });
  assert(r.name === 'Ada Lovelace' && r.source === 'WEBHOOK', JSON.stringify(r));
});
t('prospect first-only preserved', () => {
  assert.deepStrictEqual(E.prospectNameFromPayload({ First_name: 'Ada', Last_name: '' }), { name: 'Ada', source: 'WEBHOOK' });
});
t('prospect last-only preserved', () => {
  assert.deepStrictEqual(E.prospectNameFromPayload({ first_name: '', last_name: 'Lovelace' }), { name: 'Lovelace', source: 'WEBHOOK' });
});
t('prospect no name -> UNAVAILABLE', () => {
  assert.deepStrictEqual(E.prospectNameFromPayload({ email: 'a@b.com' }), { name: '', source: 'UNAVAILABLE' });
});
t('prospect never inferred from email local part', () => {
  const r = E.prospectNameFromPayload({ email: 'john.smith@corp.com', lead_email: 'john.smith@corp.com' });
  assert(r.name === '' && r.source === 'UNAVAILABLE', 'must not derive name from local part');
});
t('diacritics + punctuation preserved, case unchanged', () => {
  assert.strictEqual(E.normalizeName('José', "O'Néil"), "José O'Néil");
  assert.strictEqual(E.normalizeName('  van der  ', ' Berg '), 'van der Berg');
});
t('display strings', () => {
  assert.strictEqual(E.prospectDisplay('Ada Lovelace', 'ada@x.com'), 'Ada Lovelace <ada@x.com>');
  assert.strictEqual(E.prospectDisplay('', 'ada@x.com'), 'Name unavailable <ada@x.com>');
  assert.strictEqual(E.senderDisplay('', 'm@x.com'), 'Sender name not configured <m@x.com>');
});

// ---- sender name via account cache + mock API ----
t('resolveSenderName: API hit caches + returns display', async () => {
  let calls = 0;
  const mock = async (url) => { calls++; assert(url.includes('/accounts/'), url); return { status: 200, text: async () => JSON.stringify({ email: 'zah@onehmzautomations.com', first_name: 'Zahra', last_name: 'Khan', status: 1, timestamp_updated: 't1' }) }; };
  const r = await E.resolveSenderName(base, 'ZAH@onehmzautomations.com', { apiKey: 'K', fetchImpl: mock });
  assert(r.found && r.name === 'Zahra Khan' && r.eligible && r.source === 'API', JSON.stringify(r));
  assert(r.display === 'Zahra Khan <zah@onehmzautomations.com>');
  // second call served from fresh cache (no API)
  const r2 = await E.resolveSenderName(base, 'zah@onehmzautomations.com', { apiKey: 'K', fetchImpl: mock });
  assert(r2.source === 'CACHE' && calls === 1, 'served from cache, one API call: ' + calls);
});
t('resolveSenderName: 404 -> found:false, not eligible, display fallback', async () => {
  const mock = async () => ({ status: 404, text: async () => 'not found' });
  const r = await E.resolveSenderName(base, 'missing@x.com', { apiKey: 'K', fetchImpl: mock });
  assert(!r.found && !r.eligible && r.display === 'Sender name not configured <missing@x.com>', JSON.stringify(r));
});
t('resolveSenderName: empty first/last -> not-configured display, still found', async () => {
  const mock = async () => ({ status: 200, text: async () => JSON.stringify({ email: 'n@x.com', first_name: '', last_name: '', status: 1 }) });
  const r = await E.resolveSenderName(base, 'n@x.com', { apiKey: 'K', fetchImpl: mock });
  assert(r.found && r.name === '' && r.display === 'Sender name not configured <n@x.com>', JSON.stringify(r));
});
t('resolveSenderName: transient 500 falls back to stale cache', async () => {
  // seed cache
  const ok = async () => ({ status: 200, text: async () => JSON.stringify({ email: 's@x.com', first_name: 'Sam', last_name: 'Lee', status: 1 }) });
  await E.resolveSenderName(base, 's@x.com', { apiKey: 'K', fetchImpl: ok, forceRefresh: true });
  const fail = async () => ({ status: 500, text: async () => 'err' });
  const r = await E.resolveSenderName(base, 's@x.com', { apiKey: 'K', fetchImpl: fail, forceRefresh: true });
  assert(r.found && r.name === 'Sam Lee' && r.source === 'CACHE_STALE', JSON.stringify(r));
});
t('resolveSenderName: never uses operator/local-part name', async () => {
  const mock = async () => ({ status: 200, text: async () => JSON.stringify({ email: 'john.smith@x.com', first_name: '', last_name: '', status: 1 }) });
  const r = await E.resolveSenderName(base, 'john.smith@x.com', { apiKey: 'K', fetchImpl: mock });
  assert(!/john|smith/i.test(r.display.split('<')[0]), 'must not derive from local part');
});

// ---- prospect lookup fallback ----
t('lookup: single exact match -> name', async () => {
  const mock = async () => ({ status: 200, text: async () => JSON.stringify({ items: [{ email: 'a@b.com', payload: { First_name: 'Ann', Last_name: 'Bell' } }] }) });
  const r = await E.resolveProspectNameByLookup('a@b.com', 'camp1', { apiKey: 'K', fetchImpl: mock });
  assert(r.name === 'Ann Bell' && r.source === 'EMAIL_CAMPAIGN_LOOKUP', JSON.stringify(r));
});
t('lookup: multiple matches -> AMBIGUOUS, no arbitrary pick', async () => {
  const mock = async () => ({ status: 200, text: async () => JSON.stringify({ items: [{ email: 'a@b.com', payload: { First_name: 'A' } }, { email: 'a@b.com', payload: { First_name: 'B' } }] }) });
  const r = await E.resolveProspectNameByLookup('a@b.com', 'camp1', { apiKey: 'K', fetchImpl: mock });
  assert(r.name === '' && r.source === 'AMBIGUOUS', JSON.stringify(r));
});
t('lookup: no match -> UNAVAILABLE', async () => {
  const mock = async () => ({ status: 200, text: async () => JSON.stringify({ items: [] }) });
  const r = await E.resolveProspectNameByLookup('a@b.com', 'camp1', { apiKey: 'K', fetchImpl: mock });
  assert(r.source === 'UNAVAILABLE', JSON.stringify(r));
});

(async () => {
  for (const [n, f] of tests) { try { await f(); out.push('PASS  ' + n); pass++; } catch (e) { out.push('FAIL  ' + n + ' :: ' + e.message); } }
  for (const l of out) console.log(l);
  console.log(`\n${pass}/${out.length} enrichment tests passed`);
  fs.rmSync(base, { recursive: true, force: true });
  process.exit(pass === out.length ? 0 : 1);
})();
