# Autonomous Abuse Cases

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Purpose

Documents potential abuse scenarios specific to the autonomous layer and how each is mitigated.

---

## Abuse Case 1 — Spam-Like Volume from Autonomous Layer

**Scenario:** Autonomous mode is enabled and sends hundreds of emails per day, effectively spamming prospects.

**Controls:**
- `max_autonomous_sends_per_day` (default: 0; must be set to ≥ 1 by owner)
- `max_autonomous_sends_per_campaign_per_day`
- `max_autonomous_sends_per_sender_per_day`
- These caps are enforced before any send
- Kill switch immediately halts all sends
- Daily digest shows volume immediately

**Verdict:** NOT POSSIBLE with sample config (max=0). Requires explicit owner configuration.

---

## Abuse Case 2 — Autonomous Sends to DNC/Suppressed Contacts

**Scenario:** An autonomous send reaches a prospect who has previously opted out or is on a DNC list.

**Controls:**
- UNSUBSCRIBE and DO_NOT_CONTACT are hardcoded in permanent block list
- Any UNSUBSCRIBE intent triggers suppression, not an autonomous send
- Existing Sender workflow has its own suppression checks

**Verdict:** NOT POSSIBLE — multi-layer protection.

---

## Abuse Case 3 — Autonomous Layer Used for Mass Outreach (Not Just Replies)

**Scenario:** Someone configures the autonomous layer to initiate cold outreach (not just reply to inbound replies).

**Controls:**
- The autonomous layer only processes inbound prospect replies (replies trigger the Decision workflow)
- There is no "send first contact" function in the autonomous layer
- The autonomous layer cannot initiate a campaign
- The system is single-tenant: HMZ's own inbox only (per CLAUDE.md scope)

**Verdict:** NOT POSSIBLE — autonomous layer is a reply handler only.

---

## Abuse Case 4 — Autonomous Layer Expanded to Client Campaigns Without Proper Setup

**Scenario:** The autonomous layer is used for a client campaign before proper setup (knowledge base, permissions, testing).

**Controls:**
- Scope is HMZ's own validation campaign only (CLAUDE.md hard rule)
- campaign_allowlist and sender_allowlist must explicitly include client campaign IDs — currently empty
- The CLAUDE.md project file explicitly prohibits extending to client campaigns without full setup
- Any session attempting to configure for client campaigns should be refused

**Verdict:** NOT POSSIBLE under current project rules.

---

## Abuse Case 5 — Config File Shared Without Redacting Allowlists

**Scenario:** The autonomous config file is shared publicly or with unauthorized parties, exposing which campaigns and senders are approved for autonomous sends.

**Controls:**
- Config should not contain actual campaign IDs or sender emails in production — use environment variables or secure references
- Config file should not be committed to a public repository
- This project's constraints prevent secrets in files

**Recommendation:** When implementing, ensure campaign_allowlist and sender_allowlist use environment variable references, not literal values.

---

## Abuse Case 6 — Learning System Injecting Bad Rules Through Fake Corrections

**Scenario:** An attacker with access to the HumanApproval review form submits false corrections to inject harmful rules.

**Controls:**
- Only the owner has access to the review form (single-tenant system)
- Rule candidates require explicit owner approval (Phase 4D -Apply)
- Rules are validated against the ACTIVE_RULE_GUIDANCE schema before injection
- Any rule that overrides HUMAN_ONLY or UNSUBSCRIBE gates would be rejected by the governance layer

**Verdict:** LOW RISK — requires owner account compromise.

---

## Related Documents

- `docs/AUTONOMOUS_SECURITY_REVIEW.md` — security controls
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — hard boundaries
- `docs/AUTONOMOUS_SAFETY_MODEL.md` — gate layers
- `CLAUDE.md` — project scope (single-tenant, HMZ only)
