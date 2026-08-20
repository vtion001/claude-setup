---
name: ios-ui-impl-audit
description: >
  iOS UI implementation-quality audit. Distinct from /swiftui-ux-audit
  (design quality). Covers hit-target sizing (44pt), Dynamic Type, dark
  mode, size classes / iPad layout, SF Symbols vs custom icons, View
  body perf (Instruments SwiftUI instrument), motion-reduce support, and
  RTL / locale layout. Benchmarked against Apple HIG + WCAG 2.2.

  Triggers: "ui implementation audit ios", "hit target check",
  "dynamic type", "dark mode audit", "/ios-ui-impl-audit",
  "swiftui implementation quality", "hig conformance".

  Flags:
    --quick           # Static only
    --pass <names>    # Cherry-pick
    --device <name>   # Multi-device runs
    --linear

  Sibling skills:
    - /swiftui-ux-audit  owns design quality (hierarchy, color, emotional)
    - /ios-qa-audit      owns the runtime accessibility audit harness
---

# iOS UI Implementation Audit

Static + runtime audit for SwiftUI implementation quality. The
**implementation** sibling of `/swiftui-ux-audit` (which is **design**
quality). Benchmarked against Apple HIG and WCAG 2.2.

## Prerequisites

- macOS with Xcode 26.5 + DEVELOPER_DIR
- iOS Simulator + Maestro (per shared baseline)
- iOS 17+ for runtime a11y audit

## Invocation

```
/ios-ui-impl-audit                              # All 8 passes
/ios-ui-impl-audit --pass hit-targets,dark-mode
/ios-ui-impl-audit --device "iPhone 17,iPad Air 11-inch (M4)"
```

## Pass Names

`hit-targets`, `dynamic-type`, `dark-mode`, `size-classes`,
`sf-symbols`, `view-body-perf`, `motion-reduce`, `rtl-locale`

## Workflow

Same structure as the other 5 audits. Phase 0 detects; Phase 1 runs
static scans; Phase 2 (when not `--quick`) runs Maestro across device
classes + screenshots; Phase 3 (Tier 2) applies AI judgment per pass;
Phase 4 reports.

## Rules

- **Defer to /swiftui-ux-audit** for visual hierarchy, color palette,
  typography aesthetic decisions.
- **Defer to /ios-qa-audit** for the actual a11y runner (XCUITest
  harness lives there); this audit only flags what NEEDS to be tested.
- **HIG conformance.** Cite Apple's HIG section for each finding.

## Reference files

- `references/passes/01-hit-targets.md`
- `references/passes/02-dynamic-type.md`
- `references/passes/03-dark-mode.md`
- `references/passes/04-size-classes.md`
- `references/passes/05-sf-symbols.md`
- `references/passes/06-view-body-perf.md`
- `references/passes/07-motion-reduce.md`
- `references/passes/08-rtl-locale.md`
- `references/scoring-rubric.md`
- `references/report-template.md`
- `references/tech-stack.md`
- `references/deep-references.md`
- `scripts/install-tools.sh`
- `scripts/ui-impl-scan.sh`
