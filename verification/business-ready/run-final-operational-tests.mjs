// Business-ready FINAL CONTROLLED-LIVE ORCHESTRATION FIX - offline test suite.
//
// Pure Node.js (built-ins only). Statically validates, and where practical
// executes via pwsh, the six corrections (1-6) made by this session to
// run-controlled-live-acceptance.ps1, apply-business-ready.ps1,
// rollback-business-ready.ps1, infrastructure/business-live/docker-compose.yml,
// infrastructure/business-live/.env.example, and BUSINESS_READY_OWNER_INPUTS.md.
// Re-runs the existing run-release-blocker-tests.mjs suite (34/34). Makes no
// network call and never starts n8n. DRY_RUN remains true and LIVE_CAMPAIGNS
// remains [] throughout.
//
// Usage: node verification/business-ready/run-final-operational-tests.mjs

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOWS_DIR = path.join(ROOT, 'workflows');

const WORKFLOW_FILES = [
  '01_reply_intake_validation.json',
  '02_reply_decision_engine_validation.json',
  '03_reply_sender_validation.json',
  '04_reply_error_handler_validation.json',
  '05_reply_sla_watchdog_validation.json',
  '06_reply_full_test_harness_validation.json',
  '07_reply_human_approval_validation.json',
];

const results = [];
function record(id, description, passed, details) {
  results.push({ id, description, passed: !!passed, details: details || undefined });
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function tryRecord(id, description, fn) {
  try {
    fn();
    record(id, description, true);
  } catch (err) {
    record(id, description, false, err.message);
  }
}

const config = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'business-ready.config.json'), 'utf8'));
const controlledLiveSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'run-controlled-live-acceptance.ps1'), 'utf8');
const applyScriptSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'apply-business-ready.ps1'), 'utf8');
const rollbackScriptSrc = fs.readFileSync(path.join(ROOT, 'verification', 'business-ready', 'rollback-business-ready.ps1'), 'utf8');
const dockerComposeSrc = fs.readFileSync(path.join(ROOT, 'infrastructure', 'business-live', 'docker-compose.yml'), 'utf8');
const envExampleSrc = fs.readFileSync(path.join(ROOT, 'infrastructure', 'business-live', '.env.example'), 'utf8');
const ownerInputsSrc = fs.readFileSync(path.join(ROOT, 'BUSINESS_READY_OWNER_INPUTS.md'), 'utf8');

const controlledLiveLines = controlledLiveSrc.split('\n');

// =======================================================================
// 1. Stored config remains in its safe baseline.
// =======================================================================
tryRecord('stored_config_remains_safe', 'config/business-ready.config.json remains operating_mode=VALIDATION, dry_run=true, live_campaigns=[], and all live_credential_readiness flags false', () => {
  assert(config.operating_mode === 'VALIDATION', `operating_mode must be VALIDATION, got ${config.operating_mode}`);
  assert(config.dry_run === true, 'dry_run must be true');
  assert(Array.isArray(config.live_campaigns) && config.live_campaigns.length === 0, 'live_campaigns must be []');
  assert(config.live_credential_readiness.instantly === false, 'live_credential_readiness.instantly must be false');
  assert(config.live_credential_readiness.review_basic_auth === false, 'live_credential_readiness.review_basic_auth must be false');
  assert(config.live_credential_readiness.ready_for_controlled_live_test === false, 'live_credential_readiness.ready_for_controlled_live_test must be false');
});

