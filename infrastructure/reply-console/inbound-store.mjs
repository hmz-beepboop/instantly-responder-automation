// SQLite-backed durable inbound mirror + transactional notification outbox.
// This store is intentionally independent of the legacy supervised-send JSON
// context store. Notification reliability changes therefore cannot mutate the
// global send gate, drafts, approval tokens or send attempts.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { IDENTITY_KINDS, INBOUND_SCHEMA_VERSION } from './inbound-contract.mjs';

export const OUTBOX_STATES = Object.freeze({
  QUEUED: 'NOTIFICATION_QUEUED',
  POSTING: 'NOTIFICATION_POSTING',
  RETRYING: 'NOTIFICATION_RETRYING',
  AMBIGUOUS: 'NOTIFICATION_RESPONSE_AMBIGUOUS',
  NOTIFIED: 'CHAT_NOTIFIED',
  HISTORICAL_HOLD: 'HISTORICAL_OWNER_HOLD',
});

const OPEN = new Map();
const STATEMENTS = new WeakMap();

function statement(db, sql) {
  let cache = STATEMENTS.get(db);
  if (!cache) { cache = new Map(); STATEMENTS.set(db, cache); }
  if (!cache.has(sql)) cache.set(sql, db.prepare(sql));
  return cache.get(sql);
}

function nowIso(now = Date.now()) { return new Date(now).toISOString(); }
function sha(value) { return crypto.createHash('sha256').update(String(value), 'utf8').digest('hex'); }
function outboxId(identity) { return `notify:${sha(identity)}`; }
function json(value) { return JSON.stringify(value ?? null); }
function parseJson(value, fallback = null) {
  try { return value == null ? fallback : JSON.parse(value); } catch { return fallback; }
}

function assertSafeStateDir(base) {
  fs.mkdirSync(base, { recursive: true, mode: 0o700 });
  const dirStat = fs.lstatSync(base);
  if (!dirStat.isDirectory() || dirStat.isSymbolicLink()) throw new Error('unsafe_state_directory');
  const file = path.join(base, 'inbound-v2.sqlite');
  if (fs.existsSync(file)) {
    const stat = fs.lstatSync(file);
    if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('unsafe_inbound_database_path');
  }
  for (const suffix of ['-wal', '-shm']) {
    const companion = `${file}${suffix}`;
    if (!fs.existsSync(companion)) continue;
    const stat = fs.lstatSync(companion);
    if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('unsafe_inbound_database_companion_path');
  }
  return file;
}

function initialise(db) {
  db.exec(`
    PRAGMA journal_mode=WAL;
    PRAGMA synchronous=FULL;
    PRAGMA foreign_keys=ON;
    PRAGMA busy_timeout=5000;
    PRAGMA trusted_schema=OFF;
    PRAGMA temp_store=MEMORY;

    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS inbound_records (
      identity TEXT PRIMARY KEY,
      identity_kind TEXT NOT NULL CHECK(identity_kind IN ('INSTANTLY_EMAIL_ID','SURROGATE_UNVERIFIED')),
      instantly_email_id TEXT UNIQUE,
      workspace TEXT,
      eaccount TEXT,
      prospect_email TEXT,
      prospect_name TEXT,
      campaign_id TEXT,
      campaign_name TEXT,
      lead_id TEXT,
      thread_id TEXT,
      message_id TEXT,
      subject TEXT,
      preview TEXT,
      body_hash TEXT NOT NULL,
      has_attachment INTEGER NOT NULL CHECK(has_attachment IN (0,1)),
      classification TEXT NOT NULL,
      degraded_metadata INTEGER NOT NULL CHECK(degraded_metadata IN (0,1)),
      send_allowed INTEGER NOT NULL CHECK(send_allowed IN (0,1)),
      received_at TEXT,
      observed_at TEXT NOT NULL,
      first_seen_at TEXT NOT NULL,
      last_seen_at TEXT NOT NULL,
      first_discovery_source TEXT NOT NULL,
      last_discovery_source TEXT NOT NULL,
      discovery_sources_json TEXT NOT NULL,
      metadata_issues_json TEXT NOT NULL,
      thread_key TEXT NOT NULL UNIQUE,
      unibox_url TEXT NOT NULL,
      legacy_context_id TEXT,
      enrichment_state TEXT NOT NULL DEFAULT 'PENDING',
      enrichment_error TEXT,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE INDEX IF NOT EXISTS inbound_received_idx ON inbound_records(received_at, instantly_email_id);
    CREATE INDEX IF NOT EXISTS inbound_message_idx ON inbound_records(message_id) WHERE message_id IS NOT NULL;
    CREATE INDEX IF NOT EXISTS inbound_thread_idx ON inbound_records(thread_id) WHERE thread_id IS NOT NULL;

    CREATE TABLE IF NOT EXISTS notification_outbox (
      notification_id TEXT PRIMARY KEY,
      inbound_identity TEXT NOT NULL UNIQUE REFERENCES inbound_records(identity) ON UPDATE CASCADE ON DELETE RESTRICT,
      state TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      next_attempt_at TEXT,
      lease_owner TEXT,
      lease_expires_at TEXT,
      attempt_count INTEGER NOT NULL DEFAULT 0,
      ack_http_status INTEGER,
      ack_message_name TEXT,
      ack_thread_name TEXT,
      ack_at TEXT,
      notification_latency_ms INTEGER,
      last_error_kind TEXT,
      last_http_status INTEGER,
      ambiguity_count INTEGER NOT NULL DEFAULT 0,
      probable_duplicate_count INTEGER NOT NULL DEFAULT 0,
      recovered INTEGER NOT NULL DEFAULT 0 CHECK(recovered IN (0,1)),
      historical_backfill INTEGER NOT NULL DEFAULT 0 CHECK(historical_backfill IN (0,1)),
      historical_released_at TEXT,
      CHECK((state = 'CHAT_NOTIFIED' AND ack_message_name IS NOT NULL AND ack_at IS NOT NULL) OR state <> 'CHAT_NOTIFIED')
    ) STRICT;

    CREATE INDEX IF NOT EXISTS outbox_due_idx ON notification_outbox(state, next_attempt_at, lease_expires_at);

    CREATE TABLE IF NOT EXISTS notification_attempts (
      attempt_id INTEGER PRIMARY KEY AUTOINCREMENT,
      notification_id TEXT NOT NULL REFERENCES notification_outbox(notification_id) ON DELETE RESTRICT,
      attempt_number INTEGER NOT NULL,
      worker_id TEXT NOT NULL,
      started_at TEXT NOT NULL,
      finished_at TEXT,
      outcome TEXT NOT NULL DEFAULT 'STARTED',
      http_status INTEGER,
      response_name TEXT,
      response_thread_name TEXT,
      error_kind TEXT,
      ambiguous INTEGER NOT NULL DEFAULT 0 CHECK(ambiguous IN (0,1)),
      probable_duplicate INTEGER NOT NULL DEFAULT 0 CHECK(probable_duplicate IN (0,1)),
      response_metadata_hash TEXT,
      UNIQUE(notification_id, attempt_number)
    ) STRICT;

    CREATE TABLE IF NOT EXISTS historical_backfill_plans (
      manifest_sha256 TEXT PRIMARY KEY,
      range_end TEXT NOT NULL,
      expected_total_inbound INTEGER NOT NULL,
      expected_backfill_count INTEGER NOT NULL,
      min_interval_ms INTEGER NOT NULL CHECK(min_interval_ms>=12500),
      state TEXT NOT NULL CHECK(state IN ('ACTIVE','COMPLETE')),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      completed_at TEXT
    ) STRICT;

    CREATE TABLE IF NOT EXISTS historical_backfill_items (
      manifest_sha256 TEXT NOT NULL REFERENCES historical_backfill_plans(manifest_sha256) ON DELETE RESTRICT,
      inbound_identity TEXT NOT NULL REFERENCES inbound_records(identity) ON UPDATE CASCADE ON DELETE RESTRICT,
      sequence INTEGER NOT NULL,
      released_at TEXT,
      acknowledged_at TEXT,
      PRIMARY KEY(manifest_sha256,inbound_identity),
      UNIQUE(manifest_sha256,sequence)
    ) STRICT;

    CREATE INDEX IF NOT EXISTS historical_backfill_release_idx
      ON historical_backfill_items(manifest_sha256,released_at,sequence);

    CREATE TABLE IF NOT EXISTS identity_aliases (
      alias_identity TEXT PRIMARY KEY,
      canonical_identity TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS worker_leases (
      lease_name TEXT PRIMARY KEY,
      owner TEXT NOT NULL,
      acquired_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS poll_state (
      poll_name TEXT PRIMARY KEY,
      cursor_timestamp TEXT,
      cursor_email_id TEXT,
      last_range_start TEXT,
      last_range_end TEXT,
      last_page_count INTEGER,
      last_record_count INTEGER,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS heartbeats (
      component TEXT PRIMARY KEY,
      last_success_at TEXT,
      last_attempt_at TEXT NOT NULL,
      last_range_start TEXT,
      last_range_end TEXT,
      page_count INTEGER,
      records_observed INTEGER,
      records_missing INTEGER,
      records_recovered INTEGER,
      backlog_count INTEGER,
      last_api_error TEXT,
      details_json TEXT NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS audit_runs (
      run_id TEXT PRIMARY KEY,
      audit_name TEXT NOT NULL,
      started_at TEXT NOT NULL,
      finished_at TEXT,
      range_start TEXT NOT NULL,
      range_end TEXT NOT NULL,
      status TEXT NOT NULL,
      page_count INTEGER NOT NULL DEFAULT 0,
      records_observed INTEGER NOT NULL DEFAULT 0,
      records_missing INTEGER NOT NULL DEFAULT 0,
      records_recovered INTEGER NOT NULL DEFAULT 0,
      outbox_missing INTEGER NOT NULL DEFAULT 0,
      notifications_requeued INTEGER NOT NULL DEFAULT 0,
      last_api_error TEXT
    ) STRICT;

    CREATE TABLE IF NOT EXISTS audit_discrepancies (
      discrepancy_id INTEGER PRIMARY KEY AUTOINCREMENT,
      run_id TEXT NOT NULL REFERENCES audit_runs(run_id) ON DELETE RESTRICT,
      inbound_identity TEXT,
      instantly_email_id TEXT,
      kind TEXT NOT NULL,
      detected_at TEXT NOT NULL,
      recovered_at TEXT,
      resolution TEXT
    ) STRICT;

    CREATE TABLE IF NOT EXISTS operational_alerts (
      alert_key TEXT PRIMARY KEY,
      severity TEXT NOT NULL,
      kind TEXT NOT NULL,
      component TEXT NOT NULL,
      first_seen_at TEXT NOT NULL,
      last_seen_at TEXT NOT NULL,
      occurrence_count INTEGER NOT NULL,
      active INTEGER NOT NULL CHECK(active IN (0,1)),
      resolved_at TEXT,
      safe_details_json TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS event_counters (
      metric TEXT PRIMARY KEY,
      value INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    ) STRICT;

    CREATE TABLE IF NOT EXISTS reconciliation_snapshots (
      snapshot_id TEXT PRIMARY KEY,
      source TEXT NOT NULL,
      range_start TEXT NOT NULL,
      range_end TEXT NOT NULL,
      created_at TEXT NOT NULL,
      instantly_received_observed INTEGER NOT NULL,
      durable_inbound_present INTEGER NOT NULL,
      durable_inbound_missing INTEGER NOT NULL,
      outbox_present INTEGER NOT NULL,
      outbox_missing INTEGER NOT NULL,
      chat_notified INTEGER NOT NULL,
      queued INTEGER NOT NULL,
      retrying INTEGER NOT NULL,
      ambiguous INTEGER NOT NULL,
      historical_owner_hold INTEGER NOT NULL,
      degraded_metadata INTEGER NOT NULL,
      auto_reply INTEGER NOT NULL,
      ooo INTEGER NOT NULL,
      unsubscribe INTEGER NOT NULL,
      bounce_system INTEGER NOT NULL,
      attachment_only INTEGER NOT NULL,
      surrogate_identity INTEGER NOT NULL,
      duplicate_logical_count INTEGER NOT NULL,
      probable_duplicate_chat_posts INTEGER NOT NULL
    ) STRICT;

    PRAGMA user_version=${INBOUND_SCHEMA_VERSION};
  `);
  // Forward-compatible migration for a v2 database created by a pre-release
  // candidate before notification_latency_ms was added.
  const outboxColumns = new Set(db.prepare('PRAGMA table_info(notification_outbox)').all().map((row) => row.name));
  if (!outboxColumns.has('notification_latency_ms')) db.exec('ALTER TABLE notification_outbox ADD COLUMN notification_latency_ms INTEGER');
  if (!outboxColumns.has('historical_backfill')) {
    db.exec('ALTER TABLE notification_outbox ADD COLUMN historical_backfill INTEGER NOT NULL DEFAULT 0 CHECK(historical_backfill IN (0,1))');
  }
  if (!outboxColumns.has('historical_released_at')) db.exec('ALTER TABLE notification_outbox ADD COLUMN historical_released_at TEXT');
  const historicalPlanColumns = new Set(db.prepare('PRAGMA table_info(historical_backfill_plans)').all().map((row) => row.name));
  if (!historicalPlanColumns.has('range_end')) db.exec('ALTER TABLE historical_backfill_plans ADD COLUMN range_end TEXT');
  const timestamp = nowIso();
  db.prepare(`INSERT INTO meta(key,value,updated_at) VALUES('schema_version',?,?)
    ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`)
    .run(String(INBOUND_SCHEMA_VERSION), timestamp);
}

