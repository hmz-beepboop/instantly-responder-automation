# Implementation Plan — Validation MVP intake + decision path

Date: 2026-06-10. Reconciled during the Phase 2 correction pass (`docs/PHASE_2_CORRECTION_CHANGELOG.md` C16). The next implementation phase builds **only the Validation MVP intake and decision path** — not the full six-workflow platform, not production deployment, not the wider 38/40-workflow product architecture, and **no real sends**.

**Scope:** this plan supports **HMZ's own initial US B2B validation campaign only** (`CLAUDE.md` "Scope"; `docs/VALIDATION_CAMPAIGN_CONFIG.md`). It is not a plan for a reusable client-facing responder. Any future use of this system to monitor or respond on behalf of a client requires the separate approvals listed in `CLAUDE.md` "Scope" and is out of scope for this plan.

---

## 1. Prompt-3 readiness — Route A vs Route B (gating)

Per `CLAUDE.md` rule #1 ("n8n MCP first... If MCP is not connected, do not build workflows (offline design only, and only if the user authorises it)"), the next implementation phase ("Prompt 3") may proceed only via exactly one of the two routes below. **This correction pass does not enter either route** — it only records the gates so a future Prompt 3 can be checked against them, and so the audit (`reports/PHASE_2_BUSINESS_ALIGNMENT_AUDIT.md`) can record a verdict.

### Route A — n8n MCP-verified build (preferred)

