# Pass 14 — Design Tokens (iOS-specific, new)

**Weight:** 2×

## What this audits

Whether view code consumes the project's design-token vocabulary (the detected `Theme.swift`-equivalent) instead of inline literals. This is the cross-file consistency pass — it complements Pass 02 (typography), Pass 03 (color), Pass 04 (spacing) by looking at the *aggregate* picture across the whole project.

## Tier 1 (automated, fully static)

This pass runs even with `--static` (no simulator). It's the cheapest and most actionable signal in the whole audit.

Inputs:
- Detected token file path (e.g. `Pookoo/Utils/Theme.swift`)
- Detected token vocabulary (e.g. `PukaTypography.{title,headline,body,caption}`, `PukaSpacing.{xs,sm,md,lg,xl,xxl}`, `Color.{pukaGreen,pukaCard,pukaTextSecondary,...}`)

Checks:

| Violation | Detection |
|---|---|
| Raw `.font(.system(...))` outside token file | `rg '\.font\(\.system\(' \| grep -v <token-file>` |
| Raw `.padding(N)` integer literal | `rg '\.padding\([0-9]+'` |
| Raw `.cornerRadius(N)` integer literal | `rg '\.cornerRadius\([0-9]+'` |
| `Color(hex:...)` outside `Models/` + token file | `rg 'Color\(hex:'` filtered |
| `Color(red:..., green:..., blue:...)` | `rg 'Color\(red:'` |
| Raw `Font.custom("...")` outside token file | `rg 'Font\.custom\('` |
| Raw `.shadow(color:radius:x:y:)` literal | `rg '\.shadow\(color:'` |
| Hardcoded `Color.gray`/`Color.black`/etc. instead of token (`.foregroundColor(.gray)` etc.) | `rg '\.foregroundColor\(\.(gray|black|white|primary|secondary)\)'` (some of these are legitimate; AI filters) |
| `HStack(spacing: N)` / `VStack(spacing: N)` with integer literal | regex above |
| Animation literals (`.easeInOut(duration: 0.3)`) outside an animation-token scope | `rg '\.(easeInOut|easeIn|easeOut|spring|interactiveSpring)\(' \| grep -v <token-file>` |

Output JSON:

```json
{
  "token_file": "Pookoo/Utils/Theme.swift",
  "vocabulary": {
    "typography": ["title", "headline", "body", "caption"],
    "spacing":    ["xs", "sm", "md", "lg", "xl", "xxl"],
    "color":      ["pukaGreen", "pukaCard", "pukaTextSecondary", "..."],
    "modifiers":  ["pukaCard", "pukaElevatedCard"]
  },
  "violations": {
    "raw_font_system":      { "count": 230, "samples": [...] },
    "raw_padding_int":      { "count": 2,   "samples": [...] },
    "raw_corner_radius_int":{ "count": 83,  "samples": [...] },
    "raw_color_hex":        { "count": 18,  "samples": [...] },
    "raw_color_rgb":        { "count": 0 },
    "font_custom":          { "count": 0 },
    "raw_shadow":           { "count": 4,   "samples": [...] },
    "stack_int_spacing":    { "count": 12,  "samples": [...] },
    "raw_animation":        { "count": 7,   "samples": [...] }
  }
}
```

## Tier 2 (AI cross-checks the static findings)

For each violation cluster:

1. Is this a legitimate exception (data-driven category color in `Models/`)?
2. Is the nearest token an exact match, near-match, or no match?
3. Should the project introduce a new token (e.g. no `PukaRadius` exists yet, but 83 cornerRadius literals suggest one is overdue)?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Zero violations outside `Models/`. Every value comes from a token. |
| 4 | < 20 total violations, all explainable as edge cases. |
| 3 | 20–100 violations. Several clusters that suggest missing tokens. |
| 2 | 100–500 violations. Tokens used inconsistently. |
| 1 | > 500 violations OR token file used by less than half the views. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Cluster of >20 raw `.font(.system(...))` in one feature folder | High |
| Cluster of >10 raw `.cornerRadius(N)` suggesting a missing `PukaRadius` token | Medium (proposes new token) |
| Single `Color(hex:)` in a `View` file | Low–Medium (one-off) |
| Tab-bar icon sizes hardcoded | Low |
| `.easeInOut(duration:)` literals scattered — no animation tokens | Medium (proposes `PukaAnimations`) |

## Recommended fixes

- The `--fix` mode can directly substitute the SAFE-TO-MODIFY subset of these (raw font / raw padding / raw corner radius / legacy color alias). See `safety-guardrails-swift.md`.
- For "no token exists yet": emit a recommendation to add a new token group to the design-system file, including the suggested name + values derived from the cluster (e.g. "Add `PukaRadius.{sm, card, lg} = {8, 16, 24}` based on observed values").

## What NOT to flag

- Anything inside the detected token file itself
- Anything inside `Models/` if the project uses data-driven category colors (auto-detected by reading any `enum` containing `case` lines with `color:` properties)
- Anything inside `#Preview { }` blocks — those are dev-only
- Anything inside `*Tests*/` or `*UITests*/` directories
- Test fixtures
