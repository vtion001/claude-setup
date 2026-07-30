---
name: backend-audit
description: >
  AI-powered backend & API-integration performance auditor. Runs 13 modular passes covering
  data fetching / N+1 queries, caching & pre-fetching, API rate limits & quotas, resilience
  (retries / timeouts / circuit breakers), pagination & payload size, connection pooling,
  database schema / indexing / transactions / locking, backend latency / throughput, async
  background jobs & queues & concurrency, API contract / idempotency / versioning / webhooks,
  observability (logging / metrics / tracing / health checks), and server-side dependency usage
  hygiene.
  Stack-aware (auto-detects CodeIgniter/PHP, Node/Express, Python/FastAPI/Django, Rails, etc.).
  Uses a three-tier system: Tier 0 (static source analysis via Grep), Tier 1 (optional runtime
  measurement — live traffic via Playwright + Burp Suite MCP and synthetic load via
  k6/autocannon, gated behind --runtime), Tier 2 (AI judgment). Supports --code-only, --runtime,
  --pass, --endpoints, and --linear flags. This skill should be used when the user asks to
  "backend audit", "audit the API", "audit API integrations", "check data fetching", "are my
  APIs fast", "make APIs load quickly", "check rate limits", "API request limits",
  "prefetch / caching audit", "find N+1 queries", "backend performance", "why is my API slow",
  "check indexing / database performance", "idempotency", "API versioning", "webhook reliability",
  "observability / logging / tracing", "background jobs / queues", "audit the backend". For
  security/abuse concerns (auth, injection, DoS) defer to /security-audit. For frontend render
  performance defer to /ui-audit and /code-audit.
---

# Backend Audit — API Integration & Backend Performance

Audit whether a backend and its API integrations are **fast, efficient, and resilient**. Not
"can it be hacked?" (that's `/security-audit`) and not "does it look good?" (that's `/ux-audit`)
but **"do the APIs load quickly and smoothly, and is data fetched efficiently?"** — N+1 queries,
caching, pre-fetching, rate-limit handling, retries/timeouts, pagination, and connection pooling.

## Scope boundary (no overlap with existing audits)

This skill is the performance/reliability sibling of the audit family. To avoid duplication it
**defers** these concerns and only cross-references them:

| Concern | Owned by | This skill's angle |
|--------|----------|--------------------|
| Rate limiting as **abuse/DoS** defense | `security-audit` Pass 14 | Rate limits as **capacity/quota handling** — does the client honor `Retry-After`, back off, not get throttled |
| API **auth / injection / authz** | `security-audit` Passes 03–05, 09 | Skipped — pure performance/efficiency |
| Error handling as **info disclosure** | `security-audit` Pass 13 | Error handling as **resilience** — retries, timeouts, circuit breakers |
| Dependency **CVEs** | `security-audit` Pass 12 | Dependency **usage patterns** — ORM lazy-loading, HTTP client reuse |
| Frontend render / Core Web Vitals | `code-audit`, `ui-audit` | Server-side latency only |

When a finding touches a deferred concern, note it and point to the owning skill rather than
re-auditing it.

## Prerequisites

- **Source code access** (required) — Tier 0 static analysis is the default and always runs.
- **A running backend at a base URL** (optional) — only needed for `--runtime` measurement.
- **Tier 1 runtime tools** (optional, any subset — used automatically under `--runtime` when present):
  - **Playwright MCP** (`browser_navigate`, `browser_evaluate`, `browser_network_requests`,
    `browser_take_screenshot`) — drive the real frontend so genuine API calls fire, then read
    per-request timing via the Resource Timing API. Best for client-observed waterfalls,
    duplicate requests, over-fetching, and cache-hit verification.
  - **Burp Suite MCP** (`proxy`, `repeater`, `intruder`) — proxy intercepts all API traffic so you
    can inspect response **headers** (`Cache-Control`/`ETag`, `X-RateLimit-*`/`Retry-After`,
    `Content-Encoding`), payload sizes, and timing; `repeater` replays one endpoint to confirm
    caching/compression/latency variance; `intruder` does a *rate-capped, authorized* burst to
    measure throughput and inbound throttle behavior.
  - **`k6` or `autocannon`** — synthetic load runners for p50/p95/p99 under concurrency.
    See `scripts/loadtest.md`. Use when no proxy/browser is available or for heavier load.
