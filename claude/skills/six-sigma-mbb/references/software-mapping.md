# Six Sigma → Software Mapping & Statistical-Validity Guidance

This is the **integrity core** of the skill. Six Sigma was built for high-volume manufacturing
where you have thousands of measured units and stable specs. Software has fewer, noisier,
harder-to-count "units." This file defines how to map the tools honestly — and where NOT to force
the statistics.

## 1. Defining defect / unit / opportunity (drives DPMO)

DPMO requires three explicit definitions. Pick per-app in the Define phase and state them in the
report. Common software choices:

| Concept | Manufacturing | Software options (pick one and state it) |
|---------|---------------|-------------------------------------------|
| **Unit** | one produced part | one deploy · one user session · one API request · one PR · one feature |
| **Defect** | one nonconformance | one bug · one prod error event · one failed deploy · one CTQ miss (e.g. p95 > budget) · one escaped defect |
| **Opportunity** | each spec on the part | each way a unit could fail (e.g. per request: auth, validation, compute, render, persist = 5 opportunities) |

**Rule:** the unit and opportunity definitions must be stable across the measurement window or the
sigma level is not comparable over time. Record them verbatim in the scorecard.

Two common, defensible setups:
- **Request-based:** unit = API request; defect = 5xx or SLA miss; opportunities = distinct failure
  points per request. Data from Sentry + access logs.
- **Deploy-based:** unit = deploy; defect = deploy that caused a rollback/hotfix; opportunities = 1.
  Data from git tags + Linear/incident log. (DPMO here is really a defect *rate*; label it so.)

## 2. The 6M (Ishikawa) mapped to software

| 6M category | Manufacturing | Software root-cause bucket |
|-------------|---------------|----------------------------|
| **Method** | process steps | dev process: missing review, no tests-first, unclear requirements, weak CI |
| **Machine** | equipment | tooling & infra: build/deploy pipeline, runtime, container/host, flaky environments |
| **Material** | raw inputs | dependencies & data: outdated libs, bad/edge-case input data, schema drift, API contracts |
| **Measurement** | gauges | tests & monitoring: low coverage, flaky tests, no error tracking, wrong metrics |
| **Man (People)** | operators | knowledge gaps, onboarding, bus-factor, review fatigue, unclear ownership |
| **Mother-nature (Environment)** | ambient | prod/staging parity, traffic spikes, third-party outages, time/locale edge cases |

## 3. The 8 Lean wastes (DOWNTIME) mapped to software

| Waste | Software example | Where this skill finds it |
|-------|------------------|---------------------------|
| **D**efects | bugs, rework, hotfixes | git bugfix commits, Sentry |
| **O**verproduction | unused features, speculative generality | code-audit dead code |
| **W**aiting | synchronous blocking work (e.g. inline Gemini/PDF render on the request path) | backend-audit `async`/`latency` |
| **N**on-utilized talent | manual toil that should be automated | no CI/CD, manual deploys |
| **T**ransport | excess data movement, chatty APIs | backend-audit `fetch` (over-fetch) |
| **I**nventory | large payloads, unbounded queues, stale branches | backend-audit `pagination` |
| **M**otion | context-switching, manual multi-step release | missing scripts/automation |
| **E**xtra-processing | redundant computation, no caching | backend-audit `cache` |

## 4. Where rigorous statistics DO apply

Use the real math when you have a measurable continuous variable with a spec and enough samples:
- **Cp/Cpk** on **latency vs an SLA budget** (e.g. p95 < 300 ms) — Sentry/k6 give many samples.
- **Cp/Cpk** on **numeric output accuracy vs tolerance** — e.g. `mfg-calculator`'s estimate vs the
  pinned golden value $234.26 ± tolerance, sampled across input combinations.
- **Control charts (SPC)** on daily defect rate, error rate, deploy frequency — time series with n≥20.
- **Hypothesis tests / correlation** when you have ≥30 paired observations (PR size vs defects).

## 5. Where to ADAPT (do not fake the math)

- **Low-volume deploys / few bugs:** report counts and a *rate*, call the sigma level *indicative*,
  give the n. Do not present 4.2σ from 12 deploys as precise.
- **No monitoring in prod:** you cannot measure escaped defects — say so; recommend instrumentation
  as the first Measure improvement (often the highest-value finding).
- **Subjective defects (UX):** use qualitative CTQ pass/fail from `ux-audit`, not a fabricated DPMO.
- **MSA / gage R&R:** for software, "measurement reliability" = test flakiness + label consistency +
  monitoring coverage. Rate it qualitatively (good/fair/poor) and let it cap baseline confidence.

## 6. Confidence labelling (put this on every statistic)

| Label | When |
|-------|------|
| **Measured** | continuous data, n ≥ 30, stable definitions |
| **Indicative** | n between ~8 and 30, or mixed sources |
| **Insufficient data** | n < 8 or no monitoring — report the gap, recommend instrumentation, give no number |

If you catch yourself wanting to round a thin sample into a clean sigma figure — STOP. The honest
"indicative, n=14" is the correct Master Black Belt answer and is more credible than false precision.
