# V5 Layer 1 Evidence — Sender Retry & Uncertain-Outcome Policy

## 1. Scope

Local, deterministic, localhost-only fault-injection harness verifying the
Sender retry policy and uncertain-outcome classification contract.

- No Instantly access.
- No n8n access.
- No MCP usage.
- No workflow inspection or modification.
- This covers **V5 Layer 1 only**. V5 Layer 2 has not been started.

Files created (5, within the limit):
- `verification/v5/layer1/mock-server.mjs`
- `verification/v5/layer1/sender-policy.mjs`
- `verification/v5/layer1/run-layer1.mjs`
- `verification/v5/layer1/results.json`
- `reports/V5_LAYER1_EVIDENCE.md` (this file)

## 2. Environment

- Node.js version: `v24.15.0`
- Mock server: `http.createServer`, bound to `127.0.0.1` only, OS-assigned
  ephemeral port.
- "Connection refused" scenario uses a second `127.0.0.1` port probed and
  closed immediately before use (nothing listening on it).
- Policy under test: `verification/v5/layer1/sender-policy.mjs`
  - `MAX_ATTEMPTS = 3`
  - `BASE_BACKOFF_MS = 100`, `MAX_BACKOFF_MS = 2000`
  - `RETRY_AFTER_CAP_MS = 5000`
  - Deterministic jitter: `(attempt * 37) % 50` → jitter(1)=37, jitter(2)=24
  - `sleep` is dependency-injected as a no-op so the full 18-scenario run
    completes in real time without waiting out backoff delays.
- Test run: one initial full run, all scenarios and assertions passed; no
  repair pass was required.

## 3. Scenario matrix

| # | Scenario | Mock behaviour |
|---|---|---|
| 1 | `http_400_bad_request` | Immediate `400` JSON |
| 2 | `http_401_unauthorized` | Immediate `401` JSON |
| 3 | `http_402_payment_required` | Immediate `402` JSON |
| 4 | `http_403_forbidden` | Immediate `403` JSON |
| 5 | `http_404_invalid_reply_target` | Immediate `404` JSON (invalid reply target) |
| 6 | `http_429_with_retry_after` | `429` + `Retry-After: 1` every attempt |
| 7 | `http_429_without_retry_after` | `429`, no `Retry-After`, every attempt |
| 8 | `http_500_server_error` | `500` every attempt |
| 9 | `http_502_bad_gateway` | `502` every attempt |
| 10 | `http_503_service_unavailable` | `503` every attempt |
| 11 | `http_504_gateway_timeout` | `504` every attempt |
| 12 | `connection_refused_before_submission` | Connect to a closed `127.0.0.1` port → `ECONNREFUSED` |
| 13 | `connection_reset_before_confirmed_submission` | Server destroys socket on receipt, before draining body |
| 14 | `connection_reset_after_submission` | Server drains body, then destroys socket, no response |
| 15 | `failure_before_request_submission` | Synthetic pre-submission failure, no network call made |
| 16 | `delayed_success_within_timeout` | 20ms delay, then valid `200` contract body |
| 17 | `malformed_success_response` | Immediate `200` with non-contract body |
| 18 | `timeout_after_submission` | Server drains body, never responds; client timeout = 60ms |

All 18 required scenarios executed.

## 4. Expected versus actual state

| Scenario | Expected `finalState` | Actual `finalState` | Match |
|---|---|---|---|
| http_400_bad_request | PERMANENT_FAILURE | PERMANENT_FAILURE | ✅ |
| http_401_unauthorized | AUTH_OR_PLAN_FAILURE | AUTH_OR_PLAN_FAILURE | ✅ |
| http_402_payment_required | AUTH_OR_PLAN_FAILURE | AUTH_OR_PLAN_FAILURE | ✅ |
| http_403_forbidden | AUTH_OR_PLAN_FAILURE | AUTH_OR_PLAN_FAILURE | ✅ |
| http_404_invalid_reply_target | INVALID_REPLY_TARGET | INVALID_REPLY_TARGET | ✅ |
| http_429_with_retry_after | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| http_429_without_retry_after | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| http_500_server_error | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| http_502_bad_gateway | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| http_503_service_unavailable | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| http_504_gateway_timeout | RETRY_EXHAUSTED | RETRY_EXHAUSTED | ✅ |
| connection_refused_before_submission | PRE_SUBMISSION_NETWORK_FAILURE | PRE_SUBMISSION_NETWORK_FAILURE | ✅ |
| connection_reset_before_confirmed_submission | SEND_UNCERTAIN | SEND_UNCERTAIN | ✅ |
| connection_reset_after_submission | SEND_UNCERTAIN | SEND_UNCERTAIN | ✅ |
| failure_before_request_submission | PRE_SUBMISSION_NETWORK_FAILURE | PRE_SUBMISSION_NETWORK_FAILURE | ✅ |
| delayed_success_within_timeout | SENT | SENT | ✅ |
| malformed_success_response | SEND_UNCERTAIN | SEND_UNCERTAIN | ✅ |
| timeout_after_submission | SEND_UNCERTAIN | SEND_UNCERTAIN | ✅ |

All 7 required terminal states (`SENT`, `PERMANENT_FAILURE`,
`AUTH_OR_PLAN_FAILURE`, `INVALID_REPLY_TARGET`, `RETRY_EXHAUSTED`,
`SEND_UNCERTAIN`, `PRE_SUBMISSION_NETWORK_FAILURE`) were exercised and
matched expectations.

## 5. Attempt and submission counts

