# OPERATION_HANDOFF.md

**Purpose:** Single checked-in source of truth for Claude Code, Codex, ChatGPT, and the human operator.

**Rules:**
- Read this file before any coding-agent session.
- Update this file before ending every coding-agent session, even if the task failed.
- Keep `CURRENT_STATE` short and accurate.
- Append session logs under `SESSION_LOG`, newest first.
- Do not store secrets, API keys, tokens, passwords, private credentials, or unrelated chat history.
- If this file grows too large, archive older logs to `docs/agent-history/YYYY-MM.md`.

---

## CURRENT_STATE

**Last updated:** 2026-07-01T03:00:30Z
**Updated by:** Codex
**Current branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`

**Project status:**
The supervised responder remains human-approved only. Classification self-improvement is verified. SL-PHASE-5Q production apply and live candidate activation worked, but later live proof (`case-a3e7b1d2`) showed insufficient behavioural draft effect and duplicate-submit retry/token defects after a successful owner-approved send. SL-PHASE-5Q2/5R-prep, 5Q3, 5Q4, 5Q5, 5Q6, 5Q7, 5Q8, 5Q9, 5Q10, 5Q11, **5Q12**, 5Q14B, 5Q14D, **5Q14F**, **5Q15**, **5Q16B**, **5Q16D**, **5Q16F**, **5Q17B**, **5Q17C**, **5Q17D**, **5Q18**, and **5Q19** are complete/proven at their intended scope. **5Q19 audit completed (2026-07-01)**: four fresh seeded-thread review cases (`case-d8368748`, `case-78e677c0`, `case-86a17778`, `case-39352371`) were valid, non-diagnostic, and form-learning-saved (`LEARNING_REVISION_APPROVED`). Active HumanApproval form-created rules now exist for booking (`97eb3b0a-4dac-49e4-92e0-408eaf75b762`, source `case-d8368748`, `INFORMATION_REQUEST / BOOKING_REQUEST`), pricing (`493884ad-7d88-4e25-8744-e73e36f48322`, source `case-78e677c0`, `PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST`), setup/process (`48e10cac-69a0-4ec7-9c35-42d3675812e6`, source `case-86a17778`, `INFORMATION_REQUEST / OFFER_EXPLANATION`), and not-now/later (`6e50fd54-ff2a-4d5a-b220-c0c7374edea4` classification to `AMBIGUOUS / NON_PRIORITY` plus style rule `cdada69d-63a0-471d-801b-3cf3d7ddd1bd`, source `case-39352371`). The old weak booking rule `c9860e74-ff23-477e-87f1-812bec8023e5` was still applied to `case-d8368748` at case creation, but the better override rule was subsequently registered through the review form. No code patch or n8n write was needed in 5Q19. Anti-hardcoding check passed: the new instructions are not present in Decision/HumanApproval workflow JSON. Latest Sender execution remained `3193`; no Sender/Instantly send was triggered. Production versions remain Decision `889e1d45-7103-4b0a-a85d-685d19a2cadd` and HumanApproval `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`. Status remains `95`; do not move above `95` yet. Autonomous shadow layer remains built but inactive; Gate 2 is not approved and live autonomous sending remains 0%.

**Latest verified working state:**
- HumanApproval versionId: `0fa9d0ce-585e-495e-8af6-dbdb4957ab78` (SL-PHASE-5Q17D layer-specific diagnostics and upstream evidence preservation, 2026-07-01)
- Intake versionId: `abc83e43-9b97-4ca1-ae32-c42599255328` (SL-PHASE-5Q6 alternate thread mapping, 2026-06-28)
- Decision versionId: `889e1d45-7103-4b0a-a85d-685d19a2cadd` (SL-PHASE-5Q18 blocks booking classification-learning promotion unless reply text contains booking/calendar intent, 2026-07-01)
- Sender versionId: `dfb310f4-901a-4d76-81dc-8f5d4ad13552` — unchanged by 5Q2
- Proxy versionId: `d61050e6-dbc6-4fec-b404-3aad20a80e84` — unchanged by 5Q2
- Shadow Evaluator versionId: `ae13bf4e-ee04-438f-9657-3c57183b90a2` — `active=false`
- Harness: 5Q18 Python/PowerShell `20/20 PASS`; 5Q17D Python `28/28 PASS`; 5Q17C Python `24/24 PASS`; 5Q17B Python/PowerShell `23/23 PASS`; 5Q16F Python `22/22 PASS`; 5Q16D Python `32/32 PASS`; 5Q16B Python/PowerShell `30/30 PASS`; 5Q15 Python/PowerShell `35/35 PASS`; 5Q14F Python/PowerShell `22/22 PASS`; 5Q14D Python/PowerShell `21/21 PASS`; 5Q14B Python/PowerShell `20/20 PASS`; 5Q12 Python/PowerShell `29/29 PASS`; 5Q11 Python `24/24 PASS`; 5Q10 Python/PowerShell `22/22 PASS`; 5Q9 Python/PowerShell `21/21 PASS`; 5Q8 Python/PowerShell `22/22 PASS`; 5R-prep Python/PowerShell `17/17 PASS`; 5Q7 Python `17/17 PASS`; 5Q5 Python `34/34 PASS`; 5Q6 Python/PowerShell `24/24 PASS`; 5Q4 Python/PowerShell `26/26 PASS`; 5Q3 Python/PowerShell `30/30 PASS`; 5Q Python/PowerShell `41/41 PASS`; 5Q2 Python/PowerShell `27/27 PASS`
- Classification self-improvement: VERIFIED, `self_improvement_full_loop_proven=TRUE`

**Known failing checks / unproven behaviours:**
- Post-5Q11 review-link accessibility proof: **PATCHED / OWNER LIVE CONFIRMATION PENDING** — `case-6ebd0e3a` is in `FOLLOWUP_SEND_PENDING_MANUAL` with controlled send key `case-6ebd0e3a|f2`; HumanApproval now includes follow-up/manual-send states in renderable same-link statuses and preserves manual-send-required banners. Owner must reopen the same link once and stop before submit.
- Post-5Q8 HumanApproval render proof: **PATCHED / SUPERSEDED BY 5Q9 SAME-LINK REOPEN PENDING** — `case-c3341a17` accepted AI draft and Chat labels worked, but render failed before the 5Q8 fix; 5Q8 fixed node `J`
- Draft behavioural self-improvement: **PATCHED / HARNESS-PROVEN / LIVE SOURCE REGISTRATION VERIFIED / LEAKAGE PATCHED / DETERMINISTIC-TEMPLATE BYPASS FIXED / DIAGNOSTIC-LINK FIXED / RENDER-CRASH FIXED / ATTRIBUTION GATE PRODUCTION-APPLIED / IMPACT TRUTHFULNESS GATE PRODUCTION-APPLIED / MULTI-CASE COVERAGE PRODUCTION-APPLIED** — 5Q12 proves HumanApproval form-created active rules dynamically affect matching AI and fallback drafts; 5Q14B proves deterministic/fixed template, AI, commercial, and fallback paths consume matching active form-created rules synthetically; 5Q14D fixes diagnostic links and the `INFORMATION_REQUEST / BOOKING_REQUEST` empty-draft path; 5Q14F fixes HumanApproval render crash and narrows classifier coverage for `grab a time on your calendar`; 5Q16B removed source-gated hardcoded deterministic booking wording; 5Q16D adds explicit owner-facing applied-rule attribution; 5Q16F makes applied learning truthful by requiring actual output/classification deltas and displaying impact summaries. 5Q18 proves multi-case live coverage and patches booking-rule leakage into setup/process explanations. The old booking rule wording remains weak because it came from the HumanApproval rule instruction itself.
- Review form Save/reopen preservation: **HUMAN-REPORTED PASS / N8N-EVIDENCE PASS FOR REQUESTED FIELDS** — `case-535d430a` execution `2862` showed saved draft, combined instruction, revision types, scopes, and target classifications persisted; owner must still avoid approve/send until post-5Q6 thread/draft proof passes
- Duplicate/retry after approved send: **PATCHED / LIVE RETEST PENDING** — duplicate ownership and prior terminal states no longer issue retry tokens; no duplicate live send test was run
- Invalid blank/UNKNOWN/context-missing review case handling: **PATCHED / HARNESS-PROVEN / SEEDED-CONTEXT DROP, DIAGNOSTIC CASE-ID COLLISION, AND DECISION PARSE ERROR REPAIRED** — repeated `case-ed174cd6` traced to Decision D returning error-only `missing /` after valid Intake context, then HumanApproval hashing fallback `UNKNOWN_INTAKE|policy-HMZ-1.2` into the same diagnostic case ID. 5Q17C added a whole-item Decision D exception fallback and unique HumanApproval diagnostic fallback identity. 5Q17D proved `case-2c7e1ff0` was post-5Q17C and fixed the parse-time malformed regex that prevented the fallback from running; diagnostics are now layer-specific and preserve upstream evidence. Production keeps diagnostic rows readable until token expiry and blocks all approve/send/learning actions.
- Review reopen manual tests 2/3/4: PENDING owner action
- `approve_and_send_followup` auto-send path: still BLOCKED; metadata capture only, no auto-send

**Do not redo:**
- SL-PHASE-5P, 5O, 5N, 5M, 5L — all nodes preserved through HumanApproval versionId `07895ef4`
- Phase 4A–Stage 8 self-improvement verification — complete
- Gate 1 — executed 2026-06-24
- Do not re-run live send on `case-a3e7b1d2`; treat the confirmed edited email as sent

**Highest-risk areas:**
- Decision node D (active rule injection — do not re-apply old rule sets)
- HumanApproval token validation nodes H+L (reopen logic is stateful)
- Shadow Evaluator — must remain `active=false`; do not activate without Gate 2 owner sign-off

**Next recommended owner:** Human
**Why:** 5Q19 confirms better HumanApproval form-created rules are now registered for booking, pricing, setup/process, and not-now/later. Owner should retest those four inbound categories with fresh seeded-thread replies and inspect the Google Chat/review pages only. Do not approve/send during that proof.

---

## ACTIVE_TASKS

| ID | Status | Owner | Description | Branch | Notes |
|---|---|---|---|---|---|
| TASK-001 | review_needed | human | Manual tests 2/3/4 — review reopen, approve_learning_only, repeat-send | `main` | Use updated post-fix caution; do not live-send first |
| TASK-002 | review_needed | human | Post-5Q8 HumanApproval render proof — reopen `case-c3341a17` while authenticated, inspect source/banner/draft behaviour, then stop before Save/learning-only/send | `agent/codex/phase-5q8-humanapproval-render-regression/20260628-050738` | Use the updated one-action packet; ignore `case-ed174cd6`; see `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md` |
| TASK-007 | review_needed | human | Post-5Q9 blocked-send same-link proof — reopen existing `case-9b9197a4` review link while authenticated and confirm the form is editable | `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341` | Stop before Save, learning-only, approve/send, deny, or follow-up |
| TASK-003 | done | Codex | SL-PHASE-5Q production apply — guarded export/backup/compare/apply/versionId confirmation completed for HumanApproval and Decision | `agent/codex/phase-5q/20260627-025313` | PARTIAL overall because live owner proof remains pending; backup `backups/sl-phase-5q-production-apply-20260627T044425Z` |
| TASK-004 | in_progress | Codex/Human | SL-PHASE-5R-prep — duplicate submit/token safety production patch installed; full approve_and_send_followup auto-send audit remains blocked | `agent/codex/phase-5q2-idempotency-behavioural-fix-20260627-224147` | HumanApproval duplicate retry fixed; Sender unchanged; no auto-send enabled |
| TASK-005 | planned | human | Gate 2 autonomous pilot — 14-day shadow review + allowlist decisions + sign-off | `main` | Min date ~2026-07-08; see `docs/PHASE_5J_GATE_2_READINESS_SUMMARY.md` |
| TASK-006 | planned | human | GitHub pre-push secret scan — review 3 flagged files before first push | `main` | See SECRET_OR_RISKY_FILES below |

Status values: `planned`, `in_progress`, `blocked`, `review_needed`, `done`, `abandoned`.

---

## AGENT_WORKFLOW

| Agent | Responsibilities |
|---|---|
| Claude Code | Repo edits, workflow JSON patches, script/doc changes, local harness verification |
| Codex | Code review, independent diff audit, test suggestions, refactor review |
| ChatGPT | Prompt strategy, output audit, risk review, manual procedure design |
| Human | Production approvals, credentials, live sends, business decisions, Gate 2 approval |

**Every agent must:**
1. Read this file first.
2. Read `CLAUDE.md` and `docs/HMZ_PRODUCTION_TARGET_GUARD.md`.
3. Run `scripts/assert-hmz-production-target.ps1` before any n8n operation.
4. State files changed, tests run, risks, and next owner.
5. Update this file before ending the session.

**Branch naming:** `agent/claude/<task>/<timestamp>` or `agent/codex/<task>/<timestamp>`

---

## SECRET_OR_RISKY_FILES

Files flagged by lightweight name-pattern scan (2026-06-27). Do not print their contents. Review before pushing:

| File | Pattern | Action |
|---|---|---|
| `reports/LOCAL_RUNTIME_CREDENTI…` (truncated name) | "credential" in filename | Check contents; remove or confirm gitignored before push |
| `scripts/SL-PHASE-4I-token-refr…` (truncated name) | "token" in filename | Check for hardcoded tokens; confirm no live secrets |
| `patch_sender_token_resolution.ps1` | "token" in filename | Check for hardcoded tokens; confirm no live secrets |

`outputs/` and `backups/` are gitignored. `.env` and credential file extensions are gitignored. Verify `.gitignore` is respected with `git status` before any push.

---

## SESSION_LOG

### 2026-07-01T03:00:30Z — Codex — SL-PHASE-5Q19 human-learning-rule registration audit

**Agent:** Codex  
**Objective:** Audit four fresh seeded-thread cases, confirm valid review creation and learning attribution, determine whether better HumanApproval form-created rules exist, and prepare exact retest actions without code or backend rule insertion.

**Verdict:** COMPLETE. No workflow defect found; no patch applied. Status remains `95`.

**Live trace evidence:**
- `case-d8368748`: valid/non-diagnostic booking case, `INFORMATION_REQUEST / BOOKING_REQUEST`, draft still used old weak rule `c9860e74-ff23-477e-87f1-812bec8023e5` at creation. Review row status later became `LEARNING_REVISION_APPROVED`.
- `case-78e677c0`: valid/non-diagnostic pricing/minimum commitment case, `PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST`; old booking rule found but not eligible/applied.
- `case-86a17778`: valid/non-diagnostic setup/process case, `INFORMATION_REQUEST / OFFER_EXPLANATION`; old booking rule found but not eligible/applied, confirming the 5Q18 leakage fix held.
- `case-39352371`: valid/non-diagnostic not-now/later case, baseline `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY`; old booking rule found but not eligible/applied.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`); no Sender/Instantly POST was triggered.

