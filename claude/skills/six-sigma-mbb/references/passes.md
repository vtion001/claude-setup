# Six Sigma MBB — Pass Definitions

The ~17 tools, grouped by DMAIC phase. Each: **input → method → what-good-looks-like → artifact**.
Map to the `--pass` flag. A pass that cannot be supported by available data is marked **N/A** with
the reason (and usually becomes a Measure-phase recommendation: "instrument this first").

---

## Define

### `charter`
- **Input:** user's goal, app purpose (from README / Define interview).
- **Method:** write problem statement (what's wrong, where, how big, since when — no cause/solution),
  goal statement (SMART, e.g. "cut escaped defects 50% in 2 sprints"), scope, business case.
- **Good:** problem is quantified and bounded; goal is measurable; scope excludes the specialist
  audits' territory.
- **Artifact:** charter block in the report.

### `sipoc`
- **Input:** repo structure, CI config, branch/deploy flow, git history.
- **Method:** map Suppliers→Inputs→Process→Outputs→Customers for the dev/value pipeline
  (e.g. dev → commit → review → CI → deploy → end user). Identify where defects can enter each step.
- **Good:** every process step has named inputs/outputs and a quality check identified or missing.
- **Artifact:** SIPOC table.

### `voc-ctq`
- **Input:** user/stakeholder needs, `ux-audit` output if present, app domain.
- **Method:** translate Voice of Customer into a CTQ tree; **define defect / unit / opportunity**
  explicitly (see `references/software-mapping.md`).
- **Good:** each CTQ has a measurable spec and a data source; defect/unit/opportunity are stated.
- **Artifact:** CTQ tree + the operational defect definition (carried into Measure).

---

## Measure

### `data-sources`
- **Input:** repo, `--measure` MCPs, existing audit reports.
- **Method:** run `scripts/defect-metrics.sh`; under `--measure` pull Sentry/PostHog/Linear and read
  sibling scorecards (`scripts/data-sources.md`). Record n and time window for each source.
- **Good:** at least one quantitative defect source with a stated window; gaps named explicitly.
- **Artifact:** data inventory table (source, metric, n, window, confidence).

### `baseline`
- **Input:** defect counts, units, opportunities from `data-sources`.
- **Method:** compute DPMO and sigma level (`scripts/sigma-calc.md`); compute Cp/Cpk where a
  continuous metric + spec exists (latency vs SLA; estimate vs tolerance).
- **Good:** every number carries a confidence label (Measured / Indicative / Insufficient).
- **Artifact:** baseline table: metric, defects, opportunities, DPMO, sigma, confidence.

### `msa`
- **Input:** test suite, CI logs, monitoring coverage, bug-label consistency.
- **Method:** assess measurement-system reliability — test flakiness, label consistency, prod
  monitoring coverage (software gage R&R, qualitative).
- **Good:** measurement reliability rated good/fair/poor; poor caps baseline confidence.
- **Artifact:** MSA note feeding the confidence labels.

---

## Analyze

### `pareto`
- **Input:** categorized defects (by type/module/source).
- **Method:** rank categories by count (and by cost/severity if available); find the vital few.
- **Good:** ~20% of categories shown to drive ~80% of defects, or explicitly not Pareto-shaped.
- **Artifact:** Pareto table (category, count, cumulative %).

### `fishbone`
- **Input:** top Pareto categories.
- **Method:** Ishikawa across the 6M mapped to software (`software-mapping.md` §2) for each top
  category.
- **Good:** plausible root-cause branches, not just symptoms; ties to file/process evidence.
- **Artifact:** fishbone per top category.

### `5whys`
- **Input:** top fishbone branches.
- **Method:** iterative "why" (≈5×) to root cause; stop at an actionable systemic cause.
- **Good:** lands on a process/design cause, not "developer made a mistake."
- **Artifact:** 5-Whys chains.

### `hypothesis`
- **Input:** paired data (e.g. PR size & defects, churn & bugs), n ≥ ~30.
- **Method:** correlation / simple test; state effect size and confidence; **skip with a note if n is
  too small** — do not invent significance.
- **Good:** claims are backed by stated stats or explicitly labeled qualitative.
- **Artifact:** hypothesis findings (or "insufficient data" note).

---

## Improve

### `fmea`
- **Input:** failure modes from Analyze + specialist-audit findings.
- **Method:** score Severity, Occurrence, Detection (1–10 each, scales in `scoring-rubric.md`);
  **RPN = S×O×D**; rank; propose mitigation; show projected post-mitigation RPN.
- **Good:** highest-RPN items have concrete, behavior-preserving mitigations.
- **Artifact:** FMEA table.

### `lean-waste`
- **Input:** SIPOC + backend-audit findings + pipeline.
- **Method:** identify the 8 wastes (DOWNTIME) mapped to software (`software-mapping.md` §3).
- **Good:** each waste tied to a specific location and a removal action.
- **Artifact:** waste table (waste, location, action).

### `poka-yoke`
- **Input:** top defect categories.
- **Method:** propose error-proofing — types, schema/Zod validation, lint rules, CI gates,
  invariants/asserts — that make the defect impossible rather than merely caught.
- **Good:** each top defect category has a prevention (not just a fix).
- **Artifact:** poka-yoke list.

### `prioritize`
- **Input:** all improvement candidates (FMEA, waste, poka-yoke).
- **Method:** impact/effort or Pugh matrix; sequence into a backlog.
- **Good:** ordered backlog with quick wins first; effort & impact stated.
- **Artifact:** prioritized improvement backlog (the `--linear` source).

---

## Control

### `control-plan`
- **Input:** the prioritized improvements + key metrics.
- **Method:** for each metric — target, measurement method, frequency, owner, reaction plan.
- **Good:** every gain has a way to detect regression and a named response.
- **Artifact:** control-plan table.

### `spc`
- **Input:** time-series metrics (defect rate, p95 latency, deploy freq, escaped defects).
- **Method:** pick the chart type and where to host it (Sentry/PostHog dashboards); define control
  limits / alert thresholds.
- **Good:** signals are actionable (special-cause), not noise alarms.
- **Artifact:** SPC monitoring plan.

### `quality-gates`
- **Input:** CI/CD config, test suite, audit thresholds.
- **Method:** define gates that block regressions — coverage floor, lint, type-check, audit-score
  threshold, golden-path test must pass.
- **Good:** gates map directly to the top defect categories; concrete and enforceable in CI.
- **Artifact:** quality-gate spec (CI changes to make).
