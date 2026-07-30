# Code Audit → Playwright Screenshots → Linear Issues

Run a full-pipeline code audit: security, architecture, code review, accessibility, performance, component quality, and UX design — then capture BEFORE/AFTER Playwright screenshots (desktop + mobile) on localhost and file each finding as a Linear issue in Jorge Salazar's exact format. After fixes are implemented, re-capture AFTER screenshots as proof of completion and attach them to the same Linear issues.

```
Phase 1: Discovery      → Identify project root, scope lock, team, localhost URL, routes
Phase 2: Audit           → 8 parallel passes (security, arch, code, a11y, perf, components, UX, structure)
Phase 3: BEFORE shots    → Desktop + mobile captures of current broken state
Phase 4: File issues     → Create Linear issues with BEFORE screenshots in Jorge's format
Phase 5: Comments        → Add Lighthouse scores, a11y trees, perf traces, code snippets
Phase 6: Fix & AFTER     → After implementing fixes, capture AFTER screenshots, update Linear issues
Phase 7: Summary         → Audit scorecard + before/after comparison + issues table
```

---

## Phase 1: Discovery & Scope Lock

Before running the audit, establish the project boundary. **ALL audit passes, file scans, grep searches, and glob patterns MUST be scoped to the project root. NEVER scan files outside this directory.**

### 1. Determine the Project Root (CRITICAL)

The project root is the **current working directory** where `/code-audit` was invoked. Confirm it by checking for:
- A `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `composer.json`, or similar manifest
- A `.git` directory (repo root)
- If neither is found, the current working directory IS the project root

**Store the absolute path as `PROJECT_ROOT`.** Every file operation in the audit MUST use this as the base path.

### Scope Enforcement Rules

- All `Glob` calls: set `path` parameter to `PROJECT_ROOT`
- All `Grep` calls: set `path` parameter to `PROJECT_ROOT`
- All `Read` calls: only read files whose absolute path starts with `PROJECT_ROOT`
- All Agent dispatches: include `PROJECT_ROOT` in the prompt and instruct the agent to ONLY scan within it
- **NEVER** scan `node_modules/`, `.git/`, `dist/`, `build/`, `.next/`, `__pycache__/`, `vendor/`, or other dependency/output directories
- **NEVER** follow symlinks that point outside `PROJECT_ROOT`
- **NEVER** scan parent directories, sibling repos, or global paths like `~/.claude/`

### 2. Map to Linear Project

Detect which Linear project this repo belongs to:
   - Repos containing `bob` or `bob-ags` → Project: `BOB-AGS — Business Operations Bridge` (ID: `c7931e72-cb6b-46b3-b0d9-05c3c78e56b3`)
   - Repos containing `email` or `ags-email` → Project: `AGS Email Tool` (ID: `56de9fb6-d1e8-4d3f-884e-974d625bd076`)
   - Otherwise → ask the user which Linear project to file under
3. **Determine localhost URL** — default to `http://localhost:3000`. Check `package.json` scripts or framework config for the actual dev server port. Confirm the dev server is running before proceeding.
4. **Enumerate routes** — scan the project's routing layer **within PROJECT_ROOT only** to build a route list:
   - Next.js App Router: glob `app/**/page.{tsx,jsx,ts,js}` in `PROJECT_ROOT`
   - Next.js Pages Router: glob `pages/**/*.{tsx,jsx,ts,js}` in `PROJECT_ROOT`
   - React Router: grep for `<Route` or `path:` in router config within `PROJECT_ROOT`
   - Express/Fastify: grep for `app.get`, `router.get`, etc. within `PROJECT_ROOT`
   - Other frameworks: check framework-specific routing files within `PROJECT_ROOT`
5. **Check browser tooling** — verify Chrome DevTools MCP or Playwright MCP is available for browser automation. If using standalone Playwright, ensure it is installed: `npm i -D playwright @playwright/test && npx playwright install chromium`

## Phase 2: Audit Execution

Run eight audit passes in parallel using the Agent tool. Each pass targets a different quality dimension. **Every pass MUST scope all file operations to `PROJECT_ROOT` — include the absolute path in every Agent prompt.**

```
Pass A: Security Scan              → vulnerabilities, secrets, injection vectors
Pass B: Architecture Analysis      → structural risks, anti-patterns, scalability
Pass C: Code Review                → bugs, silent failures, logic errors
Pass D: Accessibility Audit        → WCAG, ARIA, keyboard nav, color contrast
Pass E: Performance Audit          → Core Web Vitals, LCP, render-blocking
Pass F: React Component Quality    → hooks, props, a11y attributes, patterns
Pass G: UX Design Review           → human-centered design, usability, responsiveness
Pass H: Structure & Modularization → file organization, god files, circular deps, maintainability
```

