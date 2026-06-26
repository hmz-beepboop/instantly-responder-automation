# Manual Live Test Packet — Self-Improvement Behavioural Proof

**Version:** SL-PHASE-4J-1.0  
**Date:** 2026-06-23  
**Purpose:** Prove that active rules (RC-001, RC-005) actually change draft wording and classification for future emails — not just that they exist in the workflow.

**Safety:** Do NOT run these tests by deliberately breaking real production sends. Use fresh test replies only. Do NOT approve real review cases during testing. Do NOT call Sender manually.

---

## How to Decide Whether the System Actually Improved

For each test:
1. Send the test reply to your Instantly campaign (or simulate via Intake webhook if authorised)
2. Wait for the classification + draft to appear in Google Chat
3. Compare the result against the "Expected quality" column
4. Record the case_id from Google Chat
5. Check the DataTables for capture rows (optional but recommended)

**Pass criteria for Stage 8 (Verified Complete):** At least 3 of the 4 tests show the expected improved behaviour versus what the system would have produced before RC-001/RC-005 injection.

---

## Test 1 — Proof / Examples Request (RC-001 guidance)

**Purpose:** Verify RC-001 makes AI drafts acknowledge validation stage and avoid invented case studies.

**Exact client reply text to send:**
```
Hi, thanks for reaching out. This sounds interesting but before we go further — do you have
any case studies or examples of results you've gotten for companies similar to ours?
We're a 25-person B2B SaaS team, mostly focused on enterprise sales cycles.
```

**Expected Google Chat classification:**
- Broad category: `POSITIVE_ENGAGEMENT` or `INFORMATION_REQUEST`
- Micro intent: `PROOF_REQUEST` or `EXAMPLES_REQUEST`
- Draft policy: AI_SUPERVISED → human review required

**Expected draft quality (RC-001 active):**
- Acknowledges we are at validation stage ("We're currently validating this approach with a small number of teams")
- Does NOT invent specific client names, ARR numbers, or meeting volumes
- Does NOT claim "proven" or "established" results
- Offers to connect the prospect directly with a reference contact (or acknowledges we cannot yet provide case studies)
- Wording should include something like: "honest to share that we're in early validation" or similar

**What the reviewer should do:**
- Read the draft in the approval form
- If RC-001 is working: note that the draft explicitly handles the validation-stage caveat
- If RC-001 is NOT working: the draft may invent results or not address the case study question directly
- Do NOT approve and send — this is a classification + draft quality check only
- Record the case_id and draft text

**What DataTables should contain afterward:**
- `hmz-review-cases`: row with case_id, status=IN_REVIEW, micro_intent=PROOF_REQUEST (or equivalent)
- `hmz-learning-events` (if live): row with event_type=classification_confirmed or draft_reviewed

**What rule candidate should NOT be created:**
- No new rule candidate from this test alone — RC-001 should already handle it
- If draft quality is poor despite RC-001, that is evidence to create a new rule candidate after manual review

**Pass/fail criteria:**
- PASS: Draft contains validation-stage acknowledgement and does not invent results
- FAIL: Draft invents case studies, claims "proven results", or ignores the case study question

---

## Test 2 — Pricing / Scope Request (RC-005 guidance)

**Purpose:** Verify RC-005 prevents PRICING_REQUEST false positives for general capability questions.

**Exact client reply text to send:**
```
Hey, curious how your outreach approach actually works. What kind of volume are you running,
and how do you make sure the messaging fits our specific market? We sell IT security software
to mid-market companies. Are you able to customise that kind of thing?
```

**Expected Google Chat classification:**
- Broad category: `POSITIVE_ENGAGEMENT` or `DISCOVERY_CALL_REQUEST`
- Micro intent: `DISCOVERY_CALL` or `GENERAL_INTEREST` — **NOT** `PRICING_REQUEST`
- Draft policy: AI_SUPERVISED → human review for discovery call scheduling

**Expected draft quality (RC-005 active):**
- Draft should offer to book a discovery call or share more detail
- Should NOT treat the question as a pricing negotiation
- Should NOT include "pricing starts at..." or any price-adjacent language
- Should acknowledge the capacity-aligned outreach model briefly
- Booking link should be included

**What the reviewer should do:**
- Check the Google Chat classification — specifically confirm micro_intent is NOT PRICING_REQUEST
- Read the draft — confirm it focuses on discovery call / how it works rather than quoting prices
- If RC-005 is working: DISCOVERY_CALL or GENERAL_INTEREST label
- If RC-005 is NOT working: PRICING_REQUEST label → system would route to HUMAN_ONLY instead of AI draft
- Record the case_id and the actual micro_intent label

**What DataTables should contain afterward:**
- `hmz-review-cases`: row with micro_intent = DISCOVERY_CALL or GENERAL_INTEREST (not PRICING_REQUEST)

**What rule candidate should NOT be created:**
- No new rule candidate if RC-005 correctly handles this — it is the expected behaviour
- If it still shows PRICING_REQUEST, that is a regression → create a new rule candidate

**Pass/fail criteria:**
- PASS: Micro intent classified as DISCOVERY_CALL or GENERAL_INTEREST; draft offers discovery call
- FAIL: Micro intent classified as PRICING_REQUEST; draft treated as HUMAN_ONLY pricing case

