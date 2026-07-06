"""SL-PHASE-5Q session 15: HumanApproval Node J fallback banner detail.

The ai_failed_fallback banner previously showed only the coarse reason
(AI_OUTPUT_VALIDATION_FAILED), which reads as if the AI produced something
unsafe. Live evidence (exec 5329) shows most rejections on proof/trust cases
were style-only (dense paragraph). The banner now names the exact failed
check(s) and says explicitly when the rejection was formatting/style only,
not a content-safety failure. Internal metadata is unchanged and truthful.

Run from repo root: python scripts/SL-PHASE-5Q-apply-fallback-banner-detail.py
"""
import io
import json

PATH = "workflows/production_humanapproval_current.json"

with io.open(PATH, encoding="utf-8-sig") as f:
    wf = json.load(f)

node = next(n for n in wf["nodes"] if n["name"].startswith("J."))
code = node["parameters"]["jsCode"]

OLD = (
    "  } else if ((_p4aDSRaw || _p4aDS) === 'ai_failed_fallback') {\n"
    "    html += \"<p style=\\\"background:#fff3cd;border:1px solid #ffc107;"
    "padding:10px;border-radius:4px\\\"><strong>Safe fallback draft for human "
    "review. AI draft was rejected by validation\" + (_5q7FallbackReason ? "
    "(\" (\" + escapeHtml(_5q7FallbackReason) + \")\") : \"\") + \". Edit "
    "before approving. Do not invent proof, customer examples, case studies, "
    "results, pricing, contract terms, data guarantees, or claims not yet "
    "proven.</strong></p>\";\n"
)
NEW = (
    "  } else if ((_p4aDSRaw || _p4aDS) === 'ai_failed_fallback') {\n"
    "    // SL-PHASE-5Q-BANNER-DETAIL: name the exact failed check(s); say when the\n"
    "    // rejection was style-only so the banner is not misleadingly alarming.\n"
    "    var _5q7ValErrs = (_p4aAttempt.validation_errors || []).filter(Boolean).map(String);\n"
    "    var _5q7StyleOnlySet = ['active policy violation: dense paragraph', 'active policy violation: malformed acknowledgement'];\n"
    "    var _5q7StyleOnly = _5q7ValErrs.length > 0 && _5q7ValErrs.every(function(e){ return _5q7StyleOnlySet.indexOf(e) >= 0; });\n"
    "    html += \"<p style=\\\"background:#fff3cd;border:1px solid #ffc107;"
    "padding:10px;border-radius:4px\\\"><strong>Safe fallback draft for human "
    "review. \" + (_5q7StyleOnly ? \"The AI draft failed a formatting/style "
    "check only (not a content-safety check)\" : \"AI draft was rejected by "
    "validation\") + (_5q7FallbackReason ? (\" (\" + "
    "escapeHtml(_5q7FallbackReason) + \")\") : \"\") + "
    "(_5q7ValErrs.length ? (\". Failed check(s): \" + "
    "escapeHtml(_5q7ValErrs.join(\"; \"))) : \"\") + \". Edit "
    "before approving. Do not invent proof, customer examples, case studies, "
    "results, pricing, contract terms, data guarantees, or claims not yet "
    "proven.</strong></p>\";\n"
)
assert code.count(OLD) == 1, f"Banner anchor count: {code.count(OLD)}"
code = code.replace(OLD, NEW)

node["parameters"]["jsCode"] = code
with io.open(PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(wf, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("HumanApproval Node J banner patched OK. New code length:", len(code))
