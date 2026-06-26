# Final Acceptance Checklist

**Last updated:** 2026-06-22
**Status:** PENDING — 99.99% built, awaiting one controlled live acceptance test

## Purpose

These are the exact steps required to claim 100% build completion and move to next-phase planning. Do not claim production readiness until every item is checked.

## Pre-Test Gates (must all pass before test)

- [ ] Production n8n health check passes at `https://n8n.hmzaiautomation.com/api/v1`
- [ ] Intake workflow (`VtDQqw02Ux1TgjIH`) is active
- [ ] Decision workflow (`tgYmY97CG4Bm8snI`) is active
- [ ] HumanApproval workflow (`9aPrt92jFhoYFxbs`) is active
- [ ] Sender workflow (`ePS5uBBxKxhFCYgU`) is active
- [ ] FullTestHarness (`RLUcJHQJPvLhw4mG`) is INACTIVE
- [ ] `DRY_RUN=true` confirmed in config (for shadow test) OR explicitly set to false with owner approval for live send
- [ ] Test Gmail account ready to send a controlled reply

## Controlled Live Test Steps

1. Send one real Gmail reply to a test Instantly campaign email
2. Confirm webhook received in Intake workflow execution log
3. Confirm Decision workflow runs and produces `action_plan` with `ai_supervised` draft mode
4. Confirm Google Chat card appears showing:
   - Micro-intent classification (specific, not generic)
   - Draft mode: `ai_supervised`
5. Confirm review form shows:
   - Safe draft text (no forbidden terms: proof, results, case study, guaranteed, established)
   - Exactly one sender signoff
   - Calendar link `https://calendar.app.google/bNXWJkS3xz3yqdW36` exactly once
6. Human approves in review form (one click, once)
7. Confirm Sender workflow triggers once
8. Confirm Gmail receives exactly one reply in the same thread
9. Confirm no duplicate reply is sent (wait 5 minutes, check thread again)

## Pass Criteria

| Check | Expected |
|-------|----------|
| Webhook acknowledgement | Immediate |
| Classification + action plan | Within 60 seconds |
| Google Chat notification | Within 120 seconds |
| Draft in review form | Within 120 seconds |
| Reply sent after approval | Within 5 minutes of approval |
| Duplicate reply | None |
| Forbidden terms in draft | None |
| Signoff count | Exactly 1 |
| Calendar link count | Exactly 1 |

## After Passing

- Update `docs/CURRENT_PRODUCTION_STATE.md` status to 100%
- Record pass date and test details in `docs/ASSUMPTIONS_AND_UNKNOWNS.md`
- Begin next phase with documentation and architecture only (see `docs/NEXT_PHASE_ROADMAP_SELF_IMPROVING_AND_AUTONOMOUS.md`)
