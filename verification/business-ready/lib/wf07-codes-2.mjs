// Continuation of code-node source for workflow 07 (review form + submit path).

const HELPERS = [
  'function escapeHtml(value) {',
  '  return String(value == null ? "" : value)',
  '    .replace(/&/g, "&amp;")',
  '    .replace(/</g, "&lt;")',
  '    .replace(/>/g, "&gt;")',
  '    .replace(/"/g, "&quot;")',
  "    .replace(/'/g, '&#39;');",
  '}'
].join('\n');

// H. Validate Review Token (GET) - runs after a Data Table "get rows by case_id" lookup.
export function nodeH_ValidateTokenGet() {
  return [
    'const items = $input.all();',
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const query = (input.query) || (input.webhook && input.webhook.query) || {};',
    '  const caseId = String(query.case || "");',
    '  const token = String(query.token || "");',
    '',
    '  const row = input.case_row || null;',
    '',
    '  let tokenValid = true;',
    '  let reason = "OK";',
    '',
    '  if (!row) { tokenValid = false; reason = "CASE_NOT_FOUND"; }',
    '  else if (!token || row.token !== token) { tokenValid = false; reason = "WRONG_TOKEN"; }',
    '  else if (row.status !== "NEW" && row.status !== "IN_REVIEW") { tokenValid = false; reason = "ALREADY_DECIDED"; }',
    '  else if (row.token_expires_at && new Date(row.token_expires_at).getTime() < Date.now()) { tokenValid = false; reason = "EXPIRED"; }',
    '',
    '  return {',
    '    json: {',
    '      ...input,',
    '      case_id: caseId,',
    '      token,',
    '      token_valid: tokenValid,',
    '      token_invalid_reason: reason,',
    '      review_case: row || {}',
    '    }',
    '  };',
    '});'
  ].join('\n');
}

// J. Render Review Form HTML (token valid).
export function nodeJ_RenderForm() {
  return [
    'const items = $input.all();',
    '',
    HELPERS,
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const rc = input.review_case || {};',
    '  const ctx = rc.sanitized_context || {};',
    '  const tv = rc.template_variables || {};',
    '  const blocked = rc.blocked_variables || [];',
    '',
    '  let html = "";',
    '  html += "<!DOCTYPE html><html><head><meta charset=\\"utf-8\\"><title>HMZ Reply Review</title></head><body>";',
    '  html += "<h1>Reply review - " + escapeHtml(rc.case_id) + "</h1>";',
    '  html += "<p><strong>Category:</strong> " + escapeHtml(ctx.category) + " | <strong>Urgency:</strong> " + escapeHtml(ctx.urgency) + "</p>";',
    '  html += "<p><strong>Risk flags:</strong> " + escapeHtml((ctx.risk_flags || []).join(", ")) + "</p>";',
    '  html += "<p><strong>Subject:</strong> " + escapeHtml(ctx.reply_subject) + "</p>";',
    '  html += "<p><strong>Incoming reply:</strong></p><pre>" + escapeHtml(ctx.reply_text) + "</pre>";',
    '  if (blocked.length > 0) {',
    '    html += "<p style=\\"color:red\\"><strong>Blocked variables (send disabled until resolved):</strong> " + escapeHtml(blocked.join(", ")) + "</p>";',
    '  }',
    '  html += "<form method=\\"POST\\" action=\\"submit?case=" + encodeURIComponent(rc.case_id) + "&token=" + encodeURIComponent(rc.token) + "\\">";',
    '  html += "<input type=\\"hidden\\" name=\\"case_id\\" value=\\"" + escapeHtml(rc.case_id) + "\\">";',
    '  html += "<input type=\\"hidden\\" name=\\"token\\" value=\\"" + escapeHtml(rc.token) + "\\">";',
    '  html += "<label>Reply text (editable):<br><textarea name=\\"edited_reply_text\\" rows=\\"10\\" cols=\\"80\\">" + escapeHtml(rc.draft_text) + "</textarea></label><br>";',
    '  html += "<label>Approver name/email: <input type=\\"text\\" name=\\"approver_identity\\" required></label><br>";',
    '  html += "<label>Denial reason (if denying): <input type=\\"text\\" name=\\"denial_reason\\"></label><br>";',
    '  html += "<button type=\\"submit\\" name=\\"action\\" value=\\"approve\\"" + (blocked.length > 0 ? " disabled" : "") + ">Approve and send</button> ";',
    '  html += "<button type=\\"submit\\" name=\\"action\\" value=\\"deny\\">Deny / no reply</button>";',
    '  html += "</form></body></html>";',
    '',
    '  return { json: { ...input, html } };',
    '});'
  ].join('\n');
}