- **Linear MCP** (optional) — auto-filing performance debt with the `["Performance Debt"]` label.
- No MCP server is required for a default `--code-only`-style static run.

## Invocation

```
/backend-audit                              → Full 13-pass static analysis (Tier 0 + Tier 2), no running app needed
/backend-audit --code-only                  → Same as default; explicit: never touch the network
/backend-audit --runtime --url http://localhost:8000
                                            → Add Tier 1: live traffic via Playwright/Burp (if connected)
                                              + synthetic load via k6/autocannon
/backend-audit --pass fetch,cache,resilience → Cherry-pick specific passes
/backend-audit --endpoints /api/quotes,/api/items
                                            → Limit runtime testing to specific endpoints
/backend-audit --linear                     → Auto-file findings as Linear issues
```

All flags are combinable. Defaults: full 13-pass, Tier 0 + Tier 2 only (static), markdown report.

## Pass Names (for --pass flag)

`inventory`, `fetch`, `cache`, `rate-limit`, `resilience`, `pagination`, `pooling`, `database`,
`latency`, `async`, `contract`, `observability`, `deps`

## Three-Tier System

| Tier | What It Does | Tools | When |
|------|-------------|-------|------|
| **Tier 0: Static Analysis** | Source scanning — N+1 loops, missing pagination, no-timeout HTTP calls, absent cache headers, pool config, ORM eager/lazy patterns | `Read`, `Grep`, `Glob`, `scripts/static-scan.sh` | Always |
| **Tier 1a: Live Traffic Observation** | Drive the real app and inspect actual API requests/responses — timing, headers (`Cache-Control`/`ETag`/`Retry-After`/`Content-Encoding`), payload size, request waterfalls, duplicate calls, cache hits | **Playwright MCP** (drive + Resource Timing), **Burp Suite MCP** (`proxy`, `repeater`) | With `--runtime`, if available |
| **Tier 1b: Synthetic Load** | Measure p50/p95/p99 latency, throughput, error rate under concurrency; confirm N+1 via queries-per-request | `k6` / `autocannon` (+ Burp `intruder` for capped bursts), `scripts/loadtest.md` | With `--runtime` |
| **Tier 2: AI Judgment** | Reason over Tier 0/1 results, filter false positives, estimate impact, rank fixes by effort/payoff | Claude analysis | Always |

Tier 1a is preferred when Playwright/Burp are connected — it measures what real users actually
experience and reads response headers directly. Tier 1b adds load when you need throughput
numbers. They compose: observe traffic, then stress the slow endpoints found.

## Workflow

### Phase 0: Configuration

Auto-detect from the codebase. Prompt only for what cannot be resolved.

| Input | Default | Notes |
|-------|---------|-------|
| `TARGET_DIR` | current dir | Backend repo root |
| `STACK` | auto-detect | CodeIgniter/PHP, Node/Express, FastAPI, Django, Rails… (`scripts/detect-stack.sh`) |
| `ORM` | auto-detect | Query Builder, Eloquent, Prisma, SQLAlchemy, ActiveRecord, raw SQL |
| `HTTP_CLIENT` | auto-detect | cURL/Guzzle, axios/fetch, requests/httpx |
| `CACHE_LAYER` | auto-detect | Redis, Memcached, file cache, none |
| `APP_URL` | unset | Required only if `--runtime` |
| `REPORT_DIR` | `./backend-audit/` | Where the report is written |
| `LINEAR_PROJECT` | auto-detect | Only if `--linear` |

### Phase 1: Stack & Inventory (Pass `inventory`)

