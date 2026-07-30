# Jorge Salazar — Linear Issue Template

This is the exact format Jorge uses when creating issues in Linear. All code audit findings MUST follow this structure.

## Issue Structure

```markdown
[Screenshot(s) at top — Playwright captures of the affected area]

## Problem
[Clear, concise description of the bug or issue observed. State what is wrong, not what should be done.]

## Root Cause
[Technical analysis of WHY the issue exists. Reference specific code patterns, misconfigurations, or architectural decisions. Include file paths and line numbers when possible.]

## Files Affected
[Bulleted list of specific files and components involved. Use relative paths from project root.]

## Impact
[Business and user-facing consequences: trust, compliance, performance, UX, security. Quantify where possible.]

## Fix
[Numbered, actionable steps to resolve. Each step should be specific enough for a developer to implement without ambiguity. Use sub-bullets for implementation details.]

## Verification
[Concrete test scenarios to confirm the fix is correct. Each bullet = one verification step a QA engineer can execute.]
```

## Metadata Rules

| Field       | Value Logic                                                                 |
|-------------|-----------------------------------------------------------------------------|
| **Priority** | `Urgent` = security vulnerability or data loss. `High` = broken core flow. `Medium` = incorrect behavior, UX issues. `Low` = cosmetic, minor improvements. |
| **Labels**   | `Bug` for defects. `Feature` for missing functionality. `Security` for vulnerabilities. |
| **Assignee** | Vincent John Rodriguez (ID: `d4215d96-2261-4bbf-a3ca-5ef5e741bc86`)        |
| **Team**     | Alliance Global Solutions (ID: `e50ae77f-4dee-4215-86a5-a0be5c163b7d`)     |
| **Project**  | Auto-detect from repo name. BOB-AGS repos → `BOB-AGS — Business Operations Bridge`. Email tool repos → `AGS Email Tool`. |

## Screenshot Requirements

- Capture BEFORE state of the affected page/component
- If the issue is visual, capture the exact area showing the defect
- If the issue is behavioral (e.g., filter not working), capture the state that demonstrates the problem
- Multiple screenshots are acceptable — place all at the TOP of the description before `## Problem`
- Use Playwright `page.screenshot()` with full-page or element-specific targeting
- File naming: `audit-{issue-slug}-{index}.png`

## Comment Guidelines

Add a comment to the issue when:
- Additional technical context is needed beyond the description (e.g., code snippets, stack traces)
- A related issue is discovered that connects to this finding
- The fix involves multiple PRs or phased rollout
- There are workaround instructions for the team while the fix is in progress

Comment format:
```markdown
### [Context Type]: [Brief Title]

[Content — code blocks, links, or explanation]
```

## Real Examples from Jorge

### Example 1: ALL-133 (Bug with screenshots)
- Title: "Conflicting unsubscribe link check between Quality Checklist and Pre-Send Checklist"
- Priority: Medium
- Labels: Bug
- Screenshots: 2 captures showing contradictory checklist results
- Problem: Two components evaluate same HTML, return opposite results
- Root Cause: Different detection logic for unsubscribe links
- Fix: Shared detection function, unit tests
- Verification: Run both checklists on same email, confirm matching results

### Example 2: ALL-126 (Multi-issue bug)
- Title: "Calls — filter inconsistencies, unscoped agent dropdown, free-text disposition, wrong duration unit, and missing pagination"
- Priority: Medium
- Labels: Bug
- Groups multiple related issues in one ticket when they affect the same component
- Each sub-issue gets its own numbered Fix section

### Example 3: ALL-124 (Bug without screenshots)
- Title: "Agent Profiles — missing pagination, name search, and ambiguous Call Count scope"
- Priority: Low
- Labels: Bug
- No screenshot when the issue is structural/data-level rather than visual
