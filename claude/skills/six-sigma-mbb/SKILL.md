---
name: six-sigma-mbb
description: >
  Six Sigma Master Black Belt for software quality & delivery. Runs the full DMAIC cycle
  (Define→Measure→Analyze→Improve→Control) over a webapp: treats bugs as defects, computes a
  DPMO/sigma baseline, does root-cause (Pareto, fishbone, 5 Whys), FMEA risk-ranking, Lean-waste
  removal, and a control plan. Acts as the Master Black Belt ABOVE the specialist audits — consumes
  backend-audit / code-audit / security-audit / ui-audit / ux-audit scorecards plus Sentry /
  PostHog / Linear data instead of re-auditing. Stack-aware; cached body-of-knowledge with a
  --refresh flag; flags --code-only, --measure, --phase, --pass, --linear. Use when the user asks
  to "run a six sigma analysis", "DMAIC", "master black belt", "sigma level", "DPMO", "Cp/Cpk",
  "reduce defects", "root cause analysis", "Pareto", "fishbone", "FMEA", "lean waste", "control
  plan", or "apply six sigma to my app". Defer API perf to /backend-audit, security to
  /security-audit, UX to /ux-audit.
---

# Six Sigma Master Black Belt — Software Quality & Delivery (DMAIC)

Run the **DMAIC** improvement cycle over a webapp's quality and delivery process. Not "are my
APIs fast?" (that's `/backend-audit`), not "can it be hacked?" (`/security-audit`), not "does it
look good?" (`/ux-audit`) — but **"how many defects does this process produce, what is its sigma
level, what is the root cause of the vital few, and how do we reduce and sustain it?"**

The framing is the value: a **Master Black Belt does not repeat every measurement** — they mentor
the Black Belts (your specialist audits), run the improvement portfolio, and add the layer the
specialists lack: a defect baseline, statistical scoring, root cause, risk ranking, and a control
plan. This skill is that orchestrator.

## Scope boundary (no overlap with existing audits)

This skill **consumes** the specialist audits as defect data and frames them in DMAIC. It does not
re-audit their concerns.

| Concern | Owned by | This skill's angle |
|---------|----------|--------------------|
| API/data-fetch performance | `backend-audit` | Its scorecard becomes **Measure** defect data (latency defects, "waiting waste") |
| Code bugs / quality | `code-audit` | Defect counts feed **DPMO**; categories feed the **Pareto** |
| Security vulns | `security-audit` | Vuln counts = a **defect family** with high FMEA severity |
| UX / accessibility | `ux-audit`, `ui-audit` | UX issues = **CTQ** failures (Voice of Customer) |
| Prod errors / usage | Sentry / PostHog MCP | Error rate → **DPMO numerator**; funnel drop-off → conversion defects |

When a finding belongs to a specialist audit, **point to it and ingest its score** — never re-run it.

## Prerequisites

- **Source code + git history access** (required) — Tier 0 is the default and always runs;
  git log is the primary defect/churn data source.
- **Existing audit reports** (optional, strongly recommended) — `backend-audit/`, `code-audit`,
  etc. outputs in the repo are ingested as measurement inputs. Run those first for a richer baseline.
- **Tier 1 measurement sources** (optional, used under `--measure`):
  - **Sentry MCP** — production error rate and event volume (DPMO numerator).
  - **PostHog MCP** — funnel/conversion drop-off (CTQ defects), session counts (opportunities).
  - **Linear MCP** — bug issue counts, cycle time, escaped-defect rate.
  - **Test runner + coverage** — pass/fail rate (a flaky suite = poor measurement-system, see MSA).
- **Network** (optional) — only for `--refresh` to re-crawl the body of knowledge.
- No MCP is required for a default `--code-only` static run.

## Invocation

```
/six-sigma-mbb                              → Full DMAIC, Tier 0 + Tier 2 (static), auto-detect project
/six-sigma-mbb --code-only                  → Never touch network/MCPs; git + code + existing reports only
/six-sigma-mbb --measure                    → Add Tier 1 data ingestion (Sentry / PostHog / Linear / tests)
/six-sigma-mbb --phase define,measure       → Run only chosen DMAIC phases
/six-sigma-mbb --pass fmea,pareto           → Cherry-pick individual tools
/six-sigma-mbb --refresh                    → Re-crawl the web; rebuild references/body-of-knowledge.md + sources.md
/six-sigma-mbb --linear                     → File the improvement backlog as Linear issues
```

All flags combinable. Defaults: full DMAIC, Tier 0 + Tier 2 (static), markdown report to `./six-sigma/`.

## Phase / Pass names (for `--phase` and `--pass`)

