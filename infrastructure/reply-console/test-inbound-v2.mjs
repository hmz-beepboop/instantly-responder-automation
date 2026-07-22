// Permanent deterministic regression matrix for the canonical received-email
// contract, transactional outbox, retries, leases, pagination and auditor.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  normalizeInstantlyReceived, buildNotificationText, LABELS, IDENTITY_KINDS,
} from './inbound-contract.mjs';
import {
  OUTBOX_STATES, registerInbound, getInbound, getNotification, listAttempts,
  integrityCheck, claimNotifications, beginNotificationAttempt,
  releaseExpiredNotificationLeases, closeInboundStore, operationsSnapshot,
  getPollState, requeueUnacknowledged, watchdogFacts,
} from './inbound-store.mjs';
import { createInboundService, fetchInstantlyReceivedRange } from './inbound-service.mjs';
import { createContext, attachChatPost } from './store.mjs';

let passed = 0;
const results = [];
async function test(name, fn) {
  try { await fn(); passed++; results.push(`PASS  ${name}`); }
  catch (error) { results.push(`FAIL  ${name} :: ${error.stack || error}`); }
}
function temp(prefix) { return fs.mkdtempSync(path.join(os.tmpdir(), prefix)); }
function cleanup(dir) { try { closeInboundStore(dir); } catch {} fs.rmSync(dir, { recursive: true, force: true }); }
function response(status, body) { return new Response(body === undefined ? '' : JSON.stringify(body), { status }); }

let serial = 0;
function received(overrides = {}) {
  serial++;
  return {
    id: `email-${serial}`,
    ue_type: 2,
    eaccount: 'sender@hmz.test',
    from_address_email: `prospect-${serial}@example.test`,
    First_name: 'Test',
    Last_name: `Prospect${serial}`,
    campaign_id: 'campaign-1',
    campaign_name: 'Validation',
    lead_id: `lead-${serial}`,
    thread_id: `thread-${serial}`,
    message_id: `<message-${serial}@example.test>`,
    subject: 'Re: Capacity question',
    content_preview: 'Interested — can you share details?',
    timestamp_created: new Date(Date.UTC(2026, 6, 21, 0, 0, serial % 60, serial)).toISOString(),
    ...overrides,
  };
}

const matrix = [
  ['ordinary positive', { content_preview: 'Yes, interested.' }, LABELS.ORDINARY, true],
  ['ordinary negative', { content_preview: 'No thanks.' }, LABELS.ORDINARY, true],
  ['neutral', { content_preview: 'Thanks for the note.' }, LABELS.ORDINARY, true],
  ['question', { content_preview: 'How does this work?' }, LABELS.ORDINARY, true],
  ['unsubscribe', { content_preview: 'Please unsubscribe me.' }, LABELS.UNSUBSCRIBE, false],
  ['automatic', { subject: 'Automatic reply: received', is_auto_reply: 1 }, LABELS.AUTOMATIC, false],
  ['out of office', { subject: 'Out of office', content_preview: 'I am away from the office.' }, LABELS.OOO, false],
  ['bounce', { subject: 'Delivery failed: mailbox unavailable' }, LABELS.BOUNCE, false],
  ['mailer daemon', { from_address_email: 'mailer-daemon@example.test', subject: 'Returned mail' }, LABELS.SYSTEM, false],
  ['postmaster', { from_address_email: 'postmaster@example.test', subject: 'Notice' }, LABELS.SYSTEM, false],
  ['delivery status', { subject: 'Delivery Status Notification' }, LABELS.BOUNCE, false],
  ['empty', { subject: '', content_preview: '' }, LABELS.EMPTY, true],
  ['attachment only', { subject: '', content_preview: '', attachments: [{ name: 'document.pdf' }] }, LABELS.ATTACHMENT_ONLY, true],
  ['missing name', { First_name: '', Last_name: '' }, LABELS.ORDINARY, true],
  ['missing prospect email', { from_address_email: '' }, LABELS.ORDINARY, false],
  ['missing mailbox', { eaccount: '' }, LABELS.ORDINARY, false],
  ['missing campaign', { campaign_id: '', campaign_name: '' }, LABELS.ORDINARY, true],
  ['missing lead', { lead_id: '' }, LABELS.ORDINARY, true],
  ['missing thread', { thread_id: '' }, LABELS.ORDINARY, true],
  ['missing message id', { message_id: '' }, LABELS.ORDINARY, true],
  ['missing Instantly email id', { id: '' }, LABELS.ORDINARY, false],
  ['invalid timestamp', { timestamp_created: 'not-a-timestamp' }, LABELS.ORDINARY, true],
  ['unexpected fields', { subject: { poisoned: true }, content_preview: ['not', 'text'] }, LABELS.ORDINARY, true],
  ['malformed Unicode', { subject: 'bad\uD800subject', content_preview: 'bad\uDC00body' }, LABELS.ORDINARY, true],
  ['oversized valid values', { subject: 's'.repeat(5000), content_preview: 'b'.repeat(20000) }, LABELS.ORDINARY, true],
  ['unknown sparse type', { eaccount: '', from_address_email: '', subject: '', content_preview: '', campaign_id: '', lead_id: '', thread_id: '', message_id: '' }, LABELS.MALFORMED, false],
];

