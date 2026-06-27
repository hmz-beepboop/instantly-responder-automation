# Instantly Rapid-Reply Automation — Codex / Coding-Agent Operating Rules

## 1. Project Summary

Single-tenant Instantly.ai + n8n supervised responder for HMZ's own US B2B validation campaign. Classifies inbound prospect replies, routes drafts for human review, and learns from human edits. `OPERATING_MODE=VALIDATION` — no auto-send without explicit owner approval. Not a client-delivery platform.

---

## 2. Source-of-Truth Order

1. `OPERATION_HANDOFF.md` — read first; do not rely on README.md status if it conflicts.
2. `README.md` — stable overview; may lag behind OPERATION_HANDOFF.md.
3. `CLAUDE.md` — Claude Code operating rules (apply the same safety rules here).
4. `docs/SOURCE_PRIORITY.md` — business fact hierarchy.
5. `docs/HMZ_PRODUCTION_TARGET_GUARD.md` — production target guard policy.

If README.md status contradicts OPERATION_HANDOFF.md, flag the contradiction; do not invent status.

---

## 3. What Codex Should Do

- **Default role: independent reviewer / auditor.** Unless explicitly assigned implementation, review diffs, check tests, identify risks, and suggest focused patches.
- Read `OPERATION_HANDOFF.md` before every session.
- Review diffs for correctness, safety, idempotency, and secret leakage.
- Identify risks in proposed patches before they are applied.
- Suggest targeted, minimal patches. Prefer editing specific nodes/lines over full rewrites.
- Check harness pass counts (reported in OPERATION_HANDOFF.md) for regressions.
- Flag any contradiction between docs rather than silently resolving it.
- Update `OPERATION_HANDOFF.md` if files are changed.
- Treat **SL-PHASE-5Q** as the immediate technical blocker and **SL-PHASE-5R** as the next queued task.

---

## 4. What Codex Must Not Do

- Call production APIs (`https://n8n.hmzaiautomation.com`, Instantly API, Google Chat webhook).
- Activate any workflow or autonomous mode.
- Toggle `active=true` on the Shadow Evaluator.
- Inspect, print, or log secrets, API keys, tokens, passwords, or webhook URLs containing tokens.
- Re-apply old Decision active rule patches (Phase 4D rules are already injected; re-applying causes duplicates).
- Redo any phase listed in the **Do-Not-Redo** section of `CLAUDE.md` / `OPERATION_HANDOFF.md`.
- Scan the full repository without explicit instruction.
- Read `archive/`, `backups/`, `outputs/`, or large generated reports unless explicitly instructed.
- Invent project status, completion %, or business facts.
- Use `localhost` or Docker as an n8n target.
- Claim a phase is complete without harness pass evidence and versionId confirmation.

---

## 5. Review / Diff Expectations

- Confirm versionId changes after any workflow import.
- Before approving a patch to Decision node D: verify old active rules are not being re-injected.
- Before approving any HumanApproval patch: verify token validation (nodes H+L) and reopen logic are intact.
- Before approving any Sender patch: verify idempotency and send-state checks are preserved.
- Check that `DRY_RUN=true` default is not inadvertently bypassed.
- Check that Shadow Evaluator `active=false` is not changed.

---

## 6. Safety and Secret Handling

- Do not print contents of any file with "credential", "token", "key", "secret", "password", or ".env" in the name.
- The following files are flagged as potentially sensitive (from OPERATION_HANDOFF.md):
  - `reports/LOCAL_RUNTIME_CREDENTI…` (truncated)
  - `scripts/SL-PHASE-4I-token-refr…` (truncated)
  - `patch_sender_token_resolution.ps1`
- Do not inspect or quote their contents. Refer to the existing warning in OPERATION_HANDOFF.md only.
- `outputs/` and `backups/` are gitignored. Verify `.gitignore` is respected before any push.

---

## 7. Testing Expectations

- Harness must pass (count reported in OPERATION_HANDOFF.md) before and after any patch.
- Manual live tests require owner action; flag as PENDING, not DONE.
- Do not run against production n8n or Instantly unless explicitly instructed by owner.
- Synthetic validation first; live test only after synthetic passes.

---

## 8. Handoff Rules

- Update `OPERATION_HANDOFF.md` (append a new SESSION_LOG entry, newest first) before ending any session in which files were changed.
- State: files changed, tests run, commands run, risks, do-not-repeat items, and next owner.
- Do not rely on chat history across sessions — all state lives in `OPERATION_HANDOFF.md`.
- Branch naming: `agent/codex/<task>/<timestamp>`.

---

## 9. Current High-Priority Tasks

| Priority | ID | Task | Status |
|---|---|---|---|
| 1 | TASK-003 | **SL-PHASE-5Q** — audit broken bridge: human edit → learning event → active/effective policy → Decision draft consumption → reopened-form reason preservation. Evidence: case-759e58d7 → case-d099e6f3. | IMMEDIATE BLOCKER |
| 2 | TASK-004 | **SL-PHASE-5R** — Sender idempotency / `approve_and_send_followup` automated send audit. Unblocks auto-send path. | PLANNED |
| 3 | TASK-001 | Manual reopen tests 2/3/4 — requires owner action. | REVIEW_NEEDED |
| 4 | TASK-006 | Pre-push secret scan — 3 flagged files; review before first push. | PLANNED |
| 5 | TASK-005 | Gate 2 autonomous pilot — min date ~2026-07-08; requires owner sign-off. | PLANNED |

Do not combine SL-PHASE-5Q and SL-PHASE-5R into one session. They are separate scopes.
