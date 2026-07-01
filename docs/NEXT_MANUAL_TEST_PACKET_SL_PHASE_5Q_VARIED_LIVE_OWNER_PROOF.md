# Manual Test Packet - SL-PHASE-5Q Varied Live Owner Proof

**Phase:** SL-PHASE-5Q self-improvement behavioural closure  
**Date:** 2026-06-27  
**Status:** PENDING OWNER LIVE TESTS  
**Purpose:** Prove that a human-approved draft improvement affects later similar drafts only within the intended scope, without leaking into unrelated classifications.

## 2026-06-28 SL-PHASE-5Q6 Addendum - Corrected Next Action

SL-PHASE-5Q6 is production-applied. Intake now accepts a stable alternate thread identifier from Instantly Unibox `thread_search=thread:<id>` when canonical hydration fails, and Decision fallback drafts now use active behavioural guidance instead of generic weak setup text.

Next owner action is review-only. Use a seeded owned/test prospect already present in the active campaign and reply in the existing campaign thread with:

```text
Before we go any further, can you explain what the setup would actually involve for our team?
```

Wait for the Google Chat card and inspect only:

- the card is normal/hydrated, not diagnostic;
- `Draft source` is either `ai_supervised` or a policy-aware fallback with a useful setup answer;
- the draft answers setup before CTA;
- the draft does not mention validation/proof/case studies/results unless the prospect asked for them.

Stop there. Do not click `Approved for learning only` or `Approve and send` until this post-5Q6 thread/draft behaviour is observed.

## 2026-06-28 SL-PHASE-5Q7 Addendum - Fresh Validation Recheck

`case-f67601bc` was hydrated and fallback quality was acceptable, but the normal AI draft was over-rejected by a dense-paragraph check and the review form labelled fallback as normal AI-assisted. Both defects are patched and production-applied.

Next owner action is a fresh review-only varied setup reply:

```text
Could you explain what the setup process would look like before we decide whether a call makes sense?
```

Inspect only the Google Chat card and review form:

- if `Draft source` is `ai_supervised`, the banner should say AI-generated draft for human review;
- if `Draft source` is `ai_failed_fallback`, the banner should say safe fallback draft and show a safe fallback reason;
- the draft should answer setup before CTA and avoid validation/proof/case-study/results/pricing/guarantee language unless asked.

Stop there. Do not click `Approved for learning only` or `Approve and send`.

## 2026-06-28 SL-PHASE-5Q8 Addendum - HumanApproval Render Reopen

Fresh post-5Q7 case `case-c3341a17` proved the accepted AI-generated path:

- `draft_source=ai_supervised`
- `Draft mode: AI-generated draft for human review`
- non-empty AI draft
- `INFORMATION_REQUEST / OFFER_EXPLANATION`

Clicking the review link then failed at HumanApproval node `J. Render Review Form HTML` because the 5Q7 banner/source HTML used unescaped JavaScript string quotes. 5Q8 patched only HumanApproval node `J` and production-applied HumanApproval `34531128-5ff6-4538-8846-bbbc5888a7a9`. Codex could not complete the live browser recheck because the render-only GET returned HTTP 401 before workflow execution; the owner/browser must be authenticated to the review form.

Next single owner action:

1. Reopen the same `case-c3341a17` review link from the original Google Chat card while authenticated.
2. Confirm the form renders normally.
3. Confirm the banner says: `AI-generated draft for human review. Edit before approving.`
4. Confirm incoming reply, non-empty draft, `Draft source: ai_supervised`, learning UI, Save, Approved for learning only, and Approve/send controls are visible.
5. Stop there.

Do not click Save, `Approved for learning only`, `Approve and send`, deny, or any follow-up action yet.

If the same link is expired, create one fresh varied setup reply:

```text
Could you walk me through what the setup would involve before we decide whether it is worth booking a call?
```

Again, stop after confirming the Google Chat card and review form render.

Do not run these tests until the SL-PHASE-5Q HumanApproval and Decision workflow updates have been applied to production after the exact production target guard passes:

```bash
pwsh -File ./scripts/assert-hmz-production-target.ps1
```

Codex could not apply production changes in WSL because `pwsh` is unavailable. No live emails should be sent by an agent. Owner must perform all live review/send actions.

