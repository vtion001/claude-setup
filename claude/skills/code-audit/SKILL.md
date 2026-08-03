---
name: code-audit
description: This skill should be used when the user asks to "run a code audit", "audit the codebase", "scan for bugs and create agshub work items", "do a code audit with screenshots", "audit and file issues", "QA the app", "run QA", "security audit with agshub tickets", "check UX", "accessibility audit", "performance audit", "refactor audit", "check file structure", "verify fixes", or wants to run a full code review pipeline that produces agshub work items with before/after Playwright screenshots.
---

# Code Audit → BEFORE/AFTER Screenshots → agshub Work Items

A full-pipeline code audit across 8 quality dimensions — security, architecture, code quality, accessibility, performance, component quality, UX design, and file structure/modularization — with BEFORE/AFTER Playwright screenshots (desktop + mobile) and agshub work-item tracking in Jorge Salazar's template format.

## Scope Lock (CRITICAL)

**ALL audit operations MUST be scoped to the current working directory (PROJECT_ROOT).** Never scan files outside it.

- All `Glob` / `Grep` calls: set `path` to `PROJECT_ROOT`
- All `Read` calls: only files whose path starts with `PROJECT_ROOT`
- All Agent prompts: include `PROJECT_ROOT` path and instruct to ONLY scan within it
- **NEVER** scan `node_modules/`, `.git/`, `dist/`, `build/`, `.next/`, `vendor/`, `__pycache__/`
- **NEVER** scan parent directories, sibling repos, or global paths like `~/.claude/`

## Pipeline Overview

```
Phase 1: Discovery      → Identify project root, scope lock, agshub workspace/project, localhost URL, routes
Phase 2: Audit           → 8 parallel passes (security, arch, code, a11y, perf, components, UX, structure)
Phase 3: BEFORE shots    → Desktop + mobile captures of current broken state
Phase 4: File issues     → Create agshub work items with BEFORE screenshots in Jorge's format
Phase 5: Comments        → Add Lighthouse scores, a11y trees, perf traces, code snippets
Phase 6: Fix & AFTER     → After implementing fixes, capture AFTER screenshots, update agshub
Phase 7: Summary         → Audit scorecard + before/after comparison + issues table
```

The full procedure is defined in the global command file at `C:\Users\VJ_Rodriguguez\.claude\commands\code-audit.md`. This skill triggers the same pipeline.

## 8 Audit Passes (Phase 2)

Run all passes in parallel using the Agent tool. **Include PROJECT_ROOT in every Agent prompt.**

| Pass | Dimension | Primary Tool | What to Check |
|------|-----------|-------------|---------------|
| A | Security | `opsera-devsecops:security-scan` | Secrets, injection, XSS, dependency vulns |
| B | Architecture | `opsera-devsecops:architecture-analyze` | Anti-patterns, scalability risks |
| C | Code Review | `pr-review-toolkit:review-pr` | Bugs, silent failures, logic errors |
| D | Accessibility | `chrome-devtools-mcp:a11y-debugging` | WCAG, ARIA, keyboard nav, contrast, Lighthouse a11y |
| E | Performance | `chrome-devtools-mcp:debug-optimize-lcp` | LCP, Core Web Vitals, render-blocking, Lighthouse perf |
| F | Components | `vercel:react-best-practices` | Hooks, a11y props, re-render anti-patterns, TypeScript |
| G | UX Design | Custom checklist | Human-centered design, responsiveness, usability |
| H | Structure | File analysis + dependency mapping | God files, circular deps, mixed concerns, naming |

### Pass D: Accessibility — run Lighthouse a11y on each route, capture a11y tree, check contrast, tap targets, focus indicators
### Pass E: Performance — record perf trace, analyze LCP subparts, flag routes > 2.5s, check bundle sizes
### Pass G: UX Design — navigate each route in desktop (1920x1080) + mobile (375x812), evaluate:
- Information hierarchy, cognitive load, consistency
- Feedback states (loading, error, empty, confirmation)
- Mobile responsiveness (no h-scroll, touch targets ≥44px, text ≥16px)
- Form UX (visible labels, inline validation, specific errors, tab order)
- Navigation (current page indicated, breadcrumbs, back button)
- Visual design (consistent typography, meaningful color, icons + text labels)

