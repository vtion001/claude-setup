---
name: qa-audit
description: >
  Automates comprehensive page-by-page QA auditing of a running web application using
  Playwright browser automation. Discovers routes, navigates each page, takes screenshots,
  detects UI/UX/data bugs, cross-references source code for root causes, and generates
  markdown reports with optional Linear issue filing. This skill should be used when the
  user asks to "audit the app", "QA the app", "run a QA audit", "check the app for bugs",
  "review the UI", "take screenshots of the app", "find UI bugs", "test all pages",
  "visual QA", "browser audit", "walk the app", "check for broken images",
  "audit the frontend", or "run Playwright audit".
---

# QA Audit — Automated Page-by-Page Application Review

Systematically walk every page of a running web application, capture screenshots, detect UI/UX/data bugs, cross-reference with source code for root causes, and produce a structured report. Optionally auto-file issues to Linear.

## When To Use

- After a deploy or feature merge, to catch regressions
- When a QA tester (like Jorge) would manually walk the app
- Before a sprint review or demo
- When the user wants a comprehensive UI/UX bug sweep
- When screenshots of the current app state are needed

## Prerequisites

The following MCP servers must be available (check tool list before starting):
- **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_click`, `browser_fill_form`)
- **Linear MCP** (optional — for auto-filing issues)
- Access to the running application URL

## Workflow

### Phase 0: Configuration

Auto-detect these inputs from the codebase. Prompt for any values that cannot be resolved:

| Input | Default | Notes |
|-------|---------|-------|
| `APP_URL` | `http://localhost:8082` | Base URL of the running app |
| `AUTH_REQUIRED` | `true` | Whether login is needed |
| `LOGIN_EMAIL` | auto-detect from seeders | Dev credentials |
| `LOGIN_PASSWORD` | auto-detect from seeders | Dev credentials |
| `LINEAR_PROJECT` | auto-detect from context | For auto-filing |
| `SCREENSHOT_DIR` | `./qa-audit-screenshots/` | Where to save screenshots |

If auth is required and no credentials are known:
1. Search the codebase for database seeders (`database/seeders/`) to find dev user credentials
2. Search for `.env.example` or test fixtures for default login info
3. If none found, create a dev user via the framework's CLI (e.g., `php artisan tinker` for Laravel)

### Phase 1: Route Discovery

Extract all user-facing routes from the application:

**For Laravel projects:**
```bash
php artisan route:list --columns=method,uri,name,middleware --json
```
Filter to `GET` routes with `web` or `auth` middleware. Exclude API-only, webhook, and internal routes.

**For other frameworks:** Read route definition files directly.

Organize routes into logical page groups:
- **Public pages** (no auth required)
- **Authenticated pages** (require login)
- **Admin/supervisor pages** (require elevated roles)

**For parameterized routes** (e.g., `/calls/{id}`, `/qa/{id}`): Query the database or navigate to the list page first to identify a valid entity ID. Substitute that ID into the URL before navigating. Skip routes requiring more than one parameter unless specific IDs are known.

**For other frameworks:** Read route definition files directly (Next.js `pages/` or `app/`, Express route files, Django `urls.py`).

Consult `references/audit-checklist.md` for the full list of checks per page type.

### Phase 2: Authentication

If auth is required:
1. Navigate to the login page using Playwright
2. Take a screenshot of the login page (baseline)
3. Fill credentials and submit the form
4. Verify login succeeded (check for dashboard redirect or auth indicators)
5. Take a post-login screenshot
6. If login fails, report the error and stop

### Phase 3: Page-by-Page Audit

For each discovered route, perform these checks in order:

#### 3a. Navigate & Screenshot
1. Navigate to the page URL
2. Wait for page to fully load (network idle)
3. Take a full-page screenshot at default **1920x1080** viewport
4. Save with naming convention: `{page-name}_{timestamp}.png`
5. For responsive testing (only if requested): resize to 1024px and 375px, repeat screenshot

