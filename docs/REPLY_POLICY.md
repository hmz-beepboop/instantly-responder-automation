# Reply Policy — Phase 2 (supporting design reference)

Date: 2026-06-10. Design version: `policy-2026-06-10.2`.

> **Supersession notice.** This is a supporting design document only. For all business-logic decisions it is **superseded by `docs/HMZ_APPROVED_REPLY_RULES.md` (`policy-HMZ-1.2`)**. Where this file and the approved rules disagree, the approved rules win. Use this file for the shape of the deterministic prefilter and the action-plan mapping, not for thresholds, template wording, or category actions.

This document describes how the Reply Decision Engine maps an inbound reply to a **structured action plan** (not a single enum). Deterministic rules run first; AI runs only when deterministic rules don't fire; AI may never *cause* a hard suppression directly.

---

## 1. Taxonomy (16 categories) — corrected

| # | Category | One-line definition |
| --- | --- | --- |
| T1 | `positive_interest` | Clear positive interest or acceptance of the next step **without** a substantive factual/information request **and without** an explicit booking/scheduling request (see T3). |
| T2 | `information_request` | Asks how it works, "tell me more", "send information", or any proof/case-study/feature/mechanism/scope/comparison question. |
| T3 | `booking_request` | Explicit booking/scheduling intent (calendar link request, offered availability/times, or any other explicit request to schedule). Has its own approved template, which may reuse T1's wording, but is always recorded as T3 — never reclassified as T1 (`HMZ_APPROVED_REPLY_RULES.md` §3.1, §6). |
| T4 | `timing_objection` | Interest not denied; timing deferred ("not now, try Q3"). |
| T5 | `referral` | Redirects to a colleague. |
| T6 | `not_interested` | Declines but does not request suppression. |
| T7 | `unsubscribe` | Prospect-stated suppression request. |
| T8 | `out_of_office` | Auto-responder indicating absence. |
| T9 | `bounce_or_delivery_notice` | DSN / delivery failure **with delivery-status evidence**. |
| T10 | `wrong_person` | Wrong person / not in role, without a clear referral. |
| T11 | `pricing_or_commercial` | Price/discount/commercial terms/RFP/contract (in context). |
| T12 | `legal_privacy_complaint` | GDPR/CCPA/privacy/legal/attorney/lawsuit/"where did you get my data". |
| T13 | `hostile_or_reputational_risk` | Profanity directed at us, threats, extortion, doxxing. |
| T14 | `attachment_review_required` | Attachment present or referenced. |
| T15 | `ambiguous` | Below threshold or multiple competing categories. |
| T16 | `other` | None of the above. |

**Media/journalist/press/analyst contact is a human-review risk flag (P3M media track), NOT category T13.** It must not be auto-classified as hostile.

---

## 2. Deterministic prefilter (runs before AI)

Safety-critical rules may short-circuit; non-safety rules collect evidence and contribute to mixed-intent resolution (§2.5). Authoritative trigger lists are in `HMZ_APPROVED_REPLY_RULES.md` §5; the shapes below are design reference.

### 2.1 Hard-safety rules
| Rule | Trigger | Category |
| --- | --- | --- |
| `det-unsub-001` | prospect-stated opt-out language. **A `List-Unsubscribe` inbound header alone does NOT trigger this.** | T7 |
| `det-legal-001/002` | GDPR/CCPA/privacy/data; attorney/lawsuit/cease-and-desist | T12 |
| `det-regulator-001` / `det-complaint-001` | FTC/ICO/reporting/complaint | T12 |
| `det-hostile-001/002` | credible safety threat; profanity directed at recipient | T13 |
| `det-media-001` | journalist/reporter/press/analyst | **risk flag → human review (P3M)**, not T13 |

### 2.2 Bounce / OOO
| Rule | Trigger | Category |
| --- | --- | --- |
| `det-bounce-001/002` | daemon/postmaster address **or** undeliverable subject **with delivery-status evidence** (DSN/status code) | T9 |
| `det-ooo-001` | out-of-office / auto-reply markers | T8 |

An ordinary automated sender address (e.g. `noreply@`) is **not** a bounce without delivery-status evidence — route to human review if uncertain.

### 2.3 Pricing & attachment
| Rule | Trigger | Category |
| --- | --- | --- |
| `det-price-001` | pricing/commercial intent **in context** (not an isolated "price" token where context changes meaning) | T11 |
| `det-attach-001` | attachment present/referenced | T14 |

### 2.4 Strong-signal rules
| Rule | Trigger | Category |
| --- | --- | --- |
| `det-booking-001` | explicit booking language (calendar link request, offered availability/times, or any other explicit request to schedule), no price/attachment match | T3 |
| `det-referral-001` | "contact/reach out to X", "right person is" | T5 |
| `det-wrong-001` | "wrong person", "not in that role", no referral phrase | T10 |

Anything not matching goes to the AI classifier.

### 2.5 Mixed-intent resolution
Preserve all detected categories, questions, and risk flags. Select the final primary category by: (1) any safety/risk flag wins and is never erased by a lower-risk category; (2) otherwise the highest-priority substantive category; (3) else T15. Example: "Sounds interesting, but what's the price?" preserves the T1 signal but resolves to **T11** (escalate). "Sounds interesting, but stop emailing me" resolves to **T7**.