**Active rules verified in rule table:**
- Booking style override: `97eb3b0a-4dac-49e4-92e0-408eaf75b762`, source `case-d8368748`, active, `INFORMATION_REQUEST / BOOKING_REQUEST`, `humanapproval_form_created_learning`.
- Pricing style rule: `493884ad-7d88-4e25-8744-e73e36f48322`, source `case-78e677c0`, active, `PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST`.
- Setup/process style rule: `48e10cac-69a0-4ec7-9c35-42d3675812e6`, source `case-86a17778`, active, `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Not-now/later classification rule: `6e50fd54-ff2a-4d5a-b220-c0c7374edea4`, source `case-39352371`, active, changes `AMBIGUOUS_SHORT_REPLY` to `NON_PRIORITY`.
- Not-now/later style rule: `cdada69d-63a0-471d-801b-3cf3d7ddd1bd`, source `case-39352371`, active, `AMBIGUOUS / NON_PRIORITY`.

**Anti-hardcoding guard:**
- Verified the new human instructions do not appear in `workflows/production_decision_current.json` or `workflows/production_humanapproval_current.json`.
- No code patch, no database/backend rule insertion, no production n8n write, no harness run.

**Files changed:**
- `OPERATION_HANDOFF.md`

**Next owner action:** Retest four fresh seeded-thread replies: booking/calendar request, pricing/minimum commitment, setup/process explanation, and not-now/later. Inspect Google Chat/review pages only; do not approve/send.

### 2026-07-01T00:03:58Z — Codex — SL-PHASE-5Q18 multi-classification self-learning coverage

**Agent:** Codex  
**Objective:** Verify four fresh seeded campaign-thread review cases for ingestion stability, classification coverage, learning attribution truthfulness, booking-rule leakage, duplicate same-rule metadata, and no-send safety. Patch only if evidence proved a real defect.

**Verdict:** COMPLETE with targeted repair. Status remains `95`.

**Live trace evidence:**
- Cases checked: `case-119e086c`, `case-58710f80`, `case-6396244e`, `case-c525ea1e`; prior booking proof `case-ef1010f7` also audited for duplicate same-rule metadata.
- All four new cases were valid review cases, not diagnostic-only. No `INTAKE_CONTEXT_MISSING`; `draft_text` present; raw webhook payload present; campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`; lead/sender/reply subject/reply text present; Instantly hydration supplied thread ID `53-RKIOlX32DrLO3dLAoGwdkoG`.
- Execution chains: `case-c525ea1e` Intake `3849`, Decision `3850`, HumanApproval `3851`; `case-6396244e` Intake `3852`, Decision `3854`, HumanApproval `3855`; `case-58710f80` Intake `3856`, Decision `3857`, HumanApproval `3858`; `case-119e086c` Intake `3859`, Decision `3860`, HumanApproval `3861`.
- `case-c525ea1e`: booking request; `INFORMATION_REQUEST / BOOKING_REQUEST`; booking draft rule applied correctly.
- `case-6396244e`: pricing/minimum commitment; `PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST`; booking rule found but not eligible/applied.
- `case-58710f80`: setup/process explanation; pre-patch leakage changed baseline `INFORMATION_REQUEST / OFFER_EXPLANATION` to `BOOKING_REQUEST` and applied the booking draft rule.
- `case-119e086c`: not-now/later; `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY`; booking rule found but not eligible/applied. Residual baseline draft-quality issue: AI draft included a calendar CTA despite no learning applied.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`); no Sender/Instantly POST was triggered.

**Patch summary:**
- Decision-only patch: booking HumanApproval form-created classification rules may promote a reply to `BOOKING_REQUEST` only when the reply text has booking/calendar intent.
- Added `_5qReplyHasBookingIntent(text)` and `_5qClassificationRuleAllowedForReply(rule, replyText)` in Decision D; `_5qSelectClassificationLearningRule(...)` now filters booking promotions by reply text.
- No changes to Intake, HumanApproval, Sender, Proxy, Shadow, Gate 2, autonomous mode, or learning-rule rows.

**Production apply:**
- Guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q18_20260701_010330/Decision-tgYmY97CG4Bm8snI-before.json`.
- Decision versionId `333e6d60-53e3-4e3b-ad69-5c799c4992bd` -> `889e1d45-7103-4b0a-a85d-685d19a2cadd`; active remained `true`.
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`.
- HumanApproval unchanged: `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`.
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

**Harnesses run:**
- 5Q18 Python: `20/20 PASS`
- 5Q18 PowerShell: `20/20 PASS`
- 5Q17D Python: `28/28 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16D Python: `32/32 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q18-multi-classification-self-learning-coverage.py`
- `scripts/SL-PHASE-5Q18-multi-classification-self-learning-coverage.ps1`
- `reports/SL-PHASE-5Q18_MULTI_CLASSIFICATION_SELF_LEARNING_COVERAGE.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Create a better same-scope HumanApproval form-learning override for `INFORMATION_REQUEST / BOOKING_REQUEST`, then retest one booking request and one setup/process explanation. Stop before approve/send.

### 2026-06-30T23:27:10Z — Codex — SL-PHASE-5Q17D seeded-reply ingestion stop-the-loop

**Agent:** Codex  
**Objective:** Determine whether `case-2c7e1ff0` was pre/post-5Q17C, trace the full seeded-reply path if post-repair, stop repeated generic `INTAKE_CONTEXT_MISSING` diagnostics, repair the smallest affected workflows, and production-apply only after targeted harnesses passed.

**Verdict:** COMPLETE for the seeded-reply ingestion blocker. Status remains `94` because valid self-improvement override proof is still pending.

**Live trace evidence:**
- `case-2c7e1ff0` was post-5Q17C: Intake `3814`, Decision `3815`, HumanApproval `3816`, created around `2026-06-30T21:37:11Z`; diagnostic expiry `2026-06-30T22:37:11.859Z`.
- Intake had valid seeded active-campaign context: raw payload present, event type `reply_received`, campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender email present, subject `Re: Capacity Question`, reply text present, email ID `00MR163AORTSYC1H11R9E3P123`.
- Instantly hydration was attempted and returned HTTP `200`; hydrated thread ID was `53-RKIOlX32DrLO3dLAoGwdkoG`; reply text length after merge was `50`.
- Decision input contained valid Intake context and classified `INFORMATION_REQUEST / OFFER_EXPLANATION`; Decision D output was error-only `{ error: "missing /" }`.
- Exact root cause was a malformed regex literal in `_5qNormalizeDraftForLearningDelta(...)`, a parse-time JavaScript error that the 5Q17C runtime fallback could not catch.
- HumanApproval received error-only Decision output and created a diagnostic, but the old card/page misleadingly labeled it `INTAKE_CONTEXT_MISSING` even though Intake had context.

**Patch summary:**
- Decision D `_5qNormalizeDraftForLearningDelta(...)` now uses valid regex escaping: `replace(/\r/g, '')` and `replace(/\n{3,}/g, '\n\n')`.
- HumanApproval diagnostics now classify failure layer as `RAW_WEBHOOK_CONTEXT_MISSING`, `INTAKE_MAPPING_CONTEXT_MISSING`, `INSTANTLY_HYDRATION_FAILED`, `DECISION_CONTEXT_DROPPED`, `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`, or `UNKNOWN`.
- HumanApproval diagnostic context/card/page now preserve upstream evidence fields and show upstream error; valid-Intake Decision drops now tell the owner it is a workflow defect, not a mailbox/thread setup correction.
- Intake, Sender, Proxy, Shadow, autonomous mode, Gate 2, and learning rules were not changed.

**Production apply:**
- Guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q17D_20260701_002622/Decision-tgYmY97CG4Bm8snI-before.json` and `backups/SL-PHASE-5Q17D_20260701_002622/HumanApproval-9aPrt92jFhoYFxbs-before.json`.
- Decision versionId `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef` -> `333e6d60-53e3-4e3b-ad69-5c799c4992bd`; active remained `true`.
- HumanApproval versionId `a069be1a-cfc5-4c5e-be9a-e300600aa58f` -> `0fa9d0ce-585e-495e-8af6-dbdb4957ab78`; active remained `true`.
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`); no Sender/Instantly POST was triggered by trace or apply.

**Harnesses run:**
- 5Q17D Python: `28/28 PASS`
- 5Q17D PowerShell: `28/28 PASS`
- 5Q17C Python: `24/24 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q11 Python: `24/24 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q17D-seeded-reply-ingestion-stop-the-loop.py`
- `scripts/SL-PHASE-5Q17D-seeded-reply-ingestion-stop-the-loop.ps1`
- `reports/SL-PHASE-5Q17D_SEEDED_REPLY_INGESTION_STOP_THE_LOOP.md`
- `reports/SL-PHASE-5Q17C_REPEATED_SEEDED_THREAD_CONTEXT_LOSS.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Create one fresh post-5Q17D seeded prospect reply inside the existing active Instantly campaign-started thread and inspect the Google Chat card/review page only. Do not approve, send, save, click learning-only, or use any diagnostic case as proof.

### 2026-06-30T16:09:05Z — Codex — SL-PHASE-5Q17C repeated seeded-thread context-loss and case-ID collision repair

**Agent:** Codex  
**Objective:** Trace the repeated `case-ed174cd6` diagnostic after owner confirmed seeded active-campaign thread replies, determine whether the event was stale/reused/colliding or still dropping context, repair the smallest affected workflows, production-apply, and preserve no-send safety.

**Verdict:** COMPLETE for the context-loss/collision blocker. Status remains `94` because valid self-improvement override proof is still pending.

**Live trace evidence:**
- `case-ed174cd6` is exactly `case-` + `djb2("UNKNOWN_INTAKE|policy-HMZ-1.2")`, proving a deterministic fallback case-ID collision.
- Three post-5Q17B chains reused/overwrote the same diagnostic row: `3736/3737/3738`, `3739/3740/3741`, and latest `3742/3743/3744`.
- Latest Intake `3742` had valid seeded context: raw payload present, event type `reply_received`, active campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender account present, subject `Re: Capacity Question`, reply body present, hydration attempted, HTTP `200`, and hydrated thread ID `53-RKIOlX32DrLO3dLAoGwdkoG`.
- Latest Decision `3743` received valid context through node C, including intake ID, reply_from_email, sender_email, subject, thread_id, reply_text, classification `INFORMATION_REQUEST`, and micro-intent `OFFER_EXPLANATION`; node D still returned only `{ error: "missing / " }`.
- Latest HumanApproval `3744` correctly created diagnostic-only output from the error-only Decision payload but incorrectly reused `UNKNOWN_INTAKE` identity, overwriting `case-ed174cd6` again. Latest diagnostic token existed but was redacted; expiry was `2026-06-30T16:54:53.166Z`.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`); no Sender/Instantly POST was triggered by trace or apply.

**Patch summary:**
- Decision D now wraps the whole per-item draft-prep body in a final exception fallback, preserving original `nes`, classification, micro-intent, and valid reply context if any node-D exception escapes.
- Decision D fallback emits a supervised fallback `draft_text`, `DRAFT_PREP_NODE_EXCEPTION_FALLBACK`, `human_review_required=true`, and `external_action_status=NOT_PERFORMED` instead of an error-only item.
- HumanApproval now uses a unique `DIAGNOSTIC_MISSING_INTAKE_<timestamp>_<random>` fallback intake seed only when no real Intake ID exists, preventing repeated missing-context diagnostics from overwriting the same row.
- Intake, Sender, Proxy, Shadow, autonomous mode, and Gate 2 were not changed.

**Production apply:**
- Guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q17C_20260630T160715Z/Decision-before.json` and `backups/SL-PHASE-5Q17C_20260630T160715Z/HumanApproval-before.json`.
- Decision versionId `90bcfe07-6a61-4e90-aa0f-a8eb8bd388f2` -> `3b949639-3cf8-4e0e-ab1a-cee3bcb669ef`; active remained `true`.
- HumanApproval versionId `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200` -> `a069be1a-cfc5-4c5e-be9a-e300600aa58f`; active remained `true`.
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`.
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

**Harnesses run:**
- 5Q17C Python: `24/24 PASS`
- 5Q17C PowerShell: `24/24 PASS`
- 5Q17B Python: `23/23 PASS`
- 5Q17B PowerShell: `23/23 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q17C-repeated-seeded-thread-context-loss.py`
- `scripts/SL-PHASE-5Q17C-repeated-seeded-thread-context-loss.ps1`
- `reports/SL-PHASE-5Q17C_REPEATED_SEEDED_THREAD_CONTEXT_LOSS.md`
- `reports/SL-PHASE-5Q17B_SEEDED_PROSPECT_CONTEXT_MISSING.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Create one fresh post-5Q17C seeded prospect reply inside the existing active Instantly campaign thread and inspect the Google Chat card/review page only. Do not approve, send, save, click learning-only, or use `case-ed174cd6` as proof.

### 2026-06-30T15:42:14Z — Codex — SL-PHASE-5Q17B seeded-prospect context-missing repair

**Agent:** Codex  
**Objective:** Trace `case-ed174cd6` after owner confirmed it was a seeded prospect, determine whether the diagnostic was stale or fresh, repair the smallest affected path, production-apply, and prepare the correct next live proof.

**Verdict:** PARTIAL overall. Seeded-reply context blocker is repaired and production-applied, but fresh valid self-improvement proof is still pending. Status remains `94`.

**Live trace evidence:**
- Fresh event chain existed, separate from the older `13:54:59Z` diagnostic: Intake `3726`, Decision `3727`, HumanApproval `3728`, all started around `2026-06-30T15:20:03Z`.
- Intake had valid seeded context: campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender account `zahid@gethmzautomations.com`, subject `Re: Capacity Question`, reply body present, and hydrated thread ID `53--eKozl7_zFmnRANH1W_NNdN`.
- Instantly hydration was attempted and returned HTTP `200`; thread ID came from the hydrated Instantly email response.
- Decision received the valid context and classified before node D, but `D. Draft Preparation (Templates / Human Draft)` returned error-only `{ error: "missing / " }`.
- HumanApproval then correctly created a diagnostic-only context-missing case because Decision returned no reply context, classification, micro-intent, or draft.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`) and did not contain `case-ed174cd6`; no Sender/Instantly send was triggered.

**Patch summary:**
- Decision D now catches AI provider/runtime draft-prep exceptions around `callAI(...)`.
- Decision D emits `DRAFT_PREP_EXCEPTION_FALLBACK` / `AI_PROVIDER_RUNTIME_EXCEPTION` instead of allowing an error-only Decision output.
- `OFFER_EXPLANATION` now has a non-null supervised fallback draft when AI drafting fails and no fixed template exists.
- Intake, HumanApproval, Sender, Proxy, Shadow, autonomous mode, and Gate 2 were not changed.

**Production apply:**
- Guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q17B_20260630T154021Z/Decision-before.json`
- Decision versionId `52753ab6-62f5-4334-9111-6f3f838cd698` -> `90bcfe07-6a61-4e90-aa0f-a8eb8bd388f2`; active remained `true`.
- HumanApproval unchanged: `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

**Harnesses run:**
- 5Q17B Python: `23/23 PASS`
- 5Q17B PowerShell: `23/23 PASS`
- 5Q14D Python: `21/21 PASS`
- 5Q14D PowerShell: `21/21 PASS`
- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q17B-seeded-prospect-context-missing.py`
- `scripts/SL-PHASE-5Q17B-seeded-prospect-context-missing.ps1`
- `reports/SL-PHASE-5Q17B_SEEDED_PROSPECT_CONTEXT_MISSING.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with `Could you send me the link to pick a meeting time?`; inspect the Google Chat card and review page only. Do not approve, send, save, or click learning-only. Report the new valid case ID.

### 2026-06-30T04:22:53Z — Codex — SL-PHASE-5Q16F applied-learning truthfulness and impact

**Agent:** Codex  
**Objective:** Trace `case-acf4513f`, verify whether visible active-learning attribution was truthful and meaningful, repair found/eligible/applied semantics if needed, production-apply, and prepare one fresh proof.

**Verdict:** PARTIAL overall. Production repair is complete and harness-proven, but fresh post-5Q16F live proof is still pending. Status remains `94`.

**Live trace evidence:**
- `case-acf4513f` was valid/non-diagnostic and created after Decision `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa` and HumanApproval `05244014-0ba9-4b6e-b82c-867a31be61c6`.
- Decision execution `3583` and HumanApproval executions `3584`/`3585` showed active rule `c9860e74-ff23-477e-87f1-812bec8023e5`, source case `case-5cf1aa57`, source marker `humanapproval_form_created_learning`, and effective classification `INFORMATION_REQUEST / BOOKING_REQUEST`.
- The final draft changed because of the source rule, but the awkward sentence came from the stored HumanApproval rule instruction: `At the end you can mention thaqt they can ask any question if they have any.`
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`), so no Sender/Instantly send was triggered by trace or apply.

**Patch summary:**
- Decision now separates found, eligible, and actually-applied learning.
- `learning_applied_to_draft` is true only when normalized final draft text differs from the pre-learning draft.
- `learning_applied_to_classification` is true only when effective classification differs from baseline because of a rule.
- Found/eligible/no-delta cases report `RULE_FOUND_BUT_NO_OUTPUT_DELTA`.
- Decision emits `learning_impact_summary`.
- HumanApproval displays found/eligible/actually-applied counts and learning impact summary in Google Chat and review form.
- The bad live sentence was not silently rewritten because it came from the human-created source rule, not a static template.

**Production apply:**
- Production guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q16F_20260630T041500Z`
- Decision versionId `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa` -> `52753ab6-62f5-4334-9111-6f3f838cd698`; active remained `true`.
- HumanApproval versionId `05244014-0ba9-4b6e-b82c-867a31be61c6` -> `16c2c10e-3d5a-4fb0-a9f9-f50f6be91200`; active remained `true`.
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`

**Harnesses run:**
- 5Q16F Python: `22/22 PASS`
- 5Q16F PowerShell: `22/22 PASS`
- 5Q16D Python: `32/32 PASS`
- 5Q16D PowerShell: `32/32 PASS`
- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q12 Python: `29/29 PASS`
- 5Q12 PowerShell: `29/29 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q16F-applied-learning-truthfulness-and-impact.py`
- `scripts/SL-PHASE-5Q16F-applied-learning-truthfulness-and-impact.ps1`
- `reports/SL-PHASE-5Q16F_APPLIED_LEARNING_TRUTHFULNESS_AND_IMPACT.md`
- `reports/SL-PHASE-5Q16D_LEARNING_ATTRIBUTION_AND_TEMPLATE_PROOF_GATE.md`
- `reports/SL-PHASE-5Q15_DYNAMIC_CLASSIFICATION_AND_DRAFT_LEARNING_SOURCE_OF_TRUTH.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with `Can you send across the booking link so I can choose a time?`; inspect the Google Chat card and review page only. Do not approve, send, save, or click learning-only.

### 2026-06-30T03:58:38Z — Codex — SL-PHASE-5Q16D learning attribution and deterministic-template proof gate

**Agent:** Codex  
**Objective:** Trace fresh case `case-f1135dcd`, determine whether active HumanApproval learning was consumed or merely hidden behind fixed-template labels, repair attribution/display if needed, production-apply, and prepare one fresh live proof.

**Verdict:** PARTIAL overall. Runtime rule consumption was present, and the attribution/display repair is production-applied and harness-proven, but fresh post-5Q16D live proof is still pending. Status remains `94`.

**Live trace evidence:**
- `case-f1135dcd` was valid/non-diagnostic and created after Decision `e283c3f7-6677-402a-8052-71ecf86c3a51` and HumanApproval `16ad1875-ea16-46a3-b934-ac710002a2e9`.
- Decision execution `3570` ran Q12 active form-learning lookup and consumed rule `c9860e74-ff23-477e-87f1-812bec8023e5` for draft.
- Source case `case-5cf1aa57` and source marker `humanapproval_form_created_learning` were present in Decision context.
- Baseline and effective classification were both `INFORMATION_REQUEST / BOOKING_REQUEST`; classification learning did not need to adjust this case.
- Draft policy/source remained owner-facing plain `FIXED_TEMPLATE` / `deterministic_template`, and Google Chat/review form hid the applied-rule attribution.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`), so no Sender/Instantly send was triggered by trace or apply.

**Root cause:**
- D/E/F/G/I: active rule was consumed, but Decision did not expose complete attribution, deterministic learned output kept plain fixed-template labels, and HumanApproval hid the metadata in the card/page.
- No remaining 5Q16B hardcoded learned booking phrase was found in production Decision D. Generic learned-looking booking sentence generation was removed from Decision and test helpers, with draft changes derived from active HumanApproval instruction context.

**Patch summary:**
- Decision D now emits baseline/effective classification metadata, active learning rules found/eligible/applied, applied rule IDs, source case IDs, source markers, scopes, classification/draft learning flags, non-application reason, and effective draft policy/source.
- Deterministic/fixed-template drafts affected by active HumanApproval form-created draft rules now label as `FIXED_TEMPLATE_WITH_FORM_LEARNING` / `deterministic_template_with_form_learning`.
- HumanApproval now stores and displays learning attribution in Google Chat and the review form, including applied yes/no, rule IDs, source cases, source markers, effective classification, and non-application reason.
- Updated 5Q16B/5Q14B harness helpers to stop treating generic hardcoded booking sentences as acceptable proof.

**Production apply:**
- Production guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q16D_20260630T035530Z`
- Decision versionId `e283c3f7-6677-402a-8052-71ecf86c3a51` -> `89c0d8a2-2aa8-44ab-a7b2-a4b30b95a3aa`; active remained `true`.
- HumanApproval versionId `16ad1875-ea16-46a3-b934-ac710002a2e9` -> `05244014-0ba9-4b6e-b82c-867a31be61c6`; active remained `true`.
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

**Harnesses run:**
- 5Q16D Python: `32/32 PASS`
- 5Q16D PowerShell: `32/32 PASS`
- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q14B PowerShell: `20/20 PASS`
- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`
- 5Q12 was not rerun because HumanApproval source-rule storage was not changed.

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q16D-learning-attribution-and-template-proof-gate.py`
- `scripts/SL-PHASE-5Q16D-learning-attribution-and-template-proof-gate.ps1`
- `scripts/SL-PHASE-5Q16B-deterministic-template-false-positive-audit.py`
- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.py`
- `reports/SL-PHASE-5Q16D_LEARNING_ATTRIBUTION_AND_TEMPLATE_PROOF_GATE.md`
- `reports/SL-PHASE-5Q16B_DETERMINISTIC_TEMPLATE_FALSE_POSITIVE_AUDIT.md`
- `reports/SL-PHASE-5Q15_DYNAMIC_CLASSIFICATION_AND_DRAFT_LEARNING_SOURCE_OF_TRUTH.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with `Would you be able to send me the calendar link so I can book a slot?`; inspect the Google Chat card and review page only. Do not approve, send, save, or click learning-only.

