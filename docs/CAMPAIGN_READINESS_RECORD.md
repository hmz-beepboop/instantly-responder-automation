# Campaign Readiness Record (CRR) — Gate S5 requirement

**Created:** 2026-07-07 (Fable Run 3). **Rule:** No campaign may be added to `LIVE_CAMPAIGNS` / the Sender launch profile allowlist without a completed, owner-signed copy of this record. One record per campaign. A missing or incomplete CRR blocks launch — no exceptions, no verbal approvals.

Scope reminder (CLAUDE.md): this system serves HMZ's own validation campaign only. Any non-HMZ campaign additionally requires the client-delivery preconditions in CLAUDE.md (approved client KB, client reply policy, compliance review, controlled client-environment testing) before this record may even be opened.

## Record template (copy per campaign)

| # | Field | Value | Evidence required |
|---|-------|-------|-------------------|
| 1 | Campaign ID (exact) | | Instantly campaign UUID; must match allowlist entry exactly |
| 2 | Workspace / org ID | | Instantly workspace UUID; must be on `workspace_allowlist` |
| 3 | Approved sender eaccount(s) | | Each must be in `connected_sender_eaccounts` in the Sender launch profile; a sender not on the list blocks launch |
| 4 | Expected subject / thread pattern | | Sample inbound subject; Sender preserves `Re:` threading via `reply_to_uuid` |
| 5 | Product/offer profile | | Link to approved KB / offer doc used for drafting (`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` for HMZ) |
| 6 | CTA (approved) | | Exact booking link / CTA text |
| 7 | Reviewer identity | | Must be on `reviewer_allowlist` in the Sender launch profile |
| 8 | Owned test lead | | An HMZ-controlled inbox enrolled in the campaign |
| 9 | Controlled test plan | | Planned probe replies + expected classifications, written before launch |
| 10 | Runtime proof complete | | `docs/RUNTIME_PROOF_CHECKLIST.md` executed and dated for this campaign |
| 11 | Correct sender confirmed | | Live proof: reply sent from the same eaccount that received the inbound |
| 12 | Correct recipient confirmed | | Live proof: reply addressed to the original prospect lead |
| 13 | Same-thread visible body confirmed | | Live proof: non-blank body visible in the original thread |
| 14 | No duplicate confirmed | | Rerun/replay of the same approval produces zero additional sends |
| 15 | Credential-leak scan passed | | `python scripts/scan-workflow-exports-for-secrets.py` exit 0, dated |
| 16 | Stale-script guard | | Confirm no `run-local-*`, old fix package, or stale acceptance harness was used as evidence; production exports refreshed and versionIds recorded |
| 17 | Owner signature + date | | Written sign-off in this file |

## Standing guards

- The old controlled-live acceptance harness is **never** the sole source of truth; the runtime proof checklist is.
- Rows 11-14 require a real owner-approved controlled send; harness output cannot substitute.
- Any change to Decision/HumanApproval/Sender after sign-off invalidates rows 10-14 until re-proven.

## Completed records

*(none yet — the single current validation campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0` predates this record; it must receive a backfilled CRR before any S5 scale work, and rows 11-14 for it are last evidenced 2026-06-23 (cases c0dd8298/7434572c/c9b32e56) — stale, re-proof required on next approved send.)*
