const _decisionInputItems = (() => { try { const xs = $("C. Decision Policy").all(); return xs && xs.length ? xs : $input.all(); } catch { return $input.all(); } })();
const _dynamicFormPolicyRows = (() => { try { return $("Q12. Lookup Active Form Learning Rules").all().map(i => i.json || {}); } catch { return []; } })();
const items = _decisionInputItems;
function _q12ParseMaybeJson(value, fallback) {
  if (value == null || value === "") return fallback;
  if (typeof value === "object") return value;
  try { return JSON.parse(String(value)); } catch { return fallback; }
}
function _q12Bool(value) { return value === true || String(value || "").toLowerCase() === "true"; }
function _q12DynamicFormPolicies(rows) {
  return (Array.isArray(rows) ? rows : []).filter(r => String(r.status || "").toLowerCase() === "active" && String(r.rule_type || "").toLowerCase() === "style").map(r => ({
    ...r,
    policy_id: r.policy_id || r.rule_id,
    policy_type: r.policy_type || r.rule_type,
    behavioural_instruction: r.behavioural_instruction || r.human_instruction || r.desired_future_behavior || r.proposed_rule_text || r.reason || "",
    desired_future_behavior: r.desired_future_behavior || r.behavioural_instruction || r.human_instruction || "",
    draft_improvement_target_classifications: _q12ParseMaybeJson(r.draft_improvement_target_classifications, _q12ParseMaybeJson(r.target_classifications, [])),
    target_classifications: _q12ParseMaybeJson(r.target_classifications, _q12ParseMaybeJson(r.draft_improvement_target_classifications, [])),
    original_classification: _q12ParseMaybeJson(r.original_classification, {}),
    corrected_effective_classification: _q12ParseMaybeJson(r.corrected_effective_classification, {}),
    target_classification_used: _q12ParseMaybeJson(r.target_classification_used, {}),
    requires_human_activation: _q12Bool(r.requires_human_activation),
    immediate_supervised_effect: _q12Bool(r.immediate_supervised_effect),
    activation_source: r.activation_source || "humanapproval_form",
    source_marker: r.source_marker || "humanapproval_form_created_learning"
  })).filter(p => p.behavioural_instruction && p.source_case_id && (p.activation_source === "humanapproval_form" || p.source_marker === "humanapproval_form_created_learning"));
}
const DYNAMIC_FORM_BEHAVIOURAL_POLICIES = _q12DynamicFormPolicies(_dynamicFormPolicyRows);
function _q12ClassificationObject(value) {
  const parsed = _q12ParseMaybeJson(value, {});
  if (!parsed || typeof parsed !== "object") return { broad_category:"", micro_intent:"" };
  return {
    broad_category: String(parsed.broad_category || parsed.category || parsed.corrected_category || "").trim(),
    micro_intent: String(parsed.micro_intent || parsed.corrected_micro_intent || "").trim()
  };
}
function _q12ClassificationTime(rule) {
  const raw = rule.activated_at || rule.effective_at || rule.approved_at || rule.updated_at || rule.created_at || "";
  const t = Date.parse(raw);
  return Number.isFinite(t) ? t : 0;
}
function _q12DynamicFormClassificationRules(rows) {
  return (Array.isArray(rows) ? rows : []).map(r => {
    const type = String(r.rule_type || r.policy_type || "").trim().toLowerCase();
    const status = String(r.status || "").trim().toLowerCase();
    const activationSource = String(r.activation_source || "").trim();
    const sourceMarker = String(r.source_marker || "").trim();
    const original = _q12ClassificationObject(r.original_classification);
    const corrected = _q12ClassificationObject(r.corrected_effective_classification || r.target_classification_used);
    const target = _q12ClassificationObject(r.target_classification_used || r.corrected_effective_classification);
    const instruction = String(r.human_instruction || r.behavioural_instruction || r.reason || r.proposed_rule_text || "").trim();
    return {
      ...r,
      rule_type: type,
      status,
      activation_source: activationSource,
      source_marker: sourceMarker,
      original_classification: original,
      corrected_effective_classification: corrected,
      target_classification_used: target,
      human_instruction: instruction,
      time: _q12ClassificationTime(r),
      scope_key: [original.broad_category, original.micro_intent, r.proposed_rule_scope || r.draft_improvement_scope || r.policy_precedence_key || "classification"].map(_5qNorm).join("|")
    };
  }).filter(r => {
    if (!["active", "effective"].includes(r.status)) return false;
    if (!(r.activation_source === "humanapproval_form" || r.source_marker === "humanapproval_form_created_learning")) return false;
    if (!r.source_case_id || !r.human_instruction) return false;
    if (!r.original_classification.broad_category || !r.original_classification.micro_intent) return false;
    if (!r.corrected_effective_classification.broad_category || !r.corrected_effective_classification.micro_intent) return false;
    if (r.original_classification.broad_category === r.corrected_effective_classification.broad_category && r.original_classification.micro_intent === r.corrected_effective_classification.micro_intent) return false;
    return r.rule_type === "classification" || r.rule_type === "classification_correction" || r.rule_type === "style" || r.rule_type === "draft_improvement";
  });
}
const DYNAMIC_FORM_CLASSIFICATION_RULES = _q12DynamicFormClassificationRules(_dynamicFormPolicyRows);

// === AI DRAFT CONFIG FLAGS ===
const AI_DRAFT_PROVIDER         = 'openai';
const AI_DRAFT_MODE             = 'supervised';   // off | supervised | fallback_only
const AI_DRAFT_MODEL            = 'gpt-5.4-mini';
const AI_DRAFT_TIMEOUT_MS       = 8000;
const AI_DRAFT_MAX_OUTPUT_TOKENS = 320;
const AI_DRAFT_TEMPERATURE      = 0.3;
const AI_API_KEY = (typeof $env !== 'undefined' && $env.OPENAI_API_KEY) ? $env.OPENAI_API_KEY : '';

// HMZ_INJECT_BEGIN:SENDER_CONFIG
const SENDER_CONFIG = {};
// HMZ_INJECT_END:SENDER_CONFIG
// HMZ_INJECT_BEGIN:ACTIVE_RULES
const ACTIVE_RULE_GUIDANCE = "\n---\n## Human-approved guidance (active rules -- injected by SL-PHASE-4D)\nThe following guidance has been reviewed and approved by the account owner.\nApply it to your draft where relevant. It does NOT override safety gates.\nDo not invent prices, results, case studies, guarantees, or compliance claims.\nHuman approval is still required before any reply is sent.\n\n### Rule 1 (rule_id: 55844bf1-a36c-4a03-9832-98b08c50e557)\nScope: INFORMATION_REQUEST / PROOF_REQUEST\nInstruction: Classify as INFORMATION_REQUEST/PROOF_REQUEST: see correction_reason\n\n### Rule 2 (rule_id: 1a779d95-beaf-4d2e-8c70-73721a11b02d)\nScope: PRICING_OR_COMMERCIAL_NEGOTIATION / PRICING_REQUEST\nInstruction: Classify as PRICING_OR_COMMERCIAL_NEGOTIATION/PRICING_REQUEST: see correction_reason\n\n---";
// HMZ_INJECT_END:ACTIVE_RULES
// HMZ_INJECT_BEGIN:ACTIVE_BEHAVIOURAL_POLICIES
// SL-PHASE-5Q: owner-approved draft behavioural policies only.
const ACTIVE_BEHAVIOURAL_POLICIES = [
  {
    "rule_id": "27293ea8-bc4c-444b-be08-3623c9bb942b",
    "policy_id": "27293ea8-bc4c-444b-be08-3623c9bb942b",
    "source_event_id": "7c96a99f-4c06-47f3-990e-20b1d9855159",
    "source_case_id": "case-66062eda",
    "source_original_case_id": "case-66062eda",
    "rule_type": "style",
    "policy_type": "style",
    "status": "active",
    "classification_scope": "INFORMATION_REQUEST",
    "micro_intent_scope": "OFFER_EXPLANATION",
    "draft_improvement_scope": "all_ai_drafts",
    "proposed_rule_scope": "global_draft_policy",
    "draft_improvement_target_classifications": [],
    "target_classifications": [],
    "proposed_rule_text": "Draft behaviour improvement: For OFFER_EXPLANATION setup questions, start with a natural acknowledgement, answer the setup question in short paragraphs before any CTA, and do not mention validation unless the prospect asks for proof, case studies, or maturity.",
    "behavioural_instruction": "For OFFER_EXPLANATION setup questions, start with a natural acknowledgement, answer the setup question in short paragraphs before any CTA, and do not mention validation unless the prospect asks for proof, case studies, or maturity.",
    "desired_future_behavior": "For OFFER_EXPLANATION setup questions, start with a natural acknowledgement, answer the setup question in short paragraphs before any CTA, and do not mention validation unless the prospect asks for proof, case studies, or maturity.",
    "reason": "Original draft answered the setup question, but it lacked a natural acknowledgement, was formatted as one dense block, and mentioned validation even though the prospect did not ask for proof or case studies. Owner activated globally during SL-PHASE-5Q live proof.",
    "confidence": "low",
    "requires_human_activation": false,
    "created_by": "humza@hmzaiautomation.com",
    "approved_by": "humza@hmzaiautomation.com",
    "approved_at": "2026-06-27T21:27:09Z",
    "activation_source": "owner_live_proof_chat",
    "activation_scope_confirmed_by_owner": true
  }
];
// HMZ_INJECT_END:ACTIVE_BEHAVIOURAL_POLICIES

