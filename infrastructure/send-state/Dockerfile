# HMZ Phase 4A send-state sidecar.
# Node.js built-ins only - no package.json, no dependency installation.
FROM node:24-alpine

WORKDIR /app
COPY state-store.mjs server.mjs ./

ENV STATE_DIR=/data
EXPOSE 5681

CMD ["node", "server.mjs"]