---

## Global Pass Rules

A scenario passes only if all of these hold:

- Review form shows the draft-improvement fields and preserves them on reopen.
- Human edit produces a draft-learning event/candidate with the human reason, scope, targets, and desired behaviour.
- Candidate remains `proposed_shadow` until owner explicitly activates it.
- Decision consumes only active/effective behavioural policies after owner approval.
- Similar later drafts show the intended behaviour.
- Unrelated classifications do not show the improvement unless the owner explicitly chose a global scope.
- Shadow Evaluator remains `active=false`.
- Gate 2 remains not approved.
- Sender/live send path remains human-approved only.

---

## Scenario 1 - Positive / Meeting-Interest Setup Question

**Exact test client reply text:**

> "This sounds interesting, but before we book, can you explain what the setup actually includes?"

**Expected classification:** `INFORMATION_REQUEST` / `OFFER_EXPLANATION`

**Expected draft-learning behaviour:** If the draft rushes to a booking CTA, edit it to answer the setup question before asking for a call. The edit should create a `style` or draft-behaviour candidate with `status: proposed_shadow`, `requires_human_activation: true`, `source_original_case_id`, and `behavioural_instruction`.

**What the human should amend if draft is weak:** Add a direct opener and answer first, for example: "Of course - the setup is about defining sales capacity, qualification criteria, and outbound volume around what the team can actually handle before we suggest a call."

**What should be learned:** For `OFFER_EXPLANATION`, answer setup/coverage questions before CTA and avoid pushing the calendar as the first substantive response.

**What a later similar case should show:** A later setup/coverage question should lead with the answer and only then offer a 10-minute call.

**What unrelated classifications must not show:** Pricing, not-now, unsubscribe, and ambiguous-detail drafts must not inherit the setup-answer-before-CTA rule unless explicitly scoped globally.

**Pass/fail criteria:** PASS if the later similar draft reflects the behaviour after owner activation and unrelated scenarios do not. FAIL if only the first edit is captured but later similar drafts remain CTA-first, or if the rule leaks to unrelated classifications.

---

## Scenario 2 - Pricing / Cost Question

**Exact test client reply text:**

> "What does this cost, and is there a minimum commitment?"

**Expected classification:** `PRICING_OR_COMMERCIAL_NEGOTIATION` / `PRICING_REQUEST`

**Expected draft-learning behaviour:** If the draft invents pricing, edit it to avoid unsupported pricing claims and route toward a short clarification conversation.

**What the human should amend if draft is weak:** Remove invented numbers, guarantees, discounts, or package claims. Keep the reply honest: pricing depends on scope and should be discussed after understanding the team's outbound setup.

**What should be learned:** Pricing replies must not invent costs or commitments; they should acknowledge the question and keep facts inside approved knowledge.

**What a later similar case should show:** A later pricing question should avoid made-up numbers and ask for context before quoting anything.

**What unrelated classifications must not show:** The pricing caution must not weaken unsubscribe handling, not-now closure, or setup-explanation answers.

**Pass/fail criteria:** PASS if pricing behaviour improves only for pricing-like cases. FAIL if it causes all drafts to become pricing disclaimers or changes unsubscribe/not-now handling.

---

## Scenario 3 - Objection / Not-Now Reply

**Exact test client reply text:**

> "Looks interesting but this is not a priority for us right now. Maybe later in the year."

**Expected classification:** `TIMING_OBJECTION` / `NOT_NOW`

**Expected draft-learning behaviour:** If the draft pushes too hard for a meeting, edit it to acknowledge timing and close the loop politely.

**What the human should amend if draft is weak:** Remove pressure, urgency, or repeated booking links. Keep the response short and respectful.

**What should be learned:** Not-now replies should not force a call; acknowledge timing and leave the door open.

**What a later similar case should show:** A later not-now reply should be concise, low-pressure, and not CTA-heavy.

**What unrelated classifications must not show:** Positive setup questions should still be answered; pricing questions should still handle cost safely; unsubscribe must still suppress outreach.

**Pass/fail criteria:** PASS if later not-now drafts become less pushy without affecting positive/pricing/unsubscribe behaviours. FAIL if the system globally removes CTAs from positive replies.

