# Pass 07 — Nielsen's 10 Heuristics

**Weight:** 3×

## What this audits

Nielsen Norman Group's 10 usability heuristics applied to the iOS context. Foundational; weighted 3× because violations indicate systemic UX debt.

## The 10 — and what to look for on iOS

1. **Visibility of system status**
   - Is there always feedback for what's happening? (Loading spinners, progress bars, skeleton states, sync indicators.)
   - iOS specifics: progress on long-running AI calls, network indicator, pull-to-refresh visual.

2. **Match between system and real world**
   - Does the copy use the user's vocabulary, not engineering terms?
   - Dates spoken naturally ("In 3 hours") not technically ("2026-06-02T17:00:00Z").

3. **User control and freedom**
   - Easy escape hatches from every flow. Cancel buttons on sheets. Swipe-down to dismiss. Undo for destructive actions.
   - iOS specifics: standard nav-bar back button preserved, sheet dismiss respected.

4. **Consistency and standards**
   - Same patterns across tabs. Standard iOS components used where they exist.
   - iOS specifics: `.navigationTitle` used consistently, system share sheet not reimplemented, SF Symbols not mixed with custom icons arbitrarily.

5. **Error prevention**
   - Confirmations for destructive actions. Disabled-state for not-yet-valid submits. Friendly input formatting.
   - iOS specifics: keyboard type matches input, autocorrect off for codes/emails as appropriate.

6. **Recognition rather than recall**
   - Don't ask the user to remember things shown elsewhere. Show, don't query.
   - iOS specifics: recent items, smart defaults, auto-fill from system.

7. **Flexibility and efficiency of use**
   - Shortcuts for power users. Swipe actions on list rows. Quick actions from home-screen icon.

8. **Aesthetic and minimalist design**
   - Every element earns its place. (See Pass 06 for the broader version of this.)

9. **Help users recognize, diagnose, and recover from errors**
   - Errors say what happened, why, and what to do next. Not "Error: 401."

10. **Help and documentation**
    - In-context help. Tooltips. A help tab or in-Settings help section.

## Tier 1 (automated)

Light static signals:

- Grep for `Alert(` and `ConfirmationDialog(` — confirms destructive actions have confirms
- Grep for `keyboardType(` — confirms keyboard hints used
- Grep for `Cancel`, `Done`, `Back` strings — confirms escape hatches
- Grep for empty `catch { }` blocks — silent error eating

## Tier 2 (AI on screenshot + DOM-equivalent via XCUITest snapshot if available)

For each tab, give a per-heuristic verdict: pass / minor / major / critical, with a one-line rationale.

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All 10 heuristics pass on all tabs |
| 4 | 8–9 heuristics pass; minor issues on 1–2 |
| 3 | 6–7 heuristics pass; one major violation |
| 2 | 4–5 heuristics pass; multiple major violations |
| 1 | < 4 heuristics pass; systemic UX debt |

## Common findings + severity

| Finding | Severity |
|---|---|
| Destructive action without confirm | High |
| Error message that exposes internal codes | High |
| No loading indicator on a >300ms operation | Medium |
| Date shown as ISO timestamp in user-facing copy | Medium |
| Sheet without dismiss affordance | Medium |
| Form submit button enabled when invalid | Medium |
| No in-app help for first-time users | Low |
| Custom share sheet reimplemented instead of system one | Low |

## Recommended fixes

- Add `Alert.confirm()` patterns for destructive actions.
- Format dates with `RelativeDateTimeFormatter` for "in 3 hours".
- Use `.disabled(isFormInvalid)` on submit buttons.
- Replace empty `catch { }` with logged + user-facing error.

## What NOT to flag

- Power-user shortcuts on a consumer app (#7 is contextual)
- Lack of in-app help on a 3-screen utility (#10 is contextual)
