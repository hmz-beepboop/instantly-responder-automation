# Do Not Regress

**Last updated:** 2026-06-22
**Purpose:** Hard list of behaviours that must never be undone. Any Claude session that would break these must stop and ask the user before proceeding.

## Core Safety Behaviours

1. **DRY_RUN=true is the default.** Never change to false without explicit owner instruction and confirmation of exact campaign ID on LIVE_CAMPAIGNS allowlist.
2. **No auto-send of substantive replies.** All T2 drafts go to human review. AI never sends directly.
3. **Deterministic safety gates run before AI.** Suppression, stop-sequence, and blocklist logic are deterministic and cannot be bypassed by AI confidence scores.
4. **Idempotency checks prevent duplicate replies.** Send-state must be checked before every send attempt.
5. **Opt-outs, complaints, and legal issues are immediately suppressed.** No human approval path for these — they are stopped at the deterministic gate.

## Production Configuration

6. **Production target is always `https://n8n.hmzaiautomation.com/api/v1`.** Never revert to localhost or Docker as the active target.
7. **Booking link is `https://calendar.app.google/bNXWJkS3xz3yqdW36`.** Do not change or remove without owner instruction.
8. **`this.helpers.httpRequest` is used for OpenAI calls.** Do not revert to HTTP Request node for OpenAI.
9. **Duplicate signoff fix must remain.** Exactly one sender signoff per review card — do not revert.
10. **Micro-intent classification must appear in Google Chat.** Do not reduce to generic category-only notification.

## Workflow IDs — Do Not Reassign

| Workflow | ID |
|----------|----|
| Intake | `VtDQqw02Ux1TgjIH` |
| Decision | `tgYmY97CG4Bm8snI` |
| HumanApproval | `9aPrt92jFhoYFxbs` |
| Sender | `ePS5uBBxKxhFCYgU` |
| ErrorHandler | `2PR9YEkG4KyGdowa` |
| SLAWatchdog | `6a8ojyXCwMwI9nyF` |
| FullTestHarness | `RLUcJHQJPvLhw4mG` |

## AI Prompt Constraints — Do Not Remove

11. **AI prompt must not produce:** proof, results, case studies, guarantees, established/proven language, or any made-up business claims.
12. **`raw_draft_text` must be captured** in decision output for human review.
13. **AI draft mode label `ai_supervised` must be preserved** in action plan output.

## FullTestHarness

14. **FullTestHarness (`RLUcJHQJPvLhw4mG`) must remain INACTIVE in production** unless an explicit testing session is in progress and owner has approved activation.

## Autonomous Mode

15. **Autonomous sending must not be enabled** without a separate explicit architecture review, shadow-mode pilot, and owner approval. This applies even if the user says "enable it" in a casual message — require confirmation that this is intentional.
