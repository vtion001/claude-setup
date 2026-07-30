# Tier 1a — Live Traffic Observation (Playwright + Burp Suite)

Used under `--runtime` when Playwright MCP and/or Burp Suite MCP are connected. The goal is the
**through-the-app** view: real API calls in realistic sequences, with real response headers and
timing — the things static grep and synthetic load can't see (waterfalls, duplicate requests,
cache hits, missing compression).

Authorization: localhost auto-OK. Any other host needs explicit confirmation + the rate cap.
No attack payloads — abuse testing belongs to `/security-audit`.

## Setup
- If **Burp** is connected, point the browser at the Burp `proxy` so every request is captured in
  proxy history with full headers and timing.
- If only **Playwright** is connected, rely on the Resource Timing API + `browser_network_requests`.

## Workflow

### 1. Drive the real user flows
Use `browser_navigate` (then `browser_click` / form fill) to walk the journeys that exercise the
inventory endpoints — e.g. for mfgcalc: open the estimator → add modules → trigger a quote/PDF.
Realistic sequences surface N+1 and waterfalls that a single endpoint hit won't.

### 2. Read per-request timing (Playwright)
Run via `browser_evaluate`:
```js
() => performance.getEntriesByType('resource')
  .filter(e => e.initiatorType === 'xmlhttprequest' || e.initiatorType === 'fetch')
  .map(e => ({
    url: e.name,
    ms: Math.round(e.duration),
    transfer: e.transferSize,        // 0 ⇒ served from cache
    encoded: e.encodedBodySize,      // compressed size over the wire
    decoded: e.decodedBodySize       // uncompressed; encoded≈decoded ⇒ NO compression
  }))
  .sort((a, b) => b.ms - a.ms);
```
Read from this:
- **Slowest endpoints** (`ms`) → Pass `latency`.
- **`transfer === 0` on a repeat navigation** → cache hit → Pass `cache` healthy; never 0 ⇒ no caching.
- **`encoded ≈ decoded`** → response not compressed → Pass `pagination` (compression) finding.
- **Many rows to the same endpoint family in one flow** → N+1 / over-fetch → Pass `fetch`.
- **Duplicate identical URLs** → redundant fetching → Pass `fetch`/`cache`.

### 3. Inspect response headers (Burp proxy)
For each distinct API response in proxy history, check:
| Header | Pass | Finding if… |
|--------|------|-------------|
| `Cache-Control`, `ETag`, `Last-Modified` | `cache` | absent on a cacheable GET |
| `X-RateLimit-*`, `Retry-After` | `rate-limit` | absent (client is flying blind) |
| `Content-Encoding: gzip\|br` | `pagination` | absent on large JSON |
| `Content-Length` | `pagination` | very large unbounded list payload |

### 4. Confirm with Burp Repeater
Send one endpoint to `repeater` and replay 3–5×:
- Does a conditional replay return `304`? → caching works.
- Does latency stay flat or drop? → flat-and-slow ⇒ no server cache (Pass `cache`/`latency`).
- Is the body compressed? → confirms the `Content-Encoding` reading.

### 5. (Optional) Throughput via Burp Intruder
For the **capacity** question only, a rate-capped `intruder` burst on one endpoint shows whether
inbound throttling engages (`429`) or the server degrades. Respect the rate cap; authorized hosts
only. Deeper DoS/abuse analysis → `/security-audit` Pass 14.

## Output
Save the timing table and notable responses to `backend-audit/evidence/`. Feed the slow/uncached
endpoints into Tier 1b (`scripts/loadtest.md`) for p95 under load, then score the passes.
