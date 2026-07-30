# Measurement Data Sources (Tier 1, `--measure`)

How to gather defect/throughput data for the Measure phase. Each source maps to a part of the DPMO
equation. Pull **counts and rates only** — never copy real user PII into the report.

## 1. Sentry MCP — production defects (DPMO numerator + opportunities)
- **Errors/issues** over the window → **defect count** (filter to the target project/env).
- **Event volume / total transactions** → **units / opportunities** (denominator).
- **p95/p99 transaction duration** → capability input for latency Cpk (`sigma-calc.md` ex. C).
- Tools: search Sentry MCP for issue list + counts and performance/transaction stats. Confirm the
  Sentry server is authenticated (`/mcp`) before relying on it; if not, mark the source unavailable.

## 2. PostHog MCP — conversion & usage defects (CTQ + opportunities)
- **Funnel drop-off** at a step the CTQ tree marks critical → **conversion defects**.
- **Session / pageview counts** → **units** for a session-based defect definition.
- **Error events** (if tracked in PostHog) → additional defect signal.
- Use for the Voice-of-Customer / CTQ side: a funnel the user is "supposed" to complete but doesn't
  is a defect against the customer requirement.

## 3. Linear MCP — tracked defects & flow (defects + cycle time)
- **Issues labeled bug** in the window → **defect count** (often the cleanest, if labeling is consistent).
- **Cycle time / lead time** → Lean flow metric (DORA lead-time analogue) for the Control phase.
- **Escaped defects** (bugs filed after a release) → the highest-value defect class for FMEA.
- Consistency caveat: inconsistent labeling = poor MSA → cap confidence (see `software-mapping.md` §5).

## 4. Test runner + coverage — measurement-system reliability (MSA)
- **Pass/fail rate** and **flaky tests** → the software "gage R&R": a flaky suite means your
  measurement system is unreliable, which caps baseline confidence.
- **Coverage %** → how much of the process is even being measured (low coverage = blind spots).
- Run the suite separately (`phpunit`, `vitest`, `pytest`, `playwright test`) and read the summary.

## 5. git history — change-based defects (fallback, always available)
- `scripts/defect-metrics.sh` → bugfix-commit ratio, reverts, churn hotspots, fix-concentration.
- Use as the **fallback** defect proxy when prod isn't instrumented — always label **Indicative**.

## 6. Sibling audit reports — ingest, don't re-derive
Read these from the repo (paths from `detect-project.sh`) and fold their scores into Measure/FMEA:
| File | Becomes |
|------|---------|
| `backend-audit/backend-audit-scorecard.md` | latency/efficiency defects; low passes → FMEA modes & "Waiting" waste |
| `code-audit` output | code-defect categories → Pareto buckets |
| `security-audit` output | vuln count → high-Severity FMEA family |
| `ui-audit` / `ux-audit` output | CTQ failures → VOC defects |

## DPMO assembly checklist
1. Choose the **unit** + **opportunity** definition (Define) and keep it fixed.
2. Numerator = defects from the best available source (Sentry > Linear > git proxy).
3. Denominator = units × opportunities (Sentry volume, PostHog sessions, or deploy/commit count).
4. Record **n + window + source** next to the result and label confidence.
5. If no instrumented prod data exists → report the gap; recommend adding Sentry/PostHog as the
   first improvement; give a git-proxy *Indicative* figure only.
