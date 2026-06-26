# Autonomous Phase 5 Architecture

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED  
**Owner approval required before any implementation**

---

## Overview

Phase 5 describes the autonomous layer — the future ability for the HMZ Instantly Responder Automation to classify, evaluate, and (under strict conditions) send replies without requiring human approval for every case.

**This layer is currently at 0%. Nothing in this document activates any autonomous behavior. All sends still require human approval.**

---

## Operating Modes

The system progresses through modes in order. Each mode requires explicit owner approval before activation.

### Mode 0 — Supervised Only (CURRENT STATE)
- Every reply requires human approval
- No autonomous action possible
- Self-improving layer active (learning from every approval)
- `autonomous_enabled = false`
- `shadow_only = true`
- `dry_run = true`

### Mode 1 — Shadow Evaluation (NEXT PLANNED)
- System runs autonomous eligibility engine in parallel with every supervised case
- Shadow decisions are logged but never sent
- Owner reviews shadow log daily
- No live sends from shadow path
- Purpose: calibrate eligibility engine before enabling any live sends
- `autonomous_enabled = false`
- `shadow_only = true`
- `dry_run = true`

### Mode 2 — Controlled Pilot (FUTURE — REQUIRES OWNER APPROVAL)
- Maximum 1 autonomous send per day
- Only lowest-risk intent types (T1/T5 or equivalent)
- Only allowlisted campaigns and senders
- Working-hours eligibility gate required
- Every autonomous send reviewed by owner next morning
- `autonomous_enabled = true`
- `shadow_only = false`
- `dry_run = false`
- `live_pilot_daily_cap = 1`
- `live_pilot_requires_owner_toggle = true`

### Mode 3 — Live Autonomous (FUTURE — REQUIRES FULL PILOT REVIEW)
- Higher daily cap (e.g. 5/day, then increasing)
- Expanded intent eligibility based on pilot evidence
- Daily digest review mandatory
- Kill switch always available
- Still blocks all high-risk intent types permanently

---

## Architecture Components

### Component 1 — Eligibility Engine
Offline-designed decision engine that evaluates each candidate against:
- Working-hours window
- Campaign allowlist
- Sender allowlist
- Intent eligibility
- Risk flags
- Confidence threshold
- Active rule conflicts
- Duplicate send protection
- Thread/sender/campaign identity confidence

Output: structured eligibility object with `would_be_shadow_eligible` and `would_send_live_now` fields.

### Component 2 — Autonomous Config
JSON config file defining all eligibility parameters. All defaults set to disabled.  
Schema: `outputs/autonomous_config_schema.json`  
Sample: `outputs/autonomous_sample_config.json`

### Component 3 — Shadow Candidate Log
Every candidate evaluated by the eligibility engine produces a shadow log entry regardless of outcome. The log is reviewed by the owner daily.  
Schema: `outputs/autonomous_shadow_log_schema.json`

### Component 4 — Daily Digest
Aggregated summary of all shadow candidates, blocked cases, escalations, and learning events from the past 24 hours.  
Spec: `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md`

### Component 5 — Post-Action Review Form
For any case that does proceed autonomously (Mode 2+), the owner reviews the action next morning using a structured form.  
Spec: `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md`

### Component 6 — Follow-Up Learning
Autonomous sends that receive negative follow-up replies trigger immediate human case creation. Owner reviews and creates learning signals. These feed back into the same rule candidate system as supervised cases.  
Spec: `docs/AUTONOMOUS_FOLLOWUP_LEARNING_SPEC.md`

### Component 7 — Disabled Shadow Evaluator Workflow
A disabled n8n workflow scaffold that can evaluate a manual test payload and produce a shadow decision object. Never activates production traffic. Never connects to Sender.  
Spec: `docs/AUTONOMOUS_SHADOW_EVALUATOR_WORKFLOW_SPEC.md`

### Component 8 — Kill Switch
Emergency disable path that sets `emergency_disabled = true` and stops all autonomous processing within one config reload.  
Spec: `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md`

---

## Integration with Existing System

### What the autonomous layer does NOT touch
- Intake workflow (never modified)
- Sender workflow (never connected to autonomous path)
- ErrorHandler (never modified)
- SLAWatchdog (never modified)
- FullTestHarness (never activated)
- HumanApproval workflow (not replaced, still used for supervised cases)
- Instantly send/reply API (only callable through existing Sender workflow, never directly from autonomous path)

### What the autonomous layer uses (read-only)
- Decision workflow output (classification + eligibility assessment)
- Active rules from Decision node D (same rules as supervised path)
- Knowledge base (`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`)
- Reply policy (`docs/HMZ_APPROVED_REPLY_RULES.md`)

### What the autonomous layer adds (new)
- Eligibility engine running in shadow parallel
- Shadow candidate log DataTable (new — not yet created)
- Daily digest generation
- Post-action review form (new form, separate from HumanApproval)
- Follow-up learning capture for autonomous cases

---

## Rollout Sequence

```
Phase 5A — Architecture design and safety model (COMPLETE — this document)
Phase 5B — Config schema and working-hours engine (COMPLETE — scripts/SL-PHASE-5B)
Phase 5C — Eligibility engine offline scenarios (COMPLETE — scripts/SL-PHASE-5C)
Phase 5D — Disabled shadow evaluator workflow scaffold (COMPLETE — workflows/disabled_autonomous_shadow_evaluator.json)
Phase 5E — Acceptance harness (COMPLETE — scripts/SL-PHASE-5E)

[ALL ABOVE ARE DESIGN/OFFLINE ONLY — AUTONOMOUS NOT ENABLED]

Phase 5F — Shadow mode activation [REQUIRES OWNER APPROVAL]
Phase 5G — Controlled pilot 1/day [REQUIRES OWNER APPROVAL AFTER SHADOW REVIEW]
Phase 5H — Expanded pilot [REQUIRES PILOT EVIDENCE REVIEW]
```

---

## Related Documents

- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — what is and is not autonomous
- `docs/AUTONOMOUS_SAFETY_MODEL.md` — safety gates and overrides
- `docs/AUTONOMOUS_KILL_SWITCH_AND_ROLLBACK.md` — emergency controls
- `docs/AUTONOMOUS_OWNER_APPROVAL_CHECKLIST.md` — what owner must approve
- `docs/AUTONOMOUS_FAILURE_MODES_AND_CONTROLS.md` — failure scenarios and mitigations
- `docs/AUTONOMOUS_GO_NO_GO_CHECKLIST.md` — go/no-go before each mode advancement
