# Pass 05 — Performance Regression Tests

**Weight:** 2×

## What this audits
XCTMetric-based perf tests. Catches "shipped a regression that made app
launch 800ms slower".

## Tier 0
```bash
grep -rln --include='*.swift' 'measure(metrics:' <project-root>/*Tests/
grep -rln --include='*.swift' 'XCTClockMetric\|XCTMemoryMetric\|XCTCPUMetric\|XCTApplicationLaunchMetric' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | App launch + every critical screen has perf test with baseline |
| 4 | App launch + primary flows |
| 3 | Some perf tests but no baselines (just measurement) |
| 2 | Perf test scaffolding without enforcement |
| 1 | No perf tests |

## Common findings
| Finding | Severity |
|---|---|
| No `XCTApplicationLaunchMetric` test | **High** |
| Perf tests exist but no baselines committed (`.xcresult` only) | **Medium** |
| Perf test runs only on developer machine, not CI | **Medium** |

## Recommended fix
```swift
final class LaunchPerformanceTests: XCTestCase {
    func testAppLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
```

Commit baseline `.xcresult` references; CI fails if a regression of >X%
is detected.

## What NOT to flag
- Apps where launch time isn't user-visible (background services)
- Tests that measure but don't enforce baseline (sometimes intentional —
  measurement before enforcement)
