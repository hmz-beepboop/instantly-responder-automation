"""SL-PHASE-5Q session 15: Decision Node D dense-paragraph reflow fix.

Root cause (live-proven, exec 5329): globally-scoped style policy 27293ea8
("short paragraphs") arms the dense-paragraph validator for every AI draft,
while the PROOF_REQUEST prompt instruction says "One concise paragraph".
Honest proof/trust answers routinely exceed 360 chars in one paragraph and
are rejected on style grounds only -> full fallback + AI_OUTPUT_VALIDATION_FAILED.

Patch A: intInstr.PROOF_REQUEST prompt now asks for 2-3 short paragraphs.
Patch B: style-only dense-paragraph rejections are repaired by a
         whitespace-only sentence-boundary reflow, then the FULL validator
         re-runs. Safety errors still fall back unchanged.
Patch B3: reflow recorded truthfully in persisted ai_attempt metadata.

Run from repo root: python scripts/SL-PHASE-5Q-apply-dense-reflow-fix.py
"""
import io
import json

PATH = "workflows/production_decision_current.json"

with io.open(PATH, encoding="utf-8-sig") as f:
    wf = json.load(f)

node = next(n for n in wf["nodes"] if n["name"].startswith("D."))
code = node["parameters"]["jsCode"]

# --- Patch A: intInstr.PROOF_REQUEST prompt wording ---
OLD_A = (
    "State honestly: early-stage engagement with no public customer examples "
    "or validation signal yet. The 10-minute call is the transparent "
    "evaluation step. One concise paragraph. No invented track record."
)
NEW_A = (
    "State honestly: early-stage engagement with no public customer examples "
    "or validation signal yet. The 10-minute call is the transparent "
    "evaluation step. Use 2-3 short paragraphs separated by blank lines, "
    "each under 300 characters; put the call invitation in its own final "
    "short paragraph. No invented track record."
)
assert code.count(OLD_A) == 1, f"Patch A anchor count: {code.count(OLD_A)}"
code = code.replace(OLD_A, NEW_A)

# --- Patch B1: _5qReflowDenseParagraphs helper ---
ANCHOR_B1 = (
    "function buildPolicyAwareFallback(microIntent, deterministicText, "
    "firstName, senderName, bookingLink, behaviouralGuidance, prospectText) {"
)
HELPER = r"""// SL-PHASE-5Q-DENSE-REFLOW: split paragraphs above the dense threshold at sentence
// boundaries. Whitespace-only change; wording is never added, removed, or altered.
function _5qReflowDenseParagraphs(text) {
  const paras = String(text || '').split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
  const out = [];
  for (const p of paras) {
    const lines = p.split(/\n/).map(l => l.trim()).filter(Boolean);
    const hasListStructure = lines.some(l => /^(?:[-*]|\d+[.)])\s+/.test(l));
    if (hasListStructure || p.length <= 300) { out.push(p); continue; }
    const sentences = p.split(/(?<=[.!?])\s+/).filter(Boolean);
    let cur = '';
    for (const s of sentences) {
      if (cur && (cur.length + 1 + s.length) > 300) { out.push(cur); cur = s; }
      else { cur = cur ? cur + ' ' + s : s; }
    }
    if (cur) out.push(cur);
  }
  return out.join('\n\n');
}

""".replace("\r\n", "\n")
assert code.count(ANCHOR_B1) == 1, "Patch B1 anchor not unique"
assert "_5qReflowDenseParagraphs" not in code, "Patch B1 already applied"
code = code.replace(ANCHOR_B1, HELPER + ANCHOR_B1)

# --- Patch B2: style-only reflow retry in the AI validation block ---
OLD_B2 = (
    "    if (aiResult.ok && aiResult.draft_text) {\n"
    "      const errs = validateAI(aiResult.draft_text, microIntent, "
    "behaviouralGuidance, replyText);\n"
    "      if (errs.length === 0) {"
)
NEW_B2 = (
    "    if (aiResult.ok && aiResult.draft_text) {\n"
    "      let errs = validateAI(aiResult.draft_text, microIntent, "
    "behaviouralGuidance, replyText);\n"
    "      // SL-PHASE-5Q-DENSE-REFLOW: a dense-paragraph rejection is a repairable\n"
    "      // formatting issue, not a safety failure. Reflow at sentence boundaries\n"
    "      // (whitespace-only), then re-run the FULL validator. Any safety error\n"
    "      // still falls back unchanged.\n"
    "      if (errs.length > 0 && errs.every(x => x === 'active policy violation: dense paragraph')) {\n"
    "        const _reflowed = _5qReflowDenseParagraphs(aiResult.draft_text);\n"
    "        const _reflowErrs = validateAI(_reflowed, microIntent, behaviouralGuidance, replyText);\n"
    "        if (_reflowErrs.length === 0) {\n"
    "          aiResult = { ...aiResult, draft_text: _reflowed, style_reflow_applied: true, "
    "raw_draft_text_before_reflow: aiResult.draft_text };\n"
    "          aiAttempt = aiResult;\n"
    "          errs = _reflowErrs;\n"
    "        }\n"
    "      }\n"
    "      if (errs.length === 0) {"
)
assert code.count(OLD_B2) == 1, "Patch B2 anchor not unique"
code = code.replace(OLD_B2, NEW_B2)

# --- Patch B3: persist reflow truthfully in ai_attempt output ---
OLD_B3 = (
    "      fallback_reason:   aiAttempt.fallback_reason     || null,\n"
    "      raw_draft_text:    aiAttempt.draft_text          || null\n"
    "    } : null,"
)
NEW_B3 = (
    "      fallback_reason:   aiAttempt.fallback_reason     || null,\n"
    "      raw_draft_text:    aiAttempt.draft_text          || null,\n"
    "      style_reflow_applied: aiAttempt.style_reflow_applied === true,\n"
    "      raw_draft_text_before_reflow: aiAttempt.raw_draft_text_before_reflow || null\n"
    "    } : null,"
)
assert code.count(OLD_B3) == 1, "Patch B3 anchor not unique"
code = code.replace(OLD_B3, NEW_B3)

node["parameters"]["jsCode"] = code
with io.open(PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(wf, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("Decision Node D patched OK. New code length:", len(code))
