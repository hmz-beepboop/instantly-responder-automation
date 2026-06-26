# Assumptions and Unknowns — reconciled

Date: 2026-06-10. Reconciled during the Phase 2 correction pass. Every item carries: **Status** (`VERIFIED` / `PROVISIONAL` / `BLOCKED` / `NOT REQUIRED FOR VALIDATION MVP`), why it matters, whether it **blocks the Validation MVP**, how it will be verified, and a safe fallback where one exists. Nothing here is treated as a build-verified fact until its status is `VERIFIED` against the real environment.

Status meanings:
- **VERIFIED** — confirmed against the live API / real environment / a captured payload.
- **PROVISIONAL** — documented or strongly implied, but not confirmed in our environment; safe to design around, not safe to rely on for a live action.
- **BLOCKED** — required for some capability and not yet confirmed; the dependent path must not be built on an assumption.
- **NOT REQUIRED FOR VALIDATION MVP** — out of the MVP's critical path.

---

## A. Environment blockers (gate the build, not just the design)

### A1. n8n MCP tools — **VERIFIED (Phase 2.6 Gate 2-3, 2026-06-11): tool surface present (24 tools) AND API connectivity confirmed**
- **Phase 2.6 Gate 2-3 finding (2026-06-11):** with `.mcp.json`'s `N8N_API_URL` updated to `http://127.0.0.1:5678` (was `http://localhost:5678`), `n8n_health_check(mode="diagnostic")` now returns `connected: true, error: null`. Combined with the Gate 1-2 tool-surface confirmation (24/24 tools, re-confirmed again this session via ToolSearch), **A1 is now fully resolved** — both the tool surface and live API connectivity are confirmed working. See `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` ("Phase 2.6 Gate 2-3" section).
- **Phase 2.6 Gate 1-2 finding (2026-06-11, project-scoped `.mcp.json`):** the owner replaced the user-scoped MCP config with a project-scoped `.mcp.json`. Two ToolSearch queries that session confirmed **all 24 tools present and schema-loaded** — 7 documentation/node tools + all 17 `n8n_*` instance-management tools (`n8n_health_check`, `n8n_list_workflows`, `n8n_get_workflow`, `n8n_create_workflow`, `n8n_delete_workflow`, `n8n_executions`, `n8n_audit_instance`, `n8n_validate_workflow`, `n8n_manage_credentials`, `n8n_workflow_versions`, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`, `n8n_deploy_template`, `n8n_generate_workflow`, `n8n_manage_datatable`). This resolved the Phase D retry's regression; the remaining blocker (API connectivity) is now also resolved per the Gate 2-3 finding above.
- Why it matters: required to inspect real nodes/schemas/workflows/validations before building; without it, configuration would be guessed.
- **Phase D retry finding (2026-06-11, `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` "Phase D retry" section):** in a session resumed specifically to retry Phase D's connectivity checks (after the owner reported rotating the API key, adding `WEBHOOK_SECURITY_MODE=moderate`, and restarting Claude Code), **zero of the 17 `n8n_*` instance-management tools are present** — three ToolSearch queries plus an exact-name `select:` lookup for `n8n_health_check`, `n8n_list_workflows`, `n8n_executions`, `n8n_create_workflow`, and `n8n_manage_credentials` all returned no match. Only the same 7 documentation/node tools as the pre-Phase-D state are available. The 24-tool inventory reported in the prior Phase D session was **not reproduced**.
- Cause not confirmed — `claude mcp get`/`claude mcp list` are prohibited this session (would re-expose the rotated key, as happened with the previous key). Consistent with: the owner's `claude mcp add` reconfiguration not completing successfully, Claude Code not having been fully restarted (all processes), or this session not reflecting a post-restart state.
- Previously-recorded state (Phase D, prior session, **not currently reproducible**): `n8n-mcp` connected with `N8N_API_URL`/`N8N_API_KEY` configured, all 24 tools (7 non-instance + 17 `n8n_*`) present and callable, but every `n8n_*` API call failed with `"SSRF protection: Localhost access is blocked in strict mode"` (see A2).
- Blocks MVP? **No longer.** Both the tool surface (24 tools) and live API connectivity (`connected: true`) are confirmed working as of Phase 2.6 Gate 2-3 (2026-06-11). Node/schema/template-driven design, structural workflow validation, and instance-dependent work (listing/creating/validating/deleting real workflows) are all confirmed usable.
- Verify by: already verified this session — see Gate 2-3 finding above. No further action needed for A1.
- Fallback: none needed — A1 is resolved.

### A2. Non-production n8n instance — **VERIFIED (Phase 2.6 Gate 2-3, 2026-06-11): MCP-to-instance connectivity confirmed; disposable workflow lifecycle proven**
- **Phase 2.6 Gate 2-3 finding (2026-06-11):** `n8n_health_check` reports `connected: true` against `http://127.0.0.1:5678` (the owner's local `hmz-n8n-local-dev` container, independently re-confirmed reachable via PowerShell `/healthz`/`/healthz/readiness`/`/api/v1/workflows` on both `localhost` and `127.0.0.1` this session). `n8n_list_workflows()`/`n8n_executions()` both return empty (0 workflows, 0 executions). With owner approval, the full disposable-workflow lifecycle (`DELETE_ME_ROUTE_A_VERIFICATION`: create → get → validate → confirm-inactive → confirm-no-credentials → delete → confirm-gone) succeeded — see `reports/PHASE_2_6_LOCAL_N8N_PROVISIONING_AUDIT.md` ("Phase 2.6 Gate 2-3" section). **A2 is now resolved** for the purposes of Route A (MCP-verified, non-production, isolated local instance with proven create/delete capability).
- **Phase 2.6 Gate 1-2 finding (2026-06-11):** `n8n_health_check(mode="diagnostic")` previously returned `apiConfiguration.status.connected: false` with **`error: "No response from n8n server"`** — a different, later-stage error than the prior session's `"SSRF protection: Localhost access is blocked in strict mode"`. **The SSRF fix (`WEBHOOK_SECURITY_MODE=moderate`) was confirmed working** at that point — that error class no longer occurred. The `NO_RESPONSE` error itself is now resolved per the Gate 2-3 finding above (coincided with `.mcp.json`'s `N8N_API_URL` changing from `http://localhost:5678` to `http://127.0.0.1:5678`).
- Why it matters: Rule — work only in a confirmed non-production workspace/isolated copies.
- Current state: instance-level isolation was confirmed on 2026-06-11 (Phase C) — container `hmz-n8n-local-dev` running n8n `2.25.7`, bound to `127.0.0.1:5678` only, volume intact. As of Gate 2-3, 0 workflows/0 executions/0 active workflows are reconfirmed live via MCP, and the disposable-workflow lifecycle proves create/get/validate/delete all work end-to-end. Docker-level binding/version-pin/no-tunnel were not independently re-run via Docker this session, but the owner's PowerShell `/healthz` checks this session are consistent with no regression.
- **Prior incident (resolved, logged):** `claude mcp get n8n-mcp` previously displayed the full `N8N_API_KEY` value in a session transcript (its normal behaviour). No value was repeated/written anywhere (grep-verified, re-confirmed again this session — repo-wide grep for `N8N_API_KEY|eyJhbGci` returns only 7 known placeholder/documentation files). Owner reported rotating the key. `claude mcp get`/`claude mcp list` were **not** run this or any subsequent session.
- Blocks MVP? **No longer.** MCP-to-instance connectivity and the disposable-workflow lifecycle are both confirmed working as of Gate 2-3.
- Verify by: already verified this session — see Gate 2-3 finding above. No further action needed for A2.
- Fallback: none needed — A2 is resolved.

