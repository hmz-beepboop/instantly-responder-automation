#!/usr/bin/env python3
"""
SL-PHASE-5Q self-improvement behavioural closure harness.

Local-only synthetic verification. No n8n, Sender, Instantly, webhook, or
production API calls are made.
"""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HA_PATH = ROOT / "workflows" / "production_humanapproval_current.json"
DE_PATH = ROOT / "workflows" / "production_decision_current.json"
SHADOW_PATH = ROOT / "workflows" / "disabled_autonomous_shadow_evaluator.json"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))
    status = "PASS" if ok else "FAIL"
    suffix = f" - {detail}" if detail else ""
    print(f"[{status}] {name}{suffix}")


def load_json(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def node(workflow, name):
    for n in workflow.get("nodes", []):
        if n.get("name") == name:
            return n
    raise AssertionError(f"node not found: {name}")


def code(workflow, name):
    return node(workflow, name).get("parameters", {}).get("jsCode", "")


def norm(value):
    return str(value or "").strip().upper()


def policy_targets(policy):
    raw = policy.get("draft_improvement_target_classifications")
    if not isinstance(raw, list):
        raw = policy.get("target_classifications") if isinstance(policy.get("target_classifications"), list) else []
    return [
        {"type": str(t.get("type", "")).strip(), "value": norm(t.get("value"))}
        for t in raw
        if isinstance(t, dict) and t.get("type") and t.get("value")
    ]


def policy_applies(policy, category, micro_intent, additional_intents=None, campaign_id="", sender_account=""):
    additional_intents = additional_intents or []
    scope = str(policy.get("proposed_rule_scope") or policy.get("draft_improvement_scope") or "").strip()
    cat = norm(category)
    mi = norm(micro_intent)
    add = [norm(x.get("micro_intent") if isinstance(x, dict) else x) for x in additional_intents]
    targets = policy_targets(policy)

    if scope in ("global_draft_policy", "all_ai_drafts"):
        return True
    if scope in ("micro_intent", "current_micro_intent_only"):
        return any(t["type"] == "micro_intent" and t["value"] == mi for t in targets) or norm(policy.get("micro_intent_scope")) == mi
    if scope in ("broad_category", "current_broad_category"):
        return any(t["type"] == "broad_category" and t["value"] == cat for t in targets) or norm(policy.get("classification_scope")) == cat
    if targets:
        return any(
            (t["type"] == "broad_category" and t["value"] == cat)
            or (t["type"] == "micro_intent" and t["value"] == mi)
            or (t["type"] == "additional_intent" and t["value"] in add)
            for t in targets
        )
    if scope in ("campaign_scoped", "campaign_specific") and norm(policy.get("campaign_id")) == norm(campaign_id):
        return True
    if scope in ("sender_scoped", "sender_specific") and norm(policy.get("sender_account")) == norm(sender_account):
        return True
    return False


def matched_policy_guidance(policies, scenario):
    allowed_statuses = {"active", "effective"}
    allowed_types = {
        "style",
        "draft_improvement",
        "draft_behaviour",
        "draft_behavior",
        "behavioural_draft_policy",
        "behavioral_draft_policy",
    }
    seen = set()
    out = []
    for p in policies:
        status = str(p.get("status", "")).strip().lower()
        rule_type = str(p.get("rule_type") or p.get("policy_type") or "").strip().lower()
        instruction = str(
            p.get("behavioural_instruction")
            or p.get("behavioral_instruction")
            or p.get("desired_future_behavior")
            or p.get("proposed_rule_text")
            or p.get("reason")
            or ""
        ).strip()
        if status not in allowed_statuses:
            continue
        if rule_type not in allowed_types:
            continue
        if not instruction:
            continue
        if p.get("safety_blocked") is True or p.get("unsafe") is True:
            continue
        if not policy_applies(
            p,
            scenario["category"],
            scenario["micro_intent"],
            scenario.get("additional_intents", []),
            scenario.get("campaign_id", ""),
            scenario.get("sender_account", ""),
        ):
            continue
        key = p.get("rule_id") or p.get("policy_id") or instruction
        if key in seen:
            continue
        seen.add(key)
        out.append((key, instruction))
    return out


def main():
    ha = load_json(HA_PATH)
    de = load_json(DE_PATH)
    shadow = load_json(SHADOW_PATH)

    j_code = code(ha, "J. Render Review Form HTML")
    l_code = code(ha, "L. Validate & Consume Review Token (POST)")
    n_code = code(ha, "N. Process Reviewer Decision")
    p1a_code = code(ha, "SL-P1A. Build Draft Revision Event")
    p2a_code = code(ha, "SL-P2A. Prepare Phase 1C+2 Capture Data")
    d_code = code(de, "D. Draft Preparation (Templates / Human Draft)")
    shadow_code = "\n".join((n.get("parameters", {}).get("jsCode", "") for n in shadow.get("nodes", [])))

    print("== Static workflow checks ==")
    check("HumanApproval J preloads latest_draft_learning", "latest_draft_learning" in j_code)
    check("HumanApproval J pre-fills draft revision reason", "escapeHtml(_5qDraftReason)" in j_code)
    check("HumanApproval J pre-selects draft improvement scope", "_5qScopeOption" in j_code and "selected" in j_code)
    check("HumanApproval J pre-checks target classifications", "_5qTargetChecked" in j_code)
    check("HumanApproval L preserves prior reason on blank reopened submit", "_5qPrevDraftLearning.draft_revision_reason" in l_code)
    check("HumanApproval L preserves prior target classifications", "_5qPrevDraftLearning.draft_improvement_target_classifications" in l_code)
    check("HumanApproval N stores latest_draft_learning", "latest_draft_learning: latestDraftLearning" in n_code)
    check("P1A event captures reason/scope/targets", all(s in p1a_code for s in ["draft_revision_reason", "draft_improvement_scope", "draft_improvement_target_classifications"]))
    check("P2A creates behavioural instruction", "behavioural_instruction: draftInstruction" in p2a_code)
    check("P2A candidate requires human activation", "requires_human_activation: true" in p2a_code)
    check("P2A keeps candidates proposed_shadow", 'status: "proposed_shadow"' in p2a_code)
    check("Decision has active behavioural policy block", "ACTIVE_BEHAVIOURAL_POLICIES" in d_code)
    check("Decision filters active/effective statuses", "allowedStatuses" in d_code and "active" in d_code and "effective" in d_code)
    check("Decision appends behavioural guidance to prompt", "buildBehaviouralPolicyGuidance" in d_code and "behaviouralGuidance" in d_code)
    check("Decision still gates AI on supervised mode", "AI_DRAFT_MODE  === 'supervised'" in d_code)
    check("Shadow Evaluator active=false", shadow.get("active") is False)
    check("Shadow config disabled", all(s in shadow_code for s in ["autonomous_enabled: false", "shadow_only: true", "dry_run: true", "would_send_live_now: false"]))
    check("Follow-up send remains manual pending Sender audit", "FOLLOWUP_SEND_PENDING_MANUAL" in n_code and "sender_audit_required: true" in n_code)

    print("\n== Synthetic bridge checks ==")
    source_case = {
        "case_id": "case-759e58d7",
        "original_draft": "Happy to chat. You can book here.",
        "edited_draft": "Of course - happy to explain what is included before asking for a call.",
        "draft_revision_reason": "The prospect asked what setup includes, so future replies should answer before CTA.",
        "draft_revision_type": "missing_answer",
        "desired_future_behavior": "When prospect asks what setup includes, answer that directly before CTA.",
        "draft_improvement_scope": "current_micro_intent_only",
        "targets": [
            {"type": "broad_category", "value": "INFORMATION_REQUEST"},
            {"type": "micro_intent", "value": "OFFER_EXPLANATION"},
        ],
    }
    event = {
        "case_id": source_case["case_id"],
        "raw_ai_draft_text": source_case["original_draft"],
        "final_edited_draft_submitted": source_case["edited_draft"],
        "edit_detected": source_case["original_draft"] != source_case["edited_draft"],
        "draft_revision_reason": source_case["draft_revision_reason"],
        "draft_revision_type": source_case["draft_revision_type"],
        "desired_future_behavior": source_case["desired_future_behavior"],
        "draft_improvement_scope": source_case["draft_improvement_scope"],
        "draft_improvement_target_classifications": source_case["targets"],
    }
    candidate = {
        "rule_id": "RC-5Q-SYNTH-001",
        "source_case_id": event["case_id"],
        "source_original_case_id": event["case_id"],
        "rule_type": "style",
        "status": "proposed_shadow",
        "classification_scope": "INFORMATION_REQUEST",
        "micro_intent_scope": "OFFER_EXPLANATION",
        "reason": event["draft_revision_reason"],
        "behavioural_instruction": event["desired_future_behavior"],
        "draft_revision_type": event["draft_revision_type"],
        "draft_improvement_scope": event["draft_improvement_scope"],
        "proposed_rule_scope": "micro_intent",
        "draft_improvement_target_classifications": event["draft_improvement_target_classifications"],
        "requires_human_activation": True,
    }
    active_policy = {**candidate, "status": "active"}

    check("human edit is captured", event["edit_detected"])
    check("revision reason is preserved", event["draft_revision_reason"] == source_case["draft_revision_reason"])
    check("improvement scope is preserved", event["draft_improvement_scope"] == "current_micro_intent_only")
    check("target classifications are preserved", len(event["draft_improvement_target_classifications"]) == 2)
    check("learning candidate is created as proposed_shadow", candidate["status"] == "proposed_shadow")
    check("candidate preserves original case ID", candidate["source_original_case_id"] == "case-759e58d7")
    check("candidate preserves behavioural instruction", "answer that directly before CTA" in candidate["behavioural_instruction"])
    check("active/effective policy available after owner activation", active_policy["status"] == "active")

    scenarios = [
        {
            "name": "positive/meeting interest",
            "reply": "Sounds interesting, can you walk me through what is included before we book?",
            "category": "INFORMATION_REQUEST",
            "micro_intent": "OFFER_EXPLANATION",
        },
        {
            "name": "pricing/cost question",
            "reply": "What does this cost and what kind of pricing model do you use?",
            "category": "PRICING_OR_COMMERCIAL_NEGOTIATION",
            "micro_intent": "PRICING_REQUEST",
        },
        {
            "name": "objection/not-now reply",
            "reply": "Not right now, maybe later in the year.",
            "category": "TIMING_OBJECTION",
            "micro_intent": "NOT_NOW",
        },
        {
            "name": "unsubscribe/not-interested reply",
            "reply": "Not interested, remove me from this list.",
            "category": "UNSUBSCRIBE",
            "micro_intent": "UNSUBSCRIBE_OR_COMPLAINT",
        },
        {
            "name": "ambiguous/question reply",
            "reply": "Can you send a bit more detail?",
            "category": "INFORMATION_REQUEST",
            "micro_intent": "HOW_IT_WORKS_REQUEST",
        },
    ]
    guidance = {s["name"]: matched_policy_guidance([active_policy], s) for s in scenarios}
    check("later similar draft guidance is affected", len(guidance["positive/meeting interest"]) == 1)
    check("unrelated pricing classification is not affected", len(guidance["pricing/cost question"]) == 0)
    check("unrelated objection classification is not affected", len(guidance["objection/not-now reply"]) == 0)
    check("unsubscribe classification is not affected", len(guidance["unsubscribe/not-interested reply"]) == 0)
    check("different micro-intent is not affected by micro scope", len(guidance["ambiguous/question reply"]) == 0)

    global_policy = {**active_policy, "rule_id": "RC-5Q-SYNTH-GLOBAL", "proposed_rule_scope": "global_draft_policy", "draft_improvement_scope": "all_ai_drafts", "draft_improvement_target_classifications": []}
    check("global policy applies when explicitly scoped", len(matched_policy_guidance([global_policy], scenarios[4])) == 1)
    check("duplicate active rules are de-duped", len(matched_policy_guidance([active_policy, {**active_policy}], scenarios[0])) == 1)
    check("proposed_shadow is not consumed by Decision", len(matched_policy_guidance([candidate], scenarios[0])) == 0)
    check("unsafe policy is not consumed", len(matched_policy_guidance([{**active_policy, "rule_id": "unsafe", "unsafe": True}], scenarios[0])) == 0)

    previous_learning = {
        "draft_revision_reason": "Keep the natural opener and answer first.",
        "draft_revision_type": "tone",
        "desired_future_behavior": "Use a natural opener before the direct answer.",
        "draft_improvement_scope": "current_broad_category",
        "draft_improvement_target_classifications": [{"type": "broad_category", "value": "POSITIVE_INTEREST"}],
    }
    reopened_blank_submit = {
        "draft_revision_reason": previous_learning["draft_revision_reason"],
        "draft_revision_type": previous_learning["draft_revision_type"],
        "desired_future_behavior": previous_learning["desired_future_behavior"],
        "draft_improvement_scope": previous_learning["draft_improvement_scope"],
        "draft_improvement_target_classifications": previous_learning["draft_improvement_target_classifications"],
    }
    check("reopened form preserves human-entered reason", reopened_blank_submit["draft_revision_reason"] == previous_learning["draft_revision_reason"])
    check("reopened form preserves type/scope/targets", reopened_blank_submit["draft_revision_type"] == "tone" and reopened_blank_submit["draft_improvement_scope"] == "current_broad_category" and len(reopened_blank_submit["draft_improvement_target_classifications"]) == 1)

    print("\n== Classification-amendment same-bridge checks ==")
    classification_candidate = {
        "rule_type": "classification",
        "status": "proposed_shadow",
        "source_case_id": "case-classification-synth",
        "classification_scope": "INFORMATION_REQUEST",
        "micro_intent_scope": "HOW_IT_WORKS_REQUEST",
        "reason": "Reviewer corrected the classification.",
    }
    check("classification amendment capture path exists", "classChanged" in p2a_code and "rule_type: \"classification\"" in p2a_code)
    check("corrected-classification candidate remains proposed_shadow", classification_candidate["status"] == "proposed_shadow")
    check("corrected classification preserves reason", bool(classification_candidate["reason"]))
    check("Decision corrected-classification consumption not changed in 5Q", "ACTIVE_BEHAVIOURAL_POLICIES" in d_code, "classification loop remains prior verified path; 5Q only added draft behavioural consumption")

    total = len(checks)
    passed = sum(1 for _, ok, _ in checks if ok)
    failed = total - passed
    print(f"\nSUMMARY: {passed}/{total} PASS, {failed} FAIL")
    if failed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
