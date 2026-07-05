# Instantly Rapid-Reply Automation — Project Rules

## HMZ PRODUCTION TARGET RULES

**HARD RULE — read before any verification, API call, or n8n operation.**

| Setting | Value |
|---------|-------|
| Default target | `PRODUCTION_CLOUD_N8N` |
| Production n8n API base URL | `https://n8n.hmzaiautomation.com/api/v1` |
| Production n8n UI | `https://n8n.hmzaiautomation.com` |

### Forbidden unless the user explicitly says "local dev" or "local Docker test"

- `localhost` or `127.0.0.1` as an n8n target
- `Docker Desktop` or any `docker` / `docker-compose` command
- Container name `hmz-n8n-local-dev`
- Path `infrastructure/local-n8n`
- Any script named `run-local-*`, `run-n8n-runtime-tests.ps1` (integration-closure), or any script that sets `$N8nUrl = "http://127.0.0.1:5678"`

### Why this rule exists

A previous Claude session incorrectly targeted Docker Desktop and local n8n even though the active responder runs on the production VPS. All production responder checks — workflow retrieval, execution inspection, health checks — must target `https://n8n.hmzaiautomation.com/api/v1`.

### Safe reference before any n8n operation

Run `scripts/assert-hmz-production-target.ps1` to confirm the correct target is in scope. See `docs/HMZ_PRODUCTION_TARGET_GUARD.md` for the full guard policy.

How the agent works on this project. This file governs **agent workflow only**. It does **not** define business facts, offer maturity, pricing, proof, or validation strategy — those come from the business-source hierarchy in `docs/SOURCE_PRIORITY.md`. No instruction in this file may turn an unvalidated hypothesis into a business fact.

## Objective
Build a safe, testable Instantly.ai + n8n system that handles eligible prospect replies fast, in support of a US B2B **validation-stage** sprint. Default operating mode is `VALIDATION`: prospect replies are research evidence; substantive replies are drafted and routed for human approval, not auto-sent.

## Scope
This system supports **HMZ's own initial US B2B validation campaign only**. It is a single-tenant inbox-monitoring and reply-handling responder for HMZ's own Instantly workspace and campaigns (`docs/VALIDATION_CAMPAIGN_CONFIG.md`). It is **not yet a reusable client responder** and must not be designed, described, or treated as part of a proven or operating client-delivery platform.

