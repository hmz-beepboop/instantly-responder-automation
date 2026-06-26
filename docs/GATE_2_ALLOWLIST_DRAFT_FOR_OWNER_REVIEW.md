# Gate 2 Allowlist Draft — For Owner Review Only

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5K — Gate 2 Evidence Start  
**Status:** DRAFT — DO NOT POPULATE PRODUCTION ALLOWLISTS YET

---

## WARNING

This document is a planning worksheet only. Nothing here is active.

Do not ask Claude Code to populate production allowlists from this document until:
- [ ] 14-day shadow review is complete (minimum 30 cases reviewed)
- [ ] RC-SHADOW-001 and RC-SHADOW-002 are signed
- [ ] You have explicitly decided to approve Gate 2

---

## What the Allowlists Do

Three allowlists control which events the autonomous shadow evaluator may flag as eligible for autonomous action:

| Allowlist | Controls |
|-----------|---------|
| `campaign_allowlist` | Only events from these campaign IDs can be eligible |
| `sender_allowlist` | Only events from these sender email addresses can be eligible |
| `intent_allowlist` | Only events with these micro-intent classifications can be eligible |

If **any** allowlist is empty, **no event is eligible**. All three must have at least one value before any event can pass eligibility.

A prospect reply that doesn't match all three lists is automatically routed to human review — the same as today.

---

## Section 1 — Campaign Allowlist Draft

**Instructions:** List the campaign IDs from Instantly.ai that you want the controlled pilot to act on.

Start with 1–2 campaigns maximum. Choose campaigns where:
- Replies tend to be simple and low-risk (scheduling, basic interest)
- You have reviewed enough replies to have confidence in the pattern
- You are comfortable with 1 autonomous send per day from these campaigns

| Draft Entry # | Campaign ID | Campaign Name (your label) | Your Confidence | Notes |
|--------------|-------------|---------------------------|-----------------|-------|
| 1 | _(fill in)_ | _(fill in)_ | Low / Medium / High | |
| 2 | _(fill in)_ | _(fill in, optional)_ | Low / Medium / High | |

**Recommendation:** Start with 1 campaign only. Add a second only after 7+ shadow review days confirm it.

---

## Section 2 — Sender Allowlist Draft

**Instructions:** List the sender email addresses (from your Instantly.ai workspace) that the controlled pilot may act on behalf of.

Start with 1–3 senders maximum. Choose senders where:
- You are the owner/controller of that sending domain
- Replies from that sender's campaigns have been reviewed in shadow testing
- You trust the reply templates for that sender's tone and context

| Draft Entry # | Sender Email | Sending Domain | Campaign(s) | Notes |
|--------------|-------------|---------------|-------------|-------|
| 1 | _(fill in)_ | _(fill in)_ | _(fill in)_ | |
| 2 | _(optional)_ | | | |
| 3 | _(optional)_ | | | |

**Recommendation:** Start with 1 sender. Matches the 1-campaign start recommendation.

---

## Section 3 — Intent Allowlist Draft

**Instructions:** The controlled pilot should only act on the safest, most predictable intent types. Recommendations below.

### Recommended for Gate 2 (Conservative Starting Point)

| Intent | Micro-Intent Value | Why Safe |
|--------|-------------------|----------|
| Simple scheduling request | `SCHEDULING_REQUEST` | Clear intent, templated reply, low risk |
| Simple information request | `INFORMATION_REQUEST` | Clear intent, templated reply, low risk |

### Optional — Positive Interest (Only if 7+ shadow days support it)

| Intent | Micro-Intent Value | Risk |
|--------|-------------------|------|
| Simple positive interest | `POSITIVE_INTEREST` | Slightly higher variability — only include if shadow review confirmed consistent handling |

### Explicitly Blocked — Do Not Include

These must never be in the intent allowlist, regardless of Gate 2 approval:

| Blocked Intent | Reason |
|---------------|--------|
| `PRICING` | Pricing is human-only per approved reply rules |
| `NEGOTIATION` | Requires human judgment |
| `CONTRACT_TERMS` | Legal — never autonomous |
| `LEGAL` / `COMPLIANCE` | Regulatory — never autonomous |
| `GDPR_DATA_PRIVACY` / `SECURITY` | Regulatory — never autonomous |
| `ANGRY_COMPLAINT` | Sensitive — human required |
| `UNSUBSCRIBE` / `OPT_OUT` | Must be human-handled and hard-suppressed immediately |
| `BILLING` / `REFUND` | Financial — never autonomous |
| `AMBIGUOUS` | Low confidence — human review only |
| `MULTI_INTENT` with any blocked component | If any part of the reply is blocked, the whole reply is blocked |
| `PROOF_REQUEST` | Pending RC-SHADOW-001 — default human-only |
| `OUT_OF_OFFICE` | Per RC-SHADOW-002 — default human-only |
| `COMPETITOR_MENTION` | Requires careful human handling |
| `GUARANTEE_REQUEST` | Cannot make guarantees autonomously |

### Your Intent Selections for Gate 2

Mark the intents you want to include:

- [ ] `SCHEDULING_REQUEST` *(recommended)*
- [ ] `INFORMATION_REQUEST` *(recommended)*
- [ ] `POSITIVE_INTEREST` *(optional — only after 7+ shadow days)*
- [ ] Other: _____________________ *(describe and justify)*

---

## Section 4 — Summary Sign-Off Block

Complete this only when you are ready to provide values to Claude Code for a controlled update session:

| Allowlist | Values Ready? | Count |
|-----------|-------------|-------|
| campaign_allowlist | Yes / No / Partial | |
| sender_allowlist | Yes / No / Partial | |
| intent_allowlist | Yes / No / Partial | |

**I confirm that these allowlist values are correct and I am ready to instruct Claude Code to apply them in a Gate 2 activation session:**

Signature / Initials: ___________________________  
Date: ___________________________

**Note:** Signing this section does not activate Gate 2. You must also explicitly tell Claude Code "Gate 2 approved — apply allowlists" in a dedicated session.

