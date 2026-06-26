# Gate 2 Owner Decision Packet

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5J — Gate 2 Preparation  
**Written for:** Non-technical owner  
**Status:** GATE 2 NOT YET APPROVED — this packet is preparation only

---

## Plain-English Summary

This document explains what the system can currently do, what it cannot do, and exactly what you need to decide and sign before anything changes.

**Nothing in this document takes effect until you sign Gate 2. Reading and filling in this document does not activate anything.**

---

## What Is Safe Right Now

| What | Status |
|------|--------|
| Human-reviewed reply system | Running. You see every reply before it sends. |
| AI-drafted replies (supervised) | Running. AI drafts; you approve before send. |
| Self-improving classification | Running. System improves based on your corrections. |
| Autonomous shadow evaluator | **Installed but OFF.** It logs hypothetical decisions but never sends. |
| Autonomous live sending | **Does not exist yet. Nothing sends without you.** |

**Current position:** Everything requires your review and approval. The autonomous layer exists only as a planning/testing tool.

---

## What Has Not Been Enabled

| Capability | Status | Why |
|-----------|--------|-----|
| Autonomous sending | DISABLED | Requires Gate 2 |
| Controlled pilot (1 send/day) | DISABLED | Requires Gate 2 + allowlists |
| Shadow evaluator running live | DISABLED (active=false) | Requires Gate 2 activation |
| Allowlists populated | EMPTY | Requires your explicit input |

---

## Why Live Autonomous Sending Is Still Blocked

Six independent safety gates prevent any autonomous send:

1. `autonomous_enabled = false` — master switch is off
2. `shadow_only = true` — system is in observe-only mode
3. `dry_run = true` — no real sends in any mode
4. `max_autonomous_sends_per_day = 0` — daily cap at zero
5. `campaign_allowlist = []` — empty list blocks all campaigns
6. `sender_allowlist = []` — empty list blocks all senders

All six must be changed simultaneously with your explicit approval to enable Gate 2.

---

## Exact Gate 2 Requirements

Before Gate 2 can be approved, **all** of the following must be complete:

### Section A — Shadow Review (14 days)

- [ ] You (the owner) have completed at least 14 days of manual shadow review
- [ ] Each day: at least 1 real prospect reply reviewed using the shadow review helper
- [ ] Daily review sheets saved in `outputs/shadow_review_days/`
- [ ] At least 30 shadow review cases across the 14-day period
- [ ] You are satisfied with how the system classified each case

### Section B — RC-SHADOW Decisions

- [ ] RC-SHADOW-001 signed (proof request policy — see Section C below)
- [ ] RC-SHADOW-002 signed (out-of-office policy — see Section C below)
- [ ] RC-SHADOW-003 is already COMPLETE (allowlist wire-up done 2026-06-24)

### Section C — Allowlist Decisions

You must explicitly name which campaigns, senders, and intent types the autonomous pilot may act on. See `docs/GATE_2_ALLOWLIST_SELECTION_WORKSHEET.md` for the selection process.

- [ ] `campaign_allowlist` populated with 1–2 specific campaign IDs you have tested
- [ ] `sender_allowlist` populated with 1–3 specific sender email addresses
- [ ] `intent_allowlist` set to **SCHEDULING_REQUEST and/or INFORMATION_REQUEST only** (recommended starting point)

### Section D — Configuration Confirmation

- [ ] `confidence_threshold` confirmed at 0.85 or above
- [ ] `max_autonomous_sends_per_day` set to 1 (start with 1 only)
- [ ] `require_post_action_review = true` confirmed
- [ ] `live_pilot_requires_owner_toggle = true` confirmed

### Section E — Owner Sign-Off

- [ ] You have read this entire packet
- [ ] You understand the kill switch procedure (see below)
- [ ] You commit to reviewing every autonomous send the next morning
- [ ] You sign the Gate 2 checklist in `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md`

---

## Kill Switch Procedure

If anything looks wrong after Gate 2, here is the kill switch:

1. Go to `https://n8n.hmzaiautomation.com`
2. Open workflow `aHzLtQiv6G8h1bqD` (Shadow Evaluator / Autonomous)
3. Click the Active toggle to OFF
4. The system stops in under 15 seconds
5. Notify Claude Code in your next session that the kill switch was used

