# Offline Scenario Harness Results — Phase 4B

Generated: 2026-06-23T14:55:11Z
Harness: scripts/SL-PHASE-4B-offline-commercial-scenario-harness.ps1
Production: NOT CALLED (offline only)
Node.js: v24.15.0

## Summary

| Result | Count |
|--------|-------|
| PASS   | 21 |
| FAIL   | 0 |
| TOTAL  | 21 |

## Scenario Results

| # | Scenario | Primary Micro Intent | Expected Secondary | Actual Secondary | Secondary | Expected Policy | Actual Policy | Policy | AI Allowed | Human-Only | Calendar | Autonomous Forbidden | Overall |
|---|----------|---------------------|-------------------|-----------------|-----------|----------------|--------------|--------|-----------|-----------|---------|---------------------|---------|
| 1 | Pricing + data + contract + small pilot  | PRICING_REQUEST | DATA_SECURITY_REQUEST+CONTRACT_TERMS_REQUEST+SMALL_SCALE_PILOT_REQUEST | DATA_SECURITY_REQUEST+CONTRACT_TERMS_REQUEST+SMALL_SCALE_PILOT_REQUEST | PASS | AI_COMMERCIAL_SUPERVISED | AI_COMMERCIAL_SUPERVISED | PASS | True | False | True | True | **PASS** |
| 2 | Small pilot only | SMALL_SCALE_PILOT_REQUEST |  |  | PASS | ai_supervised | ai_supervised | PASS | True | False | True | True | **PASS** |
| 3 | Pricing and included scope | PRICING_REQUEST | SCOPE_REQUEST | SCOPE_REQUEST | PASS | AI_COMMERCIAL_SUPERVISED | AI_COMMERCIAL_SUPERVISED | PASS | True | False | True | True | **PASS** |
| 4 | Data/privacy concern | DATA_SECURITY_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 5 | Contract concern | CONTRACT_TERMS_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 6 | Proof/case-study request | PROOF_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 7 | Angry/hostile complaint | HOSTILE_RESPONSE |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 8 | Unsubscribe | UNSUBSCRIBE_REQUEST |  |  | PASS | no_reply | no_reply | PASS | False | False | False | True | **PASS** |
| 9 | Security/compliance commitment request | COMPLIANCE_COMMITMENT_REQUEST | DATA_SECURITY_REQUEST | DATA_SECURITY_REQUEST | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 10 | General positive interest | HOW_IT_WORKS_REQUEST |  |  | PASS | ai_supervised | ai_supervised | PASS | True | False | True | True | **PASS** |
| 11 | Data/security only | DATA_SECURITY_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 12 | Contract only | CONTRACT_TERMS_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 13 | Pricing plus hostile objection | PRICING_REQUEST |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 14 | Pilot plus proof request | SMALL_SCALE_PILOT_REQUEST |  |  | PASS | ai_supervised | ai_supervised | PASS | True | False | True | True | **PASS** |
| 15 | Scope plus data request | SCOPE_REQUEST | DATA_SECURITY_REQUEST | DATA_SECURITY_REQUEST | PASS | ai_supervised | ai_supervised | PASS | True | False | False | True | **PASS** |
| 16 | Positive interest plus availability | HOW_IT_WORKS_REQUEST |  |  | PASS | ai_supervised | ai_supervised | PASS | True | False | True | True | **PASS** |
| 17 | Budget objection | BUDGET_CONCERN |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 18 | Competitor/comparison question | COMPETITOR_COMPARISON |  |  | PASS | ai_supervised | ai_supervised | PASS | True | False | True | True | **PASS** |
| 19 | GDPR/SOC2/contract inquiry — no unsubscr | DATA_PRIVACY_INQUIRY | DATA_SECURITY_REQUEST+CONTRACT_TERMS_REQUEST | DATA_SECURITY_REQUEST+CONTRACT_TERMS_REQUEST | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |
| 20 | Explicit unsubscribe — must not alias as | UNSUBSCRIBE_OR_COMPLAINT |  |  | PASS | no_reply | no_reply | PASS | False | False | False | True | **PASS** |
| 21 | Hostile/complaint — no unsubscribe reque | ANGRY_COMPLAINT |  |  | PASS | HUMAN_ONLY | HUMAN_ONLY | PASS | False | True | False | True | **PASS** |