### Pass H: Structure & Modularization — scan PROJECT_ROOT source files for:

**File Size & Complexity:**
- God files exceeding 300 lines — list each with line count
- Files with more than 10 exports (doing too much)
- Files with mixed concerns (UI components + API logic, routes + business logic)

**Dependency Graph:**
- Circular import chains (A → B → C → A)
- Deeply nested imports (`../../../`) — indicates poor module organization
- Orphan files not imported by anything (dead code)

**Directory Structure:**
- Feature-based organization (good) vs type-based flat folders (fragile)
- Barrel file bloat (`index.ts` re-exporting everything)
- Shared `utils/` / `helpers/` dump drawers with unrelated functions

**Naming Consistency:**
- Mixed file naming conventions (camelCase vs kebab-case vs PascalCase)
- Component-file alignment (does `UserProfile.tsx` export `UserProfile`?)

**For each finding, provide:** current state with line counts, proposed refactoring (specific files and what moves where), import updates needed, and risk level (Low/Medium/High).

## Authentication (Auto-Resolve — 4 Strategies)

Before capturing any screenshots, authenticate into the app automatically. Execute in order — only proceed to the next if the previous fails. Do NOT ask the user unless all 4 fail.

### Strategy 1: Find Credentials in Database
1. Detect DB connection from `.env`, `docker-compose.yml`, ORM configs (`prisma/schema.prisma`, `knexfile.js`, `drizzle.config.ts`)
2. Query for an admin/test user: `SELECT email, password_hash FROM users WHERE role IN ('admin','superadmin','test') LIMIT 1`
3. For MongoDB: use MCP `find` on `users` collection with `{ role: { $in: ["admin","test"] } }`
4. Check for seeded test users in `seed.ts`, `seed.js`, `seeds/`, `fixtures/`, `scripts/seed*` with known passwords
5. If passwords are hashed and unrecoverable → move to Strategy 2

### Strategy 2: Create Dev Test Credentials
1. Check for user creation scripts: `npm run seed`, `npx prisma db seed`, `python manage.py createsuperuser`
2. If no script exists, insert directly into DB:
   - Generate bcrypt hash: `node -e "console.log(require('bcryptjs').hashSync('AuditTest123!',10))"`
   - Insert: `audit-test@dev.local` / `AuditTest123!` / role: `admin`
3. Mark for cleanup after audit

### Strategy 3: Bypass Authentication
1. Check for dev bypass env vars: `DISABLE_AUTH`, `BYPASS_AUTH`, `DEV_AUTH_BYPASS`, `NEXT_PUBLIC_SKIP_AUTH`
2. If none, temporarily add bypass to auth middleware (dev only):
   ```typescript
   if (process.env.AUDIT_BYPASS_AUTH === 'true') return next();
   ```
3. Or inject JWT/session cookie directly using the app's secret from `.env` (`JWT_SECRET`, `AUTH_SECRET`, `NEXTAUTH_SECRET`)
4. **Must revert all bypass changes after audit**

### Strategy 4: Ask the User (Last Resort)
Only if all 3 above fail. Ask for credentials, session cookie, or auth instructions.

### Post-Audit Cleanup
- Strategy 2: delete `audit-test@dev.local` from DB
- Strategy 3: revert auth bypass code, remove env vars
- Log all cleanup actions in the audit summary

## BEFORE/AFTER Screenshot System (Phases 3 & 6)

### BEFORE Screenshots (Phase 3 — pre-fix)

Capture every affected route in both viewports before any fix:
- `./audit-screenshots/before/before-{slug}-desktop.png` — 1920x1080
- `./audit-screenshots/before/before-{slug}-mobile.png` — 375x812
- `./audit-screenshots/before/before-{slug}-element-{component}.png` — targeted element

