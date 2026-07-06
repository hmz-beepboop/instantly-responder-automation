# Scale-Ready Acceptance Gates

**Created:** 2026-07-06 (SL-PHASE-5Q session 15)
**Rule:** A gate passes only on recorded evidence (execution IDs, case IDs, versionIds, harness output, owner sign-off in writing). Nothing passes on "should work". Gates are strictly ordered — a later gate cannot open while an earlier one is failed. Autonomous remains **NOT APPROVED** regardless of this document until Gate 2 owner sign-off exists.

Companion fault inventory: `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`.

---

## Gate S1 — Supervised live use (current target)

Purpose: the responder may keep operating in VALIDATION mode with human-approved sends on the single allowlisted campaign.

| # | Criterion | Evidence required | Status 2026-07-06 |
|---|---|---|---|
| S1.1 | Harness fully green | 375/375 PASS on current exports | PASS |
| S1.2 | Local exports match production versionIds | Decision `4474c96a`, HumanApproval `0054f20b` | PASS |
| S1.3 | No diagnostic-fallback false positives on valid cases | P13/P14 + owner live confirmation of form render | PASS (harness) / owner re-confirm pending |
| S1.4 | Proof/trust cases produce a non-empty draft or a truthful, specific fallback banner | Fresh live trust reply post-session-15 | **PENDING — next owner action** |
| S1.5 | Manual send path verified (thread, sender, body) | Last proven 2026-06-23 (cases c0dd8298/7434572c/c9b32e56); re-confirm on next approved send | PARTIAL (stale evidence) |
| S1.6 | Safety envelope intact | Sender untouched, no Instantly POST from Decision/HumanApproval, DRY_RUN discipline, suppression categories hard-stop | PASS |

## Gate S2 — Self-improving live use

Purpose: owner corrections and draft-learning rules may keep feeding live behaviour.

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S2.1 | Classification learning proven live | Rule `1dba7933` trace (cases d24661f0/3838bcee) | PASS |
| S2.2 | Draft-style learning proven live end-to-end | Fresh two-email test after sessions 14-15: correction → next variant consumes rule with visible draft effect | **PENDING** |
| S2.3 | Attribution conservative and truthful | P9; multi-rule → attribution_uncertain | PASS |
| S2.4 | Learning never bypasses safety | Learning skipped for UNSUBSCRIBE/LEGAL/COMPLAINT; classification correction alone cannot enable AI drafting | PASS (harness) |
| S2.5 | Rule store hygiene | Q12 filters status=active; superseded/shadow rules excluded (S7/S8) | PASS |
| S2.6 | Bad-rule rollback path documented and drilled once | Owner deactivates a rule in Q12 and next case ignores it | **PENDING** |

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
- **Gate S2:** one live behavioural proof (S2.2) and one drill (S2.6) from green.
- **Gates S3-S5:** not met, by design. No autonomous activation, no Gate 2 approval, no multi-campaign work is authorised by this document.