### 2026-06-30T03:15:53Z — Codex — SL-PHASE-5Q16B deterministic-template false-positive repair and production apply

**Agent:** Codex  
**Objective:** Forensically audit fresh case `case-dce9d552`, determine whether deterministic-template output was real dynamic learning or a hardcoded false positive, repair the smallest safe Decision path if needed, production-apply, and prepare a fresh live proof.

**Verdict:** PARTIAL overall. Production repair is complete and harness-proven, but fresh post-repair live proof is still pending. Status remains `94`.

**Live trace evidence:**
- `case-dce9d552` was valid/non-diagnostic and created after 5Q15 production versions.
- Decision execution `3555` ran Q12 active form-learning lookup.
- Rule `c9860e74-ff23-477e-87f1-812bec8023e5`, source case `case-5cf1aa57`, and source marker `humanapproval_form_created_learning` were present in Decision context.
- Draft policy/source were `FIXED_TEMPLATE` / `deterministic_template`.
- The case is not accepted as complete proof because the draft matched source-gated hardcoded booking rewrite text in Decision D.
- HumanApproval executions `3556` and `3558` created/rendered the case; render was valid.
- Latest Sender execution remained `3193` (`2026-06-29T00:16:34.631Z`), so no Sender/Instantly send was triggered by the trace or apply.

**Patch summary:**
- Decision D only: removed hardcoded `_5qApplyActiveBookingRuleToDraft` learned booking wording.
- Added block-aware active HumanApproval form-created instruction parsing so multi-line form instructions retain URLs and text.
- Added structured runtime metadata: `active_form_draft_rules_applied`, `active_form_draft_learning_applied`, and `active_form_draft_learning_effect`.
- Updated the 5Q14B regression harness to stop rewarding the removed hardcoded booking rewrite.
- Added the 5Q16B false-positive audit harness.

**Production apply:**
- Production guard passed with `pwsh -File ./scripts/assert-hmz-production-target.ps1`.
- Backup: `backups/SL-PHASE-5Q16B_20260630T031453Z`
- Decision versionId `4e04ebc8-c7ef-4d45-ad75-945f5179ba2d` -> `e283c3f7-6677-402a-8052-71ecf86c3a51`; active remained `true`.
- HumanApproval unchanged: `16ad1875-ea16-46a3-b934-ac710002a2e9`
- Intake unchanged: `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged: `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged: `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow unchanged/inactive: `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Production Decision patch check: `active_form_draft_rules_applied` present, runtime instruction renderer present, old hardcoded learned booking phrase count `0`.

**Harnesses run:**
- 5Q16B Python: `30/30 PASS`
- 5Q16B PowerShell: `30/30 PASS`
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python: `20/20 PASS`
- 5Q14B PowerShell: `20/20 PASS`
- 5Q12 and 5Q11 were not rerun because HumanApproval source storage and review-state/accessibility paths were not changed.

**Files changed:**
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q16B-deterministic-template-false-positive-audit.py`
- `scripts/SL-PHASE-5Q16B-deterministic-template-false-positive-audit.ps1`
- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.py`
- `reports/SL-PHASE-5Q16B_DETERMINISTIC_TEMPLATE_FALSE_POSITIVE_AUDIT.md`
- `reports/SL-PHASE-5Q15_DYNAMIC_CLASSIFICATION_AND_DRAFT_LEARNING_SOURCE_OF_TRUTH.md`
- `OPERATION_HANDOFF.md`

**Next owner action:** Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with `Can I choose a time from your calendar link?`; inspect the review draft only. Do not approve, send, save, or click learning-only.

### 2026-06-29T23:08:50+00:00 — Codex — SL-PHASE-5Q15 production apply and live-proof preparation

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Apply the already-built 5Q15 Decision/HumanApproval deltas to production only, preserve active state, verify safety, and prepare the fresh live proof.

**Verdict:** COMPLETE for production apply; PARTIAL overall because fresh live proof remains pending. Status remains `94`.

**Pre-apply validation:**
- Mandatory files present: local Decision, HumanApproval, 5Q15 Python harness, 5Q15 PowerShell wrapper, and 5Q15 report.
- Recorded 5Q15 harness pass existed in report/handoff.
- Current pre-apply harness rerun: 5Q15 Python `35/35 PASS`; PowerShell `35/35 PASS`.
- Production pre-apply versions matched expected: Decision `e64cded8-e4a9-46f8-b541-23512e9f4dce`, HumanApproval `de84f8f3-d4c4-4565-88ab-c40449e727ca`.
- No affected-workflow drift detected.

**Production apply:**
- Production guard passed before reads and again immediately before writes.
- Backup/export path: `backups/sl-phase-5q15-production-apply-20260629T230705Z`.
- Decision `e64cded8-e4a9-46f8-b541-23512e9f4dce` -> `4e04ebc8-c7ef-4d45-ad75-945f5179ba2d`; active preserved `true`.
- HumanApproval `de84f8f3-d4c4-4565-88ab-c40449e727ca` -> `16ad1875-ea16-46a3-b934-ac710002a2e9`; active preserved `true`.
- Local `workflows/production_decision_current.json` and `workflows/production_humanapproval_current.json` synced to post-apply exports.

**Safety verification:**
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`.
- Shadow Evaluator unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- Latest Sender execution remained `3193`, started `2026-06-29T00:16:34.631Z`, before this apply window.
- No Sender execution, Instantly POST, or live email send was triggered by this apply.
- Gate 2 remains not approved; autonomous disabled.

**Post-apply harness:**
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `reports/SL-PHASE-5Q15_DYNAMIC_CLASSIFICATION_AND_DRAFT_LEARNING_SOURCE_OF_TRUTH.md`
- `OPERATION_HANDOFF.md`
- Backup artifacts under `backups/sl-phase-5q15-production-apply-20260629T230705Z`

**Next owner action:**
- Use a seeded prospect in the active Instantly campaign and reply in the existing campaign thread with: `Can I choose a time from your calendar link?` Then inspect the review draft only. Do not approve, send, save, or click learning-only.

### 2026-06-29T22:49:31+00:00 — Codex — SL-PHASE-5Q15 dynamic classification/draft learning source-of-truth repair

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Audit and repair dynamic HumanApproval form-created classification and draft learning without hardcoding owner test phrases or treating stale cases as proof.

**Verdict:** PARTIAL. Local source-of-truth repair and harness proof are complete; production apply and fresh live proof remain pending. Status remains `94`.

**Stale/render finding:**
- Owner reported `case-9747ff6f` review form now renders.
- Codex did not independently query n8n because the attempted targeted read-only production API trace was rejected by policy.
- `case-9747ff6f` was created before Decision version `e64cded8-e4a9-46f8-b541-23512e9f4dce`; its stored `INFORMATION_REQUEST / OFFER_EXPLANATION` classification and draft should remain stale on reopen.
- Local HumanApproval GET render path displays stored review-case output and does not regenerate Decision classification/draft.
- Prior 5Q14F evidence showed Sender was not triggered and no Instantly POST was caused by that case/apply.

**Root cause:**
- HumanApproval emitted draft/style form-created rules as active/effective with source metadata.
- HumanApproval classification corrections were still emitted as `proposed_shadow`, with activation required.
- Decision Q12 fetched active rows but Decision D only transformed active `style` rows into `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`.
- Therefore active HumanApproval form-created classification corrections could not adjust effective classification before draft policy/template selection.

**Local repair:**
- Patched HumanApproval `SL-P2A. Prepare Phase 1C+2 Capture Data` so form-created classification corrections now emit active/effective `classification` rule rows.
- Classification rows preserve `source_case_id`, `source_original_case_id`, original classification, corrected/effective classification, target classification used, human instruction, `activation_source=humanapproval_form`, `source_marker=humanapproval_form_created_learning`, effective/activated timestamps, and immediate supervised effect.
- Patched Decision `D. Draft Preparation (Templates / Human Draft)` so it builds `DYNAMIC_FORM_CLASSIFICATION_RULES`, selects the newest matching same-scope HumanApproval form-created classification correction, and adjusts effective category/micro-intent before draft policy/template selection.
- Decision output now carries baseline/effective classification and applied learning rule metadata on classifier/decision/draft.
- Draft learning still uses `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` after effective classification is set across AI-supervised, commercial, deterministic/template, and fallback paths.
- No Sender, Intake, Shadow Evaluator, autonomous, Gate 2, approval-send, or live-send path changed.

**Harness results:**
- 5Q15 Python: `35/35 PASS`
- 5Q15 PowerShell: `35/35 PASS`
- 5Q14B Python/PowerShell: `20/20 PASS`
- 5Q12 Python/PowerShell: `29/29 PASS`
- 5Q14F/5Q14D/5Q11 were not run because render, diagnostic, and review-state/token paths were not changed.
- Workflow JSON validity check passed for Decision and HumanApproval.

**Production apply:**
- Production guard passed locally.
- A targeted read-only n8n trace was rejected by policy because repo instructions forbid production API calls.
- No production API workaround was attempted.
- No production write/apply was attempted; production HumanApproval and Decision versionIds remain unchanged from 5Q14F.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.py`
- `scripts/SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.ps1`
- `reports/SL-PHASE-5Q15_DYNAMIC_CLASSIFICATION_AND_DRAFT_LEARNING_SOURCE_OF_TRUTH.md`
- `reports/SL-PHASE-5Q14F_HUMANAPPROVAL_RENDER_CRASH_AND_LIVE_BOOKING_CASE.md`
- `reports/SL-PHASE-5Q14B_DETERMINISTIC_TEMPLATE_LEARNING_BYPASS.md`
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `OPERATION_HANDOFF.md`

**Next owner action:**
- Explicitly authorize an allowed production apply of the local 5Q15 HumanApproval/Decision workflow deltas, then create one fresh owned/test inbound reply in the existing Instantly campaign thread and inspect the review draft only. Do not approve, send, save, or click learning-only.

### 2026-06-29T22:22:34+00:00 — Codex — SL-PHASE-5Q14F HumanApproval render crash and live booking-case audit

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Trace `case-9747ff6f`, fix the HumanApproval blank-page render crash, audit booking/calendar classification and active-rule consumption, and prevent false live-learning proof.

**Verdict:** COMPLETE for render-crash repair and classifier eligibility repair. Status remains `94`; live learning proof is still pending.

**Trace evidence:**
- `case-9747ff6f`; intake `00MQZRQI7D9OL01YPRS7ZFUH95`.
- Intake execution `3490` had campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email `alinazahidkhan890@gmail.com`, sender `hamzah@teamhmzautomations.com`, subject `Re: Capacity Question`, thread ID present, and reply body present.
- Decision execution `3491` classified as `INFORMATION_REQUEST / OFFER_EXPLANATION`; draft policy `AI_SUPERVISED_OR_TEMPLATE`; draft source `ai_supervised`.
- Q12 lookup executed and found active rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57` and marker `humanapproval_form_created_learning`.
- Decision D did not carry the rule ID/source case/source marker into the draft context because the current micro-intent `OFFER_EXPLANATION` was ineligible for the booking rule.
- HumanApproval create execution `3492` created a valid/non-diagnostic `NEW` case with draft text present.
- HumanApproval GET execution `3493` failed before rendering node J with `SyntaxError: Unexpected identifier 'background'`.
- `case-9747ff6f` token expires `2026-06-29T23:07:37.041Z`.
- Sender executions checked; none contained `case-9747ff6f`.

**Root cause:**
- 5Q14D diagnostic HTML strings in HumanApproval node `J. Render Review Form HTML` had unescaped attributes inside JavaScript strings, including `style="background...` and `type="button"`.
- This was a compile error, so it crashed valid AI-supervised pages before branch logic.
- Booking/calendar phrase `Where can I grab a time on your calendar?` was a valid booking ask but not covered by the Decision booking regex, so it fell through to `OFFER_EXPLANATION`.

**Repair:**
- Patched HumanApproval node `J. Render Review Form HTML`.
- Escaped diagnostic HTML attributes.
- Added safe optional-metadata guards for malformed `risk_flags` and `detected_intents`, rendering a safe diagnostic block instead of throwing.
- Preserved normal learning fields, state banners, diagnostic-only rendering, save/learning-only/approve-send safety controls, and same-link accessibility.
- Patched Decision node `B. Deterministic Reply Classifier`.
- Added narrow booking/calendar phrase coverage for `grab a time`, `grab a slot`, `time on your calendar`, `slot on your calendar`, and `your calendar`.
- Did not hardcode learned booking guidance into baseline policy, classifier, or deterministic templates.
- Sender, Intake, autonomous, and Gate 2 were not changed.

**Harness results:**
- Pre-apply 5Q14F Python/PowerShell: `22/22 PASS`
- Pre-apply 5Q14D Python/PowerShell: `21/21 PASS`
- Pre-apply 5Q11 Python/PowerShell: `24/24 PASS`
- Pre-apply 5Q14B Python/PowerShell: `20/20 PASS`
- Pre-apply 5Q12 Python/PowerShell: `29/29 PASS`
- Post-sync 5Q14F Python: `22/22 PASS`
- Post-sync 5Q14D Python: `21/21 PASS`
- Post-sync 5Q11 Python: `24/24 PASS`
- Post-sync 5Q14B Python: `20/20 PASS`
- Post-sync 5Q12 Python: `29/29 PASS`

**Production apply:**
- Production guard passed before n8n writes.
- Backup: `backups/sl-phase-5q14f-render-crash-live-booking-20260629T222039Z`.
- HumanApproval `00eb6dbc-c1a7-42ce-97ef-24653d06784d` -> `de84f8f3-d4c4-4565-88ab-c40449e727ca`; active preserved `true`.
- Decision `302e34bc-8b81-4c2f-97fa-832246153646` -> `e64cded8-e4a9-46f8-b541-23512e9f4dce`; active preserved `true`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`; latest Sender execution remained `3193`, started before this session, and did not contain `case-9747ff6f`.
- Shadow Evaluator unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q14F-humanapproval-render-crash-and-live-booking-case.py`
- `scripts/SL-PHASE-5Q14F-humanapproval-render-crash-and-live-booking-case.ps1`
- `reports/SL-PHASE-5Q14F_HUMANAPPROVAL_RENDER_CRASH_AND_LIVE_BOOKING_CASE.md`
- `reports/SL-PHASE-5Q14D_INVALID_DIAGNOSTIC_LINK_AND_CONTEXT_MISSING.md`
- `reports/SL-PHASE-5Q14B_DETERMINISTIC_TEMPLATE_LEARNING_BYPASS.md`
- `OPERATION_HANDOFF.md`
- Backup artifacts under `backups/sl-phase-5q14f-render-crash-live-booking-20260629T222039Z`

**Next owner action:**
- Immediately reopen the existing `case-9747ff6f` review link before `2026-06-29T23:07:37Z` and inspect the draft only. Do not approve, send, save, or click learning-only.

### 2026-06-29T20:22:36+00:00 — Codex — SL-PHASE-5Q14D invalid diagnostic link and context-missing repair

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Trace `case-3df4e733`, determine why it became `INTAKE_CONTEXT_MISSING` with missing `draft_text`, repair diagnostic review-link accessibility, and avoid false live-learning proof.

**Verdict:** COMPLETE for diagnostic-link repair and context-missing root cause. Status remains `94`; fresh valid live booking-link proof is still required.

**Trace evidence:**
- `case-3df4e733`; intake `00MQYOYTHS3KBL8U23HW3RAKX4`.
- Intake execution `3268` had campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email `hamzahzahid0@gmail.com`, sender `zahid@gethmzautomation.com`, subject `Re: Capacity Question`, thread ID present after hydration, and reply body `Is there a calendar link I can use to pick a slot?`.
- Decision execution `3269` classified as `INFORMATION_REQUEST / BOOKING_REQUEST`, selected `HUMAN_ONLY / human_only`, and produced no `draft_text`.
- HumanApproval execution `3270` created `CONTEXT_MISSING_BLOCKED` / `DIAGNOSTIC_CONTEXT_MISSING` with missing field `draft_text`.
- Review-link GET executions `3271` and `3272` were before token expiry (`2026-06-29T05:02:16.884Z`) but routed to token error because `CONTEXT_MISSING_BLOCKED` was not a renderable state.
- `case-3df4e733` is invalid/diagnostic-only and cannot prove self-improvement.

**Root cause:**
- HumanApproval GET token gate excluded diagnostic-only state `CONTEXT_MISSING_BLOCKED`, so it returned `ALREADY_DECIDED` instead of rendering the diagnostic page.
- HumanApproval diagnostic renderer was too sparse for the owner contract even if reached.
- Decision had no sendable draft-policy mapping for micro-intent `BOOKING_REQUEST` under `INFORMATION_REQUEST`, and Decision D had no template alias from `BOOKING_REQUEST` to the existing booking template.
- Owner setup was not the evidence-backed root cause for this case; core campaign/thread/lead/reply context was present.

