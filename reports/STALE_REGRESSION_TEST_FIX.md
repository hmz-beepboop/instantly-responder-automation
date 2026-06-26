# Stale Regression Test Fix

The controlled-live runtime script had already been corrected to use the real
production reply and authenticated human-approval path. However, two Blocker E
assertions in `run-release-blocker-tests.mjs` still described and positively
matched the superseded development-webhook implementation.

This patch updates only those tests. It does not change workflow logic,
runtime scripts, configuration, API contracts, or safety gates.

The revised tests now require:

- no PowerShell POST to the development Intake webhook;
- a genuine owned-inbox reply;
- production human approval exactly once;
- n8n Sender execution polling;
- temporary activation of the six required runtime workflows;
- Full Test Harness separation;
- safe restoration in `finally`;
- `dry_run=true`, `live_campaigns=[]`, and all workflows inactive afterward.
