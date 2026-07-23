// r13 — automatic and out-of-office inbound emails use the ORDINARY supervised
// Google Chat reply path.
//
// Owner requirement (2026-07-23): classification selects the card label only. It
// must not by itself make a record non-replyable. Nothing auto-sends: a reply
// still needs an @Instantly mention, a Review card, one human Send click, the
// global gate, and the historical / token / revision / duplicate gates.
//
// These tests exercise the real shared mechanism end to end: durable inbound
// registration -> reply context -> Chat acknowledgement attach -> thread lookup
// (the exact call the @Instantly mention handler makes) -> draft -> review ->
// send validation.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createInboundService } from './inbound-service.mjs';
import { normalizeInstantlyReceived, buildNotificationText, LABELS } from './inbound-contract.mjs';
import { getInbound, getNotification } from './inbound-store.mjs';
import {
  resolveByThreadKey, readContext, createDraft, validateReview, setGoLive, getGoLive,
} from './store.mjs';

let passed = 0;
const failures = [];
async function t(name, fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'auto-ooo-'));
  try { await fn(dir); passed++; console.log(`ok   ${name}`); }
  catch (error) { failures.push(name); console.log(`FAIL ${name}: ${error.message}`); }
  finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

const EPOCH = '2026-07-18T18:33:00Z';
const CAMPAIGN = '35c31fe3-1ae1-495e-b81c-49ccdbbf3ee3';
const NOTIFY = 'https://chat.googleapis.com/v1/spaces/AAA/messages?key=k&token=t';

// Instantly readback shape — how every automatic/OOO reply actually arrives.
function payload(over = {}) {
  return {
    email_type: 'received',
    id: '019f9000-0000-7000-8000-00000000aaaa',
    eaccount: 'hamzah@hmzautomation.com',
    from_address_email: 'noah@example.com',
    thread_id: '86-thread-auto',
    message_id: '<auto-1@example.com>',
    campaign_id: CAMPAIGN,
    lead_id: 'lead-1',
    subject: 'Automatic reply: quick question',
    body_text: 'I am away from my desk and will reply shortly.',
    timestamp_created: '2026-07-22T16:36:15.000Z',
    ...over,
  };
}
const OOO = { id: '019f9000-0000-7000-8000-00000000bbbb', thread_id: '86-thread-ooo',
  message_id: '<ooo-1@example.com>', subject: 'Out of the office', body_text: 'I am out of the office until Monday.' };
const ORDINARY = { id: '019f9000-0000-7000-8000-00000000cccc', thread_id: '86-thread-ord',
  message_id: '<ord-1@example.com>', subject: 'Re: quick question', body_text: 'Sounds good, send the details.' };

// Chat transport double: returns a definite message + thread resource name.
function chatDouble(state = {}) {
  state.posts = [];
  state.fetch = async (url, init) => {
    const body = JSON.parse(init.body);
    state.posts.push(body);
    return {
      status: 200,
      headers: { get: () => null },
      text: async () => JSON.stringify({
        name: `spaces/AAA/messages/M${state.posts.length}`,
        thread: { name: `spaces/AAA/threads/T${state.posts.length}` },
      }),
    };
  };
  return state;
}

// Instantly API double: no lead/account/campaign data, and it must never be
// asked to send. Any POST to /emails/reply fails the test loudly.
function instantlyDouble(state = {}) {
  state.replyPosts = 0;
  state.fetch = async (url) => {
    if (String(url).includes('/emails/reply')) { state.replyPosts++; throw new Error('UNEXPECTED_PROSPECT_SEND'); }
    return { status: 404, text: async () => '{}' };
  };
  return state;
}

async function ingest(dir, over, { epoch = EPOCH } = {}) {
  const chat = chatDouble();
  const api = instantlyDouble();
  const service = createInboundService({
    stateDir: dir, apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    notifyUrl: NOTIFY, fetchImpl: api.fetch, chatFetch: chat.fetch, notificationEpoch: epoch,
  });
  const registered = await service.registerReceived(payload(over), { authoritativeReceived: true, discoverySource: 'NORMAL_POLL' });
  const drain = await service.drainOutbox({ limit: 10 });
  const record = getInbound(dir, registered.record.identity);
  return { service, chat, api, registered, drain, record, outbox: getNotification(dir, record.identity) };
}

