import crypto from 'node:crypto';
import {
  nodeA_BuildReviewCase,
  nodeD_GoogleChatPayload,
  nodeD2_NotificationFailed,
  nodeFMerge_NotificationStatus,
  nodeG_CreateCaseResult
} from './wf07-codes.mjs';
import {
  nodeH_ValidateTokenGet,
  nodeJ_RenderForm,
  nodeJ2_RenderError,
  nodeL_ValidateTokenPost,
  nodeN_ProcessDecision,
  nodeN2_SubmitTokenError,
  nodeQ2_NonSendTerminal,
  nodeR_ApprovedResultPage
} from './wf07-codes-2.mjs';

const PLACEHOLDER_REVIEW_CASES_TABLE = '__PLACEHOLDER_REVIEW_CASES_DATA_TABLE_ID__';
const PLACEHOLDER_REPLY_SENDER_ID = '__PLACEHOLDER_REPLY_SENDER_WORKFLOW_ID__';
const PLACEHOLDER_ERROR_HANDLER_ID = '__PLACEHOLDER_ERROR_HANDLER_WORKFLOW_ID__';

function uid() {
  return crypto.randomUUID();
}

function dataTableUpsertCase() {
  return {
    id: uid(),
    name: 'B. Upsert Review Case (Data Table)',
    type: 'n8n-nodes-base.dataTable',
    typeVersion: 1.1,
    position: [560, 0],
    parameters: {
      resource: 'row',
      operation: 'upsert',
      dataTableId: { mode: 'id', value: PLACEHOLDER_REVIEW_CASES_TABLE },
      filters: {
        conditions: [
          { keyName: 'case_id', condition: 'eq', keyValue: '={{ $json.review_case.case_id }}' }
        ]
      },
      columns: {
        mappingMode: 'defineBelow',
        value: {
          case_id: '={{ $json.review_case.case_id }}',
          intake_id: '={{ $json.review_case.intake_id }}',
          token: '={{ $json.review_case.token }}',
          token_expires_at: '={{ $json.review_case.token_expires_at }}',
          status: '={{ $json.review_case.status }}',
          category: '={{ $json.review_case.category }}',
          urgency: '={{ $json.review_case.urgency }}',
          reply_mode: '={{ $json.review_case.reply_mode }}',
          draft_text: '={{ $json.review_case.draft_text }}',
          template_variables: '={{ JSON.stringify($json.review_case.template_variables) }}',
          blocked_variables: '={{ JSON.stringify($json.review_case.blocked_variables) }}',
          sanitized_context: '={{ JSON.stringify($json.review_case.sanitized_context) }}',
          policy_version: '={{ $json.review_case.policy_version }}',
          kb_version: '={{ $json.review_case.kb_version }}',
          notification_status: '={{ $json.review_case.notification_status }}',
          approver_identity: '={{ $json.review_case.approver_identity }}',
          approved_at: '={{ $json.review_case.approved_at }}',
          final_reply_text: '={{ $json.review_case.final_reply_text }}',
          decision_payload: '={{ JSON.stringify($json.review_case.decision_payload) }}',
          created_at: '={{ $json.review_case.created_at }}',
          updated_at: '={{ $json.review_case.updated_at }}'
        }
      }
    }
  };
}

function dataTableUpdateNotification() {
  return {
    id: uid(),
    name: 'F2. Update Case Notification Status (Data Table)',
    type: 'n8n-nodes-base.dataTable',
    typeVersion: 1.1,
    position: [1960, 0],
    parameters: {
      resource: 'row',
      operation: 'update',
      dataTableId: { mode: 'id', value: PLACEHOLDER_REVIEW_CASES_TABLE },
      filters: {
        conditions: [
          { keyName: 'case_id', condition: 'eq', keyValue: '={{ $json.review_case.case_id }}' }
        ]
      },
      columns: {
        mappingMode: 'defineBelow',
        value: {
          notification_status: '={{ $json.review_case.notification_status }}',
          updated_at: '={{ $json.review_case.updated_at }}'
        }
      }
    }
  };
}

