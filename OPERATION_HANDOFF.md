# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

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