- **`--phase`:** `define`, `measure`, `analyze`, `improve`, `control`
- **`--pass`:** `charter`, `sipoc`, `voc-ctq` · `baseline`, `msa`, `data-sources` · `pareto`,
  `fishbone`, `5whys`, `hypothesis` · `fmea`, `lean-waste`, `poka-yoke`, `prioritize` ·
  `control-plan`, `spc`, `quality-gates`

## Three-Tier System

| Tier | What It Does | Tools | When |
|------|-------------|-------|------|
| **Tier 0: Static** | Read code, git history (defect density, churn, bugfix-commit ratio), test & CI config, and existing audit reports | `Read`, `Grep`, `Glob`, `git log`, `scripts/detect-project.sh`, `scripts/defect-metrics.sh` | Always |
| **Tier 1: Data ingestion** | Pull defect/throughput data: Sentry errors, PostHog funnels, Linear bugs/cycle-time, test pass rate/coverage, sibling audit scorecards | Sentry / PostHog / Linear MCP, test runner, `scripts/data-sources.md` | With `--measure` |
| **Tier 2: MBB judgment** | Root-cause reasoning, FMEA scoring, prioritization, control-plan synthesis, false-positive filtering, **explicit statistical-confidence calls** | Claude analysis + `references/software-mapping.md` | Always |

## Workflow (DMAIC)

### Phase 0: Configuration

Auto-detect from the codebase; prompt only for what cannot be resolved.

| Input | Default | Notes |
|-------|---------|-------|
| `TARGET_DIR` | current dir | App repo root |
| `STACK` | auto-detect | `scripts/detect-project.sh` |
| `DEFECT_DEF` | auto | What counts as a defect for this app (bug, failed deploy, missed CTQ) — see Define |
| `DATA_SOURCES` | auto | Which of git/tests/Sentry/PostHog/Linear/audit-reports are available |
| `REPORT_DIR` | `./six-sigma/` | Where the report is written |

### Phase D — Define (passes `charter`, `sipoc`, `voc-ctq`)

Frame the improvement project before measuring anything.
- **`charter`** — problem statement, goal (measurable), scope, in/out of bounds.
- **`sipoc`** — Suppliers→Inputs→Process→Outputs→Customers for the dev/value pipeline (commit →
  review → CI → deploy → user). Locates where defects enter.
- **`voc-ctq`** — Voice of Customer → **Critical-To-Quality** tree. Define the **defect, unit, and
  opportunity** explicitly (this drives DPMO). See `references/software-mapping.md` for software
  definitions. Without a clear unit/opportunity, a sigma level is meaningless — say so.

### Phase M — Measure (passes `baseline`, `msa`, `data-sources`)

Establish the baseline with **real data**, not estimates.
- **`data-sources`** — run `scripts/defect-metrics.sh` (git-derived defect density, churn,
  bugfix-commit ratio, test pass rate); under `--measure`, also pull Sentry/PostHog/Linear and
  read sibling audit scorecards (`scripts/data-sources.md`).
- **`baseline`** — compute **DPMO** and **sigma level** per `scripts/sigma-calc.md`. Where a
  measurable spec exists (latency budget, estimate-accuracy tolerance), compute **Cp/Cpk**.
- **`msa`** — measurement-system analysis: are the metrics trustworthy? Flaky tests, inconsistent
  bug labeling, or unmonitored prod = poor "gage R&R" → flag low confidence on the baseline.

**Statistical honesty (mandatory):** state the sample size and time window. If data is too thin
for a valid sigma level, report it as **indicative only** with the n, and do not present a precise
figure as fact. This rule lives in `references/software-mapping.md` and overrides any pressure to
produce a clean number.

### Phase A — Analyze (passes `pareto`, `fishbone`, `5whys`, `hypothesis`)

Find the **vital few** causes of the defects measured.
- **`pareto`** — rank defect categories; identify the ~20% of causes driving ~80% of defects.
- **`fishbone`** — Ishikawa root cause across the **6M mapped to software** (Method/process,
  Machine/tooling+infra, Material/dependencies+data, Measurement/tests+monitoring, Man/people+review,
  Mother-nature/environment). Mapping in `references/software-mapping.md`.
- **`5whys`** — drill the top Pareto categories to root cause.
- **`hypothesis`** — where data allows, test relationships (e.g. PR size vs defect rate, module
  churn vs bug count) with correlation; state significance/confidence honestly.

### Phase I — Improve (passes `fmea`, `lean-waste`, `poka-yoke`, `prioritize`)

Design and rank countermeasures.
- **`fmea`** — Failure Mode & Effects Analysis. Score **RPN = Severity × Occurrence × Detection**
  (1–10 each) per failure mode; rank by RPN. See `references/scoring-rubric.md`.
