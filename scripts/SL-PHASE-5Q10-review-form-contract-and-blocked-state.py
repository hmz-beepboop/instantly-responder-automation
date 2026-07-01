#!/usr/bin/env python3
"""SL-PHASE-5Q10 HumanApproval review-form contract harness.

Local-only static checks. This script does not call n8n, Instantly, Sender,
OpenAI, Google Chat, or any production webhook.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

checks: list[tuple[str, bool]] = []


def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def node(workflow: dict, name: str) -> dict:
    for candidate in workflow.get("nodes", []):
        if candidate.get("name") == name:
            return candidate
    raise AssertionError(f"node not found: {name}")


def code(workflow: dict, name: str) -> str:
    return (node(workflow, name).get("parameters") or {}).get("jsCode") or ""


human = load(HUMAN)
connections = human.get("connections", {})

render = code(human, "J. Render Review Form HTML")
post = code(human, "L. Validate & Consume Review Token (POST)")
decision = code(human, "N. Process Reviewer Decision")
q2 = code(human, "Q2. Build Non-Send Terminal Result")

print("== UI/backend field contract ==")
check("draft textarea has visible label and backend body mapping", "Reply text (editable):" in render and 'name=\\"edited_reply_text\\"' in render and "submit_edited_text" in post and "body.edited_reply_text" in post)
check("learning instruction has visible label and backend body mapping", "Why did you make this change, and what should the system do next time?" in render and 'name=\\"draft_learning_instruction\\"' in render and "submit_draft_learning_instruction" in post)
check("scope selections have visible labels and backend array mapping", "Where this draft improvement should apply" in render and 'name=\\"draft_improvement_scopes\\"' in render and "submit_draft_improvement_scopes" in post)
check("improvement type selections removed from visible form", "What type of improvement is this?" not in render and 'name=\\"draft_revision_types\\"' not in render)
check("classification amendment fields have visible labels and backend mappings", "Corrected broad category" in render and "Corrected micro intent" in render and "submit_corrected_category" in post and "submit_corrected_micro_intent" in post)
check("repeat-send reason is visible when repeat-send action is available", "Reason for sending another reply (required):" in render and 'name=\\"repeat_send_reason\\"' in render and "display:block" in render)

print("\n== Validation mapping ==")
check("blank normal approve/send blocks with draft-specific reason", 'missingVarsForApprove.push("draft_text_required")' in decision and "Enter reply text in the draft box" in decision)
check("blank draft does not map solely to repeat_send_reason_required", 'if (!submittedReplyText) missingVars.push("draft_text_required")' in decision and decision.find('if (!submittedReplyText) missingVars.push("draft_text_required")') < decision.find('if (!repeatReason) missingVars.push("repeat_send_reason_required")'))
check("repeat-send reason block only exists with visible repeat-send field", "repeat_send_reason_required" in decision and "Reason for sending another reply (required):" in render)
check("repeat-send block shows exact correction instruction", "Fill the Reason for sending another reply field" in decision)
check("learning-only blank draft with learning instruction is allowed", 'if (!approver || (!submittedReplyText && !submittedLearningInstruction))' in decision)
check("learning-only blank draft and blank learning instruction blocks clearly", "learning_instruction_required" in decision and "Enter a learning instruction explaining what should change next time" in decision)

print("\n== Blocked state and retry safety ==")
check("approved/sent banner persists after blocked submit", "_5q10PreviousStatus" in render and "_5pIsSentCase" in render and "This review was already approved and an email was already sent." in render)
check("blocked-attempt banner can appear without replacing sent banner", "Previous submit was blocked; no new reply was sent." in render and render.find("Previous submit was blocked; no new reply was sent.") < render.find("This review was already approved and an email was already sent."))
check("same review link remains usable after blocked submit", "same_review_link_retry: true" in decision and "BLOCKED_MISSING_VARIABLES" in code(human, "H. Validate Review Token (GET)") and "BLOCKED_MISSING_VARIABLES" in post)
check("case remains editable after blocked submit", 'rc.status = wasSentStyle ? previousStatus : "IN_REVIEW"' in decision and 'rc.status = "IN_REVIEW"' in decision)
check("token remains stable on blocked submit", "generateReviewToken" not in decision and "new_token" not in decision)
check("learning-only never sends", 'action: "approve_learning_only"' in decision and "sent: false" in decision and "prospect_received_reply: false" in decision)
check("learning-only preserves approved/sent banner", 'rc.status = wasSentStyle ? previousStatus : "IN_REVIEW"' in decision and "approve_learning_only" in decision)
check("no duplicate Instantly POST on validation block", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("Q2. Build Non-Send Terminal Result", {})) and "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("N. Process Reviewer Decision", {})))
check("Sender not triggered on validation block", "finalAction = \"blocked\"" in decision and "Q2. Build Non-Send Terminal Result" in json.dumps(connections))
check("Q2 names exact missing variables and correction steps", "Exact missing variable(s):" in q2 and "Correction steps:" in q2 and "missingVars.join" in q2)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
