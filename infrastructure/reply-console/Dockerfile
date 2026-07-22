# HMZ Google Chat supervised reply console sidecar.
# Least-privilege: runs as the built-in node user, no shell entrypoint,
# only google-auth-library added on top of Node built-ins.
FROM node:24-alpine@sha256:a0b9bf06e4e6193cf7a0f58816cc935ff8c2a908f81e6f1a95432d679c54fbfd

WORKDIR /app

# Install exactly the reviewed lockfile graph for reproducible images.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY store.mjs verify.mjs enrich.mjs telemetry.mjs recovery.mjs server.mjs backfill.mjs \
     historical-release.mjs inbound-contract.mjs inbound-store.mjs inbound-service.mjs ./
COPY test-*.mjs scale-inbound-100k.mjs ./
# test-historical-guard.mjs and test-ooo-and-card.mjs are matched by test-*.mjs

ENV STATE_DIR=/data \
    PORT=5691 \
    NODE_ENV=production

# durable state lives on a mounted volume
RUN mkdir -p /data && chown -R node:node /data /app
USER node

EXPOSE 5691

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+ (process.env.PORT||5691) +'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.mjs"]