await test('all 26 received categories persist one inbound + one outbox and reach CHAT_NOTIFIED', async () => {
  const dir = temp('hmz-v2-matrix-');
  const posts = [];
  const service = createInboundService({
    stateDir: dir,
    notifyUrl: 'https://mock.chat.test/hook',
    allowMockChatUrl: true,
    chatFetch: async (_url, options) => {
      const body = JSON.parse(options.body); posts.push(body);
      const n = posts.length;
      return response(200, { name: `spaces/S/messages/${n}`, thread: { name: `spaces/S/threads/${n}` } });
    },
  });
  const identities = [];
  for (const [name, changes, classification, expectedSendAllowed] of matrix) {
    const raw = received(changes);
    const normalized = normalizeInstantlyReceived(raw, { authoritativeReceived: true, discoverySource: 'TEST_MATRIX' });
    assert.equal(normalized.ok, true, name);
    assert.equal(normalized.notificationRequired, true, `${name}: notification required`);
    assert.equal(normalized.record.classification, classification, name);
    assert.equal(normalized.record.sendAllowed, expectedSendAllowed, `${name}: Send capability`);
    if (!raw.id) assert.equal(normalized.record.identityKind, IDENTITY_KINDS.SURROGATE, name);
    const registered = await service.registerReceived(raw, {
      authoritativeReceived: true, discoverySource: 'TEST_MATRIX', createLegacy: false,
    });
    assert.equal(registered.created, true, name);
    identities.push(registered.record.identity);
  }
  const drain = await service.drainOutbox({ limit: 100, maxBatches: 2 });
  assert.equal(drain.notified, matrix.length);
  assert.equal(posts.length, matrix.length);
  for (const identity of identities) {
    assert.ok(getInbound(dir, identity));
    const outbox = getNotification(dir, identity);
    assert.equal(outbox.state, OUTBOX_STATES.NOTIFIED);
    assert.equal(listAttempts(dir, outbox.notificationId).length, 1);
  }
  assert.equal(integrityCheck(dir).ok, true);
  const operations = operationsSnapshot(dir);
  assert.equal(operations.counts.durable_inbound_present, matrix.length);
  assert.equal(operations.counts.outbox_missing, 0);
  assert.equal(operations.counts.posting, 0);
  assert.equal(typeof operations.backlogDrainRate.perSecond, 'number');
  cleanup(dir);
});

