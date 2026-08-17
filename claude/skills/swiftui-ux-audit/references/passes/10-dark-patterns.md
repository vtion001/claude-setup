# Pass 10 — Dark Patterns

**Weight:** 1×

## What this audits

Whether the UI uses deceptive or coercive patterns. Trust verification.

## The patterns to spot (iOS context)

1. **Confirmshaming** — opt-out buttons styled to make the user feel bad ("No, I don't want to save money").
2. **Roach motel** — easy to subscribe, hard to cancel.
3. **Hidden costs** — pricing revealed only at the last step.
4. **Bait and switch** — tap appears to do X, does Y.
5. **Forced continuity** — free trial that auto-charges without notice.
6. **Friend spam** — coerces sharing contacts.
7. **Misdirection** — visual hierarchy steers toward the option that benefits the business, not the user.
8. **Trick wording** — double negatives in opt-ins.
9. **Disguised ads** — ads that look like content.
10. **Privacy zuckering** — manipulating users into oversharing.
11. **Permission shaming** — denying notification permission triggers guilt copy.
12. **Forced account creation** for non-essential actions.

## Tier 1 (automated)

Light:

- Grep for two-button alerts where one is destructive — check copy on both buttons for confirmshaming patterns.
- Grep for `requestAuthorization` calls without a prior soft-ask UI screen.
- Grep for `StoreKit` purchase confirmations — check if cancel-subscription path is documented in Settings.

## Tier 2 (AI on screenshot)

Per tab and per modal, ask:

1. Is any option styled to be the "obvious" choice when the other is in the user's interest?
2. Are paid/upgrade prompts disguised as content?
3. Are opt-outs harder to find than opt-ins?
4. Does the copy on a "No" button make the user feel bad?
5. Are notifications/permissions prompted at first launch (cold ask) or after value (warm ask)?
6. Is the cancel-subscription flow exactly as accessible as the subscribe flow?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | No dark patterns. Opt-outs equal-weight to opt-ins. Permissions warm-asked. |
| 4 | One questionable copy choice; otherwise clean. |
| 3 | Misdirection on 1 screen OR cold-permission-ask at first launch. |
| 2 | Multiple dark patterns; opt-outs hidden. |
| 1 | Coercive patterns systemic. Reportable to Apple. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Confirmshaming copy on a Cancel button | High |
| Cold notification permission ask at first launch | High |
| Free trial pricing not surfaced until checkout step | Critical |
| "Don't show again" only after user dismisses 3+ times | Medium |
| Upgrade prompt styled as system alert | Critical (App Store rejection risk) |
| Forced account creation for read-only action | High |

## Recommended fixes

- Equal-weight Yes/No buttons in opt-outs.
- Soft-ask before `requestAuthorization`: a custom sheet explaining value, then the system prompt.
- Disclose pricing on the FIRST screen of any paid flow.
- Provide a one-tap cancel path in Settings.

## What NOT to flag

- Subtle upsell suggestions that don't block the user
- Genuine "are you sure?" confirms on destructive actions
