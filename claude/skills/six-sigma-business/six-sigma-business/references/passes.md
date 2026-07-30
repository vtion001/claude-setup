# Six Sigma Business MBB — Pass Definitions

The ~17 tools, grouped by DMAIC phase. Each: **input → method → what-good-looks-like → artifact**.
Map to the `--pass` flag. Every pass is run **per department in scope** (unless explicitly noted
as enterprise). A pass that cannot be supported by available data is marked **N/A** with the reason
(and usually becomes a Measure-phase recommendation: "instrument this first").

---

## Define

### `charter`
- **Input:** user's goal, company context, department brief (from intake / interview / sibling-agent
  outputs).
- **Method:** write problem statement (what's wrong, where, how big in $/customers/days, since when
  — no cause/solution), goal statement (SMART, e.g. "cut Sales cycle from 64 → 45 days within 2
  quarters; lift Marketing-to-Sales SLA hit-rate from 62% → 90%"), scope, business case in dollar
  terms.
- **Good:** problem is quantified in dollars or customers; goal is measurable; scope excludes
  engineering defects (those defer to `/six-sigma-mbb`) and excludes specialist territory.
- **Artifact:** charter block per department in the report.

### `sipoc`
- **Input:** department value chain, hand-off map, CRM/ERP/HRIS flow.
- **Method:** map Suppliers→Inputs→Process→Outputs→Customers for each department's primary value
  chain (e.g. Marketing: paid+organic → lead → MQL → SQL handoff → opp; Sales: SQL → demo →
  proposal → close; CS: closed-won → onboarded → renewed/expanded; Ops: order → pick → ship →
  deliver). Identify where defects enter each step.
- **Good:** every step has named inputs/outputs and a quality check identified or flagged as
  missing.
- **Artifact:** SIPOC table per department; cross-departmental hand-off map (Marketing→Sales,
  Sales→CS, Sales→Ops) called out separately.

### `voc-ctq`
- **Input:** customer needs (from CS NPS/CSAT, sales-call notes, support tickets), Voice of Market
  from `business-research` agent if available, the app's website (`/ux-audit` if present).
- **Method:** translate VOC into a CTQ tree per department; **define defect / unit / opportunity**
  explicitly using `references/business-mapping.md` §1.
- **Good:** each CTQ has a measurable spec and a data source; defect/unit/opportunity are stated
  verbatim and carried unchanged into Measure.
- **Artifact:** CTQ tree per department + the operational defect definition table.

---

## Measure

### `data-sources`
- **Input:** repo/workspace, `--measure` MCPs, existing sibling-agent outputs, available
  CSVs/Sheets.
- **Method:** run `scripts/detect-business-context.sh`; under `--measure` run `scripts/kpi-pull.sh`
  to pull gog Sheets / Ahrefs / Linear / CRM-CSV summaries (see `scripts/data-sources.md`). Record
  n, time window, and source per metric.
- **Good:** at least one quantitative defect source per department with a stated window; gaps
  named explicitly (and a recommended instrumentation in the Improve backlog).
- **Artifact:** data inventory table (dept, source, metric, n, window, confidence).

### `baseline`
- **Input:** defect counts, units, opportunities from `data-sources`.
- **Method:** compute per-department DPMO and sigma level (`scripts/sigma-calc.md`); compute Cp/Cpk
  where a continuous metric + spec exists (lead SLA, DSO, ticket SLA, cycle time, fulfillment
  minutes). Compute the **enterprise rollup** (revenue-impact weighted) — see
  `business-mapping.md` §7.
- **Good:** every number carries a confidence label (Measured / Indicative / Insufficient) and
  states the weight if part of the rollup.
- **Artifact:** baseline table per dept + enterprise rollup row: metric, defects, opportunities,
  DPMO, sigma, confidence, weight.

### `msa`
- **Input:** KPI definitions across departments, dashboards, source-system labeling consistency
  (e.g. is "MQL" the same in Marketing's sheet and Sales's CRM?), reporting cadence.
- **Method:** assess measurement-system reliability qualitatively — definition consistency, label
  drift over time, dashboard accuracy spot-checks, reporting cadence vs decision cadence.
- **Good:** measurement reliability rated good/fair/poor per dept; poor caps baseline confidence
  and produces a top-priority Measure improvement.
- **Artifact:** MSA note per dept feeding the confidence labels; KPI-definition reconciliation
  list across departments.

---

## Analyze

### `pareto`
- **Input:** categorized defects (by sub-type / segment / channel / region / rep / SKU).
- **Method:** rank categories by count and by $-impact where possible; find the vital few per
  department; then a cross-department rollup of the top causes by $-impact.
- **Good:** ~20% of categories shown to drive ~80% of defects (or $-impact), or explicitly not
  Pareto-shaped (long-tail = different prescription).
- **Artifact:** Pareto table per dept (category, count, $-impact, cumulative %) + enterprise
  vital-few list.

### `fishbone`
- **Input:** top Pareto categories.
- **Method:** Ishikawa across the 6M mapped to business (`business-mapping.md` §2) for each top
  category. Every branch must land in one of: Method / Machine / Material / Measurement /
  Manpower / Market.
- **Good:** plausible root-cause branches, not just symptoms; ties to specific tool/SOP/role
  evidence. *"The rep messed up"* resolves to Method / Measurement / Manpower / Machine.
- **Artifact:** fishbone per top category.

### `5whys`
- **Input:** top fishbone branches.
- **Method:** iterative "why" (≈5×) to root cause; stop at an actionable systemic cause (process,
  tool config, comp plan, hiring profile, attribution model).
- **Good:** lands on a process/design/incentive cause, not on an individual person.
- **Artifact:** 5-Whys chains.

### `hypothesis`
- **Input:** paired data (e.g. SDR cadence vs reply rate; channel CAC vs LTV; ticket category vs
  churn; onboarding completion vs 90-day retention), n ≥ ~30.
- **Method:** correlation / simple test; state effect size and confidence; **skip with a note if n
  is too small** — do not invent significance.
- **Good:** claims are backed by stated stats or explicitly labeled qualitative.
- **Artifact:** hypothesis findings (or "insufficient data, n=X" note) per dept.

---

## Improve

### `fmea`
- **Input:** failure modes from Analyze + specialist-agent findings (business-research signals,
  Ahrefs ranking decay, lead-generator pipeline gaps).
- **Method:** score Severity (in $ / customers / brand — scales in `scoring-rubric.md`),
  Occurrence, Detection (1–10 each); **RPN = S×O×D**; rank; propose mitigation; show projected
  post-mitigation RPN.
- **Good:** highest-RPN items have concrete, behavior-preserving mitigations with a named owner.
- **Artifact:** FMEA table per dept + enterprise top-N FMEA.

### `lean-waste`
- **Input:** SIPOC + Pareto + sibling-agent outputs + activity logs.
- **Method:** identify the 8 wastes (DOWNTIME) mapped to business (`business-mapping.md` §3).
- **Good:** each waste tied to a specific tool/team/step and a removal action (not "do better" —
  "remove the duplicate handoff between SDR and AE by handing off in-CRM rather than via email").
- **Artifact:** waste table per dept (waste, location, action, owner).

### `poka-yoke`
- **Input:** top defect categories per dept.
- **Method:** propose error-proofing — CRM required-field rules, stage-gate exit criteria,
  approval thresholds, order-entry validation, hiring scorecard floors, finance close-checklist
  items — that make the defect impossible rather than merely caught after.
- **Good:** each top defect category has a *prevention* (not just a *fix*); enforced in the tool
  config, not in a doc.
- **Artifact:** poka-yoke list per dept (defect → prevention → tool/config change).

### `prioritize`
- **Input:** all improvement candidates (FMEA, waste, poka-yoke) across departments.
- **Method:** impact/effort or Pugh matrix; sequence into a backlog. Apply `--growth-focus` or
  `--scalability-focus` bias (see `business-mapping.md` §8). Tag each item with a department,
  growth-or-scalability tag, and projected $-impact.
- **Good:** ordered backlog with quick wins first; effort & impact stated; cross-dept
  dependencies called out (e.g. "Marketing fix requires CRM change owned by RevOps").
- **Artifact:** prioritized improvement backlog (the `--linear` source).

---

## Control

### `control-plan`
- **Input:** the prioritized improvements + key metrics per dept.
- **Method:** for each metric — target, measurement method, frequency, **named owner** (role, not
  team), and reaction plan when it drifts.
- **Good:** every gain has a way to detect regression and a named responder; the metric is read
  from a live source, not a manual sheet someone has to update.
- **Artifact:** control-plan table per dept.

### `spc`
- **Input:** time-series metrics (lead SLA, deal cycle time, MRR churn, ticket resolution time,
  DSO, time-to-hire, fulfillment SLA).
- **Method:** pick the chart type (X̄-R for continuous, p-chart for proportion defective) and
  where to host it (Sheet URL, CRM dashboard, Looker board); define control limits and alert
  thresholds vs random variation; route alerts to a named owner.
- **Good:** signals are actionable (special-cause), not noise alarms; routes are subscribed.
- **Artifact:** SPC monitoring plan per dept.

### `quality-gates`
- **Input:** operating cadence, CRM/ERP/HRIS config, dashboard inventory.
- **Method:** define operational gates that block regressions — CRM stage-gate criteria, outbound-
  campaign QA checklist, finance close-checklist, hiring scorecard floor, ops capacity alarm,
  Marketing budget guardrail tied to CAC payback. These are *enforced in tools*, not in a wiki.
- **Good:** gates map directly to the top defect categories; concrete and enforceable today.
- **Artifact:** quality-gate spec per dept (tool changes to make, owner, ETA).