// J2. Render Token Error Page (token invalid/expired/used/not found).
export function nodeJ2_RenderError() {
  return [
    'const items = $input.all();',
    '',
    HELPERS,
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const reason = input.token_invalid_reason || "INVALID";',
    '  const messages = {',
    '    CASE_NOT_FOUND: "This review case could not be found.",',
    '    WRONG_TOKEN: "This review link is invalid.",',
    '    ALREADY_DECIDED: "This review case has already been decided.",',
    '    EXPIRED: "This review link has expired. Ask the operator to re-issue a notification."',
    '  };',
    '  const message = messages[reason] || "This review link is no longer valid.";',
    '  const html = "<!DOCTYPE html><html><body><h1>Review link unavailable</h1><p>" + escapeHtml(message) + "</p></body></html>";',
    '  return { json: { ...input, html, http_status: reason === "CASE_NOT_FOUND" ? 404 : 410 } };',
    '});'
  ].join('\n');
}

// L. Validate & Consume Review Token (POST) - runs after Data Table get-rows lookup by case_id.
export function nodeL_ValidateTokenPost() {
  return [
    'const items = $input.all();',
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const body = input.body || (input.webhook && input.webhook.body) || {};',
    '  const query = input.query || (input.webhook && input.webhook.query) || {};',
    '  const caseId = String(body.case_id || query.case || "");',
    '  const token = String(body.token || query.token || "");',
    '',
    '  const row = input.case_row || null;',
    '',
    '  let tokenValid = true;',
    '  let reason = "OK";',
    '',
    '  if (!row) { tokenValid = false; reason = "CASE_NOT_FOUND"; }',
    '  else if (!token || row.token !== token) { tokenValid = false; reason = "WRONG_TOKEN"; }',
    '  else if (row.status !== "NEW" && row.status !== "IN_REVIEW") { tokenValid = false; reason = "ALREADY_DECIDED"; }',
    '  else if (row.token_expires_at && new Date(row.token_expires_at).getTime() < Date.now()) { tokenValid = false; reason = "EXPIRED"; }',
    '',
    '  return {',
    '    json: {',
    '      ...input,',
    '      case_id: caseId,',
    '      token,',
    '      token_valid: tokenValid,',
    '      token_invalid_reason: reason,',
    '      review_case: row || {},',
    '      submit_action: String(body.action || ""),',
    '      submit_edited_text: String(body.edited_reply_text || ""),',
    '      submit_approver_identity: String(body.approver_identity || ""),',
    '      submit_denial_reason: String(body.denial_reason || "")',
    '    }',
    '  };',
    '});'
  ].join('\n');
}

