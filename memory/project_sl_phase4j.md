---
name: project_sl_phase4j
description: Phase 4J self-improvement verification suite + Phase 4I Apply results (token-refresh retry + proxy write fix); versionIds confirmed; harness 20/20; scorecard baseline set
metadata:
  type: project
---

## Phase 4I Apply — COMPLETED 2026-06-23

Both Phase 4I scripts applied successfully.

**Connection format bug fixed in 4I-A:** `C2` function had `,@(@{...})` (unary comma) causing triple nesting for IF-node branches. Fixed to `@(@{...})` — removes one wrapping layer. Both the scripts copy and Downloads copy were patched.

**HumanApproval** `9aPrt92jFhoYFxbs`  
- versionId after Apply: `27ef843a-1291-4e6b-a25f-dbe1dd7c351a`
- Nodes added: R0, R0-Route, R1-Route, R-GenToken, R2, R3, R4, R5, R5b
- Node H and L accept RETRY_NEEDED status
- Q now routes to R0 (retry classifier) instead of directly to R
- Recoverable blocks: campaign_not_found, instantly_api_error, send_state_lock_conflict, sender_validation_failed
- Nonrecoverable: duplicate_send_guard, send_key_conflict, SENT, SENT_RECONCILED, legal, safety_block

**Proxy** `seB6ZmlyomhC4QWU`  
- versionId after Apply: `47dbb8bd-ebbb-4a10-a39b-a1fb83be36ac`
- Validate Write node now handles: object body, string body, stringified JSON body
- VALID_STATUSES preserved: proposed_shadow, approved_for_activation, rejected, deprecated, rolled_back
- Webhook Read endpoint preserved

**False positives in verification (not real failures):**
- 4I-A: `*Sender*` check matches new `R0-Route. Sender Block Router` node name (intentional node)
- 4I-B: Verification looked for `typeof rawBody` but code uses `typeof raw` (variable name differs — code correct)

**Harness:** 20/20 PASS (all Phase 4I retry + proxy write scenarios confirmed)

---

## Phase 4J — Self-Improvement Verification Suite — COMPLETED 2026-06-23

**Script:** `scripts/SL-PHASE-4J-self-improvement-verification-suite.ps1`  
**Copy:** `C:\Users\Hamzah Zahid\Downloads\SL-PHASE-4J-self-improvement-verification-suite.ps1`

**Stage scores (baseline):**

| Stage | Status | Score |
|-------|--------|-------|
| S1 Draft revision captured | INSTALLED | 7/10 |
| S2 Human edit captured | INSTALLED | 7/10 |
| S3 Classification correction captured | INSTALLED | 7/10 |
| S4 Additional intent captured | INSTALLED | 7/10 |
| S5 Proposed shadow created | VERIFIED | 10/10 |
| S6 Approved for activation | VERIFIED | 10/10 |
| S7 Active rule injected | UNCONFIRMED | 5/10 (regex miss; Phase 4D 65/65 harness confirms actual state) |
| S8 Future email improved | STATIC_VERIFIED | 7/10 (manual live test required) |
| S9 Safety gates preserved | UNCONFIRMED | 7/10 (regex miss; same caveat as S7) |
| S10 Rollback available | VERIFIED | 10/10 |

**Installed complete:** TRUE  
**Verified complete:** FALSE — requires manual live tests from `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_PROOF.md`

**Docs created:**
- `docs/SELF_IMPROVEMENT_VERIFICATION_PROTOCOL.md`
- `docs/SELF_IMPROVEMENT_SCORECARD.md`
- `docs/NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_PROOF.md`
- `outputs/self_improvement_verification_scorecard.json`

**Why:** Installed vs Verified distinction is critical — infrastructure can be 100% installed while behavioural improvement remains unproven. Stage 8 requires live before/after email tests to confirm RC-001 and RC-005 actually change draft wording and classification.

**How to apply:** Next session should run the 4 manual tests in `NEXT_MANUAL_TEST_PACKET_SELF_IMPROVEMENT_PROOF.md`, collect case_ids and observations, then re-run the suite with `-PreviewBeforeAfterImprovement -UseKnownCases -ExportScorecard` to advance to Verified Complete.
