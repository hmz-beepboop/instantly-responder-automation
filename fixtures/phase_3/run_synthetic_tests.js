// Phase 3 local synthetic test runner.
//
// Loads the jsCode bodies straight out of workflows/01_reply_intake_validation.json
// and workflows/02_reply_decision_engine_validation.json and executes them in the
// same order n8n would, including the Phase 3.1A branching repairs:
//
//   A -> B -> B1 (IF: config_gate.passed)
//          -> true  -> C -> D -> E1 -> [E2 sim] -> E3 -> E4 (IF: idempotency.is_duplicate)
//                                                          -> true (not duplicate) -> F -> Workflow 2 (A-E)
//                                                          -> false (duplicate)    -> E5 (terminal)
//          -> false -> B2 (terminal)
//
// B1 and E4 are native IF nodes with no jsCode; their conditions are reproduced
// directly (configGatePassed / eventIsNotDuplicate below) from the exact
// leftValue/operator pairs in workflows/01_reply_intake_validation.json.
//
// Each fixtures/phase_3/*.json fixture's "input" is used as the webhook body.
//
// This makes NO calls to n8n, Instantly, or any AI provider, and does not require
// the workflows to be active. The n8n Data Table used by Workflow 1 Section E2 is
// simulated in-memory (see makeDataTable below) - this is the one PROVISIONAL
// piece, documented in reports/UNRESOLVED_ITEMS.md (U1).
//
// A fixture may declare an optional top-level "inject" object to mutate the item
// after Workflow 2 Section B runs and before Section C - used by fixture 15 to
// push an invalid (non-tri-state) value into classifier.validation_learning and
// confirm Section E's validation catches it:
//   "inject": { "path": "classifier.validation_learning.pricing_interest", "value": "MAYBE" }
//
// Run with: node run_synthetic_tests.js

const fs = require('fs');
const path = require('path');

const WORKFLOWS_DIR = path.join(__dirname, '..', '..', 'workflows');
const FIXTURES_DIR = __dirname;

function loadCode(workflowFile, nodeName) {
  const wf = JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, workflowFile), 'utf8'));
  const node = wf.nodes.find(n => n.name === nodeName);
  if (!node) throw new Error(`Node "${nodeName}" not found in ${workflowFile}`);
  return new Function('$input', '$', node.parameters.jsCode);
}

// Workflow 1 sections
const w1_A = loadCode('01_reply_intake_validation.json', 'A. Webhook Intake Normalization');
const w1_B = loadCode('01_reply_intake_validation.json', 'B. Configuration Gate');
const w1_B2 = loadCode('01_reply_intake_validation.json', 'B2. Configuration Gate Rejection (Terminal)');
const w1_C = loadCode('01_reply_intake_validation.json', 'C. Payload Validation');
const w1_D = loadCode('01_reply_intake_validation.json', 'D. Normalization to NES');
const w1_E1 = loadCode('01_reply_intake_validation.json', 'E1. Compute Idempotency Key');
const w1_E3 = loadCode('01_reply_intake_validation.json', 'E3. Recombine Idempotency Result');
const w1_E5 = loadCode('01_reply_intake_validation.json', 'E5. Duplicate Event Terminal');
const w1_F = loadCode('01_reply_intake_validation.json', 'F. Deterministic Prefilter');

// Workflow 2 sections
const w2_A = loadCode('02_reply_decision_engine_validation.json', 'A. Deterministic Policy Stage');
const w2_B = loadCode('02_reply_decision_engine_validation.json', 'B. Mock Semantic Classifier');
const w2_C = loadCode('02_reply_decision_engine_validation.json', 'C. Decision Policy');
const w2_D = loadCode('02_reply_decision_engine_validation.json', 'D. Mock Draft Preparation');
const w2_E = loadCode('02_reply_decision_engine_validation.json', 'E. Output Validation');

const VALIDATION_LEARNING_TRISTATE_FIELDS = [
  'pain_confirmed', 'current_outbound_spend_confirmed', 'capacity_problem_confirmed',
  'proof_objection', 'pricing_interest', 'alpha_interest', 'decision_maker_confirmed',
  'discovery_call_booked', 'discovery_call_showed'
];

function makeInput(items) {
  return { all: () => items };
}

// B1. Configuration Gate Router: leftValue=$json.config_gate.passed, operator boolean "true".
// True output (continue to C) when config_gate.passed === true; false output (B2) otherwise.
function configGatePassed(item) {
  return !!(item.json.config_gate && item.json.config_gate.passed === true);
}

// E4. Duplicate Event Router: leftValue=$json.idempotency.is_duplicate, operator boolean "false".
// True output (continue to F) when idempotency.is_duplicate === false; false output (E5) otherwise.
function eventIsNotDuplicate(item) {
  return !!(item.json.idempotency && item.json.idempotency.is_duplicate === false);
}

