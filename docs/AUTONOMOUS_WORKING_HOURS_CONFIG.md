# Autonomous Working Hours Configuration

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT ENABLED

---

## Purpose

The working-hours gate ensures autonomous sends only occur during times when the owner or reviewer is available to monitor and respond to any issues. This is a safety gate, not a delivery optimisation.

---

## Configuration Fields

| Field | Default | Description |
|-------|---------|-------------|
| `reviewer_timezone` | `America/New_York` | IANA timezone for all working-hours evaluation |
| `working_days` | Mon–Fri | Days on which autonomous sends are permitted |
| `working_hours_start` | `09:00` | Start of permitted window (in reviewer_timezone) |
| `working_hours_end` | `18:00` | End of permitted window (in reviewer_timezone) |
| `prospect_timezone_strategy` | `reviewer_only` | How prospect timezone affects eligibility |
| `blackout_dates` | `[]` | Dates (YYYY-MM-DD) on which no sends are permitted |
| `holiday_calendar_placeholder` | `US_FEDERAL` | Future holiday calendar integration point |

---

## Recommended Initial Configuration

For the first controlled pilot:

```json
{
  "reviewer_timezone": "America/New_York",
  "working_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
  "working_hours_start": "09:00",
  "working_hours_end": "17:00",
  "prospect_timezone_strategy": "reviewer_only",
  "blackout_dates": []
}
```

**Why 09:00–17:00 rather than 18:00:** Ending at 17:00 ensures the owner can review the daily digest before end of business and respond to any issues during working hours.

---

## Prospect Timezone Strategy Options

### `reviewer_only` (Recommended for initial pilot)
Only the reviewer's timezone is checked. If the reviewer is in their working hours, the send is eligible regardless of the prospect's timezone.

**Use when:** Starting out; simplest; lowest risk of timezone evaluation errors.

### `prospect_business_hours`
Both the reviewer AND the prospect must be in business hours (09:00–18:00 in their respective timezones). Requires prospect timezone to be known from the Instantly contact record.

**Use when:** Prospect timezone data is reliable and you want to avoid sending during prospect's off-hours.

### `intersection`
Only sends during the intersection of reviewer business hours and prospect business hours. Very restrictive; may result in few eligible windows.

**Use when:** High-sensitivity campaigns where bothering prospects off-hours is a significant concern.

---

## Blackout Dates

Add any dates when the owner cannot monitor autonomous activity:

```json
"blackout_dates": [
  "2026-07-04",
  "2026-09-07",
  "2026-11-26",
  "2026-11-27",
  "2026-12-25",
  "2026-12-26"
]
```

US Federal holidays are recommended minimums. Add any owner travel or vacation dates.

---

## Out-of-Hours Handling

When a candidate arrives out of hours:
- The case is evaluated by the eligibility engine
- The eligibility result shows `in_human_working_hours = false`
- The case is NOT sent autonomously
- The case is NOT suppressed — it is queued for the next working-hours window
- If the supervised path is still active, the case proceeds normally through human review

**Do not use the working-hours gate as a delay mechanism.** A candidate that is out of hours for autonomous eligibility should still be handled by the supervised human review path.

---

## Working Hours and the Daily Cap

The daily cap (`max_autonomous_sends_per_day`) resets at midnight in the reviewer's timezone. This means:
- Monday midnight (ET): cap resets
- Any sends from Monday working hours count against Monday's cap
- Tuesday's cap is fresh at midnight Monday ET

Do not set the daily cap higher than you can meaningfully review in one morning.

---

## Testing the Working Hours Gate

Run the eligibility engine with a scenario that specifies out-of-hours time:

```powershell
.\scripts\SL-PHASE-5C-autonomous-eligibility-engine.ps1 -UseSampleConfig -RunOfflineScenarios -ExportDecisionMatrix
```

Scenarios 2, 4, 8, 10, 48, 50 are explicitly out-of-hours scenarios. Verify `in_human_working_hours = false` and `would_send_live_now = false` for all of them.

---

## Related Documents

- `outputs/autonomous_config_schema.json` — full config schema
- `outputs/autonomous_sample_config.json` — sample config with all defaults
- `docs/AUTONOMOUS_SAFETY_MODEL.md` — all gate layers including working hours
- `docs/AUTONOMOUS_ELIGIBILITY_ENGINE.md` — how working hours is evaluated in the engine
