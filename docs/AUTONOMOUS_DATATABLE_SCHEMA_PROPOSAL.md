# Autonomous DataTable Schema Proposal

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** PROPOSAL — Requires owner approval before creation

---

## Proposed New DataTables

These three DataTables must be created in n8n when shadow mode is activated. They do not currently exist in production.

### Table 1: hmz-autonomous-shadow-log
- Description: Shadow evaluation log for all candidates
- Key: correlation_id
- See: `docs/AUTONOMOUS_DATA_MODEL.md` for full column list
- Retention: 90 days
- Privacy: no full email bodies; excerpt only

### Table 2: hmz-autonomous-review-queue
- Description: Cases requiring owner review
- Key: queue_id
- See: `docs/AUTONOMOUS_DATA_MODEL.md`
- Retention: 1 year

### Table 3: hmz-autonomous-daily-digest
- Description: Generated daily digests
- Key: digest_id
- See: `docs/AUTONOMOUS_DATA_MODEL.md`
- Retention: 1 year

---

## Creation Checklist (When Ready)

- [ ] Owner approves DataTable creation (Gate 1 / Shadow Mode approval)
- [ ] DataTables created in production n8n workspace
- [ ] DataTable IDs recorded in docs/CURRENT_PRODUCTION_STATE.md
- [ ] DataTable IDs recorded in NEXT_SESSION_HANDOFF.md
- [ ] Access permissions verified (workflow can write; external cannot read without API key)
- [ ] Test write to each table confirmed
- [ ] Retention policy configured

---

## Why Not Create Them Now

The DataTables are not needed until the shadow evaluator workflow is active and producing evaluations. Creating them now would be premature and would not be used. They should be created at the same time as shadow mode activation (Phase 5F).

---

## Related Documents

- `outputs/autonomous_datatable_schema.json` — machine-readable schema
- `docs/AUTONOMOUS_DATA_MODEL.md` — full data model
- `docs/AUTONOMOUS_PHASE_5_ARCHITECTURE.md` — where DataTables fit in the architecture
