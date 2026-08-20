# Pass 02 — Typography

**Weight:** 2×

## What this audits

Whether type is readable, consistent, and uses the project's design-token vocabulary. SwiftUI gives this pass a strong **static** signal that the web equivalent lacks: every `.font(.system(size: N))` outside the token file is a token-bypass and shows up in grep.

## Tier 1 (automated, static)

Run from `scripts/token-scan.sh`:

```bash
# Count raw .font(.system( uses outside the detected token file
rg --no-heading -n '\.font\(\.system\(' <project> | grep -v "<token-file>" | wc -l

# Sample 10 example file:line locations
rg --no-heading -n '\.font\(\.system\(' <project> | grep -v "<token-file>" | head -10
```

Also collect:

- All distinct token names declared in the detected typography scope (e.g. `PukaTypography.body`, `PukaTypography.headline`)
- Per-screen distribution of font sizes by reading each tab's view file with `rg '\.font\([^)]+\)'`

Output JSON:
```json
{
  "raw_system_font_count": 230,
  "samples": ["Pookoo/Views/Assistant/AssistantView.swift:284", "..."],
  "available_tokens": ["PukaTypography.title", "PukaTypography.headline", "..."],
  "per_screen": { "home": {"raw": 4, "tokenized": 12}, ... }
}
```

## Tier 2 (AI on screenshot)

Check:

1. **Body line-height + line-length** — does long text wrap at a comfortable measure (45–75 characters per line on phone)?
2. **Heading-to-body ratio** — minimum 1.4× size difference; under that and headings look like body.
3. **Text on imagery** — is there sufficient contrast scrim or backdrop?
4. **Dynamic Type readiness** — does the screen look like it would survive Larger Accessibility Sizes? (Static: are non-token sizes used? Hint that no.)
5. **iOS font family consistency** — does the screen mix SF Pro + SF Rounded + system fonts arbitrarily?
6. **Trailing widows / runts** — is the last word of a paragraph orphaned?
7. **Tabular numbers** — currency, time, counts — are they monospaced (`.monospacedDigit()`) where they're in a vertical list?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | 100% token usage. Heading/body/caption ratios clear. Tabular nums where needed. |
| 4 | ≥95% token usage. Minor line-length issue on one screen. 1–3 Low findings. |
| 3 | 70–95% token usage OR readable but inconsistent rhythm. 1–3 Medium findings. |
| 2 | <70% token usage — raw `.font(.system(...))` dominates. Inconsistent across tabs. 1–2 High findings. |
| 1 | Type pulled from inline literals everywhere, no detectable system. Critical. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Raw `.font(.system(size: N))` in view code | Medium (per file) — escalates if widespread |
| Mixed font designs (`.rounded` here, default there) on same screen | High |
| Heading size = body size + 1pt (hierarchy collapse) | High |
| Numeric column not using `.monospacedDigit()` | Low |
| Body text below 15pt | Medium (a11y) |
| Hardcoded line-height conflicting with Dynamic Type | High |

## Recommended fixes (auto-fixable subset)

Safe for `--fix`:

```diff
- .font(.system(size: 17, weight: .semibold, design: .rounded))
+ .font(PukaTypography.headline)
```

When no token within ±1pt of the literal size exists → escalate, don't substitute.

## What NOT to flag

- Inline `.font(.system(size: ...))` inside `Models/` data definitions (data-driven category labels)
- One-off `.font(.system(size: 36))` for app-icon-glyph hero — those are usually intentional and don't repeat
- Dev-only `Text("DEBUG: ...")` overlays
