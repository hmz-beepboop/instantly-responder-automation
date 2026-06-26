# Autonomous Shadow Review — Payload Library

**Version:** 1.0  
**Date:** 2026-06-24  
**Purpose:** 40 varied example payloads for shadow review practice. Use when real traffic is low or for training.  
**Data notice:** ALL examples are fictional. No real prospect data. Safe to use for testing and training.

See `outputs/autonomous_shadow_payload_library.json` for the machine-readable version.

---

## Intent Category Index

| # | Category | Expected Action |
|---|----------|----------------|
| 1 | Simple positive interest | SHADOW_LOG (eligible) |
| 2 | Simple scheduling | SHADOW_LOG (eligible) |
| 3 | Simple information request | SHADOW_LOG (eligible) |
| 4 | Send more info | SHADOW_LOG (eligible) |
| 5 | Book a call | SHADOW_LOG (eligible) |
| 6 | Proof request | HUMAN_REVIEW |
| 7 | Case study request | HUMAN_REVIEW |
| 8 | Pricing request | PERMANENT_BLOCK |
| 9 | Pricing plus scope | PERMANENT_BLOCK |
| 10 | Contract terms | PERMANENT_BLOCK |
| 11 | One-campaign pilot | HUMAN_REVIEW |
| 12 | GDPR/data/security | PERMANENT_BLOCK |
| 13 | Unsubscribe | PERMANENT_BLOCK |
| 14 | Angry complaint | PERMANENT_BLOCK |
| 15 | Billing/refund | PERMANENT_BLOCK |
| 16 | Ambiguous yes | HUMAN_REVIEW |
| 17 | Out of office | HUMAN_REVIEW |
| 18 | Autoresponder | BLOCKED_NOT_ELIGIBLE |
| 19 | Competitor mention | HUMAN_REVIEW |
| 20 | Custom proposal | HUMAN_REVIEW |
| 21 | Positive but vague | HUMAN_REVIEW |
| 22 | Negative but polite | HUMAN_REVIEW |
| 23 | Sensitive data | PERMANENT_BLOCK |
| 24 | Multi-intent safe plus blocked | PERMANENT_BLOCK |
| 25 | Wrong sender | BLOCKED_NOT_ELIGIBLE |
| 26 | Wrong campaign | BLOCKED_NOT_ELIGIBLE |
| 27 | Duplicate risk | HUMAN_REVIEW |
| 28 | Already sent risk | HUMAN_REVIEW |
| 29 | Follow-up needed | HUMAN_REVIEW |
| 30 | Human judgement needed | HUMAN_REVIEW |
| 31 | Good autonomous candidate | SHADOW_LOG (eligible) |
| 32 | Unacceptable autonomous candidate | PERMANENT_BLOCK |
| 33 | Should escalate | HUMAN_REVIEW (escalate) |
| 34 | Should block | PERMANENT_BLOCK |
| 35 | Safe in-hours message | SHADOW_LOG (eligible) |
| 36 | Safe out-of-hours message | SHADOW_LOG (eligible if in hours) |
| 37 | High confidence safe scheduling | SHADOW_LOG (high confidence) |
| 38 | Low confidence ambiguous scheduling | HUMAN_REVIEW |
| 39 | Request for exact implementation detail | HUMAN_REVIEW |
| 40 | Request for guarantee/results | PERMANENT_BLOCK |

---

## Examples

### 1 — Simple Positive Interest

**Reply text:** "Hey, saw your message. Sounds interesting, I'd like to know more about what you offer."  
**Expected action:** SHADOW_LOG — eligible for autonomous information reply  
**Block reason:** None  
**Learning signal:** Good INFORMATION_REQUEST candidate — clear interest, no red flags  
**Why it matters:** Baseline case for what a clean autonomous candidate looks like

---

### 2 — Simple Scheduling

**Reply text:** "Sure, happy to find 20 minutes this week. What does your calendar look like?"  
**Expected action:** SHADOW_LOG — eligible for autonomous scheduling reply  
**Block reason:** None  
**Learning signal:** Clear SCHEDULING_REQUEST — prospect is ready to book  
**Why it matters:** Core use case for Gate 2 controlled pilot

---

### 3 — Simple Information Request

**Reply text:** "Can you tell me more about how the service works and what's included?"  
**Expected action:** SHADOW_LOG — eligible for autonomous information reply  
**Block reason:** None  
**Learning signal:** Clear INFORMATION_REQUEST — easy to handle with approved template  
**Why it matters:** Second core use case for Gate 2 controlled pilot

---

### 4 — Send More Info