export function openInboundStore(base) {
  const file = assertSafeStateDir(base);
  if (OPEN.has(file)) return OPEN.get(file);
  const db = new DatabaseSync(file);
  initialise(db);
  OPEN.set(file, db);
  return db;
}

export function closeInboundStore(base) {
  const file = path.join(base, 'inbound-v2.sqlite');
  const db = OPEN.get(file);
  if (db) { db.close(); OPEN.delete(file); }
}

export function checkpointInboundStore(base) {
  const db = openInboundStore(base);
  return db.prepare('PRAGMA wal_checkpoint(TRUNCATE)').all();
}

function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    try { db.exec('ROLLBACK'); } catch { /* original error wins */ }
    throw error;
  }
}

function acknowledgementLatency(db, inboundIdentity, acknowledgementAt) {
  const row = statement(db, 'SELECT received_at FROM inbound_records WHERE identity=?').get(inboundIdentity);
  const latency = row?.received_at ? Date.parse(acknowledgementAt) - Date.parse(row.received_at) : NaN;
  return Number.isFinite(latency) && latency >= 0 ? Math.round(latency) : null;
}

function rowToRecord(row) {
  if (!row) return null;
  return {
    identity: row.identity,
    identityKind: row.identity_kind,
    instantlyEmailId: row.instantly_email_id,
    workspace: row.workspace,
    eaccount: row.eaccount,
    prospectEmail: row.prospect_email,
    prospectName: row.prospect_name,
    campaignId: row.campaign_id,
    campaignName: row.campaign_name,
    leadId: row.lead_id,
    threadId: row.thread_id,
    messageId: row.message_id,
    subject: row.subject,
    preview: row.preview,
    bodyHash: row.body_hash,
    hasAttachment: row.has_attachment === 1,
    classification: row.classification,
    degradedMetadata: row.degraded_metadata === 1,
    sendAllowed: row.send_allowed === 1,
    receivedAt: row.received_at,
    observedAt: row.observed_at,
    firstSeenAt: row.first_seen_at,
    lastSeenAt: row.last_seen_at,
    discoverySources: parseJson(row.discovery_sources_json, []),
    metadataIssues: parseJson(row.metadata_issues_json, []),
    threadKey: row.thread_key,
    uniboxUrl: row.unibox_url,
    legacyContextId: row.legacy_context_id,
    enrichmentState: row.enrichment_state,
  };
}

function rowToOutbox(row) {
  if (!row) return null;
  return {
    notificationId: row.notification_id,
    inboundIdentity: row.inbound_identity,
    state: row.state,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    nextAttemptAt: row.next_attempt_at,
    leaseOwner: row.lease_owner,
    leaseExpiresAt: row.lease_expires_at,
    attemptCount: Number(row.attempt_count),
    ackHttpStatus: row.ack_http_status,
    ackMessageName: row.ack_message_name,
    ackThreadName: row.ack_thread_name,
    ackAt: row.ack_at,
    lastErrorKind: row.last_error_kind,
    lastHttpStatus: row.last_http_status,
    ambiguityCount: Number(row.ambiguity_count),
    probableDuplicateCount: Number(row.probable_duplicate_count),
    recovered: row.recovered === 1,
    historicalBackfill: row.historical_backfill === 1,
    historicalReleasedAt: row.historical_released_at,
  };
}

function strongestSurrogate(db, record) {
  if (!record.instantlyEmailId) return null;
  if (record.messageId) {
    const candidates = statement(db, `SELECT * FROM inbound_records
      WHERE identity_kind=? AND message_id=? ORDER BY first_seen_at LIMIT 3`)
      .all(IDENTITY_KINDS.SURROGATE, record.messageId);
    const compatible = candidates.filter((candidate) => {
      // RFC Message-ID is strong, but it is not globally trustworthy: the
      // same message can be forwarded into multiple receiving accounts and
      // poisoned metadata can reuse it. Refuse any authoritative-field
      // contradiction and require a matching content/thread fingerprint.
      for (const [stored, incoming] of [
        [candidate.workspace, record.workspace], [candidate.eaccount, record.eaccount],
        [candidate.prospect_email, record.prospectEmail], [candidate.thread_id, record.threadId],
      ]) {
        if (stored && incoming && stored !== incoming) return false;
      }
      return (candidate.thread_id && record.threadId && candidate.thread_id === record.threadId)
        || candidate.body_hash === record.bodyHash;
    });
    if (compatible.length === 1) return compatible[0];
  }
  if (record.threadId && record.bodyHash) {
    const exact = statement(db, `SELECT * FROM inbound_records
      WHERE identity_kind=? AND thread_id=? AND body_hash=?
        AND COALESCE(eaccount,'')=COALESCE(?, '') AND COALESCE(prospect_email,'')=COALESCE(?, '')
      ORDER BY first_seen_at LIMIT 2`)
      .all(IDENTITY_KINDS.SURROGATE, record.threadId, record.bodyHash, record.eaccount, record.prospectEmail);
    if (exact.length === 1) return exact[0];
  }
  return null;
}

