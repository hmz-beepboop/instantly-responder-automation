# HMZ Approved Reply Rules

Version: `policy-HMZ-1.2`
Date: 2026-06-10 (surgical correction pass; supersedes `policy-HMZ-1.1`)
Status: **Business-partner review draft. Not approved for live deployment.**
Source: Owner-approved Grill-Me interview (`brainstorms/2026-06-09-instantly-rapid-reply-policy.md`), reconciled against the business-source hierarchy in `docs/SOURCE_PRIORITY.md`, the validation-stage objective, the five-minute objective, technical feasibility, and safety. Changes from `1.0` to `1.1` are logged in `docs/PHASE_2_CORRECTION_CHANGELOG.md`; changes from `1.1` to `1.2` are logged in `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md`.

This is the authoritative operational reply-policy source. It supersedes the design-only `docs/REPLY_POLICY.md` for all business-logic decisions. It does **not** invent business facts — those come from the approved knowledge base.

---

## 0. Grill Me reconciliation (disposition of each owner-approved decision)

The Grill Me decisions are owner-provided preferences. They are authoritative only where they do not conflict with the business sources, the five-minute objective, safety, or technical feasibility. Originals are preserved in `docs/PHASE_2_CORRECTION_CHANGELOG.md`.

| Decision | Disposition | Note |
| --- | --- | --- |
| Four auto-send categories (T1/T3/T4/T6) at ≥0.90 | **Replaced for Validation MVP** | VALIDATION mode requires human approval before substantive sends; original restorable in PROVEN mode after testing + owner override (C2). |
| 0.90 auto-send / 0.60 escalation thresholds | **Preserved with correction** | Score is necessary, never sufficient; full send-gate list now required (C3). |
| Quiet hours Mon-Fri 08:00-18:00, 24h hold, weekend/holiday rules | **Deferred to Production** | Removed from MVP; process immediately. Original retained in `docs/ARCHITECTURE.md` Production profile (C4). |
| US federal-holiday calendar service | **Deferred to Production** | Not required for MVP (C4). |
| Three Slack channels | **Deferred to Production** | MVP uses one configurable human-review destination + urgency field (C13). |
| Google Sheets durable audit | **Deferred to Production** | MVP needs one durable case record; technology deferred (C9/C14). |
| Email fallback | **Deferred to Production** | Optional in MVP; owner may select (C13). |
| Organisation-wide unsubscribe suppression | **Preserved with correction** | Execute strongest **verified** suppression level; human task closes the gap to org-wide; blocked levels need owner-confirmed mechanisms (C12). |
| Campaign allowlisting (deny-all, exact ID) | **Preserved unchanged** | Sound deterministic control. |
| Fixed partner-approved templates | **Preserved unchanged** | Wording retained verbatim in §6. |
| Sender mappings / booking links | **Preserved, blocked pending owner input** | Required before any send. |
| Classifier / draft-generator separation | **Preserved unchanged** | §13. |
| T1 "how does it work / tell me more" (old Scenario B) | **Replaced** | Reclassified as T2 information request (C11). |
| Suppression-before-confirmation (T7) | **Preserved unchanged** | Core safety rule. |
| NOOP for T8/T9; no-reply for legal/hostile | **Preserved unchanged** | |
| Holding-reply disabled by default | **Preserved unchanged** | |
| English-only initial scope | **Preserved unchanged** | |
| Prohibited content list | **Preserved, extended** | Adds Alpha-Offer prohibitions (C1). |

---

## 1. Context and maturity statement

**Scope:** this policy governs HMZ's own initial US B2B validation campaign only (`CLAUDE.md` "Scope"). It is not a client-facing reply policy and does not authorise responding on behalf of any other party.

The campaign promotes a **validation-stage** capacity-aligned outbound model for US B2B companies (see `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`). The offer is pre-case-study: no customers, revenue, testimonials, or proven results. Buyer pain and willingness to pay are still being validated. It must never be described as proven, established, or guaranteed.

**Desired next step from a reply:** a brief 10-minute discovery/validation conversation with the founder, CEO, or VP of Sales — not a pitch for a full service.

**Target buyer (hypothesis):** Founder / CEO / VP of Sales at US-based B2B SaaS, ~10-50 employees, mid-market or enterprise sales motion, ACV ~$10k-$60k+. Primary geography: US only (initial), ET and CT time zones prioritised.

**Campaign context fields.** Every event carries `validation_cell` (`CELL_1_SAAS_SALES_HIRING` / `CELL_2_SAAS_EXISTING_OUTBOUND` / `CELL_3_SPECIALISED_B2B_AGENCY`), `segment`, `subsegment`, `pain_trigger`, `offer_angle`, `geo_code` (`US_B2B_CORE_12`), `campaign_purpose`, and `campaign_message_variant`, sourced from `docs/VALIDATION_CAMPAIGN_CONFIG.md` via the campaign-ID lookup defined in `docs/NORMALIZED_EVENT_SCHEMA.md`. Both the classifier and the draft generator receive this context. **Cell 3 (specialised B2B agency) drafts must use the agency-specific `segment`/`pain_trigger`/`offer_angle` and must never default to SaaS-specific language.** A `geo_code` mismatch (a reply from outside `US_B2B_CORE_12`) is **not** an automatic rejection or suppression reason — it sets a human-review flag on the case for an owner to judge.

---

## 2. Operating modes

The first campaign is **market validation**. Prospect replies are research evidence and must not be hidden by premature automation.

