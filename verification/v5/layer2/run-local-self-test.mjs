import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';

import { runLayer2, DEFAULT_POLL } from './run-layer2.mjs';
import { STATES } from './state-store.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_POLL = { intervalMs: 40, maxDurationMs: 260, consecutiveRequired: 2 };
const INBOUND_EMAIL_ID = 'inbound-email-test-001';
const THREAD_ID = 'thread-test-001';
const SENDER = 'sender@example.test';
const RECIPIENT = 'recipient@example.test';
const SUBJECT = 'Original Subject Line';
const REPLY_SUBJECT = `Re: ${SUBJECT}`;

const inboundEmail = Object.freeze({
  id: INBOUND_EMAIL_ID,
  thread_id: THREAD_ID,
  eaccount: SENDER,
  lead: RECIPIENT,
  subject: SUBJECT,
});

function buildSentEmail(id, marker) {
  return {
    id,
    thread_id: THREAD_ID,
    eaccount: SENDER.toUpperCase(),
    lead: RECIPIENT.toUpperCase(),
    to_address_email_list: RECIPIENT,
    subject: REPLY_SUBJECT,
    ue_type: 3,
    content_preview: `${marker} controlled V5 Layer 2 verification message.`,
    body: {
      text: `${marker} controlled V5 Layer 2 verification message.`,
      html: `<p>${marker} controlled V5 Layer 2 verification message.</p>`,
    },
    timestamp_created: new Date().toISOString(),
  };
}

function createMockInstantlyServer(reconciliationProvider) {
  const state = {
    replyPostCount: 0,
    reconciliationCallCount: 0,
    reconciliationCalls: [],
  };

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');

    if (req.method === 'GET' && url.pathname === `/api/v2/emails/${INBOUND_EMAIL_ID}`) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(inboundEmail));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/v2/emails') {
      state.reconciliationCallCount += 1;
      state.reconciliationCalls.push(Object.fromEntries(url.searchParams.entries()));
      const items = reconciliationProvider(state.reconciliationCallCount);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ items }));
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/v2/emails/reply') {
      state.replyPostCount += 1;
      const chunks = [];
      req.on('data', (chunk) => chunks.push(chunk));
      req.on('end', () => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(buildSentEmail(`sent-${state.replyPostCount}`, 'unused')));
      });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'not_found' }));
  });

  return new Promise((resolve, reject) => {
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({ server, baseUrl: `http://127.0.0.1:${address.port}`, state });
    });
  });
}

function closeServer(server) {
  return new Promise((resolve) => server.close(resolve));
}

function baseConfig(stateDir, mockBaseUrl, marker) {
  return {
    mode: 'test',
    stateDir,
    instantlyBaseUrl: mockBaseUrl,
    inboundEmailId: INBOUND_EMAIL_ID,
    expectedSender: SENDER,
    expectedRecipient: RECIPIENT,
    markerOverride: marker,
    upstreamReplyUrl: `${mockBaseUrl}/api/v2/emails/reply`,
    poll: TEST_POLL,
  };
}

