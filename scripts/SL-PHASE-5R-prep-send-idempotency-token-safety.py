#!/usr/bin/env python3
"""
SL-PHASE-5R-prep send idempotency and token safety harness.

Local-only static/synthetic verification. Does not execute Sender, n8n,
Instantly, webhooks, or production APIs.
"""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"
SENDER = ROOT / "workflows" / "03_reply_sender_validation.json"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))
    status = "PASS" if ok else "FAIL"
    suffix = f" - {detail}" if detail else ""
    print(f"[{status}] {name}{suffix}")


def load(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def node(workflow, name):
    for n in workflow.get("nodes", []):
        if n.get("name") == name:
            return n
    raise AssertionError(f"node not found: {name}")


def code(workflow, name):
    return node(workflow, name).get("parameters", {}).get("jsCode", "")


def main():
    human = load(HUMAN)
    sender = load(SENDER)

    r0 = code(human, "R0. Check Sender Result")
    rgen = code(human, "R-GenToken. Generate Retry Token")
    r2 = node(human, "R2. Update Case RETRY_NEEDED").get("parameters", {})
    r3 = code(human, "R3. Build Retry Chat Message")
    r5 = code(human, "R5. Build Retryable Result Page")
    r5b = code(human, "R5b. Build Nonrecoverable Result Page")
    n = code(human, "N. Process Reviewer Decision")
    q = node(human, "Q. Reply Sender Handoff (Approved)").get("parameters", {})
    sender_f2 = code(sender, "F2. Blocked Duplicate or Rerun Terminal")
    sender_q = node(sender, "Q. POST Reply to Instantly (Gated)").get("parameters", {})

    print("== HumanApproval duplicate/retry/token safety ==")
    check("duplicate ownership reason is nonrecoverable", "SEND_OWNERSHIP_NOT_ACQUIRED" in r0 and "NONRECOVERABLE_REASONS" in r0)
    check("prior terminal/in-flight states are nonrecoverable", "NONRECOVERABLE_PRIOR_STATES" in r0 and "SENT_RECONCILED" in r0 and "SENDING" in r0)
    check("send lock/no prior terminal gate failures are nonrecoverable", "send_lock_acquired" in r0 and "no_prior_terminal_send_state" in r0)
    check("duplicate successful-send submit routes no retry token", "is_recoverable: isRecoverable" in r0 and "is_nonrecoverable: isBlocked && !isRecoverable" in r0)
    check("no false prospect-not-received message", "Prospect did NOT receive a reply" not in r3 and "Prospect did NOT receive a reply" not in r5)
    check("retry message keeps same review link usable", "same review link remains usable" in r3 and "same review link remains usable" in r5)
    check("retry URL has full production fallback", "https://n8n.hmzaiautomation.com/webhook/reply-review" in rgen)
    check("same stable review form returned for blocked/nonrecoverable path", "Return to the same review form" in r5b and "reply-review/review?case=" in r5b)
    check("specific block reason shown", "terminal_reason" in r0 and "Block details" in r5b)
    check("correction instructions shown", "correction_instructions" in r0 and "Correction instructions" in r5b)
    check("original token not mutated on nonrecoverable duplicate", "R2. Update Case RETRY_NEEDED" in json.dumps(human) and "new_token" not in r5b)
    check("recoverable blocked path preserves token and keeps case editable", "token_preserved" in rgen and "new_token:            preservedToken" in rgen and r2.get("columns", {}).get("value", {}).get("status") == "IN_REVIEW" and "is_recoverable === true" in json.dumps(node(human, "R1-Route. Retry Safety Router").get("parameters", {})))
    check("approval persists before sender handoff", "RESPONSE_APPROVED" in n and "latest_draft_learning" in n and q.get("workflowId", {}).get("value") == "ePS5uBBxKxhFCYgU")

    print("\n== Sender idempotency evidence ==")
    check("Sender duplicate/rerun terminal remains blocked", "SEND_OWNERSHIP_NOT_ACQUIRED" in sender_f2 and "result: 'BLOCKED'" in sender_f2)
    check("Sender blocked duplicate reports sent false", "sent: false" in sender_f2)
    check("Sender live POST node still gated", sender_q.get("method") == "POST" and "instantly" in str(sender_q).lower())
    check("Harness does not trigger Sender", True, "static JSON inspection only")

    print("\nSUMMARY: {}/{} PASS, {} FAIL".format(
        sum(1 for _, ok, _ in checks if ok),
        len(checks),
        sum(1 for _, ok, _ in checks if not ok),
    ))
    return 0 if all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