function mergeSurrogateIntoReal(db, surrogateRow, record, timestamp) {
  const realRow = db.prepare('SELECT * FROM inbound_records WHERE identity=?').get(record.identity);
  if (!realRow) {
    db.prepare(`UPDATE inbound_records SET identity=?, identity_kind=?, instantly_email_id=?, updated_at=? WHERE identity=?`)
      .run(record.identity, IDENTITY_KINDS.INSTANTLY, record.instantlyEmailId, timestamp, surrogateRow.identity);
    db.prepare(`INSERT OR REPLACE INTO identity_aliases(alias_identity,canonical_identity,reason,created_at) VALUES(?,?,?,?)`)
      .run(surrogateRow.identity, record.identity, 'SURROGATE_MATCHED_REAL_INSTANTLY_ID', timestamp);
    return true;
  }

  const surrogateOutbox = db.prepare('SELECT * FROM notification_outbox WHERE inbound_identity=?').get(surrogateRow.identity);
  const realOutbox = db.prepare('SELECT * FROM notification_outbox WHERE inbound_identity=?').get(record.identity);
  if (surrogateOutbox && realOutbox) {
    // Never invalidate a transport claim that may currently be in flight. A
    // later overlapping poll/audit will retry the merge after the worker has
    // definitely acknowledged or released its lease.
    if (surrogateOutbox.state === OUTBOX_STATES.POSTING || realOutbox.state === OUTBOX_STATES.POSTING) return false;

    // Preserve both immutable attempt histories. Attempt numbers are scoped to
    // a logical notification, so renumber the surrogate history after the
    // existing real-ID history before removing the duplicate outbox row.
    const surrogateAttempts = db.prepare(`SELECT attempt_id FROM notification_attempts
      WHERE notification_id=? ORDER BY attempt_number,attempt_id`).all(surrogateOutbox.notification_id);
    let mergedAttemptCount = Number(realOutbox.attempt_count);
    for (const attempt of surrogateAttempts) {
      mergedAttemptCount++;
      db.prepare('UPDATE notification_attempts SET notification_id=?,attempt_number=? WHERE attempt_id=?')
        .run(realOutbox.notification_id, mergedAttemptCount, attempt.attempt_id);
    }

    if (surrogateOutbox.state === OUTBOX_STATES.NOTIFIED && realOutbox.state !== OUTBOX_STATES.NOTIFIED) {
      db.prepare(`UPDATE notification_outbox SET state=?, ack_http_status=?, ack_message_name=?, ack_thread_name=?, ack_at=?,
        notification_latency_ms=?,next_attempt_at=NULL,lease_owner=NULL,lease_expires_at=NULL,last_error_kind=NULL,
        updated_at=? WHERE notification_id=?`)
        .run(OUTBOX_STATES.NOTIFIED, surrogateOutbox.ack_http_status, surrogateOutbox.ack_message_name,
          surrogateOutbox.ack_thread_name, surrogateOutbox.ack_at, surrogateOutbox.notification_latency_ms,
          timestamp, realOutbox.notification_id);
    } else if (surrogateOutbox.state === OUTBOX_STATES.NOTIFIED && realOutbox.state === OUTBOX_STATES.NOTIFIED
      && surrogateOutbox.ack_message_name !== realOutbox.ack_message_name) {
      db.prepare('UPDATE notification_outbox SET probable_duplicate_count=probable_duplicate_count+1, updated_at=? WHERE notification_id=?')
        .run(timestamp, realOutbox.notification_id);
    } else if (realOutbox.state !== OUTBOX_STATES.NOTIFIED) {
      const bothHeld = surrogateOutbox.state === OUTBOX_STATES.HISTORICAL_HOLD
        && realOutbox.state === OUTBOX_STATES.HISTORICAL_HOLD;
      db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,lease_expires_at=NULL,
        last_error_kind=?,updated_at=? WHERE notification_id=?`)
        .run(bothHeld ? OUTBOX_STATES.HISTORICAL_HOLD : OUTBOX_STATES.RETRYING,
          bothHeld ? null : timestamp, bothHeld ? null : 'SURROGATE_IDENTITY_MERGED_RETRY',
          timestamp, realOutbox.notification_id);
    }
    db.prepare(`UPDATE notification_outbox SET attempt_count=?,ambiguity_count=ambiguity_count+?,
      probable_duplicate_count=probable_duplicate_count+?,recovered=MAX(recovered,?),updated_at=? WHERE notification_id=?`)
      .run(mergedAttemptCount, Number(surrogateOutbox.ambiguity_count), Number(surrogateOutbox.probable_duplicate_count),
        Number(surrogateOutbox.recovered), timestamp, realOutbox.notification_id);
    db.prepare('DELETE FROM notification_outbox WHERE notification_id=?').run(surrogateOutbox.notification_id);
  }
  db.prepare('DELETE FROM inbound_records WHERE identity=?').run(surrogateRow.identity);
  db.prepare(`INSERT OR REPLACE INTO identity_aliases(alias_identity,canonical_identity,reason,created_at) VALUES(?,?,?,?)`)
    .run(surrogateRow.identity, record.identity, 'SURROGATE_MATCHED_EXISTING_REAL_ID', timestamp);
  return true;
}

function mergeValues(existing, record) {
  const sources = new Set(parseJson(existing?.discovery_sources_json, []));
  sources.add(record.discoverySource);
  const issues = new Set(parseJson(existing?.metadata_issues_json, []));
  for (const issue of record.metadataIssues || []) issues.add(issue);
  return { sources: [...sources].sort(), issues: [...issues].sort() };
}

function registerOneInTransaction(db, record, { queuePolicy = 'QUEUE', recovered = false, now = Date.now() } = {}) {
  if (!record || !record.identity) throw new Error('invalid_canonical_inbound_record');
  const timestamp = nowIso(now);
  if (record.instantlyEmailId) {
    const surrogate = strongestSurrogate(db, record);
    if (surrogate && surrogate.identity !== record.identity) mergeSurrogateIntoReal(db, surrogate, record, timestamp);
  }

  let existing = statement(db, 'SELECT * FROM inbound_records WHERE identity=?').get(record.identity);
  if (!existing && record.instantlyEmailId) {
    existing = statement(db, 'SELECT * FROM inbound_records WHERE instantly_email_id=?').get(record.instantlyEmailId);
  }
  const created = !existing;
  const merged = mergeValues(existing, record);
  if (existing) {
    const sameSourceSeen = parseJson(existing.discovery_sources_json, []).includes(record.discoverySource);
    const materiallySame = existing.body_hash === record.bodyHash
      && existing.instantly_email_id === record.instantlyEmailId
      && existing.eaccount === record.eaccount
      && existing.prospect_email === record.prospectEmail
      && existing.thread_id === record.threadId
      && existing.message_id === record.messageId
      && existing.classification === record.classification;
    const existingOutbox = statement(db, 'SELECT * FROM notification_outbox WHERE inbound_identity=?').get(existing.identity);
    if (sameSourceSeen && materiallySame && existingOutbox && !(recovered && existingOutbox.recovered !== 1)) {
      return { created: false, record: rowToRecord(existing), outbox: rowToOutbox(existingOutbox) };
    }
  }
  if (!existing) {
    statement(db, `INSERT INTO inbound_records(
      identity,identity_kind,instantly_email_id,workspace,eaccount,prospect_email,prospect_name,campaign_id,campaign_name,
      lead_id,thread_id,message_id,subject,preview,body_hash,has_attachment,classification,degraded_metadata,send_allowed,
      received_at,observed_at,first_seen_at,last_seen_at,first_discovery_source,last_discovery_source,discovery_sources_json,
      metadata_issues_json,thread_key,unibox_url,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
      .run(record.identity, record.identityKind, record.instantlyEmailId, record.workspace, record.eaccount,
        record.prospectEmail, record.prospectName, record.campaignId, record.campaignName, record.leadId, record.threadId,
        record.messageId, record.subject, record.preview, record.bodyHash, record.hasAttachment ? 1 : 0,
        record.classification, record.degradedMetadata ? 1 : 0, record.sendAllowed ? 1 : 0, record.receivedAt,
        record.observedAt, timestamp, timestamp, record.discoverySource, record.discoverySource, json(merged.sources),
        json(merged.issues), record.threadKey, record.uniboxUrl, timestamp);
  } else {
    const canonicalIdentity = existing.identity;
    statement(db, `UPDATE inbound_records SET
      instantly_email_id=COALESCE(instantly_email_id,?), workspace=COALESCE(?,workspace), eaccount=COALESCE(?,eaccount),
      prospect_email=COALESCE(?,prospect_email), prospect_name=COALESCE(?,prospect_name), campaign_id=COALESCE(?,campaign_id),
      campaign_name=COALESCE(?,campaign_name), lead_id=COALESCE(?,lead_id), thread_id=COALESCE(?,thread_id),
      message_id=COALESCE(?,message_id), subject=COALESCE(?,subject), preview=COALESCE(?,preview),
      has_attachment=MAX(has_attachment,?), classification=?, degraded_metadata=?, send_allowed=?,
      received_at=COALESCE(?,received_at), observed_at=?, last_seen_at=?, last_discovery_source=?,
      discovery_sources_json=?, metadata_issues_json=?, unibox_url=?, updated_at=? WHERE identity=?`)
      .run(record.instantlyEmailId, record.workspace, record.eaccount, record.prospectEmail, record.prospectName,
        record.campaignId, record.campaignName, record.leadId, record.threadId, record.messageId, record.subject,
        record.preview, record.hasAttachment ? 1 : 0, record.classification, record.degradedMetadata ? 1 : 0,
        record.sendAllowed ? 1 : 0, record.receivedAt, record.observedAt, timestamp, record.discoverySource,
        json(merged.sources), json(merged.issues), record.uniboxUrl, timestamp, canonicalIdentity);
    record = { ...record, identity: canonicalIdentity };
  }

  const initialState = queuePolicy === 'HISTORICAL_OWNER_HOLD' ? OUTBOX_STATES.HISTORICAL_HOLD : OUTBOX_STATES.QUEUED;
  const notificationId = outboxId(record.identity);
  statement(db, `INSERT OR IGNORE INTO notification_outbox(
    notification_id,inbound_identity,state,created_at,updated_at,next_attempt_at,recovered)
    VALUES(?,?,?,?,?,?,?)`)
    .run(notificationId, record.identity, initialState, timestamp, timestamp,
      initialState === OUTBOX_STATES.QUEUED ? timestamp : null, recovered ? 1 : 0);
  if (recovered) statement(db, 'UPDATE notification_outbox SET recovered=1 WHERE inbound_identity=?').run(record.identity);
  const inbound = statement(db, 'SELECT * FROM inbound_records WHERE identity=?').get(record.identity);
  const outbox = statement(db, 'SELECT * FROM notification_outbox WHERE inbound_identity=?').get(record.identity);
  return { created, record: rowToRecord(inbound), outbox: rowToOutbox(outbox) };
}

export function registerInbound(base, record, options = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => registerOneInTransaction(db, record, options));
}

export function registerInboundBatch(base, records, options = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => records.map((record) => registerOneInTransaction(db, record, {
    ...options,
    queuePolicy: typeof options.queuePolicyFor === 'function' ? options.queuePolicyFor(record) : options.queuePolicy,
  })));
}

export function getInbound(base, identityOrInstantlyId) {
  const db = openInboundStore(base);
  const row = statement(db, `SELECT * FROM inbound_records WHERE identity=? OR instantly_email_id=?`).get(identityOrInstantlyId, identityOrInstantlyId);
  return rowToRecord(row);
}

export function getNotification(base, identityOrNotificationId) {
  const db = openInboundStore(base);
  const row = statement(db, `SELECT o.* FROM notification_outbox o
    LEFT JOIN inbound_records i ON i.identity=o.inbound_identity
    WHERE o.notification_id=? OR o.inbound_identity=? OR i.instantly_email_id=?`)
    .get(identityOrNotificationId, identityOrNotificationId, identityOrNotificationId);
  return rowToOutbox(row);
}

function identitySetSha256FromDb(db, rangeEnd = null) {
  const rows = rangeEnd
    ? db.prepare('SELECT identity FROM inbound_records WHERE received_at<=? ORDER BY identity').all(rangeEnd)
    : db.prepare('SELECT identity FROM inbound_records ORDER BY identity').all();
  const identities = rows.map((row) => row.identity);
  return sha(identities.join('\n'));
}

