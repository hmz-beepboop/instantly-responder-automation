# Production Data Table Portability Fix

## Defect

The validated Intake workflow export contained the local n8n instance's fixed idempotency Data Table ID. A clean production n8n instance generates a different ID, so importing the workflow unchanged would point at a non-existent table.

## Surgical correction

- Replaced the local Intake Data Table ID with `__PLACEHOLDER_IDEMPOTENCY_DATA_TABLE_ID__`.
- Added `HMZ_IDEMPOTENCY_DATA_TABLE_ID` support to `apply-business-ready.ps1`.
- Carried that variable through controlled-live preflight, safe restoration, and cleanup.
- Added importable CSV schemas for the two required production Data Tables.

No workflow logic, routing, policy, credentials, activation state, sender behaviour, suppression behaviour, or retry behaviour was redesigned.
