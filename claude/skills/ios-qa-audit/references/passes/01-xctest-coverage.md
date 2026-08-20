# Pass 01 — XCTest Coverage

**Weight:** 3×

## What this audits
Count of XCTest methods. Code coverage % per target (if gathered).
Risk-weighted coverage (critical paths over total %).

## Tier 0
```bash
# Count XCTest methods
grep -rln --include='*.swift' 'func test' <project-root>/*Tests/

# Check if coverage is enabled
grep -E 'gatherCoverageData|CODE_COVERAGE' project.yml *.xcodeproj/project.pbxproj 2>/dev/null
```

## Tier 1 (runs `xcodebuild test`)
```bash
xcodebuild test -project <Project>.xcodeproj -scheme <Scheme> \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -enableCodeCoverage YES \
    -resultBundlePath .test-results.xcresult
```

Read `.xcresult` for pass/fail + coverage per target.

## Scoring
| Score | Criteria |
|---|---|
| 5 | 80%+ coverage on Services, 60%+ on Views, all critical paths covered, all green |
| 4 | 60-80% Services coverage; minor gaps |
| 3 | 30-60% Services coverage; critical paths covered |
| 2 | <30% coverage on Services |
| 1 | Coverage disabled in project.yml OR <10 test methods total |

## Common findings
| Finding | Severity |
|---|---|
| `gatherCoverageData: false` | **High** |
| Service file with 0 test methods (e.g., `LocalAIService`, `GmailService`) | **High** |
| Tests exist but don't pass | **Critical** |
| Tests use sleeps instead of expectations | **Medium** |
| Tests depend on network without mocking | **High** (flaky) |

## Pookoo-specific
Per exploration: coverage disabled, only `BoardingPassExtractorTests` + `ItineraryGeneratorTests` active. Services like `LocalAIService`, `GmailService`, `LocationService` have zero unit tests.

## What NOT to flag
- Stub files left by Xcode templates (`PukaTests.swift` with 1 line)
- View test files (XCTest is poor at view testing — defer to snapshot)
