---
name: ios-backend-audit
description: >
  iOS backend / networking / persistence / concurrency audit. Covers
  URLSession patterns, Swift Concurrency correctness (async/await/actors/
  Sendable), Combine, persistence (UserDefaults / SwiftData / Core Data /
  GRDB), retry/backoff, request cancellation, cache headers, background
  tasks, and network reachability. Benchmarked against the Swift 6
  Concurrency model.

  Triggers: "ios backend audit", "swift concurrency check", "actor audit",
  "url session review", "core data audit", "swiftdata performance",
  "/ios-backend-audit", "sendable check".

  Flags:
    --quick           # Tier 0 only (grep + lint)
    --pass <names>    # Cherry-pick
    --runtime         # Enable Proxyman runtime capture (optional, brew install --cask proxyman)
    --linear          # File theme-grouped findings

  Sibling skills:
    - /ios-security-audit owns secrets / Keychain / ATS / cert pinning
    - /ios-integration-audit owns OAuth flow correctness, deep links
---

# iOS Backend Audit

Static + runtime audit for SwiftUI iOS apps' networking, persistence,
and concurrency. Benchmarked against the **Swift 6 Concurrency model**
(strict checking, `Sendable`, `@MainActor` discipline) and Apple's
networking framework canonical patterns.

## Prerequisites

- macOS with Xcode 26.5 + DEVELOPER_DIR
- An iOS project at cwd
- Optional: Proxyman (`brew install --cask proxyman`) for runtime probes

## Invocation

```
/ios-backend-audit               # All 9 passes
/ios-backend-audit --quick       # Static only
/ios-backend-audit --pass swift-concurrency-correctness,sendable-conformance
/ios-backend-audit --runtime     # With Proxyman traffic capture
```

## Pass Names

`url-session-patterns`, `swift-concurrency-correctness`,
`sendable-conformance`, `persistence-layer`, `retry-backoff`,
`request-cancellation`, `cache-headers`, `background-tasks`,
`network-reachability`

## Workflow

### Phase 0: Auto-detect
Same shared detect. Additionally:
- Identify all Service files in `Services/`
- Identify persistence pattern (UserDefaults / SwiftData / Core Data / GRDB)
- Identify concurrency model (`@MainActor`, `actor`, callbacks)

### Phase 1: Tier 0 — static
For each pass, run its static scan. Aggregate to JSON.

### Phase 2: Tier 1 — runtime (`--runtime` only)
- Boot sim
- Install app
- Capture traffic via Proxyman MCP
- Analyze: TTFB, retries, redirects, header completeness

### Phase 3: Tier 2 — AI reasoning
Apply per-pass heuristics; reason about concurrency correctness which
lints miss (e.g., a `@MainActor` service doing blocking I/O).

### Phase 4: Source cross-reference
Tag with `file:line`.

### Phase 5: Report
`<project>/ios-audit/ios-backend-audit/`.

## Rules

- **Defer to /ios-security-audit** for cert-pinning / ATS / token storage.
- **Concurrency correctness > coding style.** Don't flag `DispatchQueue.main`
  unless it's actually wrong (legacy code with no async/await alternative
  is fine).
- **Persistence choice is a one-way door.** Don't recommend rewriting
  UserDefaults → SwiftData unless the data shape requires it.

## Reference files

- `references/passes/01-url-session-patterns.md`
- `references/passes/02-swift-concurrency-correctness.md`
- `references/passes/03-sendable-conformance.md`
- `references/passes/04-persistence-layer.md`
- `references/passes/05-retry-backoff.md`
- `references/passes/06-request-cancellation.md`
- `references/passes/07-cache-headers.md`
- `references/passes/08-background-tasks.md`
- `references/passes/09-network-reachability.md`
- `references/scoring-rubric.md`
- `references/report-template.md`
- `references/tech-stack.md`
- `references/deep-references.md`
- `scripts/install-tools.sh`
- `scripts/concurrency-scan.sh`
- `scripts/persistence-scan.sh`
