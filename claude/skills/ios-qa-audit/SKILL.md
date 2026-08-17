---
name: ios-qa-audit
description: >
  iOS QA audit. Inventories test coverage, snapshot tests, Maestro flows,
  accessibility audits, performance regression tests, and device coverage.
  Benchmarks against the XCTest + Swift Testing dual-framework model.

  Triggers: "qa audit ios", "test coverage swift", "snapshot tests",
  "maestro coverage", "accessibility tests", "/ios-qa-audit",
  "qa my swiftui app", "is there enough testing".

  Flags:
    --quick                # Tier 0 only (count tests + run; skip AI judgment)
    --pass <names>         # Cherry-pick passes
    --device <name>        # iPhone 17 / iPhone Air / iPad Air 11-inch (M4)
    --bootstrap            # Add a Maestro flows/ dir + UI-test target if missing
    --linear               # File theme-grouped findings
    --skip-maestro         # Skip running flows (still inventory them)

  Sibling skills:
    - /swiftui-ux-audit     overlaps on accessibility; defers a11y MAS-level findings there
    - /ios-code-review      owns test-code style; QA owns coverage + correctness
---

# iOS QA Audit

Static + runtime audit for iOS test infrastructure. Benchmarks against
the **XCTest + Swift Testing** dual-framework model (Swift Testing for
new unit tests, XCTest retained for UI + perf).

## Prerequisites

- macOS with Xcode 26.5 + DEVELOPER_DIR exported
- An iOS project with at least one test target
- **Auto-installed if missing**: Maestro (already installed per prior plan)
- Recommended SPM dep: `swift-snapshot-testing` (recommendation; never
  auto-added)

## Invocation

```
/ios-qa-audit                          # All 8 passes
/ios-qa-audit --quick                  # Test count + run only
/ios-qa-audit --pass snapshot-tests,maestro-flows
/ios-qa-audit --device "iPhone 17,iPad Air 11-inch (M4)"
/ios-qa-audit --bootstrap              # Add UI-test target if missing
```

## Pass Names

`xctest-coverage`, `swift-testing-adoption`, `snapshot-tests`,
`maestro-flows`, `performance-regression`, `accessibility-audit`,
`device-matrix`, `crashlog-integration`

## Workflow

### Phase 0: Auto-detect
Same shared detect script. Additionally:
- Inventory `<Project>Tests/` and `<Project>UITests/` directories
- Count test methods (XCTest `func test*` + Swift Testing `@Test`)
- Look for `swift-snapshot-testing` in `Package.resolved`
- Look for Maestro flows under common paths (see detect script)

### Phase 1: Tier 0 — static counts + test runs

For each pass:
- Count test methods by type
- Run `xcodebuild test -only-testing:<TargetName>` (configurable scope)
- Run `maestro test flows/*.yaml --device <UDID>` if flows exist
- Parse XCTest .xcresult bundle for pass/fail/coverage

### Phase 2: Tier 1 — runtime probes (--device dependent)

- Boot target sim(s)
- Install app
- Run XCUITest with `XCUIApplication.performAccessibilityAudit(for: .all)`
- Run Maestro flows; capture screenshots per device
- Measure perf via `XCTMetric` if a perf test exists

### Phase 3: Tier 2 — AI reasoning

For each pass, decide if coverage is sufficient for the app's risk
profile. A photo-sharing app needs different coverage than a payment app.

### Phase 4: Source cross-reference

Tag findings with `file:line` (test file or, for missing coverage, the
production file that lacks tests).

### Phase 5: Report

`<project>/ios-audit/ios-qa-audit/` with the usual triplet.

### Phase 6: --bootstrap (optional)

If `--bootstrap` AND no UI test target, append a `<Project>UITests`
target to `project.yml` and re-run `xcodegen generate`. Confirm
with user before writing.

## Rules

- Coverage % alone is meaningless without judgment. A 95% covered
  `getColor()` function and a 5% covered payment flow have the same
  total impact on rubric score. Use AI Layer 2 to classify production
  files by risk before scoring coverage.
- Snapshot tests must not be flagged as "missing" if the project uses
  visual-regression another way (Lottie reference frames, Maestro
  screenshots with golden masters).
- Don't score device-matrix gaps for apps that explicitly support only
  iPhone (read `project.yml`'s `supportedDestinations`).

## Reference files

- `references/passes/01-xctest-coverage.md`
- `references/passes/02-swift-testing-adoption.md`
- `references/passes/03-snapshot-tests.md`
- `references/passes/04-maestro-flows.md`
- `references/passes/05-performance-regression.md`
- `references/passes/06-accessibility-audit.md`
- `references/passes/07-device-matrix.md`
- `references/passes/08-crashlog-integration.md`
- `references/scoring-rubric.md`
- `references/report-template.md`
- `references/tech-stack.md`
- `references/deep-references.md`
- `scripts/install-tools.sh`
- `scripts/run-xcodebuild-tests.sh`
- `scripts/run-maestro-flows.sh`
- `scripts/count-tests.sh`
- `templates/flows/home.yaml` — starter Maestro flow
- `templates/flows/scan-boarding-pass.yaml`
