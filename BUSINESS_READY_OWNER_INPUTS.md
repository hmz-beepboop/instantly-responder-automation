# Business-Ready Owner Inputs

Status: **PARTIALLY COMPLETED — confirmed non-secret owner values recorded; deployment-specific IDs and hosting remain pending**. This file did not
exist before this build session; it was created as the entry-gate document
required by the Business-Ready Core Build session.

Every value beginning with `<REQUIRED_` is a missing owner input. Per the
build session's entry-gate rule, none of these were guessed. The generic
implementation was built using explicit configuration placeholders
(`config/business-ready.config.json`, `.env.business-ready.example`), every
missing value is recorded in `reports/BUSINESS_READY_OFFLINE_BUILD.md`, and
every live gate (`DRY_RUN`, `LIVE_CAMPAIGNS`, credential readiness,
suppression-action enablement, notification configuration) remains closed.

Do not guess any of these values. Fill them in, then re-run
`verification/business-ready/apply-business-ready.ps1` (still offline-safe;
it does not flip live gates by itself).

---

## 1. Reviewer identity

| Field | Value |
| --- | --- |
| Primary reviewer name | `Hamzah Zahid` |
| Primary reviewer contact | `hamzah@teamhmzautomations.com` |
| Backup reviewer name | `Not configured for supervised launch` |
| Backup reviewer contact | `N/A` |

## 2. Notification destination

| Field | Value |
| --- | --- |
| Google Chat space name (human-readable, not the webhook URL) | `HMZ Instantly Responder Alerts` |
| Google Chat incoming webhook URL (secret only — never place here or in any JSON/report) | lives only in `infrastructure/business-live/.env` as `GOOGLE_CHAT_WEBHOOK_URL` (not committed); passed into the n8n container by `docker-compose.yml`. The Human Approval, Error Handler, and SLA Watchdog workflows read it via `$env.GOOGLE_CHAT_WEBHOOK_URL` directly — no separate `hmzGoogleChatWebhook` n8n credential is required by the current implementation. |
| Confirmed `GOOGLE_CHAT_WEBHOOK_URL` set in deployment `.env` and reachable | `false` |

## 3. Review surface

| Field | Value |
| --- | --- |
| Public review base URL (HTTPS) | `https://n8n.hmzaiautomation.com/webhook/reply-review` |
| Review token TTL (minutes) | `60` |
| Public production Human Approval review-form URL (HTTPS, `HMZ_REVIEW_PUBLIC_BASE_URL`) | `https://n8n.hmzaiautomation.com/webhook/reply-review/review` |
| Public production Human Approval review-submit URL (HTTPS) | `https://n8n.hmzaiautomation.com/webhook/reply-review/submit` |
| Public production n8n editor/API URL (HTTPS, `HMZ_N8N_PUBLIC_URL`) | `https://n8n.hmzaiautomation.com` |
| Public production Instantly reply-intake webhook URL (HTTPS, `HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL`) | `https://n8n.hmzaiautomation.com/webhook/instantly-reply` |

## 4. Sender mapping (per `HMZ_APPROVED_REPLY_RULES.md` §9)

| `eaccount` (sending mailbox) | `{{senderName}}` (approved first name) | `{{bookingLink}}` |
| --- | --- | --- |
| `hamzah@teamhmzautomations.com` | `Hamza` | `https://calendar.app.google/qtTHURBWvZKcDxeY7` |

## 5. Campaign / workspace allowlists (policy-HMZ-1.2 §12)

| Field | Value |
| --- | --- |
| Instantly workspace ID | `c7f84f11-4a1a-42dc-9a74-a417e44cb87e` |
| `LIVE_CAMPAIGNS` (exact campaign IDs; stays `[]` this session) | `[]` (kept `[]`) |
| Approved sending account(s) allowlist | `hamzah@teamhmzautomations.com` |
| Designated controlled-live campaign ID (`HMZ_CONTROLLED_LIVE_CAMPAIGN_ID`) | `bcda01f7-21c9-4e12-9849-0a375b548467` |
| Designated controlled-live connected sender `eaccount` (`HMZ_CONTROLLED_LIVE_EACCOUNT`) | `hamzah@teamhmzautomations.com` |
| Designated controlled-live owned recipient/lead email (`HMZ_CONTROLLED_LIVE_LEAD_EMAIL`) | `hamzahzahid0@gmail.com` |
| Designated controlled-live owned test email ID (`HMZ_CONTROLLED_LIVE_EMAIL_ID`) | `NOT_REQUIRED — derived from the genuine inbound reply webhook during acceptance` |
| Exact expected controlled-live reply subject (`HMZ_CONTROLLED_LIVE_REPLY_SUBJECT`) | `HMZ-RESPONDER-CONTROLLED-LIVE-001` |

