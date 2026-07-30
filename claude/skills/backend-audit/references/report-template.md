# Backend Audit — Report Template

Two files are written to `REPORT_DIR` (default `./backend-audit/`):
`backend-audit-report.md` (full) and `backend-audit-scorecard.md` (quick).

---

## Scorecard (`backend-audit-scorecard.md`)

```markdown
# Backend Audit Scorecard — {project}
{date} · Stack: {stack} · ORM: {orm} · Cache: {cache} · Mode: {static | static+runtime}

**Backend Health Score: {BHS} / 5.0 — Band {A–F}**

| # | Pass | Score | Top issue |
|---|------|:-----:|-----------|
| 2 | Data fetching / N+1 | {1–5} | {one line} |
| 3 | Caching & prefetch | {1–5} | {one line} |
| 4 | Rate limits | {1–5/NA} | {one line} |
| 5 | Resilience | {1–5} | {one line} |
| 6 | Pagination & payload | {1–5} | {one line} |
| 7 | Connection pooling | {1–5} | {one line} |
| 8 | Database / indexing / locking | {1–5} | {one line} |
| 9 | Latency / throughput | {1–5} | {one line} |
| 10 | Async / jobs / concurrency | {1–5/NA} | {one line} |
| 11 | API contract / idempotency | {1–5} | {one line} |
| 12 | Observability | {1–5} | {one line} |
| 13 | Dependency hygiene | {1–5} | {one line} |

Cross-referenced to other audits: {e.g. "no inbound rate limiting → see /security-audit Pass 14"}
```

---

## Full report (`backend-audit-report.md`)

```markdown
# Backend Audit — {project}

## Executive summary
{2–4 sentences: overall health, the single biggest win, and whether it's safe at current scale.}

Backend Health Score: **{BHS} / 5.0 ({band})**

## Inventory
- Stack / ORM / HTTP client / cache: {…}
- Inbound endpoints: {n} · Outbound integrations: {list}
- Runtime tested: {yes (endpoints, load) | no — static only}

## Findings
{One subsection per pass that scored ≤ 4, ordered by weight×severity (biggest impact first).}

### {Pass} — score {n}/5
- **Finding:** {what}
- **Location:** `{file}:{line}` {, more}
- **Why it matters:** {impact — latency, extra queries, failure mode}
- **Evidence:** {grep hit / k6 p95 / queries-per-request}
- **Fix:** {concrete change, referencing the source in references/sources.md}
- **Verification:** {how to confirm — re-run with --runtime, count queries, measure p95}

## Quick wins (do these first)
1. {highest payoff / lowest effort}
2. …

## Deferred to other skills
- {finding} → `/security-audit` Pass {n}
- {finding} → `/code-audit`

## Sources
{cite the relevant entries from references/sources.md used in fixes}
```

### Per-finding rules
- Always give `file:line`. No location = not a finding, it's a hypothesis (label it as such).
- Every fix names the concrete technique (eager load, `whereIn`, Redis TTL, `Retry-After`,
  cursor pagination, connection pool size) — never "optimize this."
- Redact secrets in any quoted config as `[REDACTED]`.
