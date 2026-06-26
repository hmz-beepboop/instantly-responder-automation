# Local Runtime Credential Rule Fix

The business-ready apply step correctly bound three approved credential
references into the remote n8n workflows:

- `hmzInstantlyApi` as `httpHeaderAuth`
- `hmzInstantlyWebhookToken` as `httpHeaderAuth`
- `hmzReviewBasicAuth` as `httpBasicAuth`

The previous local runtime acceptance script still enforced the obsolete
Phase 4 rule that no remote workflow may contain any `credentials` object.
It therefore stopped before runtime tests and left
`allWorkflowsInactiveInitially=false` simply because that flag had not yet
been assigned.

This patch does not weaken the credential check. It replaces it with a
fail-closed rule that verifies for every binding:

- exact approved credential name;
- exact credential type;
- exact deployment credential ID from the current PowerShell process;
- permitted workflow;
- permitted node type.

It also permits only:

- the internal `hmz-send-state` URL;
- the gated Google Chat environment expression;
- exact Instantly V2 URLs or request-contract expressions on approved
  Decision Engine/Sender nodes carrying the approved Instantly credential
  and `continueRegularOutput`.

Before any execution it verifies stored safe configuration:

- `owner_inputs_status=COMPLETE`
- `operating_mode=VALIDATION`
- `dry_run=true`
- `live_campaigns=[]`
- controlled-live readiness false
- all suppression actions disabled

No workflow JSON, credentials, API contracts, or business logic were changed.
