// Localhost-only mock server for V5 Layer 1 fault-injection scenarios.
// Bound to 127.0.0.1 only. Never contacts an external host.

import http from 'node:http';

function drainRequestBody(req) {
  return new Promise((resolve) => {
    req.on('data', () => {});
    req.on('end', resolve);
  });
}

async function respondJson(req, res, status, body, extraHeaders = {}) {
  await drainRequestBody(req);
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
    ...extraHeaders,
  });
  res.end(payload);
}

// Destroys the connection before the request body has been fully read by
// the server -- represents a reset before submission can be confirmed.
function resetBeforeBody(req) {
  req.socket.destroy();
}

// Reads the full request body (submission confirmed by the server) and then
// destroys the connection without sending any response.
async function resetAfterBody(req) {
  await drainRequestBody(req);
  req.socket.destroy();
}

// Reads the full body, waits briefly, then returns a valid 2xx contract
// response. Used for "delayed success within timeout".
async function delayedSuccess(req, res) {
  await drainRequestBody(req);
  setTimeout(() => {
    const payload = JSON.stringify({ status: 'sent', messageId: 'mock-message-001' });
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
    });
    res.end(payload);
  }, 20);
}

// Reads the full body and returns a 2xx response whose body does not match
// the expected response contract.
async function malformedSuccess(req, res) {
  await drainRequestBody(req);
  const payload = 'not-a-valid-contract-response';
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

// Reads the full body (submission confirmed) and then never responds.
async function neverRespond(req) {
  await drainRequestBody(req);
  // Intentionally no response. Client-side timeout governs this scenario.
}

function handleRequest(req, res) {
  const url = new URL(req.url, 'http://127.0.0.1');
  switch (url.pathname) {
    case '/s/400':
      return respondJson(req, res, 400, { error: 'bad_request' });
    case '/s/401':
      return respondJson(req, res, 401, { error: 'unauthorized' });
    case '/s/402':
      return respondJson(req, res, 402, { error: 'payment_required' });
    case '/s/403':
      return respondJson(req, res, 403, { error: 'forbidden' });
    case '/s/404':
      return respondJson(req, res, 404, { error: 'reply_target_not_found' });
    case '/s/429-retry-after':
      return respondJson(req, res, 429, { error: 'rate_limited' }, { 'Retry-After': '1' });
    case '/s/429-no-retry-after':
      return respondJson(req, res, 429, { error: 'rate_limited' });
    case '/s/500':
      return respondJson(req, res, 500, { error: 'server_error' });
    case '/s/502':
      return respondJson(req, res, 502, { error: 'bad_gateway' });
    case '/s/503':
      return respondJson(req, res, 503, { error: 'service_unavailable' });
    case '/s/504':
      return respondJson(req, res, 504, { error: 'gateway_timeout' });
    case '/s/reset-before':
      return resetBeforeBody(req);
    case '/s/reset-after':
      return resetAfterBody(req);
    case '/s/delayed-success':
      return delayedSuccess(req, res);
    case '/s/malformed-success':
      return malformedSuccess(req, res);
    case '/s/timeout':
      return neverRespond(req);
    default:
      return respondJson(req, res, 500, { error: 'unknown_scenario' });
  }
}

export function createMockServer() {
  const server = http.createServer(handleRequest);
  server.on('clientError', (_err, socket) => {
    socket.destroy();
  });

  return {
    async start() {
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(0, '127.0.0.1', resolve);
      });
      const address = server.address();
      return { port: address.port, host: '127.0.0.1' };
    },
    async stop() {
      if (typeof server.closeAllConnections === 'function') {
        server.closeAllConnections();
      }
      await new Promise((resolve) => server.close(resolve));
    },
  };
}

// Returns a 127.0.0.1 port that had nothing listening on it at the moment of
// the probe, for the "connection refused" scenario.
export async function getClosedPort() {
  const probe = http.createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolve);
  });
  const { port } = probe.address();
  await new Promise((resolve) => probe.close(resolve));
  return port;
}
