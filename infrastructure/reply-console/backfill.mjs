#!/usr/bin/env node
// Explicit-range audit/backfill using the same received-record contract,
// normaliser, transactional outbox and notification worker as webhook, normal
// poll and scheduled completeness audit. Dry-run is the default. This module
// has no prospect-send adapter and never advances the normal poll cursor.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeInstantlyReceived, LABELS } from './inbound-contract.mjs';
import { getInbound, getNotification } from './inbound-store.mjs';
import { createInboundService, fetchInstantlyReceivedRange } from './inbound-service.mjs';
import { findByInstantlyEmailId } from './store.mjs';

function parseArgs(argv) {
  const out = { apply: false, pageLimit: 100, maxPages: 10_000 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--since') out.since = argv[++i];
    else if (arg === '--until') out.until = argv[++i];
    else if (arg === '--apply') out.apply = true;
    else if (arg === '--state-dir') out.stateDir = argv[++i];
    else if (arg === '--notify-url') out.notifyUrl = argv[++i];
    else if (arg === '--campaign') out.campaign = argv[++i];
    else if (arg === '--verbose') out.verbose = true;
  }
  return out;
}

export async function runBackfill({
  since,
  until,
  apply = false,
  stateDir,
  notifyUrl = process.env.GCHAT_NOTIFY_URL || '',
  campaign = null,
  apiKey = process.env.INSTANTLY_API_KEY,
  apiBase = process.env.INSTANTLY_API_BASE || 'https://api.instantly.ai/api/v2',
  fetchImpl = fetch,
  notifyFetch = fetch,
  pageLimit = 100,
  maxPages = 10_000,
  verbose = false,
  allowMockChatUrl = false,
} = {}) {
  if (!since || !until) return { ok: false, reason: 'MISSING_RANGE' };
  if (!apiKey) return { ok: false, reason: 'NO_API_KEY' };
  if (!stateDir) return { ok: false, reason: 'NO_STATE_DIR' };

  const fetched = await fetchInstantlyReceivedRange({
    apiKey, apiBase, since, until, pageLimit, maxPages, campaign, fetchImpl,
  });
  if (!fetched.ok) return { ok: false, reason: fetched.errorKind, status: fetched.status,
    since, until, scanned: fetched.items.length, pageCount: fetched.pages };

  const unique = new Map();
  for (const raw of fetched.items) {
    const normalized = normalizeInstantlyReceived(raw, {
      authoritativeReceived: true,
      discoverySource: 'EXPLICIT_BACKFILL',
    });
    if (normalized.ok) unique.set(normalized.record.identity, { raw, record: normalized.record });
  }

  let missing = 0, alreadyPresent = 0, outboxMissing = 0, created = 0;
  let autoReplyRecovered = 0, bounceSystemRecovered = 0, malformedRecovered = 0;
  const missingItems = [];
  const toApply = [];
  const v2Exists = fs.existsSync(path.join(stateDir, 'inbound-v2.sqlite'));
  const legacyExists = fs.existsSync(path.join(stateDir, 'contexts'));
  for (const item of unique.values()) {
    const record = item.record;
    const inbound = v2Exists ? getInbound(stateDir, record.instantlyEmailId || record.identity) : null;
    const legacy = legacyExists && record.instantlyEmailId ? findByInstantlyEmailId(stateDir, record.instantlyEmailId) : null;
    const outbox = inbound ? getNotification(stateDir, inbound.identity) : null;
    if (inbound && outbox) { alreadyPresent++; continue; }
    if (legacy && !inbound) {
      // The v2 migration imports this acknowledgement before production
      // backfill; report it distinctly rather than posting a duplicate here.
      alreadyPresent++;
      continue;
    }
    missing++;
    if (inbound && !outbox) outboxMissing++;
    missingItems.push({
      identity: record.identity,
      instantlyEmailId: record.instantlyEmailId,
      identityKind: record.identityKind,
      timestamp: record.receivedAt,
      classification: record.classification,
      degradedMetadata: record.degradedMetadata,
      subject: verbose ? record.subject : undefined,
      eaccount: verbose ? record.eaccount : undefined,
    });
    toApply.push(item);
  }

  let drain = { attempted: 0, notified: 0, ambiguous: 0, retrying: 0 };
  if (apply && toApply.length) {
    const service = createInboundService({ stateDir, apiKey, apiBase, notifyUrl,
      fetchImpl, chatFetch: notifyFetch, allowMockChatUrl, pageLimit });
    service.migrateLegacyAcknowledgements();
    for (const item of toApply) {
      const result = await service.registerReceived(item.raw, {
        authoritativeReceived: true,
        discoverySource: 'EXPLICIT_BACKFILL',
        recovered: true,
      });
      if (!result.ok) continue;
      if (result.created) created++;
      if ([LABELS.AUTOMATIC, LABELS.OOO].includes(result.record.classification)) autoReplyRecovered++;
      if ([LABELS.BOUNCE, LABELS.SYSTEM].includes(result.record.classification)) bounceSystemRecovered++;
      if (result.record.degradedMetadata) malformedRecovered++;
    }
    drain = await service.drainOutbox({ limit: 100, maxBatches: Math.max(1, Math.ceil(toApply.length / 100) + 1) });
  }

  return {
    ok: true,
    dryRun: !apply,
    since,
    until,
    pageCount: fetched.pages,
    scanned: fetched.items.length,
    instantlyReceivedObserved: unique.size,
    applicable: unique.size,
    missing,
    outboxMissing,
    alreadyPresent,
    created,
    autoReplyRecovered,
    bounceSystemRecovered,
    malformedRecovered,
    drain,
    missingItems,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = parseArgs(process.argv.slice(2));
  const stateDir = args.stateDir || process.env.STATE_DIR || '/data';
  runBackfill({ ...args, stateDir }).then((result) => {
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exitCode = 1;
    else if (!args.apply && result.missing > 0) {
      console.error(`\n${result.missing} missing durable inbound/outbox entr${result.missing === 1 ? 'y' : 'ies'} found (dry-run; pass --apply to repair).`);
    }
  }).catch((error) => {
    console.error(String(error?.stack || error));
    process.exitCode = 1;
  });
}
