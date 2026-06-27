# HMZ Instantly Responder Automation

> **This README is a stable project overview.** For operational current state, see [OPERATION_HANDOFF.md](OPERATION_HANDOFF.md). For the latest single-agent session context, see [NEXT_SESSION_HANDOFF.md](NEXT_SESSION_HANDOFF.md) (treat OPERATION_HANDOFF.md as the durable multi-agent source of truth).

---

## Purpose

n8n-based automated responder for inbound Instantly.ai prospect replies, built for **HMZ's own initial US B2B validation campaign only**. It classifies replies, applies deterministic safety rules, produces a structured action plan, routes substantive replies for **human approval** (not auto-send), and captures reviewer learning to improve future drafts.

This is a **single-tenant, validation-stage** system. It is not a reusable client responder and must not be treated as part of an operating client-delivery platform.

---

## Status

| Layer | State |
|---|---|
| Core supervised responder | **COMPLETE** — human-approved send path working |
| Self-improvement — classification | **VERIFIED** — classification loop proven (98%) |
| Self-improvement — draft behavioural | **FAILED/UNPROVEN** — capture/UI installed; live evidence (case-759e58d7 → case-d099e6f3) shows improvement did not propagate to next similar draft; SL-PHASE-5Q required |
| Review reopen / learning amendments | **INSTALLED** (SL-PHASE-5P) — manual tests 2/3/4 pending |
| approve_learning_only | **INSTALLED** — no-send learning capture working |
| approve_and_send_followup | **PARTIAL** — metadata captured; auto-send blocked pending SL-PHASE-5R Sender idempotency audit |
| Autonomous layer design | **COMPLETE** — not enabled |
| Autonomous layer live (shadow) | **active=false** — Gate 1 executed 2026-06-24 |
| Gate 2 autonomous pilot | **NOT APPROVED** — requires 14-day shadow review + owner sign-off |
| Overall build | ~99% |

**Operating mode:** `VALIDATION` — `DRY_RUN=true` — `autonomous_enabled=false`

---

## Warnings

> **No secrets in repo.** Do not commit `.env`, credentials, API keys, tokens, webhook secrets, cookies, or private keys. These are excluded by `.gitignore`. If you find any, remove before pushing.

> **Do not activate autonomous/live send paths** without explicit owner approval and Gate 2 completion. Shadow evaluator must remain `active=false`.

> **Do not use n8n-mcp** unless explicitly needed for a narrowly targeted task. It has previously caused unnecessary usage consumption. Prefer local workflow JSON inspection and the n8n REST API.

> **Agents must update OPERATION_HANDOFF.md** at the end of every session.

---

## Production Workflows (n8n Cloud)

| # | Name | n8n Workflow ID | Last versionId |
|---|---|---|---|
| 1 | HMZ - Decision Engine | `tgYmY97CG4Bm8snI` | `85f51eb4` |
| 2 | HMZ - Human Approval | `9aPrt92jFhoYFxbs` | `9c71882f` (SL-PHASE-5P, 2026-06-26) |
| 3 | HMZ - Proxy | `seB6ZmlyomhC4QWU` | `47dbb8bd` |
| 4 | Shadow Evaluator | `aHzLtQiv6G8h1bqD` | `ae13bf4e` — **active=false** |

> Production n8n API base: `https://n8n.hmzaiautomation.com/api/v1`
> Run `scripts/assert-hmz-production-target.ps1` before any n8n operation.

---

## System Components

- **Decision Engine** — deterministic prefilter → AI micro-intent classifier → structured action plan (stop/pause/send flags, reply type, human-review flags)
- **Human Approval workflow** — renders review form, validates token, processes reviewer action, captures learning fields (revision reason, improvement scope, target classifications)
- **Proxy** — token-refresh retry, de-dup, connection between workflows
- **Shadow Evaluator** — autonomous evaluation layer (shadow-only, not live)
- **Instantly API integration** — webhook intake; send via Instantly API (DRY_RUN gate)
- **Self-improvement layer** — classification + draft rule candidates written to shadow store; active policy injection via Decision node

---

## Folder Structure

```
Instantly_Responder_Automation/
├── workflows/          # Local n8n workflow JSON exports
├── docs/               # Architecture, policies, phase work logs, patch docs
├── scripts/            # PowerShell automation, apply/verify scripts
├── schemas/            # Data schemas / event formats
├── fixtures/           # Test payloads
├── sources/            # Source business/strategy documents
├── config/             # Non-secret configuration
├── outputs/            # Generated outputs (gitignored)
├── reports/            # Verification/test reports
├── verification/       # Integration closure + test harnesses
├── archive/            # Archived/superseded material (do not read unless instructed)
├── backups/            # Workflow backups before patches (gitignored)
├── CLAUDE.md           # Agent workflow rules (read first)
├── OPERATION_HANDOFF.md # Multi-agent operational log (read before every session)
├── NEXT_SESSION_HANDOFF.md # Latest single-session context
└── PROJECT_MANIFEST.md # Folder inventory
```

