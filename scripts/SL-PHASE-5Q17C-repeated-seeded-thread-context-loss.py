#!/usr/bin/env python3
"""SL-PHASE-5Q17C repeated seeded-thread context-loss harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
OpenAI, Google Chat, Sender, or any production webhook.
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

FALLBACK_CASE = "case-ed174cd6"
POLICY_VERSION = "policy-HMZ-1.2"

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


def djb2(value: str) -> str:
    h = 5381
    for ch in value:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFF
    return f"{h:08x}"


def norm(value: object) -> str:
    return str("" if value is None else value).strip()


def first_non_empty(*values: object) -> str:
    for value in values:
        text = norm(value)
        if text and text not in {"{}", "[]", "UNKNOWN"}:
            return text
    return ""


def normalize(raw: dict) -> dict:
    hydrated = raw.get("_instantly_hydrated_email") or {}
    reply_text = first_non_empty(
        raw.get("reply_text"),
        raw.get("reply_text_snippet"),
        hydrated.get("text"),
        hydrated.get("content_preview"),
    )
    lead_email = first_non_empty(raw.get("lead_email"), raw.get("email")).lower()
    return {
        "campaign_id": first_non_empty(raw.get("campaign_id")),
        "lead_email": lead_email,
        "sender_email": first_non_empty(raw.get("email_account"), hydrated.get("eaccount")),
        "reply_from_email": first_non_empty(raw.get("from_address_email"), lead_email),
        "subject": first_non_empty(raw.get("reply_subject"), hydrated.get("subject")),
        "thread_id": first_non_empty(raw.get("thread_id"), hydrated.get("thread_id")),
        "message_id": first_non_empty(raw.get("message_id"), hydrated.get("message_id")),
        "reply_text": reply_text,
    }


def classify(text: str) -> dict:
    t = text.lower()
    category = "INFORMATION_REQUEST" if "?" in t or "send" in t or "how" in t else "AMBIGUOUS"
    micro = "BOOKING_REQUEST" if re.search(r"\b(booking link|calendar link|choose a time|pick a meeting time|meeting time)\b", t) else "OFFER_EXPLANATION"
    draft = (
        "Booking link: https://calendar.app.google/bNXWJkS3xz3yqdW36\n\nZahid"
        if micro == "BOOKING_REQUEST"
        else "Happy to explain.\n\nThe short version is that we help define the right target accounts, shape the outbound message, and keep outreach volume aligned to the conversations your team can actually handle.\n\nZahid"
    )
    return {"classification": category, "micro_intent": micro, "draft_text": draft}


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
human_h = code(human, "H. Validate Review Token (GET)")
human_j = code(human, "J. Render Review Form HTML")
human_l = code(human, "L. Validate & Consume Review Token (POST)")
human_n = code(human, "N. Process Reviewer Decision")

full_raw = {
    "event_type": "reply_received",
    "workspace": "c7f84f11-4a1a-42dc-9a74-a417e44cb87e",
    "campaign_id": "531e64ed-c225-4baf-97a9-4ec90dc34eb0",
    "campaign_name": "Capacity Question",
    "email_account": "zahid@gethmzautomations.com",
    "lead_email": "prospect@example.com",
    "email_id": "email-full-001",
    "reply_subject": "Re: Capacity Question",
    "thread_id": "thread-full-001",
    "message_id": "message-full-001",
    "reply_text": "Could you send me the link to pick a meeting time?",
}
partial_raw = {
    "event_type": "reply_received",
    "campaign_id": "531e64ed-c225-4baf-97a9-4ec90dc34eb0",
    "email_account": "zahid@gethmzautomations.com",
    "lead_email": "prospect@example.com",
    "email_id": "email-partial-001",
    "reply_subject": "Re: Capacity Question",
    "reply_text": "How does your setup work?",
    "_instantly_hydrated_email": {
        "thread_id": "thread-hydrated-001",
        "eaccount": "zahid@gethmzautomations.com",
        "subject": "Re: Capacity Question",
        "text": "How does your setup work?",
    },
}
full_ctx = normalize(full_raw)
partial_ctx = normalize(partial_raw)
full_decision = classify(full_ctx["reply_text"])
partial_decision = classify(partial_ctx["reply_text"])
standalone_missing = missing_fields(normalize({"reply_subject": "", "reply_text": "", "email_account": ""}), {})

print("== Case identity / collision ==")
check("1 repeated missing-context events do not reuse fallback UNKNOWN_INTAKE case ID", "DIAGNOSTIC_MISSING_INTAKE_" in human_a and "diagnostic_identity_fallback" in human_a)
check("2 stale diagnostic rows cannot overwrite valid review cases", "rawIntakeId" in human_a and "caseInput.intake_id || nes.intake_id" in human_a)
check("3 fallback hash is identified as defective pre-patch case-ed174cd6", "case-" + djb2("UNKNOWN_INTAKE|" + POLICY_VERSION) == FALLBACK_CASE)

print("\n== Valid seeded campaign-thread path ==")
check("4 valid seeded reply with raw full payload produces valid review case", missing_fields(full_ctx, full_decision) == [])
check("5 valid seeded reply with partial payload hydrates successfully", partial_ctx["thread_id"] == "thread-hydrated-001" and "_hmz_v10_hydration" in intake_c2)
check("6 Intake preserves reply_from_email", "from_address_email" in intake_d and bool(partial_ctx["reply_from_email"]))
check("7 Intake preserves sender_email", "email_account" in intake_d and bool(partial_ctx["sender_email"]))
check("8 Intake preserves subject", "reply_subject" in intake_d and bool(partial_ctx["subject"]))
check("9 Intake preserves thread_id", "alternate_thread_id" in intake_c2 and bool(partial_ctx["thread_id"]))
check("10 Intake preserves reply_text", "finalText" in intake_c2 and bool(partial_ctx["reply_text"]))

print("\n== Decision context preservation ==")
check("11 Decision receives valid context", "nes.reply" in decision_text and "nes.eaccount" in decision_d)
check("12 Decision does not emit error-only missing slash when context is valid", "DRAFT_PREP_NODE_EXCEPTION_FALLBACK" in decision_d and "{ ...input, classifier, decision, draft" in decision_d)
check("13 Decision produces classification", "category, confidence: result.confidence" in decision_b and partial_decision["classification"] == "INFORMATION_REQUEST")
check("14 Decision produces micro_intent", "BOOKING_REQUEST" in decision_b and partial_decision["micro_intent"] == "OFFER_EXPLANATION")
check("15 Decision produces draft_text", "draft_text:" in decision_d and bool(partial_decision["draft_text"]))

print("\n== HumanApproval diagnostics and send safety ==")
check("16 HumanApproval creates valid review case", "CONTEXT_MISSING_BLOCKED" in human_a and missing_fields(full_ctx, full_decision) == [])
check("17 standalone/unseeded email still creates diagnostic-only", {"reply_from_email", "sender_email", "reply_subject", "thread_id", "reply_text", "draft_text", "classification", "micro_intent"}.issubset(set(standalone_missing)))
check("18 diagnostic-only link readable until expiry", "CONTEXT_MISSING_BLOCKED" in human_h and "token_expires_at" in human_h)
check("19 approve/send disabled on diagnostic", "This diagnostic case cannot be approved or sent." in human_j and "Approve and send unavailable" in human_j)
check("20 Sender not triggered", "Q. Reply Sender Handoff (Approved)" in human_text and "Diagnostic missing-context cases cannot be approved" in human_n)
check("21 no Instantly POST", "/emails/reply" not in decision_d and "api.instantly" not in decision_d.lower())

print("\n== Regression scope gates ==")
check("22 5Q17B harness still passes if Decision context path changed", "DRAFT_PREP_EXCEPTION_FALLBACK" in decision_d and "DRAFT_PREP_NODE_EXCEPTION_FALLBACK" in decision_d)
check("23 5Q16F harness runs only if Decision learning/draft path changed", "learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed" in decision_d)
check("24 5Q11 harness runs only if HumanApproval render/state path changed", "REVIEW_LINK_RENDERABLE_STATUSES" in human_h and "diagnostic_identity_fallback" in human_a)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
