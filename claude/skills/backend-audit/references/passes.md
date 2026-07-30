# Backend Audit — Pass Definitions (13 passes)

Each pass has: **what it checks**, **Tier 0 grep signatures** (what to search and what a hit
means), **Tier 1 runtime check** (with `--runtime` — Playwright/Burp live traffic and/or
k6/autocannon load), and **common fixes**. Signatures are intentionally broad — Tier 2 (AI
judgment) filters false positives. Attribute every finding to `file:line`.

Stack notes use the user's primary stack (CodeIgniter 4 / PHP) plus Node and Python equivalents.

Order groups the passes: **discovery** (1) → **data path** (2–9) → **integration & operability**
(10–13). Weights live in `scoring-rubric.md`.

---

## Pass 1 — `inventory`

**Checks:** Establish what you're auditing before judging it.

- Framework, ORM/query layer, HTTP client, cache layer, queue, observability stack
  (`scripts/detect-stack.sh`).
- **Inbound** endpoints: route files, controllers, OpenAPI/Swagger.
- **Outbound** integrations: every third-party API call site; webhooks received/sent.

**Tier 0 signatures:**
- Routes — CI4: `app/Config/Routes.php`, `Controllers/`; Express: `app.get|post|put|router.`;
  FastAPI: `@app.get|@router.`; Django: `urls.py`; Rails: `config/routes.rb`.
- Outbound calls — `curl_init|Guzzle|Http::|file_get_contents\(.*http` (PHP),
  `axios|fetch\(|got\(|http\.request` (Node), `requests\.|httpx\.|urllib` (Python).

**Output:** an inventory table (endpoint | method | controller | outbound deps). Used to scope
passes 2–13 and to choose runtime endpoints.

---

## Pass 2 — `fetch` (data fetching / N+1)  · weight 3 (highest)

**Checks:** The single biggest backend slowdown — querying inside a loop, lazy-loading relations
per row, fetching more than needed.

**Tier 0 signatures (a query *inside* a loop = candidate N+1):**
- PHP/CI4: a `->find(`, `->where(`, `->get(`, `->row(`, or `->result(` appearing within a
  `foreach`/`for`/`while` body. Eloquent lazy access (`$model->relation`) inside a loop.
- Node/Prisma/Sequelize: `await prisma.*.findUnique|findFirst` or `await Model.findByPk` inside
  `for|map|forEach`. `await` inside `.map()` without `Promise.all`.
- Python/Django: attribute access on a related object inside a `for` (lazy FK), `.get()` in a loop;
  missing `select_related`/`prefetch_related`. SQLAlchemy lazy `relationship` accessed in a loop.
- `SELECT *` / `->select('*')` / no column projection on wide tables = over-fetching.

**Tier 1 (runtime):** hit a list endpoint; if queries-per-request scales with row count
(e.g. 1 + N), it's a confirmed N+1. With **Playwright**, drive the page and read
`performance.getEntriesByType('resource')` — a burst of many near-simultaneous XHRs to the same
endpoint family is the client-side fingerprint of an N+1/over-fetch. With **Burp proxy**, watch
the request history for the same shape.

**Fixes:** eager/batch load (`with()` / `select_related` / `prefetch_related` / Prisma `include`),
`whereIn` batch fetch, JOIN, DataLoader (GraphQL), project only needed columns.
Source: "Top 7 Ways to 10x Your API Performance"; roadmap.sh backend performance.

---

## Pass 3 — `cache` (caching & pre-fetching)  · weight 2

**Checks:** Are expensive responses cached, and are likely-next calls pre-fetched, so APIs feel
instant?

**Tier 0 signatures:**
- Response caching present? — CI4 `cache(` / `Cache::` / `$this->cache`; Redis/Memcached client
  usage; absence near expensive read endpoints = finding.
- HTTP cache headers — search responses/middleware for `Cache-Control`, `ETag`, `Last-Modified`,
  `stale-while-revalidate`. Absent on cacheable GETs = finding.