---

## Key Docs

| Doc | Purpose |
|---|---|
| `CLAUDE.md` | Agent rules, production target guard, safety rules |
| `OPERATION_HANDOFF.md` | Multi-agent current state + session log |
| `NEXT_SESSION_HANDOFF.md` | Latest session-specific context |
| `docs/SOURCE_PRIORITY.md` | Business fact source hierarchy |
| `docs/HMZ_APPROVED_REPLY_RULES.md` | Approved reply policy |
| `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` | Approved runtime facts |
| `docs/PHASE_5_AUTONOMOUS_WORK_LOG.md` | Autonomous layer design log |
| `docs/PHASE_5J_GATE_2_READINESS_SUMMARY.md` | Gate 2 blockers |
| `docs/NEXT_MANUAL_TEST_PACKET_*.md` | Manual test procedures for pending verifications |
| `docs/HMZ_PRODUCTION_TARGET_GUARD.md` | Production target guard policy |

---

## Agent Workflow: Claude Code + Codex

- **Claude Code** — repo edits, workflow JSON patches, script/docs changes, local verification
- **Codex** — code review, independent diff audit, test suggestions, refactor review
- **ChatGPT** — prompt strategy, output audit, risk review, manual procedure design
- **Human** — production approvals, credentials, live sends, business decisions, Gate 2 approval

**Branch naming:**
```
agent/claude/<task>/<timestamp>
agent/codex/<task>/<timestamp>
```

**Rules:**
1. Read `OPERATION_HANDOFF.md` first.
2. Read `CLAUDE.md` and `docs/HMZ_PRODUCTION_TARGET_GUARD.md`.
3. Run `scripts/assert-hmz-production-target.ps1` before any n8n operation.
4. State files changed, tests run, risks, and next owner.
5. Update `OPERATION_HANDOFF.md` before ending the session.
6. Application/workflow changes require tests or explicit explanation of why tests were not run.

---

## Setup / Local Use

There is no local runtime required for documentation or review tasks. For workflow apply operations:

1. Confirm n8n production target: `scripts/assert-hmz-production-target.ps1`
2. Apply a patch script: `.\<PatchScript>.ps1` (review before running)
3. Verify with relevant test harness under `verification/`

Do not point scripts at `localhost` or Docker. The active responder runs on the production VPS.

---

## Known Pending Work

1. **SL-PHASE-5Q** *(immediate next blocker)* — Self-improvement behavioural closure: audit learning persistence, active policy creation, Decision node policy consumption, and reopened-form reason preservation. Live evidence shows draft improvement from case-759e58d7 did not propagate to case-d099e6f3. The bridge human-edit → learning event → effective policy → Decision consumption is the likely gap.
2. **SL-PHASE-5R** — Sender idempotency audit; required before `approve_and_send_followup` can route to automated send. Planned after or parallel to SL-PHASE-5Q.
3. **Review reopen manual tests** — Owner must run Tests 2/3/4 from `docs/NEXT_MANUAL_TEST_PACKET_REVIEW_REOPEN_REPEAT_SEND.md`
4. **Draft improvement target classifications UI** — Live UI confirm pending owner (SL-PHASE-5O)
5. **Gate 2 autonomous pilot** — Requires 14-day real prospect shadow review + owner decisions/allowlists/sign-off (min date ~2026-07-08)
6. **GitHub secret scan** — Review `reports/LOCAL_RUNTIME_CREDENTI…` and `scripts/SL-PHASE-4I-token-refr…` and `patch_sender_token_resolution.ps1` before first push

---

## Next Recommended Step

**SL-PHASE-5Q** — self-improvement behavioural closure. Draft behavioural self-improvement has **failed** in live evidence: a human improvement applied during review of case-759e58d7 (natural opener / reply style) did not appear in the AI draft for the later similar case case-d099e6f3. The missing or broken bridge is: human edit → learning event write → active/effective policy creation → Decision node policy consumption. Additionally, reopened review forms may not preserve actual human-entered reasons. Audit and repair each stage. Until SL-PHASE-5Q passes, do not claim end-to-end self-improvement is complete. SL-PHASE-5R (Sender idempotency audit, required for `approve_and_send_followup` automated send) follows after or in parallel.
