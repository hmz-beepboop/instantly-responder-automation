# Normalized Event Schema (NES v1) — Phase 2 (reconciled)

Date: 2026-06-10. This is the canonical shape every downstream workflow consumes. Reply Intake is the only workflow that touches Instantly's raw payload; everything else reads NES from the state store.

Rationale: Instantly's payload may change, may carry vendor-specific naming, and (per `ASSUMPTIONS_AND_UNKNOWNS.md` B3) may be missing the identifier we need for `reply_to_uuid`. Normalizing once, at the boundary, isolates the rest of the system from that risk.

> **Status-label caveat (correction pass).** In §2, "VERIFIED" means **documented in official Instantly docs, not confirmed against a live payload.** For build purposes these fields are **PROVISIONAL** until a real `reply_received` payload is captured in the non-production environment. The webhook **event names and payload fields are not treated as build-verified** until that capture exists (`docs/PHASE_2_CORRECTION_CHANGELOG.md` C10).

---

## 1. NES v1 record

```jsonc
{
  "nes_version": "1",
  "intake_id": "01HXXXXXXXXXXXXXXXXXXXXXXX",     // UUID v7, primary key in `events`
  "received_at": "2026-06-09T14:22:08.314Z",     // n8n's wall clock, UTC, ISO-8601
  "source": "instantly",                          // for future multi-vendor
  "event_type": "reply_received",                 // one of the Instantly event types we subscribe to

  "workspace_id": "…",
  "campaign_id": "…",
  "campaign_name": "…",
  "campaign_context": {                           // attached via campaign-ID lookup, see §3.4
    "validation_cell": "CELL_1_SAAS_SALES_HIRING", // or CELL_2_SAAS_EXISTING_OUTBOUND / CELL_3_SPECIALISED_B2B_AGENCY
    "segment": "…",
    "subsegment": "…",
    "pain_trigger": "…",
    "offer_angle": "…",
    "geo_code": "US_B2B_CORE_12",
    "campaign_purpose": "…",
    "campaign_message_variant": "…"
  },
  "lead_email": "lead@example.com",
  "eaccount": "sender@ourdomain.com",
  "step": 3,
  "variant": 1,
  "is_first_reply": true,

  "reply": {
    "subject": "Re: quick question",
    "snippet": "Thanks for reaching out…",
    "text": "…full plaintext…",
    "html": "…full html…",
    "has_attachments": false,                     // derived; see §3
    "language": "en",                             // best-effort, deterministic detector
    "from_address_email": null                    // unknown until verified (B3); falls back to lead_email
  },

  "threading": {
    "reply_to_uuid": null,                        // populated by Reply Intake if present in payload, else by a lookup call
    "thread_id": null,                            // populated from Instantly response when we send; carried forward thereafter
    "rfc_message_id_inbound": null,               // optional; only if Instantly surfaces it (UNKNOWN today)
    "lookup_strategy": "from_payload"             // or "lookup_by_lead_and_campaign" if we had to query
  },

  "links": {
    "unibox_url": "https://app.instantly.ai/…"
  },

  "vendor_payload_hash": "sha256:…",              // hash of the raw payload (for audit; payload itself NOT stored — see §4)
  "dedupe_key": "instantly:<campaign_id>:<lead_email>:<reply.subject_norm>:<bucket_ts>",
  "synthetic": false,                             // true for Test Harness traffic

  "operating_mode": "VALIDATION",                 // VALIDATION (default) | PROVEN; pinned at intake
  "timestamps": {                                 // lifecycle timestamps for the two SLOs (STATE_AND_IDEMPOTENCY §1.10)
    "webhook_received_at": null,
    "auth_completed_at": null,
    "normalized_at": null,
    "classification_started_at": null,
    "classification_completed_at": null,
    "draft_completed_at": null,
    "human_notified_at": null,
    "approved_at": null,
    "send_attempted_at": null,
    "transmission_verified_at": null,
    "terminal_suppressed_at": null,
    "terminal_no_reply_at": null,
    "final_failure_at": null
  },
  "policy_version": "policy-HMZ-1.2",             // pinned at intake time
  "kb_version": "KB-1.0-DRAFT",                   // active knowledge-base version
  "schema_version": "nes-1"
}

The downstream **action plan** is not part of NES; it is produced by the Decision Engine and stored in `decisions.action_plan` (`STATE_AND_IDEMPOTENCY.md` §1.2). NES carries the inbound facts and lifecycle timestamps only.
```

