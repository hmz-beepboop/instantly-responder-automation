# Instantly Rapid-Reply Business & Safety Policy: Brainstorm / Discovery Notes
Date: 2026-06-09 · Goal: Extract HMZ's approved business and safety policy for the Instantly rapid-reply system, so the policy in `docs/REPLY_POLICY.md` can be replaced with the user-authoritative version saved to `docs/HMZ_APPROVED_REPLY_RULES.md`.

## Summary / key decisions
- **Offer:** Validation-stage capacity-aligned outbound model for US B2B SaaS founders/CEOs/VPs of Sales. Pre-case-study, no proven results. Desired next step: 10-minute validation conversation.
- **Auto-send eligible (with ≥0.90 confidence + all guardrails passing):** T1 positive interest (3 scenario variants), T3 booking request, T4 timing objection (2 variants), T6 not interested (one-line ack).
- **Hard suppress + no auto-reply:** T7 unsubscribe (org-wide DNC, confirmation only after verified), T12 legal/privacy/complaint (P1/P2/P3/P3M urgency tiers), T13 hostile/reputational risk.
- **NOOP (no reply ever):** T8 out of office, T9 bounce/delivery notice.
- **Brief ack + human re-route:** T10 wrong person.
- **Brief ack + stop sequence:** T5 referral, T6 not interested.
- **Human-only (no auto-reply, draft may be generated for T2):** T2 information request, T11 pricing/commercial, T14 attachment required, T15 ambiguous, T16 other.
- **Confidence thresholds:** ≥0.90 = eligible for category action; 0.60–0.899 = retain category for routing but block auto-reply + escalate; <0.60 = AMBIGUOUS → escalate. Safety signals override confidence always.
- **Templates:** Fixed, partner-approved. AI may only classify, select template, and generate source-grounded T2 drafts for human review. No free AI drafting of prospect-facing replies.
- **Language:** English only initially. Non-English or mixed-language → stop + escalate.
- **Quiet hours:** Monday–Friday 08:00–18:00 prospect's local timezone. Hold-and-release (max 24h, then human review). No auto-sends on weekends or US federal holidays. Timezone fallback: `America/Chicago` for ET/CT sprint.
- **Escalation surfaces:** `#reply-queue` (routine), `#reply-urgent` (P1/P2/legal/media), `#automation-alerts` (technical errors). Durable audit: restricted Google Sheet. Email fallback for Slack failure or P1 events.
- **Campaign scope:** Deny-all by default. Only exact Instantly campaign ID in `LIVE_CAMPAIGNS` allowlist, verified with workspace + sending account + policy version on every send. No campaigns configured yet.
- **Knowledge base:** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md` — does not yet exist. Must be written and approved by HMZ + business partner before Phase 3 Step 2.

## Q&A log

### Q1 — Offer, buyer, and desired next step
- Asked: What is being promoted, who is the buyer, and what is the single next step we're trying to get from a reply?
- Captured:
  - **Offer:** Validation-stage concept — a capacity-aligned outbound model for US B2B companies. Core pitch: qualified meetings aligned to actual sales team capacity, not maximum volume. Pre-case-study; no customers, revenue, testimonials, or proven results yet.
  - **Do not lead with:** AI, n8n, workflow counts, technical infra, Lock & Key architecture, or unsupported performance claims.
  - **Do not describe as:** proven, established, or guaranteed.
  - **Possible commercial path (not to be auto-quoted):** Founder Validation Sprint ~$3k–$5k; 90-Day Alpha ~$10k upfront + $15k performance bonus.
  - **Buyer:** Founder / CEO / VP of Sales at US B2B SaaS, 10–50 employees, mid-market or enterprise sales motion, ACV ~$10k–$60k+, active sales function, existing outbound activity. Strongest subsegments: (1) recently hired salespeople but insufficient pipeline; (2) using outbound but getting inconsistent/low-quality meetings. Secondary: high-ticket B2B agencies.
  - **Geography:** US only (initial). ET and CT time zones prioritised.
  - **Next step:** A short 10-minute discovery / validation conversation — not a pitch for the full service. Goal: confirm buyer pain, identify future alpha candidates.
  - **Reply automation behaviour:** Answer the immediate question honestly → ask at most one qualifying question → invite a 10-minute validation conversation → human evaluates suitability.
  - **Calendar link:** May be provided after expressed interest; allowing "reply with availability" is also acceptable if lower friction.
- Flags: None from this answer.

### Q2 — Positive-interest reply policy (T1 / T3 scenarios)
- Asked: What should the auto-reply say when a prospect expresses positive interest or asks how it works?
- Captured:
  - **Tone:** warm, concise, commercially professional, transparent, calm, no generic AI language. No em dashes. Use first name only when reliably available.
  - **Never:** imply proven results, mention unsupported results, introduce pricing, make guarantees, overexplain technical infra.
  - **Three scenarios with approved copy:**

  **Scenario A — Prospect agrees to a conversation** (e.g. "I'd be open to a call", "Send me your calendar"):
  > Thanks, {{firstName}}. Happy to talk it through.
  > We're currently validating the capacity-aligned outbound model with a small number of US B2B teams. The first step is a brief 10-minute conversation to understand how you currently handle outbound and whether the problem is relevant.
  > You can choose a suitable time here: {{bookingLink}}
  > Or reply with a couple of times that work for you and I'll coordinate it.
  > {{senderName}}
  — No qualifying question. Prospect already accepted the next step.

  **Scenario B — Prospect asks how it works / wants more info** (e.g. "How does this work?", "Tell me more"):
  > Thanks, {{firstName}}.
  > The model starts by defining how many qualified meetings the sales team can realistically handle and what should count as qualified. The outbound campaign is then built around filling that capacity, rather than maximising meeting volume regardless of quality.
  > We're currently validating this with US B2B teams, so the next step is a brief 10-minute conversation to understand your current setup and whether the problem is relevant.
  > You can choose a suitable time here: {{bookingLink}}, or reply with a couple of times that work for you.
  > {{senderName}}
  — Answers the question first, then invites the call. Qualifying question normally omitted. If booking link is withheld, may ask: "Are you currently running outbound in-house, through an agency, or not actively?"

  **Scenario C — Genuine but unclear interest** (e.g. "Interesting", "Possibly", "Go on"):
  > Thanks, {{firstName}}. Happy to share more.
  > Would it be more useful for me to explain the capacity model here, or would you prefer a brief 10-minute conversation?
  > {{senderName}}
  — One lightweight routing question is acceptable since intent is unclear.

  - **Validation wording rule:** Only say "a small number of US B2B teams" if participants have actually entered the validation process. Until then: "US B2B teams."
  - **Safety override:** Do NOT send any of the above if the same message also contains: unsubscribe request, complaint, legal/privacy concern, hostile language, pricing negotiation, attachment questions, or multiple substantive questions outside the approved knowledge base. Those follow suppression/escalation policy instead.
- Flags: None.

### Q3 — Timing-objection reply policy (T4)
- Asked: What should the auto-reply say for timing objections, and should the system schedule any re-engagement?
- Captured:
  - **Direction:** low-pressure; stop the sequence. Re-engagement is conditional, not automatic.

  **Scenario A — Specific future period given** (e.g. "Try Q4", "Come back in September"):
  > Thanks, {{firstName}}. Understood.
  > I'll close the loop for now. If it is still relevant around {{followUpPeriod}}, we can reconnect then.
  > {{senderName}}
  — Stop sequence. Record stated timeframe as an internal follow-up. Do NOT promise an exact date unless specifically agreed. Do NOT auto-resume the old sequence.

  **Scenario B — Vague timing** (e.g. "Not now", "Busy at the moment", "Maybe later"):
  > Thanks, {{firstName}}. Understood.
  > I'll close the loop for now. Feel free to reach out if the timing changes.
  > {{senderName}}
  — Stop sequence. No generic 90-day re-engagement. Next move is the prospect's unless a human approves a new campaign.

  - **Offer-reminder line** ("If the outbound capacity question comes up sooner..."): acceptable ONLY where the prospect previously showed meaningful engagement AND wording fits naturally. Never appended automatically.
  - **Re-engagement rules:**
    1. Specific future period → one internal follow-up record for that period.
    2. Explicit permission to reconnect → one controlled re-contact within that timeframe.
    3. Vague "later" → no automated follow-up.
    4. Before any future re-contact: confirm no unsubscribe/complaint/legal; confirm still in same role; confirm no active conversation; confirm offer/campaign still accurate and approved.
    5. Any future message: must be freshly written; must not restart the stopped sequence; must not refer to a promised date unless one was actually agreed.
  - **Classification rule:** timing objection ≠ rejection or unsubscribe. "Not interested" → negative-interest policy. "Remove me" / "do not contact" → unsubscribe policy. Ambiguous timing → stop sequence + route for human review.
  - **Prohibited content in this reply:** pricing, scarcity, performance claims, guarantees, pressure to book sooner, claims about offer readiness, new sales pitch.
- Flags: None.

### Q4 — Not-interested reply policy (T6)
- Asked: Send a brief acknowledgement or stay silent? What should it say?
- Captured:
  - **Decision:** Send one brief acknowledgement for a clear, polite decline. NOOP is only correct when another policy takes priority.
  - **Approved reply:**
    > Thanks, {{firstName}}. Understood.
    > {{senderName}}
  - "Understood" preferred over "no problem at all" — shorter, more neutral, less formulaic.
  - **Automation actions:** Stop sequence immediately. Record disposition as `NOT_INTERESTED` (distinct from `UNSUBSCRIBE`). Send ack once only. No re-engagement. No restart. Preserve reply + disposition for reporting.
  - **No future-contact invitation.** "Feel free to reach out if things change" is prohibited — it reopens the sales conversation after a decline.
  - **Remain silent / escalate instead when:** unsubscribe request present; legal/privacy/complaint present; hostile/reputational; OOO/bounce/automated delivery; system can't confidently classify as genuine decline; ack already sent for this message.
  - **Classification boundaries:**
    - `NOT_INTERESTED`: "we are all set", "not the right fit", "we already have something", "thanks but no thanks". Also "we already use another provider" unless they also ask a comparison question.
    - `UNSUBSCRIBE`: "remove me", "stop emailing me", "do not contact me".
    - Timing language → timing-objection policy (Q3).
    - Decline + referral → close original politely; route referral for human review.
  - **Prohibited content:** offer reminder, booking link, qualifying question, pricing, scarcity, performance claims, objection handling, invitation to reconsider, automated follow-up.
- Flags: None.

### Q5 — Unsubscribe and hard-suppression policy (T7)
- Asked: Send a confirmation or stay silent? What wording? What is the suppression scope?
- Captured:
  - **Decision:** Send one short confirmation — but ONLY after suppression has successfully completed. Never confirm first, then suppress.
  - **Approved reply:**
    > Understood, {{firstName}}. You have been removed from future outreach.
    > {{senderName}}
  - "Future outreach" preferred over "our list" — broader scope, more accurate.
  - **Suppression scope (organisation-wide):** active campaign + all other campaigns in Instantly workspace + all connected sending accounts + all HMZ-controlled Instantly workspaces + all HMZ-controlled sending domains + any other outbound tools/databases that could contact the same address + future lead-list imports and recycled prospect lists. Workspace blocklist alone is NOT sufficient.
  - **Central do-not-contact register** must be maintained. If another system can't be updated automatically: stop queued outreach → create urgent manual suppression task → flag as pending organisation-wide suppression → prevent future sends until manual task is confirmed complete.
  - **Automation actions (in order):** (1) Stop sequence. (2) Classify `UNSUBSCRIBE`. (3) Add to central DNC register. (4) Suppress from current Instantly workspace. (5) Propagate to all other HMZ-controlled outbound systems. (6) Verify suppression succeeded. (7) Send confirmation once. (8) Record result + timestamp. (9) Prevent re-import/re-contact.
  - **Confirmation-send rule:** If suppression fails or is uncertain → do NOT send false confirmation → stop all current/queued sends → raise high-priority alert → require manual resolution → record which systems still need suppression.
  - **Do NOT send standard confirmation when:** message is hostile/threatening; includes legal/privacy complaint; prospect alleges previous opt-out was ignored; creates reputational/regulatory risk; confirmation already sent for same request; suppression not yet verified. → Suppress immediately and route for human review.
  - **Classification rules:** "unsubscribe", "remove me", "stop emailing me", "do not contact me again", "take me off your list", "please delete me from your outreach", and equivalents → `UNSUBSCRIBE`. UNSUBSCRIBE overrides all other categories in the same reply (e.g. "Sounds interesting, but stop emailing me" → still `UNSUBSCRIBE`). If intent uncertain → stop sequence, route for human review.
  - **Audit requirements:** Record email address, source event ID, request timestamp, suppression completion timestamp, workspaces/systems updated, confirmation-send status, failed propagation tasks, operator responsible for manual completion. Retain minimum suppression record permanently — never delete in a way that allows re-upload.
  - **Prohibited content:** no offer, no service explanation, no booking link, no qualifying question, no reason request, no invitation to reconsider or contact later, no promise of removal before suppression verified.
  - **Compliance standard:** Internal target is immediate suppression. Policy still requires review against final legal/compliance framework before deployment.
- Flags: None.

### Q6 — Legal, privacy, complaint, hostile and media reply policy (T12/T13)
- Asked: No auto-reply / hard-suppress / escalate confirmed? Urgency tiers? Journalist track?
- Captured:
  - **Core decision confirmed:** For both T12 and T13 — stop sequence immediately, cancel queued messages, apply org-wide hard suppression, send NO automated reply, preserve evidence, escalate to human.
  - **Automation must never:** apologise, defend outreach, explain legal basis, admit fault, promise data deletion, or issue any substantive automated response.
  - **Urgency tiers:**
    - **P1 — Immediate:** credible violence/doxxing/extortion/safety threats or urgent court/regulatory deadline. → Suppress + notify designated owner AND safety/legal contact immediately.
    - **P2 — Urgent:** FTC/ICO reporting threat, attorney threat, formal regulatory complaint, alleged continued contact after previous opt-out, serious reputational threat. → Suppress + human review same working session + legal review before responding.
    - **P3 — High:** "Where did you get my email?", data deletion request, GDPR/CCPA request, spam complaint without legal/safety threat. → Suppress + route to privacy/compliance owner promptly + record any response deadline.
    - **P3M — Journalist/media:** journalist writing article, requesting comment, analyst/blogger asking questions, official statement request. → Stop/suppress + classify as `JOURNALIST_OR_MEDIA_INQUIRY` + distinct media escalation track + only authorised spokesperson may respond + preserve enquiry/publication/journalist identity/deadline/questions.
  - **Classification precedence:** Legal/privacy/complaint/hostile/safety/media signals override all commercial classifications. When uncertain → stop, suppress, escalate. Profanity alone ≠ automatic safety threat, but outreach still stops when hostility creates reputational/safety risk.
  - **Universal automation actions (in order):** (1) Stop sequence. (2) Cancel queued messages. (3) Classify with correct risk category + urgency tier. (4) Org-wide suppression. (5) Preserve: original message, email headers, event ID, timestamps, prospect identity, campaign/sending-account context, prior correspondence. (6) Create human-review case. (7) Notify escalation channel. (8) Block retries/replays/future imports. (9) Record assigned owner, response decision, closure status.
  - **Journalist track prohibitions:** automation must not answer on behalf of HMZ, confirm allegations, disclose client/prospect info, speculate, argue, provide off-the-record comments, or forward broadly through unsecured channels.
  - **Human ownership required before deployment:** must name primary + backup owner for: privacy/data-rights requests; legal/regulatory complaints; hostile/safety incidents; journalist/media enquiries; urgent out-of-hours escalation. Automation must NOT go live until these are configured.
  - **Prohibited automated responses:** apology, legal explanation, defence of outreach, admission of wrongdoing, promise of data deletion, compliance claim, request to withdraw complaint, stock unsubscribe confirmation, any substantive response. Deletion confirmation only after human process completed and verified.
- Flags: **Human ownership owners must be designated before deployment** → HMZ (user to provide names + escalation channels before Phase 3 Step 3).

### Q7 — Out-of-office (T8), bounce (T9), wrong-person (T10)
- Asked: NOOP on all three? Any nuances? How to handle referred contacts?
- Captured:
  - **T8 — Out of office:**
    - Default: no automated reply. Stop or pause sequence. Classify `OUT_OF_OFFICE`.
    - Do NOT treat as positive interest, rejection, or genuine sales reply.
    - Extract return date only when explicit and unambiguous ("Back on 20 June", "Returning September 3", "Out until 14 October"). Relative wording ("next week", "later this month") only converted to date if received-date + timezone makes it dependable. Multiple conflicting dates → human review.
    - If alternate contact named → preserve, route for human review. Never contact automatically.
    - No auto-resume of old sequence. Fresh eligibility/suppression/role/context check required before any later contact.
  - **T9 — Bounce / delivery notice:**
    - Default: no reply, ever. Classify `BOUNCE_OR_DELIVERY_NOTICE`.
    - Never reply to MAILER-DAEMON, postmaster, delivery-status, or automated mailbox addresses.
    - Permanent failure → mark address invalid, suppress, prevent re-import without correction + review.
    - Temporary failure (full mailbox, transient server) → pause sends, apply approved platform retry policy or human review. No separate automated reply.
    - Must not: guess replacement email, contact another employee automatically, reply to admin details in bounce, retry a permanent failure repeatedly.
  - **T10 — Wrong person / no longer in role:**
    - Default: send one brief acknowledgement on genuine, civil human reply.
    - **Approved reply:** "Thanks for letting me know, {{firstName}}. Apologies for the mix-up. {{senderName}}"
    - Actions: stop sequence, classify `WRONG_PERSON` or `NO_LONGER_IN_ROLE`, mark contact as unsuitable for campaign, send ack once, create human re-routing task only if account still relevant.
    - NOT an org-wide unsubscribe unless person also asks not to be contacted.
  - **Replacement/referral contact handling (applies to T8, T10, and T5):** Never auto-find or email another person at the company. Any replacement contact must be independently researched, role-verified, email-verified, suppression-checked, ICP-assessed, and approved for outreach. If person names/introduces a colleague → preserve + route for human review. Naming someone ≠ consent to contact them. Do not auto-forward the original thread. Disclose no unnecessary personal information.
  - **Priority rules:** Unsubscribe overrides all three (→ Q5). Legal/privacy/complaint/hostile overrides (→ Q6). Genuine human reply must not be misclassified as OOO/bounce based on automated-looking text. Low-confidence classification → stop + human review. Dedup: no ack sent twice for same message.
- Flags: None.

### Q8 — Referral reply policy (T5)
- Asked: What does the automation say to the original prospect? Should it ever ask for a warm introduction automatically?
- Captured:
  - **Decision:** One concise acknowledgement to original prospect → stop sequence → route referral for human review. Never contact referred person automatically. Never ask for warm introduction automatically.
  - **Approved reply:** "Thanks, {{firstName}}. I appreciate the referral. I'll review it from here. {{senderName}}"
  - "I'll review it from here" preferred over "I'll leave that with you" — acknowledges the referral, does not pressure the prospect, does not promise to contact the colleague.
  - **Automation actions:** (1) Stop sequence for original prospect (unless they explicitly ask to remain involved). (2) Classify `REFERRAL`. (3) Preserve: referred person's name, role, company, email address, relevant context. (4) Send ack once only. (5) Create human-review task. (6) Record human decision (pursue / request intro / hold / reject).
  - **Must not:** auto-add referred person to Instantly, auto-enrol in another sequence, auto-forward email thread, assume referral = consent/interest/qualification, contact before verification.
  - **Human verification required before outreach:** confirm real, confirm still in role, check ICP match, verify email independently, check all suppression records, determine if suggestion vs genuine introduction, approve outreach wording and channel. Use a new context-appropriate message, never silently enrol in original sequence.
  - **Warm-introduction rule:** Automated request for introduction is prohibited. Human may request introduction only when: original prospect showed genuine engagement, referred person appears relevant, fits naturally in conversation, prospect hasn't already said they'll pass it on themselves, request is personalised + approved, made once without pressure.
  - **Optional human-approved intro-request wording:** "Thanks, {{firstName}}. I appreciate the direction. If you're comfortable introducing us by email, that would be helpful, but no problem if you would rather leave it with me. {{senderName}}"
  - **Scenarios:** (a) Name + email supplied → ack once, verify independently. (b) "I'll pass this on" → ack once, wait, no independent contact. (c) Colleague copied into email → treat as live multi-person thread, route for human handling, do not enrol colleague in automation. (d) Role only, no name → ack once, create research task, do not guess.
  - **Priority rules:** Unsubscribe overrides (→ Q5). Legal/hostile overrides (→ Q6). No double-ack on replay. Do not disclose original conversation details to referred person. Ambiguous referral → stop + human review.
- Flags: None.

### Q9 — Information requests (T2), pricing (T11), attachments (T14), ambiguous (T15/T16)
- Asked: Should the automation send a holding reply for these four categories, or stay silent while routing to human?
- Captured:
  - **Core decision:** No generic holding reply by default for any of the four. Stop/pause sequence, create human-review case, preserve thread and context, notify owner. No automated prospect reply unless a separately approved policy later permits it. 5-minute objective met through rapid human action, not automated acknowledgements.
  - **T2 — Information request:** Stop → escalate → generate clearly labelled internal draft from approved knowledge base only → include prospect's exact question, company, role, campaign, original outreach, thread context → identify sources for every factual claim → mark unavailable info as `UNKNOWN` → do NOT auto-send draft. Case-study requests must not imply customer results that don't exist. Integration/reporting/security/feature questions answered only from verified approved product docs.
  - **T11 — Pricing/commercial:** Stop → escalate for human commercial handling → preserve question + account context → no auto-reply → no pricing or proposal draft generated. Must not: invent/estimate price, offer discount, define scope, promise timeline, create proposal, define performance triggers, make contractual commitments, imply terms are final.
  - **T14 — Attachment present or referenced:** Stop → escalate → no reply until attachment reviewed by human. Record: filename, type, size, sender, message context, whether file was actually retrieved. Must not claim to have read/summarised/accepted attachment. Do not auto-open: executables, macro-enabled files, password-protected files, suspicious/unsupported types. Do not upload confidential prospect material to AI service unless approved security policy permits. If attachment referenced but not present → flag for human.
  - **T15/T16 — Ambiguous/Other:** Stop → no auto-reply → escalate for human classification and response. Use when: classifier confidence < 0.60, multiple categories conflict, no category safely fits, possible sarcasm/indirect opt-out/complaint/hostility/unrecognised risk. Human review package must include: full thread, candidate classifications, confidence scores, risk signals, reason for uncertainty, recommended next action.
  - **Holding-reply policy:** Disabled by default. "Thanks, {{firstName}}. I'll come back to you shortly." must NOT be sent because: creates an unmet promise, adds unhelpful email, appears automated, unsafe when classification is uncertain, may conflict with human reply, may be duplicated on retry. May only be reconsidered after: confidently safe category, human-response target at risk, case successfully assigned, wording separately approved, no specific time promised, duplicate-send controls active, operational evidence it improves experience. Never for: ambiguous, unsubscribe, legal/privacy, complaints, hostile, media, OOO, bounces.
  - **Escalation package contents:** prospect name/role/company/email, full incoming message + thread, campaign + sending account, source event ID, category + confidence, detected questions, attachment indicators, risk flags, recommended action, internal draft where permitted, sources used, unresolved information gaps, elapsed processing time, time remaining before 5-minute target, direct link to inbox thread or n8n execution.
  - **SLA rules:** Stop sequence immediately. Do not leave prospect in automated follow-up while human review is pending. Alert primary owner before 5-minute threshold. Escalate to backup owner when primary owner doesn't act. Generic holding ack alone does not count as resolution of 5-minute objective.
- Flags: None.

### Q10 — Escalation surface and human-review queue
- Asked: Slack, Sheet, email, or combination? Urgency separation? Backup owner? Error surface?
- Captured:
  - **Core decision:** Slack as primary action surface + restricted Google Sheet as durable audit log + email as fallback. Three separate routes: (1) routine prospect review, (2) urgent legal/safety/media, (3) technical errors. If Slack is not actively monitored pre-deployment → use dedicated monitored email inbox as temporary primary surface.
  - **Channel 1 — `#reply-queue` (private):** Routine escalations (referrals, info requests, pricing, attachments, ambiguous). Structured message per case: case ID, prospect info, category, confidence, urgency tier, exact reply, extracted question, recommended action, assigned owner, received time, elapsed time, 5-min SLA status, Unibox link, n8n execution link, audit record link. Include internal draft only when policy permits.
  - **Acknowledgement rule:** Case is acknowledged only when owner performs an action that updates the durable case status. Recommended states: `NEW`, `ACKNOWLEDGED`, `IN_REVIEW`, `RESPONSE_APPROVED`, `RESPONDED`, `NO_REPLY_REQUIRED`, `SUPPRESSED`, `RESOLVED`, `FAILED`. Slack reaction/button valid only if n8n can verify who acted, update durable record, record timestamp, prevent duplicate ownership.
  - **Durable audit log — restricted Google Sheet:** One row per case. Fields: case ID, source event ID, prospect + company, category, confidence, urgency tier, received time, assigned owner, ack time, current status, response decision, final outcome, Instantly thread link, n8n execution link, Slack message link, SLA result, notes. Same case ID in Slack + n8n + Sheet. Minimum necessary personal data only. Restricted to authorised HMZ personnel + approved business partner. Migrate to DB/ticketing if volume/concurrency grows.
  - **Channel 2 — `#reply-urgent` (private):** P1/P2 cases, legal/regulatory threats, complaints to authorities, repeated-contact complaints, credible safety threats, serious reputational threats, journalist/media enquiries. P1: notify both primary + backup owners immediately + email fallback immediately (no 15-min wait). P2: notify primary immediately + backup after 15 min without ack + email fallback on missed threshold. P3M journalist: route through `#reply-urgent` or separate private media route; notify only authorised spokesperson + business owner + necessary reviewer; do NOT expose in broad company channel.
  - **Primary + backup owners:** Primary = Hamzah (subject to confirming monitored Slack + email). Backup = business partner or other explicitly named authorised operator. Must be confirmed before activation. If neither responds: preserve case, keep prospect out of automated follow-up, record escalation breach, do not improvise.
  - **Channel 3 — `#automation-alerts` (private):** Failed API sends, failed suppression actions, broken workflows, malformed payloads, exhausted retries, webhook failures, stuck states, failed notifications, SLA-watchdog failures, duplicate-send risks, uncertain send outcomes, dead-letter cases. Do NOT mix into `#reply-queue`. If a technical error affects a live prospect case → create alert in `#automation-alerts` AND create/update linked prospect case in reply queue using same case ID. `UNCERTAIN` send must block auto-retry until confirmed. Critical errors (failed suppression, duplicate sends, possible data exposure) must also notify primary + backup by email.
  - **Email fallback:** Used when Slack delivery fails, P1/P2 not acknowledged, critical automation incident, Slack unavailable, or Slack not yet adopted as active working surface. Must use dedicated monitored mailbox or distribution address. Record whether Slack + email delivery succeeded.
  - **Security controls:** Private channels, limited membership, no API keys/tokens in Slack, prefer links over copying sensitive records, restrict Sheet + mailbox, define retention before deployment, Slack = notification + action surface not sole system of record.