export function inboundIdentitySetSha256(base, { rangeEnd = null } = {}) {
  const parsedRangeEnd = rangeEnd === null ? null : Date.parse(rangeEnd);
  if (rangeEnd !== null && !Number.isFinite(parsedRangeEnd)) throw new Error('invalid_range_end');
  return identitySetSha256FromDb(openInboundStore(base), parsedRangeEnd === null ? null : nowIso(parsedRangeEnd));
}

function syncHistoricalAcknowledgements(db, manifestSha256) {
  db.prepare(`UPDATE historical_backfill_items SET acknowledged_at=(
      SELECT o.ack_at FROM notification_outbox o WHERE o.inbound_identity=historical_backfill_items.inbound_identity
    ) WHERE manifest_sha256=? AND released_at IS NOT NULL AND acknowledged_at IS NULL
      AND EXISTS (SELECT 1 FROM notification_outbox o
        WHERE o.inbound_identity=historical_backfill_items.inbound_identity AND o.state='CHAT_NOTIFIED')`)
    .run(manifestSha256);
}

function historicalPlanStatusFromDb(db, manifestSha256) {
  const plan = db.prepare('SELECT * FROM historical_backfill_plans WHERE manifest_sha256=?').get(manifestSha256);
  if (!plan) return { ok: false, reason: 'PLAN_NOT_FOUND', manifestSha256 };
  syncHistoricalAcknowledgements(db, manifestSha256);
  const facts = db.prepare(`SELECT
      COUNT(*) AS item_count,
      SUM(CASE WHEN h.released_at IS NOT NULL THEN 1 ELSE 0 END) AS released_count,
      SUM(CASE WHEN o.state='CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS notified_count,
      SUM(CASE WHEN h.released_at IS NOT NULL AND o.state<>'CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS active_count,
      SUM(CASE WHEN h.released_at IS NULL AND o.state<>'HISTORICAL_OWNER_HOLD' THEN 1 ELSE 0 END) AS invalid_unreleased_state,
      SUM(CASE WHEN h.released_at IS NOT NULL AND o.historical_backfill<>1 THEN 1 ELSE 0 END) AS invalid_released_marker,
      SUM(CASE WHEN h.released_at IS NULL AND o.historical_backfill<>0 THEN 1 ELSE 0 END) AS invalid_unreleased_marker,
      MAX(h.released_at) AS last_released_at
    FROM historical_backfill_items h
    JOIN notification_outbox o ON o.inbound_identity=h.inbound_identity
    WHERE h.manifest_sha256=?`).get(manifestSha256);
  const itemCount = Number(facts.item_count || 0);
  const releasedCount = Number(facts.released_count || 0);
  const notifiedCount = Number(facts.notified_count || 0);
  const activeCount = Number(facts.active_count || 0);
  const invalidUnreleasedState = Number(facts.invalid_unreleased_state || 0);
  const invalidReleasedMarker = Number(facts.invalid_released_marker || 0);
  const invalidUnreleasedMarker = Number(facts.invalid_unreleased_marker || 0);
  const valid = itemCount === Number(plan.expected_backfill_count)
    && invalidUnreleasedState === 0 && invalidReleasedMarker === 0 && invalidUnreleasedMarker === 0
    && activeCount <= 1 && notifiedCount <= releasedCount && releasedCount <= itemCount;
  const complete = valid && notifiedCount === itemCount && activeCount === 0;
  if (complete && plan.state !== 'COMPLETE') {
    const timestamp = nowIso();
    db.prepare(`UPDATE historical_backfill_plans SET state='COMPLETE',completed_at=?,updated_at=? WHERE manifest_sha256=?`)
      .run(timestamp, timestamp, manifestSha256);
    plan.state = 'COMPLETE';
    plan.completed_at = timestamp;
  }
  return {
    ok: valid,
    reason: valid ? null : 'PLAN_INVARIANT_FAILED',
    manifestSha256,
    rangeEnd: plan.range_end,
    state: plan.state,
    expectedTotalInbound: Number(plan.expected_total_inbound),
    expectedBackfillCount: Number(plan.expected_backfill_count),
    minIntervalMs: Number(plan.min_interval_ms),
    itemCount,
    releasedCount,
    notifiedCount,
    activeCount,
    remainingHoldCount: itemCount - releasedCount,
    lastReleasedAt: facts.last_released_at || null,
    completedAt: plan.completed_at || null,
    invalidUnreleasedState,
    invalidReleasedMarker,
    invalidUnreleasedMarker,
    complete,
  };
}

export function createHistoricalBackfillPlan(base, {
  manifestSha256,
  rangeEnd,
  expectedTotalInbound,
  expectedBackfillCount,
  minIntervalMs = 12_500,
  now = Date.now(),
} = {}) {
  if (!/^[0-9a-f]{64}$/.test(String(manifestSha256 || ''))) return { ok: false, reason: 'INVALID_MANIFEST_SHA256' };
  const rangeEndMs = Date.parse(rangeEnd);
  if (!Number.isFinite(rangeEndMs)) return { ok: false, reason: 'INVALID_RANGE_END' };
  const canonicalRangeEnd = nowIso(rangeEndMs);
  const totalExpected = Number(expectedTotalInbound);
  const backfillExpected = Number(expectedBackfillCount);
  const interval = Number(minIntervalMs);
  if (!Number.isInteger(totalExpected) || totalExpected < 1
    || !Number.isInteger(backfillExpected) || backfillExpected < 1 || backfillExpected > totalExpected
    || !Number.isInteger(interval) || interval < 12_500) return { ok: false, reason: 'INVALID_PLAN_BOUNDS' };
  const db = openInboundStore(base);
  return transaction(db, () => {
    const existing = db.prepare('SELECT * FROM historical_backfill_plans WHERE manifest_sha256=?').get(manifestSha256);
    if (existing) {
      if (Number(existing.expected_total_inbound) !== totalExpected
        || Number(existing.expected_backfill_count) !== backfillExpected
        || Number(existing.min_interval_ms) !== interval
        || existing.range_end !== canonicalRangeEnd) return { ok: false, reason: 'PLAN_CONFIGURATION_MISMATCH' };
      return { created: false, ...historicalPlanStatusFromDb(db, manifestSha256) };
    }
    const activePlans = Number(db.prepare("SELECT COUNT(*) AS n FROM historical_backfill_plans WHERE state='ACTIVE'").get().n || 0);
    if (activePlans !== 0) return { ok: false, reason: 'ANOTHER_PLAN_ACTIVE' };
    const totalInbound = Number(db.prepare('SELECT COUNT(*) AS n FROM inbound_records WHERE received_at<=?').get(canonicalRangeEnd).n || 0);
    const totalOutbox = Number(db.prepare(`SELECT COUNT(*) AS n FROM notification_outbox o
      JOIN inbound_records i ON i.identity=o.inbound_identity WHERE i.received_at<=?`).get(canonicalRangeEnd).n || 0);
    const identitySetSha256 = identitySetSha256FromDb(db, canonicalRangeEnd);
    if (totalInbound !== totalExpected || totalOutbox !== totalExpected || identitySetSha256 !== manifestSha256) {
      return { ok: false, reason: 'AUTHORIZED_MANIFEST_MISMATCH', totalInbound, totalOutbox, identitySetSha256 };
    }
    const holds = db.prepare(`SELECT o.inbound_identity FROM notification_outbox o
      JOIN inbound_records i ON i.identity=o.inbound_identity
      WHERE o.state=? AND o.ack_message_name IS NULL AND o.ack_at IS NULL AND o.attempt_count=0
        AND o.historical_backfill=0 AND i.received_at<=?
      ORDER BY COALESCE(i.received_at,i.first_seen_at),o.notification_id`)
      .all(OUTBOX_STATES.HISTORICAL_HOLD, canonicalRangeEnd);
    const allHolds = Number(db.prepare(`SELECT COUNT(*) AS n FROM notification_outbox o
      JOIN inbound_records i ON i.identity=o.inbound_identity WHERE o.state=? AND i.received_at<=?`)
      .get(OUTBOX_STATES.HISTORICAL_HOLD, canonicalRangeEnd).n || 0);
    if (holds.length !== backfillExpected || allHolds !== backfillExpected) {
      return { ok: false, reason: 'AUTHORIZED_HOLD_SET_MISMATCH', eligibleHolds: holds.length, allHolds };
    }
    const timestamp = nowIso(now);
    db.prepare(`INSERT INTO historical_backfill_plans(
      manifest_sha256,range_end,expected_total_inbound,expected_backfill_count,min_interval_ms,state,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?,?)`).run(manifestSha256, canonicalRangeEnd, totalExpected, backfillExpected, interval, 'ACTIVE', timestamp, timestamp);
    const insert = db.prepare(`INSERT INTO historical_backfill_items(
      manifest_sha256,inbound_identity,sequence) VALUES(?,?,?)`);
    holds.forEach((row, index) => insert.run(manifestSha256, row.inbound_identity, index + 1));
    return { created: true, ...historicalPlanStatusFromDb(db, manifestSha256) };
  });
}

export function historicalBackfillStatus(base, manifestSha256) {
  if (!/^[0-9a-f]{64}$/.test(String(manifestSha256 || ''))) return { ok: false, reason: 'INVALID_MANIFEST_SHA256' };
  const db = openInboundStore(base);
  return transaction(db, () => historicalPlanStatusFromDb(db, manifestSha256));
}

