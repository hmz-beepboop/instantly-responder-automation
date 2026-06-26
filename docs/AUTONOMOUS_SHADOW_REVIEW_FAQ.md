# Autonomous Shadow Review — FAQ

**Version:** 1.0  
**Date:** 2026-06-24

---

## General

**Q: What is shadow review and why does it matter?**  
A: Shadow review is a period where you submit real prospect replies to the autonomous system without it actually sending anything. You compare the system's decisions to your own judgment. If the system consistently agrees with you on what to send and what to block, you have evidence it is safe for a controlled pilot. If it disagrees, you catch safety problems before any real email is sent.

**Q: Why 14 days? Can we do fewer?**  
A: 14 days captures day-of-week variation (Monday replies behave differently from Friday replies) and gives you enough volume to see patterns. You can do more than 14 days. You cannot do fewer and still approve Gate 2.

**Q: Do I need to review every reply every day?**  
A: No. Select 1–5 representative replies per day. The goal is breadth across intent types, not exhaustiveness. By day 14 you should have reviewed at least 30 cases with coverage across scheduling requests, information requests, and several blocked types.

**Q: What if I get no interesting replies some days?**  
A: On low-traffic days, you can review replies from earlier that week that you have not reviewed yet, or use examples from the payload library in `docs/AUTONOMOUS_SHADOW_REVIEW_PAYLOAD_LIBRARY.md`. Flag these as LIBRARY cases in the notes field.

---

## Safety

**Q: Can the system accidentally send something during shadow review?**  
A: No. Six independent safety gates block any send. The shadow evaluator workflow (`aHzLtQiv6G8h1bqD`) is `active=false` throughout the shadow review period. Payloads submitted to the helper are processed locally — no live n8n calls are made. The field `would_send_live_now` will always be `false`.

**Q: What should I do if I see `would_send_live_now = true` in any output?**  
A: Stop immediately. Do not continue the shadow review. Start a Claude Code session with: "I am running shadow review and `would_send_live_now` returned true. Payload attached. Please investigate."

**Q: What should I do if the shadow evaluator workflow shows `active=true` when I check n8n?**  
A: Stop immediately. Do not submit any more shadow review payloads. Start a Claude Code session with: "Shadow evaluator `aHzLtQiv6G8h1bqD` is showing active=true. It should be false. Please investigate and deactivate."

**Q: Does submitting shadow review payloads change my live outgoing emails?**  
A: No. Shadow review is fully read-only from the perspective of Instantly.ai and your prospect. The system assesses what it would have done but takes no real action.

---

## Payload Filling

**Q: How much of the real reply text should I paste?**  
A: Paste the complete reply text but mask any personally identifying information: use `joh@example.com` instead of `john.smith@company.com`, and replace the prospect's name with "[PROSPECT]". The intent classification depends on the actual wording, so do not paraphrase.

**Q: What if the reply contains sensitive personal information (medical, financial, legal)?**  
A: Do not paste it verbatim. Paraphrase the intent and note in the `your_notes` field: "Reply contained sensitive personal data — paraphrased for payload." These cases should always be routed to human review regardless of system assessment.

**Q: What if I do not know what campaign ID or sender email to use?**  
A: Find the campaign in Instantly.ai — the campaign ID is in the URL. For sender email, check which email account sent the original sequence to this prospect. If you cannot find it within 2 minutes, use placeholder values and note them in `your_notes`. The intent classification will still work.

**Q: What if the reply is in a language other than English?**  
A: Note the language in `your_notes`. Route non-English replies to human review. Do not submit non-English text as a representative shadow review case — the intent classifier is trained on English.

---

## Evaluating Results

**Q: How do I know if the system made the right call?**  
A: Ask yourself: "If this were a live case and the system did exactly what it says here — would that be acceptable?" If yes, AGREE. If the system says SHADOW_LOG (would have been eligible for autonomous send) and you would have sent it to human review — that is a false positive. Log it as DISAGREE.

**Q: What is a false positive in this context?**  
A: A false positive is when the system would have been eligible to autonomously reply, but your judgment says it should have gone to human review. False positives are the most important thing to catch because they represent cases where autonomous sending could have caused problems.

**Q: What is a false negative?**  
A: A false negative is when the system blocks or routes to human review, but your judgment says it was a clear, safe case for autonomous reply. False negatives reduce efficiency but not safety. A moderate rate of false negatives is acceptable and expected in early shadow review.

**Q: The system classified the intent as INFORMATION_REQUEST but I would have said SCHEDULING_REQUEST. Is this a problem?**  
A: If both would have been in the intent allowlist and both route to the same approved reply, this is a cosmetic classification disagreement — not a safety issue. Note it in `your_notes`. If the different classification leads to a different action (one would send, one would not), that is a more significant disagreement and should be flagged.

**Q: The system says HUMAN_REVIEW but I think it was a clear scheduling request. Should I override it?**  
A: No. Record your assessment as DISAGREE — system too restrictive. Do not override the system's decision during shadow review. The goal is to observe and measure, not to adjust.

---

## Gate 2 Progress

**Q: How do I know when I am ready for Gate 2?**  
A: Review `docs/GATE_2_SIGNOFF_BLOCKERS.md`. All 7 blockers must be resolved. The key metrics are: 14+ days, 30+ cases, 0 false positives, 0 unresolved disagreements.

**Q: What if I find a lot of false positives? Does that mean the system is broken?**  
A: Not necessarily broken — it may mean the intent allowlist needs refinement. Do not continue to Gate 2. Start a Claude Code session and describe the false positive patterns. The system can be adjusted before the shadow review is closed.

**Q: Can I complete the shadow review faster by submitting all 30 cases in one day?**  
A: No. The 14-day requirement is about calendar time, not case count. You need day-of-week and temporal variation in the prospect replies being reviewed. 30 cases in one day defeats the purpose.