### A3. Instantly API key and plan tier — **VERIFIED (Phase 5, V1)**
- Why it matters: webhooks and the reply/suppression endpoints require an authorised key and a sufficient plan.
- **V1 finding:** read-only access to webhook event types (including `reply_received`), accounts, and emails succeeded with a dedicated connected sender (warm-up active, score 100, daily limit 40); a genuine `reply_received` webhook was captured (V2) and a controlled `POST /api/v2/emails/reply` returned HTTP 200 (V3) — confirming the plan tier and key are sufficient for these endpoints (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`).
- Blocks MVP? No. Still subject to all other safety gates (`DRY_RUN`, `LIVE_CAMPAIGNS`, allowlisting) before any further live action.

---

## B. Instantly behaviour to confirm

### B1. API base URL (host) — **VERIFIED**
- Paths are documented as `/api/v2/...`. The host `https://api.instantly.ai` is verified (Phase 5 live evidence, `reports/INSTANTLY_VERIFICATION_EVIDENCE.md`).
- Blocks MVP? No. Resolved.

### B2. Authorization header line — **PROVISIONAL**
- "Bearer token authentication" documented; literal header not quoted. Assume `Authorization: Bearer <key>`. Verify with a no-op GET. Blocks MVP? No.

### B3. `reply_to_uuid` source in the webhook payload — **VERIFIED (Phase 5, V2)**
- Why it matters: the reply endpoint requires `reply_to_uuid`; the documented `reply_received` payload table does not list an email/message identifier.
- **V2 finding:** a genuine `reply_received` webhook was captured; its `email_id` matched the retrievable inbound Email object ID and was the correct reply target (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V2).
- Blocks MVP? No. Resolved for the controlled-test path used in V3.
- Fallback: none needed — verified.

### B4. Webhook authenticity / protection — **PROVISIONAL (strategy pending)**
- Why it matters: the endpoint must reject spoofed requests. No signing secret/signature/HMAC is documented. **We do not assume Instantly can send an `X-Webhook-Secret` header.**
- Blocks MVP? Partially — a protection strategy must be chosen and verified before the intake is exposed.
- Verify by: inspect a real delivery for any signature header; test whichever native option exists; otherwise select compensating controls (secret URL path, secret query param, source allowlist, strict payload validation, API-side event verification, rate limiting) per `docs/ARCHITECTURE.md` §4.
- Fallback: secret URL path + strict payload validation + campaign/sender allowlisting as compensating controls.

### B5. Webhook retry behaviour on non-200 — **PROVISIONAL**
- Not documented. Design assumes at-least-once delivery; intake acks fast after acceptance and all downstream actions are idempotent. Blocks MVP? No.

### B6. `update-interest-status` request body — **VERIFIED (Phase 5, V4B)**
- **V4B finding:** `POST /api/v2/leads/update-interest-status` returned HTTP 202, and retrieval proved the interest status and timestamp changed (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V4B).
- Blocks MVP? No. Decision path may record this as a verified mechanism for `STOP_ACTIVE_SEQUENCE`.

### B7. `subsequence/remove` request body — **VERIFIED (Phase 5, V4C)**
- **V4C finding:** a controlled lead was moved into, retrieved from, removed from, and re-retrieved outside a paused subsequence (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V4C).
- Blocks MVP? No. Live subsequence removal is verified.

### B8. Blocklist / DNC API — **PARTIALLY VERIFIED (Phase 5, V4D / V4E4)**
- Workspace/organisation DNC and global blocklist are documented as UI features.
- **V4D finding:** exact email-level block-list enforcement is VERIFIED workspace-wide — a blocked controlled address received no campaign email while a matched unblocked control received one (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V4D).
- **V4E4 finding:** ordinary unsubscribe (interest-status / campaign stop), under the tested workspace configuration, is **campaign-local**, not workspace-wide (`CAMPAIGN_LOCAL_UNSUBSCRIBE_VERIFIED`). Workspace-wide suppression requires the separate, exact email-level block-list action verified in V4D.
- Blocks MVP? No, but the production unsubscribe path must perform **both** the source-campaign action (B6) **and** the exact email-level block-list action (V4D) — neither alone is sufficient for workspace-wide do-not-contact.

### B9. Get-email-by-id / get-thread / reconciliation endpoint — **VERIFIED (Phase 5, V5 Layer 2)**
- **V5 Layer 2 finding:** one controlled lost-response proxy test proved a request can reach Instantly while the client loses the response, the send state becomes `SEND_UNCERTAIN`, no second reply POST occurs before reconciliation, and reconciliation by thread/sender/recipient/subject/timestamp/marker produced exactly one match that became `SENT_RECONCILED` with no duplicate (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V5 Layer 2).
- Blocks MVP? No for the exactly-one-match path. **Zero or multiple reconciliation matches require human review and no second POST** — this remains the policy for those cases and was not exercised against a live Instantly response in this test (`docs/STATE_AND_IDEMPOTENCY.md` §4).

### B10. Thread-reply / RFC threading-header semantics — **PROVISIONAL**
- `POST /api/v2/emails/reply` takes `reply_to_uuid` + `subject` but does not document `In-Reply-To`/`References` handling.
- Blocks MVP? No (no send in MVP). Verify by inspecting a sent reply's headers in a destination inbox during a later controlled test.

### B11. `reminder_ts` semantics — **NOT REQUIRED FOR VALIDATION MVP**
- Unclear whether it suppresses steps or only nags a human. Not on the MVP path; verify only if pause logic later depends on it.

---

## C. Deliberate assumptions

| # | Assumption | Status | Why defensible | What invalidates |
| --- | --- | --- | --- | --- |
| C1 | Target API is V2. | PROVISIONAL | New build; V1 is legacy. | Owner states V1. |
| C2 | Replies go in the same thread via `reply_to_uuid`. | PROVISIONAL | Documented purpose. | B10 shows threading breaks. |
| C3 | "Stop follow-ups" = interest-status to a non-default value. | PROVISIONAL | Vendor guidance. | B6 enum lacks the value. |
| C4 | Org-wide suppression maps to exact email-level Blocklist action. | VERIFIED (Phase 5, V4D) | Confirmed workspace-wide block-list enforcement via API/UI mechanism. | Ordinary campaign-level unsubscribe (B6) alone is NOT sufficient — see B8/V4E4. |
| C5 | Webhook deliveries are at-least-once; all downstream actions idempotent. | PROVISIONAL | Standard practice; B5 undocumented. | Confirmed at-most-once (harmless). |
| C6 | Processing/Transmission SLOs measured from webhook receipt at our endpoint. | VERIFIED (our definition) | Tightest controllable definition. | Owner redefines. |
| C7 | AI only for semantic classification + T2 drafts. | VERIFIED (policy) | Project rules. | n/a |
| C8 | Storage engine not yet chosen. | VERIFIED | Correction pass (C9). | Owner selects an engine. |
| C9 | Classifier is mocked in the MVP. | VERIFIED (plan) | Correction pass (C16). | Owner approves a real integration. |

---

## D. Owner decisions still required before the MVP can go live
1. First in-scope (isolated, non-customer-facing) test campaign.
2. Operating mode confirmation (`VALIDATION` default) and whether any acknowledgement category may send after approval.
3. `KB-1.0` approval and template approval.
4. One human-review destination (configurable).
5. Storage choice (per preference order).
6. Named primary + backup escalation owners; P1/P2/P3/P3M owners.
7. `{{senderName}}` mappings and `{{bookingLink}}` URLs per inbox.
8. Confirmation of the Instantly plan tier and provisioning of a scoped V2 key.
9. Legal/compliance review of the suppression and contact policy.
