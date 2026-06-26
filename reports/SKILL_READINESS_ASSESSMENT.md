# Skill Readiness Assessment — `instantly-reply-automation-builder`

**Date:** 2026-06-14
**System verdict referenced:** `READY_FOR_DRY_RUN`

## Proposed Skill

`instantly-reply-automation-builder` — a reusable Skill for building/adapting
Instantly reply-automation responders (intake, decision engine, sender, error
handler, SLA watchdog, test harness) for new campaigns/workspaces.

## Evaluation

### Workflow stability

All six workflows are inactive, n8n-valid (modulo the documented Phase 4B
validator exception), credential-free, and `localMatchesRemote: true` with
`mismatches: []`. This is a stable, reproducible baseline.

### API verification

Several Instantly v2 endpoints are live-verified
(`reply_to_uuid`/`email_id` mapping, thread/subject preservation,
`update-interest-status`, `subsequence/remove`, exact email-level Blocklist).
The Instantly API base host (`https://api.instantly.ai`) is now verified
(`docs/ASSUMPTIONS_AND_UNKNOWNS.md` B1). However, webhook
authentication/signing remains unverified, and the campaign-local-vs-workspace
unsubscribe distinction was discovered only during validation — i.e. the
verified surface is real but narrower than a general-purpose builder would
need.

### Runtime evidence

The Full Test Harness and SLA Watchdog have actual n8n-runtime execution
evidence. As of Phase 6, the Reply Sender and Error Handler — the two
workflows most relevant to a "build an automation that sends replies" Skill
— also have actual n8n-runtime execution evidence: an approved synthetic
Sender item reached `DRY_RUN_OK` (`sent=false`, `transport=NONE`), and a
forced synthetic Error Handler item persisted a sanitised, non-retryable
`SEND_UNCERTAIN` record (`reports/INTEGRATION_CLOSURE_RUNTIME.md`). The
normal Intake → Decision Engine → Sender path still terminates
`BLOCKED_PENDING_DURABLE_APPROVAL` because no durable human-approval
mechanism exists for the Sender's gate.

### Repeatability

The documentation set (this Phase 6 package, `docs/STATE_AND_IDEMPOTENCY.md`,
`docs/HMZ_APPROVED_REPLY_RULES.md`, `docs/INSTANTLY_FIELD_MAP.md`) gives a
repeatable architecture description and a repeatable audit procedure
(Phase 4A/4B offline suites, Phase 5 mechanical audit).

### Unresolved live-integration gaps

- No durable human-approval mechanism exists for the Reply Sender's approval
  gate; the normal Intake → Decision Engine → Sender path terminates
  `BLOCKED_PENDING_DURABLE_APPROVAL`.
- Automatic `settings.errorWorkflow` routing from a genuinely failed parent
  execution remains unexercised (only the synthetic Execute Workflow Trigger
  path was run).
- Zero-match and multiple-match reconciliation outcomes are policy-verified
  only, not live-exercised.
- SLA Watchdog's actual scheduled (cron) firing on an active workflow is
  unexercised.
- No live reply has been sent through the n8n Reply Sender workflow.

### Documentation completeness

After this Phase 6 package, operator-facing documentation (setup,
configuration, security, troubleshooting, deployment, rollback) is complete
for the current validation stage. Business-policy documentation
(`docs/HMZ_APPROVED_REPLY_RULES.md`) is itself marked "Business-partner
review draft. Not approved for live deployment."

### Expected reuse

The architecture (Intake → Decision Engine → Sender/Error Handler →
Watchdog/Harness, sidecar-based send ownership) is generic enough to be a
reasonable template for future campaigns/workspaces. But several pieces are
HMZ-specific and validation-stage-specific by design: hardcoded `CONFIG`
(`dry_run`, `live_campaigns`), the mocked semantic classifier, the
HMZ-approved taxonomy/templates/KB, and the single-tenant scope statement in
`docs/ARCHITECTURE.md`.

### Risk of encoding validation-only assumptions into a reusable Skill

**High if built now.** A Skill built today would likely encode: (1) the
mocked classifier as if it were a real integration point, (2) the unverified
webhook-auth strategy as a settled fact, (3) the campaign-local unsubscribe
behaviour without the now-required paired Blocklist action being
structurally enforced, and (4) the absence of a durable approval mechanism
for the Sender's gate as if the send path required no further human-approval
infrastructure. Any of these, once encoded into a reusable Skill, would be
hard to unwind across future generated workflows.

## Verdict

`READY_TO_DESIGN_SKILL`

## Rationale

The architecture, documentation, and audit trail are mature and stable
enough to begin **designing** a generalised Skill (identifying which parts
are genuinely reusable vs. HMZ/validation-specific, and which verified
contracts vs. open items must be parameterised or flagged). `READY_TO_BUILD_SKILL`
is not justified: the Sender's approval gate has no durable human-approval
mechanism (the normal path terminates `BLOCKED_PENDING_DURABLE_APPROVAL`),
the zero/multiple reconciliation paths are unexercised live, and building now
risks baking validation-only assumptions (mocked classifier, campaign-local
suppression, no approval UI) into a reusable artefact. `NOT_READY_FOR_SKILL`
is too conservative given the stable workflow baseline, clean security/audit
posture, complete operator documentation, and now-proven Sender/Error
Handler n8n-runtime evidence (Phase 6) — design work can proceed in parallel
with closing the remaining runtime/live-integration gaps.