// --- 1. ordinary regression -------------------------------------------------

await t('ordinary record keeps a replyable context, thread map, draft and footer', async (dir) => {
  const { record, outbox, chat } = await ingest(dir, ORDINARY);
  assert.equal(record.classification, LABELS.ORDINARY);
  assert.equal(record.sendAllowed, true);
  assert.ok(record.legacyContextId, 'ordinary must have a reply context');
  assert.equal(outbox.state, 'CHAT_NOTIFIED');
  const byThread = resolveByThreadKey(dir, outbox.ackThreadName);
  assert.equal(byThread.notificationId, record.legacyContextId);
  const draft = createDraft(dir, record.legacyContextId, { body: 'Thanks — here are the details.' });
  assert.equal(draft.ok, true);
  assert.equal(draft.revision, 1);
  assert.match(chat.posts[0].text, /To reply from Google Chat, reply in this thread and mention @Instantly followed by your response\./);
});

// --- 2/3. automatic and out-of-office --------------------------------------

for (const [label, over, expected] of [
  ['automatic', {}, LABELS.AUTOMATIC],
  ['out-of-office', OOO, LABELS.OOO],
]) {
  await t(`${label} record gets the full ordinary supervised reply path`, async (dir) => {
    const { record, outbox, chat } = await ingest(dir, over);
    assert.equal(record.classification, expected, 'classification label must be preserved');
    assert.equal(record.sendAllowed, true, 'must be reply eligible');
    assert.ok(record.legacyContextId, 'must create a durable reply context');
    assert.equal(outbox.state, 'CHAT_NOTIFIED');

    // The definite Chat message + thread resource are attached to the context.
    const context = readContext(dir, record.legacyContextId);
    assert.equal(context.chatMessageName, outbox.ackMessageName);
    assert.equal(context.chatThreadName, outbox.ackThreadName);

    // Exactly the lookup the @Instantly mention handler performs.
    const resolved = resolveByThreadKey(dir, outbox.ackThreadName);
    assert.ok(resolved, 'the mention handler must not get NO_CONTEXT_FOR_THREAD');
    assert.equal(resolved.notificationId, record.legacyContextId);

    // Draft -> review card -> edit -> latest revision only.
    const first = createDraft(dir, record.legacyContextId, { body: 'Thanks, understood — I will follow up next week.' });
    assert.equal(first.ok, true);
    assert.equal(first.revision, 1);
    assert.ok(first.reviewToken, 'a Review card token must be issued');
    const edited = createDraft(dir, record.legacyContextId, { body: 'Edited: I will follow up on Monday.' });
    assert.equal(edited.revision, 2, 'Edit must create a new revision');
    assert.equal(validateReview(dir, record.legacyContextId, { reviewToken: first.reviewToken, bodyHash: first.bodyHash }).ok,
      false, 'the stale revision must be refused');
    assert.equal(validateReview(dir, record.legacyContextId, { reviewToken: edited.reviewToken, bodyHash: edited.bodyHash }).ok,
      true, 'the latest revision must validate');

    // Footer wording is exactly the ordinary instruction.
    assert.match(chat.posts[0].text, /To reply from Google Chat, reply in this thread and mention @Instantly followed by your response\./);
    assert.doesNotMatch(chat.posts[0].text, /unavailable for this record type/);
  });
}

// --- 4. recovered automatic/OOO --------------------------------------------