- Flags: **Primary and backup owner names must be confirmed before activation** → HMZ to designate. **Monitored Slack accounts and email addresses** must be confirmed before going live.

### Q11 — Quiet hours and sending windows
- Asked: What is the approved send window? Hold-and-release or human decision? Timezone fallback?
- Captured:
  - **Approved automatic-send window:** Monday–Friday, 08:00–18:00 in prospect's verified local timezone. 08:00 preferred over 07:30 (less likely to appear unusually early). Window must be configurable, not hard-coded.
  - **Outside-window handling:** Stop/pause sequence as required by category → classify and check immediately → generate approved reply → queue as `QUIET_HOURS_HOLD` / `PENDING_SEND_WINDOW` → schedule release for 08:00 next permitted business day. Before releasing: re-check suppression status, unsubscribe status, complaint/legal risk, whether prospect sent another message, whether human already responded, duplicate-send state, case status, whether reply remains accurate and approved. Do not restart original sequence. Release only the single approved reply.
  - **Maximum automatic hold:** If hold would exceed 24 hours after original inbound → do NOT auto-release. Escalate for human judgement with drafted reply preserved. Prevents stale automated reply after long weekend/holiday.
  - **Weekends and holidays:** No auto-sends Saturdays, Sundays, or configured US federal holidays. Holiday calendar must use maintained calendar/verified service, not hard-coded list. If weekend/holiday causes hold > 24h → human review.
  - **Category-specific rules:** T7 unsubscribe: suppression is immediate regardless of quiet hours; confirmation follows Q5 suppression-before-confirmation rule. T12/T13: suppress + escalate immediately — no queue. Human-review categories: do not send holding reply just because message arrived outside hours.
  - **Timezone resolution order:** (1) Explicit/verified timezone on prospect/account record. (2) Verified company office city/state. (3) Campaign-level timezone. (4) Approved validation-test-cell timezone. Do NOT infer from area code (unreliable for mobile/remote/relocated/virtual numbers). Do NOT use sending-account timezone when it reflects UK operator rather than prospect.
  - **Current ET/CT fallback:** For US Eastern/Central validation sprint → use `America/Chicago` as conservative fallback (08:00 Central = 09:00 Eastern, avoiding 07:00 Central risk). If prospect may be outside approved geography or location data conflict → human review. Store: resolved IANA timezone, timezone source, confidence level, local inbound time, intended release time.
  - **5-minute SLO reporting:** (1) % processed and routed within 5 min. (2) % actually transmitted within 5 min. (3) Number held for quiet hours. (4) Number escalated for 24h hold breach. Quiet-hours hold is NOT a processing failure but must be visible in reporting.
