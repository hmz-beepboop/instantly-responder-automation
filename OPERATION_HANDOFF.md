# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

---

## 2026-07-04 — SL-PHASE-5Q Decision Classification + GAP-3b Repair (PARTIAL → pending Variant C)

**Agent:** Claude Code (claude-sonnet-4-6)  
**Objective:** FIX-1 booking/pricing classification correction; FIX-3 NOT_NOW style rule consumption (GAP-3b).

**Files changed:**
- `workflows/production_decision_current.json` — updated from production (versionId `937488a9`)
- `workflows/nodeD_backup_a3916c2e_pre_5q_session4.json` — backup before patch
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 89/89 → 119/119 (+30 new P7+P8 tests)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — session 4 patches documented
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — session 4 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — session 4 verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `a3916c2e` | `937488a9` | FIX-1 booking regex, FIX-2 pricing regex, FIX-3 GAP-3b NOT_NOW consumer |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Root causes fixed:**
- FIX-1: Section B `detectMicroIntent` BOOKING_REQUEST regex didn't match `walkthrough`/`demo`/`tour`/`meeting`. Extended: `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`. Same fix applied to `_5qReplyHasBookingIntent` in Section D.
- FIX-2: Section B `detectMicroIntent` PRICING_REQUEST regex didn't match `commitment`/`retainer`. Extended with those terms.
- FIX-3 (GAP-3b): `_5qApplyActiveFormRuleInstructionToDraft` had no NON_PRIORITY/NOT_NOW handler. Added: when cdada69d guidance active + "check back/when would be/better time" signal present, replaces "I'll close the loop" with "When would be a good time to check back in?"

**Harness:** 119/119 PASS (was 89/89). P7 (booking/pricing classification 12 tests) + P8 (NOT_NOW style 18 tests) added.

**Remaining:** Owner Variant C live retests required — booking, pricing/commitment, not-now, setup/process regression.

---

## 2026-07-04 — SL-PHASE-5Q Live Regression Repair (PARTIAL)

**Agent:** Claude Code (claude-sonnet-4-6)  
**Objective:** Repair Node J review form regression; triage Variant B live results; update harness.

**Files changed:**
- `workflows/production_humanapproval_current.json` — Node J restored from 0fa9d0ce lineage; pushed to production
- `workflows/nodeJ_backup_pre_live_regression_repair.json` — backup of 54b7a8e4 Node J before repair
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 66/66 → 89/89 (P5 + P6 sections added)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — created (Variant B execution trace + root causes)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — updated to PARTIAL + session 3 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — updated with session 3 Variant B verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `54b7a8e4` | `849c2c64` | Node J regression repair (modern UI restored) |

**Decision unchanged.** No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Node J regression root cause confirmed:**  
Previous session patched Node J using stale `9c71882f` as base instead of modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced. `draft_learning_instruction` field and `Save draft and learning` button lost.

**Node J repair:** Surgically replaced from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce). Modern UI confirmed: `draft_learning_instruction`, `Why did you make this change, and what should the system do next time?`, `Save draft and learning`, `Approved for learning only`. Old fields removed. Other nodes (H, L, N, Q2, SL-P2A) preserved.

**Harness: 89/89 PASS** (was 66/66; added P5 Node J regression + P6 Variant B structural sections).

**Variant B live triage (all cases confirmed against a3916c2e):**

| Case | Exec | Classification | Rule applied | Verdict | Root cause |
|------|------|---------------|-------------|---------|-----------|
| Booking | 4846 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 97eb3b0a | FAIL | AI misclassification |
| Setup/process | 4855 | OFFER_EXPLANATION (correct) | 48e10cac | PASS | — |
| Not-now | 4859 | AMBIGUOUS→NON_PRIORITY (correct) | cdada69d eligible but not consumed | FAIL | GAP-3b: NOT_NOW post-processor gap |
| Pricing | 4865 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 493884ad | FAIL | AI misclassification |

**Remaining gaps requiring next session:**

