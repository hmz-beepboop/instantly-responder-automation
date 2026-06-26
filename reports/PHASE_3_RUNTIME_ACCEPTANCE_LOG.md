# Phase 3.1C1 — Runtime Configuration Gate Rejection (dry_run=false)
Date: 2026-06-12. Fixture-01-shaped payload + `dry_run:false`, intake_id
`phase3-1c1-dryrun-false-config-gate`. 6 MCP calls used (limit 8).
- Activated Decision Engine (`NJcnNQoJ5nSIWYte`) then Intake (`cCcpFfi6iovWS94T`).
- POST `http://127.0.0.1:5678/webhook/hmz-validation-reply-intake-dev` -> `{"message":"Workflow was started"}`.
- Intake execution `3`: status `success`, finished `true`, mode `webhook`.
- Executed: Webhook, A. Normalization, B. Configuration Gate, B1. Router, B2. Rejection (Terminal).
- Skipped: C-G (Payload Validation, NES normalization, Data Table/idempotency, prefilter, Decision Engine).
- `config_gate`: `passed=false`, `dry_run_ok=true`, reasons=["raw_payload.dry_run is explicitly false"].
- `terminal_status=REJECTED`, `processing_halted=true`, `external_action_status=NOOP`.
- Cleanup: Intake -> `active:false`, Decision Engine -> `active:false` (both confirmed via responses).

**Verdict: CONFIGURATION GATE VERIFIED**

# Phase 3.1C2 — Duplicate Termination (same intake_id, 2nd submission)
Date: 2026-06-12. Fixture `phase3_01_positive_interest_no_scheduling`. 8 MCP calls (limit 9).
Pre-cleanup removed a leftover Data Table row; activated Decision Engine then Intake.
Exec `4` (1st POST): is_duplicate=false, Decision Engine invoked (`NJcnNQoJ5nSIWYte`), category `POSITIVE_INTEREST`, terminal_status `REVIEW_HOLD`.
Exec `6` (2nd POST, identical payload): is_duplicate=true, Decision Engine skipped (`E5. Duplicate Event Terminal`), terminal_status `COMPLETED_NO_SEND`, external_action_status `NOOP`, stop_active_sequence=false.
Cleanup: Intake -> active:false, Decision Engine -> active:false (confirmed via responses); Data Table row deleted.

**Verdict: DUPLICATE TERMINATION VERIFIED**

# Phase 3.1C3 — Unsubscribe / DNC Intent (unique valid reply)
Date: 2026-06-12. Fixture-04-shaped payload ("Please unsubscribe me and do not contact me again."), intake_id `phase3-1c3-unsubscribe-unique`. 7 MCP calls used (limit 8).
Activated Decision Engine (`NJcnNQoJ5nSIWYte`) then Intake (`cCcpFfi6iovWS94T`); Intake execution `7`: status `success`, finished `true`, mode `webhook`, is_duplicate=false.
`category=UNSUBSCRIBE` (det-unsub-001), `stop_active_sequence=true`, `durable_dnc_intent=true`, `address_suppression_intent=ORGANISATION_DNC`.
`reply_permitted=false`, draft blocked (`T7_UNSUBSCRIBE_CONFIRMATION`, BLOCKED_PENDING_SUPPRESSION_VERIFICATION), `terminal_status=REVIEW_HOLD`.
`external_action_status=NOT_PERFORMED` (requested literal "NOOP"; NOT_PERFORMED matches fixture-04's documented expected value for this Decision-Engine path, unlike the Intake-terminal "NOOP" used in 3.1C1/3.1C2).
Cleanup: Intake -> active:false, Decision Engine -> active:false (confirmed via responses); Data Table row (id=1, intake_id=phase3-1c3-unsubscribe-unique) deleted.

**Verdict: UNSUBSCRIBE POLICY VERIFIED** (external_action_status field-value caveat above; no-send/no-false-completion guarantees held)

# Phase 3.1C4 — Dual-Reply Classification (POSITIVE_INTEREST + BOOKING_REQUEST)
Date: 2026-06-12. Unique payloads, intake_id `phase3-1c4-positive-interest-unique` and `phase3-1c4-booking-request-unique`. 6 MCP calls used (limit 8).
Activated Decision Engine (`NJcnNQoJ5nSIWYte`) then Intake (`cCcpFfi6iovWS94T`).
Exec `9` ("...I'd be open to hearing more."): is_duplicate=false, deterministic no-match, `category=POSITIVE_INTEREST`, `reply_template_id=T1_SCENARIO_C_UNCLEAR_INTEREST`, `terminal_status=REVIEW_HOLD`, `external_action_status=NOT_PERFORMED`.
Exec `11` ("...Can you send me your calendar?"): is_duplicate=false, `det-booking-001` matched, `category=BOOKING_REQUEST`, `reply_template_id=T1_SCENARIO_A_OPEN_TO_CALL` (registry template text only), `terminal_status=REVIEW_HOLD`, `external_action_status=NOT_PERFORMED`.
No email or external action occurred (`external_actions_mocked: true`).
Cleanup: Intake -> active:false, Decision Engine -> active:false (confirmed via responses); Data Table rows id=1 and id=2 deleted (confirmed via returnData).

**Verdict: T1 T3 CLASSIFICATION VERIFIED**

# Phase 3.1C5 — Malformed Payload Handling (missing event_type)
Date: 2026-06-12. Unique payload, intake_id `phase3-1c5-malformed-missing-event-type-unique` (no `event_type` key, distinct from fixtures 11/13). 7 MCP calls used (limit 7).
Activated Decision Engine (`NJcnNQoJ5nSIWYte`) then Intake (`cCcpFfi6iovWS94T`); Intake execution `13`: status `success`, finished `true`, mode `webhook`.
`payload_status=MALFORMED` (event_type MISSING_OR_INVALID, all 11 `validated.*` fields null). `idempotency.key_scheme=identifier_poor_hash`, `idempotency_key="identifier_poor:instantly:payload_hash=aa08cc9e"` (hash-based, not a fixed fallback).
Decision Engine invoked (subExecution `14`): `deterministic.rule_id=op-malformed`, `category=OTHER`. `decision.terminal_status=REJECTED`, `reply_permitted=false`, `external_action_status=NOT_PERFORMED` (no external action).
Cleanup: Intake -> active:false, Decision Engine -> active:false (confirmed via responses); Data Table row id=1 (intake_id=phase3-1c5-malformed-missing-event-type-unique) deleted (confirmed via returnData).

**Verdict: MALFORMED PAYLOAD HANDLING VERIFIED**
