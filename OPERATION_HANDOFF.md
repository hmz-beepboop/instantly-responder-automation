# OPERATION_HANDOFF.md

Timestamped log of agent sessions. Most-recent entry first. This file is the authoritative execution state for this repo and takes precedence over Obsidian notes for current project status.

---

## 2026-07-08 01:55 BST — Codex Final Proof-Gate Closure Attempt (BLOCKED — owner-live evidence pending)

**Agent:** Codex
**Objective:** Final owner-guided live-proof evidence collection for CRR / supervised scale gates. Scope was evidence collection only: no workflow deploys, no workflow edits, no Sender trigger, no review approval, no Instantly POST, no Shadow activation, no Gate 2 approval, no autonomous enablement.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest commits `cd5d15f` (`review: final verify Fable Run 4`) and `dadf534` (`final: prepare shadow readiness and local ops console`). Initial worktree was already very dirty with many pre-existing modified files; this session treated them as owner/generated state and changed only this handoff file. Environment variables were presence-checked only; no secret values printed.

**Local checks:** `node --version` -> `v22.22.1`. The exact requested no-arg command `node scripts/FABLE-RUN4-sender-body-gate-node-test.js` failed because the script requires `<extracted_b.js> <extracted_o.js>` arguments. To collect the intended proof without editing the repo, Sender nodes B and O were extracted from `workflows/production_sender_current.json` into `/tmp`, then `node scripts/FABLE-RUN4-sender-body-gate-node-test.js /tmp/hmz_sender_node_b.js /tmp/hmz_sender_node_o.js` returned **77 PASS / 0 FAIL**. `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` returned **483/483 PASS**. `python3 scripts/scan-workflow-exports-for-secrets.py` returned `RESULT: no credential-shaped values found in workflow exports.`

**Production read-only metadata:** production target guard passed (`https://n8n.hmzaiautomation.com/api/v1`). The first metadata GET failed under sandbox DNS; rerun with approved network escalation was read-only only. Production workflow metadata matched required versions: Decision `tgYmY97CG4Bm8snI` versionId `84b941a4-bc6d-4f48-be27-36dad1510c8d` active=true; HumanApproval `9aPrt92jFhoYFxbs` versionId `99b4c092-d78e-4580-a3c8-46dc65ab00cf` active=true; Sender `ePS5uBBxKxhFCYgU` versionId `00b52f03-1ae7-4252-a164-ce08f0c7a77e` active=true; Shadow `aHzLtQiv6G8h1bqD` versionId `ae13bf4e-ee04-438f-9657-3c57183b90a2` active=false. No production writes were made.

**UI / live review confirmation:** BLOCKED / pending owner evidence. No fresh live review case ID, incoming reply text, Google Chat screenshot/confirmation, or review-form confirmation was supplied in this session. Required fields remain: effective classification; original vs effective if corrected; reply mode; AI draft status; draft source; non-empty draft where expected.

**Runtime proof B1-B5 against Sender `00b52f03`:** BLOCKED / pending owner-approved send. No owner approval/send evidence was supplied in this session. B1 Sender node Q `statusCode=200`, B2 terminal `SENT`, B3 correct sender/eaccount, B4 correct recipient/thread/body/marker, and B5 no duplicate/idempotency proof remain unproven live for the current Sender.

**Duplicate replay drill:** LIVE DRILL PENDING. Local/code evidence remains positive: Sender has prior-terminal-state blocking and `no_prior_terminal_send_state` gate before node Q, and duplicate terminal nodes exist. No safe replay case/send key was provided, so no second-attempt proof was collected and no claim of live B5 PASS is made.

**SEND_UNCERTAIN reconciliation:** CODE-PROVEN ONLY / live drill pending. Local Sender export still contains terminal `SEND_UNCERTAIN`, reconciliation poll nodes V/W/W4, and code paths for consecutive single-match vs zero/multiple human review. No safe simulated/live SEND_UNCERTAIN event was available; no duplicate POST was attempted; no live B6 PASS is claimed.

**S2.6 rollback live drill:** PENDING OWNER ACTION. Runbook `docs/S2_ROLLBACK_LIVE_DRILL.md` identifies candidate rule `6e50fd54-ff2a-4d5a-b220-c0c7374edea4` with stop conditions, but no owner confirmation of the exact row capture/deactivate/probe/restore/verify sequence was supplied. No DataTable row was modified by Codex.

**CRR `docs/campaign-readiness/CRR-531e64ed.md`:** BLOCKED / incomplete. Campaign ID `531e64ed-c225-4baf-97a9-4ec90dc34eb0` is the current documented Sender allowlist campaign, but owner confirmations remain pending for approved sender(s), subject/thread pattern, CTA, test lead enrollment, and campaign-ID reconciliation. Rows 10-14 remain pending current-Sender live proof. Owner signature/date is still absent. Launch remains blocked; scale-ready is not claimed.

**Ops Console Stage 1 checklist:** PARTIAL PASS from static/local inspection. `ops/responder-ops-console.html` is a local single HTML file with eight modules, Blob downloads, readiness statuses, diagnosis module, runtime proof module, and no `fetch(` / `XMLHttpRequest` / `WebSocket` / `EventSource` / `sendBeacon` / `api-key` / `apikey` matches. No standalone `READY FOR AUTONOMOUS SENDING` status exists; the permanent banner is `NOT APPROVED FOR AUTONOMOUS SENDING`. A real browser double-click/open and owner walkthrough were not confirmed in this session, so opened-locally/navigation/download UX remains owner-confirm pending.

**Autonomous status:** Shadow inactive; Gate 2 not approved; autonomous disabled; 14-day shadow review not started. High-risk categories remain no-autonomous-send: unsubscribe/suppression/legal/compliance/hostile/no-reply/pricing/booking/proof/trust/ambiguous remain human review, draft-only, or no-send according to policy and future owner allowlists.

**Final readiness percentages:** supervised responder 98%; self-improvement 98%; sender / scale safety 92%; autonomous shadow readiness 70%; ops console stage 1 90% (static/local verified, owner browser walkthrough pending); full scale-ready system 80%. System is **not** supervised scale-ready because current-Sender live send proof, duplicate replay proof, S2.6 live rollback, and signed CRR remain missing. No consolidated repair run is needed from this evidence; the blocker is owner-live proof/action, plus one minor test-run usability defect: the body-gate script's no-arg command fails despite docs/owner instructions expecting standalone execution.

**Regression Safety Check:** no Sender trigger by Codex; no Instantly POST by Codex; no production write; no workflow deploy; no Shadow/Gate2/autonomous change; no stale README evidence used; no unrelated files staged.

---

## 2026-07-08 01:08 BST — Codex Final Review: Fable Run 4 (PASS)

**Agent:** Codex
**Objective:** Final skeptical review of Fable Run 4 before owner-live proof actions. Review-only: no workflow deploy, no production writes, no live email tests, no Sender trigger, no Shadow activation, no Gate 2 approval, no autonomous enablement, no Ops Console edits.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest Run 4 commit `dadf534` (`final: prepare shadow readiness and local ops console`). Worktree remained very dirty with many pre-existing modified backup/output/workflow files; nothing was staged before this handoff update. Required process check found only the current `pwsh` shell, no orphaned Fable Run 4 node/python test process. Environment variables were presence-checked only; no secret values printed.

**Checks run:** required git pre-flight; required file reads only; production target guard passed; read-only production metadata GETs for Decision/HumanApproval/Sender/Shadow; `node scripts/FABLE-RUN4-sender-body-gate-node-test.js` attempted but `node` is unavailable in this shell; `python` shim unavailable, so the same scripts were run with `python3`; `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` -> **483/483 PASS** with P22 static fallback for node absence; `python3 scripts/scan-workflow-exports-for-secrets.py` -> no credential-shaped values; Ops Console network/API grep via PowerShell -> no matches; scoped JSON comparison of Sender current vs backup.

**Protected workflow verdict:** Decision unchanged locally and in production at `84b941a4-bc6d-4f48-be27-36dad1510c8d`; HumanApproval unchanged locally and in production at `99b4c092-d78e-4580-a3c8-46dc65ab00cf`; Sender changed from backup `dfb310f4-901a-4d76-81dc-8f5d4ad13552` to local/production `00b52f03-1ae7-4252-a164-ce08f0c7a77e`; Shadow production active=false (`ae13bf4e-ee04-438f-9657-3c57183b90a2`). No production writes were made.

**Sender body-gate verdict:** PASS. Structured diff showed only Sender nodes `B. Re-run Send & Suppression Gates`, `O. Live Send Gate Evaluation (14 Gates)`, and two sticky notes changed; workflow connections/settings/active state unchanged. Node B blocks blank body before ownership acquisition via C false -> C2. Node O adds the 15th `draft_body_non_empty` gate immediately before P/Q; P false -> P2, so POST and SENT terminal are unreachable on body failure. Node Q POST body expression, send ownership, SENT terminal, retry classification, and reconciliation nodes were byte-for-byte unchanged from backup. Body normalization covers comments/marker, HTML tags, nbsp, zero-width chars, and whitespace. HumanApproval R0 still treats recoverable Sender blocks as same-review-link retryable. Limitation: the 77/77 standalone Node.js behavioural test could not be re-run here because `node` is not installed; Fable's reported 77/77 result is supported by the real-node test script, P22 static checks, and direct export inspection.

**Ops Console verdict:** PASS. `ops/responder-ops-console.html` is a single local HTML file with 8 modules, no backend, no fetch/XHR/WebSocket/EventSource/sendBeacon/API references, no secret inputs, no workflow activation/case approval/sending/autonomous controls, and no `READY FOR AUTONOMOUS SENDING` status. It includes New Campaign Setup with approved sender list, Product/Offer setup, Draft Style tuning, start/stop guidance-only modules, Diagnose Issue with 11 issue types, Runtime Proof, SOP reference, readiness statuses `BLOCKED` / `READY FOR CONTROLLED TEST` / `READY FOR SUPERVISED USE` plus permanent `NOT APPROVED FOR AUTONOMOUS SENDING`, and all 7 Blob-download outputs.

**Autonomous-shadow verdict:** PASS for disabled readiness only. `docs/AUTONOMOUS_SHADOW_READINESS.md` states default disabled, Shadow not activated, Gate 2 NOT APPROVED/unsigned, 14-day plan with thresholds, disallowed categories, escalation rules, rollback/kill switch, owner signoff, and no executable autonomous activation without explicit owner approval.

**Campaign/S2 proof verdict:** PASS for documentation, owner-live pending. `docs/S2_ROLLBACK_LIVE_DRILL.md` is an owner runbook and does not claim completion. CRR docs mark unknowns pending, document the `bcda01f7` vs `531e64ed` campaign-ID conflict, keep launch blockers explicit, and leave the `531e64ed` record incomplete/unsigned.

**Remaining owner-live actions:** next approved send runtime proof B1-B5 against Sender `00b52f03`; duplicate replay and SEND_UNCERTAIN drills before volume increase; S2.6 rollback live drill; complete/sign `docs/campaign-readiness/CRR-531e64ed.md` including campaign-ID confirmation; confirm Run 3 UI/chat fields on the next live case; owner walk-through of `ops/README.md`.

**Final readiness percentages:** supervised responder 98%; self-improvement 98%; sender / scale safety 92%; autonomous shadow readiness 70%; ops console stage 1 100%; full scale-ready system 80%.

**Regression Safety Check:** no Sender trigger, no Instantly POST from this review, no workflow deploy, no production write, no Shadow activation, no Gate 2 approval, no autonomous enablement, no Ops Console edit, no broad repo/archive scan, no secrets printed.

---

## 2026-07-07 — Fable Run 4: Sender Blank-Body Defense-in-Depth + Shadow Readiness (disabled) + Ops Console Stage 1 (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Absorb the Codex Run 3 PASS review; close the commissioned Sender blank-body gap; backfill the Campaign Readiness Record; write the S2 live-drill runbook; consolidate autonomous shadow readiness (disabled only); build Ops Console Stage 1; update all governing docs. Owner explicitly approved this run, including the Sender defense-in-depth patch. No autonomous activation, no Gate 2 approval, no Shadow activation, no live sends.

**Baseline used:** review commit `0dd459c`, implementation commit `c558263`, branch `codex/5q-context-token-forensic-20260705`, clean worktree. Production versionIds verified matching local exports BEFORE any change (guard passed): Decision `84b941a4`, HumanApproval `99b4c092`, Sender `dfb310f4`, Shadow `aHzLtQiv6G8h1bqD` active=false.

