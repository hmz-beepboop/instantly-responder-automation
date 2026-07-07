#!/usr/bin/env python3
"""SL-PHASE-5Q-RUN3-UIVIS: UI/reporting visibility fix (HumanApproval only).

Live-proven issue (Fable Run 3, cases case-4a5596a0 / case-07bd8bb5 / case-659d1e01):
backend classification correction + AI upgrade succeeded, but the operator-facing
surfaces under-reported it:
  1. Google Chat notification (Node D) printed "Micro intent: N/A" because its
     fallback chain (ctx.micro_intent || rc.micro_intent) missed
     recommended_action_plan.micro_intent / sender_handoff.draft.micro_intent.
  2. Review form (Node J) never showed Original vs Effective classification
     side by side; the top-level baseline category (AMBIGUOUS) could be
     mistaken for the final classification.
  3. Node J's shadow-correction section labelled the EFFECTIVE micro intent as
     "Original micro intent" (untruthful label).
  4. Neither surface stated reply_mode or an explicit AI draft status.

This script patches ONLY HumanApproval nodes:
  - "J. Render Review Form HTML"
  - "D. Build Google Chat Notification Payload"
No Decision, no Sender, no send-path logic is touched.
"""
import json
import sys

WF = "workflows/production_humanapproval_current.json"
MARKER = "SL-PHASE-5Q-RUN3-UIVIS"

# ---------------------------------------------------------------- Node J ----

J_ANCHOR = 'html += "<p><strong>Broad category:</strong> " + escapeHtml(ctx.category || "") + " | <strong>Micro intent:</strong> "'

