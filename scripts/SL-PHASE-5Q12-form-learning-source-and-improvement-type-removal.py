#!/usr/bin/env python3
"""SL-PHASE-5Q12 form learning source and improvement-type removal harness.

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

SYNTHETIC_INSTRUCTION = 'For this synthetic setup-test classification, start the draft with exactly: "Thanks — I can outline the setup clearly."'
SYNTHETIC_PREFIX = "Thanks — I can outline the setup clearly."

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


def norm(value: object) -> str:
    return str("" if value is None else value).strip().upper()


def policy_targets(policy: dict) -> list[dict]:
    raw = policy.get("draft_improvement_target_classifications") or policy.get("target_classifications") or []
    return [{"type": str(t.get("type", "")).strip(), "value": norm(t.get("value", ""))} for t in raw if isinstance(t, dict)]


def policy_applies(policy: dict, category: str, micro_intent: str) -> bool:
    scope = str(policy.get("proposed_rule_scope") or policy.get("draft_improvement_scope") or "")
    cat = norm(category)
    mi = norm(micro_intent)
    targets = policy_targets(policy)
    if scope in ("global_draft_policy", "all_ai_drafts"):
        return True
    if scope in ("micro_intent", "current_micro_intent_only"):
        return any(t["type"] == "micro_intent" and t["value"] == mi for t in targets) or norm(policy.get("micro_intent_scope")) == mi
    if scope in ("broad_category", "current_broad_category"):
        return any(t["type"] == "broad_category" and t["value"] == cat for t in targets) or norm(policy.get("classification_scope")) == cat
    return False


def guidance(policies: list[dict], category: str, micro_intent: str) -> str:
    active = []
    by_scope: dict[str, dict] = {}
    for p in policies:
        if str(p.get("status", "")).lower() not in ("active", "effective"):
            continue
        if str(p.get("rule_type") or p.get("policy_type") or "").lower() not in ("style", "draft_improvement"):
            continue
        if not policy_applies(p, category, micro_intent):
            continue
        instruction = str(p.get("behavioural_instruction") or p.get("human_instruction") or p.get("desired_future_behavior") or "").strip()
        if not instruction:
            continue
        key = str(p.get("policy_precedence_key") or p.get("draft_improvement_scope") or p.get("rule_id"))
        old = by_scope.get(key)
        if not old or str(p.get("created_at", "")) >= str(old.get("created_at", "")):
            by_scope[key] = {**p, "instruction": instruction}
    active = sorted(by_scope.values(), key=lambda p: str(p.get("created_at", "")), reverse=True)
    if not active:
        return ""
    return "\n".join(f"{p.get('rule_id')}: {p['instruction']}" for p in active)


def apply_exact_start(text: str, guide: str) -> str:
    m = re.search(r'start\s+(?:the\s+)?draft\s+with\s+exactly\s*[:]?\s*["“]([^"”]+)["”]', guide, re.I)
    if not m:
        return text
    phrase = m.group(1).strip()
    current = text.lstrip()
    if current.startswith(phrase):
        return text
    return phrase + "\n\n" + re.sub(r"^(Thanks[^\n.]*\.|Happy to explain\.|Happy to talk it through\.|Here is the short version\.)\s*", "", current, flags=re.I)


human = load(HUMAN)
decision = load(DECISION)
render = code(human, "J. Render Review Form HTML")
post = code(human, "L. Validate & Consume Review Token (POST)")
process = code(human, "N. Process Reviewer Decision")
capture = code(human, "SL-P2A. Prepare Phase 1C+2 Capture Data")
writer = json.dumps(node(human, "SL-P2E. Write Rule Candidate Shadow").get("parameters", {}), ensure_ascii=False)
decision_d = code(decision, "D. Draft Preparation (Templates / Human Draft)")
workflow_text = json.dumps({"human": human, "decision": decision}, ensure_ascii=False)

print("== UI removal ==")
check("improvement-type section is absent from rendered form", "What type of improvement is this?" not in render)
check("no hidden required improvement-type field remains", 'name=\\"draft_revision_types\\"' not in render and "required" not in render[render.find("draft_revision_types") if "draft_revision_types" in render else 0:render.find("draft_revision_types") + 200 if "draft_revision_types" in render else 0])
check("save works without improvement type", "buildLatestDraftLearning" in process and "draft_revision_types" not in process.split("function buildLatestDraftLearning", 1)[1].split("return {", 1)[0])
check("learning-only works without improvement type when instruction is present", "submittedLearningInstruction" in process and "learning_instruction_required" in process)
check("approve/send saves learning fields without improvement type", "latest_draft_learning: latestDraftLearning" in process and "latest_saved_reply_text" in process)
check("old rows with improvement types remain readable for audit", "_5qPrevDraftLearning.draft_revision_types" in post or "_5qLatestDraftLearning.draft_revision_types" in render)

print("\n== Learning source-of-truth ==")
check("form-created rule stores source case ID", "source_case_id: String(rc.case_id" in capture and "source_case_id" in writer)
check("form-created rule stores human instruction", "human_instruction: draftInstruction" in capture and "human_instruction" in writer)
check("form-created rule stores scope", "draft_improvement_scope" in capture and "proposed_rule_scope" in capture and "draft_improvement_scope" in writer)
check("form-created rule stores original classification", "originalClassification" in capture and "original_classification" in writer)
check("form-created rule stores corrected/effective classification", "correctedEffectiveClassification" in capture and "corrected_effective_classification" in writer)
check("target classification uses corrected/effective classification when corrected", "effectiveDraftTargets" in capture and "value: effectMi" in capture and "target_classification_used: correctedEffectiveClassification" in capture)
check("target classification uses original classification when not corrected", "const effectCat = corrCategory    || origCategory" in capture and "const effectMi  = corrMicroIntent || origMicroIntent" in capture)
check("rule has source marker distinct from Codex baseline", "source_marker: \"humanapproval_form_created_learning\"" in capture and "activation_source: \"humanapproval_form\"" in capture)
check("rule becomes active/effective immediately for supervised drafting", 'status: "active"' in capture and "immediate_supervised_effect: true" in capture and "requires_human_activation: false" in capture)
check("Decision consumes active form-created rule", "Q12. Lookup Active Form Learning Rules" in json.dumps(decision) and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d)
check("normal AI draft changes because of form-created rule", "buildAIPrompt" in decision_d and "behaviouralGuidance || \"\"" in decision_d and "_5qApplyExactStartInstruction" in decision_d)
check("safe fallback draft changes because of form-created rule", "buildPolicyAwareFallback" in decision_d and ("_5qApplyExactStartInstruction(draftText, behaviouralGuidance)" in decision_d or "_5qApplyActiveRuleDraftPostprocessing(draftText, microIntent, behaviouralGuidance, senderName, bookingLink)" in decision_d))
check("unrelated classification does not leak the rule", "_5qPolicyApplies" in decision_d and "targets.some" in decision_d)
check("newer same-scope human rule overrides older rule", "newestByScope" in decision_d and "candidate.time >= existing.time" in decision_d and "policy_precedence_key" in capture)
check("Codex baseline policies remain distinguishable", "ACTIVE_BEHAVIOURAL_POLICIES" in decision_d and "DYNAMIC_FORM_BEHAVIOURAL_POLICIES" in decision_d and "owner_live_proof_chat" in decision_d and "humanapproval_form" in decision_d)

print("\n== Synthetic dynamic proof ==")
check("baseline before rule lacks synthetic instruction", SYNTHETIC_INSTRUCTION not in workflow_text and SYNTHETIC_PREFIX not in workflow_text)
synthetic_rule = {
    "rule_id": "synthetic-human-form-rule-5q12",
    "source_case_id": "case-synthetic-5q12",
    "rule_type": "style",
    "status": "active",
    "classification_scope": "SYNTHETIC_SETUP_TEST",
    "micro_intent_scope": "SETUP_TEST",
    "draft_improvement_scope": "current_micro_intent_only",
    "proposed_rule_scope": "micro_intent",
    "draft_improvement_target_classifications": [{"type": "micro_intent", "value": "SETUP_TEST"}],
    "target_classifications": [{"type": "micro_intent", "value": "SETUP_TEST"}],
    "behavioural_instruction": SYNTHETIC_INSTRUCTION,
    "human_instruction": SYNTHETIC_INSTRUCTION,
    "activation_source": "humanapproval_form",
    "source_marker": "humanapproval_form_created_learning",
    "created_at": "2026-06-29T00:00:02Z",
    "policy_precedence_key": "SYNTHETIC_SETUP_TEST|SETUP_TEST|current_micro_intent_only",
}
older_rule = {**synthetic_rule, "rule_id": "older", "behavioural_instruction": 'For this synthetic setup-test classification, start the draft with exactly: "OLDER PREFIX."', "human_instruction": 'For this synthetic setup-test classification, start the draft with exactly: "OLDER PREFIX."', "created_at": "2026-06-29T00:00:01Z"}
guide_before = guidance([], "SYNTHETIC_SETUP_TEST", "SETUP_TEST")
guide_after = guidance([older_rule, synthetic_rule], "SYNTHETIC_SETUP_TEST", "SETUP_TEST")
guide_unrelated = guidance([synthetic_rule], "UNRELATED", "OTHER")
normal_before = apply_exact_start("Happy to explain.\n\nExisting draft.", guide_before)
normal_after = apply_exact_start("Happy to explain.\n\nExisting draft.", guide_after)
fallback_after = apply_exact_start("Here is the short version.\n\nFallback draft.", guide_after)
unrelated_after = apply_exact_start("Happy to explain.\n\nExisting draft.", guide_unrelated)
check("form-created candidate/rule stores synthetic instruction", synthetic_rule["source_case_id"] == "case-synthetic-5q12" and synthetic_rule["human_instruction"] == SYNTHETIC_INSTRUCTION)
check("after activation/effective Decision guidance includes synthetic instruction", SYNTHETIC_INSTRUCTION in guide_after)
check("normal later similar draft changes", normal_before != normal_after and normal_after.startswith(SYNTHETIC_PREFIX))
check("safe fallback draft changes", fallback_after.startswith(SYNTHETIC_PREFIX))
check("unrelated classification does not inherit instruction", SYNTHETIC_PREFIX not in unrelated_after and guide_unrelated == "")
check("newer same-scope rule overrides older one", "OLDER PREFIX" not in guide_after and SYNTHETIC_PREFIX in normal_after)
check("effect is tied to form-created source metadata", synthetic_rule["activation_source"] == "humanapproval_form" and synthetic_rule["source_marker"] == "humanapproval_form_created_learning")

failed = [name for name, ok in checks if not ok]
print(f"\nSUMMARY: {len(checks) - len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
