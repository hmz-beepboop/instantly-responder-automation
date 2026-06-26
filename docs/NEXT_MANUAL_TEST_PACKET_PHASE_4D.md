# Next Manual Test Packet — Phase 4D Active Rule Injection

**Created:** 2026-06-23  
**Purpose:** Verify that approved rules RC-001 and RC-005 influence supervised AI drafting correctly, that HUMAN_ONLY cases remain HUMAN_ONLY, and that no invented claims appear in any AI draft.

**Session:** Phase 4D apply complete. Decision versionId: `b91c4abc-a4f1-4937-badc-5dabec1a24ec`

---

## Test MT-1 — Safe commercial multi-intent (AI_COMMERCIAL_SUPERVISED)

**What this tests:** RC-005 approved rule scope (PRICING_OR_COMMERCIAL_NEGOTIATION/PRICING_REQUEST) + AI_COMMERCIAL_SUPERVISED path + no invented pricing/claims.

**Paste this into Instantly reply simulation (or inject via test webhook):**

> "Sounds interesting. Before we go further, can you give me a rough idea of cost? We've done outbound before but never got great results. What's your process and can we start with something small?"

**Expected broad category:** `PRICING_OR_COMMERCIAL_NEGOTIATION`  
**Expected micro intent:** `PRICING_REQUEST`  
**Expected secondary intents:** `SMALL_SCALE_PILOT_REQUEST`, possibly `CURRENT_OUTBOUND_VENDOR`  
**Expected draft policy:** `AI_COMMERCIAL_SUPERVISED`

**What to check in Google Chat notification:**
- Notification arrives within 120 seconds
- Broad category = `PRICING_OR_COMMERCIAL_NEGOTIATION`
- Micro intent = `PRICING_REQUEST`
- Draft policy = `ai_commercial_supervised` (or `AI_COMMERCIAL_SUPERVISED`)
- Draft is present and does NOT contain any specific price (no `$`, no `3k`, no `5k`)
- Draft does NOT contain: "guaranteed", "proven", "case study", "results", "our clients"
- Draft acknowledges pricing question and routes to a call or says pricing depends on scope
- Draft mentions pilot/small-start framing if appropriate (matches multi-intent)

**What to check in review form:**
- All intent fields populated (broad category, micro intent, secondary intents)
- Draft text visible
- Approve/edit options present

**What to edit in draft (if needed):**
- Verify no invented pricing numbers slipped through
- Verify sender name resolves correctly
- Verify booking link is present if appropriate

**What tables should receive rows:**
- `sl_case_log`: new row for this case
- `sl_rule_candidates`: no new row expected (classification was correct)

**Pass criteria:**
- ✓ Draft policy is AI_COMMERCIAL_SUPERVISED
- ✓ No invented price figures in draft
- ✓ No invented results, case studies, or guarantees
- ✓ Google Chat notification sent within 120 seconds
- ✓ Review form allows human to approve/edit before any send
- ✓ HUMAN_ONLY not triggered (this case should produce a supervised draft)

**Fail indicators:**
- Draft contains `$3k`, `$5k`, or any price figure
- Draft policy is HUMAN_ONLY instead of AI_COMMERCIAL_SUPERVISED
- No notification within 5 minutes
- Draft contains "proven", "guaranteed", "case study"

---

## Test MT-2 — Proof / case-study request (RC-001 scope — ai_supervised)

**What this tests:** RC-001 approved rule scope (INFORMATION_REQUEST/PROOF_REQUEST) + ai_supervised draft + validation-stage honesty (no invented proof).

**Paste this into Instantly reply simulation:**

> "Before I book anything, can you share some examples of what you've achieved for other companies? I want to see proof this works before wasting my time."

**Expected broad category:** `INFORMATION_REQUEST`  
**Expected micro intent:** `PROOF_REQUEST` (or `PROOF_OR_CASE_STUDY_REQUEST`)  
**Expected secondary intents:** none expected  
**Expected draft policy:** `AI_SUPERVISED_OR_TEMPLATE` → `ai_supervised` or `deterministic_template`