---

## 2. Field-by-field mapping from Instantly payload

`VERIFIED` rows pull from `INSTANTLY_FIELD_MAP.md` §3.2. `DERIVED` rows are computed by Reply Intake. `LOOKUP` rows may require a follow-up API call if the payload doesn't carry the field.

| NES field | Instantly source | Status | Notes |
| --- | --- | --- | --- |
| `received_at` | n8n receive timestamp | DERIVED | Not the payload's `timestamp`. We trust our clock for SLA math. |
| `event_type` | `event_type` | VERIFIED | |
| `workspace_id` | `workspace` | VERIFIED | |
| `campaign_id` | `campaign_id` | VERIFIED | |
| `campaign_name` | `campaign_name` | VERIFIED | |
| `campaign_context.validation_cell` | — | LOOKUP | Attached via `campaign_id` lookup against `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). One of `CELL_1_SAAS_SALES_HIRING` / `CELL_2_SAAS_EXISTING_OUTBOUND` / `CELL_3_SPECIALISED_B2B_AGENCY`. |
| `campaign_context.segment` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `campaign_context.subsegment` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `campaign_context.pain_trigger` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `campaign_context.offer_angle` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `campaign_context.geo_code` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4); `US_B2B_CORE_12` for the initial sprint. A reply from outside this geography is a human-review flag, not a rejection (`HMZ_APPROVED_REPLY_RULES.md` §1, §16). |
| `campaign_context.campaign_purpose` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `campaign_context.campaign_message_variant` | — | LOOKUP | From `docs/VALIDATION_CAMPAIGN_CONFIG.md` (§3.4). |
| `lead_email` | `lead_email` | VERIFIED | Lowercased + trimmed before storage. |
| `eaccount` | `email_account` | VERIFIED | The inbox the original was sent from. Reused as `eaccount` on reply. |
| `step` | `step` | VERIFIED | |
| `variant` | `variant` | VERIFIED | |
| `is_first_reply` | `is_first` | VERIFIED | |
| `reply.subject` | `reply_subject` | VERIFIED | |
| `reply.snippet` | `reply_text_snippet` | VERIFIED | |
| `reply.text` | `reply_text` | VERIFIED | |
| `reply.html` | `reply_html` | VERIFIED | |
| `reply.has_attachments` | — | DERIVED | True if `reply.html` contains `<img src="cid:"` or referenced attachment markers, OR if HTML/text references "attached" / "attachment" / "see attached" / common multilingual variants. Heuristic; flagged in `RISK_REGISTER.md`. |
| `reply.language` | — | DERIVED | Run a small deterministic language detector on `reply.text`. |
| `reply.from_address_email` | UNKNOWN | LOOKUP | Not in documented payload table; assume `lead_email` until proven otherwise. |
| `threading.reply_to_uuid` | UNKNOWN | LOOKUP | **Critical gap (`ASSUMPTIONS_AND_UNKNOWNS.md` B3).** Strategy: (a) inspect payload for any UUID-shaped field at intake; (b) if absent, fall back to a "list emails for this lead+campaign since received_at − 24h" query and pick the most recent inbound. Both paths populate `threading.lookup_strategy`. |
| `threading.thread_id` | UNKNOWN at intake | LOOKUP / LATER | Populated from Instantly's reply response and reused for follow-ups. |
| `threading.rfc_message_id_inbound` | UNKNOWN | LOOKUP | Only used if/when the get-email-by-id endpoint is confirmed. |
| `links.unibox_url` | `unibox_url` | VERIFIED | |
| `vendor_payload_hash` | — | DERIVED | `sha256(canonical_json(raw_payload))`. Stored; raw payload is NOT (§4). |
| `dedupe_key` | — | DERIVED | See `STATE_AND_IDEMPOTENCY.md` §2. |
| `synthetic` | — | DERIVED | True iff payload arrived via Test Harness or carries the `X-Synthetic: 1` header. |
| `policy_version` | — | DERIVED | Pinned from current policy config at intake time so a decision can always be re-explained. |

---

## 3. Derivations — concrete rules

### 3.1 Attachment detection (`reply.has_attachments`)
Deterministic; runs in Reply Intake. True if any of:
- `reply.html` matches `/<img[^>]+src="cid:/i`
- `reply.html` or `reply.text` matches `/\b(see attached|please find attached|attached (?:is|are|please|the|for)|attachment\b)/i`
- Localised equivalents covering EN, ES, FR, DE, PT in the v1 rule set (others fall through to false; flagged in `RISK_REGISTER.md`).