- **`OPERATING_MODE=VALIDATION` (default).** No substantive prospect reply auto-sends. Replies are drafted or matched to a fixed template, the operator is notified immediately, and a human approves before any send. Deterministic safety actions (sequence stop, suppression for opt-out/legal/hostile) still execute automatically.
- **`OPERATING_MODE=PROVEN` (documented, not active).** May later allow broader fixed-template auto-sending only after: synthetic evaluation, controlled live testing, labelled real-reply review, demonstrated template safety, explicit owner approval, an approved knowledge base, and verified suppression and send mechanisms. PROVEN mode is not currently active and must not be treated as active.

Per-category mode rules are in §3.1 (VALIDATION) and §3.2 (PROVEN deltas).

---

## 3. Reply taxonomy and action matrix

### 3.1 VALIDATION mode (default)

| ID | Category | Sequence | Suppression | Reply mode | Human approval | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | Positive interest (no substantive info request, no explicit booking/scheduling request) | stop | NONE | `AI_DRAFT_APPROVAL` or `FIXED_TEMPLATE_APPROVAL` | Required | Draft immediately, notify urgently. If the reply also contains an explicit scheduling/booking ask, classify T3 instead (§6). |
| T2 | Information request ("how does it work", "tell me more", "send info", proof/case-study/feature/mechanism/scope) | stop | NONE | `AI_DRAFT_APPROVAL` | Required | Draft only from approved KB; `UNKNOWN` where unsupported. |
| T3 | Booking request (explicit scheduling intent: calendar link request, offered availability/times, or any other explicit request to schedule — det-booking-001) | stop | NONE | `FIXED_TEMPLATE_APPROVAL` | Required initially | Has its own approved template (§6); may reuse the T1 booking-link wording but stays classified T3. Fixed-template auto-send only after controlled testing + owner approval (PROVEN). |
| T4 | Timing objection | stop | NONE | `FIXED_TEMPLATE_APPROVAL` | Required initially | No promise of automated follow-up unless explicitly authorised. |
| T5 | Referral | stop | NONE | `FIXED_TEMPLATE_APPROVAL` (ack only) | Required | Never auto-contact the referred person. |
| T6 | Not interested | stop | `NONE`/`STOP_ACTIVE_SEQUENCE` | `FIXED_TEMPLATE_APPROVAL` (ack only, if enabled) | Required | Do not continue selling. |
| T7 | Unsubscribe | stop | strongest **verified** level toward org-wide DNC | `FIXED_TEMPLATE_APPROVAL` (confirmation only, if enabled) | Suppression auto; confirmation after verified suppression | Suppression precedes any confirmation. |
| T8 | Out of office | pause | NONE | `NO_REPLY` | n/a | Not buying intent; record explicit return date only if reliable. |
| T9 | Bounce / delivery notice | stop sends to address | NONE (data cleanup) | `NO_REPLY` | n/a | Route for data cleanup; never reply to MAILER-DAEMON. |
| T10 | Wrong person | stop | `STOP_ACTIVE_SEQUENCE` | `FIXED_TEMPLATE_APPROVAL` (ack only, if enabled) | Required | Do not auto-contact a named referral. |
| T11 | Pricing / commercial | stop | NONE | `HUMAN_ONLY` | Required | No automated substantive reply. |
| T12 | Legal / privacy / complaint | stop immediately | `REVIEW_HOLD` + strongest verified | `HUMAN_ONLY` | Urgent | Stop outreach; create urgent case; set `legal_review_required` and/or `privacy_review_required` per detected risk (§7.1). |
| T13 | Hostile / reputational risk | stop immediately | `REVIEW_HOLD` + strongest verified | `HUMAN_ONLY` | Urgent | Do not argue or improvise; urgent case; set `reputational_review_required` and/or `legal_review_required` per detected risk (§7.1). |
| T14 | Attachment-dependent | stop | NONE | `HUMAN_ONLY` | Required | Never claim the attachment was reviewed. |
| T15 | Ambiguous | stop | NONE | `HUMAN_ONLY` | Required | Neutral acknowledgement only if specifically approved. |
| T16 | Other | stop | NONE | `HUMAN_ONLY` | Required | Fail closed. |

Reply modes: `NO_REPLY`, `FIXED_TEMPLATE_AUTO`, `FIXED_TEMPLATE_APPROVAL`, `AI_DRAFT_APPROVAL`, `HUMAN_ONLY` (see §3.3). In VALIDATION mode, `FIXED_TEMPLATE_AUTO` is never used for substantive prospect replies.

### 3.2 PROVEN mode deltas (not active)
After all PROVEN-mode gates are met, T3 (and, subject to separate owner approval, T4/T6/T10 acknowledgements and T7 confirmations) may move from `*_APPROVAL` to `FIXED_TEMPLATE_AUTO`. T11/T12/T13/T14/T15/T16 remain `HUMAN_ONLY` in all modes. T2 remains human-review (no auto-send) until separately approved.

### 3.3 Reply-mode definitions
- `NO_REPLY` — no prospect-facing reply at all.
- `FIXED_TEMPLATE_AUTO` — a fixed, approved template sent automatically (PROVEN mode only; never for human-only categories).
- `FIXED_TEMPLATE_APPROVAL` — a fixed, approved template held for human approval before send.
- `AI_DRAFT_APPROVAL` — an AI draft grounded only in the approved KB, held for human approval.
- `HUMAN_ONLY` — no automated draft of a sendable reply; human composes any response.

---

## 4. Classifier confidence thresholds (necessary, never sufficient)

A confidence score may gate a category's eligibility but **never authorises a send by itself**. Every applicable gate in §9.1 must also pass.

| Confidence band | Effect |
| --- | --- |
| ≥0.90 | Category may proceed to its policy-defined action **if** all §9.1 gates also pass. Does not authorise a human-only category. |
| 0.60-0.899 | Retain category for internal routing only. Block all automatic prospect replies. Escalate for human review. |
| <0.60 | Override to T15 AMBIGUOUS. Stop sequence. Escalate. |