**Sender blank-body defense-in-depth (SS.4 — DEPLOYED):** Gap proven by read-only audit: node A never checks body; node B's variable gate passes when `draft_text === null`; node O's 14 gates have no body check; node Q's POST body coalesces to `''` (`draft.draft_text || body.edited_reply_text || ''`) — a blank POST was structurally possible, prevented only upstream (HumanApproval Node N `draft_text_required`). Also verified Sender is invoked ONLY from HumanApproval "Q. Reply Sender Handoff (Approved)" — no suppression-only path enters Sender, so the block cannot break a legitimate no-send flow. **Patch (nodes B + O only, marker `FABLE-RUN4-SENDER-BODY-GATE`):** shared `hmzSenderVisibleBodyText` normalization (strips HTML comments incl. the hmz-send-key marker, tags, nbsp entities/chars, zero-width chars, collapses whitespace); node B gate `draft_body_gate_passed` blocks BEFORE lock acquisition (C false → C2; reason `draft_body_missing_or_blank` + explicit fix instruction; HumanApproval R0 classifies it form-retryable → same review link, fix-and-reapprove works, no lock consumed); node O 15th gate `draft_body_non_empty` blocks immediately BEFORE the POST (P false → P2, reason `DRAFT_BODY_MISSING_OR_BLANK`). Both mirror node Q's exact effective-body precedence. Idempotency, retry, reconciliation, sender-mapping all untouched (P22.14-15). A second narrow deploy replaced the dangerously stale Sender sticky notes (claimed DRY_RUN=true/inactive/no-HTTP) with truthful live-capable text — the Codex-flagged truthfulness risk.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Sender | `ePS5uBBxKxhFCYgU` | `dfb310f4` | `aad8301e` → `00b52f03` | Run 4 blank-body gates (nodes B+O), then truthful sticky notes |

Backup: `workflows/sender_backup_dfb310f4_pre_run4_blank_body_gate.json`. Local export refreshed from production after each deploy (versionId verified); active=true preserved; Shadow re-confirmed inactive post-deploy. Patch script: `scripts/FABLE-RUN4-apply-sender-blank-body-gate.py`. Behavioural proof: `scripts/FABLE-RUN4-sender-body-gate-node-test.js` runs the REAL patched node code in Node.js — **77/77 PASS** (missing/empty/whitespace/marker-only/html-empty/nbsp/zero-width all BLOCK at both nodes with reasons; valid text, text+marker, and edited_reply_text fallback all pass; unresolved-variable gate unaffected; 15 gates total). No Sender trigger, no Instantly POST at any point.

**Harness:** **483/483 PASS** (was 463/463; P22 added 20 checks: markers, gate fields, passed-expression wiring, 15-gate count, node --check both nodes, the 77/77 behavioural run, block-point connection topology (pre-lock + pre-POST), node Q unchanged, idempotency nodes untouched, launch profile unchanged, C2/R0 retryability reasoning, upstream Node N retained, no-POST envelope). Re-run green against the production-refreshed export after BOTH deploys. Secrets scan PASS after final export refresh.

**Campaign readiness (Objective C):** `docs/campaign-readiness/README.md` documents the campaign-ID reconciliation with evidence: `bcda01f7-21c9-4e12-9849-0a375b548467` is STALE/SUPERSEDED (old BUSINESS_READY inputs/config; named `$STALE_CID` by `Apply-SupervisedLivePatch.ps1`); `531e64ed-c225-4baf-97a9-4ec90dc34eb0` is the CURRENT campaign (only entry in the live Sender allowlist; live exec 5263). The 2026-06-23 send evidence may predate the ID switch — owner confirmation required. `docs/campaign-readiness/CRR-531e64ed.md` is a backfilled but **INCOMPLETE, UNSIGNED** record: rows 1/2/7/15/16 evidence-backed; rows 3/4/6/8/17 PENDING_OWNER_CONFIRMATION; rows 10-14 require fresh live proof against Sender `00b52f03`. **Launch blocked until complete + signed. Nothing was invented.**

**S2 rollback drill (Objective D):** `docs/S2_ROLLBACK_LIVE_DRILL.md` — owner runbook (capture row → deactivate `6e50fd54` in Q12 `sl_rule_candidates` DataTable `CSdiTjXfi0tl0oZF` → probe → restore → verify probe → log), with stop conditions incl. "do not proceed if the rule row is unclear". **No production rule was modified this session; live drill remains owner-action; S2.6 stays PARTIAL.**

**Autonomous shadow readiness (Objective E — disabled only):** `docs/AUTONOMOUS_SHADOW_READINESS.md` consolidates the SR1-SR9 readiness checklist, 14-day review plan (+ restart rules), metrics/thresholds (≥98% agreement, 0 critical mismatches final 7 days, 0 false-safe on disallowed categories), safe vs disallowed categories, escalation rules, rollback + one-step kill switch, evidence + weekly templates, and the Gate 2 checklist **explicitly NOT APPROVED (G2.1-G2.7 all NOT MET/UNSIGNED)**. Nothing activated; Shadow remains inactive (API-confirmed); no config flag was flipped.

**Ops Console Stage 1 (Objective F):** `ops/responder-ops-console.html` (single self-contained file, double-click to open) + `ops/README.md`. All 8 modules built: New Campaign Setup (full field set, 24-eaccount approved-sender dropdown + blocking "Other", hard blocks, readiness scoring), Product/Offer Setup (16 fields, DRAFT-only output), Draft Style Tuning, Start/Stop guidance, Diagnose Issue (11 symptoms × 6 sections each), Runtime Proof Check (11 items), SOP Quick Reference. 7 Blob downloads (CRR JSON/MD, offer profile MD, Decision Engine update prompt MD, controlled test MD, runtime proof MD, diagnosis MD). Statuses: BLOCKED / READY FOR CONTROLLED TEST / READY FOR SUPERVISED USE + permanent NOT APPROVED FOR AUTONOMOUS SENDING banner. Verified: no fetch/XHR/WebSocket/external resources/API-key inputs; "READY FOR AUTONOMOUS SENDING" absent; console JS `node --check` clean. **It is an operator aid only — it reads nothing from and controls nothing in production. Stage 2/3 NOT built.**

**Docs updated:** `docs/SCALE_READY_ACCEPTANCE_GATES.md` (SS.4 closed dual-layer; S5.7 backfilled-incomplete; honest position rewritten for Run 4), `docs/RUNTIME_PROOF_CHECKLIST.md` (Sender-version invalidation note; new B8), `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md` (reference state; item 11 gap closed; item 15 Stage 1 built; **new item 17: stale embedded workflow documentation fault class**), `docs/CAMPAIGN_READINESS_RECORD.md` (points to per-campaign records).

**Remaining owner-only proof (unchanged in nature, updated in target):** (1) next approved send runtime proof B1-B5 **against Sender `00b52f03`**; (2) S2.6 live rollback drill per the new runbook; (3) duplicate replay + SEND_UNCERTAIN drills (B5/B6) before any volume increase; (4) complete + sign `CRR-531e64ed.md` incl. campaign-ID confirmation; (5) confirm Run 3 UI fields on the next live case (S1.7/A5/A9); (6) walk the Ops Console verification checklist in `ops/README.md`.

**Safety envelope:** production guard before every API call; only Sender nodes B/O + sticky notes changed; Decision/HumanApproval untouched; Sender never triggered; no Instantly POST; no live email tests; Shadow inactive (API-confirmed post-deploy); Gate 2 unapproved; autonomous disabled; no secrets in any file/log; no archive scan.

### Run 4 additions to the PERMANENT ANTI-REGRESSION LEDGER (items 1-12 in the Run 3 entry below remain in force, unchanged)

13. **Embedded workflow notes must be truthful:** any deploy changing a workflow's operating posture (DRY_RUN, allowlists, active state, gate count) must update that workflow's sticky notes in the same deploy. Never trust a sticky note over the executable config; never leave one contradicting it (fault ledger item 17).
14. **Sender blank-body gates are load-bearing:** node B `draft_body_gate_passed` (pre-lock) and node O `draft_body_non_empty` (pre-POST, 15th gate) must never be removed or weakened; they mirror node Q's effective-body precedence — if Q's body expression ever changes, both gates change with it (harness P22 enforces).
15. **Ops Console stays powerless:** Stage 1 is local/no-API/no-controls; no session may add network calls, credential inputs, workflow controls, case approval, sending, or any autonomous-ready status to it without explicit owner commissioning of Stage 2 with its own safety review.
16. **CRR discipline:** per-campaign records live in `docs/campaign-readiness/`; an incomplete or unsigned record blocks launch; `bcda01f7-...` is a stale campaign ID — never allowlist it without a new CRR; send-path evidence never carries across Sender versionId changes.

---

## 2026-07-07 07:27 BST — Codex Review: Fable Run 3 Scale Hardening (PASS)

**Agent:** Codex
**Objective:** Review Fable Run 3 cheaply before any Fable Run 4 work. Review-only: no workflow deploy, no production writes, no live email tests, no Sender trigger, no autonomous/Gate 2/Shadow/Ops Console work.

**Baseline used:** branch `codex/5q-context-token-forensic-20260705`; latest Run 3 commit `c558263` (`hardening: close Run 3 scale safety gates`). `git show --stat --oneline c558263` matched the reported Run 3 surface: docs/reports/scripts, HumanApproval export/backup, fresh Sender export; no Decision export change. Initial worktree was already very dirty with many unrelated modified backup/output/archive-style files; nothing was staged. Review treated those as pre-existing and ignored them.

**Checks run:** required git pre-flight; env-var presence check without values; required file reads; `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` -> `463/463 PASS`; `python3 scripts/scan-workflow-exports-for-secrets.py` -> no credential-shaped values found; local workflow metadata parsed from exports; production guard passed; read-only production workflow metadata checked; read-only Review Cases rows checked for `case-e97b60ea` and `case-ea98043d`. No production writes.

**Changed files reviewed:** `OPERATION_HANDOFF.md`; `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`; `docs/SCALE_READY_ACCEPTANCE_GATES.md`; `docs/RUNTIME_PROOF_CHECKLIST.md`; `docs/CAMPAIGN_READINESS_RECORD.md`; the three listed reports; `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py`; `scripts/SL-PHASE-5Q-RUN3-apply-ui-visibility-fix.py`; `scripts/scan-workflow-exports-for-secrets.py`; `workflows/production_humanapproval_current.json`; `workflows/production_sender_current.json`; `workflows/production_decision_current.json`. Protected workflow result: Decision unchanged (`84b941a4`), Sender unchanged logically (`dfb310f4`, new export only), Shadow inactive, no autonomous/Gate 2/Ops Console changes found.

**Production read-only verification:** Decision `84b941a4-bc6d-4f48-be27-36dad1510c8d` active and matches local; HumanApproval `99b4c092-d78e-4580-a3c8-46dc65ab00cf` active and matches local; Sender `dfb310f4-901a-4d76-81dc-8f5d4ad13552` active and matches local; Shadow `aHzLtQiv6G8h1bqD` active=false. Production target guard passed before the API reads.

