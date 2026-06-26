# Phase 3 Validation Report

Date: 2026-06-11, updated 2026-06-12 (Phase 3.1A surgical repairs). Scope: build the Reply Intake and Reply Decision Engine workflows in the isolated local n8n development instance (`http://127.0.0.1:5678`, container `hmz-n8n-local-dev`, n8n `2.25.7`), validate them, and run safe local synthetic tests against 16 fixtures/checks. Per the Phase 3 spec: no sender, SLA watchdog, error workflow, or complete Phase 4 test harness was built; no Instantly, AI provider, email, Slack, Google Sheets, or Supabase configuration/calls were made; neither workflow was activated.

**Phase 3.1A update (2026-06-12)**: four nodes were added to Workflow 1 (`B1`/`B2` config-gate router/rejection, `E4`/`E5` duplicate-event router/terminal), Workflow 1 Section E1's idempotency-key scheme was extended (`full_identity` / `identifier_poor_hash`), Workflow 1 Section D's `validation_learning` was renamed to `validation_learning_seed`, and Workflow 2 Section E now validates and exposes a single authoritative top-level `validation_learning`. See `docs/PHASE_3_SURGICAL_REPAIR_CHANGELOG.md` for the full repair-by-repair record and final Phase 3.1A verdict. The figures below reflect the post-Phase-3.1A state of both workflows.

---

## 1. Workflows built

| Workflow | ID | Nodes (logical / sticky / total) | Active | versionCounter | versionId |
| --- | --- | --- | --- | --- | --- |
| `HMZ - Instantly Reply Intake - Validation` | `cCcpFfi6iovWS94T` | 14 / 8 / 22 | `false` (`activeVersionId: null`) | 7 | `c885c7c9-11d5-48b2-a5fd-56c353642401` |
| `HMZ - Reply Decision Engine - Validation` | `NJcnNQoJ5nSIWYte` | 6 / 6 / 12 | `false` (`activeVersionId: null`) | 8 | `758b9928-2c10-48de-a7e7-2c34a8ef6fc9` |

Full node lists, configuration constants, and Data Table details are in `docs/PHASE_3_CONFIGURATION_REFERENCE.md`.

---

## 2. Mocked / provider-neutral boundaries (exact)

- **Instantly**: zero Instantly nodes, zero `httpRequest` nodes anywhere in either workflow. The intake trigger is a dev-only synthetic webhook (`hmz-validation-reply-intake-dev`) that accepts a hand-shaped JSON body resembling a future Instantly `reply_received`/`auto_reply_received` event. `decision.external_action_status` is always `NOT_PERFORMED` or `NOOP` (never `COMPLETED`/`SUCCESS`). All suppression/stop-sequence/blocklist/escalation/send-reply actions are represented purely as structured decision fields (`stop_active_sequence`, `pause_active_sequence`, `durable_dnc_intent`, `address_suppression_intent`, `reply_permitted`, `reply_template_id`, `reply_draft_status`, etc.) — none of these fields trigger any call.
- **AI / semantic classifier**: Workflow 2 Section B (`B. Mock Semantic Classifier`) is a deterministic, rule-based JavaScript mock with a documented provider-neutral interface (normalized reply, thread-context placeholder, validation-cell context, KB excerpt/identifier, campaign message variant, deterministic flags in -> category/confidence/evidence/detected_questions/requested_action/risk_flags/permitted_automation_action/validation_learning/interest_stage out). No model API is called.
- **Draft preparation**: Workflow 2 Section D (`D. Mock Draft Preparation`) returns only `template_id`, a placeholder-populated `draft_text` (or `null` with an explanatory note if the template has no registry entry or required variables are missing), `human_review_required`, and `missing_variables[]`. Nothing is transmitted. Missing `{{firstName}}`/`{{senderName}}`/`{{bookingLink}}` use the approved fallback behaviour, never invented values.
- **Persistence**: Workflow 1 Section E2 uses n8n's built-in **Data Table** node (`hmz_validation_reply_intake_idempotency`, ID `xUlD0Zhoek6mU5I2`) — a local, non-paid, dev-safe storage adapter, as required.
- **Email / Slack / Google Sheets / Supabase**: not referenced anywhere — no nodes of these types exist in either export.

---

## 3. Validation requirements (1-13 from the Phase 3 spec)

