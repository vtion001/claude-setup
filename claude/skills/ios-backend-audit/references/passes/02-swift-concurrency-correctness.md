# Pass 02 — Swift Concurrency Correctness

**Weight:** 3×

## What this audits
The hard one: does the app's concurrency model survive Swift 6 strict
checking? Specifically:

1. **`@MainActor` discipline** — only UI-facing services
2. **`actor` usage** — for shared mutable state across tasks
3. **No mixing** — `DispatchQueue` + `async/await` indicates incomplete migration
4. **Task lifetime** — `Task { }` that should be `Task.detached` or vice versa
5. **`@MainActor` doing I/O** — blocks UI thread

## Tier 0
```bash
# @MainActor doing I/O
grep -rln --include='*.swift' -B 5 '@MainActor' <project-root> | grep -E 'URLSession|URLRequest|FileManager|JSONDecoder.*decode|JSONEncoder.*encode'

# Mixing patterns
grep -rln --include='*.swift' 'DispatchQueue\.main\|DispatchQueue\.global' <project-root> \
  | xargs grep -l 'async\|await\|actor' 2>/dev/null

# Unstructured Task usage
grep -rn --include='*.swift' '\bTask {\|Task\.detached' <project-root>

# Force-tries on async
grep -rn --include='*.swift' 'try!.*await\|await.*try!' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | All async APIs. Actors for shared state. @MainActor only on UI. No mixing. Swift 6 mode would compile clean. |
| 4 | Mostly correct. 1-2 @MainActor I/O cases |
| 3 | Inconsistent migration; old + new patterns mixed |
| 2 | `@MainActor` blocking I/O. `DispatchQueue.main.async` mixed with await |
| 1 | All callback-based. Force-tries. Tasks that capture self without weak. |

## Common findings
| Finding | Severity |
|---|---|
| `@MainActor` class doing network I/O without `Task.detached` | **High** |
| `actor` mutated from outside without `await` | **Critical** (compile error in Swift 6) |
| `Task { ... }` capturing `self` strongly (retain cycle) | **High** |
| `try!` on async call (will crash on any error) | **High** |
| `DispatchQueue.main.async { }` mixed with async/await | **Medium** |
| Missing `Sendable` annotations (defers to pass 03) | **Medium** |

## Pookoo-specific
`GmailService` is `@MainActor` but does OAuth I/O (per exploration).
Recommend: move to actor or non-isolated class, hop to MainActor only
for UI updates.

## What NOT to flag
- Legacy delegate callbacks where no async alternative exists
- One-line `Task { }` for fire-and-forget side effects when retain
  cycles aren't possible
