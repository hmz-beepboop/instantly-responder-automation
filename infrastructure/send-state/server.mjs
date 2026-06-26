// hmz-send-state: minimal internal HTTP JSON sidecar for Phase 4A send
// ownership and sanitised error records. Node.js built-ins only.
//
// Endpoints:
//   GET  /health
//   POST /v1/send/acquire      { inboundEmailId, sender, recipient, policyTemplateId }
//   POST /v1/send/transition   { sendKey, toState, details }
//   GET  /v1/send/:sendKey
//   POST /v1/error             { ...sanitised fields... }
//   GET  /v1/error/:errorId
//   POST /v1/error/:errorId/resolve              (Phase 4B)
//   GET  /v1/unfinished                          (Phase 4B, read-only)
//   POST /v1/alert/dedupe      { alertKey | alertKeys, details }  (Phase 4B)
//   POST /v1/phase4b/result    { ...sanitised fields... }         (Phase 4B)
//   GET  /v1/phase4b/result/:resultId                              (Phase 4B)
//
// Binds to 0.0.0.0:5681 inside the container. Not published to the host
// (see infrastructure/local-n8n/docker-compose.yml). n8n reaches this
// service as http://hmz-send-state:5681 on the Docker Compose network.

import http from 'node:http';
import {
  acquireSend,
  transitionSend,
  readState,
  writeErrorRecord,
  readErrorRecord,
  listUnfinishedSends,
  listUnresolvedErrors,
  resolveErrorRecord,
  recordAlertOnce,
  writePhase4bResult,
  readPhase4bResult,
} from './state-store.mjs';

export const DEFAULT_PORT = 5681;
export const DEFAULT_HOST = '0.0.0.0';

const SEND_KEY_PATTERN = /^[0-9a-f]{64}$/;
const ERROR_ID_PATTERN = /^[0-9a-f]{16}$/;
const RESULT_ID_PATTERN = /^[0-9a-f]{16}$/;

function sendJson(res, status, body) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(json),
  });
  res.end(json);
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) {
        reject(new Error('payload_too_large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (chunks.length === 0) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (error) {
        reject(new Error('invalid_json_body'));
      }
    });
    req.on('error', reject);
  });
}

export function createSendStateServer(stateDir) {
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://hmz-send-state');

      if (req.method === 'GET' && url.pathname === '/health') {
        return sendJson(res, 200, { status: 'ok' });
      }

      if (req.method === 'POST' && url.pathname === '/v1/send/acquire') {
        const body = await readJsonBody(req);
        const result = acquireSend(stateDir, {
          inboundEmailId: body.inboundEmailId,
          sender: body.sender,
          recipient: body.recipient,
          policyTemplateId: body.policyTemplateId,
        });
        return sendJson(res, result.acquired ? 200 : 409, result);
      }

      if (req.method === 'POST' && url.pathname === '/v1/send/transition') {
        const body = await readJsonBody(req);
        const result = transitionSend(stateDir, body.sendKey, body.toState, body.details || {});
        return sendJson(res, result.ok ? 200 : 409, result);
      }

      const sendMatch = url.pathname.match(/^\/v1\/send\/([^/]+)$/);
      if (req.method === 'GET' && sendMatch) {
        const sendKey = sendMatch[1];
        if (!SEND_KEY_PATTERN.test(sendKey)) {
          return sendJson(res, 400, { error: 'invalid_send_key' });
        }
        const state = readState(stateDir, sendKey);
        if (!state) return sendJson(res, 404, { found: false, sendKey });
        return sendJson(res, 200, { found: true, ...state });
      }

      if (req.method === 'POST' && url.pathname === '/v1/error') {
        const body = await readJsonBody(req);
        const record = writeErrorRecord(stateDir, body);
        return sendJson(res, 201, { errorId: record.errorId });
      }

      const errorMatch = url.pathname.match(/^\/v1\/error\/([^/]+)$/);
      if (req.method === 'GET' && errorMatch) {
        const errorId = errorMatch[1];
        if (!ERROR_ID_PATTERN.test(errorId)) {
          return sendJson(res, 400, { error: 'invalid_error_id' });
        }
        const record = readErrorRecord(stateDir, errorId);
        if (!record) return sendJson(res, 404, { found: false, errorId });
        return sendJson(res, 200, { found: true, ...record });
      }

      const errorResolveMatch = url.pathname.match(/^\/v1\/error\/([^/]+)\/resolve$/);
      if (req.method === 'POST' && errorResolveMatch) {
        const errorId = errorResolveMatch[1];
        if (!ERROR_ID_PATTERN.test(errorId)) {
          return sendJson(res, 400, { error: 'invalid_error_id' });
        }
        const record = resolveErrorRecord(stateDir, errorId);
        if (!record) return sendJson(res, 404, { found: false, errorId });
        return sendJson(res, 200, { found: true, ...record });
      }

      // Phase 4B: read-only listing of unfinished send/error records for
      // SLA Watchdog evaluation. No message bodies, no credentials.
      if (req.method === 'GET' && url.pathname === '/v1/unfinished') {
        return sendJson(res, 200, {
          sends: listUnfinishedSends(stateDir),
          errors: listUnresolvedErrors(stateDir),
        });
      }

      // Phase 4B: atomic alert deduplication. Accepts either { alertKey }
      // or { alertKeys: [...] }; each key is hashed and recorded at most
      // once via an exclusive create (open('wx')).
      if (req.method === 'POST' && url.pathname === '/v1/alert/dedupe') {
        const body = await readJsonBody(req);
        const keys = Array.isArray(body.alertKeys)
          ? body.alertKeys
          : (body.alertKey != null ? [body.alertKey] : []);
        const results = keys.map((alertKey) => ({
          alertKey,
          ...recordAlertOnce(stateDir, alertKey, body.details || {}),
        }));
        return sendJson(res, 200, { results });
      }

      // Phase 4B: sanitised SLA Watchdog / Test Harness result persistence.
      if (req.method === 'POST' && url.pathname === '/v1/phase4b/result') {
        const body = await readJsonBody(req);
        const record = writePhase4bResult(stateDir, body);
        return sendJson(res, 201, { resultId: record.resultId });
      }

      const resultMatch = url.pathname.match(/^\/v1\/phase4b\/result\/([^/]+)$/);
      if (req.method === 'GET' && resultMatch) {
        const resultId = resultMatch[1];
        if (!RESULT_ID_PATTERN.test(resultId)) {
          return sendJson(res, 400, { error: 'invalid_result_id' });
        }
        const record = readPhase4bResult(stateDir, resultId);
        if (!record) return sendJson(res, 404, { found: false, resultId });
        return sendJson(res, 200, { found: true, ...record });
      }

      sendJson(res, 404, { error: 'not_found' });
    } catch (error) {
      sendJson(res, 400, { error: 'bad_request', message: error?.message || String(error) });
    }
  });
}

function isMainModule() {
  return process.argv[1] && process.argv[1].endsWith('server.mjs');
}

if (isMainModule()) {
  const stateDir = process.env.STATE_DIR || '/data';
  const server = createSendStateServer(stateDir);
  server.listen(DEFAULT_PORT, DEFAULT_HOST, () => {
    // eslint-disable-next-line no-console
    console.log(`hmz-send-state listening on ${DEFAULT_HOST}:${DEFAULT_PORT}, state dir ${stateDir}`);
  });
}