function setPath(obj, dotPath, value) {
  const parts = dotPath.split('.');
  let cur = obj;
  for (let i = 0; i < parts.length - 1; i++) cur = cur[parts[i]];
  cur[parts[parts.length - 1]] = value;
}

// In-memory stand-in for the n8n Data Table (E2). Simulates "upsert" returning
// row-level createdAt/updatedAt that differ on the second write to the same key -
// this is the PROVISIONAL assumption documented in reports/UNRESOLVED_ITEMS.md.
function makeDataTable() {
  const rows = new Map();
  let nextId = 1;
  let clock = Date.UTC(2026, 5, 11, 0, 0, 0);
  const tick = () => { clock += 1000; return new Date(clock).toISOString(); };

  return function simulateE2(e1Items) {
    return e1Items.map(item => {
      const key = item.json.idempotency.idempotency_key;
      const now = tick();
      let row = rows.get(key);
      if (row) {
        row = { ...row, updatedAt: now };
      } else {
        row = { id: nextId++, idempotency_key: key, createdAt: now, updatedAt: now };
      }
      rows.set(key, row);
      return { json: { ...row } };
    });
  };
}

function runOnce(rawPayload, simulateE2, inject) {
  let items;

  items = w1_A(makeInput([{ json: { body: rawPayload } }]));
  items = w1_B(makeInput(items));

  if (!configGatePassed(items[0])) {
    items = w1_B2(makeInput(items));
    return { result: items[0].json, terminal: 'B2' };
  }

  items = w1_C(makeInput(items));
  items = w1_D(makeInput(items));

  const e1Items = w1_E1(makeInput(items));
  const e2Items = simulateE2(e1Items);

  const dollar = (name) => {
    if (name === 'E1. Compute Idempotency Key') return { all: () => e1Items };
    throw new Error(`Unsupported $() reference: ${name}`);
  };
  items = w1_E3(makeInput(e2Items), dollar);

  if (!eventIsNotDuplicate(items[0])) {
    items = w1_E5(makeInput(items));
    return { result: items[0].json, terminal: 'E5' };
  }

  items = w1_F(makeInput(items));

  items = w2_A(makeInput(items));
  items = w2_B(makeInput(items));

  if (inject) {
    setPath(items[0].json, inject.path, inject.value);
  }

  items = w2_C(makeInput(items));
  items = w2_D(makeInput(items));
  items = w2_E(makeInput(items));

  return { result: items[0].json, terminal: 'COMPLETE' };
}

// ---- Comparison helpers -----------------------------------------------------

function isPlainObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function arraysEqualAsSets(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  const sa = [...a].map(x => JSON.stringify(x)).sort();
  const sb = [...b].map(x => JSON.stringify(x)).sort();
  return JSON.stringify(sa) === JSON.stringify(sb);
}

function checkPartial(actual, expected, label, errors) {
  if (!isPlainObject(expected)) return;
  for (const key of Object.keys(expected)) {
    const expVal = expected[key];

    if (key === 'reason_contains') {
      const actReason = actual && actual.reason;
      if (typeof actReason !== 'string' || !actReason.includes(expVal)) {
        errors.push(`${label}.reason does not contain "${expVal}" (was: ${JSON.stringify(actReason)})`);
      }
      continue;
    }
    if (key === 'notes_mention') {
      const actNotes = actual && actual.notes;
      if (typeof actNotes !== 'string' || !actNotes.includes(expVal)) {
        errors.push(`${label}.notes does not contain "${expVal}" (was: ${JSON.stringify(actNotes)})`);
      }
      continue;
    }
    if (key === 'draft_text_is_null') {
      const isNull = actual && actual.draft_text === null;
      if (isNull !== expVal) {
        errors.push(`${label}.draft_text is${isNull ? '' : ' not'} null, expected is_null=${expVal}`);
      }
      continue;
    }
    if (key === 'booking_link_line_present') {
      const text = (actual && actual.draft_text) || '';
      const present = text.includes('You can choose a suitable time here');
      if (present !== expVal) {
        errors.push(`${label}.draft_text booking link line present=${present}, expected ${expVal}`);
      }
      continue;
    }
    if (key === 'all_other_fields' && expVal === 'unknown_or_null_default') {
      for (const f of VALIDATION_LEARNING_TRISTATE_FIELDS) {
        if (Object.prototype.hasOwnProperty.call(expected, f)) continue;
        const actVal = actual ? actual[f] : undefined;
        if (actVal !== 'unknown') {
          errors.push(`${label}.${f} expected 'unknown' (default), got ${JSON.stringify(actVal)}`);
        }
      }
      continue;
    }

    const actVal = actual ? actual[key] : undefined;

    if (isPlainObject(expVal) && Object.keys(expVal).length === 1 && 'starts_with' in expVal) {
      if (typeof actVal !== 'string' || !actVal.startsWith(expVal.starts_with)) {
        errors.push(`${label}.${key} expected to start with "${expVal.starts_with}", got ${JSON.stringify(actVal)}`);
      }
      continue;
    }

    if (isPlainObject(expVal)) {
      checkPartial(actVal, expVal, `${label}.${key}`, errors);
    } else if (Array.isArray(expVal)) {
      if (!arraysEqualAsSets(actVal, expVal)) {
        errors.push(`${label}.${key} expected ${JSON.stringify(expVal)}, got ${JSON.stringify(actVal)}`);
      }
    } else {
      if (actVal !== expVal) {
        errors.push(`${label}.${key} expected ${JSON.stringify(expVal)}, got ${JSON.stringify(actVal)}`);
      }
    }
  }
}

