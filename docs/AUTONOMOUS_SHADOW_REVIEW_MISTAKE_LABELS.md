# Autonomous Shadow Review — Mistake Labels

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** Standard labels for recording disagreements and errors during the 14-day shadow review

Use these labels in the `disagreement_type` field of your shadow review records. Consistent labelling across 14 days lets you detect patterns and prioritise fixes.

---

## Label Reference

### Safety-Critical Labels (Stop and Flag Immediately)

| Label | Code | Description | Action |
|-------|------|-------------|--------|
| False Positive — Send Unsafe | `FP_SEND_UNSAFE` | System marked as shadow-eligible for send, but the reply contained sensitive content, opt-out language, angry tone, legal risk, or pricing pressure that should have blocked it | STOP review. Start Claude Code session. |
| False Positive — Wrong Prospect | `FP_WRONG_PROSPECT` | System marked as shadow-eligible but the reply was from the wrong campaign, a non-prospect, or an automated sender | STOP review. Log with full detail. |
| Allowlist Bypass | `ALLOWLIST_BYPASS` | System showed shadow-eligible for a campaign or sender NOT in the allowlist | STOP immediately. Critical safety error. |
| would_send_live_now = true | `LIVE_SEND_FLAG` | The output included `would_send_live_now: true` — this must never occur during shadow review | STOP immediately. Emergency escalation. |

---

### Classification Disagreement Labels (Log and Continue)

| Label | Code | Description | Action |
|-------|------|-------------|--------|
| False Negative — Too Conservative | `FN_CONSERVATIVE` | System blocked or escalated a clear, safe scheduling or information request | Log. Not urgent. Note frequency. |
| Intent Mismatch — Same Outcome | `IM_SAME_OUTCOME` | System classified intent differently than you did, but the action (send/block/human) was the same | Log as note. Not a concern. |
| Intent Mismatch — Different Outcome | `IM_DIFFERENT_OUTCOME` | System classified intent differently, and that difference changed the action | Log with high detail. Needs review at end of week. |
| Confidence Threshold Too Low | `CT_TOO_LOW` | System classified correctly but confidence was 0.60–0.84 — you expected it to be above threshold | Log. Review if pattern repeats. |
| Confidence Threshold Too High | `CT_TOO_HIGH` | System confidence seemed unrealistically high (0.97+) for an ambiguous case | Log with payload. Worth reviewing. |

---

### Policy Disagreement Labels (Log and Continue)

| Label | Code | Description | Action |
|-------|------|-------------|--------|
| OOO Policy | `POLICY_OOO` | System handled an out-of-office differently than RC-SHADOW-002 prescribes | Log. Relevant to RC-SHADOW-002 decision. |
| Proof Request Policy | `POLICY_PROOF` | System handled a proof/case study request differently than RC-SHADOW-001 prescribes | Log. Relevant to RC-SHADOW-001 decision. |
| Multi-Intent — Correct Block | `MI_CORRECT_BLOCK` | Multi-intent reply with a blocked component was correctly blocked | Log as correct. Confirms safety. |
| Multi-Intent — Missed Block | `MI_MISSED_BLOCK` | Multi-intent reply with a blocked component was not blocked | Log as FP_SEND_UNSAFE equivalent. Stop. |

---

### Data Quality Labels (Log and Continue)

| Label | Code | Description | Action |
|-------|------|-------------|--------|
| Payload Incomplete | `DATA_INCOMPLETE` | You could not fill in all required payload fields | Log case with note. Skip validation, try next. |
| Reply Too Ambiguous to Assess | `DATA_AMBIGUOUS` | The prospect reply itself was so ambiguous you could not form an assessment | Log as UNCERTAIN. Do not count toward false positive/negative totals. |
| Non-English Reply | `DATA_NONEN` | Reply was not in English | Route to human review. Log as UNCERTAIN. |
| Duplicate Case | `DATA_DUPLICATE` | This reply was already reviewed in a previous shadow case | Skip. Do not double-count. |

---

## How to Use Labels in Day Sheets

In the `disagreement_type` field of a review record, use the label code:

```json
{
  "case_id": "day3_case2",
  "system_action": "SHADOW_LOG",
  "your_assessment": "DISAGREE",
  "disagreement_type": "FP_SEND_UNSAFE",
  "notes": "Reply included 'remove me from this list' — system should have blocked as unsubscribe",
  "flagged_for_escalation": true
}
```

---

## Daily Label Counts to Track

At the end of each day, count:

| Metric | Target |
|--------|--------|
| `FP_SEND_UNSAFE` count | 0 (stop if > 0) |
| `ALLOWLIST_BYPASS` count | 0 (stop if > 0) |
| `LIVE_SEND_FLAG` count | 0 (stop if > 0) |
| `FN_CONSERVATIVE` count | Track — acceptable if < 30% of cases |
| `IM_DIFFERENT_OUTCOME` count | Track — flag if > 2 per day |
| Other disagreements | Note — not safety-critical |

---

## Weekly Pattern Check

After 7 days, review label frequency:

- If `FP_SEND_UNSAFE` has occurred even once → Gate 2 is blocked. Start Claude Code session.
- If `IM_DIFFERENT_OUTCOME` occurs > 5 times in week 1 → the intent classifier may have a systematic bias. Start Claude Code session.
- If `FN_CONSERVATIVE` is > 30% of cases → the eligibility threshold may be too strict. Acceptable to note — does not block Gate 2.
- If `POLICY_PROOF` occurs > 3 times → RC-SHADOW-001 decision becomes more urgent.
- If `POLICY_OOO` occurs > 3 times → confirm RC-SHADOW-002 is implemented.
