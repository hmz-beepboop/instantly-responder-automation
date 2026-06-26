# Gate 2 Sign-Off Blockers

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** Gate 2 NOT YET APPROVED  
**Purpose:** Single-page reference — exactly what is blocking Gate 2 right now

---

## Current Blockers (All Must Be Resolved)

| # | Blocker | Who | Status | Unblocked When |
|---|---------|-----|--------|----------------|
| 1 | 14-day shadow review not yet started | Owner | BLOCKED | Owner completes 14 days of manual shadow review |
| 2 | RC-SHADOW-001 not signed | Owner | PENDING | Owner signs proof request policy in Gate 2 packet |
| 3 | RC-SHADOW-002 not signed | Owner | PENDING | Owner signs OOO policy in Gate 2 packet |
| 4 | `campaign_allowlist` is empty | Owner | BLOCKED | Owner provides campaign ID(s) via worksheet |
| 5 | `sender_allowlist` is empty | Owner | BLOCKED | Owner provides sender email(s) via worksheet |
| 6 | `intent_allowlist` is empty | Owner | BLOCKED | Owner confirms intent types via worksheet |
| 7 | Gate 2 checklist not signed | Owner | BLOCKED | Owner signs `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` |

---

## Already Resolved (Not Blockers)

| Item | Status | Resolved |
|------|--------|---------|
| RC-SHADOW-003 allowlist wire-up | COMPLETE | 2026-06-24 |
| Shadow evaluator workflow imported | COMPLETE | 2026-06-24 |
| Shadow evaluator acceptance harness | 45/45 PASS | 2026-06-24 |
| Shadow evaluator active=false | VERIFIED | 2026-06-24 |
| Allowlist enforcement logic in n8n | COMPLETE | 2026-06-24 |
| 20 offline allowlist tests | 20/20 PASS | 2026-06-24 |
| 20 shadow webhook tests | 20/20 PASS | 2026-06-24 |
| Kill switch drill | PASS (15s) | 2026-06-24 |
| Core supervised responder | 100% COMPLETE | earlier |
| Self-improving layer | 100% COMPLETE + PROVEN | earlier |

---

## What Unblocking Looks Like

### Blocker 1 — Shadow Review

The owner manually reviews real Instantly.ai replies using:
```
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -GeneratePayloadTemplate
.\scripts\SL-PHASE-5I-manual-shadow-review-helper.ps1 -CreateDailyReviewSheet -Day N
```

Minimum requirement: 14 days, 30+ cases, no unresolved false positives.

### Blockers 2–3 — RC-SHADOW Decisions

Owner reads and signs `docs/GATE_2_OWNER_DECISION_PACKET.md` (RC-SHADOW-001 and RC-SHADOW-002 sections).

### Blockers 4–6 — Allowlists

Owner completes `docs/GATE_2_ALLOWLIST_SELECTION_WORKSHEET.md` and provides values to Claude Code for a controlled update session.

### Blocker 7 — Gate 2 Checklist

Owner completes all items and signs `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md`.

---

## Minimum Timeline

The fastest Gate 2 can proceed is **14 days from now** (earliest: ~2026-07-08).

This is not a timeline the system can compress. The 14-day minimum exists so the owner sees enough real traffic variation to trust the autonomous decisions.

---

## What Happens if Gate 2 Is Approved

A Claude Code session with explicit owner instruction will:

1. Populate allowlists with owner-approved values
2. Set `autonomous_enabled = true`
3. Set `shadow_only = false`
4. Set `dry_run = false`
5. Set `max_autonomous_sends_per_day = 1`
6. Activate the autonomous shadow evaluator workflow in n8n
7. Run final acceptance check
8. Confirm owner receives the first autonomous action notification before any send

**Nothing in this list may be done without explicit owner instruction in that session.**

---

## What Stays the Same After Gate 2

| Item | Post-Gate-2 Status |
|------|-------------------|
| Core supervised responder | Unchanged — still running |
| Human review for all non-autonomous cases | Unchanged |
| Decision, HumanApproval, Proxy workflows | Unchanged |
| Self-improvement layer | Unchanged |
| All safety gates except the 6 listed above | Active |
| Escalation to Google Chat | Active |
| Post-action review requirement | Active |
