# HMZ Approved Knowledge Base

Version: `KB-1.0-DRAFT`
Date: 2026-06-10
Status: **DRAFT — NOT APPROVED FOR AUTOMATIC RUNTIME USE.**

> This is a conservative draft prepared for owner review. It is **not** approved as the runtime factual source. Owner (Hamzah) and business-partner approval are required to promote it to `KB-1.0`. Until promoted, the runtime system must not use it to auto-draft any prospect-facing content. Any fact not explicitly stated here is `UNKNOWN` and must route to a human.
>
> Drafted from the business-source hierarchy in `docs/SOURCE_PRIORITY.md` (sources 1 and 2). It deliberately excludes everything from the Alpha Offer document (rank 4) and every prohibited claim. Where this draft and a higher-priority source disagree, the higher-priority source wins and this draft must be corrected before approval.

---

## 0. How to use this document

- This is the **only** approved factual source for internal T2 information-request drafts (human review only — never auto-sent).
- The classifier AI does **not** receive this document. Only the draft-generator AI receives the necessary sections (`HMZ_APPROVED_REPLY_RULES.md` §13).
- Every value marked `UNKNOWN` must be surfaced as `UNKNOWN` in any draft and escalated. The AI must never fill an `UNKNOWN` from memory or from a source document.
- Pricing is **human-only commercial information** — never an automatic disclosure (see §13).
- **Scope:** this KB exists to support drafts for HMZ's own initial US B2B validation campaign only (`CLAUDE.md` "Scope"). It must not be used to draft replies on behalf of any other party, and it does not describe a reusable client-facing service offering.

---

## 1. Working offer name
AI Sales Outbound Engine (working name; no brand or legal entity established — `sources/business/02_Product_Offer_Intake_COMPLETED.docx` §1). Do not present any other brand.

## 2. Approved plain-English description
A capacity-aligned outbound model for US B2B companies: outbound is built around the number and type of qualified sales meetings a team can actually handle, rather than maximising meeting volume regardless of quality. (`sources/business/01_Abs_Plan.docx`, positioning.)

## 3. Current maturity / validation status (state honestly)
- This is a **validation-stage** offer. It is being validated with a small number of US B2B teams.
- **No customers. No revenue. No public case studies. No proven results. No testimonials.** (`sources/business/02_Product_Offer_Intake_COMPLETED.docx` §6 — "100% PROOF GAP".)
- Must never be described as proven, established, guaranteed, or mature.
- "A small number of US B2B teams" may only be used once participants have actually entered validation. Until then use "US B2B teams."

