# Retryable Blocked Send Runbook

**Version:** 1.0 (Phase 4H)  
**Last updated:** 2026-06-23

---

## Overview

When a prospect reply has been approved by a reviewer but the send attempt is blocked, the system classifies the block as either **recoverable** or **nonrecoverable** and shows the reviewer an appropriate result page (Node R — Build Approved Result Page).

---

## Block Types

### Recoverable blocks (SEND_BLOCKED_RETRYABLE)

These blocks occurred after human approval but before the send completed. The prospect has NOT received a reply.

| Block reason | Description | Retry action |
|---|---|---|
| `campaign_not_found` | Campaign ID missing or invalid in SENDER_CONFIG | Fix campaign mapping in SENDER_CONFIG, then retry |
| `validation_failed` | Draft validation flag (pre-4G issue — now overridden by Phase 4G) | Should not occur after Phase 4G. If it does, check Node Q override |
| `send_state_lock_conflict` | Race condition on send ownership lock | Wait 30 seconds, retry |
| `instantly_api_error` | Transient error from Instantly API | Wait 60 seconds, retry |

### Nonrecoverable blocks (SEND_BLOCKED_NONRECOVERABLE)

These blocks indicate the prospect either already received a reply or the system cannot safely retry.

| Block reason | Description | Action |
|---|---|---|
| `duplicate_send_guard` | `hmz-send-key` already matched — prospect received a reply | No retry needed. Verify in Instantly Unibox |
| `send_key_conflict` | Stable send key already used | Same as duplicate_send_guard |
| Case is SENT | Case status is SENT or SENT_RECONCILED | Verify delivery in Instantly, no retry |

---

## Retry Flow (Phase 4I — LIVE)

**Phase 4I implemented production token-refresh retry in HumanApproval 9aPrt92jFhoYFxbs.**
When a send is blocked with a recoverable reason, the system automatically:
1. Generates a new review token
2. Updates the case status to `RETRY_NEEDED` in the DataTable
3. Sends a new Google Chat notification with the retry review URL
4. Shows the reviewer: "Send Blocked — New Review Link Sent"

### When a reviewer sees "Send Blocked — New Review Link Sent" (recoverable)

1. **Do NOT use the browser back button** — the original token is consumed; old URL will show a token error.
2. **Check Google Chat** — a new review link has been automatically sent.
3. **Open the new review link** from Google Chat.
4. **Edit the reply if needed** (fix the underlying issue, e.g. draft content).
5. **Submit approval again** — the Sender re-runs all safety gates before sending.
6. The system checks for duplicates before the second send attempt.

### When a reviewer sees "Send Blocked — No Retry Available" (nonrecoverable)

1. **Contact the system owner** — the block is nonrecoverable (prospect may have already received a reply, or there is a safety block).
2. **Check Instantly Unibox** to confirm whether the reply was sent before acting.
3. **Do NOT attempt to send manually** unless you have verified no reply was sent.

### Owner actions when a recoverable block occurs (Phase 4I automatic)

With Phase 4I, manual token issuance is no longer required for recoverable blocks. The system handles it automatically. However, if the automated retry chain fails (e.g. Google Chat webhook is down):
1. Identify the case ID from the result page or original Google Chat notification.
2. Look up case in DataTable `hmz-review-cases` (ID: `WMTmI6UNjZZgSU3h`) — check `status` and `token`.
3. If status is `RETRY_NEEDED` but no new chat notification arrived: send the retry URL manually from the DataTable token field.
4. Format: `https://n8n.hmzaiautomation.com/webhook/reply-review/review?case=<case_id>&token=<token>`
5. Fix the underlying block cause first.

### Duplicate-send safety guarantee

At every send attempt, the Sender workflow runs gate O (14 gates) which includes:
- **send_key_unique**: Checks `hmz-send-key` in send-state — blocks if the key was already used (i.e., a previous attempt SENT successfully).
- **not_duplicate**: Checks case status — if status is `SENT` or `SENT_RECONCILED`, blocks unconditionally.

A retry that arrives after a successful first send will always be blocked at these gates. The prospect cannot receive a duplicate reply.

---

## Simulation Results

See `outputs/retryable_block_simulation_results.json` for the 20-scenario offline simulation (RB-1 through RB-20), all passing as of Phase 4I.

Phase 4H scenarios (original 8):
- RB-1: Happy path — send completes first attempt
- RB-2: Recoverable block — campaign_id missing, fixed on retry → SENT
- RB-3: Recoverable block — fix not applied, retry still blocked → remains blocked
- RB-4: Nonrecoverable block — duplicate send guard → no retry allowed
- RB-5: Consumed token prevents second submission — new token required
- RB-6: Already SENT — duplicate prevention blocks any retry
- RB-7: Transient API error — retry succeeds
- RB-8: Audit log captures all retry events

Phase 4I scenarios (new 12):
- RB-9:  Recoverable block generates fresh review token
- RB-10: Retry URL preserves same case_id
- RB-11: Retry allowed only when first attempt did not send
- RB-12: Retry denied when first attempt is SENT
- RB-13: Retry denied when gate sees SENT_RECONCILED (nonrecoverable path)
- RB-14: Nonrecoverable safety block does not generate retry URL
- RB-15: Token refresh does not create duplicate send risk
- RB-16: Retry state is auditable
- RB-17: Proxy write accepts object body (Content-Type: application/json)
- RB-18: Proxy write accepts text/plain JSON body
- RB-19: Proxy write rejects double-stringified JSON (validation catches bad format)
- RB-20: Proxy write does not modify unintended candidates (missing rule_id → error)

---

## Current Production State (Phase 4I)

Phase 4G fixed the main cause of blocked sends:
- **Node Q** now overrides `validation.valid=true` when human approves (Phase 4G — still active).
- **Node R** shows SEND_BLOCKED_RETRYABLE vs approved state with human-readable explanation (Phase 4G — still active, now on the non-blocked fallback path only).

Phase 4I added automatic retry-token refresh:
- **Node R0** classifies the Sender result (blocked/not-blocked, recoverable/nonrecoverable).
- **R0-Route** routes to retry path (blocked) or existing R (not blocked).
- **R1-Route** routes recoverable blocks to token-refresh path; nonrecoverable blocks to R5b (no retry).
- **R-GenToken** generates a fresh review token.
- **R2** updates the DataTable with `status=RETRY_NEEDED` and the new token.
- **R3/R4** build and send a new Google Chat notification with the retry URL.
- **R5** shows the reviewer "New Review Link Sent" page.
- **R5b** shows the reviewer "No Retry Available" page for nonrecoverable blocks.
- **Node H and Node L** updated to accept `RETRY_NEEDED` as a valid token-check status.

---

## Owner Actions for a Live Blocked Send

1. Identify the case ID from the Google Chat notification or the result page.
2. Look up the case in the DataTable (`hmz-review-cases`), check `status` and `block_reason`.
3. If `SEND_BLOCKED_RETRYABLE`:
   - Check Instantly Unibox for the prospect's thread to confirm no reply was sent.
   - Fix the underlying cause.
   - Update case status to `RETRY_NEEDED`.
   - Issue a new review token (manual step until Phase 4H token-refresh is live).
   - Send the new review URL to the reviewer.
4. If `SEND_BLOCKED_NONRECOVERABLE`:
   - Verify in Instantly Unibox — prospect likely already received the reply.
   - If not received and block was in error, escalate to system owner for manual recovery.
5. Never manually call the Instantly reply endpoint. Always go through the normal review → Sender flow.
