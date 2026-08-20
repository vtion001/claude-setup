---
name: ios-dev
description: >
  Router for iOS/Swift/Apple-platform development, audits, and App Store Connect —
  App Intents, SwiftUI, SwiftData, WidgetKit, Swift Concurrency, background execution,
  macOS menubar/SwiftPM packaging, and every ios-*/asc-* specialist audit. Use on
  "/ios-dev", "help with my iOS app", "audit my SwiftUI app", "App Store Connect",
  "TestFlight", "build/archive/submit my app", or any iOS/Swift/macOS-app request
  where you're not sure which specific specialist skill applies.
---

# iOS / Swift / Apple Dev — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool. If it clearly maps to one specialist, invoke
it directly. If genuinely ambiguous, ask one short question before invoking anything.
For "audit the whole app," prefer `ios-audit-pipeline` (it already fans out to 6 audits
in parallel and merges the report) over invoking individual audits one at a time.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Exposing app actions/data to Siri, Shortcuts, Spotlight, widgets, Apple Intelligence | `app-intents` |
| Generating App Store release notes from git history | `app-store-changelog` |
| Running/designing `asc` CLI commands against App Store Connect | `asc-cli-usage` |
| Whether an app is ready to submit, driving the release flow | `asc-release-flow` |
| TestFlight distribution, groups, testers, What to Test notes | `asc-testflight-orchestration` |
| Localized "What's New" release notes from git log/bullets | `asc-whats-new-writer` |
| Build, archive, export, upload, version/build numbers via `asc xcode` | `asc-xcode-build` |
| BGTaskScheduler, background execution, background task assertions | `background-execution` |
| VoiceOver, Dynamic Type, assistive tech, accessibility patterns | `ios-accessibility` |
| "Audit my whole iOS app" — runs all 6 audits in parallel, merges report | `ios-audit-pipeline` |
| URLSession, Swift Concurrency correctness, Combine, persistence, backend/networking audit | `ios-backend-audit` |
| Swift API Design Guidelines, SwiftLint/SwiftFormat/Periphery code review | `ios-code-review` |
| Build/run/debug the app on a booted simulator via XcodeBuildMCP | `ios-debugger-agent` |
| Setting up/validating MCP servers for SwiftUI dev (not an audit) | `ios-dev-workbench` |
| OAuth+PKCE, Universal Links, push, App Intents/Shortcuts, WidgetKit, StoreKit 2 audit | `ios-integration-audit` |
| Test coverage inventory, snapshot tests, Maestro flows, device coverage | `ios-qa-audit` |
| OWASP MASVS v2 security audit — Keychain, ATS, cert pinning, secrets | `ios-security-audit` |
| UI implementation quality — hit targets, Dynamic Type, dark mode, SF Symbols | `ios-ui-impl-audit` |
| macOS menubar apps (Tuist + SwiftUI, LSUIElement) | `macos-menubar-tuist-app` |
| SwiftPM-based macOS apps without an Xcode project | `macos-spm-app-packaging` |
| Packaging an existing web app as a native Windows/macOS desktop install | `packaging-desktop-apps` |
| Swift 6.2+ concurrency review/remediation, compiler errors | `swift-concurrency-expert` |
| SwiftData modeling, queries, migrations | `swiftdata-pro` |
| iOS 26+ Liquid Glass API adoption/refactor | `swiftui-liquid-glass` |
| Diagnosing slow rendering, janky scrolling, high CPU/memory in SwiftUI | `swiftui-performance-audit` |
| SwiftUI view/navigation/modifier best practices and examples | `swiftui-ui-patterns` |
| Design-quality audit of a live SwiftUI app (Simulator + Maestro) | `swiftui-ux-audit` |
| Refactoring SwiftUI view files (small subviews, MV-over-MVVM) | `swiftui-view-refactor` |
| WidgetKit code — Home Screen/Lock Screen/StandBy/watch widgets | `widgets` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