// === DETERMINISTIC MICRO INTENT TEMPLATES =====================================
const MI_TEMPLATES = {
  MEETING_TIME_REQUEST: {
    paragraphs: [
      'Thanks, <<firstName>>. Happy to talk it through.',
      "We're currently validating the capacity-aligned outbound model with US B2B teams. The first step is a brief 10-minute conversation to understand how you currently handle outbound and whether the problem is relevant.",
      'You can choose a suitable time here: <<bookingLink>>',
      "Or reply with a couple of times that work for you and I'll coordinate it.",
      '<<senderName>>'
    ],
    bookingLinkLine: 'You can choose a suitable time here: <<bookingLink>>',
    noName: { from:'Thanks, <<firstName>>. Happy to talk it through.', to:'Happy to talk it through.' }
  },
  PROOF_OR_CASE_STUDY_REQUEST: {
    paragraphs: [
      'Thanks, <<firstName>>. Happy to be straight about where we are.',
      "This is validation stage - no public case studies or proven results yet. We're running conversations with US B2B teams to understand whether the capacity problem is real before we have evidence to share.",
      "The conversation we're offering is the proof step - a brief 10-minute call to see whether the problem is relevant to your situation.",
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Happy to be straight about where we are.', to:'Happy to be straight about where we are.' }
  },
  OFFER_EXPLANATION: {
    paragraphs: [
      'Thanks, <<firstName>>. Happy to explain.',
      'The setup is about matching outbound to the sales capacity your team can actually handle:',
      '1. Define the target accounts and qualification criteria.\n2. Build the message and routing around those criteria.\n3. Keep volume aligned to the number of useful conversations the team can work.',
      'If useful, the next step is a brief 10-minute conversation to understand your setup.',
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Happy to explain.', to:'Happy to explain.' }
  },
  HOW_IT_WORKS_REQUEST: {
    paragraphs: [
      'Thanks, <<firstName>>. Here is the short version.',
      "We define how many qualified meetings your sales team can realistically handle and what qualified means for your motion, then build outbound to fill that capacity rather than maximising volume regardless of quality.",
      "We're validating this with US B2B teams. The first step would be a brief 10-minute conversation to understand your setup and whether this is relevant.",
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Here is the short version.', to:'Here is the short version.' }
  },
  CURRENT_OUTBOUND_VENDOR: {
    paragraphs: [
      'Thanks for the context, <<firstName>>.',
      "When you say outbound is running, would the bottleneck be volume of qualified meetings, the quality of meetings you're getting, conversion after the first call, or something closer to sales capacity itself?",
      "The reason I ask is that the model we're validating addresses a specific capacity problem - and it may or may not be relevant depending on where your friction is.",
      '<<senderName>>'
    ],
    noName: { from:'Thanks for the context, <<firstName>>.', to:'Thanks for the context.' }
  },
  NOT_NOW: {
    paragraphs: [
      'Thanks, <<firstName>>. Understood.',
      "I'll close the loop for now. Feel free to reach out if the timing changes.",
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Understood.', to:'Understood.' }
  },
  NOT_INTERESTED: {
    paragraphs: ['Thanks, <<firstName>>. Understood.', '<<senderName>>'],
    noName: { from:'Thanks, <<firstName>>. Understood.', to:'Understood.' }
  },
  UNSUBSCRIBE_OR_COMPLAINT: {
    paragraphs: ['Understood. You have been removed from future outreach.', '<<senderName>>'],
    suppressFirstName: true
  },
  WRONG_PERSON: {
    paragraphs: ['Thanks for letting me know, <<firstName>>. Apologies for the mix-up.', '<<senderName>>'],
    noName: { from:'Thanks for letting me know, <<firstName>>. Apologies for the mix-up.', to:'Apologies for the mix-up.' }
  },
  AMBIGUOUS_SHORT_REPLY: {
    paragraphs: [
      'Thanks, <<firstName>>. Happy to share more.',
      'Would it be more useful for me to explain the capacity model here, or would you prefer a brief 10-minute conversation?',
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Happy to share more.', to:'Happy to share more.' }
  },
  POSITIVE_INTEREST_GENERAL: {
    paragraphs: [
      'Thanks, <<firstName>>. Happy to talk it through.',
      'Would it be more useful for me to explain the capacity model here, or would you prefer a brief 10-minute conversation?',
      "Or reply with a couple of times that work for you and I'll coordinate it.",
      '<<senderName>>'
    ],
    noName: { from:'Thanks, <<firstName>>. Happy to talk it through.', to:'Happy to talk it through.' }
  }
};

// === AI OUTPUT VALIDATION =====================================================
const FORBIDDEN_AI = [
  { rx:/guarantee/i,                                       label:'guarantee claim' },
  { rx:/\b(proven|proves|proof of|established|industry leader)\b/i, label:'proven/established claim' },
  { rx:/case stud/i,                                       label:'case study claim' },
  { rx:/testimonial/i,                                     label:'testimonial claim' },
  { rx:/\$\s?\d/,                                          label:'price disclosure' },
  { rx:/\bresults?\b/i,                                    label:'results claim' },
  { rx:/\d+\s*(meetings?|clients?|customers?)/i,           label:'numeric proof claim' },
  { rx:/we.ve (helped|worked with|served)/i,               label:'customer claim' },
  { rx:/\{\{[^}]*\}\}/,                                    label:'unresolved mustache token' },
  { rx:/<<(?!firstName|senderName|bookingLink)\w+>>/,      label:'unresolved non-standard token' }
];
const SUPPRESS_ONLY_INTENTS = new Set(['UNSUBSCRIBE_OR_COMPLAINT','ANGRY_COMPLAINT']);
const SUPPRESS_FORBIDDEN_CTA = [/\?/,/\b(call|chat|meeting|calendar|book|available)\b/i];

function validateAI(text, microIntent, behaviouralGuidance, prospectText) {
  const e = [];
  if (!text || typeof text !== 'string' || text.trim().length < 10) { e.push('draft_text too short or empty'); return e; }
  if (text.length > 800) e.push('draft_text exceeds 800 char cap');
  for (const p of FORBIDDEN_AI) {
    const _m = (new RegExp(p.rx.source, (p.rx.flags||'').replace('g',''))).exec(text);
    if (_m) {
      const _pre = text.slice(0, _m.index);
      let _sStart = 0;
      ['. ','! ','? '].forEach(function(s){ const i = _pre.lastIndexOf(s); if (i >= 0 && (i+2) > _sStart) _sStart = i+2; });
      (function(){ const i = _pre.lastIndexOf('\n'); if (i >= 0 && (i+1) > _sStart) _sStart = i+1; })();
      const _window = text.slice(_sStart, _m.index);
      if (!/\b(no|not|don'?t|doesn'?t|haven'?t|hasn'?t|isn'?t|aren'?t|never|without|zero|none|absence)\b/i.test(_window)) {
        e.push('forbidden: ' + p.label);
      }
    }
  }
  if (SUPPRESS_ONLY_INTENTS.has(microIntent)) {
    for (const p of SUPPRESS_FORBIDDEN_CTA) { if (p.test(text)) e.push('forbidden CTA/question in suppress-only intent'); }
  }
  const guidance = String(behaviouralGuidance || '');
  const prospect = String(prospectText || '');
  const asksProof = /\b(proof|prove|case stud|example|customer|result|roi|validation|maturity|evidence)\b/i.test(prospect);
  if (/do not mention validation|unless the prospect asks/i.test(guidance) && !asksProof && /\b(validation|validating|proof|case stud|public customer examples|customer examples|results?)\b/i.test(text)) {
    e.push('active policy violation: validation/proof mention without prospect proof request');
  }
  if (/short paragraphs|numbered|bulleted|list/i.test(guidance)) {
    const paras = text.split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
    const dense = paras.some(p => {
      const lines = p.split(/\n/).map(l => l.trim()).filter(Boolean);
      const hasListStructure = lines.some(l => /^(?:[-*]|\d+[.)])\s+/.test(l));
      const maxLine = lines.reduce((m, l) => Math.max(m, l.length), 0);
      if (hasListStructure) return maxLine > 260 || p.length > 900;
      return p.length > 360;
    });
    if (dense) e.push('active policy violation: dense paragraph');
  }
  if (/Absolutely,\s*\.|Thanks,\s*\.|Hi,\s*\.|Hello,\s*\./i.test(text)) {
    e.push('active policy violation: malformed acknowledgement');
  }
  return e;
}

function resolveFirstName(nes) {
  const raw = nes && typeof nes.lead_first_name === 'string' ? nes.lead_first_name.trim() : '';
  if (!raw) return null;
  const lower = raw.toLowerCase();
  if (['unknown','n/a','na','test','admin','friend','there'].includes(lower)) return null;
  if (/^\d+$/.test(raw) || /[@<>{}]/.test(raw) || /https?:\/\//i.test(raw)) return null;
  return raw;
}

function renderTemplate(tmpl, firstName, senderName, bookingLink) {
  if (!tmpl) return null;
  let lines = [...tmpl.paragraphs];
  const useName = !tmpl.suppressFirstName && !!firstName;
  if (!useName && tmpl.noName) { lines = lines.map(l => l === tmpl.noName.from ? tmpl.noName.to : l); }
  if (tmpl.bookingLinkLine && !bookingLink) { lines = lines.filter(l => l !== tmpl.bookingLinkLine); }
  const subs = { firstName:useName?firstName:'', senderName:senderName||'', bookingLink:bookingLink||'' };
  return lines
    .map(l => l.replace(/<<(\w+)>>/g, (_,k) => Object.prototype.hasOwnProperty.call(subs,k)?subs[k]:`[[${k}: unresolved]]`))
    .filter(l => l.trim().length > 0)
    .join('\n\n');
}

function _5qIsCommercialSafe(detFlags) {
  const flags = detFlags || {};
  return !flags["det-legal-001"] && !flags["det-legal-002"] &&
         !flags["det-regulator-001"] && !flags["det-hostile-001"] &&
         !flags["det-hostile-002"] && !flags["det-complaint-001"] &&
         !flags["det-unsub-001"];
}
function _5qDraftPolicyFor(microIntent, detFlags) {
  const p = {
    MEETING_TIME_REQUEST:      "FIXED_TEMPLATE",
    BOOKING_REQUEST:           "FIXED_TEMPLATE",
    PROOF_OR_CASE_STUDY_REQUEST:"AI_SUPERVISED_OR_TEMPLATE",
    OFFER_EXPLANATION:         "AI_SUPERVISED_OR_TEMPLATE",
    HOW_IT_WORKS_REQUEST:      "AI_SUPERVISED_OR_TEMPLATE",
    CURRENT_OUTBOUND_VENDOR:   "AI_SUPERVISED_OR_TEMPLATE",
    PRICING_REQUEST:           "HUMAN_ONLY",
    NOT_NOW:                   "FIXED_TEMPLATE",
    NOT_INTERESTED:            "FIXED_TEMPLATE",
    UNSUBSCRIBE_OR_COMPLAINT:  "FIXED_TEMPLATE_SUPPRESS_ONLY",
    WRONG_PERSON:              "FIXED_TEMPLATE",
    AMBIGUOUS_SHORT_REPLY:     "AI_SUPERVISED_OR_TEMPLATE",
    OOO_AUTO_REPLY:            "NO_DRAFT",
    ANGRY_COMPLAINT:           "HUMAN_ONLY",
    POSITIVE_INTEREST_GENERAL: "AI_SUPERVISED_OR_TEMPLATE"
  };
  const base = p[microIntent] || "HUMAN_ONLY";
  return (microIntent === "PRICING_REQUEST" && base === "HUMAN_ONLY" && _5qIsCommercialSafe(detFlags)) ? "AI_COMMERCIAL_SUPERVISED" : base;
}
function _5qTemplateIdFor(category, microIntent, existingTemplateId) {
  if (microIntent === "BOOKING_REQUEST" || microIntent === "MEETING_TIME_REQUEST" || category === "BOOKING_REQUEST") return "T1_SCENARIO_A_OPEN_TO_CALL";
  const map = {
    POSITIVE_INTEREST:"T1_SCENARIO_C_UNCLEAR_INTEREST",
    INFORMATION_REQUEST:"T2_KB_INFORMATION_REQUEST",
    TIMING_OBJECTION:"T4_SCENARIO_B_VAGUE",
    REFERRAL:"T5_REFERRAL_ACK",
    NOT_INTERESTED:"T6_NOT_INTERESTED_ACK",
    UNSUBSCRIBE:"T7_UNSUBSCRIBE_CONFIRMATION",
    WRONG_PERSON:"T10_WRONG_PERSON_ACK",
    PRICING_OR_COMMERCIAL_NEGOTIATION:"T8_PRICING_ALPHA_PHASE",
    AMBIGUOUS:"T11_AMBIGUOUS_CLARIFY"
  };
  return Object.prototype.hasOwnProperty.call(map, category) ? map[category] : (existingTemplateId || null);
}

function _5qNorm(value) {
  return String(value == null ? '' : value).trim().toUpperCase();
}

function _5qPolicyTargets(policy) {
  const parsedDraftTargets = _q12ParseMaybeJson(policy.draft_improvement_target_classifications, null);
  const parsedTargets = _q12ParseMaybeJson(policy.target_classifications, null);
  const raw = Array.isArray(parsedDraftTargets)
    ? parsedDraftTargets
    : (Array.isArray(parsedTargets) ? parsedTargets : []);
  return raw.map(t => ({ type: String(t.type || '').trim(), value: _5qNorm(t.value) })).filter(t => t.type && t.value);
}

function _5qPolicyMicroMatches(policyMicroIntent, category, microIntent) {
  const pmi = _5qNorm(policyMicroIntent);
  const cat = _5qNorm(category);
  const mi = _5qNorm(microIntent);
  if (pmi && pmi === mi) return true;
  // 5Q14B/5Q14D: legacy form learning stored booking as INFORMATION_REQUEST / BOOKING_REQUEST.
  // Later classifier paths can emit either INFORMATION_REQUEST / BOOKING_REQUEST or BOOKING_REQUEST / MEETING_TIME_REQUEST for booking-link asks.
  return pmi === 'BOOKING_REQUEST' && ((cat === 'BOOKING_REQUEST' && mi === 'MEETING_TIME_REQUEST') || (cat === 'INFORMATION_REQUEST' && mi === 'BOOKING_REQUEST'));
}

function _5qPolicyApplies(policy, category, microIntent, additionalIntents, campaignContext, nes) {
  const scope = String(policy.proposed_rule_scope || policy.draft_improvement_scope || '').trim();
  const cat = _5qNorm(category);
  const mi = _5qNorm(microIntent);
  const add = (additionalIntents || []).map(x => _5qNorm(typeof x === 'string' ? x : x && x.micro_intent)).filter(Boolean);
  const targets = _5qPolicyTargets(policy);

  if (scope === 'global_draft_policy' || scope === 'all_ai_drafts') return true;

  if (scope === 'micro_intent' || scope === 'current_micro_intent_only') {
    return targets.some(t => t.type === 'micro_intent' && _5qPolicyMicroMatches(t.value, cat, mi)) || _5qPolicyMicroMatches(policy.micro_intent_scope, cat, mi);
  }

  if (scope === 'broad_category' || scope === 'current_broad_category') {
    return targets.some(t => t.type === 'broad_category' && t.value === cat) || _5qNorm(policy.classification_scope) === cat;
  }

  if (targets.length > 0) {
    return targets.some(t =>
      (t.type === 'broad_category' && t.value === cat) ||
      (t.type === 'micro_intent' && t.value === mi) ||
      (t.type === 'additional_intent' && add.includes(t.value))
    );
  }
  if ((scope === 'campaign_scoped' || scope === 'campaign_specific') && _5qNorm(policy.campaign_id) && _5qNorm(policy.campaign_id) === _5qNorm(campaignContext && campaignContext.campaign_id)) return true;
  if ((scope === 'sender_scoped' || scope === 'sender_specific') && _5qNorm(policy.sender_account) && _5qNorm(policy.sender_account) === _5qNorm(nes && (nes.eaccount || nes.email_account))) return true;

  return false;
}

function _5qPolicyTime(policy) {
  const raw = policy.activated_at || policy.approved_at || policy.effective_at || policy.updated_at || policy.created_at || '';
  const t = Date.parse(raw);
  return Number.isFinite(t) ? t : 0;
}

function _5qPolicyScopeKey(policy) {
  const scope = String(policy.proposed_rule_scope || policy.draft_improvement_scope || '').trim();
  const targets = _5qPolicyTargets(policy).map(t => t.type + ':' + t.value).sort().join('|');
  return [scope, _5qNorm(policy.classification_scope), _5qNorm(policy.micro_intent_scope), targets].join('::');
}

function _5qSelectBehaviouralPolicyMatches(policies, category, microIntent, additionalIntents, campaignContext, nes) {
  const allowedStatuses = new Set(['active', 'effective']);
  const allowedTypes = new Set(['style', 'draft_improvement', 'draft_behaviour', 'draft_behavior', 'behavioural_draft_policy', 'behavioral_draft_policy']);
  const seenIds = new Set();
  const newestByScope = new Map();

  for (const p of (Array.isArray(policies) ? policies : [])) {
    const status = String(p.status || '').trim().toLowerCase();
    const type = String(p.rule_type || p.policy_type || '').trim().toLowerCase();
    const id = String(p.rule_id || p.policy_id || '').trim();
    const instruction = String(p.behavioural_instruction || p.behavioral_instruction || p.desired_future_behavior || p.proposed_rule_text || p.reason || '').trim();
    if (!allowedStatuses.has(status)) continue;
    if (!allowedTypes.has(type)) continue;
    if (!instruction) continue;
    if (p.safety_blocked === true || p.unsafe === true) continue;
    if (!_5qPolicyApplies(p, category, microIntent, additionalIntents, campaignContext, nes)) continue;
    const idKey = id || instruction;
    if (seenIds.has(idKey)) continue;
    seenIds.add(idKey);
    const scopeKey = _5qPolicyScopeKey(p) || idKey;
    const candidate = {
      id: id || ('policy-' + seenIds.size),
      rule_id: p.rule_id || id || '',
      policy_id: p.policy_id || p.rule_id || id || '',
      instruction,
      human_instruction: p.human_instruction || p.behavioural_instruction || p.behavioral_instruction || p.proposed_rule_text || instruction,
      time: _5qPolicyTime(p),
      scopeKey,
      source_case_id: p.source_case_id || '',
      source_original_case_id: p.source_original_case_id || p.source_case_id || '',
      source_marker: p.source_marker || '',
      activation_source: p.activation_source || '',
      rule_type: p.rule_type || p.policy_type || '',
      classification_scope: p.classification_scope || '',
      micro_intent_scope: p.micro_intent_scope || '',
      original_classification: p.original_classification || null,
      corrected_effective_classification: p.corrected_effective_classification || null,
      target_classification_used: p.target_classification_used || null
    };
    const existing = newestByScope.get(scopeKey);
    if (!existing || candidate.time >= existing.time) newestByScope.set(scopeKey, candidate);
  }

  return Array.from(newestByScope.values()).sort((a, b) => b.time - a.time || String(a.id).localeCompare(String(b.id)));
}

function _5qFormatBehaviouralPolicyGuidance(matched) {
  const policies = Array.isArray(matched) ? matched : [];
  if (policies.length === 0) return '';
  return '\n\nMANDATORY ACTIVE DRAFTING CONSTRAINTS FROM OWNER-APPROVED POLICIES:\n' +
    policies.map((p, i) => `${i + 1}. ${p.id} [source_case_id: ${p.source_case_id || 'unknown'}; source_marker: ${p.source_marker || p.activation_source || 'unknown'}]: ${p.instruction}`).join('\n') +
    '\nThese constraints are non-optional for this draft. Newer active policies override older contradictory policies in the same scope. Apply them inside the final draft text, while still obeying safety gates and forbidden-claim restrictions.\n' +
    'Before returning JSON, check the draft against every active constraint. Reject and rewrite your own draft if it violates any active constraint, including paragraph length, list formatting, malformed acknowledgements, grammar, CTA placement, or prohibited validation/proof mentions.';
}

function buildBehaviouralPolicyGuidance(policies, category, microIntent, additionalIntents, campaignContext, nes) {
  return _5qFormatBehaviouralPolicyGuidance(_5qSelectBehaviouralPolicyMatches(policies, category, microIntent, additionalIntents, campaignContext, nes));
}

function _5qFormCreatedDraftRuleMatches(matched) {
  return (Array.isArray(matched) ? matched : []).filter(p => {
    const marker = String(p.source_marker || p.activation_source || '');
    return !!p.source_case_id && /humanapproval_form_created_learning|humanapproval_form/i.test(marker);
  });
}

function _5qExtractExactStartInstruction(behaviouralGuidance) {
  const guidance = String(behaviouralGuidance || '');
  const m = /start\s+(?:the\s+)?draft\s+with\s+exactly\s*[:]?\s*["“]([^"”]+)["”]/i.exec(guidance);
  return m && m[1] ? m[1].trim() : '';
}

function _5qApplyExactStartInstruction(text, behaviouralGuidance) {
  const phrase = _5qExtractExactStartInstruction(behaviouralGuidance);
  if (!phrase || !text) return text;
  const current = String(text).trimStart();
  if (current.startsWith(phrase)) return text;
  return phrase + '\n\n' + current.replace(/^(Thanks[^\n.]*\.|Happy to explain\.|Happy to talk it through\.|Here is the short version\.)\s*/i, '').trimStart();
}

function _5qExtractFirstUrl(text) {
  const m = /https?:\/\/[^\s)]+/i.exec(String(text || ''));
  return m && m[0] ? m[0].replace(/[.,;]+$/, '') : '';
}

function _5qInstructionLinesFromGuidance(behaviouralGuidance) {
  const lines = String(behaviouralGuidance || '').split(/\n/);
  const chunks = [];
  let current = null;
  let include = false;
  function flush() {
    if (!current || !include) return;
    const raw = current.join(' ').replace(/\s+/g, ' ').trim();
    const instruction = raw.replace(/^\d+\.\s*/, '').replace(/^[^\]]*\]:\s*/, '').trim();
    if (instruction) chunks.push(instruction);
  }
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (/^\d+\.\s+/.test(trimmed)) {
      flush();
      current = [trimmed];
      include = /source_case_id:/i.test(trimmed) && /humanapproval_form_created_learning|humanapproval_form/i.test(trimmed);
      continue;
    }
    if (/^(These constraints are|Before returning JSON)/i.test(trimmed)) {
      flush();
      current = null;
      include = false;
      continue;
    }
    if (current) current.push(trimmed);
  }
  flush();
  return chunks;
}

