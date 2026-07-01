param()

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DecisionPath = Join-Path $Root "workflows/production_decision_current.json"
$HumanPath = Join-Path $Root "workflows/production_humanapproval_current.json"

$script:Checks = @()

function Add-Check {
  param([string]$Name, [bool]$Ok)
  $script:Checks += [pscustomobject]@{ Name = $Name; Ok = $Ok }
  if ($Ok) { Write-Host "[PASS] $Name" } else { Write-Host "[FAIL] $Name" }
}

function Get-NodeCode {
  param([string]$Path, [string]$Name)
  $wf = Get-Content -Raw -Path $Path | ConvertFrom-Json
  foreach ($node in $wf.nodes) {
    if ($node.name -eq $Name) { return [string]$node.parameters.jsCode }
  }
  throw "node not found: $Name"
}

$DecisionD = Get-NodeCode $DecisionPath "D. Draft Preparation (Templates / Human Draft)"
$HumanA = Get-NodeCode $HumanPath "A. Build Review Case Record"
$HumanD = Get-NodeCode $HumanPath "D. Build Google Chat Notification Payload"
$HumanJ = Get-NodeCode $HumanPath "J. Render Review Form HTML"
$HumanN = Get-NodeCode $HumanPath "N. Process Reviewer Decision"
$HumanP2A = Get-NodeCode $HumanPath "SL-P2A. Prepare Phase 1C+2 Capture Data"
$HumanWorkflow = Get-Content -Raw -Path $HumanPath | ConvertFrom-Json
$ApprovalRouter = ($HumanWorkflow.nodes | Where-Object { $_.name -eq "P. Approval Outcome Router" } | Select-Object -First 1).parameters | ConvertTo-Json -Depth 20

Write-Host "== Decision D syntax regression guard =="
Add-Check "active-policy regex contains escaped word boundaries, not backspace chars" (-not $DecisionD.Contains([char]8) -and $DecisionD.Contains("\b(proof|prove"))
Add-Check "paragraph split regex is escaped and not a broken multiline literal" ($DecisionD.Contains("text.split(/\n\s*\n/)"))
Add-Check "mandatory active guidance string uses escaped newlines" ($DecisionD.Contains("return '\n\nMANDATORY ACTIVE DRAFTING CONSTRAINTS"))
Add-Check "Decision D no longer contains the historical broken text.split literal" (-not $DecisionD.Contains("text.split(/`n\s*`n/)"))

Write-Host "`n== HumanApproval missing-context diagnostic guard =="
Add-Check "case creation computes missingContextFields" ($HumanA.Contains("missingContextFields"))
Add-Check "missing sender/from blocks diagnostic review" ($HumanA.Contains('missingContextFields.push("reply_from_email")') -and $HumanA.Contains('missingContextFields.push("sender_email")'))
Add-Check "missing reply body blocks diagnostic review" ($HumanA.Contains('missingContextFields.push("reply_text")'))
Add-Check "missing subject/thread blocks diagnostic review" ($HumanA.Contains('missingContextFields.push("reply_subject")') -and $HumanA.Contains('missingContextFields.push("thread_id")'))
Add-Check "missing classification/micro-intent/draft blocks diagnostic review" ($HumanA.Contains('missingContextFields.push("classification")') -and $HumanA.Contains('missingContextFields.push("micro_intent")') -and $HumanA.Contains('missingContextFields.push("draft_text")'))
Add-Check "diagnostic cases use INTAKE_CONTEXT_MISSING state" ($HumanA.Contains("INTAKE_CONTEXT_MISSING") -and $HumanA.Contains("CONTEXT_MISSING_BLOCKED"))
Add-Check "diagnostic cases use non-send reply mode" ($HumanA.Contains("DIAGNOSTIC_CONTEXT_MISSING"))
Add-Check "diagnostic alert includes missing field names" ($HumanD.Contains("INVALID reply review case - missing context") -and $HumanD.Contains("Missing fields:"))
Add-Check "diagnostic alert includes owner correction instructions" ($HumanD.Contains("Correction:") -and $HumanD.Contains("seeded owned/test prospect"))
Add-Check "diagnostic form explains blocked state" ($HumanJ.Contains("Invalid review case - missing context") -and $HumanJ.Contains("Approve/send and learning-only actions are unavailable"))
Add-Check "persisted blank/UNKNOWN rows render diagnostic-only" ($HumanJ.Contains("_5q3RowLooksMissing"))
Add-Check "diagnostic form returns before normal form/buttons" ($HumanJ.IndexOf("Invalid review case - missing context") -ge 0 -and $HumanJ.IndexOf("Invalid review case - missing context") -lt $HumanJ.IndexOf("Approve and send"))
Add-Check "approve/send button remains only on normal review path" ($HumanJ.Contains("Approve and send") -and $HumanJ.Contains("DIAGNOSTIC_CONTEXT_MISSING"))
Add-Check "learning-only button remains only on normal/reopened paths" ($HumanJ.Contains("approve_learning_only") -and $HumanJ.IndexOf("Invalid review case - missing context") -lt $HumanJ.IndexOf("approve_learning_only"))
Add-Check "submit processing blocks diagnostic cases" ($HumanN.Contains("blocked_context_missing") -and $HumanN.Contains("Diagnostic missing-context cases cannot be approved"))
Add-Check "persisted blank/UNKNOWN rows are blocked on submit" ($HumanN.Contains("rowLooksMissing"))
Add-Check "blank diagnostic cases cannot create learning candidates" ($HumanP2A.Contains("context_missing_no_learning") -and $HumanP2A.Contains("sl_p2_rule_candidates: []"))
Add-Check "Sender path still requires final_action approve" ($ApprovalRouter.Contains("final_action === 'approve'"))

