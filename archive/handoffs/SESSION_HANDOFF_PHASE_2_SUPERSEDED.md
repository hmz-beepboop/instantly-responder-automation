> **SUPERSEDED (2026-06-10).** The narrow "Pick up here" scope at the bottom of this handoff (update 0.85→0.90, add a supersession header, expand a checklist) has been **superseded by the Phase 2 correction pass.** The correction made broader changes: source hierarchy fixed (`docs/SOURCE_PRIORITY.md`), Grill Me decisions reconciled (not treated as locked), operating modes added, the action enum replaced with a structured action plan, the five-minute objective split into Processing and Transmission SLOs, quiet-hours holding removed from the MVP, two architecture profiles defined, storage deferred, taxonomy T1/T2/media/List-Unsubscribe/bounce corrected, the knowledge base drafted, and `CLAUDE.md` rebuilt. See `docs/PHASE_2_CORRECTION_CHANGELOG.md` for the full record. This handoff is retained unedited below as a historical account; where it conflicts with the corrected docs, the corrected docs win. In particular, the source-priority statement below (placing `CLAUDE.md` above the business documents) is **incorrect** and is replaced by `docs/SOURCE_PRIORITY.md`.

---

# Session Handoff — Instantly Rapid-Reply: Phase 1 research, Phase 2 architecture, and Grill-Me policy extraction

## Where it started

The session continued from a prior context that had completed Phase 1 (Instantly API research, 4 docs written, n8n MCP confirmed absent). This session ran Phase 2 (design-only: 6 architecture documents written) and then ran a full Grill-Me interview (14 questions) to extract the owner-approved business and safety policy. No n8n workflows have been built at any point across either session.

---

## Decisions locked + what shipped

- **Phase 2 architecture designed** — 6 docs written covering data flow, NES schema, policy taxonomy, state/idempotency tables, risk register, and Phase 3 build order. These are design documents; no n8n nodes were created — `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\ARCHITECTURE.md`
- **Confidence threshold corrected by Grill-Me** — Phase 2 design used 0.85 as the auto-send threshold; the owner-approved policy sets it at **0.90**. This discrepancy is the primary surgical correction needed in the Phase 2 docs.
- **Reply taxonomy confirmed** — 16 categories, all handled in `HMZ_APPROVED_REPLY_RULES.md`. The 4 auto-send-eligible categories are T1 (3 variants), T3, T4 (2 variants), T6. Hard suppress: T7, T12, T13. NOOP: T8, T9. One-line ack: T5, T10. Escalate-only: T2, T11, T14, T15, T16.
- **Approved template wording locked** — exact copy for all auto-send templates (including no-name variants) is in `HMZ_APPROVED_REPLY_RULES.md`. `REPLY_POLICY.md` has placeholder wording; the approved doc supersedes it for business logic.
- **`HMZ_APPROVED_REPLY_RULES.md` is the authoritative policy source** — it supersedes `REPLY_POLICY.md` for all business decisions. `CLAUDE.md` remains the highest-level project rule (architecture + 20 project rules). `REPLY_POLICY.md` is a design artifact only.
- **Source priority between three business documents** (in descending authority): (1) `CLAUDE.md` — project rules and 3-layer architecture; (2) `docs/HMZ_APPROVED_REPLY_RULES.md` — owner-approved business and safety policy; (3) `docs/REPLY_POLICY.md` — design-phase taxonomy, superseded wherever it conflicts with (2).
- **Unsubscribe suppression scope** — organisation-wide, not workspace-only. Suppression must complete before any confirmation is sent. Blocklist API is still unconfirmed (ASSUMPTIONS_AND_UNKNOWNS.md B8); hard-suppression falls back to a UI-action task pending API confirmation.
- **Quiet hours** — Mon-Fri 08:00-18:00 prospect's local timezone. Max 24h hold before human escalation. Timezone fallback: `America/Chicago` for the initial ET/CT sprint. No auto-sends on weekends or US federal holidays.
- **Escalation surface** — three private Slack channels: `#reply-queue` (routine), `#reply-urgent` (P1/P2/legal/media), `#automation-alerts` (technical errors). Durable audit: restricted Google Sheet. Email fallback on Slack failure or P1 events.
- **Campaign allowlisting** — deny-all default. Exact Instantly campaign ID (not name) is the allowlist key. No campaigns are configured yet.
- **AI knowledge base** — does not exist yet. Must be created at `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` before Phase 3 Step 2. AI classifier and draft-generator contexts must remain separate.
- **Brainstorm checkpoint file written** — full Q&A record and open flags — `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\brainstorms\2026-06-09-instantly-rapid-reply-policy.md`

---

## Key files for next session

- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\HMZ_APPROVED_REPLY_RULES.md` — **read this first**. The owner-approved policy. Contains exact approved template wording, confidence thresholds (0.90/0.60), all 16 category actions, pre-send validation gate (7 checks), quiet-hours rules, escalation surface spec, campaign allowlist rules, prohibited content list, and the 19-item pre-deployment checklist.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\ARCHITECTURE.md` — data flow, 6 modular workflow specs, storage recommendation, latency budget. Contains the 0.85 threshold that needs correcting to 0.90.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\REPLY_POLICY.md` — design-phase taxonomy. Needs a header added noting it is superseded by `HMZ_APPROVED_REPLY_RULES.md` for all business decisions. The deterministic prefilter rule table in this file is still useful as a design reference; the thresholds and template wording must not be used in implementation.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\IMPLEMENTATION_PLAN.md` — Phase 3 build order (Steps 0-10). The pre-deployment checklist in Section 12 needs expanding to align with the 19-item list in `HMZ_APPROVED_REPLY_RULES.md` §17, and the knowledge-base and `config/live_campaigns.example.json` deliverables need to be reflected in the Step 0/1 sequence.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\ASSUMPTIONS_AND_UNKNOWNS.md` — Phase 1 gap list. B3 (`reply_to_uuid` source in webhook payload) and B9 (get-email/get-thread endpoints) remain the most operationally critical unresolved items. B6/B7 (`update-interest-status` and `subsequence/remove` request bodies) are required before suppression flows can be built.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\INSTANTLY_FIELD_MAP.md` — verified vs inferred vs unknown Instantly capabilities. Any Phase 3 implementation must re-consult this before assuming a field exists.
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\CLAUDE.md` — project rules including 20 Instantly Rapid Reply rules and the 3-layer architecture. Rules that constrain the next session: Rule #4 (n8n MCP required before building), Rule #2 (DRY_RUN=true until explicitly authorised), Rule #5 (no credentials in files/exports/logs).
- `C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\brainstorms\2026-06-09-instantly-rapid-reply-policy.md` — full Q&A record and open flags. Read if any approved policy detail needs tracing back to the interview source.

---

## Running state

- Background processes: none
- Dev servers / ports: none
- Open worktrees / branches: none (project is not a git repository)

---

## Verification — how to confirm things still work

- `Get-ChildItem C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\` — expected: 10 .md files (ARCHITECTURE, ASSUMPTIONS_AND_UNKNOWNS, ENVIRONMENT_AUDIT, HMZ_APPROVED_REPLY_RULES, IMPLEMENTATION_PLAN, INSTANTLY_FIELD_MAP, NORMALIZED_EVENT_SCHEMA, REPLY_POLICY, RISK_REGISTER, SESSION_HANDOFF_PHASE_2, SOURCES)
- `Get-ChildItem C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\brainstorms\` — expected: 1 file (`2026-06-09-instantly-rapid-reply-policy.md`)
- `Select-String -Path "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\HMZ_APPROVED_REPLY_RULES.md" -Pattern "policy-HMZ-1.0"` — expected: match on line 3 (version header)
- `Select-String -Path "C:\Users\Hamzah Zahid\Downloads\Claude\Instantly_Responder_Automation\docs\ARCHITECTURE.md" -Pattern "0.85"` — expected: match exists, confirming this is the stale threshold that needs correcting to 0.90

---

## Deferred + open questions

- **Deferred:** Phase 3 workflow build — deferred until all 3 blockers (A1 n8n MCP, A2 non-prod instance confirmation, A3 API key + Hyper Growth+ plan confirmation) are resolved.
- **Deferred:** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — must be written and approved by Hamzah + business partner before Phase 3 Step 2. Not a task for the next agent; this requires the user.
- **Deferred:** Classifier evaluation set and threshold validation — deferred to Phase 3.
- **Open:** n8n MCP registration — without it, CLAUDE.md Rule #4 cannot be satisfied and Phase 3 cannot begin. No resolution path was established this session.
- **Open:** Primary and backup escalation owner names — not yet designated (required before workflows go live).
- **Open:** Per-sender booking link URLs and sender-account name mappings — not yet provided.
- **Open:** US federal holiday calendar service — not yet chosen.
- **Open:** Legal/compliance review of the suppression and contact policy — flagged as required before live deployment; no reviewer identified.
- **Open:** B3 (`reply_to_uuid` source) — the most critical technical unknown. Cannot confirm the reply path works until a live `reply_received` payload is captured against a sacrificial campaign.

---

## Pick up here

Read `docs/HMZ_APPROVED_REPLY_RULES.md` first, then make surgical corrections to the Phase 2 documents to align them with the approved policy: update the 0.85 confidence threshold to 0.90 in `ARCHITECTURE.md`, add a supersession notice to `REPLY_POLICY.md`, and expand the pre-deployment checklist in `IMPLEMENTATION_PLAN.md` to match the 19-item list in `HMZ_APPROVED_REPLY_RULES.md` §17 — do not build any workflows.
