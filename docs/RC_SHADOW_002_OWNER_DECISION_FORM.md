# RC-SHADOW-002: Out-of-Office Policy — Standalone Owner Decision Form

**Version:** 1.0  
**Date:** 2026-06-24  
**Phase:** 5K — Gate 2 Evidence Start  
**Status:** PENDING OWNER SIGN-OFF

---

## Plain-English Explanation

During shadow testing, the system correctly identified replies that were auto-sent by a prospect's email system while they were away — things like:

- "I'm out of the office until [date]. I'll reply when I return."
- "I'm currently travelling and have limited email access."
- "Auto-reply: I'm on holiday until [date]."

The system flagged these as `OUT_OF_OFFICE` and routed them to you for human review. That was the correct behaviour.

**The decision you are being asked to make:** When the controlled pilot detects an out-of-office reply, what should the system do?

---

## Context: Why This Matters

An out-of-office reply is not from the prospect — it is from their email server. The prospect has not read your message and has not responded. They are simply unavailable.

Three possible system behaviours exist:

1. **Human review only (current)** — the system tells you it detected OOO, and you decide whether to wait, reschedule, or do nothing.
2. **Automated acknowledgement** — the system sends a brief reply like "Noted — I'll follow up when you're back." This is visible to the prospect when they return.
3. **Permanent block** — OOO replies are suppressed silently. No notification. The system does nothing.

---

## Recommended Decision

**Confirm human-only — OOO replies always go to you for review.**

Reason: OOO replies are not actionable. The right response depends on context — how warm is this prospect? How recently did you outreach them? What campaign are they in? An automated reply to an OOO reply adds no value and may look automated/spammy.

---

## Your Options

Mark exactly one:

- [ ] **CONFIRM HUMAN-ONLY** — OOO replies always go to human review. No autonomous reply. *(recommended)*  
  Effect: You see every OOO notification and decide what to do. Current behaviour unchanged.

- [ ] **ALLOW AUTOMATED ACKNOWLEDGEMENT** — System sends a brief "I'll follow up" reply autonomously.  
  Effect: When a prospect is OOO, the system replies to their OOO auto-reply. Risk: may look robotic; prospect sees this automated reply when they return and it may reduce trust. Only choose this if you have an approved OOO acknowledgement template in the knowledge base.

- [ ] **PERMANENTLY BLOCK** — OOO replies are suppressed. No human notification, no send.  
  Effect: OOO events are ignored by the system. You will not see them. Risk: you may miss prospects who return from OOO and are warm.

---

## Safety Risk

| Risk Level | Detail |
|-----------|--------|
| Low (HUMAN-ONLY) | No change. You control every OOO outcome. |
| Low-Medium (PERMANENTLY BLOCK) | You lose visibility of OOO prospects. May miss re-engagement opportunities. |
| Medium (AUTOMATED ACKNOWLEDGEMENT) | Automated reply sent to a person's inbox that looks like a human wrote it. If prospect checks who replied, may damage trust. |

---

## Impact on Future Autonomous Behaviour

| Your Decision | Effect |
|--------------|--------|
| HUMAN-ONLY | OOO stays human-only at Gate 2. Can be revisited if a safe template is created. |
| AUTOMATED ACKNOWLEDGEMENT | OOO replies eligible for autonomous sending in the controlled pilot. Requires an approved template. |
| PERMANENTLY BLOCK | OOO events are silenced across all future gates. You will not see them in your review queue. |

---

## WARNING

Signing this form does **not** enable live autonomy. Gate 2 has 6 other blockers that must all be resolved. This form is one input to the Gate 2 process only.

---

## Owner Signature

**Decision selected:** _____________________________

**Reason (optional):** _____________________________

**Owner signature / initials:** _____________________________

**Date signed:** _____________________________