- Flags: **Holiday calendar** must be configured with a maintained service before deployment → HMZ to confirm service/source.

### Q12 — Template variables: `{{firstName}}`, `{{senderName}}`, `{{bookingLink}}`
- Asked: Fallback rules for each variable. Per-sender or central booking link? What if variables are missing?
- Captured:
  - **`{{firstName}}` validation:** Remove leading/trailing spaces. Reject: empty, numbers-only, email addresses, URLs, company names, job titles, placeholders ("unknown", "N/A", "test", "admin", "friend", "there"), merge tags, HTML, control characters, unsafe content. Do NOT auto-repair uncertain/all-caps/all-lowercase/malformed names — omit instead. Preserve verified spelling; do not blindly title-case.
  - **`{{firstName}}` fallback:** No generic greeting ("Hi there" etc.). Use a dedicated no-name template version. The workflow must never leave a dangling comma or empty merge field. Examples: named = "Thanks, Hamzah. Understood." → no-name = "Understood."
  - **`{{senderName}}`:** Resolve per connected Instantly sending account. Use approved first name of the real human identity the mailbox represents. Hamzah's inbox signs as `Hamzah`. Other operators sign with their own approved first name. Do NOT use "HMZ", "HMZ AI Automation", "The HMZ Team", "Sales", or generic role by default. Do NOT infer sender name from email address when no approved mapping exists. Confirm sender name matches mailbox AND existing thread before sending. If missing/unresolved/mismatched → block automated send → route for human review.
  - **`{{bookingLink}}`:** Per-sender booking link by default. Each sending account mapped to: correct calendar, correct human owner, approved booking URL. Central/per-campaign link allowed only when configuration clearly identifies calendar owner and routing rules. Workflow must verify URL: uses HTTPS, belongs to approved booking domain, is active, contains no unresolved variables, matches correct sender/campaign owner. Do NOT shorten/replace through unapproved link service.
  - **Missing booking link fallback:** Omit link and use "Reply with a couple of times that work for you and I'll coordinate it." — allowed ONLY when: a real human scheduling owner is assigned + that person can monitor and coordinate replies + sender identity is valid. If neither booking link NOR confirmed scheduling owner exists → do not auto-send → escalate. Never send the literal `{{bookingLink}}`, `[calendar link]`, empty hyperlink, or malformed/unapproved URL.
  - **Pre-send validation gate (all 7 checks must pass before any automated reply is released):** (1) Valid firstName or correct no-name template selected. (2) Sender name approved + matches sending account. (3) Valid booking link exists or reply-with-times variant selected. (4) No unresolved `{{variables}}`, placeholders, `UNKNOWN` values, or test text. (5) Sender identity, connected account, original thread are consistent. (6) Quiet-hours rules passed or reply queued. (7) No unsubscribe/complaint/legal/hostile/duplicate/human-response override applies. Any failed check → block send → create human-review case.
