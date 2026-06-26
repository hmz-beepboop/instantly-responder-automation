// Business-ready offline build orchestrator.
//
// Loads config/business-ready.config.json (the single durable non-secret
// configuration source), applies additive/renaming patches to workflows
// 01-05, generates the new workflow 07 ("HMZ - Reply Human Approval -
// Validation"), and writes a build report. Does not touch n8n, MCP, Docker,
// or Instantly. All workflows remain active: false.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildWorkflow07 } from './lib/wf07-build.mjs';
import {
  patchWorkflow01,
  patchWorkflow02,
  patchWorkflow03,
  patchWorkflow04,
  patchWorkflow05
} from './lib/patches.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');

const CONFIG_PATH = path.join(ROOT, 'config', 'business-ready.config.json');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');
const REPORTS_DIR = path.join(ROOT, 'reports');

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + '\n', 'utf8');
}

function main() {
  const config = readJson(CONFIG_PATH);
  const report = {
    started_at: new Date().toISOString(),
    config_version: config.config_version,
    actions: []
  };

  const patchSpecs = [
    { file: '01_reply_intake_validation.json', name: 'HMZ - Instantly Reply Intake - Validation', patch: (wf) => patchWorkflow01(wf) },
    { file: '02_reply_decision_engine_validation.json', name: 'HMZ - Reply Decision Engine - Validation', patch: (wf) => patchWorkflow02(wf, config) },
    { file: '03_reply_sender_validation.json', name: 'HMZ - Instantly Reply Sender - Validation', patch: (wf) => patchWorkflow03(wf) },
    { file: '04_reply_error_handler_validation.json', name: 'HMZ - Reply Error Handler - Validation', patch: (wf) => patchWorkflow04(wf, config) },
    { file: '05_reply_sla_watchdog_validation.json', name: 'HMZ - Reply SLA Watchdog - Validation', patch: (wf) => patchWorkflow05(wf, config) }
  ];

  for (const spec of patchSpecs) {
    const filePath = path.join(WORKFLOWS_DIR, spec.file);
    const workflow = readJson(filePath);

    if (workflow.name !== spec.name) {
      throw new Error(`unexpected workflow name in ${spec.file}: ${workflow.name}`);
    }
    if (workflow.active !== false) {
      throw new Error(`refusing to patch active workflow: ${spec.file}`);
    }

    spec.patch(workflow);

    if (workflow.active !== false) {
      throw new Error(`patch unexpectedly activated workflow: ${spec.file}`);
    }

    writeJson(filePath, workflow);
    report.actions.push({ file: spec.file, status: 'PATCHED' });
  }

  const workflow07 = buildWorkflow07(config);
  if (workflow07.active !== false) {
    throw new Error('workflow 07 must be built with active: false');
  }
  const wf07Path = path.join(WORKFLOWS_DIR, '07_reply_human_approval_validation.json');
  writeJson(wf07Path, workflow07);
  report.actions.push({ file: '07_reply_human_approval_validation.json', status: 'CREATED' });

  report.finished_at = new Date().toISOString();

  fs.mkdirSync(REPORTS_DIR, { recursive: true });
  writeJson(path.join(REPORTS_DIR, 'BUSINESS_READY_BUILD_LOG.json'), report);

  for (const action of report.actions) {
    console.log(`${action.status}: workflows/${action.file}`);
  }
}

main();
