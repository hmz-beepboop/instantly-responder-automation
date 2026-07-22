// Structural guardrails against reintroducing notification eligibility drift.

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..', '..');
const read = (relative) => {
  const repoPath = path.join(repo, relative);
  if (fs.existsSync(repoPath)) return fs.readFileSync(repoPath, 'utf8');
  // Production image layout: source/tests are /app and release workflow
  // fixtures are mounted read-only at /workflows for image verification.
  if (relative.startsWith('infrastructure/reply-console/')) {
    return fs.readFileSync(path.join(here, relative.slice('infrastructure/reply-console/'.length)), 'utf8');
  }
  if (relative.startsWith('workflows/')) return fs.readFileSync(path.join('/workflows', path.basename(relative)), 'utf8');
  throw new Error(`fixture_not_found:${relative}`);
};
let pass = 0;
const output = [];
function test(name, fn) {
  try { fn(); pass++; output.push(`PASS  ${name}`); }
  catch (error) { output.push(`FAIL  ${name} :: ${error.message}`); }
}

const contract = read('infrastructure/reply-console/inbound-contract.mjs');
const service = read('infrastructure/reply-console/inbound-service.mjs');
const inboundStore = read('infrastructure/reply-console/inbound-store.mjs');
const recovery = read('infrastructure/reply-console/recovery.mjs');
const backfill = read('infrastructure/reply-console/backfill.mjs');
const server = read('infrastructure/reply-console/server.mjs');
const dockerfile = read('infrastructure/reply-console/Dockerfile');
const historicalRelease = read('infrastructure/reply-console/historical-release.mjs');
const webhook = JSON.parse(read('workflows/HMZ_Instantly_Reply_Google_Chat_Notification.json'));
const poll = JSON.parse(read('workflows/HMZ_Inbound_Recovery_Poll.json'));
const auditor = JSON.parse(read('workflows/HMZ_Inbound_Completeness_Auditor.json'));

test('canonical received and classification functions are exported separately', () => {
  assert.match(contract, /export function isInstantlyReceived/);
  assert.match(contract, /export function classifyInboundLabel/);
  assert.match(contract, /notificationRequired: true/);
});

test('no recovery or backfill bounce classifier/filter exists', () => {
  for (const [name, source] of [['recovery', recovery], ['backfill', backfill]]) {
    assert.doesNotMatch(source, /function\s+isBounce|skippedAuto|invalidSkipped|mailer-daemon.*continue/is, name);
  }
});

test('webhook, poll, backfill and auditor all enter the canonical service', () => {
  assert.equal(webhook.nodes.find((node) => node.name === 'Persist + Queue + Attempt Chat')?.parameters?.url,
    'http://hmz-reply-console:5691/v2/inbound');
  assert.equal(poll.nodes.find((node) => node.name === 'Poll Recover (sidecar)')?.parameters?.url,
    'http://hmz-reply-console:5691/v2/poll');
  assert.match(backfill, /createInboundService/);
  assert.match(service, /runCompletenessAudit/);
  assert.match(service, /normalizeInstantlyReceived/);
});

test('notification workflow cannot filter/classify/dedup before sidecar persistence', () => {
  const executable = webhook.nodes.filter((node) => node.type !== 'n8n-nodes-base.stickyNote');
  assert.deepEqual(executable.map((node) => node.type), [
    'n8n-nodes-base.webhook', 'n8n-nodes-base.httpRequest', 'n8n-nodes-base.respondToWebhook',
  ]);
  assert.equal(executable.some((node) => node.type === 'n8n-nodes-base.if' || node.type === 'n8n-nodes-base.code'), false);
  assert.doesNotMatch(JSON.stringify(webhook), /\$getWorkflowStaticData|duplicate_suppressed|invalid_missing_fields/);
});

