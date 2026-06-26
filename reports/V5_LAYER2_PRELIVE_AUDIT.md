# V5 Layer 2 Corrected Pre-Live Audit

## Verdict

`V5_LAYER2_PRELIVE_READY`

## Critical defects corrected

1. The original send key included a random body marker, so a rerun generated a different key and could submit a duplicate.
2. The original lock was released and no durable prior-state check was performed, so a sequential rerun could send again.
3. The original self-test covered simultaneous contention only, not a later rerun after completion.
4. Reconciliation accepted any single match on two checks, even if the matching Email ID changed between checks.
5. Recipient matching omitted the documented `to_address_email_list` fallback and used case-sensitive comparisons.
6. Reconciliation HTTP failures were silently treated as zero matches.
7. The proxy had no bounded upstream timeout.
8. The live wrapper stored state inside the repository and displayed unmasked controlled addresses.
9. The original live runner did not create the promised sanitised result or evidence report.

## Corrected controls

- Stable send key based on operation, inbound Email ID, sender, and recipient.
- Exclusive atomic lock plus durable state-file refusal on later reruns.
- Concurrent and sequential duplicate-attempt tests.
- Exactly one forwarded reply POST.
- No automatic retry after uncertainty.
- Same Email object ID required on two consecutive reconciliation checks.
- Official Email List filters plus strict local thread, sender, recipient, subject, marker, and timestamp matching.
- Read-only reconciliation errors produce explicit human-review states.
- State directory moved outside the repository to the OS temporary directory.
- Sanitised live JSON and Markdown evidence outputs.
- API key remains environment-only for the child process and is cleared in `finally`.

## Local test scenarios

- Success reconciliation: `SENT_RECONCILED`
- Zero matches: `HUMAN_REVIEW_ZERO_MATCHES`
- Multiple matches: `HUMAN_REVIEW_MULTIPLE_MATCHES`
- Concurrent duplicate attempt: second attempt blocked by `LOCK_ALREADY_HELD`
- Sequential rerun with a different marker: blocked by `DURABLE_STATE_EXISTS`

## Live execution boundary

The live wrapper must be run exactly once using a controlled inbound Email object and owned recipient. A successful verification requires:

- one forwarded POST,
- upstream HTTP 2xx observed by the proxy,
- dropped client response,
- `SEND_UNCERTAIN` recorded,
- exactly one matching sent Email object observed on two consecutive checks,
- final state `SENT_RECONCILED`,
- no second POST.
