# Pass 08 — Background Tasks

**Weight:** 2×

## What this audits
Does the app use `BGTaskScheduler` for legitimate background work
(prefetch, sync, periodic updates)? Or does it do work in non-async
contexts that risks termination?

## Tier 0
```bash
grep -rln --include='*.swift' 'BGTaskScheduler\|BGAppRefreshTask\|BGProcessingTask' <project-root>
plutil -p Info.plist | grep -A 5 BGTaskSchedulerPermittedIdentifiers
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Background tasks registered + scheduled + handle expiration |
| 4 | Used but no expiration handler (tasks killed cleanly) |
| 3 | Background work attempted via `beginBackgroundTask` (deprecated pattern) |
| 2 | App does background work it shouldn't |
| 1 | N/A — no background work needed (most apps; default 5) |

## Pookoo
No background work needed. Pass scores 5/5 by default.

## What NOT to flag
- Apps that don't need background work
