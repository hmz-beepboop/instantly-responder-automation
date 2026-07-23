// r11 card-state semantics: authoritative routing safety and optional
// enrichment are separate. Covers requirement cases A–F.
import assert from 'node:assert/strict';
import {
  normalizeInstantlyReceived, buildNotificationText, notificationTitle,
  isAuthoritativeRoutingComplete, missingRoutingFields,
} from './inbound-contract.mjs';

let passed = 0; const out = [];
function t(name, fn) { try { fn(); passed++; out.push('PASS  ' + name); } catch (e) { out.push('FAIL  ' + name + ' :: ' + (e.stack || e)); } }

const raw = (over = {}) => ({
  id: 'e-' + Math.random().toString(16).slice(2), ue_type: 2,
  eaccount: 'hamzah@hmzautomation.com', from_address_email: 'alinazahidkhan890@gmail.com',
  campaign_id: '860453af', campaign_name: 'Acceptance R2', lead: 'L1', lead_id: 'L1',
  thread_id: 'th-1', message_id: '<m@x>', subject: 'Re: Capacity Question',
  content_preview: 'sounds good', timestamp_created: '2026-07-22T00:00:00.000Z', ...over,
});
const rec = (over) => normalizeInstantlyReceived(raw(over), { authoritativeReceived: true, discoverySource: 'TEST' }).record;

// A. campaign UNKNOWN (no campaign_name/id) but complete authoritative routing
t('A: routing complete + campaign unknown → no routing warning, Send permitted', () => {
  const r = rec({ campaign_name: '', campaign_id: '' });
  assert.equal(isAuthoritativeRoutingComplete(r), true);
  assert.equal(r.sendAllowed, true, 'send eligible despite unknown campaign');
  const text = buildNotificationText(r, { senderName: 'Hamza Moheen' });
  assert.doesNotMatch(text, /Metadata Incomplete/);
  assert.doesNotMatch(text, /Routing Incomplete/);
  assert.doesNotMatch(text, /sending is unavailable until authoritative routing/i);
  assert.match(text, /^Campaign: Unknown$/m);                  // r12: concise inline fallback
  assert.doesNotMatch(text, /Campaign details unavailable/);   // r12: no warning paragraph
  assert.match(text, /mention @Instantly/);                    // Send offered
  assert.doesNotMatch(notificationTitle(r), /Incomplete/);     // no warning header
});

// B. missing prospect email → routing warning, no Send
t('B: missing prospect email → routing incomplete, Send blocked', () => {
  const r = rec({ from_address_email: '' });
  assert.equal(isAuthoritativeRoutingComplete(r), false);
  assert.deepEqual(missingRoutingFields(r).includes('prospect_email'), true);
  assert.equal(r.sendAllowed, false);
  const text = buildNotificationText(r, {});
  assert.match(text, /Routing Incomplete|Routing incomplete/);
  assert.doesNotMatch(text, /mention @Instantly/);
});

// C. missing eaccount → routing warning, no Send
t('C: missing eaccount → routing incomplete, Send blocked', () => {
  const r = rec({ eaccount: '' });
  assert.equal(isAuthoritativeRoutingComplete(r), false);
  assert.equal(missingRoutingFields(r).includes('eaccount'), true);
  assert.equal(r.sendAllowed, false);
  assert.doesNotMatch(buildNotificationText(r, {}), /mention @Instantly/);
});

// D. missing reply_to_uuid/thread (no instantly id AND no thread) → routing warning
t('D: no instantly id and no thread → routing incomplete, Send blocked', () => {
  const r = rec({ id: '', thread_id: '', message_id: '' });
  assert.equal(isAuthoritativeRoutingComplete(r), false);
  assert.equal(r.sendAllowed, false);
  assert.match(buildNotificationText(r, {}), /Routing incomplete/i);
});

// D2. thread missing but instantly id present → routing STILL complete (resolved at send)
t('D2: thread missing but instantly id present → routing complete', () => {
  const r = rec({ thread_id: '' });
  assert.equal(isAuthoritativeRoutingComplete(r), true);
  assert.equal(r.sendAllowed, true);
  assert.doesNotMatch(buildNotificationText(r, {}), /Routing incomplete/i);
});

// E. optional prospect display name missing but email present → email fallback, not routing-incomplete
t('E: prospect name missing → email fallback, routing complete', () => {
  const r = rec(); r.prospectName = null;
  assert.equal(isAuthoritativeRoutingComplete(r), true);
  const text = buildNotificationText(r, { senderName: 'Hamza Moheen' });
  assert.match(text, /alinazahidkhan890@gmail\.com/);
  assert.doesNotMatch(text, /Routing incomplete/i);
});

// F. optional mailbox display name missing but eaccount present → address fallback, not routing-incomplete
t('F: mailbox display name missing → address fallback, routing complete', () => {
  const r = rec();
  const text = buildNotificationText(r, {}); // no senderName
  assert.match(text, /Sender mailbox: hamzah@hmzautomation\.com/);
  assert.doesNotMatch(text, /Routing incomplete/i);
});

// Guard: degradedMetadata (optional gaps) alone must NOT produce a routing warning
t('optional-only gaps (lead/message missing) → no routing warning, Send permitted', () => {
  const r = rec({ lead: '', lead_id: '', message_id: '' });
  assert.equal(r.degradedMetadata, true);                 // still flagged for telemetry
  assert.equal(isAuthoritativeRoutingComplete(r), true);  // but routing is complete
  assert.equal(r.sendAllowed, true);
  const text = buildNotificationText(r, { senderName: 'Hamza Moheen' });
  assert.doesNotMatch(text, /Metadata Incomplete/);
  assert.doesNotMatch(text, /Routing incomplete/i);
  assert.match(text, /mention @Instantly/);
});

for (const line of out) console.log(line);
console.log(`\n${passed}/${out.length} card-state tests passed`);
if (passed !== out.length) process.exitCode = 1;