| # | Requirement | Result |
| --- | --- | --- |
| 1 | Validate each configured node | Done. Each Code/Webhook/Data Table/Execute-Sub-workflow node was validated during construction (`validate_node`, prior sessions). The one node modified this session (Section F) was re-validated as part of `n8n_validate_workflow` (`validateNodes: true` by default) — see #2. |
| 2 | Validate both complete workflows | **Workflow 1**: `n8n_validate_workflow(cCcpFfi6iovWS94T)` -> `valid: true, errorCount: 0, warningCount: 14, totalNodes: 14, enabledNodes: 14, triggerNodes: 1, validConnections: 13, invalidConnections: 0`. **Workflow 2**: `n8n_validate_workflow(NJcnNQoJ5nSIWYte)` -> `valid: true, errorCount: 0, warningCount: 6, totalNodes: 6, enabledNodes: 6, triggerNodes: 1, validConnections: 5, invalidConnections: 0`. |
| 3 | Retrieve both workflows from n8n | Done this session: `n8n_get_workflow(cCcpFfi6iovWS94T, mode=structure)` (post Phase 3.1A repairs) and `n8n_get_workflow(..., mode=minimal)` for both workflows. |
| 4 | Confirm both are inactive | **Confirmed**. `n8n_get_workflow(mode=minimal)` for both: `active: false, isArchived: false, activeVersionId: null`. Workflow 1 `updatedAt: "2026-06-12T02:19:40.611Z"` (versionCounter 7); Workflow 2 `updatedAt: "2026-06-12T02:24:05.404Z"` (versionCounter 8) - both reconfirmed this session, and both local exports' `updatedAt`/`versionId`/`versionCounter` match exactly (no re-export needed). |
| 5 | Confirm neither contains credentials | **Confirmed**. Repository-export check: `nodes.filter(n => n.credentials)` returns 0 nodes for both `workflows/01_reply_intake_validation.json` (22 nodes) and `workflows/02_reply_decision_engine_validation.json` (12 nodes). |
| 6 | Confirm neither calls an external service | **Confirmed**. Node types present, both workflows combined: `stickyNote`, `webhook` (dev-only intake), `code`, `dataTable` (local n8n table), `executeWorkflow` / `executeWorkflowTrigger` (n8n-to-n8n only). No `httpRequest`, no Instantly/AI/email/Slack/Sheets/Supabase node type anywhere. |
| 7 | Confirm no workflow can send email | **Confirmed**. No email-sending node type (`emailSend`, SMTP, Gmail, etc.) exists in either workflow. |
| 8 | Confirm no workflow can modify Instantly | **Confirmed**. No Instantly node or `httpRequest` node exists. `decision.external_action_status` is `NOT_PERFORMED`/`NOOP` for all 12 fixtures (verified empirically — section 5 below). |
| 9 | Confirm dry-run and empty live-campaign controls exist | **Confirmed**. Workflow 1 Section B's `CONFIG` constant: `operating_mode: 'VALIDATION'`, `dry_run: true`, `live_campaigns: []`, `transmission_disabled: true`, `external_actions_mocked: true`. `config_gate.{passed, dry_run_ok, live_campaign_claim_detected, reasons[]}` is computed per item, and (Phase 3.1A Repair 1) `B1. Configuration Gate Router` now routes `config_gate.passed=false` items to `B2. Configuration Gate Rejection (Terminal)` (`terminal_status=REJECTED`, `processing_halted=true`, `external_action_status=NOOP`) instead of continuing to Section C. Exercised by `fixtures/phase_3/14_live_campaign_claim_config_gate_rejection.json` (`raw_payload.live_campaign=true`). Resolves `reports/UNRESOLVED_ITEMS.md` U2. |
| 10 | Run safe local synthetic tests where possible without activation/external calls | **Done**. `fixtures/phase_3/run_synthetic_tests.js` (pure Node.js, no n8n/Instantly/AI calls, no activation) chains all sections of both workflows against all 15 fixtures, following the Phase 3.1A branching (`A->B->B1->{C/B2}`, then for the true branch `C->D->E1->[simulated E2]->E3->E4->{F/E5}`, then for E4's true branch Workflow 2 `A->B->C->D->E`), plus 1 cross-check confirming fixtures 11 and 13 (two distinct malformed payloads) get distinct `idempotency_key` values. Result: **16/16 PASS**. |
| 11 | Distinguish validator warnings from blocking defects | **Done**. 0 `errorCount` on both workflows. Workflow 1's 14 warnings = 9 generic "Code nodes can throw errors" (one per Code node, including new terminals B2/E5) + 1 "Webhooks should always send a response, even on error" + 1 "Long linear chain detected" (workflow-level) + 1 "Invalid $ usage detected" on Section D (false positive, `reports/UNRESOLVED_ITEMS.md` U5) + 2 "Node has error output connections in main[1] but missing onError: 'continueErrorOutput'" on the new IF nodes B1/E4 (false positive, `reports/UNRESOLVED_ITEMS.md` U6 — an IF node's intrinsic `true`/`false` outputs are both ordinary `main`-type branches per its schema, not error outputs). Workflow 2's 6 warnings are all the same generic class. None are blocking. |
| 12 | Repair all confirmed blocking defects | **Done**. One confirmed defect was found during the original Phase 3 synthetic testing: Workflow 1 Section F's `OOO_PATTERN` regex did not match "out of **the** office" (`reports/UNRESOLVED_ITEMS.md` U4, RESOLVED). No other confirmed blocking defects exist. Separately, Phase 3.1A completed two previously-deferred non-blocking (KNOWN LIMITATION) items as architectural repairs: U2 (`config_gate.passed=false` routing, Repair 1) and U3 (malformed-payload idempotency-key collision, Repair 2) — both now RESOLVED. |
| 13 | Do not misrepresent unexecuted branches as tested | See section 6 ("Untested behaviour") below for an explicit list of paths the 12 fixtures do **not** exercise. |

