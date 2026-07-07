#!/usr/bin/env python3
"""FABLE-RUN4-SENDER-BODY-GATE: Sender-side blank-body defense-in-depth.

Proven gap (Codex Fable Run 3 review; confirmed by Fable Run 4 read-only audit
of workflows/production_sender_current.json, versionId dfb310f4):
  - Node A (validateSenderInput) never checks draft body.
  - Node B (runSendGates) passes the variable gate when draft_text === null.
  - Node O (14 live send gates) has no body gate.
  - Node Q POST body coalesces to '' when draft text is missing:
      String(($json.draft && $json.draft.draft_text) ||
             ($json.body && $json.body.edited_reply_text) || '')
  => a missing/blank/whitespace-only body could reach the Instantly POST.
    Blank-body prevention currently lives ONLY upstream in HumanApproval
    Node N (draft_text_required).

This script patches ONLY Sender nodes:
  - "B. Re-run Send & Suppression Gates": new draft_body gate, evaluated on the
    SAME effective text precedence node Q uses, AFTER token resolution and
    BEFORE send-lock acquisition (node E). Failure routes to the existing
    C2 gate-rejection terminal (reason listed in terminal.details; HumanApproval
    R0 treats it as form-retryable, so the same review case/link is reusable).
  - "O. Live Send Gate Evaluation (14 Gates)": 15th gate `draft_body_non_empty`
    as a last-line check immediately before the Instantly POST (node Q) and
    before any terminal SENT state. Failure routes to the existing P2 blocked
    terminal with the failed gate id.

No sender-mapping, idempotency, retry, or reconciliation logic is changed.
Sender is NOT triggered by this script. No Instantly POST occurs.
"""
import json

WF = "workflows/production_sender_current.json"
MARKER = "FABLE-RUN4-SENDER-BODY-GATE"

HELPER = '''
// FABLE-RUN4-SENDER-BODY-GATE helper: visible text after normalization.
// Strips HTML comments (e.g. the hmz-send-key marker), HTML tags, entity/char
// non-breaking spaces and zero-width characters, then collapses whitespace.
// A body whose normalized form is empty must never be POSTed to Instantly.
function hmzSenderVisibleBodyText(value) {
  let s = String(value == null ? '' : value);
  s = s.replace(/<!--[\\s\\S]*?-->/g, ' ');
  s = s.replace(/<[^>]*>/g, ' ');
  s = s.replace(/&nbsp;|&#160;|&#xa0;/gi, ' ');
  s = s.replace(/[\\u200B-\\u200D\\uFEFF\\u00A0]/g, ' ');
  return s.replace(/\\s+/g, ' ').trim();
}
'''

# ---------------------------------------------------------------- Node B ----

B_HELPER_ANCHOR = "function runSendGates(item) {"

B_GATE_ANCHOR = "  if (!draftVariableGatePassed) reasons.push('unresolved_template_variables');"

B_GATE_INSERT = '''
  // FABLE-RUN4-SENDER-BODY-GATE: Sender-side defense-in-depth. The effective
  // send body (same precedence as node Q's POST body expression) must contain
  // visible non-whitespace text after marker/HTML normalization. Upstream
  // prevention lives in HumanApproval Node N (draft_text_required); this gate
  // makes the Sender independently reject a missing/blank/whitespace-only
  // body BEFORE send-lock acquisition and BEFORE any Instantly POST.
  const effectiveSendBodyText = String((draft && draft.draft_text) || (input.body && input.body.edited_reply_text) || '');
  const draftBodyGatePassed = hmzSenderVisibleBodyText(effectiveSendBodyText).length > 0;
  if (!draftBodyGatePassed) reasons.push('draft_body_missing_or_blank');
'''

B_GATES_OBJ_OLD = "      draft_variable_gate_passed: draftVariableGatePassed,"
B_GATES_OBJ_NEW = """      draft_variable_gate_passed: draftVariableGatePassed,
      draft_body_gate_passed: draftBodyGatePassed,
      draft_body_block_reason: draftBodyGatePassed ? null : 'DRAFT_BODY_MISSING_OR_BLANK',
      draft_body_fix_instruction: draftBodyGatePassed ? null : 'Reopen the review case and re-approve with non-empty draft text. Do not retry this send without a visible body.',"""

B_PASSED_OLD = """    draftVariableGatePassed &&
    dryRunFlagValid;"""
