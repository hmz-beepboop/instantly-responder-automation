# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

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
