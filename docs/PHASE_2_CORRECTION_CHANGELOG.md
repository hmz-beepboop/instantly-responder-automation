# Phase 2 Correction Changelog

Date: 2026-06-10. This records every material correction made during the Phase 2 surgical correction pass. It captures concise decision rationale only — no private chain-of-thought. Where a Grill Me preference was changed, the original is preserved here so it can be restored by explicit owner override.

Legend for "Owner approval still required?": **YES** = blocked on an owner decision before it can change again or go live; **NO** = safe default applied, owner may override later.

---

## C1 — Source hierarchy corrected
- **Previous:** Session handoff placed `CLAUDE.md` above the business documents as the source of business authority.
- **Corrected:** Business facts/maturity/strategy come from `Abs Plan.docx` (1) → `Product_Offer_Intake_COMPLETED.docx` (2) → reconciled `HMZ_APPROVED_REPLY_RULES.md` (3) → Alpha Offer (4, future-only). `CLAUDE.md` governs agent workflow only and may not turn a hypothesis into a fact. New file: `docs/SOURCE_PRIORITY.md`.
- **Reason / principle:** No instruction file may manufacture business facts. Correction-prompt §"Source priority" and §13.
- **Owner approval required?** NO.
- **Effect on next phase:** All runtime claims gated through the approved knowledge base.

## C2 — Auto-send permissions (VALIDATION mode) — Grill Me reconciled
- **Previous (Grill Me):** Four categories auto-send-eligible at ≥0.90 confidence: T1 (3 variants), T3, T4 (2 variants), T6.
- **Corrected:** In `OPERATING_MODE=VALIDATION` (default), no substantive prospect reply auto-sends. T1/T2/T3/T4/T5 drafts or fixed templates require human approval before sending. T6/T10 acknowledgements are send-only-if-explicitly-enabled. T3 fixed-template auto-send may be enabled only after controlled testing + explicit owner approval (PROVEN mode). Deterministic safety actions (stop sequence, suppression for T7/T12/T13) still execute automatically.
- **Reason / principle:** The first campaign is market validation; prospect replies are research evidence and must not be hidden by premature automation (correction-prompt §4). Several Instantly send mechanisms are still unverified (C10), so auto-send cannot be relied on yet.
- **Original preference preserved:** four auto-send categories at 0.90 — restorable in PROVEN mode after testing + owner override.
- **Owner approval required?** YES to enable any auto-send.
- **Effect on next phase:** Build the draft + notify + human-approval path; do not build unattended auto-send.

## C3 — Confidence threshold no longer authorises a send
- **Previous:** 0.90 auto-send threshold / 0.60 escalation threshold (Grill Me); design doc used 0.85.
- **Corrected:** A confidence score is necessary but never sufficient. Sending requires ALL gates: category permits sending, operating mode permits sending, campaign allowlisted, sender approved, template/KB version approved, no risk flag, suppression clear, idempotency clear, thread mapping verified, send mechanism verified, DRY_RUN disabled by explicit approval. 0.90/0.60 retained as conservative bands; the stale 0.85 is removed. Thresholds remain pending evaluation-set validation.
- **Reason / principle:** A high score must not override a prohibited category or a missing safety gate (correction-prompt §9).
- **Owner approval required?** YES (threshold changes need owner sign-off).
- **Effect on next phase:** Implement the gate list, not a single threshold check.

## C4 — Quiet-hours holding removed from Validation MVP
- **Previous (Grill Me):** Mon-Fri 08:00-18:00 prospect local time; queue/hold outside window; max 24h hold; no sends on weekends/US federal holidays; holiday-calendar service required.
- **Corrected:** Validation MVP processes every event immediately and notifies the operator immediately. No quiet-hours hold, no prospect-timezone scheduling, no federal-holiday calendar. Auto-send (when later enabled) sends immediately or not at all; a queued/scheduled reply is never counted as transmitted. Quiet-hours logic moved to the Production profile.
- **Reason / principle:** A multi-hour hold conflicts with the five-minute response objective (correction-prompt §6).
- **Original preference preserved:** the full quiet-hours/holiday spec, recorded here and retained in the Production profile for later reintroduction.
- **Owner approval required?** NO to remove; YES to reintroduce in Production.
- **Effect on next phase:** No holiday API, no timezone scheduler in MVP.

