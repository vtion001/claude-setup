# Pass 01 — Visual Hierarchy

**Weight:** 3× (core usability driver)

## What this audits

Does the eye know where to land first? Is there a single dominant element per screen? Are secondary and tertiary elements proportionally subordinate? Is the hierarchy expressed with multiple cues (size, weight, color, spacing) — not just one?

This is a screenshot-driven pass. SwiftUI offers no DOM to query; the verdict comes from the AI reading the captured PNG of each tab.

## Tier 1 (automated)

None directly — there is no static analogue for "what does the eye see first?". However, the skill **does** collect supporting signals:

- Inventory of `Text(...)` modifiers per screen via grep — count how many distinct font sizes appear on one screen.
- Inventory of `.foregroundColor(...)` distinct values per screen — a screen with 6 different primary text colors is almost certainly hierarchy-broken.
- Card/elevation modifier usage (`.pukaCard()`, `.pukaElevatedCard()`) — same elevation everywhere kills layered depth.

Output to feed into Tier 2: `{font_sizes_per_screen, distinct_text_colors, elevation_variety}`.

## Tier 2 (AI on screenshot)

For each tab screenshot, answer:

1. **Focal point** — is there one obvious "land here first" element? If yes, what is it? Does it match the user's likely primary intent on this screen?
2. **Layering** — does the screen show 3 levels of importance (primary / secondary / tertiary)? Or does everything feel equal?
3. **Multi-cue hierarchy** — is the dominant element distinguished by ≥2 cues (size + weight, color + spacing, size + elevation)?
4. **Scan path** — trace the implied F-pattern or Z-pattern. Does it lead the user toward the primary action?
5. **Density vs breathing** — is the densest region also the most important, or is dense data drowning out the CTA?
6. **Negative space** — does whitespace work as a hierarchy tool, or has every available pixel been used?
7. **iOS-specific** — is the navigation-bar title hierarchy correct (large-title vs inline)? Does the tab bar steal too much attention?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | One clear focal point. Three readable levels of importance. Whitespace used intentionally. Could be a HIG reference example. |
| 4 | Clear hierarchy with minor weight or spacing inconsistencies. 1–3 Low findings. |
| 3 | Hierarchy readable but blurred — two competing focal points, or relies on a single cue (size only). 1–3 Medium findings. |
| 2 | Multiple competing focal points; hard to tell what's primary. 1–2 High findings. |
| 1 | No discernible hierarchy. Everything weighted equally. Critical-severity finding. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Two CTAs styled identically, competing for attention | High |
| Section headers the same size as body text | High |
| Card chrome (border + shadow + radius) on every element so nothing stands out | Medium |
| 4+ distinct foreground colors used for primary text on one screen | Medium |
| Tab-bar title styled larger than the screen's primary text | Low |
| Primary CTA below the fold without visual cue to scroll | Medium |

## Recommended fixes

- Demote secondary actions to text-button style (`.buttonStyle(.plain)` with token color)
- Promote primary CTA by combining ≥2 cues — size + weight + color, not just color
- Add `Spacer()` or vertical padding token to separate primary group from secondary group
- Cap on-screen font-size variety at 3–4 levels per screen — anything more is noise
- Use `.navigationTitle("...")` `.navigationBarTitleDisplayMode(.large)` for landing tabs, `.inline` for detail screens — never the opposite

## What NOT to flag

- Intentional density on dashboard-style screens (data-first tabs)
- Two-level hierarchy on Settings-style screens (rows are inherently flat)
- Onboarding screens where the focal point is a hero illustration, not text
