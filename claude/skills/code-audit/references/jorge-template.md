# Jorge Salazar — agshub Work Item Template

This is the exact format Jorge uses when creating work items in agshub. All code audit findings MUST follow this structure.

## Issue Structure

Renders as **plain text** in agshub (descriptions/comments are not markdown — use blank lines and indentation for structure, not `#`/`*`):

```
[Screenshot file path(s) at top — local Playwright captures of the affected area]

Problem
[Clear, concise description of the bug or issue observed. State what is wrong, not what should be done.]

Root Cause
[Technical analysis of WHY the issue exists. Reference specific code patterns, misconfigurations, or architectural decisions. Include file paths and line numbers when possible.]

Files Affected
[Bulleted list of specific files and components involved. Use relative paths from project root.]

Impact
[Business and user-facing consequences: trust, compliance, performance, UX, security. Quantify where possible.]

Fix
[Numbered, actionable steps to resolve. Each step should be specific enough for a developer to implement without ambiguity. Use sub-bullets for implementation details.]

Verification
[Concrete test scenarios to confirm the fix is correct. Each bullet = one verification step a QA engineer can execute.]
```

## Metadata Rules

| Field       | Value Logic                                                                 |
|-------------|-----------------------------------------------------------------------------|
| **Priority** | agshub enum `urgent/high/medium/low/none`. `urgent` = security vulnerability or data loss. `high` = broken core flow. `medium` = incorrect behavior, UX issues. `low` = cosmetic, minor improvements. |
| **Labels**   | Resolve or create these in the target agshub project (`GET`/`POST .../labels`): `Bug` for defects, `Feature` for missing functionality, `Security` for vulnerabilities, plus `Accessibility`, `Performance`, `UX`, `Refactor` as needed. |
| **Assignee** | Resolved dynamically via `GET /workspaces/{ws}/members`, matching the current user's email — never hardcode a member ID. |
| **Workspace/Project** | Resolved dynamically via `GET /workspaces` then `GET /workspaces/{ws}/projects`, matching the repo name against project names. If ambiguous or no match, ask — never guess (per `agshub-crud`'s rules). |

## Screenshot Requirements

- Capture BEFORE state of the affected page/component
- If the issue is visual, capture the exact area showing the defect
- If the issue is behavioral (e.g., filter not working), capture the state that demonstrates the problem
- Multiple screenshots are acceptable — list all their local file paths at the TOP of the description before `Problem`
- Use Playwright `page.screenshot()` with full-page or element-specific targeting
- File naming: `audit-{issue-slug}-{index}.png`
- agshub has no attachment-upload endpoint — screenshots stay on disk under `./audit-screenshots/`; the work item references their relative paths as plain text rather than embedding images

## Comment Guidelines

Add a comment to the work item when:
- Additional technical context is needed beyond the description (e.g., code snippets, stack traces)
- A related issue is discovered that connects to this finding
- The fix involves multiple PRs or phased rollout
- There are workaround instructions for the team while the fix is in progress

Comment format (plain text — no markdown rendering assumed):
```
[Context Type]: [Brief Title]

[Content — code blocks, links, or explanation]
```

## Real Examples from Jorge (patterns to follow, not literal IDs — agshub work items are UUIDs, not sequential ticket numbers)

### Example 1: Bug with screenshots
- Title: "Conflicting unsubscribe link check between Quality Checklist and Pre-Send Checklist"
- Priority: medium
- Labels: Bug
- Screenshots: 2 captures showing contradictory checklist results
- Problem: Two components evaluate same HTML, return opposite results
- Root Cause: Different detection logic for unsubscribe links
- Fix: Shared detection function, unit tests
- Verification: Run both checklists on same email, confirm matching results

### Example 2: Multi-issue bug
- Title: "Calls — filter inconsistencies, unscoped agent dropdown, free-text disposition, wrong duration unit, and missing pagination"
- Priority: medium
- Labels: Bug
- Groups multiple related issues in one work item when they affect the same component
- Each sub-issue gets its own numbered Fix section

### Example 3: Bug without screenshots
- Title: "Agent Profiles — missing pagination, name search, and ambiguous Call Count scope"
- Priority: low
- Labels: Bug
- No screenshot when the issue is structural/data-level rather than visual