---

## Scenario 4 - Unsubscribe / Not-Interested Reply

**Exact test client reply text:**

> "Not interested. Please remove me from your list."

**Expected classification:** `UNSUBSCRIBE` / `UNSUBSCRIBE_OR_COMPLAINT`

**Expected draft-learning behaviour:** If the draft includes persuasion, questions, booking links, or follow-up language, edit it to a compliant unsubscribe acknowledgement.

**What the human should amend if draft is weak:** Remove any CTA or sales content. Keep only the acknowledgement/removal message allowed by policy.

**What should be learned:** Unsubscribe/not-interested replies must stay short, compliant, and non-persuasive.

**What a later similar case should show:** A later unsubscribe case should not include a sales explanation, pricing answer, or booking CTA.

**What unrelated classifications must not show:** Positive, pricing, not-now, and ambiguous information requests must not become unsubscribe-style responses.

**Pass/fail criteria:** PASS if unsubscribe remains isolated and compliant. FAIL if any other scenario gets suppressed as if it were an unsubscribe, or if unsubscribe contains persuasion.

---

## Scenario 5 - Ambiguous / More-Detail Question

**Exact test client reply text:**

> "Can you send a little more detail before I decide whether it is relevant?"

**Expected classification:** `INFORMATION_REQUEST` / `HOW_IT_WORKS_REQUEST` or nearest detected information-request micro-intent.

**Expected draft-learning behaviour:** If the draft is too generic, edit it to give a concise, approved explanation while avoiding invented proof or results.

**What the human should amend if draft is weak:** Replace vague enthusiasm with a short explanation of capacity-aligned outbound, then ask whether a 10-minute conversation would be useful.

**What should be learned:** Ambiguous detail requests should get a concise explanation before any CTA, but should not inherit a micro-intent-only setup rule unless the target classifications match.

**What a later similar case should show:** A later broad-detail request should be clearer and less generic.

**What unrelated classifications must not show:** Pricing should not receive setup language unless pricing also asks about setup; unsubscribe/not-now remain isolated.

**Pass/fail criteria:** PASS if behaviour improves for matching information requests and does not leak across micro-intents when the owner selected micro-intent scope. FAIL if a micro-scoped `OFFER_EXPLANATION` rule changes `HOW_IT_WORKS_REQUEST` drafts.

---

## Focused Proof - case-759e58d7 to case-d099e6f3

**Known source case:** `case-759e58d7`  
**Known comparison case:** `case-d099e6f3`

The failure to prove/fix is:

1. Source case received a human draft improvement, including a more natural opener and clearer response style.
2. Later similar case did not show that improvement.
3. SL-PHASE-5Q local patch adds:
   - durable reopened-form draft-learning preservation;
   - `behavioural_instruction`;
   - source original case ID;
   - human activation requirement;
   - Decision consumption of active/effective behavioural policies.

**Owner proof steps:**

1. Recreate or locate a source case equivalent to `case-759e58d7`.
2. Edit the draft with the desired opener/style change.
3. Enter the reason, type, desired future behaviour, scope, and target classifications.
4. Confirm the generated candidate is `proposed_shadow`, not active.
5. Owner-review and activate the candidate only if safe.
6. Use a later similar case equivalent to `case-d099e6f3`.
7. Confirm the later draft contains the intended behaviour.
8. Run at least one unrelated pricing, not-now, unsubscribe, and ambiguous case to confirm no leakage.

**Pass criteria:** The later similar case shows the source-case improvement after owner activation, while unrelated classifications do not show it.

**Fail criteria:** The later case does not change, the candidate remains unavailable to Decision after activation, the improvement leaks to unrelated classifications, or any autonomous/live-send path is enabled.

---

## Result Log

| Check | Status | Evidence |
|---|---|---|
| Production guard passed | PASS | 2026-06-28 Codex corrected retest Stage 1 |
| Production HumanApproval updated | PASS | `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609` |
| Production Decision updated | PASS | `a4dab823-a540-48e8-8df6-514eca5d060a` |
| Source case improvement captured | PENDING | Owner live test |
| Later similar case improved | PENDING | Owner live test |
| Unrelated classifications isolated | PENDING | Owner live test |
| Shadow Evaluator inactive | PASS | `ae13bf4e-ee04-438f-9657-3c57183b90a2`, `active=false` |
| Sender/live send untouched | PASS | Sender `dfb310f4-901a-4d76-81dc-8f5d4ad13552`; no Sender trigger in corrected retest Stage 1 |

