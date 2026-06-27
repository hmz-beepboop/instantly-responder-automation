# Instantly Rapid-Reply Automation — Claude Code Operating Rules

## 1. Project Summary

Single-tenant Instantly.ai + n8n supervised responder for HMZ's own US B2B validation campaign. Classifies inbound prospect replies, routes human-review drafts, and learns from human edits. **Not a client-delivery platform.** `OPERATING_MODE=VALIDATION` — no auto-send without explicit owner approval.

This file governs **agent workflow only**. Business facts, offer maturity, and pricing come from `docs/SOURCE_PRIORITY.md`. No instruction here may convert an unvalidated hypothesis into a business fact.

---

## 2. Source-of-Truth Order

1. `OPERATION_HANDOFF.md` — read first every session; update before ending every session.
2. `README.md` — stable human-facing overview.
3. `docs/SOURCE_PRIORITY.md` — business fact hierarchy.
4. `docs/HMZ_APPROVED_REPLY_RULES.md` — approved reply policy.
5. `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — approved runtime facts only. Anything absent → `UNKNOWN` → escalate.
6. `NEXT_SESSION_HANDOFF.md` — fallback only if OPERATION_HANDOFF.md and README.md conflict.

If status in README.md conflicts with OPERATION_HANDOFF.md, trust OPERATION_HANDOFF.md and flag the contradiction.

---

## 3. Current Status Snapshot (as of 2026-06-27)

| Component | Status |
|---|---|
| Supervised responder (human-approved send) | COMPLETE |
| Classification self-improvement | VERIFIED |
| Draft learning capture UI (revision reason, scope, target) | INSTALLED / CODE-VERIFIED |
| Review reopen (SL-PHASE-5P) | INSTALLED / CODE-VERIFIED |
| **Draft behavioural self-improvement** | **FAILED / UNPROVEN** |
| Autonomous shadow layer | BUILT, `active=false` |
| Gate 2 autonomous pilot | NOT APPROVED |
| Live autonomous sending | 0% |

**Evidence of failure:** case-759e58d7 (source) → case-d099e6f3 (comparison). Human improvement did not propagate to the later draft.

**Immediate blocker:** SL-PHASE-5Q — audit: human edit → learning event → effective/active policy → Decision node draft consumption → reopened-form reason preservation.

**Next queued task:** SL-PHASE-5R — Sender idempotency / `approve_and_send_followup` automated send audit.

**Latest verified versionIds:**
- HumanApproval: `9c71882f-a096-48a9-861a-37e5424035ae`
- Decision: `85f51eb4-bf8f-4d17-9883-52d7c2f11225`
- Proxy: `47dbb8bd-ebbb-4a10-a39b-a1fb83be36ac`
- Shadow Evaluator: `ae13bf4e-ee04-438f-9657-3c57183b90a2` — **active=false**

---

## 4. Critical Safety Boundaries

- **`DRY_RUN=true` is the default.** No real send until `DRY_RUN=false` AND campaign ID is on `LIVE_CAMPAIGNS` AND every send gate passes AND owner approves explicitly.
- **Shadow Evaluator must remain `active=false`** unless Gate 2 is explicitly approved in writing by owner. Do not toggle it.
- **No autonomous activation** of any kind.
- **No real sends, activations, deletions, or production changes** without explicit approval.
- **No secrets** in files, exports, logs, or chat. Credentials live only in n8n credentials / `.env`.
- **Deterministic safety first.** Deterministic rules run before AI. AI never sends substantive replies freely.
- **Idempotency preserved.** Do not modify Sender unless the task explicitly requires it and duplicate protection is verified intact.

---

## 5. Claude Code Workflow Rules

- **Read `OPERATION_HANDOFF.md` first** every session.
- **Update `OPERATION_HANDOFF.md` before ending every session**, even if the task failed.
- One narrow objective per session.
- No full-repository scan unless explicitly authorised.
- No broad workflow dumps — inspect local JSON exports before calling n8n API or MCP.
- Hard cap tool calls when MCP is used.
- Do not use `n8n-mcp` unless explicitly necessary and narrowly scoped.
- Avoid reading `archive/`, `backups/`, `outputs/`, large generated reports, or credential files.
- Label important technical facts: `VERIFIED` / `PROVISIONAL` / `BLOCKED` / `NOT REQUIRED FOR VALIDATION MVP`.
- Verify Instantly behaviour against current official docs; never invent API fields or endpoints.
- Run synthetic validation before recommending any live test.
- Do not claim deployment or production readiness without evidence.
- Use `/session-handoff` at major context boundaries.
- Preserve original `*.docx` source documents. Never edit them.

---

## 6. Branching and Handoff Rules

- Work on a task branch: `agent/claude/<task>/<timestamp>` unless human explicitly says stay on `main`.
- State files changed, tests run, risks, and next owner in OPERATION_HANDOFF.md before ending.
- Do not rely on chat history across sessions — all state lives in OPERATION_HANDOFF.md.

---

## 7. Production / n8n Rules

**HARD RULE — always active.**

| Setting | Value |
|---|---|
| Default target | `PRODUCTION_CLOUD_N8N` |
| Production n8n API base URL | `https://n8n.hmzaiautomation.com/api/v1` |
| Production n8n UI | `https://n8n.hmzaiautomation.com` |

**Forbidden** unless the user explicitly says "local dev" or "local Docker test":
- `localhost` or `127.0.0.1` as an n8n target
- Docker Desktop or any `docker` / `docker-compose` command
- Container name `hmz-n8n-local-dev`
- Path `infrastructure/local-n8n`
- Scripts named `run-local-*` or any script that sets `$N8nUrl = "http://127.0.0.1:5678"`

**Before any n8n operation:** run `scripts/assert-hmz-production-target.ps1`.  
See `docs/HMZ_PRODUCTION_TARGET_GUARD.md` for the full guard policy.

---

## 8. Testing / Verification Expectations

- Run the local harness before and after any workflow JSON patch.
- Confirm versionId changes after any n8n import.
- Do not claim a phase is complete without a passing harness run and a versionId confirmation.
- Manual live tests require owner action; flag them as PENDING, not DONE.

---

## 9. Usage-Efficiency Rules

- Read only files directly relevant to the current task.
- Do not scan the full repo.
- Do not dump full workflow JSON unless diffing a specific node.
- Prefer local file inspection over n8n API or MCP calls.
- Hard cap MCP tool calls.
- Batch independent reads into parallel calls.

---

## 10. Do-Not-Redo List

- SL-PHASE-5P, 5O, 5N, 5M, 5L — preserved in HumanApproval versionId `9c71882f`
- Phase 4A–4K — complete
- Stage 1–8 self-improvement verification — complete
- Gate 1 — executed 2026-06-24
- Decision active rule patches (Phase 4D) — **do not re-apply old rule sets**

---

## 11. Next Recommended Task

**SL-PHASE-5Q — self-improvement behavioural closure**

Audit the broken bridge: human edit → learning event persistence → active/effective policy creation → Decision node draft consumption → reopened-form reason preservation.

Use cases case-759e58d7 (source) and case-d099e6f3 (comparison) as live evidence.

After SL-PHASE-5Q: proceed to SL-PHASE-5R (Sender idempotency / `approve_and_send_followup` automated send audit).

---

## Source of truth for business facts

`docs/SOURCE_PRIORITY.md` → `docs/HMZ_APPROVED_REPLY_RULES.md` → `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. Nothing in this file overrides those documents on business facts, offer maturity, pricing, or proof.
