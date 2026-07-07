# Scale-Ready Acceptance Gates

**Created:** 2026-07-06 (SL-PHASE-5Q session 15)
**Rule:** A gate passes only on recorded evidence (execution IDs, case IDs, versionIds, harness output, owner sign-off in writing). Nothing passes on "should work". Gates are strictly ordered — a later gate cannot open while an earlier one is failed. Autonomous remains **NOT APPROVED** regardless of this document until Gate 2 owner sign-off exists.

Companion fault inventory: `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`.

---

## Gate S1 — Supervised live use (current target)

Purpose: the responder may keep operating in VALIDATION mode with human-approved sends on the single allowlisted campaign.

| # | Criterion | Evidence required | Status 2026-07-07 (Run 3) |
|---|---|---|---|
| S1.1 | Harness fully green | 463/463 PASS on current exports (Run 3, P21 added) | PASS |
| S1.2 | Local exports match production versionIds | Decision `84b941a4`, HumanApproval `99b4c092`, Sender `dfb310f4` (export captured Run 3) | PASS |
| S1.3 | No diagnostic-fallback false positives on valid cases | P13/P14 + owner live confirmation of form render | PASS (harness) / owner re-confirm pending |
| S1.4 | Proof/trust cases produce a non-empty draft or a truthful, specific fallback banner | **Live-proven Run 3:** case-58e6b3b0 (trust reply → PROOF_REQUEST, real AI draft, ai_attempt.ok=true, style rule ea15095a injected, no fallback) | PASS |
| S1.5 | Manual send path verified (thread, sender, body) | Last proven 2026-06-23 (cases c0dd8298/7434572c/c9b32e56); Run 3 code audit confirms gates/verification logic intact; re-confirm on next approved send | PARTIAL (stale live evidence; code-audited) |
| S1.6 | Safety envelope intact | Sender untouched, no Instantly POST from Decision/HumanApproval, DRY_RUN discipline, suppression categories hard-stop | PASS |
| S1.7 | Operator-facing truthfulness: review form + chat show Original vs Effective classification, reply mode, AI draft status (Run 3 UI fix) | HumanApproval `99b4c092`; offline render proof vs real case-4a5596a0 row; P21.10-21; owner live confirm on next case | PASS (offline) / owner confirm pending |

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

## Gate S-SEND — Sender / send-path / idempotency (Run 3 read-only audit)

Purpose: the send path is safe before any volume increase. Audited 2026-07-07 against fresh production export `dfb310f4` (`workflows/production_sender_current.json`). Sender was NOT modified and NOT triggered.

| # | Criterion | Run 3 finding | Status |
|---|---|---|---|
| SS.1 | Same sender as inbound; no silent fallback sender | `nes.eaccount` + connected-sender allowlist gate + post-send `body.eaccount` verification (mismatch → SEND_UNCERTAIN) | CODE-PROVEN |
| SS.2 | Recipient is the original lead; no unexpected cc/bcc | `nes.lead_email` expected-recipient check; non-empty cc/bcc rejects sent-object validation | CODE-PROVEN |
| SS.3 | Thread + subject preserved | `reply_to_uuid` required by gate; `Re:` subject preserved and verified post-send | CODE-PROVEN |
| SS.4 | Body cannot be blank | **CLOSED IN SENDER (Fable Run 4, 2026-07-07):** HumanApproval Node N (`draft_text_required`) upstream + Sender now independently blocks — node B `draft_body_gate_passed` BEFORE lock acquisition and node O 15th gate `draft_body_non_empty` immediately BEFORE the POST (missing/blank/whitespace/marker-only all rejected after normalization; Node.js behavioural proof 77/77; harness P22). Sender `dfb310f4 → 00b52f03` | CODE-PROVEN (dual-layer) |
| SS.5 | Send marker | `hmz-send-key` HTML comment embedded in body | CODE-PROVEN |
| SS.6 | Duplicate prevention / concurrent lock / sequential rerun | Atomic acquire (hmz-send-state) + `no_prior_terminal_send_state` gate + blocked-duplicate terminal | CODE-PROVEN; live replay drill NOT run |
| SS.7 | SEND_UNCERTAIN never blindly retried | Terminal state; reconciliation poll needs 2 consecutive single matches; zero/multiple → human review | CODE-PROVEN; no live occurrence |
| SS.8 | HTTP error handling | 400→PERMANENT_FAILURE; 401/402/403→AUTH_OR_PLAN_FAILURE; 404→INVALID_REPLY_TARGET; 429/5xx→retry max 3, retry-after cap 5s | CODE-PROVEN |
| SS.9 | Blocked approvals keep same review link + exact reason | HumanApproval Node N blocked path (P10/P14) | PROVEN |
| SS.10 | Reopened-case repeat send stays manual | FOLLOWUP_SEND_PENDING_MANUAL (5P) | PROVEN |

