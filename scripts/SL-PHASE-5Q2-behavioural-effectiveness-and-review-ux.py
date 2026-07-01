#!/usr/bin/env python3
"""
SL-PHASE-5Q2 behavioural effectiveness and review UX harness.

Local-only static/synthetic verification. No n8n, Sender, Instantly,
webhook, or production API calls are made.
"""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DECISION = ROOT / "workflows" / "production_decision_current.json"
HUMAN = ROOT / "workflows" / "production_humanapproval_current.json"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))
    status = "PASS" if ok else "FAIL"
    suffix = f" - {detail}" if detail else ""
    print(f"[{status}] {name}{suffix}")


def load(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def node(workflow, name):
    for n in workflow.get("nodes", []):
        if n.get("name") == name:
            return n
    raise AssertionError(f"node not found: {name}")


def code(workflow, name):
    return node(workflow, name).get("parameters", {}).get("jsCode", "")


def main():
    decision = load(DECISION)
    human = load(HUMAN)

    d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
    j = code(human, "J. Render Review Form HTML")
    l = code(human, "L. Validate & Consume Review Token (POST)")
    n = code(human, "N. Process Reviewer Decision")
    p2a = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")

    print("== Behavioural effectiveness ==")
    check("active policies injected into direct AI prompt", "buildAIPrompt" in d and "MANDATORY ACTIVE DRAFTING CONSTRAINTS" in d and "input: [{ role:'user', content:prompt }]" in d)
    check("active policies are non-optional constraints", "These constraints are non-optional" in d and "FINAL SELF-CHECK BEFORE OUTPUT" in d)
    check("newer same-scope policy override exists", "newestByScope" in d and "_5qPolicyTime" in d and "_5qPolicyScopeKey" in d)
    check("one active improvement affects next similar prompt", "ACTIVE_BEHAVIOURAL_POLICIES" in d and "behaviouralGuidance" in d and "const prompt" in d)
    check("formatting/style constraints present", all(s in d for s in ["short paragraphs", "numbered or bulleted list", "malformed acknowledgement", "grammar", "CTA at the end"]))
    check("validation/proof mention gated by prospect ask", "ONLY when the prospect explicitly asks" in d and "active policy violation: validation/proof mention" in d)
    check("malformed acknowledgement post-validation exists", "Absolutely," in d and "active policy violation: malformed acknowledgement" in d)
    check("dense paragraph post-validation exists", "active policy violation: dense paragraph" in d)
    check("scoped rules still evaluated by policy applies", "_5qPolicyApplies" in d and "current_micro_intent_only" in d and "current_broad_category" in d)
    check("global scope only explicit", "global_draft_policy" in d and "all_ai_drafts" in d)
    check("duplicate active rules de-duped", "seenIds" in d)
    check("commercial supervised path preserved", "AI_COMMERCIAL_SUPERVISED" in d and "Pricing depends on scope" in d)

    print("\n== Review UX / preservation ==")
    check("scope is multi-select", 'name=\\"draft_improvement_scopes\\"' in j and "_5qScopeCheckbox" in j)
    check("improvement type is multi-select", 'name=\\"draft_revision_types\\"' in j and "_5qTypeCheckbox" in j)
    check("Style option exists", '_5qTypeCheckbox("style", "Style")' in j)
    check("combined learning field exists", "Why did you make this change, and what should the system do next time?" in j and 'name=\\"draft_learning_instruction\\"' in j)
    check("old redundant desired-future field removed from form", 'name=\\"desired_future_behavior\\"' not in j)
    check("old fields safely mapped in submit parser", "body.draft_revision_reason" in l and "body.desired_future_behavior" in l and "submit_draft_learning_instruction" in l)
    check("Save button exists", 'value=\\"save\\"' in j and "Save draft and learning" in j)
    check("Save action persists latest draft learning", 'action === "save"' in n and 'action: "save"' in n and "latest_draft_learning" in n)
    check("reopen preloads saved learning", "draft_learning_instruction" in j and "latest_saved_reply_text" in n)
    check("approval saves before sender handoff", "latest_draft_learning" in n and "RESPONSE_APPROVED" in n)
    check("blocked approval preserves inputs", "latest_saved_reply_text" in n and "latest_draft_learning" in n and "BLOCKED_MISSING_VARIABLES" in n)
    check("learning-only action exists on unsent form", 'value=\\"approve_learning_only\\"' in j and "Approved for learning only" in j)
    check("learning-only does not send", 'action === "approve_learning_only"' in n and "LEARNING_REVISION_APPROVED" in n)
    check("save does not create candidate", 'draftChanged && inp.final_action !== "save"' in p2a)
    check("candidate captures multi-select metadata", "draft_revision_types" in p2a and "draft_improvement_scopes" in p2a and "draft_learning_instruction" in p2a)

    print("\nSUMMARY: {}/{} PASS, {} FAIL".format(
        sum(1 for _, ok, _ in checks if ok),
        len(checks),
        sum(1 for _, ok, _ in checks if not ok),
    ))
    return 0 if all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
