// hmz-send-state state store.
//
// Adapted from verification/v5/layer2/state-store.mjs: same atomic
// open('wx') lock + write-tmp-then-rename pattern, extended with the
// Phase 4A forward-only send-state machine, sanitisation, and error
// record storage. No credentials, prospect message bodies, or full
// webhook payloads are ever written here.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const SEND_STATES = Object.freeze({
  READY: 'READY',
  LOCKED: 'LOCKED',
  DRY_RUN_OK: 'DRY_RUN_OK',
  SUBMITTING: 'SUBMITTING',
  SENT: 'SENT',
  SEND_UNCERTAIN: 'SEND_UNCERTAIN',
  SENT_RECONCILED: 'SENT_RECONCILED',
  HUMAN_REVIEW_ZERO_MATCHES: 'HUMAN_REVIEW_ZERO_MATCHES',
  HUMAN_REVIEW_MULTIPLE_MATCHES: 'HUMAN_REVIEW_MULTIPLE_MATCHES',
  PERMANENT_FAILURE: 'PERMANENT_FAILURE',
  AUTH_OR_PLAN_FAILURE: 'AUTH_OR_PLAN_FAILURE',
  INVALID_REPLY_TARGET: 'INVALID_REPLY_TARGET',
  RETRY_EXHAUSTED: 'RETRY_EXHAUSTED',
  BLOCKED: 'BLOCKED',
});

// Forward-only transition graph. An empty array means the state is
// terminal: no further transition is ever permitted, and the send lock
// (if held) is released when this state is written.
export const ALLOWED_TRANSITIONS = Object.freeze({
  READY: ['LOCKED'],
  LOCKED: ['DRY_RUN_OK', 'SUBMITTING', 'BLOCKED'],
  SUBMITTING: [
    'SENT',
    'SEND_UNCERTAIN',
    'PERMANENT_FAILURE',
    'AUTH_OR_PLAN_FAILURE',
    'INVALID_REPLY_TARGET',
    'RETRY_EXHAUSTED',
    'BLOCKED',
  ],
  SENT: ['SENT_RECONCILED'],
  SEND_UNCERTAIN: ['SENT_RECONCILED', 'HUMAN_REVIEW_ZERO_MATCHES', 'HUMAN_REVIEW_MULTIPLE_MATCHES'],
  DRY_RUN_OK: [],
  SENT_RECONCILED: [],
  HUMAN_REVIEW_ZERO_MATCHES: [],
  HUMAN_REVIEW_MULTIPLE_MATCHES: [],
  PERMANENT_FAILURE: [],
  AUTH_OR_PLAN_FAILURE: [],
  INVALID_REPLY_TARGET: [],
  RETRY_EXHAUSTED: [],
  BLOCKED: [],
});

export function isTerminal(state) {
  return (ALLOWED_TRANSITIONS[state] || []).length === 0;
}

export function canTransition(fromState, toState) {
  const allowed = ALLOWED_TRANSITIONS[fromState];
  if (!allowed) return false;
  return allowed.includes(toState);
}

function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

// Stable across process/container restarts. Deliberately excludes any
// random body marker, so a sequential rerun derives the same key.
export function deriveSendKey({ inboundEmailId, sender, recipient, policyTemplateId }) {
  const raw = [
    'HMZ_PHASE4A_SEND',
    String(inboundEmailId ?? '').trim(),
    normalizeEmail(sender),
    normalizeEmail(recipient),
    String(policyTemplateId ?? '').trim(),
  ].join('|');
  return crypto.createHash('sha256').update(raw, 'utf8').digest('hex');
}

const SENSITIVE_KEY_PATTERN = /(authoriz|api[_-]?key|secret|token|password|cookie|bearer)/i;
const SENSITIVE_CONTENT_KEY_PATTERN = /(body|html|payload|raw|reply[_-]?text|message|content|subject)/i;
const IDENTIFIER_KEY_PATTERN = /^(sender|recipient|email|lead_email|eaccount|inboundEmailId)$/i;
const EMAIL_VALUE_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_STRING_LENGTH = 500;

function hashIdentifier(value) {
  return crypto.createHash('sha256').update(String(value ?? ''), 'utf8').digest('hex');
}