// ---- Fixture runner -----------------------------------------------------

function runFixture(fixturePath, dataTable) {
  const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  const errors = [];

  if (fixture.fixture_id === 'phase3_10_duplicate_event') {
    const run1 = runOnce(fixture.input, dataTable, fixture.inject);
    checkResultAgainstExpected(run1.result, fixture.expected.first_submission, 'first_submission', errors);
    const run2 = runOnce(fixture.input, dataTable, fixture.inject);
    checkResultAgainstExpected(run2.result, fixture.expected.second_submission, 'second_submission', errors);
    return { fixture, errors, results: [run1.result, run2.result] };
  }

  const run = runOnce(fixture.input, dataTable, fixture.inject);
  checkResultAgainstExpected(run.result, fixture.expected, 'expected', errors);
  return { fixture, errors, results: [run.result] };
}

function checkResultAgainstExpected(result, expected, label, errors) {
  if (!expected) return;

  if (expected.must_be_absent) {
    for (const name of expected.must_be_absent) {
      if (result[name] !== undefined) {
        errors.push(`${label}: "${name}" should be absent (terminal short-circuit) but was present`);
      }
    }
  }

  if (expected.validation_errors) {
    const expArr = expected.validation_errors;
    const actArr = result.validation_errors || [];
    if (actArr.length !== expArr.length) {
      errors.push(`${label}.validation_errors length expected ${expArr.length}, got ${actArr.length}`);
    } else {
      expArr.forEach((expEntry, i) => {
        checkPartial(actArr[i], expEntry, `${label}.validation_errors[${i}]`, errors);
      });
    }
  }

  // result.validation_learning is the single top-level field exposed by Workflow 2
  // Section E (Repair 3) - it equals classifier.validation_learning, the enriched,
  // per-execution result. nes.validation_learning_seed is the static Workflow 1 seed.
  const known = { ...result };

  const rest = { ...expected };
  delete rest.notes;
  delete rest.how_to_test;
  delete rest.must_be_absent;
  delete rest.validation_errors;

  checkPartial(known, rest, label, errors);
}

// ---- Main -----------------------------------------------------

const fixtureFiles = fs.readdirSync(FIXTURES_DIR)
  .filter(f => f.endsWith('.json'))
  .sort();

let totalPass = 0;
let totalFail = 0;
let totalChecks = 0;
const dataTable = makeDataTable();
const resultsById = {};

for (const file of fixtureFiles) {
  totalChecks++;
  const { fixture, errors, results } = runFixture(path.join(FIXTURES_DIR, file), dataTable);
  resultsById[fixture.fixture_id] = results;
  if (errors.length === 0) {
    totalPass++;
    console.log(`PASS  ${file}  (${fixture.fixture_id})`);
  } else {
    totalFail++;
    console.log(`FAIL  ${file}  (${fixture.fixture_id})`);
    for (const e of errors) console.log(`      - ${e}`);
  }
}

// Cross-check: two content-different malformed payloads (fixtures 11 and 13) must
// hash to different identifier_poor_hash idempotency keys and each route to
// op-malformed/REJECTED independently - resolves reports/UNRESOLVED_ITEMS.md U3.
{
  const r11 = resultsById['phase3_11_malformed_payload'];
  const r13 = resultsById['phase3_13_distinct_malformed_payload'];
  totalChecks++;
  if (!r11 || !r13) {
    totalFail++;
    console.log('FAIL  cross-check fixtures 11 vs 13 (idempotency_key)');
    console.log('      - one or both fixtures did not run');
  } else {
    const key11 = r11[0].idempotency && r11[0].idempotency.idempotency_key;
    const key13 = r13[0].idempotency && r13[0].idempotency.idempotency_key;
    if (typeof key11 !== 'string' || typeof key13 !== 'string' || key11 === key13) {
      totalFail++;
      console.log('FAIL  cross-check fixtures 11 vs 13 (idempotency_key)');
      console.log(`      - expected two distinct string idempotency_key values, got 11="${key11}", 13="${key13}"`);
    } else {
      totalPass++;
      console.log(`PASS  cross-check fixtures 11 vs 13 (idempotency_key 11="${key11}" != 13="${key13}")`);
    }
  }
}

console.log('');
console.log(`${totalPass} passed, ${totalFail} failed, ${totalChecks} total`);
process.exit(totalFail > 0 ? 1 : 0);
