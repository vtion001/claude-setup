# Synthesizing the combined report (AI Layer 3 + 4)

After all 6 subagents have returned, walk through these steps to produce
`COMBINED-REPORT.md`.

## Step 1: Aggregate findings

Build a flat list of all findings from all audits. Each entry:
```json
{
  "source_audit": "security",
  "id": "F-001",
  "namespaced_id": "SEC-F-001",
  "severity": "Critical",
  "pass": "secrets-storage",
  "file": "Pookoo/Services/GmailService.swift",
  "line": 142,
  "title": "...",
  "theme": "token-storage"  // assigned in step 2
}
```

## Step 2: AI Layer 3 — theme assignment

Cluster findings by root cause. A theme groups findings whose fixes
overlap. Pre-defined themes (extensible):

- **token-storage** — UserDefaults/file token persistence, missing
  Keychain, missing biometric ACL, no test coverage of token flows
- **main-thread-contention** — @MainActor + I/O, view body jank, missing
  perf tests
- **dark-mode-gap** — hardcoded white/black, no ColorScheme, no
  snapshot variants
- **missing-test-infrastructure** — 0 snapshot, 0 Maestro, 0 perf, low
  XCTest coverage
- **integration-opportunities** — App Intents, WidgetKit, Live
  Activities not adopted
- **ats-and-network-hardening** — local-network exceptions, no cert
  pinning, missing retry/backoff
- **a11y-foundations** — no performAccessibilityAudit, hit targets,
  Dynamic Type, motion-reduce
- **swift-modernization** — pre-Swift-6 patterns, ObservableObject
  instead of @Observable, callback-based async
- **dependency-and-lint-discipline** — no SwiftLint, no SwiftFormat,
  no Periphery, no lockfile

For each finding, assign exactly one theme. If a finding doesn't fit a
theme, create an ad-hoc theme name (kebab-case).

## Step 3: Compute iHS

```
weights = {security: 3, backend: 2, "ui-impl": 2, qa: 2, integration: 1, "code-review": 1}
ran = [a for a in audits if a in results]  # exclude skipped
total = sum(weights[a] for a in ran)
weighted = sum(results[a]["score"] * weights[a] for a in ran)
iHS = round(weighted / (100 * total) * 100)
```

Map to range label per `_ios-shared/scoring-rubric-shared.md`:
- 90–100 → "Ship-ready"
- 75–89 → "Production-ready"
- 60–74 → "Needs attention"
- 40–59 → "Design debt"
- <40 → "Critical"

## Step 4: AI Layer 4 — narrative executive summary

Write as a senior iOS engineer would brief a CTO. Cover:
1. **One-sentence verdict** — ship-ready vs hold vs block
2. **Posture by domain** — 1 sentence per audit's score
3. **Top 3 themes** — name, why it matters, 1-line fix direction
4. **Recommended sprint plan** — ordered by impact-to-effort

## Step 5: Critical-findings table

All severity=Critical findings, ordered by:
1. Audit weight (security first)
2. Severity
3. File path

## Step 6: Ship-readiness verdict

```
SHIP    — no Critical findings, iHS ≥ 75
HOLD    — Critical findings but they're scoped to a single theme that can be hot-fixed
BLOCK   — Multiple Critical findings across themes; needs a focused sprint
```

## Step 7: Write the files

- `<project>/ios-audit/COMBINED-REPORT.md` (narrative, ≤ 1500 words)
- `<project>/ios-audit/COMBINED-SCORECARD.md` (1 page)
- `<project>/ios-audit/COMBINED.json` (machine-readable, schema-versioned)
- `<project>/ios-audit/baseline.json` (only if `--baseline`)

## Step 8 (--linear)

For each theme:
- Create one Linear issue with:
  - Title: "[iOS] <theme>: <one-line summary>"
  - Description: theme paragraph + bulleted findings (namespaced ids + file:line)
  - Labels: `["iOS", "ios-audit", "theme/<theme-name>"]`
  - Priority: max severity within the theme → Linear priority mapping
- Return the issue URLs in the combined report's appendix
