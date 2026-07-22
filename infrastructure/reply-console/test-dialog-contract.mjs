// Phase 7 — Google dialog response-contract tests. Runtime-evaluates the actual
// interaction-workflow code nodes and asserts the emitted JSON matches Google's
// required dialog contracts (open + submit). No network, no send.
import fs from 'node:fs';
import assert from 'node:assert';

const wf = JSON.parse(fs.readFileSync(new URL('../../workflows/HMZ_Google_Chat_Supervised_Reply_Console.json', import.meta.url)));
const nodeJs = (name) => wf.nodes.find((n) => n.name === name).parameters.jsCode;

let pass = 0; const out = [];
const t = (n, f) => { try { f(); out.push('PASS  ' + n); pass++; } catch (e) { out.push('FAIL  ' + n + ' :: ' + e.message); } };

// Evaluate a code node with mocked n8n globals; return the emitted json.
function runNode(js, { input = {}, ctx = {}, parse = { user_name: 'users/1' }, prep = {}, draft = {} } = {}) {
  const fn = new Function('$input', '$', js + '\n');
  const $ = (name) => ({
    item: { json: name === 'Card Router' ? { ctx, contextId: 'c1' } : name === 'Prep Edit Draft' ? prep : name === 'Handle Message' ? { contextId: 'c1' } : {} },
    first: () => ({ json: name === 'Parse & Authorize' ? parse : {} }),
  });
  const res = fn({ first: () => ({ json: input }) }, $);
  return JSON.parse(res[0].json.responseBody);
}

const CTX = { activeDraft: { body: 'Hello,\n\nEdited.\n\nHamza' }, prospectEmail: 'p@x.com', prospectName: 'Noah Cole', senderName: 'Hamza M', eaccount: 's@x.com', subject: 'Re: Q', uniboxUrl: 'https://app.instantly.ai/x' };

t('OPEN dialog: valid REQUEST_DIALOG response contract', () => {
  const r = runNode(nodeJs('Build Edit Dialog'), { input: { contextId: 'c1', cardToken: 'tok', ctx: CTX } });
  assert(r.actionResponse, 'has actionResponse');
  assert(r.actionResponse.type === 'DIALOG', 'type DIALOG');
  assert(r.actionResponse.dialogAction && r.actionResponse.dialogAction.dialog && r.actionResponse.dialogAction.dialog.body, 'dialogAction.dialog.body present');
  const sections = r.actionResponse.dialogAction.dialog.body.sections;
  assert(Array.isArray(sections) && sections.length >= 1, 'sections array');
  const ti = sections[0].widgets.find((w) => w.textInput);
  assert(ti && ti.textInput.name === 'reply_body' && ti.textInput.type === 'MULTIPLE_LINE', 'multiline textInput reply_body');
  assert(ti.textInput.value === CTX.activeDraft.body, 'prefilled with exact latest body');
  assert(!Array.isArray(r), 'not an array');
  assert(!('cardsV2' in r), 'no top-level cardsV2 on dialog open');
});

t('SUBMIT dialog: UPDATE_MESSAGE + cardsV2 (closes dialog, swaps card)', () => {
  const r = runNode(nodeJs('Build Review Card (edit)'), {
    input: { ok: true, reviewToken: 'newtok', revision: 2 },
    prep: { contextId: 'c1', body: 'Hello,\n\nEdited.\n\nHamza', ctx: CTX },
  });
  assert(r.actionResponse && r.actionResponse.type === 'UPDATE_MESSAGE', 'actionResponse UPDATE_MESSAGE');
  assert(Array.isArray(r.cardsV2) && r.cardsV2[0].card, 'cardsV2 present with card');
  const title = r.cardsV2[0].card.header.title;
  assert(/revision 2/.test(title), 'shows revision 2: ' + title);
  // exact edited body preserved (as <br>)
  const bodySection = r.cardsV2[0].card.sections.find((s) => s.header === 'Exact reply body');
  assert(/Hello,<br><br>Edited\.<br><br>Hamza/.test(bodySection.widgets[0].textParagraph.text), 'exact multiline body preserved');
  // buttons bound to the NEW token
  const btns = r.cardsV2[0].card.sections.flatMap((s) => s.widgets).filter((w) => w.buttonList).flatMap((w) => w.buttonList.buttons);
  const send = btns.find((b) => b.text === 'Send');
  assert(send.onClick.action.parameters.find((p) => p.key === 'tok').value === 'newtok', 'Send uses new token');
});

t('SUBMIT dialog failure: valid dialog actionStatus (not bare)', () => {
  const r = runNode(nodeJs('Build Review Card (edit)'), { input: { ok: false }, prep: { contextId: 'c1', ctx: CTX } });
  assert(r.actionResponse && r.actionResponse.type === 'DIALOG' && r.actionResponse.dialogAction.actionStatus, 'failure returns dialog actionStatus');
});

t('response is not an array / not double-encoded / not empty', () => {
  const r = runNode(nodeJs('Build Edit Dialog'), { input: { contextId: 'c1', cardToken: 'tok', ctx: CTX } });
  assert(typeof r === 'object' && !Array.isArray(r) && Object.keys(r).length > 0);
});

for (const l of out) console.log(l);
console.log(`\n${pass}/${out.length} dialog-contract tests passed`);
process.exit(pass === out.length ? 0 : 1);
