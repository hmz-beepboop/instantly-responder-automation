// Business-ready offline build: patches applied to workflows 01-05.
// Each patch function mutates a parsed workflow JSON object in place and
// returns it. Patches are additive/renaming where possible to preserve the
// previously-validated graph shape.

import crypto from 'node:crypto';

function uid() {
  return crypto.randomUUID();
}

function renameNode(workflow, oldName, newName) {
  const node = workflow.nodes.find((n) => n.name === oldName);
  if (!node) throw new Error(`renameNode: node not found: ${oldName}`);
  node.name = newName;

  if (workflow.connections[oldName]) {
    workflow.connections[newName] = workflow.connections[oldName];
    delete workflow.connections[oldName];
  }

  for (const fromName of Object.keys(workflow.connections)) {
    for (const output of workflow.connections[fromName].main || []) {
      for (const edge of output) {
        if (edge.node === oldName) edge.node = newName;
      }
    }
  }

  return node;
}

function connect(workflow, fromName, toName, fromOutput = 0) {
  workflow.connections[fromName] = workflow.connections[fromName] || { main: [] };
  const main = workflow.connections[fromName].main;
  while (main.length <= fromOutput) main.push([]);
  main[fromOutput].push({ node: toName, type: 'main', index: 0 });
}

function replaceConnectionsTarget(workflow, fromName, oldTarget, newTarget) {
  const entry = workflow.connections[fromName];
  if (!entry) return;
  for (const output of entry.main || []) {
    for (const edge of output) {
      if (edge.node === oldTarget) edge.node = newTarget;
    }
  }
}

function codeNode(name, position, jsCode) {
  return {
    id: uid(),
    name,
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position,
    parameters: { jsCode }
  };
}

function ifNode(name, position, expression) {
  return {
    id: uid(),
    name,
    type: 'n8n-nodes-base.if',
    typeVersion: 2.2,
    position,
    parameters: {
      conditions: {
        options: { version: 2, leftValue: '', caseSensitive: true, typeValidation: 'strict' },
        combinator: 'and',
        conditions: [
          {
            id: 'cond-1',
            leftValue: expression,
            rightValue: '',
            operator: { type: 'boolean', operation: 'true', singleValue: true }
          }
        ]
      },
      options: {}
    }
  };
}

function googleChatHttpNode(name, position, options = {}) {
  const node = {
    id: uid(),
    name,
    type: 'n8n-nodes-base.httpRequest',
    typeVersion: 4.2,
    position,
    parameters: {
      method: 'POST',
      url: '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}',
      sendBody: true,
      specifyBody: 'json',
      jsonBody: '={{ JSON.stringify($json.chat_notification.payload) }}',
      options: { timeout: 5000 }
    }
  };
  const onError = Object.prototype.hasOwnProperty.call(options, 'onError') ? options.onError : 'continueRegularOutput';
  if (onError !== undefined) node.onError = onError;
  return node;
}

function singleReplace(haystack, oldStr, newStr, label) {
  if (haystack.indexOf(oldStr) === -1) {
    throw new Error(`patch target not found: ${label}`);
  }
  if (haystack.indexOf(oldStr) !== haystack.lastIndexOf(oldStr)) {
    throw new Error(`patch target not unique: ${label}`);
  }
  return haystack.replace(oldStr, newStr);
}

// ---------------------------------------------------------------------------
// Workflow 01 - Reply Intake: route every non-duplicate item to the new
// durable Human Approval workflow (07) instead of calling the Reply Sender
// (03) directly. The Sender's existing approval gate
// (gates.approval_gate_passed = input.approval.approved === true) can then
// only become true via 07's reviewer-approved handoff.
// ---------------------------------------------------------------------------
export function patchWorkflow01(workflow) {
  const node = renameNode(workflow, 'H. Reply Sender Handoff', 'H. Human Approval Handoff');

  node.parameters.workflowId = {
    mode: 'list',
    value: '__PLACEHOLDER_HUMAN_APPROVAL_WORKFLOW_ID__',
    cachedResultName: 'HMZ - Reply Human Approval - Validation'
  };
  node.parameters.workflowInputs = {
    mappingMode: 'defineBelow',
    value: {
      case_input: '={{ $json }}'
    }
  };

  return workflow;
}

