# Backend Audit — External Sources

Authorities behind this skill's passes and recommended fixes. Cite the relevant entry in the
report's **Sources** section when proposing a fix.

## Standards
- **OWASP API Security Top 10 (2023) — API4:2023 Unrestricted Resource Consumption** — rate
  limiting, payload caps, resource limits (CPU/mem/connections). Backbone of passes `rate-limit`,
  `pagination`. https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/
- **OWASP API Security Top 10 (2023) — index** — https://owasp.org/API-Security/editions/2023/en/0x11-t10/

## Backend performance (passes `fetch`, `cache`, `pooling`, `pagination`, `latency`)
- **"Top 7 Ways to 10x Your API Performance"** — caching, connection pooling, avoiding N+1,
  pagination, JSON serialization, payload compression, async logging. Maps almost 1:1 to this
  skill's passes. https://medium.com/@crok07.benahmed/top-7-ways-to-10x-your-api-performance-caching-connection-pooling-avoiding-n-1-problem-33516b657af2
- **roadmap.sh — Backend Performance Best Practices** — https://roadmap.sh/backend-performance-best-practices
- **Backend performance audit ("health checkup") guidance** — load testing (JMeter/Postman),
  slow-query/index analysis, memory leaks. https://medium.com/@mrunalidalal25/a-performance-audit-is-like-a-health-checkup-for-your-backend-system-1e8a58b9519c

## Caching & pre-fetching (pass `cache`)
- **Speakeasy — Caching in REST API Design** — `Cache-Control`, `ETag`, conditional requests.
  https://www.speakeasy.com/api-design/caching
- **Predictive API Caching and Prefetching** — observe → predict → prefetch → cache; confidence-
  based prefetch. https://medium.com/@meherun.nesa/predictive-api-caching-and-prefetching-2f6e1d17bb96
- **OneUptime — Implementing Prefetching Strategies** — https://oneuptime.com/blog/post/2026-01-25-implement-prefetching-strategies/view
- **GeeksforGeeks — Caching Strategies for API** — cache-aside, write-through, eviction (LRU).
  https://www.geeksforgeeks.org/system-design/caching-strategies-for-api/

## Rate limits, retries, timeouts (passes `rate-limit`, `resilience`)
- **getknit.dev — API Rate Limiting Best Practices** — read `X-RateLimit-*` before hitting limits;
  window types. https://www.getknit.dev/blog/10-best-practices-for-api-rate-limiting-and-throttling
- **Truto — Rate limits & retries across third-party APIs** — jittered exponential backoff,
  honor `Retry-After`, circuit breakers, caching to lower consumption.
  https://truto.one/blog/best-practices-for-handling-api-rate-limits-and-retries-across-multiple-third-party-apis
- **BoldSign — API Retry Mechanism** — backoff, retry caps, idempotency.
  https://boldsign.com/blogs/api-retry-mechanism-how-it-works-best-practices/

## Database — indexing, transactions, locking, migrations (pass `database`)
- **Locking, blocking & deadlocks — isolation levels & retryable patterns** — short transactions,
  consistent lock ordering, retry-safe idempotent writes.
  https://developersvoice.com/blog/database/locking-deadlocks-field-guide/
- **Avoiding deadlocks in Postgres migrations** — migrations take heavy/table locks; `ALTER TABLE`
  blocks reads; expand-contract pattern. https://medium.com/dovetail-engineering/writing-safe-database-migrations-4b19d48029e9
- **SQL Server deadlock prevention (IDERA)** — indexing to reduce scans/contention.
  https://www.idera.com/blogs/how-to-avoid-sql-server-deadlocks/

## Async — background jobs, queues, concurrency (pass `async`)
- **Azure Well-Architected — Background jobs** — offloading, triggers, scaling, reliability.
  https://learn.microsoft.com/en-us/azure/well-architected/reliability/background-jobs
- **BullMQ** — queues, worker concurrency, retries, DLQ (Node). https://bullmq.io/
- **Full Stack Python — Task Queues** — Celery/RQ patterns, when to go async.
  https://www.fullstackpython.com/task-queues.html

## API contract — idempotency, versioning, error format, webhooks (pass `contract`)
- **Zuplo — Implementing Idempotency Keys in REST APIs** — `Idempotency-Key`, UUID v4, persist
  response by key+fingerprint. https://zuplo.com/learning-center/implementing-idempotency-keys-in-rest-apis-a-complete-guide
- **Stripe — Advanced error handling** — stable error codes + status codes (don't return 200 on error).
  https://docs.stripe.com/error-low-level
- **CalibreOS — API Design Principles (REST, idempotency, versioning, error contracts)**.
  https://www.calibreos.com/learn/lld-api-design-principles
- **Webhook best practices — retry logic, idempotency, error handling** — duplicate-event detection,
  fast `200` ack, signatures, DLQ. https://dev.to/henry_hang/webhook-best-practices-retry-logic-idempotency-and-error-handling-27i3

## Observability — logging, metrics, tracing, health (pass `observability`)
- **IBM — Three Pillars of Observability (logs, metrics, traces)**.
  https://www.ibm.com/think/insights/observability-pillars
- **OpenTelemetry best practices (Better Stack)** — instrumentation, trace/span IDs in logs.
  https://betterstack.com/community/guides/observability/opentelemetry-best-practices/
- **Zuplo — API Observability & Monitoring** — percentile latency, per-endpoint error rates, health.
  https://zuplo.com/learning-center/api-observability-monitoring-complete-guide

## Load-testing tooling (Tier 1, `--runtime`)
- **k6** — https://k6.io/docs/  ·  **autocannon** — https://github.com/mcollina/autocannon

> Note: sources retrieved June 2026. Re-verify links if they 404; the techniques (N+1 avoidance,
> cache headers, backoff + `Retry-After`, pooling, pagination) are stable regardless of any single URL.
