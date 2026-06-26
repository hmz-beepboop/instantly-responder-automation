# Rule Candidate Review Packet
**Generated:** 2026-06-23  
**Source:** sl_rule_candidates DataTable (ID: CSdiTjXfi0tl0oZF)  
**Session scope:** READ-ONLY audit — no candidate statuses were modified.  
**Production target:** https://n8n.hmzaiautomation.com/api/v1

---

## Summary Table

| # | rule_id (short) | rule_type | scope | micro_intent | confidence | status | Safe to approve? | Action |
|---|----------------|-----------|-------|--------------|------------|--------|-----------------|--------|
| RC-001 | 55844bf1 | classification | INFORMATION_REQUEST | PROOF_REQUEST | low | proposed_shadow | YES (after verification) | Approve later |
| RC-002 | 65a28dc9 | style | INFORMATION_REQUEST | PROOF_REQUEST | low | proposed_shadow | YES (needs minor edit) | Edit then approve |
| RC-003 | 95ff5e0b | style | PRICING_OR_COMMERCIAL_NEGOTIATION | *(missing)* | low | proposed_shadow | **NO** | Reject or edit |
| RC-004 | f5014c4d | style | PRICING_OR_COMMERCIAL_NEGOTIATION | *(missing)* | low | proposed_shadow | **NO** | Reject or edit |
| RC-005 | 1a779d95 | classification | PRICING_OR_COMMERCIAL_NEGOTIATION | PRICING_REQUEST | low | proposed_shadow | YES (after verification) | Approve later |
| RC-006 | 96005a4d | style | PRICING_OR_COMMERCIAL_NEGOTIATION | PRICING_REQUEST | low | proposed_shadow | **NO** | Reject — multiple unsafe domains |

---

## Candidate Detail

### RC-001 — 55844bf1-a36c-4a03-9832-98b08c50e557

| Field | Value |
|-------|-------|
| rule_id | 55844bf1-a36c-4a03-9832-98b08c50e557 |
| source_case_id | case-a27303b6 |
| rule_type | classification |
| classification_scope | INFORMATION_REQUEST |
| micro_intent_scope | PROOF_REQUEST |
| confidence | low |
| status | proposed_shadow |
| created_by | humza@hmzaiautomation.com |

**proposed_rule_text:**
> Classify as INFORMATION_REQUEST/PROOF_REQUEST: see correction_reason

**example_before:** `INFORMATION_REQUEST/` (empty micro_intent)  
**example_after:** `INFORMATION_REQUEST/PROOF_REQUEST`  
**reason:** The prospect is asking for a specific piece of information, specifically proof for the product's credibility.

**Safety risk assessment:**  
Low risk. This is a classification-only fix that assigns a missing `micro_intent` to an already-correct broad category. It does not affect draft content, pricing, legal claims, or AI behaviour beyond routing.

**Safe to approve later?** YES — provided the source case (case-a27303b6) confirms the prospect was asking for proof/credibility evidence and the blank micro_intent was a genuine classifier miss.

**Should be rejected?** No.

**Needs manual editing?** No, but confidence is `low` — owner should briefly review source case before approving.

**Recommended owner action:** Review source case case-a27303b6 in HumanApproval queue or execution log. If the reply text clearly asked for proof/examples, approve RC-001. Do not execute this session.

---

### RC-002 — 65a28dc9-0a8b-4d2a-8124-7b977819bd2f

| Field | Value |
|-------|-------|
| rule_id | 65a28dc9-0a8b-4d2a-8124-7b977819bd2f |
| source_case_id | case-a27303b6 |
| rule_type | style |
| classification_scope | INFORMATION_REQUEST |
| micro_intent_scope | PROOF_REQUEST |
| confidence | low |
| status | proposed_shadow |

**proposed_rule_text:**
> Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.

**example_before:**
> Hi , we're still in validation and don't have public customer examples yet. If helpful, we can use a 10-minute call as the next validation step and walk through what we're seeing live. If that's useful, you can book here: https://calendar.app.google/bNXWJkS3xz3yqdW36 If you'd rather, I can also share a short outcome discussion by email. Hamza

**example_after:**
> Hi , we're still in validation and don't have public customer examples yet. If helpful, we can use a 10-minute call as the next validation step and walk through what we're seeing live. If that's useful, you can book here: https://calendar.app.google/bNXWJkS3xz3yqdW36  
> If you want, I can book you in myself if you share with me your availability for the week.  
> Hamza

**reason:** Reviewer edited draft before approval.

**Key change:** Replaces "I can also share a short outcome discussion by email" with a proactive "I can book you in myself if you share availability." This is a CTA tone adjustment — more proactive booking offer, removes email fallback.

**Safety risk assessment:**  
Low risk on content. No pricing, no legal claims, no data promises. However:
- The `proposed_rule_text` is generic and does not capture the actual abstract rule.
- The example is case-specific (same source as RC-001, case-a27303b6).
- The abstract rule intent is: "For PROOF_REQUEST replies, prefer proactive calendar booking language over offering email alternatives."