test('all received API traversal is authoritative; ue_type cannot suppress endpoint-returned rows', () => {
  assert.match(service, /authoritativeReceived: true/);
  assert.doesNotMatch(service, /Number\([^)]*ue_type[^)]*\)\s*!==\s*2/);
  assert.doesNotMatch(backfill, /Number\([^)]*ue_type[^)]*\)\s*!==\s*2/);
  assert.doesNotMatch(recovery, /Number\([^)]*ue_type[^)]*\)\s*!==\s*2/);
});

test('classifier never sets notification eligibility false', () => {
  const classifierBody = contract.slice(contract.indexOf('export function classifyInboundLabel'), contract.indexOf('function unwrap'));
  assert.doesNotMatch(classifierBody, /notificationRequired:\s*false/);
});

test('inbound components contain no prospect reply POST adapter', () => {
  for (const [name, source] of [['contract', contract], ['service', service], ['recovery', recovery], ['backfill', backfill]]) {
    assert.doesNotMatch(source, /emails\/reply|performSend|acquireSend|finalizeSend/, name);
  }
});

test('test-only suppression control is unavailable by production default', () => {
  assert.match(server, /ENABLE_TEST_CONTROLS\s*=\s*process\.env\.ENABLE_TEST_CONTROLS\s*===\s*'1'/);
  assert.match(server, /if \(!ENABLE_TEST_CONTROLS\) return sendJson\(res, 404/);
});

test('auditor has all three independent bounded schedules', () => {
  const names = new Set(auditor.nodes.map((node) => node.name));
  for (const name of ['Every 5 minutes', 'Audit last 2 hours', 'Every hour', 'Audit last 24 hours', 'Every day', 'Audit last 7 days']) {
    assert.ok(names.has(name), name);
  }
  assert.equal(auditor.nodes.filter((node) => node.type === 'n8n-nodes-base.scheduleTrigger').length, 3);
  assert.doesNotMatch(JSON.stringify(auditor), /emails\/reply|\/v2\/poll/);
});

test('container installs reviewed lockfile and includes every inbound module', () => {
  assert.match(dockerfile, /COPY package\.json package-lock\.json/);
  assert.match(dockerfile, /npm ci --omit=dev/);
  for (const file of ['inbound-contract.mjs', 'inbound-store.mjs', 'inbound-service.mjs', 'historical-release.mjs']) {
    assert.match(dockerfile, new RegExp(file.replace('.', '\\.')));
  }
});

test('historical release is internal-only, durable, paced and cannot send prospect email', () => {
  assert.doesNotMatch(server, /historical[-_ ]release|historical[-_ ]backfill.*POST/is);
  assert.doesNotMatch(historicalRelease, /emails\/reply|performSend|acquireSend|finalizeSend|\bfetch\s*\(/);
  assert.match(historicalRelease, /createHistoricalBackfillPlan/);
  assert.match(historicalRelease, /releaseNextHistoricalBackfill/);
  assert.match(inboundStore, /min_interval_ms INTEGER NOT NULL CHECK\(min_interval_ms>=12500\)/);
  assert.match(inboundStore, /WAITING_FOR_ACKNOWLEDGEMENT/);
});

test('legacy Chat acknowledgements cannot be gated on the newer notification-state field', () => {
  assert.match(service, /hasDefiniteLegacyChatAcknowledgement/);
  assert.match(service, /spaces\\\/\[\^\/\\s\]\+\\\/messages/);
  assert.doesNotMatch(service, /context\.notificationState\s*===\s*['"]CHAT_NOTIFIED['"]\s*&&\s*context\.chatMessageName/);
});

test('historical owner holds cannot trigger malformed-unacknowledged watchdog alerts', () => {
  assert.match(inboundStore,
    /degraded_metadata=1\s+AND\s+o\.state\s+NOT\s+IN\s*\(\s*['"]CHAT_NOTIFIED['"]\s*,\s*['"]HISTORICAL_OWNER_HOLD['"]\s*\)/);
});

for (const line of output) console.log(line);
console.log(`\n${pass}/${output.length} inbound structural tests passed`);
if (pass !== output.length) process.exitCode = 1;