## Safety Notes Per Scenario

- **S1 [PASS]** Pricing + data + contract + small pilot (multi-intent): Commercial safe; multi-intent; draft must be source-grounded; human must approve before send
- **S2 [PASS]** Small pilot only: Positive engagement; no pricing keyword as primary; AI draft supervised; human approves. SL-PHASE-4C: de-dup filter applied — SMALL_SCALE_PILOT_REQUEST no longer appears as secondary when it is the primary.
- **S3 [PASS]** Pricing and included scope: Commercial safe; SCOPE_REQUEST secondary; AI draft supervised; human must approve
- **S4 [PASS]** Data/privacy concern: Compliance/privacy topic; no AI draft; human drafts and approves; AI_COMMERCIAL_SUPERVISED upgrade does not apply (primary is not PRICING_REQUEST). SL-PHASE-4C: de-dup filter applied — DATA_SECURITY_REQUEST no longer appears as secondary when it is the primary.
- **S5 [PASS]** Contract concern: Legal/contract topic; no AI draft; human-only; upgrade rule does not apply (primary is not PRICING_REQUEST). SL-PHASE-4C: de-dup filter applied — CONTRACT_TERMS_REQUEST no longer appears as secondary when it is the primary.
- **S6 [PASS]** Proof/case-study request: No validated proof/case studies in approved KB; AI must not invent claims; human-only; do not fabricate results
- **S7 [PASS]** Angry/hostile complaint: Hostile flags set; isCommercialSafe=false; escalation required; no AI draft; no autonomous; careful human response only
- **S8 [PASS]** Unsubscribe: Immediate suppression; sequence stop; blocklist; no reply sent; isCommercialSafe=false; hardest safety gate
- **S9 [PASS]** Security/compliance commitment request: Compliance commitment; cannot auto-commit to SOC2/GDPR; 'gdpr' keyword in text triggers DATA_SECURITY_REQUEST as secondary (correct — confirms data sensitivity); human-only; escalate if formal questionnaire required
- **S10 [PASS]** General positive interest: Positive engagement; AI supervised draft fine; calendar link appropriate; human approves before send
- **S11 [PASS]** Data/security only: Data/privacy concern; HUMAN_ONLY; de-dup: DATA_SECURITY_REQUEST is primary so not in secondary; AI_COMMERCIAL_SUPERVISED does not apply
- **S12 [PASS]** Contract only: Contract/legal concern; HUMAN_ONLY; de-dup: CONTRACT_TERMS_REQUEST is primary so not in secondary
- **S13 [PASS]** Pricing plus hostile objection: Pricing + hostile flags; isCommercialSafe=false blocks AI_COMMERCIAL_SUPERVISED upgrade; HUMAN_ONLY with escalation; careful human response required
- **S14 [PASS]** Pilot plus proof request: Pilot request primary; SMALL_SCALE_PILOT_REQUEST de-duped out; examples/proof not in secondary keyword set; AI supervised draft; no pricing keywords so no commercial upgrade
- **S15 [PASS]** Scope plus data request: Scope primary (de-duped); data/privacy secondary detected ('our data'); AI supervised for scope; human must review data claim in draft carefully; no calendar needed for info-only reply
- **S16 [PASS]** Positive interest plus availability: Warm positive reply; no secondary intents; AI supervised draft appropriate; calendar booking link must be included; human approves before send
- **S17 [PASS]** Budget objection: Budget/cost objection; no pricing keywords to trigger PRICING_REQUEST secondary; HUMAN_ONLY; no AI draft; human should address objection; do not invent pricing options
- **S18 [PASS]** Competitor/comparison question: Competitor comparison; no secondary keywords; AI supervised draft OK; must not invent claims/results/proof; source-grounded draft only; human approves before send
- **S19 [PASS]** GDPR/SOC2/contract inquiry — no unsubscribe (MT-3 type): SL-PHASE-4E: GDPR/data/contract inquiry with no explicit unsubscribe; primary must be DATA_PRIVACY_INQUIRY not UNSUBSCRIBE_OR_COMPLAINT; DATA_SECURITY_REQUEST + CONTRACT_TERMS_REQUEST detected as secondary; policy HUMAN_ONLY; isCommercialSafe=false (det-legal-001); no DNC suppression; human reviews and responds
- **S20 [PASS]** Explicit unsubscribe — must not alias as GDPR: SL-PHASE-4E regression: explicit unsubscribe keywords must still trigger UNSUBSCRIBE_OR_COMPLAINT (not DATA_PRIVACY_INQUIRY); det-unsub-001 fires; immediate suppress/no_reply; no AI draft; no calendar; no autonomous
- **S21 [PASS]** Hostile/complaint — no unsubscribe request: SL-PHASE-4E: hostile complaint without explicit remove/unsubscribe request; primary must be ANGRY_COMPLAINT not UNSUBSCRIBE_OR_COMPLAINT; isCommercialSafe=false; HUMAN_ONLY; no calendar; careful human response; no autonomous

