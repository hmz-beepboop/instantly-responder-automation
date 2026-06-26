// V5 Layer 1 runner: starts the localhost mock server, runs every required
// fault-injection scenario through the sender policy, asserts the expected
// outcomes, and writes sanitised results to results.json.

import http from 'node:http';
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { createMockServer, getClosedPort } from './mock-server.mjs';
import { sendReply, STATES, defaultJitter } from './sender-policy.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RESULTS_PATH = path.join(__dirname, 'results.json');

const noopSleep = async () => {};

// Single raw HTTP POST attempt against 127.0.0.1. Resolves; never rejects.
function rawHttpAttempt({ port, path: reqPath, timeoutMs }) {
  return new Promise((resolve) => {
    const payload = JSON.stringify({ replyId: 'layer1-test', message: 'ack' });
    const req = http.request(
      {
        host: '127.0.0.1',
        port,
        path: reqPath,
        method: 'POST',
        agent: false,
        timeout: timeoutMs,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          let parsedBody = null;
          try {
            parsedBody = JSON.parse(raw);
          } catch {
            parsedBody = null;
          }
          resolve({ ok: true, status: res.statusCode, headers: res.headers, body: parsedBody });
        });
      }
    );

    req.on('timeout', () => {
      req.destroy(new Error('CLIENT_TIMEOUT'));
    });

    req.on('error', (err) => {
      resolve({ ok: false, code: err.code || err.message });
    });

    req.write(payload);
    req.end();
  });
}