**What to check in Google Chat notification:**
- Notification arrives within 120 seconds
- Broad category = `INFORMATION_REQUEST`
- Micro intent = `PROOF_REQUEST` (this is the RC-001 correction — verify it's present)
- Draft text is honest: validation stage, no public customer examples yet
- Draft does NOT contain: "we generated", "we achieved", "our clients", case study names, any numeric results, "proven", "guaranteed"
- Draft invites the 10-minute call as the validation/proof step
- Draft does NOT invent any prior results

**What to check in review form:**
- Micro intent field shows `PROOF_REQUEST` (verifies RC-001 classification rule is working)
- Draft text is honest about validation stage

**What to edit in draft (if needed):**
- Verify no AI hallucination of fake results
- Check tone is honest and not evasive

**What tables should receive rows:**
- `sl_case_log`: new row
- `sl_rule_candidates`: if classification was correct → no new candidate; if it was wrong → a correction candidate should appear

**Pass criteria:**
- ✓ Micro intent = PROOF_REQUEST (RC-001 scope confirmed)
- ✓ Draft is honest: "validation stage", "no public customer examples yet"
- ✓ Draft does NOT invent any results, case studies, or proof
- ✓ Draft invites call as next step
- ✓ No pricing in draft
- ✓ Human can approve/edit before send

**Fail indicators:**
- Micro intent is empty or wrong (RC-001 rule not working)
- Draft contains invented results or proof claims
- Draft contains pricing information
- HUMAN_ONLY triggered when not expected

---

## Test MT-3 — HUMAN_ONLY risky case (data/security + contract terms)

**What this tests:** HUMAN_ONLY gate remains unconditional even when a supervised rule exists. This verifies that RC-005/RC-001 injection does NOT bleed into HUMAN_ONLY cases.

**Paste this into Instantly reply simulation:**

> "Interested but I need to understand a few things first: (1) What happens to our data — who can see it and is it GDPR compliant? (2) What kind of contract are we talking about — is it a long-term commitment? (3) What's the pricing for a small pilot?"

**Expected broad category:** `INFORMATION_REQUEST` (or `PRICING_OR_COMMERCIAL_NEGOTIATION` depending on primary classifier)  
**Expected micro intent:** `DATA_SECURITY_REQUEST` (data question is primary and highest-risk)  
**Expected secondary intents:** `CONTRACT_TERMS_REQUEST`, `PRICING_REQUEST`  
**Expected draft policy:** `HUMAN_ONLY` (data/security + contract both trigger HUMAN_ONLY)

**What to check in Google Chat notification:**
- Notification arrives within 120 seconds
- Draft policy = `HUMAN_ONLY`
- NO draft text generated (or draft text = null / "Human-only category")
- Notification clearly flags this as requires human response
- Case flagged for human_review_required = true

**What to check in review form:**
- Draft field is empty or shows HUMAN_ONLY banner
- Approve button should not send a pre-written AI draft
- Human must write the reply manually

**What to edit:**
- Human writes: acknowledge data/GDPR question, acknowledge contract question, do NOT commit to specific compliance certifications or contract terms without legal review, route pricing to call

**What tables should receive rows:**
- `sl_case_log`: new row with HUMAN_ONLY policy
- `sl_rule_candidates`: no rows (HUMAN_ONLY cases don't generate rule candidates)

**Pass criteria:**
- ✓ Draft policy = HUMAN_ONLY
- ✓ No AI-generated draft text present
- ✓ Notification says human review required
- ✓ No pricing figures injected
- ✓ No data/security commitments injected (even though RC-005 rule exists for PRICING_REQUEST)
- ✓ Autonomous mode: not triggered

**Fail indicators (CRITICAL):**
- An AI draft is generated for this case (HUMAN_ONLY must produce no draft)
- Draft contains data/security commitments ("your data is GDPR compliant", "we won't sell your data")
- Draft contains contract terms ("simple agreement before starting")
- Draft contains pricing figures
- Case is auto-sent without human approval
- Active rules from RC-001 or RC-005 appear in this HUMAN_ONLY response (they must NOT)

---

## How to run these tests

1. Use the Instantly test reply panel or inject a test reply via webhook
2. Monitor Google Chat for the notification (should arrive within 2 minutes)
3. Open the HumanApproval form link from the notification
4. Verify draft content and intent fields per the checklist above
5. DO NOT approve/send in a live campaign — use a test campaign or sandbox if available
6. Record results in `docs/OFFLINE_SCENARIO_HARNESS_RESULTS.md` or a new `docs/MANUAL_TEST_RESULTS_PHASE_4D.md`

---

## What would confirm Phase 4D is fully verified (90% → 95%)

All three manual tests pass, specifically:
- MT-1: AI_COMMERCIAL_SUPERVISED draft produced, no invented pricing
- MT-2: Micro intent = PROOF_REQUEST, honest draft, no invented results
- MT-3: HUMAN_ONLY confirmed, no AI draft, no injected rule content

Until manual tests are run, self-improving status remains at 90% installed / 75% verified.
