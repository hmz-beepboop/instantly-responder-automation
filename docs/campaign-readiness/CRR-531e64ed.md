# Campaign Readiness Record — `531e64ed-c225-4baf-97a9-4ec90dc34eb0`

**Campaign:** HMZ US B2B validation campaign (single-tenant, HMZ's own outreach).
**Record status:** **INCOMPLETE — LAUNCH BLOCKED.** Backfilled 2026-07-07 (Fable Run 4) from repo
evidence only. Fields marked `PENDING_OWNER_CONFIRMATION` were NOT invented; the owner must fill and
sign them. Rows 10–14 additionally require a fresh owner-approved controlled send
(`docs/RUNTIME_PROOF_CHECKLIST.md` section B) because the last live-send evidence (2026-06-23) is
stale and may predate this campaign ID (see `README.md` in this folder).

| # | Field | Value | Evidence / status |
|---|-------|-------|-------------------|
| 1 | Campaign ID (exact) | `531e64ed-c225-4baf-97a9-4ec90dc34eb0` | Matches production Sender allowlist (node O launch profile, versionId `00b52f03`, verified 2026-07-07); live exec 5263 | 
| 2 | Workspace / org ID | `c7f84f11-4a1a-42dc-9a74-a417e44cb87e` | On `workspace_allowlist` in the Sender launch profile (verified 2026-07-07) |
| 3 | Approved sender eaccount(s) | `hamzah@teamhmzautomations.com` (seed sender used in controlled acceptance); full connected list (24 eaccounts) embedded in Sender node O | In `connected_sender_eaccounts`; exec 5263 inbound sender matched. **Owner to confirm which eaccounts this campaign actually sends from: PENDING_OWNER_CONFIRMATION** |
| 4 | Expected subject / thread pattern | PENDING_OWNER_CONFIRMATION | Sender preserves `Re:` threading via `reply_to_uuid` (code-proven Run 3/4) |
| 5 | Product/offer profile | `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` | HMZ's own validation offer; anything absent from the KB is UNKNOWN → escalate |
| 6 | CTA (approved) | PENDING_OWNER_CONFIRMATION | Exact booking link / CTA text must be written here by the owner |
| 7 | Reviewer identity | `humza@hmzaiautomation.com` | Matches `reviewer_allowlist` in the Sender launch profile (verified 2026-07-07) |
| 8 | Owned test lead | `hamzahzahid0@gmail.com` (recipient used in prior controlled acceptance) | **Owner to confirm this inbox is still enrolled in campaign `531e64ed`: PENDING_OWNER_CONFIRMATION** |
| 9 | Controlled test plan | Live retest matrix from OPERATION_HANDOFF (session 15/16 owner-action lists): not-now, setup, trust/proof, pricing, high-risk probes | Written; owner must schedule and execute |
| 10 | Runtime proof complete | **NOT COMPLETE** | `docs/RUNTIME_PROOF_CHECKLIST.md` B1–B5 must be executed and dated on the next approved send |
| 11 | Correct sender confirmed | **STALE** — last proven 2026-06-23 (cases c0dd8298/7434572c/c9b32e56); campaign attribution of those sends unconfirmed | Re-prove on next approved send |
| 12 | Correct recipient confirmed | **STALE** — same evidence set as row 11 | Re-prove on next approved send |
| 13 | Same-thread visible body confirmed | **STALE** — same evidence set as row 11 | Re-prove on next approved send. Blank-body now double-blocked in Sender itself (Fable Run 4, versionId `00b52f03`) |
| 14 | No duplicate confirmed | **NOT PROVEN LIVE** — duplicate replay drill never run (code-proven only) | Required before scale (RUNTIME_PROOF_CHECKLIST B5) |
| 15 | Credential-leak scan passed | PASS — `scripts/scan-workflow-exports-for-secrets.py` exit 0, 2026-07-07 (Fable Run 4, post-Sender-deploy) | Rerun in any session touching exports |
| 16 | Stale-script guard | PASS — no `run-local-*`/old fix package used; production exports refreshed 2026-07-07; versionIds: Decision `84b941a4`, HumanApproval `99b4c092`, Sender `00b52f03` | This session |
| 17 | Owner signature + date | **UNSIGNED — PENDING_OWNER_CONFIRMATION** | Written sign-off required here; unsigned record blocks launch |

## Launch blockers (all must clear before this campaign scales)

1. Rows 3, 4, 6, 8 — owner confirmations (no agent may fill these).
2. Row 10 — runtime proof B1–B5 on next approved send.
3. Rows 11–14 — fresh live proof (sender/recipient/thread/body + duplicate replay drill).
4. Row 17 — owner signature.
5. Campaign ID reconciliation confirmation (see `docs/campaign-readiness/README.md`).

Any change to Decision/HumanApproval/Sender after sign-off invalidates rows 10–14 until re-proven.
The Fable Run 4 Sender change (`dfb310f4` → `00b52f03`) means rows 10–14 must be proven against the
CURRENT Sender version — earlier evidence cannot be carried forward.
