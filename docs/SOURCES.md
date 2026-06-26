# Sources

Authoritative references consulted during Phase 1. Each source is dated by the date this document was written (2026-06-09) since the Instantly developer site does not publish per-page revision dates. Re-verify before relying on any field in production.

## Instantly — Official developer documentation
- Introduction / V2 overview — https://developer.instantly.ai/
- Rate limits — https://developer.instantly.ai/getting-started/rate-limit
- Webhook events guide (event types + reply_received payload table) — https://developer.instantly.ai/guides/webhook-events
- Webhook management (introduction) — https://developer.instantly.ai/api/v2/webhook
- List available webhook event types — https://developer.instantly.ai/api/v2/webhook/listwebhookeventtypes
- Reply to an email — https://developer.instantly.ai/api-reference/email/reply-to-an-email
- Email endpoint group — https://developer.instantly.ai/api/v2/email
- Lead endpoint group — https://developer.instantly.ai/api-reference/groups/lead
- Remove a lead from a subsequence — https://developer.instantly.ai/api/v2/lead/removeleadfromsubsequence
- Move a lead to a subsequence — https://developer.instantly.ai/api/v2/lead/moveleadtosubsequence
- Mark all emails in a thread as read — https://developer.instantly.ai/api/v2/email/markthreadasread
- API key management — https://developer.instantly.ai/api/v2/apikey
- Machine-readable index (LLMs hint file) — https://developer.instantly.ai/llms.txt  *(not reachable from this environment on 2026-06-09; flagged in ASSUMPTIONS)*

## Instantly — Help Center
- API V2 overview article — https://help.instantly.ai/en/articles/10432807-api-v2
- How to use webhooks — https://help.instantly.ai/en/articles/6261906-how-to-use-webhooks
- How to stop a campaign for a specific lead — https://help.instantly.ai/en/articles/7913412-how-to-stop-a-campaign-for-a-specific-lead
- Subsequences — https://help.instantly.ai/en/articles/7251329-subsequences

## Instantly — Marketing pages (lower trust, used only for orientation)
- API & webhooks overview blog — https://instantly.ai/blog/api-webhooks-custom-integrations-for-outreach/
- Email API webhooks for reply tracking — https://instantly.ai/blog/how-to-integrate-email-api-webhooks-for-real-time-reply-tracking/

## Project rules (in-repo)
- `CLAUDE.md` — 3-layer architecture, Instantly Rapid Reply project rules, DRY_RUN safety defaults.

## Sources NOT consulted (deliberate)
- Third-party reviews, MCP wrappers, and CLI tools (e.g. `bcharleson/instantly-cli`, Composio Instantly toolkit) — useful as reference implementations later, but their field names should not be trusted over the official docs.

## Tooling availability
- **n8n MCP tools: NOT present in this environment.** Tool searches for `n8n` and `mcp workflow node` returned no matches. As a result, the following Phase 1 tasks could not be performed and are recorded as unknowns: confirming connected n8n instance + non-production status, searching n8n's template gallery via MCP, inspecting current node schemas via MCP, and validating node configurations programmatically. See `ENVIRONMENT_AUDIT.md`.
