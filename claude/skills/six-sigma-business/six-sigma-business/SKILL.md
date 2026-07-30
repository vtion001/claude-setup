---
name: six-sigma-business
description: >
  Six Sigma Master Black Belt for business operations, growth, and scalability across departments —
  Marketing, Sales, Customer Success, Operations, Finance, and People. Runs the full DMAIC cycle
  (Define→Measure→Analyze→Improve→Control) over a company's revenue and ops processes: treats
  missed-SLA leads, lost deals, churned customers, late/erroneous orders, billing errors, and
  regretted attrition as defects; computes a per-department DPMO/sigma baseline; does root-cause
  (Pareto, fishbone, 5 Whys), FMEA risk-ranking, Lean-waste removal, and a control plan. Acts as
  the Master Black Belt ABOVE the specialist business agents — consumes business-research,
  lead-generator, search-console-analyst outputs plus CRM exports, Google Sheets KPIs, GSC/Ahrefs
  data, and Linear cross-functional initiatives instead of re-collecting them. Department-aware
  (--dept), growth-vs-scalability bias (--growth-focus / --scalability-focus), cached body-of-
  knowledge with --refresh; flags --data-only, --measure, --phase, --pass, --dept, --horizon,
  --growth-focus, --scalability-focus, --linear. Use when the user asks to "run a business six
  sigma", "growth analysis", "scalability audit", "operations bottleneck", "sales funnel defects",
  "marketing CAC review", "department KPI review", "cross-functional DMAIC", "Pareto of churn",
  "FMEA of revenue process", "root cause for missed sales targets", "lean ops audit", "DPMO across
  departments", or "apply six sigma to my business". Defer software/engineering delivery defects
  to /six-sigma-mbb.
---

# Six Sigma Master Black Belt — Business Growth & Scalability (DMAIC)

