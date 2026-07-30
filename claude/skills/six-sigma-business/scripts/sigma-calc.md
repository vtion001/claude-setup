# Sigma / DPMO / Cp-Cpk — Formulas & Worked Business Examples

Reference for the Measure phase. Compute by hand or with the snippets below. **Always** attach a
confidence label and the n + window (see `references/business-mapping.md` §6).

## DPMO → sigma

```
DPMO = defects / (units × opportunities_per_unit) × 1,000,000
```

Sigma level: look up DPMO in the table in `references/scoring-rubric.md` (includes the 1.5σ shift),
or approximate in Python:

```python
from scipy.stats import norm   # if available
def sigma_from_dpmo(dpmo):
    yield_ = 1 - dpmo/1_000_000
    return norm.ppf(yield_) + 1.5          # +1.5 long-term shift convention
```

No SciPy? Use the discrete table in the scoring rubric — it is sufficient for reporting.

### Worked example A — Marketing: lead → MQL conversion (Measured)
- Window: 1 quarter. Units = 12,400 leads captured (HubSpot export).
- Opportunities/unit = 5 (form-validate, scoring-rule, ICP-fit-check, SLA-routing, MQL-handoff).
- Defects = 7,440 leads that failed to become MQL within SLA (60% non-conversion of in-scope ICP).
- DPMO = 7,440 / (12,400 × 5) × 1e6 = **120,000** → ~**2.7σ**.
- Confidence: **Measured** (n=12,400, 1Q, definitions stable). Read: a chronic mid-funnel leak,
  almost certainly Method (no SLA routing) or Measurement (ICP filter wrong) per
  `business-mapping.md` §2.

### Worked example B — Sales: deal-cycle defect (Indicative)
- Window: 1 quarter. Units = 38 closed deals (CRM closed-won + closed-lost). Opportunities/unit = 1
  (cycle > median × 2 = a defect, single failure point).
- Defects = 9 deals exceeded 2× median cycle (= the slow-cycle long tail).
- DPMO = 9 / (38 × 1) × 1e6 = **236,842** → ~**2.2σ** (really a slow-cycle *rate* of 23.7%).
- Confidence: **Indicative** — n=38 is borderline; cite the rate alongside the sigma. Sigma alone
  is misleading for a small sales team — name the rate.

### Worked example C — Customer Success: churn (Measured if SaaS scale)
- Window: 1 year. Units = 1,200 customer-months observed (e.g. 100 customers × 12 months).
- Opportunities/unit = 5 (onboarding completion, first-value moment, QBR cadence, expansion
  outreach, renewal touch).
- Defects = 96 customer-months that ended in churn (= 8 customers churned, ~8% gross logo churn).
- DPMO = 96 / (1,200 × 5) × 1e6 = **16,000** → ~**3.6σ**.
- Confidence: **Measured** (n=1,200 customer-months). Pair with gross-revenue churn % and NRR — the
  sigma is a process headline, the SaaS metrics are the board headline.

### Worked example D — Operations: fulfillment SLA (Measured)
- Window: 1 quarter. Units = 8,500 orders shipped. Opportunities/unit = 5 stages (receive, pick,
  pack, ship, deliver).
- Defects = 510 orders missed promised delivery date.
- DPMO = 510 / (8,500 × 5) × 1e6 = **12,000** → ~**3.8σ**.
- Confidence: **Measured**. Add Cp/Cpk on continuous fulfillment-minutes (below) to find variation
  root cause.

## Cp / Cpk (continuous metric vs spec)

```
Cp  = (USL − LSL) / (6·σ̂)
Cpk = min( (USL − μ)/(3·σ̂), (μ − LSL)/(3·σ̂) )
```
μ = sample mean, σ̂ = sample std dev. One-sided spec (e.g. lead SLA only has an upper bound USL):
use the USL half only: `Cpk = (USL − μ)/(3σ̂)`.

```python
import statistics as st
def cpk_one_sided_upper(samples, usl):
    mu = st.fmean(samples); sd = st.pstdev(samples)
    return (usl - mu) / (3*sd) if sd else float('inf')
```

### Worked example E — Marketing: lead first-contact SLA capability (Measured)
- Spec: inbound MQL must be contacted within **USL = 5 minutes**. Samples: 380 inbound leads (CRM
  timestamps).
- μ = 3.2 min, σ̂ = 2.4 min → Cpk = (5−3.2)/(3×2.4) = **0.25** → **not capable** (target ≥ 1.33).
- Read: average looks fine but variation is huge — the right tail breaches SLA constantly. The fix
  is to *reduce variation* (24×7 routing, auto-assignment, pager rotation) before reducing the
  mean. Confidence: Measured.

### Worked example F — Finance: DSO capability (Measured)
- Spec: USL = 45 days. Samples: 220 invoice cohorts (last 4 quarters).
- μ = 41 d, σ̂ = 9 d → Cpk = (45−41)/(3×9) = **0.15** → **not capable**.
- Read: the average is under target but variation will breach repeatedly; large-customer slow-pay
  is the variation source. Confidence: Measured.

### Worked example G — Support: ticket first response (Measured)
- Spec: USL = 60 min for P1. Samples: 1,100 P1 tickets.
- μ = 22 min, σ̂ = 28 min → Cpk = (60−22)/(3×28) = **0.45** → **not capable**.
- Same pattern: out-of-hours coverage is the variation source.

## Counting rules (do this explicitly in Define)
- **Pick ONE unit and ONE opportunity definition per department** and keep them stable across the
  window. Record verbatim in the scorecard.
- Defects must be **countable and observable**; if a department isn't instrumented (e.g. no
  closed-loop attribution in Marketing, no CRM stage history in Sales), you cannot count escaped
  defects — say so and recommend instrumentation as the first Measure improvement.
- Prefer **Measured** continuous data (SLA seconds/minutes, DSO days) for capability; use
  **Indicative** rates for low-volume discrete data (small sales teams); never present
  Insufficient data as a precise sigma.
- The enterprise rollup is **revenue-impact weighted** (see `business-mapping.md` §7), not a flat
  average. Exclude any dept whose label is *Insufficient* from the rollup.