| Scenario | Attempts | POST submissions | Retried |
|---|---|---|---|
| http_400_bad_request | 1 | 1 | no |
| http_401_unauthorized | 1 | 1 | no |
| http_402_payment_required | 1 | 1 | no |
| http_403_forbidden | 1 | 1 | no |
| http_404_invalid_reply_target | 1 | 1 | no |
| http_429_with_retry_after | 3 | 3 | yes |
| http_429_without_retry_after | 3 | 3 | yes |
| http_500_server_error | 3 | 3 | yes |
| http_502_bad_gateway | 3 | 3 | yes |
| http_503_service_unavailable | 3 | 3 | yes |
| http_504_gateway_timeout | 3 | 3 | yes |
| connection_refused_before_submission | 3 | 0 | yes |
| connection_reset_before_confirmed_submission | 1 | 1 | no |
| connection_reset_after_submission | 1 | 1 | no |
| failure_before_request_submission | 3 | 0 | yes |
| delayed_success_within_timeout | 1 | 1 | no |
| malformed_success_response | 1 | 1 | no |
| timeout_after_submission | 1 | 1 | no |

Permanent 4xx (1), auth/plan failures (2–4) and invalid reply target (5)
each used exactly one attempt, as required. All retryable scenarios used
at most 3 attempts (the configured maximum).

## 6. Retry-After evidence

- `http_429_with_retry_after`: mock returns `Retry-After: 1` on every
  attempt. Policy honoured it: `backoffDelaysRequested = [1000, 1000]`
  (1000ms = `Retry-After: 1` × 1000, within the 5000ms cap),
  `retryAfterHonoured = true`.
- `http_429_without_retry_after`: no `Retry-After` header present. Policy
  fell back to bounded exponential backoff with deterministic jitter:
  `backoffDelaysRequested = [137, 224]` (100+jitter(1)=137,
  200+jitter(2)=224), `retryAfterHonoured = false`.
- All other retryable scenarios (5xx, connection-refused,
  pre-submission-failure) used the same exponential-backoff-with-jitter
  formula (`[137, 224]`) since no `Retry-After` applies, and recorded
  `retryAfterHonoured = false`.

## 7. Duplicate-risk audit

- `connection_reset_before_confirmed_submission`: 1 attempt, 1 POST
  submission, **no retry**, `finalState = SEND_UNCERTAIN`.
- `connection_reset_after_submission`: 1 attempt, 1 POST submission, **no
  retry**, `finalState = SEND_UNCERTAIN`.
- `timeout_after_submission`: 1 attempt, 1 POST submission, **no retry**,
  `finalState = SEND_UNCERTAIN`.
- `malformed_success_response`: 1 attempt, 1 POST submission, **no
  retry**, `finalState = SEND_UNCERTAIN`.
- `duplicateRiskRetry` is `false` for all 18 scenarios (see
  `results.json`).
- Global assertion `no_duplicate_risk_retry_in_any_scenario`: **pass**.
- Global assertion `send_uncertain_scenarios_issued_no_second_post`:
  **pass** — none of the four `SEND_UNCERTAIN` scenarios retried or issued
  a second POST.
- `connection_refused_before_submission` and
  `failure_before_request_submission` retried up to 3 times with **0**
  POST submissions reaching the mock server in every attempt — confirming
  retries only occur when submission is proven not to have happened.

## 8. Failed assertions

None. All 18 scenarios passed all 9 per-scenario assertions
(`finalState`, `attempts`, `postSubmissions`, `retried`,
`retryAfterHonoured`, `humanReviewRequired`, `duplicateRiskRetry`,
`backoffDelaysRequested`, `postSubmissions<=maxAllowed`).

All 9 global assertions passed:
- `permanent_4xx_used_one_attempt`
- `auth_or_plan_failures_used_one_attempt`
- `invalid_reply_target_used_one_attempt`
- `retryable_scenarios_never_exceeded_three_attempts`
- `send_uncertain_scenarios_issued_no_second_post`
- `no_scenario_exceeded_its_max_allowed_post_submissions`
- `every_required_scenario_executed`
- `no_external_network_request_occurred`
- `no_duplicate_risk_retry_in_any_scenario`

No repair pass was needed; this is the result of the single initial full
run.

## 9. Limitations

- This harness verifies the **policy module in isolation**
  (`sender-policy.mjs`) against a local mock transport. It does not verify
  that the deployed n8n Sender node actually calls this policy or
  reproduces this exact retry/backoff behaviour — that is out of scope for
  Layer 1 and would require Layer 2+ (workflow-level verification, not
  performed here).
- `connection_reset_before_confirmed_submission` and
  `connection_reset_after_submission` are both implemented via the mock
  server destroying the socket (one before draining the request body, one
  after). Both currently classify to the same terminal state
  (`SEND_UNCERTAIN`) under the policy as specified ("once request
  submission cannot safely be ruled out, do not retry"), so this harness
  does not distinguish a *third*, more optimistic outcome for the
  "before confirmed" case.
- `failure_before_request_submission` (#15) is implemented as a fully
  synthetic outcome (no socket/connection is created at all), since a
  failure "proven to occur before request submission" cannot be produced
  deterministically via real OS-level networking without flakiness.
- Timing-sensitive scenarios (`delayed_success_within_timeout`,
  `timeout_after_submission`) use short, fixed local delays/timeouts
  (20ms / 60ms) suitable for a fast localhost run; absolute values are not
  meant to mirror production timeout configuration.
- Retry `sleep` is dependency-injected as a no-op for test speed; the
  requested delay values are recorded and asserted, but real wall-clock
  waiting is not exercised here.

## 10. Final verdict

**V5_LAYER1_VERIFIED**