### Pass A: Security Scan
Dispatch the `opsera-devsecops:security-scan` skill or the `opsera-devsecops:devsecops` agent. Collect findings categorized by severity (Critical, High, Medium, Low).

**Fallback if skill unavailable:** Perform a manual security scan — grep for hardcoded secrets (`password`, `api_key`, `secret`, `token` in source files), check for SQL injection patterns (string concatenation in queries), scan for XSS vectors (unsanitized `dangerouslySetInnerHTML`, `innerHTML`), and run `npm audit` or `pip audit` for dependency vulnerabilities.

### Pass B: Architecture Analysis
Dispatch the `opsera-devsecops:architecture-analyze` skill or agent. Collect structural risks, anti-patterns, and scalability concerns.

**Fallback if skill unavailable:** Manually review project structure for anti-patterns — missing error boundaries, no input validation at API boundaries, missing pagination on list endpoints, hardcoded values that should be env vars, circular dependencies, and oversized components/modules.

### Pass C: Code Review
Dispatch the `pr-review-toolkit:review-pr` skill or `feature-dev:code-reviewer` agent. Collect code quality issues, silent failures, type design problems, and logic errors.

**Fallback if skill unavailable:** Perform a manual code review pass — check for empty catch blocks, silent error swallowing, missing loading/error states in UI components, inconsistent naming, dead code, and functions exceeding 100 lines.

### Pass D: Accessibility Audit
Use the `chrome-devtools-mcp:a11y-debugging` skill via Chrome DevTools MCP. For each route on localhost:

1. **Run Lighthouse accessibility audit** — use the `lighthouse_audit` tool with `categories: ["accessibility"]` on each route. Target score: 100. Flag anything below 90 as High priority.
2. **Capture accessibility tree** — use `take_snapshot` on each page to get the accessibility tree. Check for:
   - Missing or duplicate `aria-label` / `aria-labelledby` attributes
   - Broken heading hierarchy (skipped heading levels like h1 → h3)
   - Missing `alt` text on images
   - Form inputs without associated `<label>` elements
   - Interactive elements not reachable via keyboard (`tabindex` issues)
3. **Check color contrast** — verify text meets WCAG AA minimum contrast ratios (4.5:1 for normal text, 3:1 for large text)
4. **Tap target sizing** — verify interactive elements are at least 48x48px on mobile viewport
5. **Focus indicators** — tab through the page and verify every focusable element has a visible focus ring
6. **Console issues** — use `list_console_messages` with `types: ["issue"]` to catch browser-reported a11y violations

**Fallback if Chrome DevTools MCP unavailable:** Use Playwright to run `page.accessibility.snapshot()` on each route. Grep source files for missing `alt`, `aria-label`, `htmlFor` attributes. Check CSS for `:focus` styles.

### Pass E: Performance Audit
Use the `chrome-devtools-mcp:debug-optimize-lcp` skill via Chrome DevTools MCP. For each route on localhost:

1. **Record performance trace** — use `performance_start_trace` with `reload: true` and `autoStop: true`
2. **Analyze LCP** — use `performance_analyze_insight` to get LCP subpart breakdown:
   - TTFB should be ~40% of total LCP
   - Resource load delay should be <10%
   - Resource load duration should be ~40%
   - Element render delay should be <10%
   - Flag any route with LCP > 2.5 seconds
3. **Check render-blocking resources** — identify CSS/JS files blocking first paint
4. **Check network requests** — use `list_network_requests` to identify oversized assets (images > 500KB, JS bundles > 250KB)
5. **Run Lighthouse performance audit** — use `lighthouse_audit` with `categories: ["performance"]`. Flag score below 90.

**Fallback if Chrome DevTools MCP unavailable:** Use Playwright to measure `page.evaluate(() => performance.getEntriesByType('navigation'))` and `performance.getEntriesByType('largest-contentful-paint')`. Check for unoptimized images via file size inspection.

### Pass F: React Component Quality
Use the `vercel:react-best-practices` skill concepts. Scan all `.tsx` / `.jsx` component files for:

