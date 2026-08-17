# Pass 01 — SwiftLint Rules

**Weight:** 2×

## What this audits
Is SwiftLint configured? Is the rule set sensible for the project's scale?
Are violations zero on `main`?

## Tier 0
- Look for `.swiftlint.yml` in project root
- Run `swiftlint --reporter json` and count violations by severity

## Scoring
| Score | Criteria |
|---|---|
| 5 | `.swiftlint.yml` present, customized for project, zero violations |
| 4 | Config present, < 10 warning violations |
| 3 | Default-config-only or 10-50 warnings |
| 2 | Many warnings (50+) or only one or two rules enabled |
| 1 | No `.swiftlint.yml` at all |

## Common findings
| Finding | Severity |
|---|---|
| No `.swiftlint.yml` | **High** |
| `force_cast` / `force_try` / `force_unwrapping` warnings | **Medium** |
| `cyclomatic_complexity` violations | **Medium** |
| `file_length` / `type_body_length` warnings | **Low** |
| `line_length` over 200 chars | **Low** |

## Recommended fix — starter `.swiftlint.yml`
```yaml
opt_in_rules:
  - empty_count
  - empty_string
  - explicit_init
  - first_where
  - sorted_first_last
  - trailing_closure
  - unneeded_parentheses_in_closure_argument

disabled_rules:
  - line_length             # rely on SwiftFormat width
  - identifier_name         # noisy on view-builder DSL

opt_in_rules:
  - force_unwrapping        # warn (not error) on force unwraps

excluded:
  - .build
  - Pods
  - DerivedData

reporter: "xcode"
```

## What NOT to flag
- Generated code in `Generated/` or `DerivedData/`
- Test files where assertion macros legitimately use force-unwrap
