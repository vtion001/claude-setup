# Pass 07 — Reduce Motion

**Weight:** 2×

## What this audits
Does the app respect `accessibilityReduceMotion`? Animations that don't
honor it can cause motion sickness for vestibular-sensitive users — and
fail Apple's accessibility review.

## Tier 0
```bash
# Animations
grep -rn --include='*.swift' '\.animation(\|withAnimation' <project-root> | wc -l
# Reduce-motion awareness
grep -rn --include='*.swift' 'accessibilityReduceMotion' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | All non-essential animations check `accessibilityReduceMotion`; transitions are subtle (opacity, not slide) when reduced |
| 4 | Major animations handled; minor decorative ones not |
| 3 | Awareness in 1-2 places |
| 2 | No awareness anywhere |
| 1 | Animation-heavy app that ignores the system setting |

## Recommended fix
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

VStack { ... }
    .animation(reduceMotion ? .none : .spring(), value: state)
```

## What NOT to flag
- Apps that don't animate (utility apps, list-only apps)
- Native list/sheet animations (system-managed, respect setting automatically)
