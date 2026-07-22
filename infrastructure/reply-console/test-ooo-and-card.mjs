// Targeted tests for r10: (1) OOO regex catches "out of the office";
// (2) live notification card shows the prospect's full email and the sending
// mailbox display name; (3) historical card stays redacted (no email/name change).
import assert from 'node:assert/strict';
import { normalizeInstantlyReceived, buildNotificationText, LABELS } from './inbound-contract.mjs';

let passed = 0; const out = [];
function t(name, fn) { try { fn(); passed++; out.push('PASS  ' + name); } catch (e) { out.push('FAIL  ' + name + ' :: ' + (e.stack || e)); } }

const raw = (over = {}) => ({
  id: 'e-' + Math.random().toString(16).slice(2), ue_type: 2,
  eaccount: 'hamzah@hmzautomation.com', from_address_email: 'alinazahidkhan890@gmail.com',
  campaign_id: 'c1', thread_id: 'th1', message_id: '<m@x>', subject: 'Re: Capacity Question',
  content_preview: 'hello there', timestamp_created: '2026-07-22T00:00:00.000Z', ...over,
});
const rec = (over) => normalizeInstantlyReceived(raw(over), { authoritativeReceived: true, discoverySource: 'TEST' }).record;

// (1) OOO classification
t('classifies "out of the office" as OOO (the proven gap)', () => {
  const r = rec({ content_preview: 'I am out of the office and not at my desk at the moment.' });
  assert.equal(r.classification, LABELS.OOO);
});
t('still classifies "out of office" (no the) as OOO', () => {
  assert.equal(rec({ content_preview: 'Currently out of office until Monday.' }).classification, LABELS.OOO);
});
t('ordinary reply stays ordinary (no false OOO)', () => {
  assert.equal(rec({ content_preview: 'Sounds good, tell me more.' }).classification, LABELS.ORDINARY);
});

// (2) live card shows full prospect email + mailbox display name
t('live card shows prospect FULL EMAIL (not stripped)', () => {
  const r = rec({}); r.prospectName = 'Ella Brooks';
  const text = buildNotificationText(r, { senderName: 'Hamza Moheen' });
  assert.match(text, /alinazahidkhan890@gmail\.com/);
  assert.match(text, /Ella Brooks/);
});
t('live card shows sending mailbox DISPLAY NAME + address', () => {
  const r = rec({}); r.prospectName = 'Ella Brooks';
  const text = buildNotificationText(r, { senderName: 'Hamza Moheen' });
  assert.match(text, /Sender mailbox: Hamza Moheen \(hamzah@hmzautomation\.com\)/);
});
t('live card falls back to mailbox address when no display name', () => {
  const text = buildNotificationText(rec({}), {});
  assert.match(text, /Sender mailbox: hamzah@hmzautomation\.com/);
});

// (3) historical card unchanged (redacted; ignores senderName)
t('historical card still uses its own redacted format', () => {
  const r = rec({}); r.prospectName = 'Ella Brooks';
  const text = buildNotificationText(r, { historicalBackfill: true, senderName: 'Hamza Moheen' });
  assert.match(text, /\[HISTORICAL BACKFILL — PRE-CONSOLE INSTANTLY EMAIL\]/);
  assert.match(text, /Reply controls are disabled/);
  assert.doesNotMatch(text, /Hamza Moheen \(/); // historical Sender mailbox line is address-only
});

for (const line of out) console.log(line);
console.log(`\n${passed}/${out.length} ooo-and-card tests passed`);
if (passed !== out.length) process.exitCode = 1;
