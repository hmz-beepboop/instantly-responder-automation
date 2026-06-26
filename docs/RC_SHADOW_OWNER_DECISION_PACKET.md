# RC-SHADOW Owner Decision Packet

**Date:** 2026-06-24  
**Phase:** 5H  
**Purpose:** Owner sign-off on three shadow rule candidates before or during the 14-day shadow review period  
**Urgency:** RC-SHADOW-003 must be resolved before Gate 2. RC-SHADOW-001/002 can be reviewed during or after shadow period.

---

## How to Use This Document

For each candidate below: read the issue, pick a decision (Approve / Reject / Defer), and sign. No production changes occur as a result of this document alone — each approved candidate has a defined safe next action.

---

## RC-SHADOW-001: Proof Request Promotion

| Field | Detail |
|-------|--------|
| **Candidate ID** | RC-SHADOW-001 |
| **Source** | Learning signal LS-001 from Phase 5F shadow tests |
| **Observation** | Proof/examples requests (PROOF_REQUEST intent) correctly shadow-logged with no live send. Confidence 0.88 → SHADOW_LOG. |
| **Issue** | Should PROOF_REQUEST ever be eligible for autonomous reply, or should it always route to human review? |
| **Why it matters before Gate 2** | If PROOF_REQUEST is added to intent_allowlist for Gate 2 controlled pilot, the system could autonomously reply to proof requests. This requires a pre-approved response. |
| **Risk if ignored** | Proof requests could be unintentionally included in intent_allowlist during Gate 2 setup, generating autonomous replies without a validated response template. |

### Recommended Decision

**DEFER — Monitor for frequency during 14-day shadow review, then decide.**

Proof requests are legitimate prospect behaviour but require specific approved content (case studies, data). Until:
1. Frequency is known across real traffic
2. An approved proof-request reply template is in `docs/AUTONOMOUS_ALLOWED_RESPONSE_TEMPLATES.md`
3. Legal/compliance review confirms proof claims are accurate

PROOF_REQUEST should remain SHADOW_LOG only and NOT appear in intent_allowlist for Gate 2.

### Options

| Option | Action | Risk |
|--------|--------|------|
| **A — Defer (recommended)** | Keep PROOF_REQUEST as SHADOW_LOG during 14-day review. Decide after seeing real frequency. | Low |
| **B — Approve for Gate 2 allowlist** | Add PROOF_REQUEST to intent_allowlist for controlled pilot | Medium — requires approved template first |
| **C — Permanently block** | Add PROOF_REQUEST to PERMANENT_BLOCK list | Low — reduces autonomous capability but safe |

**Safe next action if Deferred:** No change. Review frequency data at end of 14-day shadow period.  
**Production change required:** No (for Defer or Block). Yes (for Approve — intent_allowlist update needed).

**Owner Decision:** ☐ Defer (recommended)  ☐ Approve for Gate 2  ☐ Permanently block  
**Owner Signature/Date:** _______________

---

## RC-SHADOW-002: OUT_OF_OFFICE Handling Policy

| Field | Detail |
|-------|--------|
| **Candidate ID** | RC-SHADOW-002 |
| **Source** | Shadow test SHADOW-T12 (OUT_OF_OFFICE scenario) |
| **Observation** | OUT_OF_OFFICE replies correctly routed to HUMAN_REVIEW (not blocked, not shadow-eligible). This is the correct behaviour per current policy. |
| **Issue** | Policy question: should the system send an automated acknowledgement when it detects OUT_OF_OFFICE, or strictly do nothing? |
| **Why it matters before Gate 2** | If Gate 2 controlled pilot includes scheduling intents, the system needs a clear policy for what happens when a prospect replies with an OOO. |
| **Risk if ignored** | An OOO reply could be misclassified as SCHEDULING_REQUEST or INFORMATION_REQUEST in a future AI classification model, causing an autonomous reply to an unmanned inbox. |

### Recommended Decision

**CONFIRM — OOO always routes to HUMAN_REVIEW, never autonomous.**

OOO replies are not actionable by automation. The correct response is to note the return date (if present) and wait. No autonomous reply, no follow-up scheduling. Human should decide whether to park, reschedule, or dismiss.

### Options

| Option | Action | Risk |
|--------|--------|------|
| **A — Confirm human-only (recommended)** | Keep OOO → HUMAN_REVIEW. Document explicitly in approved reply rules. | Low |
| **B — Allow autonomous acknowledgement** | Add OOO-specific NOOP acknowledgement | Low-medium — requires template |
| **C — Block permanently** | Add OOO to PERMANENT_BLOCK | Low — conservative |

