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
h_code = nodes["H. Validate Review Token (GET)"]["parameters"]["jsCode"]
h0_node = nodes["H0. Lookup Case for Form (Data Table)"]
slp2a_code = nodes["SL-P2A. Prepare Phase 1C+2 Capture Data"]["parameters"]["jsCode"]
connections = workflow.get("connections", {})
workflow_text = json.dumps(workflow, ensure_ascii=False)

print("== HumanApproval render ID / syntax guard ==")
check("node J has no unescaped diagnostic style quote regression", 'style="background:#f8d7da' not in j_code)
check("node J diagnostic banner uses escaped style quotes", 'style=\\"background:#f8d7da' in j_code)
check("node J no longer contains the production UNKNOWN_ID-era syntax trigger", "Unexpected identifier 'background'" not in j_code)

print("\n== Case/token lookup and validation ==")
lookup_text = json.dumps(h0_node, ensure_ascii=False)
check("review GET lookup filters by query case", "query.case" in lookup_text and "case_id" in lookup_text)
check("token validation reads query case", "query.case" in h_code)
check("token validation reads query token", "query.token" in h_code)
check("wrong token is blocked safely", "WRONG_TOKEN" in h_code and "token_valid" in h_code)
check("missing/unknown case ID is blocked safely", "CASE_NOT_FOUND" in h_code or "UNKNOWN_ID" in h_code)
check("unknown/missing case routes to token error page", "J2. Render Token Error Page" in workflow_text)

print("\n== Hydrated render surface ==")
check("hydrated review form preserves case id in form action/query", "case=" in j_code and "rc.case_id" in j_code)
check("hydrated review form preserves token in form action/query", "token=" in j_code and "rc.token" in j_code)
check("ai_failed_fallback source remains accepted/renderable", "ai_failed_fallback" in workflow_text)
check("draft textarea renders editable draft_text", "textarea" in j_code and "draft_text" in j_code)
check("incoming reply text renders", "reply_text" in j_code)
check("learning UI appears for hydrated cases", "hmzDraftReasonSection" in j_code)
check("Save button appears for hydrated cases", 'value=\\"save\\"' in j_code or 'value="save"' in j_code)
check("Approved for learning only appears for hydrated cases", "approve_learning_only" in j_code)
check("Approve/send exists only outside diagnostic early return", "approve_and_send_followup" in j_code and "_5q3MissingContext" in j_code)

print("\n== Render safety boundaries ==")
check("diagnostic missing-context path returns before normal buttons", "_5q3MissingContext" in j_code and "return { json: { ...input, html } };" in j_code)
check("diagnostic unknown/missing cases do not show normal approval actions", "Approve/send and learning-only actions are unavailable" in j_code)
check("render path does not connect to Sender handoff", "Q. Reply Sender Handoff (Approved)" not in json.dumps(connections.get("J. Render Review Form HTML", {})))
check("render path does not create learning candidates", "SL-P2A. Prepare Phase 1C+2 Capture Data" not in json.dumps(connections.get("J. Render Review Form HTML", {})))
check("candidate prep still suppresses diagnostic rows", "CONTEXT_MISSING_BLOCKED" in slp2a_code and "DIAGNOSTIC_CONTEXT_MISSING" in slp2a_code)
check("Sender handoff remains behind approval outcome router", "Q. Reply Sender Handoff (Approved)" in json.dumps(connections.get("P. Approval Outcome Router", {})))

print("\n== Duplicate error logging ==")
check("node J does not self-post error chat records", "POST Google Chat Webhook" not in j_code)
check("node J does not call the Error Handler directly", "Error Handler" not in j_code)

failed = [name for name, ok, _ in checks if not ok]
print(f"\nSUMMARY: {len(checks)-len(failed)}/{len(checks)} PASS, {len(failed)} FAIL")
if failed:
    sys.exit(1)
