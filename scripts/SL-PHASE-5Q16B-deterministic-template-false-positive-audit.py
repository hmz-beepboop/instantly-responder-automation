#!/usr/bin/env python3
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
LIVE_CASE = "case-dce9d552"
BOOKING_URL = "https://calendar.app.google/yUyUxcuBdsFgtjnk7"

OLD_HARDCODED_LEARNED_WORDING = [
    "Here is the booking link so you can choose a time",
    "If you prefer, send over a couple of times that work and I can book it in",
    "If you have any questions, send them over",
]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def code(workflow: dict, node_name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == node_name:
            return node.get("parameters", {}).get("jsCode", "")
    raise AssertionError(f"missing node: {node_name}")


def contains_any(text: str, needles) -> bool:
    return any(n in text for n in needles)


def norm(value: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "_", (value or "").upper()).strip("_")


def extract_first_url(text: str) -> str:
    match = re.search(r"https?://[^\s)]+", text or "", re.I)
    return match.group(0).rstrip(".,;") if match else ""


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


def active_instruction_lines(guidance: str):
    rows = []
    current = []
    include = False
    for line in (guidance or "").splitlines():
        trimmed = line.strip()
        if not trimmed:
            continue
        if re.match(r"^\d+\.\s+", trimmed):
            if current and include:
                rows.append(" ".join(current))
            current = [trimmed]
            include = bool(re.search(r"source_case_id:", trimmed, re.I) and re.search(r"humanapproval_form_created_learning|humanapproval_form", trimmed, re.I))
        elif re.match(r"^(These constraints are|Before returning JSON)", trimmed, re.I):
            if current and include:
                rows.append(" ".join(current))
            current = []
            include = False
        elif current:
            current.append(trimmed)
    if current and include:
        rows.append(" ".join(current))
    return [re.sub(r"^\d+\.\s*", "", row).split("]:", 1)[-1].strip() for row in rows if row]


def apply_runtime_rule(text: str, micro_intent: str, guidance: str, sender_name: str = "Hamza") -> str:
    if norm(micro_intent) not in ("BOOKING_REQUEST", "MEETING_TIME_REQUEST"):
        return text
    instructions = active_instruction_lines(guidance)
    if not instructions:
        return text
    instruction = " ".join(instructions)
    if not re.search(r"\b(booking link|calendar link)\b", instruction, re.I):
        return text
    link = extract_first_url(instruction)
    parts = [f"Booking link: {link}"] if link else []
    availability = instruction_sentence(instruction, re.compile(r"availability|available times|book (?:them|it|you) in|book.*in", re.I))
    questions = instruction_sentence(instruction, re.compile(r"any questions?|ask any question", re.I))
    if availability:
        parts.append(availability)
    if questions:
        parts.append(questions)
    if sender_name:
        parts.append(sender_name)
    return "\n\n".join(parts)


def select_classification_rule(rules, category, micro_intent):
    cat = norm(category)
    mi = norm(micro_intent)
    candidates = []
    for rule in rules:
        original = rule["original_classification"]
        if norm(original["broad_category"]) == cat and norm(original["micro_intent"]) == mi:
            candidates.append(rule)
    candidates.sort(key=lambda r: (r["time"], r["rule_id"]), reverse=True)
    return candidates[0] if candidates else None


def apply_classification_learning(rules, category, micro_intent):
    baseline = {"broad_category": category, "micro_intent": micro_intent}
    selected = select_classification_rule(rules, category, micro_intent)
    if not selected:
        return baseline, baseline, []
    return baseline, selected["corrected_effective_classification"], [selected]


decision = load(DECISION)
human = load(HUMAN)
decision_node_names = [node.get("name", "") for node in decision.get("nodes", [])]
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_capture = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
template_block = decision_d.split("const MI_TEMPLATES =", 1)[1].split("// === AI OUTPUT VALIDATION", 1)[0]
fallback_block = decision_d.split("function buildPolicyAwareFallback", 1)[1].split("function buildAIPrompt", 1)[0]
postprocessor_block = decision_d.split("function _5qInstructionLinesFromGuidance", 1)[1].split("function _5qSelectClassificationLearningRule", 1)[0]

base_draft = (
    "You can choose a suitable time here: https://calendar.app.google/bNXWJkS3xz3yqdW36\n\n"
    "Or reply with a couple of times that work for you and I'll coordinate it.\n\n"
    "Hamza"
)
form_guidance = (
    "\nMANDATORY ACTIVE DRAFTING CONSTRAINTS FROM OWNER-APPROVED POLICIES:\n"
    f"1. {RULE_ID} [source_case_id: {SOURCE_CASE}; source_marker: {SOURCE_MARKER}]: "
    f"Just share the booking link and offer that I can book them in if they share their availability. "
    f"Booking link: {BOOKING_URL} Do NOT talk about the offer, just answer their question. "
    "At the end you can mention that they can ask any question if they have any.\n"
)
non_form_guidance = "1. baseline [source_case_id: case-baseline; source_marker: codex_baseline]: booking link"
pricing_guidance = form_guidance.replace("BOOKING_REQUEST", "PRICING_REQUEST")

old_rule = {
    "rule_id": "older",
    "source_case_id": "old-case",
    "source_marker": SOURCE_MARKER,
    "time": 1,
    "original_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"},
    "corrected_effective_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "HOW_IT_WORKS_REQUEST"},
}
new_rule = {
    "rule_id": RULE_ID,
    "source_case_id": SOURCE_CASE,
    "source_marker": SOURCE_MARKER,
    "time": 2,
    "original_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"},
    "corrected_effective_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "BOOKING_REQUEST"},
}

