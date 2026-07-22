# Codex Inbound 100K Scale Results

Run: 2026-07-21T03:49:06.985Z–03:59:22.065Z  
Verdict: **PASS — 45/45 assertions**  
Exact image: `sha256:94dd2dcb55fc4472ed5cc7ef361159a6f0a010119e0926ab8241aebfbd24ea43`  
Source archive SHA-256: `1d11b548fc0676c9cca0fab4494cfaab59a070350098e46ace850d57bd099470`  
Result-log SHA-256: `ada09575138402a7e27d834543a3e2ed2adad79af3cd8ed0f5d8373a15ae3238`

This was the full requested run, not a reduced-volume substitute. It used the real current `inbound-contract.mjs`, `inbound-store.mjs` and `inbound-service.mjs` with deterministic Instantly and Google Chat adapters in an isolated container. It made zero production Instantly reply POSTs.

## Workload completed

| Workload | Completed |
|---|---:|
| Unique Instantly received records | 100,000 |
| Duplicate deliveries | 100,000 |
| Logical webhook/poll/auditor races | 100,000 |
| Deliveries across those races | 300,000 |
| Simultaneous discovery operations | 1,000 |
| Automatic + OOO | 10,000 |
| Bounce/system | 10,000 |
| Malformed/degraded | 15,000 |
| Attachment-only/empty | 5,000 |
| Surrogate identities | 1,000 |
| Pagination pages/transitions | 102 / 101 |
| Five-minute mixed soak cycles | 1,818 |

Pagination included equal timestamps, boundary duplicates, insertion/mutation and 101 duplicate logical events across boundaries. Failure cases covered Instantly 429/5xx, partial/final-page failure, database interruption, worker races, stale leases, sidecar/database reopen, an n8n-style replay, a full component restart, a sustained Chat outage and repeated response-loss ambiguity.

## Final invariants

| Invariant | Result |
|---|---:|
| Durable inbound identities | 100,000 |
| Logical outbox rows | 100,000 |
| Final `CHAT_NOTIFIED` | 100,000 |
| Missing inbound / missing outbox | 0 / 0 |
| Nonterminal rows / open attempts | 0 / 0 |
| Duplicate logical contexts / outbox identities | 0 / 0 |
| Invalid acknowledgements | 0 |
| Prospect-email POSTs | 0 |
| SQLite quick check / foreign-key violations | `ok` / 0 |

Every malformed/degraded fixture and every bounce/system fixture reached `CHAT_NOTIFIED`. Each definite acknowledgement stored a Chat message identity. The restart recovered in 0.552 seconds.

## Outage and ambiguity

The mock Chat outage accumulated the full 100,000-item backlog. The first pass produced 99,000 explicit retryable failures and 1,000 response-loss ambiguities, with zero false acknowledgements. After restoration, four workers acknowledged all 100,000 and left queue depth zero.

- maximum backlog: 100,000;
- drain rate: 1,638.92 notifications/second;
- drain wall time: 61.016 seconds;
- probable duplicate recovery posts: 1,000 (1.00% of this intentionally ambiguity-injected workload);
- deterministic ambiguity thread keys recovered: 1,000/1,000.

The probable duplicates are expected at-least-once behavior under deliberately injected response loss. They are labelled and counted; the result does not claim visual exactly-once delivery.

## Performance and resources

| Measure | Result |
|---|---:|
| Unique registration throughput | 6,229.31/s |
| Duplicate delivery throughput | 14,633.99/s |
| Three-path race delivery throughput | 8,210.87/s |
| Outage attempt throughput | 1,688.79/s |
| Pagination throughput | 77.73 pages/s |
| Average CPU | 67.72% |
| Maximum RSS / heap | 496,271,360 / 198,511,200 bytes |
| Final RSS | 160,288,768 bytes |
| SQLite / checkpointed WAL | 229,695,488 / 0 bytes |
| File descriptors before/after soak | 22 / 22 |
| Database growth during soak | 839,680 bytes |
| RSS change during soak | -339,709,952 bytes |
| Total wall time | 615.080 seconds |

The harness's logical notification latency was p50/p95/p99/max = 1,920,000 ms because it advances a deterministic clock through the intentionally sustained outage and bounded retry schedule. It is not production network latency. The independently measured live 15-record burst was 2,303–13,924 ms from received timestamp to definite acknowledgement.

## Limits

- Instantly and Google Chat were deterministic adapters for this scale run; the result proves internal invariants, not external-provider availability.
- The soak was five minutes. Stable descriptors, RSS and bounded database growth in that interval do not prove the absence of every long-horizon leak.
- Google Chat incoming-webhook response loss cannot prove visual exactly-once delivery; the design deliberately favors at-least-once visibility over silent loss.

