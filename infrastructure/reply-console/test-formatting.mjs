// Phase 5 formatting regression: replicates the EXACT extraction / card-render /
// dialog-normalisation code used by the interaction workflow, and proves the
// multiline body is preserved byte-for-byte (no whitespace collapse).
import assert from 'node:assert';
import crypto from 'node:crypto';
import { toHtml } from './store.mjs';

// --- extraction (interaction Parse node, MESSAGE branch) ---
function extractReply(msg) {
  let text = String(msg.argumentText != null ? msg.argumentText : (msg.text || ''));
  text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  if (msg.argumentText == null) { text = text.replace(/^[ \t]*@[^\s]+[ \t]*/, ''); }
  text = text.replace(/^\s+/, '').replace(/\s+$/, '');
  return text;
}
// --- card body render (Build Review Card) ---
function cardBody(body) {
  return String(body || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/\n/g, '<br>');
}
// --- dialog submit normalisation (Prep Edit Draft) ---
function normalizeEdit(editedBody) {
  return String(editedBody || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/^\s+/, '').replace(/\s+$/, '');
}

let pass = 0; const out = [];
const t = (n, f) => { try { f(); out.push('PASS  ' + n); pass++; } catch (e) { out.push('FAIL  ' + n + ' :: ' + e.message); } };

const BODY = 'Hey,\n\nHow are you?\n\nHamza';
const NUM = 'Hi,\n\nThanks for replying.\n\nNext steps:\n1. Review the details\n2. Confirm the timing\n\nBest,\nHamza';

t('argumentText multiline preserved exactly (LF)', () => {
  assert.strictEqual(extractReply({ argumentText: BODY }), BODY);
});
t('CRLF normalised to LF, structure preserved', () => {
  assert.strictEqual(extractReply({ argumentText: 'Hey,\r\n\r\nHow are you?\r\n\r\nHamza' }), BODY);
});
t('lone CR normalised to LF', () => {
  assert.strictEqual(extractReply({ argumentText: 'A\rB' }), 'A\nB');
});
t('mention at start (no argumentText) removed, body preserved', () => {
  assert.strictEqual(extractReply({ text: '@Instantly Hey,\n\nHow are you?\n\nHamza' }), BODY);
});
t('mention on its own line then blank line (fallback)', () => {
  // argumentText present is the normal case; fallback strips leading mention token only
  assert.strictEqual(extractReply({ text: '@Instantly\nHey,\n\nHamza' }), 'Hey,\n\nHamza');
});
t('outer blank lines trimmed, inner preserved', () => {
  assert.strictEqual(extractReply({ argumentText: '\n\n' + BODY + '\n\n' }), BODY);
});
t('numbered-list body: paragraphs + numbered lines stay separate', () => {
  const r = extractReply({ argumentText: NUM });
  assert.strictEqual(r, NUM);
  assert(r.split('\n').length === 10, 'ten lines: ' + r.split('\n').length);
  assert(/1\. Review the details\n2\. Confirm the timing/.test(r), 'numbered lines separate');
});
t('emoji / unicode preserved', () => {
  const e = 'Thanks 🙏\n\nСпасибо — café';
  assert.strictEqual(extractReply({ argumentText: e }), e);
});
t('canonical stored body hash is over the exact multiline body', () => {
  const h = crypto.createHash('sha256').update(BODY).digest('hex');
  // this is what createDraft stores/hashes (proven in test-store)
  assert.strictEqual(crypto.createHash('sha256').update(extractReply({ argumentText: BODY })).digest('hex'), h);
});
t('card render maps each LF to <br>, escapes, keeps blank lines', () => {
  assert.strictEqual(cardBody(BODY), 'Hey,<br><br>How are you?<br><br>Hamza');
  assert.strictEqual(cardBody('<b> & "x" \'y\''), '&lt;b&gt; &amp; &quot;x&quot; &#39;y&#39;');
});
t('dialog round-trip preserves body unchanged', () => {
  assert.strictEqual(normalizeEdit(BODY), BODY);
  assert.strictEqual(normalizeEdit(BODY.replace(/\n/g, '\r\n')), BODY);
});
t('toHtml (outgoing email html) equals card structure', () => {
  assert.strictEqual(toHtml(BODY), 'Hey,<br><br>How are you?<br><br>Hamza');
});
t('editing one line preserves all other line breaks', () => {
  const edited = BODY.replace('How are you?', 'How have you been?');
  const r = normalizeEdit(edited);
  assert.strictEqual(r, 'Hey,\n\nHow have you been?\n\nHamza');
});

for (const l of out) console.log(l);
console.log(`\n${pass}/${out.length} formatting tests passed`);
process.exit(pass === out.length ? 0 : 1);
