# Pass 05 — Micro-interactions

**Weight:** 2×

## What this audits

Whether every interactive element responds in a way that signals "I heard you" — pressed states, haptics, transitions, loading states, optimistic feedback. The web equivalent is "hover feedback"; on iOS, hover doesn't exist on touch — the bar is **press feedback** + **haptic** + **transition into next state**.

## Tier 1 (automated)

### Static

```bash
# Haptic call sites — confirms the project knows about haptics
rg --no-heading -n 'UIImpactFeedbackGenerator|UINotificationFeedbackGenerator|UISelectionFeedbackGenerator|\.sensoryFeedback\(' <project>

# Custom button styles
rg --no-heading -n 'struct \w+: ButtonStyle' <project>

# Animation usage
rg --no-heading -n '\.animation\(' <project>
rg --no-heading -n 'withAnimation\(' <project>
```

Collect: haptic call count, custom `ButtonStyle` definitions, `withAnimation` call count.

### Runtime

For each primary CTA on each tab:

1. Maestro flow taps the CTA
2. Capture two screenshots: immediately before tap, ~150ms after tap
3. If they're pixel-identical, the button has no press feedback

## Tier 2 (AI on screenshot pair)

1. **Press feedback** — does the button visibly respond between the before/after frames? (Scale-down, opacity, color shift?)
2. **Transition smoothness** — is the next screen entering with a SwiftUI transition or jump-cutting?
3. **Loading states** — when the AI/flight/import button is tapped, does a spinner/skeleton/progress appear?
4. **Optimistic UI** — does the action feel instant, or does the user wait for the network?
5. **Empty states** — first-launch screens with no data: do they educate, or just look broken?
6. **Pull-to-refresh** — present where it should be (Home, Flights, Tips feed)?
7. **Toast / banner feedback** for non-modal success/failure?
8. **Disabled-state distinction** — is a disabled CTA visually distinct from an enabled one, AND from a primary button just at rest?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Every primary action has press feedback + haptic + transition. Loading + empty + error states all designed. |
| 4 | Primary actions feel responsive. 1–2 secondary actions missing feedback. |
| 3 | Some buttons feel "dead" — no visible press change. Loading state exists but generic. |
| 2 | Most actions lack press feedback. Empty/loading states under-designed. |
| 1 | Tapping things feels broken; no transitions; no haptics. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Primary CTA with no press feedback (identical before/after) | High |
| No haptic on destructive confirm | Medium |
| Loading state = blank screen | High |
| Empty state = empty screen with no copy | High |
| Jump-cut between tabs / sheets (no `.transition(...)`) | Low |
| Disabled-state same color as primary at rest | Medium |
| No pull-to-refresh on a list that obviously fetches | Medium |

## Recommended fixes

- Wrap CTAs in a custom `ButtonStyle` that applies `.scaleEffect(configuration.isPressed ? 0.97 : 1)` and `.opacity(configuration.isPressed ? 0.85 : 1)`.
- Add `.sensoryFeedback(.impact, trigger: <state>)` for material actions (iOS 17+).
- Add `.sensoryFeedback(.success/.error, trigger: <state>)` for outcomes.
- Replace blank-loading with `ShimmerView` (if present) or `ProgressView()`.
- Add a friendly empty-state component with copy + illustration + suggested next action.

## What NOT to flag

- Hover states — iOS touch UIs don't have them
- `onMouseEnter`-style web feedback expectations
- Press feedback on text-only labels that aren't tappable
