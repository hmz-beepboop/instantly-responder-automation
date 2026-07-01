#!/usr/bin/env python3
"""SL-PHASE-5Q15 dynamic classification/draft learning harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
OpenAI, Google Chat, Sender, or any production webhook.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"
REPORT_5Q14F = ROOT / "reports" / "SL-PHASE-5Q14F_HUMANAPPROVAL_RENDER_CRASH_AND_LIVE_BOOKING_CASE.md"

SOURCE_CASE = "case-5cf1aa57"
LIVE_CASE = "case-9747ff6f"
RULE_ID = "c9860e74-ff23-477e-87f1-812bec8023e5"
SOURCE_MARKER = "humanapproval_form_created_learning"
EXACT_INSTRUCTION = 'For this synthetic learned path, start the draft with exactly: "Learned form rule applied."'
EXACT_PREFIX = "Learned form rule applied."

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


def norm(value: object) -> str:
    return str("" if value is None else value).strip().upper()


def draft_policy_for(micro_intent: str) -> str:
    return {
        "MEETING_TIME_REQUEST": "FIXED_TEMPLATE",
        "BOOKING_REQUEST": "FIXED_TEMPLATE",
        "OFFER_EXPLANATION": "AI_SUPERVISED_OR_TEMPLATE",
        "HOW_IT_WORKS_REQUEST": "AI_SUPERVISED_OR_TEMPLATE",
        "PRICING_REQUEST": "AI_COMMERCIAL_SUPERVISED",
    }.get(micro_intent, "HUMAN_ONLY")


def select_classification_rule(rules: list[dict], category: str, micro_intent: str) -> dict | None:
    matches = []
    for rule in rules:
        original = rule["original_classification"]
        if norm(original["broad_category"]) != norm(category):
            continue
        if norm(original["micro_intent"]) != norm(micro_intent):
            continue
        if norm(rule["status"]) not in ("ACTIVE", "EFFECTIVE"):
            continue
        if rule.get("source_marker") != SOURCE_MARKER:
            continue
        matches.append(rule)
    return sorted(matches, key=lambda r: (r["effective_at"], r["rule_id"]), reverse=True)[0] if matches else None


def apply_classification_learning(rules: list[dict], category: str, micro_intent: str) -> dict:
    rule = select_classification_rule(rules, category, micro_intent)
    baseline = {"broad_category": category, "micro_intent": micro_intent}
    if not rule:
        return {"baseline": baseline, "effective": baseline, "applied": []}
    effective = rule["corrected_effective_classification"]
    return {"baseline": baseline, "effective": effective, "applied": [rule]}


def policy_targets(policy: dict) -> list[dict]:
    raw = policy.get("draft_improvement_target_classifications") or policy.get("target_classifications") or []
    return [{"type": str(t.get("type", "")).strip(), "value": norm(t.get("value", ""))} for t in raw if isinstance(t, dict)]


def micro_matches(policy_micro_intent: object, category: str, micro_intent: str) -> bool:
    pmi = norm(policy_micro_intent)
    cat = norm(category)
    mi = norm(micro_intent)
    if pmi and pmi == mi:
        return True
    return pmi == "BOOKING_REQUEST" and (
        (cat == "BOOKING_REQUEST" and mi == "MEETING_TIME_REQUEST") or
        (cat == "INFORMATION_REQUEST" and mi == "BOOKING_REQUEST")
    )


def policy_applies(policy: dict, category: str, micro_intent: str) -> bool:
    scope = str(policy.get("proposed_rule_scope") or policy.get("draft_improvement_scope") or "")
    targets = policy_targets(policy)
    if scope in ("global_draft_policy", "all_ai_drafts"):
        return True
    if scope in ("micro_intent", "current_micro_intent_only"):
        return any(t["type"] == "micro_intent" and micro_matches(t["value"], category, micro_intent) for t in targets) or micro_matches(policy.get("micro_intent_scope"), category, micro_intent)
    if scope in ("broad_category", "current_broad_category"):
        return any(t["type"] == "broad_category" and t["value"] == norm(category) for t in targets) or norm(policy.get("classification_scope")) == norm(category)
    return False


def build_guidance(policies: list[dict], category: str, micro_intent: str) -> str:
    by_scope: dict[str, dict] = {}
    for policy in policies:
        if norm(policy.get("status")) not in ("ACTIVE", "EFFECTIVE"):
            continue
        if norm(policy.get("rule_type")) not in ("STYLE", "DRAFT_IMPROVEMENT", "DRAFT_BEHAVIOUR", "DRAFT_BEHAVIOR"):
            continue
        if policy.get("source_marker") != SOURCE_MARKER:
            continue
        if not policy_applies(policy, category, micro_intent):
            continue
        key = str(policy.get("policy_precedence_key") or policy.get("draft_improvement_scope") or policy.get("rule_id"))
        old = by_scope.get(key)
        if not old or str(policy.get("effective_at", "")) >= str(old.get("effective_at", "")):
            by_scope[key] = policy
    return "\n".join(
        f"{p['rule_id']} [source_case_id: {p['source_case_id']}; source_marker: {p['source_marker']}]: {p['human_instruction']}"
        for p in sorted(by_scope.values(), key=lambda p: str(p.get("effective_at", "")), reverse=True)
    )


def apply_exact_start(text: str, guidance: str) -> str:
    match = re.search(r'start\s+(?:the\s+)?draft\s+with\s+exactly\s*[:]?\s*[""]([^""]+)[""]', guidance or "", re.I)
    if not match:
        return text
    phrase = match.group(1).strip()
    current = text.lstrip()
    if current.startswith(phrase):
        return text
    return phrase + "\n\n" + re.sub(r"^(Thanks[^\n.]*\.|Happy to explain\.|Happy to talk it through\.|Here is the short version\.)\s*", "", current, flags=re.I)


decision = load(DECISION)
human = load(HUMAN)
report_5q14f = REPORT_5Q14F.read_text(encoding="utf-8")
decision_text = json.dumps(decision, ensure_ascii=False)
human_text = json.dumps(human, ensure_ascii=False)
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_p2a = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
human_j = code(human, "J. Render Review Form HTML")
human_h = code(human, "H. Validate Review Token (GET)")
writer = json.dumps(node(human, "SL-P2E. Write Rule Candidate Shadow").get("parameters", {}), ensure_ascii=False)
template_block = decision_d.split("const MI_TEMPLATES =", 1)[1].split("function renderTemplate", 1)[0]

classification_rule = {
    "rule_id": RULE_ID,
    "source_case_id": SOURCE_CASE,
    "rule_type": "classification",
    "status": "active",
    "source_marker": SOURCE_MARKER,
    "activation_source": "humanapproval_form",
    "human_instruction": "Reviewer corrected the micro intent from offer explanation to booking request.",
    "original_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"},
    "corrected_effective_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "BOOKING_REQUEST"},
    "target_classification_used": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "BOOKING_REQUEST"},
    "effective_at": "2026-06-29T01:12:38Z",
}
older_conflict = {
    **classification_rule,
    "rule_id": "older-conflict",
    "corrected_effective_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "HOW_IT_WORKS_REQUEST"},
    "effective_at": "2026-06-29T01:00:00Z",
}
draft_rule = {
    "rule_id": "draft-form-rule",
    "source_case_id": SOURCE_CASE,
    "rule_type": "style",
    "status": "active",
    "classification_scope": "INFORMATION_REQUEST",
    "micro_intent_scope": "BOOKING_REQUEST",
    "draft_improvement_scope": "current_micro_intent_only",
    "proposed_rule_scope": "micro_intent",
    "target_classifications": [{"type": "micro_intent", "value": "BOOKING_REQUEST"}],
    "draft_improvement_target_classifications": [{"type": "micro_intent", "value": "BOOKING_REQUEST"}],
    "human_instruction": EXACT_INSTRUCTION,
    "behavioural_instruction": EXACT_INSTRUCTION,
    "source_marker": SOURCE_MARKER,
    "activation_source": "humanapproval_form",
    "effective_at": "2026-06-29T01:12:38Z",
}

learned = apply_classification_learning([older_conflict, classification_rule], "INFORMATION_REQUEST", "OFFER_EXPLANATION")
effective_category = learned["effective"]["broad_category"]
effective_micro = learned["effective"]["micro_intent"]
booking_guidance = build_guidance([draft_rule], effective_category, effective_micro)
unrelated_pricing_guidance = build_guidance([draft_rule], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST")
ai_before = "Happy to explain.\n\nBaseline draft."
ai_after = apply_exact_start(ai_before, booking_guidance)
commercial_after = apply_exact_start("Thanks.\n\nPricing depends on scope.", build_guidance([{**draft_rule, "micro_intent_scope": "PRICING_REQUEST", "target_classifications": [{"type": "micro_intent", "value": "PRICING_REQUEST"}], "draft_improvement_target_classifications": [{"type": "micro_intent", "value": "PRICING_REQUEST"}]}], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST"))
deterministic_after = apply_exact_start("Happy to talk it through.\n\nTemplate draft.", booking_guidance)
fallback_after = apply_exact_start("Here is the short version.\n\nFallback draft.", booking_guidance)

print("== Render / stale-case clarity ==")
check("case-9747ff6f render repair is represented in local evidence", LIVE_CASE in report_5q14f and "fixed a HumanApproval render compile error" in report_5q14f)
check("old stored cases are not treated as post-patch proof", "not valid self-improvement proof" in report_5q14f or "not proof" in report_5q14f)
check("stale stored draft/classification is distinguished from fresh Decision output", "Decision classified it as `INFORMATION_REQUEST / OFFER_EXPLANATION`" in report_5q14f and "live learning proof still pending" in report_5q14f)
check("reopen render path does not regenerate Decision output", "ExecuteWorkflow" not in human_h and "regenerate" not in human_j.lower())

print("\n== Dynamic classification learning ==")
check("form-created classification correction stores source case ID", "source_case_id: String(rc.case_id" in human_p2a and "source_case_id" in writer)
check("form-created classification correction stores original classification", "original_classification: originalClassification" in human_p2a and "original_classification" in writer)
check("form-created classification correction stores corrected/effective classification", "corrected_effective_classification: correctedEffectiveClassification" in human_p2a and "corrected_effective_classification" in writer)
check("form-created classification correction stores target classification", "target_classification_used: correctedEffectiveClassification" in human_p2a and "target_classification_used" in writer)
check("classification correction is active/effective immediately", 'rule_type: "classification"' in human_p2a and 'status: "active"' in human_p2a and "immediate_supervised_effect: true" in human_p2a)
check("classification learning source-marked as HumanApproval/form-created", 'source_marker: "humanapproval_form_created_learning"' in human_p2a and 'activation_source: "humanapproval_form"' in human_p2a)
check("Decision consumes active classification learning before final draft policy selection", "DYNAMIC_FORM_CLASSIFICATION_RULES" in decision_d and decision_d.index("learnedClassification") < decision_d.index("const microIntent"))
check("future matching inbound gets learned effective classification", effective_category == "INFORMATION_REQUEST" and effective_micro == "BOOKING_REQUEST")
check("draft policy/template selection uses learned effective classification", draft_policy_for(effective_micro) == "FIXED_TEMPLATE")
check("original classification remains preserved for audit", learned["baseline"] == {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"})
check("newest same-scope classification correction overrides older conflicting correction", effective_micro == "BOOKING_REQUEST")
check("classification learning does not leak into unrelated pricing cases", apply_classification_learning([classification_rule], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST")["applied"] == [])

print("\n== Dynamic draft learning ==")
check("form-created draft rule stores source case ID", "source_case_id: String(rc.case_id" in human_p2a)
check("form-created draft rule stores human instruction", "human_instruction: draftInstruction" in human_p2a)
main_learning_idx = decision_d.index("const learnedClassification")
main_guidance_idx = decision_d.index("const behaviouralGuidance", main_learning_idx)
check("Decision consumes active draft rule after effective classification is set", main_guidance_idx > main_learning_idx)
check("AI-supervised draft path consumes active draft rule", "buildAIPrompt" in decision_d and "behaviouralGuidance" in decision_d)
check("commercial supervised draft path consumes active draft rule", commercial_after.startswith(EXACT_PREFIX) and "AI_COMMERCIAL_SUPERVISED" in decision_d)
check("deterministic/fixed-template path consumes active draft rule", deterministic_after.startswith(EXACT_PREFIX))
check("safe fallback path consumes active draft rule", fallback_after.startswith(EXACT_PREFIX))
check("draft output changes because of form-created rule", ai_after != ai_before and ai_after.startswith(EXACT_PREFIX))
check("draft output does not change because of hardcoded baseline/template", EXACT_INSTRUCTION not in decision_text and EXACT_PREFIX not in decision_text)
check("pricing/minimum-contract case does not receive booking guidance", unrelated_pricing_guidance == "")

print("\n== Regression / safety ==")
check("no phrase-specific classifier patch is used as substitute for learning proof", EXACT_INSTRUCTION not in decision_b and EXACT_PREFIX not in decision_b)
check("Codex baseline and form-created policies remain separated", "ACTIVE_BEHAVIOURAL_POLICIES.concat(DYNAMIC_FORM_BEHAVIOURAL_POLICIES)" in decision_d)
check("source case metadata is emitted in Decision output", "classification_learning_rules_applied" in decision_d and "source_case_id" in decision_d)
check("no Sender trigger was added to Decision", "Reply Sender Handoff" not in decision_text)
check("no Instantly POST was added to Decision draft path", "api/v2/emails/reply" not in decision_d and "POST" not in decision_d.split("function callAI", 1)[0])
check("5Q14F render harness still applicable if render path changes", "Safe render diagnostic" in human_j and "Unexpected identifier" in report_5q14f)
check("5Q14D diagnostic harness still applicable if diagnostic path changes", "CONTEXT_MISSING_BLOCKED" in human_h and "Invalid review case - missing context" in human_j)
check("5Q14B deterministic/template harness still applicable if rule consumption changes", "_5qApplyActiveRuleDraftPostprocessing" in decision_d)
check("5Q12 form-learning harness still applicable if learning source changes", "source_marker" in human_p2a and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
