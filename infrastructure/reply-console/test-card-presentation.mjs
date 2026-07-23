// r12 notification-card presentation contract.
//
// Covers the four owner-reported presentation defects:
//   1. automatic cards showed no prospect name;
//   2. automatic titles carried a visible "(recovered)" suffix;
//   3. cards showed the campaign UUID instead of the display name;
//   4. cards carried a "Campaign details unavailable ... Reply routing is
//      unaffected." paragraph.
//
// Presentation only: nothing here may change routing, sendAllowed, duplicate
// protection, the historical guard, or the global-send record.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  buildNotificationText, notificationTitle, normalizeInstantlyReceived,
  isAuthoritativeRoutingComplete, LABELS,
} from './inbound-contract.mjs';
import { resolveCampaignName, getCachedCampaignName } from './enrich.mjs';

let passed = 0;
const failures = [];
function check(name, fn) {
  try { fn(); passed++; console.log(`ok   ${name}`); }
  catch (error) { failures.push(name); console.log(`FAIL ${name}: ${error.message}`); }
}
async function checkAsync(name, fn) {
  try { await fn(); passed++; console.log(`ok   ${name}`); }
  catch (error) { failures.push(name); console.log(`FAIL ${name}: ${error.message}`); }
}

const CAMPAIGN_UUID = '35c31fe3-1ae1-495e-b81c-49ccdbbf3ee3';
const CAMPAIGN_NAME = 'Test Batch Run - Cold Email Outbound';

// Webhook shape: carries campaign_name + lead first/last name.
function webhookPayload(extra = {}) {
  return {
    event_type: 'reply_received',
    id: 'e-ordinary-1',
    eaccount: 'hamzah@hmzautomation.com',
    from_address_email: 'noah@example.com',
    thread_id: '86-thread-ordinary',
    message_id: '<m-ordinary@example.com>',
    campaign_id: CAMPAIGN_UUID,
    campaign_name: CAMPAIGN_NAME,
    lead_id: 'lead-1',
    firstName: 'Noah',
    lastName: 'Cole',
    subject: 'Re: quick question',
    reply_text: 'Sounds good, send over the details.',
    timestamp_created: '2026-07-22T14:03:54.000Z',
    ...extra,
  };
}

// Poll/audit readback shape: campaign_id only, no campaign_name, no lead names.
// This is exactly what the recovery poll and completeness auditors receive, and
// is how every automatic / out-of-office reply reaches the console.
function readbackPayload(extra = {}) {
  return {
    email_type: 'received',
    id: 'e-auto-1',
    eaccount: 'hamzah@hmzautomation.com',
    from_address_email: 'noah@example.com',
    thread_id: '86-thread-auto',
    message_id: '<m-auto@example.com>',
    campaign_id: CAMPAIGN_UUID,
    lead_id: 'lead-1',
    subject: 'Automatic reply: quick question',
    body_text: 'I am currently away and will respond on Monday.',
    timestamp_created: '2026-07-22T16:36:15.000Z',
    ...extra,
  };
}

function norm(payload, discoverySource) {
  const result = normalizeInstantlyReceived(payload, { discoverySource });
  assert.equal(result.ok, true, 'payload must normalise');
  return result.record;
}

// --- 1/2. prospect name on automatic cards ---------------------------------

check('automatic card with an authoritative prospect name shows name + full email', () => {
  const record = { ...norm(readbackPayload(), 'NORMAL_POLL'), prospectName: 'Noah Cole' };
  assert.equal(record.classification, LABELS.AUTOMATIC);
  const text = buildNotificationText(record, { campaignName: CAMPAIGN_NAME });
  assert.match(text, /^Prospect: Noah Cole \(noah@example\.com\)$/m);
});

check('automatic card without a known name shows the full email only', () => {
  const record = norm(readbackPayload(), 'NORMAL_POLL');
  assert.equal(record.prospectName, null, 'readback payload carries no lead name');
  const text = buildNotificationText(record, { campaignName: CAMPAIGN_NAME });
  assert.match(text, /^Prospect: noah@example\.com$/m);
  assert.doesNotMatch(text, /Name unavailable/);
});

// --- 3. ordinary card unchanged --------------------------------------------

