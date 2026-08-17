# /ios-qa-audit — Tech Stack

## Tools

| Tool | Install | What it does |
|---|---|---|
| **XCTest** | bundled with Xcode | Unit + UI tests |
| **Swift Testing** | Xcode 16+ built-in | Modern unit tests; `@Test` macro |
| **swift-snapshot-testing** | SPM `https://github.com/pointfreeco/swift-snapshot-testing` | Visual + structured snapshot regression |
| **Maestro** | already at `~/.maestro/bin/maestro` | E2E flow automation |
| **XCTMetric** | bundled | Perf regression: clock, memory, CPU, app launch |
| **XCUIApplication.performAccessibilityAudit** | iOS 17+ | Apple's built-in a11y audit |
| **xcbeautify** | `brew install xcbeautify` | Pretty xcodebuild output |
| **Code Coverage** | Xcode setting | Per-target line coverage |

## MCP servers

| MCP | Use |
|---|---|
| **XcodeBuildMCP** | Runs builds, reads .xcresult bundles |
| **Maestro MCP** | `maestro mcp` (built into Maestro 2.6+) — agent-driven flow execution |

## Standards

| Standard | URL |
|---|---|
| **XCTest framework** | https://developer.apple.com/documentation/xctest |
| **Swift Testing** | https://developer.apple.com/documentation/testing |
| **Accessibility audit** | https://developer.apple.com/videos/play/wwdc2023/10035/ |
| **XCTMetric** | https://developer.apple.com/documentation/xctest/xctmetric |

## Reference reading

- **Swift Testing vs XCTest** (Crosley): https://blakecrosley.com/blog/swift-testing-vs-xctest
- **Polpiella's a11y audit guide**: https://www.polpiella.dev/xcode-15-automated-accessibility-audits/
- **swift-snapshot-testing docs**: https://github.com/pointfreeco/swift-snapshot-testing
- **Maestro for iOS**: https://docs.maestro.dev/platform-support/ios
- **Apple WWDC23 — Perform accessibility audits for your app**: https://developer.apple.com/videos/play/wwdc2023/10035/
- **Apple WWDC24 — Meet Swift Testing**: https://developer.apple.com/videos/play/wwdc2024/

## Pookoo-specific baseline (per exploration)

- 5 total test files, only ~2 with active tests
- No snapshot tests
- No Maestro flows in `swiftui-ux-audit/flows/`
- A11yAuditTests.swift exists (~21KB) — verify it actually runs
- Code coverage disabled in project.yml

First-run findings:
- **01-xctest-coverage**: 2/5 (some tests but coverage off)
- **03-snapshot-tests**: 1/5 (no swift-snapshot-testing dep)
- **04-maestro-flows**: 1/5 (zero flows)
- **05-performance-regression**: 1/5 (no XCTMetric usage detected)
- **06-accessibility-audit**: depends on whether A11yAuditTests runs
