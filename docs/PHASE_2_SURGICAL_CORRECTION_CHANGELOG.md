# Phase 2 Surgical Correction Changelog (1.1 → 1.2)

Date: 2026-06-10. This records every material correction made during the **second** Phase 2 correction pass — a *surgical* pass reconciling the existing Phase 2 documents (already corrected once, 1.0→1.1, in `docs/PHASE_2_CORRECTION_CHANGELOG.md`) with the business sources, removing remaining ambiguity, and **stopping before Prompt 3**. It captures concise decision rationale only — no private chain-of-thought.

This pass bumps `policy-HMZ-1.1` → `policy-HMZ-1.2` (`docs/HMZ_APPROVED_REPLY_RULES.md` §18) and `KB-1.0-DRAFT` remains unchanged in version (still draft, not approved) but gains new fields (D11/D12).

Legend for "Owner approval still required?": **YES** = blocked on an owner decision before it can change again or go live; **NO** = safe default applied, owner may override later.

The 15 numbered items in the correction-prompt this pass reconciles are mapped to D-items below. Items 2 and 13 of that prompt (project scope vs scope clarification) were addressed as a single coherent change (D2), since both concern the same `CLAUDE.md` "Scope" section and its downstream references.

---

## D1 — Source grounding corrected (project-relative paths + new register)
- **Previous:** Business-source references were inconsistent — some bare filenames (e.g. `Abs Plan.docx`, `Product_Offer_Intake_COMPLETED.docx`) without project-relative paths, and the rank-4 source was initially identified as `03_Alpha_Offer_SUPERSEDED.docx`, a file that does not exist in `sources/business/`.
- **Corrected:** New `docs/BUSINESS_SOURCE_REGISTER.md` lists all three business documents by their actual project-relative paths under `sources/business/`. Rank 4 is `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` (corrected mid-pass per explicit owner instruction, superseding the original mis-identification). All current-guidance documents (`docs/SOURCE_PRIORITY.md`, `docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/VALIDATION_CAMPAIGN_CONFIG.md`) now use these full paths. Two changelog entries describing the *prior* (1.0→1.1) pass — `docs/PHASE_2_CORRECTION_CHANGELOG.md:11` and `docs/KNOWLEDGE_BASE_CHANGELOG.md:7` — retain the un-prefixed names as a historical record of what was written at that time (`reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` §A).
- **Reason / principle:** Source documents must be locatable and unambiguous; an incorrect rank-4 identification could misattribute future-only claims to the wrong document.
- **Owner approval required?** NO.
- **Effect on next phase:** Any future source lookup resolves to a real, correctly-ranked file.

## D2 — Project scope clarified: HMZ's own validation campaign, not a reusable client responder
- **Previous:** `CLAUDE.md` had no dedicated "Scope" section; `docs/ARCHITECTURE.md` and `docs/IMPLEMENTATION_PLAN.md` described the system in terms general enough to be read as a reusable client-facing responder.
- **Corrected:** New `## Scope` section in `CLAUDE.md` states this system supports **HMZ's own initial US B2B validation campaign only**, is single-tenant for one Instantly workspace, is **not yet a reusable client responder**, and lists the five separate approvals (client-specific KB, client-specific reply policy, confirmed sender identity/workspace model, jurisdiction-specific compliance review, controlled testing in that client's environment) required before any future client-facing use — none of which exist yet. `docs/ARCHITECTURE.md` and `docs/IMPLEMENTATION_PLAN.md` each gained a matching scope paragraph citing `CLAUDE.md` "Scope" and `docs/VALIDATION_CAMPAIGN_CONFIG.md`.
- **Reason / principle:** The current project is HMZ's own US validation outreach, not a finished client-deployment responder; this must be unambiguous in the documents an implementation phase would read first.
- **Owner approval required?** NO.
- **Effect on next phase:** Prompt 3 (whenever authorised) builds only the single-tenant validation-campaign system; any client-responder framing in a future request would itself require new approvals first.

