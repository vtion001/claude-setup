# Pass 03 — Sendable Conformance

**Weight:** 2×

## What this audits
Swift 6 strict-concurrency requirement: types crossing actor boundaries
must be `Sendable`. Missing conformance = compile error in strict mode.

## Tier 0
```bash
# Count types
total=$(grep -rln --include='*.swift' 'struct \|class \|enum ' <project-root> | wc -l)
# Sendable-annotated
sendable=$(grep -rln --include='*.swift' ': Sendable\|@unchecked Sendable' <project-root> | wc -l)
echo "ratio: $sendable / $total"
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | All cross-actor types Sendable; no `@unchecked` shortcuts; Swift 6 strict mode enabled |
| 4 | Most types annotated; a few `@unchecked` with comments justifying |
| 3 | Some annotations; Swift 6 not enabled |
| 2 | No annotations; relies on Swift 5 compatibility |
| 1 | `@unchecked Sendable` used as escape hatch across the board |

## Common findings
| Finding | Severity |
|---|---|
| Model type crossing actor boundary without `Sendable` | **Medium** |
| `@unchecked Sendable` on a type with mutable reference fields | **High** |
| `class` with mutable state declared Sendable | **Critical** |

## Recommended fix
Prefer `struct` (auto-Sendable when all fields are). For classes, use
`final` + `@MainActor` to satisfy.

## What NOT to flag
- iOS 16-targeted projects (Sendable predates Swift 6 strict checking)
- Apple-imported types