// N. Process Reviewer Decision (token valid).
export function nodeN_ProcessDecision() {
  return [
    'const items = $input.all();',
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const rc = { ...(input.review_case || {}) };',
    '  const action = input.submit_action === "approve" ? "approve" : "deny";',
    '  const approver = input.submit_approver_identity || "";',
    '  const blocked = rc.blocked_variables || [];',
    '  const nowIso = new Date().toISOString();',
    '',
    '  let finalAction = action;',
    '  if (action === "approve" && blocked.length > 0) finalAction = "blocked";',
    '  if (action === "approve" && !approver) finalAction = "blocked";',
    '',
    '  if (finalAction === "approve") {',
    '    rc.status = "RESPONSE_APPROVED";',
    '    rc.approver_identity = approver;',
    '    rc.approved_at = nowIso;',
    '    rc.final_reply_text = input.submit_edited_text || rc.draft_text || "";',
    '    rc.decision_payload = { action: "approve", approver, decided_at: nowIso };',
    '  } else if (finalAction === "blocked") {',
    '    rc.status = "BLOCKED_MISSING_VARIABLES";',
    '    rc.approver_identity = approver || null;',
    '    rc.decision_payload = { action: "blocked", blocked_variables: blocked, decided_at: nowIso, attempted_by: approver || null };',
    '  } else {',
    '    rc.status = "NO_REPLY_REQUIRED";',
    '    rc.approver_identity = approver || null;',
    '    rc.approved_at = nowIso;',
    '    rc.decision_payload = { action: "deny", approver: approver || null, reason: input.submit_denial_reason || null, decided_at: nowIso };',
    '  }',
    '  rc.updated_at = nowIso;',
    '',
    '  return { json: { ...input, review_case: rc, final_action: finalAction } };',
    '});'
  ].join('\n');
}

// N2. Render Submit Token Error.
export function nodeN2_SubmitTokenError() {
  return [
    'const items = $input.all();',
    '',
    HELPERS,
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const reason = input.token_invalid_reason || "INVALID";',
    '  const messages = {',
    '    CASE_NOT_FOUND: "This review case could not be found.",',
    '    WRONG_TOKEN: "This review link is invalid.",',
    '    ALREADY_DECIDED: "This review case has already been decided. No second submission is accepted.",',
    '    EXPIRED: "This review link has expired."',
    '  };',
    '  const message = messages[reason] || "This review link is no longer valid.";',
    '  const html = "<!DOCTYPE html><html><body><h1>Submission rejected</h1><p>" + escapeHtml(message) + "</p></body></html>";',
    '  return { json: { ...input, html, http_status: reason === "CASE_NOT_FOUND" ? 404 : 409 } };',
    '});'
  ].join('\n');
}

// Q2. Build Non-Send Terminal Result (deny / blocked).
export function nodeQ2_NonSendTerminal() {
  return [
    'const items = $input.all();',
    '',
    HELPERS,
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const rc = input.review_case || {};',
    '  let html = "<!DOCTYPE html><html><body><h1>Recorded</h1>";',
    '  if (rc.status === "BLOCKED_MISSING_VARIABLES") {',
    '    html += "<p>Approval blocked: missing required variables (" + escapeHtml((rc.blocked_variables || []).join(", ")) + "). No reply was sent.</p>";',
    '  } else {',
    '    html += "<p>No reply will be sent for case " + escapeHtml(rc.case_id) + ". Status: " + escapeHtml(rc.status) + "</p>";',
    '  }',
    '  html += "</body></html>";',
    '  return { json: { ...input, html, http_status: 200 } };',
    '});'
  ].join('\n');
}

// R. Build Approved Send Result Page (after Reply Sender handoff returns).
export function nodeR_ApprovedResultPage() {
  return [
    'const items = $input.all();',
    '',
    HELPERS,
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const rc = input.review_case || {};',
    '  let html = "<!DOCTYPE html><html><body><h1>Approved</h1>";',
    '  html += "<p>Case " + escapeHtml(rc.case_id) + " approved by " + escapeHtml(rc.approver_identity) + ". Handed off to the Reply Sender.</p>";',
    '  if (input.sender_result) {',
    '    html += "<p>Sender result: " + escapeHtml(JSON.stringify(input.sender_result.terminal_status || input.sender_result)) + "</p>";',
    '  }',
    '  html += "</body></html>";',
    '  return { json: { ...input, html, http_status: 200 } };',
    '});'
  ].join('\n');
}
