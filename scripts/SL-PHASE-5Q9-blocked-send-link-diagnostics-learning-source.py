#!/usr/bin/env python3
"""SL-PHASE-5Q9 blocked-send link and learning-source harness.

Local-only static/synthetic checks. This script does not call n8n, Instantly,
OpenAI, Google Chat, Sender, or any production webhook.
"""

from __future__ import annotations

import json
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


def node(workflow: dict, name: str) -> dict:
    for candidate in workflow.get("nodes", []):
        if candidate.get("name") == name:
            return candidate
    raise AssertionError(f"node not found: {name}")


def code(workflow: dict, name: str) -> str:
    return (node(workflow, name).get("parameters") or {}).get("jsCode") or ""


human = load(HUMAN)
decision = load(DECISION)
connections = human.get("connections", {})

h_get = code(human, "H. Validate Review Token (GET)")
h_post = code(human, "L. Validate & Consume Review Token (POST)")
n_decision = code(human, "N. Process Reviewer Decision")
q2 = code(human, "Q2. Build Non-Send Terminal Result")
r_gen = code(human, "R-GenToken. Generate Retry Token")
r3 = code(human, "R3. Build Retry Chat Message")
r5 = code(human, "R5. Build Retryable Result Page")
slp2a = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
r2_params = node(human, "R2. Update Case RETRY_NEEDED").get("parameters") or {}

print("== Blocked approve/send safety ==")
check("approve/send stores edited draft before blocked result", "latest_saved_reply_text: rc.final_reply_text" in n_decision)
check("approve/send stores learning before blocked result", "latest_draft_learning: latestDraftLearning" in n_decision)
check("missing variable name is preserved internally", "repeat_send_reason_required" in n_decision and "blocked_variables: missingVars" in n_decision)
check("owner-facing message names exact missing variable", "Exact missing variable(s):" in q2 and "missingVars.join" in q2)
check("owner-facing message gives exact correction steps", "Correction steps:" in q2 and "repeat_send_reason" in n_decision)
check("blocked send does not mark case sent", "sent: false" in n_decision and "prospect_received_reply: false" in n_decision)
check("blocked send does not mutate token", "token_preserved" in r_gen and "generateReviewToken" not in r_gen)
check("same review link remains accessible after missing-variable block", "BLOCKED_MISSING_VARIABLES" in h_get and "BLOCKED_MISSING_VARIABLES" in h_post)
check("case remains editable after missing-variable block", "rc.status = \"IN_REVIEW\"" in n_decision)
check("no broken new review link is generated", "New Review Link Sent" not in r5 and "New full production review link issued" not in r3)
check("duplicate blocked submit is idempotent", "new_token:            preservedToken" in r_gen and (r2_params.get("columns", {}).get("value", {}).get("status") == "IN_REVIEW"))
check("no duplicate Instantly POST on blocked path", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("Q2. Build Non-Send Terminal Result", {})))

print("\n== Learning capture before/without send ==")
check("learning-only creates candidate/rule from form fields", "if (draftChanged && inp.final_action !== \"save\")" in slp2a and "rule_type: \"style\"" in slp2a)
check("approve/send with learning fields saves/creates learning before send attempt", "SL-P2A. Prepare Phase 1C+2 Capture Data" in json.dumps(connections) and "P. Approval Outcome Router" in json.dumps(connections.get("SL-P2D. Route Main vs Rule Candidate", {})))
check("candidate/rule includes source case ID", "source_case_id: String(rc.case_id || \"\")" in slp2a and "source_original_case_id" in slp2a)
check("candidate/rule includes target classification/micro intent", "classification_scope: effectCat" in slp2a and "micro_intent_scope: effectMi" in slp2a)
check("candidate/rule includes improvement types", "draft_revision_types" in slp2a and "draft_revision_type" in slp2a)
check("Decision consumes active form-created rule payloads", "ACTIVE_BEHAVIOURAL_POLICIES" in decision_d and "source_case_id" in decision_d and "buildBehaviouralPolicyGuidance" in decision_d)
check("form-created rule affects AI draft prompt", "MANDATORY ACTIVE DRAFTING CONSTRAINTS" in decision_d and "buildAIPrompt" in decision_d)
check("form-created rule affects fallback draft", "buildPolicyAwareFallback" in decision_d and "behaviouralGuidance" in decision_d)
check("Codex baseline policy is distinguishable from human learning", "activation_source" in decision_d and "source_case_id" in decision_d)

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
