# iOS Automation Primer

Which tool drives which action. Read this once before Phase 1.

## TL;DR decision table

| Action | Tool | Why |
| --- | --- | --- |
| Boot a simulator | `xcrun simctl boot` | Apple CLI, no deps |
| Build the app for simulator | `xcodebuild build` | Apple CLI, no deps |
| Install the built `.app` | `xcrun simctl install` | Apple CLI |
| Launch/terminate the app | `xcrun simctl launch / terminate` | Apple CLI |
| Screenshot a screen | `xcrun simctl io <UDID> screenshot` | Apple CLI, PNG, fastest |
| Deep-link in via URL scheme | `xcrun simctl openurl <UDID> <url>` | Apple CLI |
| Tap a tab / button / text | **Maestro** (`tapOn`) | YAML-first, forgiving on text match, no a11y identifier required |
| Wait for an element to appear | **Maestro** (`assertVisible`) | YAML-first, retries built in |
| Scroll a list | **Maestro** (`swipe`) | YAML-first |
| Inspect the accessibility tree at runtime | **XCUITest** | Apple's only API for this |
| Run accessibility audit (contrast, hit-region, dynamic type, etc.) | **XCUITest** `performAccessibilityAudit(for: .all)` | iOS 17+, Apple's first-party axe-core equivalent |
| Trace cold-launch time / frame drops | `xcrun xctrace record --template 'Time Profiler'` | Apple CLI, Instruments-backed |
| Validate design tokens in source | `grep`/`rg` against the detected `Theme.swift` | Static, no simulator needed |

## Why Maestro is the primary driver

- **Single binary install**: `brew install maestro` — no Appium server, no XCUITest target boilerplate required for basic navigation.
- **YAML flows** are reviewable diffs, not Swift code, so changes to the audit's nav script aren't entangled with the app target.
- **Text-locator matching** works even when the app has zero `.accessibilityIdentifier` calls (the common case in greenfield SwiftUI projects).
- **Auto-retry** smooths over SwiftUI's hard-to-pin animation timings.
- **Cross-platform**: same tool can later audit Android variants.

## Why XCUITest is still required for one thing

`XCUIApplication.performAccessibilityAudit(for: .all)` is **only** callable from inside a UI-test target running in the same process as the app. It returns issues for:

- `.contrast` — color contrast below WCAG thresholds
- `.elementDetection` — overlapping/occluded elements
- `.hitRegion` — tap targets below the 44pt minimum
- `.sufficientElementDescription` — missing/poor a11y labels
- `.dynamicType` — text that doesn't scale with the user's Dynamic Type setting
- `.textClipped` — text truncated when it shouldn't be
- `.trait` — incorrect accessibility traits (e.g. a button missing the `.button` trait)

This is the iOS analogue of `axe-core` for the web. No Maestro/JS equivalent exists. Available iOS 17+. If the project targets older iOS, the a11y pass is skipped with a warning.

## Why not Appium?

Appium would work but:

- Heavyweight: requires running an Appium server process (`appium` daemon) with the XCUITest driver installed
- WebDriver translation makes it 50% slower than direct XCUITest calls
- Tests are written in Node/Python/Java/Ruby — adds a language hop
- Maestro covers the same surface for navigation with a fraction of the setup

Use it if the user explicitly asks; otherwise stay with Maestro + XCUITest.

## Why not Detox?

Detox is a React Native testing tool. SwiftUI projects don't benefit; skip.

## Why not EarlGrey / KIF?

Older Google/LinkedIn frameworks. XCUITest has caught up, and Maestro is more ergonomic. Skip unless the project already uses them.

## Failure modes to watch

- **Simulator not booted** → `simctl install` errors. The skill's `boot-simulator.sh` is idempotent; always call it first.
- **App not installed** → `simctl launch` errors with `FBSOpenApplicationServiceErrorDomain`. Always install before launch.
- **Maestro can't find a tab label** → user has changed the visible label OR is using SF Symbols only. The skill should fall back to coordinate taps using `xcrun simctl io tap <x> <y>` and warn the user.
- **`performAccessibilityAudit` not found** → deployment target < iOS 17. Skip the pass and warn.
- **`xcodebuild` schemes ambiguous** → multiple schemes detected; the skill picks the first that builds an iOS app target and logs the choice for the user to override via `--scheme`.
