#!/usr/bin/env python3
"""SL-PHASE-5Q8 HumanApproval render regression harness.

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


def node(workflow: dict, name: str) -> dict:
    for candidate in workflow.get("nodes", []):
        if candidate.get("name") == name:
            return candidate
    raise AssertionError(f"node not found: {name}")


def synthetic_html(value: object) -> str:
    return (
        str("" if value is None else value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def has_unescaped_5q7_attribute_quotes(code: str) -> bool:
    risky = [
        'style="background:#fff3cd',
        'style="background:#d1ecf1',
        'name="edited_reply_text"',
        'id="hmzReplyText"',
        'rows="10"',
        'cols="80"',
    ]
    return any(fragment in code for fragment in risky)


human = load(HUMAN)
decision = load(DECISION)
human_j = node_code(human, "J. Render Review Form HTML")
human_h = node_code(human, "H. Validate Review Token (GET)")
human_slp2a = node_code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
decision_d = node_code(decision, "D. Draft Preparation (Templates / Human Draft)")
connections = human.get("connections", {})
workflow_text = json.dumps(human, ensure_ascii=False)
lookup_text = json.dumps(node(human, "H0. Lookup Case for Form (Data Table)"), ensure_ascii=False)

print("== Accepted AI render regression ==")
check("accepted AI-generated draft with ai_supervised source renders form branch", "_p4aDS === 'ai_supervised'" in human_j and "textarea" in human_j)
check("accepted AI-generated banner is accurate", "AI-generated draft for human review. Edit before approving" in human_j)
check("accepted AI source/mode fields are escaped before display", 'escapeHtml(_p4aDS || "N/A")' in human_j and "Draft source:</strong>" in human_j)
check("5Q7 banner HTML attributes are escaped in JavaScript strings", not has_unescaped_5q7_attribute_quotes(human_j))
check("AI draft text with punctuation/newlines/links is escaped in textarea", "escapeHtml(_5pLatestApprovedReply)" in human_j and 'name=\\"edited_reply_text\\"' in human_j)

print("\n== Fallback render branches ==")
check("safe fallback draft still renders with fallback banner/reason", "ai_failed_fallback" in human_j and "Safe fallback draft for human review" in human_j and "Fallback reason:" in human_j)
check("provider/config fallback still renders with safe reason", "AI_PROVIDER_CONFIG_MISSING" in decision_d and "AI_PROVIDER_OR_RESPONSE_FAILED" in decision_d and "fallback_reason" in decision_d)
check("fallback reason is rendered through escapeHtml", 'escapeHtml(_5q7FallbackReason)' in human_j)
check("human-only manual branch remains renderable", "No AI draft was generated because this reply requires human-only handling" in human_j)

print("\n== Token and missing-context safety ==")
check("unknown case ID is blocked safely", "query.case" in lookup_text and ("CASE_NOT_FOUND" in human_h or "UNKNOWN_ID" in human_h))
check("wrong token is blocked safely", "WRONG_TOKEN" in human_h and "token_valid" in human_h and "token_invalid_reason" in human_h)
check("missing-context diagnostic blocks approve/send", "_5q3MissingContext" in human_j and "Approve/send and learning-only actions are unavailable" in human_j)
check("diagnostic path returns before normal buttons", "_5q3MissingContext" in human_j and "return { json: { ...input, html } };" in human_j)

print("\n== Render side-effect safety ==")
check("render does not trigger Sender", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("J. Render Review Form HTML", {})))
check("render does not create learning candidate", "SL-P2A. Prepare Phase 1C+2 Capture Data" not in json.dumps(connections.get("J. Render Review Form HTML", {})))
check("candidate prep still suppresses diagnostic rows", "CONTEXT_MISSING_BLOCKED" in human_slp2a and "DIAGNOSTIC_CONTEXT_MISSING" in human_slp2a)

print("\n== Preserve prior review UX ==")
check("Save/reopen latest saved draft remains preferred", "latest_saved_reply_text || rc.final_reply_text || rc.draft_text" in human_j)
check("Save/reopen learning fields remain preloaded", "latest_draft_learning" in human_j and "draft_learning_instruction" in human_j)
check("learning UI remains preserved", "hmzDraftReasonSection" in human_j and "Why did you make this change" in human_j)
check("Save and learning-only controls remain preserved", 'value=\\"save\\"' in human_j and "approve_learning_only" in human_j)

print("\n== Escaping synthetic samples ==")
sample_source = 'ai_supervised"><script>alert(1)</script>'
sample_draft = 'Line 1\\nLine 2 with "quotes" and https://example.test/?a=1&b=<x>'
check("source/mode sample cannot inject HTML", "<script>" not in synthetic_html(sample_source) and "&lt;script&gt;" in synthetic_html(sample_source))
check("draft sample preserves newlines but escapes active characters", "&quot;quotes&quot;" in synthetic_html(sample_draft) and "&lt;x&gt;" in synthetic_html(sample_draft) and "&amp;b=" in synthetic_html(sample_draft))

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