A legal, privacy, complaint, hostile, safety, media, unsubscribe, attachment, or conflicting-risk indicator overrides the confidence score and follows the safer path regardless of value. Thresholds remain pending validation against a labelled evaluation set (§13) and require owner approval to change.

---

## 5. Deterministic prefilter and mixed-intent handling

Deterministic rules run before AI. **Safety-critical rules may short-circuit; non-safety rules collect evidence rather than blindly routing on first match.** All detected categories, questions, and risk flags are preserved for mixed-intent replies.

**Primary-category selection (mixed intent):** evaluate all matches, then select the final primary category by this precedence — (1) any safety/risk flag (unsubscribe, legal, privacy, complaint, hostile, media, attachment) wins and is never erased by a lower-risk category; (2) otherwise the highest-priority substantive category present; (3) if genuinely unclear, T15. A lower-risk category must never erase a legal, unsubscribe, privacy, or hostile flag.

### 5.1 Hard-safety rules (may short-circuit)

| Rule | Trigger | Category | Action |
| --- | --- | --- | --- |
| det-unsub-001 | "unsubscribe", "remove me", "take me off", "opt out", "stop emailing", "stop contacting", "do not contact me again", "take me off your list", "please delete me from your outreach", or equivalent do-not-contact language stated **by the prospect** | T7 | suppression-pending |
| det-legal-001 | "gdpr", "ccpa", "hipaa", "privacy act", "data protection", "right to be forgotten", "where did you get my email/data/info" | T12 | escalate, P3 |
| det-legal-002 | "attorney", "lawyer", "legal counsel", "lawsuit", "cease and desist", "c&d" | T12 | escalate, P2 |
| det-regulator-001 | "ftc", "ico", "reporting you to", "filing a complaint with" | T12 | escalate, P2 |
| det-hostile-001 | credible personal-safety threat, extortion, doxxing threat | T13 | escalate, P1 |
| det-media-001 | "journalist", "reporter", "press", "writing an article about", analyst/publication enquiry | **risk flag → human review** (P3M media track) | Do **not** auto-class as hostile. |
| det-hostile-002 | profanity directed at recipient; threats | T13 | escalate, P2 |
| det-complaint-001 | "spam", "reported you", "reporting this to", "continued contact after" | T12 | escalate, P2 |

**Inbound `List-Unsubscribe` header is NOT evidence the prospect personally requested opt-out.** It is a standard mail header and must not by itself trigger T7. Only prospect-stated opt-out language does.

`det-unsub-001` (prospect-stated) overrides other categories in the same reply: "This sounds interesting, but stop emailing me" is T7.

### 5.2 Bounce and OOO rules

| Rule | Trigger | Category | Action |
| --- | --- | --- | --- |
| det-bounce-001 | `from_address` is a daemon/postmaster/bounce address **and** the message carries delivery-status evidence (DSN, "delivery failed", status code) | T9 | data cleanup |
| det-bounce-002 | Subject/body matches undeliverable/delivery-failure/returned-mail/mailbox-full **with** delivery-status evidence | T9 | data cleanup |
| det-ooo-001 | "out of office", "on vacation/holiday/leave", "annual/parental leave", "sabbatical", "automatic reply", "away from the office" | T8 | pause |

An ordinary automated sender address alone (e.g. a `noreply@`) is **not** a bounce without supporting delivery-status evidence; route to human review if uncertain.

### 5.3 Pricing and attachment rules

| Rule | Trigger | Category | Action |
| --- | --- | --- | --- |
| det-price-001 | Pricing/commercial intent ("your price/cost/quote", "rfp", "rfi", "contract", "msa", "sow", "discount", "enterprise pricing") **in context** — not an isolated token like "price" where surrounding context changes the meaning | T11 | escalate |
| det-attach-001 | attachment present or referenced | T14 | escalate |

### 5.4 Strong-signal rules

| Rule | Trigger | Category | Action |
| --- | --- | --- | --- |
| det-booking-001 | "book a time", "send me your calendar", "schedule a call", "send a calendar link", "calendly", prospect offers specific availability/times ("I'm free Tuesday at 2pm", "what times work for you?"), or any other explicit request to schedule — AND no price/attachment match | T3 | template-approval |
| det-referral-001 | "please contact", "reach out to", "talk to", "forward you to", "the right person is", "this is handled by" | T5 | escalate |
| det-wrong-001 | "wrong person", "wrong address", "not the right person", "not in that role", "I no longer work here", "I'm not with that company" AND no referral phrase | T10 | stop + escalate |

---

## 6. Approved reply templates

### Tone rules (all templates)
Warm, concise, commercially professional, transparent, calm. No em dashes. No generic AI language. No overenthusiasm. Use `{{firstName}}` only when it passes validation (§9). Never imply the offer is proven, mention unsupported results, introduce pricing, or make guarantees.

### T1 — Positive interest (no substantive info request, no explicit booking/scheduling request)

**Scenario A — Prospect agrees to a conversation without an explicit scheduling ask** ("I'd be open to a call", "Let's chat", "Sounds good, happy to talk"):

> Thanks, {{firstName}}. Happy to talk it through.
>
> We're currently validating the capacity-aligned outbound model with a small number of US B2B teams. The first step is a brief 10-minute conversation to understand how you currently handle outbound and whether the problem is relevant.
>
> You can choose a suitable time here: {{bookingLink}}
>
> Or reply with a couple of times that work for you and I'll coordinate it.
>
> {{senderName}}

No qualifying question. Prospect has already accepted the next step.

