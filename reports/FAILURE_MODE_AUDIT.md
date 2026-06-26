# Phase 5 — Failure Mode Audit

**Date:** 2026-06-14
**Scope:** Hostile review of failure handling across duplicate intake, concurrency, suppression, escalation, retries, and SLA.

## 1. Duplicate intake

- Mechanism: Data Table upsert on `idempotency_key`; `createdAt !== updatedAt` after upsert → `is_duplicate=true` (Phase 3, runtime-verified against real n8n `2.25.7`).
- Second submission of an identical payload routes to `E4(false) -> E5. Duplicate Event Terminal`, `terminal_status=COMPLETED_NO_SEND`, `external_action_status=NOOP`, Decision Engine skipped.
- Malformed payloads (missing identifiers) use a content-hash-based key (`identifier_poor_hash`), preventing the collision where all malformed payloads previously shared one key (Phase 3 U3, RESOLVED).
- **No defect found.**

## 2. Concurrent send ownership / sequential rerun blocking

- Phase 4A: atomic concurrent lock verified and durable sequential-rerun block verified (42/42 passing suite).
- The implemented ownership mechanism is the internal `hmz-send-state` sidecar: exclusive lock-file creation blocks a concurrent second owner, while durable state-file existence blocks a later sequential rerun for the same stable send key. A losing path stops before any reply POST.
- **No defect found**, though this is offline/core-runtime-test evidence, not actual n8n-runtime evidence for the Sender (see Q7 in `reports/VALIDATION_REPORT.md`).

## 3. Dry-run prevention

- `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]` enforced project-wide; `IN_FLIGHT -> DRY_RUN_OK` transition stops short of any external call.
- `config_gate.passed=false` (e.g. a synthetic `live_campaign=true` claim while `dry_run=true`) routes to `B1(false) -> B2`, `terminal_status=REJECTED`, `processing_halted=true`, and the entire Decision Engine is skipped (Phase 3 U2, runtime-verified).
- **No defect found.**

## 4. Campaign allowlisting

- `LIVE_CAMPAIGNS=[]` means no campaign is currently allowlisted for live sends; any live-campaign claim is rejected by the configuration gate before Decision Engine invocation.
- **No defect found.**

## 5. Thread/reply identifiers

- V2 live capture confirmed `email_id` (the webhook's reply target) matches the retrievable inbound Email object ID, and `thread_id`/`message_id` are present and shared between inbound/outbound objects.
- **No defect found.** (B3/B10 in `docs/ASSUMPTIONS_AND_UNKNOWNS.md` now VERIFIED.)

## 6. Source-campaign stop

- V4A: replying controls received Step 1 and no Step 2 (sequence stopped); non-replying matched control received both steps.
- V4E: genuine `lead_unsubscribed` webhook changed source lead status to `-2`; Step 1 count remained 1, follow-up count remained 0.
- **No defect found.**

## 7. Exact workspace suppression

- V4D: exact email block-list enforcement verified workspace-wide — blocked address received no campaign email; matched unblocked control received one; entry later removed cleanly.
- V4E4 found ordinary unsubscribe is **campaign-local**, not workspace-wide, under the tested configuration. This is a **documented architectural consequence** (not a code defect): the production unsubscribe path must perform both the source-campaign action (B6) and the exact email-level Blocklist action (V4D). `docs/REPLY_POLICY.md` §6 and `docs/INSTANTLY_FIELD_MAP.md` §5.3 have been updated to require both actions for T7.
- **Defect found and corrected at the documentation level** (pre-existing design gap now made explicit); no workflow logic change was required because the Decision Engine action plan already separates "stop_active_sequence" from "suppression_level" as independent fields (`docs/STATE_AND_IDEMPOTENCY.md` §1.2).

## 8. Risky-category escalation

- T12 (legal/privacy/complaint) and T13 (hostile) always carry `stop_sequence=true` + `REVIEW_HOLD` + a paired suppression level, per `docs/REPLY_POLICY.md` §4; AI may never assign T7/T12/T13 — a proposed safety category becomes T15 → escalate with the proposed label attached.
- Phase 3 runtime-verified the unsubscribe/DNC path produces `terminal_status=REVIEW_HOLD`, `external_action_status=NOT_PERFORMED`, draft blocked.
- **No defect found.**

## 9. Template-variable safety

- Phase 4A/4B 60-fixture matrix exercises the `TEMPLATE_REGISTRY` and template-variable rendering paths; all embedded Code-node programs compiled and executed.
- **No defect found** (offline/runtime-suite evidence; no live send rendered a template against real Instantly data).

## 10. Retry classification / `Retry-After` / uncertain-send no-retry

- V5 Layer 1 fault-injection harness covers 400/401/402/403/404/429 (with and without `Retry-After`)/500/502/503/504, connection refused/reset, pre-submission failure, delayed/malformed response, post-submission timeout.
- Phase 4A confirms `SEND_UNCERTAIN` never blindly retries.
- **No defect found.**

## 11. Zero/one/multiple reconciliation

- V5 Layer 2: one controlled lost-response proxy test — request reached Instantly, response lost, state `SEND_UNCERTAIN`, no second POST, exactly one match found, `SENT_RECONCILED`, no duplicate.
- Zero-match and multiple-match outcomes are specified as "escalate to human review, no second POST" (`docs/STATE_AND_IDEMPOTENCY.md` §4, now updated) but were **not exercised against a live Instantly response** — these remain policy-verified only.
- **Open item, not a defect**: this is the principal remaining gap before `READY_FOR_CONTROLLED_LIVE_TEST` could be considered, flagged in `reports/UNRESOLVED_ITEMS.md`.

## 12. Error persistence / routing

- Error Handler workflow (`koyKIaY2ExF3yhx7`) is inactive, credential-free, and n8n-valid (0 errors per Phase 4A). It persists sanitised error records through the internal `hmz-send-state` `/v1/error` endpoint; no relational `errors` table is implemented in the validation architecture.
- **No defect found** (offline/runtime-suite evidence; no actual n8n-runtime execution of this workflow in Phase 4/5).

## 13. SLA warning/breach and Processing vs Transmission SLO separation

- Phase 4B: Watchdog runtime-smoke path passed, alert deduplication passed, durable `createdAt` survives state transitions, Processing and Transmission SLOs remain separately tracked.
- Phase 5: actual n8n execution of the SLA Watchdog completed successfully (exit 0, success marker observed), with the documented trigger limitation that the Schedule Trigger was fired via a manual/CLI execution rather than an active cron schedule.
- **No defect found.**

## Summary of defects found

One pre-existing **documentation gap** (item 7): the production unsubscribe path's requirement to perform both a source-campaign action and an exact email-level Blocklist action for true workspace-wide suppression was implied by V4E4/V4D evidence but not explicitly stated in `docs/REPLY_POLICY.md` / `docs/INSTANTLY_FIELD_MAP.md`. Corrected in this pass (documentation only; no workflow JSON changed, consistent with the existing action-plan schema).

No code, workflow-logic, or security defects were found that require a workflow change.
