# Six Sigma Business MBB — Report Template

Two files written to `REPORT_DIR` (default `./six-sigma-business/`):
`six-sigma-business-scorecard.md` (quick) and `six-sigma-business-dmaic-report.md` (full).

---

## Scorecard (`six-sigma-business-scorecard.md`)

```markdown
# Six Sigma Business Scorecard — {company}
{date} · Horizon: {Q | H | Y} · Bias: {balanced | growth | scalability} · Mode: {static | static+measure}

**Enterprise Process Sigma: {n.n}σ  ·  Confidence: {Measured | Indicative | Insufficient}**
_Weighted rollup across departments (weights below); excludes any dept marked Insufficient._

## Per-department headline

| Dept | Sigma | DPMO | n / window | Confidence | Weight | Unit · Defect · Opp |
|------|:-----:|-----:|------------|-----------|:------:|---------------------|
| Marketing | {n.n} | {n} | {n} / {Q1} | {label} | 20% | {triple} |
| Sales | {n.n} | {n} | {n} / {Q1} | {label} | 25% | {triple} |
| CS / Support | {n.n} | {n} | {n} / {Q1} | {label} | 20% | {triple} |
| Operations | {n.n} | {n} | {n} / {Q1} | {label} | 15% | {triple} |
| Finance | {n.n} | {n} | {n} / {Q1} | {label} | 10% | {triple} |
| People / HR | {n.n} | {n} | {n} / {Q1} | {label} | 10% | {triple} |

## DMAIC maturity (0–5 per dept × phase)

| Dept | D | M | A | I | C | Biggest gap |
|------|:-:|:-:|:-:|:-:|:-:|-------------|
| Marketing | {n} | {n} | {n} | {n} | {n} | {one line} |
| Sales | {n} | {n} | {n} | {n} | {n} | {one line} |
| … | | | | | | |

## Process capability (where computed)

| Dept | Metric | Spec | Cpk | Verdict |
|------|--------|------|:---:|---------|
| Marketing | Lead first-contact SLA | ≤ 5 min | {n.nn} | {capable / marginal / not capable} |
| CS | Ticket first response | ≤ 1 bh | {n.nn} | … |
| Finance | DSO | ≤ 45 d | {n.nn} | … |

## Top FMEA risks (enterprise)

| Dept | Failure mode | S | O | D | RPN | Mitigation → projected RPN | Owner |
|------|--------------|:-:|:-:|:-:|:---:|-----------------------------|-------|
| {dept} | {mode} | {n} | {n} | {n} | {RPN} | {action} → {new RPN} | {role} |

## Improvement backlog (prioritized)

### Growth levers (CAC / conversion / revenue)
1. {quick win — dept · impact $ · effort · owner}
2. …

### Scalability levers (throughput / automation / capacity)
1. {quick win — dept · impact $ · effort · owner}
2. …

Ingested from: {business-research, lead-generator, search-console-analyst, Ahrefs/GSC,
Linear cross-functional issues, …}
```

---

## Full report (`six-sigma-business-dmaic-report.md`)

```markdown
# Six Sigma Business DMAIC Report — {company}

## Executive summary
{3–5 sentences: enterprise sigma + confidence, the vital-few cross-departmental root cause, the
single highest-ROI improvement (with $ impact), and whether each major process is in control.}

## Per-department DMAIC

### Marketing

#### Define
- **Problem statement:** {quantified — e.g. "MQL→SQL conversion 38% vs 60% target; estimated
  $1.4M ARR foregone in Q1"}
- **Goal statement:** {SMART}
- **Scope:** {in / out — note what defers to specialist agents / `/six-sigma-mbb`}
- **SIPOC:** {table}
- **CTQ tree & defect definition:** {unit / defect / opportunity verbatim from `business-mapping.md`}

#### Measure
- **Data inventory:** {source · metric · n · window · confidence}
- **Baseline:** DPMO {n} → {n.n}σ ({confidence})
- **Capability:** {Cp/Cpk table or "no continuous spec measured"}
- **MSA:** {KPI definition consistency good/fair/poor + why}

#### Analyze
- **Pareto:** {table — vital few with $-impact}
- **Fishbone (6M):** {top categories — must land in Method/Machine/Material/Measurement/Manpower/Market}
- **5 Whys:** {chains to root cause}
- **Hypotheses:** {tested relationships or "insufficient data, n=X"}

#### Improve
- **FMEA:** {table with $-Severity calibration}
- **Lean waste:** {DOWNTIME table — waste · location · action · owner}
- **Poka-yoke:** {prevention per top defect category — tool/config change, not a doc}
- **Prioritized backlog:** {ordered list, growth-vs-scalability tagged, $ impact}

#### Control
- **Control plan:** {metric · target · live source · frequency · owner · reaction}
- **SPC plan:** {chart type · where hosted · limits · alert routing}
- **Quality gates:** {concrete CRM / marketing-automation / dashboard changes}

### Sales
{same structure}

### Customer Success / Support
{same structure}

### Operations
{same structure}

### Finance
{same structure}

### People / HR
{same structure}

## Cross-department patterns
- **Definition drift:** {e.g. Marketing's "MQL" ≠ Sales's "MQL"; reconciliation in the Improve
  backlog}
- **Hand-off defects:** {Marketing→Sales SLA miss · Sales→CS context loss · Sales→Ops capacity gap}
- **Shared root causes:** {e.g. CRM config in Method/Machine drives defects in 4 of 6 depts}

## Enterprise rollup
- **Weighted sigma:** {n.n}σ — weights: {Sales 25%, Marketing 20%, CS 20%, Ops 15%, Finance 10%,
  People 10%} (rationale: …)
- **Top 5 FMEA risks across departments:** {table}
- **Growth backlog (top 10) vs Scalability backlog (top 10):** {two ordered lists}

## Deferred (ingested, not re-derived)
- {SEO finding} → Ahrefs MCP / `search-console-analyst` agent
- {lead-gen finding} → `lead-generator` agent
- {market size / segment} → `business-research` agent
- {customer-facing UX finding} → `/ux-audit`
- {engineering / product delivery defect} → `/six-sigma-mbb`

## Sources
{cite references/sources.md entries used}
```

### Per-item rules
- Every statistic carries n, window, and a confidence label. **No bare sigma numbers.**
- Every improvement names the concrete tool/config change, a named owner role, and projected
  $-impact (or "qualitative" if not quantifiable).
- Specialist-agent findings are cited and ingested — never re-collected here.
- A bug that's also tracked in `/six-sigma-mbb` must be flagged as cross-skill, not double-counted.
- Redact PII as `[REDACTED]`; aggregate when small-n could re-identify individuals (deals, hires,
  named customers).