await test('bounce/system and degraded records receive explicit labels with no Send hint', async () => {
  const bounce = normalizeInstantlyReceived(received({ from_address_email: 'mailer-daemon@example.test' }),
    { authoritativeReceived: true, discoverySource: 'TEST' }).record;
  const bounceText = buildNotificationText(bounce);
  assert.match(bounceText, /Mail-System\/Bounce Notice/);
  assert.doesNotMatch(bounceText, /mention @Instantly/);
  const malformed = normalizeInstantlyReceived(received({ eaccount: '', from_address_email: '' }),
    { authoritativeReceived: true, discoverySource: 'TEST' }).record;
  const malformedText = buildNotificationText(malformed);
  assert.match(malformedText, /Routing Incomplete/);
  assert.match(malformedText, /still registered and notified/);
  assert.doesNotMatch(malformedText, /mention @Instantly/);
});

await test('1000 simultaneous duplicate discoveries yield one logical inbound and one outbox', async () => {
  const dir = temp('hmz-v2-concurrent-');
  const raw = received({ id: 'same-id-1000' });
  const service = createInboundService({ stateDir: dir });
  const results1000 = await Promise.all(Array.from({ length: 1000 }, () => service.registerReceived(raw, {
    authoritativeReceived: true, discoverySource: 'RACE', createLegacy: false,
  })));
  assert.equal(results1000.filter((item) => item.created).length, 1);
  assert.equal(operationsSnapshot(dir).counts.durable_inbound_present, 1);
  assert.equal(operationsSnapshot(dir).counts.outbox_present, 1);
  assert.equal(integrityCheck(dir).ok, true);
  cleanup(dir);
});

await test('expired worker lease is preserved as ambiguous attempt and safely reclaimed', async () => {
  const dir = temp('hmz-v2-lease-');
  const record = normalizeInstantlyReceived(received(), { authoritativeReceived: true, discoverySource: 'TEST' }).record;
  registerInbound(dir, record, { now: 1_000_000 });
  const first = claimNotifications(dir, 'worker-a', { now: 1_000_000, leaseMs: 100 });
  assert.equal(first.length, 1);
  const attempt = beginNotificationAttempt(dir, first[0].outbox.notificationId, 'worker-a', { now: 1_000_000 });
  assert.equal(attempt.ok, true);
  assert.equal(releaseExpiredNotificationLeases(dir, { now: 1_000_101 }), 1);
  const after = getNotification(dir, record.identity);
  assert.equal(after.state, OUTBOX_STATES.AMBIGUOUS);
  const history = listAttempts(dir, after.notificationId);
  assert.equal(history[0].outcome, 'AMBIGUOUS');
  assert.equal(history[0].error_kind, 'WORKER_LEASE_EXPIRED');
  assert.equal(claimNotifications(dir, 'worker-b', { now: 1_000_102 }).length, 1);
  cleanup(dir);
});

await test('auditor requeue cannot steal an active notification worker lease', async () => {
  const dir = temp('hmz-v2-audit-worker-race-');
  const normalized = normalizeInstantlyReceived(received(), {
    authoritativeReceived: true, discoverySource: 'COMPLETENESS_AUDIT',
  });
  const registered = registerInbound(dir, normalized.record, { now: 1_000_000 });
  const claimed = claimNotifications(dir, 'worker-a', { now: 1_000_000, leaseMs: 60_000 });
  assert.equal(claimed.length, 1);
  assert.equal(beginNotificationAttempt(dir, registered.outbox.notificationId, 'worker-a', { now: 1_000_001 }).ok, true);

  assert.equal(requeueUnacknowledged(dir, [registered.record.identity], { now: 1_000_002 }), 0);
  const duringPost = getNotification(dir, registered.record.identity);
  assert.equal(duringPost.state, OUTBOX_STATES.POSTING);
  assert.equal(duringPost.leaseOwner, 'worker-a');
  assert.equal(listAttempts(dir, duringPost.notificationId)[0].finished_at, null);
  cleanup(dir);
});

