# Pass 11 — Device Classes

**Weight:** 1× (replaces the web "mobile-responsive" pass)

## What this audits

How the UI holds up across iPhone sizes and iPad. Whether layouts adapt or just stretch. Whether safe-area, dynamic-island, and keyboard avoidance behave.

## Default device matrix

| Device | Width × Height (pt) | What it tests |
|---|---|---|
| iPhone SE (3rd generation) | 375 × 667 | Smallest current iPhone. Compact, no dynamic island, no notch. Reveals over-padded layouts and clipped headings. |
| iPhone 16 | 393 × 852 | Modern standard. Dynamic island. Default benchmark. |
| iPhone 16 Pro Max | 440 × 956 | Largest iPhone. Reveals under-utilized space, fixed-width components, hard-coded heights. |
| iPad Air | 820 × 1180 (portrait) / 1180 × 820 (landscape) | Tablet idiom. Reveals layouts that don't scale beyond compact. |

Override via `--device "..."`. Default: iPhone 16 only (re-run with `--device "iPhone 16,iPhone SE (3rd generation),iPad Air"` for the full pass).

## Tier 1 (runtime)

For each device in the matrix:
- Re-run Phase 3 capture (Maestro flows + screenshots)
- Output: `screenshots/<tab>_<device>_<timestamp>.png`

## Tier 2 (AI on screenshot comparison)

For each tab, compare screenshots across devices:

1. **Reflow** — does content adapt or just stretch? Does an iPad show one wide column where two would be appropriate?
2. **Truncation** — does text clip or wrap on iPhone SE?
3. **Safe area** — is content respecting safe areas on all devices (Dynamic Island, home indicator, status bar)?
4. **Tap-target degradation** — do tap targets shrink below 44pt on iPhone SE?
5. **Hero proportions** — do hero illustrations / images keep their aspect on different widths?
6. **Modal sizing** — sheets/fullScreenCovers sized appropriately for iPad (compact form vs full-screen)?
7. **Orientation** — if landscape is supported, does it work or does it just stretch portrait?
8. **Idiom-aware components** — `NavigationSplitView` for iPad vs `NavigationStack` for iPhone? Or a single iPhone-only layout forced onto iPad?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All devices feel native. iPad uses split layouts where appropriate. No clipping on iPhone SE. |
| 4 | iPhone sizes all clean; iPad is functional but iPhone-stretched. |
| 3 | iPhone SE has minor clipping; iPad is a stretched iPhone. |
| 2 | Layouts break on iPhone SE OR iPad is unusable. |
| 1 | Multiple sizes show broken layouts (clipping, overflow, unreadable text). |

## Common findings + severity

| Finding | Severity |
|---|---|
| Heading clips on iPhone SE | High |
| Two-column layout on iPad shows one column (wasted space) | Medium |
| Sheet shown full-screen on iPad (should be `.formSheet` or `.popover`) | Medium |
| Tab-bar icons overlap labels on iPhone SE | High |
| Tap target shrinks below 44pt on smallest size | High (a11y) |
| Fixed `width:` literal preventing reflow | Medium |
| Custom keyboard avoidance broken on iPhone SE | High |

## Recommended fixes

- Use `@Environment(\.horizontalSizeClass)` to branch layouts for iPad.
- Use `NavigationSplitView` over `NavigationStack` for iPad-aware navigation.
- Use `.frame(maxWidth: .infinity)` instead of literal widths.
- Use `.minimumScaleFactor(0.85)` on tight headings.
- Replace `.padding(40)` with token-scale padding so it doesn't crowd small screens.

## What NOT to flag

- Apps explicitly marked iPhone-only in `Info.plist` (`UIDeviceFamily = [1]`)
- Apps with their own iPad target / different Xcode scheme — audit each separately
