# Autonomous Allowed Response Templates

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED — Templates require owner approval before use

---

## Purpose

Defines the approved template responses that can be used in the autonomous path for lowest-risk intent types. Templates are preferred over AI drafts for autonomous sends because they are deterministic and pre-approved.

---

## Template Eligibility Criteria

A template is eligible for autonomous use if:
1. The owner has explicitly approved the template text
2. The template contains no pricing, no invented examples, no guarantees
3. The template includes the booking link (if appropriate for the intent)
4. The template is honest about HMZ's validation stage
5. The template has been reviewed against the approved reply rules

---

## DRAFT Templates (Not Yet Approved — Owner Review Required)

These templates are DRAFTS. They must be reviewed and approved by the owner before use.

### Template T-AUTO-001: Generic Information Request

**Intent:** INFORMATION_REQUEST  
**Status:** DRAFT — owner review required

```
Hi [First Name],

Happy to share more. [Service brief — 1-2 sentences from approved knowledge base].

If it sounds relevant, here's a link to book a quick call: [BOOKING_LINK]

[Sender Name]
```

**Rules:**
- Do NOT add pricing
- Do NOT add case studies
- Do NOT claim results
- Brief = what it is, not what it has proven

---

### Template T-AUTO-002: Scheduling Request

**Intent:** SCHEDULING_REQUEST  
**Status:** DRAFT — owner review required

```
Hi [First Name],

Absolutely. Here's my calendar to grab a time that works: [BOOKING_LINK]

[Sender Name]
```

**Rules:**
- No additional content beyond booking link
- No pricing
- Short and action-oriented only

---

### Template T-AUTO-003: "Tell Me More" / "Send More Info"

**Intent:** INFORMATION_REQUEST  
**Status:** DRAFT — owner review required

```
Hi [First Name],

Here's a quick overview of how we work: [Service brief — 1-2 sentences].

If it seems like a fit, you can grab a time here: [BOOKING_LINK]

[Sender Name]
```

---

## Templates That May NOT Be Used in Autonomous Path

| Template Type | Reason |
|--------------|--------|
| Pricing response | PRICING_REQUEST is permanently blocked |
| Case study response | Requires human oversight per RC-001 |
| Contract response | CONTRACT_TERMS is permanently blocked |
| Custom proposal | CUSTOM_PROPOSAL_REQUEST is permanently blocked |
| Any GDPR/SOC2/compliance | Permanently blocked |
| Apology or correction | Human judgment required |
| Multi-intent responses | Human oversight required for any blocked additional intent |

---

## Template Approval Process

Before any template is used in autonomous sends:
1. Owner reviews the template text
2. Owner confirms it follows approved reply policy
3. Owner adds it to this document with status: APPROVED
4. Template is referenced in the autonomous eligibility config

---

## Related Documents

- `outputs/autonomous_template_library_sample.json` — machine-readable template library
- `docs/AUTONOMOUS_PROMPTING_AND_RULE_USAGE_SPEC.md` — prompting context
- `docs/HMZ_APPROVED_REPLY_RULES.md` — approved reply policy
- `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — knowledge base for brief descriptions
