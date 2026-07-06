# Instantly Responder — Fault Ledger and Scale Readiness

**Created:** 2026-07-06 (SL-PHASE-5Q session 15, Claude Code / Fable 5)
**Purpose:** Single evidence-backed ledger of every known fault class across the whole build, with honest status. No fault is marked fixed without a versionId, harness section, or live execution/case reference. Anything without evidence is marked accordingly.

**Status vocabulary:** `FIXED` (deployed + regression-covered), `PARTIALLY FIXED`, `OPEN`, `UNVERIFIED` (no fresh evidence either way), `GATED` (intentionally not active).

**Reference state at time of writing:**
- Decision `tgYmY97CG4Bm8snI` versionId `4474c96a-d48b-49af-abc9-d016e94ef5d8` (active)
- HumanApproval `9aPrt92jFhoYFxbs` versionId `0054f20b-2090-41e4-be76-95e8b71921de` (active)
- Shadow Evaluator `aHzLtQiv6G8h1bqD` inactive; Gate 2 unapproved; autonomous disabled; Sender untouched
- Harness `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`: 375/375 PASS

---

## 1. Setup / campaign readiness

| Item | Detail |
|---|---|
| Faults | Campaign/lead config drift vs `docs/VALIDATION_CAMPAIGN_CONFIG.md`; missing sender identity fields on inbound events |
| Status | UNVERIFIED (not re-checked this session) |
| Evidence | Exec 5263 (2026-07-05) showed valid campaign_id/lead/sender context arriving at Decision, so intake wiring worked at last observation |
| Affected | Intake workflow, Instantly campaign config |
| Regression coverage | None automated (config is external to repo) |
| Remaining risk | Medium — config drift is invisible to harness |
| Acceptance proof needed | Fresh seeded reply showing campaign_id, lead email, sender email, subject, body present end-to-end |

## 2. Credentials

| Item | Detail |
|---|---|
| Faults | (a) Missing `OPENAI_API_KEY` would silently disable AI drafting; (b) GitHub credentials unavailable in Codex shell blocked the 2026-07-05 checkpoint push |
| Status | (a) FIXED as a handled path — Node D emits `AI_PROVIDER_CONFIG_MISSING` fallback (non-fatal, truthful); (b) FIXED — checkpoint branch + tag confirmed on origin 2026-07-06 |
| Evidence | Node D `fallback_reason:'AI_PROVIDER_CONFIG_MISSING'` branch; `git ls-remote` shows branch `codex/5q-context-token-forensic-20260705` and tag `sl-phase-5q-largely-working-20260705` on origin |
| Regression coverage | Fallback path in P16; no automated credential-presence check |
| Remaining risk | Low — human review still gates every send |
| Acceptance proof needed | None beyond periodic env check |

## 3. Stale source / workflow exports

| Item | Detail |
|---|---|
| Faults | (a) Local Decision export was stale (e1b84f34 vs production 889e1d45, found 2026-07-04); (b) Node J was patched from a stale `9c71882f` base, regressing the modern review UI (repaired `849c2c64`); (c) at session-15 start, the afe08974 export + 349-test harness existed only as uncommitted working-tree changes |
| Status | FIXED for current state; the class remains a standing process risk |
| Evidence | OPERATION_HANDOFF 2026-07-04 entries; session-15 commit `dec5c2f` preserved the working tree; exports refreshed from production post-deploy and match `4474c96a`/`0054f20b` |
| Affected | `workflows/production_decision_current.json`, `workflows/production_humanapproval_current.json` |
| Regression coverage | P5.0/P17.1/P19 load the real exports; harness fails if patched markers are absent |
| Remaining risk | Medium — discipline-dependent; any session that edits production without refreshing exports reintroduces it |
| Acceptance proof needed | Post-deploy export refresh + commit in every deploying session (now standard) |

## 4. Intake / context preservation