**UI confirmation cases:** owner-confirmed UI evidence was independently row-checked read-only. `case-e97b60ea`: token/review path derivable, non-empty draft, baseline/effective `INFORMATION_REQUEST/PROOF_REQUEST`, `reply_mode=AI_DRAFT_APPROVAL`, `draft_source_raw=ai_supervised`, `ai_attempt.ok=true`, rule `ea15095a`, no fallback mislabel. `case-ea98043d`: token/review path derivable, non-empty draft, baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` -> effective `AMBIGUOUS/NON_PRIORITY`, `reply_mode=AI_DRAFT_APPROVAL`, `draft_source_raw=ai_supervised`, `ai_attempt.ok=true`, rule `6e50fd54`, no fallback mislabel. This closes the Run 3 pending UI confirmation item for Original-vs-Effective / reply mode / AI status visibility.

**Sender/send-path review:** Sender is live-capable for the allowlisted campaign (`DRY_RUN=false`, live campaign allowlist present), unchanged by Run 3, and has pre/post sender/recipient/thread checks, `hmz-send-key`, sidecar acquire/terminal-state idempotency, SEND_UNCERTAIN reconciliation without blind second POST, retry handling for 429/5xx, and terminal handling for 400/401/402/403/404. Known gap is accurately documented: Sender's own live gates do not independently reject blank `draft.draft_text`; blank-body prevention is upstream in HumanApproval Node N (`draft_text_required`). This is acceptable for remaining owner-only controlled live proof, but blocks scale until runtime checklist B1-B5 and duplicate/reconciliation proof are completed or a targeted Sender defense-in-depth patch is explicitly commissioned.

**Risks / uncertainties:** large pre-existing dirty worktree remains; Sender export contains a stale sticky note saying DRY_RUN-only/inactive while executable config is live-capable; live Sender evidence from 2026-06-23 is stale; duplicate replay and SEND_UNCERTAIN reconciliation are code-proven but not live-drilled; S2 rollback drill remains owner-live pending; CRR template has no completed signed campaign record.

**Required owner actions:** complete/backfill Campaign Readiness Record for campaign `531e64ed-c225-4baf-97a9-4ec90dc34eb0`; perform owner-approved runtime proof on next send using `docs/RUNTIME_PROOF_CHECKLIST.md` B1-B5; run S2 live rollback/deactivation drill; keep Shadow/Gate 2/autonomous/Ops Console untouched until explicitly commissioned.

**Next recommended step:** Human/Fable owner-only live proof actions first. After those are recorded, Fable Run 4 may proceed with autonomous shadow readiness + Stage 1 Ops Console scaffold, still with no Gate 2 approval or autonomous activation unless owner explicitly approves.

**Regression Safety Check:** no Sender trigger, no Instantly POST from this review, no workflow deploy, no production write, no Shadow activation, no Gate 2 approval, no autonomous work, no Ops Console build, no broad archive scan.

---

## 2026-07-07 — Fable Run 3: UI/Reporting Visibility Fix + S1/S-SEND/S5 Scale Gates + Sender Audit (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Absorb the Codex live-row evidence (five cases), fix the proven UI/reporting mismatch, audit S1 supervised gate + Sender/send-path/idempotency (read-only), scaffold S5 multi-campaign gates, and write the permanent anti-regression ledger below.

**Live row confirmation (read-only REST, table `WMTmI6UNjZZgSU3h`, guard passed):** all five rows re-verified. `case-58e6b3b0` (trust → PROOF_REQUEST AI draft, rule ea15095a injected, non-empty summary) PASS. `case-5e2fbcbe` (setup → OFFER_EXPLANATION AI draft, no PROOF hijack) PASS. The three "not-now failures" (`4a5596a0`/`07bd8bb5`/`659d1e01`) are **backend successes**: baseline `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` → effective `AMBIGUOUS/NON_PRIORITY` via rule `6e50fd54`, `reply_mode=AI_DRAFT_APPROVAL`, `ai_attempt.ok=true`, drafts present, `ai_upgrade_eligible=true`. **No classifier/upgrade/style patch was made for these rows — none was needed.** Session 16 S2 work is live-proven.

**Proven UI/reporting defect (fixed — SL-PHASE-5Q-RUN3-UIVIS, HumanApproval nodes J + chat D only):** (a) Google Chat printed "Micro intent: N/A" (fallback chain missed `recommended_action_plan.micro_intent`); (b) review form had no Original-vs-Effective classification display, so top-level baseline `AMBIGUOUS` read as final; (c) correction section labelled the EFFECTIVE micro intent "Original micro intent" (untruthful); (d) no explicit reply-mode / AI-draft-status line. New form/chat content: "Classification corrected by approved learning" block (Original (detected) vs Effective (used for drafting) + applied correction rule ID + warning that top-level category may show baseline), "Reply mode: ... | AI draft status: ..." line (status derived from `draft_source_raw` + `ai_attempt.ok` — fallback can never display as AI success), truthful "Current effective ..." labels, chat "Micro intent (effective)" + correction line + reply mode + "(AI draft passed validation)". Offline proof: patched Node J executed against the REAL case-4a5596a0 row — 11/11 assertions PASS; chat node 6/6.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `0054f20b` | `99b4c092` | Run 3 UI/reporting visibility fix (nodes J + chat D) |

Decision unchanged (`84b941a4`). Backup: `workflows/humanapproval_backup_0054f20b_pre_run3_ui_visibility.json`. Local export refreshed from production post-deploy (versionId verified). Patch script: `scripts/SL-PHASE-5Q-RUN3-apply-ui-visibility-fix.py`.

**Sender read-only audit (S-SEND gate, NOT modified, NOT triggered):** fresh production export captured to `workflows/production_sender_current.json` (Sender `ePS5uBBxKxhFCYgU`, versionId `dfb310f4`, active; the old `03_reply_sender_validation.json` is stale — do not use it as Sender truth). Findings: correct-sender/recipient/thread enforced pre-send (14 gates: workspace/campaign/sender/reviewer allowlists, DRY_RUN flag, lock, suppression, no-prior-terminal-state) AND post-send (`isValidSentEmailObject` verifies eaccount/recipient/subject, rejects unexpected cc/bcc → SEND_UNCERTAIN); `hmz-send-key` marker embedded; duplicates blocked by atomic hmz-send-state acquire + prior-terminal-state gate; SEND_UNCERTAIN terminal (never blindly retried) with reconciliation needing 2 consecutive single matches (zero/multiple → human review); 400/401/402/403/404 terminal, 429/5xx retry max 3 with retry-after cap 5s. **No critical defect → no Sender patch.** Accepted gap (ledger item 11): Sender gates don't re-check non-empty body (enforced upstream in HumanApproval Node N `draft_text_required`).

**Harness:** 463/463 PASS (was 425/425; P21 added 38 tests: the three exact live not-now phrases → NON_PRIORITY + upgrade preconditions; UI-visibility markers + truthful labels; node --check on both patched nodes; Decision invariants unchanged; negative controls booking/pricing/proof/unsubscribe/legal/hostile; never-upgrade protections; no-Instantly-POST). Re-run green against production-refreshed exports.

**New docs/scripts:** `docs/RUNTIME_PROOF_CHECKLIST.md` (runtime source of truth, S1/S-SEND/S2 proof matrix), `docs/CAMPAIGN_READINESS_RECORD.md` (S5 per-campaign launch blocker template), `scripts/scan-workflow-exports-for-secrets.py` (credential-leak scan — PASS 2026-07-07). `docs/SCALE_READY_ACCEPTANCE_GATES.md` updated (S1.4 now PASS on live evidence; new S1.7, S-SEND, S5.7-S5.9). Fault ledger updated (item 11 audit evidence, new item 16).

**Safety envelope:** production guard passed before every API call; Sender untouched/not triggered; no Instantly POST; no live email tests; Shadow `aHzLtQiv6G8h1bqD` inactive (API-confirmed post-deploy); Gate 2 unapproved; autonomous disabled; Ops Console not built.

**Owner actions:** (1) open the next review case + Google Chat message and confirm the new Original-vs-Effective / Reply mode / AI draft status fields render; (2) live rollback drill (S2.6): flip one Q12 rule to `deactivated`, send a probe, restore; (3) on the next approved send, re-prove RUNTIME_PROOF_CHECKLIST B1-B4.

### PERMANENT ANTI-REGRESSION LEDGER (do not regress — details in `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md`)

1. **Stale sources:** Never execute from README, old dry-run docs, old prompt packs, old fix packages, archived notes, or stale local exports. `OPERATION_HANDOFF.md` + production-refreshed exports are truth. `03_reply_sender_validation.json` is stale; Sender truth is `production_sender_current.json`. Refresh + commit exports after every deploy (ledger 3).
2. **Wrong target:** Production is `https://n8n.hmzaiautomation.com/api/v1` only. Run `scripts/assert-hmz-production-target.ps1` first. No localhost/Docker unless owner says "local dev" (CLAUDE.md hard rule).
3. **Credentials:** No secrets in files/exports/logs/chat. Run `scripts/scan-workflow-exports-for-secrets.py` in any session touching exports (PASS 2026-07-07). Missing `OPENAI_API_KEY` must stay a truthful `AI_PROVIDER_CONFIG_MISSING` fallback (ledger 2).
4. **Code-node string patches:** Node J syntax crash (session 7) and Node D join literal-newline crash (case-68110963) both shipped from string patching. `node --check` + literal-newline guard are mandatory before any Code-node deploy (ledger 4, 13; P11/P17/P19/P21).
5. **Review render/link invariants:** newest review link only; stale link after SENT blocked (already-sent banner); blocked submits keep the same link + exact reason; valid HUMAN_ONLY/`ai_failed_fallback` cases are REAL reviews, never diagnostic fallback (P13/P14); diagnostic fallback only for genuinely missing context; Google Chat payload must remain well-formed text (ledger 7).
6. **Classification protections:** trust/proof variants (trust/trustworthy/credible/believe/evidence) stay PROOF_REQUEST; NON_PRIORITY promotion blocked on proof/trust replies; PROOF_REQUEST promotion requires trust/proof signal (no hijack of setup questions); booking stays deterministic (no hyper-literal instruction pasting — GAP-1); pricing stays PRICING_REQUEST/HUMAN_ONLY with guidance consumed (GAP-2); not-now dense coverage per P7/P18/P20/P21 (ledger 5, 6).
7. **Upgrade rules:** deterministic/human→AI upgrades ONLY from allowlist {PROOF_REQUEST, NON_PRIORITY, NOT_NOW}, ONLY with ≥1 active form-created style rule for the EFFECTIVE classification; classification correction alone never upgrades; unsubscribe/legal/hostile/suppress/no-reply/pricing/booking never upgrade; NOT_NOW/PROOF fallbacks are non-null (textarea never empty) (ledger 8; P20/P21).
8. **Truthful metadata:** `reply_mode`/`reply_draft_status` must match the real draft; fallback drafts are never labelled AI; "passed validation" requires `ai_attempt.ok===true`; multi-rule injection never claims per-rule impact (attribution stays conservative); active-learning counters must not over- or under-credit (ledger 9, 16).
9. **UI truthfulness (Run 3):** baseline row category must never present as the effective classification; Original-vs-Effective + applied rule + reply mode + AI draft status must stay visible (P21.10-19). The not-now "failure" report was a visibility artifact — check reporting before patching classifiers.
10. **Validator honesty:** style-only rejections (dense paragraph) are reflowed whitespace-only and re-validated, never presented as safety failures; banner names exact failed checks; FORBIDDEN_AI negation-window gaps (10c) stay UNPATCHED until a live case exists (ledger 10).
11. **Send safety:** same sender as inbound, original lead recipient, same thread, non-empty body (enforced at approval), `hmz-send-key` marker, duplicate prevention via send-state lock + terminal-state gate, SEND_UNCERTAIN never blindly retried, reopened-case repeat sends stay manual (S-SEND gate; ledger 11, 12).
12. **Process:** rollback = flip Q12 rule `status` (documented + offline-drilled; live drill pending); old acceptance harness is never sole runtime evidence — `docs/RUNTIME_PROOF_CHECKLIST.md` is; Shadow stays inactive, Gate 2 stays unapproved, autonomous stays disabled without explicit owner sign-off; Ops Console, when commissioned, starts as a local no-API wizard.

---

## 2026-07-07 - Codex Evidence Pass: Live Row Collection Before Fable Run 3 (COMPLETE)

**Agent:** Codex
**Objective:** Read-only live Review Case row evidence collection before Fable Run 3. No patch, deploy, live email test, Sender touch, autonomous work, Gate 2 approval, or Ops Console work.

**Baseline used:** Latest handoff entry `2026-07-07 - Codex Review/Triage: Fable Run 2 S2 Live Retest`; branch `codex/5q-context-token-forensic-20260705`; latest commit before this evidence update `5d3dde6`; latest Fable implementation commit `9ed8aa4`; Decision local export versionId `84b941a4-bc6d-4f48-be27-36dad1510c8d`; HumanApproval local export versionId `0054f20b-2090-41e4-be76-95e8b71921de`; prior harness baseline `425/425 PASS`.

**Env/API checks:** Required git pre-flight run. Production guard passed via `pwsh -File ./scripts/assert-hmz-production-target.ps1` and confirmed `https://n8n.hmzaiautomation.com/api/v1`. Env vars checked without printing values: `HMZ_N8N_API_KEY`, `N8N_API_KEY`, `N8N_API_URL`, and `N8N_BASE_URL` all SET. First sandboxed REST read failed with `Permission denied`; the same read-only production DataTables requests succeeded with approved escalation. Review Cases table `WMTmI6UNjZZgSU3h` was read via n8n REST only. No production writes.

**Files checked:** `OPERATION_HANDOFF.md`, `AGENTS.md`, `workflows/production_decision_current.json`, `workflows/production_humanapproval_current.json`. Workflow metadata matched the baseline versionIds above. No full repo scan.

**Row findings:**
- `case-58e6b3b0`: incoming reply `Anything to establish trust between us and your company?`; original/effective `INFORMATION_REQUEST / PROOF_REQUEST`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, model `gpt-5.4-mini`, no validation errors, no fallback; active learning found 29, eligible/applied style rule `ea15095a-26f3-4a12-ad2d-ff0fe2d759cc`; no classification correction; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-5e2fbcbe`: incoming reply `Mind breaking down what the setup actually is?`; original/effective `INFORMATION_REQUEST / OFFER_EXPLANATION`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, model `gpt-5.4-mini`, no validation errors, no fallback; active learning found 29, eligible style rules `41a9c35b-f2ad-40a5-ae85-01514f0b869a` and `48e10cac-69a0-4ec7-9c35-42d3675812e6`; no classification correction; `ai_upgrade_eligible=false`, reason `DRAFT_POLICY_ALREADY_AI`.
- `case-4a5596a0`: incoming reply `Not now. Maybe later`; top-level row category remains `AMBIGUOUS`, but original classification `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` was corrected to effective `AMBIGUOUS / NON_PRIORITY`; draft policy/source `AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING` / `ai_supervised_with_form_learning`; reply mode `AI_DRAFT_APPROVAL`; draft present; AI attempted `ok=true`, no validation errors, no fallback; active learning found 29; eligible rules `6e50fd54-ff2a-4d5a-b220-c0c7374edea4`, `877c3d75-ad83-4929-a9ae-b910030836e0`, `cdada69d-63a0-471d-801b-3cf3d7ddd1bd`; applied classification rule `6e50fd54-ff2a-4d5a-b220-c0c7374edea4`; style rules eligible/injected but per-rule draft impact attribution remains multi-rule unproven; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-07bd8bb5`: incoming reply `I can't right now.`; top-level row category remains `AMBIGUOUS`, but original `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` became effective `AMBIGUOUS / NON_PRIORITY`; same NON_PRIORITY rule path as `case-4a5596a0`; draft present; AI attempted `ok=true`, no validation errors, no fallback; reply mode `AI_DRAFT_APPROVAL`; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.
- `case-659d1e01`: incoming reply `I don't have time right now. Maybe later`; top-level row category remains `AMBIGUOUS`, but original `AMBIGUOUS / AMBIGUOUS_SHORT_REPLY` became effective `AMBIGUOUS / NON_PRIORITY`; same NON_PRIORITY rule path as `case-4a5596a0`; draft present; AI attempted `ok=true`, no validation errors, no fallback; reply mode `AI_DRAFT_APPROVAL`; `ai_upgrade_eligible=true`, reason `ACTIVE_DRAFT_LEARNING_RULES_PRESENT_FOR_SAFE_CLASS`.

