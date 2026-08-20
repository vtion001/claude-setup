# Pass 01 — URLSession Patterns

**Weight:** 2×

## What this audits
Is URLSession used idiomatically? Or are there anti-patterns (one
session per request, missing timeouts, no delegate, force-unwrapped
URLs)?

## Tier 0
```bash
# Direct URLSession.shared use vs shared singleton
grep -rn --include='*.swift' 'URLSession(configuration:\|URLSession\.shared' <project-root>

# URL force-unwrap
grep -rn --include='*.swift' 'URL(string: "[^"]*")!' <project-root>

# Timeout configuration
grep -rn --include='*.swift' 'timeoutIntervalFor\|timeoutInterval' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | One shared session per origin/purpose, explicit timeouts, no force-unwrap, custom delegate when needed |
| 4 | Mostly clean; 1-2 raw `URLSession.shared` in tests |
| 3 | Inconsistent — mix of `.shared` and custom sessions |
| 2 | `URLSession(configuration:)` per request (leaks); force-unwrapped URLs |
| 1 | Synchronous URL loading (`data(contentsOf:)`) in production code |

## Common findings
| Finding | Severity |
|---|---|
| `URL(string: "...")!` force-unwrap on user input | **Critical** (crash on malformed) |
| `URLSession(configuration:)` per request | **Medium** (leak) |
| Missing `timeoutIntervalForRequest` | **Medium** (hangs on slow networks) |
| `Data(contentsOf: URL)` synchronous load | **High** (blocks thread) |

## What NOT to flag
- `URL(string:)` with known-good static URLs (no `!` needed via optional binding)
- Apps using AppAuth-iOS for OAuth (manages session correctly internally)