// =======================================================================
// 2. New-ControlledLiveConfig builds the correct temporary SUPERVISED_VALIDATION
//    / dry_run=false / one-campaign config in-memory.
// =======================================================================
tryRecord('temp_config_construction_supervised_validation', 'New-ControlledLiveConfig sets operating_mode=SUPERVISED_VALIDATION, dry_run=false, live_campaigns=[the designated campaign], allowlists.campaign_ids=[same], launch_profile.required_operating_mode=SUPERVISED_VALIDATION, and the three live_credential_readiness flags to true, leaving other fields untouched', () => {
  // Dot-source only the function definitions (everything before "# Main"),
  // never executing Invoke-Preflight or the main flow.
  const mainMarkerIdx = controlledLiveLines.findIndex((l) => l.trim() === '# Main');
  assert(mainMarkerIdx > 0, 'could not find "# Main" marker');
  const helperSrc = controlledLiveLines.slice(0, mainMarkerIdx - 2).join('\n');

  const helperPath = path.join(ROOT, 'tmp', '_final_operational_controlled_live_funcs.ps1');
  fs.mkdirSync(path.dirname(helperPath), { recursive: true });
  fs.writeFileSync(helperPath, helperSrc, 'utf8');

  const sampleConfig = {
    operating_mode: 'VALIDATION',
    dry_run: true,
    live_campaigns: [],
    workspace_allowlist: ['ws-allowed'],
    allowlists: { workspace_id: 'ws-allowed', campaign_ids: ['<REQUIRED_CONTROLLED_LIVE_CAMPAIGN_ID>'], connected_sender_eaccounts: ['sender@example.com'] },
    launch_profile: { name: 'SUPERVISED_VALIDATION', required_operating_mode: 'VALIDATION', unattended_auto_send: false, proven_mode: false },
    live_credential_readiness: { instantly: false, review_basic_auth: false, ready_for_controlled_live_test: false },
    reviewer_allowlist: ['reviewer@example.com'],
  };
  const sampleConfigPath = path.join(ROOT, 'tmp', '_final_operational_sample_config.json');
  fs.writeFileSync(sampleConfigPath, JSON.stringify(sampleConfig), 'utf8');

  try {
    const proc = spawnSync('pwsh', ['-NoProfile', '-Command',
      `$env:HMZ_CONTROLLED_LIVE_CAMPAIGN_ID = 'camp-test-123'; ` +
      `. '${helperPath}'; ` +
      `$cfg = Get-Content -Raw '${sampleConfigPath.replace(/\\/g, '\\\\')}' | ConvertFrom-Json -Depth 100; ` +
      `$temp = New-ControlledLiveConfig -Config $cfg; ` +
      `$temp | ConvertTo-Json -Depth 100`
    ], { cwd: ROOT, encoding: 'utf8' });
    assert(proc.status === 0, `pwsh exited ${proc.status}: ${proc.stderr}`);

    const temp = JSON.parse(proc.stdout);
    assert(temp.operating_mode === 'SUPERVISED_VALIDATION', `operating_mode mismatch: ${temp.operating_mode}`);
    assert(temp.dry_run === false, `dry_run mismatch: ${temp.dry_run}`);
    assert(JSON.stringify(temp.live_campaigns) === JSON.stringify(['camp-test-123']), `live_campaigns mismatch: ${JSON.stringify(temp.live_campaigns)}`);
    assert(JSON.stringify(temp.allowlists.campaign_ids) === JSON.stringify(['camp-test-123']), `allowlists.campaign_ids mismatch: ${JSON.stringify(temp.allowlists.campaign_ids)}`);
    assert(temp.launch_profile.required_operating_mode === 'SUPERVISED_VALIDATION', `launch_profile.required_operating_mode mismatch: ${temp.launch_profile.required_operating_mode}`);
    assert(temp.live_credential_readiness.instantly === true, 'live_credential_readiness.instantly must be true');
    assert(temp.live_credential_readiness.review_basic_auth === true, 'live_credential_readiness.review_basic_auth must be true');
    assert(temp.live_credential_readiness.ready_for_controlled_live_test === true, 'live_credential_readiness.ready_for_controlled_live_test must be true');
    // Untouched fields.
    assert(temp.allowlists.workspace_id === 'ws-allowed', 'allowlists.workspace_id must be untouched');
    assert(JSON.stringify(temp.allowlists.connected_sender_eaccounts) === JSON.stringify(['sender@example.com']), 'allowlists.connected_sender_eaccounts must be untouched');
    assert(JSON.stringify(temp.reviewer_allowlist) === JSON.stringify(['reviewer@example.com']), 'reviewer_allowlist must be untouched');
  } finally {
    fs.rmSync(helperPath, { force: true });
    fs.rmSync(sampleConfigPath, { force: true });
  }
});

// =======================================================================
// 3. No synthetic dev-webhook POST in the controlled-live-reply path.
// =======================================================================
tryRecord('no_synthetic_dev_webhook_post', 'run-controlled-live-acceptance.ps1 does not POST a synthetic NES to the Intake dev webhook; the real reply is sent by the operator, and the script documents this explicitly', () => {
  assert(!/Invoke-RestMethod[^\n]*intake-dev/.test(controlledLiveSrc), 'must not POST to the Intake dev webhook');
  assert(!/Invoke-WebRequest[^\n]*intake-dev/.test(controlledLiveSrc), 'must not POST to the Intake dev webhook via Invoke-WebRequest');
  assert(/does NOT post a synthetic NES/.test(controlledLiveSrc), 'must document that no synthetic NES is posted');
  assert(/inbound reply is a real message the operator sends/.test(controlledLiveSrc), 'must document that the inbound reply is a real operator-sent message');
});

