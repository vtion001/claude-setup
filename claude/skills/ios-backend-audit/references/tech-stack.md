# /ios-backend-audit — Tech Stack

## Tools

| Tool | Install | What it does |
|---|---|---|
| **swift-async-algorithms** | Apple SPM | Async stream operators (chunk, throttle, debounce, zip) |
| **GRDB.swift** | SPM `https://github.com/groue/GRDB.swift` | High-perf SQLite library; outperforms SwiftData/Realm on benchmarks |
| **Proxyman** | `brew install --cask proxyman` | HTTPS debugging proxy; cert-pinning runtime checks |
| **Instruments Network template** | bundled | Trace network I/O, response time distribution |
| **swift-collections** | Apple SPM | Optimized collection types (Deque, OrderedSet) |

## MCP servers

| MCP | Use |
|---|---|
| **XcodeBuildMCP** | Build + test runner |
| **Proxyman MCP** | Beta — for runtime traffic queries (verify before depending) |

## Standards

| Standard | URL |
|---|---|
| **Swift 6 Concurrency** | https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/ |
| **Apple URL Loading System** | https://developer.apple.com/documentation/foundation/url_loading_system |
| **Swift Concurrency Manifesto** | https://forums.swift.org/t/swift-concurrency-roadmap/41611 |
| **AsyncSequence / AsyncStream** | https://developer.apple.com/documentation/swift/asyncsequence |
| **Sendable** | https://developer.apple.com/documentation/swift/sendable |
| **SwiftData** | https://developer.apple.com/documentation/swiftdata |
| **BGTaskScheduler** | https://developer.apple.com/documentation/backgroundtasks |

## Reference reading

- **Async/await full toolkit** (Emerge Tools) — https://www.emergetools.com/blog/posts/swift-async-await-the-full-toolkit
- **Retry patterns** (Young Gao) — https://dev.to/young_gao/retry-patterns-that-actually-work-exponential-backoff-jitter-and-dead-letter-queues-75
- **SwiftData vs Realm benchmarks** — https://www.emergetools.com/blog/posts/swiftdata-vs-realm-performance-comparison
- **GRDB performance** — https://github.com/groue/GRDB.swift/wiki/Performance
- **Apple WWDC22 — Eliminate data races using Swift Concurrency** — https://developer.apple.com/videos/play/wwdc2022/110351/
- **Apple WWDC24 — Migrate to Swift 6**

## Pookoo-specific baseline

Per exploration:
- `GmailService` is `@MainActor` but does blocking OAuth I/O — **02 High**
- `LocalAIService` is an `actor` (correct) — **02 strong positive**
- `BoardingPassExtractor` does sync Vision ML from async contexts — **02 Medium**
- All persistence is UserDefaults + FileManager — **04 OK for current scale but flag growth path**
- No retry/backoff anywhere — **05 Medium**
- No request cancellation visible — **06 Medium**
- Zero use of `BGTaskScheduler` — **08 N/A** (no background work needed)
- No reachability handling — **09 Medium**
