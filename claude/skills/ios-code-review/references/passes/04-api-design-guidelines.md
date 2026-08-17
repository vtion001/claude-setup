# Pass 04 — Swift API Design Guidelines Conformance

**Weight:** 3×

## What this audits
Compliance with the canonical Swift API Design Guidelines
(https://www.swift.org/documentation/api-design-guidelines/). The audit
covers:

1. **Clarity at the point of use** — function names read fluently at the call site
2. **Naming based on side effects** — verb phrases for mutators, noun phrases for non-mutators (`x.sort()` vs `x.sorted()`)
3. **First arg labels** — appropriate use/omission per the guidelines
4. **Boolean assertions** — read as assertions about the receiver (`x.isEmpty`)
5. **Documentation** — public APIs documented with the `///` markup
6. **Avoid abbreviations** — full words preferred (`background` not `bg`)
7. **Value types over reference types** — when state isn't shared

## Tier 0
```bash
# Public APIs without documentation
swiftlens analyze --rule missing-public-docs <project-root>

# Find probable abbreviations
grep -rn --include='*.swift' -E '\b(bg|fg|btn|img|svc|cfg|util|mgr|ctx|usr|num|str|val|fn|cb|arg|param|ret)[A-Z]' <project-root>

# Find force-unwraps in non-test code
grep -rn --include='*.swift' --exclude-dir='*Tests' '!' <project-root> \
  | grep -E '\b\w+!(\s|\.|$|,|\)|\])' | head -50
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Names read fluently. All public APIs documented. No abbreviations. Value types preferred. |
| 4 | Mostly clean. 1-2 abbreviations or naming inconsistencies. |
| 3 | Mix of compliant + casual naming. Some public APIs missing docs. |
| 2 | Inconsistent naming pattern across modules. Many missing docs. |
| 1 | Java-style getters/setters, abbreviations, no docs, reference types where value types fit. |

## Common findings
| Finding | Severity |
|---|---|
| Public type without doc comment | **Medium** |
| `getUserName()` instead of `var userName: String { get }` | **Medium** |
| `mngr`, `svc`, `bg` abbreviations | **Low** |
| `sort(array:)` instead of `array.sort()` (member function pattern) | **Medium** |
| `func setX(_ x: ...)` instead of `var x: { set/get }` | **Medium** |
| `class` used where `struct` would suffice (value semantics not needed) | **Medium** |

## Recommended fixes
- Rename per "fluent at call site" — read each call site aloud
- Add `///` doc to every public symbol
- Replace abbreviations with full words
- Convert classes to structs when no shared mutable state

## What NOT to flag
- Apple-imported APIs (`UIView`, `NSObject`) — out of scope
- View-builder DSL names (`HStack`, `VStack`) — Apple convention
- Test names with descriptive prefixes (`testThat_UserCanLogin`) — test conventions trump guidelines