---

## Test 3 — Non-Pricing Scope (RC-005 false-positive suppression)

**Purpose:** Verify the system distinguishes genuine pricing requests from capability/scope questions that only mention cost indirectly.

**Exact client reply text to send:**
```
We're evaluating a few options right now. Can you tell me more about what's actually
included in your service — how much of this is managed versus what we handle ourselves?
Not looking for a price, just want to understand the model before we commit to a call.
```

**Expected Google Chat classification:**
- Broad category: `POSITIVE_ENGAGEMENT` or `INFORMATION_REQUEST`
- Micro intent: `DISCOVERY_CALL` or `HOW_IT_WORKS` — **NOT** `PRICING_REQUEST`

**Expected draft quality:**
- Draft should explain the capacity-aligned outbound model
- Should acknowledge this is validation stage (do not imply operational scale)
- Should NOT interpret "not looking for a price" as an invitation to give pricing
- Should offer a call to walk through the model in detail

**What the reviewer should do:**
- Specifically check whether the word "pricing" or "cost" appears anywhere in the draft unprompted
- Confirm classification is not PRICING_REQUEST
- Record case_id

**Pass/fail criteria:**
- PASS: No pricing language in draft; classification is not PRICING_REQUEST
- FAIL: Draft includes pricing language or classification fires as PRICING_REQUEST

---

## Test 4 — Additional Intent Edit (creates new proposed_shadow candidate)

**Purpose:** Prove that when a reviewer edits the additional intents field, a new proposed_shadow rule candidate is created automatically.

**Exact client reply text to send:**
```
Sounds interesting. A couple of things — first, are you only targeting US companies or do
you work internationally too? Second, we'd want to see some kind of pilot or trial before
committing to anything longer term. Is that something you offer?
```

**Expected Google Chat classification:**
- Broad category: `POSITIVE_ENGAGEMENT`
- Micro intents detected: at least `GEOGRAPHIC_SCOPE_QUESTION` + `TRIAL_REQUEST` (or similar)
- Draft policy: AI_SUPERVISED

**What the reviewer should do:**
- In the approval form, review the additional_intents field
- Add or remove one intent — for example, add `PILOT_REQUEST` if not auto-detected, or remove one that seems wrong
- Submit the form (DO NOT APPROVE SEND — just submit the correction section)
- Record the case_id

**What DataTables should contain afterward:**
- `hmz-learning-events` (if live): row with event_type=additional_intents_edited, old/new intent arrays
- `hmz-rule-candidates`: new row with status=proposed_shadow, triggered by the intent edit
- The proposed rule should suggest something like: "PILOT_REQUEST should be detected when prospect asks for trial"

**What rule candidate should be created:**
- A new proposed_shadow candidate capturing the intent mismatch
- rule_id will be auto-generated (e.g. RC-007 or similar)
- status: proposed_shadow (NOT yet approved — human approval required)

**Pass/fail criteria:**
- PASS: DataTable has new proposed_shadow row linked to this case_id after intent edit
- FAIL: No rule candidate created after intent edit → shadow write is not functioning

---

## Case IDs to Collect

The owner must collect the following after running these tests:

| Test | Item to collect |
|------|----------------|
| Test 1 | case_id from Google Chat; copy draft text verbatim |
| Test 2 | case_id; note the actual micro_intent label |
| Test 3 | case_id; note whether "pricing" appears in draft |
| Test 4 | case_id; screenshot the learning_events DataTable row if possible |

Share these with the next Claude session to update stage scores and complete Verified Complete.

---

## What NOT to Test

- Do NOT deliberately reject a live prospect email to test the UNSUBSCRIBE path
- Do NOT manually call the Sender endpoint to simulate a blocked send
- Do NOT approve any test cases and allow them to send to real prospect inboxes
- Do NOT enable autonomous mode or change operating mode
- Do NOT delete or modify existing rule candidates (RC-001 through RC-005)
- Do NOT test with the email addresses of any current real prospects who are mid-pipeline

---

## How to Report Results to Next Claude Session

After running these 4 tests, start the next Claude session and include:

```
MANUAL TEST RESULTS — SELF-IMPROVEMENT PROOF

Test 1 (RC-001 proof/examples):
  case_id: <from Google Chat>
  Draft included validation-stage acknowledgement: YES/NO
  Draft invented results or case studies: YES/NO
  PASS/FAIL: 

Test 2 (RC-005 capability question):
  case_id: <from Google Chat>
  Micro intent classified as: <label>
  Was PRICING_REQUEST fired: YES/NO
  PASS/FAIL: 

Test 3 (RC-005 non-pricing scope):
  case_id: <from Google Chat>
  Pricing language in draft: YES/NO
  Classification: <label>
  PASS/FAIL: 

Test 4 (additional intents edit):
  case_id: <from Google Chat>
  New proposed_shadow row created: YES/NO
  rule_id of new candidate: <if created>
  PASS/FAIL: 
```

The next Claude session will use these results to update `docs/SELF_IMPROVEMENT_SCORECARD.md`, advance Stage 8 to VERIFIED, and set `verified_complete = true` if ≥ 3 tests pass.
