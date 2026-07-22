import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { normalizeInstantlyReceived } from './inbound-contract.mjs';
import {
  OUTBOX_STATES,
  closeInboundStore,
  createHistoricalBackfillPlan,
  getNotification,
  historicalBackfillStatus,
  inboundIdentitySetSha256,
  operationsSnapshot,
  releaseNextHistoricalBackfill,
} from './inbound-store.mjs';
import { createInboundService } from './inbound-service.mjs';

let passed = 0;
const output = [];
async function test(name, fn) {
  try { await fn(); passed++; output.push(`PASS  ${name}`); }
  catch (error) { output.push(`FAIL  ${name} :: ${error.stack || error}`); }
}
function response(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}
function raw(id, second) {
  return {
    id,
    ue_type: 2,
    eaccount: 'owner-sender@example.test',
    from_address_email: `owner-recipient-${second}@example.test`,
    campaign_id: 'controlled-campaign',
    campaign_name: 'Controlled campaign',
    thread_id: `thread-${second}`,
    message_id: `<historical-${second}@example.test>`,
    subject: `Historical subject ${second}`,
    content_preview: `HISTORICAL-BODY-MUST-NOT-APPEAR-${second}`,
    timestamp_created: `2026-01-01T00:00:0${second}.000Z`,
  };
}

await test('authorized historical plan releases one acknowledged notification at a time with durable pacing', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-historical-release-'));
  let clock = 1_000_000;
  const posts = [];
  const service = createInboundService({
    stateDir: dir,
    notificationEpoch: '2026-07-18T18:33:00.000Z',
    notifyUrl: 'https://mock.chat.test/hook',
    allowMockChatUrl: true,
    now: () => clock,
    chatFetch: async (_url, options) => {
      posts.push(JSON.parse(options.body));
      return response(200, { name: `spaces/H/messages/${posts.length}`, thread: { name: `spaces/H/threads/${posts.length}` } });
    },
  });
  const identities = [];
  for (let i = 1; i <= 3; i++) {
    const registered = await service.registerReceived(raw(`historical-${i}`, i), {
      authoritativeReceived: true,
      discoverySource: 'EXPLICIT_BACKFILL',
      recovered: true,
      createLegacy: false,
    });
    identities.push(registered.record.identity);
    assert.equal(registered.outbox.state, OUTBOX_STATES.HISTORICAL_HOLD);
  }

  const rangeEnd = '2026-01-31T23:59:59.999Z';
  const current = await service.registerReceived({
    ...raw('current-after-manifest', 4),
    timestamp_created: '2026-02-01T00:00:00.000Z',
  }, {
    authoritativeReceived: true,
    discoverySource: 'WEBHOOK',
    createLegacy: false,
  });
  assert.equal(current.outbox.state, OUTBOX_STATES.HISTORICAL_HOLD);
  const manifest = inboundIdentitySetSha256(dir, { rangeEnd });
  assert.equal(createHistoricalBackfillPlan(dir, {
    manifestSha256: '0'.repeat(64), rangeEnd, expectedTotalInbound: 3, expectedBackfillCount: 3, now: clock,
  }).reason, 'AUTHORIZED_MANIFEST_MISMATCH');
  const plan = createHistoricalBackfillPlan(dir, {
    manifestSha256: manifest, rangeEnd, expectedTotalInbound: 3, expectedBackfillCount: 3,
    minIntervalMs: 12_500, now: clock,
  });
  assert.equal(plan.ok, true);
  assert.equal(plan.created, true);
  assert.equal(plan.itemCount, 3);
  assert.equal(plan.rangeEnd, rangeEnd);

  const first = releaseNextHistoricalBackfill(dir, manifest, { now: clock });
  assert.equal(first.action, 'RELEASED_ONE');
  assert.equal(first.sequence, 1);
  const raced = releaseNextHistoricalBackfill(dir, manifest, { now: clock });
  assert.equal(raced.action, 'WAITING_FOR_ACKNOWLEDGEMENT');
  assert.equal(getNotification(dir, identities[0]).historicalBackfill, true);
  assert.equal((await service.drainOutbox({ limit: 25, maxBatches: 1 })).notified, 1);
  assert.match(posts[0].text, /^\[HISTORICAL BACKFILL — PRE-CONSOLE INSTANTLY EMAIL\]/);
  assert.match(posts[0].text, /predates the Google Chat console/);
  assert.match(posts[0].text, /Reply controls are disabled/);
  assert.doesNotMatch(posts[0].text, /mention @Instantly/);
  assert.doesNotMatch(posts[0].text, /HISTORICAL-BODY-MUST-NOT-APPEAR/);

  clock += 12_499;
  assert.equal(releaseNextHistoricalBackfill(dir, manifest, { now: clock }).action, 'WAITING_FOR_RATE_LIMIT');
  closeInboundStore(dir);
  clock += 1;
  const second = releaseNextHistoricalBackfill(dir, manifest, { now: clock });
  assert.equal(second.action, 'RELEASED_ONE');
  assert.equal(second.sequence, 2);
  assert.equal((await service.drainOutbox({ limit: 25, maxBatches: 1 })).notified, 1);

  clock += 12_500;
  const third = releaseNextHistoricalBackfill(dir, manifest, { now: clock });
  assert.equal(third.action, 'RELEASED_ONE');
  assert.equal(third.sequence, 3);
  assert.equal((await service.drainOutbox({ limit: 25, maxBatches: 1 })).notified, 1);
  const status = historicalBackfillStatus(dir, manifest);
  assert.equal(status.ok, true);
  assert.equal(status.complete, true);
  assert.equal(status.notifiedCount, 3);
  assert.equal(status.activeCount, 0);
  assert.equal(status.remainingHoldCount, 0);
  assert.equal(posts.length, 3);
  const operations = operationsSnapshot(dir, { now: clock });
  assert.equal(operations.historicalBackfillPlans[0].state, 'COMPLETE');
  assert.equal(operations.counts.historical_backfill_notified, 3);
  closeInboundStore(dir);
  fs.rmSync(dir, { recursive: true, force: true });
});

for (const line of output) console.log(line);
console.log(`\n${passed}/${output.length} historical-backfill tests passed`);
if (passed !== output.length) process.exitCode = 1;