## C5 — Five-minute SLO split into Processing SLO and Transmission SLO
- **Previous:** A single five-minute objective, partially conflated with notification/queueing.
- **Corrected:** Two distinct metrics. **Processing SLO** = validated, classified, drafted, suppressed, routed, or escalated within 5 min. **Transmission SLO** = an eligible prospect-facing reply actually transmitted within 5 min. A Slack/email notification, queue entry, sheet row, escalation case, draft, approval request, scheduled/held reply is NOT a transmission. Separate timestamps tracked across the lifecycle.
- **Reason / principle:** Correction-prompt §5; prevents counting an alert as a prospect response.
- **Owner approval required?** NO.
- **Effect on next phase:** Normalized schema and case record carry lifecycle timestamps.

## C6 — Single action enum replaced with a structured action plan
- **Previous:** Decision = one of `AUTO_SEND` / `SUPPRESS` / `ESCALATE` / `NOOP`.
- **Corrected:** A structured action plan with independent fields (`stop_sequence`, `pause_sequence`, `suppression_level`, `reply_mode`, `human_review_required`, `escalation_required`, `priority`, `send_allowed`, etc.) plus named `reply_mode` and `suppression_level` enumerations. Each action maps to business outcome → verified mechanism → provisional fallback → human task when no API exists. Resolves T12/T13 contradictions where one table said `ESCALATE` and another `SUPPRESS + ESCALATE`.
- **Reason / principle:** A single enum cannot represent combined behaviour (e.g. suppress AND escalate AND preserve evidence). Correction-prompt §8.
- **Owner approval required?** NO.
- **Effect on next phase:** Decision Engine emits an action plan object; schema in `STATE_AND_IDEMPOTENCY.md`.

## C7 — Webhook acknowledgement and authentication corrected
- **Previous:** Design acked 200 within ≤1s and also rejected with 401 on bad secret — contradictory. Auth assumed an Instantly-sent `X-Webhook-Secret` custom header as if verified.
- **Corrected:** Sequence = receive → minimal request authentication / compensating-control validation → minimum schema validation → respond appropriately (200 for accepted, 401/4xx for rejected) → continue processing asynchronously only after acceptance. Webhook protection is a **configurable strategy pending verification** (secret URL path, secret query param, native header/secret if supported, native signature if supported, source allowlist, strict payload validation, campaign/sender allowlist, API-side event verification, rate limiting), with primary auth distinguished from compensating controls. No method marked verified.
- **Reason / principle:** Cannot return 200 then 401 for the same request; cannot assume Instantly can send a custom secret header. Correction-prompt §2.
- **Owner approval required?** NO (design); verification required before build.
- **Effect on next phase:** Auth strategy selected and verified at build time, not assumed.

## C8 — Two architecture profiles (Validation MVP vs Production)
- **Previous:** One architecture mandating Supabase/Postgres, three Slack channels, Google Sheets audit, external heartbeat, holiday API, 6 workflows.
- **Corrected:** **Validation MVP** = smallest safe system (intake, validation/compensating controls, normalization, dedupe, deterministic safety, classification where needed, action-plan generation, draft/template selection, immediate human notification, sequence stop/suppression where verified, optional approved send, basic case state, latency logging, synthetic tests, failure visibility). One configurable human-review destination + one durable case record. **Production profile** retains Postgres/Supabase, richer observability, external heartbeat, multi-channel escalation, holiday scheduling, etc. as later options with explicit migration triggers.
- **Reason / principle:** Lightest reliable architecture for a ~500-email US validation sprint (correction-prompt §3).
- **Owner approval required?** NO to scope MVP; storage/destination choices deferred (C9).
- **Effect on next phase:** Build MVP only.

## C9 — Storage selection deferred with a preference order
- **Previous:** "Chosen: Supabase Postgres."
- **Corrected:** Storage not chosen conclusively. Preference order: (1) suitable n8n-native persistent storage if verified adequate; (2) an already-approved existing durable database; (3) a new Postgres/Supabase deployment only if the first two are demonstrably inadequate. Decision deferred until n8n MCP and the real environment are available.
- **Reason / principle:** Do not provision new infrastructure the validation sprint may not need. Correction-prompt §3.
- **Owner approval required?** YES (storage choice).
- **Effect on next phase:** Storage choice is an entry gate, not a build assumption.