// ---------------------------------------------------------------------------
// Workflow 02 - Reply Decision Engine:
//  (a) rename and re-base the mock semantic classifier on a deterministic,
//      honestly-named heuristic, add classifier_version + decision_trace, and
//      add a non-English -> AMBIGUOUS/T15 fallback (policy-HMZ-1.2 section 15).
//  (b) add a new "Safety Action Plan" node (between Draft Preparation and
//      Output Validation) that builds gated, idempotent suppression-action
//      contracts (source-campaign stop, interest-status update, exact-email
//      blocklist) independent of and prior to the prospect-reply approval
//      gate, per the suppression_action_enablement flags in
//      config/business-ready.config.json.
// ---------------------------------------------------------------------------
export function patchWorkflow02(workflow, config) {
  // (a) classifier
  const classifierNode = renameNode(workflow, 'B. Mock Semantic Classifier', 'B. Deterministic Reply Classifier');
  renameNode(workflow, 'Section B - Mock Semantic Classifier (notes)', 'Section B - Deterministic Reply Classifier (notes)');

  let code = classifierNode.parameters.jsCode;

  code = code.split('mockSemanticClassify').join('deterministicHeuristicClassify');

  code = singleReplace(
    code,
    "  const classifierInputs = {\n    model: 'mock',",
    "  const classifierInputs = {\n    model: 'deterministic-heuristic-1.0',",
    '02:classifierInputs.model'
  );

  const oldDecisionBlock = [
    '  let result;',
    '',
    '  if (det.noop_match === true) {',
    '    result = { category: null, confidence: 1, evidence: [`operational rule ${det.rule_id} matched - no classification needed`] };',
    '  } else if (det.deterministic_match === true) {',
    '    result = { category: det.category, confidence: 1, evidence: [`deterministic rule ${det.rule_id} matched`] };',
    '  } else {',
    '    result = deterministicHeuristicClassify(combined);',
    '  }',
    '',
    '  const category = result.category;'
  ].join('\n');

  const newDecisionBlock = [
    '  let result;',
    '  let decisionPath;',
    '',
    "  const replyLanguage = String(reply.language || '').toLowerCase();",
    "  const isEnglishLanguage = !replyLanguage || replyLanguage === 'en' || replyLanguage === 'eng' || replyLanguage.startsWith('en-');",
    '',
    '  if (det.noop_match === true) {',
    '    result = { category: null, confidence: 1, evidence: [`operational rule ${det.rule_id} matched - no classification needed`] };',
    "    decisionPath = 'OPERATIONAL_NOOP';",
    '  } else if (det.deterministic_match === true) {',
    '    result = { category: det.category, confidence: 1, evidence: [`deterministic rule ${det.rule_id} matched`] };',
    "    decisionPath = 'DETERMINISTIC_RULE';",
    '  } else if (!isEnglishLanguage) {',
    '    result = {',
    "      category: 'AMBIGUOUS',",
    '      confidence: 0.3,',
    "      evidence: [`non-English reply (language=${replyLanguage || 'unknown'}) routed to AMBIGUOUS per policy-HMZ-1.2 section 15`]",
    '    };',
    "    decisionPath = 'NON_ENGLISH_FALLBACK_T15';",
    '  } else {',
    '    result = deterministicHeuristicClassify(combined);',
    "    decisionPath = 'DETERMINISTIC_HEURISTIC_CLASSIFIER';",
    '  }',
    '',
    '  const category = result.category;',
    '',
    '  const decisionTrace = {',
    '    path: decisionPath,',
    '    rule_id: det.rule_id || null,',
    "    language: replyLanguage || 'unknown',",
    "    classifier_version: 'deterministic-heuristic-1.0',",
    "    policy_version: nes.policy_version || 'policy-HMZ-1.2'",
    '  };'
  ].join('\n');

  code = singleReplace(code, oldDecisionBlock, newDecisionBlock, '02:decision-block');

  code = singleReplace(
    code,
    '    category,\n    confidence: result.confidence,\n    evidence: result.evidence,\n',
    "    category,\n    confidence: result.confidence,\n    evidence: result.evidence,\n    classifier_version: 'deterministic-heuristic-1.0',\n    decision_trace: decisionTrace,\n",
    '02:classifier-object'
  );

  classifierNode.parameters.jsCode = code;

  // (b) safety action plan node, inserted between D and E
  renameNode(workflow, 'D. Mock Draft Preparation', 'D. Draft Preparation (Templates / Human Draft)');
  renameNode(workflow, 'Section D - Mock Draft Preparation (notes)', 'Section D - Draft Preparation (notes)');

  const draftNode = workflow.nodes.find((n) => n.name === 'D. Draft Preparation (Templates / Human Draft)');
  const validationNode = workflow.nodes.find((n) => n.name === 'E. Output Validation');

  const safetyNode = codeNode(
    'F. Safety Action Plan (Gated Contract, Pre-Approval)',
    [draftNode.position[0] + 280, draftNode.position[1] + 200],
    buildSafetyActionPlanCode(config)
  );

  workflow.nodes.push(safetyNode);
  replaceConnectionsTarget(workflow, draftNode.name, validationNode.name, safetyNode.name);
  connect(workflow, safetyNode.name, validationNode.name);

  return workflow;
}

