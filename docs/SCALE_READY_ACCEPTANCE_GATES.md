# Scale-Ready Acceptance Gates

**Created:** 2026-07-06 (SL-PHASE-5Q session 15)
**Rule:** A gate passes only on recorded evidence (execution IDs, case IDs, versionIds, harness output, owner sign-off in writing). Nothing passes on "should work". Gates are strictly ordered — a later gate cannot open while an earlier one is failed. Autonomous remains **NOT APPROVED** regardless of this document until Gate 2 owner sign-off exists.

Companion fault inventory: `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`.

---

## Gate S1 — Supervised live use (current target)

Purpose: the responder may keep operating in VALIDATION mode with human-approved sends on the single allowlisted campaign.

| # | Criterion | Evidence required | Status 2026-07-07 |
|---|---|---|---|
| S1.1 | Harness fully green | 425/425 PASS on current exports (session 16) | PASS |
| S1.2 | Local exports match production versionIds | Decision `84b941a4`, HumanApproval `0054f20b` | PASS |
| S1.3 | No diagnostic-fallback false positives on valid cases | P13/P14 + owner live confirmation of form render | PASS (harness) / owner re-confirm pending |
| S1.4 | Proof/trust cases produce a non-empty draft or a truthful, specific fallback banner | Fresh live trust reply post-session-15 | **PENDING — next owner action** |
| S1.5 | Manual send path verified (thread, sender, body) | Last proven 2026-06-23 (cases c0dd8298/7434572c/c9b32e56); re-confirm on next approved send | PARTIAL (stale evidence) |
| S1.6 | Safety envelope intact | Sender untouched, no Instantly POST from Decision/HumanApproval, DRY_RUN discipline, suppression categories hard-stop | PASS |

## Gate S2 — Self-improving live use

Purpose: owner corrections and draft-learning rules may keep feeding live behaviour.

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S2.1 | Classification learning proven live | Rule `1dba7933` trace (cases d24661f0/3838bcee); rule `6e50fd54` live trace (case-64589b37, session 16) | PASS |
| S2.2 | Draft-style learning proven live end-to-end | **Live-proven session 16:** case-64589b37 — rules 877c3d75/cdada69d consumed with visible draft delta (post_processor_delta); case-269eed7f — rule ea15095a injected into a real AI-supervised draft (ai_prompt_injection, applied=1). Post-S2-upgrade-engine retest (not-now → AI draft) still pending | PASS (pre-upgrade-engine) / retest pending |
| S2.3 | Attribution conservative and truthful | P9 + P20.35-37; multi-rule → attribution_uncertain; injection summary now non-empty and truthful; fallback never labelled AI (P20.34/44) | PASS |
| S2.4 | Learning never bypasses safety | Learning skipped for UNSUBSCRIBE/LEGAL/COMPLAINT; classification correction alone cannot enable AI drafting (P20.19); upgrade engine never fires for high-risk/suppress/no-reply/pricing (P20.20-27) | PASS (harness) |
| S2.5 | Rule store hygiene | Q12 filters status=active; superseded/shadow rules excluded (S7/S8); PROOF_REQUEST promotion now content-gated (P20.9-12) | PASS |
| S2.6 | Bad-rule rollback path documented and drilled once | Procedure documented (closure report session 16); offline drill P20.38-40 PASS (deactivated rule excluded; newer wins; deactivated not selected). Live drill (owner flips one rule status + probe email) | PARTIAL — offline drilled, live drill pending |
| S2.7 | Deterministic/human-to-AI upgrade truthful and auditable (added session 16) | S2 upgrade engine deployed (`84b941a4`); `ai_upgrade_eligible`/`ai_upgrade_reason`/`ai_upgrade_blocked_reason`/`effective_classification_used_for_draft_policy` recorded per case; P20.15-27 | PASS (harness) / live retest pending |

## Gate S3 — Autonomous shadow mode (Gate 2 precondition)

Purpose: Shadow Evaluator may be activated to log-only evaluate live traffic. **No approval exists as of 2026-07-06.**

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S3.1 | Gates S1 + S2 fully green | All PENDING items above closed | NOT MET |
| S3.2 | Shadow workflow validated offline | 20/20 shadow webhook tests (5F/5G) | PASS (historical) |
| S3.3 | Allowlist worksheet completed and signed by owner | Filled worksheet from Phase 5J/5K | NOT MET |
| S3.4 | 14-day shadow review plan started | Day 1 checklist executed with real traffic | NOT MET (never started) |
| S3.5 | Escalation channel proven | Google Chat webhook fires on shadow escalation case | PASS (historical, 5F) |
| S3.6 | Rollback drill re-run in current state | 6/6 drill repeated after any workflow change since 5G | NOT MET (stale) |

## Gate S4 — Autonomous out-of-hours live pilot (Gate 2 itself)

Purpose: system may send a narrow class of replies without per-message human approval, out-of-hours only. **UNAPPROVED. Owner-only decision.**

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S4.1 | Gate S3 complete including full 14-day shadow review | Daily checklists + summary metrics + zero critical shadow mismatches in final 7 days | NOT MET |
| S4.2 | Owner signs Gate 2 decision packet | Signed packet (Phase 5J) with allowlist, category whitelist, volume cap | NOT MET |
| S4.3 | Shadow-vs-human agreement threshold met | Agreement metric from the 14-day review at/above the packet's threshold | NOT MET |
| S4.4 | Kill-switch verified | Documented one-step disable, drilled during S3 | NOT MET |
| S4.5 | Idempotency re-proven under replay | Duplicate-webhook replay test: exactly one send | NOT MET |
| S4.6 | All seven Phase 5J blockers individually closed | Blocker list from Gate 2 packet | NOT MET |

## Gate S5 — Multi-campaign / multi-sender scale

Purpose: responder handles >1 campaign and/or >1 sender identity. **Out of current project scope per CLAUDE.md until separately approved.**

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S5.1 | Gates S1-S2 green; S3-S4 green if autonomous is included in scale plan | — | NOT MET |
| S5.2 | Per-campaign config isolation | Campaign-scoped rules/templates proven not to leak across campaigns (harness + live) | NOT MET |
| S5.3 | Sender identity routing proven | Reply always sent from the mailbox that received the inbound | NOT MET |
| S5.4 | Volume SLO evidence | Processing SLO (≤300s conclude) held at target volume in a load test | NOT MET |
| S5.5 | Rate-limit and retry behaviour verified against Instantly API limits | Documented test against current official Instantly docs | NOT MET |
| S5.6 | Client-delivery preconditions (if any campaign is not HMZ's own) | Per CLAUDE.md scope section: approved client KB, reply policy, compliance review, controlled testing — none exists | NOT MET |

---

## Current honest position

- **Gate S1:** effectively open for continued supervised validation use, with two re-confirmations pending (S1.4 fresh trust-case retest, S1.5 stale send evidence).
- **Gate S2 (updated 2026-07-07, session 16):** substantially closed on evidence. Classification learning, draft-style learning consumption (both post-processor delta and AI prompt injection), conservative attribution, safety non-bypass, rule hygiene, and the new auditable deterministic/human→AI upgrade engine are all proven by live rows + 425/425 harness. Remaining before fully green: (a) one owner live retest of the three fixed behaviours (not-now → AI draft; setup question stays OFFER_EXPLANATION; trust → AI draft with non-empty summary); (b) one live rollback drill (flip a rule status, send a probe).
- **Gates S3-S5:** not met, by design. No autonomous activation, no Gate 2 approval, no multi-campaign work is authorised by this document.
