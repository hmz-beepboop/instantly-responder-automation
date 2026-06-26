import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const STATES = Object.freeze({
  READY: 'READY',
  LOCKED: 'LOCKED',
  SUBMITTING: 'SUBMITTING',
  SEND_UNCERTAIN: 'SEND_UNCERTAIN',
  SENT_RECONCILED: 'SENT_RECONCILED',
  HUMAN_REVIEW_ZERO_MATCHES: 'HUMAN_REVIEW_ZERO_MATCHES',
  HUMAN_REVIEW_MULTIPLE_MATCHES: 'HUMAN_REVIEW_MULTIPLE_MATCHES',
  HUMAN_REVIEW_RECONCILIATION_ERROR: 'HUMAN_REVIEW_RECONCILIATION_ERROR',
  HUMAN_REVIEW_UPSTREAM_NON_2XX: 'HUMAN_REVIEW_UPSTREAM_NON_2XX',
  HUMAN_REVIEW_UPSTREAM_ERROR: 'HUMAN_REVIEW_UPSTREAM_ERROR',
  BLOCKED: 'BLOCKED',
});

function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

// Stable across process restarts. The body marker is deliberately excluded,
// otherwise a rerun would derive a new key and could send a duplicate.
export function deriveSendKey({ inboundEmailId, sender, recipient }) {
  const raw = [
    'V5_LAYER2_REPLY',
    String(inboundEmailId ?? '').trim(),
    normalizeEmail(sender),
    normalizeEmail(recipient),
  ].join('|');
  return crypto.createHash('sha256').update(raw, 'utf8').digest('hex');
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
  const payload = {
    sendKey,
    state,
    updatedAt: new Date().toISOString(),
    details,
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