function _5qInstructionSentence(instruction, pattern) {
  const text = String(instruction || '').replace(/https?:\/\/[^\s)]+/gi, ' ').replace(/\r/g, ' ');
  const pieces = text.split(/(?:\n+|[.!?]+\s*)/).map(s => s.trim()).filter(Boolean);
  const picked = pieces.find(s => pattern.test(s) && !/\bdo\s+not\b/i.test(s));
  if (!picked) return '';
  let sentence = picked
    .replace(/^\s*(?:just\s+)?(?:share\s+the\s+booking\s+link\s+and\s+)?/i, '')
    .replace(/^offer\s+that\s+/i, '')
    .replace(/^at\s+the\s+end\s+you\s+can\s+mention\s+(?:that|thaqt)\s+/i, '')
    .replace(/\bthey\s+can\b/ig, 'you can')
    .replace(/\bthey\s+share\b/ig, 'you share')
    .replace(/\btheir\b/ig, 'your')
    .replace(/\bthem\b/ig, 'you')
    .trim();
  if (!sentence) return '';
  return /[.!?]$/.test(sentence) ? sentence : sentence + '.';
}

function _5qApplyActiveFormRuleInstructionToDraft(text, microIntent, behaviouralGuidance, senderName, bookingLink) {
  const guidance = String(behaviouralGuidance || '');
  if (!text || !guidance) return text;
  const mi = _5qNorm(microIntent);
  if (!(mi === 'BOOKING_REQUEST' || mi === 'MEETING_TIME_REQUEST')) return text;
  if (!/humanapproval_form_created_learning|humanapproval_form/i.test(guidance)) return text;
  const instructions = _5qInstructionLinesFromGuidance(guidance);
  if (instructions.length === 0) return text;
  const instruction = instructions.join(' ');
  if (!/\b(booking link|calendar link)\b/i.test(instruction)) return text;

  const link = _5qExtractFirstUrl(instruction) || bookingLink || '';
  const parts = [];
  if (link) parts.push('Booking link: ' + link);
  const availabilityLine = _5qInstructionSentence(instruction, /availability|available times|book (?:them|it|you) in|book.*in/i);
  const questionLine = _5qInstructionSentence(instruction, /any questions?|ask any question/i);
  if (availabilityLine) parts.push(availabilityLine);
  if (questionLine) parts.push(questionLine);
  if (parts.length === 0) return text;
  if (senderName) parts.push(senderName);
  return parts.join('\n\n');
}