1. **Hooks violations** — hooks called conditionally or inside loops, missing dependency arrays in `useEffect`, stale closures
2. **Missing accessibility props** — buttons without `aria-label` or visible text, images without `alt`, custom components without ARIA roles
3. **Performance anti-patterns** — inline object/array creation in JSX props (causes unnecessary re-renders), missing `key` props on lists, large components that should be split, missing `React.memo` on expensive pure components
4. **State management issues** — prop drilling beyond 3 levels, duplicated state, state that should be derived
5. **TypeScript quality** — `any` types, missing return types on exported functions, loose union types that should be discriminated

**Fallback:** Grep for common patterns: `useEffect\(\s*\(\)` without deps array, `as any`, `// @ts-ignore`, `onClick={() =>` inline handlers in lists.

### Pass G: UX Design Review
This is a browser-based audit of human-centered design quality. For each route on localhost, navigate in **two viewports** — desktop (1920x1080) and mobile (375x812) — and evaluate:

#### Information Architecture
- Is the most important content visually prominent (size, position, contrast)?
- Is there a clear visual hierarchy — headings, subheadings, body text are distinct?
- Can a user find what they need within 2 clicks from the main navigation?
- Are related actions grouped together logically?

#### Cognitive Load
- Are there more than 7±2 options/items visible at once without grouping?
- Are CTAs (call-to-action buttons) clear and unambiguous in their labels?
- Is there unnecessary jargon or technical language in user-facing text?
- Are multi-step processes broken into clear, numbered stages?

#### Consistency
- Are similar actions (edit, delete, save) styled and positioned the same way across all pages?
- Is the same terminology used for the same concept everywhere?
- Do buttons, links, and interactive elements follow a consistent visual pattern?
- Is spacing and alignment consistent across sections?

#### Feedback & States
- Do all data-loading actions show a loading spinner or skeleton?
- Are success and error messages displayed clearly after form submissions?
- Are empty states handled (no data yet, no search results)?
- Do destructive actions (delete, remove) require confirmation?
- Are disabled buttons explained (tooltip or helper text)?

#### Mobile Responsiveness
- Does the layout adapt gracefully to mobile viewport (no horizontal scroll)?
- Are touch targets at least 44x44px with adequate spacing between them?
- Is text readable without zooming (minimum 16px body text)?
- Do tables transform to a mobile-friendly format (cards, stacked rows)?
- Is the navigation accessible on mobile (hamburger menu, bottom nav)?

#### Form UX
- Do all inputs have visible labels (not just placeholder text)?
- Is inline validation present (not just on submit)?
- Are error messages specific ("Email format invalid" not just "Error")?
- Is tab order logical (top-to-bottom, left-to-right)?
- Are required fields marked clearly?
- Do date pickers, dropdowns, and selectors work on mobile?

#### Navigation & Wayfinding
- Is the current page/section clearly indicated in the navigation?
- Are breadcrumbs present on nested pages?
- Does the back button work as expected?
- Are 404 and error pages helpful (suggest alternatives, link home)?

#### Visual Design Quality
- Is typography consistent (max 2 font families, clear size scale)?
- Is color used meaningfully (not decoratively) — e.g., red for errors, green for success?
- Are icons paired with text labels (not icon-only buttons)?
- Is there sufficient white space — or does the layout feel cramped?

**Screenshot both viewports** for every route: `audit-{slug}-desktop.png` and `audit-{slug}-mobile.png`. These screenshots serve as evidence for UX findings.

### Pass H: Structure & Modularization Audit
Analyze the codebase file structure **within PROJECT_ROOT only** for maintainability, modularity, and organization problems.

#### File Size & Complexity Analysis
1. **Find god files** — scan all source files and flag any file exceeding 300 lines. List each with line count:
   ```bash
   find "$PROJECT_ROOT/src" "$PROJECT_ROOT/app" "$PROJECT_ROOT/lib" "$PROJECT_ROOT/components" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rb" | xargs wc -l | sort -rn | head -20
   ```
2. **Count exports per file** — files with more than 10 exports are doing too much. Flag them.
3. **Identify mixed concerns** — files that contain both UI components AND API/data logic, or both route handlers AND business logic, or both types AND implementations.

#### Dependency Graph Analysis
4. **Map import dependencies** — for each source file, list what it imports and from where. Build a dependency count per file.
5. **Detect circular imports** — trace import chains and flag any cycles (A imports B imports C imports A).
6. **Flag deeply nested imports** — imports that go up more than 3 levels (`../../../`) indicate poor module organization.