export function releaseNextHistoricalBackfill(base, manifestSha256, { now = Date.now() } = {}) {
  if (!/^[0-9a-f]{64}$/.test(String(manifestSha256 || ''))) return { ok: false, reason: 'INVALID_MANIFEST_SHA256' };
  const db = openInboundStore(base);
  return transaction(db, () => {
    const status = historicalPlanStatusFromDb(db, manifestSha256);
    if (!status.ok) return status;
    if (status.complete) return { ...status, action: 'COMPLETE' };
    if (status.activeCount > 0) return { ...status, action: 'WAITING_FOR_ACKNOWLEDGEMENT' };
    const nowMs = Number(now);
    const lastMs = status.lastReleasedAt ? Date.parse(status.lastReleasedAt) : null;
    if (lastMs !== null && nowMs - lastMs < status.minIntervalMs) {
      return { ...status, action: 'WAITING_FOR_RATE_LIMIT', dueAt: nowIso(lastMs + status.minIntervalMs) };
    }
    const next = db.prepare(`SELECT h.inbound_identity,h.sequence FROM historical_backfill_items h
      JOIN notification_outbox o ON o.inbound_identity=h.inbound_identity
      WHERE h.manifest_sha256=? AND h.released_at IS NULL AND o.state=?
      ORDER BY h.sequence LIMIT 1`).get(manifestSha256, OUTBOX_STATES.HISTORICAL_HOLD);
    if (!next) return { ok: false, reason: 'NO_RELEASABLE_ITEM', ...status };
    const timestamp = nowIso(nowMs);
    const changed = db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,
      lease_expires_at=NULL,recovered=1,historical_backfill=1,historical_released_at=?,updated_at=?
      WHERE inbound_identity=? AND state=? AND ack_message_name IS NULL AND ack_at IS NULL`)
      .run(OUTBOX_STATES.QUEUED, timestamp, timestamp, timestamp, next.inbound_identity, OUTBOX_STATES.HISTORICAL_HOLD);
    if (Number(changed.changes) !== 1) return { ok: false, reason: 'RELEASE_RACE_LOST' };
    db.prepare(`UPDATE historical_backfill_items SET released_at=?
      WHERE manifest_sha256=? AND inbound_identity=? AND released_at IS NULL`)
      .run(timestamp, manifestSha256, next.inbound_identity);
    db.prepare('UPDATE historical_backfill_plans SET updated_at=? WHERE manifest_sha256=?').run(timestamp, manifestSha256);
    return {
      ok: true,
      action: 'RELEASED_ONE',
      sequence: Number(next.sequence),
      releasedCount: status.releasedCount + 1,
      notifiedCount: status.notifiedCount,
      remainingHoldCount: status.remainingHoldCount - 1,
      releasedAt: timestamp,
    };
  });
}

export function setLegacyContextId(base, identity, contextId) {
  const db = openInboundStore(base);
  db.prepare('UPDATE inbound_records SET legacy_context_id=?, enrichment_state=?, updated_at=? WHERE identity=?')
    .run(contextId || null, contextId ? 'COMPLETE' : 'BLOCKED_ROUTING', nowIso(), identity);
}

export function updateInboundEnrichment(base, identity, enrichment) {
  const db = openInboundStore(base);
  const timestamp = nowIso();
  db.prepare(`UPDATE inbound_records SET prospect_name=COALESCE(?,prospect_name),enrichment_state=?,
    enrichment_error=?,updated_at=? WHERE identity=?`)
    .run(enrichment.prospectName || null, enrichment.blocked ? 'BLOCKED_ROUTING' : (enrichment.ok === false ? 'FAILED' : 'COMPLETE'),
      enrichment.error ? String(enrichment.error).slice(0, 160) : null, timestamp, identity);
  return getInbound(base, identity);
}

export function importAcknowledgedLegacy(base, record, acknowledgement, { contextId = null, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    // Callers may pass either a freshly normalized record or the public
    // stored-record shape returned by registerInbound(). The latter carries
    // discoverySources rather than a single discoverySource; never bind an
    // undefined value while importing an acknowledgement for an existing row.
    const canonicalRecord = {
      ...record,
      discoverySource: record.discoverySource
        || record.discoverySources?.[record.discoverySources.length - 1]
        || 'LEGACY_MIGRATION',
    };
    const result = registerOneInTransaction(db, canonicalRecord, { now });
    const timestamp = acknowledgement.ackAt || nowIso(now);
    const latency = acknowledgementLatency(db, result.record.identity, timestamp);
    db.prepare(`UPDATE notification_outbox SET state=?, ack_http_status=?, ack_message_name=?, ack_thread_name=?, ack_at=?,
      notification_latency_ms=?,next_attempt_at=NULL, lease_owner=NULL, lease_expires_at=NULL, updated_at=? WHERE inbound_identity=?`)
      .run(OUTBOX_STATES.NOTIFIED, Number(acknowledgement.httpStatus || 200), acknowledgement.messageName,
        acknowledgement.threadName || null, timestamp, latency, timestamp, result.record.identity);
    if (contextId) db.prepare('UPDATE inbound_records SET legacy_context_id=?, enrichment_state=?, updated_at=? WHERE identity=?')
      .run(contextId, 'COMPLETE', timestamp, result.record.identity);
    return { ...result, outbox: getNotificationFromDb(db, result.record.identity) };
  });
}

function getNotificationFromDb(db, value) {
  return rowToOutbox(db.prepare('SELECT * FROM notification_outbox WHERE notification_id=? OR inbound_identity=?').get(value, value));
}

export function acquireNamedLease(base, leaseName, owner, { leaseMs = 60_000, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const expires = nowIso(now + leaseMs);
    const current = statement(db, 'SELECT * FROM worker_leases WHERE lease_name=?').get(leaseName);
    if (current && current.expires_at > timestamp && current.owner !== owner) return false;
    statement(db, `INSERT INTO worker_leases(lease_name,owner,acquired_at,expires_at) VALUES(?,?,?,?)
      ON CONFLICT(lease_name) DO UPDATE SET owner=excluded.owner, acquired_at=excluded.acquired_at, expires_at=excluded.expires_at`)
      .run(leaseName, owner, timestamp, expires);
    return true;
  });
}

export function renewNamedLease(base, leaseName, owner, { leaseMs = 60_000, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const result = statement(db, 'UPDATE worker_leases SET expires_at=? WHERE lease_name=? AND owner=? AND expires_at>?')
    .run(nowIso(now + leaseMs), leaseName, owner, nowIso(now));
  return Number(result.changes) === 1;
}

export function releaseNamedLease(base, leaseName, owner) {
  const db = openInboundStore(base);
  return Number(statement(db, 'DELETE FROM worker_leases WHERE lease_name=? AND owner=?').run(leaseName, owner).changes) === 1;
}

export function releaseExpiredNotificationLeases(base, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  return transaction(db, () => {
    const stale = statement(db, `SELECT notification_id,attempt_count FROM notification_outbox
      WHERE state=? AND lease_expires_at IS NOT NULL AND lease_expires_at<=?`).all(OUTBOX_STATES.POSTING, timestamp);
    for (const row of stale) {
      const openAttempt = db.prepare(`SELECT attempt_id FROM notification_attempts
        WHERE notification_id=? AND finished_at IS NULL ORDER BY attempt_number DESC LIMIT 1`).get(row.notification_id);
      if (openAttempt) {
        db.prepare(`UPDATE notification_attempts SET finished_at=?,outcome='AMBIGUOUS',error_kind='WORKER_LEASE_EXPIRED',ambiguous=1
          WHERE attempt_id=?`).run(timestamp, openAttempt.attempt_id);
      }
      db.prepare(`UPDATE notification_outbox SET state=?, lease_owner=NULL, lease_expires_at=NULL,
        next_attempt_at=?, last_error_kind='WORKER_LEASE_EXPIRED', ambiguity_count=ambiguity_count+?, updated_at=?
        WHERE notification_id=?`).run(openAttempt ? OUTBOX_STATES.AMBIGUOUS : OUTBOX_STATES.RETRYING,
        timestamp, openAttempt ? 1 : 0, timestamp, row.notification_id);
    }
    return stale.length;
  });
}

export function claimNotifications(base, workerId, { limit = 25, leaseMs = 30_000, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const rows = statement(db, `SELECT o.notification_id FROM notification_outbox o
      WHERE o.state IN (?,?,?,?)
        AND (o.next_attempt_at IS NULL OR o.next_attempt_at<=?)
        AND (o.lease_expires_at IS NULL OR o.lease_expires_at<=?)
      ORDER BY o.created_at, o.notification_id LIMIT ?`)
      .all(OUTBOX_STATES.QUEUED, OUTBOX_STATES.RETRYING, OUTBOX_STATES.AMBIGUOUS, OUTBOX_STATES.POSTING,
        timestamp, timestamp, Math.max(1, Math.min(500, Number(limit) || 25)));
    const expires = nowIso(now + leaseMs);
    for (const row of rows) {
      db.prepare(`UPDATE notification_outbox SET state=?, lease_owner=?, lease_expires_at=?, updated_at=?
        WHERE notification_id=? AND (lease_expires_at IS NULL OR lease_expires_at<=?)`)
        .run(OUTBOX_STATES.POSTING, workerId, expires, timestamp, row.notification_id, timestamp);
    }
    if (!rows.length) return [];
    const get = db.prepare(`SELECT o.*, i.* FROM notification_outbox o JOIN inbound_records i ON i.identity=o.inbound_identity
      WHERE o.notification_id=? AND o.lease_owner=?`);
    return rows.map((row) => {
      const joined = get.get(row.notification_id, workerId);
      return joined ? { record: rowToRecord(joined), outbox: rowToOutbox(joined) } : null;
    }).filter(Boolean);
  });
}

export function beginNotificationAttempt(base, notificationId, workerId, { probableDuplicate = false, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const row = db.prepare('SELECT * FROM notification_outbox WHERE notification_id=?').get(notificationId);
    if (!row || row.lease_owner !== workerId || row.state !== OUTBOX_STATES.POSTING || row.lease_expires_at <= timestamp) {
      return { ok: false, reason: 'LEASE_NOT_OWNED' };
    }
    const attemptNumber = Number(row.attempt_count) + 1;
    const insert = db.prepare(`INSERT INTO notification_attempts(
      notification_id,attempt_number,worker_id,started_at,probable_duplicate) VALUES(?,?,?,?,?)`)
      .run(notificationId, attemptNumber, workerId, timestamp, probableDuplicate ? 1 : 0);
    db.prepare('UPDATE notification_outbox SET attempt_count=?, updated_at=? WHERE notification_id=?')
      .run(attemptNumber, timestamp, notificationId);
    return { ok: true, attemptId: Number(insert.lastInsertRowid), attemptNumber };
  });
}

export function beginNotificationAttempts(base, items, workerId, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const output = [];
    for (const item of items) {
      const row = db.prepare('SELECT * FROM notification_outbox WHERE notification_id=?').get(item.notificationId);
      if (!row || row.lease_owner !== workerId || row.state !== OUTBOX_STATES.POSTING || row.lease_expires_at <= timestamp) {
        output.push({ ok: false, reason: 'LEASE_NOT_OWNED', notificationId: item.notificationId });
        continue;
      }
      const attemptNumber = Number(row.attempt_count) + 1;
      const insert = db.prepare(`INSERT INTO notification_attempts(
        notification_id,attempt_number,worker_id,started_at,probable_duplicate) VALUES(?,?,?,?,?)`)
        .run(item.notificationId, attemptNumber, workerId, timestamp, item.probableDuplicate ? 1 : 0);
      db.prepare('UPDATE notification_outbox SET attempt_count=?, updated_at=? WHERE notification_id=?')
        .run(attemptNumber, timestamp, item.notificationId);
      output.push({ ok: true, notificationId: item.notificationId,
        attemptId: Number(insert.lastInsertRowid), attemptNumber });
    }
    return output;
  });
}

export function retryDelayMs(attemptNumber) {
  const exponent = Math.min(12, Math.max(0, Number(attemptNumber) - 1));
  const base = Math.min(30 * 60_000, 5_000 * (2 ** exponent));
  const deterministicJitter = (Number(attemptNumber) * 7919) % 1000;
  return Math.min(30 * 60_000, base + deterministicJitter);
}

export function finishNotificationAttempt(base, notificationId, workerId, attemptId, result, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const outbox = db.prepare('SELECT * FROM notification_outbox WHERE notification_id=?').get(notificationId);
    if (!outbox || outbox.lease_owner !== workerId) return { ok: false, reason: 'LEASE_NOT_OWNED' };
    const attempt = db.prepare('SELECT * FROM notification_attempts WHERE attempt_id=? AND notification_id=?').get(attemptId, notificationId);
    if (!attempt || attempt.finished_at) return { ok: false, reason: 'ATTEMPT_NOT_OPEN' };
    const metadataHash = result.responseMetadata == null ? null : sha(json(result.responseMetadata));

    if (result.acknowledged === true && result.messageName) {
      const latency = acknowledgementLatency(db, outbox.inbound_identity, timestamp);
      db.prepare(`UPDATE notification_attempts SET finished_at=?,outcome='ACKNOWLEDGED',http_status=?,response_name=?,
        response_thread_name=?,response_metadata_hash=? WHERE attempt_id=?`)
        .run(timestamp, Number(result.httpStatus || 200), String(result.messageName), result.threadName || null, metadataHash, attemptId);
      db.prepare(`UPDATE notification_outbox SET state=?,ack_http_status=?,ack_message_name=?,ack_thread_name=?,ack_at=?,
        notification_latency_ms=?,next_attempt_at=NULL,lease_owner=NULL,lease_expires_at=NULL,last_error_kind=NULL,last_http_status=?,updated_at=?
        WHERE notification_id=?`)
        .run(OUTBOX_STATES.NOTIFIED, Number(result.httpStatus || 200), String(result.messageName), result.threadName || null,
          timestamp, latency, Number(result.httpStatus || 200), timestamp, notificationId);
      return { ok: true, state: OUTBOX_STATES.NOTIFIED };
    }

    const ambiguous = result.ambiguous === true;
    const state = ambiguous ? OUTBOX_STATES.AMBIGUOUS : OUTBOX_STATES.RETRYING;
    const errorKind = String(result.errorKind || (ambiguous ? 'RESPONSE_AMBIGUOUS' : 'POST_FAILED')).slice(0, 160);
    const next = nowIso(now + retryDelayMs(outbox.attempt_count));
    db.prepare(`UPDATE notification_attempts SET finished_at=?,outcome=?,http_status=?,error_kind=?,ambiguous=?,
      response_metadata_hash=? WHERE attempt_id=?`)
      .run(timestamp, ambiguous ? 'AMBIGUOUS' : 'RETRYABLE_FAILURE', result.httpStatus || null, errorKind,
        ambiguous ? 1 : 0, metadataHash, attemptId);
    db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,lease_expires_at=NULL,
      last_error_kind=?,last_http_status=?,ambiguity_count=ambiguity_count+?,updated_at=? WHERE notification_id=?`)
      .run(state, next, errorKind, result.httpStatus || null, ambiguous ? 1 : 0, timestamp, notificationId);
    return { ok: true, state, nextAttemptAt: next };
  });
}