---

## 4. Synthetic test results (`fixtures/phase_3/run_synthetic_tests.js`, 16/16 PASS)

| Fixture | Category (expected) | Terminal status | Human review required |
| --- | --- | --- | --- |
| `phase3_01_positive_interest_no_scheduling` | `POSITIVE_INTEREST` | `REVIEW_HOLD` | `true` |
| `phase3_02_information_request` | `INFORMATION_REQUEST` | `REVIEW_HOLD` | `true` |
| `phase3_03_explicit_booking_request` | `BOOKING_REQUEST` | `REVIEW_HOLD` | `true` |
| `phase3_04_unsubscribe` | `UNSUBSCRIBE` | `REVIEW_HOLD` | `true` |
| `phase3_05_out_of_office` | `OUT_OF_OFFICE` | `COMPLETED_NO_SEND` | `false` |
| `phase3_06_bounce` | `BOUNCE_OR_DELIVERY_NOTICE` | `COMPLETED_NO_SEND` | `false` |
| `phase3_07_pricing_question` | `PRICING_OR_COMMERCIAL_NEGOTIATION` | `REVIEW_HOLD` | `true` |
| `phase3_08_legal_privacy_complaint` | `LEGAL_PRIVACY_OR_COMPLAINT` | `REVIEW_HOLD` | `true` |
| `phase3_09_ambiguous_one_word_reply` | `AMBIGUOUS` | `REVIEW_HOLD` | `true` |
| `phase3_10_duplicate_event` | `POSITIVE_INTEREST` (1st) / n/a (2nd, terminal at E5, Workflow 2 not run) | `REVIEW_HOLD` / `COMPLETED_NO_SEND` | `true` / n/a (decision absent on 2nd) |
| `phase3_11_malformed_payload` | `OTHER` (`op-malformed`) | `REJECTED` | `true` |
| `phase3_12_specialised_agency_cell_reply` | `POSITIVE_INTEREST` (`CELL_3_SPECIALISED_B2B_AGENCY`) | `REVIEW_HOLD` | `true` |
| `phase3_13_distinct_malformed_payload` | `OTHER` (`op-malformed`) | `REJECTED` | `true` |
| `phase3_14_live_campaign_claim_config_gate_rejection` | n/a (terminal at B2, before Workflow 2 / Section C) | `REJECTED` | n/a (decision absent) |
| `phase3_15_invalid_validation_learning_tristate` | `POSITIVE_INTEREST` (injected invalid `classifier.validation_learning.pricing_interest='MAYBE'`) | `REVIEW_HOLD` (overridden by Section E, `validation.valid=false`) | `true` |
| cross-check: fixtures 11 vs 13 `idempotency_key` | n/a | n/a | n/a — confirms the two `identifier_poor_hash` keys are distinct strings |