---

## Post-Fix Retest Addendum - SL-PHASE-5Q2 / 5R-prep

**Status:** PENDING OWNER REVIEW-FORM RETEST AFTER 5Q3 CONTEXT FIX  
**Production fix installed:** HumanApproval `e2af1c8d-8ad2-41cf-a97a-b1e0804ea609`, Decision `a4dab823-a540-48e8-8df6-514eca5d060a`

2026-06-28 Codex corrected retest Stage 1: production guard passed; HumanApproval, Decision, Sender, Proxy, and Shadow versionIds were verified read-only through n8n API; Shadow remained inactive; Sender remained dry-run/no-live-campaign/no-live-credential-ready; 5Q3 Python/PowerShell returned `30/30 PASS`; 5Q2 Python/PowerShell returned `27/27 PASS`. The next step is still the first hydrated owner review-form action below.

2026-06-28 SL-PHASE-5Q4 update: hydrated `case-535d430a` created a valid Google Chat card but exposed a HumanApproval node J render syntax defect. Codex fixed and production-applied the renderer. HumanApproval is now `542f4159-fb6b-4dc4-9dda-f97657fbf7ac`. Next single action: reopen the same `case-535d430a` review link and confirm the form renders. Do not save, learning-only, approve, or send until Codex records the render result.

2026-06-28 SL-PHASE-5Q5 update: Save/reopen failed because the renderer loaded original `draft_text` instead of saved `decision_payload.latest_saved_reply_text` for unsent `IN_REVIEW` cases. Codex fixed and production-applied this. HumanApproval is now `4caf621f-cda5-4aca-84a7-e1b521e99c7c`. Next single action: reopen `case-535d430a`, edit/save the same fields again, reopen the same link, and report whether values persisted. Do not click learning-only or approve/send.

5Q3 note: do not use `case-ed174cd6`. That case was invalid because Decision D failed with `error: missing /` and HumanApproval built a blank/UNKNOWN fallback review. The corrected system now blocks blank/UNKNOWN cases as diagnostic-only and hides normal approve/send and learning-only actions.

Do not start with a live send. The first retest should stop at the review form.

Minimum retest:

1. Use a seeded owned/test prospect already present in the active Instantly campaign thread. Reply in the existing campaign thread, not as a new standalone email or forward.
2. Send: `Before we book anything, can you explain what your setup actually includes?`
3. Confirm the Google Chat card is hydrated before opening the form: From is not `UNKNOWN`, Sender is not `? <?>`, Broad category is not `UNKNOWN`, Micro intent is set, and Reply excerpt is nonblank. If any of these fail, stop and report the case ID only.
4. Open the next normal review form.
5. Confirm the draft-learning section has one combined field: `Why did you make this change, and what should the system do next time?`
6. Confirm scope is multi-select.
7. Confirm improvement type is multi-select and includes `Style`.
8. Edit the draft and fill the combined learning field with the setup-question rule.
9. Click `Save draft and learning`, not approve/send.
10. Reopen the same review URL and confirm edited draft, combined learning instruction, scopes, types, and target classifications are preserved.
11. If the form is correct, use `Approved for learning only` on a no-send proof case to confirm candidate creation without email send.
12. Only after the above passes, create a later similar setup-question case and inspect the draft. It should answer first, use short paragraphs or a list where suitable, avoid malformed opener text, and avoid validation/proof/public-example language unless the prospect asks for proof.

Do not click `Approve and send` for this retest unless the owner explicitly chooses to run a live send after the review-form and draft-behaviour checks pass.

Specific post-fix pass criteria:

- Active behavioural guidance materially affects the next similar draft at review stage.
- Saved edits/learning persist on the same review link before approval.
- `Approved for learning only` creates learning without sending.
- Duplicate/retry links are not used for `case-a3e7b1d2`.
- Shadow Evaluator remains inactive.
- Gate 2 remains not approved.
