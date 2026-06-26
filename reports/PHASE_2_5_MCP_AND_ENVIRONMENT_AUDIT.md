# Phase 2.5 — MCP and Environment Audit

Date: 2026-06-10. Scope: **environment-unblocking only**, per explicit instruction. No n8n workflow was created, imported, edited, activated, executed, or deleted. No Instantly API call was made. **Prompt 3 was not begun.**

This report supersedes the n8n-MCP-related findings in `docs/ENVIRONMENT_AUDIT.md` (Phase 1, when no MCP was connected) and the A1 status in `docs/ASSUMPTIONS_AND_UNKNOWNS.md`. It does not change `DRY_RUN=true` or `LIVE_CAMPAIGNS=empty`, and does not authorise Prompt 3.

---

## Summary

n8n-mcp is now **connected and working** for read-only node/template/validation tools — a material change from the Phase 1/2 audits, where n8n MCP was entirely absent (A1 = BLOCKED, "tool searches ... returned zero matches"). However, this MCP server is running **standalone**: `N8N_API_URL`/`N8N_API_KEY` are not configured, so it has **no connection to any n8n instance**. There is therefore nothing to evaluate for non-production status — A2 remains unmet, now for a more specific reason (no instance connected at all, rather than "an instance exists but is unverified").

---

## Phase A — current environment

| Check | Result |
| --- | --- |
| Claude Code version | `2.1.170` |
| MCP servers configured | `n8n-mcp` only. Scope: **user config** (available in all projects). Command: `npx n8n-mcp`. Type: `stdio`. Health check: **✔ Connected**. |
| MCP env (as configured) | `MCP_MODE=stdio`, `LOG_LEVEL=error`, `DISABLE_CONSOLE_OUTPUT=true`. No `N8N_API_URL` / `N8N_API_KEY`. |
| MCP config location | User-level config (`~/.claude.json`), not opened directly to avoid incidentally exposing unrelated config/secrets for other projects. No project-level `.mcp.json` or `.env` exists in this repo. |
| Runtime availability | Node `v24.15.0`; npm/npx `11.12.1`. Docker not installed (not required for `npx n8n-mcp`). |
| n8n Skills installed | `n8n-workflow-builder` skill present (`~/.claude/skills/n8n-workflow-builder/SKILL.md`). It names `n8n-mcp` as the example MCP server and mentions an optional separate `n8n-skills` package (`czlonkowski/n8n-skills`) — that package was **not** checked/found and is **not** assumed installed (not needed for this audit). |
| n8n instance URL/credential configured anywhere | **None found.** No `N8N_*` / `INSTANTLY_*` env vars in the shell; no local n8n reachable at `http://localhost:5678` (connection refused/no response); no `n8n` CLI; no `~/.n8n` config directory. The n8n-mcp server's own env (above) carries no instance URL or key. |
| Secrets handling | No secret values were displayed, copied, or written anywhere. Only the *existence* of relevant env-var names was checked (none found). |

---

## Phase B — installation source verification

n8n-mcp was **already configured and connected** — no installation was performed or needed. For provenance, npm registry metadata was checked (read-only):

- Package: `n8n-mcp`, version `2.57.3`
- Repository: `github.com/czlonkowski/n8n-mcp`
- Maintainer: `czlonkowski`

This matches the package the `n8n-workflow-builder` skill names as its example MCP server, and the same author it references for the optional `n8n-skills` companion package. No similarly-named or unverified package was installed or considered. The lightest valid method (`npx`, already in use) remains in place — no global install was made.

---

## Phase C — read-only MCP tests performed

