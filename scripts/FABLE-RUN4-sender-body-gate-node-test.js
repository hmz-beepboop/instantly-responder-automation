// FABLE-RUN4-SENDER-BODY-GATE behavioural test.
// Executes the REAL patched Sender node B and node O code (extracted from
// workflows/production_sender_current.json) in Node.js with mock $input items.
// No network, no n8n, no Instantly POST — pure in-process evaluation.
// Usage: node scripts/FABLE-RUN4-sender-body-gate-node-test.js <extracted_b.js> <extracted_o.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const [, , bPath, oPath] = process.argv;
const bCode = fs.readFileSync(bPath, 'utf8');
const oCode = fs.readFileSync(oPath, 'utf8');

function runNode(code, items) {
  const sandbox = {
    $input: { all: () => items.map((j) => ({ json: j })) },
    console,
  };
  vm.createContext(sandbox);
  // n8n Code nodes end with a top-level `return`; wrap in a function.
  const wrapped = `(function () {\n${code}\n})()`;
  return vm.runInContext(wrapped, sandbox, { timeout: 5000 });
}

function baseSenderInput(draftText) {
  return {
    sender_validation: { valid: true },
    validation: { valid: true },
    approval: { approved: true, approver_identity: 'humza@hmzaiautomation.com', approved_at: '2026-07-07T00:00:00Z', case_id: 'case-test' },
    decision: { reply_permitted: true, human_review_required: true },
    nes: {
      intake_id: 'intake-test',
      campaign_id: '531e64ed-c225-4baf-97a9-4ec90dc34eb0',
      workspace_id: 'c7f84f11-4a1a-42dc-9a74-a417e44cb87e',
      eaccount: 'hamzah@teamhmzautomations.com',
      lead_email: 'lead@example.com',
      reply: { subject: 'Re: test' },
      threading: { reply_to_uuid: 'uuid-test' },
    },
    draft: { draft_text: draftText },
    gates: { draft_variable_gate_passed: true },
    acquisition: { acquired: true, priorState: null, sendKey: 'send-test' },
    suppression_verification: { verified: true },
  };
}

let pass = 0, fail = 0;
function check(name, cond) {
  if (cond) { pass++; console.log('PASS ' + name); }
  else { fail++; console.log('FAIL ' + name); }
}

// ---- Node B: pre-lock gate --------------------------------------------------
const bCases = [
  ['missing (undefined)', undefined, false],
  ['null', null, false],
  ['empty string', '', false],
  ['whitespace-only', '   \n\t  \r\n ', false],
  ['marker-comment-only', '<!-- hmz-send-key:send-abc -->', false],
  ['html-empty', '<div><br><br></div>', false],
  ['nbsp-only', '&nbsp;&nbsp; ', false],
  ['zero-width-only', '​﻿‍', false],
  ['valid text', 'Thanks for your reply. Here is the booking link.', true],
  ['valid text with marker', 'Real body text.<!-- hmz-send-key:send-abc -->', true],
];

for (const [label, draftText, expectPass] of bCases) {
  const out = runNode(bCode, [baseSenderInput(draftText)]);
  const g = out[0].json.gates;
  check(`Node B ${label}: draft_body_gate_passed=${expectPass}`, g.draft_body_gate_passed === expectPass);
  check(`Node B ${label}: gates.passed=${expectPass}`, g.passed === expectPass);
  if (!expectPass) {
    check(`Node B ${label}: reason listed`, (g.reasons || []).includes('draft_body_missing_or_blank'));
    check(`Node B ${label}: fix instruction present`, typeof g.draft_body_fix_instruction === 'string' && g.draft_body_fix_instruction.includes('re-approve'));
  }
}

// edited_reply_text fallback precedence must mirror node Q: draft empty but
// body.edited_reply_text present -> effective body non-empty -> pass
const fallbackInput = baseSenderInput('');
fallbackInput.body = { edited_reply_text: 'Edited reply text used by node Q.' };
const fbOut = runNode(bCode, [fallbackInput]);
check('Node B edited_reply_text fallback passes (mirrors node Q precedence)', fbOut[0].json.gates.draft_body_gate_passed === true);

// pre-existing gates unaffected: unresolved token still blocks
const tokenInput = baseSenderInput('Hello <<firstName_missing_var>> body');
const tokOut = runNode(bCode, [tokenInput]);
check('Node B unresolved-variable gate still works', tokOut[0].json.gates.draft_variable_gate_passed === false);

// ---- Node O: 15th gate pre-POST --------------------------------------------
for (const [label, draftText, expectPass] of bCases) {
  const out = runNode(oCode, [baseSenderInput(draftText)]);
  const lsg = out[0].json.live_send_gates;
  const bodyGate = lsg.gates.find((g) => g.id === 'draft_body_non_empty');
  check(`Node O ${label}: draft_body_non_empty=${expectPass}`, !!bodyGate && bodyGate.passed === expectPass);
  check(`Node O ${label}: all_passed=${expectPass}`, lsg.all_passed === expectPass);
  if (!expectPass) {
    check(`Node O ${label}: failed_gate_ids contains draft_body_non_empty`, lsg.failed_gate_ids.includes('draft_body_non_empty'));
    check(`Node O ${label}: block reason DRAFT_BODY_MISSING_OR_BLANK`, bodyGate.reason === 'DRAFT_BODY_MISSING_OR_BLANK');
  }
}

// Node O gate count: 14 original + 1 new = 15
const oOut = runNode(oCode, [baseSenderInput('Valid body')]);
check('Node O has exactly 15 gates', oOut[0].json.live_send_gates.gates.length === 15);

// Valid path fully green end-to-end on both nodes (no regression)
const validB = runNode(bCode, [baseSenderInput('Valid body text.')]);
const validO = runNode(oCode, [baseSenderInput('Valid body text.')]);
check('Valid path: Node B all gates pass', validB[0].json.gates.passed === true);
check('Valid path: Node O all 15 gates pass', validO[0].json.live_send_gates.all_passed === true);

console.log(`\nRESULT: ${pass} PASS / ${fail} FAIL`);
process.exit(fail === 0 ? 0 : 1);
