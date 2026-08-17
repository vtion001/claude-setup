# Pass 02 — Dynamic Type

**Weight:** 3×

## What this audits
Does the app respect Dynamic Type? Specifically:
- `Text` uses `Font.body`/`.title`/etc. (or `.dynamicTypeSize(...)`)
- Custom `.font(.system(size:))` is fixed-size and BAD unless wrapped in `dynamicTypeSize(...)`
- Layouts don't clip at `AX5` (largest Accessibility size)

## Tier 0
```bash
# Fixed-size fonts (no Dynamic Type support)
grep -rn --include='*.swift' '\.font(\.system(size:' <project-root> | wc -l

# Dynamic Type users
grep -rn --include='*.swift' '\.font(\.\(title\|headline\|body\|caption\|footnote\|callout\|subheadline\)' <project-root> | wc -l

# Manual dynamicTypeSize handling
grep -rn --include='*.swift' 'dynamicTypeSize' <project-root>
```

## Tier 1
Maestro: launch with `--device` + set the simulator's Dynamic Type to
AX5 via `xcrun simctl ui booted increase_contrast` patterns; screenshot
key views; visually compare.

## Scoring
| Score | Criteria |
|---|---|
| 5 | All text uses semantic font roles. No clipping at AX5. |
| 4 | Mostly semantic. 1-2 fixed-size in places where it makes sense (logo, brand text) |
| 3 | Mix of system fonts and fixed-size. Some clipping at AX3+ |
| 2 | Most text uses fixed sizes |
| 1 | Fixed-size everywhere; obvious clipping even at default size |

## Common findings
| Finding | Severity |
|---|---|
| `.font(.system(size: N))` with no `dynamicTypeSize` | **Medium** |
| Body text clipping at AX5 | **High** |
| Buttons clipping their label at AX3+ | **Medium** |
| Long strings with `lineLimit(1)` and no `minimumScaleFactor` | **Medium** |

## Pookoo
Per CLAUDE.md: extensive use of `.font(.system(size: N, design: .rounded))`
in `PukaTypography`. This is fixed-size — needs verification of Dynamic
Type behavior. Recommend `.font(PukaTypography.body)` returning
`.system(.body, design: .rounded)` instead.

## What NOT to flag
- Logo / wordmark text where fixed sizing is intentional
- Numbers in compact UI (counters, badges) where fixed sizing aids readability
