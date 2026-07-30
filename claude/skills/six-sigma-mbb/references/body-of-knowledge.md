# Six Sigma Master Black Belt — Body of Knowledge (distilled)

Cached baseline of the MBB toolkit. Rebuilt by `--refresh` from the authorities in `sources.md`
(ASQ MBB BoK, IASSC, ISO 13053-1/-2, NIST/SEMATECH e-Handbook, Lean Enterprise Institute).

## Core idea

Six Sigma reduces **defects** and **variation** in a process so output reliably meets customer
requirements. "Six Sigma" capability = 3.4 defects per million opportunities (DPMO) — a process so
capable that ±6 standard deviations fit within the spec limits (with the classic 1.5σ long-term shift).

## DMAIC (improve an existing process)

| Phase | Goal | Key deliverables |
|-------|------|------------------|
| **Define** | Scope the problem & customer need | Project charter, SIPOC, VOC, CTQ tree |
| **Measure** | Quantify current performance | Operational defect definition, data plan, MSA, baseline DPMO/sigma, Cp/Cpk |
| **Analyze** | Find root causes of defects/variation | Pareto, Ishikawa, 5 Whys, hypothesis tests, regression, vital-few X's |
| **Improve** | Implement & validate solutions | FMEA, DOE/pilot, Lean waste removal, poka-yoke, prioritized solutions |
| **Control** | Hold the gains | Control plan, SPC/control charts, standard work, response plan, handoff |

## DMADV / DFSS (design a new process or product)

Define → Measure → Analyze → **Design** → **Verify**. Used when there is no existing process to
fix (greenfield). Emphasis on designing to CTQ targets and verifying capability before launch.

## The 7 Basic Quality (QC) Tools

1. **Check sheet** — structured data collection.
2. **Pareto chart** — rank causes; the vital few (80/20).
3. **Cause-and-effect (Ishikawa / fishbone)** — categorize root causes (6M).
4. **Histogram** — distribution shape, center, spread.
5. **Scatter diagram** — relationship between two variables.
6. **Control chart** — distinguish common-cause from special-cause variation over time.
7. **Stratification / flowchart** — separate data by source / map the process.

## Lean (speed & waste)

- **8 wastes — DOWNTIME:** Defects, Overproduction, Waiting, Non-utilized talent, Transport,
  Inventory, Motion, Extra-processing.
- **Value Stream Mapping (VSM):** map value-add vs non-value-add steps and lead time.
- **Flow / pull / takt:** reduce cycle time, work-in-progress, and handoffs.
- **5S, Kaizen, Kanban:** continuous small improvements and visual control.

## Statistical toolkit

- **DPMO & sigma level** — defect rate normalized per million opportunities → capability sigma.
- **Process capability Cp / Cpk** — how well output fits within spec limits (Cpk accounts for
  off-center processes). Cpk ≥ 1.33 is the common "capable" threshold.
- **MSA / Gage R&R** — is the measurement system itself repeatable & reproducible?
- **Hypothesis testing** — t-test, ANOVA, chi-square: is a difference real or noise?
- **Regression / correlation** — quantify relationships between X's and the Y.
- **DOE (Design of Experiments)** — efficiently find which factors matter and their settings.
- **Control charts** — X̄-R, I-MR, p/np/c/u charts for ongoing monitoring.

## Define-phase tools

- **Project charter:** problem statement, goal statement (SMART), scope, business case, team, timeline.
- **SIPOC:** Suppliers → Inputs → Process → Outputs → Customers (high-level process map).
- **VOC (Voice of Customer):** translate customer needs into measurable requirements.
- **CTQ tree:** decompose a broad need ("reliable") into measurable Critical-To-Quality specs.
- **Kano model:** classify features as basic / performance / delighter.

## Improve/risk tools

- **FMEA:** list failure modes; score Severity, Occurrence, Detection (1–10); **RPN = S×O×D**;
  act on the highest RPN first; re-score after mitigation.
- **Poka-yoke (error-proofing):** make defects impossible or immediately obvious.
- **Pugh / prioritization matrix:** score solution candidates against criteria; impact vs effort.
- **Pilot / DOE:** validate the improvement on a small scale before full rollout.

## Control tools

- **Control plan:** for each key metric — target, measurement method, frequency, owner, reaction plan.
- **SPC:** control charts with control limits; react to special-cause signals, not noise.
- **Standard work / SOPs:** document the improved process so it sticks.

## The MBB role (vs Black Belt vs Green Belt)

- **Green Belt:** runs small projects part-time; uses core DMAIC tools.
- **Black Belt:** leads full DMAIC projects full-time; deep statistics.
- **Master Black Belt:** trains/mentors Belts, governs the **portfolio** of projects, sets
  methodology and standards, aligns projects to strategy, and ensures statistical rigor across the
  org. In this skill, the MBB orchestrates the specialist audits and synthesizes their results.