## C10 — Technical facts reclassified (VERIFIED / PROVISIONAL / BLOCKED / NOT REQUIRED)
- **Previous:** Several Instantly capabilities and environment facts implied as available/confirmed (Hyper Growth tier, `X-Webhook-Secret`, `reply_to_uuid` source, thread/reconciliation endpoints, blocklist endpoint, n8n MCP, non-prod instance).
- **Corrected:** Each item labelled VERIFIED / PROVISIONAL / BLOCKED / NOT REQUIRED FOR VALIDATION MVP across the docs. No Instantly subscription tier claimed confirmed. Webhook event names/payload fields, `reply_to_uuid`, thread/reconciliation/blocklist endpoints, interest-status and subsequence bodies, webhook auth/header support, n8n MCP availability, non-prod instance, credential scopes, rate-limit behaviour — all PROVISIONAL or BLOCKED until evidence exists. Implementation blocked where a required capability is unverified.
- **Reason / principle:** Correction-prompt §1; do not represent unverified items as verified.
- **Owner approval required?** NO (verification, not approval).
- **Effect on next phase:** Blocked items gate the build; safe fallbacks documented.

## C11 — Taxonomy T1/T2 corrected and brittle rules repaired
- **Previous:** T1 included Scenario B ("how does it work?" / "tell me more"). Media/journalist auto-classed as hostile (T13). `List-Unsubscribe` inbound header treated as explicit opt-out. Bounce inferred from generic automated sender. First-match-wins could erase higher-risk flags.
- **Corrected:** T1 = clear positive interest WITHOUT a substantive factual/information request. T2 = "how does it work?", "tell me more", "send information", proof/case-study/feature/mechanism/scope questions. T1 Scenario B moved to T2 (escalate, draft from KB only). T3 = explicit booking/scheduling intent. Media/journalist = human-review **risk flag**, not automatic hostile. Inbound `List-Unsubscribe` header is NOT evidence the prospect personally opted out. Automated sender address alone is not a bounce without delivery-status evidence. Isolated tokens (e.g. "price") do not classify when context changes meaning. Safety-critical deterministic rules may short-circuit; non-safety rules collect evidence. All detected categories/questions/risk flags preserved for mixed-intent; final primary category selection defined; a lower-risk category cannot erase a legal/unsubscribe/privacy/hostile flag.
- **Reason / principle:** Correction-prompt §7.
- **Owner approval required?** NO.
- **Effect on next phase:** Reply-policy and KB align; T1 templates lose the info-request variant (now T2).

## C12 — Suppression semantics defined as levels
- **Previous:** "SUPPRESS" used loosely; org-wide unsubscribe suppression assumed; suppression mechanisms assumed available.
- **Corrected:** Named `suppression_level` enum (`NONE`, `STOP_ACTIVE_SEQUENCE`, `CAMPAIGN_ONLY`, `WORKSPACE_DNC`, `ORGANISATION_DNC`, `GLOBAL_BLOCKLIST`, `LEGAL_REVIEW_PENDING`) with the operational distinctions (pause vs stop vs subsequence-removal vs not-interested vs unsubscribe vs workspace DNC vs org suppression vs global blocklist vs record-preserving). Each level maps to a verified mechanism or a human task when no API exists. Not all operations assumed available. T7 org-wide DNC preference preserved but reconciled: suppression executes at the strongest **verified** level, with a human task closing the gap to org-wide; confirmation only after verified suppression.
- **Reason / principle:** Correction-prompt §8; blocklist/interest-status APIs unverified (C10).
- **Owner approval required?** Partly — org-wide propagation depends on systems/mechanisms the owner must confirm.
- **Effect on next phase:** Suppression sub-workflow records per-level results and raises human tasks for unverified levels.

