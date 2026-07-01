#!/usr/bin/env python3
"""SL-PHASE-5Q14F HumanApproval render-crash and live booking-case harness.

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

SOURCE_CASE = "case-5cf1aa57"
RULE_ID = "c9860e74-ff23-477e-87f1-812bec8023e5"
SOURCE_MARKER = "humanapproval_form_created_learning"
LIVE_REPLY = "Where can I grab a time on your calendar?"
LEARNED_BOOKING_PHRASE = "Just share the booking link"
LEARNED_TEST_URL = "calendar.example/test"

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


def no_unescaped_attribute_quotes(js: str) -> bool:
    risky = [
        'html += "<div style="',
        'html += "<button type="',
        'html += "<input type="',
        'html += "<textarea name="',
    ]
    return not any(fragment in js for fragment in risky)


def norm(value: object) -> str:
    return str("" if value is None else value).strip().upper()


def booking_regex_matches_live_case(decision_b: str) -> bool:
    if "grab (a )?(time|slot)" not in decision_b or "time on (your|the) calendar" not in decision_b:
        return False
    local_equivalent = re.compile(
        r"\b(booking link|calendar link|calendly|choose a time|pick a time|grab (a )?(time|slot)|"
        r"time on (your|the) calendar|slot on (your|the) calendar|your calendar|"
        r"book (a )?(time|slot|call)|schedule (a )?(time|call)|"
        r"send (me )?(the )?(booking|calendar) link|share (the )?(booking|calendar) link|"
        r"your availability|available times|time options)\b"
    )
    return local_equivalent.search(LIVE_REPLY.lower()) is not None


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
connections = human.get("connections", {})
render = code(human, "J. Render Review Form HTML")
get_gate = code(human, "H. Validate Review Token (GET)")
post_gate = code(human, "L. Validate & Consume Review Token (POST)")
process = code(human, "N. Process Reviewer Decision")
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
decision_text = json.dumps(decision, ensure_ascii=False)
human_text = json.dumps(human, ensure_ascii=False)

get_renderable = extract_status_list(get_gate, "REVIEW_LINK_RENDERABLE_STATUSES")

print("== HumanApproval render crash repair ==")
check("valid AI-supervised booking/calendar case render does not throw compile-risk syntax", no_unescaped_attribute_quotes(render) and "Unexpected identifier" not in render)
check("valid AI-supervised review page includes case ID", "<h1>Reply review - " in render and "escapeHtml(rc.case_id)" in render)
check("valid AI-supervised review page includes draft text", 'name=\\"edited_reply_text\\"' in render and "_5q10EscapedReplyTextForForm" in render)
check("valid AI-supervised review page includes learning fields", "draft_learning_instruction" in render and "draft_improvement_scopes" in render and "draft_improvement_target_classifications" in render)
check("valid AI-supervised review page includes current classification/micro intent", "Broad category:" in render and "Micro intent:" in render and "p1cMi" in render)
check("HumanApproval Node J safely escapes dynamic strings", "function escapeHtml" in render and "escapeHtml(rc.case_id)" in render and "escapeHtml(ctx.reply_text)" in render and "escapeHtml(_5q10ReplyTextForForm)" in render)
check("malformed optional metadata renders safe diagnostic block instead of blank page", "Safe render diagnostic" in render and "Array.isArray(ctx.risk_flags)" in render and "Array.isArray(_p4aIntentsRaw)" in render)
check("UNKNOWN_ID is not emitted for valid token/case render path", "UNKNOWN_ID" not in render and "token_valid" in get_gate and "CASE_NOT_FOUND" in get_gate)

print("\n== Link-state regressions ==")
check("diagnostic-only links still render until expiry", "CONTEXT_MISSING_BLOCKED" in get_renderable and "DIAGNOSTIC_CONTEXT_MISSING" in render)
check("expired token still blocks correctly", "EXPIRED" in get_gate and "EXPIRED" in post_gate and "This review link has expired" in code(human, "J2. Render Token Error Page"))
check("5Q11 review-link accessibility state set is preserved", {"IN_REVIEW", "BLOCKED_MISSING_VARIABLES", "LEARNING_REVISION_APPROVED", "RESPONSE_APPROVED", "RESPONSE_SENT", "FOLLOWUP_SEND_PENDING_MANUAL", "MANUAL_SEND_REQUIRED"}.issubset(set(get_renderable)))
check("5Q14D diagnostic-link contract is preserved", "No reply was sent." in render and "This diagnostic case cannot be approved or sent." in render and "Correction instructions:" in render)

print("\n== Booking classification and learning eligibility ==")
check("live booking/calendar wording is recognized by narrow booking classifier", booking_regex_matches_live_case(decision_b))
check("Decision maps recognized booking micro-intent to fixed-template path", "BOOKING_REQUEST:           'FIXED_TEMPLATE'" in decision_b)
check("5Q14B active booking crosswalk still covers current taxonomies", booking_crosswalk("BOOKING_REQUEST", "INFORMATION_REQUEST", "BOOKING_REQUEST") and booking_crosswalk("BOOKING_REQUEST", "BOOKING_REQUEST", "MEETING_TIME_REQUEST") and "INFORMATION_REQUEST' && mi === 'BOOKING_REQUEST" in decision_d)
check("5Q12 dynamic form-learning mechanics remain present", "Q12. Lookup Active Form Learning Rules" in decision_text and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d and SOURCE_MARKER in decision_d)

print("\n== Anti-false-positive and send safety ==")
baseline_block = decision_d.split("const ACTIVE_BEHAVIOURAL_POLICIES =", 1)[1].split("const MI_TEMPLATES =", 1)[0]
template_block = decision_d.split("const MI_TEMPLATES =", 1)[1].split("function renderTemplate", 1)[0]
check("booking guidance is not hardcoded in baseline", LEARNED_BOOKING_PHRASE not in baseline_block and LEARNED_TEST_URL not in baseline_block)
check("booking guidance is not hardcoded in classifier", LEARNED_BOOKING_PHRASE not in decision_b and LEARNED_TEST_URL not in decision_b)
check("booking guidance is not hardcoded in deterministic template", LEARNED_BOOKING_PHRASE not in template_block and LEARNED_TEST_URL not in template_block)
check("form-created rule source remains distinguishable", SOURCE_MARKER in decision_d and "ACTIVE_BEHAVIOURAL_POLICIES.concat(DYNAMIC_FORM_BEHAVIOURAL_POLICIES)" in decision_d)
check("Sender is not triggered by render", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("J. Render Review Form HTML", {})) and "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("H. Validate Review Token (GET)", {})))
changed_nodes = render + get_gate + post_gate + process + decision_b + decision_d
check("no Instantly POST occurs in changed nodes", "/emails/reply" not in changed_nodes and "reply_to_email" not in changed_nodes)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