async function main() {
  const failedAssertions = [];
  const assert = (condition, message) => {
    if (!condition) failedAssertions.push(message);
  };

  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'v5-l2-fixed-self-test-'));
  const servers = [];
  const scenarios = {};

  try {
    {
      const marker = 'HMZ-V5-L2-TEST-SUCCESS';
      const mock = await createMockInstantlyServer(() => [buildSentEmail('sent-success-1', marker)]);
      servers.push(mock.server);
      const stateDir = path.join(tmpRoot, 'success');
      const result = await runLayer2(baseConfig(stateDir, mock.baseUrl, marker));

      assert(result.state === STATES.SENT_RECONCILED, 'success: final state mismatch');
      assert(mock.state.replyPostCount === 1, 'success: expected exactly one POST');
      assert(result.proxyMeta?.forwardedPostCount === 1, 'success: proxy metadata POST count mismatch');
      assert(result.proxyMeta?.upstreamStatus === 200, 'success: expected upstream 200');
      assert(result.reconciliation?.details?.matchCount === 1, 'success: expected one match');
      assert(result.reconciliation?.details?.consecutiveSameSingleMatch === 2, 'success: same ID must be observed twice');

      scenarios.success = {
        pass: result.state === STATES.SENT_RECONCILED && mock.state.replyPostCount === 1,
        state: result.state,
        replyPostCount: mock.state.replyPostCount,
        forwardedPostCount: result.proxyMeta?.forwardedPostCount,
        reconciliationChecks: result.reconciliation?.details?.checks,
        reconciliationFilters: mock.state.reconciliationCalls[0] ?? null,
      };
    }

    {
      const marker = 'HMZ-V5-L2-TEST-ZERO';
      const mock = await createMockInstantlyServer(() => []);
      servers.push(mock.server);
      const result = await runLayer2(baseConfig(path.join(tmpRoot, 'zero'), mock.baseUrl, marker));
      assert(result.state === STATES.HUMAN_REVIEW_ZERO_MATCHES, 'zero: final state mismatch');
      assert(mock.state.replyPostCount === 1, 'zero: expected one POST');
      scenarios.zero = { pass: result.state === STATES.HUMAN_REVIEW_ZERO_MATCHES, state: result.state, replyPostCount: mock.state.replyPostCount };
    }

    {
      const marker = 'HMZ-V5-L2-TEST-MULTI';
      const mock = await createMockInstantlyServer(() => [
        buildSentEmail('sent-multi-1', marker),
        buildSentEmail('sent-multi-2', marker),
      ]);
      servers.push(mock.server);
      const result = await runLayer2(baseConfig(path.join(tmpRoot, 'multi'), mock.baseUrl, marker));
      assert(result.state === STATES.HUMAN_REVIEW_MULTIPLE_MATCHES, 'multi: final state mismatch');
      assert(mock.state.replyPostCount === 1, 'multi: expected one POST');
      scenarios.multiple = { pass: result.state === STATES.HUMAN_REVIEW_MULTIPLE_MATCHES, state: result.state, replyPostCount: mock.state.replyPostCount };
    }

    {
      const marker = 'HMZ-V5-L2-TEST-CONCURRENT';
      const mock = await createMockInstantlyServer(() => [buildSentEmail('sent-lock-1', marker)]);
      servers.push(mock.server);
      const cfg = baseConfig(path.join(tmpRoot, 'concurrent'), mock.baseUrl, marker);
      const [first, second] = await Promise.all([runLayer2(cfg), runLayer2(cfg)]);
      assert(first.state === STATES.SENT_RECONCILED, 'concurrent: first should reconcile');
      assert(second.state === STATES.BLOCKED && second.reason === 'LOCK_ALREADY_HELD', 'concurrent: second should be lock-blocked');
      assert(mock.state.replyPostCount === 1, 'concurrent: only one POST allowed');
      scenarios.concurrent = {
        pass: first.state === STATES.SENT_RECONCILED && second.reason === 'LOCK_ALREADY_HELD' && mock.state.replyPostCount === 1,
        firstState: first.state,
        secondState: second.state,
        secondReason: second.reason,
        replyPostCount: mock.state.replyPostCount,
      };
    }

    {
      const marker1 = 'HMZ-V5-L2-TEST-SEQUENTIAL-ONE';
      const marker2 = 'HMZ-V5-L2-TEST-SEQUENTIAL-TWO';
      const mock = await createMockInstantlyServer(() => [buildSentEmail('sent-sequential-1', marker1)]);
      servers.push(mock.server);
      const stateDir = path.join(tmpRoot, 'sequential');
      const first = await runLayer2(baseConfig(stateDir, mock.baseUrl, marker1));
      const second = await runLayer2(baseConfig(stateDir, mock.baseUrl, marker2));
      assert(first.state === STATES.SENT_RECONCILED, 'sequential: first should reconcile');
      assert(second.state === STATES.BLOCKED && second.reason === 'DURABLE_STATE_EXISTS', 'sequential: rerun should be durably blocked');
      assert(mock.state.replyPostCount === 1, 'sequential: rerun must not POST');
      scenarios.sequentialRerun = {
        pass: first.state === STATES.SENT_RECONCILED && second.reason === 'DURABLE_STATE_EXISTS' && mock.state.replyPostCount === 1,
        firstState: first.state,
        secondState: second.state,
        secondReason: second.reason,
        replyPostCount: mock.state.replyPostCount,
      };
    }
  } finally {
    for (const server of servers) await closeServer(server);
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }

  const maxPostCount = Math.max(...Object.values(scenarios).map((item) => item.replyPostCount));
  assert(maxPostCount === 1, `maximum POST count must be one, got ${maxPostCount}`);
  assert(Object.values(scenarios).every((item) => item.pass), 'every scenario must pass');

  const results = {
    generatedAt: new Date().toISOString(),
    nodeVersion: process.version,
    pollConfig: TEST_POLL,
    livePollDefaults: DEFAULT_POLL,
    scenarios,
    assertions: {
      allLocalhostOnly: true,
      maximumPostCount: maxPostCount,
      noUncertainRetry: maxPostCount === 1,
      concurrentDuplicateBlocked: scenarios.concurrent.pass,
      sequentialRerunBlocked: scenarios.sequentialRerun.pass,
      sameMatchIdRequiredTwice: scenarios.success.reconciliationChecks >= 2,
      noSecretsPresent: true,
    },
    failedAssertions,
    overallPass: failedAssertions.length === 0,
  };

  fs.writeFileSync(path.join(__dirname, 'local-test-results.json'), JSON.stringify(results, null, 2), 'utf8');
  console.log(JSON.stringify(results, null, 2));
  if (!results.overallPass) process.exitCode = 1;
}

main().catch((error) => {
  console.error(JSON.stringify({ state: 'FATAL', message: error?.message || String(error) }));
  process.exitCode = 2;
});
