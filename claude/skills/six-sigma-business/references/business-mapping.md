# Six Sigma → Business Mapping & Statistical-Validity Guidance

This is the **integrity core** of the skill. Six Sigma was built for high-volume manufacturing
where you have thousands of measured units and stable specs. Business operations have fewer,
noisier, harder-to-count "units" — and stakeholders pressure analysts for clean single numbers.
This file defines how to map the tools honestly across departments — and where NOT to force the
statistics.

## 1. Defining defect / unit / opportunity per department (drives DPMO)

DPMO requires three explicit definitions per department. Pick them in Define and state them in the
report. The unit/opportunity definitions must be **stable across the measurement window** or the
sigma level is not comparable over time. Record them verbatim in the scorecard.

| Dept | Unit (the thing being made) | Defect (the failure to meet spec) | Opportunity (ways a unit can fail) | Typical source |
|------|----------------------------|-----------------------------------|------------------------------------|----------------|
| **Marketing** | One lead (or one campaign-conversion event) | MQL fails to convert to SQL within SLA; CAC > channel target; attribution gap > X% | Touchpoints per lead in funnel (ad → form → MQL → handoff → SQL = 5) | HubSpot/Salesforce CSV, GA4, Ahrefs/GSC |
| **Sales** | One opportunity (or one stage transition) | Deal lost after stage-3; cycle > median × 2; quota miss > X% | Stage gates (qualify, demo, proposal, negotiate, close = 5) | CRM export, rep activity log |
| **CS / Support** | One customer-month (or one ticket) | Customer churn within N days; CSAT < threshold; ticket SLA miss | Touchpoints per renewal cycle (onboarding, QBR, support, expansion, renewal = 5) | CRM, support tool CSV, NPS sheet |
| **Operations** | One order (or one shipment line-item) | Order missing SLA; returned / reworked; stockout | Stages in fulfillment (receive, pick, pack, ship, deliver = 5) | Ops sheet, WMS export |
| **Finance** | One invoice (or one forecast-period) | Invoice with error; DSO > target; forecast variance > X% | Billing events per invoice (issue, validate, send, collect, reconcile = 5) | Billing CSV, accounting export |
| **People / HR** | One hire (or one employee-quarter) | Hire misses 90-day milestone; regretted attrition within 12 mo; ramp > target | Lifecycle events (sourcing, interview, offer, onboarding, 90-day, ramp = 6) | ATS export, HRIS sheet |

**Rule:** record the chosen triple verbatim in the per-department scorecard. If two departments
disagree on definitions for shared metrics (e.g. Marketing and Sales on what an "SQL" is), that
disagreement itself is a finding — flag it as a Measurement-system defect.

Two common, defensible cross-dept setups:
- **Funnel-stage based** (Marketing + Sales unified): unit = lead-stage transition; defect = miss
  the next stage by SLA; opportunities = funnel stages. Lets you compute a single revenue-funnel
  sigma.
- **Customer-month based** (CS unified): unit = customer-month; defect = active-status loss in the
  period; opportunities = touchpoints in the renewal cycle. Standard for SaaS NRR analysis.

## 2. The 6M (Ishikawa) mapped to business

The classic manufacturing 6M, translated to root-cause buckets that name real org artifacts:

| 6M category | Manufacturing | Business root-cause bucket |
|-------------|---------------|----------------------------|
| **Method** | process steps | playbooks, SOPs, scripts, stage-gate criteria, escalation paths, comp plans |
| **Machine** | equipment | CRM/ERP/HRIS/billing tooling, marketing automation, BI/reporting stack, telephony, support tool |
| **Material** | raw inputs | lead lists, inventory, source data quality, ICP fit, content assets, training data |
| **Measurement** | gauges | KPI definitions, attribution model, dashboard accuracy, reporting cadence, label consistency across depts |
| **Manpower** | operators | headcount, skills, ramp time, retention, span-of-control, comp design, hiring profile |
| **Mother-nature / Market** | ambient | seasonality, competition, macro/FX, regulation, supplier outages, vendor pricing changes |

