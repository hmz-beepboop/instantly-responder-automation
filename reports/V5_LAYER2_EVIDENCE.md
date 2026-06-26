# V5 Layer 2 Evidence

## Scope

One controlled live reply POST was routed through a localhost one-shot proxy. The upstream response was deliberately withheld from the sender, and the outcome was reconciled read-only.

## Sanitised Result

- Final state: `SENT_RECONCILED`
- Send outcome: `response_dropped`
- Forwarded reply POST count: 1
- Upstream HTTP status observed by proxy: 200
- Reconciliation checks: 2
- Reconciliation match count: 1
- Second reply POST attempted: false
- Duplicate-risking retry observed: false
- Verification passed: true

## Verdict

V5_LAYER2_VERIFIED

## Limitations

This evidence applies to the controlled owned-inbox test and the current Instantly workspace/API behaviour.
