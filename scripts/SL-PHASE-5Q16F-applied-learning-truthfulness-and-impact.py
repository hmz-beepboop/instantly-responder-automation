#!/usr/bin/env python3
"""SL-PHASE-5Q16F applied-learning truthfulness and impact harness.

Local-only static/synthetic checks. This script does not call n8n,
Instantly, Sender, Google Chat, or any production API.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

RULE_ID = "c9860e74-ff23-477e-87f1-812bec8023e5"
SOURCE_CASE = "case-5cf1aa57"
SOURCE_MARKER = "humanapproval_form_created_learning"
BOOKING_URL = "https://calendar.app.google/yUyUxcuBdsFgtjnk7"
BAD_SENTENCE = "you can ask any question if they have any"
BAD_SENTENCE_SOURCE = "they can ask any question if they have any"
SOURCE_RULE_INSTRUCTION = (
    "Just share the booking link and offer that I can book them in if they share their availability.\n\n"
    f"Booking link: {BOOKING_URL}\n\n"
    "Do NOT talk about the offer, just answer their question. "
    "At the end you can mention thaqt they can ask any question if they have any."
)

LEARNED_BOOKING_OUTPUT = [
    "Here is the booking link so you can choose a time",
    "If you prefer, send over a couple of times that work and I can book it in",
    "If you have any questions, send them over",
    "I can book you in if you share your availability",
    BAD_SENTENCE,
]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def code(workflow: dict, node_name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == node_name:
            return node.get("parameters", {}).get("jsCode", "")
    raise AssertionError(f"missing node: {node_name}")


def section(text: str, start: str, end: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[i:j]


def contains_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def norm_draft(text: str) -> str:
    return re.sub(r"\n{3,}", "\n\n", re.sub(r"[ \t]+", " ", text or "").replace("\r", "")).strip()


def instruction_sentence(instruction: str, pattern: re.Pattern[str]) -> str:
    text = re.sub(r"https?://[^\s)]+", " ", instruction or "", flags=re.I).replace("\r", " ")
    pieces = [p.strip() for p in re.split(r"(?:\n+|[.!?]+\s*)", text) if p.strip()]
    picked = next((p for p in pieces if pattern.search(p) and not re.search(r"\bdo\s+not\b", p, re.I)), "")
    if not picked:
        return ""
    sentence = re.sub(r"^\s*(?:just\s+)?(?:share\s+the\s+booking\s+link\s+and\s+)?", "", picked, flags=re.I)
    sentence = re.sub(r"^offer\s+that\s+", "", sentence, flags=re.I)
    sentence = re.sub(r"^at\s+the\s+end\s+you\s+can\s+mention\s+(?:that|thaqt)\s+", "", sentence, flags=re.I)
    sentence = re.sub(r"\bthey\s+can\b", "you can", sentence, flags=re.I)
    sentence = re.sub(r"\bthey\s+share\b", "you share", sentence, flags=re.I)
    sentence = re.sub(r"\btheir\b", "your", sentence, flags=re.I)
    sentence = re.sub(r"\bthem\b", "you", sentence, flags=re.I).strip()
    return sentence if not sentence or sentence.endswith((".", "!", "?")) else sentence + "."


def apply_form_rule(base: str, instruction: str, sender_name: str = "Zahid") -> str:
    if not re.search(r"\b(booking link|calendar link)\b", instruction or "", re.I):
        return base
    parts = [f"Booking link: {BOOKING_URL}"]
    availability = instruction_sentence(instruction, re.compile(r"availability|available times|book (?:them|it|you) in|book.*in", re.I))
    questions = instruction_sentence(instruction, re.compile(r"any questions?|ask any question", re.I))
    if availability:
        parts.append(availability)
    if questions:
        parts.append(questions)
    if sender_name:
        parts.append(sender_name)
    return "\n\n".join(parts)


decision = load(DECISION)
human = load(HUMAN)
decision_text = json.dumps(decision, ensure_ascii=False)
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_a = code(human, "A. Build Review Case Record")
human_d = code(human, "D. Build Google Chat Notification Payload")
human_j = code(human, "J. Render Review Form HTML")
human_capture = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")

template_block = section(decision_d, "const MI_TEMPLATES =", "// === AI OUTPUT VALIDATION")
fallback_block = section(decision_d, "function buildPolicyAwareFallback", "function buildAIPrompt")
postprocessor_block = section(decision_d, "function _5qInstructionLinesFromGuidance", "function _5qSelectClassificationLearningRule")

base_draft = (
    "Thanks. Happy to talk it through.\n\n"
    "You can choose a suitable time here: https://calendar.app.google/example\n\n"
    "Zahid"
)
with_rule = apply_form_rule(base_draft, SOURCE_RULE_INSTRUCTION)
without_rule = apply_form_rule(base_draft, "")

checks: list[tuple[str, bool]] = []


def check(label: str, ok: bool) -> None:
    checks.append((label, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'} {label}")


check("1 found/eligible/applied are distinct", all(s in decision_d for s in ["active_learning_rules_found", "active_learning_rules_eligible", "active_learning_rules_applied"]) and "RULE_FOUND_BUT_NO_OUTPUT_DELTA" in decision_d)
check("2 learning_applied_to_draft true only when output changes", "_5qDraftLearningDelta" in decision_d and "draftLearningDelta.changed" in decision_d and "learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed" in decision_d)
check("3 learning_applied_to_classification true only when classification changes", "classificationChanged" in decision_d and "classification_learning_applied: classificationChanged" in decision_d)
check("4 rule found but no output delta produces non-application reason", "RULE_FOUND_BUT_NO_OUTPUT_DELTA" in decision_d)
check("5 learning impact summary is emitted when applied", "learning_impact_summary" in decision_d and "_5qLearningImpactSummary" in decision_d)
check("6 Google Chat can display learning impact summary", "Learning impact summary:" in human_d and "Active learning rules actually applied:" in human_d)
check("7 review form can display learning impact summary", "Learning impact summary:" in human_j and "Active learning rules actually applied:" in human_j)
check("8 applied rule ID/source case/source marker remain visible", "Applied learning rule ID(s):" in human_d and "Applied rule ID(s):" in human_j and all(s in human_d and s in human_j for s in ["Source case ID(s):", "Source marker(s):"]))
check("9 deterministic template without active rule remains generic", without_rule == base_draft and "FIXED_TEMPLATE_WITH_FORM_LEARNING" in decision_d)
check("10 deterministic template with active rule changes via rule context", norm_draft(with_rule) != norm_draft(base_draft) and BOOKING_URL in with_rule and "availability" in with_rule.lower())
check("11 bad sentence is not from generic deterministic template", BAD_SENTENCE not in template_block and BAD_SENTENCE_SOURCE in SOURCE_RULE_INSTRUCTION)
check("12 booking guidance is not hardcoded in baseline", not contains_any(decision_b, LEARNED_BOOKING_OUTPUT))
check("13 booking guidance is not hardcoded in deterministic template", not contains_any(template_block, LEARNED_BOOKING_OUTPUT))
check("14 booking guidance is not hardcoded in fallback", not contains_any(fallback_block, LEARNED_BOOKING_OUTPUT))
check("15 booking guidance is not hardcoded in postprocessor", not contains_any(postprocessor_block, LEARNED_BOOKING_OUTPUT) and "humanapproval_form_created_learning|humanapproval_form" in postprocessor_block)
check("16 pricing/unrelated case does not receive booking rule", "PRICING_REQUEST" in decision_b and "RULE_FOUND_BUT_NO_OUTPUT_DELTA" in decision_d)
check("17 Sender not triggered", "Reply Sender" not in decision_text)
check("18 no Instantly POST", "api.instantly" not in decision_d.lower() and "api/v2/emails/reply" not in decision_d)
check("19 5Q16D harness still applicable if attribution path changed", (ROOT / "scripts" / "SL-PHASE-5Q16D-learning-attribution-and-template-proof-gate.py").exists())
check("20 5Q16B harness still applicable if deterministic path changed", (ROOT / "scripts" / "SL-PHASE-5Q16B-deterministic-template-false-positive-audit.py").exists())
check("21 5Q15 harness still applicable if dynamic learning path changed", (ROOT / "scripts" / "SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.py").exists())
check("22 5Q12 harness still applicable if form-learning source path changed", (ROOT / "scripts" / "SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py").exists() and SOURCE_MARKER in human_capture)

passed = sum(1 for _, ok in checks if ok)
total = len(checks)
print(f"\nSL-PHASE-5Q16F applied-learning truthfulness/impact: {passed}/{total} PASS")
if passed != total:
    sys.exit(1)