| Item | Detail |
|---|---|
| Faults | Decision Node D JS syntax error (`_prParts.join('` + literal newline) compiled to an error-only item, dropping all valid upstream context; HumanApproval then fabricated a diagnostic identity (`DIAGNOSTIC_MISSING_INTAKE_...`) — case-68110963 |
| Status | FIXED |
| Evidence | Live-proven via executions 5263/5264/5265; Decision `9198554c → f6d5b731`; token was proven NOT the cause (`token_valid=true`) |
| Affected | Decision Node D; HumanApproval Node A/J diagnostic taxonomy |
| Regression coverage | P17 (8 tests) + literal-newline lexical guard (P17, re-asserted in P19.5/P19.25); session-15 tooling itself hit the same escape-stripping class and was caught by `node --check` before deploy |
| Remaining risk | Low-medium — any string patch to Code nodes can reintroduce it; guard + syntax check now standard |
| Acceptance proof needed | Already live-proven; keep syntax check mandatory pre-deploy |

## 5. Decision classification

| Item | Detail |
|---|---|
| Faults | (a) Booking walkthrough/demo requests misclassified OFFER_EXPLANATION (exec 4846); (b) pricing/minimum-commitment misclassified (exec 4865); (c) trust/proof variants stuck at AMBIGUOUS/NON_PRIORITY after owner correction — older rule 6e50fd54 hijacked variants (case-e6e99b67 → case-3a05c80c) |
| Status | FIXED (deterministic layers); AI-misclassification residue OPEN at low severity |
| Evidence | FIX-1/FIX-2 regex (`937488a9`); trust/proof priority + NON_PRIORITY promotion guard (`afe08974`) |
| Affected | Decision Section B classifier, Node D rule-eligibility |
| Regression coverage | P7 (12), P18 (23) |
| Remaining risk | Medium — deterministic regexes cover known phrasings only; unseen phrasings fall to AI classification which has misclassified before |
| Acceptance proof needed | Owner live retests: booking, pricing/commitment, not-now, trust variant (`Ah, I don't know if you are trustworthy.`) |

## 6. Decision drafting

| Item | Detail |
|---|---|
| Faults | (a) GAP-1 booking post-processor pasted rule-instruction sentences literally into drafts (case-7c87d21a); (b) GAP-2 pricing guidance had no consumer; (c) GAP-3 NON_PRIORITY had no template → null draft; (d) GAP-3b NOT_NOW style rule not consumed; (e) PROOF_REQUEST had no draft-policy entry → always HUMAN_ONLY; (f) PROOF_REQUEST fallback was null → empty textarea (case-9996084f); (g) PROOF_REQUEST fallback join syntax error (case-68110963) |
| Status | FIXED |
| Evidence | Decision `a3916c2e` (GAP-1/2/3), `937488a9` (GAP-3b), `84e6638e` (e), `9198554c` (f), `f6d5b731` (g) |
| Affected | Decision Node D |
| Regression coverage | P1-P3, P8, P12, P15, P16 |
| Remaining risk | Low for known classes; behavioural live proof of GAP-1/2/3 owner retests still outstanding |
| Acceptance proof needed | Owner Variant C live retests (booking, pricing, not-now, setup regression) |

## 7. HumanApproval review UI

| Item | Detail |
|---|---|
| Faults | (a) Node J syntax crash rendered UNKNOWN for every case (session 7); (b) stale-base regression removed modern learning fields (session on 849c2c64); (c) valid HUMAN_ONLY/ai_failed_fallback cases intercepted as diagnostic fallback (case-b0cfd04c); (d) submit/reopen blocked on valid fallback cases (case-13c3dad3); (e) display:none hid draft-reason fields (5M); (f) blocked-send validation override (4G) |
| Status | FIXED |
| Evidence | HumanApproval `c51ac1f3`, `849c2c64`, `ee2f160e`, `c20af72e`, `8a148c91`, `7f23d288` |
| Affected | HumanApproval Nodes A, J, N, Q, SL-P2A |
| Regression coverage | P5, P10, P11, P13, P14 |
| Remaining risk | Low; render is the most regression-prone surface — every Node J patch must re-run P5/P11/P19 |
| Acceptance proof needed | Owner confirmation of live form render after session-15 banner change (cosmetic-level risk) |

## 8. Self-improvement learning

