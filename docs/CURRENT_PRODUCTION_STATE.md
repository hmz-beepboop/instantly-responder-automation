# Current Production State

**Last updated:** 2026-06-23
**Status:** 99.99% — SL-PHASE-4A applied; self-improving 70% installed, retest pending

## Production Target

| Setting | Value |
|---------|-------|
| n8n API base URL | `https://n8n.hmzaiautomation.com/api/v1` |
| n8n UI | `https://n8n.hmzaiautomation.com` |

**FORBIDDEN unless user explicitly says "local dev":** localhost, 127.0.0.1, Docker Desktop, port 5678, docker-compose, container `hmz-n8n-local-dev`.

## Workflow IDs (Production)

| Workflow | ID |
|----------|----|
| Intake | `VtDQqw02Ux1TgjIH` |
| Decision | `tgYmY97CG4Bm8snI` |
| HumanApproval | `9aPrt92jFhoYFxbs` |
| Sender | `ePS5uBBxKxhFCYgU` |
| ErrorHandler | `2PR9YEkG4KyGdowa` |
| SLAWatchdog | `6a8ojyXCwMwI9nyF` |
| FullTestHarness | `RLUcJHQJPvLhw4mG` |

**FullTestHarness must remain INACTIVE unless explicitly testing.**

## Applied Improvements (Verified in Production)

- Specific micro-intent classification shown in Google Chat notification
- `this.helpers.httpRequest` used for all OpenAI calls (not HTTP Request node)
- OpenAI model working correctly
- `raw_draft_text` captured in decision output
- Validator false positives reduced
- AI prompt avoids forbidden proof/results/case-study terms
- Duplicate signoff fixed (exactly one per review card)
- Deterministic booking link injection added
- Booking link: `https://calendar.app.google/bNXWJkS3xz3yqdW36`
- Latest path: proof/case-study replies → `ai_supervised` draft mode
- **SL-PHASE-4A (2026-06-23):** Multi-intent detection + AI-assisted commercial drafts
  - Dec-B: `detectAllIntents()` scans for PRICING_REQUEST, DATA_SECURITY_REQUEST, CONTRACT_TERMS_REQUEST, SMALL_SCALE_PILOT_REQUEST, SCOPE_REQUEST as secondary intents
  - Dec-B: `isCommercialSafe()` gate; PRICING_REQUEST with no blocking det-flags → `AI_COMMERCIAL_SUPERVISED` effective draft policy
  - Dec-D: New deterministic commercial draft branch (no extra OpenAI call); never invents prices, contract terms, data guarantees, results; includes calendar link once
  - HA-D: Google Chat notification shows additional detected intents + AI draft label
  - HA-J: Review form shows detected intents, AI draft banner, pre-populates additional_intents_shadow field
  - Decision versionId: `87f933e9-a16b-4601-82de-f38fffd59c97`
  - HumanApproval versionId: `8430c40d-9ad6-4294-bfaf-5538203f45bf`

## Operating Mode

- `OPERATING_MODE=VALIDATION`
- `DRY_RUN=true` default — no real send without explicit owner approval
- Substantive replies routed to human approval, never auto-sent
- AI used only for semantic classification and T2 draft generation

## Final Acceptance Remaining (to claim 100%)

1. One real controlled Gmail reply triggers the webhook
2. Google Chat card shows `ai_supervised` mode
3. Review form shows safe draft with exactly one sender signoff and calendar link once
4. Human approves once
5. Sender sends exactly once
6. Gmail receives exactly one same-thread reply (no duplicate)
