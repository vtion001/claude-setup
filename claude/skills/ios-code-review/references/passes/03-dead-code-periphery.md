# Pass 03 — Dead Code (Periphery)

**Weight:** 2×

## What this audits
Unused types, functions, properties, files. Bloats the binary, slows
build, increases cognitive load for new contributors.

## Tier 0
```bash
periphery scan --project <name>.xcodeproj --schemes <Scheme> --targets <Target> --quiet --format json
```

Count by kind: `unused_class`, `unused_struct`, `unused_function`,
`unused_property`, `unused_import`, `unused_enum_case`.

## Scoring
| Score | Criteria |
|---|---|
| 5 | Zero dead code |
| 4 | < 5 items, all genuinely unused |
| 3 | 5-20 items, most genuine |
| 2 | 20-50 items |
| 1 | 50+ items OR an unused-import volume that suggests no one ever runs Periphery |

## Common findings
| Finding | Severity |
|---|---|
| Unused import (e.g. `import EventKit` with no EK calls) | **Low** |
| Unused public function — interface bloat | **Medium** |
| Unused private function — dead branch | **Low** |
| Entire unused file | **Medium** |
| Unused `@objc` exposure | **Low** |

## Recommended fix
Delete the unused symbol. If false positive (e.g. used via `#selector`,
KVC, or Objective-C runtime), add an explicit `// periphery:ignore` comment.

## Pookoo-specific
First run flags `EventKit` import in `Pookoo/Views/Settings/SettingsView.swift`
that's never used (per exploration). Delete the import.

## What NOT to flag
- Code that's used only by tests (Periphery's `--retain-public` covers this)
- API surface intentionally exposed to consumers but not used internally
- Objective-C runtime / KVC / selector-based references
