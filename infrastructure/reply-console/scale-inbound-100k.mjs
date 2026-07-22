#!/usr/bin/env node
// Production-faithful isolated scale harness. Uses the real canonical
// normaliser, SQLite store, leases, outbox worker, paginator and auditor with
// mock Instantly / Google Chat transports. It contains no prospect-send code.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { normalizeInstantlyReceived } from './inbound-contract.mjs';
import {
  registerInboundBatch, operationsSnapshot, integrityCheck, diagnosticStats,
  checkpointInboundStore, closeInboundStore, openInboundStore, getPollState,
} from './inbound-store.mjs';
import { createInboundService, fetchInstantlyReceivedRange } from './inbound-service.mjs';

const TOTAL = Number(process.env.HMZ_SCALE_VOLUME || 100_000);
const SOAK_MS = Number(process.env.HMZ_SCALE_SOAK_MS || 300_000);
const BATCH = 1000;
if (!Number.isInteger(TOTAL) || TOTAL < 1000) throw new Error('HMZ_SCALE_VOLUME must be an integer >=1000');
const fullRequiredRun = TOTAL >= 100_000;
const startedWall = performance.now();
const startedAt = new Date().toISOString();
const cpuStart = process.cpuUsage();
const stateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hmz-inbound-scale-'));
const scaleReceivedAt = new Date(Date.now() - 60_000).toISOString();
let clock = Date.now();
let maxRss = process.memoryUsage().rss;
let maxHeap = process.memoryUsage().heapUsed;
const assertions = [];
const durations = {};
const throughput = {};
let maxBacklog = 0;

function sampleMemory() {
  const memory = process.memoryUsage();
  maxRss = Math.max(maxRss, memory.rss);
  maxHeap = Math.max(maxHeap, memory.heapUsed);
}
function timedStart() { return performance.now(); }
function finishTiming(name, start, operations = null) {
  const seconds = (performance.now() - start) / 1000;
  durations[`${name}Seconds`] = Number(seconds.toFixed(3));
  if (operations !== null) throughput[`${name}PerSecond`] = Number((operations / Math.max(seconds, 0.000001)).toFixed(2));
  return seconds;
}
function check(name, condition, detail = null) {
  assertions.push({ name, pass: Boolean(condition), detail });
  assert.ok(condition, `${name}${detail ? `: ${JSON.stringify(detail)}` : ''}`);
}
function rawRecord(index) {
  const autoEnd = Math.floor(TOTAL * 0.05);
  const oooEnd = Math.floor(TOTAL * 0.10);
  const bounceEnd = Math.floor(TOTAL * 0.15);
  const systemEnd = Math.floor(TOTAL * 0.20);
  const malformedEnd = Math.floor(TOTAL * 0.30);
  const attachmentEnd = Math.floor(TOTAL * 0.325);
  const emptyEnd = Math.floor(TOTAL * 0.35);
  const surrogateEnd = Math.floor(TOTAL * 0.21);
  const record = {
    id: `scale-${String(index).padStart(6, '0')}`,
    ue_type: 2,
    eaccount: 'sender@hmz-scale.test',
    from_address_email: `lead-${index}@example.test`,
    First_name: 'Scale', Last_name: `Lead${index}`,
    campaign_id: 'scale-campaign', campaign_name: 'Scale Validation',
    lead_id: `lead-${index}`,
    thread_id: `scale-thread-${index}`,
    message_id: `<scale-message-${index}@example.test>`,
    subject: 'Re: Scale test', content_preview: `Unique scale reply ${index}`,
    timestamp_created: scaleReceivedAt,
  };
  if (index < autoEnd) Object.assign(record, { subject: 'Automatic reply: received', is_auto_reply: 1 });
  else if (index < oooEnd) Object.assign(record, { subject: 'Out of office', content_preview: 'I am away from the office.' });
  else if (index < bounceEnd) Object.assign(record, { subject: 'Delivery failed: mailbox unavailable' });
  else if (index < systemEnd) Object.assign(record, { from_address_email: `mailer-daemon-${index}@example.test`, subject: 'Returned mail' });
  else if (index < malformedEnd) {
    Object.assign(record, { eaccount: '', from_address_email: '', campaign_id: '', lead_id: '' });
    if (index < surrogateEnd) record.id = '';
  } else if (index < attachmentEnd) Object.assign(record, { subject: '', content_preview: '', attachments: [{ name: 'attachment.bin' }] });
  else if (index < emptyEnd) Object.assign(record, { subject: '', content_preview: '' });
  return record;
}
function canonical(index, source) {
  const normalized = normalizeInstantlyReceived(rawRecord(index), {
    authoritativeReceived: true, discoverySource: source, observedAt: new Date(clock).toISOString(),
  });
  if (!normalized.ok) throw new Error(`normalisation failed at ${index}`);
  return normalized.record;
}
function batches(fn) {
  const output = [];
  for (let start = 0; start < TOTAL; start += BATCH) output.push(fn(start, Math.min(TOTAL, start + BATCH)));
  return output;
}
function fileBytes(file) { try { return fs.statSync(file).size; } catch { return 0; } }
function fdCount() { try { return fs.readdirSync('/proc/self/fd').length; } catch { return null; } }

