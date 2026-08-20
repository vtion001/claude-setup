# Pass 09 — Network Reachability

**Weight:** 2×

## What this audits
Does the app show appropriate UI for offline state? Queue pending
actions? Use `NWPathMonitor` instead of polling?

## Tier 0
```bash
grep -rln --include='*.swift' 'NWPathMonitor\|Reachability\|isReachable' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | `NWPathMonitor` integration; offline UI; queued retries when connectivity returns |
| 4 | Monitor present; partial UI awareness |
| 3 | Reachability awareness but no offline UI |
| 2 | Crashes / hangs in airplane mode |
| 1 | No reachability handling at all |

## Recommended fix
```swift
import Network

@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: .global(qos: .background))
    }
}
```

## What NOT to flag
- Apps that work fully offline (e.g. local-only tools)
- Apps where network is only used for non-critical telemetry