---

## 3. AI classifier
- Output: `category`, `confidence`, `secondary`, `slots`, `reasoning_excerpt` (≤280 chars, no PII), temperature 0.
- **Confidence is necessary, never sufficient.** Bands (`HMZ_APPROVED_REPLY_RULES.md` §4): ≥0.90 eligible if all pre-send gates pass; 0.60-0.899 route/escalate, no auto-reply; <0.60 → T15. (The old `0.85` band is removed.)
- **AI may never assign T7/T12/T13.** A proposed safety category becomes T15 → escalate with the proposed label attached. Hard suppression always requires deterministic evidence.
- In the Validation MVP the classifier is **mocked** until a real model integration is approved (`docs/IMPLEMENTATION_PLAN.md`).

---

## 4. Category → action plan (VALIDATION mode)

This replaces the single-enum matrix. Each category yields a structured action plan (`HMZ_APPROVED_REPLY_RULES.md` §3.1, §9.2). Summary of the send-relevant fields in VALIDATION mode:

| Category | stop/pause | suppression_level | reply_mode | send_allowed (default) |
| --- | --- | --- | --- | --- |
| T1 | stop | NONE | `AI_DRAFT_APPROVAL` / `FIXED_TEMPLATE_APPROVAL` | only after human approval |
| T2 | stop | NONE | `AI_DRAFT_APPROVAL` | no (human review) |
| T3 | stop | NONE | `FIXED_TEMPLATE_APPROVAL` | only after human approval |
| T4 | stop | NONE | `FIXED_TEMPLATE_APPROVAL` | only after human approval |
| T5 | stop | NONE | `FIXED_TEMPLATE_APPROVAL` (ack) | only after human approval |
| T6 | stop | NONE/`STOP_ACTIVE_SEQUENCE` | `FIXED_TEMPLATE_APPROVAL` (ack, if enabled) | only after human approval |
| T7 | stop | strongest **verified** toward org DNC | `FIXED_TEMPLATE_APPROVAL` (confirmation, if enabled) | confirmation only after verified suppression |
| T8 | pause | NONE | `NO_REPLY` | no |
| T9 | stop sends | NONE (data cleanup) | `NO_REPLY` | no |
| T10 | stop | `STOP_ACTIVE_SEQUENCE` | `FIXED_TEMPLATE_APPROVAL` (ack, if enabled) | only after human approval |
| T11 | stop | NONE | `HUMAN_ONLY` | no |
| T12 | stop | `REVIEW_HOLD` + verified | `HUMAN_ONLY` | no |
| T13 | stop | `REVIEW_HOLD` + verified | `HUMAN_ONLY` | no |
| T14 | stop | NONE | `HUMAN_ONLY` | no |
| T15 | stop | NONE | `HUMAN_ONLY` | no |
| T16 | stop | NONE | `HUMAN_ONLY` | no |

`reply_mode` values: `NO_REPLY`, `FIXED_TEMPLATE_AUTO` (PROVEN only), `FIXED_TEMPLATE_APPROVAL`, `AI_DRAFT_APPROVAL`, `HUMAN_ONLY`. T12/T13 always carry `stop_sequence=true` + `REVIEW_HOLD` + a paired suppression level — they can never keep receiving campaign messages. `legal_review_required`, `privacy_review_required`, and `reputational_review_required` are independent booleans set per the detected risk type, not all three for every case (`HMZ_APPROVED_REPLY_RULES.md` §7, §7.1).

---

## 5. Pre-send gate (all applicable gates required)
Any candidate send must pass the full gate list in `HMZ_APPROVED_REPLY_RULES.md` §9.1 (category, operating mode, allowlist, sender, template/KB version, no risk flag, suppression clear, idempotency clear, thread mapping verified, send mechanism verified, variables valid, `DRY_RUN=false` by approval). Confidence alone never authorises a send.

---

## 6. Suppression mechanics
Suppression is expressed as a `suppression_level` (`HMZ_APPROVED_REPLY_RULES.md` §7). The interest-status (B6), subsequence-removal (B7), and exact email-level Blocklist (B8) mechanisms are VERIFIED (`docs/ASSUMPTIONS_AND_UNKNOWNS.md` B6/B7/B8; `reports/INSTANTLY_VERIFICATION_EVIDENCE.md` V4B/V4C/V4D).

Ordinary unsubscribe (interest-status / campaign stop) is **campaign-local under tested conditions** (V4E4) — it is not a workspace-wide suppression. Workspace-wide suppression requires the **exact email-level Blocklist action** (V4D) in addition to the source-campaign action. `T7` action plans must record both as required, not as an either/or, and escalate if either fails or is uncertain.

---

## 7. Templates
Versioned (`template_id` + `template_version`). Approved wording is in `HMZ_APPROVED_REPLY_RULES.md` §6 (authoritative). No prices, claims, guarantees, or availability. The former T1 "how it works" variant is now a **T2** draft (KB-grounded, human review). Templates reviewed and approved by the owner before any live cutover.

---

## 8. Policy versioning
Every decision stores `policy_version`, `template_version`, `kb_version`, and `operating_mode`. A change to any rule, template, threshold, or mode bumps the version. Re-classification of a stored event uses `replay=true`. The Test Harness asserts at least one fixture per category per active version.