**If the reply also contains an explicit scheduling/booking request** — asks for a calendar link, offers specific availability/times, says "send me your calendar," or otherwise explicitly asks to schedule (det-booking-001, §5.4) — classify the reply **T3, not T1**, even though the wording above may still be the appropriate reply. See "T3 — Booking request" below.

**Scenario C — Genuine but unclear positive interest** ("Interesting", "Possibly", "Go on", "I may be interested"):

> Thanks, {{firstName}}. Happy to share more.
>
> Would it be more useful for me to explain the capacity model here, or would you prefer a brief 10-minute conversation?
>
> {{senderName}}

One lightweight routing question is acceptable since intent is unclear.

**(Former Scenario B — "how does it work?" / "tell me more" — moved to T2. See §8.)**

**Validation wording rule:** Only say "a small number of US B2B teams" if participants have actually entered validation. Until then use: "US B2B teams."

### T3 — Booking request

Trigger: the prospect's reply contains an **explicit scheduling/booking request** — asks for a calendar link, offers specific availability/times, or otherwise explicitly asks to schedule (det-booking-001, §5.4). This is classified **T3**, even when the surrounding wording also expresses positive interest — the explicit scheduling ask is the deciding signal that distinguishes T3 from T1.

T3 reuses the T1 Scenario A booking-link wording as its approved template:

> Thanks, {{firstName}}. Happy to talk it through.
>
> We're currently validating the capacity-aligned outbound model with a small number of US B2B teams. The first step is a brief 10-minute conversation to understand how you currently handle outbound and whether the problem is relevant.
>
> You can choose a suitable time here: {{bookingLink}}
>
> Or reply with a couple of times that work for you and I'll coordinate it.
>
> {{senderName}}

Reusing this wording does not reclassify the reply as T1 — `category=T3` is recorded, with reply mode `FIXED_TEMPLATE_APPROVAL` (§3.1). Fixed-template auto-send only after controlled testing + owner approval (PROVEN mode).

### T4 — Timing objection

**Scenario A — Specific future period** ("Try Q4", "Reconnect next quarter"):

> Thanks, {{firstName}}. Understood.
>
> I'll close the loop for now. If it is still relevant around {{followUpPeriod}}, we can reconnect then.
>
> {{senderName}}

Stop sequence; record stated timeframe as an internal follow-up note. Do NOT promise an exact date unless specifically agreed. Do NOT auto-resume the old sequence. Do NOT promise an automated follow-up unless explicitly authorised.

**Scenario B — Vague timing** ("Not now", "Maybe later"):

> Thanks, {{firstName}}. Understood.
>
> I'll close the loop for now. Feel free to reach out if the timing changes.
>
> {{senderName}}

Stop sequence. No generic re-engagement.

**Re-engagement rules:** (1) specific future period → one internal follow-up record; (2) explicit permission → one controlled re-contact within the permitted timeframe; (3) vague "later" → no automated follow-up; (4) before any future re-contact confirm no unsubscribe/complaint/legal, still same role, no active conversation, offer/campaign still accurate; (5) any future message freshly written, never restarts the stopped sequence, never refers to a promised date unless one was agreed. Prohibited: pricing, scarcity, performance claims, guarantees, pressure, readiness claims, new pitch.

**Validation MVP note:** any timeframe recorded from a T4 reply is stored on the case record as `follow_up_date` and is **non-executable metadata** for the Validation MVP — it does not trigger any automated re-contact, reminder, or sequence resume. Any future re-contact is a fresh, human-initiated, human-reviewed action per the re-engagement rules above, not an automated follow-up driven by `follow_up_date`.

### T5 — Referral

**Acknowledgement template (sent once to the original prospect, in all T5 cases):**

> Thanks, {{firstName}}. I appreciate the direction. I'll leave that with you.
>
> {{senderName}}

Stop sequence for original prospect. Classify `REFERRAL`. Preserve referred person's name/role/company/email/context. Send ack once. Create human-review task. **Never** auto-add, auto-enrol, auto-forward, or contact the referred person before human verification (real, in-role, ICP match, independently verified email, suppression-checked, approved wording).

**Optional, separate decision — human-approved intro-request wording.** This is a distinct action from the acknowledgement above: a human reviewer may choose to ask the original prospect to make the introduction themselves. It requires its own approval and is never sent automatically:

> Thanks, {{firstName}}. I appreciate the direction. If you're comfortable introducing us by email, that would be helpful, but no problem if you would rather leave it with me.
>
> {{senderName}}

Automated intro requests to the referred person remain prohibited regardless of which of the above is sent.

### T6 — Not interested (acknowledgement only if enabled)

> Thanks, {{firstName}}. Understood.
>
> {{senderName}}

Stop sequence, record `NOT_INTERESTED` (separate from `UNSUBSCRIBE`), send once. No future-contact invitation, no offer reminder, no re-engagement. **Do not send** (remain silent) when: unsubscribe present; legal/privacy/complaint; hostile; OOO/bounce; cannot confidently classify as genuine decline; ack already sent. Boundaries: "we're all set"/"not the right fit"/"thanks but no thanks" = T6; "remove me"/"stop emailing" = T7; timing language = T4; "we already use another provider" = T6 unless a comparison question is asked (then T2).

### T10 — Wrong person (acknowledgement only if enabled)

> Thanks for letting me know, {{firstName}}. Apologies for the mix-up.
>
> {{senderName}}

Stop sequence, classify `WRONG_PERSON`/`NO_LONGER_IN_ROLE`, mark contact unsuitable, send ack once, create human re-routing task if account still relevant. Not an org-wide unsubscribe unless the person also asks not to be contacted. Do not auto-contact a named referral.