await test('response loss retries in deterministic thread and records probable duplicate before definite acknowledgement', async () => {
  const dir = temp('hmz-v2-ambiguous-');
  let clock = Date.parse('2026-07-21T00:00:00Z');
  let calls = 0;
  const bodies = [];
  const service = createInboundService({ stateDir: dir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    now: () => clock,
    chatFetch: async (_url, options) => {
      bodies.push(JSON.parse(options.body)); calls++;
      if (calls === 1) throw new Error('response lost after submission');
      return response(200, { name: 'spaces/S/messages/recovered', thread: { name: 'spaces/S/threads/T' } });
    } });
  const registered = await service.registerReceived(received(), { authoritativeReceived: true, createLegacy: false });
  let drain = await service.drainOutbox();
  assert.equal(drain.ambiguous, 1);
  assert.equal(getNotification(dir, registered.record.identity).state, OUTBOX_STATES.AMBIGUOUS);
  clock += 31 * 60_000;
  drain = await service.drainOutbox();
  assert.equal(drain.notified, 1);
  assert.equal(bodies[0].thread.threadKey, bodies[1].thread.threadKey);
  assert.match(bodies[1].text, /Probable Duplicate Recovery/);
  const final = getNotification(dir, registered.record.identity);
  assert.equal(final.state, OUTBOX_STATES.NOTIFIED);
  assert.equal(final.probableDuplicateCount, 1);
  assert.equal(listAttempts(dir, final.notificationId).length, 2);
  cleanup(dir);
});

await test('retry has no finite cap and backlog drains after a sustained Chat outage', async () => {
  const dir = temp('hmz-v2-outage-');
  let clock = Date.parse('2026-07-21T00:00:00Z');
  let available = false;
  const service = createInboundService({ stateDir: dir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    now: () => clock,
    chatFetch: async () => available
      ? response(200, { name: 'spaces/S/messages/final' })
      : response(503, { error: 'unavailable' }),
  });
  const item = await service.registerReceived(received(), { authoritativeReceived: true, createLegacy: false });
  for (let i = 0; i < 30; i++) {
    await service.drainOutbox();
    clock += 31 * 60_000;
  }
  let outbox = getNotification(dir, item.record.identity);
  assert.equal(outbox.state, OUTBOX_STATES.RETRYING);
  assert.equal(outbox.attemptCount, 30);
  available = true;
  const drained = await service.drainOutbox();
  assert.equal(drained.notified, 1);
  outbox = getNotification(dir, item.record.identity);
  assert.equal(outbox.state, OUTBOX_STATES.NOTIFIED);
  assert.equal(outbox.attemptCount, 31);
  cleanup(dir);
});

await test('surrogate identity merges into a later real Instantly id without a second logical notification', async () => {
  const dir = temp('hmz-v2-surrogate-');
  let posts = 0;
  const service = createInboundService({ stateDir: dir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch: async () => response(200, { name: `spaces/S/messages/${++posts}` }) });
  const common = { message_id: '<surrogate-match@example.test>', thread_id: 'surrogate-thread',
    eaccount: 'sender@hmz.test', from_address_email: 'lead@example.test', subject: 'Hello', content_preview: 'Body',
    campaign_id: 'c', lead_id: 'l', timestamp_created: '2026-07-21T00:00:00Z' };
  const first = await service.registerReceived({ ...common, id: '', ue_type: 2 }, {
    authoritativeReceived: true, createLegacy: false,
  });
  await service.drainOutbox();
  assert.equal(first.record.identityKind, IDENTITY_KINDS.SURROGATE);
  const second = await service.registerReceived({ ...common, id: 'real-id-later', ue_type: 2 }, {
    authoritativeReceived: true, createLegacy: false,
  });
  assert.equal(second.created, false);
  assert.equal(getInbound(dir, 'real-id-later').identityKind, IDENTITY_KINDS.INSTANTLY);
  assert.equal(getNotification(dir, 'real-id-later').state, OUTBOX_STATES.NOTIFIED);
  await service.drainOutbox();
  assert.equal(posts, 1);
  assert.equal(operationsSnapshot(dir).counts.durable_inbound_present, 1);
  cleanup(dir);
});

