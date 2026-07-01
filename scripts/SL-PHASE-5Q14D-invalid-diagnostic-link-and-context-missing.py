#!/usr/bin/env python3
"""SL-PHASE-5Q14D invalid diagnostic link and context-missing harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
OpenAI, Google Chat, Sender, or any production webhook.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"
DECISION = ROOT / "workflows" / "production_decision_current.json"

DIAGNOSTIC_STATUS = "CONTEXT_MISSING_BLOCKED"
INTAKE_STATUS = "INTAKE_CONTEXT_MISSING"
CORRECTION = (
    "Use an owned/test prospect that is already a seeded lead in the active Instantly campaign. "
    "Reply in the existing campaign thread from the prospect inbox. Do not forward, compose a new "
    "standalone email, or use an unseeded address. Confirm Instantly shows campaign, lead email, "
    "subject, thread, and reply body before retrying."
)

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


def extract_status_list(js: str, const_name: str) -> list[str]:
    match = re.search(rf"const\s+{re.escape(const_name)}\s*=\s*\[([^\]]+)\];", js)
    if not match:
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def norm(value: object) -> str:
    return str("" if value is None else value).strip().upper()


def booking_crosswalk(policy_micro_intent: object, category: object, micro_intent: object) -> bool:
    pmi = norm(policy_micro_intent)
    cat = norm(category)
    mi = norm(micro_intent)
    if pmi and pmi == mi:
        return True
    return pmi == "BOOKING_REQUEST" and (
        (cat == "BOOKING_REQUEST" and mi == "MEETING_TIME_REQUEST")
        or (cat == "INFORMATION_REQUEST" and mi == "BOOKING_REQUEST")
    )


human = load(HUMAN)
decision = load(DECISION)
create_case = code(human, "A. Build Review Case Record")
notify = code(human, "D. Build Google Chat Notification Payload")
get_gate = code(human, "H. Validate Review Token (GET)")
post_gate = code(human, "L. Validate & Consume Review Token (POST)")
render = code(human, "J. Render Review Form HTML")
token_error = code(human, "J2. Render Token Error Page")
process = code(human, "N. Process Reviewer Decision")
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")

get_renderable = extract_status_list(get_gate, "REVIEW_LINK_RENDERABLE_STATUSES")
post_renderable = extract_status_list(post_gate, "REVIEW_LINK_RENDERABLE_STATUSES")
post_handoff_optional = extract_status_list(post_gate, "HANDOFF_OPTIONAL_REOPEN_STATUSES")

print("== Diagnostic review-link contract ==")
check("diagnostic-only case link renders until expiry", DIAGNOSTIC_STATUS in get_renderable and "token_expires_at" in get_gate and "EXPIRED" in get_gate)
check("diagnostic-only case does not show already-decided before expiry", DIAGNOSTIC_STATUS in get_renderable and "ALREADY_DECIDED" in token_error)
check("diagnostic page shows case ID", "Case ID:" in render and "rc.case_id" in render)
check("diagnostic page shows status", "INTAKE_CONTEXT_MISSING / diagnostic only" in render)
check("diagnostic page shows missing fields", "Missing fields:" in render and "missing_fields" in render)
check("diagnostic page shows exact correction instructions", CORRECTION in create_case and "Correction instructions:" in render and "owner_correction_instructions" in render)
check("diagnostic page states no reply was sent", "No reply was sent." in render)
check("diagnostic page states it cannot be approved/sent", "This diagnostic case cannot be approved or sent." in render)
check("diagnostic page disables send/approval actions", 'type=\\"button\\" disabled' in render and "Approve and send unavailable" in render and "Approved for learning only unavailable" in render)
check("token remains stable", "row.token =" not in get_gate and "row.token =" not in post_gate and "generateReviewToken" not in get_gate and "generateReviewToken" not in post_gate)
check("expired token still blocks correctly", "EXPIRED" in get_gate and "EXPIRED" in post_gate and "This review link has expired" in token_error)

print("\n== Review-link regressions ==")
normal_reopen_statuses = {
    "NEW",
    "IN_REVIEW",
    "SAVED",
    "RETRY_NEEDED",
    "BLOCKED_MISSING_VARIABLES",
    "LEARNING_REVISION_APPROVED",
    "RESPONSE_APPROVED",
    "RESPONSE_SENT",
    "FOLLOWUP_SEND_PENDING_MANUAL",
    "FOLLOWUP_SEND_CAPTURED",
    "MANUAL_SEND_REQUIRED",
}
check("normal review links still render after save/block/send/manual states", normal_reopen_statuses.issubset(set(get_renderable)))
check("5Q11 accessibility behaviour not regressed", {"RESPONSE_APPROVED", "RESPONSE_SENT", "LEARNING_REVISION_APPROVED", "FOLLOWUP_SEND_PENDING_MANUAL", "MANUAL_SEND_REQUIRED"}.issubset(set(get_renderable)))

print("\n== Intake/context and Decision repair ==")
check("diagnostic case creation records draft_text as missing", 'missingContextFields.push("draft_text")' in create_case and INTAKE_STATUS in create_case)
check("Decision maps INFORMATION_REQUEST/BOOKING_REQUEST to an existing sendable draft policy", "BOOKING_REQUEST:           'FIXED_TEMPLATE'" in decision_b)
check("Decision aliases BOOKING_REQUEST micro-intent to the existing booking template", "templateMicroIntent = microIntent === 'BOOKING_REQUEST' ? 'MEETING_TIME_REQUEST' : microIntent" in decision_d)
check("5Q14B deterministic-template learning still covers both booking taxonomies", booking_crosswalk("BOOKING_REQUEST", "BOOKING_REQUEST", "MEETING_TIME_REQUEST") and booking_crosswalk("BOOKING_REQUEST", "INFORMATION_REQUEST", "BOOKING_REQUEST") and "INFORMATION_REQUEST' && mi === 'BOOKING_REQUEST" in decision_d)
check("5Q12 form-learning source consumption remains present", "Q12. Lookup Active Form Learning Rules" in json.dumps(decision) and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d and "humanapproval_form_created_learning" in decision_d)

print("\n== Send safety ==")
check("diagnostic POST path is non-send and non-learning", "blocked_context_missing" in process and "Diagnostic missing-context cases cannot be approved, sent, saved as learning, or used to create candidates." in process)
check("Sender is not triggered by diagnostic contract repair", "Q. Reply Sender Handoff (Approved)" in json.dumps(human) and "blocked_context_missing" in process and DIAGNOSTIC_STATUS in post_handoff_optional)
changed_decision_nodes = decision_b + decision_d
changed_human_nodes = get_gate + post_gate + render + process
check("no Instantly POST occurs in changed nodes", "reply_to_email" not in changed_decision_nodes and "reply_to_email" not in changed_human_nodes and "/emails/reply" not in changed_decision_nodes and "/emails/reply" not in changed_human_nodes)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