- Eviction/TTL — cache writes with **no TTL** or no invalidation on the corresponding write path
  = stale-data risk.
- Pre-fetch — for predictable sequences (list → detail), is there batch/eager fetch or a warm
  cache? None = opportunity, not a defect.

**Tier 1:** issue the same GET twice; if the second is not materially faster, caching is absent
or ineffective. With **Burp `repeater`**, replay the request and read the response headers
directly — no `Cache-Control`/`ETag` and no `304` on replay = no HTTP caching. With **Playwright**,
navigate the same view twice and check `transferSize === 0` on the repeat (a browser cache hit).

**Fixes:** add a cache layer (Redis) with explicit TTL + invalidation on writes; emit
`Cache-Control`/`ETag`; consider `stale-while-revalidate`; predictive prefetch for high-probability
next calls (only non-sensitive data). LRU eviction when memory-bound.
Sources: Speakeasy REST caching; predictive prefetching; oneuptime prefetch strategies.

---

## Pass 4 — `rate-limit` (capacity / quota handling)  · weight 1

**Checks (performance lens only — DoS/abuse → `/security-audit` Pass 14):**

- **Outbound:** does client code read `X-RateLimit-Remaining` / honor `Retry-After` on `429`/`503`
  instead of hammering and getting throttled?
- **Inbound:** is there any throttle/quota config so one client can't starve the API?

**Tier 0 signatures:**
- Outbound: presence of `429`, `Retry-After`, `X-RateLimit` handling near HTTP call sites.
  None = blind client (will get throttled).