check('ordinary card retains name + full email', () => {
  const record = norm(webhookPayload(), 'DISCOVERED_WEBHOOK');
  assert.equal(record.classification, LABELS.ORDINARY);
  const text = buildNotificationText(record, { campaignName: CAMPAIGN_NAME });
  assert.match(text, /^Prospect: Noah Cole \(noah@example\.com\)$/m);
});

// --- 4/5. campaign display name --------------------------------------------

check('automatic/recovered record with a resolvable campaign shows the name, not the UUID', () => {
  const record = norm(readbackPayload(), 'COMPLETENESS_AUDIT');
  assert.equal(record.campaignName, null, 'readback carries no campaign_name');
  const text = buildNotificationText(record, { campaignName: CAMPAIGN_NAME });
  assert.match(text, new RegExp(`^Campaign: ${CAMPAIGN_NAME.replace(/[-[\]{}()*+?.,\\^$|#]/g, '\\$&')}$`, 'm'));
  assert.doesNotMatch(text, new RegExp(CAMPAIGN_UUID));
  assert.doesNotMatch(text, /Campaign details unavailable/);
  assert.doesNotMatch(text, /campaign context not registered/);
  assert.doesNotMatch(text, /Reply routing is unaffected/);
});

check('ordinary record with the same campaign shows the same authoritative name', () => {
  const auto = buildNotificationText(norm(readbackPayload(), 'NORMAL_POLL'), { campaignName: CAMPAIGN_NAME });
  const ordinary = buildNotificationText(norm(webhookPayload(), 'DISCOVERED_WEBHOOK'), { campaignName: CAMPAIGN_NAME });
  const line = (t) => t.split('\n').find((l) => l.startsWith('Campaign: '));
  assert.equal(line(auto), `Campaign: ${CAMPAIGN_NAME}`);
  assert.equal(line(ordinary), `Campaign: ${CAMPAIGN_NAME}`);
  assert.doesNotMatch(ordinary, /Campaign details unavailable/);
});

// --- 6. genuinely unresolved campaign --------------------------------------

check('unresolved campaign falls back to the UUID without a warning paragraph', () => {
  const record = norm(readbackPayload(), 'NORMAL_POLL');
  const text = buildNotificationText(record, {});
  assert.match(text, new RegExp(`^Campaign: ${CAMPAIGN_UUID}$`, 'm'));
  assert.doesNotMatch(text, /Campaign details unavailable/);
  assert.doesNotMatch(text, /Reply routing is unaffected/);
  assert.doesNotMatch(text, /Routing incomplete/);
});

check('campaign with no id at all renders the concise Unknown fallback', () => {
  const record = norm(readbackPayload({ campaign_id: undefined }), 'NORMAL_POLL');
  const text = buildNotificationText(record, {});
  assert.match(text, /^Campaign: Unknown$/m);
  assert.doesNotMatch(text, /Campaign details unavailable/);
});

check('unresolved campaign does not affect sendAllowed or routing completeness', () => {
  const withName = norm(webhookPayload(), 'DISCOVERED_WEBHOOK');
  const withoutName = norm(webhookPayload({ campaign_name: undefined }), 'DISCOVERED_WEBHOOK');
  assert.equal(withName.sendAllowed, true);
  assert.equal(withoutName.sendAllowed, true, 'missing campaign name must not block Send');
  assert.equal(isAuthoritativeRoutingComplete(withoutName), true);
  const text = buildNotificationText(withoutName, {});
  assert.match(text, /mention @Instantly/);
  assert.doesNotMatch(text, /Reply sending is unavailable/);
});

// --- 7/8. titles and discovery source --------------------------------------

check('automatic and OOO titles carry no "(recovered)" suffix', () => {
  const auto = norm(readbackPayload(), 'NORMAL_POLL');
  const ooo = norm(readbackPayload({ id: 'e-ooo-1', subject: 'Out of the office', thread_id: '86-t-ooo' }), 'NORMAL_POLL');
  assert.equal(ooo.classification, LABELS.OOO);
  for (const record of [auto, ooo]) {
    for (const options of [{}, { recovered: true }]) {
      const title = notificationTitle(record, options);
      assert.doesNotMatch(title, /\(recovered\)/);
      assert.equal(buildNotificationText(record, options).split('\n')[0], title);
    }
  }
  assert.equal(notificationTitle(auto, { recovered: true }), '🤖 Automatic Reply');
  assert.equal(notificationTitle(ooo, { recovered: true }), '🤖 Out-of-Office Reply');
});

