# Pass 08 — Laws of UX

**Weight:** 1×

## What this audits

Whether the design respects empirical laws of UX — Fitts, Hick, Miller, Jakob, Doherty, Tesler, Peak-End, Aesthetic-Usability, Goal-Gradient, Serial Position, Von Restorff, Zeigarnik.

## The laws — iOS interpretations

1. **Fitts's Law** — primary CTAs should be large + close to the user's thumb. Bottom half of the screen (especially the bottom 1/3) is the prime zone on a phone. Tab bar already lives there; respect that.
2. **Hick's Law** — fewer choices = faster decisions. Tab bars with 5 tabs are at Apple's recommended cap. Sheets with 7 options should consider a hierarchy.
3. **Miller's Law** — 7 ± 2 chunks. Apply to forms (group fields), to lists (sections), to settings (groupings).
4. **Jakob's Law** — users expect your app to work like other iOS apps. Don't reinvent system patterns (share sheet, photo picker, date picker, tab bar).
5. **Doherty Threshold** — <400ms response time keeps users in flow. Anything slower needs a loading state.
6. **Tesler's Law** — complexity can't be removed, only moved. If onboarding is short, settings will be longer. Honest distribution.
7. **Peak-End Rule** — users remember the most intense moment and the end. Design first-success and end-of-task to be the peaks.
8. **Aesthetic-Usability Effect** — beautiful UIs feel easier to use. Don't dismiss aesthetics as decoration.
9. **Goal-Gradient Effect** — proximity to goal accelerates motivation. Progress bars on multi-step flows; "1 of 3" labels.
10. **Serial Position Effect** — first and last items in a list are remembered more. Order matters.
11. **Von Restorff Effect** — the odd-one-out is remembered. Primary CTA must be visually distinct.
12. **Zeigarnik Effect** — unfinished tasks pull attention. Use carefully — badges for unread, but not for guilt.

## Tier 1 (automated)

Minimal. Could measure:
- Tab count (Hick — >5 is a flag)
- Largest interactive target's frame in points (Fitts — primary CTA should be >= 44pt and ideally larger)
- Multi-step flow detection (look for `ProgressView` styled as bar, or page indicators)

## Tier 2 (AI on screenshot)

Per tab, identify which laws the design respects vs violates. Spot 1–3 high-leverage interventions.

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Multiple laws actively leveraged (visible peak moment, clear Von Restorff CTA, sensible chunking) |
| 4 | Laws respected by default; nothing breaks them |
| 3 | Some laws silently broken (no progress bar on long flow, all CTAs equal weight) |
| 2 | Multiple violations, design feels harder than it should |
| 1 | Fundamental violations that make the app feel laborious |

## Common findings + severity

| Finding | Severity |
|---|---|
| Primary CTA above the fold, far from thumb zone | Medium (Fitts) |
| 7-item tab bar (exceeds Hick + Apple's cap) | High (Hick + Jakob) |
| Multi-step flow with no progress indicator | Medium (Goal-Gradient) |
| All actions on a screen styled identically (no Von Restorff) | Medium |
| Reimplemented share/photo picker | Medium (Jakob) |

## What NOT to flag

- Two-tab apps (sometimes the right call — not all apps need 5 tabs)
- Carefully designed exceptions to Jakob (a strong creative direction can earn this)
