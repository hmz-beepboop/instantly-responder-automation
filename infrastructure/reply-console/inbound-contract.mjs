// Canonical Instantly-received-email contract.
//
// Eligibility and presentation are deliberately separate:
//   isInstantlyReceived(...) === true  => notificationRequired === true
//   classifyInboundLabel(...)         => presentation / Send capability only
//
// This module must be used by webhook, poll, backfill and completeness-audit
// paths. It never decides that a received record is commercially unimportant.

import crypto from 'node:crypto';

export const INBOUND_SCHEMA_VERSION = 2;
export const IDENTITY_KINDS = Object.freeze({
  INSTANTLY: 'INSTANTLY_EMAIL_ID',
  SURROGATE: 'SURROGATE_UNVERIFIED',
});
export const LABELS = Object.freeze({
  ORDINARY: 'ordinary',
  AUTOMATIC: 'automatic',
  OOO: 'out_of_office',
  UNSUBSCRIBE: 'unsubscribe',
  BOUNCE: 'bounce',
  SYSTEM: 'system',
  ATTACHMENT_ONLY: 'attachment_only',
  EMPTY: 'empty',
  MALFORMED: 'malformed',
  UNKNOWN: 'unknown',
});

const MAX = Object.freeze({
  id: 512,
  email: 320,
  thread: 1024,
  campaign: 512,
  name: 240,
  subject: 500,
  preview: 1000,
  messageId: 1024,
  source: 80,
});

function digest(value) {
  return crypto.createHash('sha256').update(String(value ?? ''), 'utf8').digest('hex');
}