**Exact root-cause hypothesis:** The three alleged not-now failures are not live AI-draft failures and not upgrade failures. They are most likely a reporting/UI expectation mismatch: the row-level `category` remains baseline `AMBIGUOUS`, while the persisted effective classification and review decision path use `AMBIGUOUS / NON_PRIORITY`, apply rule `6e50fd54`, inject NON_PRIORITY draft guidance, and produce successful AI drafts. Root cause bucket: reporting/UI issue. Not supported by live evidence: classifier phrase coverage gap, classification-rule eligibility/scope gap, effective-classification timing issue, upgrade allowlist issue, style-rule absence, or legitimate human-only/block case.

**Exact Fable Run 3 requirements:** Do not spend Fable time patching classifier/upgrade/style coverage for these five rows unless new contrary evidence appears. Fix target should be HumanApproval/reporting visibility if the owner expects the displayed classification to show the effective classification/micro intent and AI attempt status. Harness additions: exact phrases from the three not-now rows must assert effective `AMBIGUOUS / NON_PRIORITY`, `AI_DRAFT_APPROVAL`, `ai_attempt.ok=true`, no fallback, draft present, rule `6e50fd54` applied, and NON_PRIORITY style rules eligible/injected. Add UI/reporting assertions that baseline row category cannot be mistaken for final effective classification. Negative controls: booking/setup, pricing, proof/trust, unsubscribe/legal/hostile/no-reply, and human-only blocked classes must not be swept into NON_PRIORITY or upgraded. Live retests: the three exact not-now phrases above, one known good trust/proof case, one setup/OFFER_EXPLANATION case, one pricing exclusion, and one high-risk/human-only protection case; verify both row metadata and review UI labels.

**Regression safety check:** Sender untouched and not triggered; no Instantly POST; Shadow status not changed from inactive baseline; Gate 2 unapproved; autonomous disabled; no broad rewrites/deletions; no stale README/local dry-run assumptions used. Existing dirty worktree contains many unrelated modified files; this session should commit only `OPERATION_HANDOFF.md`.

---

## 2026-07-07 — Codex Review/Triage: Fable Run 2 S2 Live Retest (PARTIAL — live rows not API-rechecked)

**Agent:** Codex
**Objective:** Review Fable Run 2 / Session 16 cheaply and triage the owner's new live retest results without patching, deploying, touching Sender/autonomous/Gate 2, or running live email tests.

**Baseline used:** Latest valid handoff entry remains Session 16. Branch `codex/5q-context-token-forensic-20260705`; latest commit before this handoff update was `9ed8aa4` (`SL-PHASE-5Q session 16: S2 upgrade engine + PROOF promotion gate + truthful metadata`). Local exports report Decision `84b941a4-bc6d-4f48-be27-36dad1510c8d` and HumanApproval `0054f20b-2090-41e4-be76-95e8b71921de`. `git diff --ignore-space-at-eol` showed no semantic local diff for the current Decision/HumanApproval exports despite line-ending noise on `workflows/production_decision_current.json`. HumanApproval was not changed by commit `9ed8aa4`; Sender was not in the Session 16 changed-file set.

**Checks run:** Required git pre-flight run (`git status --short`, branch, log, `git show --stat --oneline 9ed8aa4`, remote). Read required source files only. Production target guard passed via `pwsh -File ./scripts/assert-hmz-production-target.ps1`. Local harness run with `python3 scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` returned `425/425 PASS`; JS syntax checks used the harness static fallback because `node` is unavailable in this shell. No n8n REST row/metadata checks were possible because no n8n/HMZ environment variable names were present; live Review Case rows for the five new case IDs were therefore **not rechecked** from DataTables in this Codex pass.

**Fable Run 2 review verdict:** Session 16 S2 code-level work is locally coherent and harness-green. Decision Node D contains the S2 upgrade allowlist `{PROOF_REQUEST, NON_PRIORITY, NOT_NOW}`, requires at least one active form-created draft/style rule for the effective classification, keeps classification correction alone from upgrading, records `ai_upgrade_eligible` / reason / blocked reason / `effective_classification_used_for_draft_policy`, preserves the PROOF_REQUEST content gate, maps fallback drafts away from AI-labelled success, and emits truthful `decision.reply_mode`. The protected high-risk/no-reply/suppress/pricing/booking branches are covered by P20 and were not broadened in this review. No critical safety defect was found.

**Owner live PASS evidence triage:** Owner reported `case-58e6b3b0` and `case-5e2fbcbe` were correctly classified and received AI drafts. Because DataTable rows were not API-rechecked here, incoming reply text, exact original/effective classification, draft source, AI attempt status, rule IDs, and attribution remain unverified by Codex. At high level, the observation is consistent with Session 16 claims that AI draft paths still work and reply-mode/status truthfulness should now be recorded, but Fable Run 3 should fetch the rows before treating these as closed evidence.

**Owner live FAIL not-now evidence triage:** Owner reported `case-4a5596a0`, `case-07bd8bb5`, and `case-659d1e01` are genuine not-now cases, were not classified as `NOT_NOW` / `NON_PRIORITY`, and did not receive AI drafts. Without row access, the exact incoming text and row metadata are not verified by Codex. Local code strongly suggests the likely failure is upstream classification/eligibility, not the Session 16 upgrade engine: Section B timing coverage includes `not the right time`, `maybe next/in a few`, `circle/check back`, `follow up in/next`, `touch base in/next`, `revisit`, `down the road/line`, and `next quarter/month/year`, but does **not** visibly cover common timing phrases such as `not until ...`, `later in the quarter`, `after ...`, month/quarter names, or `Q1/Q2/Q3/Q4`. Node D's NON_PRIORITY promotion guard only blocks proof/trust hijacks; it does not positively rescue every timing phrase across mismatched source scopes. If these live rows landed in a baseline class other than the existing `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY` correction scope, the known rule `6e50fd54` would not apply; no effective `NON_PRIORITY` / `NOT_NOW` means no style-rule match, no S2 AI upgrade eligibility, and therefore no AI draft.

**Exact Fable Run 3 requirements:** Fetch and trace the five new Review Case rows first, especially reply text, baseline classification, effective classification, `learning_attribution`, `ai_attempt`, `reply_mode`, `draft_source`, and `applied_learning_rule_ids`. For the three failing not-now rows, add S2 retest fixes only after row proof: likely patch Decision Section B timing phrase coverage and/or Node D classification-rule eligibility for genuine timing/later language. Add harness tests for each exact live phrase; include negative controls proving booking/setup, pricing/commitment, proof/trust, unsubscribe/legal/hostile/no-reply, and human-only blocked classes do not get swept into NOT_NOW or upgraded. Required live retest after Fable Run 3: the three exact failing not-now phrases plus a known good not-now, setup/booking question, pricing question, proof/trust question, and one high-risk/human-only protection case. Sender must remain untouched unless Fable Run 3 is explicitly auditing Sender safety.

**Regression safety check:** Used Session 16 handoff as latest baseline; did not rely on README/local dry-run assumptions or old templates. No broad repo/archive scan. No production writes, no workflow deploy, no live email tests, no Sender/autonomous/Gate 2/Ops Console work. Existing dirty worktree contains many unrelated pre-existing modified backup/report/output files; this session should commit only this handoff entry.

---

## 2026-07-07 — SL-PHASE-5Q Session 16: S2 Closure — Upgrade Engine + PROOF Promotion Gate + Truthful Metadata (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Close Gate S2. Trace owner-reported live cases `case-64589b37` / `case-269eed7f` / `case-5afa61d3` ("forms remain deterministic/human drafts despite applied learning"), prove exact root causes, patch only what is proven.

**Live trace (production Review Cases DataTable `WMTmI6UNjZZgSU3h`, via REST `/data-tables`; production versionIds verified matching local exports before any change):**
- **case-64589b37** (not-now): learning WORKED — classification rule `6e50fd54` + style rules `877c3d75`/`cdada69d` consumed via `post_processor_delta` with visible draft effect ("When would be a good time to check back in?"). Stayed deterministic because NON_PRIORITY→FIXED_TEMPLATE and the upgrade guard was PROOF_REQUEST-only. Exact blocking predicate: `microIntent === 'PROOF_REQUEST' && draftPolicy === 'HUMAN_ONLY'` + `canTryAI` requiring `AI_SUPERVISED_OR_TEMPLATE`.
- **case-269eed7f** (trust): SUCCESS — real AI-supervised draft (`ai_attempt.ok=true`, zero validation errors) with style rule `ea15095a` injected (applied=1, `ai_prompt_injection`). Defects: empty `learning_impact_summary` for the injection path; row `reply_mode=HUMAN_ONLY`.
- **case-5afa61d3** (setup question): CLASSIFICATION FALSE POSITIVE — active OFFER_EXPLANATION→PROOF_REQUEST correction rules `d82e94d7`/`1dba7933` fired on a reply with zero trust/proof signal (`_5qClassificationRuleAllowedForReply` gated booking and NON_PRIORITY promotions but not PROOF_REQUEST). Trust guidance leaked into a setup answer; stale `reply_draft_status=NO_DRAFT_HUMAN_ONLY` sat next to a real AI draft.
- **All rows** stored `reply_mode=HUMAN_ONLY` because Decision never emitted `reply_mode` (HumanApproval Node A default).

**Fixes deployed (Decision Node D ONLY; HumanApproval untouched):**
1. `SL-PHASE-5Q-S2-PROOF-GATE` — rules promoting to PROOF_REQUEST require a trust/proof signal in the reply. Genuine trust variants still pass.
2. `SL-PHASE-5Q-S2-UPGRADE` — generalized safe deterministic/human→AI upgrade engine. Allowlist: PROOF_REQUEST (from HUMAN_ONLY), NON_PRIORITY and NOT_NOW (from FIXED_TEMPLATE/HUMAN_ONLY). Requires ≥1 active form-created style rule for the EFFECTIVE classification; classification correction alone never upgrades. Unsubscribe/legal/hostile/suppress/no-reply/pricing/booking classes never upgrade (booking deterministic by design). Auditable per case: `ai_upgrade_eligible`, `ai_upgrade_reason`, `ai_upgrade_blocked_reason`, `effective_classification_used_for_draft_policy` in `learning_attribution` (considered/consumed reuse `active_learning_rules_found`/`applied_learning_rule_ids`).
3. New `intInstr` NON_PRIORITY/NOT_NOW AI instructions (acknowledge timing, ONE check-back question, no pitch). AI failure falls back to the non-null NOT_NOW template + post-processing (textarea never empty).
4. `SL-PHASE-5Q-S2-STATUS-SYNC` — `reply_draft_status` flipped only when contradicted by the real draft; NOT_APPLICABLE never rewritten.
5. `SL-PHASE-5Q-S2-REPLY-MODE` — Decision emits `decision.reply_mode` (AI_DRAFT_APPROVAL / FIXED_TEMPLATE_APPROVAL / HUMAN_ONLY / NO_REPLY); case rows now truthful; fallback drafts are never labelled AI.
6. `SL-PHASE-5Q-S2-SUMMARY` — single-rule AI injection now writes a truthful non-empty impact summary; multi-rule stays attribution-uncertain.

**Harness:** 425/425 PASS (was 375/375; P20 added 50 tests: reproductions of all three live cases, upgrade allowlist + every blocked-reason branch, high-risk/unsubscribe/no-reply never-upgrade protections, pricing exclusion, status-sync/reply-mode truthfulness, injection-summary truthfulness, rollback/deactivation offline drill P20.38-40, newer-overrides-older, scope containment, JS `node --check`, no-Instantly-POST). Re-run green against the production-refreshed export. P12.11 updated to recognise the S2 form of the rule-gate (same invariant).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `4474c96a` | `84b941a4` | S2 upgrade engine + PROOF promotion gate + reply_mode/status/summary truthfulness |