J_INSERT = '''
  // SL-PHASE-5Q-RUN3-UIVIS: original vs effective classification + reply mode + AI draft status.
  // Baseline row category must never be mistaken for the final effective classification.
  var _r3Draft = (ctx.sender_handoff && ctx.sender_handoff.draft) || {};
  var _r3Attr = ctx.learning_attribution || _r3Draft.learning_attribution || {};
  var _r3BaseBC = String(_r3Attr.baseline_broad_category || "");
  var _r3BaseMI = String(_r3Attr.baseline_micro_intent || "");
  var _r3EffBC = String(_r3Attr.effective_broad_category || ctx.category || rc.category || "");
  var _r3EffMI = String(_r3Attr.effective_micro_intent || (ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ctx.micro_intent || rc.micro_intent || _r3Draft.micro_intent || "");
  var _r3WasCorrected = ((_r3BaseBC && _r3EffBC && _r3BaseBC !== _r3EffBC) || (_r3BaseMI && _r3EffMI && _r3BaseMI !== _r3EffMI));
  var _r3ClassRuleIds = Array.isArray(_r3Draft.classification_learning_rules_applied) ? _r3Draft.classification_learning_rules_applied.map(function(r){ return (r && typeof r === "object") ? (r.rule_id || r.id || "") : String(r || ""); }).filter(Boolean) : [];
  if (!_r3ClassRuleIds.length && _r3Attr.learning_applied_to_classification === true && Array.isArray(_r3Attr.applied_learning_rule_ids)) { _r3ClassRuleIds = _r3Attr.applied_learning_rule_ids.filter(Boolean); }
  if (_r3WasCorrected) {
    html += "<div style=\\"background:#e8f5e9;border:1px solid #66bb6a;padding:10px;border-radius:4px;margin:6px 0\\"><strong>Classification corrected by approved learning.</strong><br><strong>Original (detected):</strong> " + escapeHtml((_r3BaseBC || "?") + " / " + (_r3BaseMI || "?")) + "<br><strong>Effective (used for drafting):</strong> " + escapeHtml((_r3EffBC || "?") + " / " + (_r3EffMI || "?")) + (_r3ClassRuleIds.length ? ("<br><strong>Applied correction rule:</strong> " + escapeHtml(_r3ClassRuleIds.join(", "))) : "") + "<br><small>The top-level case category may still show the originally detected broad category. The effective classification above is what routing and drafting actually used.</small></div>";
  } else if (_r3EffBC || _r3EffMI) {
    html += "<p><strong>Effective classification:</strong> " + escapeHtml((_r3EffBC || "?") + " / " + (_r3EffMI || "?")) + " <small>(no classification correction applied)</small></p>";
  }
  var _r3AIAttempt = _r3Draft.ai_attempt || {};
  var _r3SrcRaw = String(_r3Attr.draft_source_raw || _r3Draft.draft_source_raw || _r3Draft.draft_source || ctx.draft_source || rc.draft_source || "");
  var _r3ReplyMode = String(rc.reply_mode || (ctx.recommended_action_plan && ctx.recommended_action_plan.reply_mode) || (ctx.sender_handoff && ctx.sender_handoff.decision && ctx.sender_handoff.decision.reply_mode) || "");
  var _r3AIStatus = "";
  if (_r3SrcRaw === "ai_supervised" || _r3SrcRaw === "ai_supervised_or_template") { _r3AIStatus = (_r3AIAttempt.ok === true) ? "AI draft generated and passed validation" : "AI draft generated"; if (_r3AIAttempt.ok === true && _r3AIAttempt.model) { _r3AIStatus += " (model: " + String(_r3AIAttempt.model) + ")"; } }
  else if (_r3SrcRaw === "ai_commercial_supervised") { _r3AIStatus = "AI-assisted commercial draft (human review required)"; }
  else if (_r3SrcRaw === "ai_failed_fallback") { _r3AIStatus = "AI attempted; output rejected or provider failed; safe fallback draft used"; }
  else if (_r3SrcRaw === "deterministic_template") { _r3AIStatus = "Deterministic template draft (no AI draft attempted)"; }
  else if (_r3SrcRaw === "human_only" || _r3SrcRaw === "none") { _r3AIStatus = "No AI draft by policy (human-only or no-reply handling)"; }
  else if (_r3SrcRaw === "node_exception_fallback") { _r3AIStatus = "Diagnostic fallback (draft preparation exception)"; }
  else { _r3AIStatus = _r3SrcRaw ? ("No AI draft recorded (source: " + _r3SrcRaw + ")") : "Draft source not recorded"; }
  html += "<p><strong>Reply mode:</strong> " + escapeHtml(_r3ReplyMode || "not recorded") + " | <strong>AI draft status:</strong> " + escapeHtml(_r3AIStatus) + "</p>";
'''

J_LABEL_OLD_1 = 'html += "<p style=\\"font-size:0.85em;color:#555;margin:4px 0\\"><strong>Original broad category:</strong> " + p1cCat + "";'
J_LABEL_NEW_1 = 'html += "<p style=\\"font-size:0.85em;color:#555;margin:4px 0\\"><strong>Current effective broad category:</strong> " + p1cCat + "";  // SL-PHASE-5Q-RUN3-UIVIS truthful label'

J_LABEL_OLD_2 = 'html += " | <strong>Original micro intent:</strong> " + (p1cMi || "<em>not set</em>");'
J_LABEL_NEW_2 = 'html += " | <strong>Current effective micro intent:</strong> " + (p1cMi || "<em>not set</em>") + (_r3WasCorrected ? (" | <strong>Originally detected:</strong> " + escapeHtml((_r3BaseBC || "?") + " / " + (_r3BaseMI || "?"))) : "");  // SL-PHASE-5Q-RUN3-UIVIS truthful label'

# ---------------------------------------------------------------- Node D ----

