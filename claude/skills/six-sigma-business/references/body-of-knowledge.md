# Six Sigma Master Black Belt — Body of Knowledge (distilled)

Cached baseline of the MBB toolkit, framed for **business operations** (Marketing, Sales, CS, Ops,
Finance, People). The methodology is domain-neutral; this file pulls examples from business
processes rather than manufacturing or software. Rebuilt by `--refresh` from the authorities in
`sources.md` (ASQ MBB BoK, IASSC, ISO 13053-1/-2, NIST/SEMATECH e-Handbook, Lean Enterprise
Institute, SaaS metrics canon).

## Core idea

Six Sigma reduces **defects** and **variation** in a process so output reliably meets customer
requirements. "Six Sigma" capability = 3.4 defects per million opportunities (DPMO) — a process so
capable that ±6 standard deviations fit within the spec limits (with the classic 1.5σ long-term
shift). In a business context, a *defect* might be: an MQL that fails to convert in SLA, a deal
lost after stage-3, a customer who churns within 90 days, an invoice with a billing error, an order
that misses its fulfillment SLA, or a regretted attrition.

## DMAIC (improve an existing process)

| Phase | Goal | Key deliverables |
|-------|------|------------------|
| **Define** | Scope the problem & customer/market need | Project charter, SIPOC, VOC, CTQ tree |
| **Measure** | Quantify current performance | Operational defect definition per department, data plan, MSA, baseline DPMO/sigma, Cp/Cpk |
| **Analyze** | Find root causes of defects/variation | Pareto, Ishikawa (6M), 5 Whys, hypothesis tests, regression, vital-few X's |
| **Improve** | Implement & validate solutions | FMEA, pilot, Lean waste removal, poka-yoke, prioritized solutions |
| **Control** | Hold the gains | Control plan, SPC/control charts, standard work / SOPs, response plan, handoff |

## DMADV / DFSS (design a new process or product)

Define → Measure → Analyze → **Design** → **Verify**. Used when there is no existing process to
fix (greenfield) — e.g. launching a new product line, opening a new market, standing up a new ops
function. Emphasis on designing to CTQ targets and verifying capability before launch.

## The 7 Basic Quality (QC) Tools

1. **Check sheet** — structured data collection (e.g. defect log per channel per week).
2. **Pareto chart** — rank causes; the vital few (80/20). E.g. 80% of churn from 20% of root causes.
3. **Cause-and-effect (Ishikawa / fishbone)** — categorize root causes (6M).
4. **Histogram** — distribution shape, center, spread (e.g. deal cycle time distribution).
5. **Scatter diagram** — relationship between two variables (e.g. SDR cadence vs reply rate).
6. **Control chart** — distinguish common-cause from special-cause variation over time.
7. **Stratification / flowchart** — separate data by segment / map the process (SIPOC).

## Lean (speed & waste)

- **8 wastes — DOWNTIME:** Defects, Overproduction, Waiting, Non-utilized talent, Transport,
  Inventory, Motion, Extra-processing.
- **Value Stream Mapping (VSM):** map value-add vs non-value-add steps and lead time across the
  funnel / fulfillment chain / hire-to-productivity flow.
- **Flow / pull / takt:** reduce cycle time, work-in-progress (e.g. open deals per rep), and
  hand-offs (e.g. Marketing→Sales, Sales→CS).
- **5S, Kaizen, Kanban:** continuous small improvements and visual control of operational state.

## Statistical toolkit

- **DPMO & sigma level** — defect rate normalized per million opportunities → capability sigma.
- **Process capability Cp / Cpk** — how well output fits within spec limits (Cpk accounts for
  off-center processes). Cpk ≥ 1.33 is the common "capable" threshold. Business uses: lead SLA
  seconds, DSO days, ticket SLA hours, fulfillment minutes vs spec.
- **MSA / Gage R&R** — is the measurement system itself repeatable & reproducible? For business:
  are KPI definitions consistent across departments, dashboards, and time?
- **Hypothesis testing** — t-test, ANOVA, chi-square: is a difference real or noise? (e.g. is
  variant A's conversion truly higher, or noise?)
- **Regression / correlation** — quantify relationships between X's and the Y.
- **DOE (Design of Experiments)** — efficiently find which factors matter and their settings —
  pairs naturally with marketing A/B/n testing and pricing experiments.
- **Control charts** — X̄-R, I-MR, p/np/c/u charts for ongoing monitoring.

## Define-phase tools

- **Project charter:** problem statement, goal statement (SMART), scope, business case ($ impact),
  team (named cross-functional owners), timeline.
- **SIPOC:** Suppliers → Inputs → Process → Outputs → Customers (high-level process map). Built per
  department's value chain.
- **VOC (Voice of Customer):** translate customer needs into measurable requirements. Pair with
  **Voice of Market** when sourcing from market research.
- **CTQ tree:** decompose a broad need ("responsive support") into measurable Critical-To-Quality
  specs ("first response < 1 business hour for P1").
- **Kano model:** classify features/promises as basic / performance / delighter.

## Improve/risk tools

- **FMEA:** list failure modes; score Severity (in dollars/customers), Occurrence, Detection
  (1–10); **RPN = S×O×D**; act on the highest RPN first; re-score after mitigation.
- **Poka-yoke (error-proofing):** make defects impossible or immediately obvious — required CRM
  fields, stage-gate exit criteria, approval thresholds, validation on order entry.
- **Pugh / prioritization matrix:** score solution candidates against criteria; impact vs effort.
- **Pilot / DOE:** validate the improvement on a small scale (one region, one segment, one rep
  pod) before full rollout.

## Control tools

- **Control plan:** for each key metric — target, measurement method, frequency, **named owner**,
  reaction plan when it drifts.
- **SPC:** control charts with control limits; react to special-cause signals, not noise. Hosted
  in the CRM dashboard, Sheet, or Looker board (cite the URL).
- **Standard work / SOPs:** document the improved process so it sticks even when the champion leaves.

## The MBB role (vs Black Belt vs Green Belt)

- **Green Belt:** runs small projects part-time; uses core DMAIC tools.
- **Black Belt:** leads full DMAIC projects full-time; deep statistics.
- **Master Black Belt:** trains/mentors Belts, governs the **portfolio** of projects across
  departments, sets methodology and standards, aligns projects to strategy and the P&L, and ensures
  statistical rigor across the org. In this skill, the MBB orchestrates the specialist business
  agents (research, lead-gen, search-console) and the dashboards (Sheets, CRM, Ahrefs, Linear) and
  synthesizes their results into a cross-functional improvement portfolio.
