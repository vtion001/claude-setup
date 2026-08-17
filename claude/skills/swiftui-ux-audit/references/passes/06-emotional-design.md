# Pass 06 — Emotional Design

**Weight:** 3×

## What this audits

Whether the UI feels human, intentional, and on-brand — not just functional. The "would I be happy to open this?" verdict. Pure AI screenshot pass.

## Tier 1 (automated)

None. This is a Tier 2-only pass.

Supporting signals from prior passes:
- Token discipline (from Pass 02/03/04) — chaos drains warmth
- Animation usage count (from Pass 05) — motion is emotional
- Custom illustrations / `Image(systemName:)` variety — emotional vocabulary

## Tier 2 (AI on screenshot)

Per tab, answer with reasoning:

1. **Voice** — does the copy sound like a person or like a spec doc? Welcoming or robotic?
2. **Delight beats** — are there moments designed to make the user smile (an SF Symbol used playfully, a particle animation, a friendly empty state, a witty error message)?
3. **Restraint** — is the design confident enough to leave space, or does every pixel scream?
4. **Brand expression** — does this look distinctively like *this product*, or could it be any iOS app?
5. **Onboarding warmth** — first-launch screens: do they welcome, or do they interrogate (forms first)?
6. **Imagery quality** — if photos/illustrations are used, are they on-brand or stock?
7. **Tone-shift across screens** — does the assistant sound playful, settings sound dry, errors sound concerned — or is everything the same flat voice?
8. **Peak-End** — would the *peak* moment (e.g. first successful flight import) feel celebratory? Would the *end* moment (e.g. completed onboarding) feel rewarding?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | This app has a personality. Copy, motion, restraint, and imagery all work together. Could be a brand reference. |
| 4 | Personality comes through on most screens; one tab feels generic. |
| 3 | Functional but cool. Visible brand, missing warmth. |
| 2 | Borrowed look-and-feel; feels like a template. No memorable beats. |
| 1 | Feels assembled, not designed. No personality. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Empty state with no copy (just "No items") | High |
| Error message reads as a stack trace ("Error: code 401") | High |
| Generic settings screen (could be any iOS app) | Medium |
| Onboarding leads with a permission prompt instead of a welcome | High |
| No celebration moment after first successful action | Medium |
| Imagery looks stock-photo / royalty-free | Low |
| Same tone of voice across playful and serious surfaces | Low |

## Recommended fixes

- Rewrite empty-state copy in two passes: explain what would appear here, then offer the action that brings it to life.
- Map error codes to human messages with a hint.
- Add a single delight beat per primary tab — confetti, scale-bounce, glow.
- Onboarding: lead with the user's first win, then ask for permissions when their value is established.

## What NOT to flag

- Restraint *is* a choice — minimalism is not "missing emotion"
- Settings screens should be quieter than the rest; flag only if they go *colder* than the rest, not just calmer
