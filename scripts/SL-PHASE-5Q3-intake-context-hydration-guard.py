#!/usr/bin/env python3
"""SL-PHASE-5Q3 intake/context hydration guard harness.

Local static/synthetic checks only. Does not call n8n, Sender, Instantly, or
Google Chat.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

checks: list[tuple[str, bool]] = []


def add(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")


def node_code(path: Path, name: str) -> str:
    workflow = json.loads(path.read_text(encoding="utf-8"))
    for node in workflow.get("nodes", []):
        if node.get("name") == name:
            return (node.get("parameters") or {}).get("jsCode") or ""
    raise AssertionError(f"node not found: {name}")


decision_d = node_code(DECISION, "D. Draft Preparation (Templates / Human Draft)")
human_a = node_code(HUMAN, "A. Build Review Case Record")
human_d = node_code(HUMAN, "D. Build Google Chat Notification Payload")
human_j = node_code(HUMAN, "J. Render Review Form HTML")
human_n = node_code(HUMAN, "N. Process Reviewer Decision")
human_p2a = node_code(HUMAN, "SL-P2A. Prepare Phase 1C+2 Capture Data")
human_p = json.loads(HUMAN.read_text(encoding="utf-8"))
approval_router = next(
    node for node in human_p["nodes"] if node.get("name") == "P. Approval Outcome Router"
)
approval_router_text = json.dumps(approval_router.get("parameters", {}), ensure_ascii=False)


print("== Decision D syntax regression guard ==")
add("active-policy regex contains escaped word boundaries, not backspace chars", "\x08" not in decision_d and r"\b(proof|prove" in decision_d)
add("paragraph split regex is escaped and not a broken multiline literal", r"text.split(/\n\s*\n/)" in decision_d)
add("mandatory active guidance string uses escaped newlines", r"return '\n\nMANDATORY ACTIVE DRAFTING CONSTRAINTS" in decision_d)
add("Decision D no longer contains the historical broken text.split literal", "text.split(/\n\\s*\n/)" not in decision_d)

print("\n== HumanApproval missing-context diagnostic guard ==")
add("case creation computes missingContextFields", "missingContextFields" in human_a)
add("missing sender/from blocks diagnostic review", 'missingContextFields.push("reply_from_email")' in human_a and 'missingContextFields.push("sender_email")' in human_a)
add("missing reply body blocks diagnostic review", 'missingContextFields.push("reply_text")' in human_a)
add("missing subject/thread blocks diagnostic review", 'missingContextFields.push("reply_subject")' in human_a and 'missingContextFields.push("thread_id")' in human_a)
add("missing classification/micro-intent/draft blocks diagnostic review", 'missingContextFields.push("classification")' in human_a and 'missingContextFields.push("micro_intent")' in human_a and 'missingContextFields.push("draft_text")' in human_a)
add("diagnostic cases use INTAKE_CONTEXT_MISSING state", "INTAKE_CONTEXT_MISSING" in human_a and "CONTEXT_MISSING_BLOCKED" in human_a)
add("diagnostic cases use non-send reply mode", "DIAGNOSTIC_CONTEXT_MISSING" in human_a)
add("diagnostic alert includes missing field names", "INVALID reply review case - missing context" in human_d and "Missing fields:" in human_d)
add("diagnostic alert includes owner correction instructions", "Correction:" in human_d and "seeded owned/test prospect" in human_d)
add("diagnostic form explains blocked state", "Invalid review case - missing context" in human_j and "Approve/send and learning-only actions are unavailable" in human_j)
add("persisted blank/UNKNOWN rows render diagnostic-only", "_5q3RowLooksMissing" in human_j)
add("diagnostic form returns before normal form/buttons", "return { json: { ...input, html } };" in human_j and human_j.find("Invalid review case - missing context") < human_j.find("Approve and send"))
add("approve/send button remains only on normal review path", "Approve and send" in human_j and "DIAGNOSTIC_CONTEXT_MISSING" in human_j)
add("learning-only button remains only on normal/reopened paths", "approve_learning_only" in human_j and human_j.find("Invalid review case - missing context") < human_j.find("approve_learning_only"))
add("submit processing blocks diagnostic cases", "blocked_context_missing" in human_n and "Diagnostic missing-context cases cannot be approved" in human_n)
add("persisted blank/UNKNOWN rows are blocked on submit", "rowLooksMissing" in human_n)
add("blank diagnostic cases cannot create learning candidates", "context_missing_no_learning" in human_p2a and "sl_p2_rule_candidates: []" in human_p2a)
add("Sender path still requires final_action approve", "$json.final_action === 'approve'" in approval_router_text)


print("\n== Synthetic guard predicate ==")


def synthetic_missing_context(case: dict) -> tuple[bool, list[str]]:
    fields: list[str] = []
    if not case.get("reply_from_email"):
        fields.append("reply_from_email")
    if not case.get("sender_email"):
        fields.append("sender_email")
    if not case.get("reply_subject"):
        fields.append("reply_subject")
    if not case.get("thread_id"):
        fields.append("thread_id")
    if not case.get("reply_text"):
        fields.append("reply_text")
    if not case.get("draft_text"):
        fields.append("draft_text")
    if not case.get("category") or case.get("category") == "UNKNOWN":
        fields.append("classification")
    if not case.get("micro_intent"):
        fields.append("micro_intent")
    blocked = bool(fields)
    return blocked, fields


valid_case = {
    "reply_from_email": "prospect@example.test",
    "sender_email": "sender@example.test",
    "reply_subject": "Re: Capacity Question",
    "thread_id": "thread-1",
    "reply_text": "Before we book anything, can you explain setup?",
    "draft_text": "Of course. The setup includes qualification and capacity planning.",
    "category": "INFORMATION_REQUEST",
    "micro_intent": "OFFER_EXPLANATION",
    "validation_valid": True,
}
blocked, missing = synthetic_missing_context(valid_case)
add("valid hydrated inbound reply remains normal review case", not blocked and missing == [])

for field in ["reply_from_email", "reply_text", "reply_subject", "thread_id", "draft_text", "category"]:
    bad = dict(valid_case)
    bad[field] = "UNKNOWN" if field == "category" else ""
    blocked, missing = synthetic_missing_context(bad)
    expected = "classification" if field == "category" else field
    add(f"missing {expected} blocks normal review/send", blocked and expected in missing)

bad_unknown = dict(valid_case, category="UNKNOWN", draft_text="", micro_intent="", validation_valid=False)
blocked, missing = synthetic_missing_context(bad_unknown)
add("UNKNOWN classification with blank draft is diagnostic only", blocked and "classification" in missing and "draft_text" in missing)


failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
