# Six Sigma Business MBB — Scoring Rubric

Three scores, each answering a different question. Always attach a **confidence label**
(Measured / Indicative / Insufficient — see `references/business-mapping.md` §6).

## 1. Headline: Sigma level (from DPMO) — per department + enterprise rollup

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

Report the per-department sigma level **with the n and window** and its confidence label. If
`Insufficient`, give DPMO/rate only and explicitly withhold a sigma figure.

**Enterprise rollup** = weighted average of per-department sigmas, weights per
`business-mapping.md` §7. State weights inline. Do not roll up a department whose label is
`Insufficient`.

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

Business uses: lead SLA seconds vs spec (USL = 5 min); DSO days vs target (USL = 45 days); ticket
first response vs SLA; fulfillment minutes; deal cycle days. Needs n ≥ ~30 to be Measured.

## 3. DMAIC maturity (0–5 per phase per department)

Rates whether the department's process is *set up* to be improved & controlled — independent of
current defect count.

| Score | Meaning |
|:-----:|---------|
| 5 | Fully practiced: clear CTQs, live metrics with named owners, root-cause discipline, error-proofing in tools, SPC alerts routed |
| 4 | Strong, minor gaps |
| 3 | Partial: some KPIs/SOPs but inconsistent across reps/regions |
| 2 | Ad hoc — KPIs exist on paper, no live tracking |
| 1 | Largely absent — no shared definitions |
| 0 | None / not possible (e.g. no CRM at all → Measure = 0) |

Report a small table: Define / Measure / Analyze / Improve / Control each 0–5 *per department*,
with the one gap that most limits the score. Cross-dept patterns (e.g. every dept scores Measure≤2
because no shared KPI definitions) become a top-priority enterprise improvement.

## 4. FMEA RPN scale (business-impact severity)

Each of Severity, Occurrence, Detection scored 1–10; **RPN = S × O × D** (1–1000).

| | 1–3 (low) | 4–6 (moderate) | 7–10 (high) |
|--|-----------|----------------|-------------|
| **Severity** (in $ / customers / brand) | annoyance / internal-only / single rep affected; <$1k impact | one customer affected; <$50k impact; degraded NPS for a segment | revenue loss > $50k; multiple customer churn; regulatory exposure; named-account loss; brand incident |
| **Occurrence** | rare (<1% of units in window) | occasional (1–10%) | frequent / on a hot path (>10% or every cycle) |
| **Detection** (10 = hard to detect) | caught at the source (CRM validation, finance close checklist) | caught in QBR / monthly close | only found after customer escalation or external audit |

Act on highest RPN first; any **Severity ≥ 9** (named-account loss, regulatory exposure, brand
incident) is escalated regardless of RPN. Re-score after mitigation to show the projected RPN drop.

### Severity examples by dept (calibration)

| Dept | S=3 | S=6 | S=9 |
|------|------|------|------|
| Marketing | misattributed channel | wrong ICP campaign waste $25k | brand-safety incident; named PR |
| Sales | one stuck deal | named enterprise deal slipped a quarter | named-account loss to competitor |
| CS | minor NPS dip | one mid-market churn | top-10 customer churn |
| Ops | one delayed order | regional SLA miss for a week | recall / safety incident |
| Finance | a manual reissue | DSO breach across cohort | audit finding / restatement |
| People | candidate ghosted | senior IC regretted attrition | VP-level regretted attrition |

## RPN → Linear priority (with `--linear`)

| RPN (or Severity) | Linear priority |
|-------------------|-----------------|
| RPN ≥ 200, or Severity ≥ 9 | P1 (Urgent) |
| 120–199 | P2 (High) |
| 60–119 | P3 (Medium) |
| < 60 | P4 (Low) |

Linear issues use label `["Business / Six Sigma"]` and a sub-label `["Dept: <name>"]`.
