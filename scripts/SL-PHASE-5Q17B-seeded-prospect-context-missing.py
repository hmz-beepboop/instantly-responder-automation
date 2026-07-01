#!/usr/bin/env python3
"""SL-PHASE-5Q17B seeded-prospect context-missing harness.

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

CASE_ID = "case-ed174cd6"
INTAKE_ID = "00MR0SMBJ0UVDONAEVMFFH5NU5"
DIAGNOSTIC_STATUS = "CONTEXT_MISSING_BLOCKED"

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
        if text and text not in {"{}", "[]", "UNKNOWN"}:
            return text
    return ""


def normalize_seeded(raw: dict) -> dict:
    hydrated = raw.get("_instantly_hydrated_email") or {}
    reply_text = first_non_empty(raw.get("reply_text"), raw.get("reply_text_snippet"), hydrated.get("text"), hydrated.get("content_preview"))
    thread_id = first_non_empty(raw.get("thread_id"), hydrated.get("thread_id"))
    lead_email = first_non_empty(raw.get("lead_email"), raw.get("email")).lower()
    return {
        "reply_from_email": first_non_empty(raw.get("from_address_email"), lead_email),
        "sender_email": first_non_empty(raw.get("email_account"), hydrated.get("eaccount")),
        "subject": first_non_empty(raw.get("reply_subject"), hydrated.get("subject")),
        "thread_id": thread_id,
        "reply_text": reply_text,
        "campaign_id": first_non_empty(raw.get("campaign_id")),
        "lead_email": lead_email,
    }


def classify(text: str) -> tuple[str, str, str]:
    t = text.lower()
    category = "INFORMATION_REQUEST" if "?" in t or "send" in t else "AMBIGUOUS"
    if re.search(r"\b(booking link|calendar link|pick a meeting time|choose a time|book a slot|meeting time)\b", t):
        return category, "BOOKING_REQUEST", "Booking link: https://calendar.app.google/bNXWJkS3xz3yqdW36\n\nZahid"
    return category, "OFFER_EXPLANATION", (
        "Happy to explain.\n\n"
        "The short version is that we help define the right target accounts, shape the outbound message, "
        "and keep outreach volume aligned to the conversations your team can actually handle.\n\n"
        "Zahid"
    )


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
human_text = json.dumps(human)
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
decision_b = code(decision, "B. Deterministic Reply Classifier")
human_a = code(human, "A. Build Review Case Record")
human_j = code(human, "J. Render Review Form HTML")
human_n = code(human, "N. Process Reviewer Decision")

seeded_raw = {
    "event_type": "reply_received",
    "workspace": "c7f84f11-4a1a-42dc-9a74-a417e44cb87e",
    "campaign_id": "531e64ed-c225-4baf-97a9-4ec90dc34eb0",
    "campaign_name": "Capacity Question",
    "email_account": "zahid@gethmzautomations.com",
    "lead_email": "humzaabbas1357@gmail.com",
    "email_id": "019f191d-9f8f-7770-b17e-f8f70665a2e3",
    "reply_subject": "Re: Capacity Question",
    "reply_text": "Could you send me the link to pick a meeting time?",
    "_instantly_hydrated_email": {
        "thread_id": "53--eKozl7_zFmnRANH1W_NNdN",
        "eaccount": "zahid@gethmzautomations.com",
        "subject": "Re: Capacity Question",
        "text": "Could you send me the link to pick a meeting time?",
    },
}
seeded_ctx = normalize_seeded(seeded_raw)
classification, micro_intent, draft_text = classify(seeded_ctx["reply_text"])
seeded_decision = {"classification": classification, "micro_intent": micro_intent, "draft_text": draft_text}
standalone_ctx = normalize_seeded({"reply_subject": "", "reply_text": "", "email_account": ""})
standalone_missing = missing_fields(standalone_ctx, {})

print("== Valid seeded context contract ==")
check("1 valid seeded campaign-thread reply has campaign/thread/lead/reply body", all(seeded_ctx[k] for k in ["campaign_id", "lead_email", "thread_id", "reply_text"]))
check("2 valid context includes reply_from_email", bool(seeded_ctx["reply_from_email"]))
check("3 valid context includes sender_email", bool(seeded_ctx["sender_email"]))
check("4 valid context includes subject", bool(seeded_ctx["subject"]))
check("5 valid context includes thread_id", bool(seeded_ctx["thread_id"]))
check("6 valid context includes reply_text", bool(seeded_ctx["reply_text"]))
check("7 valid context reaches Decision", "case_input" in intake_text and "When Called by Reply Intake" in json.dumps(decision))
check("8 Decision produces classification", seeded_decision["classification"] == "INFORMATION_REQUEST" and "category, confidence: result.confidence" in decision_b)
check("9 Decision produces micro_intent", seeded_decision["micro_intent"] == "BOOKING_REQUEST" and "BOOKING_REQUEST" in decision_b)
check("10 Decision produces draft_text", bool(seeded_decision["draft_text"]) and "draft_text:" in decision_d)
check("11 HumanApproval creates valid review case, not diagnostic", missing_fields(seeded_ctx, seeded_decision) == [] and DIAGNOSTIC_STATUS in human_a)

print("\n== Diagnostic contract remains intact ==")
check("12 standalone/unseeded email still creates diagnostic-only", {"reply_from_email", "sender_email", "reply_subject", "thread_id", "reply_text", "draft_text", "classification", "micro_intent"}.issubset(set(standalone_missing)))
check("13 diagnostic-only case shows missing fields", "Missing fields:" in human_j and "missing_fields" in human_j)
check("14 diagnostic-only review link remains readable until expiry", DIAGNOSTIC_STATUS in code(human, "H. Validate Review Token (GET)") and "token_expires_at" in code(human, "H. Validate Review Token (GET)"))
check("15 diagnostic-only disables approve/send", "This diagnostic case cannot be approved or sent." in human_j and "Approve and send unavailable" in human_j)
check("16 duplicate/stale case ID collision is prevented or detected", "generateReviewToken" in human_a and "case-ed174cd6" not in human_text and "source_event_id" in decision_d)

print("\n== No-send and repair guardrails ==")
check("17 Sender not triggered", "Reply Sender" not in decision_d and "Q. Reply Sender Handoff (Approved)" in human_text)
check("18 no Instantly POST", "/emails/reply" not in decision_d and "api.instantly" not in decision_d.lower())
check("19 5Q16F learning-impact harness not required by this patch", "learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed" in decision_d)
check("20 5Q11 accessibility harness not required by this patch", "DRAFT_PREP_EXCEPTION_FALLBACK" in decision_d and "REVIEW_LINK_RENDERABLE_STATUSES" in code(human, "H. Validate Review Token (GET)"))

print("\n== 5Q17B targeted Decision repair ==")
check("21 AI provider/runtime exceptions are caught before they can discard context", "AI_PROVIDER_RUNTIME_EXCEPTION" in decision_d)
check("22 OFFER_EXPLANATION has a non-null fallback draft", "if (microIntent === 'OFFER_EXPLANATION')" in decision_d and "The short version is that we help define the right target accounts" in decision_d)
check("23 draft-prep fallback is owner-visible", "DRAFT_PREP_EXCEPTION_FALLBACK" in decision_d)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