## 4. Target buyers and geography (hypotheses, not validated facts)
- **Hypothesis** (label as such if asked): Founder / CEO / VP of Sales at US-based B2B SaaS, ~10-50 employees, mid-market or enterprise sales motion, ACV ~$10k-$60k+, already running outbound (in-house, agency, SDRs, or tools), likely capacity issue (too few qualified meetings or too many low-quality ones). (`sources/business/01_Abs_Plan.docx` Phase 2; `sources/business/02_Product_Offer_Intake_COMPLETED.docx` §3.)
- Secondary hypothesis: specialised high-ticket B2B agencies (used for validation conversations, not assumed paid buyers).
- Geography: **US only** for the initial validation sprint; ET and CT time zones prioritised. California, Pacific/Mountain time, and non-US excluded for the first sprint. (`sources/business/01_Abs_Plan.docx` Phase 1.)
- Buyer pain is a **hypothesis under validation**, not a confirmed fact.
- **Validation cells (campaign context, internal — never a prospect-facing label):** outreach for the validation sprint is segmented into `CELL_1_SAAS_SALES_HIRING` (SaaS founders who recently hired sales capacity but pipeline isn't keeping up), `CELL_2_SAAS_EXISTING_OUTBOUND` (SaaS teams already running outbound with volume but inconsistent quality), and `CELL_3_SPECIALISED_B2B_AGENCY` (B2B agencies whose founder-led sales depends on referrals) (`sources/business/01_Abs_Plan.docx` Phase 3; `docs/VALIDATION_CAMPAIGN_CONFIG.md`). The classifier and draft generator receive `validation_cell`, `segment`, `subsegment`, and `pain_trigger` as campaign context for every event. **Cell 3 (agency) drafts must never use SaaS-specific language** — use the `segment`/`subsegment`/`pain_trigger`/`offer_angle` supplied for that event, not the SaaS hypothesis above.
- **Geography lock:** `geo_code=US_B2B_CORE_12` (`docs/VALIDATION_CAMPAIGN_CONFIG.md`) is supplied as campaign context/allowlist metadata. A reply from outside this geography is **not** an automatic rejection or suppression reason — it creates a human-review flag so an owner can judge the individual case.

## 5. The "capacity-aligned" differentiator (approved explanation)
Most outbound optimises for maximum meetings. This model starts from the team's real sales capacity, defines what counts as a qualified meeting, and builds outbound to fill that capacity — fewer junk meetings, alignment to what the team can actually close. (`sources/business/01_Abs_Plan.docx`, core differentiation.)

## 6. Approved explanation of how the model works
Define how many qualified meetings the sales team can realistically handle and what should count as qualified → build the outbound campaign to fill that capacity rather than maximise volume → test messaging → track booked qualified meetings → weekly reporting with a capacity guardrail. Do **not** mention n8n, workflow counts, technical backend, Lock & Key, AI infrastructure, or any internal automation detail. (`sources/business/01_Abs_Plan.docx` Phase 7, Asset 2; prohibited list §14.)

## 7. Purpose of the next step
The desired next step from any positive reply is a **brief 10-minute discovery / validation conversation** with the founder, CEO, or VP of Sales — to understand current outbound and whether the problem is relevant. It is **not** a pitch for a full paid service. (`sources/business/01_Abs_Plan.docx` Phase 9; `HMZ_APPROVED_REPLY_RULES.md` §1.)

## 8. What is currently being validated
Whether target buyers recognise the capacity problem, already spend on outbound, value capacity-aligned outbound, and would consider a managed validation engagement — and what proof they would need. (`sources/business/01_Abs_Plan.docx` Phase 4.)

## 9. Approved scope — included
ICP/offer review, capacity model, qualified-meeting definition, lead-list build, cold-email campaign setup, message testing, inbox monitoring, reply categorisation, weekly reporting, booked-qualified-meeting tracking. (`sources/business/01_Abs_Plan.docx` Asset 3; `sources/business/02_Product_Offer_Intake_COMPLETED.docx` §9.)

## 10. Approved scope — excluded
Responding to leads on the client's behalf without approval, taking sales calls, closing deals, CRM management, content creation beyond icebreakers, paid ads, LinkedIn posting, SMS campaigns, automated calling, building a full custom outbound platform, unlimited revisions, guaranteed revenue. (`sources/business/01_Abs_Plan.docx` Asset 3; `sources/business/02_Product_Offer_Intake_COMPLETED.docx` §9.)

## 11. Existing proof and proof limitations (state honestly)
There is currently **no** demo, video, screenshot, customer, result, or case study approved for disclosure. Proof is still being built. If a prospect asks for proof or case studies, acknowledge honestly that this is a validation-stage offer without public case studies yet, and that the validation conversation is the appropriate next step — never imply results that do not exist. (`sources/business/02_Product_Offer_Intake_COMPLETED.docx` §6.)

**Validation evidence fields (internal research only).** Cases may record `pain_confirmed`, `current_outbound_spend_confirmed`, `capacity_problem_confirmed`, `proof_objection`, `pricing_interest`, `alpha_interest`, `decision_maker_confirmed`, `discovery_call_booked`, `discovery_call_showed`, `validation_signal_strength`, and `voice_of_customer_excerpt` (`true`/`false`/`unknown`; see `docs/STATE_AND_IDEMPOTENCY.md` §1.9). These exist so HMZ can track its own validation sprint. They are **internal evidence only** and must never be surfaced to a prospect, paraphrased back to a prospect, or used as the basis for a claim made to a *different* prospect (e.g. one prospect's `pain_confirmed=true` must never become "other companies have confirmed this pain" in another draft).

## 12. Approved answers to common questions (drafts — human review only)

**"How does it work?" / "Tell me more." / "Send me information."** → Use §6 explanation, state validation status (§3), invite the 10-minute conversation (§7). (This is a **T2 information request**, not T1 — see `HMZ_APPROVED_REPLY_RULES.md` §3.)

**"Do you have case studies / proof / results?"** → Honest §11 response. Never invent or imply results. Escalate if the prospect presses for specifics beyond §11.

**"Can you send a Loom / short video?"** → A validation overview Loom may exist (`sources/business/01_Abs_Plan.docx` Asset 2) but is **not confirmed as built or approved for sending** — treat as `UNKNOWN` until the owner confirms a specific approved asset. Do not promise or attach a video that has not been confirmed.

**"What does 'capacity aligned' mean?"** → Use §5.

**Permitted CTA:** invite the brief 10-minute validation conversation, via the approved per-sender booking link or "reply with a couple of times." Nothing stronger.

## 13. Commercial / pricing information — HUMAN ONLY
- Any pricing in the source documents (e.g. validation-sprint or alpha figures) is **human-only commercial information, not permitted for automatic disclosure**, and is subject to the current offer stage and owner approval.
- The runtime must never state, estimate, confirm, discount, or imply a price. Pricing questions are **T11 → escalate** (`HMZ_APPROVED_REPLY_RULES.md` §8).
- Source figures are recorded only so humans recognise them; they are **not** approved runtime facts and remain unvalidated/under review. (Sources disagree: intake §7 lists figures in GBP; `sources/business/01_Abs_Plan.docx` Phase 8 lists USD options. This conflict is itself a reason pricing stays human-only.)
- **`interest_stage` (internal triage only, never disclosed):** cases may be tagged `DISCOVERY_ONLY`, `VALIDATION_SPRINT_INTEREST`, `ALPHA_INTEREST`, or `UNKNOWN`. A positive reply (T1) alone does **not** justify `ALPHA_INTEREST` — that tag requires explicit prospect-stated interest in a paid/future engagement plus human review of the §11 evidence fields. Default to `DISCOVERY_ONLY` or `VALIDATION_SPRINT_INTEREST`. Regardless of `interest_stage`, price is never auto-disclosed.

## 14. Prohibited claims (never in any template or draft)
Invented/unapproved case studies; customer names or testimonials; unsupported results, metrics, or guarantees; "ensures results"; "proven" system, infrastructure, or outcomes; "established"/"mature" infrastructure; "fully built"/"operational at scale"; 20+ qualified shown meetings; prospects "ready to buy"; automatic alpha eligibility; unapproved prices or discounts; unapproved scope, timelines, or contract terms; refund promises; unverified integrations or technical capabilities; compliance/security assurances not in this KB; competitor names/comparisons unless the prospect introduced them and a human approves; disparagement of competitors/agencies/SDRs/tools/the prospect's provider; n8n; workflow counts; Lock & Key architecture; prompts or model names; internal automation details; claims that an attachment/CRM/system was reviewed unless verified; legal conclusions, admissions, deletion confirmations, or automated apologies; em dashes. (Consolidated from `sources/business/02_Product_Offer_Intake_COMPLETED.docx`, `sources/business/01_Abs_Plan.docx` Asset 4, `HMZ_APPROVED_REPLY_RULES.md` §14, and the Alpha-Offer prohibition in `docs/SOURCE_PRIORITY.md` §4.)

## 15. Questions that must always escalate (never auto-drafted)
Pricing/commercial negotiation; legal/privacy/complaint; hostile/media; attachment-dependent; anything requiring a claim not in this KB; any request to confirm proof, results, customers, guarantees, or timelines. (`HMZ_APPROVED_REPLY_RULES.md` §8.)

---

## 16. Governance
- **Content owner:** Hamzah.
- **Approvers (required before promotion to `KB-1.0`):** Hamzah + named business partner.
- **Review date:** to be set at approval.
- **Version status:** `KB-1.0-DRAFT` — not active. Only one approved production version may be active at a time.
- The AI must never autonomously rewrite or approve this document. Changes to pricing, proof, scope, integrations, process, claims, or CTA require owner review and a new version recorded in `docs/KNOWLEDGE_BASE_CHANGELOG.md`.

## 17. Source references
`sources/business/01_Abs_Plan.docx` (rank 1); `sources/business/02_Product_Offer_Intake_COMPLETED.docx` (rank 2). The Alpha Offer document (`sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx`, rank 4) is **excluded** by `docs/SOURCE_PRIORITY.md` §4. Full source inventory: `docs/BUSINESS_SOURCE_REGISTER.md`. Validation cells / geography lock: `docs/VALIDATION_CAMPAIGN_CONFIG.md`. Reply behaviour governed by `docs/HMZ_APPROVED_REPLY_RULES.md`.