**Safe to approve later?** YES, but needs the proposed_rule_text to be edited to a concrete abstract instruction before injection, e.g.: `For INFORMATION_REQUEST/PROOF_REQUEST: prefer a direct booking CTA ("I can book you in myself") over an email fallback alternative.`

**Should be rejected?** No.

**Needs manual editing before approval?** YES — `proposed_rule_text` must be replaced with an abstract actionable instruction. Current text is placeholder only.

**Recommended owner action:** Edit `proposed_rule_text` to an abstract rule, then approve. Do not approve the current generic text — it is not injectable as written.

---

### RC-003 — 95ff5e0b-b672-4d2d-a1c2-ac9042192808

| Field | Value |
|-------|-------|
| rule_id | 95ff5e0b-b672-4d2d-a1c2-ac9042192808 |
| source_case_id | case-bfd637ab |
| rule_type | style |
| classification_scope | PRICING_OR_COMMERCIAL_NEGOTIATION |
| micro_intent_scope | *(empty — MISSING)* |
| confidence | low |
| status | proposed_shadow |

**proposed_rule_text:**
> Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.

**example_before:** *(empty)*  
**example_after (truncated in DB, full content reconstructed from fetch):**
> Yes, we can start small. I would recommend a validation sprint first... Pricing for a small test is usually around $3k to $5k depending on scope...

**reason:** Reviewer edited draft before approval.

**Safety risk assessment: HIGH RISK — DO NOT APPROVE AS-IS**