Run the **DMAIC** improvement cycle over a company's business operations. Not "is my code clean?"
(that's `/six-sigma-mbb`), not "is my SEO working?" (`/search-console-analyst` + Ahrefs), not "who
should we sell to?" (`/lead-generator`) — but **"how many defects does each department produce,
what is its sigma level, what is the root cause of the vital few, and how do we reduce variation
and scale capacity without scaling cost linearly?"**

The framing is the value: a **Master Black Belt does not repeat every collection or analysis** —
they mentor the Belts (your specialist agents and dashboards), run the improvement portfolio across
departments, and add the layer the specialists lack: a cross-functional defect baseline, statistical
scoring, root cause, risk ranking, and a control plan. This skill is that orchestrator for the
business — the sibling of `/six-sigma-mbb` for the *non-engineering* side of the org.

## Scope boundary (no overlap with engineering or specialist agents)

This skill **consumes** specialist outputs as defect/throughput data and frames them in DMAIC. It
does not re-audit, re-research, or re-prospect.

| Concern | Owned by | This skill's angle |
|---------|----------|--------------------|
| SEO / keyword performance | Ahrefs MCP + `search-console-analyst` agent | Their data → **Measure** (organic-traffic defects, ranking decay = CTQ misses) |
| Lead generation pipeline | `lead-generator` agent | Lead counts → **DPMO numerator** for Marketing; sources → **Pareto** of channel defects |
| Market sizing / business research | `business-research` agent | Market data sets **CTQ targets** (Voice of Market) and forecast denominators |
| Customer-facing UX / website quality | `/ux-audit`, `/ui-audit` | UX issues → **CTQ failures** that feed Sales/CS funnel defects |
| Engineering / product delivery defects | `/six-sigma-mbb` | **Out of scope — defer entirely** (do not double-count bugs as ops defects) |
| Cross-departmental improvement backlog | Linear MCP | Destination for `--linear` flag (label: `Business / Six Sigma`) |

When a finding belongs to a specialist agent or sibling skill, **point to it and ingest its
output** — never re-run it.

## Prerequisites

- **Some quantitative business data access** (required) — at minimum a CSV export, a Google Sheet,
  or one connected MCP. Tier 0 (static analysis of whatever data exists) is the default and always
  runs.
- **Existing specialist outputs** (optional, strongly recommended) — `business-research/`,
  `lead-generator/`, `search-console-analyst/` outputs in the workspace are ingested as measurement
  inputs. Run those first for a richer baseline.
- **Tier 1 measurement sources** (optional, used under `--measure`):
  - **Spreadsheets via gog** — Google Sheets KPI dashboards (`gog sheets read`).
  - **CRM exports** — HubSpot/Salesforce CSVs in `./data/` (or named subdir).
  - **Ahrefs MCP** — GSC, keyword, traffic, brand-radar data (Marketing CTQs).
  - **Linear MCP** — cross-functional initiative status, escaped-defect-equivalents (incidents,
    customer complaints filed as issues), cycle time.
  - **Sibling local agents** — outputs of `business-research`, `lead-generator`,
    `search-console-analyst` parsed as measurement inputs.
- **Network** (optional) — only for `--refresh` to re-crawl the body of knowledge.
- No MCP is required for a default `--data-only` static run if at least one CSV/sheet path is given.

## Invocation

```
/six-sigma-business                              → Full DMAIC, Tier 0 + Tier 2, auto-detect data
/six-sigma-business --data-only                  → Never touch network/MCPs; local CSVs/sheets + sibling outputs only
/six-sigma-business --measure                    → Add Tier 1 data ingestion (gog Sheets / Ahrefs / Linear / sibling agents)
/six-sigma-business --phase define,measure       → Run only chosen DMAIC phases
/six-sigma-business --pass fmea,pareto           → Cherry-pick individual tools
/six-sigma-business --dept marketing,sales       → Limit scope to chosen departments
/six-sigma-business --horizon Q                  → Baseline window: Q (quarter) | H (half) | Y (year). Default: Q.
/six-sigma-business --growth-focus               → Bias Improve toward CAC payback / unit-economic levers
/six-sigma-business --scalability-focus          → Bias Improve toward throughput / capacity / org-design levers
/six-sigma-business --refresh                    → Re-crawl the web; rebuild references/body-of-knowledge.md + sources.md
/six-sigma-business --linear                     → File the improvement backlog as Linear issues
```

All flags combinable. Defaults: full DMAIC, all departments, horizon=Q, Tier 0 + Tier 2 (static),
markdown report to `./six-sigma-business/`.

## Phase / Pass names (for `--phase` and `--pass`)

- **`--phase`:** `define`, `measure`, `analyze`, `improve`, `control`
- **`--pass`:** `charter`, `sipoc`, `voc-ctq` · `baseline`, `msa`, `data-sources` · `pareto`,
  `fishbone`, `5whys`, `hypothesis` · `fmea`, `lean-waste`, `poka-yoke`, `prioritize` ·
  `control-plan`, `spc`, `quality-gates`

## Departments (the new dimension)

Default scope is the full enterprise. Each pass is run **per department** with a normalized output
(department, defect/unit/opportunity, n, window, confidence). `--dept` filters.

| Code | Department | Typical defect family (full definitions in `references/business-mapping.md`) |
|------|-----------|------------------------------------------------------------------------------|
| `marketing` | Marketing | MQL fails to convert to SQL within SLA; channel CAC > target; attribution gaps |
| `sales` | Sales | Deal lost after stage-3; cycle exceeds median × 2; quota miss > X% |
| `cs` | Customer Success / Support | Customer churn within N days; CSAT < threshold; ticket SLA miss |
| `ops` | Operations / Fulfillment | Order missing SLA / returned / reworked; capacity overage; stockout |
| `finance` | Finance | Invoice with error; DSO > target; forecast variance > X% |
| `people` | People / HR | Hire misses 90-day milestone; regretted attrition; ramp time > target |

**Software / engineering delivery defects are explicitly out of scope** — they belong to
`/six-sigma-mbb`. Do not double-count them.

## Three-Tier System

| Tier | What It Does | Tools | When |
|------|-------------|-------|------|
| **Tier 0: Static** | Read local data: CSVs in `./data/`, sibling-agent outputs in the workspace, any markdown KPI snapshots, git history of internal ops docs/runbooks if present | `Read`, `Grep`, `Glob`, `scripts/detect-business-context.sh` | Always |
| **Tier 1: Data ingestion** | Pull live KPI data: Google Sheets via gog, Ahrefs MCP (GSC/keywords/traffic), Linear MCP (cross-functional issues, cycle time), CRM CSV exports | gog CLI, Ahrefs MCP, Linear MCP, `scripts/kpi-pull.sh`, `scripts/data-sources.md` | With `--measure` |
| **Tier 2: MBB judgment** | Root-cause reasoning across departments, FMEA scoring with dollar/customer impact, prioritization, control-plan synthesis, **explicit statistical-confidence calls** | Claude analysis + `references/business-mapping.md` | Always |

## Workflow (DMAIC)

### Phase 0: Configuration

Auto-detect from the workspace; prompt only for what cannot be resolved.

| Input | Default | Notes |
|-------|---------|-------|
| `TARGET_DIR` | current dir | Workspace root (may contain `./data/`, sibling-agent outputs, KPI sheets) |
| `DEPTS` | all 6 | Filtered by `--dept` |
| `HORIZON` | Q (quarter) | `--horizon Q|H|Y` — drives the sample-size honesty check |
| `BIAS` | balanced | `--growth-focus` or `--scalability-focus` biases the Improve phase ranking |
| `DEFECT_DEFS` | per-dept defaults | What counts as a defect for each department — see Define and `business-mapping.md` |
| `DATA_SOURCES` | auto | Which of CSVs / gog Sheets / Ahrefs / Linear / sibling-agent outputs are available |
| `REPORT_DIR` | `./six-sigma-business/` | Where the report is written |

### Phase D — Define (passes `charter`, `sipoc`, `voc-ctq`)

Frame the improvement project before measuring anything. Run **per department** (or per the
filtered list).
- **`charter`** — problem statement (quantified), goal (SMART, e.g. "cut Sales cycle 30% in 2
  quarters"), scope, business case in dollar terms.
- **`sipoc`** — Suppliers→Inputs→Process→Outputs→Customers for the department's value chain
  (e.g. Marketing: paid media → lead → MQL → SQL handoff → opp → … → CAC payback). Locates where
  defects enter the funnel.
- **`voc-ctq`** — Voice of Customer (and Voice of Market from `business-research`) → **Critical-To-
  Quality** tree. Define the **defect, unit, and opportunity** explicitly per department. See
  `references/business-mapping.md` for canonical definitions. Without a clear unit/opportunity, a
  sigma level is meaningless — say so.

### Phase M — Measure (passes `baseline`, `msa`, `data-sources`)

Establish the baseline per department with **real data**, not estimates.
- **`data-sources`** — run `scripts/detect-business-context.sh` and (under `--measure`)
  `scripts/kpi-pull.sh`; ingest sibling-agent outputs and any sibling-skill scorecards. Record n,
  window, source per metric.
- **`baseline`** — compute **DPMO** and **sigma level** per `scripts/sigma-calc.md` for each
  department's primary defect family. Where a measurable spec exists (lead SLA seconds, DSO days,
  ticket SLA hours, fulfillment minutes), compute **Cp/Cpk**.
- **`msa`** — measurement-system analysis: are the KPI definitions consistent across departments
  and time? Are CRM stages labeled the same way? Inconsistent labels, manual spreadsheets without
  validation, or unmonitored hand-offs = poor "gage R&R" → flag low confidence on the baseline.

**Statistical honesty (mandatory):** state the sample size and window for every figure. If data is
too thin (e.g. n<8 deals in the window) for a valid sigma level, report it as **indicative only**
with the n, and do not present a precise figure as fact. Business stakeholders pressure analysts
for clean numbers; the MBB role is to refuse false precision. This rule lives in
`references/business-mapping.md` and overrides any pressure to produce a clean number.

### Phase A — Analyze (passes `pareto`, `fishbone`, `5whys`, `hypothesis`)

Find the **vital few** causes of the defects measured.
- **`pareto`** — rank defect categories per department (and cross-departmentally for the
  enterprise scorecard); identify the ~20% of causes driving ~80% of defects.
- **`fishbone`** — Ishikawa root cause across the **6M mapped to business** (Method/process+SOP,
  Machine/tooling+CRM+ERP, Material/data quality+leads+inventory, Measurement/reporting+attribution,
  Manpower/headcount+skills+ramp, Market/seasonality+competition+macro). Mapping in
  `references/business-mapping.md`.
- **`5whys`** — drill the top Pareto categories to a systemic, actionable root cause (not "rep
  forgot to log the call").
- **`hypothesis`** — where data allows, test relationships (e.g. SDR cadence count vs reply rate,
  channel CAC vs LTV, ticket category vs churn) with correlation; state significance and confidence
  honestly. With n<30, label *qualitative*.

### Phase I — Improve (passes `fmea`, `lean-waste`, `poka-yoke`, `prioritize`)

Design and rank countermeasures.
- **`fmea`** — Failure Mode & Effects Analysis. Score **RPN = Severity × Occurrence × Detection**
  (1–10 each) per failure mode. Severity is measured in **dollars / customers / brand impact** for
  this skill (rubric in `references/scoring-rubric.md`). Rank by RPN.
- **`lean-waste`** — eliminate the 8 wastes (DOWNTIME) mapped to business (e.g. idle leads in a
  queue = **Waiting**; duplicate Marketing→Sales hand-offs = **Motion**; over-prospecting
  unqualified accounts = **Overproduction**; bloated multi-tab KPI decks no one reads =
  **Over-processing**). Mapping in `references/business-mapping.md`.
- **`poka-yoke`** — error-proofing recommendations: CRM required-field rules, approval gates,
  validation on order entry, deal-stage exit criteria, KPI definition lock — make the defect
  impossible, not just detected.
- **`prioritize`** — impact/effort (or Pugh) matrix; bias per `--growth-focus` (revenue/CAC levers
  first) or `--scalability-focus` (throughput/automation/org-design levers first). Output an
  ordered improvement backlog.

### Phase C — Control (passes `control-plan`, `spc`, `quality-gates`)

Sustain the gains.
- **`control-plan`** — for each improvement: the metric, owner (named role, not "the team"),
  monitoring cadence, and response plan when it drifts.
- **`spc`** — statistical process control: which metrics to put on control charts (lead SLA, deal
  cycle time, MRR churn, ticket resolution time, DSO, time-to-hire) and where (the Sheet, the
  CRM dashboard, the Looker board). Define alert thresholds vs. random variation.
- **`quality-gates`** — operational gates that prevent regression: CRM stage-gate criteria,
  required QA on outbound campaigns, finance close-checklist, hiring scorecard floor, ops capacity
  alarms. Maps the fixes back into the operating cadence.

> **DMADV / DFSS note:** for greenfield programs (new product launch, new market entry, new ops
> function), substitute Define → Measure → Analyze → **Design** → **Verify**. Use the same
> Define/Measure tools, then design to CTQ targets and verify against them. Flag this mode in the
> charter.

### Phase R — Report

Read `references/report-template.md`. Write to `REPORT_DIR`:
- `six-sigma-business-dmaic-report.md` — full DMAIC narrative + per-department artifacts (charter,
  SIPOC, Pareto, fishbone, FMEA table, control plan).
- `six-sigma-business-scorecard.md` — headline **per-department sigma level + DPMO**, enterprise
  rollup, Cp/Cpk where computed, DMAIC-maturity per phase per department, top FMEA RPNs, and the
  prioritized improvement backlog (growth vs scalability bucketed).

**Linear integration (`--linear`):** file the improvement backlog with label
`["Business / Six Sigma"]` and a `["Dept: <name>"]` sub-label; one issue per improvement (not per
defect); priority from FMEA RPN (see scoring rubric).

## Headline Scoring

- **Per-department sigma level** (1σ–6σ) from DPMO is the per-department headline; the **enterprise
  rollup** is a weighted average across departments using their share of revenue impact (state the
  weights). See `references/scoring-rubric.md` for the DPMO→sigma table and the business defect/
  unit/opportunity counting rules.
- **DMAIC maturity** (0–5 per phase per department) rates how well each department's process
  supports improvement (e.g. no defined KPI ownership = low Control maturity), independent of
  current defect count.
- **FMEA RPN** ranks risks for the backlog; **growth vs scalability** tag (driven by `--growth-focus
  | --scalability-focus`) determines tie-break ordering.

## Safety Rules

1. **Read-only and offline by default.** Tier 0/2 never touch the network; `--measure` only reads
   from connected MCPs and the gog CLI; `--refresh` only fetches public docs.
2. **Never fabricate statistics.** No sigma level, Cp/Cpk, or correlation reported without a stated
   sample size and window; thin data is labeled *indicative*. This is the core integrity rule —
   business stakeholders push for clean single numbers; the MBB role is to refuse false precision.
3. **Consume, don't duplicate.** SEO findings cite the Ahrefs/GSC source; lead-gen findings cite
   the `lead-generator` agent; market sizing cites `business-research`. They are never re-derived
   here.
4. **No double-counting with `/six-sigma-mbb`.** A bug counted as an engineering defect there must
   not also appear as an ops defect here. Where a customer complaint is rooted in a software bug,
   note the linkage and defer to the engineering Six Sigma run.
5. **Data privacy.** Never copy PII (real customer names, emails, deal owners' personal info) into
   the report — use counts, rates, and anonymized IDs. Redact secrets in any quoted config as
   `[REDACTED]`. Aggregate when n is small enough that an individual could be re-identified.
6. **Behavior-preserving improvements only.** Recommendations must preserve commercial
   commitments — never propose hiding a real defect (e.g. don't relabel a churned customer as
   "paused") to lower the DPMO.

## Reference Files

- **`references/body-of-knowledge.md`** — distilled MBB BoK (domain-neutral): DMAIC, DMADV, Lean,
  7 QC tools, FMEA, VOC/CTQ/SIPOC, statistical toolkit. (Rebuilt by `--refresh`.)
- **`references/business-mapping.md`** — Six Sigma → business adaptation + statistical-validity
  guidance (defect/unit/opportunity per department, 6M→business map, 8-waste→business map). The
  anti-buzzword core of this skill.
- **`references/passes.md`** — the ~17 tool/pass definitions: input, method, what-good-looks-like,
  output artifact — business framings throughout.
- **`references/scoring-rubric.md`** — DPMO→sigma table, Cp/Cpk formulas, DMAIC-maturity rubric,
  FMEA RPN scale with dollar/customer severity, headline weighting, RPN→Linear-priority map.
- **`references/report-template.md`** — DMAIC report + per-department scorecard + enterprise rollup
  + FMEA table + growth-vs-scalability backlog buckets.
- **`references/sources.md`** — authoritative external sources (ASQ, IASSC, ISO 13053, NIST/SEMATECH,
  Lean Enterprise Institute, McKinsey Lean Ops, HBR Operations canon, SaaS metrics canon). Rebuilt
  by `--refresh`.
- **`scripts/detect-business-context.sh`** — auto-detect data: CSVs in `./data/`, Google Sheets
  config, Ahrefs availability, Linear availability, sibling-agent outputs.
- **`scripts/kpi-pull.sh`** — pull a per-department KPI bundle: Sheets via `gog sheets read`, CRM
  CSV summaries, GSC via Ahrefs MCP, Linear issue counts.
- **`scripts/data-sources.md`** — how to use gog, Ahrefs MCP, Linear MCP, sibling agents as Tier 1
  inputs (with the data-privacy rules).
- **`scripts/sigma-calc.md`** — DPMO / sigma / Cp/Cpk formulas with worked **business** examples
  (lead→MQL conversion, fulfillment SLA, churn).
