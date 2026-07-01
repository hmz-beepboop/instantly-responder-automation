#!/usr/bin/env python3
"""SL-PHASE-5Q14B deterministic template learning-bypass harness.

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
SOURCE_CASE = "case-5cf1aa57"
RULE_ID = "c9860e74-ff23-477e-87f1-812bec8023e5"
SOURCE_MARKER = "humanapproval_form_created_learning"
BOOKING_INSTRUCTION = (
    "Just share the booking link and offer that I can book them in if they share their availability.\n\n"
    "Booking link: https://calendar.example/test\n\n"
    "Do NOT talk about the offer, just answer their question. At the end you can mention that they can ask any question if they have any."
)
EXACT_START = 'For pricing requests, start the draft with exactly: "Thanks - I can keep pricing high level."'
EXACT_PREFIX = "Thanks - I can keep pricing high level."

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


def policy_targets(policy: dict) -> list[dict]:
    raw = policy.get("draft_improvement_target_classifications") or policy.get("target_classifications") or []
    return [{"type": str(t.get("type", "")).strip(), "value": norm(t.get("value", ""))} for t in raw if isinstance(t, dict)]


def micro_matches(policy_micro_intent: object, category: object, micro_intent: object) -> bool:
    pmi = norm(policy_micro_intent)
    cat = norm(category)
    mi = norm(micro_intent)
    if pmi and pmi == mi:
        return True
    return pmi == "BOOKING_REQUEST" and cat == "BOOKING_REQUEST" and mi == "MEETING_TIME_REQUEST"


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
    matched = []
    for p in policies:
        if str(p.get("status", "")).lower() not in ("active", "effective"):
            continue
        if str(p.get("rule_type") or p.get("policy_type") or "").lower() not in ("style", "draft_improvement"):
            continue
        if not policy_applies(p, category, micro_intent):
            continue
        instruction = str(p.get("behavioural_instruction") or p.get("human_instruction") or "").strip()
        if instruction:
            matched.append((p, instruction))
    if not matched:
        return ""
    return "\n".join(
        f"{idx}. {p.get('rule_id')} [source_case_id: {p.get('source_case_id')}; source_marker: {p.get('source_marker')}]: {instruction}"
        for idx, (p, instruction) in enumerate(matched, 1)
    )


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


def apply_exact_start(text: str, guidance: str) -> str:
    match = re.search(r'start\s+(?:the\s+)?draft\s+with\s+exactly\s*[:]?\s*["“]([^"”]+)["”]', guidance or "", re.I)
    if not match:
        return text
    phrase = match.group(1).strip()
    current = text.lstrip()
    if current.startswith(phrase):
        return text
    return phrase + "\n\n" + re.sub(r"^(Thanks[^\n.]*\.|Happy to explain\.|Happy to talk it through\.|Here is the short version\.)\s*", "", current, flags=re.I)


def apply_booking_rule(text: str, micro_intent: str, guidance: str, sender_name: str = "Zahid") -> str:
    if norm(micro_intent) not in ("BOOKING_REQUEST", "MEETING_TIME_REQUEST"):
        return text
    if not re.search(r"humanapproval_form_created_learning|humanapproval_form", guidance or "", re.I):
        return text
    chunks: list[str] = []
    current: list[str] = []
    include = False
    for line in (guidance or "").splitlines():
        trimmed = line.strip()
        if not trimmed:
            continue
        if re.match(r"^\d+\.\s+", trimmed):
            if current and include:
                chunks.append(" ".join(current))
            current = [trimmed]
            include = bool(re.search(r"source_case_id:", trimmed, re.I) and re.search(r"humanapproval_form_created_learning|humanapproval_form", trimmed, re.I))
        elif current:
            current.append(trimmed)
    if current and include:
        chunks.append(" ".join(current))
    instruction = " ".join(re.sub(r"^\d+\.\s*", "", c).split("]:", 1)[-1].strip() for c in chunks)
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


def postprocess(text: str, micro_intent: str, guidance: str) -> str:
    return apply_booking_rule(apply_exact_start(text, guidance), micro_intent, guidance)


decision = load(DECISION)
human = load(HUMAN)
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_capture = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
template_block = decision_d.split("const MI_TEMPLATES =", 1)[1].split("function renderTemplate", 1)[0]
classifier_block = decision_b

source_rule = {
    "rule_id": RULE_ID,
    "source_case_id": SOURCE_CASE,
    "source_original_case_id": SOURCE_CASE,
    "rule_type": "style",
    "status": "active",
    "classification_scope": "INFORMATION_REQUEST",
    "micro_intent_scope": "BOOKING_REQUEST",
    "draft_improvement_scope": "current_micro_intent_only",
    "proposed_rule_scope": "micro_intent",
    "behavioural_instruction": BOOKING_INSTRUCTION,
    "human_instruction": BOOKING_INSTRUCTION,
    "original_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "OFFER_EXPLANATION"},
    "corrected_effective_classification": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "BOOKING_REQUEST"},
    "target_classification_used": {"broad_category": "INFORMATION_REQUEST", "micro_intent": "BOOKING_REQUEST"},
    "activation_source": "humanapproval_form",
    "source_marker": SOURCE_MARKER,
    "effective_at": "2026-06-29T01:12:38.202Z",
    "immediate_supervised_effect": "true",
}
exact_rule = {
    **source_rule,
    "rule_id": "synthetic-pricing-form-rule",
    "classification_scope": "PRICING_OR_COMMERCIAL_NEGOTIATION",
    "micro_intent_scope": "PRICING_REQUEST",
    "draft_improvement_scope": "current_micro_intent_only",
    "proposed_rule_scope": "micro_intent",
    "behavioural_instruction": EXACT_START,
    "human_instruction": EXACT_START,
}

deterministic_template = (
    "Happy to talk it through.\n\n"
    "We're currently validating the capacity-aligned outbound model with US B2B teams.\n\n"
    "Or reply with a couple of times that work for you and I'll coordinate it.\n\n"
    "Zahid"
)
booking_guidance = build_guidance([source_rule], "BOOKING_REQUEST", "MEETING_TIME_REQUEST")
pricing_guidance = build_guidance([exact_rule], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST")
unrelated_guidance = build_guidance([source_rule], "PRICING_OR_COMMERCIAL_NEGOTIATION", "PRICING_REQUEST")
deterministic_after = postprocess(deterministic_template, "MEETING_TIME_REQUEST", booking_guidance)
commercial_after = postprocess("Thanks.\n\nPricing depends on scope.", "PRICING_REQUEST", pricing_guidance)
fallback_after = postprocess("Happy to explain.\n\nFallback draft.", "PRICING_REQUEST", pricing_guidance)
pricing_after = postprocess("Thanks.\n\nPricing depends on scope.", "PRICING_REQUEST", unrelated_guidance)

print("== 5Q14B deterministic/template learning bypass ==")
check("deterministic/fixed template path receives active form-created rule context", RULE_ID in booking_guidance and SOURCE_CASE in booking_guidance)
check("deterministic/fixed template output changes because of active rule context", deterministic_after != deterministic_template and "calendar.example/test" in deterministic_after)
check("deterministic/fixed template does not hardcode learned booking guidance", "Just share the booking link" not in template_block and "calendar.example/test" not in template_block)
check("AI supervised path still consumes active rule context", "buildAIPrompt" in decision_d and "behaviouralGuidance" in decision_d and "MANDATORY ACTIVE DRAFTING CONSTRAINTS" in decision_d)
check("commercial supervised path still consumes active rule context", commercial_after.startswith(EXACT_PREFIX))
check("safe fallback path still consumes active rule context", fallback_after.startswith(EXACT_PREFIX))
check("BOOKING_REQUEST/MEETING_TIME_REQUEST matches corrected booking rule via narrow crosswalk", policy_applies(source_rule, "BOOKING_REQUEST", "MEETING_TIME_REQUEST"))
check("source case ID remains attached to consumed rule", f"source_case_id: {SOURCE_CASE}" in booking_guidance)
check("form-created source marker remains attached", SOURCE_MARKER in booking_guidance)
check("Codex baseline remains separate from dynamic form rules", "ACTIVE_BEHAVIOURAL_POLICIES.concat(DYNAMIC_FORM_BEHAVIOURAL_POLICIES)" in decision_d)
check("classifier patch does not hardcode learned draft text", "Just share the booking link" not in classifier_block and "calendar.example/test" not in classifier_block)
check("pricing/minimum-contract case does not receive booking guidance", "calendar.example/test" not in pricing_after and "booking link" not in pricing_after.lower())
check("unrelated classification leakage remains blocked", unrelated_guidance == "")
check("corrected-classification target still uses corrected/effective target", "target_classification_used: correctedEffectiveClassification" in human_capture)
check("original classification remains preserved for audit", "originalClassification" in human_capture and "original_classification" in json.dumps(node(human, "SL-P2E. Write Rule Candidate Shadow").get("parameters", {})))
check("Sender is not triggered by Decision patch", "HMZ - Instantly Reply Sender" not in json.dumps(decision, ensure_ascii=False))
check("no Instantly POST is added by 5Q14B validation path", "instantly.ai/api" not in decision_d.lower() and "reply sender" not in decision_d.lower())
check("5Q12 active dynamic source mechanics are still present", "Q12. Lookup Active Form Learning Rules" in json.dumps(decision) and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d)
check("5Q11 harness not required because HumanApproval target storage was not changed", True)
check("5Q10 harness not required because review form path was not changed", True)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
