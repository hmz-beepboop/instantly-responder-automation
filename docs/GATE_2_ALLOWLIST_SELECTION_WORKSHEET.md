# Gate 2 — Allowlist Selection Worksheet

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** NOT YET POPULATED — owner must fill in before Gate 2  
**Instructions:** Work through each section. Write the exact values you want. Do not guess — these are real campaign IDs and email addresses from your Instantly.ai account.

---

## Why Allowlists Matter

The autonomous system will only consider acting on a reply if ALL THREE allowlists allow it:

1. The **campaign** the reply came from must be in `campaign_allowlist`
2. The **sender** (your sending email address) must be in `sender_allowlist`
3. The **intent type** classified for the reply must be in `intent_allowlist`

If any one of these three is empty or the value is not in the list, the system blocks the case and routes it to human review. This is a hard gate, not a suggestion.

---

## Section 1 — Campaign Allowlist

### Where to Find Campaign IDs

1. Log in to Instantly.ai
2. Go to Campaigns
3. Open the campaign you want to include
4. The campaign ID appears in the URL: `app.instantly.ai/app/campaign/[CAMPAIGN_ID]/...`

### Selection Guidance

For Gate 2 controlled pilot, start with **1 campaign only**:
- It should be an active US B2B validation campaign
- It should be the campaign where you have the most real prospect replies to learn from
- It should NOT be a campaign with sensitive prospects (enterprise, legal, government)

**Your campaign selection:**

| # | Campaign Name | Campaign ID | Why Selected | Verified Active? |
|---|--------------|-------------|--------------|------------------|
| 1 | | | | ☐ |

**Do not add more than 2 campaigns for the initial Gate 2 pilot.**

`campaign_allowlist` value to enter in n8n config:

```
["PASTE_CAMPAIGN_ID_HERE"]
```

---

## Section 2 — Sender Allowlist

### Where to Find Sender Email Addresses

1. Log in to Instantly.ai
2. Go to Settings → Sending Accounts (or Email Accounts)
3. The sender email addresses are listed there
4. Use the exact email address as it appears in Instantly (lowercase)

### Selection Guidance

For Gate 2 controlled pilot, include **only the sending email addresses used in your selected campaign(s)**:
- 1–3 sender addresses maximum
- These should be addresses you own and control
- Do not include addresses used by any other person or campaign

**Your sender selection:**

| # | Sender Email Address | Associated Campaign | Verified Ownership? |
|---|---------------------|--------------------|--------------------|
| 1 | | | ☐ |
| 2 | | | ☐ |
| 3 | | | ☐ |

`sender_allowlist` value to enter in n8n config:

```
["sender1@yourdomain.com"]
```

---

## Section 3 — Intent Allowlist

### Recommended Starting Values

For Gate 2 controlled pilot, the safest starting point is:

```
["SCHEDULING_REQUEST", "INFORMATION_REQUEST"]
```

**Why only these two:**
- Both have clear, templated replies
- Neither involves pricing, legal, compliance, or sensitive content
- Both have been tested in shadow mode
- Both have the highest probability of a confident, accurate AI classification

### What Each Intent Means

| Intent Code | What It Catches | Example Prospect Reply |
|-------------|----------------|------------------------|
| SCHEDULING_REQUEST | Prospect wants to book a call or meeting | "Sure, happy to chat. When works for you?" |
| INFORMATION_REQUEST | Prospect wants to know more | "Interesting — can you tell me more about how this works?" |

### What NOT to Include at Gate 2

Do not add these to the intent allowlist at Gate 2:

| Intent Code | Reason |
|-------------|--------|
| PROOF_REQUEST | Pending RC-SHADOW-001 — human-only until decided |
| PRICING | Human-only per approved reply rules |
| NEGOTIATION | Human judgment required |
| OOO | Human-only per RC-SHADOW-002 |
| ANGRY | Human-only |
| UNSUBSCRIBE | Human-only + hard suppression |
| LEGAL | Human-only |
| AMBIGUOUS | Too uncertain for autonomous |

**Your intent selection:**

- [ ] SCHEDULING_REQUEST *(recommended)*
- [ ] INFORMATION_REQUEST *(recommended)*
- [ ] Other: _____________________ *(document reason)*

`intent_allowlist` value to enter in n8n config:

```
["SCHEDULING_REQUEST", "INFORMATION_REQUEST"]
```

---

## Section 4 — Confidence and Cap Settings

These settings apply to Gate 2 controlled pilot. Do not change during the pilot without a new Claude session.

| Setting | Recommended Value | Your Confirmed Value |
|---------|------------------|---------------------|
| `confidence_threshold` | 0.85 | |
| `max_autonomous_sends_per_day` | 1 | |
| `require_post_action_review` | true | |
| `live_pilot_requires_owner_toggle` | true | |

---

## Section 5 — Owner Sign-Off on Allowlist Values

I confirm that the values I have written in this worksheet are the correct, owner-approved values for the Gate 2 controlled pilot. I understand that these are the only campaign IDs, sender email addresses, and intent types for which any autonomous action will be considered.

**Owner name:** ___________________________  
**Signature/Date:** ___________________________  

---

## Next Step After Completing This Worksheet

Once this worksheet is signed:

1. Tell Claude Code: "Gate 2 worksheet is complete. Here are my allowlist values: [paste values]."
2. Claude Code will update the allowlists in the n8n shadow evaluator config in a controlled session.
3. Claude Code will re-run the 20 offline allowlist tests with your specific values.
4. You will review and confirm the test results before Gate 2 is activated.

**Do not attempt to edit the n8n workflow directly without Claude Code assistance.**
