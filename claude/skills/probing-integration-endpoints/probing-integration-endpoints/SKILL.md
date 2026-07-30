---
name: probing-integration-endpoints
description: Use when you need to find out whether specific data is reachable through a third-party integration or API you already authenticate to (a CRM's connected valuation/market/reporting/vendor data, etc.), the docs are thin, or the official API seems not to expose it but the vendor's web app clearly renders it. Keywords — API surface enumeration, discovery trick, describe classes, connection state, deep link, XHR/fetch interception, reverse-engineer web app backend, structured JSON, CoreLogic/REX/vendor data.
---

# Probing Integration Endpoints

## Overview

Third-party integrations rarely expose through their API everything their own web app shows. Before concluding "the API can't give us X," systematically map what's *actually* reachable — the documented API surface **and** the private backend endpoints the vendor's web app calls.

**Core principle:** a vendor's web app is a live client of a richer API than the one handed to you. Data you see *rendered* is *fetched* from endpoints you can usually observe and replicate — so capture the JSON, don't screenshot the pixels.

## When to Use

- "Can we pull `<data>` from `<vendor>` into our dashboard?" and you're unsure the API exposes it.
- The API returns only attributes or a **deep link**, but the web app renders the full report (valuation, comparables, market stats).
- Docs are thin or lag the real surface.
- **Before** reporting "the API doesn't have X" — cross-validate the negative.

**Not for:** public, well-documented APIs where docs are authoritative; anything you lack authorization to probe.

## Methodology

### Phase 1 — Enumerate the real surface (don't trust docs)
1. **Baseline auth** with one trusted read, so later nulls mean *data-absence*, not auth failure.
2. **Leak the surface via errors:** call a bogus class/method/endpoint — many APIs return the full valid-class / available-method list in the 400 (REX does this).
3. **`describe`/introspect every candidate class:** read *every* method's parameters — hidden `include_*` flags, `type` enums.
4. **Leak enum values:** pass a bogus value (`type: "__x__"`) → the error lists the valid ones.
5. **Capability scan the *whole* surface** (all classes, not just vendor-named ones): grep for `valuation|estimate|avm|comparable|cma|market|median|report|sale|price|yield`.

### Phase 2 — Confirm the source, then probe
6. **List connected third-party services + state** (`connected`, token alive). A live connection means the *source* exists even if a data method doesn't.
7. **Call each candidate with a REAL identifier;** inspect the actual response shape. Distinguish **returns the numbers as data** from **returns only a deep link / bare attributes**.
8. **Cross-validate a negative** before reporting it: a null can be a stale copy, wrong/unlinked identifier, or permissions — re-check a second way.

### Phase 3 — Web-app-only fallback (the high-value technique)
When the API only deep-links into the vendor's web app: that app is a SPA that fetches the report from a **private backend JSON API**. Observe and replicate it — **intercept the XHR/fetch, do NOT scrape the rendered DOM.**

1. Server-side, open the tokenized deep link in a headless browser (Playwright).
2. Listen on `response`; filter to `xhr`/`fetch` + `application/json`; log `method + host+path` and which data-keys each body contains.
3. Identify the endpoints returning the structured data; extract JSON via `page.evaluate(fetch)` in-session, or replay with the session cookies/bearer.

```js
// Server-side: capture the JSON the vendor's SPA fetches from its private backend.
const hits = []
page.on('response', async (res) => {
  if (!['xhr', 'fetch'].includes(res.request().resourceType())) return
  if (!/json/i.test(res.headers()['content-type'] || '')) return
  const body = await res.text().catch(() => '')
  const keys = ['estimate', 'confidence', 'comparable', 'medianPrice', 'salePrice']
    .filter((k) => new RegExp(`"${k}"`, 'i').test(body))
  if (keys.length) hits.push({ endpoint: new URL(res.url()).pathname, keys })
})
await page.goto(tokenizedDeepLink, { waitUntil: 'domcontentloaded' })
await page.waitForLoadState('networkidle').catch(() => {})
await page.waitForTimeout(6000)
// hits → the backend endpoints + which data each returns. Replicate those calls.
```

## Gates — raise BEFORE building (Phase 3 especially)

- **ToS / licensing (gating):** replicating a vendor's private web API is usually outside your API license and often breaches ToS + any data-vendor redistribution terms — *independent of technical feasibility*. It's a legal/business decision: get explicit owner sign-off first, and prefer a sanctioned data API if one exists.
- **Token is a secret:** deep-link URLs embed a live credential — never log, cache, or render it; keep the session server-side.
- **PII:** vendor payloads often carry owner/occupier fields — exclude them from anything stored or displayed.
- **Fragility:** private endpoints change silently — needs an owner + monitoring.

## Quick Reference

| Goal | Probe |
|------|-------|
| Real API surface | bogus class/method → error leaks the list; `describe()` each class |
| Hidden params / enums | `describe()`; pass a bogus enum value → error leaks valid values |
| Does the source exist? | list connections + token-alive state |
| Data vs. just a link? | call with a real id; inspect the response shape |
| Web-app-only data | headless + intercept XHR JSON; replicate the endpoints |

## Common Mistakes

- Trusting docs over the live surface — enumerate it.
- Reporting "the API doesn't have X" off one null (stale / unlinked / wrong id) — cross-validate.
- **DOM-scraping or screenshotting the rendered report when the structured JSON is right there in the network tab** — capture the JSON instead.
- Building the web-app replication before raising the ToS/licensing gate — gate first.
- Logging the deep-link token or leaving it in client-served HTML.
