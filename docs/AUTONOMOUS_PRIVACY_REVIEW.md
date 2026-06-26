# Autonomous Privacy Review

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Privacy Principles

1. **Minimal data retention.** Only store what is necessary to operate and audit the autonomous layer.
2. **No full email body storage.** Shadow logs store only the first 200 chars of prospect replies.
3. **Prospect consent.** Autonomous sends are outreach replies — they occur in the context of a prospect who responded to a campaign they received. The same consent baseline as supervised replies applies.
4. **No inference from personal data.** The eligibility engine evaluates intents and gates; it does not build profiles on individual prospects.
5. **Explicit blocking for sensitive data.** Any prospect email mentioning SENSITIVE_PERSONAL_DATA is permanently blocked from autonomous processing.

---

## Data Processed by Autonomous Layer

| Data Type | Source | Stored? | How Long? |
|-----------|--------|---------|-----------|
| Prospect email address | Instantly | YES (shadow log) | 90 days |
| Prospect reply excerpt (200 chars) | Instantly | YES (shadow log) | 90 days |
| Campaign ID | Instantly | YES (shadow log) | 90 days |
| Sender email | Instantly | YES (shadow log) | 90 days |
| Classification result | Decision workflow | YES (shadow log) | 90 days |
| Full prospect reply | Instantly | NO — only excerpt | — |
| Prospect personal details | — | NO | — |
| API keys or credentials | — | NO | — |

---

## GDPR / Privacy Law Considerations

The autonomous layer is an extension of the existing outreach system. The following apply:

1. **Legitimate interest basis.** Sending a reply to a prospect who responded to a B2B outreach email is within legitimate interest (same as supervised path). This does not change with autonomous mode.

2. **Unsubscribe/opt-out.** Permanently blocked — any UNSUBSCRIBE or DNC intent is hardcoded as blocked. A prospect who opts out will NOT receive an autonomous reply.

3. **Data minimisation.** Shadow logs contain only the minimum data needed for audit. Full email bodies are not stored.

4. **Retention limits.** Shadow log retention is 90 days. Review queue and digest retention is 1 year.

5. **GDPR requests.** Any prospect asking about their data or requesting deletion (GDPR_REQUEST) is permanently blocked from autonomous processing and routed to human review.

6. **No automated profiling.** The eligibility engine does not build personal profiles. It evaluates classification results, not individual prospect history.

---

## Privacy Risks

| Risk | Mitigation |
|------|-----------|
| Prospect opt-out not honoured | UNSUBSCRIBE hardcoded as permanently blocked |
| GDPR request handled autonomously | GDPR_REQUEST hardcoded as permanently blocked |
| Personal data in shadow log | 200-char excerpt only; no full bodies; no personal details beyond email |
| Data breach of shadow log | Shadow log is in n8n DataTable — same security as existing DataTables |

---

## Privacy Checklist

Before shadow mode activation:

- [ ] UNSUBSCRIBE and GDPR_REQUEST are in the permanent block list (CONFIRMED — eligibility engine hardcodes these)
- [ ] Shadow log stores only 200-char excerpt (DESIGNED — to be enforced in implementation)
- [ ] Retention policy configured for DataTables when created
- [ ] Outreach is to B2B contacts in compliant campaigns (scope is HMZ's own validation campaign)
- [ ] Privacy policy document reviewed for outreach if required by jurisdiction

---

## Related Documents

- `docs/AUTONOMOUS_SECURITY_REVIEW.md` — security controls
- `docs/AUTONOMOUS_SYSTEM_BOUNDARIES.md` — permanently blocked intents
- `docs/HMZ_APPROVED_REPLY_RULES.md` — approved reply policy
