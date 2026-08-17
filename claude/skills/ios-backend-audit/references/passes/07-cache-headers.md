# Pass 07 — Cache Headers / URLCache

**Weight:** 1×

## What this audits
Does the app respect server cache headers? Or refetch the same
resource every time?

## Tier 0
```bash
grep -rln --include='*.swift' 'URLCache\|cachePolicy\|URLRequest\.CachePolicy' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | URLCache configured; default `.useProtocolCachePolicy`; respects ETags |
| 4 | URLCache present; minor misuse |
| 3 | No explicit caching; relies on iOS defaults |
| 2 | `cachePolicy = .reloadIgnoringLocalCacheData` everywhere |
| 1 | URLCache zeroed out or `removeAllCachedResponses()` called frequently |

## What NOT to flag
- Endpoints that explicitly shouldn't cache (token refresh, real-time data)