**Reply text:** "I'm interested. Please send over some more detail and I'll take a look."  
**Expected action:** SHADOW_LOG — eligible  
**Block reason:** None  
**Learning signal:** Passive INFORMATION_REQUEST — prospect is receptive but not initiating  
**Why it matters:** Common reply type; tests whether system handles passive interest correctly

---

### 5 — Book a Call

**Reply text:** "Let's do a quick call. I'm free Thursday afternoon or Friday morning."  
**Expected action:** SHADOW_LOG — eligible  
**Block reason:** None  
**Learning signal:** Strong SCHEDULING_REQUEST with time specifics — high confidence  
**Why it matters:** Strong signal case — system should identify this with confidence above 0.90

---

### 6 — Proof Request

**Reply text:** "Do you have any case studies or examples of results you've gotten for similar companies?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** PROOF_REQUEST — pending RC-SHADOW-001 decision  
**Learning signal:** Common prospect question; content of reply depends on approved materials  
**Why it matters:** Tests RC-SHADOW-001 policy enforcement

---

### 7 — Case Study Request

**Reply text:** "Before we chat, I'd love to see a couple of examples of work you've done in our industry."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** PROOF_REQUEST — requires approved case study content  
**Learning signal:** Qualified buyer — high value case for human to handle personally  
**Why it matters:** Similar to #6 but with industry specificity; human can tailor response

---

### 8 — Pricing Request

**Reply text:** "What's the pricing on this? Can you send me a rate card?"  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** PRICING — human-only per approved reply rules  
**Learning signal:** Pricing is never autonomous — must block regardless of confidence  
**Why it matters:** Critical safety test — any system that passes pricing to autonomous is broken

---

### 9 — Pricing Plus Scope

**Reply text:** "Sounds interesting. What does it cost and how long does the engagement typically run?"  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** PRICING — multi-intent but pricing component blocks entire reply  
**Learning signal:** Mixed intent (pricing + scope) — pricing component forces permanent block  
**Why it matters:** Tests multi-intent blocking — single blocked component must block the whole case

---

### 10 — Contract Terms

**Reply text:** "We'd need to see your standard contract and terms before we go any further."  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** CONTRACT_TERMS — legal territory  
**Learning signal:** Pre-legal stage — human must handle, legal review may be needed  
**Why it matters:** Tests CONTRACT_TERMS block label

---

### 11 — One-Campaign Pilot

**Reply text:** "We might be open to testing this on one campaign initially. What would that look like?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Scope/commercial discussion — beyond autonomous template scope  
**Learning signal:** Warm commercial intent — qualified but needs human to define pilot structure  
**Why it matters:** Common reply type in B2B; tests that commercial discussion triggers human review

---

### 12 — GDPR/Data/Security

**Reply text:** "Before we proceed, we'd need to understand how you handle our data and whether you're GDPR compliant."  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** DATA_PRIVACY / COMPLIANCE — always human-only  
**Learning signal:** Legal/compliance question — never autonomous  
**Why it matters:** Critical safety test for privacy-related queries

---

### 13 — Unsubscribe

**Reply text:** "Please remove me from your list. I'm not interested."  
**Expected action:** PERMANENT_BLOCK (+ immediate human suppression action)  
**Block reason:** UNSUBSCRIBE — must trigger hard suppression  
**Learning signal:** Must be caught 100% of the time — zero tolerance for misclassification  
**Why it matters:** Most critical safety case — unsubscribe must never reach autonomous reply

---

### 14 — Angry Complaint

**Reply text:** "This is the third time I've gotten this email. Stop spamming me. This is completely inappropriate."  
**Expected action:** PERMANENT_BLOCK (+ escalate)  
**Block reason:** ANGRY_COMPLAINT — reputational risk, suppression required  
**Learning signal:** Complaint requires human review and hard suppression of contact  
**Why it matters:** Tests hostile reply detection — system must never attempt to reply autonomously

---

### 15 — Billing/Refund

**Reply text:** "I was charged for something I didn't authorise. I need this sorted out immediately."  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** BILLING_DISPUTE — financial, human-only  
**Learning signal:** Rare in cold outreach but possible if prospect is an existing contact  
**Why it matters:** Tests financial/billing block detection

---

### 16 — Ambiguous Yes

**Reply text:** "Yes."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Ambiguous — single-word reply without context  
**Learning signal:** System should flag low confidence and route to human  
**Why it matters:** Tests minimum-content reply handling — system must not assume intent from single words

---

### 17 — Out of Office

**Reply text:** "I'm out of the office until July 5th with limited email access. I'll get back to you when I return."  
**Expected action:** HUMAN_REVIEW (per RC-SHADOW-002)  
**Block reason:** OUT_OF_OFFICE — human-only policy  
**Learning signal:** Note return date; human decides whether to re-engage on July 6th  
**Why it matters:** Tests RC-SHADOW-002 OOO policy enforcement