You do not need technical help to use the kill switch. This is the same as turning off a light switch.

---

## RC-SHADOW-001: Proof Request Policy — Your Decision Required

**What happened:** During shadow testing, the system correctly identified "proof request" replies (prospects asking for case studies, results, examples) and routed them to human review. Good.

**The question:** Should proof requests ever be eligible for an autonomous reply in the controlled pilot?

**Recommendation:** NO — defer this entirely. Proof requests require specific approved content (real case studies, data). Do not include PROOF_REQUEST in the intent allowlist.

**Your decision:**

- [ ] Defer — keep PROOF_REQUEST as human-only. Do not include in Gate 2 intent_allowlist. *(recommended)*
- [ ] Permanently block — add PROOF_REQUEST to the blocked-forever list
- [ ] Approve for Gate 2 — include PROOF_REQUEST in intent_allowlist *(not recommended without an approved template)*

**Signature/Date:** ___________________________

---

## RC-SHADOW-002: Out-of-Office Policy — Your Decision Required

**What happened:** During shadow testing, the system correctly identified out-of-office (OOO) replies and routed them to human review. Good.

**The question:** Should the system ever send an automated response when it detects an OOO reply?

**Recommendation:** NO — OOO replies are not actionable by automation. The correct response is to wait and let you decide whether to reschedule or park the prospect.

**Your decision:**

- [ ] Confirm human-only — OOO replies always go to human review, never autonomous. *(recommended)*
- [ ] Allow automated acknowledgement — system sends a brief "noted, will follow up" reply
- [ ] Permanently block — add OOO to the blocked-forever list

**Signature/Date:** ___________________________

---

## Intent Types: Allowed vs Blocked Forever at Gate 2

### Recommended for Gate 2 Allowlist (Safe Starting Point)

| Intent | Description | Why Safe |
|--------|-------------|----------|
| SCHEDULING_REQUEST | Prospect wants to book a call | Clear intent, low-risk standard reply |
| INFORMATION_REQUEST | Prospect wants general info | Clear intent, templated response |

### Blocked Forever at Gate 2 (Do Not Include)

| Intent | Why Blocked |
|--------|-------------|
| PRICING | Pricing is human-only per approved reply rules |
| NEGOTIATION | Requires human judgment |
| CONTRACT_TERMS | Legal — never autonomous |
| LEGAL / COMPLIANCE | Legal — never autonomous |
| GDPR / DATA_PRIVACY / SECURITY | Regulatory — never autonomous |
| ANGRY_COMPLAINT | Sensitive — requires human |
| UNSUBSCRIBE / OPT_OUT | Must be handled immediately by human and hard-suppressed |
| BILLING / REFUND | Financial — never autonomous |
| AMBIGUOUS | Low confidence — human review only |
| MULTI_INTENT with any blocked component | If any part of the reply is blocked, the whole reply is blocked |
| PROOF_REQUEST | Pending RC-SHADOW-001 decision — default human-only |
| OUT_OF_OFFICE | Per RC-SHADOW-002 — human-only |

---

## Do Not Proceed Conditions

Stop and do not proceed to Gate 2 if:

- [ ] You have not completed 14 days of shadow review
- [ ] Any of the daily review sheets show a false positive (system wanted to send when it should not have)
- [ ] Any of the daily review sheets show a disagreement you have not resolved
- [ ] RC-SHADOW-001 or RC-SHADOW-002 have not been signed
- [ ] The allowlists are still empty
- [ ] You are not comfortable reviewing every autonomous send the morning after it happens
- [ ] Anyone else (not you) is being asked to sign Gate 2

---

## Related Documents

- `docs/GATE_2_SIGNOFF_BLOCKERS.md` — exact current blockers list
- `docs/GATE_2_ALLOWLIST_SELECTION_WORKSHEET.md` — how to choose campaign/sender/intent values
- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — official sign-off form
- `docs/RC_SHADOW_OWNER_DECISION_PACKET.md` — RC-SHADOW-001/002/003 detail
- `docs/AUTONOMOUS_14_DAY_SHADOW_REVIEW_PLAN.md` — shadow review plan
- `docs/AUTONOMOUS_SHADOW_REVIEW_DAILY_CHECKLIST.md` — daily checklist
