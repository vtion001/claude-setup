# Shared Report Template — iOS Audit Suite

Every iOS audit skill writes its report into `<project-root>/ios-audit/<skill-name>/`
using this structure. The orchestrator (`/ios-audit-pipeline`) reads each
per-skill report and synthesizes a `COMBINED-REPORT.md` at
`<project-root>/ios-audit/COMBINED-REPORT.md`.

---

## Output files (per audit)

```
<project-root>/ios-audit/<skill-name>/
├── report.md                # Full narrative + per-pass scores + findings
├── scorecard.md             # Quick-reference (1 page, ASCII box)
├── findings.json            # Machine-readable (orchestrator reads this)
├── screenshots/             # If the audit captured any (ui-impl, qa)
└── fix-diffs/               # If --fix applied any, the diffs land here
```

---

## report.md skeleton

```markdown
# <Skill Display Name> — Audit Report
**Project:** <name>
**Path:** <absolute path>
**Date:** <YYYY-MM-DD>
**Auditor:** Claude (model: <model>) via /<skill-name>
**Passes run:** <N> of <total>
**Score:** <UIQ/BNH/SEC/QAH/CRQ/INT>-iOS = <NN/100> · <range label>

## Executive Summary

[3-6 paragraphs in domain-expert voice. Lead with the headline (Ship-ready /
Production-ready / Needs attention / Design debt / Critical). Identify
root-cause patterns. Group findings into themes with unified fixes. Prioritize
by impact-to-effort. Estimate effort in sprint-friendly terms (hours / days /
sprints). Speak in iOS-native vocabulary (HIG, Dynamic Type, Swift Concurrency,
SwiftData, App Intents) — never generic web language.]

## Themes (cross-pass root causes)

### Theme 1: <name>
**Affected passes:** <pass-name>, <pass-name>
**Affected files:** <count>
**Severity:** <max severity across the theme>
**Unified fix:** <one paragraph + code snippet>
**Effort:** <hours/days>

[Repeat per theme]

## Per-Pass Results

### Pass NN — <Title>
**Weight:** <N>×  **Score:** <1-5>

[1-2 sentences on what this pass found]

#### Findings
- F-NNN — <Title> (Severity: <Critical/High/Medium/Low>) — `<file>:<line>`
- F-NNN — ...

[Repeat per pass run]

## Findings detail

#### F-NNN — <Title>
- **Severity:** <Critical/High/Medium/Low>
- **Pass:** <pass-name>
- **File:** `path/file.swift:line`
- **Root cause:** [one sentence]
- **Recommended fix:**
  ```swift
  // BEFORE
  ...
  // AFTER
  ...
  ```
- **Auto-fixable:** <yes / no — reason>
- **Effort:** <S/M/L>

[Repeat per finding, ordered by severity then file]

## What's Working (preserve list)

[3-8 bullets listing patterns the audit positively recognized. This builds
trust in the rubric and tells the team what NOT to refactor away.]

## Appendix

- Skill version: <skill commit/date>
- Tools used: <list with versions>
- Detection results: <JSON from _ios-shared/scripts/detect-ios-project.sh>
```

---

## scorecard.md skeleton

```markdown
# <Skill Display Name> — Scorecard

```
╔══════════════════════════════════════════╗
║  <SCORE_ACRONYM>-iOS:  NN / 100           ║
║  Range:               <Ship/Prod/Needs/.. ║
║  Critical findings:   N                   ║
║  High findings:       N                   ║
║  Medium findings:     N                   ║
║  Low findings:        N                   ║
╚══════════════════════════════════════════╝
```

## Per-Pass Scores

| Pass | Weight | Score | Findings |
|---|---|---|---|
| 01-pass-name | 2× | 4/5 | 2 Low |
| 02-pass-name | 3× | 2/5 | 1 Critical, 1 High |
| ... | | | |

## Top 5 actions

1. [single-line action with file:line]
2. ...

See `report.md` for narrative + full findings.
```

---

## findings.json schema

The orchestrator consumes this. Stable schema — never break it without
versioning.

```json
{
  "schema_version": "1.0",
  "skill": "ios-security-audit",
  "project": "Pookoo",
  "project_path": "/Users/archerterminez/Desktop/REPOSITORY/ios-app/Puka",
  "run_at": "2026-06-13T20:00:00Z",
  "score": {
    "acronym": "SEC-iOS",
    "value": 42,
    "range_label": "Design debt"
  },
  "passes": [
    {
      "name": "01-secrets-storage",
      "weight": 3,
      "score": 1,
      "finding_ids": ["F-001", "F-002"]
    }
  ],
  "findings": [
    {
      "id": "F-001",
      "title": "Gmail OAuth tokens stored in UserDefaults (plaintext)",
      "severity": "Critical",
      "pass": "01-secrets-storage",
      "file": "Pookoo/Services/GmailService.swift",
      "line": 142,
      "root_cause": "Tokens persisted via UserDefaults.standard.set(_:forKey:) — accessible to any process post-jailbreak and backed up to iCloud by default.",
      "recommended_fix_summary": "Migrate to Keychain with kSecAttrAccessibleAfterFirstUnlock + kSecAttrAccessControl biometric requirement.",
      "code_diff": "...",
      "auto_fixable": false,
      "effort": "M",
      "theme": "token-storage"
    }
  ],
  "themes": ["token-storage", "missing-keychain"]
}
```

---

## Finding ID convention

`F-NNN` per skill (resets each skill run). The orchestrator namespaces by
skill prefix when synthesizing: `SEC-F-001`, `BNH-F-014`, etc.

---

## Style notes (avoid)

- Never use vague terms ("might be slow", "could leak"). Always quantify or
  cite a specific line.
- Never recommend a refactor for taste alone. Tie every finding to a published
  standard (HIG, OWASP MASVS, Swift API Design Guidelines, RFC).
- Never inflate severity to seem thorough. Critical is reserved for
  ship-blockers.
- Always include "What's Working" — 3+ items minimum. An audit that only
  finds fault loses credibility.
