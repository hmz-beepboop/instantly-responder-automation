#!/usr/bin/env python3
import json
import sys

HUMANAPPROVAL = "workflows/production_humanapproval_current.json"

checks = []


def check(name, ok, detail=""):
    checks.append((name, ok, detail))
    print(("[PASS] " if ok else "[FAIL] ") + name + (f" - {detail}" if detail and not ok else ""))


with open(HUMANAPPROVAL, "r", encoding="utf-8") as f:
    workflow = json.load(f)

nodes = {node.get("name"): node for node in workflow.get("nodes", [])}
j_code = nodes["J. Render Review Form HTML"]["parameters"]["jsCode"]
n_code = nodes["N. Process Reviewer Decision"]["parameters"]["jsCode"]
o_params = nodes["O. Persist Reviewer Decision (Data Table)"]["parameters"]
h_code = nodes["H. Validate Review Token (GET)"]["parameters"]["jsCode"]
connections = workflow.get("connections", {})
workflow_text = json.dumps(workflow, ensure_ascii=False)
o_text = json.dumps(o_params, ensure_ascii=False)

print("== Save receives reviewer fields ==")
check("Save branch exists", 'action === "save"' in n_code)
check("Save reads edited draft", "input.submit_edited_text" in n_code)
check("Save reads combined reason/instruction", "input.submit_draft_learning_instruction" in n_code)
check("Save reads multiple scope selections", "submit_draft_improvement_scopes" in n_code)
check("Save reads multiple improvement types", "submit_draft_revision_types" in n_code)
check("Save reads target classification selections", "submit_draft_improvement_target_classifications" in n_code)
check("Save reads approver identity", "submit_approver_identity" in workflow_text and "const approver" in n_code)

print("\n== Save persists state ==")
check("Save keeps review in IN_REVIEW", 'rc.status = "IN_REVIEW"' in n_code)
check("Save stores edited draft as final_reply_text", "rc.final_reply_text = input.submit_edited_text" in n_code)
check("Save stores approver identity on review case", "rc.approver_identity = approver || rc.approver_identity || null" in n_code)
check("Save stores latest_saved_reply_text in decision_payload", "latest_saved_reply_text: rc.final_reply_text" in n_code)
check("Save stores latest_draft_learning in decision_payload", "latest_draft_learning: latestDraftLearning" in n_code)
check("Save stores saved_by in decision_payload", "saved_by: rc.approver_identity" in n_code)
check("Persist node writes final_reply_text", "final_reply_text" in o_text)
check("Persist node writes decision_payload", "decision_payload" in o_text)
check("Persist node writes approver_identity", "approver_identity" in o_text)
check("Persist node does not mutate token on save", "token" not in o_text)

print("\n== Reopen prefills saved state ==")
check("Render works for valid hydrated case", "hmzReplyText" in j_code and "reply_text" in j_code)
check("Render prefers latest_saved_reply_text for unsent saved case", "_5pDecisionPayload.latest_saved_reply_text || rc.final_reply_text || rc.draft_text" in j_code)
check("Render falls back to original draft only after saved fields", "rc.final_reply_text || rc.draft_text" in j_code)
check("Render preloads saved learning for unsent cases", "const _5qLatestDraftLearning = _5pDecisionPayload.latest_draft_learning" in j_code)
check("Render prefills combined reason/instruction", "draft_learning_instruction" in j_code and "combined_learning_instruction" in j_code)
check("Render prefills multiple scopes", "draft_improvement_scopes" in j_code and "_5qScopeChecked" in j_code)
check("Render prefills multiple improvement types", "draft_revision_types" in j_code and "_5qTypeChecked" in j_code)
check("Render prefills detected classification targets", "draft_improvement_target_classifications" in j_code and "_5qTargetChecked" in j_code)
check("Render prefills approver identity", "value=\\\"" in j_code and "saved_by" in j_code)
check("Same review URL stays case/token based", "case=" in j_code and "token=" in j_code and "rc.token" in j_code)

print("\n== Save safety boundaries ==")
check("Save routes to non-send terminal result", "Q2. Build Non-Send Terminal Result" in json.dumps(connections.get("P. Approval Outcome Router", {})))
check("Save does not satisfy approval router", "final_action" in json.dumps(nodes["P. Approval Outcome Router"]["parameters"], ensure_ascii=False) and "approve" in json.dumps(nodes["P. Approval Outcome Router"]["parameters"], ensure_ascii=False))
check("Save candidate creation is suppressed", 'draftChanged && inp.final_action !== "save"' in nodes["SL-P2A. Prepare Phase 1C+2 Capture Data"]["parameters"]["jsCode"])
check("Render path does not trigger Sender", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("J. Render Review Form HTML", {})))
check("Save response path does not trigger Sender", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("Q2. Build Non-Send Terminal Result", {})))
check("Wrong token remains blocked", "WRONG_TOKEN" in h_code)
check("Unknown case remains blocked", "CASE_NOT_FOUND" in h_code or "UNKNOWN_ID" in h_code)

failed = [name for name, ok, _ in checks if not ok]
print(f"\nSUMMARY: {len(checks)-len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
