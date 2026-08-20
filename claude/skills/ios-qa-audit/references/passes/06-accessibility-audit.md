# Pass 06 — Accessibility Audit (XCUIApplication.performAccessibilityAudit)

**Weight:** 3×

## What this audits
Does the project run Apple's built-in accessibility audit on every view?
Catches: dynamic type clipping, contrast failures, missing labels,
trait misuse, sub-44pt hit targets.

## Tier 0
```bash
grep -rln --include='*.swift' 'performAccessibilityAudit' <project-root>
```

## Tier 1
Run the audit per view via XCUITest. Use `references/runner-template.swift`
from `swiftui-ux-audit` as the template.

## Scoring
| Score | Criteria |
|---|---|
| 5 | Audit runs on every tab + primary sheet; zero issues; in CI |
| 4 | Audit runs on primary screens; <5 minor issues |
| 3 | Audit exists but limited coverage |
| 2 | Audit scaffolding without enforcement |
| 1 | No audit; no XCUITest-based a11y |

## Common findings
| Finding | Severity |
|---|---|
| No XCUIApplication.performAccessibilityAudit call | **High** |
| Audit exists but only for one screen | **Medium** |
| Audit findings ignored in CI | **High** |
| Buttons under 44pt hit target | **Medium** |
| Images without accessibilityLabel | **Medium** |

## Pookoo-specific
A11yAuditTests.swift exists (~21KB) per exploration. Confirm it actually
runs by reading the file and checking the audit assertion isn't commented
out.

## What NOT to flag
- Decorative-only views that explicitly mark themselves
  `.accessibilityHidden(true)`
- iOS 16- targets without `performAccessibilityAudit` (not available)