Any future use of this system to monitor or respond to replies on behalf of a client (rather than HMZ's own outreach) is **out of scope** until all of the following are separately produced and approved: a client-specific approved knowledge base, a client-specific approved reply policy, a confirmed sender identity and workspace/permissions model for that client, a compliance review for that client's jurisdiction and offer, and controlled testing in that client's environment. None of this exists yet. Do not build toward it implicitly.

## Source of truth
- Current execution state / latest handoff: `OPERATION_HANDOFF.md`. This takes precedence over README, older reports, Obsidian notes, and stale local workflow assumptions.
- Business facts / maturity / strategy: `docs/SOURCE_PRIORITY.md` (Abs Plan → Offer Intake → reconciled approved reply rules → Alpha Offer is future-only).
- Approved reply policy: `docs/HMZ_APPROVED_REPLY_RULES.md` (reconciled).
- Approved runtime facts: `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` only. Anything absent is `UNKNOWN` → escalate.
- Architecture / state / implementation: the corresponding `docs/*.md`.

## Build discipline
1. **Use the lightest reliable interface.** Inspect and edit local workflow JSON first. Prefer deterministic local tests and the n8n CLI/API for bounded import, retrieval and runtime checks. Use n8n MCP only for narrowly targeted schema questions, validation or execution inspection that cannot be done reliably from local files or the CLI. Never retrieve full workflows or full node schemas through MCP when a local export already exists.
2. **Verify Instantly behaviour** against current official Instantly documentation. Do not invent API fields, endpoints, payloads, or plan tiers.
3. **Status discipline.** Label important technical facts `VERIFIED` / `PROVISIONAL` / `BLOCKED` / `NOT REQUIRED FOR VALIDATION MVP`. Implementation is blocked where a required capability is unverified.
4. **Production-cloud targeting discipline.** The active responder is on the production n8n cloud target above. Run `scripts/assert-hmz-production-target.ps1` before any n8n API call. Do not use local/Docker targets unless the owner explicitly says "local dev" in the current session.
5. **`DRY_RUN=true` is the default.** No real send leaves the system until `DRY_RUN=false` AND the exact campaign ID is on the `LIVE_CAMPAIGNS` allowlist AND every send gate passes — all with explicit owner approval.
6. **No secrets in files, exports, or logs.** Credentials live only in n8n credentials / `.env`, never in chat, workflow JSON, or logs.
7. **No real sends, activations, deletions, or production changes without explicit approval.**
8. **Build incrementally** and validate each step before proceeding. Use the simplest architecture that reliably meets the objective (Validation MVP before Production profile).

## Safety and correctness
9. **Deterministic safety before AI.** Deterministic rules run first and override AI output. AI is used only for semantic classification and for source-grounded T2 drafts (human review). AI never drafts/sends substantive prospect replies freely and never causes a hard suppression directly.
10. **Idempotency and send-state.** Persistent idempotency + send-state checks prevent any duplicate reply. One acknowledgement per inbound event.
11. **Reconcile uncertain sends before retrying.** If an uncertain send cannot be reconciled with a verified mechanism, do not auto-retry — raise an urgent human case.
12. **Stop/suppress immediately** for opt-outs, complaints, legal/privacy issues, and hostile responses.
13. **Do not auto-send** substantive replies for legal, privacy, pricing-negotiation, reputational, attachment-dependent, ambiguous, or low-confidence cases.
14. **Structured action plan, not a single enum.** Decisions emit independent fields (stop/pause sequence, suppression level, reply mode, human-review/escalation flags, send-allowed, etc.). A confidence score never authorises a send on its own — every applicable gate must pass.
15. **No invented business claims.** No invented prices, results, case studies, guarantees, availability, integrations, or proof. No "proven/established/mature" language. Pricing is human-only.

## Five-minute objective (two separate metrics, staged)
The five-minute objective does **not** mean every prospect receives a reply within 5 minutes. It means the system *processes* every eligible event within 5 minutes — which may correctly conclude in suppression, escalation, or "no reply needed."

- **Processing SLO (staged sub-targets):**
  - Webhook acknowledgement: immediate.
  - Classification + structured action plan produced: within 60 seconds.
  - Draft (if applicable) + human notification routed: within 120 seconds.
  - Processing concluded — completed, suppressed, or escalated: within 300 seconds.
- **Transmission SLO (separate, not guaranteed in `OPERATING_MODE=VALIDATION`):** for the subset of cases where `send_allowed=true` and a human approves, the approved reply is transmitted within 5 minutes of approval. In `VALIDATION` mode there is **no transmission guarantee at all** — substantive replies wait for human approval, which may take longer than 5 minutes.
- A notification, queue entry, case record, draft, approval request, or held/scheduled reply is **not** a transmission.
- An intentional no-reply (e.g. T5/T8/T9 acknowledgement-only or NOOP outcomes) that completes within the Processing SLO is a **successful resolution**, not a failure of the five-minute objective.

## Governance
16. **Record assumptions and unresolved issues** instead of silently guessing (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`).
17. **Save important findings and decisions to project files** so later phases do not depend on chat history.
18. **Preserve the original business source documents** (`*.docx`). Never edit them. Do not delete the Grill Me brainstorm record.
19. **Run synthetic validation** before recommending any live test.
20. **Do not claim controlled-live-test, deployment, or production readiness without evidence.**
21. **Preserve current handoff state.** Read `OPERATION_HANDOFF.md` first, avoid redoing completed work, and do not regress to stale README/local dry-run assumptions.
22. **Do not touch Sender/autonomous/Gate 2 without explicit current-session approval.** Sender remains gated, Shadow Evaluator remains inactive unless approved, Gate 2 remains unapproved, and autonomous remains disabled.

## Notes
- Use installed n8n workflow / validation / node-config / expression / JavaScript / MCP skills where relevant.
- Use `/session-handoff` at major context boundaries.
- Do not create an Instantly-specific Skill until implementation and controlled testing are complete.
- Do not read `archive/` unless explicitly instructed.
- One narrow objective per Claude session.
- No full-repository scan unless explicitly authorised.
- Hard cap tool calls when MCP is used.
- Update `OPERATION_HANDOFF.md` after major context boundaries or state-changing sessions.

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