A finding without a 6M assignment is incomplete — every root cause must land in one of these
buckets. *"The rep messed up"* is never a final answer; it resolves to **Method** (no script/SOP),
**Measurement** (no defined success criterion), **Manpower** (insufficient ramp/training), or
**Machine** (CRM didn't enforce a required field).

## 3. The 8 Lean wastes (DOWNTIME) mapped to business

| Waste | Business example | Where this skill finds it |
|-------|------------------|---------------------------|
| **D**efects | rework on misquoted deals, wrong-product shipments, billing reissues | CRM exception logs, support tickets |
| **O**verproduction | over-prospecting unqualified accounts; spec'ing features no segment wants; producing reports nobody opens | SDR activity logs, content-engagement sheets |
| **W**aiting | idle leads sitting in a queue; deals stalled awaiting approval; support tickets awaiting another team | CRM stage-age, ticket aging report |
| **N**on-utilized talent | senior AEs doing data entry; engineers running manual ops; SDRs hand-copying lists | activity audit, time-allocation surveys |
| **T**ransport | excessive hand-offs (e.g. Marketing→SDR→AE→AM→CS without context carrying); data exported and re-imported between tools | process map, integration audit |
| **I**nventory | aging pipeline (deals past their median age); on-hand inventory > demand; over-hired bench | CRM cohort, ops sheet |
| **M**otion | duplicate hand-offs; reps logging the same data in two tools; managers re-typing dashboards into slides | activity logs, screen-time analysis |
| **E**xtra-processing | bloated multi-tab KPI decks no one reads; over-engineered approval chains; weekly reports nobody opens | report-traffic analytics, meeting load |

Every Improve recommendation should remove at least one of these — not just "do better."

## 4. Where rigorous statistics DO apply

Use the real math when you have a measurable continuous variable with a spec and enough samples:
- **Cp/Cpk** on **lead SLA** (e.g. first contact ≤ 5 min): inbound forms give hundreds of samples
  per month for any healthy marketing function.
- **Cp/Cpk** on **DSO** vs target — billing events give clean continuous data.
- **Cp/Cpk** on **ticket SLA** (first response time) vs SLA — support tools give large n.
- **Cp/Cpk** on **deal cycle time** vs target — if cycle is measured in days and you have ≥30
  closed-won/closed-lost deals in the window.
- **Control charts (SPC)** on weekly defect rates per dept (churn, DSO breaches, missed SLAs) —
  time series with n ≥ 20 weekly points.
- **Hypothesis tests / correlation** when you have ≥30 paired observations (e.g. SDR cadence count
  vs reply rate, ticket category vs renewal probability).

## 5. Where to ADAPT (do not fake the math)

- **Small sales teams / few deals:** a Series-A SaaS with 12 closed-won deals in the quarter does
  not produce a meaningful sigma. Report counts and a *rate*, label it *indicative*, give the n.
  Do not present 3.4σ from 12 deals as precise.
- **Inconsistent KPI definitions:** if Marketing's "MQL" ≠ Sales's "MQL", the measurement system
  is broken — call it out as the first Measure improvement (often the highest-value finding).
- **Subjective defects (CSAT / brand):** use qualitative CTQ pass/fail; don't fabricate a DPMO
  from a survey with n=20.
- **MSA / gage R&R:** for business, "measurement reliability" = KPI definition consistency, source-
  system label consistency, monitoring cadence. Rate qualitatively (good/fair/poor) and let it cap
  baseline confidence.
- **Anecdotal "the CEO heard from a customer":** record as a Voice-of-Customer signal, not a
  defect count. One executive escalation ≠ a process problem.

## 6. Confidence labelling (put this on every statistic)

| Label | When |
|-------|------|
| **Measured** | continuous data, n ≥ 30, stable definitions across the window |
| **Indicative** | n between ~8 and 30, or mixed sources / partial windows |
| **Insufficient data** | n < 8, or KPI definition changed mid-window, or no monitoring — report the gap, recommend instrumentation, give no number |

If you catch yourself wanting to round a thin sample into a clean sigma figure to make a slide
look good — STOP. The honest *"indicative, n=14"* is the correct Master Black Belt answer and is
more credible to a board than false precision. Business stakeholders will pressure for a single
number; the MBB role is to refuse.

## 7. Cross-department weighting (enterprise sigma rollup)

The enterprise rollup is **not** the simple average of per-department sigmas. Weight each
department by its share of revenue impact (or revenue-at-risk for cost centers like People). State
the weights explicitly in the scorecard. A defensible default:

| Dept | Default weight | Rationale |
|------|----------------|-----------|
| Sales | 25% | Direct revenue creation |
| Marketing | 20% | Pipeline coverage |
| CS / Support | 20% | NRR / retention |
| Operations | 15% | COGS / delivery promise |
| Finance | 10% | Cash conversion |
| People / HR | 10% | Capacity to scale |

These are starting weights. Override per company strategy (e.g. PLG company may weight Marketing >
Sales; manufacturer may weight Ops > Marketing). State the rationale next to the weight.

## 8. Growth vs Scalability bias (drives Improve prioritization)

| Mode | Tie-break favors | Examples |
|------|------------------|----------|
| `--growth-focus` | Revenue-side levers, CAC payback, unit economics, conversion-rate lifts | "Add stage-2 exit criterion in CRM (closes 40% of stuck deals)" before "Reduce DSO from 52→45 days" |
| `--scalability-focus` | Throughput, automation, org-design, capacity unlock per dollar | "Automate Finance close week 1→day 3" before "Add SDR-2 to top-of-funnel" |
| (balanced, default) | RPN order, then $-impact | Pure FMEA priority |

The bias does not change *which* improvements are in the backlog — it changes *ordering*.