// =======================================================================
// 4. No POST /api/v2/emails/reply from PowerShell, anywhere.
// =======================================================================
tryRecord('no_post_to_instantly_reply_endpoint', 'run-controlled-live-acceptance.ps1 never references the Instantly reply-send endpoint path (api/v2/emails/reply) and never issues a second send on SEND_UNCERTAIN', () => {
  assert(!/api\/v2\/emails\/reply/.test(controlledLiveSrc), 'must never reference api/v2/emails/reply');
  assert(/never POSTs to the Instantly reply-send endpoint/.test(controlledLiveSrc), 'must document never POSTing to the Instantly reply-send endpoint');
  assert(/SEND_UNCERTAIN[\s\S]*reconciliation reads only/.test(controlledLiveSrc), 'SEND_UNCERTAIN must be documented as reconciliation-only');
  assert(/never a second send/.test(controlledLiveSrc) || /never attempt a second send/i.test(controlledLiveSrc), 'must document never performing a second send');
});

// =======================================================================
// 5. Real production reply + authenticated human-approval requirement.
// =======================================================================
tryRecord('real_production_reply_human_approval_required', 'run-controlled-live-acceptance.ps1 prints the marker, designated campaign/workspace/sender/lead/subject, instructs the operator to send a real reply and approve via the production Human Approval review page, and blocks on Read-Host until the operator confirms approval', () => {
  assert(/controlledLiveMarker = "HMZ-CTRL-"/.test(controlledLiveSrc), 'must generate a unique controlledLiveMarker');
  assert(/Designated campaign ID/.test(controlledLiveSrc) && /Designated workspace ID/.test(controlledLiveSrc), 'must print designated campaign and workspace IDs');
  assert(/Connected sender/.test(controlledLiveSrc) && /Owned test lead email/.test(controlledLiveSrc) && /Expected reply subject/.test(controlledLiveSrc), 'must print connected sender, lead email, and expected subject');
  assert(/HMZ_REVIEW_PUBLIC_BASE_URL/.test(controlledLiveSrc), 'must reference the public review page URL');
  assert(/approve it EXACTLY ONCE/.test(controlledLiveSrc), 'must instruct the operator to approve exactly once');
  assert(/Read-Host "Press Enter once you have approved the review case/.test(controlledLiveSrc), 'must block on operator confirmation via Read-Host');
  assert(/Wait-ForControlledReplyOutcome/.test(controlledLiveSrc), 'must poll for the outcome only after operator confirmation');
});

// =======================================================================
// 6. Correct 6-workflow runtime activation set, Full Test Harness excluded.
// =======================================================================
tryRecord('runtime_activation_set_excludes_full_test_harness', 'RuntimeWorkflowNames lists exactly the 6 runtime workflows (Intake, Decision Engine, Reply Sender, Error Handler, Human Approval, SLA Watchdog), excludes the Full Test Harness, and Set-RuntimeWorkflowsActive explicitly verifies/deactivates the Full Test Harness if active', () => {
  const match = controlledLiveSrc.match(/\$RuntimeWorkflowNames = @\(([\s\S]*?)\n\)/);
  assert(match, '$RuntimeWorkflowNames array not found');
  const names = match[1].split('\n').map((l) => l.trim()).filter(Boolean).map((l) => l.replace(/^"|"$/g, '').replace(/,$/, '').replace(/^"|"$/g, ''));
  const expected = [
    'HMZ - Instantly Reply Intake - Validation',
    'HMZ - Reply Decision Engine - Validation',
    'HMZ - Instantly Reply Sender - Validation',
    'HMZ - Reply Error Handler - Validation',
    'HMZ - Reply Human Approval - Validation',
    'HMZ - Reply SLA Watchdog - Validation',
  ];
  const cleaned = names.map((n) => n.replace(/^"/, '').replace(/"$/, ''));
  assert(JSON.stringify(cleaned) === JSON.stringify(expected), `RuntimeWorkflowNames mismatch: ${JSON.stringify(cleaned)}`);
  assert(!cleaned.includes('HMZ - Reply Full Test Harness - Validation'), 'Full Test Harness must not be in RuntimeWorkflowNames');

  assert(/\$FullTestHarnessName = "HMZ - Reply Full Test Harness - Validation"/.test(controlledLiveSrc), '$FullTestHarnessName must be declared');
  assert(/The Full Test Harness must never be activated by this script/.test(controlledLiveSrc), 'must document that the Full Test Harness is never activated');
  assert(/if \(\[bool\]\$HarnessSummary\.active\) \{/.test(controlledLiveSrc), 'must check whether the Full Test Harness is active and deactivate it if so');
});

// =======================================================================
// 7. Restoration in `finally`.
// =======================================================================
tryRecord('finally_restoration_present', 'The -AllowOneControlledReply main flow wraps its work in try/catch/finally; the finally block calls Restore-SafeState, which deactivates the runtime workflows, restores or re-asserts safe config defaults, reruns apply-business-ready.ps1, verifies the restored state, and clears every secret/controlled-live environment variable', () => {
  assert(/finally \{[\s\S]*Restore-SafeState -BackupDir \$BackupDir -RuntimeWorkflowsWereActivated \$RuntimeWorkflowsWereActivated/.test(controlledLiveSrc), 'main finally block must call Restore-SafeState');
  assert(/function Restore-SafeState/.test(controlledLiveSrc), 'Restore-SafeState must be defined');
  assert(/Set-RuntimeWorkflowsActive -Headers \$N8nHeaders -Active \$false/.test(controlledLiveSrc), 'Restore-SafeState must deactivate the runtime workflows');
  assert(/Invoke-ApplyBusinessReady -AdditionalEnv @\{\}/.test(controlledLiveSrc), 'Restore-SafeState must rerun apply-business-ready.ps1 against the restored config');
  assert(/configRestoredSafe = \$FinalConfigSafe/.test(controlledLiveSrc), 'Restore-SafeState must verify configRestoredSafe');
  assert(/allWorkflowsInactiveAfter = \$FinalAllInactive/.test(controlledLiveSrc), 'Restore-SafeState must verify allWorkflowsInactiveAfter');

  const clearedVarsMatch = controlledLiveSrc.match(/# Clear every secret \/ controlled-live environment[\s\S]*?foreach \(\$VarName in @\(([\s\S]*?)\)\) \{\s*Remove-Item "Env:\\\$VarName"/);
  assert(clearedVarsMatch, 'Restore-SafeState must clear secret/controlled-live env vars');
  const clearedVars = clearedVarsMatch[1].match(/"HMZ_[A-Z0-9_]+"/g) || [];
  for (const required of ['"HMZ_N8N_API_KEY"', '"HMZ_INSTANTLY_API_KEY"', '"HMZ_INSTANTLY_API_CREDENTIAL_ID"', '"HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID"', '"HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID"', '"HMZ_CONTROLLED_LIVE_CAMPAIGN_ID"']) {
    assert(clearedVars.includes(required), `Restore-SafeState must clear ${required}, found: ${JSON.stringify(clearedVars)}`);
  }
});

// =======================================================================
// 8. Blank/missing workspace_id blocks preflight (fail-closed, 3-part check).
// =======================================================================
tryRecord('blank_workspace_id_blocks_preflight', 'Invoke-Preflight requires the designated campaign workspace_id to be non-empty, present in config.workspace_allowlist, AND exactly equal to config.allowlists.workspace_id; a blank workspace_id alone blocks regardless of the other two', () => {
  // Extract the exact fail-closed block verbatim from the source (lines
  // between the "Fail-closed workspace check" comment and the third throw).
  const startIdx = controlledLiveLines.findIndex((l) => l.includes('# Fail-closed workspace check'));
  assert(startIdx > 0, 'could not find the "Fail-closed workspace check" comment');
  const endIdx = controlledLiveLines.findIndex((l, i) => i > startIdx && l.includes('does not exactly match config.allowlists.workspace_id'));
  assert(endIdx > startIdx, 'could not find the third throw of the fail-closed workspace check');
  // Include the closing "}" of the third `if`.
  const endIdxClose = endIdx + 2;
  const snippet = controlledLiveLines.slice(startIdx, endIdxClose + 1).join('\n');
  assert(/designatedCampaignWorkspaceNonEmpty/.test(snippet), 'snippet must compute designatedCampaignWorkspaceNonEmpty');
  assert(/designatedCampaignInWorkspaceAllowlist/.test(snippet), 'snippet must compute designatedCampaignInWorkspaceAllowlist');
  assert(/designatedCampaignWorkspaceMatchesConfigured/.test(snippet), 'snippet must compute designatedCampaignWorkspaceMatchesConfigured');

  const helperPath = path.join(ROOT, 'tmp', '_final_operational_workspace_check.ps1');
  fs.mkdirSync(path.dirname(helperPath), { recursive: true });

  function runCase(matchWorkspaceId, workspaceAllowlist, configuredWorkspaceId) {
    const script = `
$Results = [ordered]@{}
$Config = [pscustomobject]@{ workspace_allowlist = @(${workspaceAllowlist.map((w) => `'${w}'`).join(',')}); allowlists = [pscustomobject]@{ workspace_id = '${configuredWorkspaceId}' } }
$Match = @([pscustomobject]@{ workspace_id = '${matchWorkspaceId}' })
function Get-OptionalPropertyValue {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $null }
    return $Property.Value
}
try {
${snippet}
    Write-Output "RESULT:NOTHROW:$($Results.designatedCampaignWorkspaceNonEmpty):$($Results.designatedCampaignInWorkspaceAllowlist):$($Results.designatedCampaignWorkspaceMatchesConfigured)"
} catch {
    Write-Output "RESULT:THROW:$($_.Exception.Message)"
}
`;
    fs.writeFileSync(helperPath, script, 'utf8');
    const proc = spawnSync('pwsh', ['-NoProfile', '-File', helperPath], { cwd: ROOT, encoding: 'utf8' });
    assert(proc.status === 0, `pwsh exited ${proc.status}: ${proc.stderr}`);
    return proc.stdout.trim().split('\n').find((l) => l.startsWith('RESULT:'));
  }

  try {
    // Case A: blank workspace_id -> must throw, blocked regardless of allowlist/configured.
    const a = runCase('', ['ws-allowed'], 'ws-allowed');
    assert(a.startsWith('RESULT:THROW:'), `blank workspace_id must throw, got: ${a}`);
    assert(/blank\/missing workspace_id/.test(a), `blank workspace_id throw message mismatch: ${a}`);

    // Case B: non-empty but not in workspace_allowlist -> must throw.
    const b = runCase('ws-other', ['ws-allowed'], 'ws-allowed');
    assert(b.startsWith('RESULT:THROW:'), `non-allowlisted workspace_id must throw, got: ${b}`);
    assert(/not present in config\.workspace_allowlist/.test(b), `non-allowlisted workspace_id throw message mismatch: ${b}`);

    // Case C: in allowlist but does not match configured workspace_id -> must throw.
    const c = runCase('ws-other', ['ws-allowed', 'ws-other'], 'ws-allowed');
    assert(c.startsWith('RESULT:THROW:'), `mismatched configured workspace_id must throw, got: ${c}`);
    assert(/does not exactly match config\.allowlists\.workspace_id/.test(c), `mismatched configured workspace_id throw message mismatch: ${c}`);

    // Case D: non-empty, in allowlist, matches configured -> no throw, all three true.
    const d = runCase('ws-allowed', ['ws-allowed'], 'ws-allowed');
    assert(d === 'RESULT:NOTHROW:True:True:True', `fully-matching workspace must pass with all three true, got: ${d}`);
  } finally {
    fs.rmSync(helperPath, { force: true });
  }
});

// =======================================================================
// 9. hmzReviewBasicAuth -> httpBasicAuth.
// =======================================================================
tryRecord('review_basic_auth_credential_type_http_basic_auth', 'apply-business-ready.ps1 resolves hmzReviewBasicAuth as httpBasicAuth, separately from the Instantly credential map, and throws if a remote node carries hmzReviewBasicAuth bound to anything other than httpBasicAuth', () => {
  assert(/\$ReviewCredentialNames = @\("hmzReviewBasicAuth"\)/.test(applyScriptSrc), '$ReviewCredentialNames must be exactly @("hmzReviewBasicAuth")');
  assert(/"hmzReviewBasicAuth"\s*=\s*"httpBasicAuth"/.test(applyScriptSrc), '$CredentialTypeByPlaceholder["hmzReviewBasicAuth"] must be "httpBasicAuth"');
  assert(/if \(\$ReviewCredentialNames -contains \$CredName\)/.test(applyScriptSrc), 'must branch on $ReviewCredentialNames -contains $CredName');
  assert(/must be bound as httpBasicAuth, found/.test(applyScriptSrc), 'must throw if hmzReviewBasicAuth is bound as something other than httpBasicAuth');
  assert(/it must never be resolved via the Instantly credential map/.test(config.live_credential_readiness.note), 'config note must state hmzReviewBasicAuth is never resolved via the Instantly credential map');
});

// =======================================================================
// 10. Instantly credentials -> httpHeaderAuth.
// =======================================================================
tryRecord('instantly_credentials_http_header_auth', 'apply-business-ready.ps1 resolves hmzInstantlyApi and hmzInstantlyWebhookToken as httpHeaderAuth and throws if a remote node carries either bound to anything else', () => {
  assert(/\$InstantlyCredentialNames = @\("hmzInstantlyApi", "hmzInstantlyWebhookToken"\)/.test(applyScriptSrc), '$InstantlyCredentialNames must be exactly @("hmzInstantlyApi", "hmzInstantlyWebhookToken")');
  assert(/"hmzInstantlyApi"\s*=\s*"httpHeaderAuth"/.test(applyScriptSrc), '$CredentialTypeByPlaceholder["hmzInstantlyApi"] must be "httpHeaderAuth"');
  assert(/"hmzInstantlyWebhookToken"\s*=\s*"httpHeaderAuth"/.test(applyScriptSrc), '$CredentialTypeByPlaceholder["hmzInstantlyWebhookToken"] must be "httpHeaderAuth"');
  assert(/if \(\$InstantlyCredentialNames -contains \$CredName\)/.test(applyScriptSrc), 'must branch on $InstantlyCredentialNames -contains $CredName');
  assert(/must be bound as httpHeaderAuth, found/.test(applyScriptSrc), 'must throw if an Instantly credential is bound as something other than httpHeaderAuth');
  assert(/HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID/.test(applyScriptSrc), 'must require HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID');
});

// =======================================================================
// 11. Google Chat env passed to business-live n8n.
// =======================================================================
tryRecord('google_chat_env_passed_to_business_live_n8n', 'infrastructure/business-live/docker-compose.yml passes GOOGLE_CHAT_WEBHOOK_URL into the n8n container environment, and .env.example documents it as a deployment-only secret with no separate hmzGoogleChatWebhook credential required', () => {
  const n8nServiceMatch = dockerComposeSrc.match(/n8n:\n[\s\S]*?environment:\n([\s\S]*?)\n(?:\s*volumes:)/);
  assert(n8nServiceMatch, 'could not locate n8n service environment block');
  assert(/- GOOGLE_CHAT_WEBHOOK_URL=\$\{GOOGLE_CHAT_WEBHOOK_URL\}/.test(n8nServiceMatch[1]), 'n8n service environment must include GOOGLE_CHAT_WEBHOOK_URL=${GOOGLE_CHAT_WEBHOOK_URL}');

  assert(/GOOGLE_CHAT_WEBHOOK_URL=<REQUIRED_GOOGLE_CHAT_WEBHOOK_URL>/.test(envExampleSrc), '.env.example must declare GOOGLE_CHAT_WEBHOOK_URL=<REQUIRED_GOOGLE_CHAT_WEBHOOK_URL>');
  assert(/No separate `hmzGoogleChatWebhook` n8n credential is\nrequired by the current implementation\./.test(envExampleSrc) || /No separate `hmzGoogleChatWebhook` n8n credential is/.test(envExampleSrc), '.env.example must document that no separate hmzGoogleChatWebhook credential is required');
});

// =======================================================================
// 12. No secrets embedded anywhere in config/workflow JSON or owner docs.
// =======================================================================
tryRecord('no_secrets_embedded', 'No workflow JSON export carries a resolved "credentials" object, config/business-ready.config.json carries no secret values, and run-controlled-live-acceptance.ps1 references credential IDs only via $env: variables, never literals', () => {
  for (const file of WORKFLOW_FILES) {
    const wf = JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, file), 'utf8'));
    assert(wf.active === false, `${file}: active must remain false`);
    for (const node of wf.nodes) {
      assert(!('credentials' in node), `${file}: node '${node.name}' must not carry a resolved credentials object`);
    }
  }

  const configRaw = JSON.stringify(config);
  assert(!/GOOGLE_CHAT_WEBHOOK_URL\s*[:=]\s*"https/.test(configRaw), 'config must not embed a real GOOGLE_CHAT_WEBHOOK_URL value');
  assert(!/"Bearer [^<\s"]/.test(configRaw), 'config must not embed a literal Bearer token');

  for (const idVar of ['HMZ_INSTANTLY_API_CREDENTIAL_ID', 'HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID', 'HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID']) {
    // Required-but-not-resolved by this script: apply-business-ready.ps1 (a
    // child process inheriting the environment) reads these directly, so
    // this script only needs to require/clear the named env var, never a
    // literal value.
    assert(controlledLiveSrc.includes(`"${idVar}"`), `run-controlled-live-acceptance.ps1 must require/clear ${idVar}`);
  }
  assert(!/HMZ_[A-Z_]+_CREDENTIAL_ID\s*=\s*"[a-f0-9-]{8,}"/i.test(controlledLiveSrc), 'must not embed a literal credential ID');
});

// =======================================================================
// 13. Existing release-blocker suite still passes (34/34).
// =======================================================================
function runRegression(id, scriptPath, expectedTotal) {
  if (!fs.existsSync(scriptPath)) {
    record(id, `${path.relative(ROOT, scriptPath)} regression suite (${expectedTotal}/${expectedTotal})`, false, 'script not found');
    return;
  }
  const proc = spawnSync(process.execPath, [scriptPath], { cwd: ROOT, encoding: 'utf8' });
  const output = `${proc.stdout || ''}${proc.stderr || ''}`;
  const match = output.match(/(\d+)\/(\d+) passed, (\d+) failed/);
  const ok =
    proc.status === 0 &&
    !!match &&
    Number(match[2]) === expectedTotal &&
    Number(match[1]) === expectedTotal &&
    Number(match[3]) === 0;
  record(
    id,
    `${path.relative(ROOT, scriptPath)} regression suite reports ${expectedTotal}/${expectedTotal}`,
    ok,
    ok ? undefined : { exitCode: proc.status, matched: match ? match[0] : null, tail: output.slice(-2000) }
  );
}

runRegression('regression_release_blocker', path.join(ROOT, 'verification', 'business-ready', 'run-release-blocker-tests.mjs'), 34);

// =======================================================================
// 14. All retained PowerShell scripts parse.
// =======================================================================
tryRecord('powershell_scripts_parse', 'apply-business-ready.ps1, run-controlled-live-acceptance.ps1, and rollback-business-ready.ps1 are all syntactically valid PowerShell', () => {
  for (const rel of [
    'verification/business-ready/apply-business-ready.ps1',
    'verification/business-ready/run-controlled-live-acceptance.ps1',
    'verification/business-ready/rollback-business-ready.ps1',
  ]) {
    const proc = spawnSync('pwsh', ['-NoProfile', '-Command',
      `$e=$null; $t=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('${rel}', [ref]$t, [ref]$e); if ($e.Count -gt 0) { $e | ForEach-Object { Write-Output $_.Message } } else { Write-Output 'OK' }`
    ], { cwd: ROOT, encoding: 'utf8' });
    assert(proc.status === 0, `pwsh exited ${proc.status} for ${rel}: ${proc.stderr}`);
    assert(proc.stdout.includes('OK'), `${rel}: parse errors: ${proc.stdout}`);
  }
});

// =======================================================================
// 15. All 7 workflow exports remain inactive/unchanged.
// =======================================================================
tryRecord('workflow_exports_remain_inactive', 'All 7 workflow JSON exports remain active=false; this session made no workflow JSON edits', () => {
  for (const file of WORKFLOW_FILES) {
    const wf = JSON.parse(fs.readFileSync(path.join(WORKFLOWS_DIR, file), 'utf8'));
    assert(wf.active === false, `${file}: active must be false`);
  }
});

// =======================================================================
// 16. rollback-business-ready.ps1 accepts hmzReviewBasicAuth backups and
//     re-asserts safe defaults including the review_basic_auth flag.
// =======================================================================
tryRecord('rollback_handles_review_basic_auth_and_reasserts_safe_defaults', 'rollback-business-ready.ps1 allows hmzReviewBasicAuth in credential backups and re-asserts operating_mode=VALIDATION, dry_run=true, live_campaigns=[], allowlists.campaign_ids=[], and all three live_credential_readiness flags=false on rollback', () => {
  assert(/\$AllowedBackupCredentialNames = @\("hmzInstantlyApi", "hmzInstantlyWebhookToken", "hmzReviewBasicAuth"\)/.test(rollbackScriptSrc), '$AllowedBackupCredentialNames must include hmzReviewBasicAuth');
  assert(/\$AllowedBackupCredentialNames -notcontains \$CredName/.test(rollbackScriptSrc), 'credential backup check must use $AllowedBackupCredentialNames');
  assert(/\$Config\.operating_mode = "VALIDATION"/.test(rollbackScriptSrc), 'rollback must re-assert operating_mode=VALIDATION');
  assert(/\$Config\.dry_run = \$true/.test(rollbackScriptSrc), 'rollback must re-assert dry_run=true');
  assert(/live_campaigns["']? -NotePropertyValue @\(\)/.test(rollbackScriptSrc), 'rollback must re-assert live_campaigns=[]');
  assert(/\$Config\.allowlists\.campaign_ids = @\(\)/.test(rollbackScriptSrc), 'rollback must re-assert allowlists.campaign_ids=[]');
  assert(/\$Config\.live_credential_readiness\.instantly = \$false/.test(rollbackScriptSrc), 'rollback must re-assert live_credential_readiness.instantly=false');
  assert(/\$Config\.live_credential_readiness\.review_basic_auth = \$false/.test(rollbackScriptSrc), 'rollback must re-assert live_credential_readiness.review_basic_auth=false');
  assert(/\$Config\.live_credential_readiness\.ready_for_controlled_live_test = \$false/.test(rollbackScriptSrc), 'rollback must re-assert live_credential_readiness.ready_for_controlled_live_test=false');
});

// =======================================================================
// 17. BUSINESS_READY_OWNER_INPUTS.md updated with the new required fields.
// =======================================================================
tryRecord('owner_inputs_updated_with_controlled_live_fields', 'BUSINESS_READY_OWNER_INPUTS.md records the new review Basic Auth / webhook-token credential rows, the public production URLs, the exact controlled-live campaign/workspace/sender/recipient fields, and the owner acknowledgement for the temporary live-mode rewrite/restore cycle - with no secret values added', () => {
  assert(/hmzReviewBasicAuth.*httpBasicAuth.*HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID/.test(ownerInputsSrc.replace(/\n/g, ' ')), 'must record hmzReviewBasicAuth / httpBasicAuth / HMZ_REVIEW_BASIC_AUTH_CREDENTIAL_ID');
  assert(/hmzInstantlyWebhookToken.*httpHeaderAuth.*HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID/.test(ownerInputsSrc.replace(/\n/g, ' ')), 'must record hmzInstantlyWebhookToken / httpHeaderAuth / HMZ_INSTANTLY_WEBHOOK_TOKEN_CREDENTIAL_ID');
  assert(/REQUIRED_N8N_PUBLIC_URL/.test(ownerInputsSrc) && /HMZ_N8N_PUBLIC_URL/.test(ownerInputsSrc), 'must record the public n8n URL (HMZ_N8N_PUBLIC_URL)');
  assert(/REQUIRED_REVIEW_PUBLIC_FORM_URL/.test(ownerInputsSrc) && /HMZ_REVIEW_PUBLIC_BASE_URL/.test(ownerInputsSrc), 'must record the public review form URL (HMZ_REVIEW_PUBLIC_BASE_URL)');
  assert(/REQUIRED_PRODUCTION_INSTANTLY_WEBHOOK_URL/.test(ownerInputsSrc) && /HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL/.test(ownerInputsSrc), 'must record the production Instantly webhook URL (HMZ_PRODUCTION_INSTANTLY_WEBHOOK_URL)');
  for (const field of ['REQUIRED_CONTROLLED_LIVE_CAMPAIGN_ID', 'REQUIRED_CONTROLLED_LIVE_EACCOUNT', 'REQUIRED_CONTROLLED_LIVE_LEAD_EMAIL', 'REQUIRED_CONTROLLED_LIVE_EMAIL_ID', 'REQUIRED_CONTROLLED_LIVE_REPLY_SUBJECT']) {
    assert(ownerInputsSrc.includes(`<${field}>`), `must record <${field}>`);
  }
  assert(/REQUIRED_OWNER_ACKNOWLEDGEMENT_CONTROLLED_LIVE/.test(ownerInputsSrc), 'must record the owner acknowledgement for the controlled-live temporary rewrite/restore cycle');
  assert(!/https:\/\/chat\.googleapis\.com/.test(ownerInputsSrc), 'must not embed a real Google Chat webhook URL');
});

// ---------------------------------------------------------------------
// Finish.
// ---------------------------------------------------------------------
const passed = results.filter((r) => r.passed).length;
const failed = results.length - passed;
const summary = {
  schema_version: '1.0',
  generated_at: new Date().toISOString(),
  total: results.length,
  passed,
  failed,
  overall_result: failed === 0 ? 'PASS' : 'FAIL',
  results,
};

fs.writeFileSync(
  path.join(__dirname, 'final-operational-results.json'),
  `${JSON.stringify(summary, null, 2)}\n`,
  'utf8'
);

for (const r of results) {
  console.log(`[${r.passed ? 'PASS' : 'FAIL'}] ${r.id} - ${r.description}`);
  if (!r.passed && r.details !== undefined) {
    console.log(`       ${JSON.stringify(r.details)}`);
  }
}
console.log(`\n${passed}/${results.length} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
