# Autonomous Shadow Readiness — Consolidated Checklist (DISABLED STATE)

**Created:** 2026-07-07 (Fable Run 4).
**Current state, verified via production API this session:** Shadow Evaluator `aHzLtQiv6G8h1bqD`
**active = false**. **Gate 2: NOT APPROVED. Autonomous: DISABLED.** Nothing in this document
activates anything; it consolidates what must be true before the owner may start shadow review,
and after that, before the owner may even consider Gate 2.

**Config defaults (must stay this way until explicit owner sign-off):**
- Shadow Evaluator workflow: imported `active=false` (log-only design; RC-SHADOW-003 allowlist wire-up applied, versionId `ae13bf4e`).
- Gate 2 decision packet (Phase 5J): UNSIGNED.
- Allowlist worksheet (Phase 5J/5K): UNFILLED.
- No live routing sends traffic to the Shadow Evaluator; no autonomous send path exists in any active workflow.

---

## 1. Shadow-readiness checklist (before activating shadow — owner-gated)

| # | Precondition | Status 2026-07-07 |
|---|---|---|
| SR1 | Gate S1 fully green (incl. S1.5 fresh send proof, S1.7 owner UI confirm) | NOT MET (stale send evidence; UI confirm pending) |
| SR2 | Gate S2 fully green (incl. S2.6 live rollback drill — `docs/S2_ROLLBACK_LIVE_DRILL.md`) | NOT MET (live drill pending) |
| SR3 | Runtime proof checklist B1–B5 completed on current workflow versions | NOT MET |
| SR4 | Campaign Readiness Record for `531e64ed` completed + signed | NOT MET (`docs/campaign-readiness/CRR-531e64ed.md`) |
| SR5 | Shadow workflow offline tests green in CURRENT state (20/20 from 5F/5G are historical; re-run after any workflow change) | STALE — re-run required |
| SR6 | Rollback drill 6/6 re-run in current state (5G drill is stale) | NOT MET |
| SR7 | Allowlist worksheet filled and signed by owner | NOT MET |
| SR8 | Escalation channel re-proven (Google Chat webhook fires on shadow escalation) | STALE (5F historical) |
| SR9 | Owner has read the 14-day plan below and committed to daily checks | NOT MET |

Shadow activation itself is a **Gate S3** action: owner-only, in-session, explicit, and reversible
by the kill switch below.

## 2. 14-day shadow review plan

Day 1 pack already exists (Phase 5K: working file, daily checklist, step-by-step instructions,
RC-SHADOW-001/002 decision forms). The clock has **never started**.

- **Days 1–14:** every day the owner (or reviewer on `reviewer_allowlist`) completes the daily
  checklist: list all shadow-evaluated cases; for each, compare the shadow verdict vs the human
  decision; label each with one of the 17 review labels (Phase 5J SOP); log mismatches with case IDs.
- **Weekly:** fill the weekly review template (section 8) at day 7 and day 14.
- **Restart rule:** any critical shadow mismatch in days 8–14 (i.e., the final 7 days must be
  clean), any workflow deploy to Decision/HumanApproval/Sender, or any gap of >2 consecutive
  unreviewed days **restarts the 14-day clock**.

## 3. Required metrics and thresholds (from the Gate 2 packet; owner may tighten, never loosen)

| Metric | Threshold to pass |
|---|---|
| Shadow-vs-human agreement on send/no-send | ≥ 98% over the full 14 days |
| Critical mismatches (shadow would send where human blocked/suppressed) | 0 in the final 7 days |
| Shadow false-safe rate on disallowed categories (section 5) | 0 — a single occurrence fails the review |
| Escalation delivery (Google Chat) | 100% of escalation-class cases produce a chat message |
| Coverage | ≥ 90% of eligible live cases shadow-evaluated (gaps logged) |
| Daily review completion | ≥ 12 of 14 days, no 2-day gap |

## 4. Safe categories (the ONLY candidates for any future autonomous scope)

Candidates only — the signed allowlist worksheet decides. Nothing here is auto-approved:
- `NON_PRIORITY` / `NOT_NOW` acknowledgement-only check-back replies (deterministic template lineage).
- OOO/auto-reply NOOP handling (no reply needed — already deterministic).
- Simple thank-you/close-loop acknowledgements with no substantive content.

## 5. Disallowed categories (NEVER autonomous, regardless of shadow results)

Unsubscribe/opt-out/complaint; legal/privacy; hostile/reputational; pricing/negotiation;
booking/meeting commitments; proof/case-study requests; anything requiring business facts beyond
`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`; ambiguous/low-confidence classifications; any reply to a
thread with prior SEND_UNCERTAIN or duplicate-suspect state; any non-HMZ campaign.

## 6. Escalation rules

- Any shadow-evaluated case in a disallowed category, any classifier/shadow disagreement on a
  suppress/stop decision, and any shadow evaluator error → Google Chat escalation
  (`GOOGLE_CHAT_WEBHOOK_URL`) + case remains fully human-reviewed (shadow is log-only; it can never
  hold, alter, or send anything).
- Escalations are reviewed same-day; unresolved escalations pause the 14-day clock.

## 7. Rollback plan and kill switch

- **Kill switch (one step):** deactivate workflow `aHzLtQiv6G8h1bqD` (n8n UI toggle or
  `POST /api/v1/workflows/aHzLtQiv6G8h1bqD/deactivate`). Shadow is log-only, so deactivation has
  zero effect on the live supervised responder.
- **Rollback drill:** re-run the 5G 6/6 drill in current state before activation (SR6); drill the
  kill switch once during week 1 of the review (deactivate, confirm no evaluation on next case,
  reactivate, log it).
- **Learning-rule rollback** stays independent: `docs/S2_ROLLBACK_LIVE_DRILL.md`.

## 8. Evidence capture + weekly review templates

**Per-case evidence row (daily file):**
`date | case_id | live classification (baseline/effective) | human decision | shadow verdict | agree? | label (1-17) | critical? | escalated? | notes`

**Weekly review template:**
- Week #, date range, cases evaluated / eligible (coverage %)
- Agreement % (send/no-send), mismatch list w/ case IDs, critical mismatch count
- Disallowed-category hits and how shadow handled them
- Escalations fired / delivered / resolved
- Clock status (running / restarted — why)
- Reviewer signature + date

## 9. Gate 2 approval checklist — **STATUS: NOT APPROVED**

Gate 2 remains **UNAPPROVED**. All of the following must be individually true and evidenced before
the owner may sign the Gate 2 decision packet (Phase 5J). Signing is a human act; no agent may do it.

| # | Item | Status |
|---|---|---|
| G2.1 | Full 14-day shadow review complete, metrics in section 3 met | NOT MET (never started) |
| G2.2 | All seven Phase 5J blockers individually closed | NOT MET |
| G2.3 | Allowlist worksheet signed (categories, volume cap, out-of-hours window) | NOT MET |
| G2.4 | Kill switch drilled during shadow period | NOT MET |
| G2.5 | Duplicate-replay idempotency re-proven live (RUNTIME_PROOF_CHECKLIST B5) | NOT MET |
| G2.6 | S4 gates in `docs/SCALE_READY_ACCEPTANCE_GATES.md` green | NOT MET |
| G2.7 | Owner signature on the Gate 2 decision packet | **NOT SIGNED** |

**Standing rule for agents:** do not activate Shadow, do not approve Gate 2, do not enable any
autonomous path, and do not route live traffic to the Shadow Evaluator. Preparation work (docs,
offline tests, disabled-state config) is the only permitted autonomous-layer work without explicit
current-session owner instruction.
