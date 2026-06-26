# Autonomous Allowlist Wire-Up Verification

**Date:** 2026-06-24  
**Phase:** 5I — RC-SHADOW-003 Applied  
**Status:** COMPLETE — allowlist wire-up applied and verified

---

## Summary

RC-SHADOW-003 has been applied. The n8n shadow evaluator eligibility node now correctly checks all three allowlists (`campaign_allowlist`, `sender_allowlist`, `intent_allowlist`). Empty allowlists block eligibility. PERMANENT_BLOCK intents override all allowlists. `would_send_live_now=false` remains hardcoded unconditionally.

**Allowlist wire-up status: COMPLETE**  
**RC-SHADOW-003 status: APPLIED — 2026-06-24**  
**New shadow evaluator versionId: `ae13bf4e-ee04-438f-9657-3c57183b90a2`**  
**Workflow active: `false` (verified)**

---

## Component 1: PowerShell Eligibility Engine (SL-PHASE-5C)

File: `scripts/SL-PHASE-5C-autonomous-eligibility-engine.ps1`

### Status: UNCHANGED — verified Phase 5H

All allowlist checks correct in PS eligibility engine (offline scenarios).
- `campaign_allowlist` empty → blocked (via scenario boolean flag pattern)
- `sender_allowlist` empty → blocked
- `intent_allowlist` empty → blocked directly in config array check
- 75 scenarios: all `would_send_live_now=false`

---

## Component 2: n8n Shadow Evaluator Workflow (aHzLtQiv6G8h1bqD)

File: `workflows/disabled_autonomous_shadow_evaluator.json`  
**Version after RC-SHADOW-003: 1.1.0**

### Eligibility Node After Patch (RC-SHADOW-003)

The `Run Eligibility Gates [SHADOW ONLY]` node now implements:

```javascript
// RC-SHADOW-003: Allowlist wire-up — campaign, sender, intent all required
const cLen = (SHADOW_CONFIG.campaign_allowlist || []).length;
const sLen = (SHADOW_CONFIG.sender_allowlist || []).length;
const iLen = (SHADOW_CONFIG.intent_allowlist || []).length;
const campaignOk = cLen > 0 && SHADOW_CONFIG.campaign_allowlist.includes(p.campaign_id);
const senderOk   = sLen > 0 && SHADOW_CONFIG.sender_allowlist.includes(p.sender_email);
const intentOk   = iLen > 0 && SHADOW_CONFIG.intent_allowlist.includes(intent);
const confOk     = confidence >= SHADOW_CONFIG.confidence_threshold;
```

PERMANENT_BLOCK intents override allowlists:
```javascript
if      (intentBlocked)          allowlistBlockReason = 'intent_permanently_blocked';
else if (addBlocked.length > 0)  allowlistBlockReason = 'additional_intent_permanently_blocked';
else if (cLen === 0)             allowlistBlockReason = 'campaign_allowlist_empty';
else if (!campaignOk)            allowlistBlockReason = 'campaign_not_allowlisted';
// ... etc
```

`would_send_live_now` remains hardcoded false:
```javascript
const blockedReason = 'shadow_evaluator_always_disabled';
const wouldSendLiveNow = false; // HARDCODED — never changes
```

### Current Allowlist Status in n8n (after patch)

| Check | In Code | Reached? | Live Send Possible? |
|-------|---------|----------|---------------------|
| Gate 1 (always_disabled) | YES — unconditional | Always | NO |
| campaign_allowlist check | YES — wired up | After perm-block checks | NO |
| sender_allowlist check | YES — wired up | After campaign check | NO |
| intent_allowlist check | YES — wired up | After sender check | NO |
| confidence check | YES — wired up | After intent check | NO |
| would_send_live_now=false | Hardcoded | Always | NO |

---

## Verification Results

### Test: 20 offline allowlist simulation tests (Phase 5I)

Run: `.\scripts\SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1 -RunAllowlistTests`  
Result: **20/20 PASS**  
Output: `outputs/autonomous_allowlist_shadow_test_results.json`

| Test Group | Cases | Result |
|------------|-------|--------|
| Allowlisted eligible (T01–T04) | 4 | PASS — correctly shadow eligible |
| Non-allowlisted (T05–T07) | 3 | PASS — correctly blocked by allowlist |
| PERMANENT_BLOCK (T08–T12) | 5 | PASS — blocked regardless of allowlists |
| Multi-intent blocked (T13–T14) | 2 | PASS — additional intent blocks |
| Edge cases (T15–T20) | 6 | PASS — ambiguous/OOO/low-conf/empty-lists all blocked |
| **would_send_live_now=false** | **20/20** | **ALL FALSE** |

### Test: n8n API deployment

- New versionId: `ae13bf4e-ee04-438f-9657-3c57183b90a2`
- active: false (verified via API response)
- No Sender node: VERIFIED
- No Instantly send/reply endpoint: VERIFIED
- would_send_live_now hardcoded false: VERIFIED

---

## RC-SHADOW-003 Resolution Status

**Status: APPLIED AND COMPLETE — 2026-06-24**

All pre-Gate-2 requirements for RC-SHADOW-003 are met:
1. ✅ campaign_id checked against campaign_allowlist
2. ✅ sender_email checked against sender_allowlist
3. ✅ micro_intent checked against intent_allowlist
4. ✅ empty allowlists block eligibility (all three)
5. ✅ PERMANENT_BLOCK overrides allowlists
6. ✅ multi-intent with blocked component blocks
7. ✅ would_send_live_now=false hardcoded (unconditional)
8. ✅ workflow active=false after apply
9. ✅ no Sender connection
10. ✅ no Instantly API calls

**Remaining before Gate 2 (not RC-SHADOW-003):**
- Populate campaign_allowlist, sender_allowlist, intent_allowlist with owner-approved values
- Complete 14-day shadow review
- Owner signs Gate 2 checklist

---

## Files Verified

| File | Status |
|------|--------|
| `scripts/SL-PHASE-5C-autonomous-eligibility-engine.ps1` | VERIFIED — allowlists block correctly offline |
| `workflows/disabled_autonomous_shadow_evaluator.json` | VERIFIED — RC-SHADOW-003 applied, v1.1.0 |
| `outputs/autonomous_allowlist_shadow_test_results.json` | VERIFIED — 20/20 would_send_live_now=false |
| `outputs/autonomous_readiness_acceptance_report.json` | VERIFIED — 45/45 PASS (Phase 5H) |
| `scripts/SL-PHASE-5I-shadow-evaluator-allowlist-enforcement.ps1` | CREATED — patch + test script |