function _5qApplyActiveRuleDraftPostprocessing(text, microIntent, behaviouralGuidance, senderName, bookingLink) {
  let out = _5qApplyExactStartInstruction(text, behaviouralGuidance);
  out = _5qApplyActiveFormRuleInstructionToDraft(out, microIntent, behaviouralGuidance, senderName, bookingLink);
  return out;
}

function _5qNormalizeDraftForLearningDelta(value) {
  return String(value || '').replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
}
function _5qDraftLearningDelta(beforeText, afterText) {
  const before = _5qNormalizeDraftForLearningDelta(beforeText);
  const after = _5qNormalizeDraftForLearningDelta(afterText);
  const changed = !!after && before !== after;
  return { changed, before, after };
}
function _5qLearningImpactSummary(delta, draftRules, classificationRules) {
  const parts = [];
  const dRules = Array.isArray(draftRules) ? draftRules : [];
  const cRules = Array.isArray(classificationRules) ? classificationRules : [];
  if (cRules.length > 0) {
    parts.push('Classification changed by HumanApproval form rule ' + cRules.map(r => r.rule_id).filter(Boolean).join(', ') + '.');
  }
  if (delta && delta.changed && dRules.length > 0) {
    const ids = dRules.map(r => r.rule_id).filter(Boolean).join(', ') || 'unknown';
    const cases = dRules.map(r => r.source_case_id).filter(Boolean).join(', ') || 'unknown source case';
    parts.push('Draft changed by HumanApproval form rule ' + ids + ' from source case ' + cases + ': final draft differs from the pre-learning draft after active rule postprocessing.');
  }
  return parts.join(' ');
}

