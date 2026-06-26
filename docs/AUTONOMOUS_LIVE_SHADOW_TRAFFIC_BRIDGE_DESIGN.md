# Autonomous Live Shadow Traffic Bridge — Design Document

**Date:** 2026-06-24  
**Phase:** 5H — Design Only (not implemented)  
**Status:** DESIGN DOCUMENT ONLY. No implementation in this session.  
**Purpose:** Design how real inbound replies could be mirrored into the shadow evaluator without sending.

---

## Context

Currently, the shadow evaluator receives traffic only through manual payload submission. The owner selects real inbound replies, builds JSON payloads, and submits them to the shadow evaluator webhook manually. This is safe but labour-intensive.

A "live shadow traffic bridge" would automatically forward eligible real inbound replies from the main Decision workflow to the shadow evaluator — without causing any sends. This document designs four options and recommends the appropriate approach for each phase.

---

## Option 1: Manual Payload Submission Only (Current State)

### How It Works
Owner reviews inbound replies in Instantly.ai, selects candidates, builds JSON payloads manually, and POSTs them to the shadow evaluator webhook during a controlled window when the evaluator is temporarily active.

### Effort
Low setup (already done). Medium ongoing effort per day (~20 min/day).

### Risk
Very low. No workflow modification. No automation risk. Complete owner control.

### Production Workflow Modification Required
No.

### Live Send Possible
No. Shadow evaluator hardcodes `would_send_live_now=false`.

### Data Captured
Whatever the owner chooses to include. May miss nuance from full Decision output (only what owner copies over).

### Owner Approval Required
No (already approved and tested in Phase 5F).

### Rollback
N/A — nothing to roll back.

### Recommendation
**Use for 14-day shadow review period and Gate 2 evaluation. Default mode.**

---

## Option 2: Google Chat Review Link / Manual Copy

### How It Works
The Decision workflow already sends cases to a Google Chat review channel. The owner copies the JSON from the review message and submits it to the shadow evaluator. This reduces manual payload construction because the case data is already formatted.

### Effort
Low setup (no workflow changes needed). Slightly lower daily effort than Option 1 (5–10 min/day instead of 20).

### Risk
Low. No workflow modification. The copy step remains manual, so there's no automation risk.

### Production Workflow Modification Required
Minimal — Decision workflow could be updated to include a formatted shadow-eval payload in the Google Chat message. This is a non-functional addition (no routing change).

### Live Send Possible
No. Still requires manual submission to shadow evaluator.

### Data Captured
Same as Decision workflow output. Complete classification data including micro_intent, confidence, campaign_id, sender_email.

### Owner Approval Required
Yes — modification to the Decision workflow's Google Chat message format requires owner review and explicit approval before implementation.

### Rollback
Easy — remove the payload from the Chat message format.

### Recommendation
**Consider for Week 2 of shadow review if manual payload construction is burdensome. Requires owner approval of the HumanApproval node change (minor format update). Do not implement without sign-off.**

---

## Option 3: Production Intake Shadow-Tap Branch (Disabled by Default)

### How It Works
A new branch is added to the main Decision workflow (or Intake) that, when enabled, automatically forwards every classified reply to the shadow evaluator webhook. The branch is controlled by a flag (`shadow_tap_enabled=false` default) and hardcoded to never produce sends.

### Effort
High setup — requires modifying a production workflow (Decision or Intake). Requires careful node design to ensure the tap never affects the main execution path.

### Risk
**Medium-High.** Modifying a production workflow introduces regression risk. The tap branch must be completely isolated from the main path. Any bug in the tap node could affect production classification. Requires thorough testing before enabling.

### Production Workflow Modification Required
**Yes — modification to Decision or Intake workflow.** This is a production change to currently stable, verified workflows.

### Live Send Possible
In theory no — the shadow evaluator hardcodes no sends. But the risk is that modifying Intake/Decision introduces unintended side effects.

### Data Captured
Full real-time classification data for every eligible reply, automatically.

### Owner Approval Required
**Yes — explicit owner approval required before any production workflow modification.** Decision workflow current versionId is `85f51eb4`. Any change creates a new versionId and must be tracked.

### Rollback
Medium complexity — revert Decision to prior versionId. Need to maintain rollback record.

### Recommendation
**Do NOT implement during shadow review period. Consider only after Gate 2 with explicit owner approval. Conservative recommendation: skip Option 3 entirely unless volume makes manual review impractical (e.g. >20 replies/day).**

---

## Option 4: Separate Webhook Triggered by Controlled Test Payloads

### How It Works
A new n8n workflow (not connected to Intake/Decision) is created with a separate webhook that accepts controlled test payloads from Claude Code or owner. This is essentially a structured version of Option 1 — but the workflow could include helper nodes (e.g. auto-format display, digest accumulation) to reduce manual effort.

### Effort
Medium setup — new workflow needed but no production workflow changes.

### Risk
Low. Separate from all production workflows. No regression risk to Decision/HumanApproval/Proxy.

### Production Workflow Modification Required
No. New separate workflow.

### Live Send Possible
No — workflow designed from scratch with no Sender connection.

### Data Captured
Whatever is submitted manually or via helper script. Can be enriched with automation later.

### Owner Approval Required
Yes — importing a new n8n workflow requires owner awareness and approval.

### Rollback
Easy — delete or deactivate the new workflow.

### Recommendation
**Consider as an enhancement to Option 1 for Phase 5I or beyond. Lower risk than Option 3. Useful if daily shadow review volume grows beyond 10 cases/day.**

---

## Comparison Table

| Option | Effort | Risk | Prod Modification | Live Send Possible | Data Captured | Owner Approval | Rollback |
|--------|--------|------|-------------------|--------------------|---------------|----------------|---------|
| 1 — Manual | Low setup, Medium daily | Very Low | No | No | Partial | No | N/A |
| 2 — Google Chat copy | Low setup, Low daily | Low | Minor | No | Full | Yes (minor) | Easy |
| 3 — Intake shadow-tap | High setup | Medium-High | YES (production) | No | Full auto | YES (required) | Medium |
| 4 — Separate webhook | Medium setup | Low | No | No | Partial/manual | Yes (new wf) | Easy |

---

## Recommendation

| Phase | Recommended Option | Reason |
|-------|--------------------|--------|
| 14-day shadow review (now) | **Option 1** | Zero risk, already working, sufficient for 30+ candidates |
| Week 2 if volume is high | **Option 2** | Minor efficiency improvement, minimal risk |
| Gate 2 controlled pilot | **Option 1 or 2** | Still manual control for the first pilot phase |
| Post-Gate 2 scale-up | **Option 4** | If volume warrants automation, build a separate helper workflow |
| Production scale (future) | **Option 3** | Only after extended controlled pilot, full owner sign-off |

**Conservative recommendation: Keep manual submission (Option 1) throughout the 14-day period. Do not modify Intake or Decision for shadow traffic until the controlled pilot is stable and there is a clear operational need.**

---

## What Is NOT in Scope for This Design

- Any routing change to the Sender workflow
- Any change to the Instantly.ai reply handling
- Any mechanism that could send a reply without human approval
- Any change to Decision, HumanApproval, or Proxy workflows in this session