export function finishNotificationAttempts(base, items, workerId, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  return transaction(db, () => {
    const timestamp = nowIso(now);
    const output = [];
    for (const item of items) {
      const { notificationId, attemptId, result } = item;
      const outbox = db.prepare('SELECT * FROM notification_outbox WHERE notification_id=?').get(notificationId);
      if (!outbox || outbox.lease_owner !== workerId) {
        output.push({ ok: false, reason: 'LEASE_NOT_OWNED', notificationId }); continue;
      }
      const attempt = db.prepare('SELECT * FROM notification_attempts WHERE attempt_id=? AND notification_id=?').get(attemptId, notificationId);
      if (!attempt || attempt.finished_at) {
        output.push({ ok: false, reason: 'ATTEMPT_NOT_OPEN', notificationId }); continue;
      }
      const metadataHash = result.responseMetadata == null ? null : sha(json(result.responseMetadata));
      if (result.acknowledged === true && result.messageName) {
        const latency = acknowledgementLatency(db, outbox.inbound_identity, timestamp);
        db.prepare(`UPDATE notification_attempts SET finished_at=?,outcome='ACKNOWLEDGED',http_status=?,response_name=?,
          response_thread_name=?,response_metadata_hash=? WHERE attempt_id=?`)
          .run(timestamp, Number(result.httpStatus || 200), String(result.messageName), result.threadName || null, metadataHash, attemptId);
        db.prepare(`UPDATE notification_outbox SET state=?,ack_http_status=?,ack_message_name=?,ack_thread_name=?,ack_at=?,
          notification_latency_ms=?,next_attempt_at=NULL,lease_owner=NULL,lease_expires_at=NULL,last_error_kind=NULL,last_http_status=?,updated_at=?
          WHERE notification_id=?`)
          .run(OUTBOX_STATES.NOTIFIED, Number(result.httpStatus || 200), String(result.messageName), result.threadName || null,
            timestamp, latency, Number(result.httpStatus || 200), timestamp, notificationId);
        output.push({ ok: true, state: OUTBOX_STATES.NOTIFIED, notificationId });
        continue;
      }
      const ambiguous = result.ambiguous === true;
      const state = ambiguous ? OUTBOX_STATES.AMBIGUOUS : OUTBOX_STATES.RETRYING;
      const errorKind = String(result.errorKind || (ambiguous ? 'RESPONSE_AMBIGUOUS' : 'POST_FAILED')).slice(0, 160);
      const next = nowIso(now + retryDelayMs(outbox.attempt_count));
      db.prepare(`UPDATE notification_attempts SET finished_at=?,outcome=?,http_status=?,error_kind=?,ambiguous=?,
        response_metadata_hash=? WHERE attempt_id=?`)
        .run(timestamp, ambiguous ? 'AMBIGUOUS' : 'RETRYABLE_FAILURE', result.httpStatus || null, errorKind,
          ambiguous ? 1 : 0, metadataHash, attemptId);
      db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,lease_expires_at=NULL,
        last_error_kind=?,last_http_status=?,ambiguity_count=ambiguity_count+?,updated_at=? WHERE notification_id=?`)
        .run(state, next, errorKind, result.httpStatus || null, ambiguous ? 1 : 0, timestamp, notificationId);
      output.push({ ok: true, state, nextAttemptAt: next, notificationId });
    }
    return output;
  });
}

export function requeueUnacknowledged(base, identities = null, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  if (!identities || identities.length === 0) {
    return Number(db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,lease_expires_at=NULL,updated_at=?
      WHERE state NOT IN (?,?,?)`).run(OUTBOX_STATES.RETRYING, timestamp, timestamp,
      OUTBOX_STATES.NOTIFIED, OUTBOX_STATES.HISTORICAL_HOLD, OUTBOX_STATES.POSTING).changes);
  }
  let changed = 0;
  const stmt = db.prepare(`UPDATE notification_outbox SET state=?,next_attempt_at=?,lease_owner=NULL,lease_expires_at=NULL,updated_at=?
    WHERE inbound_identity=? AND state NOT IN (?,?,?)`);
  transaction(db, () => {
    for (const identity of identities) changed += Number(stmt.run(OUTBOX_STATES.RETRYING, timestamp, timestamp, identity,
      OUTBOX_STATES.NOTIFIED, OUTBOX_STATES.HISTORICAL_HOLD, OUTBOX_STATES.POSTING).changes);
  });
  return changed;
}

export function markProbableDuplicate(base, notificationId) {
  const db = openInboundStore(base);
  return Number(db.prepare('UPDATE notification_outbox SET probable_duplicate_count=probable_duplicate_count+1,updated_at=? WHERE notification_id=?')
    .run(nowIso(), notificationId).changes) === 1;
}

export function markProbableDuplicates(base, notificationIds, { now = Date.now() } = {}) {
  if (!notificationIds.length) return 0;
  const db = openInboundStore(base);
  return transaction(db, () => {
    const statement = db.prepare('UPDATE notification_outbox SET probable_duplicate_count=probable_duplicate_count+1,updated_at=? WHERE notification_id=?');
    let changed = 0;
    for (const id of notificationIds) changed += Number(statement.run(nowIso(now), id).changes);
    return changed;
  });
}

export function getPollState(base, pollName) {
  const db = openInboundStore(base);
  return statement(db, 'SELECT * FROM poll_state WHERE poll_name=?').get(pollName) || null;
}

export function commitPollState(base, pollName, state, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  db.prepare(`INSERT INTO poll_state(poll_name,cursor_timestamp,cursor_email_id,last_range_start,last_range_end,last_page_count,last_record_count,updated_at)
    VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(poll_name) DO UPDATE SET
      cursor_timestamp=excluded.cursor_timestamp,cursor_email_id=excluded.cursor_email_id,last_range_start=excluded.last_range_start,
      last_range_end=excluded.last_range_end,last_page_count=excluded.last_page_count,last_record_count=excluded.last_record_count,
      updated_at=excluded.updated_at`)
    .run(pollName, state.cursorTimestamp || null, state.cursorEmailId || null, state.rangeStart || null,
      state.rangeEnd || null, Number(state.pageCount || 0), Number(state.recordCount || 0), timestamp);
}