## C13 — Slack-channel design reduced for MVP
- **Previous (Grill Me):** Three private Slack channels (`#reply-queue`, `#reply-urgent`, `#automation-alerts`) + restricted Google Sheet audit + email fallback.
- **Corrected:** Validation MVP uses **one configurable primary human-review destination** + **one durable case record**, with urgency carried as a field on the case (routine vs urgent vs technical), not three mandated channels. No mandated service. Multi-channel separation, Google Sheets audit, and email fallback move to the Production profile as options the owner may select.
- **Reason / principle:** Lightest reliable MVP (correction-prompt §3).
- **Original preference preserved:** three-channel + Sheet + email design, retained in Production profile.
- **Owner approval required?** YES (which destination/service).
- **Effect on next phase:** Human-review destination is a generic placeholder until the owner selects it.

## C14 — Google Sheets durable audit no longer mandatory
- **Previous (Grill Me):** Restricted Google Sheet as the durable audit log.
- **Corrected:** Durable case record required, but the technology is the deferred storage choice (C9), not mandated Sheets. Sheets allowed only if the owner selects it.
- **Reason / principle:** Avoid mandating a service and leaking PII into Drive before it is chosen.
- **Owner approval required?** YES.
- **Effect on next phase:** One durable case record, technology TBD.

## C15 — Knowledge base drafted now
- **Previous:** Handoff said KB creation was "not a task for the next agent."
- **Corrected:** Conservative draft created at `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` (`KB-1.0-DRAFT`) + `docs/KNOWLEDGE_BASE_CHANGELOG.md`. Clearly marked draft, not approved for runtime, pricing human-only, all proof/result claims prohibited.
- **Reason / principle:** Correction-prompt §10.
- **Owner approval required?** YES (Hamzah + business partner to approve `KB-1.0`).
- **Effect on next phase:** Draft exists for owner review; runtime still treats KB facts as pending.

## C16 — Implementation plan reduced to the Validation MVP intake + decision path
- **Previous:** 10-step plan building all 6 workflows, Supabase, watchdog, reconciler, ramp, with n8n MCP / Hyper Growth+ stated as prerequisites and `≤200ms p95` latency targets.
- **Corrected:** Next implementation scope limited to: intake skeleton, minimal webhook validation, normalization, idempotency-state design, deterministic safety prefilter, classifier interface using mocks, structured action-plan generation, human-review routing placeholder, basic case-state persistence, synthetic test harness, no real send. Deterministic tests only for deterministic categories; mocked classifier for semantic categories. Speculative latency thresholds replaced with "measure a baseline, then set a target in the real environment." Uncertain-send reconciliation that cannot be verified does not auto-retry — it raises an urgent human case. Controlled live testing and production deployment excluded from the next phase. Explicit entry gates added.
- **Reason / principle:** Correction-prompt §11.
- **Owner approval required?** Entry gates must be satisfied/owner-confirmed before build.
- **Effect on next phase:** Defines exactly what gets built next.

## C17 — Root `CLAUDE.md` cleaned
- **Previous:** ~146 lines with escaped Markdown, Google Sheets/Slides rules, generic OAuth/Python-folder doctrine, mirrored-file and directive-overwrite doctrine.
- **Corrected:** Concise project-specific file (<120 lines) retaining objective, source hierarchy pointer, n8n-MCP-first rule, Instantly-verification rule, status discipline, non-prod restriction, DRY_RUN, no-secrets, no-real-sends-without-approval, incremental build, deterministic-safety-before-AI, idempotency, structured action plan, no invented claims, VALIDATION default, no mature-offer claims, save decisions, preserve sources, no production-readiness claims without evidence.
- **Reason / principle:** Correction-prompt §12.
- **Owner approval required?** NO.
- **Effect on next phase:** Cleaner project rules; no business-fact override.

## C18 — Operating modes added
- **Corrected:** `OPERATING_MODE=VALIDATION` (default) and `OPERATING_MODE=PROVEN` defined with per-category rules (T1-T16). PROVEN mode is documented but not active and is gated behind synthetic eval + controlled testing + labelled real-reply review + template-safety + owner approval + approved KB + verified suppression/send.
- **Reason / principle:** Correction-prompt §4.
- **Owner approval required?** YES to activate PROVEN.
- **Effect on next phase:** All policy/architecture/implementation docs reference the same mode rules.

---

## Summary of Grill Me decisions by disposition
See `HMZ_APPROVED_REPLY_RULES.md` §0 (reconciliation table) for the per-decision classification (preserved / reworded / deferred to Production / replaced for MVP / blocked / requires owner override).
