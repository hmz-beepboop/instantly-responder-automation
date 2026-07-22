// Targeted tests for the permanent historical defence-in-depth guard.
// Historical (EXPLICIT_BACKFILL or pre-epoch) records must never create
// tokens/drafts, expose Send/Edit, arm, or invoke the reply endpoint.
// Live (post-epoch) records must remain fully actionable (no false positives).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import * as S from './store.mjs';

const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rc-guard-'));
let passed = 0; const out = [];
function t(name, fn) { try { fn(); passed++; out.push('PASS  ' + name); } catch (e) { out.push('FAIL  ' + name + ' :: ' + (e.stack || e)); } }

const live = (over = {}) => ({
  replyToUuid: 'uuid-' + Math.random().toString(16).slice(2), eaccount: 'sender@owner.test',
  prospectEmail: Math.random().toString(16).slice(2) + '@corp.test', subject: 'Re: q',
  uniboxUrl: 'https://app.instantly.ai/app/unibox?x=1', receivedAt: '2026-07-21T13:00:00.000Z',
  discoverySource: 'DISCOVERED_WEBHOOK', sourcePayloadHash: 'abc', ...over,
});
const ctxFile = (id) => path.join(base, 'contexts', id + '.json');
const makeHistoricalInPlace = (id) => { const j = JSON.parse(fs.readFileSync(ctxFile(id), 'utf8')); j.discoverySource = 'EXPLICIT_BACKFILL'; fs.writeFileSync(ctxFile(id), JSON.stringify(j)); };

t('isHistoricalActor: EXPLICIT_BACKFILL => true', () => assert.equal(S.isHistoricalActor({ discoverySource: 'EXPLICIT_BACKFILL' }), true));
t('isHistoricalActor: pre-epoch => true', () => assert.equal(S.isHistoricalActor({ receivedAt: '2026-03-01T00:00:00.000Z' }), true));
t('isHistoricalActor: post-epoch live => false', () => assert.equal(S.isHistoricalActor({ discoverySource: 'DISCOVERED_WEBHOOK', receivedAt: '2026-07-21T13:00:00.000Z' }), false));

t('createContext BLOCKS EXPLICIT_BACKFILL', () => {
  const r = S.createContext(base, live({ discoverySource: 'EXPLICIT_BACKFILL' }));
  assert.equal(r.ok, false); assert.equal(r.reason, 'HISTORICAL_NON_ACTIONABLE');
});
t('createContext BLOCKS pre-epoch receivedAt', () => {
  const r = S.createContext(base, live({ receivedAt: '2026-02-01T00:00:00.000Z' }));
  assert.equal(r.ok, false); assert.equal(r.reason, 'HISTORICAL_NON_ACTIONABLE');
});

let liveId, hist;
t('createContext ALLOWS live (no false positive)', () => {
  const r = S.createContext(base, live()); assert.equal(r.ok, true); assert.equal(r.created, true);
  liveId = r.context.notificationId;
});
t('live context CAN draft (guard no false positive)', () => {
  const d = S.createDraft(base, liveId, { body: 'Hello, happy to help. Best, HMZ', author: 'owner' });
  assert.equal(d.ok, true); assert.ok(d.reviewToken);
});

t('setup: a live context then flip to historical on disk', () => {
  const r = S.createContext(base, live()); hist = r.context.notificationId; makeHistoricalInPlace(hist);
});
t('createDraft BLOCKED on historical context', () => {
  const r = S.createDraft(base, hist, { body: 'nope', author: 'owner' });
  assert.equal(r.ok, false); assert.equal(r.reason, 'HISTORICAL_NON_ACTIONABLE');
});
t('validateReview BLOCKED on historical context', () => {
  const r = S.validateReview(base, hist, { reviewToken: 'x', bodyHash: 'y' });
  assert.equal(r.ok, false); assert.equal(r.reason, 'HISTORICAL_NON_ACTIONABLE');
});
t('performSend BLOCKED on historical context (no POST)', async () => {
  const r = await S.performSend(base, hist, { reviewToken: 'x', bodyHash: 'y' },
    { apiKey: 'K', fetchImpl: () => { throw new Error('MUST_NOT_POST'); } });
  assert.equal(r.ok, false); assert.equal(r.acquired, false); assert.equal(r.reason, 'HISTORICAL_NON_ACTIONABLE');
});
t('setGoLive REFUSES to arm a historical context', () => {
  const gl = S.setGoLive(base, true, 'arm-test', { contextId: hist, revision: 1 });
  assert.equal(gl.armedContextId, null);
});
t('setGoLive CAN arm a live context (no false positive)', () => {
  const gl = S.setGoLive(base, true, 'arm-live', { contextId: liveId, revision: 1 });
  assert.equal(gl.armedContextId, liveId);
});

for (const line of out) console.log(line);
console.log(`\n${passed}/${out.length} historical-guard tests passed`);
if (passed !== out.length) process.exitCode = 1;
fs.rmSync(base, { recursive: true, force: true });