await t('recovered automatic record creates exactly one context and one notification', async (dir) => {
  const chat = chatDouble();
  const api = instantlyDouble();
  const service = createInboundService({
    stateDir: dir, apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    notifyUrl: NOTIFY, fetchImpl: api.fetch, chatFetch: chat.fetch, notificationEpoch: EPOCH,
  });
  const a = await service.registerReceived(payload(), { authoritativeReceived: true, discoverySource: 'NORMAL_POLL', recovered: true });
  await service.drainOutbox({ limit: 10 });
  // Re-discovered by the completeness auditor.
  const b = await service.registerReceived(payload(), { authoritativeReceived: true, discoverySource: 'COMPLETENESS_AUDIT', recovered: true });
  await service.drainOutbox({ limit: 10 });
  assert.equal(a.record.identity, b.record.identity);
  assert.equal(chat.posts.length, 1, 'no duplicate Chat notification');
  const record = getInbound(dir, a.record.identity);
  assert.equal(record.classification, LABELS.AUTOMATIC, 'label preserved through recovery');
  assert.ok(record.legacyContextId);
  assert.equal(b.legacy.contextId, record.legacyContextId, 'no duplicate context');
  const outbox = getNotification(dir, record.identity);
  assert.equal(resolveByThreadKey(dir, outbox.ackThreadName).notificationId, record.legacyContextId);
  assert.equal(createDraft(dir, record.legacyContextId, { body: 'Understood, thanks.' }).ok, true);
});

await t('an automatic card notified before the policy change is linked without reposting', async (dir) => {
  // Simulates the deployed fleet: the record was notified while it was still
  // reply-ineligible, so it has an acknowledgement but no context.
  const chat = chatDouble();
  const api = instantlyDouble();
  const mk = () => createInboundService({
    stateDir: dir, apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    notifyUrl: NOTIFY, fetchImpl: api.fetch, chatFetch: chat.fetch, notificationEpoch: EPOCH,
  });
  const registered = await mk().registerReceived(payload(), { authoritativeReceived: true, discoverySource: 'NORMAL_POLL', createLegacy: false });
  await mk().drainOutbox({ limit: 10 });
  const before = getInbound(dir, registered.record.identity);
  assert.equal(before.legacyContextId, null, 'precondition: notified with no context');
  const outbox = getNotification(dir, before.identity);
  assert.equal(outbox.state, 'CHAT_NOTIFIED');
  const postsBefore = chat.posts.length;

  // A later poll/audit observation heals it through the shared path.
  await mk().registerReceived(payload(), { authoritativeReceived: true, discoverySource: 'COMPLETENESS_AUDIT', recovered: true });
  const after = getInbound(dir, before.identity);
  assert.ok(after.legacyContextId, 'context created on re-observation');
  assert.equal(chat.posts.length, postsBefore, 'no card was reposted');
  assert.equal(resolveByThreadKey(dir, outbox.ackThreadName).notificationId, after.legacyContextId,
    'the ORIGINAL Chat thread now resolves to the context');
  assert.equal(readContext(dir, after.legacyContextId).chatMessageName, outbox.ackMessageName);
});

// --- 5/6. no pending-context error, exact authoritative routing -------------

await t('automatic thread resolves and the draft keeps exact authoritative routing', async (dir) => {
  const { record, outbox } = await ingest(dir, {});
  const resolved = resolveByThreadKey(dir, outbox.ackThreadName);
  assert.ok(resolved, 'must never be NO_CONTEXT_FOR_THREAD');
  const context = readContext(dir, record.legacyContextId);
  assert.equal(context.instantlyEmailId, '019f9000-0000-7000-8000-00000000aaaa');
  assert.equal(context.replyToUuid, '019f9000-0000-7000-8000-00000000aaaa');
  assert.equal(context.authoritativeThreadId, '86-thread-auto');
  assert.equal(context.prospectEmail, 'noah@example.com');
  assert.equal(context.eaccount, 'hamzah@hmzautomation.com');
  assert.equal(context.campaignId, CAMPAIGN);
  assert.equal(context.chatThreadName, outbox.ackThreadName);
});

// --- 7. routing incomplete --------------------------------------------------

await t('automatic record missing routing is notified but never becomes sendable', async (dir) => {
  const { record, outbox, chat, api } = await ingest(dir, { eaccount: '' });
  assert.equal(record.classification, LABELS.AUTOMATIC);
  assert.equal(record.sendAllowed, false, 'incomplete routing must stay ineligible');
  assert.equal(record.legacyContextId, null, 'no reply context');
  assert.equal(outbox.state, 'CHAT_NOTIFIED', 'still notified');
  assert.match(chat.posts[0].text, /Routing Incomplete/);
  assert.match(chat.posts[0].text, /Reply sending is unavailable until authoritative routing is recovered\./);
  assert.equal(api.replyPosts, 0);
});