// Strips anything that looks like a credential, and truncates long
// strings (prospect message bodies / full payloads must never be stored).
export function sanitize(value, keyName = '') {
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.slice(0, 50).map((item) => sanitize(item, keyName));
  if (typeof value === 'object') {
    const out = {};
    for (const [key, val] of Object.entries(value)) {
      if (SENSITIVE_KEY_PATTERN.test(key)) {
        out[key] = '<REDACTED>';
        continue;
      }
      if (SENSITIVE_CONTENT_KEY_PATTERN.test(key)) {
        out[key] = '<REDACTED_CONTENT>';
        continue;
      }
      if (IDENTIFIER_KEY_PATTERN.test(key) && val !== null && val !== undefined) {
        out[`${key}Hash`] = hashIdentifier(typeof val === 'string' ? val.toLowerCase() : val);
        continue;
      }
      out[key] = sanitize(val, key);
    }
    return out;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (EMAIL_VALUE_PATTERN.test(trimmed)) {
      return `<EMAIL_HASH:${hashIdentifier(trimmed.toLowerCase()).slice(0, 16)}>`;
    }
    if (value.length > MAX_STRING_LENGTH) {
      return `${value.slice(0, MAX_STRING_LENGTH)}...<TRUNCATED>`;
    }
  }
  return value;
}

export function ensureStateDir(stateDir) {
  fs.mkdirSync(stateDir, { recursive: true });
}

export function lockPathFor(stateDir, sendKey) {
  return path.join(stateDir, `${sendKey}.lock`);
}

export function statePathFor(stateDir, sendKey) {
  return path.join(stateDir, `${sendKey}.state.json`);
}

export function acquireLock(stateDir, sendKey) {
  ensureStateDir(stateDir);
  const lockPath = lockPathFor(stateDir, sendKey);
  try {
    const fd = fs.openSync(lockPath, 'wx');
    try {
      fs.writeFileSync(
        fd,
        JSON.stringify({ pid: process.pid, acquiredAt: new Date().toISOString(), sendKey }),
        'utf8'
      );
    } finally {
      fs.closeSync(fd);
    }
    return { acquired: true, lockPath };
  } catch (error) {
    if (error?.code === 'EEXIST') {
      return { acquired: false, lockPath, reason: 'LOCK_ALREADY_HELD' };
    }
    throw error;
  }
}