Live re-proof requirements live in `docs/RUNTIME_PROOF_CHECKLIST.md` section B.

## Gate S5 — Multi-campaign / multi-sender scale

Purpose: responder handles >1 campaign and/or >1 sender identity. **Out of current project scope per CLAUDE.md until separately approved.**

| # | Criterion | Evidence required | Status |
|---|---|---|---|
| S5.1 | Gates S1-S2 green; S3-S4 green if autonomous is included in scale plan | — | NOT MET |
| S5.2 | Per-campaign config isolation | Campaign-scoped rules/templates proven not to leak across campaigns (harness + live) | NOT MET |
| S5.3 | Sender identity routing proven | Reply always sent from the mailbox that received the inbound | CODE-PROVEN (Run 3); live NOT MET |
| S5.4 | Volume SLO evidence | Processing SLO (≤300s conclude) held at target volume in a load test | NOT MET |
| S5.5 | Rate-limit and retry behaviour verified against Instantly API limits | Documented test against current official Instantly docs | NOT MET |
| S5.6 | Client-delivery preconditions (if any campaign is not HMZ's own) | Per CLAUDE.md scope section: approved client KB, reply policy, compliance review, controlled testing — none exists | NOT MET |
| S5.7 | Campaign Readiness Record per campaign (added Run 3) | Completed, owner-signed record in `docs/campaign-readiness/`; missing/incomplete CRR blocks launch | BACKFILLED for `531e64ed` (Run 4, `docs/campaign-readiness/CRR-531e64ed.md`) — **INCOMPLETE/UNSIGNED, launch blocked**; campaign-ID reconciliation (`bcda01f7` stale) documented |
| S5.8 | Credential-leak scan of workflow exports | `python scripts/scan-workflow-exports-for-secrets.py` exit 0 | PASS (2026-07-07) — rerun each session that touches exports |
| S5.9 | Stale-script / stale-harness guard | Runtime proof checklist is the runtime source of truth; old controlled-live acceptance harness never sole evidence; forbidden `run-local-*` scripts unused | DOCUMENTED (CRR rows 10/16) |

---

## Current honest position (updated 2026-07-07, Fable Run 4)

- **Gate S1:** open for continued supervised validation use. S1.4 live-proven (Run 3). Pending: owner confirms the Run 3 UI (S1.7) on the next live case; S1.5 send evidence remains stale until the next approved send — and must now be proven against Sender `00b52f03` (Run 4 change invalidates carrying forward older Sender-version evidence).
- **Gate S2:** closed on live evidence (Run 3). Remaining: one live rollback drill (S2.6) — owner runbook now exists: `docs/S2_ROLLBACK_LIVE_DRILL.md`.
- **Gate S-SEND:** code-proven end-to-end. **SS.4 blank-body gap closed in Sender itself (Run 4, dual-layer, harness P22 + 77/77 Node.js behavioural proof).** Live replay (B5) and reconciliation (B6) drills still outstanding — required before any volume increase. UI confirmation cases from the Run 3 review (case-e97b60ea / case-ea98043d) closed that pending item.
- **Gates S3-S4:** not met, by design. Autonomous shadow readiness is now consolidated in `docs/AUTONOMOUS_SHADOW_READINESS.md` (all disabled-state; Shadow inactive API-confirmed 2026-07-07; Gate 2 checklist explicitly NOT APPROVED).
- **Gate S5:** not met. CRR for `531e64ed` backfilled but incomplete/unsigned (`docs/campaign-readiness/`); launch blocked until owner completes + signs and rows 10-14 are re-proven live.
- **Ops Console:** Stage 1 built (Run 4, `ops/responder-ops-console.html`) — local-only, no API, no controls, no autonomous-ready status. It changes no gate status; it is an operator aid only.
