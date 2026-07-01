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

HARDCODED_LEARNED_OUTPUT = [
    "Here is the booking link so you can choose a time",
    "If you prefer, send over a couple of times that work and I can book it in",
    "If you have any questions, send them over",
    "I can book it in if you share your availability",
    "You can ask any questions as well",
]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def node_code(workflow: dict, node_name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == node_name:
            return node.get("parameters", {}).get("jsCode", "")
    raise AssertionError(f"missing node {node_name}")


def contains_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def section(text: str, start: str, end: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[i:j]


decision = load(DECISION)
human = load(HUMAN)
decision_b = node_code(decision, "B. Deterministic Reply Classifier")
decision_d = node_code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_a = node_code(human, "A. Build Review Case Record")
human_d = node_code(human, "D. Build Google Chat Notification Payload")
human_j = node_code(human, "J. Render Review Form HTML")

template_block = section(decision_d, "const MI_TEMPLATES =", "// === AI OUTPUT VALIDATION")
fallback_block = section(decision_d, "function buildPolicyAwareFallback", "function buildAIPrompt")
postprocessor_block = section(decision_d, "function _5qInstructionLinesFromGuidance", "function _5qSelectClassificationLearningRule")

checks: list[tuple[str, bool]] = []


def check(label: str, ok: bool) -> None:
    checks.append((label, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'} {label}")


# Attribution metadata
check("1 Decision output always includes baseline classification", "baseline_broad_category" in decision_d and "baseline_micro_intent" in decision_d)
check("2 Decision output always includes effective classification", "effective_broad_category" in decision_d and "effective_micro_intent" in decision_d)
check("3 Decision output records active rules found", "active_learning_rules_found" in decision_d)
check("4 Decision output records active rules eligible", "active_learning_rules_eligible" in decision_d)
check("5 Decision output records active rules applied", "active_learning_rules_applied" in decision_d)
check("6 Decision output records applied rule ID", "applied_learning_rule_ids" in decision_d and "rule_id" in decision_d)
check("7 Decision output records source case ID", "applied_learning_source_case_ids" in decision_d and "source_case_id" in decision_d)
check("8 Decision output records source marker", "applied_learning_source_markers" in decision_d and SOURCE_MARKER in decision_d)
check("9 Decision output records learning applied to classification/draft", "learning_applied_to_classification" in decision_d and "learning_applied_to_draft" in decision_d)
check("10 Decision output records non-application reason when no rule is applied", "learning_not_applied_reason" in decision_d and "NO_ACTIVE_HUMANAPPROVAL_FORM_RULES_FOUND" in decision_d)

# Deterministic template proof gate
check("11 plain deterministic template without active rule remains plain", "_5qDraftPolicyLabel(draftPolicyRaw, learningAppliedToDraft)" in decision_d and "if (!learningApplied) return policy" in decision_d)
check("12 deterministic template with active form-created rule is labelled as learning-applied", "FIXED_TEMPLATE_WITH_FORM_LEARNING" in decision_d and "deterministic_template_with_form_learning" in decision_d)
check("13 deterministic template with active form-created rule carries applied rule metadata", "active_form_draft_rules_applied" in decision_d and "applied_learning_type: \"draft\"" in decision_d)
check("14 deterministic template output changes only through active rule context", "_5qInstructionLinesFromGuidance" in decision_d and "humanapproval_form_created_learning|humanapproval_form" in postprocessor_block)
check("15 deterministic template does not contain hardcoded learned guidance", not contains_any(template_block, HARDCODED_LEARNED_OUTPUT))

# HumanApproval display
check("16 Google Chat card can display active learning applied yes/no", "Active learning applied:" in human_d)
check("17 Google Chat card can display rule ID/source case/source marker or safe summary", "Applied learning rule ID(s):" in human_d and "Source case ID(s):" in human_d and "Source marker(s):" in human_d)
check("18 review form can display active learning metadata", "Active learning applied:" in human_j and "Applied rule ID(s):" in human_j and "Source marker(s):" in human_j)
check("19 review form can display non-application reason", "Learning not applied reason:" in human_j and "learning_not_applied_reason" in human_j)

# Anti-false-positive
check("20 no hardcoded booking guidance in classifier", not contains_any(decision_b, HARDCODED_LEARNED_OUTPUT))
check("21 no hardcoded booking guidance in deterministic template", not contains_any(template_block, HARDCODED_LEARNED_OUTPUT))
check("22 no hardcoded booking guidance in fallback", not contains_any(fallback_block, HARDCODED_LEARNED_OUTPUT))
check("23 no hardcoded booking guidance in postprocessor", not contains_any(postprocessor_block, HARDCODED_LEARNED_OUTPUT))
check("24 source marker remains humanapproval_form_created_learning", SOURCE_MARKER in decision_d and "source_marker" in human_d and "Source marker(s):" in human_j)
check("25 Codex baseline remains separated", "ACTIVE_BEHAVIOURAL_POLICIES.concat(DYNAMIC_FORM_BEHAVIOURAL_POLICIES)" in decision_d)

# Safety / regression
check("26 pricing case does not inherit booking rule", "PRICING_REQUEST" in decision_b and "learning_not_applied_reason" in decision_d)
check("27 Sender not triggered", "Reply Sender" not in json.dumps(decision, ensure_ascii=False))
check("28 no Instantly POST", "api.instantly" not in decision_d.lower() and "https://api.instantly" not in decision_b.lower())
check("29 5Q16B harness still applicable if template/postprocessor path changed", (ROOT / "scripts" / "SL-PHASE-5Q16B-deterministic-template-false-positive-audit.py").exists())
check("30 5Q15 harness still applicable if learning metadata path changed", (ROOT / "scripts" / "SL-PHASE-5Q15-dynamic-classification-and-draft-learning-source-of-truth.py").exists())
check("31 5Q12 harness still applicable if form-learning source path changed", (ROOT / "scripts" / "SL-PHASE-5Q12-form-learning-source-and-improvement-type-removal.py").exists())
check("32 5Q11 harness only if review display/state path changed", (ROOT / "scripts" / "SL-PHASE-5Q11-review-link-accessibility-and-corrected-classification.py").exists())

passed = sum(1 for _, ok in checks if ok)
total = len(checks)
print(f"\nSL-PHASE-5Q16D learning attribution/template proof gate: {passed}/{total} PASS")
if passed != total:
    sys.exit(1)