Run `scripts/detect-stack.sh` against `TARGET_DIR`, then:
- Enumerate **inbound** API endpoints (route files, controllers, OpenAPI/Swagger).
- Enumerate **outbound** integrations (every place the code calls a third-party API).
- Record the ORM, HTTP client, and cache layer in use.
- Output an inventory table used to scope the remaining passes.

If `--code-only` (the default), all subsequent passes run Tier 0 + Tier 2 only.

### Phase 2: Static Analysis (Tier 0, all passes)

Run `scripts/static-scan.sh` and targeted `Grep` to collect raw signals for every selected pass.
For each pass, read its definition in `references/passes.md`, which lists the exact grep
signatures and what each signal means. Attribute every finding to `file:line`.

### Phase 3: Runtime Measurement (Tier 1 — only if `--runtime`)

Confirm `APP_URL` resolves and the backend is up, then use whatever is connected. Read
`scripts/browser-trace.md` for the Playwright + Burp workflow and `scripts/loadtest.md` for load.

**Tier 1a — Live traffic (preferred, if Playwright/Burp available):**
1. If Burp is present, route the browser through the Burp `proxy` so every API call is captured.
2. `browser_navigate` through the real app's key flows (the user journeys that hit the inventory
   endpoints). This fires genuine API requests in realistic sequences.
3. Read per-request timing with `browser_evaluate` →
   `performance.getEntriesByType('resource')` (duration, `transferSize`, `encodedBodySize`).
   `transferSize === 0` on a repeat = served from cache.
4. From Burp proxy history (or `browser_network_requests`), inspect each API response for:
   `Cache-Control`/`ETag` (Pass 3), `X-RateLimit-*`/`Retry-After` (Pass 4), `Content-Encoding`
   gzip/br (Pass 6), `Content-Length`/payload size (Pass 6), and response time (Pass 8).
5. Flag **client-observed** problems static analysis can't see: request waterfalls (many
   sequential XHRs), duplicate identical requests, and over-fetching (large payloads for small UI).
6. Use Burp `repeater` to replay one endpoint 3–5× → confirm caching (faster / `304`), compression,
   and latency variance.

**Tier 1b — Synthetic load (for throughput numbers):**
7. Run k6/autocannon (or a *rate-capped, authorized* Burp `intruder` burst) against the slow
   endpoints from 1a, or the `--endpoints` subset. Capture p50/p95/p99, throughput, error rate.
8. If query logging or an APM is available, capture queries-per-request to confirm/deny N+1.