function _5qReplyHasBookingIntent(text) {
  return /\b(booking link|calendar link|calendly|choose a time|pick a time|pick a meeting time|meeting time|grab (a )?(time|slot)|time on (your|the) calendar|slot on (your|the) calendar|your calendar|book (a )?(time|slot|call)|schedule (a )?(time|call)|send (me )?(the )?(booking|calendar) link|share (the )?(booking|calendar) link|availability|available times|time options)\b/i.test(String(text || ""));
}
function _5qClassificationRuleAllowedForReply(rule, replyText) {
  const corrected = rule && rule.corrected_effective_classification ? rule.corrected_effective_classification : {};
  const correctedCat = _5qNorm(corrected.broad_category);
  const correctedMi = _5qNorm(corrected.micro_intent);
  const promotesBooking = correctedCat === "BOOKING_REQUEST" || correctedMi === "BOOKING_REQUEST" || correctedMi === "MEETING_TIME_REQUEST";
  if (promotesBooking && !_5qReplyHasBookingIntent(replyText)) return false;
  return true;
}
function _5qSelectClassificationLearningRule(rules, category, microIntent, replyText) {
  const cat = _5qNorm(category);
  const mi = _5qNorm(microIntent);
  const protectedBaselineCategories = new Set(["UNSUBSCRIBE", "LEGAL_PRIVACY_OR_COMPLAINT", "HOSTILE_OR_REPUTATIONAL_RISK", "BOUNCE_OR_DELIVERY_NOTICE", "OUT_OF_OFFICE"]);
  if (protectedBaselineCategories.has(cat)) return null;
  const newestByScope = new Map();
  for (const rule of (Array.isArray(rules) ? rules : [])) {
    const original = rule.original_classification || {};
    if (_5qNorm(original.broad_category) !== cat || _5qNorm(original.micro_intent) !== mi) continue;
    if (!_5qClassificationRuleAllowedForReply(rule, replyText)) continue;
    const key = rule.scope_key || [cat, mi].join("|");
    const existing = newestByScope.get(key);
    if (!existing || rule.time >= existing.time) newestByScope.set(key, rule);
  }
  const candidates = Array.from(newestByScope.values()).sort((a, b) => b.time - a.time || String(a.rule_id || "").localeCompare(String(b.rule_id || "")));
  return candidates[0] || null;
}
function _5qApplyDynamicClassificationLearning(classifier, decision, detFlags, replyText) {
  const baselineCategory = classifier.category || decision.category || "";
  const baselineMicroIntent = classifier.micro_intent || "";
  const selected = _5qSelectClassificationLearningRule(DYNAMIC_FORM_CLASSIFICATION_RULES, baselineCategory, baselineMicroIntent, replyText);
  const baseline = { broad_category: baselineCategory, micro_intent: baselineMicroIntent };
  if (!selected) {
    return {
      classifier,
      decision: {
        ...decision,
        micro_intent: decision.micro_intent || baselineMicroIntent,
        baseline_classification: baseline,
        effective_classification: baseline,
        active_learning_rules_applied: []
      },
      applied_rules: [],
      baseline,
      effective: baseline
    };
  }
  const corrected = selected.corrected_effective_classification || {};
  const effectiveCategory = corrected.broad_category || baselineCategory;
  const effectiveMicroIntent = corrected.micro_intent || baselineMicroIntent;
  const learnedDraftPolicy = _5qDraftPolicyFor(effectiveMicroIntent, detFlags);
  const eligible = {
    rule_id: selected.rule_id || "",
    source_case_id: selected.source_case_id || "",
    source_marker: selected.source_marker || selected.activation_source || "",
    activation_source: selected.activation_source || "",
    human_instruction: selected.human_instruction || "",
    original_classification: selected.original_classification || baseline,
    corrected_effective_classification: corrected,
    target_classification_used: selected.target_classification_used || corrected,
    applied_stage: "pre_draft_policy_selection"
  };
  const effective = { broad_category: effectiveCategory, micro_intent: effectiveMicroIntent };
  const classificationChanged = _5qNorm(effectiveCategory) !== _5qNorm(baselineCategory) || _5qNorm(effectiveMicroIntent) !== _5qNorm(baselineMicroIntent);
  const appliedRules = classificationChanged ? [eligible] : [];
  return {
    classifier: {
      ...classifier,
      category: effectiveCategory,
      micro_intent: effectiveMicroIntent,
      draft_policy: learnedDraftPolicy,
      baseline_classification: baseline,
      effective_classification: effective,
      active_learning_rules_eligible: [eligible],
      active_learning_rules_applied: appliedRules,
      classification_learning_applied: classificationChanged
    },
    decision: {
      ...decision,
      category: effectiveCategory,
      micro_intent: effectiveMicroIntent,
      reply_template_id: _5qTemplateIdFor(effectiveCategory, effectiveMicroIntent, decision.reply_template_id),
      reply_draft_status: learnedDraftPolicy === "NO_DRAFT" ? "NOT_APPLICABLE" : (learnedDraftPolicy === "HUMAN_ONLY" ? "NO_DRAFT_HUMAN_ONLY" : "DRAFT_PENDING_REVIEW"),
      reply_permitted: learnedDraftPolicy === "NO_DRAFT" ? false : decision.reply_permitted,
      human_review_required: learnedDraftPolicy === "NO_DRAFT" ? false : true,
      baseline_classification: baseline,
      effective_classification: effective,
      active_learning_rules_eligible: [eligible],
      active_learning_rules_applied: appliedRules,
      classification_learning_applied: classificationChanged,
      reason: classificationChanged ? (String(decision.reason || "") + " Dynamic HumanApproval form-created classification rule " + (selected.rule_id || "unknown") + " adjusted effective classification before draft policy selection.") : String(decision.reason || "")
    },
    eligible_rules: [eligible],
    applied_rules: appliedRules,
    baseline,
    effective
  };
}

function buildPolicyAwareFallback(microIntent, deterministicText, firstName, senderName, bookingLink, behaviouralGuidance, prospectText) {
  const guidance = String(behaviouralGuidance || '');
  const prospect = String(prospectText || '');
  const asksSetup = /\b(setup|set up|include|involve|work|how it works|what your.*model)\b/i.test(prospect);
  const setupPolicy = /OFFER_EXPLANATION|setup question|answer the setup|short paragraphs|before any CTA|do not mention validation/i.test(guidance);

  if (microIntent === 'OFFER_EXPLANATION' && (asksSetup || setupPolicy)) {
    const greeting = firstName ? `Thanks, ${firstName}. Happy to explain.` : 'Happy to explain.';
    const parts = [
      greeting,
      'The setup is about matching outbound to the sales capacity your team can actually handle:',
      '1. Define the target accounts and qualification criteria.\n2. Build the message and routing around those criteria.\n3. Keep volume aligned to the number of useful conversations the team can work.'
    ];
    const link = bookingLink || 'https://calendar.app.google/bNXWJkS3xz3yqdW36';
    if (link) parts.push('If useful, we can walk through whether it fits your team on a brief 10-minute conversation here: ' + link);
    if (senderName) parts.push(senderName);
    return parts.join('\n\n');
  }

  if (microIntent === 'OFFER_EXPLANATION') {
    const greeting = firstName ? `Thanks, ${firstName}. Happy to explain.` : 'Happy to explain.';
    const parts = [
      greeting,
      'The short version is that we help define the right target accounts, shape the outbound message, and keep outreach volume aligned to the conversations your team can actually handle.'
    ];
    const link = bookingLink || 'https://calendar.app.google/bNXWJkS3xz3yqdW36';
    if (link) parts.push('If useful, we can walk through whether it fits your team on a brief 10-minute conversation here: ' + link);
    if (senderName) parts.push(senderName);
    return parts.join('\n\n');
  }

  if (!deterministicText && ['HOW_IT_WORKS_REQUEST','AMBIGUOUS_SHORT_REPLY','POSITIVE_INTEREST_GENERAL'].includes(microIntent)) {
    const parts = ['Thanks. Happy to talk it through.'];
    const link = bookingLink || 'https://calendar.app.google/bNXWJkS3xz3yqdW36';
    if (link) parts.push('You can grab 10 minutes here: ' + link);
    if (senderName) parts.push(senderName);
    return parts.join('\n\n');
  }

  return deterministicText;
}

function buildAIPrompt(microIntent, replyText, firstName, campaignContext, behaviouralGuidance) {
  const cell        = (campaignContext && campaignContext.validation_cell) || 'UNKNOWN';
  const painTrigger = (campaignContext && campaignContext.pain_trigger)    || 'outbound capacity problem';
  const offerAngle  = (campaignContext && campaignContext.offer_angle)     || 'capacity-aligned outbound validation';
  const intInstr = {
    PROOF_OR_CASE_STUDY_REQUEST: 'Acknowledge honestly: validation stage, no public case studies or proven results yet. Invite the 10-minute call as the proof step. Zero invented results.',
    OFFER_EXPLANATION:           'Explain capacity-aligned outbound in 1-2 short paragraphs. Do not mention validation stage, proof, public examples, or case studies unless the prospect explicitly asks for proof, examples, maturity, or results. Use bullets or a numbered list when explaining setup steps. Put any CTA at the end.',
    HOW_IT_WORKS_REQUEST:        'Give a 2-sentence explanation of how the model works (define capacity, build outbound to fill it). Invite the 10-minute call.',
    CURRENT_OUTBOUND_VENDOR:     'Ask ONE diagnostic question to identify where the bottleneck is. Do not pitch the offer again. One question only.',
    AMBIGUOUS_SHORT_REPLY:       'Ask ONE light clarifying question OR suggest the 10-minute call. One option only. Brief.',
    POSITIVE_INTEREST_GENERAL:   'Confirm readiness for a brief call. Offer <<bookingLink>> or reply with times. One CTA.'
  };
  const instr    = intInstr[microIntent] || intInstr.OFFER_EXPLANATION;
  const nameHint = firstName ? 'Use <<firstName>> to address them.' : 'Do not include a name greeting.';
  return `You are a B2B email draft assistant for a validation-stage outbound service.

STRICT RULES (any violation causes rejection and fallback to template):
- FORBIDDEN WORDS/PHRASES — never write these, not even in negated sentences: proof, proven, proves, case study, case studies, result, results, ROI, guaranteed, established, industry leader, clients have achieved, delivered results
- For proof or case-study requests use ONLY these safe alternatives: public customer examples, early customer evidence, validation signal, live comparison, outcome discussion
- Mention validation stage, proof, public examples, case studies, or missing customer evidence ONLY when the prospect explicitly asks for proof, examples, maturity, results, or case studies
- No pricing, cost figures, or budget language
- No "proven", "established", "industry leader", or maturity claims
- Do not include any signoff, closing phrase, sender name, or signature. Do not write "Best,", "Regards,", "Thanks,", "Kind regards,", or "Sincerely,". The system appends the sender name separately.
- No em dashes
- No generic AI filler language
- Use <<firstName>>, <<senderName>>, <<bookingLink>> as literal placeholders - do not resolve them
- Maximum 5 sentences total
- No malformed acknowledgement or empty-name opener such as "Absolutely, .", "Thanks, .", or "Hi, ."
- Use short paragraphs; when explaining setup or multiple parts, use a numbered or bulleted list where suitable
- Put the CTA at the end, after answering the prospect
- Output ONLY valid JSON on a single line with exactly these fields:
  {"draft_text":"...","reasoning_summary":"short explanation of approach","risk_flags":[]}

CAMPAIGN CONTEXT: cell=${cell}, pain=${painTrigger}, angle=${offerAngle}
MICRO INTENT: ${microIntent}
INSTRUCTIONS: ${instr}
${nameHint}${behaviouralGuidance || ""}

PROSPECT EMAIL:
${replyText}

FINAL SELF-CHECK BEFORE OUTPUT:
- Does the draft obey every mandatory active drafting constraint above?
- Does it avoid malformed openers and grammar errors?
- If the prospect did not ask for proof/examples/results/maturity, does it avoid validation/proof/public-example/case-study language?
- If the prospect asked what setup includes, does it answer first in short paragraphs or a list before the CTA?

Output only JSON with exactly: draft_text, reasoning_summary, risk_flags`;
}

