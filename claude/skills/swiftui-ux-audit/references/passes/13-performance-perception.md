# Pass 13 — Performance Perception

**Weight:** 1×

## What this audits

How fast the app *feels*, not necessarily how fast it is on paper. Cold launch, scroll smoothness, transition fluidity, and waiting-state design.

## Tier 1 (runtime, Instruments-backed)

`scripts/perf-trace.sh` wraps `xcrun xctrace`:

```bash
xcrun xctrace record \
  --template 'Time Profiler' \
  --target-stdout - \
  --output ./swiftui-ux-audit/.trace/launch.trace \
  --launch -- <bundle.id>
```

For frame drops, use a SwiftUI-friendly Instruments template:

```bash
xcrun xctrace record \
  --template 'SwiftUI' \
  --output ./swiftui-ux-audit/.trace/scroll.trace \
  --time-limit 10s \
  --attach <bundle.id>
```

The skill parses the `.trace` bundles or sidecar JSON (xctrace supports `--output --format json`-ish in newer versions; fall back to parsing the `.tracev3` via `Instruments.app` if needed) and extracts:

- **Cold launch time** — median of 5 runs, target < 2.0s
- **Largest contentful image** — first-frame-render of Home, target < 1.5s
- **Frame drops during scroll** — count of frames > 16.67ms (60fps) or > 8.33ms (120fps for ProMotion)
- **Memory at idle** — `ru_maxrss` after settle
- **Network request count per tab landing** — too many = janky perception

## Tier 2 (AI on screenshot of loading/empty states)

1. **First-paint quality** — is what the user sees in the first 200ms recognizable as the app, or a blank screen?
2. **Skeleton vs spinner** — long fetches use skeleton/shimmer; short waits use spinner. Mismatch reads as poor judgment.
3. **Progressive disclosure** — does content stream in (first text, then images) or wait for everything?
4. **Optimistic UI** — does an action feel instant before the server confirms?
5. **Loading state design** — does the loading state look like part of the design, or a placeholder?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | < 1.5s cold launch, zero scroll drops, every wait has a designed state |
| 4 | < 2.0s cold launch, < 5 drops on heavy tab, designed loading states |
| 3 | < 2.5s cold launch, occasional drops, generic loading states |
| 2 | > 2.5s cold launch OR consistent drops on scroll OR blank-screen loading |
| 1 | > 3.5s cold launch OR app hangs at launch |

## Common findings + severity

| Finding | Severity |
|---|---|
| Cold launch > 2.5s | High |
| Scroll frame drops > 10 in 10s on a list tab | High |
| Blank screen during fetch (no skeleton or spinner) | High |
| Optimistic UI absent on like/save actions | Medium |
| Image loading without placeholder | Low |
| Network requests on tab switch (should be cached) | Medium |

## Recommended fixes

- Move expensive work off the launch path; use `.task { await … }` on the view that needs it.
- Add `.scrollContentBackground(.hidden)` and reuse cells in `LazyVStack` properly.
- Cache images with `AsyncImage(... transaction:)` or a token-level cache layer.
- Add `ShimmerView`-style skeletons for any wait > 300ms.
- Add optimistic state mutation before the network call.

## What NOT to flag

- Cold launch on cold-cache simulator runs (always slower than device); use the median, not max
- One-time first-launch delays (initial data download, account setup)
