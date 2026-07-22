// hmz-reply-console enrichment: prospect-name and mailbox-sender-name resolution.
// Node built-ins only. Pure functions + a durable account-directory cache.
//
// Names are NEVER inferred from the email local part, untrusted display names,
// company, reply body or signatures. Prospect names come from the authenticated
// reply_received payload's merged lead fields (or an exact lead lookup); sender
// names come from the Instantly Account resource for the exact eaccount.

import fs from 'node:fs';
import path from 'node:path';

// ---- name normalisation ---------------------------------------------------
// Unicode-safe trim, preserve diacritics/punctuation/case, single-space join.
export function normalizeName(first, last) {
  const f = String(first == null ? '' : first).trim();
  const l = String(last == null ? '' : last).trim();
  return [f, l].filter((s) => s.length > 0).join(' ');
}

// ---- prospect name from the reply_received payload ------------------------
// Returns { name, source }. source ∈ WEBHOOK | UNAVAILABLE.
// Only trusts explicit first/last name fields (several documented casings).
const FIRST_KEYS = ['First_name', 'first_name', 'firstName', 'FirstName', 'FIRST_NAME'];
const LAST_KEYS = ['Last_name', 'last_name', 'lastName', 'LastName', 'LAST_NAME'];
function pick(obj, keys) {
  for (const k of keys) {
    if (obj && Object.prototype.hasOwnProperty.call(obj, k) && String(obj[k] ?? '').trim()) return String(obj[k]).trim();
  }
  return '';
}
export function prospectNameFromPayload(payload = {}) {
  const first = pick(payload, FIRST_KEYS);
  const last = pick(payload, LAST_KEYS);
  const name = normalizeName(first, last);
  return name ? { name, source: 'WEBHOOK' } : { name: '', source: 'UNAVAILABLE' };
}

// Display string: "First Last <email>" or "Name unavailable <email>".
export function prospectDisplay(name, email) {
  const e = String(email || '').trim();
  return `${name && name.trim() ? name.trim() : 'Name unavailable'} <${e}>`;
}
export function senderDisplay(name, mailbox) {
  const m = String(mailbox || '').trim();
  return `${name && name.trim() ? name.trim() : 'Sender name not configured'} <${m}>`;
}

// ---- durable account-directory cache (eaccount -> first/last name) --------
// Keyed by exact lower-cased account email. Stores name, status,
// timestamp_updated, and a cache timestamp. Refreshes on TTL or a miss.
const ACCOUNT_CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6h