**Backup:** `workflows/decision_backup_4474c96a_pre_s2_upgrade_engine.json`. Local export refreshed from production post-deploy (versionId verified matching). HumanApproval unchanged (`0054f20b`). Production guard passed before every API call. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive via API post-deploy. Gate 2 unapproved. Autonomous disabled. No live email tests run. New reusable script: `scripts/SL-PHASE-5Q-S2-inject-node-code.py`.

**Rollback/deactivation procedure (S2.6):** documented in `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — operator sets a Q12 rule's `status` to `deactivated`/`rejected`/`superseded` (n8n Data Table UI or REST); Decision ignores it on the next case; newer same-scope rules already override older ones. Offline drill proven (P20.38-40); live drill pending.

**Owner action required (manual live test matrix, ~3 emails):**
1. Not-now reply ("This could be useful but not until later in the quarter.") → expect an AI-supervised draft (blue "AI-generated draft" banner) acknowledging timing + ONE check-back question; metadata `ai_upgrade_eligible=true`. If AI fails, the NOT_NOW template with the check-back question must appear (never empty).
2. Setup question ("Before I book, can you give me a quick breakdown of what you set up?") → expect `INFORMATION_REQUEST / OFFER_EXPLANATION` (NOT PROOF_REQUEST) and a setup-steps draft.
3. Trust reply ("I don't know if you are trustworthy.") → expect PROOF_REQUEST AI draft as before, now with a non-empty learning impact summary.
4. Optional S2.6 live drill: set one Q12 rule to `deactivated`, send a matching probe, confirm the rule no longer applies, then restore.

**Do-not-regress rules unchanged:** Do not touch Sender. Do not activate Shadow. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before the live retest matrix above is complete.

---

## 2026-07-06 — SL-PHASE-5Q Session 15: Dense-Paragraph Fallback Fix + Fault Ledger + Scale Gates (DEPLOYED)

**Agent:** Claude Code (Fable 5)
**Objective:** Trace and repair the remaining blocker (`AI_OUTPUT_VALIDATION_FAILED` / safe-fallback banner too frequent on proof/trust cases); create the complete fault ledger and scale-readiness gates; preserve checkpoint state.

**Checkpoint status resolved:** The 2026-07-05 handoff entry said the push was blocked; verified via `git ls-remote` that branch `codex/5q-context-token-forensic-20260705` and tag `sl-phase-5q-largely-working-20260705` ARE on origin. The uncommitted working-tree changes from sessions 13-14 (afe08974 export, 349-test harness, reports, backups) were committed (`dec5c2f`) and pushed before any new work.

**Blocker root cause (live-proven, exec 5329):** AI provider returned a fully safe, honest, correctly-negated PROOF_REQUEST draft; the ONLY validation error was `active policy violation: dense paragraph` — a style predicate, not a safety predicate. Cause chain: globally-scoped owner style policy `27293ea8` ("short paragraphs", scope `all_ai_drafts`) arms the dense-paragraph check (>360 chars/paragraph) for every AI draft, while `intInstr.PROOF_REQUEST` demanded "One concise paragraph" — the prompt invited exactly the shape the validator rejects. Boundary confirmed: exec 5286 (~336 chars) passed, exec 5329 (~386 chars) failed. The older proof-mention false positive (execs 4976/4980) was confirmed already fixed by session 12 (`asksProof` guard) — current executions 5286/5296 pass it.

**Fixes deployed:**
- Decision Node D `buildAIPrompt`: PROOF_REQUEST instruction now asks for 2-3 short paragraphs (each <300 chars), CTA in its own final paragraph.
- Decision Node D: new `_5qReflowDenseParagraphs` — when validation errors are EXCLUSIVELY dense-paragraph, the draft is reflowed at sentence boundaries (whitespace-only; wording never altered) and the FULL validator re-runs. Any safety error still falls back unchanged. Smoke-tested in Node.js against the exact exec-5329 draft: rejected before, passes after, wording preserved, invented-proof drafts still fail.
- Decision Node D: `ai_attempt` now records `style_reflow_applied` and `raw_draft_text_before_reflow` (truthful metadata).
- HumanApproval Node J: ai_failed_fallback banner now names the exact failed check(s) and states when the rejection was a formatting/style check only, not a content-safety check. Safety wording ("Do not invent proof...") retained.
- Proof safety NOT weakened: invented proof/case studies/testimonials/results/guarantees/pricing still hard-fail (harness P19.11-P19.16).

**Harness:** 375/375 PASS (was 349/349; P19 added 26 tests: exec-5329 regression reproduction, reflow fix proof, wording preservation, safety-not-weakened, banner accuracy, JS literal-newline guards on both patched nodes, no-Instantly-POST check). Re-run green against production-refreshed exports.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `afe08974` | `4474c96a` | PROOF_REQUEST prompt paragraphs + dense-reflow rescue + truthful reflow metadata |
| HumanApproval | `9aPrt92jFhoYFxbs` | `7aac637e` | `0054f20b` | Fallback banner names failed checks; style-only vs safety distinction |

**Backups:** `workflows/decision_backup_afe08974_pre_dense_reflow_fix.json`, `workflows/humanapproval_backup_7aac637e_pre_fallback_banner_detail.json`. Local exports refreshed from production post-deploy (versionIds verified matching). Both workflows remain active. Production guard passed before every API call. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive via API post-deploy. Gate 2 unapproved. Autonomous disabled. No live email tests run.

**New governance docs:**
- `docs/INSTANTLY_RESPONDER_FAULT_LEDGER_AND_SCALE_READINESS.md` — 15 fault classes, honest statuses, evidence, false-positive risks, ranked open faults. Notable open item 10(c): FORBIDDEN_AI negation-window gaps (`can't/cannot/won't` missing; post-keyword negation not exempted) — deliberately NOT patched (no live occurrence; do not patch without a live case).
- `docs/SCALE_READY_ACCEPTANCE_GATES.md` — gates S1 (supervised live) through S5 (multi-campaign). S1 effectively open pending fresh trust retest; S3-S5 not met by design; autonomous remains NOT APPROVED.
- New scripts: `scripts/SL-PHASE-5Q-apply-dense-reflow-fix.py`, `scripts/SL-PHASE-5Q-apply-fallback-banner-detail.py`, `scripts/SL-PHASE-5Q-deploy-workflow-update.py` (reusable PUT deploy helper).

**Owner action required (manual live test matrix):**
1. Send a fresh trust/proof reply (e.g. `Ah, I don't know if you are trustworthy.`). Expect: `INFORMATION_REQUEST / PROOF_REQUEST`; an AI-supervised draft in 2-3 short paragraphs (possibly `style_reflow_applied=true` in metadata); NOT an empty textarea; NOT a diagnostic page.
2. If a fallback still occurs, the yellow banner must name the exact failed check(s) — report the named check.
3. Regression: send one OFFER_EXPLANATION setup question — expect short-paragraph/list draft as before.
4. Regression: send one not-now reply — expect NON_PRIORITY NOT_NOW template with check-back question.

**Do-not-regress rules unchanged:** Do not touch Sender. Do not activate Shadow. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before the SL-PHASE-5Q live retest matrix above is complete.

---

## 2026-07-05 00:00 BST — GitHub Checkpoint / Build Preservation (PARTIAL: LOCAL COMMIT/TAG CREATED, PUSH BLOCKED)

**Agent:** Codex
**Objective:** Documentation and Git/GitHub checkpoint only. Preserve the current largely working SL-PHASE-5Q responder build before any further repair work.

**Current known production version IDs (from handoff/reports, not freshly queried via n8n API):**

| Workflow | ID | Current known versionId | Status |
|----------|----|-------------------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `afe08974-b635-4a56-be42-d005ba7f3520` / short `afe08974` | Latest known trust/proof variant repair deployed |
| HumanApproval | `9aPrt92jFhoYFxbs` | `7aac637e-e57a-44b3-91c4-96b9e4f0d064` / short `7aac637e` | Latest known modern review/scope/default repair deployed |

**Current known status:** Largely working, approximately 97% ready, and should be preserved before more changes. Latest harness reported `349/349 PASS`. Exact proof/trust classification path is mostly working after the trust/proof variant repair. `trust`, `trustworthy`, `credible`, `believe`, and proof/evidence variants were patched into the Decision classifier priority and NON_PRIORITY leakage guard. Sender remains untouched. Shadow Evaluator remains inactive. Gate 2 remains unapproved. Autonomous remains disabled.

**What is working:** Decision and HumanApproval current known versions reflect SL-PHASE-5Q fixes through the trust/proof variant repair. PROOF_REQUEST classification learning and style-rule eligibility are materially improved. Context/token regression was repaired. Review form modern path and fallback taxonomy are documented as repaired in the current handoff/reports. No Sender trigger, no Instantly POST, no autonomous activation, and no Gate 2 approval are recorded for these latest repairs.

**Not yet fully verified:** A fresh live owner retest is still required after the trust/proof variant repair. Production version metadata was not re-queried in this checkpoint session; `scripts/assert-hmz-production-target.ps1` passed, but no n8n API metadata call was made. SL-PHASE-5Q live verification and anti-false-positive audit remain the gating evidence before any autonomous or 5R work.

**Current blocker / next task:** Remaining known issue is `AI_OUTPUT_VALIDATION_FAILED` / safe fallback banner appearing too often on proof/trust cases. Next repair task is to reduce fallback frequency on proof/trust cases without inventing proof, results, guarantees, customer examples, or credibility claims.

**Do-not-regress rules:** Do not regress to older `README.md` or local dry-run project state. Do not touch Sender. Do not activate Shadow Evaluator. Do not approve Gate 2. Do not enable autonomous. Do not start SL-PHASE-5R before SL-PHASE-5Q live verification and anti-false-positive audit are complete. Keep `OPERATION_HANDOFF.md` as the source of truth when it conflicts with README or older docs.

**Files changed in checkpoint session:** `OPERATION_HANDOFF.md`, `README.md`, `CLAUDE.md`, `AGENTS.md`. No application code or workflow logic intentionally changed.

**Git branch:** `codex/5q-context-token-forensic-20260705` before checkpoint; preferred checkpoint branch is `checkpoint/sl-phase-5q-largely-working-20260705`, but branch switch may be skipped because the worktree is already dirty with many pre-existing non-documentation changes.

**Commit / push / tag result:** Documentation checkpoint commit `23b2d48` created with message `checkpoint: preserve largely working SL-PHASE-5Q responder state`. GitHub branch push attempted to `origin codex/5q-context-token-forensic-20260705` and failed because GitHub credentials were unavailable in the agent shell: `fatal: could not read Username for 'https://github.com': No such device or address`. Local annotated tag `sl-phase-5q-largely-working-20260705` created. Tag push skipped because branch push did not succeed.

**Exact next recommended owner/action:** Preserve this checkpoint, then run a fresh live proof/trust retest (`Ah, I don't know if you are trustworthy.`). If classification is `INFORMATION_REQUEST / PROOF_REQUEST` but the safe fallback banner appears too often, start a narrow Decision-only repair session for AI validation/fallback-frequency on proof/trust cases. Do not start autonomous or SL-PHASE-5R first.

---

## 2026-07-05 — SL-PHASE-5Q Trust/Proof Variant Classification-Learning Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove and repair why `Ah, I don't know if you are trustworthy.` remained `AMBIGUOUS / NON_PRIORITY` after the owner corrected `case-e6e99b67` to `INFORMATION_REQUEST / PROOF_REQUEST`.

**Root cause (live-proven):** The correction was submitted and stored, but not consumable for the follow-up baseline. `case-e6e99b67` produced correction event row `66` (`approval_decision=approve`, `status=captured_only`, old `AMBIGUOUS/NON_PRIORITY`, corrected `INFORMATION_REQUEST/PROOF_REQUEST`) and active Q12 rows: classification rule `b90ff779-5593-4b02-9a98-6aebd40ef7e8` scoped from `AMBIGUOUS/NON_PRIORITY`, plus PROOF_REQUEST style rule `9f7c332d-651d-4931-bae3-a17ed2caa131`. Follow-up `case-3a05c80c` started as `AMBIGUOUS/AMBIGUOUS_SHORT_REPLY`, so `b90ff779` was not eligible. Older rule `6e50fd54` promoted it to `NON_PRIORITY`, then NON_PRIORITY draft rules `877c3d75` and `cdada69d` generated the wrong check-back draft.

**Fix:** Decision only. Section B now gives trust/proof variants (`trust`, `trustworthy`, `credible`, `believe`, proof/evidence wording) deterministic priority as `INFORMATION_REQUEST / PROOF_REQUEST`. Node D now blocks NON_PRIORITY classification-rule promotion when the reply has trust/proof intent. No proof claims or reply text were hardcoded.

**Harness:** 349/349 PASS (was 326/326; P18 added 23 trust/proof variant, NON_PRIORITY leakage, source-case rule eligibility, attribution, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `f6d5b731` | `afe08974` | Trust/proof classifier priority + NON_PRIORITY classification guard |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_f6d5b731_pre_trust_variant_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) confirmed inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh `Ah, I don't know if you are trustworthy.` reply. Expected: `INFORMATION_REQUEST / PROOF_REQUEST`; PROOF_REQUEST style learning eligible; no NON_PRIORITY check-back draft.