## D3 — Five-minute objective restated with staged sub-targets
- **Previous:** `CLAUDE.md` and `docs/ARCHITECTURE.md` carried the Processing/Transmission SLO split (from the 1.0→1.1 pass, C5) but without staged sub-targets within the 5-minute Processing SLO, and without an explicit "no-reply = success" statement in `ARCHITECTURE.md`.
- **Corrected:** `CLAUDE.md` "Five-minute objective" section and `docs/ARCHITECTURE.md` §1 both now state the staged sub-targets: webhook acknowledgement immediate; classification + action plan within 60s; draft (where `draft_required=true`) + human notification within 120s; processing concluded (completed/suppressed/escalated) within 300s. Both restate that an intentional no-reply (e.g. `NO_REPLY` outcomes) completing within the Processing SLO is a **successful resolution**, and that the Transmission SLO has no guarantee in `OPERATING_MODE=VALIDATION`. `docs/HMZ_APPROVED_REPLY_RULES.md` §10 (already staged from a prior pass) is the authoritative source both now cite.
- **Reason / principle:** A single 5-minute figure without sub-targets and without an explicit no-reply=success statement risks being read as "every reply must go out in 5 minutes," which directly conflicts with `OPERATING_MODE=VALIDATION`'s human-approval requirement.
- **Owner approval required?** NO.
- **Effect on next phase:** Lifecycle-timestamp instrumentation (already specified in `docs/STATE_AND_IDEMPOTENCY.md` §1.10) can be checked against these four concrete sub-target checkpoints.

## D4 — Validation cells and campaign-context fields added
- **Previous:** No formal validation-cell taxonomy existed; the Normalized Event Schema had no mechanism to attach segment/sub-segment/pain-trigger/offer-angle context to an inbound reply, so the classifier and draft-generator had no campaign-specific grounding.
- **Corrected:** New `docs/VALIDATION_CAMPAIGN_CONFIG.md` defines three validation cells — `CELL_1_SAAS_SALES_HIRING`, `CELL_2_SAAS_EXISTING_OUTBOUND`, `CELL_3_SPECIALISED_B2B_AGENCY` — sourced verbatim from `sources/business/01_Abs_Plan.docx` Phase 3 (segment, subsegment, buyer, pain_trigger, offer_angle per cell), plus an (initially empty) campaign registry mapping `campaign_id` → cell + context. `docs/NORMALIZED_EVENT_SCHEMA.md` gained a `campaign_context` object (new §3.4) populated via this campaign-ID lookup, with explicit handling for unregistered campaigns (`campaign_context` fields = `UNKNOWN`, human-review flag, independent of the `LIVE_CAMPAIGNS` send-allowlist) and an explicit rule that Cell 3 events must never receive the Cell 1/2 SaaS hypothesis context.
- **Reason / principle:** The classifier and draft-generator need to know *which* validation hypothesis a given reply is testing (SaaS sales-hiring vs SaaS existing-outbound vs specialised agency) to avoid grounding a Cell 3 agency reply in SaaS-specific language.
- **Owner approval required?** YES for any registry row (campaign-context mapping is itself owner-approved configuration, `docs/VALIDATION_CAMPAIGN_CONFIG.md` §4).
- **Effect on next phase:** Reply Intake / Decision Engine implementation includes the campaign-ID → `campaign_context` lookup as part of normalization (already reflected in `docs/ARCHITECTURE.md` §2 step 3 and `docs/IMPLEMENTATION_PLAN.md` §2 item 3).