await test('late surrogate reconciliation preserves both attempt histories without a merge failure', async () => {
  const dir = temp('hmz-v2-surrogate-dual-history-');
  let posts = 0;
  const service = createInboundService({ stateDir: dir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch: async () => response(200, { name: `spaces/S/messages/merge-${++posts}` }) });
  const common = { message_id: '<late-surrogate-match@example.test>', thread_id: 'late-surrogate-thread',
    eaccount: 'sender@hmz.test', from_address_email: 'late-lead@example.test', subject: 'Hello', content_preview: 'Body',
    campaign_id: 'c', lead_id: 'l', timestamp_created: '2026-07-21T00:00:00Z', ue_type: 2 };

  await service.registerReceived({ ...common, id: 'real-id-first' }, { authoritativeReceived: true, createLegacy: false });
  await service.drainOutbox();
  await service.registerReceived({ ...common, id: '' }, { authoritativeReceived: true, createLegacy: false });
  await service.drainOutbox();
  assert.equal(posts, 2, 'identity uncertainty produced two acknowledged logical rows before they could be matched');

  await service.registerReceived({ ...common, id: 'real-id-first' }, { authoritativeReceived: true, createLegacy: false });
  const merged = getNotification(dir, 'real-id-first');
  assert.equal(merged.state, OUTBOX_STATES.NOTIFIED);
  assert.equal(merged.attemptCount, 2);
  assert.equal(merged.probableDuplicateCount, 1);
  assert.deepEqual(listAttempts(dir, merged.notificationId).map((attempt) => attempt.attempt_number), [1, 2]);
  assert.equal(operationsSnapshot(dir).counts.durable_inbound_present, 1);
  assert.equal(operationsSnapshot(dir).counts.outbox_present, 1);
  assert.equal(integrityCheck(dir).ok, true);
  cleanup(dir);
});

await test('surrogate merge rejects a reused RFC Message-ID across receiving accounts', async () => {
  const dir = temp('hmz-v2-surrogate-collision-');
  const service = createInboundService({ stateDir: dir });
  const common = { message_id: '<reused-message-id@example.test>', thread_id: '',
    from_address_email: 'same-lead@example.test', subject: 'Same', content_preview: 'Same body',
    campaign_id: 'c', lead_id: 'l', timestamp_created: '2026-07-21T00:00:00Z', ue_type: 2 };
  const surrogate = await service.registerReceived({ ...common, id: '', eaccount: 'mailbox-a@hmz.test' },
    { authoritativeReceived: true, createLegacy: false });
  const real = await service.registerReceived({ ...common, id: 'real-other-mailbox', eaccount: 'mailbox-b@hmz.test' },
    { authoritativeReceived: true, createLegacy: false });
  assert.equal(real.created, true);
  assert.ok(getInbound(dir, surrogate.record.identity), 'surrogate remains distinct');
  assert.ok(getInbound(dir, 'real-other-mailbox'), 'real identity remains distinct');
  assert.equal(operationsSnapshot(dir).counts.durable_inbound_present, 2);
  cleanup(dir);
});

function pagedApi(pages, failures = {}) {
  return async (url) => {
    if (url.includes('/accounts/')) return response(200, { email: 'sender@hmz.test', first_name: 'HMZ', status: 1 });
    if (url.includes('/leads/list')) return response(200, { items: [] });
    if (url.includes('/accounts?')) return response(200, { items: [] });
    const token = new URL(url).searchParams.get('starting_after') || 'FIRST';
    if (failures[token]) return response(failures[token], { error: 'injected' });
    const page = pages[token] || { items: [] };
    return response(200, page);
  };
}

