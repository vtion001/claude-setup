# Backend Audit — Scoring Rubric

## Per-pass severity (1–5)

Each pass gets a single integer 1–5:

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Optimal | Best-practice; (with `--runtime`) measured fast |
| 4 | Good | Production-ready; minor tuning possible |
| 3 | Acceptable | Works, but a clear inefficiency exists |
| 2 | Poor | Measurable slowness or fragility under load |
| 1 | Critical | Will fail / degrade badly at scale |

A pass that does not apply to the target (e.g. no outbound integrations → `rate-limit`) is marked
**N/A** and dropped from the weighted average (do not score it 5).

## Pass weights

Weights reflect impact on "load quickly and smoothly." Data fetching dominates real-world latency.

| Pass | Weight |
|------|--------|
| `fetch` (N+1 / data fetching) | 3 |
| `cache` (caching & prefetch) | 2 |
| `resilience` (retries/timeouts) | 2 |
| `pagination` (payload bounds) | 2 |
| `database` (indexing/locking/migrations) | 2 |
| `latency` (slow queries / sync work) | 2 |
| `async` (jobs / queues / concurrency) | 2 |
| `contract` (idempotency/versioning/webhooks) | 2 |
| `rate-limit` (capacity handling) | 1 |
| `pooling` (connections) | 1 |
| `observability` (logging/metrics/tracing) | 1 |
| `deps` (usage hygiene) | 1 |
| `inventory` | 0 (context only, not scored) |

## Backend Health Score (BHS)

```
BHS = ( Σ (pass_score × weight) over scored passes )
      ÷ ( Σ weight over scored passes )
```

Result is a 1.0–5.0 number. Convert to a band:

| BHS | Band |
|-----|------|
| 4.5 – 5.0 | A — Fast & resilient |
| 3.5 – 4.4 | B — Solid, minor debt |
| 2.5 – 3.4 | C — Works, real inefficiencies |
| 1.5 – 2.4 | D — Slow / fragile under load |
| 1.0 – 1.4 | F — Will not scale |

Worked example: `fetch`=2 (w3), `cache`=3 (w2), `resilience`=2 (w2), `pagination`=4 (w2),
`database`=3 (w2), `latency`=3 (w2), `async`=2 (w2), `contract`=3 (w2), `rate-limit`=N/A,
`pooling`=4 (w1), `observability`=2 (w1), `deps`=4 (w1).
Numerator = 6+6+4+8+6+6+4+6+4+2+4 = 56; Denominator = 3+2+2+2+2+2+2+2+1+1+1 = 20 →
**BHS = 2.8 (C)**.

## Severity → Linear priority (with `--linear`)

| Pass score | Linear priority |
|------------|-----------------|
| 1 | P1 (Urgent) |
| 2 | P2 (High) |
| 3 | P3 (Medium) |
| 4–5 | P4 (Low) / skip |