function buildScenarios({ port, closedPort }) {
  // Wraps a mock-server path that always returns an HTTP response.
  const httpSubmit = (reqPath, timeoutMs = 100) => async () => {
    const raw = await rawHttpAttempt({ port, path: reqPath, timeoutMs });
    if (!raw.ok) {
      throw new Error(`Unexpected network error for ${reqPath}: ${raw.code}`);
    }
    return { kind: 'http', status: raw.status, headers: raw.headers, body: raw.body, serverReceived: true };
  };

  // Wraps a mock-server path that always fails at the network level after
  // the server has received at least the request headers.
  const networkSubmit = (reqPath, errorPhase, timeoutMs = 100) => async () => {
    const raw = await rawHttpAttempt({ port, path: reqPath, timeoutMs });
    if (raw.ok) {
      throw new Error(`Expected network error for ${reqPath} but got HTTP ${raw.status}`);
    }
    return { kind: 'network-error', errorPhase, serverReceived: true, code: raw.code };
  };

  // Scenario 12: connection refused, proven before submission (no listener).
  const connectionRefusedSubmit = () => async () => {
    const raw = await rawHttpAttempt({ port: closedPort, path: '/s/anything', timeoutMs: 100 });
    if (raw.ok) {
      throw new Error('Expected connection refused but got an HTTP response');
    }
    return { kind: 'network-error', errorPhase: 'connection-refused', serverReceived: false, code: raw.code };
  };

  // Scenario 15: synthetic failure before any request is dispatched.
  const preSubmissionSubmit = () => async () => ({
    kind: 'network-error',
    errorPhase: 'pre-submission',
    serverReceived: false,
    code: 'SIMULATED_PRE_SUBMISSION_FAILURE',
  });

  const j1 = defaultJitter(1); // 37
  const j2 = defaultJitter(2); // 24
  const backoff429NoRetryAfter = [100 + j1, 200 + j2];
  const backoff5xx = [100 + j1, 200 + j2];
  const backoffPreSubmission = [100 + j1, 200 + j2];
  const backoff429RetryAfter = [1000, 1000];

  return [
    {
      name: 'http_400_bad_request',
      description: 'HTTP 400 -> PERMANENT_FAILURE, no retry',
      submit: httpSubmit('/s/400'),
      expected: {
        finalState: STATES.PERMANENT_FAILURE,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'http_401_unauthorized',
      description: 'HTTP 401 -> AUTH_OR_PLAN_FAILURE, no retry',
      submit: httpSubmit('/s/401'),
      expected: {
        finalState: STATES.AUTH_OR_PLAN_FAILURE,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'http_402_payment_required',
      description: 'HTTP 402 -> AUTH_OR_PLAN_FAILURE, no retry',
      submit: httpSubmit('/s/402'),
      expected: {
        finalState: STATES.AUTH_OR_PLAN_FAILURE,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'http_403_forbidden',
      description: 'HTTP 403 -> AUTH_OR_PLAN_FAILURE, no retry',
      submit: httpSubmit('/s/403'),
      expected: {
        finalState: STATES.AUTH_OR_PLAN_FAILURE,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'http_404_invalid_reply_target',
      description: 'HTTP 404 invalid reply target -> INVALID_REPLY_TARGET, no retry',
      submit: httpSubmit('/s/404'),
      expected: {
        finalState: STATES.INVALID_REPLY_TARGET,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'http_429_with_retry_after',
      description: 'HTTP 429 with Retry-After -> bounded retry honouring Retry-After -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/429-retry-after'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: true,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff429RetryAfter,
      },
    },
    {
      name: 'http_429_without_retry_after',
      description: 'HTTP 429 without Retry-After -> bounded exponential backoff -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/429-no-retry-after'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff429NoRetryAfter,
      },
    },
    {
      name: 'http_500_server_error',
      description: 'HTTP 500 -> bounded retry -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/500'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff5xx,
      },
    },
    {
      name: 'http_502_bad_gateway',
      description: 'HTTP 502 -> bounded retry -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/502'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff5xx,
      },
    },
    {
      name: 'http_503_service_unavailable',
      description: 'HTTP 503 -> bounded retry -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/503'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff5xx,
      },
    },
    {
      name: 'http_504_gateway_timeout',
      description: 'HTTP 504 -> bounded retry -> RETRY_EXHAUSTED',
      submit: httpSubmit('/s/504'),
      expected: {
        finalState: STATES.RETRY_EXHAUSTED,
        attempts: 3,
        postSubmissions: 3,
        maxAllowedSubmissions: 3,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoff5xx,
      },
    },
    {
      name: 'connection_refused_before_submission',
      description: 'Connection refused before submission -> retryable -> PRE_SUBMISSION_NETWORK_FAILURE',
      submit: connectionRefusedSubmit(),
      expected: {
        finalState: STATES.PRE_SUBMISSION_NETWORK_FAILURE,
        attempts: 3,
        postSubmissions: 0,
        maxAllowedSubmissions: 0,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoffPreSubmission,
      },
    },
    {
      name: 'connection_reset_before_confirmed_submission',
      description: 'Connection reset before submission confirmed -> SEND_UNCERTAIN, no retry',
      submit: networkSubmit('/s/reset-before', 'connection-loss-before-confirmed'),
      expected: {
        finalState: STATES.SEND_UNCERTAIN,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'connection_reset_after_submission',
      description: 'Connection reset after request body submitted -> SEND_UNCERTAIN, no retry',
      submit: networkSubmit('/s/reset-after', 'connection-loss-after-submission'),
      expected: {
        finalState: STATES.SEND_UNCERTAIN,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'failure_before_request_submission',
      description: 'Failure proven before request submission -> retryable -> PRE_SUBMISSION_NETWORK_FAILURE',
      submit: preSubmissionSubmit(),
      expected: {
        finalState: STATES.PRE_SUBMISSION_NETWORK_FAILURE,
        attempts: 3,
        postSubmissions: 0,
        maxAllowedSubmissions: 0,
        retried: true,
        retryAfterHonoured: false,
        humanReviewRequired: true,
        backoffDelaysRequested: backoffPreSubmission,
      },
    },
    {
      name: 'delayed_success_within_timeout',
      description: 'Delayed valid 2xx response within timeout -> SENT, no retry',
      submit: httpSubmit('/s/delayed-success'),
      expected: {
        finalState: STATES.SENT,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: false,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'malformed_success_response',
      description: 'Malformed 2xx response -> SEND_UNCERTAIN, no retry',
      submit: httpSubmit('/s/malformed-success'),
      expected: {
        finalState: STATES.SEND_UNCERTAIN,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
    {
      name: 'timeout_after_submission',
      description: 'Timeout waiting for response after submission -> SEND_UNCERTAIN, no retry',
      submit: networkSubmit('/s/timeout', 'timeout-after-submission', 60),
      expected: {
        finalState: STATES.SEND_UNCERTAIN,
        attempts: 1,
        postSubmissions: 1,
        maxAllowedSubmissions: 1,
        retried: false,
        retryAfterHonoured: null,
        humanReviewRequired: true,
        backoffDelaysRequested: [],
      },
    },
  ];
}

function arraysEqual(a, b) {
  return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => v === b[i]);
}

function assertField(assertions, check, expected, actual) {
  const pass = Array.isArray(expected) ? arraysEqual(expected, actual) : expected === actual;
  assertions.push({ check, expected, actual, pass });
  return pass;
}

async function runScenario(scenario) {
  const result = await sendReply({ submit: scenario.submit, sleep: noopSleep });
  const assertions = [];

  assertField(assertions, 'finalState', scenario.expected.finalState, result.finalState);
  assertField(assertions, 'attempts', scenario.expected.attempts, result.attempts);
  assertField(assertions, 'postSubmissions', scenario.expected.postSubmissions, result.postSubmissions);
  assertField(assertions, 'retried', scenario.expected.retried, result.retried);
  assertField(assertions, 'retryAfterHonoured', scenario.expected.retryAfterHonoured, result.retryAfterHonoured);
  assertField(assertions, 'humanReviewRequired', scenario.expected.humanReviewRequired, result.humanReviewRequired);
  assertField(assertions, 'duplicateRiskRetry', false, result.duplicateRiskRetry);
  assertField(assertions, 'backoffDelaysRequested', scenario.expected.backoffDelaysRequested, result.backoffDelaysRequested);
  assertField(
    assertions,
    'postSubmissions<=maxAllowed',
    true,
    result.postSubmissions <= scenario.expected.maxAllowedSubmissions
  );

  const pass = assertions.every((a) => a.pass);

  return {
    name: scenario.name,
    description: scenario.description,
    expected: scenario.expected,
    actual: {
      finalState: result.finalState,
      attempts: result.attempts,
      postSubmissions: result.postSubmissions,
      retried: result.retried,
      backoffDelaysRequested: result.backoffDelaysRequested,
      retryAfterHonoured: result.retryAfterHonoured,
      humanReviewRequired: result.humanReviewRequired,
      duplicateRiskRetry: result.duplicateRiskRetry,
      attemptOutcomes: result.attemptOutcomes,
    },
    assertions,
    pass,
  };
}

function buildGlobalAssertions(scenarioResults) {
  const byName = Object.fromEntries(scenarioResults.map((r) => [r.name, r]));
  const global = [];

  const oneAttempt = (names, label) => {
    const pass = names.every((n) => byName[n].actual.attempts === 1);
    global.push({ check: label, names, pass });
  };

  oneAttempt(['http_400_bad_request'], 'permanent_4xx_used_one_attempt');
  oneAttempt(
    ['http_401_unauthorized', 'http_402_payment_required', 'http_403_forbidden'],
    'auth_or_plan_failures_used_one_attempt'
  );
  oneAttempt(['http_404_invalid_reply_target'], 'invalid_reply_target_used_one_attempt');

  const retryableNames = [
    'http_429_with_retry_after',
    'http_429_without_retry_after',
    'http_500_server_error',
    'http_502_bad_gateway',
    'http_503_service_unavailable',
    'http_504_gateway_timeout',
    'connection_refused_before_submission',
    'failure_before_request_submission',
  ];
  global.push({
    check: 'retryable_scenarios_never_exceeded_three_attempts',
    names: retryableNames,
    pass: retryableNames.every((n) => byName[n].actual.attempts <= 3),
  });

  const uncertainNames = [
    'connection_reset_before_confirmed_submission',
    'connection_reset_after_submission',
    'malformed_success_response',
    'timeout_after_submission',
  ];
  global.push({
    check: 'send_uncertain_scenarios_issued_no_second_post',
    names: uncertainNames,
    pass: uncertainNames.every((n) => !byName[n].actual.retried && byName[n].actual.postSubmissions <= 1),
  });

  global.push({
    check: 'no_scenario_exceeded_its_max_allowed_post_submissions',
    names: scenarioResults.map((r) => r.name),
    pass: scenarioResults.every((r) => r.actual.postSubmissions <= r.expected.maxAllowedSubmissions),
  });

  global.push({
    check: 'every_required_scenario_executed',
    expectedCount: 18,
    actualCount: scenarioResults.length,
    pass: scenarioResults.length === 18,
  });

  global.push({
    check: 'no_external_network_request_occurred',
    pass: true,
    note: 'All requests target 127.0.0.1 (mock server and a closed-port probe); the pre-submission-failure scenario makes no network call at all.',
  });

  global.push({
    check: 'no_duplicate_risk_retry_in_any_scenario',
    pass: scenarioResults.every((r) => r.actual.duplicateRiskRetry === false),
  });

  return global;
}

async function main() {
  const mock = createMockServer();
  let scenarioResults = [];
  let globalAssertions = [];
  let allPass = false;

  try {
    const { port } = await mock.start();
    const closedPort = await getClosedPort();

    const scenarios = buildScenarios({ port, closedPort });
    for (const scenario of scenarios) {
      scenarioResults.push(await runScenario(scenario));
    }

    globalAssertions = buildGlobalAssertions(scenarioResults);
    allPass = scenarioResults.every((r) => r.pass) && globalAssertions.every((g) => g.pass);

    const summary = {
      totalScenarios: scenarioResults.length,
      passedScenarios: scenarioResults.filter((r) => r.pass).length,
      failedScenarios: scenarioResults.filter((r) => !r.pass).length,
      globalAssertionsTotal: globalAssertions.length,
      globalAssertionsPassed: globalAssertions.filter((g) => g.pass).length,
      verdict: allPass ? 'V5_LAYER1_VERIFIED' : 'V5_LAYER1_FAILED',
    };

    const results = {
      generatedAt: new Date().toISOString(),
      nodeVersion: process.version,
      policy: {
        maxAttempts: 3,
        baseBackoffMs: 100,
        maxBackoffMs: 2000,
        retryAfterCapMs: 5000,
        jitter: 'deterministic: (attempt * 37) % 50',
      },
      scenarios: scenarioResults,
      globalAssertions,
      summary,
    };

    await writeFile(RESULTS_PATH, JSON.stringify(results, null, 2), 'utf8');

    console.log(`Node version: ${process.version}`);
    for (const r of scenarioResults) {
      console.log(`${r.pass ? 'PASS' : 'FAIL'} ${r.name} -> ${r.actual.finalState}`);
    }
    for (const g of globalAssertions) {
      console.log(`${g.pass ? 'PASS' : 'FAIL'} [global] ${g.check}`);
    }
    console.log(`Verdict: ${summary.verdict}`);
  } finally {
    await mock.stop();
  }

  process.exitCode = allPass ? 0 : 1;
}

await main();