#### 3b. Visual Inspection (from snapshot)
- Take a DOM snapshot (`browser_snapshot`) for structured analysis
- Check for broken images (img elements with no natural dimensions or error states)
- Check for placeholder/lorem ipsum text
- Check for empty states that should have data
- Check for layout overflow or overlapping elements
- Check for missing or broken navigation elements

#### 3c. Data Integrity Checks
- Compare summary counters against table row counts (do they match?)
- Verify data scoping (is data filtered to the correct team/group?)
- Check for `0` values that suggest broken data pipelines
- Verify pagination exists for tables with many rows
- Check that date filters enforce valid ranges (no future dates, From <= To)

#### 3d. Form & Filter Validation
- Identify all form inputs and filters on the page
- Check dropdowns are populated (not empty selects)
- Check dependent dropdowns are scoped correctly
- Verify input types match data types (numbers for numbers, dates for dates)
- Check for free-text fields that should be enums/selects

#### 3e. Console & Network Errors
- Check for JavaScript console errors via `browser_console_messages`
- If console capture is unavailable, check the DOM snapshot for visible error overlays or toast messages
- Check for failed network requests (4xx/5xx) via `browser_network_requests`

#### 3f. Cross-Reference with Source Code
For each finding, read the relevant source file to identify:
- The exact file and line number causing the issue
- The root cause (missing filter, wrong query, missing validation, bad asset path)
- The specific fix needed

### Phase 4: Report Generation

Generate two outputs:

#### 4a. Markdown Report (`qa-audit-report.md`)

Follow the template in `references/report-template.md`. Structure:

```markdown
# QA Audit Report — {App Name}
**Date:** {date}  |  **URL:** {url}  |  **Auditor:** Claude QA Audit

## Summary
- Pages audited: X
- Issues found: X (Critical: X, High: X, Medium: X, Low: X)
- Screenshots taken: X

## Findings

### Finding 1: {Title}
**Severity:** {Critical|High|Medium|Low}
**Page:** {route}
**Screenshot:** {path}

**Problem:** {description}

**Root Cause:** {code analysis}

**Files Affected:**
- `{file_path}:{line}` — {what's wrong}

**Suggested Fix:** {specific code changes}

**Verification:** {how to confirm the fix}
```

#### 4b. Linear Issues (if requested)

For each finding, create a Linear issue with:
- Title: concise problem description
- Description: full finding details (problem, root cause, files affected, fix, verification)
- Priority: mapped from severity
- Labels: `["Bug"]`
- Project: the detected project
- Assignee: current user

### Phase 5: Summary

Present a final summary to the user:
- Total pages audited
- Total issues found by severity
- Top 3 most critical findings
- Link to the markdown report
- Links to created Linear issues (if applicable)

## Severity Mapping

| Severity | Criteria | Linear Priority |
|----------|----------|-----------------|
| **Critical** | App crash, data loss, security exposure, auth bypass | Urgent (1) |
| **High** | Wrong data displayed, broken core workflow, data integrity issues | High (2) |
| **Medium** | UI bugs, broken images, missing validation, bad UX | Medium (3) |
| **Low** | Missing pagination, cosmetic issues, missing tooltips | Low (4) |

## Important Rules

- Never skip a page — audit every discovered route
- Always take a screenshot before reporting a finding
- Always cross-reference findings with source code
- Never guess at root causes — read the actual code
- Group related sub-issues into a single finding when they share a root cause
- Report what IS working too — this builds confidence in the audit

## Additional Resources

### Reference Files
- **`references/audit-checklist.md`** — Detailed per-page-type checklist of all checks to perform
- **`references/report-template.md`** — Full markdown report template with examples

### Examples
- **`examples/sample-audit-report.md`** — A completed audit report with 3 findings, showing expected output format

### Scripts
- **`scripts/extract-laravel-routes.sh`** — Extract and format Laravel routes for auditing