- Inbound: CI4 `Throttler`/filters; Express `express-rate-limit`; FastAPI `slowapi`; Django
  ratelimit. Absent = finding (note: cross-reference security-audit, don't re-score there).

**Tier 1:** with **Burp proxy**, inspect responses for `X-RateLimit-*`/`Retry-After` headers (are
they even exposed?). A *rate-capped, authorized* **Burp `intruder`** burst against an inbound
endpoint shows whether throttling kicks in (`429`) or the server just keeps serving until it
degrades — the capacity question. (Attack-style abuse testing stays in `/security-audit`.)

**Fixes:** read rate-limit headers proactively; back off before the ceiling; cap concurrency to
a third-party API; add inbound throttling.
Sources: getknit rate-limiting best practices; Truto rate limits & retries; OWASP API4:2023.

---

## Pass 5 — `resilience` (retries / timeouts / circuit breakers)  · weight 2

**Checks:** Will one slow/failed dependency hang or cascade?

**Tier 0 signatures:**
- **Timeouts:** every outbound HTTP/DB call must set a timeout. Search call sites for `timeout`/
  `connect_timeout`/`CURLOPT_TIMEOUT`/axios `timeout:`/`httpx.Client(timeout=`. **Missing = finding**
  (a call with no timeout can hang forever).
- **Retries:** look for retry logic; flag both *no retries* on idempotent calls and *naive
  immediate retries* (no backoff). Want jittered exponential backoff, capped at 3–5 attempts.
- **Circuit breaker:** for hot third-party deps, any breaker (e.g. resilience4j-style, opossum,
  `pybreaker`)? None on a critical dependency = finding.
- **Silent drops:** `catch` blocks that swallow errors with no log/rethrow (overlaps the
  silent-failure concern — flag for resilience, fix is to surface + retry/queue).

**Tier 1:** none required; static is authoritative here.

**Fixes:** per-attempt timeouts (1–5s typical); jittered exponential backoff; 3–5 retry cap;
circuit breaker on hot deps; never silently drop — log and fail or enqueue.
Sources: Truto retries; getknit; boldsign retry mechanism.

---

## Pass 6 — `pagination` (pagination & payload)  · weight 2

**Checks:** Do list endpoints return bounded payloads?

**Tier 0 signatures:**
- List/index endpoints returning a full table — `->findAll()` / `Model.all()` / `.objects.all()`
  with **no limit/offset/cursor** = finding.
- Max payload / input size enforced on writes? (large bodies = CPU/memory cost — overlaps
  OWASP API4:2023 resource consumption).
- Compression — is gzip/brotli enabled at app or proxy layer for JSON responses?
- JSON serialization cost — serializing huge object graphs per request.

**Tier 1:** measure payload size and latency on list endpoints; large unbounded payloads show up
as high p95 + large transfer. **Burp proxy** shows `Content-Length` and `Content-Encoding` per
response (missing gzip/br on a large JSON body = finding); **Playwright** `transferSize` vs
`encodedBodySize` reveals whether compression is actually applied over the wire.

**Fixes:** cursor pagination (preferred for large/active sets) or offset with a hard max page
size; enforce max body size; enable gzip/brotli; trim serialized fields.
Sources: "Top 7 Ways to 10x API Performance"; OWASP API4:2023.

---

## Pass 7 — `pooling` (connection pooling & resources)  · weight 1

**Checks:** Are DB/HTTP connections reused, not rebuilt per request?

**Tier 0 signatures:**
- DB pool config present and sane (pool size, max connections, idle timeout)? CI4 `Database`
  `pConnect`; Node pg/mysql2 `Pool`; SQLAlchemy `pool_size`/`max_overflow`; Django `CONN_MAX_AGE`.
  Per-request `new Connection()` outside a pool = finding.
- HTTP client reuse — constructing a new client/session per request (`new GuzzleClient` /
  `new axios instance` / `requests.get` without a `Session`) inside handlers = no keep-alive.
- Connection-leak risk — opened connections without a `finally`/close, or cache/DB handles created
  in loops.

**Tier 1:** under load, exhausted pools manifest as latency cliffs / connection-timeout errors.

**Fixes:** size the pool to concurrency; reuse a single HTTP client/session with keep-alive;
ensure connections are released in `finally`; tune idle timeout.
Sources: "Top 7 Ways to 10x API Performance"; roadmap.sh.

---

## Pass 8 — `database` (schema, indexing, transactions, locking)  · weight 2  · NEW

**Checks:** Below the query layer — is the schema indexed for the access patterns, and do writes
avoid lock contention / deadlocks / dangerous migrations?

**Tier 0 signatures:**
- **Indexing:** inspect migrations for indexes on FK columns and frequent `WHERE`/`ORDER BY`
  columns. A `where('col', …)` on a column with no index in any migration = missing-index finding.
  Flag over-indexing too (many indexes on a write-heavy table slow inserts).
- **Transaction scope:** `beginTransaction`/`DB::transaction`/`@transaction.atomic`/`with transaction`
  wrapping network calls or long loops = lock held too long. No transaction around multi-statement
  writes that must be atomic = consistency finding.
- **Locking / ordering:** writes that touch the same tables in inconsistent order across code paths
  → deadlock risk. `SELECT ... FOR UPDATE`/`lockForUpdate` held across slow work.
- **Migrations:** `ALTER TABLE`, `ADD COLUMN ... DEFAULT`, `CREATE INDEX` (non-concurrent) — these
  take heavy/table locks that block reads+writes during deploy. Flag non-`CONCURRENTLY` index
  creation (Postgres) and table-rewriting `ALTER`s.
- **Isolation:** explicit `SERIALIZABLE`/`REPEATABLE READ` on hot paths (contention) or missing
  isolation where it's needed.

**Tier 1:** enable slow-query / deadlock logging (MySQL `innodb_print_all_deadlocks`, Postgres
`log_lock_waits`) and exercise the write paths; capture lock waits and deadlocks under concurrency.

**Fixes:** add indexes matching query shapes; keep transactions short and outside network I/O;
lock tables in a consistent order; build retry-safe idempotent write logic; use
`CREATE INDEX CONCURRENTLY` and online/expand-contract migrations to avoid deploy-time locks.
Sources: SQL Server/Postgres locking & deadlock guides; safe-migration guidance (see sources.md).

---

## Pass 9 — `latency` (backend latency / throughput)  · weight 2

**Checks:** Where does request time actually go?

**Tier 0 signatures:**
- Slow-query shapes — joins without indexed keys, `LIKE '%...%'` leading wildcard, `ORDER BY` on
  unindexed columns, `COUNT(*)` on large tables per request. (Coordinate with Pass 8 for indexes.)
- Sync work that should be async — sending email, image/render, or third-party calls **inline** in
  a request handler instead of a queue/job. (Relevant to the user's mfgcalc render + email tool;
  see Pass 10 `async`.)

**Tier 1 (the headline runtime metric):** k6/autocannon p50/p95/p99 latency, throughput (req/s),
error rate per endpoint. Flag any endpoint with p95 over a target budget (default 500 ms) or
error rate > 1% under nominal load. For real-user latency (not just synthetic), **Playwright**
Resource Timing `duration` per request and **Burp `repeater`** round-trip time give the
through-the-app number; use them to rank which endpoints deserve a k6 load run.

**Fixes:** add indexes; rewrite slow queries; move slow side-effects to a background queue;
cache hot reads (see Pass 3).
Sources: roadmap.sh; performance-audit health-checkup guidance.

---

## Pass 10 — `async` (background jobs / queues / concurrency)  · weight 2  · NEW

**Checks:** Is slow or bursty work offloaded to workers, and are those workers correct and bounded?

**Tier 0 signatures:**
- **Queue presence:** any job/queue infra — CI4 queue/`spark` tasks, Laravel `queue`/`dispatch(`,
  Celery/RQ/ARQ (Python), BullMQ/Bee (Node), Sidekiq (Ruby). Absent while heavy inline work exists
  (Pass 9) = "should be async" finding.
- **Blocking the loop/thread:** Node — synchronous `fs.*Sync`, `crypto.*Sync`, big `JSON.parse`,
  CPU loops on the event loop. Python async — blocking calls (`requests`, `time.sleep`, heavy CPU)
  inside `async def` without `run_in_executor`. = stalls all concurrent requests.
- **Worker hygiene:** unbounded concurrency, no per-job timeout, no retry/`max_attempts`, **no
  dead-letter queue** for exhausted jobs, non-idempotent job bodies (re-run on retry duplicates work).
- **Batching:** per-item processing where a batch API/bulk insert exists.

**Tier 1:** under load, watch queue depth/lag and worker throughput; a growing backlog = under-
provisioned or blocked workers.

**Fixes:** move slow side-effects to a queue; cap worker concurrency to resources; set per-job
timeout + bounded retries + DLQ; make job bodies idempotent; offload blocking CPU off the event
loop (worker threads / executor); batch where possible.
Sources: Azure Well-Architected background jobs; BullMQ; Full Stack Python task queues (sources.md).

---

## Pass 11 — `contract` (API contract / idempotency / versioning)  · weight 2  · NEW

**Checks:** Is the API a stable, integration-friendly contract — safe to retry, versioned, with
machine-readable errors? (Design/reliability lens; auth/signature security → `/security-audit`.)

**Tier 0 signatures:**
- **Idempotency:** do unsafe POST/PUT handlers honor an `Idempotency-Key` (store first response by
  key, return it on retry)? None on payment/order/create endpoints = duplicate-operation risk.
- **Versioning:** URL/header versioning (`/api/v1`, `Accept-Version`)? Breaking changes without a
  version or deprecation path = finding. Look for an OpenAPI/Swagger spec as the contract source.
- **Error envelope:** the cardinal sin — returning `HTTP 200` with `{status:"error"}`. Want proper
  status codes + a stable `error_code`, human `message`, and `request_id`. Grep for `200` responses
  in catch blocks / error branches.
- **Webhooks (received):** duplicate-event detection (idempotent processing), immediate `200` ack,
  signature/HMAC verification present (trust → cross-ref security-audit), and async handoff so the
  handler doesn't do slow work inline.
- **Consistency:** consistent status-code usage, pagination/filtering conventions, content types.

**Tier 1:** with **Burp `repeater`**, send the same idempotent request twice with one
`Idempotency-Key` → a correct API returns the stored result, not a second create. Check error
responses use real status codes (not `200`).

**Fixes:** add idempotency keys (UUID v4, persist response by key+fingerprint) on unsafe writes;
version the API and publish a deprecation policy; standardize a machine-readable error envelope
with `request_id`; make webhook processing idempotent + ack-fast + verify signatures + DLQ.
Sources: Zuplo idempotency; Stripe error handling; CalibreOS API design; webhook best-practice guides.

---

## Pass 12 — `observability` (logging / metrics / tracing / health)  · weight 1  · NEW

**Checks:** Can you actually see backend health — diagnose a slow/failing request after the fact?
(Performance/operability lens; log *leakage* of secrets → `/security-audit` Pass 13.)

**Tier 0 signatures:**
- **Structured logging:** is logging structured (JSON) with context fields, or ad-hoc
  `echo`/`print`/`console.log`/`var_dump`/`die(` scattered in handlers? Raw debug prints in
  request paths = finding (noise + perf + no queryability).
- **Correlation/request IDs:** a request/correlation ID generated at the edge and propagated to
  downstream calls + logs? Absent = un-traceable cross-service requests.
- **Metrics:** any metrics/APM (Prometheus client, StatsD, OpenTelemetry, Datadog, New Relic)
  capturing latency percentiles + error rate per endpoint? None = flying blind.
- **Tracing:** OpenTelemetry / distributed tracing on multi-service or multi-dependency paths?
- **Health checks:** a `/health` / readiness/liveness endpoint for the orchestrator/load balancer?
- **Timing logs:** are slow operations timed/logged so regressions are visible?

**Tier 1:** confirm a `/health` endpoint responds; confirm a request ID appears in both the
response headers and the logs for the same request.

**Fixes:** adopt structured JSON logging with `request_id`/`user_id`/`tenant_id`; generate +
propagate a correlation ID at the edge; emit per-endpoint latency percentiles + error-rate metrics;
adopt OpenTelemetry tracing; add health/readiness endpoints; remove raw debug prints.
Sources: IBM three pillars; OpenTelemetry best practices; Zuplo API observability (sources.md).

---

## Pass 13 — `deps` (server-side dependency usage hygiene)  · weight 1

**Checks (usage patterns, NOT CVEs — CVEs → `/security-audit` Pass 12):**

- ORM defaults — lazy-loading on by default (Eloquent, Django) inviting N+1; chatty ORM patterns
  where a single query would do.
- HTTP client misuse — building a new client per call (no connection reuse, no shared config),
  no default timeout configured on the client.
- Heavy library on a hot path — synchronous, blocking, or known-slow library where a lighter call
  exists.

**Fixes:** prefer eager loading where relations are always used; configure one shared HTTP client
with sane defaults; replace blocking calls on hot paths.

---

## Cross-reference quick map

| If you find… | Score it here as | Also point user to |
|--------------|------------------|--------------------|
| No inbound rate limiting | `rate-limit` (capacity) | `/security-audit` Pass 14 (DoS) |
| Webhook with no signature/HMAC verification | note in `contract` | `/security-audit` (trust/auth) |
| Stack trace / secret leaking in logs or error | — (don't score) | `/security-audit` Pass 13 |
| Outdated dependency with CVE | — (don't score) | `/security-audit` Pass 12 |
| SQL injection in a raw query | — (don't score) | `/security-audit` Pass 05 |
| Frontend over-fetching / waterfall in React | — (don't score) | `/code-audit`, `/ui-audit` |
