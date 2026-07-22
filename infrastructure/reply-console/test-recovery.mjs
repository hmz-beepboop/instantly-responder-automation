// Compatibility-facade regression tests. The deeper v2 matrix lives in
// test-inbound-v2.mjs.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as R from './recovery.mjs';
import * as Legacy from './store.mjs';
import { getInbound, getNotification, OUTBOX_STATES, closeInboundStore } from './inbound-store.mjs';

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-recov-v2-'));
let serial = 0, pass = 0;
const output = [];
async function test(name, fn) {
  try { await fn(); pass++; output.push(`PASS  ${name}`); }
  catch (error) { output.push(`FAIL  ${name} :: ${error.stack || error}`); }
}
function email(overrides = {}) {
  serial++;
  return {
    id: `recover-${serial}`, ue_type: 2, eaccount: 'sender@x.test',
    from_address_email: `lead-${serial}@corp.test`, campaign_id: 'c1', lead_id: `l${serial}`,
    message_id: `<m${serial}@corp.test>`, thread_id: `t${serial}`, subject: 'Re: question',
    content_preview: 'Interested', timestamp_created: new Date().toISOString(), ...overrides,
  };
}
function api(items, status = 200) {
  return async (url) => {
    if (url.includes('/emails?')) return { status, text: async () => JSON.stringify(status === 200 ? { items } : {}) };
    if (url.includes('/accounts/')) return { status: 200, text: async () => JSON.stringify({ email: 'sender@x.test', first_name: 'Sam', status: 1 }) };
    if (url.includes('/leads/list')) return { status: 200, text: async () => JSON.stringify({ items: [] }) };
    return { status: 404, text: async () => '{}' };
  };
}
let posts = [];
const chat = async (_url, options) => {
  posts.push(JSON.parse(options.body));
  return { status: 200, text: async () => JSON.stringify({ name: `spaces/S/messages/${posts.length}`, thread: { name: 'spaces/S/threads/T' } }) };
};

await test('poll recovers and definitely acknowledges an ordinary received record', async () => {
  posts = [];
  const item = email();
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.ok, true);
  assert.equal(result.recovered, 1);
  assert.equal(posts.length, 1);
  assert.equal(getNotification(base, item.id).state, OUTBOX_STATES.NOTIFIED);
  assert.ok(Legacy.findByInstantlyEmailId(base, item.id), 'safe routing also creates legacy interactive context');
});

await test('poll replay deduplicates by canonical Instantly email id', async () => {
  posts = [];
  const item = email();
  await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]), notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  posts = [];
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]), notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.recovered, 0);
  assert.equal(result.alreadyPresent, 1);
  assert.equal(posts.length, 0);
});

await test('already-acknowledged legacy webhook context migrates without duplicate Chat post', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-recov-migrate-'));
  const item = email();
  const legacy = Legacy.createContext(dir, { replyToUuid: item.id, instantlyEmailId: item.id, eaccount: item.eaccount,
    prospectEmail: item.from_address_email, subject: item.subject, uniboxUrl: 'https://app.instantly.ai/app/unibox',
    receivedAt: item.timestamp_created, threadKey: 'legacy-thread', discoverySource: 'DISCOVERED_WEBHOOK' });
  Legacy.attachChatPost(dir, legacy.context.notificationId, { chatMessageName: 'spaces/S/messages/existing', chatStatus: 200 });
  posts = [];
  const result = await R.pollRecover(dir, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.recovered, 0);
  assert.equal(posts.length, 0);
  assert.equal(getNotification(dir, item.id).state, OUTBOX_STATES.NOTIFIED);
  closeInboundStore(dir); fs.rmSync(dir, { recursive: true, force: true });
});

await test('bounce/system rows are registered and individually notified', async () => {
  posts = [];
  const item = email({ id: 'recover-bounce', from_address_email: 'mailer-daemon@corp.test', subject: 'Delivery failed' });
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.recovered, 1);
  assert.match(posts[0].text, /Mail-System\/Bounce Notice/);
  assert.equal(getInbound(base, item.id).sendAllowed, false);
  assert.equal(getNotification(base, item.id).state, OUTBOX_STATES.NOTIFIED);
});

await test('malformed routing metadata still reaches CHAT_NOTIFIED with no Send context', async () => {
  posts = [];
  const item = email({ id: 'recover-malformed', eaccount: '', from_address_email: '' });
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.recovered, 1);
  assert.equal(getInbound(base, item.id).degradedMetadata, true);
  assert.equal(getInbound(base, item.id).sendAllowed, false);
  assert.equal(getNotification(base, item.id).state, OUTBOX_STATES.NOTIFIED);
  assert.match(posts[0].text, /Routing Incomplete/);
});

await test('missing Instantly id receives deterministic surrogate and notification', async () => {
  posts = [];
  const item = email({ id: '', message_id: '<surrogate-recovery@corp.test>' });
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.recovered, 1);
  assert.equal(posts.length, 1);
  const surrogate = result.reconciliation.surrogateIdentity;
  assert.equal(surrogate, 1);
});

await test('API error returns failure and does not advance cursor', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-recov-error-'));
  const result = await R.pollRecover(dir, { apiKey: 'K', fetchImpl: api([], 500) });
  assert.equal(result.ok, false);
  assert.equal(result.cursorAdvanced, false);
  assert.equal(R.getHighWaterMark(dir).ts, null);
  closeInboundStore(dir); fs.rmSync(dir, { recursive: true, force: true });
});

await test('successful pass persists overlapping timestamp cursor plus stable email identity', async () => {
  const item = email({ id: 'recover-cursor' });
  const result = await R.pollRecover(base, { apiKey: 'K', fetchImpl: api([item]),
    notifyUrl: 'https://mock.chat.test/hook', notifyFetch: chat });
  assert.equal(result.ok, true);
  const cursor = R.getHighWaterMark(base);
  assert.ok(cursor.ts);
  assert.equal(cursor.emailId, item.id);
});

for (const line of output) console.log(line);
console.log(`\n${pass}/${output.length} recovery compatibility tests passed`);
closeInboundStore(base);
fs.rmSync(base, { recursive: true, force: true });
if (pass !== output.length) process.exitCode = 1;