B_PASSED_NEW = """    draftVariableGatePassed &&
    draftBodyGatePassed &&
    dryRunFlagValid;"""

# ---------------------------------------------------------------- Node O ----

O_HELPER_ANCHOR = "function evaluateLiveSendGates(item) {"

O_GATE_ANCHOR = "    'PRIOR_TERMINAL_SEND_STATE_EXISTS');"

O_GATE_INSERT = '''
  // FABLE-RUN4-SENDER-BODY-GATE (15th gate): last-line defense-in-depth
  // immediately before the Instantly POST (node Q). Mirrors node Q's exact
  // effective-body precedence so the text checked here is the text sent.
  const draftForBodyGate = input.draft || {};
  const effectiveSendBodyText = String((draftForBodyGate && draftForBodyGate.draft_text) || (input.body && input.body.edited_reply_text) || '');
  gate('draft_body_non_empty', 'Approved draft body is non-empty after marker/HTML/whitespace normalization (fix: reopen the review case and re-approve with non-empty draft text)',
    hmzSenderVisibleBodyText(effectiveSendBodyText).length > 0,
    'DRAFT_BODY_MISSING_OR_BLANK');
'''


def insert_before(code, anchor, text, node_name):
    idx = code.find(anchor)
    if idx < 0:
        raise SystemExit(f"HELPER ANCHOR NOT FOUND in {node_name}: {anchor[:80]}")
    if code.count(anchor) != 1:
        raise SystemExit(f"HELPER ANCHOR NOT UNIQUE in {node_name}: {anchor[:80]}")
    return code[:idx] + text + "\n" + code[idx:]


def insert_after_line(code, anchor, text, node_name):
    idx = code.find(anchor)
    if idx < 0:
        raise SystemExit(f"GATE ANCHOR NOT FOUND in {node_name}: {anchor[:80]}")
    if code.count(anchor) != 1:
        raise SystemExit(f"GATE ANCHOR NOT UNIQUE in {node_name}: {anchor[:80]}")
    line_end = code.find("\n", idx)
    return code[:line_end] + "\n" + text + code[line_end:]


def replace_unique(code, old, new, node_name):
    if old not in code:
        raise SystemExit(f"REPLACE ANCHOR NOT FOUND in {node_name}: {old[:80]}")
    if code.count(old) != 1:
        raise SystemExit(f"REPLACE ANCHOR NOT UNIQUE in {node_name}: {old[:80]}")
    return code.replace(old, new)


def main():
    with open(WF, encoding="utf-8-sig") as f:
        wf = json.load(f)
    nodes = {n["name"]: n for n in wf["nodes"]}
    b = nodes["B. Re-run Send & Suppression Gates"]
    o = nodes["O. Live Send Gate Evaluation (14 Gates)"]

    changed = False

    b_code = b["parameters"]["jsCode"]
    if MARKER in b_code:
        print("  SKIP Node B: already patched")
    else:
        b_code = insert_before(b_code, B_HELPER_ANCHOR, HELPER, "Node B")
        b_code = insert_after_line(b_code, B_GATE_ANCHOR, B_GATE_INSERT, "Node B")
        b_code = replace_unique(b_code, B_GATES_OBJ_OLD, B_GATES_OBJ_NEW, "Node B")
        b_code = replace_unique(b_code, B_PASSED_OLD, B_PASSED_NEW, "Node B")
        b["parameters"]["jsCode"] = b_code
        changed = True
        print("  PATCHED Node B (pre-lock draft_body gate)")

    o_code = o["parameters"]["jsCode"]
    if MARKER in o_code:
        print("  SKIP Node O: already patched")
    else:
        o_code = insert_before(o_code, O_HELPER_ANCHOR, HELPER, "Node O")
        o_code = insert_after_line(o_code, O_GATE_ANCHOR, O_GATE_INSERT, "Node O")
        o["parameters"]["jsCode"] = o_code
        changed = True
        print("  PATCHED Node O (15th gate draft_body_non_empty, pre-POST)")

    if not changed:
        print("No changes made.")
        return

    with open(WF, "w", encoding="utf-8") as f:
        json.dump(wf, f, indent=2, ensure_ascii=False)
    print(f"PATCHED {WF}")
    print("Run node --check on extracted node code + harness before deploying.")


if __name__ == "__main__":
    main()