**Repair:**
- Patched HumanApproval nodes `H. Validate Review Token (GET)`, `L. Validate & Consume Review Token (POST)`, and `J. Render Review Form HTML`.
- Added `CONTEXT_MISSING_BLOCKED` to renderable/diagnostic reopen states.
- Diagnostic page now renders until token expiry with case ID, status, missing fields, from, sender, broad category, micro intent, draft policy/source, reply excerpt, exact correction instructions, `No reply was sent.`, and `This diagnostic case cannot be approved or sent.`
- Diagnostic page disables send/approval/learning actions.
- Patched Decision nodes `B. Deterministic Reply Classifier` and `D. Draft Preparation (Templates / Human Draft)`.
- Added `BOOKING_REQUEST: FIXED_TEMPLATE`, aliased `BOOKING_REQUEST` micro-intent to the existing `MEETING_TIME_REQUEST` booking template, and extended active booking-rule matching to both `BOOKING_REQUEST / MEETING_TIME_REQUEST` and `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Did not hardcode learned booking guidance into baseline policy or templates.
- Sender, autonomous, and Gate 2 were not changed.

**Harness results:**
- Pre-apply 5Q14D Python/PowerShell: `21/21 PASS`
- Pre-apply 5Q11 Python/PowerShell: `24/24 PASS`
- Pre-apply 5Q14B Python/PowerShell: `20/20 PASS`
- Pre-apply 5Q12 Python/PowerShell: `29/29 PASS`
- Post-sync 5Q14D Python: `21/21 PASS`
- Post-sync 5Q11 Python: `24/24 PASS`
- Post-sync 5Q14B Python: `20/20 PASS`
- Post-sync 5Q12 Python: `29/29 PASS`

**Production apply:**
- Production guard passed before n8n writes.
- First PUT attempt was rejected with HTTP 400 due payload shape; no version change was confirmed. Guard was rerun before retry.
- Backup: `backups/sl-phase-5q14d-invalid-diagnostic-link-20260629T202122Z`.
- HumanApproval `f1138daa-8d38-4acf-b0c9-a6a2bef626fe` -> `00eb6dbc-c1a7-42ce-97ef-24653d06784d`; active preserved `true`.
- Decision `c7299598-71e2-4f0f-b493-184cb7b793f7` -> `302e34bc-8b81-4c2f-97fa-832246153646`; active preserved `true`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`; latest Sender execution remained `3193`, started before this session, and did not contain `case-3df4e733`.
- Shadow Evaluator unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q14D-invalid-diagnostic-link-and-context-missing.py`
- `scripts/SL-PHASE-5Q14D-invalid-diagnostic-link-and-context-missing.ps1`
- `reports/SL-PHASE-5Q14D_INVALID_DIAGNOSTIC_LINK_AND_CONTEXT_MISSING.md`
- `reports/SL-PHASE-5Q14B_DETERMINISTIC_TEMPLATE_LEARNING_BYPASS.md`
- `OPERATION_HANDOFF.md`
- Backup artifacts under `backups/sl-phase-5q14d-invalid-diagnostic-link-20260629T202122Z`

**Next owner action:**
- Create one fresh owned/test booking-link reply after HumanApproval version `00eb6dbc-c1a7-42ce-97ef-24653d06784d` and Decision version `302e34bc-8b81-4c2f-97fa-832246153646`.
- Use a seeded owned/test prospect in the active Instantly campaign and reply from the prospect inbox in the existing campaign thread. Do not forward or compose a standalone email.
- Confirm Instantly shows campaign, lead email, subject, thread, and reply body before retrying.
- Suggested reply: `Is there a calendar link I can use to pick a slot?`
- Inspect the review draft only; do not approve, send, or click learning-only.

### 2026-06-29T03:53:14+00:00 — Codex — SL-PHASE-5Q14B deterministic-template learning bypass repair

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Audit and fix why `case-7f53d7bb` used `FIXED_TEMPLATE / deterministic_template` without applying active HumanApproval form-created booking guidance.

**Verdict:** PARTIAL. Deterministic-template bypass and booking taxonomy mismatch are fixed and harness-proven; fresh live post-repair proof is still required. Status remains `94`.

**Trace evidence:**
- Case `case-7f53d7bb`; intake `00MQYNWXX305FU23S7A2RHHMXH`; inbound asked for the link to book a time.
- Case created at `2026-06-29T03:32:50.020Z`, after Decision version `f50e70f3-56bb-494e-8dfb-c3108d84e784`.
- Decision execution `3257` classified as `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- Draft policy `FIXED_TEMPLATE`; draft source `deterministic_template`.
- Q12 active form-learning lookup executed and fetched rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57`.
- Decision D output did not contain or apply the source rule context.
- Sender executions checked; latest Sender execution remained `3193` before and after production apply.

**Root cause:**
- Q12 lookup ran, but deterministic/fixed template output bypassed active form-created learning.
- Source rule target was `INFORMATION_REQUEST / BOOKING_REQUEST`; current classifier emitted `BOOKING_REQUEST / MEETING_TIME_REQUEST`.
- Eligibility and deterministic output both needed repair; Q12 presence alone was a false-positive risk.

**Repair:**
- Patched Decision node `D. Draft Preparation (Templates / Human Draft)` only.
- Added narrow booking taxonomy crosswalk: form-created micro-intent `BOOKING_REQUEST` can match current `BOOKING_REQUEST / MEETING_TIME_REQUEST`; pricing/unrelated scopes remain blocked.
- Preserved `source_case_id` and `source_marker` in active behavioural guidance.
- Added active-rule postprocessing across AI supervised, commercial supervised, safe fallback, and deterministic/fixed template paths.
- Booking deterministic-template modification activates only from matching active HumanApproval form-created rule context; the learned booking guidance was not hardcoded into classifier or templates.

**Harness results:**
- 5Q14B Python: `20/20 PASS`
- 5Q14B PowerShell: `20/20 PASS`
- 5Q12 Python: `29/29 PASS`
- 5Q12 PowerShell: `29/29 PASS`
- 5Q11/5Q10 not run because HumanApproval target storage and review-form paths were not changed.

**Production apply:**
- Production guard passed before API write.
- Backup: `backups/sl-phase-5q14b-deterministic-template-learning-bypass-20260629T035240Z`.
- Decision `f50e70f3-56bb-494e-8dfb-c3108d84e784` -> `c7299598-71e2-4f0f-b493-184cb7b793f7`; active preserved `true`.
- HumanApproval unchanged `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow Evaluator unchanged/inactive `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- Sender was not triggered by apply; no Instantly POST observed.

**Files changed:**
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.py`
- `scripts/SL-PHASE-5Q14B-deterministic-template-learning-bypass.ps1`
- `scripts/SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py`
- `reports/SL-PHASE-5Q14B_DETERMINISTIC_TEMPLATE_LEARNING_BYPASS.md`
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `OPERATION_HANDOFF.md`
- Backup artifacts under `backups/sl-phase-5q14b-deterministic-template-learning-bypass-20260629T035240Z`

**Next owner action:**
- Create one fresh owned/test booking-link reply after Decision version `c7299598-71e2-4f0f-b493-184cb7b793f7`, using: `Can you send over the link to book a time that works for me?`
- Inspect the review draft only; do not approve, send, or click learning-only.

### 2026-06-29T02:53:41+00:00 — Codex — SL-PHASE-5Q13 later-similar, leakage, corrected-classification, and classifier repair

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Verify live later-similar booking-rule effect, leakage control, corrected-classification targeting, and apply only a clear minimal repair if needed.

**Verdict:** PARTIAL. Source registration, leakage control, and corrected-classification source proof passed. First later-similar booking proof failed pre-repair due classification mismatch. Minimal classifier repair production-applied. Status is now `94`.

**Live case identification:**
- `case-0c0f1ee1`: booking-link request, inbound asks for the booking link so the prospect can choose a time; draft source `ai_supervised`.
- `case-89673efb`: pricing/commitment request, inbound asks about cost and minimum contract; draft source `ai_commercial_supervised`.

**Later-similar booking proof:**
- Booking case: `case-0c0f1ee1`; Decision execution `3225`.
- `Q12. Lookup Active Form Learning Rules` executed and fetched active rule `c9860e74-ff23-477e-87f1-812bec8023e5` with source case `case-5cf1aa57`.
- The draft shared a booking link, but Decision classified the case as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Because the source rule is scoped to `INFORMATION_REQUEST / BOOKING_REQUEST / current_micro_intent_only`, the rule was fetched but not eligible for the current micro-intent.
- Root cause: Decision micro-intent detection lacked booking-link/time-selection phrase handling under `INFORMATION_REQUEST`.

**Leakage control:**
- Pricing case: `case-89673efb`; Decision execution `3222`.
- Q12 executed and active rules were fetched.
- Pricing draft stayed pricing/commitment scoped, did not adopt booking-link guidance, did not invent pricing, and did not invent guarantees/results/contracts.
- No Sender execution contained either live test case; no Instantly POST observed for either case.

**Corrected-classification proof:**
- Source rule preserved original classification `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Corrected/effective classification and target used are both `INFORMATION_REQUEST / BOOKING_REQUEST`.
- The first later-similar miss confirmed the system did not silently broaden the corrected-target rule back to the original `OFFER_EXPLANATION` target.

**Repair:**
- Patched only Decision node `B. Deterministic Reply Classifier`.
- Added booking-link/time-selection phrase handling so `booking link`, `calendar link`, `choose a time`, `pick a time`, `send/share booking link`, `availability`, and `time options` map to micro-intent `BOOKING_REQUEST`.
- Guard passed before production apply.
- Backup: `backups/sl-phase-5q13-booking-classifier-20260629T025310Z`.
- Decision versionId `009daf13-58f7-442c-b74b-c43f352620fe` -> `f50e70f3-56bb-494e-8dfb-c3108d84e784`; active remained `true`.
- HumanApproval unchanged `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.

**Verification:**
- 5Q12 targeted harness after patch/apply: `29/29 PASS`.
- JSON parse passed for synced Decision export.
- Local phrase checks passed: live booking-link wording matches booking regex; pricing wording remains pricing and does not match booking.

**Files changed:**
- `workflows/production_decision_current.json`
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `OPERATION_HANDOFF.md`
- Backup artifacts under `backups/sl-phase-5q13-booking-classifier-20260629T025310Z`

**Next owner action:**
- Create one fresh owned/test booking-link reply after Decision version `f50e70f3-56bb-494e-8dfb-c3108d84e784`, using wording like: `Could you send me the booking link so I can choose a time?`
- Inspect the review draft only; do not approve, send, or click learning-only.

### 2026-06-29T01:15:55+00:00 — Codex — SL-PHASE-5Q13 retry live source-registration verification

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Re-check `case-5cf1aa57` after owner reported the `Approved for learning only` submission was made.

**Verdict:** PARTIAL / source registration verified, but stored rule differs from the originally intended setup/process instruction. Status is now `93`.

**Read-only production evidence:**
- Production-target guard passed before n8n API reads.
- Review case table now shows `case-5cf1aa57` as `LEARNING_REVISION_APPROVED`.
- HumanApproval execution `3216` received `submit_action=approve_learning_only` and `final_action=approve_learning_only`.
- Execution `3216` ran submit validation, reviewer decision, draft revision event write, classification correction capture, rule candidate emit/write, and non-send terminal result.
- Execution `3216` did not run Sender handoff node `Q. Reply Sender Handoff (Approved)`.
- Recent Sender executions checked: 51; none contained `case-5cf1aa57`.
- Rule-candidate table contains classification candidate `f3170717-c5bc-4324-bc04-71aa6b371469` as `proposed_shadow`.
- Rule-candidate table contains active style rule `c9860e74-ff23-477e-87f1-812bec8023e5`.

**Active style rule evidence:**
- `source_case_id=case-5cf1aa57`; `source_original_case_id=case-5cf1aa57`.
- `status=active`; `activation_source=humanapproval_form`; `source_marker=humanapproval_form_created_learning`.
- `immediate_supervised_effect=true`; `effective_at=2026-06-29T01:12:38.202Z`; `activated_at=2026-06-29T01:12:38.202Z`.
- Original classification preserved as `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Corrected/effective classification stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Target classification used stored as `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Scope stored as `current_micro_intent_only`; policy precedence key `INFORMATION_REQUEST|BOOKING_REQUEST|current_micro_intent_only`.

**Important mismatch:**
- The active style rule did not store the originally intended setup/process instruction from the handoff.
- The stored instruction is booking-link guidance for `INFORMATION_REQUEST / BOOKING_REQUEST`.
- Do not use the setup/process later-similar wording as proof for this source rule; it would not be a matching classification/scope test.

**Decision readiness evidence:**
- Local Decision workflow remains versionId `009daf13-58f7-442c-b74b-c43f352620fe`.
- `Q12. Lookup Active Form Learning Rules` reads active rows from `sl_rule_candidates`.
- Draft preparation still separates `ACTIVE_BEHAVIOURAL_POLICIES` from `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` and includes dynamic form-created rules for normal AI and fallback draft paths.
- The active rule is consumable for matching `INFORMATION_REQUEST / BOOKING_REQUEST` cases.

**Files changed:**
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `OPERATION_HANDOFF.md`

**Tests/harnesses:** Not run; no patch was made.

**Production apply:** None.

**Next owner action:**
- Either test a later similar owned/test booking-request case matching the actual active rule, or create a new setup/process source learning rule before using the setup/process proof wording.

### 2026-06-29T00:59:19+00:00 — Codex — SL-PHASE-5Q13 live source-registration verification

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Verify whether owner action on `case-5cf1aa57` created an active HumanApproval form-origin learning rule consumable by Decision.

**Verdict:** FAILED / source registration not observed; status remains `92`.

**Read-only production evidence:**
- Production-target guard passed before n8n API reads.
- Review case table contains `case-5cf1aa57`, but it remains `status=NEW`.
- The case has no `approved_at`, no `approver_identity`, no `final_reply_text`, and no `decision_payload`.
- Rule-candidate table contains no row with `source_case_id=case-5cf1aa57`.
- Recent HumanApproval executions checked: 100; only matching execution was create-review-case execution `3210` at `2026-06-29T00:51:29.513Z`.
- Execution `3210` ran create/notification nodes only; submit, reviewer-decision, learning-capture, rule-candidate write, and Sender-handoff nodes did not run.
- Recent Sender executions checked: 51; none contained `case-5cf1aa57`.

**Decision readiness evidence:**
- Local Decision workflow remains versionId `009daf13-58f7-442c-b74b-c43f352620fe`.
- `Q12. Lookup Active Form Learning Rules` exists and reads active rows from `sl_rule_candidates`.
- Draft preparation still separates `ACTIVE_BEHAVIOURAL_POLICIES` from `DYNAMIC_FORM_BEHAVIOURAL_POLICIES` and includes dynamic form-created rules for normal AI and fallback draft paths.
- No active rule exists for `case-5cf1aa57`, so there is nothing for Decision to consume for that source case.

**Files changed:**
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `OPERATION_HANDOFF.md`

**Tests/harnesses:** Not run; no patch was made.

**Production apply:** None.

**Next owner action:**
- Reattempt one owned/test learning-only submission from a currently open review case, then ask Codex to verify the source rule before creating a later similar proof case.

### 2026-06-29T00:37:28+00:00 — Codex — SL-PHASE-5Q12 form-learning source and improvement-type removal

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Remove the redundant improvement-type field and prove HumanApproval form-created learning, not Codex hardcoded baseline, dynamically affects later similar drafts.

**Owner evidence:**
- Fresh case `case-389ef118`; owner reported review-link/accessibility flow is working perfectly after 5Q11.
- Owner requested removal of `What type of improvement is this?`.
- Owner required proof that one HumanApproval form-created improvement affects future similar drafts.

**Root cause / finding:**
- HumanApproval form candidates were previously written as inert `proposed_shadow` style candidates.
- Decision consumed embedded `ACTIVE_BEHAVIOURAL_POLICIES`, not active form-created rule rows dynamically.
- Rule-candidate table lacked metadata columns required to preserve source/effective-target proof.

**Fix summary:**
- Removed visible improvement-type checkbox section and submit dependency.
- HumanApproval now uses `draft_learning_instruction` as the primary learning signal.
- HumanApproval style candidates created from form learning now write `status=active`, `effective_at`, `activated_at`, `activation_source=humanapproval_form`, `source_marker=humanapproval_form_created_learning`, `immediate_supervised_effect=true`, and source/effective-target metadata.
- Decision now reads active form-created rule rows through `Q12. Lookup Active Form Learning Rules`, converts them to `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`, and merges them with the embedded baseline policies.
- Added generic active-rule exact-start postprocessing so matching human instructions can affect both AI and safe fallback drafts without hardcoding the owner’s example.

**Data table schema:**
- Table: `sl_rule_candidates`.
- Schema backup: `backups/sl-phase-5q12-rule-candidate-table-schema-20260629T003608Z`.
- Added only missing source-of-truth metadata columns needed by 5Q12.

**Harness results:**
- 5Q12 Python: `29/29 PASS`
- 5Q12 PowerShell: `29/29 PASS`
- 5Q11 Python/PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep not run; send/idempotency path unchanged.
- Post-production-export sync: 5Q12 Python `29/29 PASS`; 5Q11 Python `24/24 PASS`.

**Production apply:**
- Production guard passed before API writes.
- Workflow backup: `backups/sl-phase-5q12-form-learning-source-20260629T003636Z`.
- HumanApproval `d3449764-b059-48be-b73a-8a9beae443ea` -> `f1138daa-8d38-4acf-b0c9-a6a2bef626fe`, active preserved `true`.
- Decision `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8` -> `009daf13-58f7-442c-b74b-c43f352620fe`, active preserved `true`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- Latest Sender execution observed after apply was `3193`, started before the apply; no Sender execution or Instantly POST was caused by 5Q12.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `scripts/SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py`
- `scripts/SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.ps1`
- `scripts/SL-PHASE-5Q11-review-link-accessibility-and-corrected-classification.py`
- `scripts/SL-PHASE-5Q10-review-form-contract-and-blocked-state.py`
- `reports/SL-PHASE-5Q12_FORM_LEARNING_SOURCE_AND_IMPROVEMENT_TYPE_REMOVAL.md`
- `reports/SL-PHASE-5Q11_REVIEW_LINK_ACCESSIBILITY_AND_CORRECTED_CLASSIFICATION.md`
- `reports/SL-PHASE-5Q10_REVIEW_FORM_CONTRACT_AND_BLOCKED_STATE.md`
- `OPERATION_HANDOFF.md`

**Next owner action:**
- Use one owned/test review case. Enter a unique instruction in the combined learning box, choose the intended scope/target classification, click `Approved for learning only`, then open a later similar owned/test inbound case and report whether the new draft follows that exact instruction.

**Next recommended owner:** Human

### 2026-06-28T21:52:11+00:00 — Codex — SL-PHASE-5Q11 review-link accessibility and corrected-classification fix

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Fix HumanApproval same-link accessibility after follow-up/send-again capture and ensure corrected classification is used for “this classification” draft-improvement targets.

**Case traced:**
- `case-6ebd0e3a`: production row status `FOLLOWUP_SEND_PENDING_MANUAL`; decision action `approve_and_send_followup`; previous status `RESPONSE_APPROVED`; controlled send key `case-6ebd0e3a|f2`; revision count `2`; repeat-send reason recorded as owner provided; token present and not printed.
- Current row stored correction evidence: broad category `INFORMATION_REQUEST`; corrected/effective micro intent `BOOKING_REQUEST`.
- Execution runData was unavailable through API for the target case, but row state and owner-observed Q2 result page matched the workflow path.

**Root cause:**
- HumanApproval token validators `H`/`L` did not include `FOLLOWUP_SEND_PENDING_MANUAL`, `FOLLOWUP_SEND_CAPTURED`, `MANUAL_SEND_REQUIRED`, `RESPONSE_SENT`, or `SAVED` as renderable same-link states.
- Render node `J` did not treat follow-up/manual-send-required states as sent-style states.
- Draft-improvement target classifications preserved original checkbox values even when human classification corrections made a different corrected/effective classification.

