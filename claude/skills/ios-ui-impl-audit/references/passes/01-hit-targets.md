# Pass 01 — Hit Target Sizes

**Weight:** 3×
**Standard:** Apple HIG (44×44 pt minimum) + WCAG 2.5.5

## What this audits
Every interactive element (Button, NavigationLink, .onTapGesture)
provides a minimum 44×44 pt tap area. Smaller = users miss the target.

## Tier 0
```bash
# Buttons with explicit small frames
grep -rn --include='*.swift' -E '\.frame\(width: [12][0-9]?, height: [12][0-9]?\)' <project-root>

# Image-only buttons (likely small)
grep -rn --include='*.swift' -B 1 'Image(systemName' <project-root> | grep -E 'Button|onTapGesture' | head -50
```

## Tier 1 (runtime via XCUI)
`XCUIApplication.performAccessibilityAudit(for: [.hitRegion])` — flags any
target below the threshold.

## Scoring
| Score | Criteria |
|---|---|
| 5 | All interactive elements >= 44×44 pt (verified via runtime audit) |
| 4 | Mostly compliant; 1-2 edge cases (close buttons in sheets) |
| 3 | Several borderline targets |
| 2 | Common targets (icons, list disclosure) < 44 |
| 1 | Multiple critical buttons < 30 pt |

## Common findings
| Finding | Severity |
|---|---|
| `Image(systemName:)` button without `.frame(minWidth: 44, minHeight: 44)` | **Medium** |
| Custom close (×) icon in modal at 24×24 | **Medium** |
| Tab bar items meeting HIG by default | **Not a finding** |
| List row disclosure indicators (handled by system) | **Not a finding** |

## Recommended fix
```swift
// BEFORE
Button { ... } label: { Image(systemName: "xmark") }

// AFTER
Button { ... } label: {
    Image(systemName: "xmark")
        .frame(width: 44, height: 44)   // Or .contentShape(Rectangle())
        .contentShape(Rectangle())
}
```

## What NOT to flag
- System-provided controls (tab bar, navigation bar) — Apple ensures HIG
- Decorative icons that are NOT interactive