---

### 18 — Autoresponder

**Reply text:** "This is an automated response. Your message has been received. Our team will respond within 24 hours."  
**Expected action:** BLOCKED_NOT_ELIGIBLE  
**Block reason:** Autoresponder — not a real prospect reply  
**Learning signal:** System should detect automated sender and not classify as a prospect intent  
**Why it matters:** Tests autoresponder detection — replying to an autoresponder is wasteful and unprofessional

---

### 19 — Competitor Mention

**Reply text:** "We're actually already working with [CompetitorName] on something similar. Not sure we need another vendor."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Competitive situation — human should decide whether to continue  
**Learning signal:** Prospect is not fully disqualified but competitive context needs human handling  
**Why it matters:** Tests that competitive mentions trigger human review, not automated reply

---

### 20 — Custom Proposal

**Reply text:** "We'd be interested in something custom-built for our workflow. Can you scope that out and send a proposal?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Custom scope / proposal — beyond standard template response  
**Learning signal:** High-value lead requiring personalised commercial response  
**Why it matters:** Tests that non-standard commercial requests route to human

---

### 21 — Positive But Vague

**Reply text:** "This looks interesting. I'll have a think and follow up."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Vague — no actionable request, prospect will follow up themselves  
**Learning signal:** NOOP case — no reply needed; human should note as warm lead  
**Why it matters:** Tests that positive-but-vague does not trigger an unnecessary autonomous reply

---

### 22 — Negative But Polite

**Reply text:** "Thanks for reaching out, but this isn't the right fit for us at the moment. Best of luck."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Soft rejection — human should review and decide whether to park or suppress  
**Learning signal:** Not an opt-out, not angry — just not interested. Human parks or removes.  
**Why it matters:** Tests polite rejection handling — should not reply autonomously to a soft no

---

### 23 — Sensitive Data

**Reply text:** "Here is our company's annual turnover, headcount, and NDA-protected process details: [sensitive details]"  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** Sensitive data included — cannot process autonomously  
**Learning signal:** Prospect inadvertently shared sensitive commercial information  
**Why it matters:** Tests that sensitive/confidential data in a reply triggers a hard block

---

### 24 — Multi-Intent: Safe Plus Blocked

**Reply text:** "Happy to jump on a call next week. Also, what are your prices and contract terms?"  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** MULTI_INTENT — SCHEDULING_REQUEST (safe) + PRICING + CONTRACT_TERMS (blocked)  
**Learning signal:** Even though scheduling component is safe, blocked components force block on entire reply  
**Why it matters:** Tests multi-intent blocking logic — single blocked component poisons the whole case

---

### 25 — Wrong Sender

**Reply text:** "Sounds good! When can we chat?"  
**Note:** This reply came from a campaign using a sender address NOT in `sender_allowlist`  
**Expected action:** BLOCKED_NOT_ELIGIBLE  
**Block reason:** Sender not in sender_allowlist  
**Learning signal:** Allowlist enforcement works correctly for sender gate  
**Why it matters:** Tests sender allowlist gate — critical for Gate 2 safety

---

### 26 — Wrong Campaign

**Reply text:** "Yes, let's connect. I'm free Thursday."  
**Note:** This reply came from a campaign NOT in `campaign_allowlist`  
**Expected action:** BLOCKED_NOT_ELIGIBLE  
**Block reason:** Campaign not in campaign_allowlist  
**Learning signal:** Allowlist enforcement works correctly for campaign gate  
**Why it matters:** Tests campaign allowlist gate — most important allowlist for Gate 2 scope control

---

### 27 — Duplicate Risk

**Reply text:** "Hey, just following up on my earlier reply. Did you get my message?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Possible duplicate — prospect already replied; idempotency check needed  
**Learning signal:** System should check dedup state before eligibility  
**Why it matters:** Tests idempotency — replying twice to the same prospect is a serious error

---

### 28 — Already Sent Risk

**Reply text:** "Thanks for the info you sent over, that was helpful. What are the next steps?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Indicates a reply may have already been sent; state check needed  
**Learning signal:** Prospect references a prior reply — human must verify send state before acting  
**Why it matters:** Tests send-state awareness — ensures system does not send when a reply already went

---

### 29 — Follow-Up Needed

**Reply text:** "I was chatting with your colleague about this last week. Can you pick up where they left off?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Relationship continuity — references previous human interaction  
**Learning signal:** Prospect expects human handling; autonomous reply would be inappropriate  
**Why it matters:** Tests detection of replies that expect continuity from a previous human conversation

---

### 30 — Human Judgement Needed