---

## 2026-07-05 — SL-PHASE-5Q Context/Token Upstream Regression Repair (DEPLOYED)

**Agent:** Codex
**Objective:** Prove why `case-68110963` rendered as `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK` with `Invalid or unexpected token` and all upstream context missing.

**Root cause (live-proven):** Not review-link token validation, case lookup, Google Chat URL corruption, Intake payload loss, or owner/test misuse. Production execution `5263` showed Decision received valid upstream context before Node D (`campaign_id=531e64ed-c225-4baf-97a9-4ec90dc34eb0`, lead email present, sender `hamzah@teamhmzautomations.com`, subject/reply text present, classifier `INFORMATION_REQUEST / OFFER_EXPLANATION`). Decision Node D then failed before its in-node catch could preserve context and emitted only `{ error: "Invalid or unexpected token " }`. HumanApproval execution `5264` created `case-68110963` from that error-only item, generated a diagnostic fallback identity (`DIAGNOSTIC_MISSING_INTAKE_...`), and stored `context_missing.blocked=true`, `status=HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`, all required fields missing, and `upstream_error="Invalid or unexpected token "`. Review execution `5265` proved `token_valid=true`, `token_invalid_reason=OK`; the token was not the cause.

**Exact code bug:** Decision Node D PROOF_REQUEST fallback branch contained a JavaScript syntax error:
`return _prParts.join('` followed by a literal newline and then `');`. n8n could not compile the Code node, so the workflow-level error output dropped valid Decision/Intake context before HumanApproval.

**Fix:** Decision Node D only — changed the PROOF_REQUEST fallback join to escaped newline source: `return _prParts.join('\\n\\n');`.

**Harness:** 326/326 PASS (was 318/318; P17 added 8 context/token/upstream regression tests, plus Node J syntax check now has a static fallback when `node` is unavailable in the agent shell).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `9198554c` | `f6d5b731` | Node D syntax repair in PROOF_REQUEST fallback join |

**HumanApproval unchanged** (`7aac637e`). Backup created: `workflows/decision_backup_9198554c_pre_context_token_fix.json`. Local Decision export refreshed from production. Sender untouched and not triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) remains inactive. Gate 2 remains unapproved.

**Owner action required:** Send a fresh seeded reply in the existing Instantly campaign thread. Verify Instantly shows campaign ID, lead email, sender email, subject/thread, and reply body before sending. The next review case should no longer be an error-only diagnostic from Node D; it should preserve upstream context and render a normal review form or a legitimate context diagnostic if Instantly truly omits required fields.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST AI-Fallback Non-Null Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the empty textarea for PROOF_REQUEST cases when AI fails after the session 11 eligibility fix.

**Root cause (proven from code):** Session 11 fixed eligibility correctly — the upgrade guard fires and `draftPolicy` upgrades to `AI_SUPERVISED_OR_TEMPLATE` when the style rule from case-a92bb763 is active. AI is called. But when AI output fails validation OR the API call fails, `draftText = fallbackText`. `buildPolicyAwareFallback` had no PROOF_REQUEST branch — it fell through to `return deterministicText` which is `null` (no PROOF_REQUEST entry in `MI_TEMPLATES`). Result: `draftText = null` → empty textarea, `draftSource = ai_failed_fallback`, `aiDraftUsedGuidance = false` (because `draftSource !== 'ai_supervised'`) → draft style rule not counted as applied in `activeLearningRulesApplied` → only classification rule 1dba7933 shown as applied. Evidence: case-9996084f (`AI_SUPERVISED_OR_TEMPLATE / ai_failed_fallback`, found=19, eligible=2, applied=1, empty textarea).

**Fix 1 (Decision Node D — `validateAI`):**
- `asksProof = microIntent === 'PROOF_REQUEST' || /.../.test(prospect)` — ensures `asksProof = true` for PROOF_REQUEST micro_intent.
- Prevents false-positive validation rejection if any active guidance rule contains "do not mention validation unless the prospect asks" (the prospect's "How can I trust you?" doesn't contain the trigger words, so `asksProof` would be `false` without this fix).

**Fix 2 (Decision Node D — `buildPolicyAwareFallback`):**
- Added PROOF_REQUEST branch before the HOW_IT_WORKS/AMBIGUOUS fallback.
- Returns a safe, non-null deterministic fallback: honest proof-gap acknowledgment ("We don't have public customer examples or case studies to point to yet. We're at an early validation stage...") + diagnostic question ("Would that be worth the time?").
- No invented proof, results, guarantees, case studies, or customer examples.
- Human review still required before send.