## 6. Credentials (names only — values live only in n8n credential store)

| Credential name | Type | Purpose | Bound? | Credential ID env var |
| --- | --- | --- | --- | --- |
| `hmzInstantlyApi` | `httpHeaderAuth` | Instantly API V2 bearer key | `false` | `HMZ_INSTANTLY_API_CREDENTIAL_ID` = `YzdmODRmMTEtNGExYS00MmRjLTlhNzQtYTQxN2U0NGNiODdlOkFRaHlKaXFleURHZg==` |
| `hmzInstantlyWebhookToken` | `httpHeaderAuth` | Shared-secret header on the production Instantly reply-intake webhook | `false` | `HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID` = `Bx8l7u66xX59QY85` |
| `hmzReviewBasicAuth` | `httpBasicAuth` | Basic Auth on the production Human Approval review-form/submit webhooks | `false` | `HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID` = `BAkT9YlukhfyEv0s` |
| `hmzN8nApi` | n8n API key | n8n API key for apply/acceptance scripts | `false` | n/a (used as `HMZ_N8N_API_KEY` env var, not a workflow credential) |

## 7. Policy / KB / template versions

| Field | Value |
| --- | --- |
| Active reply-policy version | `policy-HMZ-1.2` (from `docs/HMZ_APPROVED_REPLY_RULES.md`) |
| Active KB version | `KB-1.0-DRAFT` (not approved for runtime factual use — `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`) |
| `KB-1.0` approved for runtime? | `false` |

## 8. Retention

| Field | Value |
| --- | --- |
| Review-case retention (days) | `90` |
| Sidecar send-state retention (days) | `90` |
| Error-record retention (days) | `90` |

## 9. Suppression-action enablement (still requires separate live-safety gate per task instructions)

| Action | Enabled for this session? |
| --- | --- |
| Source-campaign stop / interest-status update | `false` (offline build; gate stays closed) |
| Exact email-level workspace blocklist | `false` (offline build; gate stays closed) |
| Subsequence removal | `false` (offline build; gate stays closed) |

## 10. Hosting

| Field | Value |
| --- | --- |
| Target host/VM | `Planned Hostinger VPS running Ubuntu 24.04 LTS — not yet provisioned` |
| Domain for HTTPS reverse proxy | `n8n.hmzaiautomation.com` |
| TLS certificate strategy | `Caddy automatic Let's Encrypt TLS after the DNS A record points to the VPS` |

## 11. Controlled-live acceptance acknowledgement

`verification/business-ready/run-controlled-live-acceptance.ps1
-RunControlledLiveReply -ConfirmationPhrase "RUN-ONE-CONTROLLED-REPLY"`
temporarily rewrites `config/business-ready.config.json` in place to
`operating_mode=SUPERVISED_VALIDATION`, `dry_run=false`, and
`live_campaigns=[the one designated campaign]` for the duration of a single
supervised, production-path controlled-live reply, then restores
`operating_mode=VALIDATION`, `dry_run=true`, and `live_campaigns=[]` (and
deactivates every temporarily-activated workflow) in its `finally` block
regardless of outcome.

| Field | Value |
| --- | --- |
| Owner acknowledges the script temporarily enters live mode for one supervised run and always restores safe mode afterward, including on error | `true` |

---

## Disposition for this session

Confirmed non-secret values are filled. Any remaining angle-bracket deployment placeholders are deployment-specific items that do not yet exist. This build proceeds as a
**generic, configuration-driven implementation**:

- `config/business-ready.config.json` carries placeholder values matching
  the keys above (e.g. `"https://n8n.hmzaiautomation.com/webhook/reply-review"`).
- `OPERATING_MODE=VALIDATION`, `DRY_RUN=true`, `LIVE_CAMPAIGNS=[]`, all seven
  workflows `active: false`, no credentials bound, suppression-action live
  gates `false`, `review_notification_configured=false` (fail-closed —
  `REVIEW_NOTIFICATION_FAILED` is the expected state until a real webhook
  credential is bound).
- No live call is made, no credential is requested or handled, and no
  workflow is activated.