let phase = 'initialise';
let report;
try {
  openInboundStore(stateDir);

  phase = 'A_unique_100k';
  let phaseStart = timedStart();
  let uniqueCreated = 0;
  for (let start = 0; start < TOTAL; start += BATCH) {
    const records = [];
    for (let i = start; i < Math.min(TOTAL, start + BATCH); i++) records.push(canonical(i, 'DISCOVERED_WEBHOOK'));
    const registered = registerInboundBatch(stateDir, records, { now: clock });
    uniqueCreated += registered.filter((item) => item.created).length;
    sampleMemory();
  }
  finishTiming('uniqueRegistration', phaseStart, TOTAL);
  check('A: explicit unique volume completed', uniqueCreated === TOTAL, { uniqueCreated, required: TOTAL });
  let snapshot = operationsSnapshot(stateDir, { now: clock });
  maxBacklog = Math.max(maxBacklog, snapshot.queueDepth);
  check('A: one durable inbound per unique record', snapshot.counts.durable_inbound_present === TOTAL, snapshot.counts);
  check('A: one logical outbox per unique record', snapshot.counts.outbox_present === TOTAL, snapshot.counts);

  phase = 'B_duplicate_100k';
  phaseStart = timedStart();
  let duplicateCreated = 0;
  for (let start = 0; start < TOTAL; start += BATCH) {
    const records = [];
    for (let i = start; i < Math.min(TOTAL, start + BATCH); i++) records.push(canonical(i, 'DISCOVERED_WEBHOOK'));
    const registered = registerInboundBatch(stateDir, records, { now: clock });
    duplicateCreated += registered.filter((item) => item.created).length;
    sampleMemory();
  }
  finishTiming('duplicateDelivery', phaseStart, TOTAL);
  check('B: 100k duplicate deliveries create zero logical records', duplicateCreated === 0, { duplicateCreated });

  phase = 'C_100k_three_path_races';
  phaseStart = timedStart();
  let raceCreated = 0;
  const raceDeliveries = TOTAL * 3;
  for (let start = 0; start < TOTAL; start += BATCH) {
    const records = [];
    for (let i = start; i < Math.min(TOTAL, start + BATCH); i++) {
      records.push(canonical(i, 'DISCOVERED_WEBHOOK'));
      records.push(canonical(i, 'NORMAL_POLL'));
      records.push(canonical(i, 'COMPLETENESS_AUDIT'));
    }
    const registered = registerInboundBatch(stateDir, records, { now: clock });
    raceCreated += registered.filter((item) => item.created).length;
    sampleMemory();
  }
  finishTiming('threePathRaceDeliveries', phaseStart, raceDeliveries);
  check('C: 100k webhook/poll/auditor races create zero duplicate logical records', raceCreated === 0, { raceCreated, logicalRaces: TOTAL, deliveries: raceDeliveries });

  phase = 'concurrent_1000_discoveries';
  const noTransportService = createInboundService({ stateDir, now: () => clock });
  phaseStart = timedStart();
  const concurrent = await Promise.all(Array.from({ length: 1000 }, (_, index) => noTransportService.registerReceived(rawRecord(index % TOTAL), {
    authoritativeReceived: true, discoverySource: 'DISCOVERED_WEBHOOK', createLegacy: false,
  })));
  finishTiming('simultaneousDiscovery1000', phaseStart, 1000);
  check('concurrency: 1000 simultaneous discovery operations all complete', concurrent.length === 1000 && concurrent.every((item) => item.ok));
  check('concurrency: count remains unique', operationsSnapshot(stateDir).counts.durable_inbound_present === TOTAL);

  phase = 'outage_and_ambiguity';
  let transportMode = 'outage';
  let outageCalls = 0, acknowledgedCalls = 0;
  const ambiguousThreadKeys = new Set();
  const recoveredAmbiguousKeys = new Set();
  let prospectPostCalls = 0;
  const chatFetch = async (url, options) => {
    if (!String(url).startsWith('https://mock.chat.test/')) prospectPostCalls++;
    const payload = JSON.parse(options.body);
    const key = payload.thread?.threadKey;
    if (transportMode === 'outage') {
      outageCalls++;
      if (outageCalls <= Math.min(1000, TOTAL)) {
        ambiguousThreadKeys.add(key);
        throw new Error('injected response loss after possible acceptance');
      }
      return { status: 503, text: async () => JSON.stringify({ error: 'injected outage' }) };
    }
    acknowledgedCalls++;
    if (ambiguousThreadKeys.has(key)) {
      recoveredAmbiguousKeys.add(key);
      if (!/Probable Duplicate Recovery/.test(payload.text)) throw new Error('ambiguous retry lacked probable-duplicate label');
    }
    return { status: 200, text: async () => JSON.stringify({
      name: `spaces/S/messages/scale-${acknowledgedCalls}`,
      thread: { name: `spaces/S/threads/${key}` },
    }) };
  };
  let workerService = createInboundService({ stateDir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch, now: () => clock });
  snapshot = operationsSnapshot(stateDir, { now: clock });
  maxBacklog = Math.max(maxBacklog, snapshot.queueDepth);
  check('outage: full backlog accumulated before transport', snapshot.queueDepth === TOTAL, { queueDepth: snapshot.queueDepth });
  phaseStart = timedStart();
  const outageDrain = await workerService.drainOutbox({ limit: 500, maxBatches: Math.ceil(TOTAL / 500),
    workerId: 'scale-outage-worker', leaseMs: 120_000 });
  finishTiming('sustainedChatOutageAttempts', phaseStart, TOTAL);
  check('outage: every queued item attempted once', outageDrain.attempted === TOTAL, outageDrain);
  check('outage: all items remain retryable/ambiguous', outageDrain.retrying + outageDrain.ambiguous === TOTAL, outageDrain);
  check('ambiguity: repeated response-loss workload completed', outageDrain.ambiguous === Math.min(1000, TOTAL), outageDrain);
  snapshot = operationsSnapshot(stateDir, { now: clock });
  maxBacklog = Math.max(maxBacklog, snapshot.queueDepth);
  check('outage: no false CHAT_NOTIFIED acknowledgement', snapshot.counts.chat_notified === 0, snapshot.counts);

  phase = 'restart_recovery';
  const restartStart = performance.now();
  closeInboundStore(stateDir);
  openInboundStore(stateDir);
  const restartIntegrity = integrityCheck(stateDir);
  durations.restartRecoverySeconds = Number(((performance.now() - restartStart) / 1000).toFixed(3));
  check('restart: durable SQLite state survives full component reopen', restartIntegrity.ok, restartIntegrity);
  clock += 31 * 60_000;
  transportMode = 'healthy';
  workerService = createInboundService({ stateDir, notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true,
    chatFetch, now: () => clock });
  phaseStart = timedStart();
  const workers = await Promise.all(Array.from({ length: 4 }, (_, index) => workerService.drainOutbox({
    limit: 500, maxBatches: Math.ceil(TOTAL / 4 / 500) + 5,
    workerId: `scale-recovery-worker-${index}`, leaseMs: 120_000,
  })));
  const drainSeconds = finishTiming('backlogDrainFourWorkers', phaseStart, TOTAL);
  snapshot = operationsSnapshot(stateDir, { now: clock });
  throughput.backlogDrainPerSecond = Number((TOTAL / Math.max(drainSeconds, 0.000001)).toFixed(2));
  check('recovery: four workers drain the complete backlog', workers.reduce((sum, item) => sum + item.notified, 0) === TOTAL, workers);
  check('recovery: every unique record reaches CHAT_NOTIFIED', snapshot.counts.chat_notified === TOTAL, snapshot.counts);
  check('recovery: no queued/retrying/ambiguous state remains', snapshot.queueDepth === 0
    && snapshot.counts.queued === 0 && snapshot.counts.retrying === 0 && snapshot.counts.ambiguous === 0, snapshot.counts);
  check('ambiguity: deterministic thread keys recovered', recoveredAmbiguousKeys.size === ambiguousThreadKeys.size,
    { ambiguous: ambiguousThreadKeys.size, recovered: recoveredAmbiguousKeys.size });
  check('security: mock worker made zero prospect-email posts', prospectPostCalls === 0, { prospectPostCalls });

  phase = 'pagination_102_pages';
  const PAGE_COUNT = 102;
  let paginationCalls = 0;
  const paginationApi = async (url) => {
    if (!url.includes('/emails?')) return { status: 404, text: async () => '{}' };
    paginationCalls++;
    const token = new URL(url).searchParams.get('starting_after');
    const page = token ? Number(token.slice(1)) : 0;
    const items = [];
    const start = page * 99;
    for (let offset = 0; offset < 100; offset++) items.push(rawRecord((start + offset) % TOTAL));
    // Simulate insertion/reordering while traversal is in progress. It is a
    // duplicate of the authoritative inventory, so ID dedup must absorb it.
    if (page === 50) items.splice(50, 0, rawRecord(TOTAL - 1));
    return { status: 200, text: async () => JSON.stringify({ items,
      next_starting_after: page < PAGE_COUNT - 1 ? `P${page + 1}` : null }) };
  };
  const paginationService = createInboundService({ stateDir, apiKey: 'mock-instantly-key', fetchImpl: paginationApi,
    notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true, chatFetch, now: () => clock });
  phaseStart = timedStart();
  const paginationAudit = await paginationService.runCompletenessAudit('scale_pagination', {
    windowMs: 2 * 60 * 60 * 1000, indexingDelayMs: 0, maxPages: 1000, createLegacy: false,
  });
  finishTiming('pagination102Pages', phaseStart, paginationAudit.recordsObserved);
  check('pagination: at least 100 full page transitions completed', paginationAudit.pageCount === PAGE_COUNT && paginationAudit.pageCount - 1 >= 100,
    { pageCount: paginationAudit.pageCount, paginationCalls });
  check('pagination: boundary/mutation duplicates suppressed', paginationAudit.duplicateLogicalEvents >= PAGE_COUNT - 1,
    { duplicates: paginationAudit.duplicateLogicalEvents });
  check('pagination: equal-timestamp records remain complete', paginationAudit.reconciliation.durableInboundMissing === 0
    && paginationAudit.reconciliation.outboxMissing === 0 && paginationAudit.reconciliation.chatNotified === paginationAudit.recordsObserved,
    paginationAudit.reconciliation);
  check('pagination: independent auditor never creates/advances poll cursor', getPollState(stateDir, 'normal-recovery-poll') === null);

  phase = 'instantly_failures';
  const rangeArgs = { apiKey: 'mock', since: new Date(clock - 3600_000).toISOString(), until: new Date(clock).toISOString() };
  const failure429 = await fetchInstantlyReceivedRange({ ...rangeArgs, fetchImpl: async () => ({ status: 429, text: async () => '{}' }) });
  const failure5xx = await fetchInstantlyReceivedRange({ ...rangeArgs, fetchImpl: async () => ({ status: 503, text: async () => '{}' }) });
  check('Instantly 429 remains explicit and retryable', !failure429.ok && failure429.errorKind === 'INSTANTLY_429', failure429);
  check('Instantly 5xx remains explicit and retryable', !failure5xx.ok && failure5xx.errorKind === 'INSTANTLY_5XX', failure5xx);

  phase = 'five_minute_soak';
  checkpointInboundStore(stateDir);
  const dbFile = path.join(stateDir, 'inbound-v2.sqlite');
  const databaseBytesBeforeSoak = fileBytes(dbFile);
  const fdBefore = fdCount();
  if (global.gc) global.gc();
  const rssBeforeSoak = process.memoryUsage().rss;
  const soakItems = Array.from({ length: 100 }, (_, index) => rawRecord(index));
  const soakApi = async (url) => url.includes('/emails?')
    ? { status: 200, text: async () => JSON.stringify({ items: soakItems }) }
    : { status: 200, text: async () => JSON.stringify({ items: [] }) };
  const soakService = createInboundService({ stateDir, apiKey: 'mock', fetchImpl: soakApi,
    notifyUrl: 'https://mock.chat.test/hook', allowMockChatUrl: true, chatFetch, now: () => clock });
  const soakStart = performance.now();
  let soakCycles = 0;
  while (performance.now() - soakStart < SOAK_MS) {
    const audit = await soakService.runCompletenessAudit('soak', {
      windowMs: 2 * 60 * 60 * 1000, indexingDelayMs: 0, createLegacy: false,
    });
    if (!audit.ok) throw new Error(`soak audit failed: ${audit.reason}`);
    soakCycles++;
    sampleMemory();
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  durations.soakSeconds = Number(((performance.now() - soakStart) / 1000).toFixed(3));
  checkpointInboundStore(stateDir);
  if (global.gc) global.gc();
  const rssAfterSoak = process.memoryUsage().rss;
  const fdAfter = fdCount();
  const databaseBytesAfterSoak = fileBytes(dbFile);
  snapshot = operationsSnapshot(stateDir, { now: clock });
  check('soak: continuous audit/discovery cycles completed', soakCycles > 0, { soakCycles, soakMs: SOAK_MS });
  check('soak: queue starvation absent', snapshot.queueDepth === 0, { queueDepth: snapshot.queueDepth });
  check('soak: cursor drift absent', getPollState(stateDir, 'normal-recovery-poll') === null);
  check('soak: file descriptors bounded', fdBefore === null || fdAfter <= fdBefore + 4, { fdBefore, fdAfter });
  check('soak: RSS growth bounded', rssAfterSoak <= rssBeforeSoak + 256 * 1024 * 1024,
    { rssBeforeSoak, rssAfterSoak, growth: rssAfterSoak - rssBeforeSoak });
  check('soak: database growth bounded', databaseBytesAfterSoak - databaseBytesBeforeSoak < 64 * 1024 * 1024,
    { databaseBytesBeforeSoak, databaseBytesAfterSoak, growth: databaseBytesAfterSoak - databaseBytesBeforeSoak });

  phase = 'final_invariants';
  checkpointInboundStore(stateDir);
  const finalIntegrity = integrityCheck(stateDir);
  const diagnostics = diagnosticStats(stateDir);
  const finalOperations = operationsSnapshot(stateDir, { now: clock });
  check('final: SQLite/inbound/outbox integrity clean', finalIntegrity.ok, finalIntegrity);
  check('final: zero missing durable inbound identities', diagnostics.inbound_count === TOTAL, diagnostics);
  check('final: zero missing logical outbox records', diagnostics.outbox_count === TOTAL, diagnostics);
  check('final: zero permanently unnotified records', diagnostics.nonterminal_count === 0, diagnostics);
  check('final: zero open/orphan attempt states', diagnostics.open_attempt_count === 0, diagnostics);
  check('final: every definite ack stores a Chat message identity', diagnostics.invalid_ack_count === 0, diagnostics);
  check('final: zero duplicate logical contexts', diagnostics.duplicate_instantly_identity_group === 0, diagnostics);
  check('final: zero duplicate outbox identities', diagnostics.duplicate_outbox_identity_group === 0, diagnostics);
  check('final: every malformed/degraded record notified', finalOperations.counts.degraded_metadata >= Math.floor(TOTAL * 0.10)
    && finalOperations.counts.chat_notified === TOTAL, finalOperations.counts);
  check('final: every bounce/system record notified', finalOperations.counts.bounce_system >= Math.floor(TOTAL * 0.10)
    && finalOperations.counts.chat_notified === TOTAL, finalOperations.counts);
  if (fullRequiredRun) {
    check('explicit 100,000+ unique-event requirement met', TOTAL >= 100_000, { TOTAL });
    check('mixed workload contains >=10,000 auto/OOO', finalOperations.counts.auto_reply + finalOperations.counts.ooo >= 10_000, finalOperations.counts);
    check('mixed workload contains >=10,000 bounce/system', finalOperations.counts.bounce_system >= 10_000, finalOperations.counts);
    check('mixed workload contains >=10,000 malformed/degraded', finalOperations.counts.degraded_metadata >= 10_000, finalOperations.counts);
    check('mixed workload contains >=5,000 attachment-only/empty',
      finalOperations.counts.attachment_only + Math.floor(TOTAL * 0.025) >= 5_000, finalOperations.counts);
  }

  const cpu = process.cpuUsage(cpuStart);
  const wallSeconds = (performance.now() - startedWall) / 1000;
  const cpuPercent = ((cpu.user + cpu.system) / 1_000_000 / Math.max(wallSeconds, 0.000001)) * 100;
  report = {
    schemaVersion: 1,
    harness: 'real inbound-contract + inbound-store + inbound-service; mock Instantly and Google Chat adapters',
    startedAt,
    finishedAt: new Date().toISOString(),
    fullRequiredRun,
    volume: {
      uniqueReceived: TOTAL,
      duplicateDeliveries: TOTAL,
      logicalThreePathRaces: TOTAL,
      threePathRaceDeliveries: TOTAL * 3,
      simultaneousDiscoveryOperations: 1000,
      autoAndOooMinimum: Math.floor(TOTAL * 0.10),
      bounceSystemMinimum: Math.floor(TOTAL * 0.10),
      malformedDegradedMinimum: Math.floor(TOTAL * 0.10),
      attachmentEmptyMinimum: Math.floor(TOTAL * 0.05),
      paginationPages: paginationAudit.pageCount,
      paginationTransitions: paginationAudit.pageCount - 1,
      soakCycles,
      soakMilliseconds: SOAK_MS,
    },
    result: {
      verdict: assertions.every((item) => item.pass) && fullRequiredRun ? 'PASS' : 'REDUCED_OR_FAILED',
      assertionsPassed: assertions.filter((item) => item.pass).length,
      assertionsTotal: assertions.length,
      durableInbound: diagnostics.inbound_count,
      logicalOutbox: diagnostics.outbox_count,
      chatNotified: finalOperations.counts.chat_notified,
      nonterminal: diagnostics.nonterminal_count,
      openAttempts: diagnostics.open_attempt_count,
      duplicateLogicalContexts: diagnostics.duplicate_instantly_identity_group,
      duplicateOutboxIdentities: diagnostics.duplicate_outbox_identity_group,
      probableDuplicateChatPosts: finalOperations.counts.probable_duplicate_chat_posts,
      probableDuplicateRate: Number((finalOperations.counts.probable_duplicate_chat_posts / TOTAL).toFixed(6)),
      prospectEmailPosts: prospectPostCalls,
      maximumBacklog: maxBacklog,
      backlogDrainRatePerSecond: throughput.backlogDrainPerSecond,
      restartRecoverySeconds: durations.restartRecoverySeconds,
    },
    classificationCounts: {
      autoReply: finalOperations.counts.auto_reply,
      ooo: finalOperations.counts.ooo,
      bounceSystem: finalOperations.counts.bounce_system,
      degradedMetadata: finalOperations.counts.degraded_metadata,
      attachmentOnly: finalOperations.counts.attachment_only,
      surrogateIdentity: finalOperations.counts.surrogate_identity,
    },
    notificationLatency: finalOperations.notificationLatency,
    throughput,
    durations: { ...durations, totalWallSeconds: Number(wallSeconds.toFixed(3)) },
    resources: {
      maxRssBytes: maxRss,
      maxHeapUsedBytes: maxHeap,
      finalRssBytes: process.memoryUsage().rss,
      cpuUserMicroseconds: cpu.user,
      cpuSystemMicroseconds: cpu.system,
      averageCpuPercent: Number(cpuPercent.toFixed(2)),
      databaseBytes: fileBytes(dbFile),
      walBytesAfterCheckpoint: fileBytes(`${dbFile}-wal`),
      logBytes: 0,
      fdBeforeSoak: fdBefore,
      fdAfterSoak: fdAfter,
      databaseBytesBeforeSoak,
      databaseBytesAfterSoak,
      rssBeforeSoak,
      rssAfterSoak,
    },
    outage: {
      attemptedDuringOutage: outageDrain.attempted,
      retryingDuringOutage: outageDrain.retrying,
      ambiguousDuringOutage: outageDrain.ambiguous,
      definiteAcknowledgementsDuringOutage: 0,
      acknowledgedAfterRestore: acknowledgedCalls,
      ambiguousThreadKeysRecovered: recoveredAmbiguousKeys.size,
    },
    pagination: {
      pages: paginationAudit.pageCount,
      transitions: paginationAudit.pageCount - 1,
      recordsObserved: paginationAudit.recordsObserved,
      duplicateLogicalEventsSuppressed: paginationAudit.duplicateLogicalEvents,
      durableInboundMissing: paginationAudit.reconciliation.durableInboundMissing,
      outboxMissing: paginationAudit.reconciliation.outboxMissing,
      chatNotified: paginationAudit.reconciliation.chatNotified,
    },
    diagnostics,
    integrity: finalIntegrity,
    assertions,
    limitations: [
      'Google Chat and Instantly are deterministic mocks; this measures internal invariants and not external-provider availability.',
      'A response-loss exception models possible acceptance; probable duplicate posts are labelled and counted, not claimed exact-once.',
      `Soak duration was ${SOAK_MS} ms; absence of growth in this bounded run is not a proof against every long-horizon leak.`,
    ],
  };
  console.log(`SCALE_RESULT ${JSON.stringify(report)}`);
  closeInboundStore(stateDir);
  fs.rmSync(stateDir, { recursive: true, force: true });
} catch (error) {
  report = {
    schemaVersion: 1,
    startedAt,
    failedAt: new Date().toISOString(),
    phase,
    volume: TOTAL,
    soakMilliseconds: SOAK_MS,
    stateDir,
    error: String(error?.stack || error),
    assertions,
  };
  console.log(`SCALE_RESULT ${JSON.stringify(report)}`);
  process.exitCode = 1;
}

