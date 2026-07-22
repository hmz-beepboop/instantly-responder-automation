// Explicit-range canonical backfill regression tests.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { runBackfill } from './backfill.mjs';
import { getInbound, getNotification, OUTBOX_STATES, closeInboundStore } from './inbound-store.mjs';

let serial = 0, pass = 0;
const output = [];
async function test(name, fn) {
  try { await fn(); pass++; output.push(`PASS  ${name}`); }
  catch (error) { output.push(`FAIL  ${name} :: ${error.stack || error}`); }
}
function temp(prefix) { return fs.mkdtempSync(path.join(os.tmpdir(), prefix)); }
function item(overrides = {}) {
  serial++;
  return { id: `bf-${serial}`, ue_type: 2, eaccount: 'sender@x.test', from_address_email: `lead-${serial}@corp.test`,
    campaign_id: 'c1', lead_id: `l${serial}`, thread_id: `t${serial}`, message_id: `<m${serial}@corp.test>`,
    timestamp_created: '2026-07-10T00:00:00.000Z', subject: 'Re: Q', content_preview: 'Reply', ...overrides };
}
function api(items, status = 200) {
  return async (url) => {
    if (url.includes('/emails?')) return { status, text: async () => JSON.stringify(status === 200 ? { items } : {}) };
    if (url.includes('/accounts/')) return { status: 200, text: async () => JSON.stringify({ email: 'sender@x.test', first_name: 'HMZ', status: 1 }) };
    if (url.includes('/leads/list')) return { status: 200, text: async () => JSON.stringify({ items: [] }) };
    return { status: 404, text: async () => '{}' };
  };
}
const range = { since: '2026-07-01T00:00:00Z', until: '2026-07-20T00:00:00Z', apiKey: 'K' };

await test('requires an explicit bounded range', async () => {
  const result = await runBackfill({ stateDir: temp('bf-range-'), apiKey: 'K' });
  assert.equal(result.reason, 'MISSING_RANGE');
});

await test('dry-run reports every received category and creates no state file', async () => {
  const dir = temp('bf-dry-');
  const records = [item(), item({ from_address_email: 'mailer-daemon@corp.test' }), item({ id: '', eaccount: '', from_address_email: '' })];
  const result = await runBackfill({ ...range, stateDir: dir, fetchImpl: api(records) });
  assert.equal(result.ok, true);
  assert.equal(result.dryRun, true);
  assert.equal(result.instantlyReceivedObserved, 3);
  assert.equal(result.missing, 3);
  assert.equal(fs.existsSync(path.join(dir, 'inbound-v2.sqlite')), false);
  assert.equal(fs.existsSync(path.join(dir, 'inbound-hwm.json')), false);
  fs.rmSync(dir, { recursive: true, force: true });
});

await test('--apply notifies ordinary, bounce/system and malformed/surrogate records', async () => {
  const dir = temp('bf-apply-');
  const records = [item({ id: 'bf-ordinary' }), item({ id: 'bf-bounce', from_address_email: 'postmaster@corp.test' }),
    item({ id: '', eaccount: '', from_address_email: '', message_id: '<bf-surrogate@corp.test>' })];
  let posts = 0;
  const chat = async () => ({ status: 200, text: async () => JSON.stringify({ name: `spaces/S/messages/${++posts}` }) });
  const result = await runBackfill({ ...range, stateDir: dir, fetchImpl: api(records), apply: true,
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat, allowMockChatUrl: true });
  assert.equal(result.created, 3);
  assert.equal(result.bounceSystemRecovered, 1);
  assert.ok(result.malformedRecovered >= 1);
  assert.equal(result.drain.notified, 3);
  assert.equal(posts, 3);
  assert.equal(getNotification(dir, 'bf-ordinary').state, OUTBOX_STATES.NOTIFIED);
  assert.equal(getNotification(dir, 'bf-bounce').state, OUTBOX_STATES.NOTIFIED);
  assert.equal(getInbound(dir, 'bf-bounce').sendAllowed, false);
  const rerun = await runBackfill({ ...range, stateDir: dir, fetchImpl: api(records), apply: true,
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat, allowMockChatUrl: true });
  assert.equal(rerun.created, 0);
  assert.equal(rerun.alreadyPresent, 3);
  assert.equal(posts, 3);
  assert.equal(fs.existsSync(path.join(dir, 'inbound-hwm.json')), false);
  closeInboundStore(dir); fs.rmSync(dir, { recursive: true, force: true });
});

await test('API failure is non-mutating and explicit', async () => {
  const dir = temp('bf-fail-');
  const result = await runBackfill({ ...range, stateDir: dir, fetchImpl: api([], 429) });
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'INSTANTLY_429');
  assert.equal(fs.existsSync(path.join(dir, 'inbound-v2.sqlite')), false);
  fs.rmSync(dir, { recursive: true, force: true });
});

await test('backfill module contains no prospect-send adapter', async () => {
  const source = fs.readFileSync(new URL('./backfill.mjs', import.meta.url), 'utf8')
    .split('\n').filter((line) => !line.trim().startsWith('//')).join('\n');
  assert.doesNotMatch(source, /performSend|acquireSend|emails\/reply/);
});

for (const line of output) console.log(line);
console.log(`\n${pass}/${output.length} backfill tests passed`);
if (pass !== output.length) process.exitCode = 1;
