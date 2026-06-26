# Autonomous Observability Dashboard Specification

**Version:** 1.0  
**Date:** 2026-06-24  
**Status:** DESIGN — NOT IMPLEMENTED

---

## Purpose

Defines the metrics, panels, and data sources for an observability dashboard to monitor autonomous layer health during shadow mode and controlled pilot.

---

## Dashboard Panels

### Panel 1 — Daily Activity Summary

**Metrics:**
- Total candidates evaluated today
- Shadow-eligible count today
- Blocked count today
- Autonomous sends today (0 in shadow mode)
- Kill switch status (GREEN/RED)

**Refresh:** Real-time (every 5 minutes)

---

### Panel 2 — Intent Distribution

**Chart type:** Horizontal bar chart  
**Shows:** Count of candidates by micro_intent type, split by blocked/shadow-eligible  
**Purpose:** Identify which intent types dominate the candidate pool

---

### Panel 3 — Block Reason Breakdown

**Chart type:** Pie chart  
**Shows:** Top 10 blocked reasons as % of total blocked  
**Purpose:** Identify the primary gates blocking autonomous sends

---

### Panel 4 — Confidence Distribution

**Chart type:** Histogram  
**Shows:** Distribution of confidence scores across all candidates  
**Purpose:** Calibrate the confidence_threshold setting

---

### Panel 5 — Quality Trend (Controlled Pilot Only)

**Chart type:** Line chart over time  
**Shows:** Rolling 7-day quality rating breakdown (good / acceptable / bad)  
**Purpose:** Track whether autonomous quality is improving or degrading

---

### Panel 6 — Prospect Reaction Rate (Controlled Pilot Only)

**Chart type:** Stacked bar  
**Shows:** Prospect reactions (POSITIVE / NEUTRAL / NEGATIVE / UNSUBSCRIBE) by week  
**Purpose:** Detect deteriorating prospect experience

---

### Panel 7 — Kill Switch and Escalation History

**Chart type:** Event timeline  
**Shows:** Kill switch activations, escalations, incidents  
**Purpose:** Safety event audit trail at a glance

---

### Panel 8 — Learning Event Rate

**Chart type:** Line chart  
**Shows:** Learning events generated per week from autonomous cases  
**Purpose:** Track whether the system is learning from autonomous corrections

---

## Data Sources

| Panel | Source |
|-------|--------|
| 1 | hmz-autonomous-daily-digest DataTable |
| 2, 3, 4 | hmz-autonomous-shadow-log DataTable |
| 5, 6 | hmz-autonomous-review-queue DataTable |
| 7 | Audit trail log |
| 8 | hmz-learning-events DataTable (filtered by autonomous_case=true) |

---

## Implementation Note

This dashboard is not yet implemented. Candidate tools:
- n8n built-in monitoring
- Grafana (if n8n metrics are exportable)
- Custom Google Sheets dashboard reading from DataTable API

The daily digest serves as a text-based observability mechanism until a graphical dashboard is built.

---

## Related Documents

- `docs/AUTONOMOUS_ALERTING_SPEC.md` — alert rules
- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — text-based monitoring
- `docs/AUTONOMOUS_DATA_MODEL.md` — data sources