function stableJson(value, seen = new WeakSet()) {
  if (value === null || value === undefined || typeof value !== 'object') return JSON.stringify(value ?? null);
  if (seen.has(value)) return '"[circular]"';
  seen.add(value);
  if (Array.isArray(value)) return `[${value.map((item) => stableJson(item, seen)).join(',')}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key], seen)}`).join(',')}}`;
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function first(value, keys) {
  for (const key of keys) {
    const parts = key.split('.');
    let current = value;
    for (const part of parts) current = isPlainObject(current) ? current[part] : undefined;
    if (current !== undefined && current !== null) return current;
  }
  return undefined;
}

function replaceMalformedUnicode(value) {
  // JSON text is Unicode, but JavaScript strings can still contain unpaired
  // surrogates. Replace those deterministically so logs, SQLite and Chat see
  // valid scalar text.
  return value
    .replace(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])/g, '\uFFFD')
    .replace(/(^|[^\uD800-\uDBFF])[\uDC00-\uDFFF]/g, '$1\uFFFD');
}

function scalar(value, field, maxLength, issues, { lower = false } = {}) {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string' && typeof value !== 'number' && typeof value !== 'boolean') {
    issues.push(`${field}:unexpected_type`);
    return '';
  }
  let text = String(value);
  const repaired = replaceMalformedUnicode(text);
  if (repaired !== text) issues.push(`${field}:invalid_unicode`);
  text = repaired.replace(/[\u0000-\u001F\u007F\u200B-\u200D\uFEFF]/g, ' ').trim();
  if (text.length > maxLength) {
    issues.push(`${field}:oversized`);
    text = text.slice(0, maxLength);
  }
  return lower ? text.toLowerCase() : text;
}

export function sanitizeChatText(value, maxLength = MAX.preview) {
  let text = replaceMalformedUnicode(String(value ?? ''));
  text = text
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/[<>]/g, ' ')
    .replace(/[\u0000-\u001F\u007F\u200B-\u200D\uFEFF]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (text.length > maxLength) text = `${text.slice(0, maxLength).trim()}…`;
  return text;
}

function normalizeTimestamp(value, issues) {
  if (value === undefined || value === null || value === '') {
    issues.push('received_at:missing');
    return null;
  }
  const raw = scalar(value, 'received_at', 100, issues);
  const ms = Date.parse(raw);
  if (!Number.isFinite(ms)) {
    issues.push('received_at:invalid');
    return null;
  }
  return new Date(ms).toISOString();
}

function hasAttachment(raw) {
  const candidates = [raw.attachments, raw.files, raw.attachment, raw.body?.attachments];
  return candidates.some((candidate) => Array.isArray(candidate) ? candidate.length > 0 : Boolean(candidate));
}

export function isInstantlyReceived(record, { authoritativeReceived = false } = {}) {
  if (authoritativeReceived) return true;
  const raw = isPlainObject(record?.body) && record.event_type === undefined ? record.body : record;
  if (!isPlainObject(raw)) return false;
  const eventType = String(raw.event_type ?? raw.eventType ?? '').trim().toLowerCase();
  if (eventType === 'reply_received') return true;
  const emailType = String(raw.email_type ?? raw.type ?? '').trim().toLowerCase();
  if (emailType === 'received' || emailType === 'inbound') return true;
  return Number(raw.ue_type) === 2;
}

export function classifyInboundLabel(record) {
  const subject = String(record.subject ?? '').toLowerCase();
  const sender = String(record.prospectEmail ?? record.senderEmail ?? '').toLowerCase();
  const preview = String(record.preview ?? '').toLowerCase();
  const combined = `${subject}\n${preview}`;

  const mailSystemSender = /(^|[<\s])(mailer-daemon|postmaster|mail-daemon|maildelivery)[@+>\s]/i.test(sender)
    || /(mailer-daemon|postmaster)@/i.test(sender);
  const bounceSubject = /(^|\b)(delivery status notification|delivery failure|delivery failed|undeliverable|returned mail|mail delivery failed|failure notice|mailbox unavailable)(\b|:)/i.test(subject);
  if (mailSystemSender || bounceSubject) {
    return { classification: mailSystemSender ? LABELS.SYSTEM : LABELS.BOUNCE, notificationRequired: true };
  }
  if (/\b(unsubscribe|remove me|stop emailing|do not (?:email|contact)|opt[ -]?out)\b/i.test(combined)) {
    return { classification: LABELS.UNSUBSCRIBE, notificationRequired: true };
  }
  const explicitAuto = record.isAutoReply === true || record.isAutoReply === 1;
  if (explicitAuto || /(^|\b)(automatic reply|auto[ -]?reply|automated response)(\b|:)/i.test(subject)) {
    return { classification: LABELS.AUTOMATIC, notificationRequired: true };
  }
  if (/\b(out[ -]?of[ -]?(?:the[ -]?)?office|away from (?:the )?office|on (?:annual )?leave|vacation responder)\b/i.test(combined)) {
    return { classification: LABELS.OOO, notificationRequired: true };
  }
  if (record.metadataIssues?.length && !record.prospectEmail && !record.eaccount) {
    return { classification: LABELS.MALFORMED, notificationRequired: true };
  }
  if (!record.preview && record.hasAttachment) {
    return { classification: LABELS.ATTACHMENT_ONLY, notificationRequired: true };
  }
  if (!record.preview && !record.subject) {
    return { classification: LABELS.EMPTY, notificationRequired: true };
  }
  if (record.preview || record.subject || record.prospectEmail) {
    return { classification: LABELS.ORDINARY, notificationRequired: true };
  }
  return { classification: LABELS.UNKNOWN, notificationRequired: true };
}

function unwrap(rawInput) {
  if (!isPlainObject(rawInput)) return {};
  if (isPlainObject(rawInput.body) && rawInput.event_type === undefined && rawInput.id === undefined) return rawInput.body;
  if (isPlainObject(rawInput.event) && rawInput.event_type === undefined && rawInput.id === undefined) return rawInput.event;
  return rawInput;
}

export function normalizeInstantlyReceived(rawInput, {
  authoritativeReceived = false,
  discoverySource = 'UNKNOWN',
  workspace = '',
  observedAt = new Date().toISOString(),
} = {}) {
  const raw = unwrap(rawInput);
  if (!isInstantlyReceived(raw, { authoritativeReceived })) {
    return { ok: false, notificationRequired: false, reason: 'NOT_INSTANTLY_RECEIVED' };
  }

  const issues = [];
  if (!isPlainObject(rawInput)) issues.push('record:unexpected_type');
  const instantlyEmailId = scalar(first(raw, ['id', 'email_id', 'reply_id']), 'instantly_email_id', MAX.id, issues);
  const eaccount = scalar(first(raw, ['eaccount', 'email_account', 'receiving_account', 'to_address_email']), 'eaccount', MAX.email, issues, { lower: true });
  const prospectEmail = scalar(first(raw, ['from_address_email', 'from_address_json.email', 'lead_email', 'email', 'lead']), 'prospect_email', MAX.email, issues, { lower: true });
  const messageId = scalar(first(raw, ['message_id', 'rfc_message_id', 'headers.message-id']), 'message_id', MAX.messageId, issues);
  const threadId = scalar(first(raw, ['thread_id', 'threadId']), 'thread_id', MAX.thread, issues);
  const campaignId = scalar(first(raw, ['campaign_id', 'campaign']), 'campaign_id', MAX.campaign, issues);
  const campaignName = scalar(first(raw, ['campaign_name']), 'campaign_name', MAX.campaign, issues);
  const leadId = scalar(first(raw, ['lead_id', 'leadId']), 'lead_id', MAX.id, issues);
  const subjectCandidate = first(raw, ['subject', 'reply_subject']);
  if (subjectCandidate !== undefined && subjectCandidate !== null
    && !['string', 'number', 'boolean'].includes(typeof subjectCandidate)) issues.push('subject:unexpected_type');
  if (String(subjectCandidate ?? '').length > MAX.subject) issues.push('subject:oversized');
  const subject = sanitizeChatText(subjectCandidate, MAX.subject);
  const previewCandidate = first(raw, ['content_preview', 'reply_text_snippet', 'reply_text', 'body.text', 'body_text', 'text']);
  if (previewCandidate !== undefined && previewCandidate !== null
    && !['string', 'number', 'boolean'].includes(typeof previewCandidate)) issues.push('body:unexpected_type');
  if (String(previewCandidate ?? '').length > MAX.preview) issues.push('body:oversized');
  const preview = sanitizeChatText(previewCandidate, MAX.preview);
  const receivedAt = normalizeTimestamp(first(raw, ['timestamp_created', 'timestamp_email', 'timestamp', 'reply_timestamp', 'received_at']), issues);
  const source = scalar(discoverySource, 'discovery_source', MAX.source, issues) || 'UNKNOWN';
  const organisation = scalar(first(raw, ['organization', 'organisation', 'workspace', 'workspace_id', 'organization_id']) || workspace,
    'workspace', MAX.id, issues);
  const prospectName = sanitizeChatText([
    first(raw, ['First_name', 'first_name', 'firstName']),
    first(raw, ['Last_name', 'last_name', 'lastName']),
  ].filter((v) => v !== undefined && v !== null).join(' '), MAX.name);
  const uniboxRaw = scalar(first(raw, ['unibox_url']), 'unibox_url', 2048, issues);
  const uniboxUrl = /^https:\/\/[^\s<>|]+$/i.test(uniboxRaw)
    ? uniboxRaw
    : 'https://app.instantly.ai/app/unibox';
  if (uniboxRaw && uniboxUrl !== uniboxRaw) issues.push('unibox_url:invalid');

  if (!instantlyEmailId) issues.push('instantly_email_id:missing');
  if (!prospectEmail) issues.push('prospect_email:missing');
  if (!eaccount) issues.push('eaccount:missing');
  if (!campaignId) issues.push('campaign_id:missing');
  if (!leadId) issues.push('lead_id:missing');
  if (!threadId) issues.push('thread_id:missing');
  if (!messageId) issues.push('message_id:missing');
  if (!subject) issues.push('subject:blank');
  if (!preview) issues.push('body:blank');

  const bodyHash = digest(String(previewCandidate ?? ''));
  // Hash (never store) the complete API object so two malformed records that
  // differ only in an unexpected field do not collapse onto one surrogate.
  const rawFingerprint = digest(stableJson(raw));
  const surrogateParts = [organisation, eaccount, messageId, threadId, receivedAt || '', prospectEmail, bodyHash, rawFingerprint];
  const identityKind = instantlyEmailId ? IDENTITY_KINDS.INSTANTLY : IDENTITY_KINDS.SURROGATE;
  const identity = instantlyEmailId
    ? `instantly:${instantlyEmailId}`
    : `surrogate:${digest(surrogateParts.join('\u001f'))}`;

  const base = {
    schemaVersion: INBOUND_SCHEMA_VERSION,
    identity,
    identityKind,
    instantlyEmailId: instantlyEmailId || null,
    workspace: organisation || null,
    eaccount: eaccount || null,
    prospectEmail: prospectEmail || null,
    prospectName: prospectName || null,
    campaignId: campaignId || null,
    campaignName: campaignName || null,
    leadId: leadId || null,
    threadId: threadId || null,
    messageId: messageId || null,
    subject: subject || null,
    preview: preview || null,
    bodyHash,
    hasAttachment: hasAttachment(raw),
    isAutoReply: first(raw, ['is_auto_reply']) === true || Number(first(raw, ['is_auto_reply'])) === 1,
    receivedAt,
    observedAt: normalizeTimestamp(observedAt, []) || new Date().toISOString(),
    discoverySource: source,
    uniboxUrl,
    metadataIssues: [...new Set(issues)].sort(),
  };
  const classified = classifyInboundLabel(base);
  const degradedMetadata = base.metadataIssues.length > 0;   // retained for telemetry/compat only
  // Explicit, independent state dimensions (see isAuthoritativeRoutingComplete):
  const authoritativeRoutingComplete = identityKind === IDENTITY_KINDS.INSTANTLY
    && Boolean(eaccount && prospectEmail && (threadId || instantlyEmailId));
  // Optional presentation enrichment — never affects routing safety or Send.
  const optionalEnrichmentComplete = Boolean(campaignName && leadId && prospectName && subject && preview);
  // sendAllowed derives ONLY from authoritative routing + classification, never
  // from optional campaign enrichment.
  const sendAllowed = authoritativeRoutingComplete
    && ![LABELS.AUTOMATIC, LABELS.OOO, LABELS.UNSUBSCRIBE, LABELS.BOUNCE, LABELS.SYSTEM, LABELS.MALFORMED, LABELS.UNKNOWN].includes(classified.classification);

  return {
    ok: true,
    notificationRequired: true,
    record: {
      ...base,
      classification: classified.classification,
      degradedMetadata,
      authoritativeRoutingComplete,
      optionalEnrichmentComplete,
      sendAllowed,
      threadKey: `hmz-inbound-v2-${digest(identity).slice(0, 32)}`,
    },
  };
}

function available(value, fallback = 'unavailable') {
  return sanitizeChatText(value || fallback, 500) || fallback;
}

// --- explicit, independent state dimensions ---------------------------------
// Authoritative routing safety and optional presentation enrichment are
// SEPARATE concerns. Routing completeness is the only input to send-warning /
// Send-visibility; optional enrichment (campaign display, lead id, message id,
// display names) never blocks a reply and never triggers a routing warning.
export function isAuthoritativeRoutingComplete(record) {
  return record.identityKind === IDENTITY_KINDS.INSTANTLY
    && Boolean(record.eaccount && record.prospectEmail && (record.threadId || record.instantlyEmailId));
}
export function missingRoutingFields(record) {
  const m = [];
  if (record.identityKind !== IDENTITY_KINDS.INSTANTLY) m.push('instantly_identity');
  if (!record.eaccount) m.push('eaccount');
  if (!record.prospectEmail) m.push('prospect_email');
  if (!record.threadId && !record.instantlyEmailId) m.push('instantly_thread_or_email_id');
  return m;
}

export function notificationTitle(record, { recovered = false, probableDuplicate = false } = {}) {
  let title;
  switch (record.classification) {
    case LABELS.AUTOMATIC: title = '🤖 Automatic Reply'; break;
    case LABELS.OOO: title = '🤖 Out-of-Office Reply'; break;
    case LABELS.UNSUBSCRIBE: title = '🛑 Unsubscribe Request'; break;
    case LABELS.BOUNCE:
    case LABELS.SYSTEM: title = '📨 Mail-System/Bounce Notice'; break;
    case LABELS.ATTACHMENT_ONLY: title = '📎 Instantly Inbound Email — Attachment Only'; break;
    case LABELS.EMPTY: title = '✉️ Instantly Inbound Email — Empty Message'; break;
    default: title = '🔔 New Instantly Inbound Email';
  }
  // Warn in the header ONLY when authoritative routing is incomplete — never
  // for optional-enrichment gaps (e.g. an unregistered campaign).
  if (!isAuthoritativeRoutingComplete(record)) {
    title = '⚠️ Instantly Inbound Email — Routing Incomplete';
  }
  if (recovered) title += ' (recovered)';
  if (probableDuplicate) title = `⚠️ Probable Duplicate Recovery — ${title}`;
  return title;
}

export function buildNotificationText(record, options = {}) {
  if (options.historicalBackfill === true) {
    const lines = [
      '[HISTORICAL BACKFILL — PRE-CONSOLE INSTANTLY EMAIL]', '',
    ];
    if (options.probableDuplicate === true) {
      lines.push('⚠️ Probable duplicate recovery attempt after an ambiguous Google Chat response.', '');
    }
    lines.push(
      'This email predates the Google Chat console. It was still durably registered and individually notified.', '',
      `Type: ${available(record.classification, LABELS.UNKNOWN)}`,
      `Prospect: ${available(record.prospectName ? `${record.prospectName} <${record.prospectEmail || 'unavailable'}>` : record.prospectEmail)}`,
      `Sender mailbox: ${available(record.eaccount)}`,
      `Campaign: ${available(record.campaignName || record.campaignId)}`,
      `Subject: ${available(record.subject, '(no subject)')}`,
      `Originally received: ${available(record.receivedAt)}`, '',
      `${record.uniboxUrl || 'https://app.instantly.ai/app/unibox'} — Review in Instantly`, '',
      'Reply controls are disabled for this historical notification.'
    );
    return lines.join('\n');
  }
  const lines = [
    notificationTitle(record, options), '',
    `Type: ${available(record.classification, LABELS.UNKNOWN)}`,
    `Prospect: ${available(record.prospectName ? `${record.prospectName} (${record.prospectEmail || 'email unavailable'})` : record.prospectEmail)}`,
    `Sender mailbox: ${available(options.senderName ? `${options.senderName} (${record.eaccount})` : record.eaccount)}`,
    `Campaign: ${available(record.campaignName || record.campaignId)}`,
    `Subject: ${available(record.subject, '(no subject)')}`,
    `Received: ${available(record.receivedAt)}`, '',
    'Reply preview:', available(record.preview, record.hasAttachment ? '(attachment only)' : '(no text supplied)'), '',
    `${record.uniboxUrl || 'https://app.instantly.ai/app/unibox'} — Review in Instantly`,
  ];
  if (!isAuthoritativeRoutingComplete(record)) {
    // Case 2/4: authoritative routing incomplete — the primary safety message.
    const missing = missingRoutingFields(record).join(', ') || 'required routing fields';
    lines.push('', `⚠️ Routing incomplete — unavailable: ${missing}. This email was still registered and notified.`,
      'Reply sending is unavailable until authoritative routing is recovered.');
  } else {
    // Routing complete. Optional-enrichment gaps get a narrow, non-blocking note
    // only where useful, and never suppress Send.
    if (!record.campaignName) {
      lines.push('', `Campaign details unavailable${record.campaignId ? ` (campaign context not registered: ${available(record.campaignId)})` : ''}. Reply routing is unaffected.`);
    }
    if (record.sendAllowed) {
      lines.push('', 'To reply from Google Chat, reply in this thread and mention @Instantly followed by your response.');
    } else {
      lines.push('', 'Reply through this Chat notification is unavailable for this record type.');
    }
  }
  return lines.join('\n');
}
