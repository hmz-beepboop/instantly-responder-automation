# Autonomous Live Shadow Traffic Bridge — Risk Review

**Date:** 2026-06-24  
**Phase:** 5H  
**Status:** Design document only. No implementation.

---

## Risk Summary

| Risk | Applies To | Severity | Mitigated By |
|------|------------|----------|-------------|
| Production workflow regression | Option 3 | High | Do not implement Option 3 during shadow review |
| Shadow evaluator accidentally activated too long | All options | Medium | Strict activate/deactivate protocol |
| Shadow evaluator sends a live reply | All options | Critical | Hardcoded `would_send_live_now=false` + Gate 1 |
| Full production classification data exposure | Options 2, 3 | Low | Data stays in n8n + owner-controlled Google Chat |
| Tap branch affecting main execution path | Option 3 | Medium | Node isolation, but regression risk remains |
| New webhook creates unapproved send path | Option 4 | Low | Shadow-only workflow design, no Sender connection |

---

## Key Risk Analysis

### Risk 1: Production Regression (Option 3)

Option 3 requires modifying the Decision workflow (versionId: `85f51eb4`). This workflow is stable and fully tested. Any modification:
- Resets the versionId (making rollback comparison harder)
- Introduces regression risk to the classification, routing, and human-review notification path
- Must be re-tested with all 55 existing test cases before re-deploying

**Mitigation:** Do not implement Option 3 until after Gate 2 is stable and there is a specific operational need (e.g. >20 replies/day making manual review impractical).

### Risk 2: Shadow Evaluator Left Active

The shadow evaluator receives all inbound traffic only when `active=true`. If left active accidentally, it could:
- Process real traffic without the owner's controlled review
- Generate shadow log records that are harder to audit
- Consume n8n execution credits

**Mitigation:** 
- Activate only for controlled windows (activate → submit → deactivate in <10 min)
- Use `SL-PHASE-5F-autonomous-shadow-control.ps1 -KillSwitch` as emergency
- Check `active=false` in n8n UI before and after every session

### Risk 3: Live Reply Sent (Any Option)

The shadow evaluator's JS code hardcodes `would_send_live_now: false` unconditionally. There is no Sender connection. There is no Instantly.ai API call in the workflow.

**Residual risk:** Near zero — requires both the hardcoded false to be removed AND a Sender connection to be added AND the workflow to be activated, which are all separate explicit actions.

**Mitigation:** Verified in 20/20 shadow webhook tests. Verified in acceptance harness. No Sender connection in workflow JSON.

### Risk 4: RC-SHADOW-003 Not Fixed Before Gate 2

If Gate 2 is approved before the allowlist wire-up enhancement is done:
- The n8n eligibility node would allow any campaign/sender/intent combination to pass Gate 3 checks
- An intent not on the intent_allowlist could become eligible if `autonomous_enabled=true`

**Mitigation:** RC-SHADOW-003 is a hard blocker for Gate 2. It is documented in `docs/RC_SHADOW_OWNER_DECISION_PACKET.md` and tracked in the Gate 2 checklist.

---

## Current Safety State

| Check | Status |
|-------|--------|
| Shadow evaluator active | false |
| would_send_live_now hardcoded | false |
| Sender connected | No |
| Instantly API called | No |
| Decision workflow modified | No (versionId: 85f51eb4) |
| HumanApproval modified | No |
| Proxy modified | No |
| Live send possible | No |