Write-Host "`n== Synthetic guard predicate =="
function Test-MissingContext {
  param([hashtable]$Case)
  $fields = New-Object System.Collections.Generic.List[string]
  if (-not $Case.reply_from_email) { $fields.Add("reply_from_email") }
  if (-not $Case.sender_email) { $fields.Add("sender_email") }
  if (-not $Case.reply_subject) { $fields.Add("reply_subject") }
  if (-not $Case.thread_id) { $fields.Add("thread_id") }
  if (-not $Case.reply_text) { $fields.Add("reply_text") }
  if (-not $Case.draft_text) { $fields.Add("draft_text") }
  if (-not $Case.category -or $Case.category -eq "UNKNOWN") { $fields.Add("classification") }
  if (-not $Case.micro_intent) { $fields.Add("micro_intent") }
  $blocked = ($fields.Count -gt 0)
  return [pscustomobject]@{ Blocked = $blocked; Missing = @($fields) }
}

$valid = @{
  reply_from_email = "prospect@example.test"
  sender_email = "sender@example.test"
  reply_subject = "Re: Capacity Question"
  thread_id = "thread-1"
  reply_text = "Before we book anything, can you explain setup?"
  draft_text = "Of course. The setup includes qualification and capacity planning."
  category = "INFORMATION_REQUEST"
  micro_intent = "OFFER_EXPLANATION"
  validation_valid = $true
}
$result = Test-MissingContext $valid
Add-Check "valid hydrated inbound reply remains normal review case" (-not $result.Blocked -and $result.Missing.Count -eq 0)

foreach ($field in @("reply_from_email", "reply_text", "reply_subject", "thread_id", "draft_text", "category")) {
  $bad = $valid.Clone()
  if ($field -eq "category") { $bad[$field] = "UNKNOWN"; $expected = "classification" } else { $bad[$field] = ""; $expected = $field }
  $result = Test-MissingContext $bad
  Add-Check "missing $expected blocks normal review/send" ($result.Blocked -and $result.Missing -contains $expected)
}

$badUnknown = $valid.Clone()
$badUnknown.category = "UNKNOWN"
$badUnknown.draft_text = ""
$badUnknown.micro_intent = ""
$badUnknown.validation_valid = $false
$result = Test-MissingContext $badUnknown
Add-Check "UNKNOWN classification with blank draft is diagnostic only" ($result.Blocked -and $result.Missing -contains "classification" -and $result.Missing -contains "draft_text")

$failures = @($script:Checks | Where-Object { -not $_.Ok })
$passes = $script:Checks.Count - $failures.Count
Write-Host "`nSUMMARY: $passes/$($script:Checks.Count) PASS, $($failures.Count) FAIL"
if ($failures.Count -gt 0) { exit 1 }
