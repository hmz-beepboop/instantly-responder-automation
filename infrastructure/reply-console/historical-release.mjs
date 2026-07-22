#!/usr/bin/env node
// Internal-only, restart-safe historical notification release coordinator.
// It never calls Instantly or Google Chat and contains no prospect-send path.
// The normal durable outbox worker performs the fixed-destination Chat POST.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  createHistoricalBackfillPlan,
  historicalBackfillStatus,
  releaseNextHistoricalBackfill,
} from './inbound-store.mjs';

function parseArgs(argv) {
  const out = { apply: false, stayAlive: false, stateDir: process.env.STATE_DIR || '/data', minIntervalMs: 12_500 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--apply') out.apply = true;
    else if (arg === '--stay-alive') out.stayAlive = true;
    else if (arg === '--state-dir') out.stateDir = argv[++i];
    else if (arg === '--manifest') out.manifestSha256 = argv[++i];
    else if (arg === '--range-end') out.rangeEnd = argv[++i];
    else if (arg === '--expected-total') out.expectedTotalInbound = Number(argv[++i]);
    else if (arg === '--expected-backfill') out.expectedBackfillCount = Number(argv[++i]);
    else if (arg === '--min-interval-ms') out.minIntervalMs = Number(argv[++i]);
    else throw new Error(`unknown_argument:${String(arg).slice(0, 40)}`);
  }
  return out;
}

function safeSummary(result) {
  return {
    ok: result.ok,
    reason: result.reason || null,
    action: result.action || null,
    state: result.state || null,
    rangeEnd: result.rangeEnd || null,
    created: result.created,
    sequence: result.sequence,
    itemCount: result.itemCount,
    releasedCount: result.releasedCount,
    notifiedCount: result.notifiedCount,
    activeCount: result.activeCount,
    remainingHoldCount: result.remainingHoldCount,
    releasedAt: result.releasedAt,
    dueAt: result.dueAt,
    completedAt: result.completedAt,
  };
}

function log(kind, value) {
  process.stdout.write(`${JSON.stringify({ at: new Date().toISOString(), kind, ...safeSummary(value) })}\n`);
}

function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, Math.max(250, Math.min(60_000, ms)))); }

export async function runHistoricalRelease(options) {
  if (!options.apply) {
    const status = historicalBackfillStatus(options.stateDir, options.manifestSha256);
    log('DRY_RUN_STATUS', status);
    return status;
  }
  const plan = createHistoricalBackfillPlan(options.stateDir, {
    manifestSha256: options.manifestSha256,
    rangeEnd: options.rangeEnd,
    expectedTotalInbound: options.expectedTotalInbound,
    expectedBackfillCount: options.expectedBackfillCount,
    minIntervalMs: options.minIntervalMs,
  });
  log('PLAN_READY', plan);
  if (!plan.ok) throw new Error(plan.reason || 'plan_initialization_failed');

  let completeReported = false;
  for (;;) {
    const result = releaseNextHistoricalBackfill(options.stateDir, options.manifestSha256);
    if (!result.ok) {
      log('PLAN_ERROR', result);
      throw new Error(result.reason || 'historical_release_failed');
    }
    if (result.action === 'RELEASED_ONE') {
      log('RELEASED_ONE', result);
      await sleep(2_000);
      continue;
    }
    if (result.action === 'COMPLETE') {
      if (!completeReported) { log('COMPLETE', result); completeReported = true; }
      if (!options.stayAlive) return result;
      await sleep(60_000);
      const status = historicalBackfillStatus(options.stateDir, options.manifestSha256);
      if (!status.ok || !status.complete) throw new Error(status.reason || 'completed_plan_regressed');
      continue;
    }
    if (result.action === 'WAITING_FOR_RATE_LIMIT' && result.dueAt) {
      await sleep(Math.max(250, Date.parse(result.dueAt) - Date.now()));
    } else {
      await sleep(2_000);
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = parseArgs(process.argv.slice(2));
  runHistoricalRelease(args).catch((error) => {
    process.stderr.write(`${JSON.stringify({ at: new Date().toISOString(), kind: 'FATAL',
      errorKind: String(error?.message || error || 'unknown').replace(/https?:\/\/\S+/g, '<url-redacted>').slice(0, 160) })}\n`);
    process.exitCode = 1;
  });
}