| Item | Detail |
|---|---|
| Faults | (a) Owner-created style rule never eligible due to unresolvable scope (`requires_human_scope_decision`, case-532bae78); (b) form scope default caused (a); (c) learning capture skipped on ai_failed_fallback submits |
| Status | FIXED; end-to-end behavioural closure PARTIALLY VERIFIED |
| Evidence | Decision `0e1e1193` (scope fallback), HumanApproval `7aac637e` (default scope), `c20af72e` (capture); classification learning live-proven (rule `1dba7933`, cases d24661f0/3838bcee); full-loop proof recorded 2026-06-24 (SIP-FINAL 4/4) |
| Affected | Decision Node D `_5qPolicyApplies`; HumanApproval J/N/SL-P2A |
| Regression coverage | P15 (26), P14, P13 |
| Remaining risk | Medium — draft-style learning consumption is proven in harness + rule eligibility, but fresh live two-email proof after the session 14-15 changes is outstanding |
| Acceptance proof needed | Live: correction → follow-up variant consumes rule (classification) and style rule visibly shapes next draft |

## 9. Active learning attribution

| Item | Detail |
|---|---|
| Faults | (a) Applied-count 0 despite real learning (delta measured after AI generation but injection happens before); (b) multi-rule AI injection over-credited all eligible rules |
| Status | FIXED |
| Evidence | Decision `4cb34768`; `learning_attribution_uncertain` + `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN` semantics |
| Affected | Decision Node D attribution block |
| Regression coverage | P9 (29) |
| Remaining risk | Low — attribution is now conservative by design (prefers under-crediting) |
| Acceptance proof needed | Owner two-email test: 1 eligible rule → applied=1 via ai_prompt_injection |

## 10. AI validation / fallback (the session-15 blocker)

| Item | Detail |
|---|---|
| Fault (a) | Proof-mention predicate rejected safe honest drafts on PROOF_REQUEST when guidance contained "do not mention validation" — `asksProof` was false despite micro_intent |
| Status (a) | FIXED — live-proven false positive (execs 4976/4980, drafts were safe); Decision `9198554c`; P16 coverage |
| Fault (b) | Dense-paragraph style predicate rejected safe one-paragraph proof answers >360 chars. Globally-scoped style policy `27293ea8` ("short paragraphs") arms the check for ALL AI drafts, while the PROOF_REQUEST prompt demanded "One concise paragraph" — the prompt invited exactly what the validator rejected. Live-proven: exec 5329 rejected (≈386-char paragraph, content fully safe); execs 5286/5296 passed at shorter/multi-paragraph shape |
| Status (b) | FIXED session 15 — (1) prompt now asks for 2-3 short paragraphs; (2) style-only dense rejections repaired by whitespace-only sentence reflow, full validator re-runs, safety errors still hard-fail; (3) reflow recorded truthfully (`style_reflow_applied`, `raw_draft_text_before_reflow`). Decision `afe08974 → 4474c96a`; P19 (26 tests) incl. exec-5329 regression reproduction |
| Fault (c) | Negation-window gaps in FORBIDDEN_AI: `can't/cannot/won't/wouldn't/couldn't/didn't` are NOT in the negation exemption list, and negation AFTER the keyword is not exempted (e.g. "Case studies aren't something we have yet" would false-reject). Conversely, ANY negation word earlier in the sentence exempts a later positive claim (theoretical false-negative) |
| Status (c) | OPEN / UNVERIFIED frequency — no live occurrence observed; the prompt forbids these words outright so AI rarely emits them; every draft is still human-reviewed. Deliberately NOT patched (root cause of observed failures was (a)+(b); patching (c) blind would risk new behaviour without evidence) |
| Fault (d) | Reviewer-facing banner showed only `AI_OUTPUT_VALIDATION_FAILED`, reading as a safety failure even when rejection was style-only |
| Status (d) | FIXED session 15 — banner names exact failed check(s) and states when rejection was formatting/style only. HumanApproval `7aac637e → 0054f20b`; P19.19-21 |
| Acceptance proof needed | Owner sends fresh trust/proof reply → expect ai_supervised draft (possibly reflowed), or if fallback occurs, banner names the exact check |

## 11. Sender / idempotency