- **`lean-waste`** — eliminate the 8 wastes (DOWNTIME) mapped to software (e.g. synchronous
  blocking work = **Waiting**; manual deploys = **excess Motion/Processing**; over-fetching =
  **excess Inventory/Transport**).
- **`poka-yoke`** — error-proofing recommendations: types, schema validation, linting, CI gates,
  invariants — make the defect impossible, not just detected.
- **`prioritize`** — impact/effort (or Pugh) matrix; output an ordered improvement backlog.

### Phase C — Control (passes `control-plan`, `spc`, `quality-gates`)

Sustain the gains.
- **`control-plan`** — for each improvement: the metric, owner, monitoring cadence, and response
  plan when it drifts.
- **`spc`** — statistical process control: which metrics to put on control charts (defect rate,
  p95 latency, deploy frequency, escaped-defect rate) and where (Sentry/PostHog dashboards).
- **`quality-gates`** — CI/CD gates that prevent regression (coverage floor, lint, type-check,
  audit thresholds, the golden-path test). Maps the fixes back into the pipeline.

> **DMADV / DFSS note:** for greenfield features (no process to fix yet), substitute Define →
> Measure → Analyze → **Design** → **Verify**. Use the same Define/Measure tools, then design to
> CTQ targets and verify against them. Flag this mode in the charter.

### Phase R — Report

Read `references/report-template.md`. Write to `REPORT_DIR`:
- `six-sigma-dmaic-report.md` — full DMAIC narrative + per-phase artifacts (charter, SIPOC, Pareto,
  fishbone, FMEA table, control plan).
- `six-sigma-scorecard.md` — headline **sigma level + DPMO**, Cp/Cpk where computed, DMAIC-maturity
  per phase, top FMEA RPNs, and the prioritized improvement backlog.

**Linear integration (`--linear`):** file the improvement backlog with label `["Quality / Six Sigma"]`,
one issue per improvement (not per defect); priority from FMEA RPN (see scoring rubric).

## Headline Scoring

- **Sigma level** (1σ–6σ) from DPMO is the headline — see `references/scoring-rubric.md` for the
  DPMO→sigma table and the software defect/unit/opportunity counting rules.
- **DMAIC maturity** (0–5 per phase) rates how well the process supports improvement (e.g. no
  monitoring = low Control maturity), independent of current defect count.
- **FMEA RPN** ranks risks for the backlog.

## Safety Rules

1. **Read-only and offline by default.** Tier 0/2 never touch the network; `--measure` only reads
   from connected MCPs; `--refresh` only fetches public docs.
2. **Never fabricate statistics.** No sigma level or Cp/Cpk without a stated sample size and window;
   thin data is labeled *indicative*. This is the core integrity rule of the skill.
3. **Consume, don't duplicate.** Performance/security/UX findings cite and ingest the owning audit;
   they are never re-derived here.
4. **No correctness-breaking fixes.** Improvement recommendations must preserve behavior (e.g. the
   `mfg-calculator` golden-path estimate must stay pinned).
5. **Data privacy.** When pulling Sentry/PostHog, never copy real user PII into the report; use
   counts and rates. Redact secrets in any quoted config as `[REDACTED]`.

## Reference Files

- **`references/body-of-knowledge.md`** — distilled MBB BoK: DMAIC, DMADV, Lean, 7 QC tools, FMEA,
  VOC/CTQ/SIPOC, statistical toolkit. (Rebuilt by `--refresh`.)
- **`references/software-mapping.md`** — Six Sigma → software adaptation + statistical-validity
  guidance (defect/unit/opportunity definitions, 6M map, 8-waste map). The anti-buzzword core.
- **`references/passes.md`** — the ~17 tool/pass definitions: input, method, what-good-looks-like,
  output artifact.
- **`references/scoring-rubric.md`** — DPMO→sigma table, Cp/Cpk formulas, DMAIC-maturity rubric,
  FMEA RPN scale, headline weighting, RPN→Linear-priority map.
- **`references/report-template.md`** — DMAIC report + scorecard + FMEA table + backlog format.
- **`references/sources.md`** — authoritative external sources (ASQ, IASSC, ISO 13053,
  NIST/SEMATECH, Lean Enterprise Institute). (Rebuilt by `--refresh`.)
- **`scripts/detect-project.sh`** — auto-detect stack, tests, CI, and existing audit reports.
- **`scripts/defect-metrics.sh`** — git-derived defect density, churn, bugfix ratio, test pass rate.
- **`scripts/sigma-calc.md`** — DPMO / sigma / Cp/Cpk formulas with worked software examples.
- **`scripts/data-sources.md`** — how to pull Sentry/PostHog/Linear and parse sibling audit scorecards.
