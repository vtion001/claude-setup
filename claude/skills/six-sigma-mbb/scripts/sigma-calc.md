# Sigma / DPMO / Cp-Cpk — Formulas & Worked Software Examples

Reference for the Measure phase. Compute by hand or with the snippets below. **Always** attach a
confidence label and the n + window (see `references/software-mapping.md` §6).

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

### Worked example A — request-based (Measured)
- Window: 30 days. Units = 1,000,000 API requests (from access logs / PostHog).
- Opportunities/unit = 5 (auth, validate, compute, render, persist).
- Defects = 420 (5xx + SLA-miss events from Sentry).
- DPMO = 420 / (1,000,000 × 5) × 1e6 = **84**. → ~**5.3σ**. Confidence: **Measured** (n=1e6, 30d).

### Worked example B — deploy-based (Indicative)
- Window: 90 days. Units = 22 deploys (git tags). Opportunities/unit = 1.
- Defects = 3 deploys that needed a hotfix/rollback.
- DPMO = 3 / (22 × 1) × 1e6 = **136,363** → ~**2.6σ** (really a change-fail *rate* of 13.6%).
- Confidence: **Indicative** — n=22 is small; report the rate alongside, map to DORA change-fail rate.

## Cp / Cpk (continuous metric vs spec)

```
Cp  = (USL − LSL) / (6·σ̂)
Cpk = min( (USL − μ)/(3·σ̂), (μ − LSL)/(3·σ̂) )
```
μ = sample mean, σ̂ = sample std dev. One-sided spec (e.g. latency only has an upper bound USL):
use the USL half only: `Cpk = (USL − μ)/(3σ̂)`.

```python
import statistics as st
def cpk_one_sided_upper(samples, usl):
    mu = st.fmean(samples); sd = st.pstdev(samples)
    return (usl - mu) / (3*sd) if sd else float('inf')
```

### Worked example C — latency capability (Measured)
- Spec: p-level API must stay under **USL = 300 ms**. Samples: 500 request durations (Sentry/k6).
- μ = 180 ms, σ̂ = 45 ms → Cpk = (300−180)/(3×45) = **0.89** → **not capable** (target ≥ 1.33).
- Read: average is fine but variation is too wide; the tail breaches the budget. Confidence: Measured.

### Worked example D — output accuracy (domain spec)
- `mfg-calculator`: golden estimate = $234.26, allowed tolerance ±$0.50 → LSL=233.76, USL=234.76.
- Sample the estimator across N input combinations; compute μ, σ̂ of the output error.
- Cpk < 1.33 ⇒ pricing logic produces unacceptable variation → a CTQ defect source.
  (This is the rare case where Six Sigma's original numeric-tolerance math maps perfectly.)

## Counting rules (do this explicitly in Define)
- **Pick ONE unit and ONE opportunity definition** and keep them stable across the window.
- Defects must be **countable and observable**; if prod isn't instrumented, you cannot count
  escaped defects — say so and recommend instrumentation as the first Measure improvement.
- Prefer **Measured** continuous data (latency, accuracy) for capability; use **Indicative** rates
  for low-volume discrete data (deploys); never present Insufficient data as a precise sigma.
