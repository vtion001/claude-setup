# Pass 09 — Accessibility (XCUI native audit)

**Weight:** 2×

## What this audits

Apple's first-party accessibility audit, the iOS analogue of `axe-core` for the web. Available iOS 17+. If the project's deployment target is below iOS 17, this pass is **skipped with a warning** — do NOT try to backport.

## Tier 1 (runtime — only XCUI can do this)

Add a UI-test target to the project (or use the one bootstrapped by `--bootstrap`). The test method:

```swift
// scripts/a11y-audit-runner.swift (template)
import XCTest

final class A11yAuditTests: XCTestCase {
    func testFullAuditAllTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // For each tab, perform the audit and write results to a JSON file.
        // The skill provides the tab list via launch-environment.
        let tabs = (ProcessInfo.processInfo.environment["AUDIT_TABS"] ?? "")
            .split(separator: ",").map(String.init)

        var aggregated: [[String: Any]] = []

        for tab in tabs {
            // Naïve: tap by visible label first (matches what the user sees)
            let tabButton = app.buttons[tab].firstMatch
            if tabButton.exists {
                tabButton.tap()
            }
            // give SwiftUI a beat to settle
            _ = app.wait(for: .runningForeground, timeout: 2)

            try app.performAccessibilityAudit(for: .all) { issue in
                aggregated.append([
                    "tab": tab,
                    "description": issue.compactDescription ?? "",
                    "type": "\(issue.auditType)",
                    "element": issue.element?.debugDescription ?? "nil"
                ])
                return true // continue collecting (don't fail the test)
            }
        }

        let outURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["AUDIT_OUTPUT_PATH"] ?? "/tmp/a11y.json")
        let data = try JSONSerialization.data(withJSONObject: aggregated, options: [.prettyPrinted])
        try data.write(to: outURL)
    }
}
```

The skill runs this via `xcodebuild test -only-testing:<UITestTarget>/A11yAuditTests/testFullAuditAllTabs -destination ...` with environment vars wired through `-test-arguments` or `xcconfig` (`AUDIT_TABS`, `AUDIT_OUTPUT_PATH`).

## Audit types collected

`XCUIAccessibilityAuditType.all` covers seven categories:

| Type | What it catches |
|---|---|
| `.contrast` | WCAG contrast violations on visible text |
| `.elementDetection` | Overlapping or occluded elements |
| `.hitRegion` | Tap targets below the 44pt minimum |
| `.sufficientElementDescription` | Missing/poor accessibility labels |
| `.dynamicType` | Text that doesn't scale with Dynamic Type |
| `.textClipped` | Text truncated where it shouldn't be |
| `.trait` | Wrong/missing accessibility traits (e.g. `.button` on a Button) |

## Tier 2 (AI)

Read the JSON output, group findings by audit type and by tab, identify root-cause patterns. Cross-reference each finding to a source file by mapping the element's a11y label or hierarchy to the view that renders it.

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Zero findings across all 7 audit types on every tab |
| 4 | < 5 total findings, none Critical |
| 3 | 5–15 findings OR 1 Critical (contrast on a primary CTA) |
| 2 | 16–30 findings OR 2+ Critical |
| 1 | > 30 findings OR systemic Dynamic Type failure |

## Severity mapping for XCUI findings

| Audit type | Default severity | When it escalates |
|---|---|---|
| `.contrast` | High | Critical when on primary CTA / form labels |
| `.hitRegion` | High | Critical when on primary CTA |
| `.sufficientElementDescription` | Medium | High when on interactive element |
| `.dynamicType` | High (legal risk) | Critical for body text |
| `.textClipped` | Medium | High when label is interactive |
| `.elementDetection` | Medium | High when occlusion breaks tappability |
| `.trait` | Medium | High when trait is missing on a primary action |

## Common findings + recommended fixes

| Finding | Fix |
|---|---|
| Contrast fail on `.foregroundColor(.gray)` body text | Move to `.foregroundColor(Color.pukaTextSecondary)` (token) |
| Hit region 32×32 on icon-only button | Wrap in 44pt frame: `.frame(minWidth: 44, minHeight: 44)` |
| Missing `.accessibilityLabel` on `Image(systemName: "xmark")` close button | Add `.accessibilityLabel("Close")` |
| Dynamic Type fail on `.font(.system(size: 14))` | Replace with a token bound to a `.font(.subheadline)` style |
| Text clipped at smaller widths | Add `.lineLimit(nil)` and `.minimumScaleFactor(0.8)` |
| Button missing `.button` trait | Almost always means the element is a `Text` with `.onTapGesture` — convert to `Button` |

## When this pass is skipped

- Deployment target < iOS 17 → skip + warn, surface in report.
- No UI-test target and `--bootstrap` was not invoked → emit "Add a UI-test target with `--bootstrap` to enable Pass 09".
- Maestro can't navigate to a tab (e.g. label changed) → skip that tab and warn.

## What NOT to flag from raw XCUI output

- Findings on internal `_UIKit` host views (XCUI sometimes surfaces these on iOS 18+; filter via the issue's `element` description starting with `_`).
- Duplicate findings — dedupe by `(tab, type, element label)`.
- System keyboard contrast findings — those are Apple's, not yours.
