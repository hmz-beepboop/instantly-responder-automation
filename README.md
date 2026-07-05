# Instantly Responder Automation (Validation Stage)

## Purpose

This repository contains HMZ's single-tenant Instantly.ai + n8n responder for HMZ's own US B2B validation campaign. It classifies inbound replies, prepares supervised reply handling, supports human approval and learning loops, and keeps sending behind explicit safety gates.

It is not a reusable client platform. Do not use old local dry-run documentation as the current state when it conflicts with `OPERATION_HANDOFF.md`.

## Current Status

Authoritative execution state lives in `OPERATION_HANDOFF.md`.

Current known SL-PHASE-5Q state as of the latest handoff:

- Build is largely working and should be preserved before further repair work.
- Overall readiness is approximately 97%, not autonomous-ready.
- Latest known Decision version: `afe08974-b635-4a56-be42-d005ba7f3520` (`afe08974`).
- Latest known HumanApproval version: `7aac637e-e57a-44b3-91c4-96b9e4f0d064` (`7aac637e`).
- Latest known harness: `349/349 PASS`.
- Proof/trust classification variants were repaired for `trust`, `trustworthy`, `credible`, `believe`, and proof/evidence wording.
- Sender is untouched.
- Shadow Evaluator is inactive.
- Gate 2 is unapproved.
- Autonomous mode is disabled.

## Main Workflows

Production n8n operations target:

`https://n8n.hmzaiautomation.com/api/v1`

Primary workflows in current 5Q context:

| Workflow | Production ID | Current known role |
|----------|---------------|--------------------|
| Decision | `tgYmY97CG4Bm8snI` | Classification, learning-policy application, draft-policy selection, proof/trust repairs |
| HumanApproval | `9aPrt92jFhoYFxbs` | Review-case creation, review UI, approval/learning capture |
| Sender | See handoff before touching | Send path; do not touch without explicit owner approval |
| Shadow Evaluator | `aHzLtQiv6G8h1bqD` | Inactive; do not activate without explicit owner approval |

Older local/Docker workflow IDs in historical docs may be stale.

## Source Of Truth

Use this order when files conflict:

1. `OPERATION_HANDOFF.md` for current execution state and next action.
2. Current reports in `reports/`, especially the SL-PHASE-5Q live verification, closure, and anti-false-positive audit reports.
3. `AGENTS.md` and `CLAUDE.md` for agent/session safety rules.
4. `docs/SOURCE_PRIORITY.md`, `docs/HMZ_APPROVED_REPLY_RULES.md`, and `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` for approved business/reply facts.
5. This README as a concise orientation only.

## Safety Gates

- `DRY_RUN=true` remains the default.
- No live sends without explicit owner approval and campaign allowlist entry.
- No Sender changes unless explicitly approved in the current session.
- No Shadow Evaluator activation unless explicitly approved.
- No Gate 2 approval or autonomous enablement unless explicitly approved.
- No SL-PHASE-5R work until SL-PHASE-5Q live verification and anti-false-positive audit are complete.
- Run `scripts/assert-hmz-production-target.ps1` before any n8n API call.
- Never commit secrets, tokens, cookies, API keys, `.env` files, credentials, or unsafe generated artifacts.

## Agent Workflow

Start each session by reading `OPERATION_HANDOFF.md`, then only the narrow docs/reports needed for the task. Avoid full-repository scans unless the owner explicitly authorizes them.

For checkpoint or preservation work, stage only intended safe files and run `git diff --check` plus a secret/risk pattern scan on candidate files before committing.

## Next Recommended Step

Run a fresh owner live retest for the proof/trust path. If classification is correct but `AI_OUTPUT_VALIDATION_FAILED` or the safe fallback banner appears too often, the next repair should be a narrow Decision-focused fix for proof/trust AI validation and fallback frequency. Do not start autonomous or SL-PHASE-5R first.