| Item | Detail |
|---|---|
| Faults | Token-refresh retry gap; proxy write repair; C2 connection bug (all SL-PHASE-4I) |
| Status | FIXED historically; UNVERIFIED recently (Sender intentionally untouched since; correct per standing rules) |
| Evidence | HumanApproval `27ef843a`, Proxy `47dbb8bd` (2026-06-23); retry harness 8/8; cases c0dd8298/7434572c/c9b32e56 SENT correctly (4H) |
| Regression coverage | Retry harness (4H/4I era); not re-run this session |
| Remaining risk | Medium at scale — idempotency proven at single-campaign, low-volume supervised use only |
| Acceptance proof needed | Before scale: duplicate-webhook replay test + uncertain-send reconciliation drill |

## 12. Threading / wrong sender / blank body

| Item | Detail |
|---|---|
| Faults | Historical: blank textarea (fixed via fault 10/6f); manual-test sends verified correct thread + sender in 4H |
| Status | FIXED at last observation; UNVERIFIED since 2026-06-23 live sends |
| Evidence | 4H manual test matrix (3 cases SENT, correct thread/sender) |
| Regression coverage | None automated (requires live send) |
| Remaining risk | Medium — untested against current Instantly API behaviour |
| Acceptance proof needed | Next owner-approved live send confirms thread, sender identity, non-blank body |

## 13. Runtime proof

| Item | Detail |
|---|---|
| Faults | Recurring gap: harness simulates logic in Python; JS-level and live-behaviour faults escaped it twice (Node J syntax crash; Node D join syntax error) |
| Status | PARTIALLY FIXED — `node --check` syntax validation + literal-newline lexical guard + static export checks now in harness; live behavioural verification still owner-dependent |
| Evidence | P11, P17, P19.5/P19.25; session 15 caught its own tooling-induced escape bug via `node --check` pre-deploy |
| Remaining risk | Medium — Python mirrors can drift from JS; live retest matrix outstanding for sessions 14-15 changes |
| Acceptance proof needed | Manual live test matrix (see OPERATION_HANDOFF session-15 entry) |

## 14. Autonomous

| Item | Detail |
|---|---|
| Faults | None active — layer is designed but disabled |
| Status | GATED (by design). Shadow Evaluator imported inactive; Gate 2 unapproved; 14-day shadow review NOT started (Day 1 never executed); allowlist worksheet unfilled |
| Evidence | Shadow `aHzLtQiv6G8h1bqD` active=false confirmed via API 2026-07-06; Gate 2 decision packet exists (Phase 5J) |
| Remaining risk | The 14-day shadow review clock has not started; autonomous timeline is entirely owner-driven |
| Acceptance proof needed | See SCALE_READY_ACCEPTANCE_GATES.md gates 3-4 |

## 15. Ops Console

| Item | Detail |
|---|---|
| Faults | Not built; no faults to record |
| Status | OPEN (not started; plan-only) |
| Remaining risk | None operational; absence of console means review flow depends on Google Chat links + n8n UI |
| Acceptance proof needed | N/A until Stage 1 is commissioned |

---

## False-positive risks found in this audit

1. **"Fallback = AI failure" was itself partly a false positive.** Execs 4976/4980/5329 all contained safe, honest, correctly-negated drafts. The system's safety posture was working; the validator's style/scope predicates were over-firing. Fixed in sessions 12 + 15.
2. **Banner over-alarm.** `AI_OUTPUT_VALIDATION_FAILED` implied unsafe output to the reviewer when the rejection was formatting-only. Fixed session 15 (banner detail).
3. **Residual false-positive surface (open, ledger item 10c):** negation-list gaps (`can't`/`won't`/`cannot`) and post-keyword negation. Not patched — no observed occurrence; do not patch without a live case.
4. **Residual false-negative surface (open, ledger item 10c):** any negation word early in a sentence exempts a later positive claim in the same sentence. Mitigated by the prompt-level word ban and mandatory human review. Watch for this in review; if observed live, tighten the window (proximity-based) rather than the word list.

## Highest-risk open faults (ranked)

1. **10(c)** — validator negation-window false-negative surface (safety-relevant but human-review-mitigated).
2. **11/12** — Sender idempotency + threading unverified at anything above single-campaign supervised volume.
3. **5** — unseen phrasings fall to AI classification, which has misclassified before.
4. **1/3** — config drift and stale-export process risks (discipline-dependent, not code-fixed).
