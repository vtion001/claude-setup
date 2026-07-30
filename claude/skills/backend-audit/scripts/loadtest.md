# Tier 1b — Synthetic Load Testing (`--runtime`)

Only runs when the user passes `--runtime` AND a confirmed, owned `APP_URL`. Localhost is
auto-authorized; any other host needs explicit confirmation and a rate cap (default 50 req/s).
This measures the thing static analysis can't: actual latency under **concurrent load**.

> Prefer **Tier 1a** (`scripts/browser-trace.md` — Playwright + Burp) first to observe real
> traffic and headers and find the slow/uncached endpoints; then load-test those here for p95.

## Prerequisite (use whichever is installed)
- **autocannon** (Node): `npm i -g autocannon` — simplest, zero config.
- **k6** (Go binary): https://k6.io/docs/ — best for ramps and thresholds.

## Quick latency check (autocannon)
```bash
# 20 connections, 20s, per-endpoint. Capture p50/p95/p99 + req/s + non-2xx.
autocannon -c 20 -d 20 -l "$APP_URL/api/quotes"
```
Read from output: `Latency` (p50/p97.5/p99), `Req/Sec`, and the `2xx`/`Non 2xx` counts.

## Ramped test with pass/fail budget (k6)
```js
// save as /tmp/ba-loadtest.js ; run: k6 run /tmp/ba-loadtest.js
import http from 'k6/http';
import { check } from 'k6';
export const options = {
  stages: [
    { duration: '10s', target: 10 },   // ramp up
    { duration: '20s', target: 20 },   // sustain
    { duration: '5s',  target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // p95 latency budget = 500ms (tune per endpoint)
    http_req_failed:   ['rate<0.01'],  // <1% errors
  },
};
const BASE = __ENV.APP_URL;
const PATHS = (__ENV.PATHS || '/api/quotes').split(',');
export default function () {
  for (const p of PATHS) {
    const res = http.get(`${BASE}${p}`);
    check(res, { 'status 2xx': (r) => r.status >= 200 && r.status < 300 });
  }
}
```
```bash
APP_URL="$APP_URL" PATHS="/api/quotes,/api/items" k6 run /tmp/ba-loadtest.js
```

## Interpreting results (feeds passes 2, 3, 8)
- **p95 > budget** (default 500 ms) → Pass `latency` score ≤ 3; investigate slow query / N+1.
- **Second identical GET not faster than first** → Pass `cache`: caching absent/ineffective.
- **Latency cliff or connection-timeout errors as load rises** → Pass `pooling`: pool exhaustion.
- **If query logging / APM is available**, capture queries-per-request: if it grows with the
  number of returned rows, Pass `fetch` N+1 is **confirmed** (not just suspected).

## Confirming N+1 directly (when you control the DB)
- MySQL: `SET GLOBAL general_log='ON';` hit the endpoint once, count queries, then `'OFF'`.
- Postgres: set `log_statement='all'` for the session, tail the log during one request.
- Laravel: `DB::enableQueryLog()` → `count(DB::getQueryLog())`. Django: `len(connection.queries)`.

## Safety
- Never load-test a host the user does not own. Third-party/production = blocked unless explicitly
  authorized; keep the rate cap and a short duration.
- Clean up any rows created by POST tests. Record the run output into `backend-audit/evidence/`.