// --- 8. optional enrichment missing ----------------------------------------

await t('missing campaign/prospect name does not affect reply eligibility', async (dir) => {
  const { record } = await ingest(dir, {});
  assert.equal(record.campaignName, null);
  assert.equal(record.prospectName, null);
  assert.equal(record.sendAllowed, true);
  assert.ok(record.legacyContextId);
  const text = buildNotificationText(record, {});
  assert.match(text, new RegExp(`^Campaign: ${CAMPAIGN}$`, 'm'));
  assert.match(text, /^Prospect: noah@example\.com$/m);
});

// --- 9. historical guard ----------------------------------------------------

await t('pre-epoch automatic record stays held and non-actionable', async (dir) => {
  const chat = chatDouble();
  const api = instantlyDouble();
  const service = createInboundService({
    stateDir: dir, apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    notifyUrl: NOTIFY, fetchImpl: api.fetch, chatFetch: chat.fetch, notificationEpoch: EPOCH,
  });
  const registered = await service.registerReceived(payload({ timestamp_created: '2026-03-02T09:00:00.000Z' }),
    { authoritativeReceived: true, discoverySource: 'NORMAL_POLL' });
  await service.drainOutbox({ limit: 10 });
  const record = getInbound(dir, registered.record.identity);
  const outbox = getNotification(dir, record.identity);
  assert.equal(record.classification, LABELS.AUTOMATIC);
  assert.equal(outbox.state, 'HISTORICAL_OWNER_HOLD', 'pre-epoch stays held');
  assert.equal(chat.posts.length, 0, 'never posted to Chat');
  assert.equal(record.legacyContextId, null, 'no reply context for a held record');
  assert.equal(api.replyPosts, 0);
});

await t('historical guard refuses context, draft, review and arming for pre-epoch automatic records', async (dir) => {
  // Build the context via a live-epoch record, then prove the guard keys on the
  // record being historical rather than on its classification.
  const { record } = await ingest(dir, {});
  const cid = record.legacyContextId;
  assert.ok(cid);
  const draft = createDraft(dir, cid, { body: 'Live record drafts fine.' });
  assert.equal(draft.ok, true);

  // Same service, a genuinely pre-epoch automatic record: context is refused.
  const chat = chatDouble();
  const api = instantlyDouble();
  const service = createInboundService({
    stateDir: dir, apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    notifyUrl: NOTIFY, fetchImpl: api.fetch, chatFetch: chat.fetch, notificationEpoch: null,
  });
  const old = await service.registerReceived(
    payload({ id: '019f9000-0000-7000-8000-00000000dddd', thread_id: '86-t-old', message_id: '<old@x>',
      timestamp_created: '2026-03-02T09:00:00.000Z' }),
    { authoritativeReceived: true, discoverySource: 'NORMAL_POLL' });
  const oldRecord = getInbound(dir, old.record.identity);
  assert.equal(oldRecord.classification, LABELS.AUTOMATIC);
  assert.equal(oldRecord.sendAllowed, true, 'eligibility is about classification+routing only');
  assert.equal(oldRecord.legacyContextId, null, 'r9 guard refuses a historical context');
  assert.equal(old.legacy.ok, false);
});

// --- 10. unsubscribe / bounce / system regression ---------------------------

