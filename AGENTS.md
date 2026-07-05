# AGENTS.md — Instantly Rapid-Reply Automation

Agent-facing rules for this repository. Read this file at the start of any agentic session (Codex, Claude Code, or similar).

## Scope

This repo is a single-tenant Instantly.ai + n8n reply-handling responder for HMZ's own US B2B validation campaign. It is not a client platform. See `CLAUDE.md` for full project rules.

## Production target

All n8n operations must target **`https://n8n.hmzaiautomation.com/api/v1`** (production cloud).
Local/Docker targets are forbidden unless the owner explicitly says "local dev" in the current session.
Run `scripts/assert-hmz-production-target.ps1` before any n8n API call.

## Safety defaults

- `DRY_RUN=true` is always the default. No sends without explicit owner approval + campaign allowlist entry.
- No production changes (activate, delete, send) without explicit instruction in the current session.
- No secrets in files, exports, logs, or chat.

## Source of truth (this repo)

| What | File |
|------|------|
| Execution state / handoff | `OPERATION_HANDOFF.md` |
| Approved reply rules | `docs/HMZ_APPROVED_REPLY_RULES.md` |
| Approved knowledge base | `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` |
| Source priority | `docs/SOURCE_PRIORITY.md` |
| Assumptions / unknowns | `docs/ASSUMPTIONS_AND_UNKNOWNS.md` |

## Business Brain Context

Business-wide context for HMZ may exist at:
`C:\Users\Hamzah Zahid\Projects\hmz-business-brain`

**Read these files only when business context is needed for the current task:**
- `AI_CONTEXT/AI_BUSINESS_BRIEF.md` — high-level business overview
- `AI_CONTEXT/AI_PROJECT_INDEX.md` — index of active projects
- `AI_CONTEXT/AI_SOURCE_PRIORITY.md` — which source wins when files conflict
- `AI_CONTEXT/AI_AGENT_RULES.md` — agent behaviour rules that apply across projects
- The relevant project note under `02_PROJECTS/` for the specific project in scope

**Hard rules for the vault:**
- Do not read the full vault by default. Read only the files listed above plus targeted project notes.
- Do not edit any vault file unless the owner explicitly instructs it in the current session.
- Do not copy large Obsidian notes into this repo.
- Do not store secrets found in the vault in any repo file or log.

**Precedence:**
- For current execution state of this responder project, `OPERATION_HANDOFF.md` in this repo takes precedence over any Obsidian note.
- If an Obsidian file conflicts with a file in this repo, follow `AI_CONTEXT/AI_SOURCE_PRIORITY.md` to resolve.

## Session discipline

- Read `OPERATION_HANDOFF.md` first and treat it as the current execution state.
- Do not rely on stale README/local dry-run assumptions when they conflict with the handoff.
- Do not redo completed SL-PHASE-5Q repairs unless the current handoff says verification failed.
- Do not touch Sender, Shadow Evaluator, Gate 2, or autonomous mode without explicit current-session owner approval.
- One narrow objective per session.
- Record assumptions in `docs/ASSUMPTIONS_AND_UNKNOWNS.md`; do not silently guess.
- At major context boundaries, update `OPERATION_HANDOFF.md` with a concise handoff entry.
- No full-repository scan unless explicitly authorised.
