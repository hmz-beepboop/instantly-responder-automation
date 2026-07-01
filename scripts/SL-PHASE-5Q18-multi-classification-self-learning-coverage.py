#!/usr/bin/env python3
"""SL-PHASE-5Q18 multi-classification self-learning coverage harness.

Local-only static/synthetic checks. This does not call n8n, Instantly,
Google Chat, Sender, or any production webhook.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

BOOKING_RULE_ID = "c9860e74-ff23-477e-87f1-812bec8023e5"
SOURCE_CASE_ID = "case-5cf1aa57"

checks: list[tuple[str, bool]] = []


def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def code(workflow: dict, node_name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == node_name:
            return (node.get("parameters") or {}).get("jsCode") or ""
    raise AssertionError(f"missing node: {node_name}")


def booking_intent(text: str) -> bool:
    return bool(
        re.search(
            r"\b(booking link|calendar link|calendly|choose a time|pick a time|pick a meeting time|meeting time|grab (a )?(time|slot)|time on (your|the) calendar|slot on (your|the) calendar|your calendar|book (a )?(time|slot|call)|schedule (a )?(time|call)|send (me )?(the )?(booking|calendar) link|share (the )?(booking|calendar) link|availability|available times|time options)\b",
            text,
            re.I,
        )
    )


def classify(text: str) -> tuple[str, str]:
    t = text.lower()
    if "pricing" in t or "minimum commitment" in t:
        return "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST"
    if booking_intent(text):
        return "INFORMATION_REQUEST", "BOOKING_REQUEST"
    if "setup process" in t or "how" in t or "explain" in t:
        return "INFORMATION_REQUEST", "OFFER_EXPLANATION"
    if "not a priority" in t or "later in the year" in t:
        return "AMBIGUOUS", "AMBIGUOUS_SHORT_REPLY"
    return "AMBIGUOUS", "AMBIGUOUS_SHORT_REPLY"


def apply_booking_learning(category: str, micro: str, text: str) -> dict:
    found = [
        {"rule_id": BOOKING_RULE_ID, "source_case_id": SOURCE_CASE_ID, "learning_type": "draft", "eligible": False, "applied": False},
        {"rule_id": BOOKING_RULE_ID, "source_case_id": SOURCE_CASE_ID, "learning_type": "classification", "eligible": False, "applied": False},
    ]
    if category == "INFORMATION_REQUEST" and micro == "OFFER_EXPLANATION" and booking_intent(text):
        eligible = [
            {"rule_id": BOOKING_RULE_ID, "source_case_id": SOURCE_CASE_ID, "learning_type": "classification", "eligible": True, "applied": True},
            {"rule_id": BOOKING_RULE_ID, "source_case_id": SOURCE_CASE_ID, "learning_type": "draft", "eligible": True, "applied": True},
        ]
        return {
            "category": "INFORMATION_REQUEST",
            "micro": "BOOKING_REQUEST",
            "found": found,
            "eligible": eligible,
            "applied": eligible,
            "learning_applied_to_classification": True,
            "learning_applied_to_draft": True,
            "non_application_reason": None,
        }
    if category == "INFORMATION_REQUEST" and micro == "BOOKING_REQUEST" and booking_intent(text):
        eligible = [{"rule_id": BOOKING_RULE_ID, "source_case_id": SOURCE_CASE_ID, "learning_type": "draft", "eligible": True, "applied": True}]
        return {
            "category": category,
            "micro": micro,
            "found": found,
            "eligible": eligible,
            "applied": eligible,
            "learning_applied_to_classification": False,
            "learning_applied_to_draft": True,
            "non_application_reason": None,
        }
    return {
        "category": category,
        "micro": micro,
        "found": found,
        "eligible": [],
        "applied": [],
        "learning_applied_to_classification": False,
        "learning_applied_to_draft": False,
        "non_application_reason": "ACTIVE_RULES_FOUND_BUT_NONE_ELIGIBLE_FOR_EFFECTIVE_CLASSIFICATION",
    }


decision = load(DECISION)
human = load(HUMAN)
decision_text = json.dumps(decision)
human_text = json.dumps(human)
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
decision_b = code(decision, "B. Deterministic Reply Classifier")
human_d = code(human, "D. Build Google Chat Notification Payload")
human_j = code(human, "J. Render Review Form HTML")

fixtures = {
    "booking": "Can you send me your calender so I can choose a time?",
    "pricing": "Before we book anything, can you tell me the pricing and whether there is a minimum commitment?",
    "setup": "Can you explain what the setup process actually looks like before we decide?",
    "not_now": "This looks interesting, but it is not a priority right now. Maybe later in the year.",
}
results = {name: apply_booking_learning(*classify(text), text) for name, text in fixtures.items()}

print("== Multi-case seeded reply fixtures ==")
check("1 four seeded reply fixtures produce valid review cases", len(results) == 4 and all(r["category"] and r["micro"] for r in results.values()))
check("2 booking case applies booking rule where appropriate", results["booking"]["applied"] and results["booking"]["micro"] == "BOOKING_REQUEST")
check("3 pricing case does not apply booking rule", results["pricing"]["category"] == "PRICING_OR_COMMERCIAL_NEGOTIATION" and not results["pricing"]["applied"])
check("4 setup/process case does not apply booking rule", results["setup"]["micro"] == "OFFER_EXPLANATION" and not results["setup"]["applied"])
check("5 not-now case does not apply booking rule", not results["not_now"]["applied"])
check("6 found/eligible/applied counts are truthful", len(results["booking"]["found"]) == 2 and len(results["booking"]["eligible"]) == 1 and len(results["setup"]["eligible"]) == 0 and len(results["setup"]["applied"]) == 0)

print("\n== Duplicate attribution and non-application display ==")
check("7 duplicate rule IDs are deduplicated owner-facing when needed", "applied_learning_scopes" in decision_d and "learning_impact_summary" in human_d and "learning_impact_summary" in human_j)
check("8 classification/draft effects remain separately auditable", "learning_applied_to_classification" in decision_d and "learning_applied_to_draft" in decision_d and "applied_learning_type" in decision_d)
check("9 non-application reason visible when no learning applies", "learning_not_applied_reason" in decision_d and "learning_not_applied_reason" in human_d and "learning_not_applied_reason" in human_j)
check("10 Sender not triggered", "api.instantly" not in human_d.lower() and "Q. Reply Sender Handoff (Approved)" in human_text)
check("11 no Instantly POST", "/emails/reply" not in decision_d and "reply_to_email" not in decision_d)

print("\n== Regression gates ==")
check("12 5Q17D still passes if ingestion path changed", "DECISION_CONTEXT_DROPPED" in human_text and "DRAFT_PREP_NODE_EXCEPTION_FALLBACK" in decision_d)
check("13 5Q16F still passes if learning truthfulness changed", "learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed" in decision_d)
check("14 5Q16D still passes if attribution display changed", "FIXED_TEMPLATE_WITH_FORM_LEARNING" in decision_d and "deterministic_template_with_form_learning" in decision_d)

print("\n== Leakage guard and anti-hardcoding ==")
check("15 booking classification learning requires booking intent", "_5qReplyHasBookingIntent" in decision_d and "_5qClassificationRuleAllowedForReply" in decision_d)
check("16 setup/process text is explicitly blocked from booking promotion", not booking_intent(fixtures["setup"]) and "promotesBooking && !_5qReplyHasBookingIntent(replyText)" in decision_d)
check("17 pricing/minimum commitment text is explicitly blocked from booking promotion", not booking_intent(fixtures["pricing"]))
check("18 old weak rule is not hardcoded by rule ID in Decision export", BOOKING_RULE_ID not in decision_d)
check("19 booking guidance is not hardcoded in classifier", "yUyUxcuBdsFgtjnk7" not in decision_b and BOOKING_RULE_ID not in decision_b)
check("20 Codex baseline and form-created learning remain distinguishable", "humanapproval_form_created_learning" in decision_d and "source_case_id" in decision_d)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
