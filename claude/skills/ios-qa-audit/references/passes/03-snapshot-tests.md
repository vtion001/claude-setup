# Pass 03 — Snapshot Tests

**Weight:** 2×

## What this audits
Visual regression coverage. Catches "developer changes Theme.swift and
breaks 12 views" before TestFlight.

## Tier 0
```bash
grep -rln 'SnapshotTesting\|assertSnapshot' <project-root>/*Tests/ 2>/dev/null
grep -E 'pointfreeco/swift-snapshot-testing' Package.resolved 2>/dev/null
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | swift-snapshot-testing integrated; snapshots for every public View; CI catches drift |
| 4 | Snapshots for most major Views |
| 3 | Snapshots for a few Views; partial coverage |
| 2 | Snapshot framework added but not used yet |
| 1 | No snapshot testing |

## Common findings
| Finding | Severity |
|---|---|
| No swift-snapshot-testing dep | **High** for design-system-heavy apps |
| Snapshots exist but reference frames out of date | **Medium** (false-positive risk) |
| Snapshots only for happy-path; no dark mode / dynamic type variants | **Medium** |
| Snapshots not in CI (only run locally) | **Medium** |

## Recommended fix
Add as SPM dep (NEVER auto-add — just recommend):
```
https://github.com/pointfreeco/swift-snapshot-testing
```

Example test:
```swift
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Pookoo

final class HomeViewSnapshotTests: XCTestCase {
    func testHome_light() {
        let view = HomeView().environmentObject(AppState.preview)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone17))
    }
    func testHome_dark() {
        let view = HomeView().environmentObject(AppState.preview)
            .preferredColorScheme(.dark)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone17))
    }
}
```

## What NOT to flag
- Apps where the design system genuinely doesn't change (rare)
- Apps targeting only iPad with no visual variance
