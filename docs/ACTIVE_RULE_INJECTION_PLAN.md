# Active Rule Injection Plan

**Status:** PLANNED — NOT ACTIVE  
**Last updated:** 2026-06-23  
**Prepared by:** SL overnight batch (Phase 4B)

---

## Current State

Rule candidates are captured automatically as shadow data via Phase 1C/2A learning nodes in HumanApproval. They are stored in the `sl_rule_candidates` DataTable (`CSdiTjXfi0tl0oZF`).

A human reviewer may use the Phase 3 review console
(`scripts/SL-PHASE-3-rule-candidate-review-console.ps1`) to inspect candidates
and set their status to `approved_for_activation`.

**`approved_for_activation` is a review status only. It does NOT:**
- inject anything into the Decision workflow
- alter AI behaviour, prompt, or classification
- enable autonomous sending
- change any operating mode

Active rule injection is a **separate, future phase** that does not yet exist.

---

## Governance Rules for Active Rules (Future)

These rules must be enforced before any active injection is implemented:

1. **Human-approved only.** Only candidates with `status = approved_for_activation` (set by a named human reviewer) may ever become active rules. The system must not auto-promote candidates.

2. **Versioned.** Every active rule must carry a version ID, activation timestamp, and the reviewer who approved it. Rules must be stored in a versioned structure (not overwritten in place).

3. **Reversible.** Every active rule must have a clear rollback path. Rolling back must restore exactly the previous behaviour without side effects. Rollback must not require a full workflow redeploy.

4. **Contradiction detection.** Before a rule is activated, the system must check for contradictions with existing active rules (same scope, conflicting action). Contradictory rules must be blocked from activation until the conflict is resolved by a human reviewer.

5. **No weakening of safety gates.** Active rules must not:
   - lower confidence thresholds for sending
   - bypass dry-run, live-campaigns, or duplicate-check gates
   - reduce suppression coverage (unsubscribe, hostile, legal)
   - enable sending without human approval in VALIDATION mode

6. **No autonomous sending.** The first phase of active rule injection affects only supervised AI drafts (prompt context). It must not enable out-of-hours autonomous sending. That requires a separate controlled pilot phase (Phase 5/6) with explicit owner approval.

7. **Scope limited to supervised drafts first.** The first active rules may only influence what context is passed to the AI prompt for supervised drafting. They must not change routing, classification, or suppression behaviour in the first injection phase.

---

## Implementation Phases

### Phase 4C — Active Rule Table / Scaffold
- Create an `sl_active_rules` DataTable (separate from `sl_rule_candidates`).
- Schema: `rule_id`, `rule_type`, `classification_scope`, `micro_intent_scope`, `rule_text`, `activated_at`, `activated_by`, `version`, `status` (active/rolled_back), `rollback_reason`, `source_candidate_id`.
- Add a contradiction-check utility function (offline, run before activation).
- No n8n workflow changes in this phase.

### Phase 4D — Supervised Prompt Injection from Approved Rules
- In Decision node D (Draft Preparation), before building the AI prompt, fetch `sl_active_rules` rows where `status = active` and `micro_intent_scope` matches the current micro intent.
- Inject matching rule text as additional context into the supervised AI prompt (not as instructions that override safety).
- Gate: injection only runs when `effectiveDraftPolicy = AI_COMMERCIAL_SUPERVISED` or `ai_supervised`. Never runs for `HUMAN_ONLY`, `no_reply`, or escalation.
- Log injected rule IDs in the output for human review visibility.
- Patch scope: Decision node D only.

### Phase 4E — Monitored Retest
- Run the offline scenario harness (`scripts/SL-PHASE-4B-offline-commercial-scenario-harness.ps1`) against Phase 4D output.
- Perform controlled live test with a known test prospect (explicit owner approval required).
- Monitor Google Chat notifications for at least 48 hours before broadening.
- Document any regressions. Roll back immediately if any safety gate behaves unexpectedly.

### Phase 5 — Autonomous Shadow Simulation
- Simulate autonomous (no human approval) behaviour in shadow only.
- Shadow output is logged but never transmitted.
- Compare shadow vs human-approved drafts for quality and safety.
- Do not enable real autonomous sending until Phase 6.

### Phase 6 — Limited Out-of-Hours Autonomous Pilot
- Requires all of: explicit owner approval, Phase 5 clean shadow run (minimum 50 cases), confirmed compliance review, confirmed no legal/hostile/pricing cases in scope.
- Pilot must be time-boxed and scope-limited (specific campaign or time window only).
- Full human review of all Phase 6 sends within 24 hours.
- Automatic revert to VALIDATION mode on any anomaly.

---

## How to Set Up Phase 3 Review Console (Owner Action Required)

Phase 3 review console setup requires interactive owner confirmation.
Claude Code cannot run this unattended. The owner must run:

```powershell
# In the project directory:
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -Setup
# Type YES when prompted.
```

After setup, set the environment variable printed by the script, then:

```powershell
# Check proxy is up:
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -CheckSetup

# List rule candidates (read-only):
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ListCandidates

# Show a specific candidate:
.\scripts\SL-PHASE-3-rule-candidate-review-console.ps1 -ShowCandidate <rule_id>
```

**Do not run `ApproveCandidate`, `RejectCandidate`, `DeprecateCandidate`, or `RollbackCandidate` unless this plan's governance requirements are met.**

---

## Known Issue: detectAllIntents De-duplication Gap

Discovered during Phase 4B offline harness (2026-06-23):

`detectAllIntents()` does not filter the primary micro intent from secondary results for intents other than `PRICING_REQUEST`. This means:
- A `DATA_SECURITY_REQUEST` reply may show `DATA_SECURITY_REQUEST` as both primary and secondary.
- Same for `CONTRACT_TERMS_REQUEST`, `SMALL_SCALE_PILOT_REQUEST`.

**Safety impact:** None — the duplicate secondary is display noise only. Policy logic uses `primaryMicroIntent`, not secondary list, for the `AI_COMMERCIAL_SUPERVISED` upgrade gate.

**Recommended fix (Phase 4C or 4D):** Filter `detected_intents` to exclude entries where `micro_intent === primaryMicroIntent` before display and before rule matching.