// === OpenAI Responses API call ================================================
async function callAI(prompt, apiKey) {
  if (!apiKey) return { ok:false, error:'no OPENAI_API_KEY', provider:'openai' };
  let timer;
  try {
    const reqBody = {
      model:              AI_DRAFT_MODEL,
      max_output_tokens:  AI_DRAFT_MAX_OUTPUT_TOKENS,
      input: [{ role:'user', content:prompt }]
    };
    // Temperature: included by default; if model rejects it the error falls back to deterministic
    if (typeof AI_DRAFT_TEMPERATURE === 'number') reqBody.temperature = AI_DRAFT_TEMPERATURE;

    if (typeof this.helpers.httpRequest !== 'function') {
      return { ok:false, error:'this.helpers.httpRequest is not available in this n8n sandbox', provider:'openai' };
    }
    const _httpPromise    = this.helpers.httpRequest({
      method:  'POST',
      url:     'https://api.openai.com/v1/responses',
      headers: { 'Content-Type':'application/json', 'Authorization':'Bearer ' + apiKey },
      body:    reqBody,
      json:    true
    });
    const _timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('AI request timed out after ' + AI_DRAFT_TIMEOUT_MS + 'ms')), AI_DRAFT_TIMEOUT_MS);
    });
    const data = await Promise.race([_httpPromise, _timeoutPromise]);
    clearTimeout(timer);
    // Responses API structure: data.output[0].content[0].text
    const raw = (
      data.output && data.output[0] &&
      data.output[0].content && data.output[0].content[0] &&
      data.output[0].content[0].text
    ) || '';
    if (!raw.trim()) return { ok:false, error:'OpenAI returned empty output text', provider:'openai' };

    let parsed;
    try { parsed = JSON.parse(raw.trim()); }
    catch(e) { return { ok:false, error:'OpenAI response not valid JSON: ' + raw.slice(0,120), provider:'openai' }; }

    if (typeof parsed.draft_text !== 'string')       return { ok:false, error:'AI response missing draft_text',       provider:'openai' };
    if (typeof parsed.reasoning_summary !== 'string') return { ok:false, error:'AI response missing reasoning_summary', provider:'openai' };
    if (!Array.isArray(parsed.risk_flags))            return { ok:false, error:'AI response missing risk_flags array',  provider:'openai' };

    return {
      ok:               true,
      draft_text:       parsed.draft_text,
      reasoning_summary:parsed.reasoning_summary,
      risk_flags:       parsed.risk_flags,
      provider:         'openai'
    };
  } catch(e) {
    clearTimeout(timer);
    return { ok:false, error:String(e && e.message ? e.message : e), provider:'openai' };
  }
}

