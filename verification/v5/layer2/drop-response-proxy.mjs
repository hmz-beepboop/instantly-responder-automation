import http from 'node:http';
import https from 'node:https';

const HOP_BY_HOP_HEADERS = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
]);

function closeServer(server, callback) {
  server.close(() => callback());
  if (typeof server.closeAllConnections === 'function') {
    server.closeAllConnections();
  }
}

export function startDropResponseProxy({
  host = '127.0.0.1',
  port = 0,
  upstreamUrl,
  upstreamTimeoutMs = 60000,
}) {
  if (host !== '127.0.0.1') {
    throw new Error('drop-response-proxy may only bind to 127.0.0.1');
  }

  const upstream = new URL(upstreamUrl);

  return new Promise((resolve, reject) => {
    let requestHandled = false;
    let settled = false;
    let resolveResult;
    const resultPromise = new Promise((res) => {
      resolveResult = res;
    });

    const settle = (metadata, clientSocket) => {
      if (settled) return;
      settled = true;
      if (clientSocket && !clientSocket.destroyed) clientSocket.destroy();
      closeServer(server, () => resolveResult(metadata));
    };

    const server = http.createServer((req, res) => {
      if (req.method !== 'POST') {
        res.writeHead(405, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'method_not_allowed' }));
        return;
      }

      if (requestHandled) {
        req.resume();
        res.writeHead(409, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'second_post_refused' }));
        return;
      }
      requestHandled = true;

      const chunks = [];
      req.on('data', (chunk) => chunks.push(chunk));
      req.on('end', () => {
        const bodyBuffer = Buffer.concat(chunks);
        const forwardHeaders = {};
        for (const [key, value] of Object.entries(req.headers)) {
          if (HOP_BY_HOP_HEADERS.has(key.toLowerCase())) continue;
          forwardHeaders[key] = value;
        }
        forwardHeaders['content-length'] = String(bodyBuffer.length);
        forwardHeaders.host = upstream.host;

        const transport = upstream.protocol === 'https:' ? https : http;
        const upstreamReq = transport.request(
          {
            protocol: upstream.protocol,
            hostname: upstream.hostname,
            port: upstream.port || (upstream.protocol === 'https:' ? 443 : 80),
            path: upstream.pathname + upstream.search,
            method: 'POST',
            headers: forwardHeaders,
          },
          (upstreamRes) => {
            upstreamRes.resume();
            upstreamRes.once('end', () => {
              settle(
                {
                  forwardedPostCount: 1,
                  upstreamStatus: upstreamRes.statusCode ?? null,
                  upstreamResponseCompleted: true,
                  respondedAt: new Date().toISOString(),
                },
                req.socket
              );
            });
            upstreamRes.once('error', (error) => {
              settle(
                {
                  forwardedPostCount: 1,
                  upstreamStatus: upstreamRes.statusCode ?? null,
                  upstreamResponseCompleted: false,
                  upstreamError: error?.code || error?.name || 'upstream_response_error',
                  respondedAt: new Date().toISOString(),
                },
                req.socket
              );
            });
          }
        );

        upstreamReq.setTimeout(upstreamTimeoutMs, () => {
          upstreamReq.destroy(new Error('upstream_timeout'));
        });

        upstreamReq.once('error', (error) => {
          settle(
            {
              forwardedPostCount: 1,
              upstreamStatus: null,
              upstreamResponseCompleted: false,
              upstreamError: error?.message || error?.code || 'upstream_request_error',
              respondedAt: new Date().toISOString(),
            },
            req.socket
          );
        });

        // The upstream POST is issued exactly once and never retried.
        upstreamReq.end(bodyBuffer);
      });

      req.on('error', () => {
        // Client-side read errors do not trigger another upstream request.
      });
    });

    server.on('error', reject);
    server.listen(port, host, () => {
      resolve({ server, address: server.address(), resultPromise });
    });
  });
}