Critical issues:
1. **Specific pricing claim** (`$3k to $5k`) — this is a numeric pricing range that is NOT in `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. Injecting this as an active rule would cause the AI to state specific pricing in supervised drafts, violating Rule 15 (no invented prices) and the requirement that pricing is human-only.
2. **Missing `micro_intent_scope`** — scope is too broad; the rule would fire for any PRICING_OR_COMMERCIAL_NEGOTIATION case regardless of micro_intent.
3. **Generic `proposed_rule_text`** — not an injectable abstract rule; it is a case-specific example.
4. **`example_before` is empty** — the before/after comparison cannot be evaluated.

**Safe to approve later?** NO.

**Should be rejected?** YES — unless heavily edited: pricing must be removed or replaced with a placeholder and the rule must be narrowed to a specific micro_intent.

**Needs manual editing?** YES (major editing required before any approval is possible).

**Recommended owner action:** Reject RC-003, or if the style intent (recommend a validation sprint first, small-start framing) is valuable, create a new candidate with pricing removed. Do not execute this session.

---

### RC-004 — f5014c4d-9448-478d-9c6d-b5139a878099

| Field | Value |
|-------|-------|
| rule_id | f5014c4d-9448-478d-9c6d-b5139a878099 |
| source_case_id | case-9094be7d |
| rule_type | style |
| classification_scope | PRICING_OR_COMMERCIAL_NEGOTIATION |
| micro_intent_scope | *(empty — MISSING)* |
| confidence | low |
| status | proposed_shadow |

**proposed_rule_text:**
> Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.

**example_before:** *(empty)*  
**example_after (truncated):**
> Yes, we can start with a small pilot first. For a pilot, we would define the target market... Pricing for a small pilot is usually around $3k to $5k depending on scope...

**reason:** Reviewer edited draft before approval.

**Safety risk assessment: HIGH RISK — NEAR-DUPLICATE OF RC-003**

Critical issues (same as RC-003):
1. **Specific pricing claim** (`$3k to $5k`) — identical pricing range, same prohibition applies.
2. **Missing `micro_intent_scope`** — no scope constraint.
3. **Generic `proposed_rule_text`** — not injectable.
4. **`example_before` is empty**.
5. **Near-duplicate** of RC-003 (different source case, same draft pattern, same safety violation).

**Safe to approve later?** NO.

**Should be rejected?** YES — this is a near-duplicate of RC-003 with the same core safety issues. Both should be rejected and replaced by a single clean rule (if the pilot/small-start framing is desired) with pricing removed.

**Needs manual editing?** YES (same major edits as RC-003).

**Recommended owner action:** Reject RC-004 alongside RC-003. Consolidate into one new candidate without pricing language. Do not execute this session.

---

### RC-005 — 1a779d95-beaf-4d2e-8c70-73721a11b02d

| Field | Value |
|-------|-------|
| rule_id | 1a779d95-beaf-4d2e-8c70-73721a11b02d |
| source_case_id | case-b5f314e3 |
| rule_type | classification |
| classification_scope | PRICING_OR_COMMERCIAL_NEGOTIATION |
| micro_intent_scope | PRICING_REQUEST |
| confidence | low |
| status | proposed_shadow |

**proposed_rule_text:**
> Classify as PRICING_OR_COMMERCIAL_NEGOTIATION/PRICING_REQUEST: see correction_reason

**example_before:** `PRICING_OR_COMMERCIAL_NEGOTIATION/` (empty micro_intent)  
**example_after:** `PRICING_OR_COMMERCIAL_NEGOTIATION/PRICING_REQUEST`  
**reason:** Reviewer classification correction.

**Safety risk assessment:**  
Low risk. Same structure as RC-001 — a classification-only fix assigning a missing micro_intent. Routing only. Does not affect draft content, pricing claims, or AI behaviour.

**Safe to approve later?** YES — provided source case (case-b5f314e3) confirms the reply was asking about pricing.

**Should be rejected?** No.

**Needs manual editing?** No, but confidence is `low` — review source case first.

**Recommended owner action:** Review source case case-b5f314e3. If the prospect's reply clearly asked about pricing/cost, approve RC-005. Do not execute this session.

---

### RC-006 — 96005a4d-d7e5-4e57-a8df-dec5b9bcb491

| Field | Value |
|-------|-------|
| rule_id | 96005a4d-d7e5-4e57-a8df-dec5b9bcb491 |
| source_case_id | case-b5f314e3 |
| rule_type | style |
| classification_scope | PRICING_OR_COMMERCIAL_NEGOTIATION |
| micro_intent_scope | PRICING_REQUEST |
| confidence | low |
| status | proposed_shadow |

**proposed_rule_text:**
> Style/CTA adjustment: reviewer edited draft. See example_before vs example_after.

**example_before:** *(empty)*  
**example_after (truncated):**
> Of course. For a small pilot, pricing is usually around $3k to $5k depending on scope. This would cover one focused campaign... Your data would only be used for the agreed campaign. We would not sell it, share it, or use it outside the agreed scope. Yes, there would be a simple agreement before starting. We can definitely test this with one small campaign first...

**reason:** Reviewer edited draft before approval.

**Safety risk assessment: VERY HIGH RISK — MULTIPLE PROHIBITED DOMAINS**

Critical issues:
1. **Specific pricing claim** (`$3k to $5k`) — same as RC-003/RC-004. Not in approved KB. Auto-injection would cause AI to state specific pricing in drafts.
2. **Data commitment** (`"Your data would only be used for the agreed campaign. We would not sell it, share it, or use it outside the agreed scope."`) — this is a data privacy/security promise. Per approved reply rules, data/security questions are `HUMAN_ONLY`. Injecting this as an active rule would cause the AI supervised draft to make data commitments that require human review and legal validation.
3. **Contract commitment** (`"Yes, there would be a simple agreement before starting."`) — legal/contract territory. Per approved rules, CONTRACT_TERMS_REQUEST is `HUMAN_ONLY`. Injecting this would cause the AI to confirm contract existence in supervised drafts.
4. **Generic `proposed_rule_text`** — not injectable.
5. **`example_before` is empty**.

**Safe to approve later?** NO — this candidate would need to be fully reconstructed. All three dangerous content types (pricing, data promise, contract confirmation) must be removed before any consideration.

**Should be rejected?** YES.

**Needs manual editing?** YES (major reconstruction required — the core draft content is not safe for AI injection).

**Recommended owner action:** Reject RC-006. If the small-pilot CTA framing (excluding pricing, data, and contract language) is desired as a style guide, create a new candidate scoped only to safe response framing. Do not execute this session.

---

## Top 3 Safest Candidates to Consider Approving Later

1. **RC-001 (55844bf1)** — Classification fix for PROOF_REQUEST. Low risk, no content injection, just routing. Review case-a27303b6 before approving.
2. **RC-005 (1a779d95)** — Classification fix for PRICING_REQUEST. Same structure, same low risk. Review case-b5f314e3 before approving.
3. **RC-002 (65a28dc9)** — CTA style adjustment for PROOF_REQUEST. Safe content, but requires `proposed_rule_text` to be edited to an abstract injectable instruction before approval.

## Candidates That Must NOT Be Approved Without Major Edits

- **RC-003 (95ff5e0b)** — pricing claim, missing micro_intent, empty example_before
- **RC-004 (f5014c4d)** — near-duplicate of RC-003, same issues
- **RC-006 (96005a4d)** — pricing + data commitment + contract confirmation

## Duplicate or Low-Value Candidates

- **RC-003 and RC-004** are near-duplicates: different source cases but identical pattern (small-start framing, $3k-$5k pricing, missing micro_intent_scope). If the style intent is ever approved, consolidate into a single clean candidate.

## Unsafe Candidates (Do Not Approve)

| Candidate | Safety Issue |
|-----------|-------------|
| RC-003 | Pricing claim ($3k-$5k), missing micro_intent, empty example_before |
| RC-004 | Same as RC-003 (near-duplicate), near-duplicate risk |
| RC-006 | Pricing + data privacy promise + contract confirmation in same rule |

---

## Owner Decision Checklist (Do Not Execute in This Session)

- [ ] Review case-a27303b6 execution log → Approve RC-001 if PROOF_REQUEST confirmed
- [ ] Review case-b5f314e3 execution log → Approve RC-005 if PRICING_REQUEST confirmed
- [ ] Edit RC-002 `proposed_rule_text` to abstract injectable instruction → then approve
- [ ] Reject RC-003 (or create replacement without pricing)
- [ ] Reject RC-004 (near-duplicate of RC-003)
- [ ] Reject RC-006 (pricing + data + contract — multiple prohibited domains)

---

*All 6 candidates remain at `proposed_shadow` status. No modifications were made in this session.*
