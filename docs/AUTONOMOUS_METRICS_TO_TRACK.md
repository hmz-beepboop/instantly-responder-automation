# Autonomous Metrics to Track

**Version:** 1.0  
**Date:** 2026-06-24

---

## Shadow Mode Metrics (Phase A)

Track these during the 14-day shadow calibration period:

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Total candidates evaluated | N/A (count) | Daily digest |
| Shadow-eligible rate | 20–50% of candidates | Daily digest |
| Top blocked reasons | Document top 3 | Daily digest |
| Draft quality rating (subjective) | 90%+ acceptable | Owner review of draft excerpts |
| Unexpected shadow allowances | 0 | Owner digest review |
| Unexpected blocks | < 5% | Owner digest review |
| High-risk escalations | 0 unexpected | Daily digest section 3 |
| Learning events generated | N/A (count) | Daily digest section 7 |

---

## Controlled Pilot Metrics (Phase B)

Track these during and after each autonomous send:

### Volume Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Sends per day | ≤ `live_pilot_daily_cap` | Never exceed cap |
| Sends blocked by cap | 0 cap violations | Cap must never be exceeded |
| Sends per campaign | ≤ cap per campaign | Separate counter |
| Sends per sender | ≤ cap per sender | Separate counter |

### Quality Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| `good_response` rate | ≥ 85% | From post-action reviews |
| `bad_response` rate | < 5% | Triggers review if > 5% |
| `should_have_escalated` rate | 0% | Zero tolerance |
| `wrong_classification` rate | < 2% | Triggers eligibility review |
| Post-action review completion | 100% | Every send reviewed next day |

### Prospect Reaction Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Positive reactions | N/A (track) | Count prospects who replied positively |
| Negative reactions | 0 | Any negative triggers human case |
| Unsubscribes from autonomous sends | 0 | Zero tolerance |
| No reply rate | Track over time | Compare to supervised baseline |

### Safety Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Kill switch activations | 0 | Any activation is a serious event |
| Blocked intent violations | 0 | Permanently blocked intents must never be sent |
| Idempotency failures | 0 | No duplicates |
| Out-of-hours sends | 0 | Working hours gate must never fail |

---

## Weekly Review Dashboard (Suggested)

Each week, owner reviews:

1. **Sends this week:** total, by campaign, by intent type
2. **Quality distribution:** good / acceptable / bad / escalated counts
3. **Blocked reason distribution:** top 5 blocked reasons
4. **Prospect reactions:** positive / neutral / negative
5. **Learning events from autonomous cases:** rule candidates created
6. **Shadow calibration quality:** any unexpected shadow decisions this week
7. **Kill switch / escalation events:** zero target
8. **Comparison to supervised baseline:** are autonomous responses as good as supervised?

---

## Comparison Baseline (Supervised Path)

Before enabling any autonomous sends, establish baselines from the supervised path:

| Metric | Supervised Baseline | Autonomous Target |
|--------|--------------------|--------------------|
| Prospect reply rate | Measure first | Match or exceed |
| Positive reply rate | Measure first | Match or exceed |
| Negative reply rate | Measure first | ≤ supervised |
| Unsubscribe rate | Measure first | ≤ supervised |
| Draft quality (owner rating) | 9.0+/10 | ≥ 8.5/10 |

---

## When to Reduce or Pause Autonomous Mode

| Signal | Action |
|--------|--------|
| `bad_response` rate > 10% | Reduce confidence_threshold; review intent allowlist |
| Any `should_have_escalated` | Review that intent type for eligibility |
| Any unsubscribe from autonomous send | Remove that intent type immediately |
| Prospect complaint | Activate kill switch; investigate |
| Kill switch activated once | Reduce daily cap to 1 after re-enabling |
| Post-action review not completed for 3+ days | Pause autonomous mode |

---

## Related Documents

- `docs/AUTONOMOUS_FIRST_PILOT_RECOMMENDATION.md` — pilot configuration
- `docs/AUTONOMOUS_DAILY_DIGEST_SPEC.md` — digest includes these metrics
- `docs/AUTONOMOUS_POST_ACTION_REVIEW_FORM_SPEC.md` — quality rating source
- `docs/AUTONOMOUS_GO_NO_GO_CHECKLIST.md` — when to advance or halt
