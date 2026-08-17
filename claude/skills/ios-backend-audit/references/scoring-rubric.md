# /ios-backend-audit — Scoring Rubric

Extends `_ios-shared/scoring-rubric-shared.md`. Acronym: **BNH-iOS**.

## Pass Weights

Total: **19** (max raw 95).

| Pass | Weight | Rationale |
|---|---|---|
| 01-url-session-patterns | 2× | Foundation; bad patterns cascade |
| 02-swift-concurrency-correctness | 3× | Data races crash silently or corrupt state |
| 03-sendable-conformance | 2× | Swift 6 strict mode requirement |
| 04-persistence-layer | 3× | Wrong choice = years of pain to migrate |
| 05-retry-backoff | 2× | Resilience vs server overload |
| 06-request-cancellation | 2× | Memory + battery; leaked tasks are common |
| 07-cache-headers | 1× | Bandwidth + perf; not safety-critical |
| 08-background-tasks | 2× | Pre-load, sync, scheduled work — correctness-critical |
| 09-network-reachability | 2× | UX during airplane mode / poor coverage |