await test('Instantly page reader accepts measured production-sized JSON and enforces a streaming upper bound', async () => {
  const range = { apiKey: 'test-key', since: '2026-07-20T00:00:00Z', until: '2026-07-22T00:00:00Z' };
  const productionSized = await fetchInstantlyReceivedRange({ ...range,
    fetchImpl: async () => response(200, { items: [received({ content_preview: 'x'.repeat(150_000) })] }) });
  assert.equal(productionSized.ok, true);
  assert.equal(productionSized.items.length, 1);

  const oversized = await fetchInstantlyReceivedRange({ ...range,
    fetchImpl: async () => response(200, { items: [{ payload: 'x'.repeat(8 * 1024 * 1024 + 1024) }] }) });
  assert.equal(oversized.ok, false);
  assert.equal(oversized.errorKind, 'INSTANTLY_RESPONSE_TOO_LARGE');
});

await test('full pagination handles equal timestamps, boundary duplicates and saves strongest cursor identity', async () => {
  const dir = temp('hmz-v2-pages-');
  const ts = '2026-07-21T00:00:00.123Z';
  const a = received({ id: 'page-a', timestamp_created: ts, from_address_email: 'mailer-daemon@example.test' });
  const b = received({ id: 'page-b', timestamp_created: ts, from_address_email: 'mailer-daemon@example.test' });
  const c = received({ id: 'page-c', timestamp_created: ts, from_address_email: 'mailer-daemon@example.test' });
  const api = pagedApi({
    FIRST: { items: [a, b], next_starting_after: 'T1' },
    T1: { items: [b, c] },
  });
  const service = createInboundService({ stateDir: dir, apiKey: 'test-key', fetchImpl: api,
    notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch: async () => response(200, { name: `spaces/S/messages/${Math.random()}` }) });
  const result = await service.runNormalPoll({ indexingDelayMs: 0 });
  assert.equal(result.ok, true);
  assert.equal(result.pageCount, 2);
  assert.equal(result.observed, 3);
  assert.equal(result.duplicates, 1);
  assert.equal(result.reconciliation.chatNotified, 3);
  const state = getPollState(dir, 'normal-recovery-poll');
  assert.ok(state.cursor_timestamp);
  assert.equal(state.cursor_email_id, 'page-c');
  assert.equal(integrityCheck(dir).ok, true);
  cleanup(dir);
});

await test('final-page API failure persists earlier pages but never advances cursor; retry restores safely', async () => {
  const dir = temp('hmz-v2-partial-');
  const a = received({ id: 'partial-a', from_address_email: 'mailer-daemon@example.test' });
  const b = received({ id: 'partial-b', from_address_email: 'mailer-daemon@example.test' });
  const pages = { FIRST: { items: [a], next_starting_after: 'T1' }, T1: { items: [b] } };
  let service = createInboundService({ stateDir: dir, apiKey: 'test-key', fetchImpl: pagedApi(pages, { T1: 500 }) });
  const failed = await service.runNormalPoll({ indexingDelayMs: 0 });
  assert.equal(failed.ok, false);
  assert.equal(failed.cursorAdvanced, false);
  assert.equal(getPollState(dir, 'normal-recovery-poll'), null);
  assert.ok(getInbound(dir, 'partial-a'), 'first page remains durably represented');
  service = createInboundService({ stateDir: dir, apiKey: 'test-key', fetchImpl: pagedApi(pages) });
  const retried = await service.runNormalPoll({ indexingDelayMs: 0 });
  assert.equal(retried.ok, true);
  assert.ok(getInbound(dir, 'partial-b'));
  assert.ok(getPollState(dir, 'normal-recovery-poll').cursor_timestamp);
  cleanup(dir);
});

for (const status of [401, 429, 500]) {
  await test(`Instantly ${status} never advances recovery cursor`, async () => {
    const dir = temp(`hmz-v2-api-${status}-`);
    const service = createInboundService({ stateDir: dir, apiKey: 'test-key', fetchImpl: async () => response(status, {}) });
    const result = await service.runNormalPoll({ indexingDelayMs: 0 });
    assert.equal(result.ok, false);
    assert.equal(result.cursorAdvanced, false);
    assert.equal(getPollState(dir, 'normal-recovery-poll'), null);
    cleanup(dir);
  });
}

