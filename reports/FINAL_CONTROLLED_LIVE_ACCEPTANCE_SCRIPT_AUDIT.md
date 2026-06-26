# Final Controlled-Live Acceptance Script Audit

**Status:** `FINAL_ACCEPTANCE_SCRIPT_HARDENED`

The 3.1 package was offline-complete, but independent source review found that
the controlled-live script began its Sender-execution observation window only
after the operator had approved the review case. Because approval triggers the
Sender immediately, a successful execution could start before the polling
window and be ignored.

The original final verdict also did not require all of the acceptance
contract: correct sender, correct recipient, empty CC/BCC, same Email/message
IDs, no duplicate after the observation window, successful safe-config
restoration, and all workflows inactive.

This patch:

- starts the observation window before the operator sends/approves;
- removes the unused `HMZ_CONTROLLED_LIVE_EMAIL_ID` prerequisite;
- supports both `-AllowOneControlledReply` and alias
  `-RunControlledLiveReply`;
- locally verifies sender and recipient rather than trusting API query
  filtering alone;
- requires the same single Email object after the duplicate-observation
  window;
- cross-checks Email and message IDs against the Sender terminal;
- requires empty CC/BCC;
- requires safe config restoration and all workflows inactive;
- fails the final acceptance verdict if restoration produced any warning.

No workflow JSON, policy, API contract, classifier, state machine, or
deployment configuration was changed.