function acctDir(base) { return path.join(base, 'account-directory'); }
function acctPath(base, email) {
  const safe = String(email || '').toLowerCase().replace(/[^a-z0-9._@+-]/g, '_');
  return path.join(acctDir(base), `${safe}.json`);
}
function readJson(p) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; } }
function atomicWrite(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  const tmp = `${p}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2), 'utf8');
  fs.renameSync(tmp, p);
}

export function getCachedAccount(base, email) {
  const rec = readJson(acctPath(base, email));
  if (!rec) return null;
  rec._fresh = (Date.now() - Date.parse(rec.cachedAt || 0)) < ACCOUNT_CACHE_TTL_MS;
  return rec;
}

export function putCachedAccount(base, email, acct) {
  const rec = {
    email: String(email || '').toLowerCase(),
    firstName: String(acct.first_name || '').trim(),
    lastName: String(acct.last_name || '').trim(),
    status: acct.status,
    timestampUpdated: acct.timestamp_updated || null,
    cachedAt: new Date().toISOString(),
    found: true,
  };
  atomicWrite(acctPath(base, email), rec);
  return rec;
}
export function putMissingAccount(base, email) {
  const rec = { email: String(email || '').toLowerCase(), found: false, cachedAt: new Date().toISOString() };
  atomicWrite(acctPath(base, email), rec);
  return rec;
}

// Resolve the sender name for an exact eaccount, using the durable cache and an
// authenticated Instantly Account lookup on miss/stale. Fails CLOSED for
// eligibility (found:false) but always returns a display string.
// Returns { name, display, found, eligible, source, status }.
export async function resolveSenderName(base, eaccount, { apiKey, apiBase, fetchImpl, forceRefresh = false } = {}) {
  const email = String(eaccount || '').toLowerCase().trim();
  if (!email) return { name: '', display: senderDisplay('', ''), found: false, eligible: false, source: 'NO_EACCOUNT' };

  let cached = getCachedAccount(base, email);
  if (cached && cached.found && cached._fresh && !forceRefresh) {
    return snap(cached, 'CACHE');
  }
  if (!apiKey) {
    // no key to refresh; use stale cache if present
    if (cached && cached.found) return snap(cached, 'CACHE_STALE');
    return { name: '', display: senderDisplay('', email), found: false, eligible: false, source: 'NO_KEY' };
  }
  const doFetch = fetchImpl || fetch;
  const base2 = (apiBase || 'https://api.instantly.ai/api/v2').replace(/\/$/, '');
  try {
    const r = await doFetch(`${base2}/accounts/${encodeURIComponent(email)}`, {
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(8000),
    });
    if (r.status === 200) {
      const acct = JSON.parse(await r.text());
      const rec = putCachedAccount(base, email, acct);
      return snap(rec, 'API');
    }
    if (r.status === 404) { putMissingAccount(base, email); return { name: '', display: senderDisplay('', email), found: false, eligible: false, source: 'API_404', status: 404 }; }
    // transient error: fall back to stale cache if any
    if (cached && cached.found) return snap(cached, 'CACHE_STALE');
    return { name: '', display: senderDisplay('', email), found: false, eligible: false, source: 'API_' + r.status, status: r.status };
  } catch {
    if (cached && cached.found) return snap(cached, 'CACHE_STALE');
    return { name: '', display: senderDisplay('', email), found: false, eligible: false, source: 'API_ERROR' };
  }
}

function snap(rec, source) {
  const name = normalizeName(rec.firstName, rec.lastName);
  return {
    name, display: senderDisplay(name, rec.email),
    found: true, eligible: rec.status === 1 || rec.status === undefined,
    status: rec.status, source, timestampUpdated: rec.timestampUpdated || null,
  };
}

// Optional prospect lead lookup (fallback when the payload lacked names). Uses
// exact lead email + campaign; refuses on multiple matches (no arbitrary pick).
// Returns { name, source } with source ∈ LEAD_ID_LOOKUP | EMAIL_CAMPAIGN_LOOKUP
// | UNAVAILABLE | LOOKUP_FAILED | AMBIGUOUS.
export async function resolveProspectNameByLookup(email, campaignId, { apiKey, apiBase, fetchImpl } = {}) {
  if (!apiKey || !email) return { name: '', source: 'UNAVAILABLE' };
  const doFetch = fetchImpl || fetch;
  const base2 = (apiBase || 'https://api.instantly.ai/api/v2').replace(/\/$/, '');
  try {
    const body = { search: email, limit: 5 };
    if (campaignId) body.campaign = campaignId;
    const r = await doFetch(`${base2}/leads/list`, {
      method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(8000),
    });
    if (r.status !== 200) return { name: '', source: 'LOOKUP_FAILED' };
    const j = JSON.parse(await r.text());
    const items = (j.items || j.data || []).filter((l) => String(l.email || '').toLowerCase() === email.toLowerCase());
    if (items.length === 0) return { name: '', source: 'UNAVAILABLE' };
    if (items.length > 1) return { name: '', source: 'AMBIGUOUS' };
    const l = items[0];
    const pl = l.payload || {};
    const name = normalizeName(pick(pl, FIRST_KEYS) || pick(l, FIRST_KEYS), pick(pl, LAST_KEYS) || pick(l, LAST_KEYS));
    return name ? { name, source: 'EMAIL_CAMPAIGN_LOOKUP' } : { name: '', source: 'UNAVAILABLE' };
  } catch {
    return { name: '', source: 'LOOKUP_FAILED' };
  }
}