function dataTableGetByCaseId(name, position) {
  return {
    id: uid(),
    name,
    type: 'n8n-nodes-base.dataTable',
    typeVersion: 1.1,
    position,
    parameters: {
      resource: 'row',
      operation: 'getRows',
      dataTableId: { mode: 'id', value: PLACEHOLDER_REVIEW_CASES_TABLE },
      filters: {
        conditions: [
          { keyName: 'case_id', condition: 'eq', keyValue: '={{ ($json.query && $json.query.case) || ($json.body && $json.body.case_id) || "" }}' }
        ]
      },
      options: {}
    }
  };
}

function dataTableUpdateDecision() {
  return {
    id: uid(),
    name: 'O. Persist Reviewer Decision (Data Table)',
    type: 'n8n-nodes-base.dataTable',
    typeVersion: 1.1,
    position: [1400, 860],
    parameters: {
      resource: 'row',
      operation: 'update',
      dataTableId: { mode: 'id', value: PLACEHOLDER_REVIEW_CASES_TABLE },
      filters: {
        conditions: [
          { keyName: 'case_id', condition: 'eq', keyValue: '={{ $json.review_case.case_id }}' }
        ]
      },
      columns: {
        mappingMode: 'defineBelow',
        value: {
          status: '={{ $json.review_case.status }}',
          approver_identity: '={{ $json.review_case.approver_identity }}',
          approved_at: '={{ $json.review_case.approved_at }}',
          final_reply_text: '={{ $json.review_case.final_reply_text }}',
          decision_payload: '={{ JSON.stringify($json.review_case.decision_payload) }}',
          updated_at: '={{ $json.review_case.updated_at }}'
        }
      }
    }
  };
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

function respondNode(name, position) {
  return {
    id: uid(),
    name,
    type: 'n8n-nodes-base.respondToWebhook',
    typeVersion: 1.4,
    position,
    parameters: {
      respondWith: 'text',
      responseBody: '={{ $json.html }}',
      options: {
        responseHeaders: {
          entries: [{ name: 'Content-Type', value: 'text/html; charset=utf-8' }]
        }
      }
    }
  };
}

function webhookNode(name, position, httpMethod, path) {
  return {
    id: uid(),
    name,
    type: 'n8n-nodes-base.webhook',
    typeVersion: 2.1,
    position,
    onError: 'continueRegularOutput',
    alwaysOutputData: true,
    parameters: {
      httpMethod,
      path,
      responseMode: 'responseNode',
      options: {}
    },
    webhookId: uid()
  };
}

function googleChatHttpNode() {
  return {
    id: uid(),
    name: 'E. POST Google Chat Webhook (Gated)',
    type: 'n8n-nodes-base.httpRequest',
    typeVersion: 4.2,
    position: [1400, -160],
    onError: 'continueRegularOutput',
    parameters: {
      method: 'POST',
      url: '={{ $env.GOOGLE_CHAT_WEBHOOK_URL }}',
      sendBody: true,
      specifyBody: 'json',
      jsonBody: '={{ JSON.stringify($json.chat_notification.payload) }}',
      options: { timeout: 5000 }
    }
  };
}

function replySenderHandoffNode() {
  return {
    id: uid(),
    name: 'Q. Reply Sender Handoff (Approved)',
    type: 'n8n-nodes-base.executeWorkflow',
    typeVersion: 1.3,
    position: [1960, 760],
    parameters: {
      source: 'database',
      workflowId: {
        mode: 'list',
        value: PLACEHOLDER_REPLY_SENDER_ID,
        cachedResultName: 'HMZ - Instantly Reply Sender - Validation'
      },
      workflowInputs: {
        mappingMode: 'defineBelow',
        value: {
          nes: '={{ $json.case_input.nes }}',
          decision: '={{ $json.case_input.decision }}',
          draft: '={{ Object.assign({}, $json.case_input.draft, { draft_text: $json.review_case.final_reply_text }) }}',
          validation: '={{ $json.case_input.validation }}',
          approval: '={{ { approved: true, approver_identity: $json.review_case.approver_identity, approved_at: $json.review_case.approved_at, case_id: $json.review_case.case_id, policy_version: $json.review_case.policy_version } }}'
        }
      },
      mode: 'each',
      options: {}
    }
  };
}

export function buildWorkflow07(config) {
  const configJson = JSON.stringify(config);

  const triggerCreateCase = {
    id: 'trigger_create_case',
    name: 'When Called to Create Review Case',
    type: 'n8n-nodes-base.executeWorkflowTrigger',
    typeVersion: 1.1,
    position: [0, 0],
    parameters: { inputSource: 'passthrough' }
  };

  const nodeA = codeNode('A. Build Review Case Record', [280, 0], nodeA_BuildReviewCase(configJson));
  const nodeB = dataTableUpsertCase();
  const nodeC = ifNode('C. Notification Configured Router', [840, 0], '={{ $json.config.review.google_chat_configured === true }}');
  const nodeD = codeNode('D. Build Google Chat Notification Payload', [1120, -160], nodeD_GoogleChatPayload());
  const nodeE = googleChatHttpNode();
  const nodeD2 = codeNode('D2. Mark Review Notification Failed', [1120, 160], nodeD2_NotificationFailed());
  const nodeFMerge = codeNode('F. Merge Notification Result', [1680, 0], nodeFMerge_NotificationStatus());
  const nodeF2 = dataTableUpdateNotification();
  const nodeG = codeNode('G. Build Create-Case Result', [2240, 0], nodeG_CreateCaseResult());

  // GET review form
  const triggerFormDev = webhookNode('Webhook - Review Form (Dev)', [0, 400], 'GET', 'hmz-validation-review-form-dev');
  const triggerFormProd = webhookNode('Webhook - Review Form (Production, Gated Path)', [0, 600], 'GET', '__REQUIRED_PRODUCTION_REVIEW_FORM_PATH__');
  const nodeH0 = dataTableGetByCaseId('H0. Lookup Case for Form (Data Table)', [280, 480]);
  const nodeH = codeNode('H. Validate Review Token (GET)', [560, 480], nodeH_ValidateTokenGet());
  const nodeI = ifNode('I. Token Valid Router (GET)', [840, 480], '={{ $json.token_valid === true }}');
  const nodeJ = codeNode('J. Render Review Form HTML', [1120, 360], nodeJ_RenderForm());
  const nodeK = respondNode('K. Respond Review Form HTML', [1400, 360]);
  const nodeJ2 = codeNode('J2. Render Token Error Page', [1120, 600], nodeJ2_RenderError());
  const nodeK2 = respondNode('K2. Respond Token Error Page', [1400, 600]);

  // POST submit
  const triggerSubmitDev = webhookNode('Webhook - Review Submit (Dev)', [0, 900], 'POST', 'hmz-validation-review-submit-dev');
  const triggerSubmitProd = webhookNode('Webhook - Review Submit (Production, Gated Path)', [0, 1060], 'POST', '__REQUIRED_PRODUCTION_REVIEW_SUBMIT_PATH__');
  const nodeL0 = dataTableGetByCaseId('L0. Lookup Case for Submit (Data Table)', [280, 980]);
  const nodeL = codeNode('L. Validate & Consume Review Token (POST)', [560, 980], nodeL_ValidateTokenPost());
  const nodeM = ifNode('M. Submit Token Valid Router', [840, 980], '={{ $json.token_valid === true }}');
  const nodeN = codeNode('N. Process Reviewer Decision', [1120, 860], nodeN_ProcessDecision());
  const nodeO = dataTableUpdateDecision();
  const nodeP = ifNode('P. Approval Outcome Router', [1680, 860], "={{ $json.final_action === 'approve' }}");
  const nodeQ = replySenderHandoffNode();
  const nodeR = codeNode('R. Build Approved Result Page', [2240, 760], nodeR_ApprovedResultPage());
  const nodeK3 = respondNode('K3. Respond Approved Result', [2520, 760]);
  const nodeQ2 = codeNode('Q2. Build Non-Send Terminal Result', [1960, 1000], nodeQ2_NonSendTerminal());
  const nodeK4 = respondNode('K4. Respond Non-Send Result', [2240, 1000]);
  const nodeN2 = codeNode('N2. Render Submit Token Error', [1120, 1100], nodeN2_SubmitTokenError());
  const nodeK5 = respondNode('K5. Respond Submit Token Error', [1400, 1100]);

  const nodes = [
    triggerCreateCase, nodeA, nodeB, nodeC, nodeD, nodeE, nodeD2, nodeFMerge, nodeF2, nodeG,
    triggerFormDev, triggerFormProd, nodeH0, nodeH, nodeI, nodeJ, nodeK, nodeJ2, nodeK2,
    triggerSubmitDev, triggerSubmitProd, nodeL0, nodeL, nodeM, nodeN, nodeO, nodeP, nodeQ, nodeR, nodeK3, nodeQ2, nodeK4, nodeN2, nodeK5
  ];

  const connections = {};
  const connect = (fromName, toName, fromOutput = 0) => {
    connections[fromName] = connections[fromName] || { main: [] };
    while (connections[fromName].main.length <= fromOutput) connections[fromName].main.push([]);
    connections[fromName].main[fromOutput].push({ node: toName, type: 'main', index: 0 });
  };

  connect(triggerCreateCase.name, nodeA.name);
  connect(nodeA.name, nodeB.name);
  connect(nodeB.name, nodeC.name);
  connect(nodeC.name, nodeD.name, 0);
  connect(nodeC.name, nodeD2.name, 1);
  connect(nodeD.name, nodeE.name);
  connect(nodeE.name, nodeFMerge.name);
  connect(nodeD2.name, nodeFMerge.name);
  connect(nodeFMerge.name, nodeF2.name);
  connect(nodeF2.name, nodeG.name);

  connect(triggerFormDev.name, nodeH0.name);
  connect(triggerFormProd.name, nodeH0.name);
  connect(nodeH0.name, nodeH.name);
  connect(nodeH.name, nodeI.name);
  connect(nodeI.name, nodeJ.name, 0);
  connect(nodeI.name, nodeJ2.name, 1);
  connect(nodeJ.name, nodeK.name);
  connect(nodeJ2.name, nodeK2.name);

  connect(triggerSubmitDev.name, nodeL0.name);
  connect(triggerSubmitProd.name, nodeL0.name);
  connect(nodeL0.name, nodeL.name);
  connect(nodeL.name, nodeM.name);
  connect(nodeM.name, nodeN.name, 0);
  connect(nodeM.name, nodeN2.name, 1);
  connect(nodeN.name, nodeO.name);
  connect(nodeO.name, nodeP.name);
  connect(nodeP.name, nodeQ.name, 0);
  connect(nodeP.name, nodeQ2.name, 1);
  connect(nodeQ.name, nodeR.name);
  connect(nodeR.name, nodeK3.name);
  connect(nodeQ2.name, nodeK4.name);
  connect(nodeN2.name, nodeK5.name);

  const now = new Date().toISOString();

  return {
    name: 'HMZ - Reply Human Approval - Validation',
    description: 'Business-ready offline build: durable review-case creation, gated Google Chat notification, secure one-time review form, and approval handoff to the Reply Sender. Imports inactive; no credentials bound.',
    active: false,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
    versionId: uid(),
    activeVersionId: null,
    versionCounter: 1,
    triggerCount: 5,
    sourceWorkflowId: null,
    tags: [],
    nodes,
    connections,
    settings: {
      executionOrder: 'v1',
      saveDataErrorExecution: 'all',
      saveDataSuccessExecution: 'all',
      saveManualExecutions: true,
      saveExecutionProgress: true,
      errorWorkflow: PLACEHOLDER_ERROR_HANDLER_ID
    },
    staticData: null,
    meta: null,
    nodeGroups: null,
    pinData: {}
  };
}