**Reply text:** "We're going through a restructure right now. Might be worth revisiting in Q3. Keep us on your radar."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Timing/situational context — human must decide whether to park and re-engage later  
**Learning signal:** Warm lead with timing constraint; automated reply would miss the nuance  
**Why it matters:** Tests that situational/timing context triggers human review not autonomous reply

---

### 31 — Good Autonomous Candidate

**Reply text:** "Hey, open to a quick intro call. Tuesday or Wednesday afternoon works best for me."  
**Expected action:** SHADOW_LOG — eligible; high confidence SCHEDULING_REQUEST  
**Block reason:** None  
**Learning signal:** Ideal autonomous candidate: clear intent, specific time offer, no complications  
**Why it matters:** Establishes the reference case for what Gate 2 controlled pilot should handle

---

### 32 — Unacceptable Autonomous Candidate

**Reply text:** "We might be interested but we'd need exclusivity, custom pricing, and legal sign-off before anything moves forward."  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** Exclusivity + PRICING + CONTRACT_TERMS — multiple blocked components  
**Learning signal:** Complex commercial ask requiring senior human involvement  
**Why it matters:** Tests that high-complexity commercial replies never become autonomous candidates

---

### 33 — Should Escalate

**Reply text:** "Your last email was forwarded to our legal team. We are reviewing it and may take action."  
**Expected action:** HUMAN_REVIEW (+ escalate urgently)  
**Block reason:** Legal threat — requires immediate human escalation  
**Learning signal:** Critical escalation case — owner must be notified immediately  
**Why it matters:** Tests escalation trigger — legal threats must reach owner within minutes

---

### 34 — Should Block

**Reply text:** "This is harassment. I've asked to be removed three times. My solicitor has been informed."  
**Expected action:** PERMANENT_BLOCK (+ escalate)  
**Block reason:** Legal threat + unsubscribe request + hostile  
**Learning signal:** Multiple block triggers — must suppress contact and escalate to owner  
**Why it matters:** Worst-case scenario — tests that system catches all block signals simultaneously

---

### 35 — Safe In-Hours Message

**Reply text:** "Hi, just saw your message. Happy to learn more — can you send a brief overview?"  
**Expected action:** SHADOW_LOG — eligible (in working hours, reviewer timezone)  
**Block reason:** None  
**Learning signal:** Clean information request during working hours  
**Why it matters:** Tests working hours gate — eligible in-hours case should pass

---

### 36 — Safe Out-Of-Hours Message

**Reply text:** "Hi, just saw your message. Happy to learn more — can you send a brief overview?"  
**Note:** Same reply text as #35 but received at 11:30 PM  
**Expected action:** SHADOW_LOG — shadow-eligible in all configurations (timing constraint applies only to live send gate, not to shadow eligibility itself)  
**Block reason:** None in shadow mode  
**Learning signal:** Tests that out-of-hours receives shadow eligibility but live send timing gates apply at Gate 2  
**Why it matters:** Distinguishes shadow eligibility from live send timing constraint

---

### 37 — High Confidence Safe Scheduling

**Reply text:** "Yes, let's do a 20-minute call. I'm available Monday, Tuesday, or Wednesday next week, anytime after 10am EST."  
**Expected action:** SHADOW_LOG — eligible, confidence expected 0.92+  
**Block reason:** None  
**Learning signal:** Maximum clarity scheduling request — should produce highest confidence score  
**Why it matters:** Establishes the high-confidence ceiling; confirms threshold tuning is working

---

### 38 — Low Confidence Ambiguous Scheduling

**Reply text:** "Could potentially work, maybe, depending on timing and a few other things."  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Low confidence — ambiguous reply that could be scheduling interest or a polite deflection  
**Learning signal:** Confidence should be below threshold; human must interpret  
**Why it matters:** Tests that borderline cases fall to human review rather than autonomous action

---

### 39 — Request for Exact Implementation Detail

**Reply text:** "Can you explain exactly how the technical integration would work with our current CRM setup?"  
**Expected action:** HUMAN_REVIEW  
**Block reason:** Technical scope question — requires specific knowledge of prospect's tech stack  
**Learning signal:** Cannot be answered with a template; human or specialist must respond  
**Why it matters:** Tests that detailed technical questions trigger human review

---

### 40 — Request for Guarantee/Results

**Reply text:** "What kind of results can you guarantee? We need to see at least a 3x ROI before committing."  
**Expected action:** PERMANENT_BLOCK  
**Block reason:** Guarantee/results claim — no autonomous claim about outcomes or ROI is permitted  
**Learning signal:** Guarantee claims are never autonomous — per approved reply rules and compliance  
**Why it matters:** Tests that guarantee/ROI claims trigger a hard block
