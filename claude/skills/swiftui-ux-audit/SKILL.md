---
name: swiftui-ux-audit
description: >
  AI-powered UI/UX design quality auditor for SwiftUI iOS apps. The native-iOS
  sibling of /ux-audit. Boots the iOS Simulator, drives the app through every
  tab/sheet via Maestro, captures screenshots at multiple device classes, runs
  Apple's XCUIApplication.performAccessibilityAudit, statically validates
  design-token usage against the project's Theme.swift, and produces a Design
  Quality Score with Linear-fileable findings. 14 modular passes covering
  visual hierarchy, typography, color, spacing, micro-interactions, emotional
  design, Nielsen heuristics, Laws of UX, accessibility (XCUI), dark patterns,
  device classes, trust signals, performance perception, and design tokens.
  Supports --quick (static + screenshots only), --static (no simulator),
  --pass (cherry-pick), --device (multi-simulator), --pages (tab subset),
  --fix (safe Swift token-swap auto-fix), --bootstrap (add UI-test target).
  This skill should be used when the user asks to "audit the SwiftUI UI",
  "ux audit iOS", "design audit ios app", "review the SwiftUI design",
  "check the iOS UI quality", "design quality check iOS", "audit the design
  of my SwiftUI app", "review the iOS UX", "does this iOS UI feel right",
  "rate the SwiftUI design", "check iOS design consistency", or any UX-audit
  request when the current working directory is a SwiftUI iOS project.
---

# SwiftUI UX Audit — AI-Powered Design Quality Review for iOS

Evaluate whether a SwiftUI iOS UI feels human. Not "is it broken?" (that's
`/qa-audit`) but "is it good?" — does it delight, does it guide, does it feel
like a designer cared?

This skill is the iOS-native sibling of `/ux-audit` (web). Same 13 core passes,
plus a 14th iOS-specific design-tokens pass. Same DQS rubric and report format.
Different drivers (Maestro + XCUITest + `xcrun simctl` instead of Playwright)
and different fix vocabulary (Swift token swaps instead of Tailwind/CSS).

## Why not Playwright?

Playwright does **not** support native iOS apps — it only drives mobile-web
WebKit. SwiftUI has no DOM. Confirmed by Microsoft's own position. This skill
uses **Maestro** as the primary driver (YAML, CLI-first, single binary,
forgiving on text matches) and **XCUITest** only for the one capability that
requires Apple's first-party APIs: `XCUIApplication.performAccessibilityAudit`,
which catches contrast, hit-region, dynamic-type, text-clipping, element-detection,
sufficient-description, and trait issues.

## Prerequisites

The skill checks these at the start of Phase 0 and fails loudly if missing.

- **Xcode + iOS Simulator** (`xcodebuild`, `xcrun simctl` in PATH)
- **Maestro CLI** — `brew install maestro` (or `curl -Ls "https://get.maestro.mobile.dev" | bash`)
- A SwiftUI iOS project as `cwd` (detected from `*.xcodeproj` / `*.xcworkspace` / `project.yml` / `Package.swift` with iOS platform)
- **iOS 17+ deployment target** for the `performAccessibilityAudit` pass (skill skips that pass with a warning if lower)
- **Linear MCP** (optional, for `--file-issues`)

## Invocation

```
/swiftui-ux-audit                        → full 14-pass, default device iPhone 16
/swiftui-ux-audit --quick                → static + screenshots only; skip XCUI a11y + perf
/swiftui-ux-audit --static               → no simulator at all; token + grep passes only
/swiftui-ux-audit --pass tokens,a11y     → cherry-pick passes (see Pass Names)
/swiftui-ux-audit --device "iPhone 16,iPhone SE (3rd generation),iPad Air"
/swiftui-ux-audit --pages home,flights   → tab subset
/swiftui-ux-audit --fix                  → propose Swift token-swap diffs, await confirm
/swiftui-ux-audit --bootstrap            → add a UI-test target to project.yml (one-shot)
/swiftui-ux-audit --file-issues          → file findings to Linear (requires MCP)
```

All flags combinable. Defaults: full 14-pass, all tabs, iPhone 16 only, no fix.

## Pass Names (for `--pass`)

`hierarchy`, `typography`, `color`, `spacing`, `interactions`, `emotional`,
`nielsen`, `laws-of-ux`, `a11y`, `dark-patterns`, `device-classes`, `trust`,
`performance`, `tokens`

## Workflow

### Phase 0: Auto-detect project

Read `references/ios-automation-primer.md` once. Then detect from `cwd`:

1. **Is this a SwiftUI iOS project?** Look for, in order:
   - `project.yml` (XcodeGen) → parse for targets + schemes
   - `*.xcworkspace` → run `xcodebuild -list -workspace <ws> -json`
   - `*.xcodeproj` → run `xcodebuild -list -project <proj> -json`
   - `Package.swift` with `.iOS(...)` platform
   - If none → fail with: *"Not a SwiftUI iOS project. For web projects use `/ux-audit`."*
2. **Scheme name** — single scheme = pick it; multiple = pick first one with an iOS app target, log the choice.
3. **Bundle identifier** — from `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) or `Info.plist`'s `CFBundleIdentifier`. Required for `simctl launch`.
4. **Deployment target** — to gate the XCUI a11y pass (need iOS 17+).
5. **Design-token file** — search project root for: `Utils/Theme.swift`, `DesignSystem/Theme.swift`, `Theme.swift`, `Tokens.swift`, `DesignTokens.swift`, `*Theme*.swift`, `*Token*.swift`, `*DesignSystem*.swift`. First file with `static let` color/font/spacing decls wins. Extract:
   - Color names (any `static let <name>: Color`)
   - Typography presets (any `static let <name>: Font` inside a *Typography*-named scope)
   - Spacing constants (any `static let <name>: CGFloat` inside a *Spacing*-named scope)
   - Card/elevation/radius modifier names
6. **Navigation surfaces** — read the `@main` file and `ContentView.swift` for `TabView`/`selectedTab` cases and top-level `.sheet(`/`.fullScreenCover(`. This populates `--pages` defaults.
7. **Tests target** — check whether a UI-test target exists. If not and the user invoked anything that requires XCUITest (a11y or perf pass), prompt to run `--bootstrap`.
8. **Report dir** — `<project-root>/swiftui-ux-audit/`. Create if missing. Add to `.gitignore` if a `.gitignore` exists and doesn't already list it (one-line append, confirm first).

Print a 6-line summary of detection results before continuing.

### Phase 1: Build + boot

Skip entirely if `--static`.

1. Pick the simulator(s) per `--device`. Default: `iPhone 16`. Resolve UDIDs via `xcrun simctl list devices --json`.
2. Boot each in sequence: `xcrun simctl boot <UDID>` (idempotent).
3. Build the app: `xcodebuild build -scheme <scheme> -destination "platform=iOS Simulator,id=<UDID>" -configuration Debug -derivedDataPath ./swiftui-ux-audit/.derived`.
4. Install: `xcrun simctl install <UDID> ./swiftui-ux-audit/.derived/Build/Products/Debug-iphonesimulator/<scheme>.app`.
5. Launch once and immediately terminate, to surface crash-on-launch early: `xcrun simctl launch <UDID> <bundleID>` → `xcrun simctl terminate <UDID> <bundleID>`.

If `--bootstrap` is set and no UI-test target exists, run `scripts/bootstrap-uitest.sh` BEFORE step 3 (it edits `project.yml` and runs `xcodegen generate`). Show the diff and await confirm.

### Phase 2: Tab/sheet inventory

Enumerate "pages" to visit. A "page" in SwiftUI = one tab landing screen, or one top-level sheet/full-screen-cover entered from a tab.

Use the inventory from Phase 0.7. If `--pages` is set, intersect.

For each page, prepare a Maestro flow YAML from `templates/flows/`. If a flow already exists for this tab in `<project-root>/swiftui-ux-audit/flows/<page>.yaml`, prefer the project-local one (lets users customize navigation per project).

### Phase 3: Page-by-page capture + audit

Skip per-page runtime steps if `--static`.

For each `(page, device)` combination:

1. **Capture** — `maestro test ./swiftui-ux-audit/flows/<page>.yaml --device <UDID>` runs the navigation flow and screenshots. Save to `./swiftui-ux-audit/screenshots/<page>_<device>_<timestamp>.png`.
2. **Classify the screen** (AI Layer 2) using the screenshot:
   - **List/Feed** → relax whitespace, tighten hierarchy + tap-target spacing
   - **Detail** → relax density, tighten typography + emotional beats
   - **Form** → tighten errors, empty states, field labels
   - **Onboarding** → tighten Peak-End Rule, progress disclosure
   - **Settings** → tighten consistency + a11y
   - **Empty/Loading** → relax everything, audit just the state itself
3. **Run selected passes** — for each pass in the active set (all 14 by default):
   - Read `references/passes/<pass>.md`
   - Run Tier 1 (automated): static grep where applicable, XCUITest a11y dump if it's the a11y pass, etc.
   - Run Tier 2 (AI): read screenshot + Tier 1 results, apply the pass's heuristics
   - Score 1–5 per `references/scoring-rubric.md`
   - Collect findings with severity, pass tag, page, screenshot ref, file:line root cause
4. **Source cross-reference** — for every finding, identify exact `Pookoo/Views/.../*.swift:line` (or generic equivalent), determine root cause (raw value vs token, missing accessibility modifier, etc.), determine fix, classify safe-to-auto-fix per `references/safety-guardrails-swift.md`.

### Phase 4: Cross-page consistency

Once all pages are scored, run the consistency sweep:

1. Collect all design decisions across pages: typography use, color use, spacing values, card modifiers, animation timings, interaction states, empty/loading state styling, icon sizes.
2. For each dimension, identify the dominant pattern and flag drift.
3. **AI Layer 3** — for each inconsistency, identify the page scoring highest on that dimension and recommend unifying *toward it*. Explain why using design principles.
4. Compute Design Consistency Score (DCS) per the rubric, swapping web "Tailwind classes" dimension for "Theme.swift token usage".

### Phase 5: Report

Generate three artifacts in `<project-root>/swiftui-ux-audit/`:

- `report.md` — full narrative report (template from `references/report-template.md`)
- `scorecard.md` — quick-reference per-page scorecard
- `screenshots/` — all captured screenshots

**AI Layer 4 — Design narrative.** Write the executive summary as a senior iOS designer. Identify root-cause patterns, group findings into themes with unified fixes, prioritize by impact-to-effort, estimate effort in sprint-friendly terms, speak in iOS-design language (HIG, Dynamic Type, SF Symbols, haptics, transitions) — not generic web language.

**DQS calculation** — per `references/scoring-rubric.md`. Pass 14 (tokens) is weighted 2x.

**Linear filing** (only if `--file-issues`): group by theme, one issue per theme not per finding, label `["Design Debt", "iOS"]`, priority mapped from severity. Use Linear MCP.

### Phase 6: Auto-fix (only if `--fix`)

1. Load `references/safety-guardrails-swift.md` — internalize NEVER-MODIFY (property wrappers, concurrency, persistence, service singletons, navigation state, event handlers) and SAFE-TO-MODIFY (raw `.font(.system(`, raw `.padding(N)`, raw `.cornerRadius(N)`, legacy color aliases, standalone `.shadow(...)`).
2. Filter findings to those marked auto-fixable.
3. For each, read the target file fully, run the 5-step pre-flight (scope / dependency / behavioral isolation / reversibility / dry-run diff under 5 lines).
4. If pre-flight fails → emit "MANUAL FIX REQUIRED" with the escalation template, move on.
5. Present ALL passing fixes as one unified diff, **wait for explicit confirmation**, then apply.
6. Re-run the affected static passes and report before/after violation counts.

## Rules

- Never skip a page in the inventory unless `--pages` excludes it.
- Always screenshot before reporting a runtime finding.
- Always cross-reference findings to a Swift `file:line` — never guess root causes.
- Read the project's design-token file before recommending any token name. Don't assume `PukaTypography`/`PukaSpacing` — those are this-project names. Use whatever the detected file actually exports.
- Report what IS working — preserve patterns that score well.
- `--fix` must show a unified diff and wait for confirm before applying.
- When pre-flight is uncertain about a fix's safety, escalate. Never auto-apply a doubtful change.
- Respect the existing design system — recommend within its vocabulary, not against it.
- Tab/page text labels are extracted from the actual app, never hardcoded.

## Reference files

- `references/ios-automation-primer.md` — when to use Maestro vs XCUITest vs `simctl`
- `references/safety-guardrails-swift.md` — Swift NEVER-MODIFY / SAFE-TO-MODIFY + 5-step pre-flight
- `references/scoring-rubric.md` — DQS formula, weights, DCS (delegates to web `/ux-audit` rubric where identical)
- `references/report-template.md` — full report + scorecard templates
- `references/passes/01-visual-hierarchy.md` … `14-design-tokens.md` — individual pass definitions

## Scripts

- `scripts/detect-project.sh` — Phase 0 auto-detection (writes a JSON to `<project>/swiftui-ux-audit/.detect.json`)
- `scripts/boot-simulator.sh` — boot a simulator by name or UDID
- `scripts/build-and-install.sh` — `xcodebuild build` + `simctl install`
- `scripts/screenshot.sh` — `xcrun simctl io <UDID> screenshot <path>`
- `scripts/token-scan.sh` — static violation scan against the detected token file
- `scripts/a11y-audit-runner.swift` — XCUITest template that calls `performAccessibilityAudit(for: .all)`
- `scripts/perf-trace.sh` — `xcrun xctrace` launch-time + frame-drop measurement
- `scripts/bootstrap-uitest.sh` — patch `project.yml` to add a UI-test target (only when `--bootstrap`)

## Templates

- `templates/flows/*.yaml` — Maestro flow stubs per common tab name (home, flights, tips, etc.). Used as defaults; users can override per-project.
- `templates/project.yml-uitest-patch.md` — exact YAML diff for adding a UI-test target