**Harness:** 318/318 PASS (was 292/292; P16 added: 26 new PROOF_REQUEST AI-fallback, validateAI guard, and safety tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `0e1e1193` | `9198554c` | Node D `validateAI` asksProof guard + `buildPolicyAwareFallback` PROOF_REQUEST branch |

**HumanApproval unchanged** (`7aac637e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review form should now show a non-empty draft in the textarea — a safe proof-gap acknowledgment with a diagnostic question. Edit as needed and approve/send or approve for learning. If the textarea is still empty, check the n8n execution log for the specific AI failure reason in `aiAttempt.fallback_reason`.

---

## 2026-07-05 — SL-PHASE-5Q PROOF_REQUEST Draft-Learning Activation Bridge Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix the missing bridge between teaching case (case-532bae78) manual reply + draft_learning_instruction and future PROOF_REQUEST AI-supervised draft generation.

**Root cause:** Style rule from case-532bae78 was written to Q12 (rule count 17→18 confirmed) but was NEVER eligible in `_5qPolicyApplies`. The owner submitted the form without selecting a scope checkbox. Node N fell back to `draft_improvement_scope = "unsure_review_needed"` (default). SL-P2A mapped this to `proposed_rule_scope = "requires_human_scope_decision"` (the else branch). In Decision Node D, `_5qPolicyApplies` returned `false` for this scope → rule not eligible → `activeFormDraftRuleMatches = []` → upgrade guard never fired → PROOF_REQUEST remained HUMAN_ONLY.

**Fix 1 (Decision Node D — `_5qPolicyApplies`):**
- Added fallback for `scope === 'requires_human_scope_decision' || scope === 'unsure_review_needed'`.
- Falls back to `_5qPolicyMicroMatches(policy.micro_intent_scope, cat, mi)` if `micro_intent_scope` is set, else `classification_scope` category match.
- Fixes the existing rule already in Q12 from case-532bae78 (will now be eligible for PROOF_REQUEST cases).

**Fix 2 (HumanApproval Node J — form scope default):**
- Changed `_5qDraftScopes` default for new cases from `["unsure_review_needed"]` to `["current_micro_intent_only"]`.
- The "current_micro_intent_only" scope checkbox is now pre-checked for new cases.
- Future rules get `proposed_rule_scope = "micro_intent"` directly via SL-P2A → no fallback needed.
- Previously reviewed cases with saved scopes are preserved (not overridden).

**Harness:** 292/292 PASS (was 266/266; P15 added: 26 new PROOF_REQUEST draft-learning bridge tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `84e6638e` | `0e1e1193` | Node D `_5qPolicyApplies` unresolvable-scope fallback |
| HumanApproval | `9aPrt92jFhoYFxbs` | `c20af72e` | `7aac637e` | Node J form scope default → current_micro_intent_only |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Owner action required:** Send another "How can I trust you?" reply to generate a fresh PROOF_REQUEST case. The review form should now show: (1) scope checkbox pre-checked at "current_micro_intent_only"; (2) on subsequent cases, if the existing case-532bae78 style rule is eligible, the upgrade guard should fire and produce an AI-supervised draft using the proof-safety prompt. Human approval still required before send.

---

## 2026-07-05 — SL-PHASE-5Q Valid-Fallback Submit/Reopen Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix `CONTEXT_MISSING_BLOCKED` on submit + diagnostic fallback on reopen for valid `ai_failed_fallback` cases (case-13c3dad3 class).

**Root causes:**
- Node N `rowLooksMissing`: no `isIntentionallyNoDraft` exemption → empty `draft_text` on `ai_failed_fallback` cases triggered `contextMissingBlocked=true` → blocked submit despite valid upstream context.
- Node J `_5q3MissingContext`: included `rc.status === "CONTEXT_MISSING_BLOCKED"` as standalone trigger → after blocked submit set status, reopening showed diagnostic fallback even though `sanitized_context` was intact.
- SL-P2A had same `rowLooksMissing` bug → learning capture skipped for `ai_failed_fallback` cases on valid submits.

**Fix (HumanApproval — Node N + Node J + SL-P2A only):**
- Node N: added `_nIsIntentionallyNoDraft` (mirrors Node A/J) before `rowLooksMissing`; removed `rc.status === "CONTEXT_MISSING_BLOCKED"` from `contextMissingBlocked` (relies on `reply_mode` + `rowLooksMissing`).
- Node J: removed `(rc.status === "CONTEXT_MISSING_BLOCKED")` from `_5q3MissingContext`; `_5q3RowLooksMissing` still catches all genuinely missing context.
- SL-P2A: added `_p2aIsIntentionallyNoDraft` exemption; removed `rc.status` check from context-skip condition.
- Genuine diagnostic invariants preserved: `reply_mode=DIAGNOSTIC_CONTEXT_MISSING`, `ctx.context_missing.blocked=true`, and missing required context fields still always diagnostic.

**Harness:** 266/266 PASS (was 240/240; P14 added: 26 new submit/reopen taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `ee2f160e` | `c20af72e` | Node N + Node J + SL-P2A submit/reopen fix |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Reopen case-13c3dad3 from the review link. The form should now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons enabled. Submit a learning-only or save action. Confirm CONTEXT_MISSING_BLOCKED is gone and the case can be re-reviewed. Then send another "How can I trust you?" reply to generate a fresh case and confirm the full render → save → approve cycle works end-to-end.

---

## 2026-07-04 — SL-PHASE-5Q ai_failed_fallback Valid-Review Taxonomy Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix recurring valid-context diagnostic fallback when AI draft validation fails (case-b0cfd04c class: PROOF_REQUEST + AI_SUPERVISED_OR_TEMPLATE + ai_failed_fallback + missing draft_text + valid upstream context).

**Root cause:** Both Node A (`_aIsIntentionallyNoDraft`) and Node J (`_5q3IsIntentionallyNoDraft`) only exempted `HUMAN_ONLY`/`NO_DRAFT`/`human_only`/`none` from the missing-draft check. `ai_failed_fallback` was missing → cases where AI ran but output failed validation (draft_source=ai_failed_fallback, draft_text empty) were flagged as diagnostic fallback despite fully valid upstream context. The `ai_failed_fallback` banner at Node J ~18100 already existed but was never reached.

**Fix (HumanApproval Node A + Node J only):**
- Node A: `_aIsIntentionallyNoDraft` — added `|| _aDraftSourceRaw === "ai_failed_fallback"`.
- Node J: `_5q3IsIntentionallyNoDraft` — added `|| rc.draft_source === "ai_failed_fallback"` and `|| ctx.draft_source === "ai_failed_fallback"` in ctx branch.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent) still triggers diagnostic fallback.

**Review-state taxonomy established:**
- Diagnostic: missing reply_from_email, sender_email, thread_id, reply_text, UNKNOWN category, missing micro_intent — always diagnostic regardless of draft_source.
- Valid human-only: draft_policy=HUMAN_ONLY, draft_source=human_only → exempt.
- Valid ai_failed_fallback: draft_source=ai_failed_fallback → exempt. Existing ai_failed_fallback banner renders (yellow warning, safety constraints, empty editable textarea).
- Valid no-draft: draft_policy=NO_DRAFT, draft_source=none → exempt.

**Harness:** 240/240 PASS (was 216/216; P13 added: 24 new ai_failed_fallback taxonomy tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `c51ac1f3` | `ee2f160e` | Node A + Node J ai_failed_fallback exempt |

**Decision unchanged** (`84e6638e`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. The review page must now render normally — yellow AI-failed-fallback banner, empty editable textarea, classification/learning metadata, all modern buttons. If still diagnostic, check n8n execution log for any remaining error in Node A or Node J.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST Learned-Draft Pathway (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Allow future PROOF_REQUEST draft-learning rules to generate AI-supervised drafts; keep current HUMAN_ONLY behaviour while only classification correction exists.

**Root cause:** `_5qDraftPolicyFor` (and `draftPolicyFor` in Section B) mapped `PROOF_OR_CASE_STUDY_REQUEST → AI_SUPERVISED_OR_TEMPLATE` but had no `PROOF_REQUEST` entry — default fell through to `HUMAN_ONLY`. After classification correction set `micro_intent=PROOF_REQUEST`, no draft-policy recalculation occurred.

**Fix (Decision Node D only):**
- `const draftPolicy` → `let draftPolicy` (allows in-place upgrade).
- Upgrade guard: if `microIntent === 'PROOF_REQUEST'` AND `draftPolicy === 'HUMAN_ONLY'` AND `activeFormDraftRuleMatches.length > 0`, upgrade to `AI_SUPERVISED_OR_TEMPLATE`.
- `activeFormDraftRuleMatches` includes only `rule_type=style` rules (via `DYNAMIC_FORM_BEHAVIOURAL_POLICIES`). Classification correction rules (`rule_type=classification_correction`) are excluded — classification learning alone does NOT trigger the upgrade.
- Added `PROOF_REQUEST` entry to `buildAIPrompt` `intInstr` map with safety-first instruction (no invented proof/results/customer claims).

**Current state:** Case case-5de97d7a has rule `1dba7933` (classification correction only) → upgrade condition is `false` → PROOF_REQUEST correctly remains HUMAN_ONLY. Upgrade path is ready for future owner-created style rules for PROOF_REQUEST.

**Harness:** 216/216 PASS (was 190/190; P12 section added: 26 new PROOF_REQUEST learned-draft pathway tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `4cb34768` | `84e6638e` | Node D PROOF_REQUEST draft-learning upgrade guard + intInstr |

**HumanApproval unchanged** (`c51ac1f3`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** To enable AI drafts for future PROOF_REQUEST cases, use the review form to create a draft-learning rule with `rule_type=style` and `micro_intent_scope=PROOF_REQUEST`. Once that rule is active in Q12, the upgrade guard will fire and AI-supervised drafts will be generated — human approval still required before send.

---

## 2026-07-04 — SL-PHASE-5Q Node J Syntax Crash Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix live render crash (UNKNOWN at node J) for valid PROOF_REQUEST/HUMAN_ONLY cases after session 6 deploy.

**Root cause:** Session 6 introduced a JavaScript `SyntaxError` in Node J. The comment placement was wrong: `const // SL-PHASE-5Q-PROOF-FIX: ...` (line 59) left an orphaned `const` keyword with no variable declaration — only a comment followed on the same line. Line 61 then declared `_5q3RowLooksMissing = ...` without `const`/`let`/`var`. These two errors together caused n8n to report `UNKNOWN at node J. Render Review Form HTML` for every case, including valid PROOF_REQUEST cases. The session 6 harness (168/168 Python simulation) missed this because it simulates logic in Python and never runs the actual JavaScript.

**Fix (HumanApproval Node J only):**
- Line 59: `const // SL-PHASE-5Q-PROOF-FIX: ...` → `// SL-PHASE-5Q-PROOF-FIX: ...` (removed orphaned `const`)
- Line 61: `_5q3RowLooksMissing = ...` → `const _5q3RowLooksMissing = ...` (added `const` declaration)
- Verified with `node --check`: SYNTAX OK.

**Harness:** 190/190 PASS (was 168/168; P11 section added: 22 new tests including `node --check` JS syntax validation to prevent recurrence).

**Classification learning confirmed (live):** Cases case-d24661f0 and case-3838bcee both showed active learning applied, rule `1dba7933-c38c-4bc1-a7d2-3723af0b2711`, source case-bd8e453e, marker `humanapproval_form_created_learning`, effective classification `INFORMATION_REQUEST / PROOF_REQUEST`. Classification learning is materially evidenced.

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `e0e89e0e` | `c51ac1f3` | Node J syntax crash fix (two-line const error) |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page must now render fully — HUMAN_ONLY banner, empty editable textarea, classification/learning metadata, all modern buttons. If blank page persists, check n8n execution log for any remaining error.

---

## 2026-07-04 — SL-PHASE-5Q PROOF_REQUEST / HUMAN_ONLY Review-Path Repair (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Fix valid PROOF_REQUEST/HUMAN_ONLY cases incorrectly becoming `HUMANAPPROVAL_DIAGNOSTIC_FALLBACK`.

**Root cause:** Both Node A (Build Review Case Record) and Node J (Render Review Form HTML) in HumanApproval treated missing `draft_text` as a missing-context indicator. For `HUMAN_ONLY` and `NO_DRAFT` policies, `draft_text` is intentionally absent — no AI draft is generated. This caused valid PROOF_REQUEST cases with complete upstream context (campaign, lead_email, sender_email, thread_id, reply_text all present) to be flagged as diagnostic fallback.

**Patches applied (HumanApproval):**
- Node A: `_aIsIntentionallyNoDraft` guard — skips `draft_text` from `missingContextFields` when `draft_policy ∈ {HUMAN_ONLY, NO_DRAFT}` or `draft_source ∈ {human_only, none}`.
- Node J: `_5q3IsIntentionallyNoDraft` guard — same condition exempts `draft_text` from `_5q3RowLooksMissing`.
- Existing HUMAN_ONLY banner at ~line 17090 in Node J was already correct — it was never reached due to the diagnostic intercept.
- Genuine missing context (campaign, lead_email, sender_email, thread_id, reply_text absent) still triggers diagnostic fallback correctly.

**Harness:** 168/168 PASS (was 148/148; P10 section added: 20 new PROOF_REQUEST/HUMAN_ONLY tests).

**Classification-learning verdict (case-bd8e453e):** PARTIAL. The owner corrected `OFFER_EXPLANATION` → `PROOF_REQUEST` on case-bd8e453e, and follow-up cases ea4350f5/cd2c2eb6 showed `PROOF_REQUEST` classification. This is plausible classification learning but cannot be fully proven without a live rule trace from the DataTable (no rule ID confirmed).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `849c2c64` | `e0e89e0e` | Node A + Node J HUMAN_ONLY draft_text exempt |

**Decision unchanged** (`4cb34768`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Send another "How can I trust you?" reply. Review page should now show the HUMAN_ONLY banner ("No AI draft was generated because this reply requires human-only handling.") with a text area to write a manual reply — not the diagnostic fallback red error page.

---

## 2026-07-04 — SL-PHASE-5Q Attribution False-Positive Fix (DEPLOYED)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Audit local attribution patch; fix multi-rule over-credit risk; deploy.

**Root cause fixed:** Local patch credited ALL eligible draft rules when `learningAppliedToDraft=true` via AI prompt injection. If 2 rules were eligible (as in the two-email test), both were counted even if only one could provably influence AI output.

**Fix applied (Node D):**
- Added `aiPromptInjectionSingleRule` / `aiPromptInjectionMultiRule` flags.
- Single-rule AI injection → 1 rule credited, `via: 'ai_prompt_injection'`.
- Multi-rule AI injection → 0 rules credited individually; `learning_attribution_uncertain: true`; `via: 'ai_prompt_injection_multi_rule_unproven'`; reason: `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.
- Post-processor delta → all eligible rules credited (observable proof).
- Added `learning_guidance_injected` and `learning_attribution_uncertain` to attribution object.

**Harness:** 148/148 PASS (was 119/119; P9 section added: 29 new attribution false-positive tests).

| Workflow | ID | Old versionId | New versionId | Change |
|----------|----|---------------|---------------|--------|
| Decision | `tgYmY97CG4Bm8snI` | `937488a9` | `4cb34768` | Attribution false-positive fix |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Owner action required:** Run a fresh two-email self-learning test (same OFFER_EXPLANATION path). Expect: if 1 eligible rule → `applied count = 1`, `via = 'ai_prompt_injection'`. If 2 eligible → `applied count = 0`, `attribution_uncertain = true`, reason = `GUIDANCE_INJECTED_MULTI_RULE_PER_RULE_ATTRIBUTION_UNPROVEN`.

---

## 2026-07-04 — SL-PHASE-5Q Learning Attribution False-Positive Check (PATCH READY, PENDING DEPLOY)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Diagnose two-email self-improvement test: applied count = 0 despite apparent second-draft improvement.

**Root cause confirmed:** Attribution bug. `draftTextBeforeActiveLearning` is captured AFTER AI generation (index 62,295) but the learning rule is injected into `buildAIPrompt` BEFORE AI generation (index 57,461). For OFFER_EXPLANATION (AI prompt injection path), the post-processor makes no change → delta = 0 → applied count = 0. The learning IS consumed but is invisible to the delta check.

**Verdict:** Second draft improvement is likely REAL learning. Applied count = 0 is a counter bug, not a false positive.

**Patch written to local file — NOT YET DEPLOYED:**
- `workflows/production_decision_current.json` — Node D: added `aiDraftUsedGuidance` flag; extended `learningAppliedToDraft` to include AI prompt injection path; added `learning_applied_via` field (`'ai_prompt_injection'` vs `'post_processor_delta'`)
- Owner must approve and deploy this patch before it takes effect.

**Files changed (local only):**
- `workflows/production_decision_current.json` — patch written
- `reports/SL-PHASE-5Q_LEARNING_ATTRIBUTION_FALSE_POSITIVE_CHECK.md` — created
- `OPERATION_HANDOFF.md` — this entry

**No production changes applied.** Decision versionId still `937488a9`. HumanApproval unchanged (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator untouched. Gate 2 unapproved.

**Owner action required:** Review patch in `workflows/production_decision_current.json` Node D, then deploy via `PUT /workflows/tgYmY97CG4Bm8snI` or run harness after confirming patch is correct.

---

## 2026-07-04 — SL-PHASE-5Q Decision Classification + GAP-3b Repair (PARTIAL → pending Variant C)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** FIX-1 booking/pricing classification correction; FIX-3 NOT_NOW style rule consumption (GAP-3b).

**Files changed:**
- `workflows/production_decision_current.json` — updated from production (versionId `937488a9`)
- `workflows/nodeD_backup_a3916c2e_pre_5q_session4.json` — backup before patch
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 89/89 → 119/119 (+30 new P7+P8 tests)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — session 4 patches documented
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — session 4 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — session 4 verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `a3916c2e` | `937488a9` | FIX-1 booking regex, FIX-2 pricing regex, FIX-3 GAP-3b NOT_NOW consumer |

**HumanApproval unchanged** (`849c2c64`). No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Root causes fixed:**
- FIX-1: Section B `detectMicroIntent` BOOKING_REQUEST regex didn't match `walkthrough`/`demo`/`tour`/`meeting`. Extended: `book (?:a (?:quick |brief )?)?(time|slot|call|walkthrough|demo|tour|meeting)`. Same fix applied to `_5qReplyHasBookingIntent` in Section D.
- FIX-2: Section B `detectMicroIntent` PRICING_REQUEST regex didn't match `commitment`/`retainer`. Extended with those terms.
- FIX-3 (GAP-3b): `_5qApplyActiveFormRuleInstructionToDraft` had no NON_PRIORITY/NOT_NOW handler. Added: when cdada69d guidance active + "check back/when would be/better time" signal present, replaces "I'll close the loop" with "When would be a good time to check back in?"

**Harness:** 119/119 PASS (was 89/89). P7 (booking/pricing classification 12 tests) + P8 (NOT_NOW style 18 tests) added.

**Remaining:** Owner Variant C live retests required — booking, pricing/commitment, not-now, setup/process regression.

---

## 2026-07-04 — SL-PHASE-5Q Live Regression Repair (PARTIAL)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Repair Node J review form regression; triage Variant B live results; update harness.

**Files changed:**
- `workflows/production_humanapproval_current.json` — Node J restored from 0fa9d0ce lineage; pushed to production
- `workflows/nodeJ_backup_pre_live_regression_repair.json` — backup of 54b7a8e4 Node J before repair
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — updated 66/66 → 89/89 (P5 + P6 sections added)
- `reports/SL-PHASE-5Q_LIVE_BEHAVIOURAL_VERIFICATION.md` — created (Variant B execution trace + root causes)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — updated to PARTIAL + session 3 status
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — updated with session 3 Variant B verdict
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| HumanApproval | `9aPrt92jFhoYFxbs` | `54b7a8e4` | `849c2c64` | Node J regression repair (modern UI restored) |

**Decision unchanged.** No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.

**Node J regression root cause confirmed:**
Previous session patched Node J using stale `9c71882f` as base instead of modern `0fa9d0ce` lineage. Old `draft_revision_type`, `desired_future_behavior`, and `What should the system do next time?` fields reintroduced. `draft_learning_instruction` field and `Save draft and learning` button lost.

**Node J repair:** Surgically replaced from `agent/codex/sl-phase-5q-checkpoint-20260701` (0fa9d0ce). Modern UI confirmed: `draft_learning_instruction`, `Why did you make this change, and what should the system do next time?`, `Save draft and learning`, `Approved for learning only`. Old fields removed. Other nodes (H, L, N, Q2, SL-P2A) preserved.

**Harness: 89/89 PASS** (was 66/66; added P5 Node J regression + P6 Variant B structural sections).

**Variant B live triage (all cases confirmed against a3916c2e):**

| Case | Exec | Classification | Rule applied | Verdict | Root cause |
|------|------|---------------|-------------|---------|-----------|
| Booking | 4846 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 97eb3b0a | FAIL | AI misclassification |
| Setup/process | 4855 | OFFER_EXPLANATION (correct) | 48e10cac | PASS | — |
| Not-now | 4859 | AMBIGUOUS→NON_PRIORITY (correct) | cdada69d eligible but not consumed | FAIL | GAP-3b: NOT_NOW post-processor gap |
| Pricing | 4865 | OFFER_EXPLANATION (WRONG) | 48e10cac instead of 493884ad | FAIL | AI misclassification |

**Remaining gaps requiring next session:**

1. **GAP-3b:** cdada69d post-processing not implemented for NOT_NOW/FIXED_TEMPLATE path. Draft says "close the loop" — needs "when to check back" question. Requires narrow Decision patch to NOT_NOW style rule consumer.

2. **Classification correction for booking/pricing:** Booking walkthrough requests and minimum-commitment questions misclassified as OFFER_EXPLANATION. Recommended fix: add classification correction rules (similar to 6e50fd54 pattern) for BOOKING_REQUEST and PRICING_REQUEST signals within OFFER_EXPLANATION context.

**Recommended next actions (owner):**
1. Verify review form renders modern UI (no `draft_revision_type` dropdown, yes `Save draft and learning` button).
2. Next Claude Code session: patch GAP-3b (NOT_NOW post-processor for cdada69d style guidance).
3. Decide booking/pricing classification fix approach (correction rules recommended).
4. Fresh live retest after Decision patch.

---

## 2026-07-04 — SL-PHASE-5Q Self-Improvement Behavioural Closure (COMPLETE)

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Root-cause all self-learning behavioural failures; create harness; patch all 4 gaps.

**Files changed:**
- `reports/SL-PHASE-5Q_BASELINE_EVIDENCE_RECONCILIATION.md` — created (session 1), unchanged (session 2)
- `reports/SL-PHASE-5Q_SELF_IMPROVEMENT_BEHAVIOURAL_CLOSURE.md` — created (session 1); updated to COMPLETE + patch status (session 2)
- `reports/SL-PHASE-5Q_ANTI_FALSE_POSITIVE_AUDIT.md` — created (session 1); updated post-patch verdicts (session 2)
- `scripts/SL-PHASE-5Q-self-improvement-behavioural-closure.py` — created 44/44 (session 1); updated to 66/66 with P1-P4 post-patch tests (session 2)
- `workflows/nodeD_backup_889e1d45.js` — backup of Decision Node D before patch
- `workflows/nodeD_patched.js` — patched Decision Node D (all 4 gaps, pushed to production)
- `workflows/production_decision_current.json` — updated from production (versionId `a3916c2e`)
- `workflows/production_humanapproval_current.json` — updated from production (versionId `54b7a8e4`)
- `OPERATION_HANDOFF.md` — this entry

**Production workflow changes:**

| Workflow | ID | Old versionId | New versionId | Patches |
|----------|----|---------------|---------------|---------|
| Decision | `tgYmY97CG4Bm8snI` | `889e1d45` | `a3916c2e` | GAP-1, GAP-2, GAP-3 |
| HumanApproval | `9aPrt92jFhoYFxbs` | `0fa9d0ce` | `54b7a8e4` | GAP-4 |

**No Sender triggered. No Instantly POST. Shadow Evaluator (`aHzLtQiv6G8h1bqD`) not touched. Gate 2 unapproved.**

**Patches applied (Decision Node D, versionId a3916c2e):**

- **GAP-1 (booking post-processor):** `_5qApplyActiveFormRuleInstructionToDraft` now detects `instructionUrl`. If URL present → email-content mode (extract booking link). If no URL and instruction matches constraint pattern (`replace the previous|do not ask|do not say|do not use`) → policy-constraint mode: renders template without pasting instruction meta-phrases as email lines. Eliminates hyper-literal booking draft from 97eb3b0a.

- **GAP-2 (pricing constraints):** New function `_5qApplyPricingConstraints` added to post-processing chain. When `behaviouralGuidance` from rule 493884ad is present (marker check + `do not dodge pricing` signal), replaces the hardcoded evasive pricing paragraph with a per-shown-call / setup-fee pricing line. No invented prices. Pilot line added when guidance mentions "small pilot".

- **GAP-3 (NON_PRIORITY template):** `NON_PRIORITY` added to `_5qDraftPolicyFor` → `"FIXED_TEMPLATE"`. `templateMicroIntent` maps `NON_PRIORITY` → `NOT_NOW`. NON_PRIORITY cases now produce a NOT_NOW template draft (not null), enabling cdada69d style rule post-processing.

**Patch applied (HumanApproval Node J, versionId 54b7a8e4):**

- **GAP-4 (revision reason prefill):** `_5pSavedRevisionReason` variable added. For sent-case reopens (`RESPONSE_APPROVED`/`LEARNING_REVISION_APPROVED`), reads `decision_payload.draft_revision_reason` and prefills the `draft_revision_reason` textarea. New cases and old cases without saved reason start blank.

**Harness: 66/66 PASS** (was 44/44 pre-patch; P1-P4 post-patch sections added).

**Key finding — local Decision file is STALE:**
Local `production_decision_current.json` versionId `e1b84f34` ≠ production `889e1d45`.
Production Decision has 1253-line Node D with full 5Q learning infrastructure (Q12 DataTable lookup, policy matching, classification correction, AI prompt injection). Local file has 393-line stale version.
**Action required: update local workflow export after any future Decision patch.**

**Root causes confirmed:**

1. **Booking hyper-literal (case-7c87d21a):** `_5qApplyActiveFormRuleInstructionToDraft` extracts sentences from `97eb3b0a`'s behavioral specification and pastes them as email content. The instruction contains no URL → booking link is null → draft becomes garbled instruction fragments.

2. **Old booking rule (c9860e74) suppression:** WORKING CORRECTLY via scope deduplication. `97eb3b0a` wins (newer timestamp). Not a bug — the literal application (root cause #1) is the only booking failure.

3. **Pricing no delta (case-d555bcfd):** Rule `493884ad` eligible, guidance built, but `AI_COMMERCIAL_SUPERVISED` branch uses a hardcoded deterministic template that never reads `behaviouralGuidance`. Pipeline gap — guidance built but has no consumer.

4. **Setup/process rule (case-083fe26e):** Rule `48e10cac` eligible, guidance IS injected into AI prompt for OFFER_EXPLANATION (AI_SUPERVISED_OR_TEMPLATE). If "no output delta" was observed, it may be an AI compliance issue (AI ignoring guidance) or a measurement artifact. Not a code injection failure.

5. **Not-now/later → HUMAN_ONLY (case-5fa982f4):** Classification rule `6e50fd54` correctly changes AMBIGUOUS/AMBIGUOUS_SHORT_REPLY → NON_PRIORITY. But `NON_PRIORITY` is not in the draft policy map → defaults to HUMAN_ONLY → `draft_text=null`. Style rule `cdada69d` is eligible but has no pathway to reach the draft.

6. **Reopened form reasons:** Node J doesn't prefill `draft_revision_reason` textarea from case history on reopen. Reply text IS prefilled; reasons are not.

**Harness results:** 44/44 PASS (all rules, leakage tests, safety checks, attribution tests).

**Patches applied:** All 4 gaps patched. See patch detail block above.

**Old/new versionIDs:** Decision `889e1d45` → `a3916c2e`. HumanApproval `0fa9d0ce` → `54b7a8e4`.

**Recommended next actions (owner):**
1. Live test GAP-1: BOOKING_REQUEST case — verify draft has no policy meta-phrases ("Replace the previous", "Do not ask them").
2. Live test GAP-2: PRICING_REQUEST case with rule 493884ad active — verify commercial draft shows setup-fee / per-shown-call wording.
3. Live test GAP-3: AMBIGUOUS/AMBIGUOUS_SHORT_REPLY case with rule 6e50fd54 active — verify NON_PRIORITY classification produces NOT_NOW template draft.
4. Live test GAP-4: Reopen a previously approved case — verify `draft_revision_reason` textarea is prefilled.
5. If all 4 live tests pass → SL-PHASE-5Q VERIFIED COMPLETE. Start SL-PHASE-5R if further self-improvement scope identified.

---

## 2026-07-02 03:13 BST — Codex Strategic Repo Audit

**Agent:** Codex
**Objective:** Read-only strategic audit of current repo status and next highest-leverage task.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this concise audit entry only

**Current status observed:**
- Repo docs are inconsistent by age: `README.md` still describes the older six-workflow dry-run state, while newer docs/reports show a seven-workflow supervised responder, production workflow IDs, self-improvement patches, and autonomous shadow-review preparation.
- Latest repo evidence points to: core supervised responder operating in validation/supervised mode; self-improvement infrastructure installed with remaining behavioural proof for draft-improvement learning; autonomous Gate 2 not approved and blocked by the 14-day shadow review plus owner signoffs/allowlists.
- Worktree has many pre-existing modified files; future sessions should use narrow file scopes and avoid assuming a clean baseline.

**Recommended next task:**
Run the docs-guided, owner-supervised draft-improvement learning behavioural proof from `docs/NEXT_MANUAL_TEST_PACKET_DRAFT_IMPROVEMENT_LEARNING.md` before further autonomous Gate 2 work. This should be a Claude Code/manual-production-validation session, not a Codex implementation session.

---

## 2026-07-02 02:48 BST — Codex Business Brain Pilot

**Agent:** Codex
**Objective:** Verify that this repo is correctly connected to the HMZ Business Brain and that future Codex sessions can use the correct context without reading the full Obsidian vault.

**Files changed:**
- `OPERATION_HANDOFF.md` — added this timestamped pilot entry

**Files read:**
- `OPERATION_HANDOFF.md`
- `AGENTS.md`
- `README.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_BUSINESS_BRIEF.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_PROJECT_INDEX.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_SOURCE_PRIORITY.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\AI_CONTEXT\AI_AGENT_RULES.md`
- `C:\Users\Hamzah Zahid\Projects\hmz-business-brain\02_PROJECTS\INSTANTLY_RESPONDER.md`

**What was verified:**
- `AGENTS.md` is accurate, concise, and safe for future Codex sessions.
- `AGENTS.md` points to the Business Brain root at `C:\Users\Hamzah Zahid\Projects\hmz-business-brain`.
- `AGENTS.md` explicitly says not to read the full vault by default.
- `AGENTS.md` explicitly says this repo's `OPERATION_HANDOFF.md` takes precedence over Obsidian notes for current execution state.
- The named Business Brain files were read selectively; the full vault was not scanned or edited.

**Current status:** COMPLETE — documentation/control-file review only; no application code, scripts, workflows, configs, credentials, package files, tests, lockfiles, deployment files, or vault files were modified.

**Risks / unknowns:**
- `AI_CONTEXT/AI_AGENT_RULES.md` mentions `AI_CONTEXT/AI_CURRENT_PRIORITIES.md` in its general vault checklist, but this repo's `AGENTS.md` deliberately lists a narrower project-specific allowed set. Future sessions should follow repo instructions and current user instructions first.
- `02_PROJECTS/INSTANTLY_RESPONDER.md` still contains placeholder repo-reference fields and explicitly says not to rely on it for current state. This is low risk because both the repo and `AI_SOURCE_PRIORITY.md` direct agents back to `OPERATION_HANDOFF.md`.

**Recommended next step:**
Proceed with future Codex sessions using `OPERATION_HANDOFF.md`, `AGENTS.md`, and `README.md` first; read only the named Business Brain context files when the task needs business context.

---

## 2026-07-01 — Business Brain Connection

**Agent:** Claude Code (claude-sonnet-4-6)
**Objective:** Connect this repo to the HMZ Business Brain so Claude Code and Codex can access business-wide context safely.

**Files changed:**
- `CLAUDE.md` — added "Business Brain Context" section at end of file
- `AGENTS.md` — created; contains production target rules, safety defaults, source-of-truth table, and Business Brain Context section
- `OPERATION_HANDOFF.md` — created (this file)

**What was done:**
Documentation/control-file update only. No application code, scripts, workflows, configs, tests, package files, or credentials were modified. No vault files were read or edited. No secrets were stored.

**Current status:** COMPLETE — documentation update only; no production changes.

**Risks / unknowns:**
- The vault path `C:\Users\Hamzah Zahid\Projects\hmz-business-brain` has not been verified to exist in this session (per the hard rule against reading the vault without need). An agent reading `AI_CONTEXT/` files for the first time should confirm the path exists before acting on anything found there.
- `AI_CONTEXT/AI_SOURCE_PRIORITY.md` has not been read. Until it is, conflict-resolution between vault and repo files should default to favouring repo files (this file, `docs/SOURCE_PRIORITY.md`).
- `AGENTS.md` is new — Codex or other agents that auto-load it will pick up the vault-path pointer. Verify those agents respect the "read only when needed" rule before running them in this repo.

**Recommended next step:**
If the owner wants to use business-brain context in an upcoming session, open `AI_CONTEXT/AI_BUSINESS_BRIEF.md` and `AI_CONTEXT/AI_SOURCE_PRIORITY.md` at the start of that session to confirm the vault is current, then proceed with the specific task (e.g., campaign copy, offer positioning, or scope decisions).

**Recommended next agent:** Human review first. Then Codex should perform a documentation-only onboarding pass to verify `AGENTS.md` before any implementation task.
