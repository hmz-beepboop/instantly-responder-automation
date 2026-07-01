#!/usr/bin/env python3
"""SL-PHASE-5Q11 review-link accessibility and corrected-classification harness.

Local-only static checks. This script does not call n8n, Instantly, Sender,
OpenAI, Google Chat, or any production webhook.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

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


human = load(HUMAN)
connections = human.get("connections", {})

h_get = code(human, "H. Validate Review Token (GET)")
h_post = code(human, "L. Validate & Consume Review Token (POST)")
render = code(human, "J. Render Review Form HTML")
decision = code(human, "N. Process Reviewer Decision")
capture = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")

print("== Review-link accessibility ==")
for status, label in [
    ("IN_REVIEW", "review link renders after Save"),
    ("BLOCKED_MISSING_VARIABLES", "review link renders after blocked send"),
    ("LEARNING_REVISION_APPROVED", "review link renders after Approved for learning only"),
    ("RESPONSE_APPROVED", "review link renders after Approve and send / sent-style state"),
    ("FOLLOWUP_SEND_CAPTURED", "review link renders after follow-up/send-again captured"),
    ("MANUAL_SEND_REQUIRED", "review link renders after manual-send-required"),
    ("FOLLOWUP_SEND_PENDING_MANUAL", "review link renders after pending manual follow-up"),
]:
    check(label, status in h_get and status in h_post and "REVIEW_LINK_RENDERABLE_STATUSES" in h_get and "REVIEW_LINK_RENDERABLE_STATUSES" in h_post)

check("approved/sent banner persists after blocked send", "_5q11SentStyleStatuses" in render and "_5q10PreviousStatus" in render and "This review was already approved and an email was already sent." in render)
check("approved/sent banner persists after learning-only", "LEARNING_REVISION_APPROVED" in render and "_5q11SentStyleStatuses" in render)
check("approved/sent banner persists after follow-up/send-again captured", "FOLLOWUP_SEND_PENDING_MANUAL" in render and "_5q11SentStyleStatuses" in render)
check("manual-send-required banner persists after follow-up/send-again captured", "Follow-up send captured" in render and "manual send required" in render and "controlled_send_key" in render)
check("blocked-attempt banner can appear without replacing sent/manual banners", "Previous submit was blocked; no new reply was sent." in render and render.find("Previous submit was blocked; no new reply was sent.") < render.find("This review was already approved and an email was already sent."))
check("same token remains stable until expiry", "row.token !== token" in h_get and "row.token_expires_at" in h_get and "generateReviewToken" not in decision)
check("unsafe duplicate send actions remain guarded", "Follow-up already captured" in render and "disabled" in render and "manual_send_required: true" in decision)
check("no duplicate Instantly POST is possible from render/reopen", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("J. Render Review Form HTML", {})) and "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("H. Validate Review Token (GET)", {})))

print("\n== Corrected classification learning target ==")
check("original classification is preserved for audit", "originalClassification" in capture and "old_category: origCategory" in capture and "old_micro_intent: origMicroIntent" in capture)
check("corrected/effective classification is stored", "correctedEffectiveClassification" in capture and "corrected_effective_classification" in capture)
check("\"this classification\" improvement uses corrected/effective classification", "effectiveDraftTargets" in capture and "value === origCategory" in capture and "value: effectCat" in capture and "value === origMicroIntent" in capture and "value: effectMi" in capture)
check("candidate/rule target classification equals corrected classification", "target_classification_used: correctedEffectiveClassification" in capture and "classification_scope: effectCat" in capture and "micro_intent_scope: effectMi" in capture)
check("candidate/rule does not incorrectly target original classification after correction", "draft_improvement_target_classifications: effectiveDraftTargets" in capture and "draft_improvement_target_classifications: (inp.submit_draft_improvement_target_classifications || [])" not in capture)
check("no correction means original classification is used", "const effectCat = corrCategory    || origCategory" in capture and "const effectMi  = corrMicroIntent || origMicroIntent" in capture)
check("scope persists and improvement-type dependency is removed", "draft_improvement_scopes" in capture and "draft_improvement_scope" in capture and "draft_revision_types:" not in capture)
check("newest same-scope corrected rule overrides older one", "policy_precedence_key" in capture and "supersedes_older_same_scope: true" in capture and "created_at: nowIso" in capture)
check("Decision-active policy metadata can distinguish original vs corrected classification if consumed", "original_classification" in capture and "corrected_effective_classification" in capture and "target_classification_used" in capture)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