**Safety:** localhost is auto-authorized. For any non-localhost `APP_URL`, require explicit
confirmation before driving the app or generating load, and cap request rate (default 50 req/s).
Never drive/load a third-party or production host the user does not own. Burp `intruder` is for
**throughput measurement only** here — no attack payloads (that's `/security-audit`).

### Phase 4: AI Judgment (Tier 2, all passes)

For each pass: combine Tier 0 signals with Tier 1 measurements (if any), discard false positives
(e.g. a "loop with a query" that runs over a fixed 3-item config is not a real N+1), estimate
impact, and score the pass using `references/scoring-rubric.md`.

### Phase 5: Report Generation

Read `references/report-template.md`. Generate:
- `backend-audit/backend-audit-report.md` — narrative report + per-finding detail.
- `backend-audit/backend-audit-scorecard.md` — quick scorecard with the 13 pass scores.
- `backend-audit/evidence/` — k6/autocannon output, query logs (only if `--runtime`).

**Backend Health Score (BHS):** weighted average of the 13 pass scores — see
`references/scoring-rubric.md` for weights and formula.

**Linear integration (if `--linear`):**
- File issues with label `["Performance Debt"]`, grouped by pass (one issue per pass, not per line).
- Priority mapped from severity: 1 → P1, 2 → P2, 3 → P3, 4–5 → P4.

### Phase 6: Delivery & Cleanup

1. Print the scorecard and top findings inline.
2. Offer to send the report to Telegram (bot creds in project `CLAUDE.md`) if the user wants.
3. If `--runtime` created any test data, remove it. Confirm no artifacts remain.

## The 13 Passes (summary)

Full definitions, grep signatures, and severity guidance live in `references/passes.md`.
Order: discovery (1) → data path (2–9) → integration & operability (10–13).

| # | Pass | Checks (in one line) |
|---|------|----------------------|
| 1 | `inventory` | Detect stack/ORM/HTTP-client/cache/queue; list inbound endpoints + outbound integrations |
| 2 | `fetch` | **N+1 queries**, eager vs lazy loading, `SELECT *`, batch loading, over-fetching |
| 3 | `cache` | Response cache, `Cache-Control`/`ETag`, pre-fetch, stale-while-revalidate, eviction policy |
| 4 | `rate-limit` | Outbound: honor `X-RateLimit-*`/`Retry-After`; inbound: throttle config exists (→ security-audit for DoS) |
| 5 | `resilience` | Per-attempt timeouts, jittered exponential backoff, 3–5 retry cap, circuit breaker, no silent drops |
| 6 | `pagination` | List endpoints paginated (cursor/offset), max payload enforced, gzip/br compression |
| 7 | `pooling` | DB connection pool sized & reused, connection-leak risks, HTTP keep-alive / client reuse |
| 8 | `database` | Indexing for access patterns, short transactions, lock/deadlock risk, safe migrations (no table-lock deploys) |
| 9 | `latency` | Slow queries, sync work that should be async/queued; (Tier 1) measured p95/throughput |
| 10 | `async` | Background jobs/queues offload slow work; bounded workers, per-job timeout + retries + DLQ; no event-loop blocking |
| 11 | `contract` | Idempotency keys on unsafe writes, API versioning, machine-readable error envelope (not `200`+error), webhook reliability |
| 12 | `observability` | Structured logging, correlation/request IDs, latency/error metrics, tracing (OTel), health checks |
| 13 | `deps` | ORM/HTTP-client anti-patterns (lazy-loading defaults, per-request client construction) |

## Severity Scale

| Score | Meaning |
|-------|---------|
| **5** | Optimal — best-practice, measured fast |
| **4** | Good — production-ready, minor tuning possible |
| **3** | Acceptable — works, but a clear inefficiency exists |
| **2** | Poor — measurable slowness or fragility under load |
| **1** | Critical — N+1 on a hot path, no caching, no timeouts; will fail at scale |

## Safety Rules

1. **Default is read-only and offline.** Tier 0/2 never touch the network.
2. **Never load-test without `--runtime` and a confirmed, owned target.** Localhost auto-OK;
   anything else needs explicit confirmation and a rate cap. Third-party hosts are blocked.
3. **Never recommend a fix that changes cut/compute logic** — performance changes must preserve
   correctness (e.g. caching must have correct invalidation; pagination must not drop rows).
4. **Cross-reference, don't duplicate.** Security-flavored findings point to `/security-audit`.
5. **Redact secrets** found in config (connection strings, API keys) as `[REDACTED]` in the report.

## Reference Files

- **`references/passes.md`** — The 13 pass definitions with grep signatures, what-it-means, and fixes.
- **`references/scoring-rubric.md`** — Pass weights, Backend Health Score formula, severity mapping.
- **`references/report-template.md`** — Report + scorecard + per-finding + Linear issue format.
- **`references/sources.md`** — External authorities (OWASP API4:2023, caching/rate-limit/prefetch guides).
- **`scripts/detect-stack.sh`** — Identify framework, ORM, HTTP client, and cache layer in a repo.
- **`scripts/static-scan.sh`** — Grep signatures for N+1, missing pagination, no-timeout calls, cache headers.
- **`scripts/browser-trace.md`** — Playwright + Burp Suite workflow for Tier 1a live-traffic observation.
- **`scripts/loadtest.md`** — How to run k6/autocannon for the Tier 1b synthetic load.