These document the current broken state and get referenced in the agshub work item under `Before (Pre-Fix)`.

### AFTER Screenshots (Phase 6 — post-fix)

After each fix is implemented and the dev server reflects the updated code:

1. **Re-capture the same routes and elements** in both viewports:
   - `./audit-screenshots/after/after-{slug}-desktop.png` — 1920x1080
   - `./audit-screenshots/after/after-{slug}-mobile.png` — 375x812
   - `./audit-screenshots/after/after-{slug}-element-{component}.png` — targeted element

2. **Re-run relevant audit checks** to produce measurable proof:
   - A11y issues → re-run Lighthouse a11y, include new score
   - Performance issues → re-run Lighthouse perf, include new LCP
   - UX issues → re-verify checklist items, capture corrected layout
   - Bugs → capture page showing correct behavior

3. **Add a verification comment** to the agshub work item (`POST .../work-items/{id}/comments`), plain text — reference screenshot file paths, agshub has no attachment-upload endpoint:

```
Implementation Complete: Post-Fix Verification

AFTER — Desktop: ./audit-screenshots/after/after-{slug}-desktop.png
AFTER — Mobile:  ./audit-screenshots/after/after-{slug}-mobile.png

Before -> After Comparison:
Lighthouse A11y   62/100 -> 98/100
LCP               4.2s -> 1.8s
Status            Broken -> Resolved

Changes Made:
- [Files modified with brief description]
- [Link to commit/PR]
```

4. **Update the work item's state** (`PATCH .../work-items/{id}` `{state_id}`) to the project's
   `completed`-group state — or leave it in the `started`-group state if a PR review is still
   pending (agshub's 5 seeded states have no dedicated "in review" group).

### Side-by-Side Format for Comments

```markdown
### Before / After: [Page Name]

| Desktop | Mobile |
|---------|--------|
| **BEFORE** | **BEFORE** |
| ![before-desktop](url) | ![before-mobile](url) |
| **AFTER** | **AFTER** |
| ![after-desktop](url) | ![after-mobile](url) |
```

### What Counts as Verified

- AFTER screenshots visually confirm the issue is resolved
- The same audit check that flagged the issue now passes
- Both desktop and mobile viewports show correct behavior
- No new console errors introduced by the fix

## agshub Work Item Template (Phase 4)

Description is **plain text** in agshub (not markdown) — use blank lines/indentation for
structure, not `#`/`*`:

```
Before (Pre-Fix)
[BEFORE screenshot file paths — desktop + mobile]

Problem
[What is wrong — observable behavior]

Root Cause
[Why — code-level analysis with file paths]

Files Affected
[Bulleted file list]

Impact
[Business/user consequences, quantified where possible]

Fix
[Numbered actionable steps]

Verification
[Test scenarios to confirm]

After (Post-Fix)
[Added after implementation via Phase 6 — AFTER screenshot file paths]
```

## Screenshots & agshub (No Attachment Upload)

agshub has **no attachment-upload endpoint**. Screenshots stay on disk under
`./audit-screenshots/` — reference their relative file paths as plain text in the description
and in the Phase 6 verification comment. Do not attempt to embed `![alt](url)` markdown; agshub
descriptions/comments render as plain text.

## Labels & Priority

**Labels:** resolve or create these in the target agshub project (`GET`/`POST .../labels`):
`Bug`, `Feature`, `Security`, `Accessibility`, `Performance`, `UX`, `Refactor`.

**Priority:** agshub enum `urgent/high/medium/low/none`. `urgent` = security/data loss/WCAG-A.
`high` = broken flow/LCP>4s. `medium` = incorrect behavior/UX friction. `low` = cosmetic.

## Additional Resources

- **`references/jorge-template.md`** — Jorge's complete issue template, metadata rules, examples
- **`scripts/take-screenshots.js`** — Playwright dual-viewport screenshot utility