1. **GAP-3b:** cdada69d post-processing not implemented for NOT_NOW/FIXED_TEMPLATE path. Draft says "close the loop" — needs "when to check back" question. Requires narrow Decision patch to NOT_NOW style rule consumer.

2. **Classification correction for booking/pricing:** Booking walkthrough requests and minimum-commitment questions misclassified as OFFER_EXPLANATION. Recommended fix: add classification correction rules (similar to 6e50fd54 pattern) for BOOKING_REQUEST and PRICING_REQUEST signals within OFFER_EXPLANATION context.

**Recommended next actions (owner):**
1. Verify review form renders modern UI (no `draft_revision_type` dropdown, yes `Save draft and learning` button).
2. Next Claude Code session: patch GAP-3b (NOT_NOW post-processor for cdada69d style guidance).
3. Decide booking/pricing classification fix approach (correction rules recommended).
4. Fresh live retest after Decision patch.

---

## 2026-07-04 — SL-PHASE-5Q Self-Improvement Behavioural Closure (COMPLETE)

**Agent:** Claude Code (claude-sonnet-4-6)  
**Objective:** Root-cause all self-learning behavioural failures; create harness; patch all 4 gaps.

**Files changed:**
- `reports/SL-PHASE-5Q_BASELINE_EVIDENCE_RECONCILIATION.md` — created (session 1), unchanged (session 2)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — created (session 1); updated to COMPLETE + patch status (session 2)
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — created (session 1); updated post-patch verdicts (session 2)
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — created 44/44 (session 1); updated to 66/66 with P1-P4 post-patch tests (session 2)
- `workflows/nodeD_backup_889e1d45.js` — backup of Decision Node D before patch
- `workflows/nodeD_patched.js` — patched Decision Node D (all 4 gaps, pushed to production)
- `workflows/production_decision_current.json` — updated from production (versionId `a3916c2e`)
- `workflows/production_humanapproval_current.json` — updated from production (versionId `54b7a8e4`)
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` | GAP-1, GAP-2, GAP-3 |
| HumanApproval | `9aPrt92jFhoYFxbs` | `0fa9d0ce` | `54b7a8e4` | GAP-4 |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Patches applied (Decision Node D, versionId a3916c2e):**

- **GAP-1 (booking post-processor):** `_5qApplyActiveFormRuleInstructionToDraft` now detects `instructionUrl`. If URL present → email-content mode (extract booking link). If no URL and instruction matches constraint pattern (`replace the previous|do not ask|do not say|do not use`) → policy-constraint mode: renders template without pasting instruction meta-phrases as email lines. Eliminates hyper-literal booking draft from 97eb3b0a.

- **GAP-2 (pricing constraints):** New function `_5qApplyPricingConstraints` added to post-processing chain. When `behaviouralGuidance` from rule 493884ad is present (marker check + `do not dodge pricing` signal), replaces the hardcoded evasive pricing paragraph with a per-shown-call / setup-fee pricing line. No invented prices. Pilot line added when guidance mentions "small pilot".

- **GAP-3 (NON_PRIORITY template):** `NON_PRIORITY` added to `_5qDraftPolicyFor` → `"FIXED_TEMPLATE"`. `templateMicroIntent` maps `NON_PRIORITY` → `NOT_NOW`. NON_PRIORITY cases now produce a NOT_NOW template draft (not null), enabling cdada69d style rule post-processing.

**Patch applied (HumanApproval Node J, versionId 54b7a8e4):**

- **GAP-4 (revision reason prefill):** `_5pSavedRevisionReason` variable added. For sent-case reopens (`RESPONSE_APPROVED`/`LEARNING_REVISION_APPROVED`), reads `decision_payload.draft_revision_reason` and prefills the `draft_revision_reason` textarea. New cases and old cases without saved reason start blank.

**Harness: 66/66 PASS** (was 44/44 pre-patch; P1-P4 post-patch sections added).

**Key finding — local Decision file is STALE:**  
Local `production_decision_current.json` versionId `e1b84f34` ≠ production `889e1d45`.  
Production Decision has 1253-line Node D with full 5Q learning infrastructure (Q12 DataTable lookup, policy matching, classification correction, AI prompt injection). Local file has 393-line stale version.  
**Action required: update local workflow export after any future Decision patch.**

**Root causes confirmed:**

1. **Booking hyper-literal (case-7c87d21a):** `_5qApplyActiveFormRuleInstructionToDraft` extracts sentences from `97eb3b0a`'s behavioral specification and pastes them as email content. The instruction contains no URL → booking link is null → draft becomes garbled instruction fragments.

2. **Old booking rule (c9860e74) suppression:** WORKING CORRECTLY via scope deduplication. `97eb3b0a` wins (newer timestamp). Not a bug — the literal application (root cause #1) is the only booking failure.

3. **Pricing no delta (case-d555bcfd):** Rule `493884ad` eligible, guidance built, but `AI_COMMERCIAL_SUPERVISED` branch uses a hardcoded deterministic template that never reads `behaviouralGuidance`. Pipeline gap — guidance built but has no consumer.

4. **Setup/process rule (case-083fe26e):** Rule `48e10cac` eligible, guidance IS injected into AI prompt for OFFER_EXPLANATION (AI_SUPERVISED_OR_TEMPLATE). If "no output delta" was observed, it may be an AI compliance issue (AI ignoring guidance) or a measurement artifact. Not a code injection failure.

5. **Not-now/later → HUMAN_ONLY (case-5fa982f4):** Classification rule `6e50fd54` correctly changes AMBIGUOUS/AMBIGUOUS_SHORT_REPLY → NON_PRIORITY. But `NON_PRIORITY` is not in the draft policy map → defaults to HUMAN_ONLY → `draft_text=null`. Style rule `cdada69d` is eligible but has no pathway to reach the draft.

6. **Reopened form reasons:** Node J doesn't prefill `draft_revision_reason` textarea from case history on reopen. Reply text IS prefilled; reasons are not.

**Harness results:** 44/44 PASS (all rules, leakage tests, safety checks, attribution tests).

**Patches applied:** All 4 gaps patched. See patch detail block above.

**Old/new versionIDs:** Decision `889e1d45` → `a3916c2e`. HumanApproval `0fa9d0ce` → `54b7a8e4`.

**Recommended next actions (owner):**
1. Live test GAP-1: BOOKING_REQUEST case — verify draft has no policy meta-phrases ("Replace the previous", "Do not ask them").
2. Live test GAP-2: PRICING_REQUEST case with rule 493884ad active — verify commercial draft shows setup-fee / per-shown-call wording.
3. Live test GAP-3: AMBIGUOUS/AMBIGUOUS_SHORT_REPLY case with rule 6e50fd54 active — verify NON_PRIORITY classification produces NOT_NOW template draft.
4. Live test GAP-4: Reopen a previously approved case — verify `draft_revision_reason` textarea is prefilled.
5. If all 4 live tests pass → SL-PHASE-5Q VERIFIED COMPLETE. Start SL-PHASE-5R if further self-improvement scope identified.

---

## 2026-07-02 03:13 BST — Codex Strategic Repo Audit

**Agent:** Codex  
**Objective:** Read-only strategic audit of current repo status and next highest-leverage task.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this concise audit entry only

**Current status observed:**
- Repo docs are inconsistent by age: `README.md` still describes the older six-workflow dry-run state, while newer docs/reports show a seven-workflow supervised responder, production workflow IDs, self-improvement patches, and autonomous shadow-review preparation.
- Latest repo evidence points to: core supervised responder operating in validation/supervised mode; self-improvement infrastructure installed with remaining behavioural proof for draft-improvement learning; autonomous Gate 2 not approved and blocked by the 14-day shadow review plus owner signoffs/allowlists.
- Worktree has many pre-existing modified files; future sessions should use narrow file scopes and avoid assuming a clean baseline.

**Recommended next task:**
Run the docs-guided, owner-supervised draft-improvement learning behavioural proof from `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` before further autonomous Gate 2 work. This should be a Claude Code/manual-production-validation session, not a Codex implementation session.

---

## 2026-07-02 02:48 BST — Codex Business Brain Pilot

**Agent:** Codex  
**Objective:** Verify that this repo is correctly connected to the HMZ Business Brain and that future Codex sessions can use the correct context without reading the full Obsidian vault.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this timestamped pilot entry

**Files read:**
- `OPERATION_HANDOFF.md`
- `AGENTS.md`
- `README.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_BUSINESS_BRIEF.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_PROJECT_INDEX.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_SOURCE_PRIORITY.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_AGENT_RULES.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\02_PROJECTS\INSTANTLY_RESPONDER.md`

**What was verified:**
- `AGENTS.md` is accurate, concise, and safe for future Codex sessions.
- `AGENTS.md` points to the Business Brain root at `C:\Users\Hamzah Zahid\Projects\hmz-business-brain`.
- `AGENTS.md` explicitly says not to read the full vault by default.
- `AGENTS.md` explicitly says this repo's `OPERATION_HANDOFF.md` takes precedence over Obsidian notes for current execution state.
- The named Business Brain files were read selectively; the full vault was not scanned or edited.

**Current status:** COMPLETE — documentation/control-file review only; no application code, scripts, workflows, configs, credentials, package files, tests, lockfiles, deployment files, or vault files were modified.

**Risks / unknowns:**
- `AI_CONTEXT/AI_AGENT_RULES.md` mentions `AI_CONTEXT/AI_CURRENT_PRIORITIES.md` in its general vault checklist, but this repo's `AGENTS.md` deliberately lists a narrower project-specific allowed set. Future sessions should follow repo instructions and current user instructions first.
- `02_PROJECTS/INSTANTLY_RESPONDER.md` still contains placeholder repo-reference fields and explicitly says not to rely on it for current state. This is low risk because both the repo and `AI_SOURCE_PRIORITY.md` direct agents back to `OPERATION_HANDOFF.md`.

**Recommended next step:**
Proceed with future Codex sessions using `OPERATION_HANDOFF.md`, `AGENTS.md`, and `README.md` first; read only the named Business Brain context files when the task needs business context.

---

## 2026-07-01 — Business Brain Connection

**Agent:** Claude Code (claude-sonnet-4-6)  
**Objective:** Connect this repo to the HMZ Business Brain so Claude Code and Codex can access business-wide context safely.

**Files changed:**
- `CLAUDE.md` — added "Business Brain Context" section at end of file
- `AGENTS.md` — created; contains production target rules, safety defaults, source-of-truth table, and Business Brain Context section
- `OPERATION_HANDOFF.md` — created (this file)

**What was done:**
Documentation/control-file update only. No application code, scripts, workflows, configs, tests, package files, or credentials were modified. No vault files were read or edited. No secrets were stored.

**Current status:** COMPLETE — documentation update only; no production changes.

**Risks / unknowns:**
- The vault path `C:\Users\Hamzah Zahid\Projects\hmz-business-brain` has not been verified to exist in this session (per the hard rule against reading the vault without need). An agent reading `AI_CONTEXT/` files for the first time should confirm the path exists before acting on anything found there.
- `AI_CONTEXT/AI_SOURCE_PRIORITY.md` has not been read. Until it is, conflict-resolution between vault and repo files should default to favouring repo files (this file, `docs/SOURCE_PRIORITY.md`).
- `AGENTS.md` is new — Codex or other agents that auto-load it will pick up the vault-path pointer. Verify those agents respect the "read only when needed" rule before running them in this repo.

**Recommended next step:**
If the owner wants to use business-brain context in an upcoming session, open `AI_CONTEXT/AI_BUSINESS_BRIEF.md` and `AI_CONTEXT/AI_SOURCE_PRIORITY.md` at the start of that session to confirm the vault is current, then proceed with the specific task (e.g., campaign copy, offer positioning, or scope decisions).

**Recommended next agent:** Human review first. Then Codex should perform a documentation-only onboarding pass to verify `AGENTS.md` before any implementation task.
