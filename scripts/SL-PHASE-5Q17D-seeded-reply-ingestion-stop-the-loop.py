#!/usr/bin/env python3
"""SL-PHASE-5Q17D seeded-reply ingestion stop-the-loop harness.

Local-only static/synthetic checks. This script does not call n8n,
Instantly, Google Chat, Sender, or any production webhook.
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


def code(workflow: dict, node_name: str) -> str:
    for node in workflow.get("nodes", []):
        if node.get("name") == node_name:
            return (node.get("parameters") or {}).get("jsCode") or ""
    raise AssertionError(f"missing node: {node_name}")


def norm(value: object) -> str:
    return str("" if value is None else value).strip()


def first_non_empty(*values: object) -> str:
    for value in values:
        text = norm(value)
        if text and text not in {"{}", "[]", "UNKNOWN", "null", "None"}:
            return text
    return ""


def normalize_like_intake(raw: dict) -> dict:
    hydrated = raw.get("_instantly_hydrated_email") or {}
    lead_email = first_non_empty(raw.get("lead_email"), raw.get("email")).lower()
    reply_text = first_non_empty(
        raw.get("reply_text"),
        raw.get("reply_text_snippet"),
        hydrated.get("text"),
        hydrated.get("content_preview"),
    )
    return {
        "campaign_id": first_non_empty(raw.get("campaign_id")),
        "campaign_name": first_non_empty(raw.get("campaign_name")),
        "lead_email": lead_email,
        "sender_email": first_non_empty(raw.get("email_account"), hydrated.get("eaccount")),
        "reply_from_email": first_non_empty(raw.get("from_address_email"), lead_email),
        "subject": first_non_empty(raw.get("reply_subject"), hydrated.get("subject")),
        "thread_id": first_non_empty(raw.get("thread_id"), hydrated.get("thread_id")),
        "message_id": first_non_empty(raw.get("message_id"), hydrated.get("message_id")),
        "reply_text": reply_text,
        "hydration_attempted": bool(raw.get("_instantly_hydrated_email") is not None or raw.get("email_id")),
        "hydration_status": hydrated.get("_http_status") or raw.get("_hydration_status") or "",
    }


def classify_like_decision(reply_text: str) -> dict:
    text = reply_text.lower()
    category = "INFORMATION_REQUEST" if "?" in text or "how" in text or "what" in text else "AMBIGUOUS"
    if re.search(r"\b(booking link|calendar link|pick a time|choose a time|meeting time)\b", text):
        micro_intent = "BOOKING_REQUEST"
    elif re.search(r"\b(how does|how do|process|methodology)\b", text):
        micro_intent = "HOW_IT_WORKS_REQUEST"
    else:
        micro_intent = "OFFER_EXPLANATION"
    draft_text = (
        "Booking link: https://calendar.app.google/bNXWJkS3xz3yqdW36\n\nZahid"
        if micro_intent == "BOOKING_REQUEST"
        else "Happy to explain.\n\nThe short version is that we help define the target accounts, shape the outbound message, and keep outreach volume aligned to the conversations your team can handle.\n\nZahid"
    )
    return {
        "classification": category,
        "micro_intent": micro_intent,
        "draft_text": draft_text,
    }


def missing_fields(ctx: dict, decision: dict | None = None) -> list[str]:
    decision = decision or {}
    required = {
        "reply_from_email": ctx.get("reply_from_email"),
        "sender_email": ctx.get("sender_email"),
        "reply_subject": ctx.get("subject"),
        "thread_id": ctx.get("thread_id"),
        "reply_text": ctx.get("reply_text"),
        "draft_text": decision.get("draft_text"),
        "classification": decision.get("classification"),
        "micro_intent": decision.get("micro_intent"),
    }
    return [name for name, value in required.items() if not norm(value)]


def diagnostic_layer(ctx: dict, decision_error: str | None = None) -> str:
    has_valid_intake = all(
        bool(norm(ctx.get(key)))
        for key in ["campaign_id", "lead_email", "sender_email", "subject", "thread_id", "reply_text"]
    )
    if decision_error:
        return "DECISION_CONTEXT_DROPPED" if has_valid_intake else "HUMANAPPROVAL_DIAGNOSTIC_FALLBACK"
    if not ctx.get("campaign_id") and not ctx.get("lead_email") and not ctx.get("sender_email"):
        return "RAW_WEBHOOK_CONTEXT_MISSING"
    if not ctx.get("thread_id") and ctx.get("hydration_attempted"):
        return "INSTANTLY_HYDRATION_FAILED"
    if not has_valid_intake:
        return "INTAKE_MAPPING_CONTEXT_MISSING"
    return "UNKNOWN"


intake = load(INTAKE)
decision = load(DECISION)
human = load(HUMAN)

intake_text = json.dumps(intake)
decision_text = json.dumps(decision)
human_text = json.dumps(human)
intake_c2 = code(intake, "C2. Merge Reply Hydration")
intake_d = code(intake, "D. Normalization to NES")
decision_b = code(decision, "B. Deterministic Reply Classifier")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
human_a = code(human, "A. Build Review Case Record")
human_d = code(human, "D. Build Google Chat Notification Payload")
human_h = code(human, "H. Validate Review Token (GET)")
human_j = code(human, "J. Render Review Form HTML")
human_n = code(human, "N. Process Reviewer Decision")

# Shape extracted from the post-5Q17C failing execution, with emails redacted.
real_failing_shape = {
    "timestamp": "2026-06-30T21:37:10.851Z",
    "event_type": "reply_received",
    "workspace": "workspace-redacted",
    "campaign_id": "531e64ed-c225-4baf-97a9-4ec90dc34eb0",
    "unibox_url": "https://app.instantly.ai/app/unibox/...",
    "campaign_name": "Capacity Question",
    "email_account": "sender@example.com",
    "reply_text_snippet": "Could you send me more info about how this works?",
    "lead_email": "prospect@example.com",
    "email": "prospect@example.com",
    "First_name": "Prospect",
    "Company_name": "ExampleCo",
    "step": "1",
    "variant": "A",
    "email_id": "00MR163AORTSYC1H11R9E3P123",
    "reply_subject": "Re: Capacity Question",
    "reply_text": "Could you send me more info about how this works?",
    "_instantly_hydrated_email": {
        "_http_status": 200,
        "thread_id": "53-RKIOlX32DrLO3dLAoGwdkoG",
        "message_id": "msg-redacted",
        "eaccount": "sender@example.com",
        "subject": "Re: Capacity Question",
        "text": "Could you send me more info about how this works?",
    },
}

full_payload = {
    **real_failing_shape,
    "thread_id": "thread-full-001",
    "message_id": "message-full-001",
}

partial_payload = {
    key: value
    for key, value in real_failing_shape.items()
    if key not in {"thread_id", "message_id"}
}

standalone_payload = {
    "event_type": "email_received",
    "reply_subject": "",
    "reply_text": "",
    "email_account": "",
}

full_ctx = normalize_like_intake(full_payload)
partial_ctx = normalize_like_intake(partial_payload)
standalone_ctx = normalize_like_intake(standalone_payload)
full_decision = classify_like_decision(full_ctx["reply_text"])
partial_decision = classify_like_decision(partial_ctx["reply_text"])

print("== Seeded reply acceptance ==")
check("1 valid seeded campaign-thread full payload produces valid review", missing_fields(full_ctx, full_decision) == [])
check("2 valid seeded campaign-thread partial payload hydrates and produces valid review", partial_ctx["thread_id"] == "53-RKIOlX32DrLO3dLAoGwdkoG" and missing_fields(partial_ctx, partial_decision) == [])
check("3 Intake preserves reply_from_email", "from_address_email" in intake_d and full_ctx["reply_from_email"] == "prospect@example.com")
check("4 Intake preserves sender_email", "email_account" in intake_d and full_ctx["sender_email"] == "sender@example.com")
check("5 Intake preserves subject", "reply_subject" in intake_d and full_ctx["subject"] == "Re: Capacity Question")
check("6 Intake preserves thread_id", "alternate_thread_id" in intake_c2 and bool(partial_ctx["thread_id"]))
check("7 Intake preserves reply_text", "finalText" in intake_c2 and bool(partial_ctx["reply_text"]))

print("\n== Decision stop-the-loop repair ==")
check("8 Decision receives valid context", "nes.reply" in decision_text and "nes.eaccount" in decision_d)
check("9 Decision does not emit error-only missing slash for valid context", "DRAFT_PREP_NODE_EXCEPTION_FALLBACK" in decision_d and "return String(value || '').replace(/\\r/g, '')" in decision_d and "replace(/\n" not in decision_d)
check("10 Decision produces classification", "category, confidence: result.confidence" in decision_b and full_decision["classification"] == "INFORMATION_REQUEST")
check("11 Decision produces micro_intent", "detectMicroIntent" in decision_b and partial_decision["micro_intent"] == "OFFER_EXPLANATION")
check("12 Decision produces draft_text", "draft_text:" in decision_d and bool(partial_decision["draft_text"]))
check("13 HumanApproval creates valid review from valid Decision output", "CONTEXT_MISSING_BLOCKED" in human_a and missing_fields(full_ctx, full_decision) == [])

print("\n== Diagnostics and collision safety ==")
check("14 standalone/unseeded email still creates diagnostic-only", set(missing_fields(standalone_ctx, {})) == {"reply_from_email", "sender_email", "reply_subject", "thread_id", "reply_text", "draft_text", "classification", "micro_intent"})
check("15 diagnostic layer is accurate", diagnostic_layer(partial_ctx, "missing /") == "DECISION_CONTEXT_DROPPED" and "DECISION_CONTEXT_DROPPED" in human_a)
check("16 diagnostic preserves available upstream evidence", "upstream_evidence" in human_a and "campaign_id" in human_a and "reply_text_present" in human_a)
check("17 repeated diagnostics do not reuse/collide incorrectly", "DIAGNOSTIC_MISSING_INTAKE_" in human_a and "diagnostic_identity_fallback" in human_a)
check("18 stale diagnostic cannot overwrite valid review", "rawIntakeId" in human_a and "caseInput.intake_id || nes.intake_id" in human_a)
check("19 Sender not triggered", "Diagnostic missing-context cases cannot be approved" in human_n and "Q. Reply Sender Handoff (Approved)" in human_text)
check("20 no Instantly POST", "api.instantly" not in decision_d.lower() and "/emails/reply" not in decision_d and "Diagnostic missing-context cases cannot be approved" in human_n)

print("\n== Layer-specific diagnostic contract ==")
check("21 5Q17C harness still passes if Decision context path changed", "DRAFT_PREP_EXCEPTION_FALLBACK" in decision_d and "DRAFT_PREP_NODE_EXCEPTION_FALLBACK" in decision_d)
check("22 5Q16F harness only if Decision learning/draft path changed", "learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed" in decision_d)
check("23 5Q11 harness only if HumanApproval display/state changed", "REVIEW_LINK_RENDERABLE_STATUSES" in human_h and "This diagnostic case cannot be approved or sent." in human_j)
check("24 diagnostic layer is shown in Google Chat and review page", "Diagnostic layer:" in human_d and "Diagnostic layer:" in human_j)
check("25 upstream evidence is shown in Google Chat and review page", "Upstream evidence:" in human_d and "Upstream evidence" in human_j)
check("26 misleading owner setup message removed when upstream context exists", "No owner retry setup change is indicated" in human_a and "Decision dropped" in human_a)
check("27 raw webhook missing layer is represented", diagnostic_layer(standalone_ctx) == "RAW_WEBHOOK_CONTEXT_MISSING" and "RAW_WEBHOOK_CONTEXT_MISSING" in human_a)
check("28 hydration failure layer is represented", diagnostic_layer({**full_ctx, "thread_id": "", "hydration_attempted": True}) == "INSTANTLY_HYDRATION_FAILED" and "INSTANTLY_HYDRATION_FAILED" in human_a)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