export function startAuditRun(base, auditName, rangeStart, rangeEnd, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const startedAt = nowIso(now);
  const runId = `${auditName}:${startedAt}:${crypto.randomBytes(6).toString('hex')}`;
  statement(db, `INSERT INTO audit_runs(run_id,audit_name,started_at,range_start,range_end,status) VALUES(?,?,?,?,?,'RUNNING')`)
    .run(runId, auditName, startedAt, rangeStart, rangeEnd);
  return runId;
}

export function recordAuditDiscrepancy(base, runId, discrepancy, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  statement(db, `INSERT INTO audit_discrepancies(run_id,inbound_identity,instantly_email_id,kind,detected_at,recovered_at,resolution)
    VALUES(?,?,?,?,?,?,?)`).run(runId, discrepancy.identity || null, discrepancy.instantlyEmailId || null,
    discrepancy.kind, nowIso(now), discrepancy.recovered ? nowIso(now) : null, discrepancy.resolution || null);
}

export function finishAuditRun(base, runId, result, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  statement(db, `UPDATE audit_runs SET finished_at=?,status=?,page_count=?,records_observed=?,records_missing=?,records_recovered=?,
    outbox_missing=?,notifications_requeued=?,last_api_error=? WHERE run_id=?`)
    .run(nowIso(now), result.ok ? 'SUCCESS' : 'FAILED', Number(result.pageCount || 0), Number(result.recordsObserved || 0),
      Number(result.recordsMissing || 0), Number(result.recordsRecovered || 0), Number(result.outboxMissing || 0),
      Number(result.notificationsRequeued || 0), result.lastApiError || null, runId);
}