| Gate | Required state |
| --- | --- |
| Corrected documents approved | Owner has reviewed this correction pass. |
| n8n MCP connected | Real nodes/schemas/validations/executions inspectable (`docs/ENVIRONMENT_AUDIT.md`). |
| Non-production n8n instance confirmed | Instance URL + isolation confirmed in writing. |
| Relevant node schemas inspected | Via n8n MCP, not assumed. |
| Required Instantly fields verified or safely mocked | Webhook payload, `reply_to_uuid` source, send/suppression mechanisms (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`). |
| Validation-MVP storage choice verified | Per `docs/ARCHITECTURE.md` §6 preference order. |
| Human-review destination selected or generic placeholder | One configurable destination (`HMZ_APPROVED_REPLY_RULES.md` §11). |
| No real sends | `DRY_RUN=true`, mock classifier, empty `LIVE_CAMPAIGNS` throughout (per §2 item 11). |

If every Route A gate holds → **READY FOR PROMPT 3 — MCP-VERIFIED BUILD.** Building, importing, or activating any n8n workflow still requires the user's separate, explicit authorisation at the start of Prompt 3 (`CLAUDE.md` rules #1, #4, #7).

### Route B — Offline mock-only design (fallback)

Enter Route B only if a Route A gate (typically "n8n MCP connected") cannot currently be met **and** the owner explicitly authorises an offline-design fallback (`CLAUDE.md` rule #1).

| Gate | Required state |
| --- | --- |
| Owner authorisation for offline fallback | Explicit and recorded — not assumed from silence. |
| Design-only output | JSON/document workflow design only. No n8n workflow is built, imported, or activated. |
| All external interfaces mocked | Instantly API, classifier, and storage calls are mocked/stubbed; no real API calls of any kind. |
| `DRY_RUN=true` hard-locked, `LIVE_CAMPAIGNS` empty | No path to a real send exists anywhere in the design. |
| Mandatory later MCP verification recorded as a precondition | Before any Route B design is built, imported, or activated in n8n, it must be re-verified against real n8n nodes/schemas/validations via n8n MCP — i.e. the Route A gates above are re-applied retroactively. This precondition is recorded now precisely so it cannot be skipped later. |

If every Route B gate holds → **READY FOR PROMPT 3 — OFFLINE MOCK BUILD ONLY** (design-only; MCP verification is still required before any real n8n build).

### Neither route's gates met

→ **NOT READY FOR PROMPT 3.** Record which gate(s) are unmet and what is needed to clear them. If a required Instantly capability is unverified, its dependent path is **BLOCKED** and is mocked or deferred — never built on an assumption.

---

## 2. Scope of the next implementation phase (exactly these 11 items)

1. **Intake skeleton** — webhook receiver.
2. **Minimal webhook validation** — authenticate/compensating control, then minimal schema validation, then respond (200/4xx), then async dispatch (`docs/ARCHITECTURE.md` §4). Never 200-then-401.
3. **Normalization** — to NES v1 (`docs/NORMALIZED_EVENT_SCHEMA.md`).
4. **Idempotency-state design** — dedupe key + send lock (`docs/STATE_AND_IDEMPOTENCY.md`), on the chosen storage.
5. **Deterministic safety prefilter** — the deterministic rules only (`HMZ_APPROVED_REPLY_RULES.md` §5).
6. **Classifier interface using mocks** — a stable interface that returns canned categories/confidence for semantic categories; no real model integration until approved.
7. **Structured action-plan generation** — emit the action-plan object (`HMZ_APPROVED_REPLY_RULES.md` §9.2).
8. **Human-review routing placeholder** — write the case to one configurable destination; generic until the owner selects a service.
9. **Basic case-state persistence** — one durable case record with lifecycle timestamps.
10. **Synthetic test harness** — fixtures for the intake + decision path.
11. **No real send** — the send path is stubbed/DRY_RUN hard-locked; no Instantly send call is wired live.

Explicitly **out of scope** for the next phase: real classifier integration, the full sender, watchdog, error-handler, reconciler, reporting platform, all six original workflows by default, controlled live testing, and production deployment. Build a sender/watchdog/error-handler only if minimally required to test the intake/decision boundary safely — otherwise stub them.

---

## 3. Build order (each step gated; DRY_RUN hard-locked throughout)

### Step 0 — Storage + case schema
Stand up the chosen store (per `ARCHITECTURE.md` §6 preference order). Apply the storage-agnostic schema (`STATE_AND_IDEMPOTENCY.md`): events/dedupe, case record, send-lock, timestamps. **Gate:** a uniqueness test inserts conflicting idempotency keys and confirms only one survives.

### Step 1 — Synthetic test harness + fixtures
Build the harness and fixtures. **Deterministic categories** (T7/T8/T9/T11/T12/T13/T14 and the deterministic positives) get deterministic-assertion fixtures. **Semantic categories** (T1/T2/T4/T5/T6/T10/T15/T16) are exercised through the **mock classifier** with canned outputs. Fixtures are scrubbed synthetic data; `synthetic=true`. **Gate:** harness reads a fixture, writes a run record, asserts against a stub decision engine.

### Step 2 — Reply Decision Engine (deterministic + mock classifier)
Implement the deterministic prefilter and the mixed-intent resolution. Wire the classifier **interface** to the mock. Emit the structured action plan. **Gate:** harness runs all 16 fixtures and gets the expected action plan for each. Deterministic categories asserted exactly; semantic categories asserted against mock outputs. 100% on this set. No external API calls.

### Step 3 — Reply Intake (webhook receiver)
Webhook node; authenticate/compensating control; minimal schema validation; respond; async-dispatch to the Decision Engine; insert the idempotency/event record. **Gate:** (a) replay test — same payload twice collapses to one event; (b) auth test — rejected request returns 4xx **before** any acceptance, never 200-then-401; (c) latency — record a **baseline** for ack + normalization in the real environment (no asserted p95 yet).

### Step 4 — Action dispatch + human-review routing (no real send)
Dispatch the action plan: write the case record, route to the human-review destination, set sequence-stop/suppression intents as **recorded intents** (not live API calls — mechanisms unverified), and stub the send path DRY_RUN-locked. **Gate:** suppression/safety categories produce the correct intents and a case; send path produces a rendered draft but makes no API call; synthetic notification clearly marked `[SYNTHETIC]`.

### Step 5 — Latency + failure visibility
Record lifecycle timestamps for both SLOs; surface failures to the human-review destination. **Gate:** an injected fault produces a visible failure case; timestamps populate for a synthetic run.

That is the end of the next phase. Anything beyond (real classifier, live send, reconciliation, watchdog, ramp, production) is a **later** phase behind its own gates and explicit owner approval.

---

## 4. Reconciliation and retries
If uncertain-send reconciliation cannot be verified against a real Instantly mechanism, the system does **not** auto-retry. It creates an urgent human-review case. (No reconciliation endpoint is verified — `docs/ASSUMPTIONS_AND_UNKNOWNS.md` B9.)

## 5. Latency targets
No speculative threshold (the old `≤200ms p95` is removed). Measure a baseline in the real environment first, then set Processing-SLO and Transmission-SLO targets against it (`docs/ARCHITECTURE.md` §9).

---

## 6. Open business-policy inputs still needed
| ID | Decision |
| --- | --- |
| U1 | First in-scope (isolated, non-customer-facing) test campaign, mapped to one validation cell and `geo_code=US_B2B_CORE_12` (`docs/VALIDATION_CAMPAIGN_CONFIG.md`). |
| U2 | Operating mode confirmation (`VALIDATION` default) and whether any acknowledgement category (T6/T10) is enabled to send after approval. |
| U3 | Approval of `KB-1.0` and the approved templates. |
| U4 | Human-review destination (one configurable service). |
| U5 | Storage choice (per preference order). |
| U6 | Named primary + backup escalation owners and P1/P2/P3/P3M owners. |
| U7 | `{{senderName}}` mappings and `{{bookingLink}}` URLs per inbox. |

## 7. Next-phase deliverables checklist
- [ ] Step 0 — storage + case schema (uniqueness test passes).
- [ ] Step 1 — synthetic harness + 16 fixtures (deterministic vs mock-semantic).
- [ ] Step 2 — Decision Engine (deterministic + mock classifier) emitting action plans.
- [ ] Step 3 — Reply Intake (auth/validate/respond/async; replay + auth + baseline tests).
- [ ] Step 4 — action dispatch + human-review routing, send path stubbed.
- [ ] Step 5 — lifecycle timestamps + failure visibility.
- [ ] No real send wired. No production deployment. No controlled live test in this phase.
