# Pass 07 — Swift Evolution Adoption

**Weight:** 2×

## What this audits
Is the project using current Swift idioms?

- `@Observable` macro (Swift 5.9+) vs older `ObservableObject` for new code
- `async let` for concurrent loads
- `actor` for shared mutable state
- `Sendable` annotations
- Result builders for DSL-heavy code
- Macros (custom or built-in)
- `if let x` shorthand (Swift 5.7+)
- Typed throws (Swift 6+)

## Tier 0
```bash
# Observable adoption ratio
old=$(grep -rln "ObservableObject" --include='*.swift' . | wc -l)
new=$(grep -rln "@Observable" --include='*.swift' . | wc -l)
echo "old=$old new=$new"

# Sendable annotations
sendable=$(grep -rln ": Sendable\|@unchecked Sendable" --include='*.swift' . | wc -l)
echo "sendable_files=$sendable"
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | `@Observable` for new code, `actor` used appropriately, Sendable adopted, typed throws where suitable |
| 4 | Mostly modern; one or two ObservableObject holdouts |
| 3 | Modern features sprinkled in; older patterns dominate |
| 2 | Pre-async/await patterns (callback hell, DispatchQueue.main.async) |
| 1 | Code reads like Swift 3 — no async/await, no actors, no result builders |

## Common findings
| Finding | Severity |
|---|---|
| New file using `ObservableObject` instead of `@Observable` | **Low** |
| `DispatchQueue.main.async { }` instead of `await MainActor.run { }` | **Low** |
| Callback closures for async ops instead of `async/await` | **Medium** |
| `NotificationCenter` for cross-screen state instead of `@Observable` | **Medium** |
| No `Sendable` annotations on cross-actor types | **Medium** (defer to /ios-backend-audit for thread-safety) |

## Recommended fix
Pick one module, modernize. Don't bulk-rewrite. Reference
`https://forums.swift.org/c/evolution/18` for the proposal (SE-XXXX)
behind each modern pattern.

## What NOT to flag
- `ObservableObject` on existing code that works (not worth the churn)
- iOS 15- targets that can't use newer features
- Apple-imported APIs that haven't been modernized yet (`UIApplication` etc.)
