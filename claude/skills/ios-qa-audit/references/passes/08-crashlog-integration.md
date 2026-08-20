# Pass 08 — Crashlog Integration

**Weight:** 1×

## What this audits
Are post-deploy crashes captured + actionable? TestFlight ships built-in
crash aggregation; this pass checks whether the team consumes it.

## Tier 0
- Look for Sentry / Crashlytics / Bugsnag SDK in deps
- Look for `.xcconfig` settings for symbol-upload automation
- Look for CI step that uploads dSYMs

## Scoring
| Score | Criteria |
|---|---|
| 5 | Crashlytics/Sentry SDK + dSYM upload in CI + crash-free-rate dashboard |
| 4 | TestFlight crashes monitored manually; no SDK |
| 3 | TestFlight only, not actively reviewed |
| 2 | dSYMs not uploaded → crashes show as hex addresses |
| 1 | No crash aggregation infrastructure |

## Common findings
| Finding | Severity |
|---|---|
| dSYMs not uploaded | **High** (every crash unreadable) |
| Crash SDK installed but no alerting | **Medium** |
| No baseline crash-free-rate target | **Low** |

## What NOT to flag
- Apps still in alpha / fewer than 10 users
- TestFlight-only apps that haven't shipped publicly yet