The detector is intentionally conservative: false positives only delay (escalation), false negatives risk auto-sending past an attachment.

### 3.2 `dedupe_key`
```
instantly:<campaign_id>:<lower(lead_email)>:<subject_norm>:<floor(received_at / 300s)>
```
- `subject_norm` = lowercase, strip `Re:` / `Fwd:` recursively, collapse whitespace.
- The 5-minute time bucket guarantees retried webhook deliveries collapse, while genuinely separate replies (e.g. an inbound 10 minutes later) still get processed.
- This is the unique key on `events.dedupe_key` — see `STATE_AND_IDEMPOTENCY.md`.

### 3.3 `synthetic`
The Test Harness sets `synthetic=true` and passes through the *same* Decision Engine and Reply Sender, but the Sender's DRY_RUN gate is hard-locked on regardless of env vars when `synthetic=true`. Belt and suspenders against accidental live sends from a fixture.

### 3.4 Campaign context lookup (`campaign_context`)

Reply Intake (or the Decision Engine, if Reply Intake does not have access to the lookup) resolves `campaign_id` against the campaign registry in `docs/VALIDATION_CAMPAIGN_CONFIG.md` and attaches `validation_cell`, `segment`, `subsegment`, `pain_trigger`, `offer_angle`, `geo_code`, `campaign_purpose`, and `campaign_message_variant` to `campaign_context`. Both the classifier and the draft-generator AI receive this context (`HMZ_APPROVED_REPLY_RULES.md` §1). **Cell 3 (`CELL_3_SPECIALISED_B2B_AGENCY`) events must carry agency-specific `segment`/`subsegment`/`pain_trigger`/`offer_angle`, never the SaaS hypothesis** (`HMZ_APPROVED_KNOWLEDGE_BASE.md` §4).

- If `campaign_id` is not found in the registry, every `campaign_context` field is set to `UNKNOWN` and the event is flagged for human review. This is independent of, and in addition to, the campaign-allowlist deny-all check (`HMZ_APPROVED_REPLY_RULES.md` §12), which separately governs whether a *send* is permitted.
- A `geo_code` mismatch (the reply indicates the prospect is outside `US_B2B_CORE_12`) is a human-review flag on the case, not an automatic rejection or suppression (`HMZ_APPROVED_REPLY_RULES.md` §1, §16).
- `campaign_context` is attached once at intake and is immutable thereafter, consistent with the rest of NES (§5).

---

## 4. What we deliberately do NOT store

- **Raw Instantly payload.** Only its sha256 hash + the normalized fields. Two reasons: (a) Rule #5 — minimise PII surface in our store; (b) decouples us from vendor schema drift.
- **Full message bodies for synthetic events.** Test fixtures may contain example text but never real prospect content.
- **API keys, tokens, or webhook secrets.** They live in n8n credentials.
- **AI classifier raw prompt + response.** We store the *category*, *confidence*, *prompt_version*, and a redacted reasoning excerpt (≤ 280 chars, PII-scrubbed). Full prompts are recoverable from version control because `prompt_version` pins the template.

---

## 5. Versioning

- `schema_version` and `policy_version` are stamped at intake and never mutated.
- Any change to NES bumps `nes_version` and ships a migration. Downstream workflows read `nes_version` and refuse anything they don't recognise (fail-loud, not silent).
- Re-classifying an old event uses the *current* policy with `replay=true` so we don't silently overwrite the original decision.
