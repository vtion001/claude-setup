# Six Sigma MBB — Scoring Rubric

Three scores, each answering a different question. Always attach a **confidence label**
(Measured / Indicative / Insufficient — see `references/software-mapping.md` §6).

## 1. Headline: Sigma level (from DPMO)

```
DPMO = (number of defects) / (units × opportunities-per-unit) × 1,000,000
```

DPMO → process sigma (long-term, includes the conventional 1.5σ shift):

| Sigma | DPMO (approx) | Yield | Read as |
|:-----:|--------------:|------:|---------|
| 6σ | 3.4 | 99.99966% | World-class |
| 5σ | 233 | 99.977% | Excellent |
| 4σ | 6,210 | 99.38% | Good / industry-typical |
| 3σ | 66,807 | 93.3% | Mediocre — most uncontrolled processes |
| 2σ | 308,537 | 69.1% | Poor |
| 1σ | 691,462 | 30.9% | Not capable |

Report the sigma level **with the n and window** and its confidence label. If `Insufficient`,
give DPMO/rate only and explicitly withhold a sigma figure.

## 2. Process capability Cp / Cpk (where a continuous metric + spec exists)

```
Cp  = (USL − LSL) / (6σ̂)                      # potential capability (centered)
Cpk = min( (USL − μ)/(3σ̂), (μ − LSL)/(3σ̂) )   # actual capability (accounts for off-center)
```

| Cpk | Verdict |
|-----|---------|
| ≥ 1.67 | Excellent |
| ≥ 1.33 | Capable (common target) |
| 1.00–1.33 | Marginal |
| < 1.00 | Not capable |

Software uses: latency vs SLA budget (one-sided USL); numeric-output accuracy vs tolerance band
(e.g. `mfg-calculator` estimate vs golden value ± tolerance). Needs n ≥ ~30 to be Measured.

## 3. DMAIC maturity (0–5 per phase)

Rates whether the process is *set up* to be improved & controlled — independent of current defect count.

| Score | Meaning |
|:-----:|---------|
| 5 | Fully practiced: clear CTQs, live metrics, root-cause discipline, error-proofing, SPC control |
| 4 | Strong, minor gaps |
| 3 | Partial: some measurement/tests/CI but inconsistent |
| 2 | Ad hoc |
| 1 | Largely absent |
| 0 | None / not possible (e.g. no monitoring at all → Control = 0) |

Report a small table: Define / Measure / Analyze / Improve / Control each 0–5, with the one gap
that most limits the score.

## 4. FMEA RPN scale

Each of Severity, Occurrence, Detection scored 1–10; **RPN = S × O × D** (1–1000).

| | 1–3 (low) | 4–6 (moderate) | 7–10 (high) |
|--|-----------|----------------|-------------|
| **Severity** | cosmetic / minor | degraded UX / partial outage | data loss / security breach / full outage |
| **Occurrence** | rare | occasional | frequent / on a hot path |
| **Detection** (10 = hard to detect) | caught by CI/tests | caught in staging/manual | only found in prod by users |

Act on highest RPN first; any **Severity ≥ 9** is escalated regardless of RPN. Re-score after
mitigation to show the projected RPN drop.

## RPN → Linear priority (with `--linear`)

| RPN (or Severity) | Linear priority |
|-------------------|-----------------|
| RPN ≥ 200, or Severity ≥ 9 | P1 (Urgent) |
| 120–199 | P2 (High) |
| 60–119 | P3 (Medium) |
| < 60 | P4 (Low) |