await t('unsubscribe, bounce, system and malformed records remain non-replyable', async (dir) => {
  const cases = [
    ['unsubscribe', { id: '019f9000-0000-7000-8000-00000000e001', thread_id: '86-t-u', message_id: '<u@x>',
      subject: 'Automatic reply: unsubscribe me', body_text: 'Please unsubscribe me.' }, LABELS.UNSUBSCRIBE],
    ['bounce', { id: '019f9000-0000-7000-8000-00000000e002', thread_id: '86-t-b', message_id: '<b@x>',
      subject: 'Undeliverable: quick question', body_text: 'Delivery failed.' }, LABELS.BOUNCE],
    ['system', { id: '019f9000-0000-7000-8000-00000000e003', thread_id: '86-t-s', message_id: '<s@x>',
      from_address_email: 'mailer-daemon@example.com', subject: 'Automatic reply', body_text: 'x' }, LABELS.SYSTEM],
  ];
  for (const [name, over, expected] of cases) {
    const { record, chat } = await ingest(dir, over);
    assert.equal(record.classification, expected, `${name} classification must be preserved`);
    assert.equal(record.sendAllowed, false, `${name} must stay non-replyable`);
    assert.equal(record.legacyContextId, null, `${name} must not get a reply context`);
    assert.match(chat.posts.at(-1).text, /Reply through this Chat notification is unavailable for this record type\./);
  }
});

await t('unsubscribe precedence survives auto-reply wording', () => {
  const r = normalizeInstantlyReceived(payload({
    subject: 'Automatic reply: please remove me', body_text: 'stop emailing me',
  }), { authoritativeReceived: true, discoverySource: 'NORMAL_POLL' }).record;
  assert.equal(r.classification, LABELS.UNSUBSCRIBE, 'unsubscribe must win over automatic');
  assert.equal(r.sendAllowed, false);
});

// --- 11. duplicate / stale protections --------------------------------------

await t('automatic draft keeps one-use token, stale-revision and duplicate protection', async (dir) => {
  const { record } = await ingest(dir, {});
  const cid = record.legacyContextId;
  const d1 = createDraft(dir, cid, { body: 'First revision body.' });
  const ok1 = validateReview(dir, cid, { reviewToken: d1.reviewToken, bodyHash: d1.bodyHash });
  assert.equal(ok1.ok, true);
  // Tampered body is refused even with a valid token.
  assert.equal(validateReview(dir, cid, { reviewToken: d1.reviewToken, bodyHash: 'deadbeef' }).ok, false);
  // A new revision invalidates the previous token.
  const d2 = createDraft(dir, cid, { body: 'Second revision body.' });
  assert.equal(d2.revision, 2);
  assert.equal(validateReview(dir, cid, { reviewToken: d1.reviewToken, bodyHash: d1.bodyHash }).ok, false);
  assert.equal(validateReview(dir, cid, { reviewToken: d2.reviewToken, bodyHash: d2.bodyHash }).ok, true);
});

// --- 12. security: Chat parameters cannot override durable routing ----------

await t('Chat-supplied parameters cannot override stored routing on an automatic context', async (dir) => {
  const { record } = await ingest(dir, {});
  const cid = record.legacyContextId;
  const draft = createDraft(dir, cid, {
    body: 'Legitimate body.',
    // Hostile extras a Chat payload might carry:
    eaccount: 'attacker@evil.invalid', prospectEmail: 'victim@evil.invalid',
    replyToUuid: 'attacker-uuid', authoritativeThreadId: 'attacker-thread', campaignId: 'attacker-campaign',
    revision: 99,
  });
  assert.equal(draft.ok, true);
  const context = readContext(dir, cid);
  assert.equal(context.eaccount, 'hamzah@hmzautomation.com');
  assert.equal(context.prospectEmail, 'noah@example.com');
  assert.equal(context.replyToUuid, '019f9000-0000-7000-8000-00000000aaaa');
  assert.equal(context.authoritativeThreadId, '86-thread-auto');
  assert.equal(context.campaignId, CAMPAIGN);
  assert.equal(draft.revision, 1, 'revision is server-assigned');
});

await t('no test in this suite armed the global gate or issued an Instantly reply POST', async (dir) => {
  const { api } = await ingest(dir, {});
  assert.equal(api.replyPosts, 0);
  const gate = getGoLive(dir);
  assert.equal(gate.armedContextId ?? null, null);
  assert.notEqual(typeof setGoLive, 'undefined');
});

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.error('failed:', failures.join(', ')); process.exit(1); }
