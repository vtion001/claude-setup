# Pass 06 — View Body Performance

**Weight:** 2×

## What this audits
Are SwiftUI View bodies efficiently composed? Common pitfalls:
- Single body too complex → type-checker timeout or re-renders entire tree
- `LazyVGrid`/`LazyVStack` for >50 items (not regular VStack)
- `ForEach` with non-stable id (causes diff churn)
- Expensive computations inside body
- Missing `id:` or `EquatableView` to prevent re-renders

## Tier 0
```bash
# Files exceeding 500 lines (likely complex bodies)
find <project-root> -name "*.swift" -exec wc -l {} \; | awk '$1 > 500' | head -10

# ForEach with non-stable ids
grep -rn --include='*.swift' 'ForEach(.*,\s*id:\s*\\.self)' <project-root> | head -20

# Body using Date()/UUID() (recomputes every render)
grep -rn --include='*.swift' -A 5 'var body:' <project-root> | grep -E 'Date\(\)|UUID\(\)' | head
```

## Tier 1
Instruments → SwiftUI instrument with the 4 hitch-attribution lanes.
Open `App Activity` template, replay a tap-through, look for hot bodies.

## Scoring
| Score | Criteria |
|---|---|
| 5 | All bodies < 50 lines OR cleanly extracted to subviews. Lazy stacks for long lists. Stable ids. |
| 4 | Mostly clean; 1-2 large bodies |
| 3 | Several large bodies but no measurable perf issue |
| 2 | Type-check timeouts in places (use of @ViewBuilder helper) |
| 1 | Scrolling jank; over-render in profiler |

## Common findings
| Finding | Severity |
|---|---|
| `id: \.self` on a non-uniquely-identifiable collection | **High** (silent diff bug) |
| `body` over 200 lines without sub-view extraction | **Medium** |
| `VStack` rendering 100+ items (use LazyVStack) | **Medium** |
| `Date()` called inside `body` | **Medium** |

## Pookoo
CLAUDE.md mentions: "type-check too complex" rule, extracted to private
View structs. Strong positive — already aware. Verify via Instruments.

## What NOT to flag
- Short bodies that look complex but are functional patterns
- Lazy containers used correctly for short lists (no perf cost)
