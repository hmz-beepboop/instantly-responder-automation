# Phase 5 Mechanical Audit

**Generated:** 2026-06-14T17:06:51.2179350+00:00

## Safety boundary

- No live Instantly call was made.
- No workflow was activated or modified.
- The main n8n service was temporarily stopped only to avoid the documented task-broker port conflict during CLI execution.
- The main n8n service was restarted and confirmed API-ready.
- The n8n workflow executions were synthetic/local only.

## Workflow checks

| Workflow | ID | Active | Local matches remote | Credentials | External HTTP targets |
|---|---|---:|---:|---:|---:|
| HMZ - Instantly Reply Intake - Validation | cCcpFfi6iovWS94T | False | True | False | 0 |
| HMZ - Reply Decision Engine - Validation | NJcnNQoJ5nSIWYte | False | True | False | 0 |
| HMZ - Instantly Reply Sender - Validation | OzYLWuCF6DoU7Iw9 | False | True | False | 0 |
| HMZ - Reply Error Handler - Validation | koyKIaY2ExF3yhx7 | False | True | False | 0 |
| HMZ - Reply SLA Watchdog - Validation | 37p0OPzfDxlPvYQo | False | True | False | 0 |
| HMZ - Reply Full Test Harness - Validation | gu9Ede8IM5cHGtKK | False | True | False | 0 |

## Deterministic suites

- Phase 4A exit: 0
- Phase 4A pass marker: True
- Phase 4B exit: 0
- Phase 4B pass marker: True
- Sidecar health exit: 0
- Sidecar healthy: True

## Actual n8n runtime

### Full Test Harness

- Exit code: 0
- Timed out: False
- PASS/success marker observed: True
- Sanitised output snippet:

    n8n Task Broker ready on 127.0.0.1, port 5679
    Failed to start Python task runner in internal mode. because Python 3 is missing from this system. Launching a Python runner in internal mode is intended only for debugging and is not recommended for production. Users are encouraged to deploy in external mode. See: https://docs.n8n.io/hosting/configuration/task-runners/#setting-up-external-mode
    [license SDK] Skipping renewal on init: renewOnInit is disabled in config
    [license SDK] Skipping renewal on init: autoRenewEnabled is disabled in config
    [license SDK] Skipping renewal on init: license cert is not due for renewal
    Registered runner "JS Task Runner" (HIdp2q7KiF_CL-0LuPX7q) 
    Execution was successful:
    ====================================
    {
      "data": {
        "version": 1,
        "startData": {},
        "resultData": {
          "runData": {
            "Manual Trigger": [
              {
                "startTime": 1781456852264,
                "executionIndex": 0,
                "source": [],
                "hints": [],
                "executionTime": 2,
                "executionStatus": "success",
                "data": {
                  "main": [
                    [
                      {
                        "json": {},
                        "pairedItem": {
                          "item": 0
                        }
                      }
                    ]
                  ]
                }
              }
            ],
            "A. Run Fixture Matr...<TRUNCATED>

### SLA Watchdog

- Exit code: 0
- Timed out: False
- Success marker observed: True
- Sanitised output snippet:

    n8n Task Broker ready on 127.0.0.1, port 5679
    Failed to start Python task runner in internal mode. because Python 3 is missing from this system. Launching a Python runner in internal mode is intended only for debugging and is not recommended for production. Users are encouraged to deploy in external mode. See: https://docs.n8n.io/hosting/configuration/task-runners/#setting-up-external-mode
    [license SDK] Skipping renewal on init: renewOnInit is disabled in config
    [license SDK] Skipping renewal on init: autoRenewEnabled is disabled in config
    [license SDK] Skipping renewal on init: license cert is not due for renewal
    Registered runner "JS Task Runner" (QUp3RMvr6K5VX8yhmZ9rl) 
    Execution was successful:
    ====================================
    {
      "data": {
        "version": 1,
        "startData": {},
        "resultData": {
          "runData": {
            "Schedule Trigger (Eventual)": [
              {
                "startTime": 1781456864646,
                "executionIndex": 0,
                "source": [],
                "hints": [],
                "executionTime": 1,
                "executionStatus": "success",
                "data": {
                  "main": [
                    [
                      {
                        "json": {},
                        "pairedItem": {
                          "item": 0
                        }
                      }
                    ]
                  ]
                }
              }
            ],
            "A. Cap...<TRUNCATED>

## n8n security audit

- Exit code: 0
- Timed out: False
- Sanitised output snippet:

    {
      "Nodes Risk Report": {
        "risk": "nodes",
        "sections": [
          {
            "title": "Official risky nodes",
            "description": "These nodes are part of n8n's official nodes and may be used to fetch and run any arbitrary code in the host system. This may lead to exploits such as remote code execution.",
            "recommendation": "Consider reviewing the parameters in these nodes, replacing them with app nodes where possible, and not loading unneeded node types with the NODES_EXCLUDE environment variable. See: https://docs.n8n.io/hosting/configuration/environment-variables/",
            "location": [
              {
                "kind": "node",
                "workflowId": "NJcnNQoJ5nSIWYte",
                "workflowName": "HMZ - Reply Decision Engine - Validation",
                "nodeId": "section_a",
                "nodeName": "A. Deterministic Policy Stage",
                "nodeType": "n8n-nodes-base.code"
              },
              {
                "kind": "node",
                "workflowId": "NJcnNQoJ5nSIWYte",
                "workflowName": "HMZ - Reply Decision Engine - Validation",
                "nodeId": "section_b",
                "nodeName": "B. Mock Semantic Classifier",
                "nodeType": "n8n-nodes-base.code"
              },
              {
                "kind": "node",
                "workflowId": "NJcnNQoJ5nSIWYte",
                "workflowName": "HMZ - Reply Decision Engine - Validation",
                "nodeId": "section_c",
                "nodeName": "C. Decision Policy",
                "nodeType": "n8n-nodes-base.code"
              },
              {
                "kind": "node",
                "workflowId": "NJcnNQ...<TRUNCATED>

## Project scan

- Historical owner-email replacements made: 0
- Real-email hit count after cleanup: 0
- Real-email files after cleanup: 
- Known synthetic secret-pattern hit count: 2
- Known synthetic secret-pattern files: verification\phase4a\run-offline-tests.mjs, verification\phase4b\run-offline-tests.mjs
- Unexpected secret-pattern hit count: 0
- Unexpected secret-pattern files: 

## Mechanical verdict

PHASE_5_MECHANICAL_AUDIT_PASSED

## Known limitations

- The Phase 4B n8n-MCP static-validator exception remains documented.
- Intake and Decision Engine runtime acceptance is inherited from Phase 3 evidence.
- Sender/Error Handler Code-node runtime and sidecar contracts are inherited from the audited Phase 4A suite.
- A controlled live Instantly send remains outside Phase 5 and is prohibited.
