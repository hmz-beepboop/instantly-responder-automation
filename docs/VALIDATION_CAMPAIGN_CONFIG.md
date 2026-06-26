# Validation Campaign Configuration

Date: 2026-06-10. Status: **DRAFT — campaign registry not yet populated.** No campaigns are configured; none are on `LIVE_CAMPAIGNS` (`docs/HMZ_APPROVED_REPLY_RULES.md` §12).

**Scope:** this file defines the validation cells and geography lock for **HMZ's own initial US B2B validation campaign** (`CLAUDE.md` "Scope") and is the lookup source for the `campaign_context` fields attached to every event (`docs/NORMALIZED_EVENT_SCHEMA.md` §3.4). It does not itself authorise any send — the separate `LIVE_CAMPAIGNS` allowlist (`docs/HMZ_APPROVED_REPLY_RULES.md` §12) governs whether a send is permitted for a given campaign ID.

Source: `sources/business/01_Abs_Plan.docx` Phases 1 and 3 (rank 1, `docs/SOURCE_PRIORITY.md`). Full source inventory: `docs/BUSINESS_SOURCE_REGISTER.md`.

---

## 1. Geography lock — `geo_code=US_B2B_CORE_12`

The initial validation sprint is locked to the United States only:

- Country: United States only.
- Language: English.
- Currency in any sales material: USD.
- Legal/compliance frame: US commercial email rules (CAN-SPAM basics — accurate header information, non-deceptive subject lines, identification as advertising where required, physical mailing address, clear opt-out). Email only — no SMS, no automated calling (TCPA risk).
- Timezone operating window: US Eastern and Central time zones first.

### 1.1 `US_B2B_CORE_12` — fixed city/metro pool

Used for sourcing and tracking in the first validation sprint:

1. New York, NY
2. Boston, MA
3. Washington, DC
4. Philadelphia, PA
5. Atlanta, GA
6. Miami, FL
7. Chicago, IL
8. Austin, TX
9. Dallas, TX
10. Houston, TX
11. Raleigh-Durham, NC
12. Charlotte, NC

### 1.2 Excluded for the first validation sprint

California, Seattle, Portland, Mountain time zones, and non-US companies (Canada, UK, Australia, EU). This is a sourcing/sequencing decision for the first sprint, not a permanent exclusion — California in particular adds CCPA complexity that is deferred until after initial validation.

### 1.3 How `geo_code` is used at runtime

- `geo_code=US_B2B_CORE_12` is attached to every event as part of `campaign_context` (`docs/NORMALIZED_EVENT_SCHEMA.md` §3.4), indicating the campaign's intended/sourced geography.
- A reply indicating the prospect is **outside** `US_B2B_CORE_12` (e.g. a different state, time zone, or a non-US company) is **not** an automatic rejection or suppression reason. It sets a human-review flag on the case so an owner can judge the individual case (`docs/HMZ_APPROVED_REPLY_RULES.md` §1, §16).

---

## 2. Validation cells

Three validation cells are defined for the first sprint (`sources/business/01_Abs_Plan.docx` Phase 3). Every campaign in the registry (§3) must map to exactly one cell. **Cell 3 is the only agency cell — its `segment`/`subsegment`/`pain_trigger`/`offer_angle` must never be replaced with the SaaS hypothesis from Cells 1/2** (`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` §4).

### `CELL_1_SAAS_SALES_HIRING` — B2B SaaS founders with new sales hires
| Field | Value |
| --- | --- |
| `segment` | B2B SaaS |
| `subsegment` | 10-50 employees, recently hiring sales roles |
| Buyer | Founder, CEO, VP Sales |
| `pain_trigger` | "We hired sales capacity but pipeline is not keeping up" |
| `offer_angle` | Capacity-aligned qualified meetings |
| `geo_code` | `US_B2B_CORE_12` |

### `CELL_2_SAAS_EXISTING_OUTBOUND` — B2B SaaS founders already using outbound
| Field | Value |
| --- | --- |
| `segment` | B2B SaaS |
| `subsegment` | Already using outbound tools/agencies/SDRs |
| Buyer | Founder, CEO, VP Sales |
| `pain_trigger` | "Outbound is producing volume, but quality is inconsistent" |
| `offer_angle` | Fewer junk meetings, capacity-based targeting |
| `geo_code` | `US_B2B_CORE_12` |

### `CELL_3_SPECIALISED_B2B_AGENCY` — Specialised B2B agencies selling high-ticket retainers
| Field | Value |
| --- | --- |
| `segment` | B2B agencies |
| `subsegment` | $5k+ monthly retainer services |
| Buyer | Founder, CEO |
| `pain_trigger` | "Founder-led sales depends too much on referrals and inconsistent pipeline" |
| `offer_angle` | Predictable qualified meetings without hiring SDRs |
| `geo_code` | `US_B2B_CORE_12` |

---

## 3. Campaign registry (campaign-ID lookup)

Every Instantly `campaign_id` that the system processes must have exactly one row in this registry. The Reply Intake / Decision Engine looks up `campaign_id` here to attach `campaign_context` to the Normalized Event (`docs/NORMALIZED_EVENT_SCHEMA.md` §3.4).

| `campaign_id` | `validation_cell` | `segment` | `subsegment` | `pain_trigger` | `offer_angle` | `geo_code` | `campaign_purpose` | `campaign_message_variant` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| *(none configured)* | — | — | — | — | — | — | — | — |

**Field definitions:**
- `validation_cell` — one of `CELL_1_SAAS_SALES_HIRING` / `CELL_2_SAAS_EXISTING_OUTBOUND` / `CELL_3_SPECIALISED_B2B_AGENCY` (§2).
- `segment`, `subsegment`, `pain_trigger`, `offer_angle` — copied from the cell definition in §2 for that campaign (Cell 3 campaigns must use the Cell 3 row, never the Cell 1/2 SaaS values).
- `geo_code` — `US_B2B_CORE_12` for all campaigns in the first sprint (§1).
- `campaign_purpose` — a short, human-readable description of what this specific campaign is testing (e.g. `"validation_sprint_cell1_initial_outreach"`). Set when the campaign is registered.
- `campaign_message_variant` — an identifier for the message/sequence copy variant running in this campaign, distinct from Instantly's per-step `variant` field on NES (`docs/NORMALIZED_EVENT_SCHEMA.md` §1). Set when the campaign is registered.

**Unregistered campaigns:** if an inbound event's `campaign_id` has no row in this registry, every `campaign_context` field is set to `UNKNOWN` and the event is flagged for human review (`docs/NORMALIZED_EVENT_SCHEMA.md` §3.4). This is independent of, and in addition to, the `LIVE_CAMPAIGNS` send-allowlist check (`docs/HMZ_APPROVED_REPLY_RULES.md` §12) — a campaign can be registered here (so its replies get correct context) without being on `LIVE_CAMPAIGNS` (so it cannot send).

---

## 4. Governance

- Adding or changing a registry row (§3) requires owner approval, the same as any change to campaign configuration.
- This file does not grant send permission. `LIVE_CAMPAIGNS` (`docs/HMZ_APPROVED_REPLY_RULES.md` §12) is the separate, deny-all-by-default allowlist that governs sends.
- Changes to the validation-cell definitions (§2) or the geography lock (§1) follow the business-source hierarchy (`docs/SOURCE_PRIORITY.md`) — they originate in `sources/business/01_Abs_Plan.docx` and require owner + business-partner approval to change here.
