// Google Chat request verification — dual strict mode.
//
// Google signs every interaction request to a Chat app with a bearer JWT. Two
// official verification modes exist, depending on the app's Authentication
// Audience setting (per Google's "Verify requests from Chat"):
//
//   A. HTTP endpoint URL  -> OIDC ID token; aud == exact endpoint URL;
//      iss ∈ {accounts.google.com}; email == chat@system.gserviceaccount.com.
//   B. Project Number     -> self-signed JWT from the Chat service account;
//      aud == the Google Cloud project number; iss == email ==
//      chat@system.gserviceaccount.com; signature verified with Google's Chat
//      service-account x509 certs.
//
// Each mode is independently strict. We route by the (decode-only) aud claim,
// then cryptographically verify with the maintained google-auth-library. We
// never trust the decode; it only selects the mode and drives sanitized
// diagnostics. Bearer tokens are NEVER logged.

import { OAuth2Client } from 'google-auth-library';

const CHAT_ISSUER_EMAIL = 'chat@system.gserviceaccount.com';
const ACCEPTED_ID_ISSUERS = new Set(['accounts.google.com', 'https://accounts.google.com']);
const CHAT_CERT_URL =
  'https://www.googleapis.com/service_accounts/v1/metadata/x509/chat@system.gserviceaccount.com';

const client = new OAuth2Client();
const DEBUG = process.env.CHAT_VERIFY_DEBUG === '1';

let certCache = { certs: null, at: 0 };
async function getChatCerts() {
  if (certCache.certs && Date.now() - certCache.at < 60 * 60 * 1000) return certCache.certs;
  const r = await fetch(CHAT_CERT_URL);
  if (!r.ok) throw new Error('cert_fetch_failed_' + r.status);
  const certs = await r.json();
  certCache = { certs, at: Date.now() };
  return certs;
}

// Decode header+payload WITHOUT verifying — diagnostics + mode routing only.
function decodeUnverified(token) {
  const parts = String(token).split('.');
  if (parts.length !== 3) return { segments: parts.length };
  const b64 = (s) => Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
  let header = {}, payload = {};
  try { header = JSON.parse(b64(parts[0])); } catch { /* ignore */ }
  try { payload = JSON.parse(b64(parts[1])); } catch { /* ignore */ }
  return { segments: 3, header, payload };
}

function redactEmail(e) {
  const s = String(e || '');
  const [u, d] = s.split('@');
  return d ? `${u.slice(0, 2)}***@${d}` : null;
}

function classifyAud(audStr, audienceUrl) {
  if (audStr && audStr === audienceUrl) return 'endpoint_url';
  if (/^[0-9]{4,}$/.test(String(audStr))) return 'project_number';
  return 'other';
}

// Sanitized diagnostic record — safe to log/return. Never contains the token.
function sanitizedDiag(decoded, audienceUrl) {
  const h = decoded.header || {}, p = decoded.payload || {};
  const audStr = String(p.aud || '');
  const audKind = classifyAud(audStr, audienceUrl);
  return {
    segments: decoded.segments,
    alg: h.alg || null,
    kid: h.kid ? String(h.kid).slice(0, 8) + '…' : null,
    iss: p.iss || null,
    aud_kind: audKind,
    // A GCP project number is a non-secret identifier; expose it so an observed
    // mention reveals the value to configure mode B. Endpoint URLs are already
    // known; anything else is withheld.
    aud_value: audKind === 'project_number' ? audStr : (audKind === 'endpoint_url' ? '<endpoint_url>' : null),
    aud_len: audStr.length || 0,
    email: redactEmail(p.email),
    email_verified: p.email_verified === true,
    iat: p.iat || null,
    exp: p.exp || null,
  };
}

function mapErr(e) {
  const m = String(e?.message || '');
  if (/audience|wrong recipient/i.test(m)) return 'WRONG_AUDIENCE';
  if (/\bexpired\b|too late|used too late/i.test(m)) return 'TOKEN_EXPIRED';
  if (/cert/i.test(m)) return 'CERT_ERROR';
  return 'SIGNATURE_OR_CLAIM_INVALID';
}

export async function verifyChatBearer(token, audienceUrl, projectNumber) {
  if (!token || typeof token !== 'string') return { verified: false, reason: 'MISSING_TOKEN' };
  const decoded = decodeUnverified(token);
  const diag = sanitizedDiag(decoded, audienceUrl);
  if (DEBUG) console.log('[verify] ' + JSON.stringify(diag));   // sanitized; never the token

  // Mode A — endpoint-URL OIDC ID token
  if (diag.aud_kind === 'endpoint_url') {
    if (!audienceUrl) return { verified: false, reason: 'MISSING_AUDIENCE_CONFIG', diag };
    try {
      const ticket = await client.verifyIdToken({ idToken: token, audience: audienceUrl });
      const pl = ticket.getPayload() || {};
      if (pl.email !== CHAT_ISSUER_EMAIL || pl.email_verified !== true)
        return { verified: false, reason: 'NOT_CHAT_SERVICE_IDENTITY', diag };
      if (!ACCEPTED_ID_ISSUERS.has(pl.iss)) return { verified: false, reason: 'UNEXPECTED_ISSUER', diag };
      if (pl.aud !== audienceUrl) return { verified: false, reason: 'WRONG_AUDIENCE', diag };
      return { verified: true, mode: 'endpoint_url', chatServiceEmail: pl.email, aud: pl.aud, iss: pl.iss, exp: pl.exp };
    } catch (e) { return { verified: false, reason: mapErr(e), diag }; }
  }

  // Mode B — project-number Chat-SA self-signed JWT
  if (diag.aud_kind === 'project_number') {
    if (!projectNumber) return { verified: false, reason: 'MISSING_PROJECT_NUMBER_CONFIG', diag };
    try {
      const certs = await getChatCerts();
      const login = await client.verifySignedJwtWithCertsAsync(
        token, certs, String(projectNumber), [CHAT_ISSUER_EMAIL]);
      const pl = (login && typeof login.getPayload === 'function') ? login.getPayload() : (login?.payload || {});
      if (String(pl.aud) !== String(projectNumber)) return { verified: false, reason: 'WRONG_AUDIENCE', diag };
      if (pl.iss !== CHAT_ISSUER_EMAIL) return { verified: false, reason: 'UNEXPECTED_ISSUER', diag };
      return { verified: true, mode: 'project_number', chatServiceEmail: CHAT_ISSUER_EMAIL, aud: String(pl.aud), iss: pl.iss, exp: pl.exp };
    } catch (e) { return { verified: false, reason: mapErr(e), diag }; }
  }

  return { verified: false, reason: 'UNKNOWN_AUDIENCE_MODE', diag };
}