function buildSafetyActionPlanCode(config) {
  const enablement = config.suppression_action_enablement || {};
  const enablementJson = JSON.stringify({
    source_campaign_stop_enabled: !!enablement.source_campaign_stop_enabled,
    interest_status_update_enabled: !!enablement.interest_status_update_enabled,
    subsequence_removal_enabled: !!enablement.subsequence_removal_enabled,
    exact_email_blocklist_enabled: !!enablement.exact_email_blocklist_enabled
  });

  return [
    'const items = $input.all();',
    '',
    'const SUPPRESSION_ACTION_ENABLEMENT = ' + enablementJson + ';',
    '',
    "const DNC_SCOPES = ['WORKSPACE_DNC', 'ORGANISATION_DNC', 'GLOBAL_BLOCKLIST'];",
    '',
    'function buildSafetyActionPlan(input) {',
    '  const nes = input.nes || {};',
    '  const decision = input.decision || {};',
    '  const campaign = nes.campaign_context || {};',
    '  const actions = [];',
    '',
    '  if (decision.stop_active_sequence === true) {',
    '    actions.push({',
    "      action: 'STOP_ACTIVE_SEQUENCE',",
    '      enabled: SUPPRESSION_ACTION_ENABLEMENT.subsequence_removal_enabled,',
    '      request_contract: {',
    "        method: 'POST',",
    "        url: 'https://api.instantly.ai/api/v2/leads/subsequence/remove',",
    '        body: { campaign_id: campaign.campaign_id || null, lead_email: nes.lead_email || null },',
    '      },',
    '    });',
    '    actions.push({',
    "      action: 'UPDATE_INTEREST_STATUS',",
    '      enabled: SUPPRESSION_ACTION_ENABLEMENT.interest_status_update_enabled,',
    '      request_contract: {',
    "        method: 'POST',",
    "        url: 'https://api.instantly.ai/api/v2/leads/update-interest-status',",
    '        body: { campaign_id: campaign.campaign_id || null, lead_email: nes.lead_email || null, interest_status: decision.category || null },',
    '      },',
    '    });',
    '  }',
    '',
    '  if (DNC_SCOPES.includes(decision.address_suppression_intent)) {',
    '    actions.push({',
    "      action: 'ADD_TO_BLOCKLIST',",
    '      scope: decision.address_suppression_intent,',
    '      enabled: SUPPRESSION_ACTION_ENABLEMENT.exact_email_blocklist_enabled,',
    '      request_contract: {',
    "        method: 'POST',",
    "        url: 'https://api.instantly.ai/api/v2/blocklist',",
    '        body: { entries: [nes.lead_email || null] },',
    '      },',
    '    });',
    '  }',
    '',
    '  const plannedActions = actions.map((a) => ({',
    '    ...a,',
    '    executed: false,',
    "    verification_status: a.enabled ? 'PLANNED_AWAITING_LIVE_GATE' : 'SUPPRESSION_ACTION_DISABLED_BY_CONFIG',",
    '  }));',
    '',
    '  return {',
    "    schema_version: '1.0',",
    '    required: plannedActions.length > 0,',
    '    actions: plannedActions,',
    "    execution_order: 'BEFORE_REPLY_APPROVAL_GATE',",
    "    note: 'Required suppression actions are planned and contract-defined here, independent of and prior to the prospect-reply human-approval gate (workflow 07) and the reply send gates (workflow 03). Real HTTP execution remains additionally gated by suppression_action_enablement, dry_run and live_credential_readiness.',",
    '  };',
    '}',
    '',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  return { json: { ...input, safety_action_plan: buildSafetyActionPlan(input) } };',
    '});'
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Workflow 03 - Reply Sender: extend the existing "Live Adapter Contract
// (Validation-Only, Unreachable)" node with request contracts for the other
// verified Instantly V2 endpoints (update-interest-status, subsequence
// remove, blocklist, get-email, list-emails for reconciliation). The node
// remains a documented, unreachable contract (reachable:false, blocked:true)
// - no new live calls are introduced.
// ---------------------------------------------------------------------------
export function patchWorkflow03(workflow) {
  const node = workflow.nodes.find((n) => n.name === 'N. Live Adapter Contract (Validation-Only, Unreachable)');
  if (!node) throw new Error('patchWorkflow03: node N not found');

  let code = node.parameters.jsCode;

  const anchor = [
    '          body: {',
    '            text: draft.draft_text || null,',
    '            html: null,',
    '          },',
    '        },',
    '      },',
    '      retry_policy: {'
  ].join('\n');

  const replacement = [
    '          body: {',
    '            text: draft.draft_text || null,',
    '            html: null,',
    '          },',
    '        },',
    '      },',
    '      // Additional verified V2 contracts (reconciliation and pre-send',
    '      // safety actions). All remain unreachable in VALIDATION mode.',
    '      additional_contracts: {',
    '        update_interest_status: {',
    "          method: 'POST',",
    "          url: 'https://api.instantly.ai/api/v2/leads/update-interest-status',",
    '          body: { campaign_id: (nes.campaign_context || {}).campaign_id || null, lead_email: nes.lead_email || null, interest_status: null },',
    '        },',
    '        remove_subsequence: {',
    "          method: 'POST',",
    "          url: 'https://api.instantly.ai/api/v2/leads/subsequence/remove',",
    '          body: { campaign_id: (nes.campaign_context || {}).campaign_id || null, lead_email: nes.lead_email || null },',
    '        },',
    '        add_to_blocklist: {',
    "          method: 'POST',",
    "          url: 'https://api.instantly.ai/api/v2/blocklist',",
    '          body: { entries: [nes.lead_email || null] },',
    '        },',
    '        get_email: {',
    "          method: 'GET',",
    "          url: `https://api.instantly.ai/api/v2/emails/${threading.reply_to_uuid || '{id}'}`,",
    '        },',
    '        list_emails: {',
    "          method: 'POST',",
    "          url: 'https://api.instantly.ai/api/v2/emails/list',",
    '          body: { eaccount: nes.eaccount || null, lead_email: nes.lead_email || null },',
    '        },',
    '      },',
    '      retry_policy: {'
  ].join('\n');

  code = singleReplace(code, anchor, replacement, '03:additional_contracts');
  node.parameters.jsCode = code;

  return workflow;
}

function replaceAllExact(haystack, oldStr, newStr, expectedCount, label) {
  const count = haystack.split(oldStr).length - 1;
  if (count !== expectedCount) {
    throw new Error(`patch target count mismatch for ${label}: expected ${expectedCount}, found ${count}`);
  }
  return haystack.split(oldStr).join(newStr);
}

// ---------------------------------------------------------------------------
// Workflow 04 - Reply Error Handler: replace the placeholder notification
// terminal with a gated Google Chat adapter. If
// config.review.google_chat_configured is true, POST to
// $env.GOOGLE_CHAT_WEBHOOK_URL; otherwise (or on HTTP failure) fail closed
// with notification.fail_closed_reason = 'ERROR_NOTIFICATION_FAILED'.
// ---------------------------------------------------------------------------
export function patchWorkflow04(workflow, config) {
  const configJson = JSON.stringify(config);
  const node = renameNode(workflow, 'D. Build Placeholder Notification', 'D. Build Notification Payload (Gated)');

  let code = node.parameters.jsCode;

  code = singleReplace(
    code,
    'const items = $input.all();\n',
    'const items = $input.all();\n\nconst CONFIG = ' + configJson + ';\n',
    '04:config-injection'
  );

  const oldFn = [
    'function buildPlaceholderNotification(item) {',
    '  const input = item || {};',
    '  const record = input.error_record || {};',
    '  return {',
    '    ...input,',
    '    notification: {',
    "      schema_version: '1.0',",
    "      surface: 'PLACEHOLDER_NOT_CONFIGURED',",
    '      delivered: false,',
    '      summary: `Error in ${record.workflow_name || \'unknown workflow\'}: ${record.error_class || \'UNKNOWN\'} at node ${record.failed_node || \'unknown\'}`,',
    "      operator_action: record.operator_action || 'MANUAL_REVIEW',",
    '    },',
    '  };',
    '}'
  ].join('\n');

  const newFn = [
    'function buildNotificationPayload(item) {',
    '  const input = item || {};',
    '  const record = input.error_record || {};',
    '  const summary = `Error in ${record.workflow_name || \'unknown workflow\'}: ${record.error_class || \'UNKNOWN\'} at node ${record.failed_node || \'unknown\'}`;',
    '  const operatorAction = record.operator_action || \'MANUAL_REVIEW\';',
    '  const chatText = [',
    "    'HMZ error record: ' + (record.error_id || 'UNKNOWN_ID'),",
    '    summary,',
    "    'Operator action: ' + operatorAction,",
    "  ].join('\\n');",
    '  return {',
    '    ...input,',
    '    config: CONFIG,',
    '    chat_notification: { payload: { text: chatText } },',
    '    notification: {',
    "      schema_version: '1.0',",
    "      surface: CONFIG.review.google_chat_configured === true ? 'GOOGLE_CHAT' : 'NOT_CONFIGURED',",
    '      delivered: false,',
    '      summary,',
    '      operator_action: operatorAction,',
    '    },',
    '  };',
    '}'
  ].join('\n');

  code = singleReplace(code, oldFn, newFn, '04:buildPlaceholderNotification');
  code = singleReplace(
    code,
    'return items.map(item => ({ json: buildPlaceholderNotification(item.json || {}) }));',
    'return items.map(item => ({ json: buildNotificationPayload(item.json || {}) }));',
    '04:return-statement'
  );

  node.parameters.jsCode = code;

  const [dx, dy] = node.position;
  const eNode = ifNode('E. Notification Configured Router', [dx + 280, dy], '={{ $json.config.review.google_chat_configured === true }}');
  const fNode = googleChatHttpNode('F. POST Google Chat Webhook (Gated)', [dx + 560, dy - 100]);
  const f2Node = codeNode('F2. Mark Error Notification Failed (Not Configured)', [dx + 560, dy + 100], [
    'const items = $input.all();',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const notification = { ...(input.notification || {}) };',
    '  notification.delivered = false;',
    "  notification.fail_closed_reason = 'ERROR_NOTIFICATION_FAILED';",
    '  return { json: { ...input, notification } };',
    '});'
  ].join('\n'));
  const gNode = codeNode('G. Finalize Error Notification Result', [dx + 840, dy], [
    'const items = $input.all();',
    'return items.map(item => {',
    '  const input = item.json || {};',
    '  const notification = { ...(input.notification || {}) };',
    '  if (notification.fail_closed_reason) {',
    '    return { json: { ...input, notification } };',
    '  }',
    '  if (input.error) {',
    '    notification.delivered = false;',
    "    notification.fail_closed_reason = 'ERROR_NOTIFICATION_FAILED';",
    '  } else {',
    '    notification.delivered = true;',
    '  }',
    '  return { json: { ...input, notification } };',
    '});'
  ].join('\n'));

  workflow.nodes.push(eNode, fNode, f2Node, gNode);

  connect(workflow, node.name, eNode.name);
  connect(workflow, eNode.name, fNode.name, 0);
  connect(workflow, eNode.name, f2Node.name, 1);
  connect(workflow, fNode.name, gNode.name);
  connect(workflow, f2Node.name, gNode.name);

  return workflow;
}

// ---------------------------------------------------------------------------
// Workflow 05 - Reply SLA Watchdog: extend the alert-dedupe merge with a
// gated Google Chat adapter for non-deduped alerts, fail-closed when
// google_chat_configured is false or the HTTP call errors.
// ---------------------------------------------------------------------------
export function patchWorkflow05(workflow, config) {
  const configJson = JSON.stringify(config);
  const gNode = workflow.nodes.find((n) => n.name === 'G. Merge Alert Dedupe Results');
  if (!gNode) throw new Error('patchWorkflow05: node G not found');

  let code = gNode.parameters.jsCode;

  code = singleReplace(
    code,
    'const items = $input.all();\nconst priorItems = ',
    'const items = $input.all();\n\nconst CONFIG = ' + configJson + ';\n\nconst priorItems = ',
    '05:config-injection'
  );

  const oldReturnBlock = [
    '  return Object.assign({}, {',
    '    ...input,',
    '    alerts,',
    '    notification: {',
    "      schema_version: '1.0',",
    "      surface: 'PLACEHOLDER_NOT_CONFIGURED',",
    '      delivered: false,',
    '      alert_count: toNotify.length,',
    '      deduped_count: alerts.length - toNotify.length,',
    '    },',
    '  });',
    '}'
  ].join('\n');

  const newReturnBlock = [
    '  const chatLines = toNotify.map((a) => `${a.severity} ${a.sloType}/${a.category} ${a.kind}:${a.identifier} age=${a.ageSeconds}s`);',
    "  const chatText = ['HMZ Watchdog alerts (' + toNotify.length + ')'].concat(chatLines).join('\\n');",
    '',
    '  return Object.assign({}, {',
    '    ...input,',
    '    config: CONFIG,',
    '    alerts,',
    '    chat_notification: { payload: { text: chatText } },',
    '    notification: {',
    "      schema_version: '1.0',",
    "      surface: CONFIG.review.google_chat_configured === true ? 'GOOGLE_CHAT' : 'NOT_CONFIGURED',",
    '      delivered: false,',
    '      alert_count: toNotify.length,',
    '      deduped_count: alerts.length - toNotify.length,',
    '    },',
    '  });',
    '}'
  ].join('\n');

  code = replaceAllExact(code, oldReturnBlock, newReturnBlock, 2, '05:notification-return-block');
  gNode.parameters.jsCode = code;

  const hNode = workflow.nodes.find((n) => n.name === 'H. Build Watchdog Result');
  const [gx, gy] = gNode.position;

  const g2Node = ifNode(
    'G2. Notification Configured Router',
    [gx + 100, gy + 220],
    '={{ $json.config.review.google_chat_configured === true && $json.notification.alert_count > 0 }}'
  );
  const g3Node = googleChatHttpNode('G3. POST Google Chat Alert (Gated)', [gx + 380, gy + 120], { onError: undefined });
  const g4Node = codeNode('G4. Skip Watchdog Notification (Not Configured / No Alerts)', [gx + 380, gy + 320], [
    'const items = $input.all();',
    '',
    'function skipWatchdogNotification(input) {',
    '  const notification = Object.assign({}, input.notification || {});',
    '  notification.delivered = false;',
    '  notification.fail_closed_reason = (input.config && input.config.review && input.config.review.google_chat_configured === true)',
    "    ? 'NO_ALERTS_TO_NOTIFY'",
    "    : 'WATCHDOG_NOTIFICATION_FAILED';",
    '  return Object.assign({}, input, { notification });',
    '}',
    '',
    'return items.map((item) => ({ json: skipWatchdogNotification(item.json || {}) }));'
  ].join('\n'));
  const g5Node = codeNode('G5. Finalize Watchdog Notification Result', [gx + 660, gy + 220], [
    'const items = $input.all();',
    '',
    'function finalizeWatchdogNotification(input) {',
    '  const notification = Object.assign({}, input.notification || {});',
    '  if (notification.fail_closed_reason) {',
    '    return Object.assign({}, input, { notification });',
    '  }',
    '  notification.delivered = true;',
    '  return Object.assign({}, input, { notification });',
    '}',
    '',
    'return items.map((item) => ({ json: finalizeWatchdogNotification(item.json || {}) }));'
  ].join('\n'));

  workflow.nodes.push(g2Node, g3Node, g4Node, g5Node);

  replaceConnectionsTarget(workflow, gNode.name, hNode.name, g2Node.name);
  connect(workflow, g2Node.name, g3Node.name, 0);
  connect(workflow, g2Node.name, g4Node.name, 1);
  connect(workflow, g3Node.name, g5Node.name);
  connect(workflow, g4Node.name, g5Node.name);
  connect(workflow, g5Node.name, hNode.name);

  return workflow;
}

export { renameNode, connect, replaceConnectionsTarget, codeNode, ifNode, googleChatHttpNode, singleReplace, replaceAllExact, uid };