D_MI_OLD = 'lines.push("Micro intent: " + (ctx.micro_intent || rc.micro_intent || "N/A"));'
D_MI_NEW = '''// SL-PHASE-5Q-RUN3-UIVIS: effective micro intent + original-vs-effective visibility in chat.
  var _r3cDraft = (ctx.sender_handoff && ctx.sender_handoff.draft) || {};
  var _r3cAttr = ctx.learning_attribution || _r3cDraft.learning_attribution || {};
  var _r3cEffMI = String(_r3cAttr.effective_micro_intent || (ctx.recommended_action_plan && ctx.recommended_action_plan.micro_intent) || ctx.micro_intent || rc.micro_intent || _r3cDraft.micro_intent || "");
  var _r3cBaseBC = String(_r3cAttr.baseline_broad_category || "");
  var _r3cBaseMI = String(_r3cAttr.baseline_micro_intent || "");
  var _r3cEffBC = String(_r3cAttr.effective_broad_category || ctx.category || rc.category || "");
  lines.push("Micro intent (effective): " + (_r3cEffMI || "N/A"));
  if ((_r3cBaseBC && _r3cEffBC && _r3cBaseBC !== _r3cEffBC) || (_r3cBaseMI && _r3cEffMI && _r3cBaseMI !== _r3cEffMI)) {
    lines.push("Classification corrected by learning: original " + (_r3cBaseBC || "?") + " / " + (_r3cBaseMI || "?") + " -> effective " + (_r3cEffBC || "?") + " / " + (_r3cEffMI || "?"));
  }'''

D_SRC_OLD = 'lines.push("Draft source: " + (_p4aHDSrc || "N/A"));'
D_SRC_NEW = '''lines.push("Draft source: " + (_p4aHDSrc || "N/A"));
  lines.push("Reply mode: " + (rc.reply_mode || (ctx.recommended_action_plan && ctx.recommended_action_plan.reply_mode) || "not recorded"));  // SL-PHASE-5Q-RUN3-UIVIS'''

D_MODE_OLD = 'lines.push("Draft mode: AI-generated draft for human review");'
D_MODE_NEW = 'lines.push("Draft mode: AI-generated draft for human review" + (_p4aHDAttempt.ok === true ? " (AI draft passed validation)" : ""));  // SL-PHASE-5Q-RUN3-UIVIS'


def patch_node(node, replacements, inserts_after):
    code = node["parameters"]["jsCode"]
    if MARKER in code:
        print(f"  SKIP {node['name']}: already patched ({MARKER} present)")
        return code, False
    for old, new in replacements:
        if old not in code:
            raise SystemExit(f"ANCHOR NOT FOUND in {node['name']}: {old[:90]}...")
        if code.count(old) != 1:
            raise SystemExit(f"ANCHOR NOT UNIQUE in {node['name']}: {old[:90]}...")
        code = code.replace(old, new)
    for anchor, insert in inserts_after:
        idx = code.find(anchor)
        if idx < 0:
            raise SystemExit(f"INSERT ANCHOR NOT FOUND in {node['name']}: {anchor[:90]}...")
        # insert after the end of the anchor's statement line
        line_end = code.find("\n", idx)
        code = code[:line_end] + "\n" + insert + code[line_end:]
    node["parameters"]["jsCode"] = code
    return code, True


def main():
    with open(WF, encoding="utf-8-sig") as f:
        wf = json.load(f)
    nodes = {n["name"]: n for n in wf["nodes"]}
    j = nodes["J. Render Review Form HTML"]
    d = nodes["D. Build Google Chat Notification Payload"]

    _, j_changed = patch_node(
        j,
        replacements=[(J_LABEL_OLD_1, J_LABEL_NEW_1), (J_LABEL_OLD_2, J_LABEL_NEW_2)],
        inserts_after=[(J_ANCHOR, J_INSERT)],
    )
    _, d_changed = patch_node(
        d,
        replacements=[(D_MI_OLD, D_MI_NEW), (D_SRC_OLD, D_SRC_NEW), (D_MODE_OLD, D_MODE_NEW)],
        inserts_after=[],
    )

    if not (j_changed or d_changed):
        print("No changes made.")
        return

    with open(WF, "w", encoding="utf-8") as f:
        json.dump(wf, f, indent=2, ensure_ascii=False)
    print(f"PATCHED {WF}: Node J changed={j_changed}, Node D(chat) changed={d_changed}")
    print("Run node --check on extracted node code before deploying.")


if __name__ == "__main__":
    main()