## D5 — Geography lock added (`geo_code=US_B2B_CORE_12`)
- **Previous:** No formal geography constraint existed in the schema or architecture; handling of a reply indicating the prospect is outside the intended US geography was undefined.
- **Corrected:** `docs/VALIDATION_CAMPAIGN_CONFIG.md` §1 defines `geo_code=US_B2B_CORE_12` (United States only, English, USD, CAN-SPAM frame, ET/CT timezone window first) with the fixed 12-city sourcing pool from `sources/business/01_Abs_Plan.docx` Phase 1 (New York, Boston, Washington DC, Philadelphia, Atlanta, Miami, Chicago, Austin, Dallas, Houston, Raleigh-Durham, Charlotte) and explicit first-sprint exclusions (California, Seattle, Portland, Mountain timezones, non-US). `geo_code` is attached via `campaign_context` (D4). A reply indicating the prospect is outside `US_B2B_CORE_12` is a **human-review flag**, not an automatic rejection or suppression — stated identically in `docs/VALIDATION_CAMPAIGN_CONFIG.md` §1.3, `docs/NORMALIZED_EVENT_SCHEMA.md` §2/§3.4, and `docs/ARCHITECTURE.md` §2.
- **Reason / principle:** The validation sprint is intentionally geography-locked for sourcing/sequencing reasons (not a permanent restriction), but an off-geography reply is still real research evidence and must reach a human, not be silently dropped.
- **Owner approval required?** Changes to the cell/geo definitions require owner + business-partner approval (`docs/VALIDATION_CAMPAIGN_CONFIG.md` §4); the lock itself reflects existing rank-1 source content, so no new approval needed to *record* it.
- **Effect on next phase:** Geo-mismatch becomes one more case attribute the human-review surface displays, not a code path that can silently discard a reply.

## D6 — T1/T3 separation tightened (explicit booking/scheduling intent)
- **Previous:** T1 (`positive_interest`) was defined as positive interest "without a substantive factual/information request" but did not explicitly exclude scheduling/booking language; `det-booking-001` (T3) covered "calendar link or availability request" without an explicit catch-all for other scheduling phrasing. This left a narrow ambiguity for replies like "Sounds good, when works for you?" (positive interest *and* an implicit scheduling ask).
- **Corrected:** T1's definition (`docs/REPLY_POLICY.md` §1, `docs/HMZ_APPROVED_REPLY_RULES.md` §3) now explicitly excludes "an explicit booking/scheduling request (see T3)". T3's definition is broadened to "explicit booking/scheduling intent (calendar link request, offered availability/times, or any other explicit request to schedule)" and `det-booking-001`'s trigger is updated to match. T3 is stated to have its own approved template — which **may reuse T1's wording** — but a reply matching T3's trigger is **always recorded as T3, never reclassified as T1**.
- **Reason / principle:** T1 and T3 drive different `template_id`s and (in a future PROVEN mode) potentially different auto-send eligibility; conflating "interested" with "interested and asking to book" would lose the scheduling signal even if the reply text sent to the prospect ends up similar.
- **Owner approval required?** NO.
- **Effect on next phase:** Test-harness fixtures must include at least one "positive interest with explicit scheduling ask" case asserting T3, not T1.

## D7 — Referral (T5) acknowledgement template added
- **Previous:** T5 (`referral` — "redirects to a colleague") had a category definition and `det-referral-001` deterministic trigger, but `docs/HMZ_APPROVED_REPLY_RULES.md` §6 had no approved acknowledgement wording for T5, leaving `reply_mode=FIXED_TEMPLATE_APPROVAL (ack)` without a template to select.
- **Corrected:** `docs/HMZ_APPROVED_REPLY_RULES.md` §6 gained an approved T5 acknowledgement template — a short, neutral thank-you/redirect acknowledgement with no claims, no pricing, and the standard unsubscribe footer, consistent with the other ack templates (T6/T10).
- **Reason / principle:** Every category whose action plan can produce `reply_mode=FIXED_TEMPLATE_APPROVAL` needs an approved template to point `template_id` at; T5 was the one remaining gap.
- **Owner approval required?** YES (template wording is owner-approved per `docs/HMZ_APPROVED_REPLY_RULES.md` §18) — recorded here as drafted-and-pending-approval, consistent with the rest of §6.
- **Effect on next phase:** T5's action plan can reference a real `template_id`; no remaining "ack category with no template" gap.

