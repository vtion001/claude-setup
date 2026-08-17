---
name: ios-audit-pipeline
description: >
  Orchestrator. Spawns all 6 iOS audit subagents in parallel against the
  cwd's SwiftUI project and synthesizes one combined report with overall
  iOS Health Score (iHS), theme-grouped findings, and optional Linear
  filing. The single-command entry point for "audit my iOS app."

  Triggers: "audit my ios app", "run all ios audits", "full ios audit",
  "ios health check", "/ios-audit-pipeline", "ios audit pipeline",
  "audit pookoo", "complete ios audit".

  Flags:
    --skip <audit1,audit2>   # Skip specific audits (e.g. --skip qa,integration)
    --quick                  # Pass --quick to every audit
    --linear                 # File theme-grouped issues
    --baseline               # Save current scores to ios-audit/baseline.json
    --compare                # Compare current run against last baseline

  Sibling skills:
    - Spawns all 6 ios-*-audit skills via subagents
    - Reuses /swiftui-ux-audit results if a recent run exists in ios-audit/
---

# /ios-audit-pipeline — Combined iOS Audit Orchestrator

Single-command runner for the full iOS audit suite. Spawns the 6 audit
subagents **in parallel** (one message, 6 tool calls), collects their
structured JSON summaries, then synthesizes a single
`COMBINED-REPORT.md` with overall **iOS Health Score (iHS)** weighted
across the audits per `_ios-shared/scoring-rubric-shared.md`.

## Prerequisites

- An iOS project at cwd
- All 6 audit skills installed in `~/.claude/skills/` (verify via `ls`)
- All 6 subagents in `~/.claude/agents/`

## Invocation

```
/ios-audit-pipeline                          # Full run
/ios-audit-pipeline --quick                  # Static-only across all
/ios-audit-pipeline --skip qa,integration    # Skip selected
/ios-audit-pipeline --linear                 # File theme-grouped issues
/ios-audit-pipeline --baseline               # Snapshot current scores
/ios-audit-pipeline --compare                # Diff vs last baseline
```

## Workflow

### Phase 0: Auto-detect + setup

1. Run `_ios-shared/scripts/detect-ios-project.sh` — fail loud if no iOS project.
2. Create `<project>/ios-audit/` if missing.
3. Print the audit plan (which 6 audits will run, --quick or not).

### Phase 1: Parallel dispatch

Issue **a single message with 6 Agent tool calls** (one per subagent),
all in parallel. The 6 subagents:

| Subagent | Skill |
|---|---|
| `ios-ui-auditor` | `/ios-ui-impl-audit` |
| `ios-backend-auditor` | `/ios-backend-audit` |
| `ios-integration-auditor` | `/ios-integration-audit` |
| `ios-security-auditor` | `/ios-security-audit` |
| `ios-qa-auditor` | `/ios-qa-audit` |
| `ios-code-reviewer` | `/ios-code-review` |

Pass `--skip` exclusions through to the matching subagents (skip the
spawn entirely if the audit is in the skip list).

### Phase 2: Collect results

Each subagent returns its structured summary + a JSON findings block.
Collect them into a single in-memory dict keyed by audit name.

### Phase 3: AI Layer 3 — cross-audit theme synthesis

Group findings across audits by root cause. Common themes seen in
Pookoo-class apps:

- **token-storage** (security 01 + backend 04 + qa 01 — Gmail OAuth tokens
  in UserDefaults, no Keychain wrapper, no test coverage of token refresh)
- **main-thread-contention** (backend 02 + ui-impl 06 + qa 05 — `@MainActor`
  doing I/O, view body jank, no XCTMetric)
- **dark-mode-gap** (ui-impl 03 + code-review 04 — hardcoded `Color.white`,
  no ColorScheme adaptation, no snapshot tests across schemes)
- **missing-test-infrastructure** (qa 03 + qa 04 + code-review 03)
- **integration-opportunities** (integration 04 + 05 — App Intents +
  WidgetKit not adopted)

For each theme, write 1 paragraph + unified fix recommendation + effort estimate.

### Phase 4: Compute iOS Health Score (iHS)

Per `_ios-shared/scoring-rubric-shared.md` default weights:

```
iHS = (
    security_score × 3 +
    backend_score  × 2 +
    ui_impl_score  × 2 +
    qa_score       × 2 +
    integration_score × 1 +
    code_review_score × 1
) / (100 × 11) × 100
```

If `--skip` excluded an audit, its weight is dropped from both
numerator and denominator.

### Phase 5: Write combined report

Output to `<project>/ios-audit/COMBINED-REPORT.md`:

```markdown
# iOS Audit Combined Report — <project>
**Date:** YYYY-MM-DD
**iHS:** NN/100 (<range label>)

## Executive Summary
[3-6 paragraphs covering: posture overview, top 3 themes, ship-readiness verdict, recommended sprint scope]

## Per-Audit Scores
| Audit | Score | Range |
|---|---|---|
| Security | NN/100 | range |
| Backend | NN/100 | range |
| UI Impl | NN/100 | range |
| QA | NN/100 | range |
| Integration | NN/100 | range |
| Code Review | NN/100 | range |

## Cross-Audit Themes
### Theme 1 — <name>
[paragraph + unified fix + effort]

## Critical Findings (across all audits)
[All severity=Critical findings, ordered by audit weight then severity]

## Ship-Readiness Verdict
- Critical findings: N
- High findings: M
- Recommendation: SHIP / HOLD / BLOCK

## Recommended Sprint Plan
1. [highest-impact item]
2. ...

## Appendix
- Per-audit report links
- Configurations used (--skip, --quick, etc.)
```

Also write `<project>/ios-audit/COMBINED-SCORECARD.md` and
`<project>/ios-audit/COMBINED.json` (machine-readable).

### Phase 6 (--baseline): snapshot

Save the current scores + finding counts to `<project>/ios-audit/baseline.json`.
Future `--compare` runs diff against this.

### Phase 7 (--linear): file issues

One Linear issue per **theme** (not per finding). Labels:
`["iOS", "ios-audit"]`. Priority from severity per shared rubric.

## Rules

- **Always spawn in parallel.** Sequential dispatch defeats the purpose.
  Use a single message with 6 Agent tool calls.
- **Don't synthesize without all 6 results.** Wait for each subagent's
  return before computing iHS.
- **Don't auto-fix anywhere.** Per-skill rules apply; orchestrator never
  bypasses them.
- **Stay short in the report.** The combined report is for executives;
  per-audit reports already carry detail. Aim for ≤ 1500 words in the
  combined report.
- **Honor the user's threat model.** If CLAUDE.md declares L2,
  pass `MASVS_LEVEL=L2` env to the security subagent.

## Reference files

- `scripts/dispatch-audits.md` — instructions for the parallel-dispatch step
- `scripts/synthesize-report.md` — instructions for AI Layer 3 + report writing
- Shared rubric: `~/.claude/skills/_ios-shared/scoring-rubric-shared.md`
- Shared template: `~/.claude/skills/_ios-shared/report-template-shared.md`