#### Directory Structure Review
7. **Check for feature/domain grouping** — is the code organized by feature (good: `features/auth/`, `features/dashboard/`) or by type (fragile: `components/`, `hooks/`, `utils/` with everything mixed)?
8. **Identify orphan files** — files that are not imported by anything (dead code) or test files without corresponding source files.
9. **Check for barrel files** — if the project uses `index.ts` barrel exports, verify they don't re-export everything (barrel bloat slows builds).
10. **Shared utilities audit** — check `utils/`, `helpers/`, `lib/` for files that have grown into dump drawers with unrelated functions.

#### Naming & Convention Consistency
11. **File naming consistency** — are files consistently named? (camelCase vs kebab-case vs PascalCase). Flag mixed conventions.
12. **Directory naming consistency** — same check for directory names.
13. **Component-file alignment** — does `UserProfile.tsx` export `UserProfile`? Flag mismatches between filename and default/primary export.

#### Modularization Recommendations

For each structural finding, provide:
- **Current state** — what the file/directory looks like now (with line counts)
- **Proposed refactoring** — how to split or reorganize (specific file names and what moves where)
- **Import updates** — which files would need import path changes
- **Risk level** — Low (rename/move only), Medium (split file, update imports), High (restructure multiple modules)

**Fallback:** Use `wc -l`, `grep -r "import\|require"`, and `find` commands scoped to `PROJECT_ROOT` to perform the analysis manually.

### Consolidating All Findings

After all eight passes complete:

