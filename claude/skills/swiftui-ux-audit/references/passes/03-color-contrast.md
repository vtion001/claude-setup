# Pass 03 — Color & Contrast

**Weight:** 2×

## What this audits

Whether color is used semantically (state, brand, severity) and meets contrast thresholds. iOS gets two sources of truth:

1. **Static** grep for `Color(hex:)` / `Color(red:...)` outside the token file
2. **Runtime** `XCUIApplication.performAccessibilityAudit(for: .contrast)` returns Apple's first-party contrast verdict

## Tier 1 (automated)

### Static

```bash
# Color(hex:) outside Theme + Models
rg --no-heading -n 'Color\(hex:|Color\(red:' <project> \
  | grep -v "<token-file>" | grep -v "/Models/"
```

Note: `Models/` is allow-listed because category enums frequently declare per-category hex colors driven from data — that is legitimate.

Also collect the token color palette from the detected file (any `static let <name>: Color`).

### Runtime

XCUITest runner result for `.contrast` audit type per tab. Each result has:
- `description` — the violating element's a11y label
- `element` — the XCUIElement (frame, screenshot)
- `severity` — Apple's internal classification

## Tier 2 (AI on screenshot)

1. **Brand color discipline** — is the primary brand color reserved for primary actions, or is it sprinkled?
2. **Semantic color use** — are red/green/yellow used for error/success/warning consistently and not for decoration?
3. **Background hierarchy** — are surfaces / elevated surfaces / brand-tinted surfaces distinct?
4. **Color-only conveyance** — does any state rely on color alone? (A11y red flag.)
5. **Dark mode** — if the project supports dark mode, do colors invert sensibly? (Capture both schemes if `--dark-mode` flag implemented; v1 default is light only.)
6. **Tab bar tinting** — does the selected-tab tint match the brand color, and does the unselected tint have enough contrast?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All colors named tokens. XCUI contrast pass with 0 findings. Semantic discipline maintained. |
| 4 | 1–2 Low contrast findings or a single `Color(hex:)` outside Models. |
| 3 | 3–5 contrast findings OR brand color used for non-primary decoration. |
| 2 | High-severity contrast violations on primary text or CTAs. |
| 1 | Critical contrast failures on primary actions; color used as the only signal for state. |

## Common findings + severity

| Finding | Severity |
|---|---|
| WCAG AA contrast fail on primary text (XCUI flag) | Critical |
| WCAG AA contrast fail on secondary text | High |
| Brand color used for body text (not just accents) | Medium |
| `Color(hex:"...")` in a `View` file outside Models | Medium |
| Error/success states relying on color only (no icon) | High (a11y) |
| Inconsistent disabled-state tint across tabs | Low |

## Recommended fixes

- Map raw `Color(hex:)` literals to named tokens (manual; auto-fix only when token exists in palette and is unique).
- For XCUI contrast violations: bump foreground to the next darker token OR add a backdrop scrim.
- For color-only state: pair with an SF Symbol (`Image(systemName: "checkmark.circle.fill")`, `"exclamationmark.triangle.fill"`).

## What NOT to flag

- Per-category data colors in `Models/` (food=orange, safety=green) — those are content, not chrome
- Splash-screen / launch-screen tints — they live in `Info.plist`, not in views
- Live preview / `#Preview { }` blocks — those don't ship