check('ordinary and other classification labels are unchanged', () => {
  assert.equal(notificationTitle(norm(webhookPayload(), 'DISCOVERED_WEBHOOK'), { recovered: true }),
    '🔔 New Instantly Inbound Email');
  const unsub = norm(readbackPayload({ id: 'e-u-1', thread_id: '86-t-u', subject: 'unsubscribe me' }), 'NORMAL_POLL');
  assert.equal(notificationTitle(unsub, { recovered: true }), '🛑 Unsubscribe Request');
});

check('recovery/probable-duplicate safety signals are preserved', () => {
  const record = norm(readbackPayload(), 'NORMAL_POLL');
  assert.equal(notificationTitle(record, { recovered: true, probableDuplicate: true }),
    '⚠️ Probable Duplicate Recovery — 🤖 Automatic Reply');
});

check('discovery source stays in durable state and never reaches the title or card', () => {
  const record = norm(readbackPayload(), 'COMPLETENESS_AUDIT');
  assert.equal(record.discoverySource, 'COMPLETENESS_AUDIT', 'must remain on the record');
  const text = buildNotificationText(record, { recovered: true, campaignName: CAMPAIGN_NAME });
  assert.doesNotMatch(text, /COMPLETENESS_AUDIT|NORMAL_POLL|DISCOVERED_WEBHOOK/);
  assert.doesNotMatch(text, /\(recovered\)/);
});

// --- 9. sanitisation --------------------------------------------------------

check('full prospect email stays visible and hostile names cannot inject card markup', () => {
  const record = {
    ...norm(readbackPayload(), 'NORMAL_POLL'),
    prospectName: '<b>Evil</b>\nSend: yes <script>x</script>',
  };
  const text = buildNotificationText(record, { campaignName: '<img src=x>\nCampaign: Injected' });
  const prospect = text.split('\n').find((l) => l.startsWith('Prospect: '));
  const campaign = text.split('\n').filter((l) => l.startsWith('Campaign: '));
  assert.match(prospect, /noah@example\.com/, 'full email must remain visible');
  assert.doesNotMatch(text, /<b>|<script>|<img/);
  assert.equal(campaign.length, 1, 'a hostile campaign name must not forge a second Campaign line');
  assert.equal(text.split('\n').filter((l) => l.startsWith('Prospect: ')).length, 1);
});

check('a missing mailbox never renders as "(null)" on a routing-incomplete card', () => {
  const record = { ...norm(readbackPayload(), 'NORMAL_POLL'), eaccount: null };
  const text = buildNotificationText(record, { senderName: 'Hamza Moheen', campaignName: CAMPAIGN_NAME });
  assert.match(text, /^Sender mailbox: unavailable$/m);
  assert.doesNotMatch(text, /null/);
  assert.match(text, /Routing incomplete — unavailable: eaccount/);
});

check('sanitised email survives when only the email is known', () => {
  const record = { ...norm(readbackPayload(), 'NORMAL_POLL'), prospectName: null };
  assert.match(buildNotificationText(record, {}), /^Prospect: noah@example\.com$/m);
});

// --- 10. regression ---------------------------------------------------------

