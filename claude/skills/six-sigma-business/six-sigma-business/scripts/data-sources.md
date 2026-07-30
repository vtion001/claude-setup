# Measurement Data Sources (Tier 1, `--measure`)

How to gather defect/throughput data for the Measure phase. Each source maps to a part of the DPMO
equation (or to a per-department CTQ). Pull **counts and rates only** — never copy PII (customer
names, emails, deal-owner personal data) into the report.

## 1. Google Sheets via `gog` CLI — primary KPI source

Most departments already keep a master KPI sheet. The `gog` CLI is preinstalled (Mach-O binary at
`/opt/homebrew/bin/gog`, authed to `vjrodriguez1994@gmail.com`).

- **List sheets the user has shared with you:** `gog sheets list` (or `gog drive list --mime
  application/vnd.google-apps.spreadsheet`).
- **Read a tab:** `gog sheets read <SHEET_ID> <TAB_NAME> [--range A1:Z200]` → CSV / JSON.
- **Parse:** treat the first row as the header; defect/unit columns named per
  `business-mapping.md` §1 (e.g. `lead_id`, `mql_at`, `sql_at`, `sla_minutes`).
- **Record:** sheet URL, tab, range, row count (n), and the time window the data covers.

Tip: when there is more than one sheet for the same KPI (e.g. RevOps and Finance each maintain
"MRR"), this is itself an MSA finding — flag it.

## 2. CRM CSV exports — Marketing/Sales/CS DPMO numerator

Look in `./data/`, `./exports/`, `./crm-export/`, or whatever the user points to.

- **HubSpot:** contacts.csv, deals.csv, lifecycle_stages.csv. Lifecycle stage history (when present)
  gives stage-transition timestamps for cycle calculations.
- **Salesforce:** Opportunity__c.csv, Account.csv, OpportunityHistory.csv (the stage-history file
  is essential for cycle / slippage calculations).
- **What to extract per dept:**
  - **Marketing** — count of leads in window; count of MQLs; lead-to-MQL conversion rate; SLA-miss
    count (time from lead create → first owner touch > spec).
  - **Sales** — open deals by stage; closed-won/closed-lost; cycle-time distribution; stage slip
    counts; quota attainment vs plan.
  - **CS** — active customers, gross churn count, NRR computed from line-item changes, ticket
    volume by category.
- Privacy: drop PII columns before any aggregation. Keep IDs, timestamps, stages, monetary values.

## 3. Ahrefs MCP — Marketing CTQs (organic & brand-radar)

Already authed on this machine. Use the GSC- and brand-radar-flavored tools to pull:
- **GSC clicks, impressions, position over the window** → Marketing organic-traffic units +
  defects (a CTQ-bound page that fell off the front page = a defect).
- **Keyword ranking decay** → defect class for the Pareto.
- **Brand-radar mentions / SOV** → brand-CTQ baseline.
- Honour the rendering note in the MCP instructions: when an Ahrefs tool returns a `render_with`
  hint, call the named render tool before summarizing.

## 4. Linear MCP — cross-functional initiative status + escaped defects

Use Linear MCP to:
- **Search issues** with labels matching `customer-escalation`, `bug`, `ops-incident`,
  `compliance` to estimate escaped-defect counts.
- **Cycle time / lead time** on improvement initiatives → Control-phase flow metric.
- **Destination for `--linear`**: file the improvement backlog as new issues with label
  `["Business / Six Sigma"]` and a sub-label `["Dept: <name>"]`. One issue per improvement, not
  per defect; priority from FMEA RPN (see `references/scoring-rubric.md`).

## 5. Sibling local agents — ingest as Tier 1 inputs

Check for recent run outputs in the workspace (or the agents' default output dirs) and ingest:

| Agent | Becomes |
|-------|---------|
| `business-research` | Voice of Market, CTQ targets, TAM/SAM denominators, competitor benchmarks |
| `lead-generator` | Lead/account counts, source-channel defects, ICP-fit hit rate |
| `search-console-analyst` | Organic-traffic CTQ baseline + ranking-decay defects (deduped against Ahrefs MCP if both present) |
| `website-analyst` | Customer-facing CTQ failures (web funnel drop-offs) |
| `qa-engineer` / `debug-test-agent` | If they file customer-impacting incidents — but engineering defects defer to `/six-sigma-mbb` |

When two sources agree (e.g. Ahrefs MCP and `search-console-analyst` both show the same ranking
decay), cite both, count once. When they disagree, that's a measurement-system finding.

## 6. Spreadsheet / CSV fallback — always available

When no MCP is connected and no sibling-agent output exists, run on whatever CSVs the user has:
- `./data/*.csv`, `./exports/*.csv`, `./*.csv` (head and tail to identify the schema).
- `scripts/kpi-pull.sh` summarizes available CSVs and Sheets into a single inventory the Measure
  phase can score from.

## DPMO assembly checklist (per department)

1. Choose the **unit + opportunity** definition (Define) per `business-mapping.md` §1 and keep it
   fixed across the window.
2. Numerator = defects from the best available source (CRM stage-history > sibling-agent count >
   sheet > CSV proxy).
3. Denominator = units × opportunities (CRM total, Sheet total, lead count, customer-month total).
4. Record **n + window + source** next to the result and label confidence (Measured / Indicative /
   Insufficient).
5. If no instrumented data exists for a dept → report the gap; recommend instrumentation as the
   first improvement; give the best available *Indicative* figure only, or mark *Insufficient* and
   give no sigma.

## Privacy & redaction

- Never copy named customers, deal owners, or hires into the report. Use counts, rates, and
  segment-level aggregates.
- Redact secrets in any quoted config as `[REDACTED]`.
- When n is small enough that an individual could be re-identified (e.g. only 3 hires in a region,
  one regretted attrition), aggregate up or do not name the segment.
