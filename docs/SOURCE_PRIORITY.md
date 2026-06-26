# Source Priority

Date: 2026-06-10. Status: authoritative reference for resolving conflicts between project documents.

This file defines which document wins when two sources disagree. It was created during the Phase 2 correction pass to fix an earlier error in which `CLAUDE.md` was treated as the authority for business facts. **`CLAUDE.md` governs how the agent works; it does not define business facts, offer maturity, or validation strategy.**

All source documents are inventoried by exact project-relative path, status, and permitted/prohibited claims in `docs/BUSINESS_SOURCE_REGISTER.md`. If a path below ever appears to mismatch a file on disk, the register is corrected first and this file is updated to match — the original `.docx` files are never renamed (`CLAUDE.md` rule #18).

---

## 1. The hierarchy

### Business authority (facts, maturity, offer, strategy, ICP, geography)

| Rank | Source | What it is authoritative for | May supply runtime claims? |
| --- | --- | --- | --- |
| 1 | `sources/business/01_Abs_Plan.docx` | Current go-to-market strategy, validation-stage operating plan, current ICP and geography, current campaign objective, validation cells (Cell 1/2/3) and `US_B2B_CORE_12` geography lock. | Indirectly — only after a fact is copied into the approved knowledge base. |
| 2 | `sources/business/02_Product_Offer_Intake_COMPLETED.docx` | Factual maturity baseline, proof status, delivery risks, scope limits, commercial and operational uncertainties. | Indirectly — same gate. |
| 3 | `docs/HMZ_APPROVED_REPLY_RULES.md` + `brainstorms/2026-06-09-instantly-rapid-reply-policy.md` (Grill Me record) | Owner-approved operational reply policy and safety controls. **Authoritative only where they do not conflict with sources 1 and 2, the five-minute objective, safety, or technical feasibility.** | The reply-rules document defines which replies are permitted; it does not invent business facts. |
| 4 | `sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` | **Future commercial concept only.** Not approved as a source of present-tense runtime claims. | No. See §4. |

### Project-instruction authority (how the agent works)

| Source | Authoritative for | Not authoritative for |
| --- | --- | --- |
| `CLAUDE.md` | Agent workflow rules, safety defaults (DRY_RUN, no-secrets, approval gates), build discipline, architecture principles. | Business facts, offer maturity, validation strategy, pricing, proof. |
| `docs/HMZ_APPROVED_REPLY_RULES.md` | Approved operational reply policy **after reconciliation in this correction pass**. | Inventing facts not present in the business sources or knowledge base. |
| `docs/REPLY_POLICY.md` | Supporting design detail (deterministic rule shapes, schema design). | It must not independently override the reconciled approved rules. |
| `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` | The only approved factual source the runtime/AI may use to draft answers. | Anything marked `UNKNOWN` or absent → escalate, never guess. |
| Remaining `docs/*` | Architecture, state, risk, assumptions, implementation detail. | Business facts and reply policy. |

---

## 2. Conflict-resolution rules

1. **Business fact vs project instruction:** the business-authority hierarchy wins. No instruction file (including `CLAUDE.md`) may turn an unvalidated hypothesis into a business fact.
2. **Within business authority:** lower rank yields to higher rank. If the Grill Me record (rank 3) conflicts with `Abs Plan.docx` (rank 1) or the intake's maturity baseline (rank 2), the higher-ranked source wins and the Grill Me preference is preserved in `docs/PHASE_2_CORRECTION_CHANGELOG.md` with the safer validation-stage default applied. The original preference may be restored only by explicit owner override.
3. **Safety and feasibility override preference:** any reply policy that conflicts with the five-minute objective, deterministic safety, or a still-unverified technical capability is replaced with the safer/simpler validation-stage default until the owner explicitly overrides and the capability is verified.
4. **Reply policy vs design doc:** `HMZ_APPROVED_REPLY_RULES.md` (reconciled) beats `REPLY_POLICY.md`. `REPLY_POLICY.md` is design reference only.
5. **Runtime claims:** the runtime system and the AI may state only facts that appear in `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` at its approved version. Everything else is `UNKNOWN` and routes to a human.

---

## 3. Which sources may supply runtime claims

- **Permitted (after copying into the approved KB and owner approval):** conservative facts from `sources/business/01_Abs_Plan.docx` and `sources/business/02_Product_Offer_Intake_COMPLETED.docx` — current validation maturity, ICP hypotheses, capacity-aligned positioning, honest scope/exclusions, proof limitations.
- **Never permitted as a runtime claim:** anything from the Alpha Offer document (rank 4); any pricing as an automatic disclosure; any proof, guarantee, case study, testimonial, or "proven/established/mature" language.

---

## 4. Prohibited use of the Alpha Offer document

`sources/business/03_Overview AI Sales Outbound Engine_ Phase 1_Alpha_Offer.docx` is a **future offer concept**. The runtime system must not use it to claim or imply any of: 20+ qualified shown meetings; prospects ready to purchase; guaranteed or ensured results; proven delivery or infrastructure; an established managed service; existing customers; case studies; testimonials; established performance statistics; automatic eligibility for the full alpha; that HMZ already handles everything at scale; or that the complete engine is currently built and operational.

Any surviving reference to these concepts elsewhere must be labelled as exactly one of:

- **prohibited current claim**
- **unvalidated hypothesis**
- **future offer concept**
- **historical source content not approved for runtime use**

See `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §"Prohibited claims" for the enforced list.

---

## 5. Approval ownership

- Business facts, offer maturity, pricing, and proof: **Hamzah + the named business partner.**
- Reply policy and safety controls: **Hamzah + the named business partner** (governance in `HMZ_APPROVED_REPLY_RULES.md` §18).
- Knowledge-base versions: **Hamzah + the named business partner** (governance in the KB changelog).
- Agent workflow rules (`CLAUDE.md`): Hamzah.

The agent must never autonomously edit the original business source documents (`*.docx`) or self-approve a knowledge-base version.