check('routing fields, sendAllowed and routing-incomplete warning are unchanged', () => {
  const ordinary = norm(webhookPayload(), 'DISCOVERED_WEBHOOK');
  assert.equal(ordinary.eaccount, 'hamzah@hmzautomation.com');
  assert.equal(ordinary.prospectEmail, 'noah@example.com');
  assert.equal(ordinary.threadId, '86-thread-ordinary');
  assert.equal(ordinary.sendAllowed, true);
  // r13: automatic/OOO replies use the ordinary supervised reply path — the
  // classification selects the label only (see test-auto-ooo-replyable.mjs).
  const auto = norm(readbackPayload(), 'NORMAL_POLL');
  assert.equal(auto.sendAllowed, true, 'automatic replies are reply-eligible');
  assert.match(buildNotificationText(auto, {}), /mention @Instantly/);

  // Routing-incomplete cards keep their safety title and warning.
  const broken = { ...ordinary, eaccount: null };
  assert.equal(isAuthoritativeRoutingComplete(broken), false);
  assert.equal(notificationTitle(broken, { recovered: true }), '⚠️ Instantly Inbound Email — Routing Incomplete');
  const brokenText = buildNotificationText(broken, { campaignName: CAMPAIGN_NAME });
  assert.match(brokenText, /Routing incomplete — unavailable: eaccount/);
  assert.match(brokenText, /Reply sending is unavailable until authoritative routing is recovered\./);
});

check('historical-backfill card copy is unchanged and still has no reply controls', () => {
  const record = norm(readbackPayload(), 'NORMAL_POLL');
  const text = buildNotificationText(record, { historicalBackfill: true, campaignName: CAMPAIGN_NAME });
  assert.match(text, /^\[HISTORICAL BACKFILL — PRE-CONSOLE INSTANTLY EMAIL\]$/m);
  assert.match(text, /Reply controls are disabled for this historical notification\./);
  assert.doesNotMatch(text, /mention @Instantly/);
});

// --- campaign resolver cache ------------------------------------------------

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'card-presentation-'));

await checkAsync('campaign resolver caches one API call per campaign, not per card', async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls++;
    return { status: 200, text: async () => JSON.stringify({ id: CAMPAIGN_UUID, name: CAMPAIGN_NAME }) };
  };
  const opts = { apiKey: 'k', apiBase: 'https://api.example.invalid/v2', fetchImpl };
  const first = await resolveCampaignName(tmp, CAMPAIGN_UUID, opts);
  assert.equal(first.name, CAMPAIGN_NAME);
  assert.equal(first.source, 'API');
  for (let i = 0; i < 25; i++) await resolveCampaignName(tmp, CAMPAIGN_UUID, opts);
  assert.equal(calls, 1, 'subsequent resolutions must be served from the durable cache');
  assert.equal(getCachedCampaignName(tmp, CAMPAIGN_UUID), CAMPAIGN_NAME);
});

await checkAsync('unresolvable campaign is negatively cached and never blocks the card', async () => {
  let calls = 0;
  const fetchImpl = async () => { calls++; return { status: 404, text: async () => '{}' }; };
  const opts = { apiKey: 'k', apiBase: 'https://api.example.invalid/v2', fetchImpl };
  const missing = '00000000-0000-0000-0000-000000000000';
  const first = await resolveCampaignName(tmp, missing, opts);
  assert.equal(first.found, false);
  for (let i = 0; i < 10; i++) await resolveCampaignName(tmp, missing, opts);
  assert.equal(calls, 1, '404 must be cached so a broken campaign cannot storm the API');
  assert.equal(getCachedCampaignName(tmp, missing), '');
});

await checkAsync('resolver makes no request without a campaign id or api key', async () => {
  let calls = 0;
  const fetchImpl = async () => { calls++; return { status: 200, text: async () => '{}' }; };
  assert.equal((await resolveCampaignName(tmp, '', { apiKey: 'k', fetchImpl })).source, 'NO_CAMPAIGN_ID');
  assert.equal((await resolveCampaignName(tmp, 'other-campaign', { fetchImpl })).source, 'NO_KEY');
  assert.equal(calls, 0);
  assert.equal(getCachedCampaignName(tmp, 'other-campaign'), '');
});

await checkAsync('a transient API error keeps serving the last known good name', async () => {
  const opts = (status) => ({
    apiKey: 'k', apiBase: 'https://api.example.invalid/v2',
    fetchImpl: async () => ({ status, text: async () => '{}' }),
    forceRefresh: true,
  });
  const result = await resolveCampaignName(tmp, CAMPAIGN_UUID, opts(500));
  assert.equal(result.name, CAMPAIGN_NAME);
  assert.equal(result.source, 'CACHE_STALE');
});

fs.rmSync(tmp, { recursive: true, force: true });

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) { console.error('failed:', failures.join(', ')); process.exit(1); }
