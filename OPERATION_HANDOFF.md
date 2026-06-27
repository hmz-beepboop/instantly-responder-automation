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

**Last updated:** 2026-06-27T00:00:00+00:00
**Updated by:** Claude Code
**Current branch:** `main`

**Project status:**
The supervised responder is complete and working for human-approved reply sending. Classification self-improvement is verified. Draft learning capture UI (revision reason, improvement scope, target classifications) and review reopen (SL-PHASE-5P) are installed and code-verified. The critical missing piece is **draft behavioural self-improvement**: capture and UI are in place, but the bridge from human edit → learning event → active policy → Decision node consumption is unverified. Cases case-759e58d7 and case-d099e6f3 demonstrated that a learned improvement did not propagate to the next similar draft. SL-PHASE-5Q (Sender idempotency audit) is also required before `approve_and_send_followup` can auto-send. The autonomous shadow layer is built and Gate 1 is executed, but live autonomous sending remains 0% and Gate 2 is not approved.

**Latest verified working state:**
- HumanApproval versionId: `9c71882f-a096-48a9-861a-37e5424035ae` (SL-PHASE-5P, 2026-06-26)
- Decision versionId: `85f51eb4-bf8f-4d17-9883-52d7c2f11225`
- Proxy versionId: `47dbb8bd-ebbb-4a10-a39b-a1fb83be36ac`
- Shadow Evaluator versionId: `ae13bf4e-ee04-438f-9657-3c57183b90a2` — `active=false`
- Harness: 106/108 verified at SL-PHASE-5P apply; 2 false negatives confirmed fixed manually
- Classification self-improvement: VERIFIED, `self_improvement_full_loop_proven=TRUE`

**Known failing checks / unproven behaviours:**
- Draft behavioural self-improvement: **FAILED/UNPROVEN** — live owner test (case-759e58d7 → case-d099e6f3) showed improvement did not propagate; SL-PHASE-5Q required to audit and repair
- Reopened review forms: suspected to lose human-entered reasons (not confirmed); SL-PHASE-5Q scope
- Review reopen manual tests 2/3/4: PENDING owner action
- Draft improvement target classifications live UI: PENDING owner confirm
- `approve_and_send_followup` auto-send path: BLOCKED pending SL-PHASE-5R Sender idempotency audit

**Do not redo:**
- SL-PHASE-5P, 5O, 5N, 5M, 5L — all nodes preserved in HumanApproval versionId 9c71882f
- Phase 4A–Stage 8 self-improvement verification — complete
- Gate 1 — executed 2026-06-24

**Highest-risk areas:**
- Decision node D (active rule injection — do not re-apply old rule sets)
- HumanApproval token validation nodes H+L (reopen logic is stateful)
- Shadow Evaluator — must remain `active=false`; do not activate without Gate 2 owner sign-off

**Next recommended owner:** Human (manual tests) or Claude Code (SL-PHASE-5Q)
**Why:** Behavioural draft proof and review reopen tests require live prospect cases. SL-PHASE-5Q can be scoped and planned by Claude Code independently.

---

## ACTIVE_TASKS

| ID | Status | Owner | Description | Branch | Notes |
|---|---|---|---|---|---|
| TASK-001 | review_needed | human | Manual tests 2/3/4 — review reopen, approve_learning_only, repeat-send | `main` | See `docs/NEXT_MANUAL_TEST_PACKET_REVIEW_REOPEN_REPEAT_SEND.md` |
| TASK-002 | blocked | human/Claude Code | Draft behavioural self-improvement FAILED — live evidence case-759e58d7 → case-d099e6f3 shows improvement did not propagate | `main` | SL-PHASE-5Q required; see `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_BEHAVIOURAL_PROOF.md` |
| TASK-003 | planned | Claude Code | SL-PHASE-5Q — self-improvement behavioural closure: audit learning persistence, active policy creation, Decision policy consumption, reopened-form reason preservation | `agent/claude/phase-5q/<ts>` | Immediate next technical blocker |
| TASK-004 | planned | Claude Code | SL-PHASE-5R — Sender idempotency / approve_and_send_followup automated send audit; unblocks auto-send path | `agent/claude/phase-5r/<ts>` | Planned after or parallel to SL-PHASE-5Q |
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