- Flags: **Per-sender booking link URLs** and **sender name mappings** must be configured before activation → HMZ to provide before Phase 3 Step 4.

### Q13 — Campaign scope and AI knowledge base
- Asked: Is the first campaign set up yet? Does the knowledge base document exist?
- Captured:
  - **First campaign:** Not yet selected. Campaign setup is pending. No campaign ID should be placed in `LIVE_CAMPAIGNS` yet. Do not guess, invent, or use a placeholder.
  - **First controlled test requirements:** Create a dedicated, tightly controlled campaign with: separate non-prod/isolated setup, very small manually reviewed contact set, one approved sending account, one approved sender identity, one approved booking route, one defined validation cell, no unrelated leads or workflows. Use internal test addresses and consenting business-partner addresses before real prospects.
  - **LIVE_CAMPAIGNS allowlist record — required fields per campaign:** exact Instantly campaign ID (primary key — not name), campaign name (readable label only), workspace, sending account, sender identity, booking route, timezone, reply-policy version, knowledge-base version, approving business partners.
  - **Default deny-all:** unknown campaign = blocked, missing ID = blocked, mismatched workspace = blocked, unapproved sending account = blocked, archived/changed campaign = blocked, not on allowlist = blocked. Campaign-ID match alone is NOT sufficient — workflow must also verify workspace, sending account, config version, active reply-policy version, and DRY_RUN state before each send.
  - **Knowledge base status:** Does not yet exist as a single controlled document. Current offer/planning documents are source material only — they contain unresolved conflicts on validation-stage vs alpha positioning, pricing, currencies, scope, proof claims. Do NOT give raw documents to the runtime AI to resolve conflicts.
  - **Approved knowledge base location:** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`. This is the ONLY approved factual source for internal T2 draft generation. Everything outside it → `UNKNOWN` → route for human review.
  - **Required KB contents (17 sections):** working offer name, approved plain-English description, current maturity/validation status, target buyers + geography, capacity-aligned outbound differentiation, approved explanation of how the model works, approved inclusions, approved exclusions, existing proof + proof gaps, approved process/delivery facts, verified integrations/features, approved reporting facts, commercial info permitted to disclose, prohibited claims, approved answers to common questions, questions that must always escalate, source docs/owner/version/approval date.
  - **Two separate AI contexts:** (1) Classifier context: taxonomy, precedence rules, category examples, confidence threshold, risk indicators, permitted-action schema. NOT the full KB. (2) Draft-generator context: prospect's exact question, relevant thread context, only necessary approved KB sections, reply-policy restrictions. Draft generator must not answer pricing/legal/privacy/complaint/hostile/attachment/unresolved questions automatically.
  - **Every generated draft must record:** active KB version, approved sections used, unresolved facts, any `UNKNOWN` values.
  - **KB governance:** Hamzah + business partner approve initial version `KB-1.0`. Only one approved production version active at once. AI must never autonomously rewrite or approve the KB. Changes to pricing/proof/scope/integrations/process/claims/CTA require review + new version. Run regression tests before activating revised version. Record active KB version with every classification, draft, and sent reply.
  - **New files to create:** `docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`, `docs/KNOWLEDGE_BASE_CHANGELOG.md`, `config/live_campaigns.example.json`.
- Flags: **`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`** does not yet exist → HMZ + business partner to write and approve before Phase 3 Step 2. **`config/live_campaigns.example.json`** to be created in Phase 3.

### Q14 — Classifier thresholds, AI use, language, industry scope, prohibited content, completeness
- Asked: Confirm thresholds (0.85/0.60). Any remaining topics — language, AI for drafting, industry restrictions, prohibited content?
- Captured:
  - **Conservative launch thresholds:** >=0.90 = category may proceed to policy-defined action (all guardrails must also pass; does NOT authorise a human-review-only category). 0.60-0.899 = retain category for routing, block all auto-replies, escalate. <0.60 = override to AMBIGUOUS, stop, escalate. Safety/legal/unsubscribe/attachment/conflicting-risk signals always override confidence score. High confidence cannot authorise a policy-prohibited action.
  - **AI use:** Fixed partner-approved templates for all auto-sent replies. AI may: classify, select appropriate template/variant, generate source-grounded internal draft for T2 only. Must not freely draft and auto-send prospect-facing replies. T2 drafts remain human-review-only. Must never auto-draft/send: pricing, legal/privacy, complaints, hostile/media, attachment-dependent, ambiguous, or unapproved commercial commitments.
  - **Language:** English only for initial sprint. Non-English or materially non-English reply: stop, no auto-reply, route for human review. No auto-translation. Mixed-language may proceed only if operative meaning unambiguous in English and no risk indicators; otherwise escalate. Multilingual automation only with approved native-language templates and separate quality testing.
  - **Industry restrictions:** Campaign allowlisting is primary scope control. Initial live scope: approved US B2B SaaS validation cells + specialised high-ticket B2B agency validation cells. Blocked until specifically reviewed and approved: healthcare/clinical, financial/investment services, insurance, government/public sector, education with student records, legal services, defence, political campaigns, other highly regulated/sensitive sectors.
  - **Prohibited content (templates and AI drafts):** invented/unapproved case studies; customer names/testimonials; unsupported results/metrics/guarantees; unapproved prices/discounts; unapproved scope/timelines/contract terms; refund promises; claims service/infrastructure is proven; unverified integrations/technical capabilities; compliance/security assurances not in approved KB; competitor names/comparisons unless prospect introduced it AND human approves; disparaging comments about competitors/agencies/SDRs/tools/prospect's current provider; n8n; workflow counts; Lock & Key architecture; prompts or model names; internal automation details; claims HMZ reviewed an attachment/CRM/system unless verified; legal conclusions/admissions/deletion confirmations/automated apologies; em dashes.
  - **Threshold validation before live use:** labelled evaluation set covering all 16 categories including mixed-intent, sarcasm, indirect opt-outs, adversarial wording, edge cases. High precision required for: positive interest, timing objections, not interested, unsubscribe. Record: classifier model, prompt version, thresholds, policy version, decision trace. Rerun whenever model/prompt/taxonomy changes. Hamzah + business partner must approve any threshold change.
  - **Completeness verdict:** Policy is substantively complete as a business-partner review draft. Not yet approved for live deployment. Remaining pre-deployment items: named primary + backup escalation owners; confirmed monitored Slack + email channels; approved sender-account mappings; approved booking links; HMZ_APPROVED_KNOWLEDGE_BASE.md; approved KB version; dedicated test campaign; verified Instantly campaign ID; classifier evaluation results; synthetic workflow testing; controlled live testing with internal/consenting recipients; final business-partner approval; any required legal/compliance review.
- Flags: All items in "Remaining pre-deployment items" above.

## Open flags (pending input)
- **Primary + backup owner names** must be confirmed before activation → HMZ to designate.
- **Monitored Slack accounts and email addresses** to be confirmed before going live.
- **Human owners for T12/T13/P1/P2/P3/P3M escalation paths** (privacy, legal, hostile, media) → HMZ to provide names + escalation channels.
- **Holiday calendar** source must be configured before deployment → HMZ to confirm.
- **Per-sender booking link URLs** and **sender name mappings** → HMZ to provide before Phase 3 Step 4.
- **`docs/HMZ_APPROVED_KNOWLEDGE_BASE.md`** → HMZ + business partner to write and approve before Phase 3 Step 2.
- **`config/live_campaigns.example.json`** → to be created in Phase 3.
- **Classifier evaluation set** → HMZ + business partner to approve before controlled live use.
- **Named backup escalation owner** → HMZ to confirm.
- **Legal/compliance review** → required before live deployment.
