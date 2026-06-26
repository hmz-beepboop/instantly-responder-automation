# Manual Test Packet — Review Reopen and Repeat Send (SL-PHASE-5P)

**Date:** 2026-06-26
**HumanApproval versionId:** 9c71882f-a096-48a9-861a-37e5424035ae

---

## Pre-conditions

- A case must have been approved and sent (status = `RESPONSE_APPROVED`)
- Use the original review link (token required; expiry is NOT checked for approved cases)
- Do NOT approve or send anything during testing unless explicitly instructed

---

## Test 1 — Pending review form (baseline)

**Goal:** Confirm pending-review form is unchanged.

Steps:
1. Open a pending case review link (status = NEW or IN_REVIEW)
2. Confirm:
   - No already-sent banner visible
   - Draft-learning fields visible: "Why did you change the draft reply?", scope dropdown, target classifications checkboxes, revision type, desired future behavior
   - Classification correction section present
   - "Approve and send" button visible
   - "Deny / no reply" button visible
   - NO "Approve future learning changes only" button
   - NO "Send another human-approved reply" button

**Pass criteria:** All baseline fields present, no sent-case UI elements.

---

## Test 2 — Approved and sent case — form access

**Goal:** Confirm already-sent banner appears for RESPONSE_APPROVED case.

Steps:
1. Find the review link for a previously approved and sent case
2. Open the link
3. Confirm:
   - Green banner: "This review was already approved and an email was already sent."
   - Info text: "The fields below are prefilled with the last human-approved content, not the original AI draft."
   - Info text: "This includes the last approved reply text, classification corrections, and reasons entered by the reviewer."
   - Revision counter: "Approved improvement revisions for this case: 1"
   - Reply textarea prefilled with the approved reply (not original AI draft)
   - "Approve future learning changes only — do not send email" button visible
   - "Send another human-approved reply" button visible
   - "Approve and send" (original) button NOT visible
   - "Deny / no reply" (original) button NOT visible

**Pass criteria:** All sent-case UI elements present and correct.

---

## Test 3 — Learning-only approval (do NOT approve live)

**Goal:** Verify approve_learning_only works without sending.

Steps:
1. Open an approved/sent case review link
2. Edit the draft text (change something)
3. Enter a reason in "Why did you change the draft reply?"
4. Select scope and check at least one target classification
5. Enter approver name/email
6. Click "Approve future learning changes only — do not send email"
7. Confirm result page shows:
   - "Learning revision approved — no email sent"
   - "Draft improvement learning captured for case case-xxx"
   - "Approved improvement revisions for this case: 2"
8. Reopen the same case review link
9. Confirm revision counter now shows: 2

**Pass criteria:**
- No email sent to prospect
- Revision counter increments
- Reopened form shows revision 2

---

## Test 4 — Follow-up send (metadata capture only — no auto-send)

**Goal:** Verify approve_and_send_followup captures metadata but does NOT send automatically.

Steps:
1. Open an approved/sent case review link
2. Click "Send another human-approved reply"
3. Confirm a "Reason for sending a follow-up reply" text input appears
4. Enter a reason (e.g. "Prospect sent another question")
5. Enter approver name/email
6. Click "Send another human-approved reply" button
7. Confirm result page shows:
   - "Follow-up send captured — manual send required"
   - "The email was NOT automatically sent."
   - "Controlled repeat send requires a Sender idempotency audit (SL-PHASE-5Q)"
   - Controlled send key shown (e.g. "case-xxx|f2 (revision 2)")

**Pass criteria:**
- No email auto-sent
- Result page clearly explains manual send required
- Repeat send reason stored

---

## Test 5 — Blocked/denied case — no sent banner

**Goal:** Confirm denied/blocked cases don't show the already-sent banner.

Steps:
1. Open review link for a case with status NO_REPLY_REQUIRED or BLOCKED_MISSING_VARIABLES
2. Confirm: no already-sent banner visible
3. Confirm: no revision counter visible

---

## Test 6 — Google Chat notification expiry text

**Goal:** Confirm review notifications include expiry info.

Steps:
1. Trigger a new review case (send/process a test prospect reply)
2. Check the Google Chat message
3. Confirm it includes a line like:
   - "Review link expires: 2026-06-26T10:15:00.000Z (58 min remaining)"
4. After 60 minutes (if you wait), confirm it shows "EXPIRED"

---

## Test 7 — Classification correction reasons prefill (requires prior corrected case)

**Goal:** Verify that if a prior learning amendment stored corrections, they prefill on reopen.

Precondition: Test 3 must have been completed with a correction entered.

Steps:
1. Reopen the same case from Test 3
2. Confirm corrected category and micro intent fields are prefilled with the latest corrections from Test 3
3. Clear the fields and submit — confirm new state is stored

---

## What to report back to Claude

After each test, report:
- Test number
- Pass / Fail
- What you saw (exact banner text, button labels, revision number)
- Any unexpected behavior
- Case ID used

Claude will then verify proposed_shadow rule candidates in the DataTable to confirm all fields were captured correctly.