Every fixture's `expected` block (category, deterministic match/rule_id, classifier output, decision action plan, draft, `validation_learning`, `validation.valid`) was checked via `checkResultAgainstExpected`/`checkPartial` — see `fixtures/phase_3/run_synthetic_tests.js`. Output: `16 passed, 0 failed, 16 total`.

No fixture has `reply_permitted=true` AND `terminal_status` other than `REVIEW_HOLD`/`REJECTED`/`COMPLETED_NO_SEND` — i.e. no fixture represents a completed send. No fixture sets `external_action_status` to anything other than `NOT_PERFORMED` or `NOOP`.

---

## 5. Untested behaviour (per requirement 13 — explicit, not implied)

The 16 fixtures/checks and `run_synthetic_tests.js` exercise the **Code-node logic** of both workflows (plus the B1/E4 IF-node conditions, reproduced directly as helper functions) by extracting and chaining `jsCode` bodies directly in Node.js. The following were **not** executed and are **not** claimed as tested:

- **Real n8n execution of either workflow** — neither workflow has been run inside n8n itself (no "Test workflow" execution, no webhook delivery). The webhook (`n8n-nodes-base.webhook`), Data Table (`n8n-nodes-base.dataTable`, Section E2), IF nodes (`n8n-nodes-base.if`, Sections B1/E4), and Execute Sub-workflow (`n8n-nodes-base.executeWorkflow`/`executeWorkflowTrigger`, Section G / Workflow 2 trigger) **node behaviours themselves** are untested — only the surrounding Code-node logic and reproduced IF conditions that consume/produce their expected shapes.
- **The real n8n Data Table `upsert` row shape** (`createdAt`/`updatedAt` presence and behaviour) — E2 is simulated in-memory in the test harness. `reports/UNRESOLVED_ITEMS.md` U1.
- **Deterministic rules not hit by any fixture**: `det-legal-002`, `det-regulator-001`, `det-hostile-001`, `det-hostile-002`, `det-media-001` (media flag), `det-attach-001`, `det-referral-001`, `det-wrong-001`, `op-self-sent`, `op-unsupported-event`, `op-empty-reply`. These exist in Workflow 2 Section A's rule chain (`docs/PHASE_3_CONFIGURATION_REFERENCE.md` §3.1) and were code-reviewed during construction, but no fixture's `expected.deterministic.rule_id` confirms their runtime behaviour empirically.
- **`TEMPLATE_REGISTRY` entries not selected by any fixture's `reply_template_id`**: e.g. `T1_SCENARIO_A_OPEN_TO_CALL` (only `T1_SCENARIO_C_UNCLEAR_INTEREST` is hit by fixtures 1/10/12).
- **Campaign/validation-cell mismatch** (`prefilter.is_campaign_cell_mismatch`) — all 12 fixtures use a `validation_cell` consistent with their `campaign_id`; the mismatch path is implemented but not exercised by a fixture.

None of the above are claimed as PASS/tested. They are recorded here so Phase 4 can target them explicitly.

---

## Final Report (15 points)

