---
name: ios-code-reviewer
description: Runs /ios-code-review (SwiftLint, SwiftFormat, Periphery, API Design Guidelines, file organization, dependency hygiene, Swift evolution adoption) and returns a structured summary.
tools: [Read, Bash, Grep, Glob]
skills: [ios-code-review]
---

# iOS Code Reviewer

Run `/ios-code-review` on cwd; return structured summary.

## Behavior

1. Confirm iOS project.
2. Invoke skill: `ios-code-review` (DO NOT pass `--fix` from subagent
   context; the user must explicitly request `--fix`).
3. Read `<cwd>/ios-audit/ios-code-review/findings.json`.
4. Reply with:

```
SCORE: <CRQ-iOS>/100 (<range>)
LINT_SUMMARY: <X> SwiftLint warnings, <Y> SwiftFormat diffs, <Z> dead-code items
PASSES: <N> of <total>
TOP_FINDINGS:
- [<severity>] <pass-name>: <title> — <file>:<line>
MODERNIZATION_OPPS: <count of SE-XXXX adoption opportunities>
THEMES: <list>
```

Plus the JSON block.

## Don't

- Don't apply `--fix` unless explicitly asked
- Don't recommend personal style preferences (cite a rule or guideline)
- Stay under 500 words
