# Instantly Field Map — Phase 1 (status labels reconciled)

Date: 2026-06-10. All claims here are sourced from the URLs in `SOURCES.md`. Status legend:

- **VERIFIED (documented)** — quoted from official Instantly documentation. **This is NOT the same as confirmed against our account / a live payload.** For build purposes treat documented-but-uncaptured items as **PROVISIONAL** (see `docs/ASSUMPTIONS_AND_UNKNOWNS.md`). A field is build-verified only after we confirm it in the non-production environment.
- **INFERRED** — strongly implied but not literally quoted; working hypothesis.
- **UNKNOWN / BLOCKED** — docs did not state it; do not invent; the dependent path must not be built on an assumption.

> Project rule: do not invent fields, endpoints, payloads, or plan tiers. Anything not confirmed against the live environment must be confirmed (with explicit auth and `DRY_RUN=true`) before it ships into a workflow. The Phase 2 correction pass downgrades documented webhook payload fields and the plan tier to PROVISIONAL until captured live.

---

## 1. API version, base URL, authentication

| Item | Status | Detail |
| --- | --- | --- |
| API version targeted | VERIFIED | **V2** (V1 still exists but uses a different auth scheme; the user's CLAUDE.md targets a new integration so V2 is the correct choice). |
| Base URL | VERIFIED | All V2 endpoint paths in docs are quoted as `/api/v2/...`. The host `https://api.instantly.ai` is verified by Phase 5 live evidence (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`; `docs/ASSUMPTIONS_AND_UNKNOWNS.md` B1). |
| Authentication scheme | VERIFIED | "Bearer token authentication, which is more secure than the previous version authentication." V2 requires a new API key distinct from V1. |
| Authorization header value | INFERRED | Standard `Authorization: Bearer <API_KEY>`. The intro page describes Bearer auth but does not quote the literal header line. |
| API scopes | VERIFIED | V2 introduces granular scopes per key. Examples seen in endpoint docs: `emails:create`, `emails:all`, `leads:read`, `leads:all`, `leads:delete`, `all:read`, `all:create`, `all:all`, `all:delete`. |
| Multiple keys | VERIFIED | Multiple keys can be created and revoked. |

## 2. Rate limits

| Item | Status | Detail |
| --- | --- | --- |
| Per-second limit | VERIFIED | "No more than 100 requests per second." |
| Per-minute limit | VERIFIED | "No more than 6,000 requests per minute." |
| Over-limit status | VERIFIED | HTTP `429`. |
| `X-RateLimit-*` headers | UNKNOWN | Not stated. |
| `Retry-After` header | UNKNOWN | Not stated. |
| Vendor backoff guidance | VERIFIED | Distribute requests across the day; batch with ~2s gaps between groups of ~100. |

## 3. Webhook — reply-received event

### 3.1 Event types catalog (VERIFIED)
Email events: `email_sent`, `email_opened`, `reply_received`, `auto_reply_received`, `link_clicked`, `email_bounced`, `lead_unsubscribed`, `account_error`, `campaign_completed`.
Lead status events: `lead_neutral`, `lead_interested`, `lead_not_interested`.
Meeting events: `lead_meeting_booked`, `lead_meeting_completed`.
Other lead events: `lead_closed`, `lead_out_of_office`, `lead_wrong_person`.
Plus any custom labels configured in the workspace.

### 3.2 `reply_received` payload — fields as documented (VERIFIED)

| Field | Type | Notes |
| --- | --- | --- |
| `timestamp` | string | ISO timestamp when the event occurred. |
| `event_type` | string | Value: `reply_received`. |
| `workspace` | string | Workspace UUID. |
| `campaign_id` | string | Campaign UUID. |
| `campaign_name` | string | Campaign name. |
| `lead_email` | string | Lead's email address. |
| `email_account` | string | Email account used to send the original. |
| `unibox_url` | string | URL to view the conversation in Unibox (reply events only). |
| `step` | number | Step number in campaign (1-based). |
| `variant` | number | Variant number of step (1-based). |
| `is_first` | boolean | Whether this is the first event of this type for the lead. |
| `reply_text_snippet` | string | Short preview of reply content. |
| `reply_subject` | string | Subject of the reply email. |
| `reply_text` | string | Full plain-text content of reply. |
| `reply_html` | string | Full HTML content of reply. |

### 3.3 Fields verified by Phase 5 live capture (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`, V2)
- `email_id` — VERIFIED. A genuine `reply_received` webhook's `email_id` matched the retrievable inbound Email object ID and was the correct `reply_to_uuid` target for `POST /api/v2/emails/reply`.
- `thread_id` / `message_id` — VERIFIED. The inbound and original outbound Email objects shared the same `thread_id`; `message_id` was also present.
- `from_address_email` of the actual reply sender — not separately re-verified; treat as PROVISIONAL.

### 3.4 Webhook authenticity / verification

| Item | Status | Detail |
| --- | --- | --- |
| Signing secret | UNKNOWN | Not documented in the help center webhook article or in the developer docs pages we reached. |
| Signature header (`X-Instantly-Signature` or similar) | UNKNOWN | Not mentioned. |
| HMAC algorithm | UNKNOWN | Not mentioned. |
| IP allowlist | UNKNOWN | Not mentioned. |
| **User-supplied custom headers** | VERIFIED | When creating a webhook in the UI, the user can "optionally add custom HTTP headers for authentication." This is the documented mechanism: caller chooses a shared secret and includes it as a static header; the receiver validates. |
| Retry behavior on non-200 | UNKNOWN | Not documented. Assume best-effort, no replay. |
| Per-campaign vs workspace-wide | VERIFIED | Webhooks are configured per campaign in the UI ("choose the target campaign"). For workspace-wide coverage either the API or one webhook per campaign is needed. |
| Plan gating | PROVISIONAL | Documentation indicates webhooks require a higher plan tier (referenced as "Hyper Growth or above"). **Our account's tier is NOT confirmed** — do not state any tier as confirmed. Owner must confirm in writing (`ASSUMPTIONS_AND_UNKNOWNS.md` A3). |

## 4. Retrieving / threading emails

| Endpoint | Method | Path | Status |
| --- | --- | --- | --- |
| Reply to an email | POST | `/api/v2/emails/reply` | VERIFIED |
| Mark all emails in a thread as read | (POST per docs index; method to confirm in spec) | `/api/v2/emails/markthreadasread` (path slug per group page) | INFERRED |
| Get an individual email by id | UNKNOWN | The `/api/v2/email` group page returned 404 from our fetch; sibling endpoints commonly include a list / get-by-id. Must confirm against the spec. |
| Get a thread by id | UNKNOWN | Same. |

### 4.1 `POST /api/v2/emails/reply` — request body (VERIFIED)

Required:
- `reply_to_uuid` (string) — "The id of the email to reply to."
- `eaccount` (string) — "The email account that will be used to send this email."
- `subject` (string) — Subject line.
- `body` (object) — contains `html` and/or `text`.

Optional:
- `cc_address_email_list` (string) — Comma-separated CC addresses.
- `bcc_address_email_list` (string) — Comma-separated BCC addresses.
- `reminder_ts` (string, date-time) — Attaches a reminder.
- `assigned_to` (string, UUID) — User assigned to the lead.

Required scopes: `emails:create` OR `emails:all` OR `all:create` OR `all:all`.

### 4.2 `POST /api/v2/emails/reply` — response (VERIFIED, partial)
Returns an Email object including (at minimum): `id`, `timestamp_created`, `timestamp_email`, `message_id`, `subject`, `from_address_email`, `to_address_email_list`, `body`, `thread_id`.

Implication for design: `thread_id` on the response **groups related messages**. ("All the emails in the same thread have the same thread ID.") — useful for idempotency keys.

## 5. Stopping follow-ups / suppressing a lead

### 5.1 What the official Instantly help center says is the right thing to do (VERIFIED)
> "Any status other than the default 'Lead' status stops the campaign sequence."

Two documented mechanisms for a single lead:
1. **Change the lead's status** (recommended). Done in UI from the Campaign → Leads tab or from Unibox.
2. **Add to Blocklist** (Settings → Blocklist). Prevents future sends across campaigns; existing campaign leads are automatically skipped if added afterward.

### 5.2 API endpoints that implement these (VERIFIED listing; field-level details require spec re-fetch in Phase 2)

| Purpose | Method | Path |
| --- | --- | --- |
| Update lead's interest status (drives the "anything but 'Lead'" stop behavior) | POST | `/api/v2/leads/update-interest-status` |
| Patch arbitrary lead fields | PATCH | `/api/v2/leads/{id}` |
| Remove lead from a subsequence (sub-step pause) | POST | `/api/v2/leads/subsequence/remove` |
| Move lead to a subsequence | POST | `/api/v2/leads/subsequence/move` |
| Delete a lead | DELETE | `/api/v2/leads/{id}` |
| List leads | POST | `/api/v2/leads/list` |
| Move leads between campaigns/lists | POST | `/api/v2/leads/move` |
| Bulk-assign leads | POST | `/api/v2/leads/bulk-assign` |

Verified by Phase 5 (`reports/INSTANTLY_VERIFICATION_EVIDENCE.md`):
- `update-interest-status` (V4B) — VERIFIED: returns HTTP 202; retrieval confirmed the interest status and timestamp changed.
- `subsequence/remove` (V4C) — VERIFIED: a controlled lead was moved into, removed from, and confirmed outside a paused subsequence.
- Exact email-level **Blocklist** action (V4D) — VERIFIED workspace-wide kill switch: a blocked address received no campaign email; a matched unblocked control received one.
- Ordinary campaign-level unsubscribe (V4E4) — VERIFIED **campaign-local**, not workspace-wide, under the tested configuration (`CAMPAIGN_LOCAL_UNSUBSCRIBE_VERIFIED`).

### 5.3 Implication for our policy classes (CLAUDE.md rule #12 — opt-outs, complaints, legal/privacy, hostile)

- **Hard suppression** (opt-out, complaint, legal/privacy hit): change interest status to a not-interested equivalent (B6, verified) **and** add the exact email to the workspace Blocklist (B8/V4D, verified). The campaign-level unsubscribe alone is **not** a workspace-wide kill switch — both actions are required.
- **Soft pause** (e.g. waiting on us): `update-interest-status` to a non-default value stops the campaign sequence without suppressing across the workspace.

## 6. Likely n8n nodes (Phase 1 Task 4)

Identified from general n8n knowledge — node-version-specific schemas should be confirmed via n8n MCP in Phase 2.

| Purpose | Likely node |
| --- | --- |
| Webhook intake | **Webhook** trigger node (production URL + `httpMethod: POST`). |
| Immediate ack | Webhook node's "Respond" mode set to **Respond Immediately** (return 200 within the 5-minute objective margin so Instantly doesn't retry/disconnect), or a **Respond to Webhook** node placed early in the path. |
| HTTP API requests to Instantly | **HTTP Request** node with a generic Bearer credential. |
| Branching on classifier output | **Switch** (preferred) or **IF**. |
| Persistent state / dedupe | n8n's native primitives are limited. Options to evaluate in Phase 2: a dedicated key/value table (Postgres / Supabase / Redis) via the respective node, the **Data Store** node if available in the user's n8n version, or a Google Sheets / Airtable row keyed by `thread_id` + `message_id`. **Workflow Static Data is not durable across redeploys — do not use for idempotency.** |
| Sub-workflows | **Execute Workflow** node (caller) + a **Workflow Trigger** in the child. Useful for: classifier, send-reply, suppression-actions. |
| Error handling | Per-workflow **Error Trigger** + a dedicated error workflow that logs and alerts. Plus node-level `continueOnFail` only where the downstream branch handles it. |
| Scheduled monitoring | **Schedule** trigger for periodic reconciliation (Rule #11 — uncertain send outcomes must be reconciled before retry). |
| Testing | Built-in node "Execute Node" with a static webhook payload fixture; an additional **manual trigger** workflow that feeds canned payloads through the same sub-workflows. |

UNKNOWN until MCP is available:
- Exact node versions present in the connected instance (affects field names, e.g. Webhook v1 vs v2 response modes).
- Whether the user's n8n has Queue mode (affects how the immediate-ack timing behaves under load).

## 7. Scopes required (recommended minimum set)

INFERRED from endpoints we'll need:
- `emails:create` — to call `POST /api/v2/emails/reply`.
- `leads:all` (or narrower: `leads:read` + the specific write scope for `update-interest-status` once we confirm it) — for suppression / status updates.
- Read scope sufficient to fetch an email/thread by id, **if** that endpoint exists and we end up using it (see §4 UNKNOWNs).
- No `*:delete` scope unless we deliberately decide to delete leads (we should not for normal opt-outs — Blocklist + status change is safer and auditable).

Principle: issue one API key per workflow class with the **narrowest** set of scopes that works.