**Fix summary:**
- Patched HumanApproval nodes `H`, `L`, `J`, `N`, and `SL-P2A` only.
- Same review link now renders until token expiry for save, blocked, learning-only, sent, response-sent, follow-up captured, and manual-send-required states.
- Manual-send-required banner persists with controlled send key and repeat-send reason.
- Duplicate follow-up capture button is disabled while manual-send-required is pending.
- Follow-up capture stores latest learning/corrections plus `manual_send_required` and `same_review_link_retry`.
- Learning candidates now preserve original classification, corrected/effective classification, and target classification used; “this classification” targets are rewritten to corrected/effective classification.

**Harness results:**
- 5Q11 Python: `24/24 PASS`
- 5Q11 PowerShell: `24/24 PASS`
- 5Q10 Python/PowerShell: `22/22 PASS`
- 5Q9 Python/PowerShell: `21/21 PASS`
- 5Q8 render Python/PowerShell: `22/22 PASS`
- 5R-prep Python/PowerShell: `17/17 PASS`

**Production apply:**
- Production guard passed before API write.
- Backup directory: `backups/sl-phase-5q11-review-link-accessibility-20260628T215136Z`
- HumanApproval `50d77bbb-546f-4a85-8902-4ead1c3776b4` -> `d3449764-b059-48be-b73a-8a9beae443ea`, active preserved `true`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- No Sender execution or Instantly POST was caused by the patch; latest Sender execution remained `3141`, started before the apply.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q11-review-link-accessibility-and-corrected-classification.py`
- `scripts/SL-PHASE-5Q11-review-link-accessibility-and-corrected-classification.ps1`
- `reports/SL-PHASE-5Q11_REVIEW_LINK_ACCESSIBILITY_AND_CORRECTED_CLASSIFICATION.md`
- `reports/SL-PHASE-5Q10_REVIEW_FORM_CONTRACT_AND_BLOCKED_STATE.md`
- `reports/SL-PHASE-5Q9_BLOCKED_SEND_LINK_DIAGNOSTICS_LEARNING_SOURCE.md`
- `OPERATION_HANDOFF.md`

**Next owner action:**
- Reopen the same `case-6ebd0e3a` review link once. Confirm the review form renders, the approved/sent banner remains visible, and the manual-send-required banner shows the controlled send key. Stop before clicking any submit button.

**Next recommended owner:** Human

### 2026-06-28T17:24:43+00:00 — Codex — SL-PHASE-5Q10 review-form contract and blocked-state fix

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Fix only the HumanApproval UI/backend contract mismatch where a blank sent-style reply blocked with hidden/misleading `repeat_send_reason_required` and removed the already-approved/sent banner.

**Files inspected:**
- `OPERATION_HANDOFF.md`
- `reports/SL-PHASE-5Q9_BLOCKED_SEND_LINK_DIAGNOSTICS_LEARNING_SOURCE.md`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.py`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.ps1`

**Root cause:**
- `repeat_send_reason` existed in the form but was hidden by `display:none` with no reveal script.
- `approve_and_send_followup` did not independently map blank reply text to `draft_text_required`.
- normal approve/send blank draft reused stale blocked-variable state.
- blocked sent-style submits changed status to `IN_REVIEW`, removing the already-approved/sent banner on reopen.
- learning-only allowed both blank reply text and blank learning instruction.

**Fix summary:**
- Patched HumanApproval nodes `J. Render Review Form HTML` and `N. Process Reviewer Decision` only.
- Visible repeat-send field label: `Reason for sending another reply`.
- Blank reply text now blocks with `draft_text_required`.
- Repeat-send reason blocks with `repeat_send_reason_required` only for the visible repeat-send field.
- Learning-only with blank draft is allowed only when learning instruction is non-empty; if both are blank, it blocks with `learning_instruction_required`.
- Blocked-attempt banner now renders above, not instead of, the already-approved/sent banner.
- Same-link retry, token stability, editable state, no-send behaviour, and no duplicate Sender/Instantly semantics preserved.

**Harness results:**
- 5Q10 Python: `22/22 PASS`
- 5Q10 PowerShell: `22/22 PASS`
- 5Q9 Python: `21/21 PASS`
- 5Q9 PowerShell: `21/21 PASS`
- 5Q8 render Python: `22/22 PASS`
- 5Q8 render PowerShell: `22/22 PASS`
- 5R-prep not run because Sender/idempotency path was not changed.

**Production apply:**
- Production guard passed before API write.
- Backup directory: `backups/sl-phase-5q10-review-form-contract-20260628T172409Z`
- HumanApproval `91060513-b41f-4b9d-9c25-f94935ae8bc7` -> `50d77bbb-546f-4a85-8902-4ead1c3776b4`, active preserved `true`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- No Sender execution started during/after the apply; latest Sender execution remained `3066` from `2026-06-28T16:40:37.296Z`.
- No Instantly POST was caused by this patch.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q10-review-form-contract-and-blocked-state.py`
- `scripts/SL-PHASE-5Q10-review-form-contract-and-blocked-state.ps1`
- `reports/SL-PHASE-5Q10_REVIEW_FORM_CONTRACT_AND_BLOCKED_STATE.md`
- `reports/SL-PHASE-5Q9_BLOCKED_SEND_LINK_DIAGNOSTICS_LEARNING_SOURCE.md`
- `OPERATION_HANDOFF.md`

**Next owner action:**
- Use one owned/test sent-style case that already shows the approved/sent banner. Reopen the review link, clear the reply textarea, leave `Reason for sending another reply` blank, click `Send another human-approved reply` once, screenshot the blocked page, reopen the same link, and confirm both banners are visible. Stop there.

**Next recommended owner:** Human

### 2026-06-28T16:57:06+00:00 — Codex — SL-PHASE-5Q9 Q2 blocked-page quote addendum

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Patch only HumanApproval node `Q2. Build Non-Send Terminal Result` raw blocked-page HTML attribute quotes before a fresh live blocked-send proof.

**Files inspected:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.py`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.ps1`

**Root cause / fix:**
- Q2 blocked-page strings had raw `style="..."` attribute quotes inside JavaScript double-quoted strings.
- Patched Q2 only to escape the blocked heading and correction div attributes.
- Preserved exact missing variable `repeat_send_reason_required`, correction instructions, same-link retry behaviour, editable blocked state, token stability, no-send behaviour, and no duplicate Instantly POST semantics.

**Harness results:**
- 5Q9 Python: `21/21 PASS`
- 5Q9 PowerShell: `21/21 PASS`
- 5Q8 render not run because shared render node `J` was not touched.

**Production apply:**
- Production guard passed before API write.
- Backup directory: `backups/sl-phase-5q9-q2-quote-escape-20260628T165553Z`
- HumanApproval `68f4b543-0004-4677-a95c-ba6768a8523c` -> `91060513-b41f-4b9d-9c25-f94935ae8bc7`, active preserved `true`.
- Changed node: `Q2. Build Non-Send Terminal Result` only.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.

**Sender / Instantly evidence:**
- Q2 apply did not trigger Sender.
- Latest Sender execution observed after apply was `3066`, started `2026-06-28T16:40:37.296Z`, before this Q2 apply; it reached `Q. POST Reply to Instantly (Gated)` and `X2. Build SENT Terminal Result`. Treat this as separate owner/live activity, not caused by the Q2 patch.

**Next owner action:**
- Use one fresh owned/test sent-style review case. Reopen it, click `Send another human-approved reply`, leave `Reason for sending a follow-up reply` blank, submit once, screenshot/report the blocked result page, then reopen the same review link and stop before any further submit.

**Next recommended owner:** Human

### 2026-06-28T15:53:39+00:00 — Codex — SL-PHASE-5Q9 blocked-send same-link repair

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q9-blocked-send-link-diagnostics-learning-source/20260628-152341`  
**Objective:** Trace `case-9b9197a4` and `case-8cba5975`, fix blocked-send/review-link issues, prove missing-variable messaging, check learning source, add a targeted 5Q9 harness, production-apply if clear, and return one owner action.

**Cases traced:**
- `case-9b9197a4`: Intake `2908`; HumanApproval create `2910`; render `2911`; save `2912`; render `2913`; learning-only `2914`; render `2915`; blocked `approve_and_send_followup` `2916`; same-link token-error renders `2917`, `2918`, `2924`, `2925`, `3042`.
- `case-8cba5975`: Intake `2920`; HumanApproval create `2922`; render `2923`; status `NEW`; no submit, Sender, retry link, duplicate send, or Instantly POST found in targeted trace.

**Root cause:**
- `case-9b9197a4` submitted `approve_and_send_followup` with missing `repeat_send_reason`.
- Node `N` stored exact internal missing variable `repeat_send_reason_required` in `decision_payload.blocked_variables`, saved edited draft/learning, and did not route to Sender.
- Node `Q2` displayed `rc.blocked_variables`, which was empty, producing `missing required variables ()`.
- Node `N` set status `BLOCKED_MISSING_VARIABLES`; token validators `H`/`L` treated that status as terminal and returned `ALREADY_DECIDED`.
- Token hash evidence showed the token did not mutate; same stored/submitted token hash prefix appeared before and after the block.

**Fix summary:**
- Patched only HumanApproval nodes `H`, `L`, `N`, `Q2`, `R-GenToken`, `R2`, `R3`, `R5`.
- Missing-variable blocked submits now keep the case editable as `IN_REVIEW`, preserve token, save draft/learning fields, record `sent=false`, and show exact missing variables plus correction steps.
- Existing `BLOCKED_MISSING_VARIABLES` rows are allowed to reopen on the same token.
- Recoverable blocked-send path preserves the same token/link and no longer issues a new retry token/link.
- Sender workflow was not changed.

**Learning source evidence:**
- HumanApproval learning-only created a `style` proposed-shadow candidate from `case-9b9197a4` with source case ID, human instruction, scope `current_micro_intent_only`, target classifications, improvement types, timestamp, and status.
- Decision consumes active behavioural policies from embedded `ACTIVE_BEHAVIOURAL_POLICIES`; those active rules are distinguishable by `source_case_id` / `activation_source`. Fresh form-created candidates do not affect Decision until activated/injected.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.py`
- `scripts/SL-PHASE-5Q9-blocked-send-link-diagnostics-learning-source.ps1`
- `scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.py`
- `reports/SL-PHASE-5Q9_BLOCKED_SEND_LINK_DIAGNOSTICS_LEARNING_SOURCE.md`
- `reports/SL-PHASE-5Q8_HUMANAPPROVAL_RENDER_REGRESSION.md`
- `reports/SL-PHASE-5Q7_AI_SOURCE_LABEL_AND_VALIDATION.md`
- `reports/SL-PHASE-5Q6_THREAD_AND_AI_FALLBACK_REPAIR.md`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `OPERATION_HANDOFF.md`

**Harness results:**
- 5Q9 Python/PowerShell: `21/21 PASS`
- Post-production-export sync rerun: 5Q9 Python `21/21 PASS`; 5Q8 render Python `22/22 PASS`; 5Q7 labels Python `17/17 PASS`; 5Q5 save/reopen Python `34/34 PASS`; 5R-prep idempotency/token Python `17/17 PASS`; 5R-prep PowerShell `17/17 PASS`

**Production apply:**
- Production guard passed before API operations.
- Backup directory: `backups/sl-phase-5q9-blocked-send-link-diagnostics-learning-source-20260628T155013Z`
- HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9` -> `68f4b543-0004-4677-a95c-ba6768a8523c`, active preserved `true`.
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`.
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`.
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`.
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`.
- Latest Sender executions after apply remained old `2762`, `2760`, `2740`; no Sender/live send was triggered.

**Safety:**
- No Instantly API call, Google Chat webhook call, live send, autonomous activation, Gate 2 work, or VPS/SSH.
- `approve_and_send_followup` automated send remains disabled/manual-pending.
- Owner-authenticated same-link reopen remains pending, so verdict is PARTIAL and status remains 88%.

**Commands run:**
- Targeted `sed`/`rg`/Python JSON node reads for required docs, reports, and affected workflow nodes.
- `pwsh -File ./scripts/assert-hmz-production-target.ps1` before n8n API operations.
- Guarded n8n API GET executions/workflows for the two case IDs and post-apply metadata.
- Guarded n8n API PUT for HumanApproval only.
- Targeted harnesses listed above.

**Risks / do-not-repeat:**
- Do not re-click approve/send in Codex. Owner-only live proof remains one authenticated same-link reopen.
- Do not start SL-PHASE-5R full automated send audit in this 5Q9 scope.
- Do not re-apply old Decision active rule patches.

**Next owner action:**
- Open the same `case-9b9197a4` review link while authenticated and confirm it renders as an editable review form. Stop before Save, learning-only, approve/send, deny, or follow-up submission.

**Next recommended owner:** Human

### 2026-06-28T05:20:50+00:00 — Codex — SL-PHASE-5Q8 HumanApproval render regression repaired

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q8-humanapproval-render-regression/20260628-050738`  
**Objective:** Trace `case-c3341a17`, identify why accepted AI review rendering failed at HumanApproval node `J`, patch the smallest renderer defect, verify harnesses, production-apply safely, and return the next owner action.

**Live case traced:**
- Case ID: `case-c3341a17`
- Intake execution: `2893`, success, `2026-06-28T04:48:04.143Z`
- Decision execution: `2894`, success, `2026-06-28T04:48:04.463Z`
- HumanApproval create: `2895`, success, `2026-06-28T04:48:07.667Z`
- HumanApproval render failures: `2896`, `2898`, both failed at node `J. Render Review Form HTML`
- Error Handler: `2897`, `2899`, both reported `UNKNOWN_ID`
- Sender: no new execution; latest remained old `2762`

**Evidence:**
- Intake hydrated the reply and used the SL-PHASE-5Q6 alternate thread mapping source `unibox_url_thread_search`.
- Source/from: `hamzahzahid3@gmail.com`; sender: `hamzah@onehmzautomation.com`; subject: `Re: Capacity Question`.
- Reply: `Could you explain what the setup process would look like before we decide whether a call makes sense?`
- Decision classified `INFORMATION_REQUEST / OFFER_EXPLANATION`.
- Decision provider call succeeded: `provider=openai`, `model=gpt-5.4-mini`, `ok=true`, raw AI draft present.
- Final draft source: `ai_supervised`; draft policy: `AI_SUPERVISED_OR_TEMPLATE`; draft text non-empty.
- HumanApproval create persisted a normal `NEW` review case and Google Chat showed `Draft mode: AI-generated draft for human review`.
- Render lookup and token validation passed for `case-c3341a17`; node `J` then failed with `Unexpected identifier 'background'`.
- Error Handler collapsed the failure to `UNKNOWN_ID` because node `J` failed before normal case-aware render output.

**Root cause:**
- Category A: JavaScript/HTML escaping defect.
- 5Q7 source/banner render logic inserted unescaped HTML attributes inside JavaScript strings, e.g. `html += "<p style="background...`.
- The same injected block had unescaped editable textarea attributes.
- The accepted `ai_supervised` branch was not covered by a compile-string regression check in the 5Q7 harness.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q8-humanapproval-render-regression.py`
- `scripts/SL-PHASE-5Q8-humanapproval-render-regression.ps1`
- `reports/SL-PHASE-5Q8_HUMANAPPROVAL_RENDER_REGRESSION.md`
- `reports/SL-PHASE-5Q7_AI_SOURCE_LABEL_AND_VALIDATION.md`
- `reports/SL-PHASE-5Q6_THREAD_AND_AI_FALLBACK_REPAIR.md`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Fix summary:**
- Patched only HumanApproval node `J. Render Review Form HTML`.
- Escaped 5Q7 banner attributes for human-only, commercial AI, safe fallback, and accepted AI branches.
- Escaped nearby textarea attributes.
- Preserved accepted AI banner/source logic, fallback banner/reason logic, Save/reopen persistence, missing-context diagnostics, learning UI, and Sender gating.

**Harness results:**
- 5Q8 Python: `22/22 PASS`; PowerShell: `22/22 PASS`
- 5Q7 Python/PowerShell: `17/17 PASS`
- 5Q6 Python/PowerShell: `24/24 PASS`
- 5Q5 Python/PowerShell: `34/34 PASS`
- 5Q4 Python/PowerShell: `26/26 PASS`
- 5Q3 Python/PowerShell: `30/30 PASS`
- 5Q2 Python/PowerShell: `27/27 PASS`
- 5R-prep Python/PowerShell: `17/17 PASS`
- Post-production-export sync rerun: 5Q8 Python/PowerShell `22/22 PASS`, 5Q7 Python `17/17 PASS`, 5Q4 Python `26/26 PASS`

**Production apply:**
- Production target guard passed before API operations.
- Backup directory: `backups/sl-phase-5q8-humanapproval-render-regression-20260628T051752Z`
- Pre-apply production/local drift: only `J. Render Review Form HTML`.
- HumanApproval changed only: `J. Render Review Form HTML`
- HumanApproval `4b18ec1b-a821-42a0-bc46-06e7ebe81599` -> `34531128-5ff6-4538-8846-bbbc5888a7a9`, active preserved `true`
- Decision unchanged `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Unexpected drift: NONE.
- First PUT attempt was rejected before update because `tags` is read-only; no-tags payload succeeded.

**Live recheck status:**
- Codex attempted one render-only GET for `case-c3341a17` after apply.
- GET returned HTTP `401` before workflow execution because review Basic Auth is required and no Basic Auth credential is available in the allowed env vars.
- Post-attempt execution check showed HumanApproval latest still `2898`, Error Handler latest still `2899`, and Sender latest still old `2762`.
- Owner-authenticated live reopen remains pending, so verdict is PARTIAL and status remains 88%.

**Safety:**
- No Save, learning-only, approve/send, deny, follow-up, Sender, Instantly send, autonomous activation, Gate 2 work, or VPS/SSH.
- Render path remains disconnected from Sender and learning candidate creation.
- Wrong-token and unknown-case blocking remain harness-proven.
- `approve_and_send_followup` auto-send remains disabled.

**Next owner action:**
- Reopen the same `case-c3341a17` review link from Google Chat while authenticated.
- Confirm the form renders normally with incoming reply, non-empty AI draft, `Draft source: ai_supervised`, and banner `AI-generated draft for human review. Edit before approving.`
- Stop before Save, `Approved for learning only`, `Approve and send`, deny, or any follow-up action.
- If the same link is expired, create one fresh varied setup reply: `Could you walk me through what the setup would involve before we decide whether it is worth booking a call?`

**Next recommended owner:** Human