export function updateHeartbeat(base, component, details, { success = false, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  const previous = statement(db, 'SELECT * FROM heartbeats WHERE component=?').get(component);
  statement(db, `INSERT INTO heartbeats(component,last_success_at,last_attempt_at,last_range_start,last_range_end,page_count,
    records_observed,records_missing,records_recovered,backlog_count,last_api_error,details_json,updated_at)
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(component) DO UPDATE SET
      last_success_at=excluded.last_success_at,last_attempt_at=excluded.last_attempt_at,last_range_start=excluded.last_range_start,
      last_range_end=excluded.last_range_end,page_count=excluded.page_count,records_observed=excluded.records_observed,
      records_missing=excluded.records_missing,records_recovered=excluded.records_recovered,backlog_count=excluded.backlog_count,
      last_api_error=excluded.last_api_error,details_json=excluded.details_json,updated_at=excluded.updated_at`)
    .run(component, success ? timestamp : (previous?.last_success_at || null), timestamp, details.rangeStart || null,
      details.rangeEnd || null, details.pageCount ?? null, details.recordsObserved ?? null, details.recordsMissing ?? null,
      details.recordsRecovered ?? null, details.backlogCount ?? null, details.lastApiError || null, json(details.safeDetails || {}), timestamp);
}

export function persistAlert(base, alert, { active = true, now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  const key = alert.key || `${alert.component}:${alert.kind}`;
  db.prepare(`INSERT INTO operational_alerts(alert_key,severity,kind,component,first_seen_at,last_seen_at,occurrence_count,active,resolved_at,safe_details_json)
    VALUES(?,?,?,?,?,?,1,?,?,?) ON CONFLICT(alert_key) DO UPDATE SET severity=excluded.severity,last_seen_at=excluded.last_seen_at,
      occurrence_count=operational_alerts.occurrence_count+1,active=excluded.active,resolved_at=excluded.resolved_at,
      safe_details_json=excluded.safe_details_json`)
    .run(key, alert.severity, alert.kind, alert.component, timestamp, timestamp, active ? 1 : 0,
      active ? null : timestamp, json(alert.safeDetails || {}));
  return key;
}

export function incrementCounter(base, metric, amount = 1, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  db.prepare(`INSERT INTO event_counters(metric,value,updated_at) VALUES(?,?,?)
    ON CONFLICT(metric) DO UPDATE SET value=event_counters.value+excluded.value,updated_at=excluded.updated_at`)
    .run(String(metric).slice(0, 120), Number(amount), nowIso(now));
}

export function eventCounters(base) {
  const db = openInboundStore(base);
  return Object.fromEntries(db.prepare('SELECT metric,value FROM event_counters ORDER BY metric').all()
    .map((row) => [row.metric, Number(row.value)]));
}

export function saveReconciliationSnapshot(base, source, rangeStart, rangeEnd, metrics, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const createdAt = nowIso(now);
  const snapshotId = `${source}:${rangeEnd}:${crypto.randomBytes(5).toString('hex')}`;
  statement(db, `INSERT INTO reconciliation_snapshots(
    snapshot_id,source,range_start,range_end,created_at,instantly_received_observed,durable_inbound_present,
    durable_inbound_missing,outbox_present,outbox_missing,chat_notified,queued,retrying,ambiguous,historical_owner_hold,
    degraded_metadata,auto_reply,ooo,unsubscribe,bounce_system,attachment_only,surrogate_identity,duplicate_logical_count,
    probable_duplicate_chat_posts) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .run(snapshotId, source, rangeStart, rangeEnd, createdAt,
      Number(metrics.instantlyReceivedObserved || 0), Number(metrics.durableInboundPresent || 0),
      Number(metrics.durableInboundMissing || 0), Number(metrics.outboxPresent || 0), Number(metrics.outboxMissing || 0),
      Number(metrics.chatNotified || 0), Number(metrics.queued || 0), Number(metrics.retrying || 0),
      Number(metrics.ambiguous || 0), Number(metrics.historicalOwnerHold || 0), Number(metrics.degradedMetadata || 0),
      Number(metrics.autoReply || 0), Number(metrics.ooo || 0), Number(metrics.unsubscribe || 0),
      Number(metrics.bounceSystem || 0), Number(metrics.attachmentOnly || 0), Number(metrics.surrogateIdentity || 0),
      Number(metrics.duplicateLogicalCount || 0), Number(metrics.probableDuplicateChatPosts || 0));
  return snapshotId;
}

export function latestReconciliationSnapshots(base) {
  const db = openInboundStore(base);
  const rows = db.prepare(`SELECT r.* FROM reconciliation_snapshots r JOIN (
    SELECT source,MAX(created_at) AS max_created FROM reconciliation_snapshots GROUP BY source
  ) latest ON latest.source=r.source AND latest.max_created=r.created_at ORDER BY r.source`).all();
  return rows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [key,
    typeof value === 'bigint' ? Number(value) : value])));
}

export function resolveAlertsNotIn(base, activeKeys, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  const rows = db.prepare('SELECT alert_key FROM operational_alerts WHERE active=1').all();
  const active = new Set(activeKeys);
  const stmt = db.prepare('UPDATE operational_alerts SET active=0,resolved_at=?,last_seen_at=? WHERE alert_key=?');
  transaction(db, () => { for (const row of rows) if (!active.has(row.alert_key)) stmt.run(timestamp, timestamp, row.alert_key); });
}

export function inboundCounts(base, { since = null, until = null } = {}) {
  const db = openInboundStore(base);
  const conditions = [];
  const params = [];
  if (since) { conditions.push('i.received_at>=?'); params.push(since); }
  if (until) { conditions.push('i.received_at<=?'); params.push(until); }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const row = db.prepare(`SELECT
    COUNT(*) AS durable_inbound_present,
    SUM(CASE WHEN o.notification_id IS NOT NULL THEN 1 ELSE 0 END) AS outbox_present,
    SUM(CASE WHEN o.notification_id IS NULL THEN 1 ELSE 0 END) AS outbox_missing,
    SUM(CASE WHEN o.state='CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS chat_notified,
    SUM(CASE WHEN o.state='NOTIFICATION_QUEUED' THEN 1 ELSE 0 END) AS queued,
    SUM(CASE WHEN o.state='NOTIFICATION_POSTING' THEN 1 ELSE 0 END) AS posting,
    SUM(CASE WHEN o.state='NOTIFICATION_RETRYING' THEN 1 ELSE 0 END) AS retrying,
    SUM(CASE WHEN o.state='NOTIFICATION_RESPONSE_AMBIGUOUS' THEN 1 ELSE 0 END) AS ambiguous,
    SUM(CASE WHEN o.state='HISTORICAL_OWNER_HOLD' THEN 1 ELSE 0 END) AS historical_owner_hold,
    SUM(CASE WHEN o.historical_backfill=1 THEN 1 ELSE 0 END) AS historical_backfill_released,
    SUM(CASE WHEN o.historical_backfill=1 AND o.state='CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS historical_backfill_notified,
    SUM(i.degraded_metadata) AS degraded_metadata,
    SUM(CASE WHEN i.classification='automatic' THEN 1 ELSE 0 END) AS auto_reply,
    SUM(CASE WHEN i.classification='out_of_office' THEN 1 ELSE 0 END) AS ooo,
    SUM(CASE WHEN i.classification='unsubscribe' THEN 1 ELSE 0 END) AS unsubscribe,
    SUM(CASE WHEN i.classification IN ('bounce','system') THEN 1 ELSE 0 END) AS bounce_system,
    SUM(CASE WHEN i.classification='attachment_only' THEN 1 ELSE 0 END) AS attachment_only,
    SUM(CASE WHEN i.identity_kind='SURROGATE_UNVERIFIED' THEN 1 ELSE 0 END) AS surrogate_identity,
    SUM(CASE WHEN o.recovered=1 THEN 1 ELSE 0 END) AS recovered,
    SUM(o.probable_duplicate_count) AS probable_duplicate_chat_posts,
    MIN(CASE WHEN o.state<>'CHAT_NOTIFIED' AND o.state<>'HISTORICAL_OWNER_HOLD'
      THEN CASE WHEN o.historical_backfill=1 THEN COALESCE(o.historical_released_at,o.updated_at) ELSE o.created_at END END)
      AS oldest_unacknowledged_at
    FROM inbound_records i LEFT JOIN notification_outbox o ON o.inbound_identity=i.identity ${where}`).get(...params);
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [key, typeof value === 'bigint' ? Number(value) : (value ?? 0)]));
}

export function notificationLatencyStats(base, { since = null, until = null } = {}) {
  const db = openInboundStore(base);
  const conditions = ["o.state='CHAT_NOTIFIED'", 'o.notification_latency_ms IS NOT NULL'];
  const params = [];
  if (since) { conditions.push('i.received_at>=?'); params.push(since); }
  if (until) { conditions.push('i.received_at<=?'); params.push(until); }
  const from = `FROM inbound_records i JOIN notification_outbox o ON o.inbound_identity=i.identity WHERE ${conditions.join(' AND ')}`;
  const aggregate = statement(db, `SELECT COUNT(*) AS n,MAX(o.notification_latency_ms) AS maximum ${from}`).get(...params);
  const count = Number(aggregate.n || 0);
  const at = (fraction) => {
    if (!count) return null;
    const offset = Math.min(count - 1, Math.floor((count - 1) * fraction));
    return Number(statement(db, `SELECT o.notification_latency_ms AS value ${from} ORDER BY o.notification_latency_ms LIMIT 1 OFFSET ?`)
      .get(...params, offset).value);
  };
  return { count, p50Ms: at(0.5), p95Ms: at(0.95), p99Ms: at(0.99), maxMs: count ? Number(aggregate.maximum) : null };
}

export function notificationQueueDepth(base) {
  const db = openInboundStore(base);
  return Number(statement(db, `SELECT COUNT(*) AS n FROM notification_outbox
    WHERE state NOT IN ('CHAT_NOTIFIED','HISTORICAL_OWNER_HOLD')`).get().n || 0);
}

export function recentBacklogDrainRate(base, { now = Date.now(), windowMs = 5 * 60_000 } = {}) {
  const db = openInboundStore(base);
  const boundedWindowMs = Math.max(1_000, Math.min(24 * 60 * 60_000, Number(windowMs) || 5 * 60_000));
  const since = nowIso(now - boundedWindowMs);
  const acknowledged = Number(statement(db, `SELECT COUNT(*) AS n FROM notification_attempts
    WHERE outcome='ACKNOWLEDGED' AND finished_at>=?`).get(since).n || 0);
  return {
    windowSeconds: boundedWindowMs / 1000,
    acknowledgements: acknowledged,
    perSecond: Number((acknowledged / (boundedWindowMs / 1000)).toFixed(6)),
  };
}

export function operationsSnapshot(base, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const counts = inboundCounts(base);
  const heartbeats = db.prepare('SELECT * FROM heartbeats ORDER BY component').all().map((row) => ({
    component: row.component,
    lastSuccessAt: row.last_success_at,
    lastAttemptAt: row.last_attempt_at,
    rangeStart: row.last_range_start,
    rangeEnd: row.last_range_end,
    pageCount: row.page_count,
    recordsObserved: row.records_observed,
    recordsMissing: row.records_missing,
    recordsRecovered: row.records_recovered,
    backlogCount: row.backlog_count,
    lastApiError: row.last_api_error,
  }));
  const alerts = db.prepare(`SELECT alert_key,severity,kind,component,first_seen_at,last_seen_at,occurrence_count,safe_details_json
    FROM operational_alerts WHERE active=1 ORDER BY severity,first_seen_at`).all().map((row) => ({
    key: row.alert_key, severity: row.severity, kind: row.kind, component: row.component,
    firstSeenAt: row.first_seen_at, lastSeenAt: row.last_seen_at, occurrenceCount: Number(row.occurrence_count),
    safeDetails: parseJson(row.safe_details_json, {}),
  }));
  const databaseFile = assertSafeStateDir(base);
  const databaseBytes = fs.existsSync(databaseFile) ? fs.statSync(databaseFile).size : 0;
  const historicalBackfillPlans = db.prepare(`SELECT p.manifest_sha256,p.range_end,p.state,p.expected_total_inbound,
      p.expected_backfill_count,p.min_interval_ms,p.created_at,p.updated_at,p.completed_at,
      COUNT(h.inbound_identity) AS item_count,
      SUM(CASE WHEN h.released_at IS NOT NULL THEN 1 ELSE 0 END) AS released_count,
      SUM(CASE WHEN o.state='CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS notified_count,
      SUM(CASE WHEN h.released_at IS NOT NULL AND o.state<>'CHAT_NOTIFIED' THEN 1 ELSE 0 END) AS active_count
    FROM historical_backfill_plans p
    LEFT JOIN historical_backfill_items h ON h.manifest_sha256=p.manifest_sha256
    LEFT JOIN notification_outbox o ON o.inbound_identity=h.inbound_identity
    GROUP BY p.manifest_sha256 ORDER BY p.created_at`).all().map((row) => ({
      manifestSha256: row.manifest_sha256,
      rangeEnd: row.range_end,
      state: row.state,
      expectedTotalInbound: Number(row.expected_total_inbound),
      expectedBackfillCount: Number(row.expected_backfill_count),
      minIntervalMs: Number(row.min_interval_ms),
      itemCount: Number(row.item_count || 0),
      releasedCount: Number(row.released_count || 0),
      notifiedCount: Number(row.notified_count || 0),
      activeCount: Number(row.active_count || 0),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      completedAt: row.completed_at,
    }));
  return {
    ok: true,
    generatedAt: nowIso(now),
    schemaVersion: INBOUND_SCHEMA_VERSION,
    databaseBytes,
    counts,
    historicalEventCounters: eventCounters(base),
    notificationLatency: notificationLatencyStats(base),
    currentStateReconciliation: latestReconciliationSnapshots(base),
    queueDepth: notificationQueueDepth(base),
    backlogDrainRate: recentBacklogDrainRate(base, { now }),
    historicalBackfillPlans,
    heartbeats,
    alerts,
  };
}

export function watchdogFacts(base, { now = Date.now() } = {}) {
  const db = openInboundStore(base);
  const timestamp = nowIso(now);
  const counts = db.prepare(`SELECT
    SUM(CASE WHEN o.state='NOTIFICATION_POSTING' THEN 1 ELSE 0 END) AS posting,
    SUM(CASE WHEN o.state='NOTIFICATION_POSTING' AND o.lease_expires_at<=? THEN 1 ELSE 0 END) AS stuck_posting_lease,
    SUM(CASE WHEN o.state NOT IN ('CHAT_NOTIFIED','HISTORICAL_OWNER_HOLD') THEN 1 ELSE 0 END) AS unacknowledged,
    SUM(CASE WHEN i.enrichment_state='FAILED' THEN 1 ELSE 0 END) AS failed_enrichment,
    SUM(CASE WHEN i.identity_kind='SURROGATE_UNVERIFIED' THEN 1 ELSE 0 END) AS surrogate_unreconciled,
    SUM(CASE WHEN i.degraded_metadata=1 AND o.state NOT IN ('CHAT_NOTIFIED','HISTORICAL_OWNER_HOLD') THEN 1 ELSE 0 END) AS unacknowledged_malformed
    FROM inbound_records i JOIN notification_outbox o ON o.inbound_identity=i.identity`).get(timestamp);
  const poll = db.prepare("SELECT * FROM poll_state WHERE poll_name='normal-recovery-poll'").get() || null;
  return {
    posting: Number(counts.posting || 0),
    stuckPostingLease: Number(counts.stuck_posting_lease || 0),
    unacknowledged: Number(counts.unacknowledged || 0),
    failedEnrichment: Number(counts.failed_enrichment || 0),
    surrogateUnreconciled: Number(counts.surrogate_unreconciled || 0),
    unacknowledgedMalformed: Number(counts.unacknowledged_malformed || 0),
    cursorTimestamp: poll?.cursor_timestamp || null,
    cursorUpdatedAt: poll?.updated_at || null,
  };
}

export function listAttempts(base, notificationId) {
  const db = openInboundStore(base);
  return db.prepare(`SELECT attempt_id,attempt_number,worker_id,started_at,finished_at,outcome,http_status,response_name,
    response_thread_name,error_kind,ambiguous,probable_duplicate,response_metadata_hash
    FROM notification_attempts WHERE notification_id=? ORDER BY attempt_number`).all(notificationId)
    .map((row) => ({ ...row, attempt_id: Number(row.attempt_id), attempt_number: Number(row.attempt_number) }));
}

export function integrityCheck(base) {
  const db = openInboundStore(base);
  const quick = db.prepare('PRAGMA quick_check').all();
  const foreign = db.prepare('PRAGMA foreign_key_check').all();
  const missingOutbox = Number(db.prepare(`SELECT COUNT(*) AS n FROM inbound_records i
    LEFT JOIN notification_outbox o ON o.inbound_identity=i.identity WHERE o.notification_id IS NULL`).get().n);
  const orphanOutbox = Number(db.prepare(`SELECT COUNT(*) AS n FROM notification_outbox o
    LEFT JOIN inbound_records i ON i.identity=o.inbound_identity WHERE i.identity IS NULL`).get().n);
  return { ok: quick.length === 1 && quick[0].quick_check === 'ok' && foreign.length === 0 && missingOutbox === 0 && orphanOutbox === 0,
    quick, foreignKeyViolations: foreign.length, missingOutbox, orphanOutbox };
}

export function diagnosticStats(base) {
  const db = openInboundStore(base);
  const row = db.prepare(`SELECT
    (SELECT COUNT(*) FROM inbound_records) AS inbound_count,
    (SELECT COUNT(*) FROM notification_outbox) AS outbox_count,
    (SELECT COUNT(*) FROM notification_attempts) AS attempt_count,
    (SELECT COUNT(*) FROM notification_attempts WHERE finished_at IS NULL) AS open_attempt_count,
    (SELECT COUNT(*) FROM notification_outbox WHERE state='CHAT_NOTIFIED' AND (ack_message_name IS NULL OR ack_at IS NULL)) AS invalid_ack_count,
    (SELECT COUNT(*) FROM notification_outbox WHERE state NOT IN ('CHAT_NOTIFIED','HISTORICAL_OWNER_HOLD')) AS nonterminal_count,
    (SELECT COUNT(*) FROM inbound_records WHERE instantly_email_id IS NOT NULL GROUP BY instantly_email_id HAVING COUNT(*)>1 LIMIT 1) AS duplicate_instantly_identity_group,
    (SELECT COUNT(*) FROM notification_outbox GROUP BY inbound_identity HAVING COUNT(*)>1 LIMIT 1) AS duplicate_outbox_identity_group,
    (SELECT MAX(attempt_count) FROM notification_outbox) AS max_attempt_count,
    (SELECT COUNT(*) FROM audit_runs) AS audit_run_count,
    (SELECT COUNT(*) FROM audit_discrepancies) AS audit_discrepancy_count`).get();
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [key, Number(value || 0)]));
}