1. **Deduplicate** — merge findings that reference the same file/component across different passes
2. **Group** — cluster related findings into single issues when they affect the same page or component (following Jorge's multi-issue pattern, e.g., ALL-126 grouped 4 filter bugs into one issue)
3. **Prioritize**:
   - `Urgent` (1) = security vulnerability, data loss, or WCAG Level A violation
   - `High` (2) = broken core flow, LCP > 4s, or critical a11y failure
   - `Medium` (3) = incorrect behavior, UX friction, LCP 2.5–4s, WCAG AA violation
   - `Low` (4) = cosmetic, minor UX improvements, code quality nitpicks
4. **Classify** — label each finding:
   - `Bug` = defect, broken behavior
   - `Feature` = missing functionality
   - `Security` = vulnerability
   - `Accessibility` = WCAG / a11y violation
   - `Performance` = Core Web Vitals issue
   - `UX` = usability / design issue
   - `Refactor` = file structure, modularization, maintainability issue

## Phase 3: BEFORE Screenshots (Pre-Fix State)

For each finding that has a visible UI impact, capture **BEFORE** screenshots on localhost in **both viewports**. These document the current broken state prior to any fix.

### Taking BEFORE Screenshots

Use Chrome DevTools MCP tools (`navigate_page`, `take_screenshot`, `take_snapshot`) or Playwright MCP tools (`browser_navigate`, `browser_take_screenshot`, `browser_snapshot`) to:

1. **Desktop capture** — set viewport to 1920x1080, navigate to the affected route, wait for network idle, capture full-page screenshot
2. **Mobile capture** — resize to 375x812 (iPhone SE), capture the same route
3. **Element capture** — if the finding affects a specific component, also capture a targeted element screenshot
4. **Accessibility tree** — use `take_snapshot` or `browser_snapshot` to capture the accessibility tree as text evidence for a11y findings

Save BEFORE screenshots locally in `./audit-screenshots/before/` with naming:
- `before-{slug}-desktop.png` — desktop viewport, pre-fix
- `before-{slug}-mobile.png` — mobile viewport, pre-fix
- `before-{slug}-element-{component}.png` — targeted element, pre-fix

### Authentication Handling (Auto-Resolve — 4 Strategies)

Before capturing any screenshots, the audit MUST authenticate into the app. Execute these strategies in order — proceed to the next only if the previous fails. Do NOT ask the user unless all 4 strategies fail.

#### Strategy 1: Find Existing Credentials in Database

Automatically discover credentials by inspecting the project's database:

1. **Detect the database connection** — scan for database URLs in:
   - `.env`, `.env.local`, `.env.development`, `.env.test` files
   - `docker-compose.yml` or `docker-compose.dev.yml` (look for `DATABASE_URL`, `MONGO_URI`, `POSTGRES_*`, `MYSQL_*`)
   - ORM config files: `prisma/schema.prisma`, `knexfile.js`, `ormconfig.ts`, `drizzle.config.ts`, `sequelize` config
   - Framework config: `next.config.js`, `nuxt.config.ts`, `settings.py` (Django)

2. **Connect and query for a test/admin user** — use the appropriate tool:
   - **PostgreSQL/MySQL**: run a query via Bash: `psql "$DATABASE_URL" -c "SELECT email, password_hash FROM users WHERE role IN ('admin','superadmin','test') LIMIT 1;"` or equivalent
   - **MongoDB**: use the MongoDB MCP `find` tool on the `users` collection: `{ role: { $in: ["admin", "superadmin", "test"] } }` with limit 1
   - **Prisma**: run `npx prisma studio` or query directly via the DB URL
   - **Supabase**: use the Supabase MCP tools to query the `auth.users` table

3. **Extract usable credentials**:
   - If passwords are hashed (bcrypt, argon2, etc.) — the raw password is not recoverable. Move to Strategy 2.
   - If the app uses magic link / OTP login — look for a token generation endpoint or a way to generate a login link directly from the DB
   - If the app has a seeded test user with a known password (check `seed.ts`, `seed.js`, `seeds/`, `fixtures/`, `scripts/seed*`) — use those credentials
   - If the app has OAuth/SSO only — check for a local dev bypass or test token in env vars

#### Strategy 2: Create Dev Test Credentials

If no usable credentials are found in the database, create temporary test credentials:

1. **Check for a user creation script** — look for:
   - `scripts/create-user.*`, `scripts/seed.*`, `scripts/setup-dev.*`
   - npm scripts: check `package.json` for `seed`, `db:seed`, `create-admin`, `setup` scripts
   - CLI commands: `npx prisma db seed`, `python manage.py createsuperuser`, `rails db:seed`

2. **If a seed/create script exists** — run it to create a test user:
   ```bash
   # Example for common frameworks
   npm run seed          # Node.js projects
   npx prisma db seed    # Prisma projects
   python manage.py createsuperuser --noinput  # Django
   ```

3. **If no script exists, create the user directly in the database**:
   - **PostgreSQL**: Insert a user with a bcrypt-hashed password:
     ```bash
     # Generate bcrypt hash for "AuditTest123!"
     HASH=$(node -e "const bcrypt=require('bcryptjs');console.log(bcrypt.hashSync('AuditTest123!',10))")
     psql "$DATABASE_URL" -c "INSERT INTO users (email, password, role, name, created_at) VALUES ('audit-test@dev.local', '$HASH', 'admin', 'Audit Test User', NOW()) ON CONFLICT (email) DO NOTHING;"
     ```
   - **MongoDB**: Use the MongoDB MCP `insert-many` tool to insert a test user document
   - **Supabase**: Use the Supabase auth admin API to create a user

4. **Record the credentials created**:
   - Email: `audit-test@dev.local`
   - Password: `AuditTest123!`
   - Role: `admin` (to access all routes)
   - Mark this user for cleanup after the audit completes

#### Strategy 3: Bypass Authentication

If credentials cannot be found or created, bypass the auth layer entirely:

1. **Check for auth bypass in dev mode** — look for:
   - `NEXT_PUBLIC_SKIP_AUTH`, `DISABLE_AUTH`, `BYPASS_AUTH`, `DEV_AUTH_BYPASS` in `.env` files
   - Middleware that skips auth when `NODE_ENV=development` or `NODE_ENV=test`
   - A `?bypass=true` or `?token=dev` query parameter pattern in the auth middleware

2. **Temporarily disable auth middleware** (dev environment only):
   - Locate the auth middleware file (grep for `middleware.ts`, `auth.ts`, `withAuth`, `requireAuth`, `protect`, `isAuthenticated`)
   - Add a dev-only bypass at the top of the middleware:
     ```typescript
     if (process.env.AUDIT_BYPASS_AUTH === 'true') {
       return next(); // Audit bypass — remove after audit
     }
     ```
   - Set `AUDIT_BYPASS_AUTH=true` in the environment and restart the dev server
   - **IMPORTANT**: This change must be reverted after the audit. Add a TODO comment and track it.

3. **Inject session cookies directly** — if the app uses JWT or session cookies:
   - Generate a valid JWT token using the app's secret key from `.env` (`JWT_SECRET`, `AUTH_SECRET`, `NEXTAUTH_SECRET`)
   - Inject the cookie into the browser context:
     ```javascript
     await context.addCookies([{
       name: 'session-token', // or 'next-auth.session-token', '__session', etc.
       value: generatedToken,
       domain: 'localhost',
       path: '/',
     }]);
     ```

#### Strategy 4: Ask the User (Last Resort)

Only if all three strategies above fail:

1. Report which strategies were attempted and why they failed
2. Ask the user for ONE of:
   - Login credentials (email + password)
   - A session cookie value to inject
   - Instructions on how to access the app as an authenticated user
3. Proceed with the provided credentials

#### Post-Audit Cleanup

After the audit completes, clean up any auth changes:

- **If Strategy 2 was used**: Delete the `audit-test@dev.local` user from the database
- **If Strategy 3 was used**: Revert any auth bypass code changes, remove `AUDIT_BYPASS_AUTH` env var
- **Log cleanup actions** in the audit summary so the user knows exactly what was created/modified and what was reverted

### When Screenshots Are Required

- The finding is **visual** (broken layout, missing element, wrong data displayed) — ALWAYS capture both viewports
- The finding is **behavioral** (filter not working, wrong state) — capture the state demonstrating the problem
- The finding is **structural** (missing pagination, no validation) — capture the page showing the gap
- The finding is **a11y** — capture the page + include accessibility tree snapshot as a code block
- The finding is **UX** — capture both desktop AND mobile to show responsive behavior
- The finding is **performance** — capture the page + include Lighthouse scores as text in the issue

### When Screenshots Are NOT Required

- Pure backend / API-only issues with no UI surface
- Code-level issues (type errors, unused imports, dead code)
- Configuration or environment issues

## Phase 4: Create Linear Issues

For each consolidated finding, create a Linear issue using the `save_issue` MCP tool.

### Jorge's Exact Issue Template

Every issue MUST follow this structure:

```markdown
## Before (Pre-Fix)
[BEFORE Playwright screenshot(s) — desktop and mobile showing the current broken state]

## Problem
[Clear, concise description of the bug or issue observed. State what is wrong, not what should be done.]

## Root Cause
[Technical analysis of WHY the issue exists. Reference specific code patterns, misconfigurations, or architectural decisions. Include file paths and line numbers when possible.]

## Files Affected
[Bulleted list of specific files and components involved. Use relative paths from project root.]

## Impact
[Business and user-facing consequences: trust, compliance, performance, UX, security. Quantify where possible — e.g., "Lighthouse a11y score: 62/100", "LCP: 4.2s on /dashboard".]

## Fix
[Numbered, actionable steps to resolve. Each step should be specific enough for a developer to implement without ambiguity. Use sub-bullets for implementation details.]

## Verification
[Concrete test scenarios to confirm the fix is correct. Each bullet = one verification step a QA engineer can execute.]

## After (Post-Fix)
<!-- AFTER screenshots will be added here once the fix is implemented -->
[AFTER Playwright screenshot(s) — desktop and mobile showing the completed fix output. Added via Phase 7 after implementation.]
```

### Required Fields for save_issue

| Field       | Value                                                                 |
|-------------|-----------------------------------------------------------------------|
| title       | Concise, descriptive — e.g., "Dashboard — missing loading states, broken mobile layout, and Lighthouse a11y score 62" |
| description | Full issue body with screenshots + all 6 sections above               |
| priority    | 1=Urgent, 2=High, 3=Medium, 4=Low                                    |
| teamId      | `e50ae77f-4dee-4215-86a5-a0be5c163b7d` (Alliance Global Solutions)   |
| projectId   | Auto-detected from repo (see Phase 1)                                 |
| assigneeId  | `d4215d96-2261-4bbf-a3ca-5ef5e741bc86` (Vincent John Rodriguez)      |
| labelIds    | Map finding type to label: `Bug`, `Feature`, `Security`, `Accessibility`, `Performance`, `UX`, or `Refactor` |

### Uploading & Embedding Screenshots in Issues (MANDATORY)

Screenshots MUST be uploaded and embedded in every Linear issue that has a UI finding. This is a 3-step process using Linear MCP tools. Do NOT skip this — issues without screenshots are incomplete.

#### Step 1: Create the issue FIRST (without screenshots)

Create the Linear issue via `save_issue` with a placeholder in the description where screenshots will go:

```markdown
## Before (Pre-Fix)
<!-- Screenshots uploading... -->

## Problem
...
```

Record the returned issue ID (e.g., `ALL-140`).

#### Step 2: Upload each screenshot file to Linear

For EACH screenshot file, execute this exact 3-step sequence:

**Step 2a** — Get the file size in bytes:
```bash
wc -c < "./audit-screenshots/before/before-{slug}-desktop.png"
```

**Step 2b** — Call `prepare_attachment_upload` with the issue ID, filename, content type, and exact file size:
```
prepare_attachment_upload(
  issue: "ALL-140",
  filename: "before-dashboard-desktop.png",
  contentType: "image/png",
  size: <exact byte count from step 2a>,
  title: "Before — Dashboard Desktop"
)
```

This returns TWO values — save both:
- `assetUrl` — the permanent Linear CDN URL for this file
- `uploadRequest.url` + `uploadRequest.headers` — the signed Google Cloud upload URL and headers

**Step 2c** — Upload the raw file bytes via curl with ALL signed headers exactly as returned:
```bash
curl -X PUT --data-binary @"./audit-screenshots/before/before-dashboard-desktop.png" \
  -H "content-type: image/png" \
  -H "x-goog-content-length-range: <value from headers>" \
  -H "cache-control: public, max-age=31536000" \
  -H 'Content-Disposition: attachment; filename="before-dashboard-desktop.png"' \
  "<uploadRequest.url>"
```

CRITICAL: Use `--data-binary` (NOT `-d`). Send ALL headers from `uploadRequest.headers` exactly as returned — do not modify casing or omit any. The signed URL expires in 60 seconds, so execute immediately after step 2b.

**Step 2d** — Finalize the attachment by calling `create_attachment_from_upload`:
```
create_attachment_from_upload(
  issue: "ALL-140",
  assetUrl: "<assetUrl from step 2b>",
  title: "Before — Dashboard Desktop"
)
```

Repeat steps 2a–2d for every screenshot (desktop, mobile, element captures).

#### Step 3: Update the issue description with embedded images

After all screenshots are uploaded, update the issue description via `save_issue` to replace the placeholders with the actual `assetUrl` values:

```markdown
## Before (Pre-Fix)
**Desktop (1920×1080):**
![Before — Dashboard Desktop](assetUrl-from-step-2b)

**Mobile (375×812):**
![Before — Dashboard Mobile](assetUrl-from-step-2b-mobile)

## Problem
...
```

Use the `assetUrl` returned by `prepare_attachment_upload` — this is the permanent CDN link that renders inline in Linear.

#### Full Upload Sequence Per Issue

```
1. save_issue → create issue, get issue ID (e.g., ALL-140)
2. For each screenshot:
   a. wc -c to get file size
   b. prepare_attachment_upload → get assetUrl + uploadRequest
   c. curl PUT --data-binary with ALL signed headers → upload raw bytes
   d. create_attachment_from_upload → link file to issue
3. save_issue → update description with ![alt](assetUrl) markdown
```

#### For AFTER Screenshots (Phase 6)

The same upload sequence applies when adding AFTER screenshots. Instead of updating the issue description, add them as a **comment** using `save_comment`:

```
1. For each AFTER screenshot:
   a–d. Same upload steps as above
2. save_comment on the issue with:
   ### Implementation Complete: Post-Fix Verification
   **AFTER — Desktop:**
   ![After — Dashboard Desktop](assetUrl)
   **AFTER — Mobile:**
   ![After — Dashboard Mobile](assetUrl)
```

## Phase 5: Comments

After issue creation, add comments using the `save_comment` MCP tool when:

- **Lighthouse scores** — attach full Lighthouse audit summary (a11y score, performance score, best practices score) as a comment
- **Accessibility tree excerpt** — paste relevant portions of the accessibility tree snapshot showing the violation
- **Performance trace data** — include LCP subpart breakdown (TTFB, resource load delay, load duration, render delay)
- **Code snippets** — when the root cause involves specific code patterns, include the offending snippet
- **Related findings** — link to other issues from this audit that are connected
- **Workarounds** — provide temporary mitigation steps for the team

Comment format:
```markdown
### [Context Type]: [Brief Title]

[Content — code blocks, Lighthouse scores, accessibility tree excerpts, or explanation]
```

## Phase 6: Implementation & AFTER Screenshots (Post-Fix Verification)

After each fix is implemented, capture **AFTER** screenshots to prove the change was completed successfully. These get attached to the same Linear issue as visual proof.

### When to Run Phase 6

This phase runs **after code changes are applied** for each issue. It can run:
- Immediately after fixing each issue (one at a time)
- In a batch after multiple fixes are applied
- As a separate `/code-audit` pass by specifying "verify fixes" mode

### Capturing AFTER Screenshots

For each fixed issue, re-capture the same routes and elements that were captured in the BEFORE screenshots:

1. **Ensure the dev server is running** with the fix applied (localhost must reflect the updated code)
2. **Navigate to the same route** used in the BEFORE capture
3. **Capture both viewports**:
   - `after-{slug}-desktop.png` — desktop 1920x1080, post-fix
   - `after-{slug}-mobile.png` — mobile 375x812, post-fix
   - `after-{slug}-element-{component}.png` — targeted element, post-fix
4. **Save in** `./audit-screenshots/after/`

### Re-run Audit Checks on Fixed Routes

After capturing screenshots, re-run the relevant audit checks to produce measurable proof:

- **If the issue was a11y:** Re-run `lighthouse_audit` with `categories: ["accessibility"]` — include the new score
- **If the issue was performance:** Re-run `lighthouse_audit` with `categories: ["performance"]` — include the new LCP time and score
- **If the issue was UX:** Re-capture both viewports and verify the UX checklist items now pass
- **If the issue was a bug:** Capture the page state showing the correct behavior

### Uploading AFTER Screenshots & Updating the Linear Issue

For each fixed issue, upload AFTER screenshots using the SAME 3-step MCP flow from Phase 4:

**Step 1** — For each AFTER screenshot file:
```
a. wc -c < "./audit-screenshots/after/after-{slug}-desktop.png"   → get exact byte size
b. prepare_attachment_upload(issue: "ALL-140", filename: "after-dashboard-desktop.png", contentType: "image/png", size: <bytes>)
   → returns assetUrl + uploadRequest
c. curl -X PUT --data-binary @"./audit-screenshots/after/after-dashboard-desktop.png" \
     -H "content-type: image/png" \
     -H "x-goog-content-length-range: <from headers>" \
     -H "cache-control: public, max-age=31536000" \
     -H 'Content-Disposition: attachment; filename="after-dashboard-desktop.png"' \
     "<uploadRequest.url>"
d. create_attachment_from_upload(issue: "ALL-140", assetUrl: "<assetUrl>", title: "After — Dashboard Desktop")
```

**Step 2** — Add a verification comment with the uploaded AFTER `assetUrl` values via `save_comment`:

```markdown
### Implementation Complete: Post-Fix Verification

**AFTER — Desktop:**
![After — Dashboard Desktop](assetUrl-from-step-1b)

**AFTER — Mobile:**
![After — Dashboard Mobile](assetUrl-from-step-1b-mobile)

**Before → After Comparison:**
| Metric | Before | After |
|--------|--------|-------|
| Lighthouse A11y | 62/100 | 98/100 |
| Lighthouse Perf | 71/100 | 94/100 |
| LCP | 4.2s | 1.8s |
| Issue Status | Broken | Resolved |

**Changes Made:**
- [List of files modified with brief description of each change]
- [Link to commit or PR if available]
```

**Step 3** — Update issue status via `save_issue` to `Done` or `In Review`
**Step 4** — If a PR was created, add it as a comment linking to the PR URL

### Side-by-Side Evidence Format

When adding AFTER screenshots, always present them alongside the BEFORE state for clear comparison. Use this format in comments:

```markdown
### Before / After: [Page or Component Name]

| Desktop | Mobile |
|---------|--------|
| **BEFORE** | **BEFORE** |
| ![before-desktop](url) | ![before-mobile](url) |
| **AFTER** | **AFTER** |
| ![after-desktop](url) | ![after-mobile](url) |
```

### What Counts as Verified

A fix is considered verified when:
- AFTER screenshots visually confirm the issue is resolved
- The same audit check that flagged the issue now passes (e.g., Lighthouse score improved, a11y violation gone)
- Both desktop and mobile viewports show correct behavior
- No new issues were introduced by the fix (check console for errors after navigation)

## Phase 7: Output Summary

After the full pipeline completes, provide a summary to the user:

### Audit Scorecard

```markdown
| Dimension       | Score | Status |
|-----------------|-------|--------|
| Security        | —     | X issues found |
| Architecture    | —     | X risks identified |
| Code Quality    | —     | X issues found |
| Accessibility   | XX/100 | Lighthouse a11y score (avg across routes) |
| Performance     | XX/100 | Lighthouse perf score (avg across routes) |
| Component Quality | —   | X anti-patterns found |
| UX Design       | —     | X usability issues found |
```

### Issues Filed

```markdown
| # | Issue ID | Title | Priority | Label | Before | After | Status |
|---|----------|-------|----------|-------|--------|-------|--------|
| 1 | ALL-XXX  | ...   | High     | Bug   | 2 imgs | 2 imgs | Done |
| 2 | ALL-XXX  | ...   | Medium   | A11y  | 3 imgs | pending | Todo |
```

Include:
- Total issues created, grouped by label type
- Breakdown by priority
- Link to each Linear issue URL
- Average Lighthouse scores (accessibility + performance) across all routes — BEFORE and AFTER where fixes were applied
- Count of issues with AFTER verification completed vs. still pending
- Any findings that could NOT be filed (with reason)
- Top 3 highest-impact recommendations