## D8 — Review-hold semantics renamed; independent review-type booleans added
- **Previous:** The `suppression_level` enum included `LEGAL_REVIEW_PENDING`, a name that implied legal review specifically even though T12 (legal/privacy) and T13 (hostile/reputational) both used it, and there was a single implicit "review required" concept rather than separate flags per risk type.
- **Corrected:** `LEGAL_REVIEW_PENDING` renamed to the neutral **`REVIEW_HOLD`** throughout `docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/REPLY_POLICY.md`, `docs/ARCHITECTURE.md`, and `docs/STATE_AND_IDEMPOTENCY.md` (the 1.0→1.1 instance of `LEGAL_REVIEW_PENDING` in `docs/PHASE_2_CORRECTION_CHANGELOG.md` is left as a historical record of the prior pass). Three new independent action-plan booleans — `legal_review_required`, `privacy_review_required`, `reputational_review_required` — are set per detected risk type, not uniformly: a T12 legal/privacy case may set `legal_review_required` and/or `privacy_review_required` without `reputational_review_required`, and a T13 hostile/reputational case may set only `reputational_review_required`. New §7.1 (D9) is the authoritative per-category mapping.
- **Reason / principle:** "Legal review pending" as a suppression-level name and as the only review flag conflated three distinct review types (legal, privacy, reputational) that may need different reviewers and different downstream handling, even though all three currently pair with the same hold state.
- **Owner approval required?** NO (naming/structure clarification; no change to which categories trigger a hold).
- **Effect on next phase:** `cases`/`decisions` schema (`docs/STATE_AND_IDEMPOTENCY.md` §1.2) carries the three booleans; the human-review surface can route a `REVIEW_HOLD` case to the right reviewer(s) based on which boolean(s) are set.

## D9 — Stop vs suppression mapping made explicit (new §7.1)
- **Previous:** The relationship between `stop_sequence`/`pause_sequence` and `suppression_level` for each of the 16 categories was implicit, scattered across the category→action table and the suppression-levels section, with no single authoritative per-category mapping.
- **Corrected:** New `docs/HMZ_APPROVED_REPLY_RULES.md` §7.1 gives an explicit per-category mapping of `stop_sequence`/`pause_sequence` to `suppression_level` (including which categories pair `REVIEW_HOLD` with a verified suppression level, and which `*_review_required` booleans apply). `docs/REPLY_POLICY.md`, `docs/ARCHITECTURE.md` §5, and `docs/STATE_AND_IDEMPOTENCY.md` §1.2 all defer to §7.1 as the authority rather than restating their own (potentially drifting) mappings.
- **Reason / principle:** A single authoritative mapping prevents the kind of T12/T13 contradiction the 1.0→1.1 pass already fixed once (C6) from silently re-appearing as the schema gains more fields (D8).
- **Owner approval required?** NO (clarifies existing approved behaviour; does not change which categories stop/suppress).
- **Effect on next phase:** Decision Engine's action-plan generation for stop/suppression fields can be implemented as a direct table lookup against §7.1.

## D10 — T4 timing-objection `follow_up_date` clarified as non-executable metadata
- **Previous:** T4 (`timing_objection`)'s action plan included a `follow_up_date` field, but whether the Validation MVP would *act* on it (e.g. auto-resurface the lead, schedule a follow-up send) was unstated — a risk of an implied automated follow-up sequence that doesn't exist yet.
- **Corrected:** `docs/HMZ_APPROVED_REPLY_RULES.md` §6/§9.2 now states `follow_up_date` is **non-executable metadata for the Validation MVP** — recorded for human reference only; no automated job reads or acts on it.
- **Reason / principle:** Avoids an implicit promise of automated follow-up scheduling that the Validation MVP (per `docs/IMPLEMENTATION_PLAN.md` §2, 11 items) does not build.
- **Owner approval required?** NO.
- **Effect on next phase:** No follow-up scheduler is in scope for the next phase; `follow_up_date` is just a stored value on the case record.

