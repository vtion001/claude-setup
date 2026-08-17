# Pass 08 — RTL / Locale Support

**Weight:** 2×

## What this audits
For internationalized apps: does the layout flip correctly for RTL
locales (Arabic, Hebrew)? Does the app use `String Catalog` (.xcstrings)
for localizations?

## Tier 0
```bash
# String Catalog presence
ls -d <project-root>/**/*.xcstrings 2>/dev/null

# Localizable.strings (legacy)
ls -d <project-root>/**/Localizable.strings 2>/dev/null

# Hard-coded strings (any Text("...") that's not %s-prefixed)
grep -rn --include='*.swift' 'Text("[A-Z]' <project-root> | wc -l
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | String Catalog; RTL flips correctly; locale-specific assets when needed |
| 4 | Localizations present; minor layout issues in RTL |
| 3 | One locale supported (en) |
| 2 | Localizations attempted but broken |
| 1 | N/A — apps with English-only target audience score 5 |

## Pookoo
Not internationalized; default 5/5.

## What NOT to flag
- English-only apps (or apps with no localization goals)
- Apps where the target user base is known to be single-locale