`tools_documentation()` (no parameters) returned the authoritative catalogue: **21 tools total**.
- 6 are local node/template/validation tools that work **without any n8n instance** (plus `tools_documentation` itself = 7).
- 15 are `n8n_*` workflow-management/API tools that the documentation states **"require N8N_API_URL configuration"** (`n8n_create_workflow`, `n8n_get_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`, `n8n_delete_workflow`, `n8n_list_workflows`, `n8n_validate_workflow`, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_executions`, `n8n_health_check`, `n8n_workflow_versions`, `n8n_deploy_template`, `n8n_manage_datatable`, `n8n_generate_workflow`).

Only the 7 non-instance tools are exposed in this session — consistent with `N8N_API_URL` not being set.

**Tests run (all read-only; nothing created or modified):**

| Tool | Call | Result |
| --- | --- | --- |
| `tools_documentation` | no params | Returned tool catalogue (21 tools, categorised). ✅ |
| `search_nodes` | `{query:"webhook"}`, limit 5 | 5 results returned (e.g. `nodes-base.activeCampaignTrigger`, etc.). ✅ |
| `get_node` | `{nodeType:"nodes-base.webhook", detail:"minimal"}` | Returned node metadata (display name, category, isWebhook, isTrigger). ✅ |
| `validate_node` | `{nodeType:"nodes-base.webhook", config:{path:"test", httpMethod:"POST"}, mode:"minimal"}` | `{"valid":true,"missingRequiredFields":[]}`. ✅ |
| `validate_workflow` | in-memory dummy 1-node webhook workflow, `connections:{}` | `{"valid":true, errorCount:0, warningCount:4}` — pure schema/structure validation, no instance contacted. ✅ |
| `search_templates` | `{searchMode:"by_task", task:"webhook_processing"}` | 307 templates found; 3 returned. ✅ |
| `get_template` | `{templateId:5171, mode:"nodes_only"}` | Returned template's node list. ✅ |

**Not available (require `N8N_API_URL`, confirmed absent):** `n8n_health_check`, `n8n_list_workflows`, `n8n_get_workflow`, `n8n_validate_workflow` (by ID), `n8n_executions`, and the other 10 `n8n_*` tools — none appear in the tool catalogue or the session's tool list. Not invoked (would fail / are not exposed).

**No write, activation, deletion, or execution tool was called.**

---

## Phase D — non-production isolation

**No n8n environment is connected.** n8n-mcp runs purely against its bundled node/template database; with no `N8N_API_URL` it cannot list, fetch, or validate-by-ID any real workflow, and has no concept of "which n8n instance" it might talk to. There is nothing to classify as production or non-production — none of the acceptable-evidence forms (instance URL/label, dedicated workspace, absence of production workflows, owner confirmation, isolated read-only listing) can be produced because there is no instance to query.

Per the instruction's handling of "isolation cannot be proven": **Route A is blocked here.** No workflow contents were inspected (none exist to inspect, and no listing tool is available), and nothing was created.

**What would resolve A2:**
1. Owner provisions or designates a **non-production** n8n instance (e.g. a free n8n Cloud trial workspace, or a local/self-hosted instance run via `npx n8n` / Docker) used only for this project.
2. Generate a scoped n8n API key for that instance.
3. Configure `N8N_API_URL` and `N8N_API_KEY` as environment variables on the `n8n-mcp` MCP server — **outside this repository** (e.g. via `claude mcp remove n8n-mcp -s user` then re-add with `--env N8N_API_URL=... --env N8N_API_KEY=...`, or the equivalent user-config edit). Never in `.env`, workflow JSON, or chat.
4. Owner confirms in writing that the instance/workspace is non-production (isolated from any production n8n the owner may run elsewhere; no customer workflows).
5. Reload the MCP connection and re-run Phase C against the `n8n_*` API tools (starting with `n8n_health_check`, then `n8n_list_workflows`) to confirm read-only visibility — before any build step.

---

## Phase E — Instantly dependency assessment

No Instantly configuration exists (no `INSTANTLY_API_KEY`/`INSTANTLY_*` env var found). A3 (`docs/ASSUMPTIONS_AND_UNKNOWNS.md`) is unchanged: **BLOCKED for live actions**. Per `docs/IMPLEMENTATION_PLAN.md` §2-3, the next phase ("Prompt 3") scope is the 11-item Validation MVP intake/decision path, built and tested entirely against **synthetic NES fixtures** (`synthetic=true`) and a **mock classifier** — no live Instantly call is in scope.

| Required before... | Instantly dependency | Status for Prompt 3 |
| --- | --- | --- |
| Mock intake + decision construction (Steps 0-2) | None — synthetic NES fixtures per `NORMALIZED_EVENT_SCHEMA.md` / `IMPLEMENTATION_PLAN.md` Step 1. | **Not blocked.** No Instantly access of any kind needed. |
| Controlled webhook testing (Step 3, intake skeleton) | A real Instantly campaign + webhook config to deliver a live `reply_received` event, plus a chosen webhook-protection strategy (B4, PROVISIONAL). | The intake **skeleton** can be built and exercised with synthetic HTTP POSTs (curl/Postman) without Instantly. **Live Instantly-origin delivery** additionally needs A3 + B4 — deferred, not required to build/validate the skeleton itself. |
| Suppression testing (Step 4) | B6 (`update-interest-status` body) and B8 (blocklist/DNC API) — both BLOCKED. | **Not blocked.** `IMPLEMENTATION_PLAN.md` Step 4 records suppression as an **intent** (case-record field), not a live API call. |
| Sending | A3, B3 (`reply_to_uuid` source), B10 (threading). | **Out of scope** — item 11 hard-locks the send path to stub/`DRY_RUN`. |
| Production | Full A3 + B3/B6/B7/B8/B9 resolution, `OPERATING_MODE=PROVEN` gates, owner approvals. | Not applicable to Prompt 3. |

**Conclusion:** the Instantly side of Route A's gates is already satisfied by the existing mock/fallback design recorded in `ASSUMPTIONS_AND_UNKNOWNS.md` (B3/B6-B9 fallbacks) and `IMPLEMENTATION_PLAN.md` (Steps 1 and 4, item 11). **A3 does not block Prompt 3** as currently scoped. It remains required before any controlled live webhook test, live suppression call, send, or production step.

---

## Required final checks

| Check | Result |
| --- | --- |
| MCP process actually starts | ✅ `claude mcp list` → Connected; live tool calls succeeded. |
| Claude Code exposes the expected tools | ✅ 7 of 21 documented tools available (the 7 not requiring `N8N_API_URL`); 15 `n8n_*` API tools correctly absent given no instance is configured. |
| At least one read-only node discovery / schema-inspection operation succeeds | ✅ `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template` all succeeded. |
| No workflow was created or changed | ✅ `validate_workflow` ran against an in-memory dummy object only — nothing written to any instance. |
| No secret was written into the repository | ✅ No `.env`/credential files created; only env-var *names* (never values) were checked. |
| Non-production isolation proven or explicitly unproven | **Explicitly unproven** — no n8n instance is connected to evaluate (Phase D). |
| Instantly-dependent functions required later remain marked mocked/blocked | ✅ See Phase E table; `ASSUMPTIONS_AND_UNKNOWNS.md` A3/B3/B6-B9 substance unchanged. |

---

## Final verdict

**ROUTE A BLOCKED — NON-PRODUCTION ISOLATION NOT PROVEN**

1. **MCP server identified:** `n8n-mcp` (`github.com/czlonkowski/n8n-mcp`, v2.57.3), configured at user scope, command `npx n8n-mcp`, `stdio` transport.
2. **Installation/configuration status:** Already installed and connected (health check ✔ Connected); no installation action was needed or taken. Configured env: `MCP_MODE=stdio`, `LOG_LEVEL=error`, `DISABLE_CONSOLE_OUTPUT=true` — no `N8N_API_URL` / `N8N_API_KEY`.
3. **Actual tools available:** 7 of 21 — `tools_documentation`, `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`. The 15 `n8n_*` workflow-management/API tools (`n8n_list_workflows`, `n8n_get_workflow`, `n8n_health_check`, `n8n_executions`, etc.) are not available — they require `N8N_API_URL`, which is not configured.
4. **Read-only tests performed:** node search, node inspection (minimal detail), node validation, full workflow validation (in-memory dummy workflow), template search (by-task), template fetch (nodes-only). All succeeded — see Phase C table.
5. **Connected n8n environment:** **None.** n8n-mcp runs standalone against its bundled node/template database; no n8n instance is reachable or configured via this MCP server, the shell environment, or the local machine (`localhost:5678` not listening, no `~/.n8n`, no `n8n` CLI).
6. **Non-production isolation proven?** **No** — there is no instance to classify. A2 remains unmet.
7. **Secrets handling:** No secret values exist for n8n or Instantly in this environment; none were displayed, copied, or written. No `.env`/credentials files exist or were created.
8. **Instantly functions that may remain mocked in Prompt 3:** all of them — webhook delivery (synthetic POSTs to the intake skeleton), classifier, send, and suppression/blocklist calls (recorded as intents only). This matches `IMPLEMENTATION_PLAN.md` §2 items 1-11 — not a new gap.
9. **Unresolved blockers:**
   - **A2** — no non-production n8n instance connected/confirmed. Gates the remaining Route A items (live node-schema inspection against the real instance, storage-choice verification per `ARCHITECTURE.md` §6, `n8n_*` tool access).
   - **A3** — Instantly API key/plan tier still BLOCKED for live actions. Does **not** block Prompt 3 (Phase E), but remains required before any live webhook/suppression/send/production step.
10. **Exact next action:** Owner decides whether to (a) provision a non-production n8n instance + scoped API key and configure `N8N_API_URL`/`N8N_API_KEY` on the `n8n-mcp` MCP server (outside the repo) so A2 can be (re-)evaluated, which would enable Route A in full; or (b) explicitly authorise Route B (offline mock-only design, with mandatory later MCP re-verification per `IMPLEMENTATION_PLAN.md` §1). Until one of these happens, the verdict remains **NOT READY FOR PROMPT 3**, and Prompt 3 must not begin.