await test('malformed 200 API schema never advances recovery cursor', async () => {
  const dir = temp('hmz-v2-schema-');
  const service = createInboundService({ stateDir: dir, apiKey: 'test-key',
    fetchImpl: async () => response(200, { unexpected: [] }) });
  const result = await service.runNormalPoll({ indexingDelayMs: 0 });
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'INSTANTLY_INVALID_SCHEMA');
  assert.equal(result.cursorAdvanced, false);
  assert.equal(getPollState(dir, 'normal-recovery-poll'), null);
  cleanup(dir);
});

await test('production Chat destination rejects arbitrary HTTPS hosts', async () => {
  const dir = temp('hmz-v2-ssrf-');
  assert.throws(() => createInboundService({ stateDir: dir, notifyUrl: 'https://attacker.invalid/hook' }),
    /chat_destination_not_google_chat/);
  cleanup(dir);
});

await test('SQLite database symlink is rejected before open', async () => {
  const dir = temp('hmz-v2-symlink-');
  const target = path.join(dir, 'target.sqlite');
  fs.writeFileSync(target, 'not-a-database');
  fs.symlinkSync(target, path.join(dir, 'inbound-v2.sqlite'));
  assert.throws(() => createInboundService({ stateDir: dir }), /unsafe_inbound_database_path/);
  fs.rmSync(dir, { recursive: true, force: true });
});

await test('independent short auditor recovers webhook/poll miss without sharing normal cursor', async () => {
  const dir = temp('hmz-v2-audit-');
  const item = received({ id: 'audit-only', from_address_email: 'mailer-daemon@example.test' });
  const api = pagedApi({ FIRST: { items: [item] } });
  const service = createInboundService({ stateDir: dir, apiKey: 'test-key', fetchImpl: api,
    notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch: async () => response(200, { name: 'spaces/S/messages/audit' }) });
  assert.equal(getPollState(dir, 'normal-recovery-poll'), null);
  const audit = await service.runCompletenessAudit('short', { windowMs: 2 * 60 * 60 * 1000, indexingDelayMs: 0 });
  assert.equal(audit.ok, true);
  assert.equal(audit.recordsMissing, 1);
  assert.equal(audit.recordsRecovered, 1);
  assert.equal(audit.reconciliation.chatNotified, 1);
  assert.equal(getPollState(dir, 'normal-recovery-poll'), null, 'auditor does not create/advance normal cursor');
  assert.equal(getNotification(dir, 'audit-only').state, OUTBOX_STATES.NOTIFIED);
  cleanup(dir);
});

await test('old-schema legacy Chat resource names import as definite acknowledgements without a duplicate post', async () => {
  const dir = temp('hmz-v2-legacy-ack-');
  const raw = received({ id: 'legacy-ack-before-state-field' });
  const legacy = createContext(dir, {
    replyToUuid: raw.id,
    instantlyEmailId: raw.id,
    eaccount: raw.eaccount,
    prospectEmail: raw.from_address_email,
    subject: raw.subject,
    campaignId: raw.campaign_id,
    campaignName: raw.campaign_name,
    uniboxUrl: 'https://app.instantly.ai/app/unibox',
    authoritativeThreadId: raw.thread_id,
    receivedAt: raw.timestamp_created,
    preview: raw.content_preview,
  });
  assert.equal(legacy.ok, true);
  attachChatPost(dir, legacy.context.notificationId, {
    chatMessageName: 'spaces/LEGACY/messages/ACK',
    chatThreadName: 'spaces/LEGACY/threads/ACK',
    chatStatus: 200,
  });
  const legacyPath = path.join(dir, 'contexts', `${legacy.context.notificationId}.json`);
  const oldSchema = JSON.parse(fs.readFileSync(legacyPath, 'utf8'));
  delete oldSchema.notificationState;
  delete oldSchema.chatNotifiedAt;
  fs.writeFileSync(legacyPath, JSON.stringify(oldSchema));

  let posts = 0;
  const service = createInboundService({
    stateDir: dir,
    notifyUrl: 'https://mock.chat.test/hook',
    allowMockChatUrl: true,
    chatFetch: async () => { posts++; return response(200, { name: 'spaces/S/messages/DUPLICATE' }); },
  });
  const migration = service.migrateLegacyAcknowledgements();
  assert.equal(migration.importedAcknowledged, 1);
  const outbox = getNotification(dir, raw.id);
  assert.equal(outbox.state, OUTBOX_STATES.NOTIFIED);
  assert.equal(outbox.ackMessageName, 'spaces/LEGACY/messages/ACK');
  const drain = await service.drainOutbox({ limit: 10, maxBatches: 1 });
  assert.equal(drain.attempted, 0);
  assert.equal(posts, 0);
  cleanup(dir);
});