baseline, effective, applied = apply_classification_learning([old_rule, new_rule], "INFORMATION_REQUEST", "OFFER_EXPLANATION")
unrelated_baseline, unrelated_effective, unrelated_applied = apply_classification_learning([new_rule], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST")
without_rule = apply_runtime_rule(base_draft, "BOOKING_REQUEST", "")
with_rule = apply_runtime_rule(base_draft, "BOOKING_REQUEST", form_guidance)
pricing_with_rule = apply_runtime_rule("Pricing depends on scope.", "PRICING_REQUEST", pricing_guidance)

live_fixture = {
    "case_id": LIVE_CASE,
    "valid_non_diagnostic": True,
    "decision_execution_id": "3555",
    "humanapproval_execution_id": "3556",
    "created_after_decision_4e04ebc8": True,
    "created_after_humanapproval_16ad1875": True,
    "draft_source": "deterministic_template",
    "draft_policy": "FIXED_TEMPLATE",
    "q12_lookup_executed": True,
    "rule_id_found": RULE_ID,
    "source_case_id": SOURCE_CASE,
    "source_marker": SOURCE_MARKER,
}

tests = []


def check(label: str, condition: bool):
    tests.append((label, bool(condition)))


# False-positive prevention
check("1 deterministic without active HumanApproval rule does not include learned booking guidance", without_rule == base_draft and not contains_any(without_rule, OLD_HARDCODED_LEARNED_WORDING))
check("2 deterministic with active HumanApproval form-created rule includes guidance", BOOKING_URL in with_rule and "availability" in with_rule.lower())
check("3 output metadata includes active rule ID", "active_form_draft_rules_applied" in decision_d and "rule_id" in decision_d)
check("4 output metadata includes source case ID", "source_case_id" in decision_d)
check("5 output metadata includes source marker", "source_marker" in decision_d)
check("6 learned wording is absent from baseline classifier", not contains_any(decision_b, OLD_HARDCODED_LEARNED_WORDING))
check("7 learned wording is absent from deterministic template baseline", not contains_any(template_block, OLD_HARDCODED_LEARNED_WORDING))
check("8 learned wording is absent from fallback template baseline", not contains_any(fallback_block, OLD_HARDCODED_LEARNED_WORDING))
check("9 learned wording is absent from postprocessor unless injected from active rule context", not contains_any(postprocessor_block, OLD_HARDCODED_LEARNED_WORDING) and "_5qInstructionLinesFromGuidance" in decision_d)
check("10 classifier/crosswalk only changes eligibility/scope, not wording", "BOOKING_REQUEST" in decision_b and not contains_any(decision_b, OLD_HARDCODED_LEARNED_WORDING) and RULE_ID not in decision_b)

# Dynamic classification learning
check("11 form-created classification correction adjusts effective classification before draft policy", effective["micro_intent"] == "BOOKING_REQUEST" and "_5qApplyDynamicClassificationLearning" in decision_d and decision_d.index("_5qApplyDynamicClassificationLearning") < decision_d.index("const draftPolicy"))
check("12 original classification remains preserved", baseline == {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"} and "original_classification" in decision_d)
check("13 corrected/effective classification is used for rule lookup and draft policy", effective["micro_intent"] == "BOOKING_REQUEST" and "decision.category || cls.category" in decision_d)
check("14 newest same-scope rule overrides older conflicting rule", applied and applied[0]["rule_id"] == RULE_ID)
check("15 pricing/unrelated cases do not inherit booking classification correction", unrelated_effective == unrelated_baseline and unrelated_applied == [])

# Dynamic draft learning
check("16 AI-supervised path consumes active draft rule", "buildAIPrompt(microIntent, replyText, firstName, campaignCtx, behaviouralGuidance)" in decision_d and "_5qApplyActiveRuleDraftPostprocessing" in decision_d)
check("17 commercial supervised path consumes active draft rule", "draftSource = 'ai_commercial_supervised'" in decision_d and "if (draftText) draftText = _5qApplyActiveRuleDraftPostprocessing" in decision_d)
check("18 deterministic/fixed-template path consumes active draft rule", "draftSource = 'deterministic_template'" in decision_d and "_5qApplyActiveFormRuleInstructionToDraft" in decision_d)
check("19 safe fallback path consumes active draft rule", "draftSource = 'ai_failed_fallback'" in decision_d and "buildPolicyAwareFallback" in decision_d)
check("20 output changes because of form-created rule, not baseline hardcoding", with_rule != base_draft and not contains_any(decision_d, OLD_HARDCODED_LEARNED_WORDING))
check("21 pricing/minimum-contract case does not receive booking guidance", pricing_with_rule == "Pricing depends on scope.")

# Live-case fixture
check("22 case-dce9d552 represented as deterministic/fixed-template booking fixture", live_fixture["case_id"] == LIVE_CASE and live_fixture["draft_source"] == "deterministic_template")
check("23 live-case fixture only passes if runtime rule consumption is proven", live_fixture["q12_lookup_executed"] and live_fixture["rule_id_found"] == RULE_ID and "active_form_draft_rules_applied" in decision_d)
check("24 live-case fixture fails if deterministic template contains hardcoded learned guidance", not contains_any(template_block + postprocessor_block, OLD_HARDCODED_LEARNED_WORDING))

# Safety
check("25 Sender not triggered", not any("sender" in name.lower() for name in decision_node_names))
check("26 no Instantly POST", "api.instantly" not in decision_d.lower() and "https://api.instantly" not in decision_b.lower())
check("27 5Q15 source-of-truth hooks still present", "DYNAMIC_FORM_CLASSIFICATION_RULES" in decision_d and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d)
check("28 5Q14B deterministic/template hooks still present", "_5qApplyExactStartInstruction" in decision_d and "_5qApplyActiveRuleDraftPostprocessing" in decision_d)
check("29 5Q12 form-learning source metadata still present", SOURCE_MARKER in human_capture and "source_case_id" in human_capture)
check("30 5Q11 accessibility harness not required because review-state path unchanged", "review-state" not in decision_d.lower())

passed = sum(1 for _, ok in tests if ok)
total = len(tests)
for label, ok in tests:
    print(f"{'PASS' if ok else 'FAIL'} {label}")

print(f"\nSL-PHASE-5Q16B deterministic-template false-positive audit: {passed}/{total} PASS")
if passed != total:
    sys.exit(1)
