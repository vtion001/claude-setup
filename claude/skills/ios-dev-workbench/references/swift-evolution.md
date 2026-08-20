# Swift Evolution — Accepted Proposals Worth Adopting

iOS audits cite SE-XXXX when recommending modernization. Updated June 2026.

## Swift 6 (strict concurrency)
- **SE-0337 — Incremental migration to concurrency checking** (5.6+, default in 6)
- **SE-0411 — Isolated default value expressions**
- **SE-0413 — Typed throws** — `func foo() throws(SpecificError) -> ...`
- **SE-0420 — Inheritance of actor isolation**
- **SE-0421 — Generalize effect polymorphism for AsyncSequence**

## Swift 5.9 — Observation
- **SE-0395 — Observation** — `@Observable` macro (use for new ObservableObjects)
- **SE-0395 + Apple WWDC23 Discover Observation in SwiftUI** (Session 10149)

## Swift 5.9 — Macros
- **SE-0382 — Expression macros**
- **SE-0389 — Attached macros**

## Swift 5.7 — Quality of life
- **SE-0345 — `if let` shorthand** — `if let x { }` instead of `if let x = x { }`
- **SE-0353 — Constrained existential types**

## Async (Swift 5.5)
- **SE-0296 — Async/await**
- **SE-0297 — Concurrency interoperability with Objective-C**
- **SE-0300 — Continuations for interfacing async tasks with synchronous code**
- **SE-0302 — Sendable**
- **SE-0306 — Actors**

## Result builders (Swift 5.4)
- **SE-0289 — Result builders** — what underpins SwiftUI's ViewBuilder

## How audits use this list

When `/ios-code-review` pass 07 (`swift-evolution-adoption`) finds an
opportunity, it cites:
- The SE-XXXX number
- The corresponding URL: `https://github.com/apple/swift-evolution/blob/main/proposals/<NNNN>-name.md`
- The minimum iOS / Swift version
- 1-line summary

Don't recommend a proposal unless the project's deployment target
supports the matching Swift / iOS version.
