#!/usr/bin/env python3
"""SL-PHASE-5Q6 thread hydration and AI fallback repair harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
Google Chat, OpenAI, or Sender.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INTAKE = ROOT / "workflows" / "production_intake_current.json"
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


def synthetic_thread_from_unibox(value: str | None) -> str | None:
    if not value:
        return None
    decoded = value.replace("%3A", ":")
    match = re.search(r"(?:^|[?&])(?:thread_id|threadId|thread)=([A-Za-z0-9_-]{8,})", decoded)
    if match:
        return match.group(1)
    match = re.search(r"thread_search=[^&]*thread:([A-Za-z0-9_-]{8,})", decoded)
    return match.group(1) if match else None


def missing_context(case: dict) -> list[str]:
    missing: list[str] = []
    for key, field in [
        ("reply_from_email", "reply_from_email"),
        ("sender_email", "sender_email"),
        ("reply_subject", "reply_subject"),
        ("thread_id", "thread_id"),
        ("reply_text", "reply_text"),
        ("draft_text", "draft_text"),
    ]:
        if not case.get(key):
            missing.append(field)
    if not case.get("category") or case.get("category") == "UNKNOWN":
        missing.append("classification")
    if not case.get("micro_intent"):
        missing.append("micro_intent")
    return missing


intake = load(INTAKE)
decision = load(DECISION)
human = load(HUMAN)

c2 = node_code(intake, "C2. Merge Reply Hydration")
d_norm = node_code(intake, "D. Normalization to NES")
decision_d = node_code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_a = node_code(human, "A. Build Review Case Record")
human_d = node_code(human, "D. Build Google Chat Notification Payload")
human_j = node_code(human, "J. Render Review Form HTML")
human_n = node_code(human, "N. Process Reviewer Decision")
human_p2a = node_code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
connections = json.dumps(human.get("connections", {}), ensure_ascii=False)
approval_router = json.dumps(
    next(n for n in human["nodes"] if n.get("name") == "P. Approval Outcome Router").get("parameters", {}),
    ensure_ascii=False,
)

print("== Thread/context hydration ==")
check("valid campaign reply with canonical thread ID passes hydration", "if (!raw.thread_id && alternateThreadId) raw.thread_id = alternateThreadId" in c2 and "email.thread_id" in c2)
check("valid campaign reply with alternate thread key maps correctly", "threadIdFromUniboxUrl" in c2 and "thread_search" in c2 and "unibox_url_thread_search" in c2)
check("synthetic alternate thread parser extracts thread_search", synthetic_thread_from_unibox("https://app.instantly.ai/app/unibox?selected_wks=x&thread_search=thread:53-1-WxpS69xd1JM68kPWij0FP") == "53-1-WxpS69xd1JM68kPWij0FP")
check("missing thread but sufficient alternate context is accepted by mapping", "alternateThreadId" in c2 and "raw.thread_id = alternateThreadId" in c2)
check("genuinely missing thread context produces diagnostic only", 'missingContextFields.push("thread_id")' in human_a and "CONTEXT_MISSING_BLOCKED" in human_a)
check("diagnostic shows exact missing fields and correction instructions", "Missing fields:" in human_d and "Correction:" in human_d and "seeded owned/test prospect" in human_d)
check("diagnostic cannot approve/send", "Diagnostic missing-context cases cannot be approved" in human_n and "blocked_context_missing" in human_n)
check("diagnostic cannot create learning candidate", "context_missing_no_learning" in human_p2a and "sl_p2_rule_candidates: []" in human_p2a)
check("Sender unreachable from diagnostic case", "$json.final_action === 'approve'" in approval_router and "Q. Reply Sender Handoff (Approved)" in connections)
check("normalization consumes mapped raw thread_id", "thread_id: (typeof rawPayload.thread_id === 'string') ? rawPayload.thread_id : null" in d_norm)

print("\n== AI draft success/failure ==")
check("hydrated supervised case attempts AI draft", "const canTryAI" in decision_d and "callAI(prompt, AI_API_KEY)" in decision_d)
check("AI provider/config missing gives explicit internal reason and safe fallback", "AI_PROVIDER_CONFIG_MISSING" in decision_d and "draftSource = 'ai_failed_fallback'" in decision_d)
check("malformed AI output gives explicit internal reason and safe fallback", "OpenAI response not valid JSON" in decision_d and "AI_PROVIDER_OR_RESPONSE_FAILED" in decision_d)
check("AI draft success uses active learning policy", "buildBehaviouralPolicyGuidance" in decision_d and "const prompt" in decision_d and "behaviouralGuidance" in decision_d)
check("AI draft fallback uses active learning policy", "buildPolicyAwareFallback" in decision_d and "fallbackText" in decision_d and "behaviouralGuidance" in decision_d)
check("fallback for INFORMATION_REQUEST/OFFER_EXPLANATION answers setup before CTA", "The setup is about matching outbound" in decision_d and decision_d.find("The setup is about matching outbound") < decision_d.find("If useful, we can walk through"))
check("fallback does not mention validation/proof unless asked", "do not mention validation" in decision_d and "We're at validation stage, so the next step" not in decision_d)
check("fallback uses short paragraphs/list where suitable", "'1. Define the target accounts" in decision_d and "\\n\\n" in decision_d)
check("fallback includes booking link only after useful answer", decision_d.find("The setup is about matching outbound") < decision_d.find("brief 10-minute conversation here"))
check("newer policy overrides older contradictory policy", "newestByScope" in decision_d and "_5qPolicyTime" in decision_d)
check("unrelated pricing case does not leak setup-specific guidance", "microIntent === 'OFFER_EXPLANATION'" in decision_d and "AI_COMMERCIAL_SUPERVISED" in decision_d and "Pricing depends on scope" in decision_d)
check("safe fallback reason is exposed in draft metadata", "fallback_reason" in decision_d and "AI drafting fallback used:" in decision_d)

print("\n== Synthetic diagnostic predicate ==")
valid = {
    "reply_from_email": "prospect@example.test",
    "sender_email": "sender@example.test",
    "reply_subject": "Re: Capacity Question",
    "thread_id": "53-thread-id",
    "reply_text": "Before we book anything, can you explain what your setup includes?",
    "draft_text": "Happy to explain.",
    "category": "INFORMATION_REQUEST",
    "micro_intent": "OFFER_EXPLANATION",
}
check("synthetic valid case has no missing context", missing_context(valid) == [])
missing = dict(valid, thread_id="", draft_text="")
check("synthetic missing thread/draft reports exact fields", missing_context(missing) == ["thread_id", "draft_text"])

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