**Safe next action if Confirmed:** Update `docs/HMZ_APPROVED_REPLY_RULES.md` to explicitly state OOO → human only. No workflow changes needed.  
**Production change required:** No (for any option at this stage).

**Owner Decision:** ☐ Confirm human-only (recommended)  ☐ Allow acknowledgement  ☐ Block permanently  
**Owner Signature/Date:** _______________

---

## RC-SHADOW-003: Allowlist Wire-Up Enhancement for Gate 2

| Field | Detail |
|-------|--------|
| **Candidate ID** | RC-SHADOW-003 |
| **Source** | Architecture review during Phase 5H |
| **Observation** | The n8n shadow evaluator's eligibility node does not check campaign_allowlist, sender_allowlist, or intent_allowlist against actual values. Gate 1 is hardcoded as always-disabled, so allowlist gates are never reached. |
| **Issue** | When Gate 2 controlled pilot is enabled (autonomous_enabled=true, allowlists populated), the n8n eligibility code must be updated to actually check the allowlists. Currently it would skip them. |
| **Why it matters before Gate 2** | Without the allowlist wire-up, a Gate 2 scenario with `autonomous_enabled=true` could bypass campaign/sender/intent filtering and reach a send decision for unintended cases. |
| **Risk if ignored** | High. If Gate 2 is approved and the n8n workflow is not updated, the allowlist safety gates would be missing. A case from a non-approved campaign could become eligible. |
| **Current safety** | NONE needed right now — Gate 1 hardcodes all sends as blocked. This becomes a hole only when `autonomous_enabled=true`. |

### Recommended Decision

**APPROVE ENHANCEMENT — Required before Gate 2 approval can be given.**

The allowlist wire-up must be implemented in the n8n eligibility node before Gate 2. This is a pre-requisite, not optional.

### Options

| Option | Action | Risk |
|--------|--------|------|
| **A — Implement before Gate 2 (recommended/required)** | Update eligibility node to check campaign_id vs campaign_allowlist, sender_email vs sender_allowlist, micro_intent vs intent_allowlist | Low when done correctly |
| **B — Defer until Gate 2 approval day** | Do the wire-up as part of Gate 2 activation | Medium — last-minute change is riskier |
| **C — Accept risk and skip** | Do not add allowlist checks | UNACCEPTABLE — creates live send path without filtering |

### Safe Next Action (if Approved)

1. Update `workflows/disabled_autonomous_shadow_evaluator.json` eligibility node to add:
   - `if (!SHADOW_CONFIG.campaign_allowlist.includes(p.campaign_id)) { ... }` check
   - `if (!SHADOW_CONFIG.sender_allowlist.includes(p.sender_email)) { ... }` check
   - `if (SHADOW_CONFIG.intent_allowlist.length === 0 || !SHADOW_CONFIG.intent_allowlist.includes(p.micro_intent)) { ... }` check
2. Re-run `.\scripts\SL-PHASE-5E-autonomous-readiness-acceptance-harness.ps1 -RunAll`
3. Re-run 20 shadow webhook tests (shadow only — not activated for live sends)
4. Document in `docs/AUTONOMOUS_ALLOWLIST_WIREUP_VERIFICATION.md`
5. Do not activate for live sends — these are shadow-only tests

**This does NOT require owner approval to implement. But owner must confirm the wire-up is complete before signing Gate 2.**

**Production change required:** Yes — `disabled_autonomous_shadow_evaluator.json` needs updating (not a live production workflow — it is currently `active=false`).

**Owner Decision:** ☐ Approve enhancement (required for Gate 2)  ☐ Defer to Gate 2 day  
**Owner Signature/Date:** _______________

---

## Summary Table

| Candidate | Urgency | Recommended | Production Change | Blocks Gate 2? |
|-----------|---------|-------------|-------------------|----------------|
| RC-SHADOW-001 | Low — defer | Defer, monitor | No | No |
| RC-SHADOW-002 | Low — confirm | Confirm human-only | No | No |
| RC-SHADOW-003 | High | Implement before Gate 2 | Yes (shadow evaluator JSON only) | YES |

---

## Next Step

Owner signs this document, then:
1. Email/message decision for each candidate to the implementation team
2. RC-SHADOW-003 enhancement is scheduled during the 14-day shadow review period
3. Gate 2 checklist in `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` is NOT signed until RC-SHADOW-003 enhancement is complete and verified
