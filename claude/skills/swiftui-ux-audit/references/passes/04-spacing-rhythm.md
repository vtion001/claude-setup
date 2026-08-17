# Pass 04 — Spacing & Rhythm

**Weight:** 2×

## What this audits

Whether spacing follows a consistent scale (typically 4pt or 8pt grid) and creates rhythmic group/separator/section breathing room. SwiftUI gives this a strong static signal — every raw `.padding(N)` integer literal is a token-bypass.

## Tier 1 (automated, static)

```bash
# Raw .padding(N) integer literals — likely violations
rg --no-heading -n '\.padding\([0-9]+(\.[0-9]+)?\)' <project> | grep -v "<token-file>"

# Raw .cornerRadius(N)
rg --no-heading -n '\.cornerRadius\([0-9]+(\.[0-9]+)?\)' <project> | grep -v "<token-file>"

# Raw spacing inside HStack/VStack(spacing: N)
rg --no-heading -n '(HStack|VStack|LazyVStack|LazyHStack)\(spacing:\s*[0-9]+(\.[0-9]+)?\)' <project>
```

Output the available spacing scale from the detected token file (e.g. `xs=4, sm=8, md=16, lg=24, xl=32, xxl=48`) and cross-reference each raw literal against the scale. A literal of `16` when `md=16` exists is a "should-use-token" finding; a literal of `13` is both a token-bypass AND off-grid.

## Tier 2 (AI on screenshot)

1. **Grid coherence** — do major edges align to a consistent column/grid?
2. **Group/separator/section** breathing — is there a clear 3-level spacing rhythm (within-group < between-groups < between-sections)?
3. **Trailing edge** — does content respect the safe-area / horizontal margin?
4. **Card padding** — same padding inside every card variant?
5. **Touch-target spacing** — adjacent tappable elements at least 8pt apart?
6. **List-row spacing** — consistent vertical rhythm in `List` / `LazyVStack`?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | 100% spacing token usage. Visual rhythm reads cleanly across all tabs. |
| 4 | ≥95% token usage. 1–2 minor off-grid literals. |
| 3 | 70–95% token usage. Rhythm breaks on 1–2 screens. |
| 2 | <70% token usage. Pad-by-eyeball is the norm. |
| 1 | No detectable system. Spacing is chaotic. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Raw `.padding(N)` integer literal outside token file | Medium (per file) |
| Raw `.cornerRadius(N)` outside token file | Medium (per file) |
| Off-grid value (e.g. `padding(13)` when grid is 4/8/16/24) | Medium |
| Two adjacent buttons with < 8pt gap | High (a11y/Fitts) |
| Card padding varies between tabs | Medium |
| Section break < 24pt — sections feel merged | Low |

## Recommended fixes (auto-fixable subset)

```diff
- .padding(16)
+ .padding(PukaSpacing.md)
```

Only apply when value exactly matches a token in the detected spacing scale. Mismatches → escalate.

## What NOT to flag

- Sub-pixel padding values inside custom drawing (`Canvas`, `Path`) — those are geometry, not UI spacing
- `.padding()` (no argument) — that uses SwiftUI's default, fine
- One-off ornamental padding inside `#Preview { }` blocks
