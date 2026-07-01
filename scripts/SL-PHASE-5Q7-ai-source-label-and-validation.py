#!/usr/bin/env python3
"""SL-PHASE-5Q7 AI source label and validation harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
OpenAI, Google Chat, or Sender.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

checks: list[tuple[str, bool]] = []


def check(name: str, ok: bool) -> None:
    checks.append((name, bool(ok)))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def node_code(workflow: dict, name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == name:
            return (node.get("parameters") or {}).get("jsCode") or ""
    raise AssertionError(f"node not found: {name}")


def synthetic_validate(text: str, guidance: str, prospect: str) -> list[str]:
    errors: list[str] = []
    forbidden = [
        (r"guarantee", "guarantee claim"),
        (r"\b(proven|proves|proof of|established|industry leader)\b", "proven/established claim"),
        (r"case stud", "case study claim"),
        (r"\$\s?\d", "price disclosure"),
        (r"\bresults?\b", "results claim"),
    ]
    for pattern, label in forbidden:
        if re.search(pattern, text, re.I):
            errors.append("forbidden: " + label)
    asks_proof = bool(re.search(r"\b(proof|prove|case stud|example|customer|result|roi|validation|maturity|evidence)\b", prospect, re.I))
    if re.search(r"do not mention validation|unless the prospect asks", guidance, re.I) and not asks_proof and re.search(r"\b(validation|validating|proof|case stud|public customer examples|customer examples|results?)\b", text, re.I):
        errors.append("active policy violation: validation/proof mention without prospect proof request")
    if re.search(r"short paragraphs|numbered|bulleted|list", guidance, re.I):
        paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
        dense = False
        for p in paras:
            lines = [line.strip() for line in p.split("\n") if line.strip()]
            has_list = any(re.search(r"^(?:[-*]|\d+[.)])\s+", line) for line in lines)
            max_line = max([len(line) for line in lines] or [0])
            if (has_list and (max_line > 260 or len(p) > 900)) or ((not has_list) and len(p) > 360):
                dense = True
        if dense:
            errors.append("active policy violation: dense paragraph")
    if re.search(r"Absolutely,\s*\.|Thanks,\s*\.|Hi,\s*\.|Hello,\s*\.", text, re.I):
        errors.append("active policy violation: malformed acknowledgement")
    return errors


decision = load(DECISION)
human = load(HUMAN)
decision_d = node_code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_d = node_code(human, "D. Build Google Chat Notification Payload")
human_j = node_code(human, "J. Render Review Form HTML")

print("== Source labels and banners ==")
check("accepted AI draft displays normal AI source in card/form", "Draft mode: AI-generated draft for human review" in human_d and "AI-generated draft for human review" in human_j)
check("accepted AI draft banner is accurate", "_p4aDS === 'ai_supervised'" in human_j and "AI-generated draft for human review. Edit before approving" in human_j)
check("validation-rejected AI draft displays fallback source in card/form", "Draft source:" in human_d and "Draft source:</strong>" in human_j and "ai_failed_fallback" in human_j)
check("validation-rejected fallback banner is accurate and not misleading", "Safe fallback draft for human review. AI draft was rejected by validation" in human_j and "AI-assisted draft for human review" not in human_j)
check("provider/config failure fallback banner is accurate and safe", "AI_PROVIDER_CONFIG_MISSING" in decision_d and "Safe fallback draft for human review" in human_j)
check("fallback reason category shown without secrets", "Fallback reason:" in human_j and "fallback_reason" in decision_d and "Authorization" not in human_j and "OPENAI_API_KEY" not in human_j)

print("\n== Fallback quality and learning policy ==")
check("fallback for INFORMATION_REQUEST/OFFER_EXPLANATION is policy-aware", "buildPolicyAwareFallback" in decision_d and "OFFER_EXPLANATION" in decision_d)
check("fallback uses active learning guidance", "behaviouralGuidance" in decision_d and "buildBehaviouralPolicyGuidance" in decision_d)
check("fallback answers setup before CTA", decision_d.find("The setup is about matching outbound") < decision_d.find("If useful, we can walk through"))
check("fallback avoids proof/case-study/customer-results unless asked", "do not mention validation" in decision_d and "We're at validation stage, so the next step" not in decision_d)
check("fallback avoids invented pricing/guarantee/contract claims", "guarantee claim" in decision_d and "price disclosure" in decision_d and "contract terms" in human_j)
check("fallback uses short paragraphs/list where suitable", "'1. Define the target accounts" in decision_d and "numbered or bulleted list" in decision_d)
check("normal AI drafts still use active learning guidance", "const prompt" in decision_d and "behaviouralGuidance" in decision_d)
check("newer learning override preserved", "newestByScope" in decision_d and "_5qPolicyTime" in decision_d)
check("unrelated pricing case does not leak setup-specific guidance", "microIntent === 'OFFER_EXPLANATION'" in decision_d and "AI_COMMERCIAL_SUPERVISED" in decision_d and "Pricing depends on scope" in decision_d)

print("\n== Validation strictness ==")
guidance = "For OFFER_EXPLANATION setup questions, answer the setup question in short paragraphs before any CTA and do not mention validation unless the prospect asks."
safe = """Absolutely, here is what setup would involve on our side:
1. We align on your target accounts, offer, and the capacity you want to keep available for outbound.
2. We map the outreach flow and define who should be contacted.
3. We set the handoff so replies reach the right person before any call.

If useful, we can walk through whether that fits your team on a short call."""
unsafe = "We have proven results, case studies, and a guarantee. Pricing starts at $500."
check("over-strict validation does not reject safe answer-before-CTA drafts", synthetic_validate(safe, guidance, "Can you explain setup?") == [])
check("unsafe proof/pricing/guarantee drafts are still rejected", len(synthetic_validate(unsafe, guidance, "Can you explain setup?")) >= 3)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
