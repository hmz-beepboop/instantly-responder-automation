# HMZ Responder Ops Console — Stage 1 (local only)

**Created:** 2026-07-07 (Fable Run 4). One file: `responder-ops-console.html`.

## What it is

A local, offline planning and guidance tool for operating the supervised Instantly responder.
Open it by **double-clicking the HTML file** — it runs entirely in your browser from disk.

- **No backend.** Nothing to install, nothing to run.
- **No network calls.** The page contains no fetch/XHR/WebSocket usage and never contacts n8n,
  Instantly, Google Chat, or anything else. You can open it with Wi-Fi off.
- **No secrets.** It never asks for, stores, or displays API keys, passwords, or webhook URLs.
  Do not paste any into it.
- **No controls.** It cannot start/stop workflows, approve review cases, send emails, or touch
  autonomous settings. All real actions stay in the n8n UI and the review-form flow.

## Modules

| Module | What it does |
|---|---|
| New Campaign Setup | Wizard for all campaign fields + approved-sender dropdown. Computes readiness with hard blocks (missing campaign ID/sender/offer/CTA/reviewer/test lead, unapproved sender, no controlled test planned, secret scan unconfirmed, runtime proof incomplete). Downloads a draft Campaign Readiness Record (JSON + Markdown) and a controlled-test checklist. |
| New Product / Offer Setup | Captures the offer profile (pains, outcomes, proof available/NOT available, allowed/forbidden claims, pricing/booking policy, escalation triggers, tone). Downloads a DRAFT profile — it only becomes usable after owner reconciliation into `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. |
| Draft Style Tuning | Planning sheet for draft style (tone, length, CTA style, voice, avoid-lists, pricing/booking/escalation rules). Feeds the Decision Engine update prompt download. |
| Start Supervised Responder | Step-by-step manual start checklist (guard, versions, harness, CRR, workflow states, probe). The console itself starts nothing. |
| Stop Responder | Safe manual stop procedure (what to deactivate, in what order, what never to do). |
| Diagnose Issue | Symptom picker (11 known issues incl. chat alert missing, review link fails, Sender blocked, Instantly 401/404, blank email, duplicate, watchdog breach, SEND_UNCERTAIN, wrong sender, stale link). Each shows likely cause, immediate stop rule, exact evidence to collect, where to look, what NOT to do, and next action. Downloads a diagnosis record. |
| Runtime Proof Check | Interactive checklist mirroring `docs/RUNTIME_PROOF_CHECKLIST.md` for a controlled send (statusCode 200, SENT state, correct eaccount/recipient/subject, non-empty body, marker, same thread, no duplicate, workflow states). Downloads a dated proof record. |
| SOP Quick Reference | The standing rules on one screen (source of truth, production target, human approval, secrets, suppression, pricing, send safety, rollback, CRR requirement). |

## Readiness statuses

Only these exist: `BLOCKED`, `READY FOR CONTROLLED TEST`, `READY FOR SUPERVISED USE`, and the
permanent banner `NOT APPROVED FOR AUTONOMOUS SENDING`. There is **no** autonomous-ready status
anywhere in the console, by design.

## Generating records

Fill a module's fields and click its download button — files are generated in-browser (Blob download)
and land in your Downloads folder. Outputs: CRR (JSON + MD), product/offer profile (MD), Decision
Engine update prompt (MD), controlled test checklist (MD), runtime proof checklist (MD), diagnosis
record (MD). Downloaded CRRs are **drafts**: the authoritative record lives in
`docs/campaign-readiness/` and needs an owner signature there.

## What it does NOT do (Stage 1 boundaries)

- Not a production dashboard: it shows no live data and has no idea what n8n is doing.
- It cannot verify anything it asks you to confirm (e.g. "secret scan passed") — you run those
  commands yourself in the repo.
- Stage 2 (read-only evidence viewer) and Stage 3 (anything beyond that) are **not built** and not
  authorised by this stage.

## Verification checklist (run after any edit to the console)

1. Double-click opens in a browser; all 8 nav tabs switch correctly.
2. Campaign wizard: with empty fields status = BLOCKED with listed blockers; filling required fields
   + both hard-block checkboxes = READY FOR CONTROLLED TEST; + runtime-proof checkbox = READY FOR
   SUPERVISED USE. Sender "Other" blocks.
3. All 7 download buttons produce files.
4. Diagnose selector renders all 11 symptoms with 6 sections each.
5. `grep -Ei "fetch\(|XMLHttpRequest|WebSocket|api-key|apikey" ops/responder-ops-console.html` → no matches.
6. `grep -i "READY FOR AUTONOMOUS SENDING" ops/responder-ops-console.html` → only as part of
   "NOT APPROVED FOR AUTONOMOUS SENDING" (i.e. no standalone autonomous-ready status).
