# Campaign Readiness Records (per-campaign, Gate S5.7)

**Created:** 2026-07-07 (Fable Run 4). Template and rules: `docs/CAMPAIGN_READINESS_RECORD.md`.
One file per campaign. A missing, incomplete, or unsigned record **blocks launch** for that campaign.

## Campaign ID reconciliation (read before using any record)

Two campaign IDs appear in this repo's history. They are **not** interchangeable:

| Campaign ID | Status | Evidence |
|---|---|---|
| `bcda01f7-21c9-4e12-9849-0a375b548467` | **STALE / SUPERSEDED** | Original designated controlled-live campaign (`BUSINESS_READY_OWNER_INPUTS.md` row `HMZ_CONTROLLED_LIVE_CAMPAIGN_ID`; `config/business-ready.config.json` allowlist). `Apply-SupervisedLivePatch.ps1` explicitly names it `$STALE_CID` and replaced it. |
| `531e64ed-c225-4baf-97a9-4ec90dc34eb0` | **CURRENT validation campaign** | Only campaign in the production Sender launch profile allowlist (node O, versionId `00b52f03`, verified 2026-07-07); carried by live execution 5263 (2026-07-05); named by the Codex Fable Run 3 review as the CRR backfill target. |

**Consequence for evidence:** the last controlled-live send acceptance (2026-06-23, cases
`c0dd8298`/`7434572c`/`c9b32e56`, matrix 4H) predates the supervised-live patch that switched the
campaign ID. Whether those sends ran on `bcda01f7` or `531e64ed` is **PENDING_OWNER_CONFIRMATION**.
Until confirmed, that evidence cannot satisfy CRR rows 11–14 for `531e64ed` — those rows must be
re-proven on the next owner-approved send regardless (they are stale by age anyway).

**Owner selection required before any scale launch:** the owner must confirm in writing, in the
campaign's CRR file, that `531e64ed-c225-4baf-97a9-4ec90dc34eb0` is the campaign being launched and
that `bcda01f7-...` is retired. Do not add `bcda01f7-...` to any allowlist without a new, separate CRR.

## Records

| Campaign | File | Status |
|---|---|---|
| `531e64ed-c225-4baf-97a9-4ec90dc34eb0` (HMZ US B2B validation) | `CRR-531e64ed.md` | **INCOMPLETE — LAUNCH BLOCKED** (owner fields + live re-proof pending) |

No other campaign may be added to `LIVE_CAMPAIGNS` without a new record here, owner-signed.