### 2026-06-28T04:40:14+00:00 — Codex — SL-PHASE-5Q7 AI source label and validation repaired

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q6-thread-and-ai-fallback-repair/20260628-050358`  
**Objective:** Trace `case-f67601bc`, explain `ai_failed_fallback`, fix over-strict validation and misleading fallback labelling, verify harnesses, and production-apply safely.

**Live case traced:**
- Case ID: `case-f67601bc`
- Intake execution: `2882`, success, `2026-06-28T04:25:14.910Z`
- HumanApproval create: `2884`
- HumanApproval render: `2886`
- HumanApproval save-only: `2887`
- HumanApproval reopen: `2888`
- Sender: no execution contained `case-f67601bc`

**Evidence:**
- Thread hydration correct: Instantly email hydration returned HTTP 200 with canonical thread id and RFC message id.
- Classification: `INFORMATION_REQUEST / OFFER_EXPLANATION`
- Draft source: `ai_failed_fallback`
- OpenAI provider call attempted and succeeded in Decision output: provider `openai`, model `gpt-5.4-mini`, `ok=true`, no provider error, raw AI draft present.
- Post-validation rejected AI output with `active policy violation: dense paragraph`; fallback reason `AI_OUTPUT_VALIDATION_FAILED`.
- Fallback text was good/policy-aware: natural opener, setup answer before CTA, numbered list, no validation/proof/case-study/results/pricing/guarantee claims.
- HumanApproval form banner was misleading: it said normal `AI-assisted draft for human review` for `ai_failed_fallback`.

**Root cause:**
- Decision dense-paragraph validator split only on blank lines, so a safe numbered-list AI draft with single-newline list structure could be treated as one dense paragraph.
- HumanApproval node J grouped `ai_failed_fallback` with normal AI-assisted drafts instead of showing fallback-specific wording/reason.

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q7-ai-source-label-and-validation.py`
- `scripts/SL-PHASE-5Q7-ai-source-label-and-validation.ps1`
- `reports/SL-PHASE-5Q7_AI_SOURCE_LABEL_AND_VALIDATION.md`
- `reports/SL-PHASE-5Q6_THREAD_AND_AI_FALLBACK_REPAIR.md`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Fix summary:**
- Decision D dense-paragraph validation is now list-aware: list-structured drafts are checked by max line length/overall bound, while non-list dense paragraphs remain rejected.
- HumanApproval D/J now display normal AI-generated drafts separately from safe fallback drafts.
- Fallback review form shows `Draft source` and safe `Fallback reason` category without secrets.

**Harness results after post-apply export sync:**
- 5Q7 Python: `17/17 PASS`; PowerShell: `17/17 PASS`
- 5Q6 Python: `24/24 PASS`; PowerShell pre-apply: `24/24 PASS`
- 5Q5 Python: `34/34 PASS`; PowerShell pre-apply: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`; PowerShell pre-apply: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`; PowerShell pre-apply: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`; PowerShell pre-apply: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`; PowerShell pre-apply: `17/17 PASS`

**Production apply:**
- Production target guard passed before API writes.
- Backup directory: `backups/sl-phase-5q7-ai-source-label-validation-20260628T043853Z`
- Decision changed only: `D. Draft Preparation (Templates / Human Draft)`
- HumanApproval changed only: `D. Build Google Chat Notification Payload`, `J. Render Review Form HTML`
- Decision `676c83ad-ebbd-4dd6-a204-b48245e061bc` -> `71ec8fdd-4bb4-4537-a2fd-3d97d03f19a8`, active preserved `true`
- HumanApproval `4caf621f-cda5-4aca-84a7-e1b521e99c7c` -> `4b18ec1b-a821-42a0-bc46-06e7ebe81599`, active preserved `true`
- Intake unchanged `abc83e43-9b97-4ca1-ae32-c42599255328`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Unexpected drift: NONE.

**Safety:**
- No approve/send clicked by Codex.
- No learning-only action clicked by Codex.
- Sender was not triggered; latest Sender executions remained older pre-existing runs.
- Instantly API was not called directly by Codex.
- Google Chat webhook was not called directly by Codex.
- VPS/SSH not used.
- Shadow Evaluator remains inactive; Gate 2 not approved; live autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled.

**Next owner action:**
- Create one new seeded owned/test prospect reply in the existing active campaign thread:
  `Could you explain what the setup process would look like before we decide whether a call makes sense?`
- Inspect the Google Chat card and review form only. Confirm source/banner consistency and draft behaviour.
- Stop before `Approved for learning only` or `Approve and send`.

**Next recommended owner:** Human

### 2026-06-28T04:15:00+00:00 — Codex — SL-PHASE-5Q6 thread hydration and AI fallback repaired

**Agent:** Codex  
**Branch:** `agent/codex/phase-5q6-thread-and-ai-fallback-repair/20260628-050358`  
**Objective:** Trace `case-f54aff79` missing `thread_id`, trace `ai_failed_fallback` on hydrated cases, patch minimal Intake/Decision workflow defects, verify Save/reopen evidence, run harnesses, and production-apply safely.

**Live cases traced:**
- `case-f54aff79`: Intake execution `2864`; HumanApproval create/render `2866`, `2867`, `2868`.
- `case-495332d8`: Intake execution `2869`; HumanApproval create/render/save/reopen `2871`-`2875`.
- `case-535d430a`: prior Intake `2835`; post-5Q5 reopen evidence `2862`.

**Root causes:**
- `case-f54aff79` root cause category B: `thread_id` existed under an alternate Instantly Unibox query key. Top-level `thread_id` was absent and email hydration returned `404 Email not found`, but `unibox_url` contained `thread_search=thread:<id>`. Intake did not extract it, so HumanApproval diagnostic blocking was correct under old data but over-strict relative to available safe evidence.
- `ai_failed_fallback` root cause: not provider outage. Decision showed OpenAI provider `openai`, model `gpt-5.4-mini`, `ok=true`, no provider error, and raw AI draft text present. Post-validation rejected the AI draft and fell back to deterministic text. The fallback text did not consume active behavioural guidance strongly enough.

**Files changed:**
- `workflows/production_intake_current.json`
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json` (post-apply export sync only; no production HumanApproval delta)
- `scripts/SL-PHASE-5Q6-thread-and-ai-fallback-repair.py`
- `scripts/SL-PHASE-5Q6-thread-and-ai-fallback-repair.ps1`
- `reports/SL-PHASE-5Q6_THREAD_AND_AI_FALLBACK_REPAIR.md`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Fix summary:**
- Intake `C2. Merge Reply Hydration` now extracts `thread_id` from canonical hydrated email first, then from alternate Unibox URL query keys including `thread_search=thread:<id>`.
- Decision `D. Draft Preparation` now builds policy-aware fallback text using active behavioural policy guidance, answers setup before CTA, avoids validation/proof language unless asked, and emits safe `fallback_reason` metadata for provider/config/validation fallback categories.

**Harness results after post-apply export sync:**
- 5Q6 Python: `24/24 PASS`; PowerShell: `24/24 PASS`
- 5Q5 Python: `34/34 PASS`; PowerShell: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`; PowerShell: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`; PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`; PowerShell: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`; PowerShell: `17/17 PASS`

**Production apply:**
- Production target guard passed before API writes.
- Backup directory: `backups/sl-phase-5q6-thread-ai-fallback-20260628T041346Z`
- Intake changed only: `C2. Merge Reply Hydration`
- Decision changed only: `D. Draft Preparation (Templates / Human Draft)`
- Intake `bcfadfeb-e1a2-4924-b429-c522863c6708` -> `abc83e43-9b97-4ca1-ae32-c42599255328`, active preserved `true`
- Decision `a4dab823-a540-48e8-8df6-514eca5d060a` -> `676c83ad-ebbd-4dd6-a204-b48245e061bc`, active preserved `true`
- HumanApproval unchanged `4caf621f-cda5-4aca-84a7-e1b521e99c7c`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Unexpected drift: NONE.

**Save/reopen evidence:**
- `case-535d430a` execution `2862` reopened as `IN_REVIEW` with saved draft, combined learning instruction, revision types, improvement scopes, and target classifications persisted.
- No Sender execution contained `case-535d430a`; no learning-only/approval action was performed by Codex.

**Safety:**
- No approve/send clicked by Codex.
- No learning-only action clicked by Codex.
- Sender was not triggered; latest Sender executions remained older pre-existing runs.
- Instantly API was not called directly by Codex.
- Google Chat webhook was not called directly by Codex.
- VPS/SSH not used.
- Shadow Evaluator remains inactive; Gate 2 not approved; live autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled.

**Next owner action:**
- Create one new seeded owned/test prospect reply in the existing active campaign thread:
  `Before we go any further, can you explain what the setup would actually involve for our team?`
- Inspect the Google Chat card and review form only. Confirm it is hydrated and the draft/fallback answers setup before CTA without validation/proof/case-study/result language unless asked.
- Stop before `Approved for learning only` or `Approve and send`.

**Next recommended owner:** Human

### 2026-06-28T04:05:00+00:00 — Codex — SL-PHASE-5Q5 Save/reopen persistence fixed

**Agent:** Codex
**Branch:** `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`
**Objective:** Stop learning proof, trace failed Save/reopen for `case-535d430a`, patch minimal HumanApproval persistence/reload issue, add harness coverage, and production-apply.

**Live case:**
- Case ID: `case-535d430a`
- Save submit executions: `2853`, `2857`
- Reopen executions after save: `2854`, `2855`, `2858`
- Sender: no linked execution; recent Sender executions did not contain `case-535d430a`

**Root cause:**
- Category D: render reloaded original state.
- Save received `edited_reply_text`, `draft_learning_instruction`, multi-select `draft_revision_types`, multi-select `draft_improvement_scopes`, target classifications, and approver identity.
- Save persisted edited text in `final_reply_text` / `decision_payload.latest_saved_reply_text` and learning metadata in `decision_payload.latest_draft_learning`.
- Node `J. Render Review Form HTML` used original `rc.draft_text` for unsent cases, so reopened `IN_REVIEW` cases ignored saved state.
- Save also did not set `rc.approver_identity`, so approver identity was not preserved.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q5-save-reopen-persistence.py`
- `scripts/SL-PHASE-5Q5-save-reopen-persistence.ps1`
- `reports/SL-PHASE-5Q5_SAVE_REOPEN_PERSISTENCE.md`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Harness results:**
- 5Q5 Python: `34/34 PASS`
- 5Q5 PowerShell: `34/34 PASS`
- 5Q4 Python: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`

**Production apply:**
- Production target guard passed before API write.
- Backup directory: `backups/sl-phase-5q5-save-reopen-persistence-20260628T034300Z`
- HumanApproval changed only: `J. Render Review Form HTML`, `N. Process Reviewer Decision`
- HumanApproval `542f4159-fb6b-4dc4-9dda-f97657fbf7ac` -> `4caf621f-cda5-4aca-84a7-e1b521e99c7c`, active preserved `true`
- Decision unchanged `a4dab823-a540-48e8-8df6-514eca5d060a`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

**Safety:**
- No approve/send clicked by Codex.
- Sender was not triggered.
- Instantly API was not called.
- Google Chat webhook was not called directly by Codex.
- VPS/SSH not used.
- Token not mutated by Save path.
- Save does not create draft candidates while `final_action === "save"`.
- Shadow Evaluator remains inactive; Gate 2 not approved; live autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled.

**Next owner action:**
- Reopen `case-535d430a`.
- Edit/save the same draft and learning fields again.
- Click `Save draft and learning` only.
- Reopen the same link.
- Report whether edited draft, combined reason/instruction, improvement types, scope/target classifications, approver identity, and same-link access persisted.
- Do not click `Approved for learning only` or `Approve and send`.

**Next recommended owner:** Human

### 2026-06-28T03:55:00+00:00 — Codex — SL-PHASE-5Q4 HumanApproval UNKNOWN_ID/render defect fixed

**Agent:** Codex
**Branch:** `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`
**Objective:** Stop save/reopen proof, trace hydrated `case-535d430a`, root-cause HumanApproval `UNKNOWN_ID`/node J render failure, patch minimally, add harness coverage, and production-apply safely.

**Live case:**
- Case ID: `case-535d430a`
- Intake execution: `2835`, success, `2026-06-28T02:40:05.073Z`
- Decision execution: `2836`, success, `2026-06-28T02:40:05.657Z`
- HumanApproval create execution: `2837`, success, `2026-06-28T02:40:09.053Z`
- Error-handler executions: `2841`, `2842`
- Sender: no linked execution; latest Sender executions did not contain `case-535d430a`

**Evidence:**
- HumanApproval create built `case-535d430a`, status `NEW`, micro intent `OFFER_EXPLANATION`, draft source `ai_failed_fallback`, draft policy `AI_SUPERVISED_OR_TEMPLATE`, and a non-empty fallback draft.
- Data Table row id `67` was persisted with token.
- HumanApproval render executions `2839` and `2840` failed at `J. Render Review Form HTML` with `Unexpected identifier 'background'`.
- The `UNKNOWN_ID` Chat label was secondary/error-handler context; the actionable first failing node was node J syntax.

**Root cause:**
- HumanApproval node `J. Render Review Form HTML` contained malformed JavaScript in the 5Q3 diagnostic block: an inner `style="background...` quote was not escaped.
- This made the renderer fail compilation before any hydrated or diagnostic case could render.
- `case-535d430a` was hydrated but not renderable because the renderer code itself was invalid.

**Files changed:**
- `workflows/production_humanapproval_current.json`
- `scripts/SL-PHASE-5Q4-humanapproval-render-id-guard.py`
- `scripts/SL-PHASE-5Q4-humanapproval-render-id-guard.ps1`
- `reports/SL-PHASE-5Q4_HUMANAPPROVAL_RENDER_ID_GUARD.md`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Harness results:**
- 5Q4 Python: `26/26 PASS`
- 5Q4 PowerShell: `26/26 PASS`
- 5Q3 Python: `30/30 PASS`
- 5Q3 PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5Q2 PowerShell: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`

**Production apply:**
- Production target guard passed.
- Backup directory: `backups/sl-phase-5q4-humanapproval-render-id-guard-20260628T025225Z`
- HumanApproval changed only: `J. Render Review Form HTML`
- HumanApproval `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609` -> `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`, active preserved `true`
- Decision unchanged `a4dab823-a540-48e8-8df6-514eca5d060a`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

**Safety:**
- No approve/send clicked by Codex.
- Sender was not triggered.
- Instantly API was not called.
- Google Chat webhook was not called directly by Codex.
- VPS/SSH not used.
- Shadow Evaluator remains inactive; Gate 2 not approved; live autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled.

**Next owner action:**
- Reopen the same `case-535d430a` review link once and confirm whether the form renders normally.
- Do not click Save, learning-only, approve, or send yet.
- If the same link is expired or unsafe, create a new seeded owned/test prospect reply with: `Before we go any further, can you explain what the setup would actually involve for our team?`

**Next recommended owner:** Human

### 2026-06-28T03:35:00+00:00 — Codex — SL-PHASE-5Q3 corrected live retest Stage 1 verified; owner action pending

**Agent:** Codex
**Branch:** `agent/codex/phase-5q3-corrected-live-retest/20260628-032641`
**Objective:** Start the corrected post-5Q3 hydrated live retest, verify production/safety state, run cheap harnesses, and hand off the minimum next owner action.

**Files changed:**
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Production read-only verification:**
- Production target guard passed before n8n API use.
- HumanApproval `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`, active `true`
- Decision `a4dab823-a540-48e8-8df6-514eca5d060a`, active `true`
- Sender `dfb310f4-901a-4d76-81dc-8f5d4ad13552`, active `true`
- Proxy `d61050e6-dbc6-4fec-b404-3aad20a80e84`, active `true`
- Shadow Evaluator `ae13bf4e-ee04-438f-9657-3c57183b90a2`, active `false`
- Sender production workflow still has `DRY_RUN=true`, empty `LIVE_CAMPAIGNS`, and `LIVE_CREDENTIAL_READY=false`.
- HumanApproval contains `approve_and_send_followup` metadata path and `approve_learning_only`; no auto-send was enabled.

**Harness results:**
- 5Q3 Python: `30/30 PASS`
- 5Q3 PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5Q2 PowerShell: `27/27 PASS`
- 5R-prep was not run in this session because optional send/idempotency proof was not selected.

**Live proof status:**
- Corrected hydrated source case: PENDING owner action
- Save/reopen persistence: PENDING
- Learning-only/candidate activation: PENDING
- Later similar behavioural effect: PENDING
- Leakage control: PENDING
- Optional send/idempotency retest: PENDING / not requested

**Commands run:**
```bash
git switch -c agent/codex/phase-5q3-corrected-live-retest/20260628-032641
git status --short --branch
pwsh -File ./scripts/assert-hmz-production-target.ps1
python3 scripts/SL-PHASE-5Q3-intake-context-hydration-guard.py
pwsh -File ./scripts/SL-PHASE-5Q3-intake-context-hydration-guard.ps1
python3 scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.py
pwsh -File ./scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.ps1
read-only n8n API GET /workflows/{HumanApproval,Decision,Sender,Proxy,Shadow}
```

**Safety:**
- No production workflow updates.
- No Instantly API calls.
- No Google Chat webhook direct calls.
- No Sender trigger.
- No approve/send click.
- No candidate activation by Codex.
- No VPS/SSH use.
- Shadow Evaluator remains inactive; Gate 2 not approved; live autonomous sending disabled.

**Next owner action:**
- Use a seeded owned/test prospect already in the active Instantly campaign thread.
- Reply in the existing thread with: `Before we book anything, can you explain what your setup actually includes?`
- Confirm the Google Chat card is hydrated before opening the form: From not `UNKNOWN`, Sender not `? <?>`, reply excerpt present, broad category not blank/invalid, and review link present.
- If hydrated, open the form only and confirm incoming reply text, non-empty draft, normal-case approve/send availability, and visible learning UI.
- Do not click Save, learning-only, approve, or send until Codex records the case via read-only n8n evidence.

**Next recommended owner:** Human

### 2026-06-28T02:20:00+00:00 — Codex — SL-PHASE-5Q3 invalid blank/UNKNOWN case root-caused and guarded

**Agent:** Codex
**Branch:** `agent/codex/phase-5q2-postfix-live-retest/20260628-002222`
**Objective:** Stop the 5Q2 live retest after invalid `case-ed174cd6`, trace the blank/UNKNOWN case end-to-end, fix the workflow defect, and prevent missing-context cases from becoming normal review/send or learning cases.

**Bad live case:**
- Case ID: `case-ed174cd6`
- Intake execution: `2820`, success, `2026-06-28T01:44:14.290Z`
- Decision execution: `2821`, success, `2026-06-28T01:44:14.608Z`
- HumanApproval create execution: `2822`, success, `2026-06-28T01:44:14.845Z`
- HumanApproval form execution: `2823`, success, `2026-06-28T01:44:28.993Z`

**Root cause:**
- Workflow defect, not test setup.
- Intake/webhook had usable campaign, lead, subject, reply body, hydrated Instantly email, from/sender, and thread context.
- First missing point was Decision node `D. Draft Preparation (Templates / Human Draft)`, which returned `error: missing /`.
- Cause was malformed JavaScript literals in the 5Q2 active-policy validation patch: backspace word-boundary chars, broken newline regex, and real line breaks inside single-quoted strings.
- HumanApproval then built a normal-looking blank fallback review instead of a diagnostic blocked case.

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json` (post-export sync only; `active=false`)
- `scripts/SL-PHASE-5Q3-intake-context-hydration-guard.py`
- `scripts/SL-PHASE-5Q3-intake-context-hydration-guard.ps1`
- `reports/SL-PHASE-5Q3_INTAKE_CONTEXT_HYDRATION_GUARD.md`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Production apply:**
- Exact production guard passed before n8n API operations.
- Backups:
  - `backups/sl-phase-5q3-context-guard-apply-20260628T021021Z`
  - `backups/sl-phase-5q3-persisted-row-guard-apply-20260628T021242Z`
