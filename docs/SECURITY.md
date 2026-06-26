# Security

## No secrets in exports

All six workflow exports under `workflows/` have `credentialsBound: false`
and contain no API keys, tokens, or secret values
(`reports/PHASE_5_MECHANICAL_AUDIT.md`,
`reports/SECURITY_AUDIT.md`). The project-level secret/PII scan recorded 0
real-email hits and 0 unexpected secret-pattern hits; the only 2
secret-pattern hits are known synthetic fixtures in
`verification/phase4a/run-offline-tests.mjs` and
`verification/phase4b/run-offline-tests.mjs`.

## API keys only through environment/credential storage

Per `docs/ARCHITECTURE.md` §8, secrets live only in n8n credentials or
environment variables — never in workflow JSON or logs. The
`INSTANTLY_API_KEY` placeholder in `.env.example` is explicitly unused while
`DRY_RUN=true` and `LIVE_CAMPAIGNS=[]`.

## Sidecar internal network boundary

`hmz-send-state` runs only on the internal Docker Compose network, reachable
at `http://hmz-send-state:5681`. It stores no API keys, Authorization
headers, full message bodies, full webhook payloads, or raw API responses
(`docs/STATE_AND_IDEMPOTENCY.md` §1).

## No published sidecar port

`infrastructure/local-n8n/docker-compose.yml` defines no `ports:` mapping for
`hmz-send-state` — it is unreachable from the host or external network, only
from other containers on the compose network.

## Identifier hashing and content redaction

Error records persisted via `POST /v1/error` may include sanitised source
workflow, execution reference, failed node, intake identifier/hash, send
key, send state, HTTP status, error class, attempt count, retryability, and
operator action. Credential-like fields are redacted; message/body/payload
content is replaced with redacted placeholders; email-like identifiers are
hashed (`docs/STATE_AND_IDEMPOTENCY.md` §8).

## Code-node generic platform risk

The n8n security audit flags the Decision Engine's Code nodes (`A.
Deterministic Policy Stage`, `B. Mock Semantic Classifier`, `C. Decision
Policy`, etc.) under n8n's generic "Official risky nodes" advisory — Code
nodes can execute arbitrary code on the host. This is a standard n8n
platform notice, not a project-specific defect. These nodes contain only
deterministic policy/classification logic over in-memory item data, make no
external network calls (`externalHttpTargets: []`), and are not driven by
unvalidated external input beyond the validated NES structure
(`reports/SECURITY_AUDIT.md`).

## Strict dry-run and allowlist gates

`OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, and `LIVE_CAMPAIGNS=[]` are
enforced project-wide. The configuration gate rejects any item where
`config_gate.passed=false` (e.g. a synthetic `live_campaign=true` claim while
`dry_run=true`) before the Decision Engine runs, with
`terminal_status=REJECTED` and `external_action_status=NOOP`
(`reports/FAILURE_MODE_AUDIT.md` §3).

## No uncertain-send blind retry

`SEND_UNCERTAIN` is a forward-only state that may transition only to
`SENT_RECONCILED`, `HUMAN_REVIEW_ZERO_MATCHES`, or
`HUMAN_REVIEW_MULTIPLE_MATCHES`. It is never blindly retried, and no
uncertain or human-review state may issue a second reply `POST`
(`docs/STATE_AND_IDEMPOTENCY.md` §5-§6, Phase 4A-verified).

## Workspace suppression requirement

True workspace-wide suppression (T7/T12/T13) requires **both** the
source-campaign action (interest-status change / unsubscribe, verified
campaign-local) **and** the exact email-level Blocklist action (verified
workspace-wide, V4D). The campaign-level action alone is not a workspace-wide
kill switch (`docs/REPLY_POLICY.md` §6, `docs/INSTANTLY_FIELD_MAP.md` §5.3).

## Log and evidence sanitisation

Captured outputs (e.g. `reports/PHASE_5_MECHANICAL_AUDIT.md`) use sanitised
snippets and confirm zero real-email/secret-pattern residue project-wide. A
historical environment-audit report's single real local n8n owner email was
confirmed already cleaned (replaced/removed) with 0 remaining hits
(`reports/SECURITY_AUDIT.md`).
