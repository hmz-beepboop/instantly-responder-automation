# Autonomous Live Shadow Traffic Bridge — Approval Checklist

**Date:** 2026-06-24  
**Purpose:** Owner sign-off required before implementing any live traffic bridge option  
**Status:** NOT APPROVED — do not implement any option without completing this checklist

---

## Option 2 Approval (Google Chat Copy Helper)

Minor update to Decision workflow's Google Chat message format to include a pre-formatted shadow-eval payload.

**Pre-conditions:**
- [ ] Owner has reviewed `docs/AUTONOMOUS_LIVE_SHADOW_TRAFFIC_BRIDGE_DESIGN.md` Option 2 section
- [ ] Owner agrees the Google Chat message change is non-functional (format only, no routing change)
- [ ] Owner has confirmed Decision workflow is stable (versionId: `85f51eb4`)
- [ ] No other changes to Decision during the same session

**Owner Decision:** ☐ Approve Option 2  ☐ Reject — continue manual only  
**Owner Signature/Date:** _______________

---

## Option 3 Approval (Production Intake Shadow-Tap)

Adds a shadow-tap branch to the Decision or Intake workflow. This is a production workflow modification.

**Pre-conditions (ALL required):**
- [ ] Gate 2 controlled pilot is already running stably (not just approved)
- [ ] At least 14 days of controlled pilot completed with 0 safety issues
- [ ] Volume of inbound replies justifies automation (>20/day)
- [ ] Owner has reviewed Option 3 risk review in `docs/AUTONOMOUS_LIVE_SHADOW_TRAFFIC_BRIDGE_RISK_REVIEW.md`
- [ ] A rollback plan is documented with the current versionId recorded
- [ ] The tap branch design is reviewed and tested in a non-production copy first
- [ ] Regression test suite (55 test cases) planned for after modification

**Owner Decision:** ☐ Approve Option 3  ☐ Reject — not needed  
**Owner Signature/Date:** _______________  
**Target implementation date:** _______________

---

## Option 4 Approval (Separate Helper Webhook Workflow)

Creates a new n8n workflow (not connected to production) to assist with shadow review submissions.

**Pre-conditions:**
- [ ] Owner has reviewed the Option 4 design
- [ ] New workflow will have no Sender connection
- [ ] New workflow will have no Instantly API call
- [ ] New workflow will be imported as `active=false`
- [ ] Owner approves importing a new workflow to production n8n

**Owner Decision:** ☐ Approve Option 4  ☐ Reject  
**Owner Signature/Date:** _______________

---

## General Constraint

Regardless of which option is approved:
- No bridge implementation may enable live sends
- The shadow evaluator must remain `active=false` except during controlled test windows
- `would_send_live_now=false` must remain hardcoded in the shadow evaluator
- Decision, HumanApproval, and Proxy workflows may not be modified for bridge purposes without separate approval per this checklist

**Current recommendation: Continue with Option 1 (manual submission) through the 14-day review period and Gate 2. Revisit options only if operational need arises.**
