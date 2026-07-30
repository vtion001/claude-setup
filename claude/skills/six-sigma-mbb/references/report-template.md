# Six Sigma MBB — Report Template

Two files written to `REPORT_DIR` (default `./six-sigma/`):
`six-sigma-scorecard.md` (quick) and `six-sigma-dmaic-report.md` (full).

---

## Scorecard (`six-sigma-scorecard.md`)

```markdown
# Six Sigma Scorecard — {project}
{date} · Stack: {stack} · Mode: {static | static+measure}

**Process Sigma: {n.n}σ  ·  DPMO: {n}  ·  Confidence: {Measured | Indicative | Insufficient (n={n}, window={range})}**

Defect definition: unit = {unit} · defect = {defect} · opportunities/unit = {k}

## DMAIC maturity
| Phase | 0–5 | Biggest gap |
|-------|:---:|-------------|
| Define | {n} | {one line} |
| Measure | {n} | {one line} |
| Analyze | {n} | {one line} |
| Improve | {n} | {one line} |
| Control | {n} | {one line} |

## Process capability (if computed)
| Metric | Spec | Cpk | Verdict |
|--------|------|:---:|---------|
| {e.g. API p95} | {< 300 ms} | {n.nn} | {capable / marginal / not capable} |

## Top FMEA risks
| Failure mode | S | O | D | RPN | Mitigation → projected RPN |
|--------------|:-:|:-:|:-:|:---:|-----------------------------|
| {mode} | {n} | {n} | {n} | {RPN} | {action} → {new RPN} |

## Improvement backlog (prioritized)
1. {quick win — impact/effort}
2. …

Ingested from: {backend-audit 2.7/5, code-audit, Sentry error rate, …}
```

---

## Full report (`six-sigma-dmaic-report.md`)

```markdown
# Six Sigma DMAIC Report — {project}

## Executive summary
{3–5 sentences: current sigma level + confidence, the vital-few root cause, the single highest-ROI
improvement, and whether the process is in control.}

## Define
- **Problem statement:** {quantified, no cause/solution}
- **Goal statement:** {SMART}
- **Scope:** {in / out — note what defers to specialist audits}
- **SIPOC:** {table}
- **CTQ tree & defect definition:** {unit / defect / opportunity}

## Measure
- **Data inventory:** {source · metric · n · window · confidence}
- **Baseline:** DPMO {n} → {n.n}σ ({confidence})
- **Capability:** {Cp/Cpk table or "no continuous spec measured"}
- **MSA:** {measurement reliability good/fair/poor + why}

## Analyze
- **Pareto:** {table — vital few}
- **Fishbone (6M):** {top categories}
- **5 Whys:** {chains to root cause}
- **Hypotheses:** {tested relationships or "insufficient data"}

## Improve
- **FMEA:** {table}
- **Lean waste:** {DOWNTIME table — waste · location · action}
- **Poka-yoke:** {prevention per top defect category}
- **Prioritized backlog:** {ordered list, impact/effort}

## Control
- **Control plan:** {metric · target · method · frequency · owner · reaction}
- **SPC plan:** {chart type · where hosted · limits}
- **Quality gates:** {concrete CI/CD changes}

## Deferred to specialist audits (ingested, not re-derived)
- {finding} → `/backend-audit` (score {n}/5)
- {finding} → `/security-audit` / `/code-audit` / `/ux-audit`

## Sources
{cite references/sources.md entries used}
```

### Per-item rules
- Every statistic carries n, window, and a confidence label. No bare sigma numbers.
- Every improvement names the concrete technique and is behavior-preserving (never "optimize this").
- Specialist-audit findings are cited and ingested — never re-audited here.
- Redact secrets as `[REDACTED]`; never copy real user PII from Sentry/PostHog into the report.