await test('late discovery imports an existing legacy Chat acknowledgement before draining', async () => {
  const dir = temp('hmz-v2-late-legacy-ack-');
  const raw = received({ id: 'late-legacy-ack' });
  const legacy = createContext(dir, {
    replyToUuid: raw.id,
    instantlyEmailId: raw.id,
    eaccount: raw.eaccount,
    prospectEmail: raw.from_address_email,
    subject: raw.subject,
    campaignId: raw.campaign_id,
    campaignName: raw.campaign_name,
    uniboxUrl: 'https://app.instantly.ai/app/unibox',
    authoritativeThreadId: raw.thread_id,
    receivedAt: raw.timestamp_created,
    preview: raw.content_preview,
  });
  attachChatPost(dir, legacy.context.notificationId, {
    chatMessageName: 'spaces/LEGACY/messages/LATE',
    chatThreadName: 'spaces/LEGACY/threads/LATE',
    chatStatus: 200,
  });
  const legacyPath = path.join(dir, 'contexts', `${legacy.context.notificationId}.json`);
  const oldSchema = JSON.parse(fs.readFileSync(legacyPath, 'utf8'));
  delete oldSchema.notificationState;
  fs.writeFileSync(legacyPath, JSON.stringify(oldSchema));

  let posts = 0;
  const service = createInboundService({
    stateDir: dir,
    notifyUrl: 'https://mock.chat.test/hook',
    allowMockChatUrl: true,
    chatFetch: async () => { posts++; return response(200, { name: 'spaces/S/messages/DUPLICATE' }); },
  });
  const registered = await service.registerReceived(raw, {
    authoritativeReceived: true, discoverySource: 'COMPLETENESS_AUDIT', createLegacy: true,
  });
  assert.equal(registered.legacy.acknowledgementImported, true);
  assert.equal(registered.outbox.state, OUTBOX_STATES.NOTIFIED);
  assert.equal(registered.outbox.ackMessageName, 'spaces/LEGACY/messages/LATE');
  assert.equal((await service.drainOutbox({ limit: 10, maxBatches: 1 })).attempted, 0);
  assert.equal(posts, 0);
  cleanup(dir);
});

await test('historical owner holds are excluded from malformed-unacknowledged watchdog facts', async () => {
  const dir = temp('hmz-v2-historical-watchdog-');
  const service = createInboundService({ stateDir: dir, notificationEpoch: '2026-07-22T00:00:00Z' });
  const registered = await service.registerReceived(received({ id: 'historical-degraded', lead_id: '' }), {
    authoritativeReceived: true, createLegacy: false,
  });
  assert.equal(registered.outbox.state, OUTBOX_STATES.HISTORICAL_HOLD);
  assert.equal(registered.record.degradedMetadata, true);
  assert.equal(watchdogFacts(dir).unacknowledgedMalformed, 0);
  cleanup(dir);
});

for (const line of results) console.log(line);
console.log(`\n${passed}/${results.length} inbound-v2 tests passed`);
if (passed !== results.length) process.exitCode = 1;