- Decision `a7d7c4cf-bc33-460e-95a4-63070490a9cf` -> `a4dab823-a540-48e8-8df6-514eca5d060a`, active preserved `true`
- HumanApproval `0ee1b410-94e1-4ffc-bcfe-c722af783839` -> `57c8c955-a157-4ee9-966d-ba1efed553fc` -> `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`, active preserved `true`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Changed nodes only:
  - Decision: `D. Draft Preparation (Templates / Human Draft)`
  - HumanApproval: `A. Build Review Case Record`, `D. Build Google Chat Notification Payload`, `J. Render Review Form HTML`, `N. Process Reviewer Decision`, `SL-P2A. Prepare Phase 1C+2 Capture Data`

**Harness results after post-apply export sync:**
- 5Q3 Python: `30/30 PASS`
- 5Q3 PowerShell: `30/30 PASS`
- 5Q2 Python: `27/27 PASS`
- 5Q2 PowerShell: `27/27 PASS`
- 5R-prep Python: `17/17 PASS`
- 5R-prep PowerShell: `17/17 PASS`
- Legacy 5Q Python: `41/41 PASS`
- Legacy 5Q PowerShell: `41/41 PASS`

**Safety:**
- No live email sent by Codex.
- Sender was not triggered by this run; latest execution page showed no Sender executions.
- Instantly API was not called by this run.
- Google Chat webhook was not called directly by this run.
- VPS/SSH not used.
- Shadow Evaluator remains inactive; Gate 2 not approved; autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled/pending full Sender audit.

**Next owner action:**
- Ignore `case-ed174cd6`; it is invalid proof.
- Use a seeded owned/test prospect already in the active Instantly campaign thread.
- Reply in the existing thread with: `Before we book anything, can you explain what your setup actually includes?`
- Confirm the Google Chat card is hydrated before opening the form: From not `UNKNOWN`, Sender not `? <?>`, Broad category not `UNKNOWN`, Micro intent set, Reply excerpt nonblank.
- Stop before approve/send and continue the Save/reopen proof only if hydrated.

### 2026-06-27T23:10:00+00:00 — Codex — SL-PHASE-5Q2 / 5R-prep production fix applied and verified

**Agent:** Codex
**Branch:** `agent/codex/phase-5q2-idempotency-behavioural-fix-20260627-224147`
**Objective:** Repair behavioural-policy effectiveness, review-form learning UX/persistence, and duplicate-submit retry/token safety after 5Q live proof failed.

**Files changed:**
- `workflows/production_decision_current.json`
- `workflows/production_humanapproval_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json` (post-export sync only; `active=false`)
- `scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.py`
- `scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.ps1`
- `scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.py`
- `scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.ps1`
- `reports/SL-PHASE-5Q2_BEHAVIOURAL_EFFECTIVENESS_REVIEW_UX_AND_IDEMPOTENCY_FIX.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- `OPERATION_HANDOFF.md`

**Root causes fixed:**
- Decision active behavioural guidance was advisory and contradicted by the `OFFER_EXPLANATION` instruction to state validation stage.
- Review form used single-select learning controls, redundant reason/future fields, and lacked Save on unsent cases.
- HumanApproval retry classifier ignored `SEND_OWNERSHIP_NOT_ACQUIRED`, prior terminal/in-flight state, and send-state gate failures, so duplicate successful-send submits rotated tokens and sent false retry messaging.

**Production apply:**
- Exact production guard passed before n8n API operations.
- Backup directory: `backups/sl-phase-5q2-production-apply-20260627T225600Z`
- HumanApproval `07895ef4-f177-41a0-954b-dcb67690a8ee` -> `0ee1b410-94e1-4ffc-bcfe-c722af783839`, active preserved `true`
- Decision `d1bc10e9-1a41-4cae-89cf-9ea38cdce2b0` -> `a7d7c4cf-bc33-460e-95a4-63070490a9cf`, active preserved `true`
- Sender unchanged `dfb310f4-901a-4d76-81dc-8f5d4ad13552`
- Proxy unchanged `d61050e6-dbc6-4fec-b404-3aad20a80e84`
- Shadow Evaluator unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`
- Drift check passed before PUT; only intended nodes changed.

**Harness results:**
- Existing 5Q Python: `41/41 PASS`
- Existing 5Q PowerShell: `41/41 PASS`
- New 5Q2 Python: `27/27 PASS`
- New 5Q2 PowerShell: `27/27 PASS`
- New 5R-prep Python: `17/17 PASS`
- New 5R-prep PowerShell: `17/17 PASS`

**Commands run:**
```bash
pwsh -File ./scripts/assert-hmz-production-target.ps1
python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
pwsh -File ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1
python3 scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.py
pwsh -File ./scripts/SL-PHASE-5Q2-behavioural-effectiveness-and-review-ux.ps1
python3 scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.py
pwsh -File ./scripts/SL-PHASE-5R-prep-send-idempotency-token-safety.ps1
curl GET /workflows/{HumanApproval,Decision,Sender,Proxy,Shadow}
curl PUT /workflows/{HumanApproval,Decision}
```

**Safety:**
- No live prospect/send test run.
- Sender was not triggered by this run.
- Instantly API was not called by this run.
- Google Chat webhook was not called by this run.
- VPS/SSH not used.
- Shadow Evaluator remains inactive; Gate 2 not approved; autonomous sending disabled.
- `approve_and_send_followup` auto-send remains disabled/pending full Sender audit.

**Risks / next owner action:**
- Verdict remains PARTIAL because post-fix live review-form/draft retest is pending.
- Human should run the updated post-fix retest: open review form, Save, reopen same link, confirm persistence, then inspect next similar draft before any send.
- Do not retry or use retry links for `case-a3e7b1d2`; treat the confirmed edited email as sent.

### 2026-06-27T22:31:00+00:00 — Codex — Original review link failure root-caused to duplicate retry token mutation

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** After owner confirmed the edited email was present but the same review form could not be accessed, identify why the form failed.

**Guard/API:**
- Exact production guard passed before API calls
- n8n API used read-only for executions `2759`, `2761`, and `2763`
- Review tokens and private URLs were not printed; token comparison was done by short digest only

**Evidence collected:**
- Execution `2759` approved `case-a3e7b1d2` with a valid original token and status `RESPONSE_APPROVED`
- Execution `2761` was a second duplicate submit with the same original token initially valid
- Execution `2761` then updated the case to `RETRY_NEEDED` with a different token
- Execution `2763` rendered the original/same review link as `WRONG_TOKEN` / HTTP `410`

**Assessment:** The owner should not be able to use the original review form anymore because the duplicate retry path mutated the case token after the successful send. That behaviour is unsafe/misleading for post-send review access and belongs in SL-PHASE-5R or a dedicated HumanApproval retry-token fix.

**Next owner action:** Do not use the original or retry review links for `case-a3e7b1d2`. Treat the sent email as complete and pause additional live send/retry clicks until the duplicate/retry defect is fixed or explicitly accepted.

### 2026-06-27T22:20:00+00:00 — Codex — SL-PHASE-5Q live edited approval exposed duplicate retry defect

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** After owner clicked `Approved and send` for `case-a3e7b1d2` and saw a blocked/new-link message, collect read-only n8n evidence and determine the next safe human action.

**Guard/API:**
- Exact production guard passed before API calls
- n8n API used read-only for executions `2759`, `2760`, `2761`, `2762`, `2763`
- Secrets, private retry tokens, and review URLs were not printed

**Evidence collected:**
- HumanApproval execution `2759`: success, started `2026-06-27T22:07:31.878Z`, owner submit action `approve`
- Sender execution `2760`: success, started `2026-06-27T22:07:32.099Z`
- Sender node `Q. POST Reply to Instantly (Gated)` returned HTTP `200`
- Sender node `X2. Build SENT Terminal Result` produced a sent terminal path
- Sender node `X. Persist SENT Result (hmz-send-state)` hit `409 UNKNOWN_STATE`
- HumanApproval execution `2761`: success, started `2026-06-27T22:07:35.098Z`, second duplicate submit for the same case
- Sender execution `2762`: success, duplicate/rerun blocked as `SEND_OWNERSHIP_NOT_ACQUIRED`; no Instantly POST occurred on the second attempt
- HumanApproval marked the duplicate block recoverable, set case status `RETRY_NEEDED`, and generated a retry notification
- Retry Chat webhook node `R4. POST Retry Chat Webhook` did not error and received a Google Chat message object back
- Retry notification incorrectly said the prospect did not receive a reply, despite the preceding HTTP `200`
- Retry notification generated a relative review path, not a full production review URL
- HumanApproval render execution `2763` returned `WRONG_TOKEN` / HTTP `410`

**Assessment:** First owner-approved edited reply appears to have sent; the blocked page came from a duplicate submit path and is misleading. This is a SL-PHASE-5R Sender/HumanApproval idempotency and retry-notification blocker, not a successful 5Q behavioural proof.

**Next owner action:** Do not click approve/send again for `case-a3e7b1d2`. Confirm the 23:07 BST edited reply in Instantly or the recipient inbox. Pause further live send clicks until the owner explicitly accepts the duplicate/retry risk or SL-PHASE-5R is completed.

### 2026-06-27T21:50:00+00:00 — Codex — SL-PHASE-5Q later similar live effect insufficient

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** After owner sent a later similar setup-question reply, find the new case/executions and verify whether Decision consumed the active behavioural policy.

**Evidence collected:**
- Owner sent later similar setup reply around 2026-06-27 22:41 BST
- Decision execution: `2750`, success, `2026-06-27T21:41:53Z`
- HumanApproval execution: `2751`, success, `2026-06-27T21:41:56Z`
- New review case: `case-a3e7b1d2`
- Classification: `INFORMATION_REQUEST` / `OFFER_EXPLANATION`
- Draft source/status: `ai_supervised` / `DRAFT_PENDING_REVIEW`
- Sender execution: none
- Shadow Evaluator execution: none

**Decision consumption evidence:**
- Execution workflow data contained active behavioural candidate `27293ea8-bc4c-444b-be08-3623c9bb942b`
- Execution workflow data contained the active behavioural guidance code/block and instruction text
- Direct AI prompt string was not exposed in n8n execution data, so runtime prompt inclusion is inferred rather than directly logged

**Observed draft:**
- Started with acknowledgement: `Absolutely, .` (partial/malformed)
- Still one dense main paragraph before signoff
- Still mentioned validation/public examples even though the prospect asked only about setup

**Result:** PARTIAL/FAILED-LIVE-EFFECT. Active policy availability is proven, and the draft showed weak partial effect, but the later similar case did not satisfy the behavioural requirements. Do not mark SL-PHASE-5Q complete.

**Next owner action:** Do not send this draft as-is. Reopen/edit `case-a3e7b1d2` to reinforce the same behavioural rule, preferably with tighter wording and no global overreach unless owner intentionally wants global. Record whether submitted fields persist on reopen.

### 2026-06-27T21:28:38+00:00 — Codex — SL-PHASE-5Q live source candidate activated globally

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** Guide live owner proof one step at a time, collect n8n evidence for source setup case, and activate the owner-approved global behavioural candidate.

**Live source case evidence:**
- Source case: `case-66062eda`
- Decision execution: `2727`
- HumanApproval create/render executions: `2728`, `2729`, `2731`
- HumanApproval submit execution: `2739`
- Sender execution from owner `approve`: `2740`
- Submitted action: `approve` (no `approve_learning_only` button existed in the form)
- Instantly POST result in Sender: HTTP `200 OK`; owner-approved reply sent at `2026-06-27T21:12:06Z`
- Sender post-send state persistence issue observed: `409 UNKNOWN_STATE` at node `X. Persist SENT Result (hmz-send-state)`; defer to SL-PHASE-5R

**Learning/candidate evidence:**
- Submitted learning fields were captured in HumanApproval submit body and preserved into `decision_payload.latest_draft_learning`
- Draft revision event was built and written
- Candidate/rule ID: `27293ea8-bc4c-444b-be08-3623c9bb942b`
- Candidate source event: `7c96a99f-4c06-47f3-990e-20b1d9855159`
- Candidate source case: `case-66062eda`
- Candidate status before activation: `proposed_shadow`
- Candidate scope chosen by owner: global / `all_ai_drafts`
- Embedded active policy scope after activation: `global_draft_policy`

**Activation apply:**
- Exact production guard passed before API operations
- Backup/payload directory: `backups/sl-phase-5q-live-activate-global-20260627T212709Z`
- Decision versionId: `646fe558-01b1-4e4b-8b84-bb4866bcbb91` -> `d1bc10e9-1a41-4cae-89cf-9ea38cdce2b0`
- Decision active state preserved: `true`
- Shadow Evaluator status read: `active=false`, versionId unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`
- Local `workflows/production_decision_current.json` and `workflows/disabled_autonomous_shadow_evaluator.json` synced to post-activation exports

**Checks run:**
```bash
pwsh -File ./scripts/assert-hmz-production-target.ps1
curl GET /workflows/tgYmY97CG4Bm8snI
curl PUT /workflows/tgYmY97CG4Bm8snI
curl GET /workflows/tgYmY97CG4Bm8snI
curl GET /workflows/aHzLtQiv6G8h1bqD
python3 ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
python3 -c "import json; ..."
```

**Verification result:**
- Decision D only changed
- Existing active rule IDs remained present exactly once
- No old active-rule set was re-applied
- Active behavioural candidate is present in `ACTIVE_BEHAVIOURAL_POLICIES`
- Python 5Q harness after activation: `41/41 PASS, 0 FAIL`
- JSON parse after activation: PASS

**Important caveat from live proof:**
- Owner reported reopened/expired form did not preserve unsent in-browser edits. n8n evidence showed no submit execution before the reopen, so this proves unsent browser state is not durable. Submitted learning fields did persist after final approval.

**Production/autonomous safety:**
- n8n API used: YES, guarded Decision GET/PUT and read-only execution/status checks
- Sender/live send touched: YES, by owner approval of `case-66062eda`; not by Codex
- Instantly send occurred: YES, owner-approved via Sender execution `2740`
- Autonomous/Gate 2: not touched, not approved
- Shadow Evaluator remains `active=false`
- VPS SSH: not used

**Result:** PARTIAL. Source learning capture and active global Decision policy are proven. Later similar-case behavioural effect and unrelated leakage checks remain pending.

**Next owner action:** Human sends a later similar setup-question reply to verify the global candidate changes the next draft. Then run leakage checks for pricing, not-now, unsubscribe, and ambiguous/detail.

### 2026-06-27T04:49:42+00:00 — Codex — SL-PHASE-5Q guarded production apply succeeded; live proof pending

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** Re-verify SL-PHASE-5Q local proof, run the exact PowerShell production guard, export/back up/compare production HumanApproval and Decision workflows, apply only safe 5Q deltas, confirm new versionIds and safety state, and update reports/handoff.

**Runtime/worktree checkpoint:**
- Current branch confirmed: `agent/codex/phase-5q/20260627-025313`
- Git required per-command `safe.directory` because the repo is owned differently in this WSL session
- `pwsh`, `python3`, `bash`, and `curl` available; `node` and `jq` unavailable
- `N8N_BASE_URL` and `N8N_API_KEY` present; values were not printed
- `N8N_BASE_URL` was the production UI base, so the documented `/api/v1` API path was derived from that env value after the exact guard passed
- Worktree still has substantial pre-existing modified/generated files under backups/outputs/verification/reports; unrelated changes were not reverted or inspected

**Files inspected:**
- `OPERATION_HANDOFF.md`
- `CLAUDE.md`
- `AGENTS.md`
- `README.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `scripts/assert-hmz-production-target.ps1`
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1`
- `scripts/SL-PHASE-5P-review-reopen-learning-amendments-consolidated.ps1` (PUT payload shape only)
- `scripts/SL-PHASE-5M-live-review-draft-reason-ui-repair.ps1` (PUT payload shape only)
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json`
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`

**Files changed:**
- `workflows/production_humanapproval_current.json` — synced to post-apply production export with versionId `07895ef4-f177-41a0-954b-dcb67690a8ee`
- `workflows/production_decision_current.json` — synced to post-apply production export with versionId `646fe558-01b1-4e4b-8b84-bb4866bcbb91`; Decision B/C preserved, Decision D has 5Q behavioural policy consumption plus existing active rule guidance
- `workflows/disabled_autonomous_shadow_evaluator.json` — synced to post-apply status export; remains `active=false`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — updated with production guard/export/apply/versionId evidence, comparison result, and PARTIAL status
- `OPERATION_HANDOFF.md` — current state, active tasks, and this session log updated
- Backup/generated artifacts under `backups/sl-phase-5q-production-apply-20260627T044425Z` — pre/post exports, clean PUT payloads, and PUT responses

**Commands/tests run:**
```bash
git -c safe.directory=/mnt/c/Users/Hamzah\ Zahid/Downloads/Claude/Instantly_Responder_Automation branch --show-current
git -c safe.directory=/mnt/c/Users/Hamzah\ Zahid/Downloads/Claude/Instantly_Responder_Automation status --short
for t in pwsh python3 bash curl node jq; do command -v "$t"; done
python3 ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
pwsh -File ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1
python3 -c "import json; ..."
pwsh -File ./scripts/assert-hmz-production-target.ps1
curl GET /workflows/9aPrt92jFhoYFxbs
curl GET /workflows/tgYmY97CG4Bm8snI
curl GET /workflows/aHzLtQiv6G8h1bqD
curl PUT /workflows/9aPrt92jFhoYFxbs
curl PUT /workflows/tgYmY97CG4Bm8snI
curl GET post-apply exports for HumanApproval, Decision, and Shadow Evaluator
```

**Harness/results:**
- Pre-apply Python harness: `41/41 PASS, 0 FAIL`
- Pre-apply PowerShell harness: `41/41 PASS, 0 FAIL`
- Pre-apply JSON parse: PASS for HumanApproval, Decision, and disabled Shadow Evaluator
- Exact production guard: PASS
- Post-export assertions: `22/22 PASS, 0 FAIL`
- Post-apply Python harness: `41/41 PASS, 0 FAIL`
- Post-apply PowerShell harness: `41/41 PASS, 0 FAIL`
- Post-apply JSON parse: PASS for HumanApproval, Decision, and disabled Shadow Evaluator

**Production versionIds:**
- HumanApproval: `9c71882f-a096-48a9-861a-37e5424035ae` -> `07895ef4-f177-41a0-954b-dcb67690a8ee`
- Decision: `85f51eb4-bf8f-4d17-9883-52d7c2f11225` -> `646fe558-01b1-4e4b-8b84-bb4866bcbb91`
- Shadow Evaluator: unchanged `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false`

**Comparison / safety notes:**
- The local Decision workflow was not safe to upload as-is because it contained unrelated B/C drift and would have removed existing `ACTIVE_RULE_GUIDANCE` and the `AI_COMMERCIAL_SUPERVISED` path.
- Codex generated clean PUT payloads from the current production exports. HumanApproval changed only the four 5Q learning/reopen nodes. Decision changed only node D.
- Existing active rule IDs remained present exactly once after apply; no duplicate active rules were introduced.
- `ACTIVE_BEHAVIOURAL_POLICIES` is empty by default; Decision consumes active/effective behavioural guidance only when owner-approved policies exist.
- `approve_and_send_followup` remains `FOLLOWUP_SEND_PENDING_MANUAL` with `sender_audit_required`.

**Production/n8n/Sender/autonomous:**
- n8n API used: YES, only guarded GET/PUT for HumanApproval and Decision plus guarded GET status for Shadow Evaluator.
- Instantly API used: NO
- Google Chat webhook used: NO
- Sender workflow touched or triggered: NO
- Live email sent: NO
- VPS SSH used: NO
- Gate 2 approved/enabled: NO
- Live autonomous sending enabled: NO
- Shadow Evaluator remains `active=false`

**Result:** PARTIAL. Production apply/versionId/safety verification succeeded, but live owner behavioural proof remains pending. Do not mark SL-PHASE-5Q COMPLETE until the owner runs the varied proof packet and confirms the case-759e58d7 -> case-d099e6f3 behavioural effect without leakage.

**Known remaining work:**
- Owner runs `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`
- Owner confirms reopened-form reason preservation in live review if needed
- SL-PHASE-5R remains separate and unstarted in this session

**Recommended next owner:** Human.

**Next prompt pointer:** Run/record SL-PHASE-5Q varied live owner proof from `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`. Do not start SL-PHASE-5R or Gate 2 unless owner explicitly changes scope.

### 2026-06-27T03:41:50+00:00 — Codex — SL-PHASE-5Q production apply blocked by missing pwsh

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** Continue from local SL-PHASE-5Q patch, re-verify local proof, run the exact production guard, export/compare/apply production workflows only if safe, confirm versionIds and safety state, and create/update the varied owner proof packet.

**Runtime/worktree checkpoint:**
- Current branch confirmed: `agent/codex/phase-5q/20260627-025313`
- `python3`, `bash`, and `curl` available; `pwsh`, `node`, and `jq` unavailable
- `N8N_BASE_URL` and `N8N_API_KEY` are present; values were not printed
- Worktree has substantial pre-existing modified/generated files; unrelated changes were not reverted or inspected

**Files inspected:**
- `OPERATION_HANDOFF.md`
- `CLAUDE.md`
- `AGENTS.md`
- `README.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md`
- `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`
- `scripts/assert-hmz-production-target.ps1`
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`

