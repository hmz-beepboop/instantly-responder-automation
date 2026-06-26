# Local Runtime Harness Verdict Fix

The runtime acceptance had already independently verified:

- the real Reply Sender output;
- the real Error Handler output;
- the Error Trigger entry;
- the SLA Watchdog entry.

It then additionally required a duplicate integration summary embedded inside
the Full Test Harness result. That duplicate summary could fail even though
the independently inspected runtime outputs passed.

The corrected acceptance:

- verifies all deterministic harness fixtures from `total`, `passed`,
  `failed`, and failed fixture IDs;
- requires the real Sender result independently;
- strengthens the real Error Handler check to require:
  - `SEND_UNCERTAIN` send state;
  - `SEND_UNCERTAIN` error class;
  - non-retryable;
  - persisted error ID;
  - no delivered notification while Google Chat is not configured;
- retains the embedded combined/integration results as diagnostic fields;
- does not change any workflow, credential, fixture, API contract, or runtime
  behaviour.