### T7 — Unsubscribe confirmation (only after verified suppression, if enabled)

> Understood, {{firstName}}. You have been removed from future outreach.
>
> {{senderName}}

**Send the confirmation ONLY after suppression has successfully completed. Never confirm first.** See §7 for suppression levels and the suppression-before-confirmation rule.

**No-name variants:** "Thanks, {{firstName}}. Happy to talk it through." → "Happy to talk it through." / "Thanks, {{firstName}}. Understood." → "Understood." / "Understood, {{firstName}}. You have been removed from future outreach." → "Understood. You have been removed from future outreach." / "Thanks, {{firstName}}. I appreciate the direction. I'll leave that with you." → "I appreciate the direction. I'll leave that with you."

---

## 7. Suppression semantics (levels)

`suppression_level` is an explicit field, not a loose "SUPPRESS". Each level maps to a business outcome → verified mechanism → provisional fallback → human task when no verified API exists. Not all operations are assumed available (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`).

| Level | Meaning | Mechanism status |
| --- | --- | --- |
| `NONE` | No suppression. | n/a |
| `STOP_ACTIVE_SEQUENCE` | Stop the current campaign sequence for this lead (record preserved). | PROVISIONAL — interest-status change; body unverified (B6). |
| `CAMPAIGN_ONLY` | Stop/suppress within the current campaign only. | PROVISIONAL. |
| `WORKSPACE_DNC` | Do-not-contact across the Instantly workspace. | BLOCKED — blocklist API unverified (B8). Human UI task fallback. |
| `ORGANISATION_DNC` | DNC across all HMZ-controlled workspaces, domains, and outbound tools/databases. | BLOCKED — requires owner-confirmed systems + central DNC register. Human task. |
| `GLOBAL_BLOCKLIST` | Hard global blocklist preventing any future contact/import. | BLOCKED — mechanism unverified. Human task. |
| `REVIEW_HOLD` | Outreach halted pending human review of a legal, privacy, and/or reputational-risk signal; record preserved. `REVIEW_HOLD` is a neutral hold state — it does not by itself say *which* review is needed; that is recorded by the independent `legal_review_required`, `privacy_review_required`, and `reputational_review_required` booleans (§9.2). | Deterministic internal state. |

**Operational distinctions:** pausing a sequence ≠ stopping it ≠ removing from a subsequence ≠ marking not-interested ≠ unsubscribing ≠ workspace DNC ≠ organisation suppression ≠ global blocklist ≠ a review hold ≠ preserving the record while preventing further automation. The action plan names exactly which is intended. See §7.1 for the authoritative per-category mapping.

**T7 unsubscribe:** execute the strongest **verified** level immediately; raise a human task to close the gap to organisation-wide DNC (the owner's preference) wherever a mechanism is not yet verified. Maintain a central DNC register. Verify suppression succeeded **before** sending any confirmation. If suppression fails or is uncertain: do NOT send a confirmation; stop all current/queued sends; raise a high-priority alert; require manual resolution; record which systems still need suppression. Retain the minimum suppression record permanently. Audit: email address, source event ID, request timestamp, suppression-completion timestamp, systems updated, confirmation status, failed-propagation tasks, responsible operator.

**T12/T13:** suppress at `REVIEW_HOLD` plus the strongest verified level immediately; never auto-reply; create an urgent human case; preserve evidence. Set `legal_review_required`, `privacy_review_required`, and/or `reputational_review_required` based on the **detected risk type(s)** — not uniformly. For example: a GDPR/CCPA data-origin question (det-legal-001) sets `legal_review_required` and `privacy_review_required`; a profanity-driven complaint with no legal content (det-hostile-002) may set only `reputational_review_required`; a credible threat (det-hostile-001) sets both `reputational_review_required` and `legal_review_required`. **Not every hostile (T13) reply requires legal review** — only the flag(s) matching the detected risk are set, while `REVIEW_HOLD` and the paired suppression level still apply to every T12/T13 case. **T12/T13 can never continue receiving campaign messages** — the action plan always sets `stop_sequence=true` and a suppression level for these categories.

### 7.1 Stop vs suppression — explicit per-category mapping

"Stopping a sequence" and "suppression" are different operations. Stopping the active sequence for a lead does **not** imply any workspace, organisation, or global do-not-contact action; a durable suppression (workspace/org/global DNC) always also stops the sequence, but the reverse is not true. This mapping is authoritative:

- **T1-T5, T11, T14-T16:** stop the active sequence (`stop_sequence=true`, `suppression_level=NONE`). The lead remains otherwise contactable; no DNC action is taken.
- **T6 (Not interested):** stop the active sequence and record `interest_status_update=NOT_INTERESTED`. This is **not** an automatic organisation-wide unsubscribe — `suppression_level` stays `NONE` (or `STOP_ACTIVE_SEQUENCE`) unless the prospect separately uses do-not-contact language, which makes the reply T7 instead.
- **T7 (Unsubscribe):** the strongest **durable do-not-contact** intent. Execute the strongest **verified** suppression level immediately (at minimum `STOP_ACTIVE_SEQUENCE`, escalating toward `WORKSPACE_DNC` / `ORGANISATION_DNC` / `GLOBAL_BLOCKLIST` as mechanisms are verified). A human task closes the gap to organisation-wide DNC wherever a mechanism is not yet verified (see the T7 procedure above).
- **T8 (Out of office):** `pause_sequence=true` per the approved OOO rules (§8) — not a stop, not a suppression. No automated resume logic exists for the Validation MVP; the pause is human-monitored.
- **T9 (Bounce / delivery notice):** stop sends to the failed address and set `data_cleanup_required=true`. This is address-level data hygiene, not a DNC suppression level — the contact record is corrected or removed, not flagged as "do not contact."
- **T12/T13 (Legal/privacy/complaint, Hostile/reputational risk):** `REVIEW_HOLD` plus the strongest **justified verified** suppression level, applied immediately, with `stop_sequence=true` always. `REVIEW_HOLD` is a human-review state, not itself a contactability level — the paired suppression level (anywhere from `STOP_ACTIVE_SEQUENCE` up to `WORKSPACE_DNC`/stronger as justified) determines contactability while review is pending.

**Non-conflation rule:** `stop_sequence=true` (campaign-level, this lead) ≠ `WORKSPACE_DNC` (Instantly workspace-wide) ≠ `ORGANISATION_DNC` (all HMZ-controlled systems) ≠ `GLOBAL_BLOCKLIST` (hard global block) ≠ `REVIEW_HOLD` (human-review state, independent of contactability). Each is an independent action-plan field; none implies another except where this section states it does.

---

## 8. Human-review categories (no automated substantive send)

### T2 — Information request
Stop sequence. Draft (human review only) using **only** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. Includes "how does it work?", "tell me more", "send information", proof/case-study/feature/mechanism/scope questions. Record prospect's exact question, company, role, campaign, original outreach, thread context, and the KB source for every factual claim. Mark unavailable info `UNKNOWN`. Never auto-send. Case-study/proof requests must not imply results that do not exist.

### T11 — Pricing or commercial
Stop. Escalate for human commercial handling. No auto-reply, no pricing/proposal draft. Never invent/estimate a price, offer a discount, define scope, promise a timeline, create a proposal, define performance triggers, or make commitments. Pricing is human-only commercial information.

### T12 — Legal / privacy / complaint
No automated reply. Stop outreach immediately. Suppress (`REVIEW_HOLD` + strongest verified, with `legal_review_required`/`privacy_review_required` set per detected risk — §7.1). Create an urgent human case. Urgency tiers:

| Tier | Examples | Response |
| --- | --- | --- |
| P1 | Credible violence/doxxing/extortion threat; urgent court/regulatory deadline | Suppress immediately; notify primary AND backup owner immediately; urgent fallback. |
| P2 | FTC/ICO threat, attorney threat, formal complaint, alleged continued contact after opt-out, serious reputational threat | Suppress immediately; same-session human review; specialist review before any response. |
| P3 | "Where did you get my email?", GDPR/CCPA/deletion request, spam complaint without legal/safety threat | Suppress immediately; route to privacy/compliance owner; record any deadline. |
| P3M | Journalist/media/analyst enquiry | Stop outreach; classify `JOURNALIST_OR_MEDIA_INQUIRY`; distinct media track; only an authorised spokesperson responds; preserve enquiry/publication/identity/deadline/questions. Media is a **risk flag for human review, not automatically hostile.** |

Automation must never apologise, defend the outreach, explain legal basis, admit fault, promise deletion, or issue any substantive automated response.

### T13 — Hostile / reputational risk
Same framework as T12, appropriate urgency tier. Stop outreach immediately; do not argue or improvise; preserve evidence; urgent human case. Profanity alone is not automatically P1, but outreach still stops when hostility creates reputational/safety risk.

### T14 — Attachment-dependent
Stop. Escalate. No reply until a human reviews the attachment. Never claim to have read/summarised/accepted it. Do not auto-open executables, macro-enabled, password-protected, or suspicious files. Do not upload prospect material to an AI service unless an approved data-processing policy permits. If referenced but absent, flag for human handling.

### T15 — Ambiguous
Stop. No auto-reply. Escalate with full thread, candidate categories, confidence scores, risk signals, reason for uncertainty, recommended action. A neutral acknowledgement may be sent only if specifically approved.

### T16 — Other
Fail closed. Stop. Human review.

### T8 — Out of office
No automated reply. Pause sequence. Not buying intent, not a rejection. Extract a return date only when explicit and unambiguous. Multiple conflicting dates → human review. Named alternate contact → preserve, human review, never auto-contact.

### T9 — Bounce / delivery notice
No reply ever. Route for data cleanup. Never reply to MAILER-DAEMON/postmaster/automated addresses. Permanent failure → mark invalid, suppress sends to the address, prevent re-import without correction. Temporary failure → pause, apply approved retry policy or human review. Never guess a replacement email or auto-contact another employee.

### Holding-reply policy
**Disabled by default.** Never send "I'll come back to you shortly." Never for ambiguous, unsubscribe, legal/privacy, complaints, hostile, media, OOO, or bounces. May be reconsidered only after operational evidence, separate approval, and active duplicate-send controls.

---

## 9. Template variables, action plan, and pre-send gate

### `{{firstName}}` validation
Use only when valid. Reject: empty, numbers-only, emails, URLs, company names, job titles, placeholders ("unknown", "N/A", "test", "admin", "friend", "there"), merge tags, HTML, control characters. Do not auto-repair or blindly title-case. If rejected, use the no-name variant. Never leave a dangling comma or empty merge field.

### `{{senderName}}`
Resolve per connected sending account to the approved first name of the real human the mailbox represents (Hamzah's inbox signs "Hamzah"). Never "HMZ", "The HMZ Team", "Sales", or a generic role. Never infer from the email address without an approved mapping. If missing/mismatched, block the send and route for human review.

### `{{bookingLink}}`
Per-sender booking link mapped to the correct calendar/owner/approved URL. Verify HTTPS, approved domain, active, no unresolved variables, correct owner. Never shorten via an unapproved service. **Missing-link fallback:** "Reply with a couple of times that work for you and I'll coordinate it." — allowed only when a real human scheduling owner is assigned. If neither a link nor a scheduling owner exists, do not send; escalate. Never send the literal `{{bookingLink}}`, `[calendar link]`, or a malformed URL.

### 9.1 Pre-send gate (a send requires ALL applicable gates, not just confidence)
1. Category permits a send in the current operating mode.
2. Operating mode permits the send (VALIDATION → human approval recorded).
3. Campaign is on the `LIVE_CAMPAIGNS` allowlist (exact ID).
4. Sender account is approved and matches the thread.
5. Template or knowledge-base version is approved.
6. No risk flag (unsubscribe, legal, privacy, complaint, hostile, media, attachment, duplicate, human-response override) blocks the send.
7. Suppression state is clear (or, for confirmations, suppression is verified complete).
8. Idempotency state is clear (no existing send for this event).
9. Thread mapping is verified (the reply targets the correct inbound).
10. Technical send mechanism is verified.
11. `{{firstName}}` valid or no-name variant selected; `{{senderName}}` approved; `{{bookingLink}}` valid or reply-with-times selected; no unresolved variables/placeholders/`UNKNOWN`/test text.
12. `DRY_RUN=false` by explicit approval.

A high confidence score cannot override a prohibited category or a missing gate. Any failed gate blocks the send and creates a human-review case.

### 9.2 Structured action plan
The Decision Engine emits an action plan, not a single enum. Independent fields: `stop_sequence`, `pause_sequence`, `suppression_level`, `interest_status_update`, `reply_mode`, `template_id`, `draft_required`, `human_review_required`, `escalation_required`, `priority`, `follow_up_date`, `send_allowed`, `blocklist_required`, `data_cleanup_required`, `legal_review_required`, `privacy_review_required`, `reputational_review_required`, `reason_codes`. `legal_review_required`, `privacy_review_required`, and `reputational_review_required` are independent booleans set per the detected risk type for T12/T13 (§7.1) — not a single overloaded "legal review" flag, and not all three are set for every T12/T13 case. `follow_up_date` (T4) is non-executable metadata for the Validation MVP (§6). Each field maps to: intended business outcome → verified mechanism → provisional fallback → human task when no API exists. Schema in `docs/STATE_AND_IDEMPOTENCY.md`.

---

## 10. Five-minute objective (two metrics, staged) — quiet hours deferred

The Validation MVP processes every event immediately and notifies the operator immediately. There is **no quiet-hours hold, no prospect-timezone scheduling, and no federal-holiday calendar in the MVP** (see `docs/ARCHITECTURE.md` Production profile for the deferred quiet-hours design and the original Grill Me preference).

The five-minute objective does **not** mean every prospect receives a reply within 5 minutes — it means every event is *processed* within 5 minutes, which may correctly conclude in suppression, escalation, or "no reply needed."

- **Processing SLO (staged sub-targets):**
  - Webhook acknowledgement: immediate.
  - Classification + structured action plan produced: within 60 seconds.
  - Draft (where `draft_required=true`) + human notification routed: within 120 seconds.
  - Processing concluded — completed, suppressed, or escalated: within 300 seconds.
- **Transmission SLO (separate; not guaranteed in `OPERATING_MODE=VALIDATION`):** for cases where `send_allowed=true` and a human approves, the approved reply transmits within 5 minutes of approval. In `VALIDATION` mode there is **no transmission guarantee** — substantive replies wait for human approval, which may take longer.
- A notification, queue entry, case record, draft, approval request, or scheduled/held reply is **not** a transmission.
- An intentional no-reply (e.g. T5/T8/T9 acknowledgement-only or `NO_REPLY` outcomes) that completes within the Processing SLO is a **successful resolution**, not a failure of the five-minute objective.

Track timestamps for: webhook receipt, authentication completion, normalization, classification start, classification completion, draft completion, human notification, approval, send attempt, verified transmission, terminal suppression, terminal no-reply decision, final failure. Report separately: % processed/routed within 5 min (by stage); % transmitted within 5 min of approval.

---

## 11. Human-review surface (Validation MVP)

The MVP uses **one configurable primary human-review destination** plus **one durable case record**. Urgency (routine / urgent / technical) is a field on the case, not three separate mandated channels. No particular service is mandated before the owner selects it. (The three-channel Slack design, Google Sheets audit, and email fallback are retained in the Production profile, `docs/ARCHITECTURE.md`.)

Each case carries: case ID, source event ID, prospect (name/role/company/email — minimum necessary), category, confidence, urgency, exact incoming reply, extracted question(s), risk flags, recommended action plan, assigned owner, time received, elapsed processing time, Processing-SLO status, links (conversation, execution, audit), and an internal draft only when policy permits. A case is acknowledged only when the assigned owner performs an action that updates the durable case status. States: `NEW`, `ACKNOWLEDGED`, `IN_REVIEW`, `RESPONSE_APPROVED`, `RESPONDED`, `NO_REPLY_REQUIRED`, `SUPPRESSED`, `RESOLVED`, `FAILED`.

**Validation evidence and commercial-stage fields (internal only).** Cases also carry the validation evidence fields (`pain_confirmed`, `current_outbound_spend_confirmed`, `capacity_problem_confirmed`, `proof_objection`, `pricing_interest`, `alpha_interest`, `decision_maker_confirmed`, `discovery_call_booked`, `discovery_call_showed`, `validation_signal_strength`, `voice_of_customer_excerpt` — `true`/`false`/`unknown`) and `interest_stage` (`DISCOVERY_ONLY` / `VALIDATION_SPRINT_INTEREST` / `ALPHA_INTEREST` / `UNKNOWN`), defined in `docs/STATE_AND_IDEMPOTENCY.md` §1.9 and `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §11/§13. These are set or updated by the human reviewer, not auto-derived from confidence scores, and are **never** surfaced to a prospect.

**Primary/backup owners** must be named and confirmed before activation. If neither responds, preserve the case, keep the prospect out of automated follow-up, record an escalation breach, do not improvise.

---

## 12. Campaign allowlisting

**Default: deny all.** The allowlist key is the **exact Instantly campaign ID** (not the name).

| Condition | Result |
| --- | --- |
| Unknown / missing campaign ID, mismatched workspace, unapproved sending account, archived/changed campaign, not on allowlist | Blocked |

Before each send, verify: exact campaign ID, workspace, sending account, configuration version, active reply-policy version, `DRY_RUN` state, knowledge-base version. Minimum allowlist record per campaign: exact campaign ID, readable name, workspace, sending account, sender identity, booking route, reply-policy version, knowledge-base version, approving owners. **Current status:** no campaigns configured; none in `LIVE_CAMPAIGNS`. First controlled test requires an isolated non-production setup, a small manually reviewed contact set, one approved sending account/identity/booking route, one validation cell, and consenting test addresses before any real prospect.

---

## 13. AI classifier governance

**Two separate AI contexts.** Classifier context receives only taxonomy, precedence, examples, thresholds, risk indicators, and the permitted-action schema — **not** the knowledge base. Draft-generator context (T2 only) receives the prospect's exact question, relevant thread context, only the necessary approved KB sections, and the reply-policy restrictions; it never auto-sends and records the active KB version, sections used, and any `UNKNOWN` values.

**Knowledge base:** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` (currently `KB-1.0-DRAFT`, not approved for runtime). Only one approved production version active at a time. The AI never autonomously rewrites or approves it.

**Threshold validation before live use:** labelled evaluation set across all 16 categories including mixed-intent, sarcasm, indirect opt-outs, and adversarial wording; measure precision/recall/false-auto-send/escalation; especially high precision for positive interest, timing, not-interested, unsubscribe; record model, prompt version, thresholds, policy version, decision trace; re-run on any change; owner approval for any threshold change.

---

## 14. Prohibited content
See `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §14 for the enforced list (invented case studies/results/guarantees, "proven/established/mature", 20+ meetings, ready-to-buy, prices/discounts, scope/timeline/contract terms, refund promises, unverified integrations, competitor disparagement, n8n/workflow counts/Lock & Key/model names/internal automation details, attachment/CRM review claims, legal admissions/deletion confirmations/automated apologies, em dashes). The Alpha Offer document's claims are prohibited at runtime (`docs/SOURCE_PRIORITY.md` §4).

---

## 15. Language policy
English only for the initial sprint and controlled live test. Wholly/materially non-English reply → stop, no auto-reply, human review. No auto-translation. Mixed-language may proceed only when the operative meaning is unambiguous in English and no risk indicators are present; otherwise escalate.

---

## 16. Industry scope
Initial live scope: the three approved validation cells — `CELL_1_SAAS_SALES_HIRING` (US B2B SaaS, recently hired sales capacity), `CELL_2_SAAS_EXISTING_OUTBOUND` (US B2B SaaS, existing outbound), and `CELL_3_SPECIALISED_B2B_AGENCY` (specialised high-ticket B2B agencies) — within geography `geo_code=US_B2B_CORE_12` (`docs/VALIDATION_CAMPAIGN_CONFIG.md`). A `geo_code` mismatch is a human-review flag, not an automatic block (§1). Blocked until specifically reviewed: healthcare/clinical, financial/investment, insurance, government/public-sector, education with student records, legal services, defence, political campaigns, and other regulated/sensitive sectors. Never process or repeat sensitive personal/medical/financial/government-ID/confidential information in an automated reply. Uncertain industry → escalate.

---

## 17. Pre-deployment requirements

Not approved for live deployment until every item is completed and confirmed.

| Item | Status | Owner |
| --- | --- | --- |
| Operating mode confirmed (`VALIDATION` default) | Set | HMZ |
| Named primary + backup escalation owners | Pending | HMZ |
| Human-review destination selected (one, configurable) | Pending | HMZ |
| Human owners for P1/P2/P3/P3M paths (privacy, legal, hostile, media) | Pending | HMZ |
| Approved `{{senderName}}` mappings per inbox | Pending | HMZ |
| Per-sender `{{bookingLink}}` URLs | Pending | HMZ |
| `KB-1.0` approved (currently `KB-1.0-DRAFT`) | Pending | HMZ + business partner |
| Validation-MVP storage choice verified | Pending | HMZ |
| Dedicated isolated test campaign + verified campaign ID | Pending | HMZ |
| Verified send/suppression mechanisms (or human-task fallbacks confirmed) | Pending | HMZ |
| Classifier evaluation set created, labelled, validated | Pending | HMZ + business partner |
| Synthetic testing of the intake + decision path | Pending | Implementation phase |
| Controlled live testing with internal/consenting recipients | Pending | Later phase |
| Final business-partner approval of this policy | Pending | HMZ + business partner |
| Legal/compliance review | Pending | HMZ (external if required) |

---

## 18. Document governance
Updated only by Hamzah and the designated business partner. `policy-HMZ-1.1` reconciles `policy-HMZ-1.0` per `docs/PHASE_2_CORRECTION_CHANGELOG.md`. `policy-HMZ-1.2` reconciles `policy-HMZ-1.1` per `docs/PHASE_2_SURGICAL_CORRECTION_CHANGELOG.md`. Changes to templates, thresholds, category actions, suppression rules, or operating modes require a new version and a regression pass. The active policy version is recorded with every classification, decision, and sent reply. The automation must never autonomously update this document.