## Key Invariants Verified

- detectAllIntents() correctly identifies secondary intents from reply text
- isCommercialSafe() correctly blocks commercial upgrade when hostile/unsub/legal flags are set
- AI_COMMERCIAL_SUPERVISED upgrade fires ONLY when primary = PRICING_REQUEST + base = HUMAN_ONLY + no blocking flags
- DATA_SECURITY, CONTRACT_TERMS, PROOF_REQUEST, COMPLIANCE_COMMITMENT stay HUMAN_ONLY (no upgrade)
- UNSUBSCRIBE triggers immediate suppression (no_reply) — never upgraded
- HOSTILE responses never receive AI draft
- Calendar link appropriate only for positive/commercial engagement scenarios
- Autonomous sending is forbidden in ALL scenarios (VALIDATION mode)
- Human approval is required before any send in VALIDATION mode

## detectAllIntents Source

Functions detectAllIntents and isCommercialSafe are copied verbatim from
SL-PHASE-4A-multi-intent-ai-assisted-drafts.ps1 (the same code applied to production).
Any changes to those functions in production must be re-tested against this harness.

## Phase 4D Rule Simulation Scenarios (added 2026-06-23)

Simulates how approved active rules would influence supervised AI draft prompts.
Verifies: conflict detection blocks unsafe rules, HUMAN_ONLY stays HUMAN_ONLY, autonomous is forbidden.

