# Phase 5 — Security Audit

**Date:** 2026-06-14
**Scope:** Six-workflow validation system, project-level secret/PII scan, n8n security audit, credential and network-boundary review.

## Credentials and network boundary

- All six workflows: `credentialsBound: false` (verification/phase5/mechanical-audit.json).
- All six workflows: `externalHttpTargets: []` — zero external HTTP Request targets.
- Per `reports/PHASE_4_VALIDATION.md`, all HTTP Request nodes in Phase 4 target only `http://hmz-send-state:5681` (the local sidecar, no published host port). The live Instantly adapter exists only as an unreachable validation contract.
- `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]` for all six workflows.
- No live Instantly call occurred during Phase 4 or Phase 5.

## n8n security audit (`n8nSecurityAudit` in mechanical-audit.json)

- Exit code 0, not timed out.
- "Nodes Risk Report" flags the Decision Engine's Code nodes (`A. Deterministic Policy Stage`, `B. Mock Semantic Classifier`, `C. Decision Policy`, etc.) as official "risky nodes" — this is the **generic n8n advisory** that Code nodes can execute arbitrary code on the host. These nodes contain only deterministic policy/classification logic operating on in-memory item data; they make no external network calls (confirmed via `externalHttpTargets: []`) and are not user-input-driven beyond the validated NES structure.
- No findings beyond the generic Code-node risk advisory were observed in the captured snippet.

## Project secret/PII scan (`projectScan` in mechanical-audit.json)

| Check | Result |
|---|---|
| Real-email hit count after cleanup | 0 |
| Real-email files after cleanup | (none) |
| Known synthetic secret-pattern hit count | 2 |
| Known synthetic secret-pattern files | `verification\phase4a\run-offline-tests.mjs`, `verification\phase4b\run-offline-tests.mjs` |
| Unexpected secret-pattern hit count | 0 |
| Unexpected secret-pattern files | (none) |
| Historical owner-email replacements made | 0 |

**Conclusion:** No real email addresses or unexpected secret-pattern residue were found anywhere in the project. The only secret-pattern hits are known, expected synthetic test fixtures used by the offline test suites. The `docs/PHASE_5_VERIFIED_INPUT.md` privacy-cleanup item (a historical environment-audit report containing one real local n8n owner email) is confirmed already clean — the post-cleanup real-email hit count is 0 with 0 owner-email replacement needed in this pass. `reports/INSTANTLY_VERIFICATION_EVIDENCE.md` independently confirms it contains no API keys, webhook tokens, secret-header values, or real recipient addresses.

## Reply Sender / Error Handler credential posture (inherited from Phase 4A)

- No credentials bound; no reachable Instantly request. `SEND_UNCERTAIN` never blindly retries (Phase 4A-verified). Concurrent-send ownership lock and durable sequential-rerun blocking are verified (Phase 4A 42/42).

## Overall security/privacy conclusion

No defects found. All six workflows are inactive, credential-free, and network-isolated to the local sidecar only. The secret/PII scan is clean. The generic Code-node risk advisory is a standard n8n platform notice, not a project-specific defect, and is mitigated by the absence of external HTTP targets and bound credentials.
