// hmz-reply-console telemetry: append-only, concurrency-safe reliability metrics.
//
// Each event is one JSON line appended to a per-UTC-day file. Append of a small
// line is atomic on local fs, so concurrent writers don't corrupt or race a
// read-modify-write. Reports aggregate the lines. NEVER stores prospect reply
// bodies, names, emails, or credentials — only counters + latency + coarse tags.

import fs from 'node:fs';
import path from 'node:path';

function telemetryDir(base) { return path.join(base, 'telemetry'); }
function dayFile(base, d = new Date()) {
  const day = d.toISOString().slice(0, 10);
  return path.join(telemetryDir(base), `events-${day}.jsonl`);
}

// metric: short kebab/snake name. fields: small numeric/string tags only.
export function record(base, metric, fields = {}) {
  try {
    fs.mkdirSync(telemetryDir(base), { recursive: true });
    const safe = {};
    for (const [k, v] of Object.entries(fields)) {
      if (typeof v === 'number' || typeof v === 'boolean') safe[k] = v;
      else if (typeof v === 'string') safe[k] = v.slice(0, 64);   // coarse tag only, truncated
    }
    const line = JSON.stringify({ t: new Date().toISOString(), m: String(metric).slice(0, 48), ...safe }) + '\n';
    fs.appendFileSync(dayFile(base), line, 'utf8');
  } catch { /* telemetry is best-effort; never throws into the caller */ }
}

// Read events across the last N days (inclusive).
export function readEvents(base, days = 30) {
  const dir = telemetryDir(base);
  if (!fs.existsSync(dir)) return [];
  const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    if (!/^events-\d{4}-\d{2}-\d{2}\.jsonl$/.test(f)) continue;
    const dayStr = f.slice(7, 17);
    if (Date.parse(dayStr) < cutoff - 24 * 60 * 60 * 1000) continue;
    for (const line of fs.readFileSync(path.join(dir, f), 'utf8').split('\n')) {
      if (!line.trim()) continue;
      try { const e = JSON.parse(line); if (Date.parse(e.t) >= cutoff) out.push(e); } catch { /* skip */ }
    }
  }
  return out;
}

function pct(sorted, p) {
  if (!sorted.length) return null;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

// Aggregate into the reliability report shape (numerator/denominator + latency).
export function report(base, days = 30) {
  const events = readEvents(base, days);
  const count = (m, pred) => events.filter((e) => e.m === m && (!pred || pred(e))).length;
  const latencies = (m, field) => events.filter((e) => e.m === m && typeof e[field] === 'number').map((e) => e[field]).sort((a, b) => a - b);
  const latStats = (arr) => ({ n: arr.length, p50: pct(arr, 50), p95: pct(arr, 95), p99: pct(arr, 99), max: arr.length ? arr[arr.length - 1] : null });

  const inboundTotal = count('inbound_applicable');
  const chatNotified = count('inbound_notified');
  const outboundPost = count('send_post');
  const clearSuccess = count('send_outcome', (e) => ['SENT_API_CONFIRMED', 'SENT_RECONCILED_WEBHOOK', 'SENT_RECONCILED_READBACK'].includes(e.outcome));
  const definiteFail = count('send_outcome', (e) => e.outcome === 'FAILED_DEFINITIVE');
  const manual = count('send_outcome', (e) => e.outcome === 'MANUAL_RECONCILIATION_REQUIRED');

  const clearOrDefinite = clearSuccess + definiteFail;
  // truthful demonstration: 99.99% only claimable at >= 10,000 applicable events
  const notifyDemonstrated = inboundTotal >= 10000 && (inboundTotal - chatNotified) === 0;
  const sendDemonstrated = outboundPost >= 10000 && manual === 0;

  return {
    dateRange: { days, generatedAt: new Date().toISOString() },
    inbound: {
      applicable: inboundTotal,
      discoveredWebhook: count('inbound_applicable', (e) => e.source === 'DISCOVERED_WEBHOOK'),
      discoveredReadback: count('inbound_applicable', (e) => e.source === 'DISCOVERED_READBACK'),
      duplicatesSuppressed: count('inbound_duplicate_suppressed'),
      chatNotified,
      failedNotifications: count('inbound_notify_failed'),
      ambiguousChatPosts: count('inbound_notify_ambiguous'),
      latencyMs: latStats(latencies('inbound_notified', 'latencyMs')),
      notified_numerator: chatNotified, notified_denominator: inboundTotal,
      notified_pct: inboundTotal ? +(100 * chatNotified / inboundTotal).toFixed(4) : null,
      target_99_99_demonstrated: notifyDemonstrated,
    },
    outbound: {
      reviewedDrafts: count('draft_created'),
      sendClicks: count('send_click'),
      instantlyPosts: outboundPost,
      sentApiConfirmed: count('send_outcome', (e) => e.outcome === 'SENT_API_CONFIRMED'),
      sentReconciledWebhook: count('send_outcome', (e) => e.outcome === 'SENT_RECONCILED_WEBHOOK'),
      sentReconciledReadback: count('send_outcome', (e) => e.outcome === 'SENT_RECONCILED_READBACK'),
      failedDefinitive: definiteFail,
      manualReconciliationRequired: manual,
      duplicateClicksBlocked: count('send_duplicate_blocked'),
      staleTokensBlocked: count('send_stale_blocked'),
      confirmationLatencyMs: latStats(latencies('send_confirmed', 'latencyMs')),
      clearOutcome_numerator: clearOrDefinite, clearOutcome_denominator: outboundPost,
      clearOutcome_pct: outboundPost ? +(100 * clearOrDefinite / outboundPost).toFixed(4) : null,
      manual_pct: outboundPost ? +(100 * manual / outboundPost).toFixed(4) : null,
      target_99_99_demonstrated: sendDemonstrated,
    },
    dataQuality: {
      prospectNameWebhook: count('name_source', (e) => e.kind === 'prospect' && e.source === 'WEBHOOK'),
      prospectNameLookup: count('name_source', (e) => e.kind === 'prospect' && (e.source === 'EMAIL_CAMPAIGN_LOOKUP' || e.source === 'LEAD_ID_LOOKUP')),
      prospectNameMissing: count('name_source', (e) => e.kind === 'prospect' && e.source === 'UNAVAILABLE'),
      senderNameMissing: count('name_source', (e) => e.kind === 'sender' && (e.source === 'API_404' || e.source === 'NOT_CONFIGURED')),
      accountLookupFailures: count('name_source', (e) => e.kind === 'sender' && String(e.source || '').startsWith('API_5')),
      ambiguousLeadMatches: count('name_source', (e) => e.source === 'AMBIGUOUS'),
    },
    truthfulness: inboundTotal < 10000
      ? `Sample below 10,000. Report as "0 unresolved out of N applicable events" — 99.99% is a TARGET, not demonstrated. inbound N=${inboundTotal}, outbound N=${outboundPost}.`
      : 'Sample >= 10,000; statistical demonstration possible if unresolved==0.',
  };
}