| Id | Scenario | Case Policy | Conflict? | Violations | Would Inject? | Expect Inject? | Inject Match | HUMAN_ONLY Safe | Auto Forbidden | Overall |
|----|----------|-------------|-----------|------------|--------------|---------------|-------------|----------------|---------------|---------|
| RS-1 | Approved CTA rule — PRICING_REQUEST (safe, ai_comm | AI_COMMERCIAL_SUPERVISED | NO | none | YES | YES | PASS | PASS | PASS | **PASS** |
| RS-2 | Approved tone rule — SMALL_SCALE_PILOT_REQUEST (sa | ai_supervised | NO | none | YES | YES | PASS | PASS | PASS | **PASS** |
| RS-3 | Approved data/security caution rule — DATA_SECURIT | HUMAN_ONLY | NO | none | NO | NO | PASS | PASS | PASS | **PASS** |
| RS-4 | Unsafe rule — invents specific pricing (must be BL | AI_COMMERCIAL_SUPERVISED | YES | pricing_claim | NO | NO | PASS | PASS | PASS | **PASS** |
| RS-5 | Unsafe rule — invents fake case studies/results (m | ai_supervised | YES | pricing_claim,result_claim | NO | NO | PASS | PASS | PASS | **PASS** |
| RS-6 | Unsafe rule — attempts to allow autonomous sending | ai_supervised | YES | bypass_human | NO | NO | PASS | PASS | PASS | **PASS** |
| RS-7 | RC-001 approved — PROOF_REQUEST classification rul | ai_supervised | NO | none | YES | YES | PASS | PASS | PASS | **PASS** |
| RS-8 | RC-005 approved — PRICING_REQUEST classification r | AI_COMMERCIAL_SUPERVISED | NO | none | YES | YES | PASS | PASS | PASS | **PASS** |
| RS-9 | RC-003 rejected — HUMAN_ONLY must win regardless o | HUMAN_ONLY | NO | none | NO | NO | PASS | PASS | PASS | **PASS** |
| RS-10 | RC-006 unsafe — pricing + data + contract claims a | AI_COMMERCIAL_SUPERVISED | YES | pricing_claim,contract_commit | NO | NO | PASS | PASS | PASS | **PASS** |

### Rule Simulation Safety Notes

- **RS-1 [PASS]** Approved CTA rule — PRICING_REQUEST (safe, ai_commercial_supervised): Safe CTA-wording rule; no pricing numbers; no invented claims; correctly injected into AI_COMMERCIAL_SUPERVISED draft; human approval still required before send
- **RS-2 [PASS]** Approved tone rule — SMALL_SCALE_PILOT_REQUEST (safe, ai_supervised): Safe tone rule; validation framing only; no invented deliverables or pricing; correctly injected into ai_supervised draft; human approval still required before send
- **RS-3 [PASS]** Approved data/security caution rule — DATA_SECURITY_REQUEST (HUMAN_ONLY must stay HUMAN_ONLY): Rule itself is safe and passes conflict detection; BUT case policy is HUMAN_ONLY — injection is NOT permitted for HUMAN_ONLY cases regardless of rule safety; safety gate wins
- **RS-4 [PASS]** Unsafe rule — invents specific pricing (must be BLOCKED before injection): Contains specific pricing numbers — blocked by conflict detection; never reaches injection stage regardless of case policy; Rule 15 enforced
- **RS-5 [PASS]** Unsafe rule — invents fake case studies/results (must be BLOCKED): Contains invented case studies and results — blocked by conflict detection; AI must never fabricate proof; Rule 15 enforced
- **RS-6 [PASS]** Unsafe rule — attempts to allow autonomous sending (must be BLOCKED): Attempts to bypass human approval — blocked by conflict detection; autonomous sending is forbidden in VALIDATION mode; safety gate wins regardless of case policy
- **RS-7 [PASS]** RC-001 approved — PROOF_REQUEST classification rule (ai_supervised): RC-001: classification correction only; no pricing/results/guarantees; safe for ai_supervised injection; human approval required before send
- **RS-8 [PASS]** RC-005 approved — PRICING_REQUEST classification rule (AI_COMMERCIAL_SUPERVISED): RC-005: classification correction only; no pricing numbers or claims; safe for AI_COMMERCIAL_SUPERVISED injection; human approval required before send
- **RS-9 [PASS]** RC-003 rejected — HUMAN_ONLY must win regardless of category match: RC-003 rejected (pricing claim); even a passing rule must NOT inject into HUMAN_ONLY cases; HUMAN_ONLY gate wins unconditionally
- **RS-10 [PASS]** RC-006 unsafe — pricing + data + contract claims all blocked: RC-006 rejected: pricing + data_commit + contract_commit all present; conflict detection blocks on pricing_claim; three HUMAN_ONLY domains must never be AI-injected

### Rule Simulation Key Invariants

- Conflict detection blocks unsafe rules BEFORE they reach injection (pricing, results, bypass_human)
- HUMAN_ONLY cases never receive injected rules regardless of rule safety
- Only ai_supervised and AI_COMMERCIAL_SUPERVISED cases receive injection (when rule is safe)
- Autonomous sending is never enabled by any rule path
- Human approval is required before any send even with rules injected

## Phase 4E micro-intent + correction semantics (added 2026-06-23)

### Micro-intent regression (detectMicroIntent fix — Node B)

| Id | Description | Expected | Actual | Result |
|----|-------------|----------|--------|--------|
| MI-1 | GDPR/SOC2/contract inquiry — must NOT return UNSUBSCRIBE_OR_ | DATA_PRIVACY_INQUIRY | DATA_PRIVACY_INQUIRY | **PASS** |
| MI-2 | Explicit stop-emailing — must still return UNSUBSCRIBE_OR_CO | UNSUBSCRIBE_OR_COMPLAINT | UNSUBSCRIBE_OR_COMPLAINT | **PASS** |
| MI-3 | Legal threat (attorney/lawsuit) — must return LEGAL_COMPLAIN | LEGAL_COMPLAINT | LEGAL_COMPLAINT | **PASS** |
| MI-4 | Generic legal/privacy (no specific keyword) — must return LE | LEGAL_PRIVACY_INQUIRY | LEGAL_PRIVACY_INQUIRY | **PASS** |
| MI-5 | UNSUBSCRIBE category — always returns UNSUBSCRIBE_OR_COMPLAI | UNSUBSCRIBE_OR_COMPLAINT | UNSUBSCRIBE_OR_COMPLAINT | **PASS** |

Summary: PASS: 5/5

### Correction semantics regression (SL-P2A status logic — Phase 4F)

| Id | Description | Expected | Actual | Result |
|----|-------------|----------|--------|--------|
| CS-1 | Both blank + reason → remove_association_feedback (4F) | remove_association_feedback | remove_association_feedback | **PASS** |
| CS-2 | Corrected category only (non-blank, different) → captured_on | captured_only | captured_only | **PASS** |
| CS-3 | Both blank, no reason → no_change | no_change | no_change | **PASS** |
| CS-4 | Non-blank micro_intent, no category → captured_only | captured_only | captured_only | **PASS** |
| CS-5 | Blank category only + reason → remove_association_feedback | remove_association_feedback | remove_association_feedback | **PASS** |
| CS-6 | Blank micro_intent only + reason → remove_association_feedba | remove_association_feedback | remove_association_feedback | **PASS** |
| CS-7 | Blank both fields no reason → no_change (not removal) | no_change | no_change | **PASS** |
| CS-8 | Both non-blank and different + reason → captured_only | captured_only | captured_only | **PASS** |
| CS-9 | Blank both + reason (regression: does not blank live routing | remove_association_feedback | remove_association_feedback | **PASS** |

Summary: PASS: 9/9

## Phase 4F additions (2026-06-23)

### Additional intents comparison (AI-1 to AI-5)

| Id | Description | Added | Removed | Result |
|----|-------------|-------|---------|--------|
| AI-1 | Submitted = original → no added, no removed |  |  | **PASS** |
| AI-2 | Add new intent → added=[NEW], removed=[] | CONTRACT_TERMS_REQUEST |  | **PASS** |
| AI-3 | Remove a prefilled intent → added=[], removed=[old] |  | CONTRACT_TERMS_REQUEST | **PASS** |
| AI-4 | Replace all → added=[NEW], removed=[old] | PROOF_OR_CASE_STUDY_REQUEST | DATA_SECURITY_REQUEST | **PASS** |
| AI-5 | Empty submitted (reviewer cleared all) → removed=[all], |  | DATA_SECURITY_REQUEST,CONTRACT_TERMS_REQUEST | **PASS** |

Summary: PASS: 5/5

### Calendar link fix regression (CL-1 to CL-5)

| Id | Description | ContainsOk | NotContOk | Result |
|----|-------------|------------|-----------|--------|
| CL-1 | bookingLink null → AI <<bookingLink>> resolves to hardc | True | True | **PASS** |
| CL-2 | bookingLink null → "book time here: " CTA fixed by broa | True | True | **PASS** |
| CL-3 | bookingLink provided → uses provided link, no hardcoded | True | True | **PASS** |
| CL-4 | No booking CTA in draft → no booking link injected | True | True | **PASS** |
| CL-5 | Draft must not contain empty CTA pattern "book here: ." | True | True | **PASS** |

Summary: PASS: 5/5

## Phase 4G additions (2026-06-23)

### Review retry + classification edit regression (RG-1 to RG-10)

| Id | Description | Actual | Result |
|----|-------------|--------|--------|
| RG-1 | addl classification section blank when no detected intents | True | **PASS** |
| RG-2 | addl classification section prefilled when detected intents exist | True | **PASS** |
| RG-3 | addl intents correction box is inside optional correction section | True | **PASS** |
| RG-4 | blank corrected_micro_intent + reason → remove_association_feedba | True | **PASS** |
| RG-5 | blank corrected_broad_category + reason → remove_association_feed | True | **PASS** |
| RG-6 | additional intent removed → additional_intent_removal_feedback ru | True | **PASS** |
| RG-7 | additional intent added → additional_intent_addition_feedback rul | True | **PASS** |
| RG-8 | empty addl intents field + no original intents → no destructive f | True | **PASS** |
| RG-9 | ai_failed_fallback blocked send shows SEND_BLOCKED_RETRYABLE stat | True | **PASS** |
| RG-10 | human_approved override sets validation.valid=true (recoverable b | True | **PASS** |

Summary: PASS: 10/10

