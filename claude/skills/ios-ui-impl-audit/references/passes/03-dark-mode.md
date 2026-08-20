# Pass 03 — Dark Mode

**Weight:** 2×

## What this audits
Does the app render correctly in dark mode? Or does it ship with
hardcoded white-ish backgrounds that look broken on dark?

## Tier 0
```bash
# Hardcoded Color.white / .black (NOT in shadow context)
grep -rn --include='*.swift' 'Color\.white' <project-root> | grep -vE 'shadow|fill\(Color\.white\b' | head -50

# ColorScheme adaptation
grep -rn --include='*.swift' 'colorScheme\|@Environment(\.colorScheme)\|preferredColorScheme' <project-root>
```

## Tier 1
Boot simulator in dark mode, screenshot each tab + sheet, visually diff.

## Scoring
| Score | Criteria |
|---|---|
| 5 | Dark mode renders correctly; colors adapt via assets or ColorScheme |
| 4 | Mostly works; minor contrast/visibility issues |
| 3 | Partial support — some screens look fine, others broken |
| 2 | No adaptation; light-themed in dark mode |
| 1 | Explicitly disabled via `preferredColorScheme(.light)` without a justification |

## Common findings
| Finding | Severity |
|---|---|
| `Color.white` as background (no dark adaptation) | **Medium** |
| `Color(hex: "...")` constants for backgrounds (no asset-catalog dark variants) | **Medium** |
| `.preferredColorScheme(.light)` forcing light mode | **High** unless intentional |
| Text contrast failing in dark mode | **High** |

## Pookoo
Per exploration: pure white background + black text. No ColorScheme
adaptation. Dark mode users see broken UI. Score 1/5 — critical for the
audit to flag.

## What NOT to flag
- Apps that intentionally lock to light mode for brand reasons (rare;
  document in CLAUDE.md if so)