1. **Workflows created**: two, both new this build series — `HMZ - Instantly Reply Intake - Validation` and `HMZ - Reply Decision Engine - Validation`.
2. **Workflow IDs**: `cCcpFfi6iovWS94T` (Reply Intake), `NJcnNQoJ5nSIWYte` (Reply Decision Engine).
3. **Node counts**: Workflow 1 — 22 total (14 logical: 1 webhook, 9 Code [`A`, `B`, `C`, `D`, `E1`, `E3`, `F`, `B2`, `E5`], 1 Data Table [`E2`], 2 IF [`B1`, `E4`], 1 Execute Sub-workflow [`G`]; 8 sticky notes). Workflow 2 — 12 total (6 logical: 1 Execute-Sub-workflow Trigger, 5 Code; 6 sticky notes) — unchanged by Phase 3.1A.
4. **Exact mocked boundaries**: see section 2 above — no Instantly/AI/email/Slack/Sheets/Supabase nodes or calls anywhere; classifier and drafting are deterministic JS mocks; persistence is n8n's local Data Table; all external-effect fields are structured intents (`NOT_PERFORMED`/`NOOP`) only.
5. **Validations performed**: per-node validation during construction (prior sessions) + per-node validation of the four Phase 3.1A additions (`B1`, `B2`, `E4`, `E5`) and the edited nodes (Workflow 1 Section E1, Section D; Workflow 2 Sections B and E) during this session + `n8n_validate_workflow` on both workflows (Workflow 1 post-Phase-3.1A: `valid: true, errorCount: 0, warningCount: 14, totalNodes: 14, enabledNodes: 14, triggerNodes: 1, validConnections: 13, invalidConnections: 0`; Workflow 2: `valid: true, errorCount: 0, warningCount: 6, totalNodes: 6, enabledNodes: 6, triggerNodes: 1, validConnections: 5, invalidConnections: 0`) + `n8n_get_workflow` retrieval (`mode=structure`/`minimal`) confirming structure (22/12 total nodes), inactivity (`active: false, isArchived: false, activeVersionId: null`), and absence of credentials for both. Workflow 1 is at versionCounter 7 (`versionId c885c7c9-11d5-48b2-a5fd-56c353642401`, `updatedAt 2026-06-12T02:19:40.611Z`); Workflow 2 is at versionCounter 8 (`versionId 758b9928-2c10-48de-a7e7-2c34a8ef6fc9`, `updatedAt 2026-06-12T02:24:05.404Z`).
6. **Synthetic tests performed**: `fixtures/phase_3/run_synthetic_tests.js` against all 15 `fixtures/phase_3/*.json` fixtures plus 1 cross-check, chaining Workflow 1's Phase 3.1A branching (`A->B->B1->{C / B2 (terminal)}`, then for the `C` branch `C->D->E1->[simulated E2]->E3->E4->{F / E5 (terminal)}`) and, for `F`'s output, Workflow 2 sections `A->B->C->D->E`, in n8n's execution order, with an in-memory Data Table simulation for idempotency and the B1/E4 IF conditions reproduced as helper functions (`configGatePassed`, `eventIsNotDuplicate`).
7. **Tests passed**: **16 / 16** (`16 passed, 0 failed, 16 total`).
8. **Warnings**: Workflow 1 — 14 total: 9 generic "Code nodes can throw errors — consider adding error handling" (one per Code node, including the new terminals `B2`/`E5`) + 1 "Webhooks should always send a response, even on error" (workflow-level) + 1 "Long linear chain detected — consider breaking into sub-workflows" (workflow-level) + 1 "Invalid $ usage detected" on Section D (false positive, `reports/UNRESOLVED_ITEMS.md` U5) + 2 "Node has error output connections in main[1] but missing onError: 'continueErrorOutput'" on the new IF nodes `B1`/`E4` (false positive, `reports/UNRESOLVED_ITEMS.md` U6 — an IF node's intrinsic `true`/`false` outputs are both ordinary `main`-type branches per its schema, not error outputs; confirmed via `get_node('nodes-base.if', detail=full)` and the live connection structure). Workflow 2 — 6, all the same generic "Code nodes can throw errors" class, unchanged by Phase 3.1A. `errorCount: 0` for both.
9. **Confirmed defects repaired**: 1 — Workflow 1 Section F `OOO_PATTERN` regex did not match "out of **the** office"; fixed, re-validated, re-exported (`reports/UNRESOLVED_ITEMS.md` U4, resolved in the original Phase 3 build). Separately, Phase 3.1A completed two previously-deferred architectural items (not defects in the strict sense, but documented gaps) as surgical repairs: U2 (`config_gate.passed=false` now routes to a terminal `B2` rejection — Repair 1) and U3 (malformed payloads now get a collision-resistant `identifier_poor_hash` idempotency key — Repair 2). Both are now RESOLVED; see `docs/PHASE_3_SURGICAL_REPAIR_CHANGELOG.md`.
10. **Untested behaviour**: see section 5 above (real n8n/webhook/Data-Table/IF-node/sub-workflow execution; real Data Table `upsert` row shape; 11 deterministic rules and several template-registry entries not hit by any fixture; campaign/cell-mismatch path).
11. **Unresolved Instantly dependencies**: unchanged from `docs/ASSUMPTIONS_AND_UNKNOWNS.md` — A3 (Instantly API key/plan tier, BLOCKED for live action), B3 (`reply_to_uuid` source, BLOCKED), B6-B9 (suppression/sequence-stop/blocklist/reconciliation request bodies, BLOCKED), B4/B5/B10/B11 (PROVISIONAL/not required for MVP). None of these block Phase 3 (no Instantly call exists in either workflow); all remain required before any live send/suppression/reconciliation.
12. **Unresolved owner decisions**: the 9 items in `docs/ASSUMPTIONS_AND_UNKNOWNS.md` section D (test campaign, operating-mode confirmation, KB/template approval, review destination, storage choice, escalation owners, sender-name/booking-link mappings, Instantly plan/key, legal/compliance review). The two Phase-3-specific items previously listed here (U2, U3) were resolved this session via Phase 3.1A Repairs 1 and 2 and no longer require an owner decision. U6 (IF-node `onError` warning) is a documented false positive and does not require an owner decision either.
13. **Proof both workflows are inactive**: `n8n_get_workflow(cCcpFfi6iovWS94T, mode=minimal)` -> `active: false, isArchived: false, activeVersionId: null, updatedAt: "2026-06-12T02:19:40.611Z", versionCounter: 7`; `n8n_get_workflow(NJcnNQoJ5nSIWYte, mode=minimal)` -> `active: false, isArchived: false, activeVersionId: null, updatedAt: "2026-06-12T02:24:05.404Z", versionCounter: 8`. Both reconfirmed this session, after the Phase 3.1A edits.
14. **Proof no credentials or external calls exist**: repo-export check on both `workflows/*.json` — `nodes.filter(n => n.credentials).length === 0` for both (22 and 12 nodes respectively, matching the live n8n exports exactly). Combined node-type inventory across both workflows contains only `stickyNote`, `webhook`, `code`, `dataTable`, `if`, `executeWorkflow`, `executeWorkflowTrigger` — no `httpRequest` or any vendor-specific (Instantly/OpenAI/Anthropic/SMTP/Slack/Google Sheets/Supabase) node type.
15. **Readiness verdict**: **`PHASE 3.1A COMPLETE WITH NON-BLOCKING WARNINGS`**

   Rationale: both workflows validate with `errorCount: 0`; the one confirmed blocking-class defect found during original Phase 3 testing (U4, OOO regex) remains repaired and re-verified; all 16 synthetic fixtures/checks pass end-to-end, including the three new Phase 3.1A fixtures (14: config-gate rejection; 15: invalid tri-state validation_learning; 13: distinct malformed-payload cross-check vs. 11); both workflows are confirmed inactive (`activeVersionId: null`) with no credentials and no external-service node types, at versionCounter 7 (Workflow 1) and 8 (Workflow 2). The "non-blocking warnings" qualifier reflects: 20 total validator warnings across both workflows (all non-blocking; two investigated as false positives — U5 and the new U6); and the PROVISIONAL idempotency duplicate-detection mechanism (U1, logically sound and synthetically confirmed for both `full_identity` and `identifier_poor_hash` key schemes, but not yet confirmed against the real n8n Data Table). U2 and U3, previously KNOWN LIMITATION items, are now RESOLVED by this phase's repairs. Full repair-by-repair detail and rationale are in `docs/PHASE_3_SURGICAL_REPAIR_CHANGELOG.md`.

**Phase 3.1B and Phase 4 have not begun.**

---
## Phase 3.1B/3.1C Final-Verification Addendum (2026-06-12)

U1 -> **VERIFIED**: `reports/PHASE_3_DATATABLE_BEHAVIOUR_EXPERIMENT.md` confirms the real
Data Table `upsert` returns `id`/`createdAt`/`updatedAt`; `createdAt` is preserved and
`updatedAt` advances on repeat upsert — E3's `is_duplicate` check is correct as-is.

Runtime acceptance (`PHASE_3_RUNTIME_ACCEPTANCE_LOG.md`, `PHASE_3_SUBWORKFLOW_HANDOFF_RUNTIME_TEST.md`,
n8n `2.25.7`, both workflows re-deactivated after each run): 3.1B3C real sub-workflow
handoff; 3.1C1 config-gate rejection (`B1`/`B2` -> REJECTED, NOOP); 3.1C2 duplicate
termination (`E4`/`E5` -> COMPLETED_NO_SEND, NOOP); 3.1C3 unsubscribe/DNC (REVIEW_HOLD,
draft blocked); 3.1C4 T1/T3 classification; 3.1C5 malformed payload
(`identifier_poor_hash`, REJECTED) — all verified.

Technical closure (`PHASE_3_TECHNICAL_CLOSURE.md`, 3.1C6A): 16/16 fixtures pass; both
workflows `valid:true, errorCount:0, active:false`; Data Table empty; export alignment
confirmed (Intake versionId churn = activate/deactivate cycles only, content
byte-identical); no credentials/external-service nodes.

**Final verdict: PHASE 3 VERIFIED COMPLETE.**
