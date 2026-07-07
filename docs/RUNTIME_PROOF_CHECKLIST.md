# Runtime Proof Checklist (Gate S1/S3 source of truth)

**Created:** 2026-07-07 (Fable Run 3). **Purpose:** the harness (`scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`) simulates logic in Python and statically checks JS; it cannot prove live runtime behaviour. This checklist is the runtime source of truth. The old controlled-live acceptance harness is NOT a substitute.

Each item needs: date, execution/case ID, and who observed it. Anything unchecked is UNPROVEN — do not claim it.

## A. Supervised review loop (Gate S1)

| # | Proof | Last evidence | Status |
|---|-------|---------------|--------|
| A1 | Fresh inbound reply produces a review case with full context (campaign, lead, sender, subject, body) | exec 5263, 2026-07-05 | PROVEN (recheck after Intake changes) |
| A2 | Review form renders for an AI-supervised case (blue banner, non-empty textarea) | cases 58e6b3b0 / 5e2fbcbe rows, 2026-07-07 (form render owner-confirm pending post-99b4c092) | PARTIAL |
| A3 | Review form renders for ai_failed_fallback (yellow banner names failed check) | case-13c3dad3 reopen fix, 2026-07-05 | PROVEN (pre-99b4c092 UI) |
| A4 | Review form renders for human-only and deterministic-template cases | P5/P11 static + earlier lives | PROVEN (static) / owner re-confirm pending |
| A5 | Original vs Effective classification + Reply mode + AI draft status visible (Run 3 UI fix) | offline render vs real case-4a5596a0 row, 2026-07-07 | OFFLINE PROVEN — live owner confirm pending |
| A6 | Save / approve / learning-only / deny paths update the case row correctly | P14 + session-10 live | PROVEN |
| A7 | Blocked approval keeps the same review link and shows the exact reason | 4G + P10 | PROVEN |
| A8 | Stale link approval after SENT is blocked (already-sent banner; no resend) | 5P live, 2026-06-26 | PROVEN |
| A9 | Google Chat notification shows effective classification and review link with expiry | Run 3 chat patch — live confirm pending | PENDING |

## B. Send path (Gate S3 — only during an owner-approved controlled send)

| # | Proof | Last evidence | Status |
|---|-------|---------------|--------|
| B1 | Reply sent from the same eaccount that received the inbound | 4H matrix, 2026-06-23 | STALE — re-prove on next send |
| B2 | Reply addressed to the original prospect lead only (no cc/bcc) | 4H matrix | STALE — re-prove |
| B3 | Reply lands in the same thread with non-blank visible body | 4H matrix | STALE — re-prove |
| B4 | `hmz-send-key` marker present in sent HTML | code-verified 2026-07-07 (Q node); live check on next send | PENDING |
| B5 | Duplicate approval/webhook replay produces zero extra sends | send-state lock code-verified; live replay drill never run | NOT PROVEN |
| B6 | SEND_UNCERTAIN produces reconciliation poll + human case, never blind retry | R/W nodes code-verified 2026-07-07 | CODE-PROVEN, no live occurrence |
| B7 | Reopened-case "send another reply" stays manual (FOLLOWUP_SEND_PENDING_MANUAL) | 5P, 2026-06-26 | PROVEN |

## C. Learning loop (Gate S2)

| # | Proof | Last evidence | Status |
|---|-------|---------------|--------|
| C1 | Classification correction rule consumed live | rule 6e50fd54, cases 4a5596a0/07bd8bb5/659d1e01, 2026-07-07 | PROVEN |
| C2 | Style rule injected into real AI draft | rule ea15095a, case-58e6b3b0, 2026-07-07 | PROVEN |
| C3 | Deterministic→AI upgrade produces AI draft live | not-now cases above (`ai_upgrade_eligible=true`, ai ok) | PROVEN |
| C4 | Live rollback drill (deactivate one rule, probe, restore) | offline drill P20.38-40 only | LIVE DRILL PENDING |

Update this file in the same session as any new runtime evidence.