## D11 — Validation evidence fields added (11 fields, internal only)
- **Previous:** The `cases` table had no structured way to record what a human reviewer learned from a reply as *validation evidence* (e.g. "did this reply confirm the hypothesised pain point?", "did the prospect mention current outbound spend?") — this information, if captured at all, would have been free-text only.
- **Corrected:** `docs/STATE_AND_IDEMPOTENCY.md` §1.9 gained 11 new `cases` columns, all set by the human reviewer and never auto-derived from confidence scores or prospect-facing: nine boolean tri-state (`true`/`false`/`unknown`) fields — `pain_confirmed`, `current_outbound_spend_confirmed`, `capacity_problem_confirmed`, `proof_objection`, `pricing_interest`, `alpha_interest`, `decision_maker_confirmed`, `discovery_call_booked`, `discovery_call_showed` — plus `validation_signal_strength` (`weak`/`moderate`/`strong`/`unknown`) and `voice_of_customer_excerpt` (≤280 chars, PII-scrubbed, never reused as a claim in a different prospect's draft). `docs/HMZ_APPROVED_REPLY_RULES.md` §11 and `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §11/§13 cross-reference these fields.
- **Reason / principle:** This is a validation-stage sprint (`CLAUDE.md` Objective) — prospect replies are research evidence, and that evidence needs a structured home so later phases don't depend on chat history or reviewers' memory (`CLAUDE.md` rule #17).
- **Owner approval required?** NO to add the fields; the fields themselves never authorise anything (e.g. `pricing_interest=true` never authorises an automated price disclosure, per `CLAUDE.md` rule #15 and `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §13).
- **Effect on next phase:** Case-state persistence (`docs/IMPLEMENTATION_PLAN.md` §2 item 9) includes these 11 columns from the start, even though no UI to populate them is built in the next phase.

## D12 — Commercial stage (`interest_stage`) enum added
- **Previous:** A T1 (`positive_interest`) reply and a reply expressing interest in a *future paid engagement* (Alpha) were both just "positive interest," with no field distinguishing "interested in continuing this validation conversation" from "interested in becoming a future paying customer" — a risk of a positive T1 reply being mistaken for commercial/Alpha interest.
- **Corrected:** New `interest_stage` enum (`DISCOVERY_ONLY` / `VALIDATION_SPRINT_INTEREST` / `ALPHA_INTEREST` / `UNKNOWN`) added to `cases` (`docs/STATE_AND_IDEMPOTENCY.md` §1.9), set by the human reviewer, never disclosed to a prospect. `docs/STATE_AND_IDEMPOTENCY.md` and `docs/HMZ_APPROVED_REPLY_RULES.md` §11 both state explicitly: **a positive T1 reply alone does not justify `ALPHA_INTEREST`** (or `alpha_interest=true` in D11) — that requires the reviewer's separate judgement.
- **Reason / principle:** `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` (rank 4) is future-only; conflating ordinary validation-conversation interest with Alpha-stage commercial interest would risk the kind of premature "ready to buy" framing `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §14 prohibits.
- **Owner approval required?** NO.
- **Effect on next phase:** The human-review surface can show `interest_stage` as a separate field from the reply category, preventing T1-as-commercial-signal conflation in reporting.

## D13 — Superseded session handoff archived; new current handoff written
- **Previous:** `docs/SESSION_HANDOFF_PHASE_2.md` (already marked superseded at its top from the 1.0→1.1 pass) remained in `docs/`, where a future session might read it first and pick up stale (1.1-era) instructions.
- **Corrected:** Moved to `archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md` (verified no remaining non-archive references to the old path, `reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` §C). New `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` written after this changelog, summarising the 1.1→1.2 state, this changelog, and the audit verdict (D14).
- **Reason / principle:** `CLAUDE.md` rule #17 — later phases should not depend on chat history, and should not be misdirected by an archived handoff sitting in the active `docs/` directory.
- **Owner approval required?** NO.
- **Effect on next phase:** A future session reads `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` first.

## D14 — Prompt-3 readiness gating added (Route A vs Route B); audit verdict recorded
- **Previous:** `docs/IMPLEMENTATION_PLAN.md` had an "Entry gates" section, but no explicit decision framework for *how* a future Prompt 3 should proceed given `CLAUDE.md` rule #1's "n8n MCP first... offline design only, and only if the user authorises it."
- **Corrected:** `docs/IMPLEMENTATION_PLAN.md` §1 now defines **Route A** (n8n MCP-verified build — preferred, requires MCP connected + non-prod instance confirmed + node schemas inspected + Instantly fields verified/mocked + storage choice verified + human-review destination selected + no real sends) and **Route B** (offline mock-only design — fallback, requires explicit recorded owner authorisation + design-only output + all external interfaces mocked + `DRY_RUN=true`/`LIVE_CAMPAIGNS` empty hard-locked + mandatory later MCP re-verification recorded as a precondition). If neither route's gates are met → **NOT READY FOR PROMPT 3**. New `reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` runs the full consistency audit (source grounding, prohibited claims, cross-references, terminology, T1/T2/T3 distinguishability, stop/suppression/`REVIEW_HOLD` non-conflation, `DRY_RUN=true` preservation, no-self-approval) and records the verdict against this gating.
- **Reason / principle:** This correction pass must end with a recorded, checkable verdict rather than an implicit "probably fine" — and must not itself enter either route (`CLAUDE.md` rule #1, the standing "Do not begin Prompt 3" instruction for this pass).
- **Owner approval required?** N/A — this item defines the gates; satisfying them (Route A or B) requires owner action as described in each gate.
- **Effect on next phase:** Whoever picks up Prompt 3 checks `docs/IMPLEMENTATION_PLAN.md` §1 against the current environment state (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` A1/A2, `docs/ENVIRONMENT_AUDIT.md`) before doing anything else.

---

## Final verdict

`reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` §K records: **NOT READY FOR PROMPT 3.**

- Route A is unmet: n8n MCP is not connected and the non-production n8n instance is not confirmed (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` A1/A2, reaffirmed by `docs/ENVIRONMENT_AUDIT.md`).
- Route B is unmet and not sought: no explicit owner authorisation for an offline-design fallback has been given, and the standing instruction for this entire pass is "Do not begin Prompt 3."

This is the expected outcome of a correction-only pass. No n8n workflow was built, imported, activated, or tested; no API calls were made; `DRY_RUN=true` and `LIVE_CAMPAIGNS=empty` are unchanged throughout.

---

## Summary of file changes this pass

| File | Change |
| --- | --- |
| `docs/BUSINESS_SOURCE_REGISTER.md` | New (D1). |
| `docs/SOURCE_PRIORITY.md` | Updated (D1). |
| `CLAUDE.md` | New "Scope" section + staged five-minute objective (D2, D3). |
| `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` | Cross-references for D11/D12. |
| `docs/HMZ_APPROVED_REPLY_RULES.md` | T1/T3 (D6), T5 template (D7), `REVIEW_HOLD` + review booleans (D8), new §7.1 (D9), `follow_up_date` (D10), validation evidence + `interest_stage` (D11/D12), version bump to `policy-HMZ-1.2` (§18). |
| `docs/ARCHITECTURE.md` | Scope (D2), staged SLO (D3), `campaign_context` lookup (D4), §5 review fields (D8/D9). |
| `docs/IMPLEMENTATION_PLAN.md` | Scope (D2), Route A/B gating (D14), U1 updated (D4/D5). |
| `docs/NORMALIZED_EVENT_SCHEMA.md` | `campaign_context` object + §3.4 (D4/D5), `policy_version` bump. |
| `docs/STATE_AND_IDEMPOTENCY.md` | Review booleans (D8/D9), validation evidence + `interest_stage` columns (D11/D12). |
| `docs/REPLY_POLICY.md` | T1/T3 (D6), `REVIEW_HOLD` + review booleans (D8/D9), supersession version bump. |
| `docs/VALIDATION_CAMPAIGN_CONFIG.md` | New (D4/D5). |
| `archive/SESSION_HANDOFF_PHASE_2_SUPERSEDED.md` | Moved here from `docs/SESSION_HANDOFF_PHASE_2.md` (D13). |
| `docs/SESSION_HANDOFF_PHASE_2_CURRENT.md` | New, written after this changelog (D13). |
| `reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md` | New (D14). |