// === MAIN ====================================================================
const results = [];
for (const item of items) {
  const input    = item.json || {};
  try {
  const baselineDecision = input.decision   || {};
  const nes      = input.nes        || {};
  const baselineClassifier = input.classifier || {};
  const detFlags = (input.deterministic && input.deterministic.flags) || {};
  const replyText   = String((nes.reply && nes.reply.text) || '');
  const learnedClassification = _5qApplyDynamicClassificationLearning(baselineClassifier, baselineDecision, detFlags, replyText);
  const decision = learnedClassification.decision;
  const cls = learnedClassification.classifier;

  const microIntent  = cls.micro_intent || 'AMBIGUOUS_SHORT_REPLY';
  const draftPolicy  = cls.draft_policy || _5qDraftPolicyFor(microIntent, detFlags) || 'HUMAN_ONLY';

  const firstName   = resolveFirstName(nes);
  const eKey        = String(nes.eaccount || '').trim().toLowerCase();
  const sCfg        = SENDER_CONFIG[eKey] || null;
  let   senderName  = (sCfg && (sCfg.senderName || sCfg.sender_name)) || null;
  if (!senderName) {
    const _toJson = input.raw_payload &&
      input.raw_payload._instantly_hydrated_email &&
      Array.isArray(input.raw_payload._instantly_hydrated_email.to_address_json) &&
      input.raw_payload._instantly_hydrated_email.to_address_json[0];
    if (_toJson && typeof _toJson.name === 'string' && _toJson.name.trim()) {
      senderName = _toJson.name.trim().split(/\s+/)[0];
    }
  }
  if (!senderName && eKey) {
    const _lp = eKey.split('@')[0];
    if (_lp) senderName = _lp.charAt(0).toUpperCase() + _lp.slice(1);
  }
  const bookingLink = sCfg && sCfg.bookingLink ? sCfg.bookingLink : null;
  const campaignCtx = nes.campaign_context || {};

  const activeFormAndBaselinePolicies = ACTIVE_BEHAVIOURAL_POLICIES.concat(DYNAMIC_FORM_BEHAVIOURAL_POLICIES);
  const activeDraftRuleMatches = _5qSelectBehaviouralPolicyMatches(activeFormAndBaselinePolicies, decision.category || cls.category || "", microIntent, cls.detected_intents || cls.additional_intents || [], campaignCtx, nes);
  const behaviouralGuidance = _5qFormatBehaviouralPolicyGuidance(activeDraftRuleMatches);
  const activeFormDraftRuleMatches = _5qFormCreatedDraftRuleMatches(activeDraftRuleMatches);
  const activeDraftRulesApplied = activeFormDraftRuleMatches.length;
  const activeFormDraftRuleMetadataRaw = activeFormDraftRuleMatches.map(p => ({
    rule_id: p.rule_id || p.id || "",
    source_case_id: p.source_case_id || "",
    source_marker: p.source_marker || p.activation_source || "",
    activation_source: p.activation_source || "",
    human_instruction: p.human_instruction || p.instruction || "",
    classification_scope: p.classification_scope || "",
    micro_intent_scope: p.micro_intent_scope || "",
    scope: [p.classification_scope || "", p.micro_intent_scope || ""].filter(Boolean).join(" / ") || p.scopeKey || "",
    original_classification: p.original_classification || null,
    corrected_effective_classification: p.corrected_effective_classification || null,
    target_classification_used: p.target_classification_used || null,
    applied_learning_type: "draft",
    applied_to_draft: false
  }));
  const templateMicroIntent = microIntent === 'BOOKING_REQUEST' ? 'MEETING_TIME_REQUEST' : microIntent;
  const tmpl              = MI_TEMPLATES[templateMicroIntent] || null;
  const deterministicText = tmpl ? renderTemplate(tmpl, firstName, senderName, bookingLink) : null;
  const fallbackText      = buildPolicyAwareFallback(microIntent, deterministicText, firstName, senderName, bookingLink, behaviouralGuidance, replyText);

  let draftText   = null;
  let draftSource = 'none';
  let aiAttempt   = null;

  const canTryAI = (
    AI_DRAFT_MODE  === 'supervised' &&
    draftPolicy    === 'AI_SUPERVISED_OR_TEMPLATE' &&
    decision.reply_permitted !== false &&
    replyText.trim().length > 0
  );

  if (canTryAI && AI_API_KEY) {
    const prompt   = buildAIPrompt(microIntent, replyText, firstName, campaignCtx, behaviouralGuidance) + ACTIVE_RULE_GUIDANCE;
    let aiResult;
    try {
      aiResult = await callAI(prompt, AI_API_KEY);
    } catch (e) {
      aiResult = { ok:false, error:String(e && e.message ? e.message : e), provider:'openai', fallback_reason:'DRAFT_PREP_EXCEPTION_FALLBACK', diagnostic_reason:'AI_PROVIDER_RUNTIME_EXCEPTION' };
    }
    aiAttempt      = aiResult;
    if (aiResult.ok && aiResult.draft_text) {
      const errs = validateAI(aiResult.draft_text, microIntent, behaviouralGuidance, replyText);
      if (errs.length === 0) {
        const resolved = aiResult.draft_text
          .replace(/<<firstName>>/g,   firstName   || '')
          .replace(/<<senderName>>/g,  senderName  || '')
          .replace(/<<bookingLink>>/g, bookingLink || 'https://calendar.app.google/bNXWJkS3xz3yqdW36');
        draftText   = resolved;
        draftSource = 'ai_supervised';
        if (senderName) {
          const _esc = senderName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          const _signoffRx = new RegExp(
            '\\n+(?:(?:best|regards|thanks|kind\\s+regards|sincerely|cheers)[,.]?[\\s]*\\n*)?\\s*' + _esc + '\\s*$',
            'i'
          );
          const _stripped = draftText.trimEnd().replace(_signoffRx, '');
          draftText = _stripped.trimEnd() + '\n\n' + senderName;
        }
        const BOOKING_LINK = 'https://calendar.app.google/bNXWJkS3xz3yqdW36';
        const _ctaRx = /(\b(?:you\s+can\s+)?book(?:\s+(?:a\s+)?time)?(?:\s+here)?)\s*:\s*(?!https?:\/\/)\.?[ \t]*/gi;
        draftText = draftText.replace(_ctaRx, '$1: ' + BOOKING_LINK);
        const _bkEsc = BOOKING_LINK.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        let _bkSeen = false;
        draftText = draftText.replace(new RegExp(_bkEsc, 'g'), () => _bkSeen ? '' : (_bkSeen = true, BOOKING_LINK));
      } else {
        draftText   = fallbackText;
        draftSource = 'ai_failed_fallback';
        aiAttempt   = { ...aiResult, validation_errors: errs, fallback_reason: 'AI_OUTPUT_VALIDATION_FAILED' };
      }
    } else {
      draftText   = fallbackText;
      draftSource = 'ai_failed_fallback';
      aiAttempt   = { ...aiResult, fallback_reason: 'AI_PROVIDER_OR_RESPONSE_FAILED' };
    }
  } else if (canTryAI && !AI_API_KEY) {
    draftText   = fallbackText;
    draftSource = 'ai_failed_fallback';
    aiAttempt   = { ok:false, error:'no OPENAI_API_KEY', provider:'openai', fallback_reason:'AI_PROVIDER_CONFIG_MISSING' };
  } else if (['AI_SUPERVISED_OR_TEMPLATE','FIXED_TEMPLATE','FIXED_TEMPLATE_SUPPRESS_ONLY'].includes(draftPolicy)) {
    draftText   = fallbackText;
    draftSource = 'deterministic_template';
  } else if (draftPolicy === 'AI_COMMERCIAL_SUPERVISED') {
    // SL-PHASE-4A: Non-committal context-aware commercial draft
    var _di4d = cls.detected_intents || [];
    var _hP = microIntent === 'PRICING_REQUEST' || _di4d.some(function(i){return i.micro_intent==='PRICING_REQUEST';});
    var _hD = _di4d.some(function(i){return i.micro_intent==='DATA_SECURITY_REQUEST';});
    var _hC = _di4d.some(function(i){return i.micro_intent==='CONTRACT_TERMS_REQUEST';});
    var _hPi = _di4d.some(function(i){return i.micro_intent==='SMALL_SCALE_PILOT_REQUEST';});
    var _hS = _di4d.some(function(i){return i.micro_intent==='SCOPE_REQUEST';});
    var _gr = firstName ? ('Thanks, ' + firstName + '.') : 'Thanks.';
    var _ps = [_gr, 'Happy to answer these.'];
    if (_hP)  _ps.push('Pricing depends on scope. I want to give you a number that actually reflects your situation rather than a generic figure. The best way to do that is a brief 10-minute conversation.');
    if (_hD)  _ps.push('Your data would only be used for the agreed campaign. We would not sell it, share it, or use it outside the agreed scope.');
    if (_hC)  _ps.push('Yes, there would be a simple agreement before anything starts. Nothing complex or long-term at this stage.');
    if (_hPi) _ps.push('Yes, we can test this with one small campaign first before committing to anything bigger. That is actually how we prefer to start.');
    if (_hS)  _ps.push('Happy to explain exactly what is involved. The short version: we define the target, build a focused prospect list, write and run the outreach, then review results together.');
    _ps.push('If it helps to talk through the specifics, you can grab 10 minutes here: https://calendar.app.google/bNXWJkS3xz3yqdW36');
    if (senderName) _ps.push(senderName);
    draftText   = _ps.filter(function(p){return p.trim().length>0;}).join('\n\n');
    draftSource = 'ai_commercial_supervised';
  } else {
    draftText   = null;
    draftSource = draftPolicy === 'NO_DRAFT' ? 'none' : 'human_only';
  }

  // Active human-created policies apply to AI, fallback, commercial, and deterministic template drafts.
  const draftTextBeforeActiveLearning = draftText || '';
  if (draftText) draftText = _5qApplyActiveRuleDraftPostprocessing(draftText, microIntent, behaviouralGuidance, senderName, bookingLink);

  // Token safety check: reject any unresolved <<...>> or {{...}} in final draft_text
  if (draftText && (/<<\w+>>/.test(draftText) || /\{\{[^}]*\}\}/.test(draftText))) {
    draftText   = fallbackText;
    draftSource = 'ai_failed_fallback';
    if (aiAttempt) aiAttempt = { ...aiAttempt, fallback_reason: aiAttempt.fallback_reason || 'FINAL_DRAFT_TOKEN_VALIDATION_FAILED', validation_errors: (aiAttempt.validation_errors||[]).concat(['unresolved token in final draft_text']) };
  }

  function _5qDraftPolicyLabel(policy, learningApplied) {
    if (!learningApplied) return policy;
    if (policy === 'FIXED_TEMPLATE') return 'FIXED_TEMPLATE_WITH_FORM_LEARNING';
    if (policy === 'AI_COMMERCIAL_SUPERVISED') return 'AI_COMMERCIAL_SUPERVISED_WITH_FORM_LEARNING';
    if (policy === 'AI_SUPERVISED_OR_TEMPLATE') return 'AI_SUPERVISED_OR_TEMPLATE_WITH_FORM_LEARNING';
    if (policy === 'FIXED_TEMPLATE_SUPPRESS_ONLY') return 'FIXED_TEMPLATE_SUPPRESS_ONLY_WITH_FORM_LEARNING';
    return String(policy || 'UNKNOWN') + '_WITH_FORM_LEARNING';
  }
  function _5qDraftSourceLabel(source, learningApplied) {
    if (!learningApplied) return source;
    if (source === 'deterministic_template') return 'deterministic_template_with_form_learning';
    if (source === 'ai_supervised') return 'ai_supervised_with_form_learning';
    if (source === 'ai_commercial_supervised') return 'ai_commercial_supervised_with_form_learning';
    if (source === 'ai_failed_fallback') return 'ai_failed_fallback_with_form_learning';
    return String(source || 'unknown') + '_with_form_learning';
  }
  const draftLearningDelta = _5qDraftLearningDelta(draftTextBeforeActiveLearning, draftText || '');
  const learningAppliedToClassification = (learnedClassification.applied_rules || []).length > 0;
  const learningAppliedToDraft = activeDraftRulesApplied > 0 && draftLearningDelta.changed;
  const activeFormDraftRuleMetadata = activeFormDraftRuleMetadataRaw.map(r => ({ ...r, applied_to_draft: learningAppliedToDraft }));
  const learningImpactSummary = _5qLearningImpactSummary(draftLearningDelta, learningAppliedToDraft ? activeFormDraftRuleMetadata : [], learnedClassification.applied_rules || []);
  const activeLearningRulesFound = DYNAMIC_FORM_BEHAVIOURAL_POLICIES.map(p => ({
    rule_id: p.rule_id || p.policy_id || "",
    source_case_id: p.source_case_id || "",
    source_marker: p.source_marker || p.activation_source || "",
    scope: [p.classification_scope || "", p.micro_intent_scope || ""].filter(Boolean).join(" / ") || p.policy_precedence_key || "",
    learning_type: "draft",
    eligible: false,
    applied: false
  })).concat(DYNAMIC_FORM_CLASSIFICATION_RULES.map(r => ({
    rule_id: r.rule_id || "",
    source_case_id: r.source_case_id || "",
    source_marker: r.source_marker || r.activation_source || "",
    scope: r.scope_key || "classification",
    learning_type: "classification",
    eligible: false,
    applied: false
  })));
  const classificationEligibleMetadata = (learnedClassification.eligible_rules || learnedClassification.applied_rules || []).map(r => ({ ...r, learning_type: "classification", applied_learning_type: "classification", eligible: true, applied: learningAppliedToClassification }));
  const classificationAppliedMetadata = (learnedClassification.applied_rules || []).map(r => ({ ...r, learning_type: "classification", applied_learning_type: "classification", eligible: true, applied: true }));
  const draftEligibleMetadata = activeFormDraftRuleMetadata.map(r => ({ ...r, learning_type: "draft", eligible: true, applied: learningAppliedToDraft, learning_impact_summary: learningAppliedToDraft ? learningImpactSummary : null }));
  const activeLearningRulesEligible = classificationEligibleMetadata.concat(draftEligibleMetadata);
  const activeLearningRulesApplied = classificationAppliedMetadata.concat(learningAppliedToDraft ? draftEligibleMetadata : []);
  const draftPolicyRaw = draftPolicy;
  const draftSourceRaw = draftSource;
  const draftPolicyEffective = _5qDraftPolicyLabel(draftPolicyRaw, learningAppliedToDraft);
  const draftSourceEffective = _5qDraftSourceLabel(draftSourceRaw, learningAppliedToDraft);
  const learningNotAppliedReason = activeLearningRulesApplied.length > 0 ? null : (
    activeLearningRulesFound.length === 0 ? 'NO_ACTIVE_HUMANAPPROVAL_FORM_RULES_FOUND' :
    activeLearningRulesEligible.length === 0 ? 'ACTIVE_RULES_FOUND_BUT_NONE_ELIGIBLE_FOR_EFFECTIVE_CLASSIFICATION' :
    !draftText ? 'ELIGIBLE_RULES_FOUND_BUT_NO_DRAFT_TEXT' :
    activeLearningRulesEligible.length > 0 ? 'RULE_FOUND_BUT_NO_OUTPUT_DELTA' :
    'NO_ACTIVE_RULE_APPLIED_TO_CLASSIFICATION_OR_DRAFT'
  );
  const learningAttribution = {
    baseline_broad_category: learnedClassification.baseline && learnedClassification.baseline.broad_category || "",
    baseline_micro_intent: learnedClassification.baseline && learnedClassification.baseline.micro_intent || "",
    effective_broad_category: learnedClassification.effective && learnedClassification.effective.broad_category || "",
    effective_micro_intent: learnedClassification.effective && learnedClassification.effective.micro_intent || "",
    active_learning_rules_found: activeLearningRulesFound,
    active_learning_rules_eligible: activeLearningRulesEligible,
    active_learning_rules_applied: activeLearningRulesApplied,
    applied_learning_rule_ids: activeLearningRulesApplied.map(r => r.rule_id).filter(Boolean),
    applied_learning_source_case_ids: activeLearningRulesApplied.map(r => r.source_case_id).filter(Boolean),
    applied_learning_source_markers: activeLearningRulesApplied.map(r => r.source_marker).filter(Boolean),
    applied_learning_scopes: activeLearningRulesApplied.map(r => r.scope || [r.classification_scope || "", r.micro_intent_scope || ""].filter(Boolean).join(" / ")).filter(Boolean),
    learning_applied_to_classification: learningAppliedToClassification,
    learning_applied_to_draft: learningAppliedToDraft,
    learning_impact_summary: learningImpactSummary,
    learning_not_applied_reason: learningNotAppliedReason,
    draft_policy_raw: draftPolicyRaw,
    draft_source_raw: draftSourceRaw,
    draft_policy_effective: draftPolicyEffective,
    draft_source_effective: draftSourceEffective
  };

  const missingVariables = [];
  if (!firstName  && tmpl && !tmpl.suppressFirstName) missingVariables.push('firstName');
  if (!senderName) missingVariables.push('senderName');
  if (tmpl && tmpl.bookingLinkLine && !bookingLink) missingVariables.push('bookingLink');

  const draft = {
    template_id:           decision.reply_template_id || null,
    micro_intent:          microIntent,
    draft_policy:          draftPolicyEffective,
    draft_source:          draftSourceEffective,
    draft_policy_raw:      draftPolicyRaw,
    draft_source_raw:      draftSourceRaw,
    draft_policy_effective:draftPolicyEffective,
    draft_source_effective:draftSourceEffective,
    draft_text:            draftText,
    draft_status:          decision.reply_draft_status || 'NOT_APPLICABLE',
    missing_variables:     missingVariables,
    human_review_required: decision.human_review_required === true,
    detected_intents: cls.detected_intents || [],
    ai_attempt: aiAttempt ? {
      provider:          AI_DRAFT_PROVIDER,
      model:             AI_DRAFT_MODEL,
      ok:                aiAttempt.ok,
      error:             aiAttempt.error   || null,
      reasoning_summary: aiAttempt.reasoning_summary || null,
      risk_flags:        aiAttempt.risk_flags         || [],
      validation_errors: aiAttempt.validation_errors  || [],
      fallback_reason:   aiAttempt.fallback_reason     || null,
      raw_draft_text:    aiAttempt.draft_text          || null
    } : null,
    notes: draftSource === 'ai_failed_fallback'
      ? 'AI drafting fallback used: ' + ((aiAttempt && aiAttempt.fallback_reason) || 'AI_FALLBACK_USED') + '. Human review required.'
      : (draftPolicy === 'HUMAN_ONLY'
        ? 'Human-only category per policy-HMZ-1.2. No automated draft.'
        : (draftPolicy === 'NO_DRAFT' ? 'No draft applicable (OOO/bounce/noop).' : null)),
    baseline_classification: learnedClassification.baseline,
    effective_classification: learnedClassification.effective,
    baseline_broad_category: learningAttribution.baseline_broad_category,
    baseline_micro_intent: learningAttribution.baseline_micro_intent,
    effective_broad_category: learningAttribution.effective_broad_category,
    effective_micro_intent: learningAttribution.effective_micro_intent,
    classification_learning_rules_applied: learnedClassification.applied_rules,
    active_form_draft_rule_count: activeDraftRulesApplied,
    active_form_draft_rules_applied: activeFormDraftRuleMetadata,
    active_form_learning_source: activeDraftRulesApplied > 0 ? 'humanapproval_form_created_learning' : null,
    active_form_draft_learning_applied: learningAppliedToDraft,
    active_form_draft_learning_effect: learningAppliedToDraft ? 'runtime_rule_context_applied_after_effective_classification' : null,
    active_learning_rules_found: activeLearningRulesFound,
    active_learning_rules_eligible: activeLearningRulesEligible,
    active_learning_rules_applied: activeLearningRulesApplied,
    applied_learning_rule_ids: learningAttribution.applied_learning_rule_ids,
    applied_learning_source_case_ids: learningAttribution.applied_learning_source_case_ids,
    applied_learning_source_markers: learningAttribution.applied_learning_source_markers,
    applied_learning_scopes: learningAttribution.applied_learning_scopes,
    learning_applied_to_classification: learningAppliedToClassification,
    learning_applied_to_draft: learningAppliedToDraft,
    learning_impact_summary: learningImpactSummary,
    learning_not_applied_reason: learningNotAppliedReason,
    learning_attribution: learningAttribution
  };

  results.push({ json: { ...input, classifier: cls, decision, draft } });
  } catch (e) {
    const nes = input.nes || {};
    const existingClassifier = input.classifier || {};
    const existingDecision = input.decision || {};
    const detFlags = (input.deterministic && input.deterministic.flags) || {};
    const microIntent = existingClassifier.micro_intent || existingDecision.micro_intent || 'AMBIGUOUS_SHORT_REPLY';
    const draftPolicy = existingClassifier.draft_policy || _5qDraftPolicyFor(microIntent, detFlags) || 'AI_SUPERVISED_OR_TEMPLATE';
    const category = existingClassifier.category || existingDecision.category || 'AMBIGUOUS';
    const firstName = resolveFirstName(nes);
    const eKey = String(nes.eaccount || '').trim().toLowerCase();
    const sCfg = SENDER_CONFIG[eKey] || null;
    let senderName = (sCfg && (sCfg.senderName || sCfg.sender_name)) || null;
    if (!senderName && eKey) {
      const local = eKey.split('@')[0];
      if (local) senderName = local.charAt(0).toUpperCase() + local.slice(1);
    }
    const bookingLink = sCfg && sCfg.bookingLink ? sCfg.bookingLink : null;
    const replyText = String((nes.reply && nes.reply.text) || '');
    const fallbackText = buildPolicyAwareFallback(microIntent, null, firstName, senderName, bookingLink, '', replyText) || (replyText.trim()
      ? ['Thanks' + (firstName ? ', ' + firstName : '') + '.', 'Happy to answer this. I need to review the exact context before sending, so I have prepared this for human review.', senderName || ''].filter(Boolean).join('\n\n')
      : null);
    const errMsg = String(e && e.message ? e.message : e);
    const classifier = {
      ...existingClassifier,
      category,
      micro_intent: microIntent,
      draft_policy: draftPolicy
    };
    const decision = {
      ...existingDecision,
      category,
      confidence: typeof existingDecision.confidence === 'number' ? existingDecision.confidence : (typeof existingClassifier.confidence === 'number' ? existingClassifier.confidence : 0.5),
      confidence_overridden: existingDecision.confidence_overridden === true,
      stop_active_sequence: existingDecision.stop_active_sequence === true,
      durable_dnc_intent: existingDecision.durable_dnc_intent === true,
      address_suppression_intent: existingDecision.address_suppression_intent || 'NONE',
      review_hold: true,
      legal_review_required: existingDecision.legal_review_required === true,
      privacy_review_required: existingDecision.privacy_review_required === true,
      reputational_review_required: existingDecision.reputational_review_required === true,
      human_review_required: true,
      reply_permitted: existingDecision.reply_permitted !== false,
      reply_template_id: existingDecision.reply_template_id || null,
      reply_draft_status: fallbackText ? 'DRAFT_PENDING_REVIEW' : 'NO_DRAFT_HUMAN_ONLY',
      external_action_status: 'NOT_PERFORMED',
      follow_up_date: existingDecision.follow_up_date || null,
      interest_stage: existingDecision.interest_stage || existingClassifier.interest_stage || 'UNKNOWN',
      terminal_status: 'REVIEW_HOLD',
      reason: 'DRAFT_PREP_NODE_EXCEPTION_FALLBACK: preserved Intake/Decision context after node D exception (' + errMsg + ')'
    };
    const learningAttribution = {
      baseline_broad_category: category,
      baseline_micro_intent: microIntent,
      effective_broad_category: category,
      effective_micro_intent: microIntent,
      active_learning_rules_found: [],
      active_learning_rules_eligible: [],
      active_learning_rules_applied: [],
      applied_learning_rule_ids: [],
      applied_learning_source_case_ids: [],
      applied_learning_source_markers: [],
      applied_learning_scopes: [],
      learning_applied_to_classification: false,
      learning_applied_to_draft: false,
      learning_impact_summary: null,
      learning_not_applied_reason: 'DRAFT_PREP_NODE_EXCEPTION_FALLBACK',
      draft_policy_raw: draftPolicy,
      draft_source_raw: 'node_exception_fallback',
      draft_policy_effective: draftPolicy,
      draft_source_effective: 'node_exception_fallback'
    };
    const draft = {
      template_id: decision.reply_template_id || null,
      micro_intent: microIntent,
      draft_policy: draftPolicy,
      draft_source: 'node_exception_fallback',
      draft_policy_raw: draftPolicy,
      draft_source_raw: 'node_exception_fallback',
      draft_policy_effective: draftPolicy,
      draft_source_effective: 'node_exception_fallback',
      draft_text: fallbackText,
      draft_status: decision.reply_draft_status,
      missing_variables: [],
      human_review_required: true,
      detected_intents: existingClassifier.detected_intents || [],
      ai_attempt: { provider: AI_DRAFT_PROVIDER, model: AI_DRAFT_MODEL, ok: false, error: errMsg, reasoning_summary: null, risk_flags: [], validation_errors: [], fallback_reason: 'DRAFT_PREP_NODE_EXCEPTION_FALLBACK', raw_draft_text: null },
      notes: 'Decision node D exception fallback used. Human review required.',
      baseline_classification: { broad_category: category, micro_intent: microIntent },
      effective_classification: { broad_category: category, micro_intent: microIntent },
      baseline_broad_category: category,
      baseline_micro_intent: microIntent,
      effective_broad_category: category,
      effective_micro_intent: microIntent,
      classification_learning_rules_applied: [],
      active_form_draft_rule_count: 0,
      active_form_draft_rules_applied: [],
      active_form_learning_source: null,
      active_form_draft_learning_applied: false,
      active_form_draft_learning_effect: null,
      active_learning_rules_found: [],
      active_learning_rules_eligible: [],
      active_learning_rules_applied: [],
      applied_learning_rule_ids: [],
      applied_learning_source_case_ids: [],
      applied_learning_source_markers: [],
      applied_learning_scopes: [],
      learning_applied_to_classification: false,
      learning_applied_to_draft: false,
      learning_impact_summary: null,
      learning_not_applied_reason: 'DRAFT_PREP_NODE_EXCEPTION_FALLBACK',
      learning_attribution: learningAttribution
    };
    results.push({ json: { ...input, classifier, decision, draft, draft_prep_exception_fallback: { applied: true, error: errMsg } } });
  }
}

return results;