export function releaseLock(lockPath) {
  try {
    fs.unlinkSync(lockPath);
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
}

export function writeState(stateDir, sendKey, state, details = {}) {
  ensureStateDir(stateDir);
  const statePath = statePathFor(stateDir, sendKey);
  const tmpPath = path.join(
    stateDir,
    `${sendKey}.${process.pid}.${Date.now()}.${crypto.randomBytes(4).toString('hex')}.tmp`
  );
  const now = new Date().toISOString();
  const existing = fs.existsSync(statePath)
    ? JSON.parse(fs.readFileSync(statePath, 'utf8'))
    : null;
  const payload = {
    sendKey,
    state,
    createdAt: existing?.createdAt || existing?.updatedAt || now,
    updatedAt: now,
    details: sanitize({ ...(existing?.details || {}), ...details }),
  };
  fs.writeFileSync(tmpPath, JSON.stringify(payload, null, 2), 'utf8');
  fs.renameSync(tmpPath, statePath);
  return payload;
}

export function readState(stateDir, sendKey) {
  const statePath = statePathFor(stateDir, sendKey);
  if (!fs.existsSync(statePath)) return null;
  return JSON.parse(fs.readFileSync(statePath, 'utf8'));
}

// Atomically acquire send ownership for a deterministic identity tuple.
// - Exclusive lock file prevents a concurrent second owner.
// - A pre-existing durable state file blocks a later sequential rerun.
export function acquireSend(stateDir, { inboundEmailId, sender, recipient, policyTemplateId }) {
  const sendKey = deriveSendKey({ inboundEmailId, sender, recipient, policyTemplateId });
  const lock = acquireLock(stateDir, sendKey);
  if (!lock.acquired) {
    return { acquired: false, blocked: true, reason: 'LOCK_ALREADY_HELD', sendKey };
  }

  const prior = readState(stateDir, sendKey);
  if (prior) {
    releaseLock(lock.lockPath);
    return { acquired: false, blocked: true, reason: 'DURABLE_STATE_EXISTS', priorState: prior.state, sendKey };
  }

  const record = writeState(stateDir, sendKey, SEND_STATES.LOCKED, {
    acquiredAt: new Date().toISOString(),
    inboundEmailIdHash: hashIdentifier(inboundEmailId),
    senderHash: hashIdentifier(normalizeEmail(sender)),
    recipientHash: hashIdentifier(normalizeEmail(recipient)),
    policyTemplateIdHash: hashIdentifier(policyTemplateId),
  });

  return { acquired: true, blocked: false, sendKey, state: record.state };
}

// Forward-only transition. Releases the lock once a terminal state is
// written so a later acquire for the same key hits DURABLE_STATE_EXISTS.
export function transitionSend(stateDir, sendKey, toState, details = {}) {
  if (!sendKey || typeof sendKey !== 'string') {
    return { ok: false, reason: 'INVALID_SEND_KEY' };
  }
  if (!Object.prototype.hasOwnProperty.call(SEND_STATES, toState)) {
    return { ok: false, reason: 'UNKNOWN_STATE', toState };
  }

  const current = readState(stateDir, sendKey);
  if (!current) {
    return { ok: false, reason: 'NOT_FOUND', sendKey };
  }

  if (!canTransition(current.state, toState)) {
    return { ok: false, reason: 'INVALID_TRANSITION', fromState: current.state, toState, sendKey };
  }

  const record = writeState(stateDir, sendKey, toState, details);

  if (isTerminal(toState)) {
    releaseLock(lockPathFor(stateDir, sendKey));
  }

  return { ok: true, sendKey, state: record.state, updatedAt: record.updatedAt };
}

export function errorsDirFor(stateDir) {
  return path.join(stateDir, 'errors');
}

export function errorPathFor(stateDir, errorId) {
  return path.join(errorsDirFor(stateDir), `${errorId}.json`);
}

// Sanitised, atomic error record write. Returns the stored record
// (including the generated errorId).
export function writeErrorRecord(stateDir, record = {}) {
  const errorsDir = errorsDirFor(stateDir);
  fs.mkdirSync(errorsDir, { recursive: true });

  const errorId = crypto.randomBytes(8).toString('hex');
  const sanitized = sanitize({ ...record, errorId, recordedAt: new Date().toISOString() });

  const finalPath = errorPathFor(stateDir, errorId);
  const tmpPath = path.join(
    errorsDir,
    `${errorId}.${process.pid}.${Date.now()}.${crypto.randomBytes(4).toString('hex')}.tmp`
  );
  fs.writeFileSync(tmpPath, JSON.stringify(sanitized, null, 2), 'utf8');
  fs.renameSync(tmpPath, finalPath);
  return sanitized;
}

export function readErrorRecord(stateDir, errorId) {
  const errorPath = errorPathFor(stateDir, errorId);
  if (!fs.existsSync(errorPath)) return null;
  return JSON.parse(fs.readFileSync(errorPath, 'utf8'));
}

// ---------------------------------------------------------------------
// Phase 4B: read-only unfinished-record listing for the SLA Watchdog.
// ---------------------------------------------------------------------

const STATE_FILE_SUFFIX = '.state.json';

// Non-terminal send records only (LOCKED, SUBMITTING, SENT, SEND_UNCERTAIN).
// Returns sanitised details already written by writeState/transitionSend.
export function listUnfinishedSends(stateDir) {
  ensureStateDir(stateDir);
  const out = [];
  for (const entry of fs.readdirSync(stateDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(STATE_FILE_SUFFIX)) continue;
    const sendKey = entry.name.slice(0, -STATE_FILE_SUFFIX.length);
    const record = readState(stateDir, sendKey);
    if (!record || isTerminal(record.state)) continue;
    out.push({
      sendKey: record.sendKey,
      state: record.state,
      createdAt: record.createdAt || record.updatedAt,
      updatedAt: record.updatedAt,
      details: record.details,
    });
  }
  return out;
}

// Error records not yet marked resolved via resolveErrorRecord().
export function listUnresolvedErrors(stateDir) {
  const errorsDir = errorsDirFor(stateDir);
  if (!fs.existsSync(errorsDir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(errorsDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.json')) continue;
    const errorId = entry.name.slice(0, -'.json'.length);
    const record = readErrorRecord(stateDir, errorId);
    if (!record || record.resolved === true) continue;
    out.push(record);
  }
  return out;
}

// Marks an error record resolved (atomic write-tmp-then-rename), excluding
// it from listUnresolvedErrors() thereafter. Returns null if not found.
export function resolveErrorRecord(stateDir, errorId) {
  const record = readErrorRecord(stateDir, errorId);
  if (!record) return null;
  const updated = { ...record, resolved: true, resolvedAt: new Date().toISOString() };
  const errorsDir = errorsDirFor(stateDir);
  const finalPath = errorPathFor(stateDir, errorId);
  const tmpPath = path.join(
    errorsDir,
    `${errorId}.${process.pid}.${Date.now()}.${crypto.randomBytes(4).toString('hex')}.tmp`
  );
  fs.writeFileSync(tmpPath, JSON.stringify(updated, null, 2), 'utf8');
  fs.renameSync(tmpPath, finalPath);
  return updated;
}

// ---------------------------------------------------------------------
// Phase 4B: atomic alert deduplication.
//
// The alert key is an arbitrary stable string (built deterministically by
// watchdog-core.mjs from category/SLO-type/record-identifier/status). It is
// hashed before use as a filename; the underlying open('wx') gives the same
// atomic create-once guarantee as acquireLock(), so concurrent and
// sequential repeats of the same alert are both blocked.
// ---------------------------------------------------------------------

export function alertsDirFor(stateDir) {
  return path.join(stateDir, 'alerts');
}

function alertPathFor(stateDir, alertKey) {
  const hash = crypto.createHash('sha256').update(String(alertKey ?? ''), 'utf8').digest('hex');
  return { hash, filePath: path.join(alertsDirFor(stateDir), `${hash}.json`) };
}

export function recordAlertOnce(stateDir, alertKey, details = {}) {
  const alertsDir = alertsDirFor(stateDir);
  fs.mkdirSync(alertsDir, { recursive: true });
  const { hash, filePath } = alertPathFor(stateDir, alertKey);
  const now = new Date().toISOString();
  try {
    const fd = fs.openSync(filePath, 'wx');
    try {
      fs.writeFileSync(fd, JSON.stringify({ alertKeyHash: hash, firstSeenAt: now, details: sanitize(details) }, null, 2), 'utf8');
    } finally {
      fs.closeSync(fd);
    }
    return { deduped: false, alertKeyHash: hash, firstSeenAt: now };
  } catch (error) {
    if (error?.code === 'EEXIST') {
      const existing = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      return { deduped: true, alertKeyHash: hash, firstSeenAt: existing.firstSeenAt };
    }
    throw error;
  }
}

// ---------------------------------------------------------------------
// Phase 4B: sanitised SLA Watchdog / Test Harness result persistence.
// Same atomic write-tmp-then-rename pattern as writeErrorRecord().
// ---------------------------------------------------------------------

export function phase4bResultsDirFor(stateDir) {
  return path.join(stateDir, 'phase4b-results');
}

function phase4bResultPathFor(stateDir, resultId) {
  return path.join(phase4bResultsDirFor(stateDir), `${resultId}.json`);
}

export function writePhase4bResult(stateDir, record = {}) {
  const dir = phase4bResultsDirFor(stateDir);
  fs.mkdirSync(dir, { recursive: true });

  const resultId = crypto.randomBytes(8).toString('hex');
  const sanitized = sanitize({ ...record, resultId, recordedAt: new Date().toISOString() });

  const finalPath = phase4bResultPathFor(stateDir, resultId);
  const tmpPath = path.join(
    dir,
    `${resultId}.${process.pid}.${Date.now()}.${crypto.randomBytes(4).toString('hex')}.tmp`
  );
  fs.writeFileSync(tmpPath, JSON.stringify(sanitized, null, 2), 'utf8');
  fs.renameSync(tmpPath, finalPath);
  return sanitized;
}

export function readPhase4bResult(stateDir, resultId) {
  const resultPath = phase4bResultPathFor(stateDir, resultId);
  if (!fs.existsSync(resultPath)) return null;
  return JSON.parse(fs.readFileSync(resultPath, 'utf8'));
}