**Files changed:**
- `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md` — new varied owner live proof packet covering positive/setup, pricing, not-now, unsubscribe, ambiguous, and case-759e58d7 to case-d099e6f3 proof/non-leakage
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — added re-verification result, guard failure, production non-touch status, packet location, and blocked status
- `OPERATION_HANDOFF.md` — current state, active task status, and this session log updated

**Commands/tests run:**
```bash
git branch --show-current
git status --short
for t in pwsh python3 bash curl node jq; do command -v "$t"; done
python3 ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
python3 -m json.tool workflows/production_humanapproval_current.json
python3 -m json.tool workflows/production_decision_current.json
python3 -m json.tool workflows/disabled_autonomous_shadow_evaluator.json
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

**Harness result:** `41/41 PASS, 0 FAIL`

**JSON parse result:** PASS for HumanApproval, Decision, and disabled Shadow Evaluator workflow JSON.

**Production guard result:** FAILED before execution: `/bin/bash: line 1: pwsh: command not found`.

**Production/n8n/Sender:** Not touched. No n8n API, n8n MCP, production export, production import, Instantly API, Google Chat webhook, Sender trigger, live email, VPS SSH, autonomous activation, or Gate 2 operation occurred.

**Result:** BLOCKED. Local 5Q proof remains valid, and the varied live owner proof packet now exists, but production export/backup/compare/apply/versionId confirmation cannot proceed until the exact PowerShell guard can run.

**Known remaining work:**
- Run this from an environment with `pwsh`, `N8N_BASE_URL`, and `N8N_API_KEY`
- Re-run `pwsh -File ./scripts/assert-hmz-production-target.ps1`
- Export/back up current production HumanApproval and Decision workflows
- Compare production exports against local 5Q workflow JSON before applying
- Apply only safe SL-PHASE-5Q deltas, preserve active states, and confirm new HumanApproval/Decision versionIds
- Confirm Shadow Evaluator remains `active=false` and Sender/live/autonomous paths remain untouched
- Owner runs `docs/NEXT_MANUAL_TEST_PACKET_SL_PHASE_5Q_VARIED_LIVE_OWNER_PROOF.md`

**Recommended next owner:** Human or Claude Code/Codex in an environment with `pwsh`.

**Next prompt pointer:** Continue SL-PHASE-5Q production guarded apply from `agent/codex/phase-5q/20260627-025313`; do not start SL-PHASE-5R. First command must be `pwsh -File ./scripts/assert-hmz-production-target.ps1`; if it passes, export/back up and compare production HumanApproval/Decision before applying.

---

### 2026-06-27T03:28:20+00:00 — Codex — SL-PHASE-5Q local behavioural closure patch

**Agent:** Codex
**Branch:** `agent/codex/phase-5q/20260627-025313`
**Objective:** Implement the narrow SL-PHASE-5Q local repair for draft behavioural self-improvement: human draft edit → learning persistence/event → active/effective behavioural policy availability → Decision node consumption → improved future draft guidance; also verify reopened-form reason preservation and same-bridge classification amendment status.

**Runtime/worktree checkpoint:**
- Current branch confirmed: `agent/codex/phase-5q/20260627-025313`
- `pwsh`, `node`, and `jq` unavailable; `python3` and `bash` available
- Worktree already had many pre-existing modified/generated files under backups/outputs/verification/reports/workflows; unrelated changes were not reverted or edited
- No production n8n operation was attempted because `pwsh` is unavailable and `scripts/assert-hmz-production-target.ps1` could not run

**Files inspected:**
- `OPERATION_HANDOFF.md`
- `CLAUDE.md`
- `AGENTS.md`
- `README.md`
- `docs/HMZ_PRODUCTION_TARGET_GUARD.md`
- `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md`
- `docs/SELF_IMPROVEMENT_OPERATIONAL_RUNBOOK.md`
- `docs/REVIEW_REOPEN_LEARNING_AMENDMENTS_CONSOLIDATED_PATCH.md`
- `workflows/production_humanapproval_current.json`
- `workflows/production_decision_current.json`
- `workflows/disabled_autonomous_shadow_evaluator.json`

**Files changed:**
- `workflows/production_humanapproval_current.json` — added `latest_draft_learning` storage/prefill/preservation for reopened reviews; draft candidates now carry `behavioural_instruction`, `source_original_case_id`, and `requires_human_activation: true`
- `workflows/production_decision_current.json` — added empty `ACTIVE_BEHAVIOURAL_POLICIES` block and active/effective behavioural guidance matcher consumed by supervised AI prompt; no active rules injected
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — dependency-free local synthetic harness
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.ps1` — local-only PowerShell wrapper for owner execution where `pwsh` exists
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — root cause, evidence, test results, safety status, manual next steps
- `OPERATION_HANDOFF.md` — current state, active tasks, and this session log

**Commands/tests run:**
```bash
git status --short --branch
for t in pwsh node jq python3 bash; do command -v "$t"; done
python3 ./scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py
```

**Harness result:** `41/41 PASS, 0 FAIL`

**What was proved locally:**
- Human edit, revision reason/type, improvement scope, and target classifications are preserved
- Draft learning event/candidate carries original case ID and behavioural instruction
- Candidate remains `proposed_shadow` and requires human activation
- Active/effective behavioural policies are matched, de-duplicated, and consumed by Decision prompt guidance
- Similar future draft guidance is affected by the learned behaviour
- Pricing, objection/not-now, unsubscribe/not-interested, and different micro-intent scenarios are not affected by a micro-scoped rule
- Global policy applies only when explicitly scoped
- Reopened blank submit preserves prior human-entered draft-learning reason/type/scope/targets
- Classification amendment capture and proposed_shadow candidate creation still use the same HumanApproval self-improvement bridge; no parallel system added
- Shadow Evaluator remains `active=false`; autonomous config remains disabled; Sender/live send untouched

**Result:** PARTIAL. Local bridge repair is synthetically verified, but production import/versionId confirmation and live owner behavioural proof are still pending.

**Production/n8n/Sender:** Not touched. No n8n API, n8n MCP, Instantly API, Google Chat webhook, Sender trigger, live email, autonomous activation, or Gate 2 operation occurred.

**Known remaining work:**
- Owner/Claude Code must run production target guard in an environment with `pwsh`, import/apply the local workflow changes if approved, and confirm new HumanApproval/Decision `versionId`s
- Owner must run varied manual live tests, including the case-759e58d7 → case-d099e6f3 behavioural pattern and unrelated pricing/not-now/unsubscribe/ambiguous scenarios
- SL-PHASE-5R remains separate and unimplemented

**Recommended next owner:** Human or Claude Code for production guarded apply + live owner proof; Codex can review before apply.

**Next prompt pointer:** Apply/review SL-PHASE-5Q local patch from `agent/codex/phase-5q/20260627-025313`; run `pwsh -File ./scripts/assert-hmz-production-target.ps1` first, then apply to production only if guard passes, confirm versionIds, and run varied live behavioural proof. Do not start SL-PHASE-5R in the same session.

---

### 2026-06-27T14:30:00+00:00 — Claude Code — Documentation control files: CLAUDE.md + AGENTS.md

**Agent:** Claude Code
**Branch:** `main`
**Objective:** Documentation/control-file pass only. Create AGENTS.md. Rewrite CLAUDE.md to include all 11 required sections (project summary, source-of-truth order, current status snapshot, critical safety boundaries, workflow rules, branching/handoff, production/n8n rules, testing expectations, usage-efficiency rules, do-not-redo list, next recommended task). No application code, workflow, script, config, or test changes.

**Files inspected:**
- `OPERATION_HANDOFF.md` (lines 1–120)
- `CLAUDE.md` (existing, full)
- `AGENTS.md` (did not exist)

**Files changed:**
- `CLAUDE.md` — rewritten with 11 sections; all existing production-guard rules, safety rules, scope rules, and governance rules preserved; current status snapshot and do-not-redo list added
- `AGENTS.md` — created; covers source-of-truth order, Codex role, what Codex must not do, review/diff expectations, safety, testing, handoff, and high-priority task table

**Commands/tests run:** None (documentation-only session; no API calls, no MCP, no n8n operations, no test runner)

**Result:** COMPLETE. Both files written and consistent with OPERATION_HANDOFF.md CURRENT_STATE.

**Evidence:** File writes confirmed; no conflicts with CURRENT_STATE found.

**Risks/uncertainties:** None introduced. README.md not changed (no contradiction found).

**Do not repeat:** Do not rewrite CLAUDE.md or AGENTS.md again unless a project-status change requires it. Next agent should proceed directly to SL-PHASE-5Q.

**Recommended next owner:** Claude Code (SL-PHASE-5Q) or Human (manual reopen tests 2/3/4)

**Next prompt pointer:** Proceed with SL-PHASE-5Q self-improvement behavioural closure: audit learning persistence, active/effective policy creation, Decision policy consumption, and reopened-form reason persistence using cases case-759e58d7 and case-d099e6f3.

---

### 2026-06-27T12:00:00+00:00 — Claude Code — Documentation reconciliation after failed self-improvement live test

**Agent:** Claude Code
**Branch:** `main`
**Objective:** Documentation-only reconciliation patch. Record owner's live finding that draft behavioural self-improvement failed. Resolve SL-PHASE-5Q/5R naming conflict. Update status, pending work, and task list accordingly.

**Trigger / owner finding:**
- Owner ran a live quick self-improvement test.
- Source case: case-759e58d7 — owner improved AI draft by adding a natural opener ("Of course" / "Hey") and improving reply style.
- Comparison case: case-d099e6f3 — a later similar prospect email; new AI draft did not reflect the prior human improvement.
- Conclusion: draft-learning UI/capture/reopen is installed but the behavioural bridge is broken or missing. Missing link is likely: human edit → learning event write → approved/effective policy → Decision draft generation consumes policy.
- Reopened forms may also lose human-entered reasons (suspected, not confirmed).

**Phase naming conflict resolved:**
- SL-PHASE-5Q was used in two places with different meanings. Resolved:
  - **SL-PHASE-5Q** = self-improvement behavioural closure (immediate next technical blocker)
  - **SL-PHASE-5R** = Sender idempotency / approve_and_send_followup automated send audit (planned after or parallel to 5Q)

**Files changed:**
- `README.md` — Status table (draft behavioural row: PENDING → FAILED/UNPROVEN; approve_and_send_followup: 5Q → 5R); Known Pending Work reordered with 5Q as item 1, 5R as item 2; Next Recommended Step expanded with failure evidence.
- `OPERATION_HANDOFF.md` — CURRENT_STATE known failures updated (FAILED/UNPROVEN + evidence pair); ACTIVE_TASKS restructured (TASK-002 blocked, TASK-003 = SL-PHASE-5Q, TASK-004 = SL-PHASE-5R, TASK-005/006 shifted); this session log entry added.

**Commands/tests run:** none

**Code/workflow/script changes:** none

**Production changes:** none

**Risks / uncertainties:**
- Reopened-form reason preservation issue is suspected but not confirmed in code; SL-PHASE-5Q scope should verify this.
- Manual tests 2/3/4 status not changed (owner has not reported them complete).

**Next recommended owner:** Claude Code (SL-PHASE-5Q design and implementation) or human (manual tests 2/3/4)

---

### 2026-06-27T00:00:00+00:00 — Claude Code — Documentation: README + OPERATION_HANDOFF

**Agent:** Claude Code
**Branch:** `main`
**Objective:** Create stable README.md and initialise OPERATION_HANDOFF.md with real current state for safe GitHub storage and dual-agent (Claude Code + Codex) work. Documentation-only session.

**Starting context read:**
- `NEXT_SESSION_HANDOFF.md` (primary state source)
- `OPERATION_HANDOFF.md` (template — replaced)
- `README.md` (stale — replaced)
- `.gitignore` (verified)
- `git status --short`
- Lightweight secret-file name scan

**Files changed:**
- `README.md` — replaced stale early-build README with current-state overview (status table, warnings, agent workflow rules, folder structure, known pending work, next step)
- `OPERATION_HANDOFF.md` — replaced template with real current state (this file)

**Commands/tests run:**
```
git status --short
ls (top-level only)
Get-ChildItem -Recurse -File -Include ".env","*.pem","*.key","*secret*","*token*","*credential*" | Select-Object -First 50 FullName
```

**Result:** success (documentation only)

**Evidence:** NEXT_SESSION_HANDOFF.md is the authoritative state source (dated 2026-06-26, Phase 5P). README and OPERATION_HANDOFF now reflect Phase 5P completion state. No application code, workflow JSON, or scripts modified.

**Decisions made:**
- Stale README (reflected early-build 6-workflow inventory with wrong workflow IDs vs current 3-workflow + shadow architecture) was replaced entirely.
- OPERATION_HANDOFF template replaced with real state. No prior session log existed to preserve.
- Three token/credential-named files flagged but not read; listed in SECRET_OR_RISKY_FILES table.

**Risks / uncertainties:**
- `reports/LOCAL_RUNTIME_CREDENTI…` filename was truncated in PowerShell output; full name not confirmed. Owner should verify file contents before pushing to GitHub.
- README workflow table uses IDs from NEXT_SESSION_HANDOFF — confirmed against that doc but not verified against live n8n API this session (would consume usage).
- `.gitignore` excludes `outputs/` and `backups/` — confirm `git status` shows these excluded before push.

**Do not repeat:**
- Do not re-read archive/, backups/, or full workflow JSON for documentation purposes.
- Do not re-initialise OPERATION_HANDOFF from template.

**Recommended next owner:** Human (run pending manual tests) or Claude Code (design SL-PHASE-5Q)

**Next prompt:**
```markdown
Read OPERATION_HANDOFF.md and NEXT_SESSION_HANDOFF.md first.

Task: SL-PHASE-5Q — design and implement Sender idempotency audit.

Context: approve_and_send_followup (SL-PHASE-5P) captures metadata and sets
FOLLOWUP_SEND_PENDING_MANUAL status, but automated send is blocked pending a
Sender idempotency audit. The Proxy/Sender workflows must be verified to handle
repeat-send for a previously RESPONSE_APPROVED case without duplicating sends.

Focus: scope the Sender node changes needed, run harness, apply to production
HumanApproval workflow. Do not touch Decision node or Shadow Evaluator.

Before any n8n operation: run scripts/assert-hmz-production-target.ps1.
Do not use n8n-mcp unless a specific bounded schema question cannot be
answered from local workflow JSON.

Also needed (separate concern, lower priority): investigate draft behavioural
self-improvement gap. Source case: case-759e58d7. Comparison case: case-d099e6f3.
Trace: human edit → learning event write → active policy creation → Decision node
policy consumption. Identify the missing or broken bridge.
```
