---
name: ios-code-review
description: >
  Swift / iOS code review audit benchmarked against the Swift API Design
  Guidelines, SwiftLint, SwiftFormat, Periphery, and Swift evolution
  proposals. Covers naming, file organization, dead code, dependency
  hygiene, formatting consistency, and Swift idiom adoption.

  Triggers: "code review iOS", "swift code quality", "swiftlint check",
  "dead code scan", "/ios-code-review", "review my swift code",
  "code review my SwiftUI app".

  Flags:
    --quick           # Tier 0 only (lint + format check; no AI judgment)
    --pass <names>    # Cherry-pick passes
    --fix             # Apply SwiftFormat + SwiftLint --fix; never touches security/concurrency
    --strict          # Treat warnings as errors
    --linear          # File theme-grouped findings

  Sibling skills:
    - /ios-security-audit   owns any secrets / Keychain finding
    - /ios-backend-audit    owns concurrency / persistence issues
---

# iOS Code Review Audit

Swift / SwiftUI code review. Static-analysis-first with AI judgment for
patterns lints can't see. Benchmarks against the canonical
**Swift API Design Guidelines** (swift.org).

## Prerequisites

- macOS with Xcode 26.5 + DEVELOPER_DIR exported
- An iOS project at cwd
- **Auto-installed if missing**: SwiftLint, SwiftFormat, Periphery
  (via `_ios-shared/scripts/install-tool.sh`)
- Optional: SwiftLens MCP for semantic Swift analysis

## Invocation

```
/ios-code-review                  # All 7 passes
/ios-code-review --quick          # SwiftLint + SwiftFormat + Periphery only
/ios-code-review --pass dead-code-periphery,swiftlint-rules
/ios-code-review --fix            # Apply safe SwiftFormat + lint autocorrect
/ios-code-review --strict         # Warnings → errors
```

## Pass Names

`swiftlint-rules`, `swiftformat-config`, `dead-code-periphery`,
`api-design-guidelines`, `file-organization`, `dependency-hygiene`,
`swift-evolution-adoption`

## Workflow

### Phase 0: Auto-detect
Run `_ios-shared/scripts/detect-ios-project.sh`. Check for SwiftLint /
SwiftFormat configs; if absent, the audit flags this (1/5 for that pass)
but still runs with defaults.

### Phase 1: Tier 0 — lint + format + dead code
- SwiftLint on all source dirs
- SwiftFormat in `--lint` mode (no writes)
- Periphery `scan --strict`
- Static greps per pass

Outputs to `<project>/ios-audit/ios-code-review/tier0.json`.

### Phase 2: Tier 2 — AI reasoning

For each pass, apply heuristics from `references/passes/`:
- Naming: do identifiers follow Swift's "clarity at the point of use" rule?
- File organization: does one struct per file hold (matches CLAUDE.md
  convention)?
- API design: are public APIs documented, do they use Swift's value-type
  preferences?
- Dependency hygiene: are SPM deps pinned? Lockfile committed?

### Phase 3: Source cross-reference

Tag every finding with `file:line` + root cause + recommended fix.

### Phase 4: Report

Write to `<project>/ios-audit/ios-code-review/`:
- `report.md`, `scorecard.md`, `findings.json`

### Phase 5 (if `--fix`): apply mechanical fixes

Only `swiftformat <files>` and `swiftlint --fix`. Never touches anything
on the NEVER-MODIFY list in `_ios-shared/safety-guardrails-swift.md`.

## Rules

- **Don't audit style for taste.** Every recommendation references
  SwiftLint rule, SwiftFormat config option, or the Swift API Design
  Guidelines section.
- **Defer to /ios-security-audit** for any secrets / Keychain finding.
- **Defer to /ios-backend-audit** for concurrency / persistence issues.
- **Score the absence of config files.** A project without `.swiftlint.yml`
  is scoring 1/5 on `swiftlint-rules` even if there are no lint warnings
  (because there are no rules being enforced).

## Reference files

- `references/passes/01-swiftlint-rules.md`
- `references/passes/02-swiftformat-config.md`
- `references/passes/03-dead-code-periphery.md`
- `references/passes/04-api-design-guidelines.md`
- `references/passes/05-file-organization.md`
- `references/passes/06-dependency-hygiene.md`
- `references/passes/07-swift-evolution-adoption.md`
- `references/scoring-rubric.md`
- `references/report-template.md`
- `references/tech-stack.md`
- `references/deep-references.md`
- `scripts/install-tools.sh`
- `scripts/run-swiftlint.sh`
- `scripts/run-swiftformat.sh`
- `scripts/run-periphery.sh`
