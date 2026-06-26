# Autonomous Security Review

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Scope

This security review covers the autonomous layer only. The supervised path security is covered by the existing system architecture.

---

## Threat Model

### Threat 1 — Config Manipulation

**Threat:** An attacker modifies the autonomous config to enable live sends without owner approval.

**Controls:**
- Config file stored locally (not in n8n); attacker needs file system access
- Config requires ALL of: autonomous_enabled=true, dry_run=false, shadow_only=false, emergency_disabled=false, non-empty allowlists, non-zero daily cap simultaneously
- Owner is notified via ALERT-008 (CONFIG_CHANGED) when config changes
- n8n workflow activation requires n8n API key or UI access

**Residual risk:** LOW — requires multiple simultaneous changes and n8n access

---

### Threat 2 — Eligibility Engine Bypass

**Threat:** An attacker sends a malformed payload that bypasses the eligibility gates and causes an autonomous send.

**Controls:**
- Input validation node rejects malformed payloads
- Default-blocked posture: exception = blocked, not allowed
- Permanently blocked intents are hardcoded in JavaScript, not configurable
- Sender workflow has independent idempotency check

**Residual risk:** VERY LOW — exception handling defaults to block

---

### Threat 3 — Credential Exposure

**Threat:** Autonomous layer logs expose API keys, Instantly credentials, or n8n webhook secrets.

**Controls:**
- Shadow log schema: excerpt only (200 chars max), no full email bodies
- Logs must not contain API keys or secrets (enforced in log schema)
- n8n node code must not output credential values

**Residual risk:** LOW — depends on correct implementation of log schema

---

### Threat 4 — Replay Attack

**Threat:** An attacker replays a legitimate webhook payload to trigger multiple sends.

**Controls:**
- Existing Sender workflow idempotency check prevents duplicate sends
- Daily cap limits blast radius even if replay occurs
- duplicate_risk gate blocks cases flagged as potential duplicates

**Residual risk:** LOW — idempotency check is the primary control

---

### Threat 5 — Scope Creep in Allowlists

**Threat:** Over time, the campaign_allowlist or sender_allowlist expands to include accounts that should not be autonomous.

**Controls:**
- Every allowlist addition requires documented owner approval
- ALERT-008 fires when config changes
- Acceptance harness can verify allowlist contents against expected values
- Periodic review of allowlists recommended (monthly)

**Residual risk:** MEDIUM — depends on owner discipline with allowlist management

---

## Security Checklist

Before shadow mode activation:

- [ ] Config file is stored outside git history (not committed with real allowlists or credentials)
- [ ] n8n API key is stored only in n8n credentials manager and local `.env` (not in any log or doc)
- [ ] Disabled workflow has no credential nodes (confirmed in 5D validation)
- [ ] Shadow log schema enforces 200-char excerpt limit
- [ ] No full email bodies in any autonomous log
- [ ] Escalation channels are real addresses owned by the owner
- [ ] Config file permissions restrict access to owner only

---

## Related Documents

- `docs/AUTONOMOUS_PRIVACY_REVIEW.md` — privacy controls
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — what the autonomous layer cannot access
- `docs/SECURITY.md` — base system security review
