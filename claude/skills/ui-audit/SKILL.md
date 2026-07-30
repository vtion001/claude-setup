---
name: ui-audit
description: >
  AI-powered UI implementation quality auditor that uses Playwright for visual inspection,
  source code analysis, and design theory evaluation. Runs 12 modular audit passes using a
  three-tier system (Tier 0: code analysis, Tier 1: browser scripts, Tier 2: AI judgment)
  covering design tokens, CSS architecture, component quality, visual regression, Gestalt
  principles, visual balance, color system, type system, atomic design, grid/layout, icon
  system, and UI state coverage. Supports --quick, --code-only, --pass, --fix, --viewport,
  --pages, and --snapshot flags. This skill should be used when the user asks to "audit the UI",
  "check component consistency", "design system health check", "is the CSS clean",
  "check design tokens", "visual regression check", "are all states implemented",
  "grid alignment check", "audit the frontend implementation", "design system audit",
  "UI quality check", "check the UI implementation", "ui audit", "check design system".
---

# UI Audit — AI-Powered Implementation Quality Review

Evaluate whether a live UI is built right. Not "does it feel human?" (that's `/ux-audit`) but "is it built correctly?" — are tokens consistent, components complete, grid aligned, and the system healthy?

## Prerequisites

The following MCP tools must be available:
- **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_evaluate`, `browser_resize`, `browser_click`, `browser_hover`, `browser_console_messages`, `browser_network_requests`)
- **Linear MCP** (optional — for auto-filing UI debt issues)
- A running application accessible at a URL
- Access to source code (for Tier 0 codebase analysis)

## Invocation

```
/ui-audit                                    → Full 12-pass, all three tiers
/ui-audit --quick                            → Tier 0 + Tier 1 only (no AI judgment, fast)
/ui-audit --code-only                        → Tier 0 only (no browser needed)
/ui-audit --pass tokens,css,components       → Cherry-pick specific passes
/ui-audit --fix                              → Audit + apply safe auto-fixes after
/ui-audit --pages /dashboard,/settings       → Audit specific pages only
/ui-audit --viewport mobile                  → Mobile-only (375px)
/ui-audit --viewport all                     → Test at 375, 768, 1024, 1440px
/ui-audit --snapshot components              → Component-level documentation screenshots
/ui-audit --snapshot sections                → Section-level documentation screenshots
```

All flags are combinable. Defaults: full 12-pass, all three tiers, all pages, 1920x1080.

## Pass Names (for --pass flag)

`tokens`, `css`, `components`, `regression`, `gestalt`, `balance`, `color`, `type`, `atomic`, `grid`, `icons`, `states`

## Workflow

### Phase 0: Configuration

Auto-detect from codebase. Prompt only for values that cannot be resolved:

| Input | Default | Notes |
|-------|---------|-------|
| `APP_URL` | `http://localhost:3000` | Base URL of the running app |
| `AUTH_REQUIRED` | auto-detect | Whether login is needed |
| `LOGIN_EMAIL` | auto-detect from seeders/env | Dev credentials |
| `LOGIN_PASSWORD` | auto-detect from seeders/env | Dev credentials |
| `LINEAR_PROJECT` | auto-detect from context | For auto-filing |
| `SCREENSHOT_DIR` | `./ui-audit/screenshots/` | Where to save screenshots |

Also detect:
- **Framework** (Next.js, Laravel, Vue, etc.) — adjusts route discovery and fix syntax
- **Design system** (shadcn, MUI, Chakra, Tailwind, CSS modules) — adjusts fix recommendations
- **CSS methodology** (BEM, CSS modules, utility-first) — adjusts CSS architecture pass
- **Existing tokens/variables** — reuse in recommendations instead of hardcoded values
- **Component library/shared components** — identify centralized fix points

### Phase 1: Codebase Analysis (Tier 0)

Before opening any browser, run Tier 0 across all selected passes. Read source files using `Read`, `Grep`, `Glob` tools. This is the key differentiator from `/ux-audit`.

Analyze:
- **Token definitions** — CSS custom properties, Tailwind config, theme files, SCSS variables
- **CSS architecture** — file organization, naming conventions, specificity patterns, dead CSS
- **Component files** — prop interfaces, variant coverage, composition patterns, reuse metrics
- **Layout configurations** — grid definitions, breakpoint values, container queries
- **Font definitions** — font-face declarations, font stack consistency, weight usage
- **Icon sources** — icon library, SVG consistency, sizing system, accessibility labels
- **Color definitions** — palette structure, semantic vs. raw values, contrast ratios in code

If `--code-only` flag is set, stop here and generate report from Tier 0 findings only.

### Phase 2: Route Discovery

Extract all user-facing routes from the application.

**For Next.js:** Read `app/` or `pages/` directory structure.
**For Laravel:** `php artisan route:list --columns=method,uri,name,middleware --json` — filter GET + web/auth middleware.
**For other frameworks:** Read route definition files directly.

Organize routes into page groups:
- Public pages (no auth)
- Authenticated pages (require login)
- Admin pages (elevated roles)

If `--pages` flag is set, use only the specified pages.

### Phase 3: Authentication

If auth is required:
1. Navigate to login page
2. Screenshot the login page (it gets audited too)
3. Fill credentials and submit
4. Verify login succeeded
5. If login fails, report error and stop

### Phase 4: Page-by-Page Audit

For each discovered page:

#### Step 1: Capture
1. Navigate to the page URL via `browser_navigate`
2. Wait for full page load (network idle)
3. Take screenshot at current viewport via `browser_take_screenshot`
4. Save as `{page-name}_{viewport}_{timestamp}.png`
5. Take DOM snapshot via `browser_snapshot` for accessibility tree
6. If `--viewport all`: resize to each breakpoint (375, 768, 1024, 1440px) via `browser_resize`, repeat screenshot + snapshot

#### Step 2: Run Tier 1 Scripts
For each selected pass (all 12 by default):
1. **Read the pass reference file** from `references/passes/{pass}.md`
2. **Run Tier 1 scripts** from the pass file via `browser_evaluate` — collect JSON results

#### Step 3: Run Tier 2 AI Evaluation
Unless `--quick` is set:
1. Read screenshot + DOM snapshot + Tier 0 results + Tier 1 results
2. Apply the pass's heuristics and design theory criteria
3. Interpret results contextually, eliminate false positives
4. Add "Why this matters" reasoning for each finding

#### Step 4: Score Each Pass
Score each pass 1-5 using the pass's scoring criteria from its reference file.

#### Step 5: Source Code Cross-Reference
For each finding:
1. Read the relevant source file to identify exact file and line
2. Determine root cause (missing token, wrong variable, inconsistent variant, etc.)
3. Determine specific fix (exact CSS/Tailwind/component change)
4. Classify: safe to auto-fix? (check against `references/safety-guardrails.md`)

### Phase 5: Cross-Page Consistency Analysis

After all pages are audited individually, run the consistency sweep:

1. Collect all implementation pattern instances across pages:
   - Token usage (are the same tokens used everywhere?)
   - CSS patterns (consistent methodology?)
   - Component variants (same component rendered the same way?)
   - Grid system (consistent columns, gutters, breakpoints?)
   - Type scale (same hierarchy applied uniformly?)
   - Color usage (semantic tokens vs. raw values?)
   - Icon system (consistent sizing, stroke, source?)
   - State implementation (loading, empty, error on every page?)
   - Spacing values (consistent scale or ad-hoc?)
   - Border radii (unified radius tokens?)
2. For each dimension, compare values across all pages
3. Flag inconsistencies
4. AI identifies the strongest implementation per dimension and recommends unifying toward it
5. Calculate **UI Consistency Score** (0-100)

### Phase 6: Documentation Screenshots

Only runs when `--snapshot` flag is provided.

Capture targeted screenshots based on snapshot mode:

**`--snapshot components`:**
- Individual components in all states: default, hover, focus, active, disabled, loading, error, empty, success
- Trigger each state via `browser_hover`, `browser_click`, `browser_evaluate`

**`--snapshot sections`:**
- Headers, sidebars, footers, card groups, form sections
- Full-width captures of each major layout section

**Both modes include:**
- Breakpoint comparison strips at 375, 768, 1024, 1440px

Save to `ui-audit/screenshots/` organized into subdirectories:
- `pages/` — full-page captures
- `components/` — isolated component captures
- `findings/` — annotated finding screenshots
- `regressions/` — before/after comparison pairs

### Phase 7: Report Generation

Read `references/report-template.md` for the full template.

Generate:
- `ui-audit/ui-audit-report.md` — Full narrative report
- `ui-audit/ui-audit-scorecard.md` — Quick-reference scorecard
- `ui-audit/screenshots/` — All captured screenshots

**Calculate UI Quality Score (UIQS):**
Read `references/scoring-rubric.md` for weights and formula.

**Design Maturity Matrix (if /ux-audit results exist):**
If a previous `/ux-audit` report is found, generate a cross-referenced Design Maturity Matrix combining UX feel scores with UI implementation scores to show where the system is both well-designed AND well-built vs. gaps.

**Linear integration (if requested):**
- File issues with label `["UI Debt"]`
- Group by theme (one issue per theme, not per finding)
- Include screenshot, finding, and recommended fix
- Priority mapped from severity

### Phase 8: Auto-Fix (if --fix)

Only runs when `--fix` flag is provided. After the full audit:

1. Read `references/safety-guardrails.md` — internalize the never-modify and safe-to-modify lists
2. Filter findings to only those marked "safe to auto-fix"
3. For each safe fix:
   a. Read the full target file
   b. Run pre-flight validation (imports check, token existence check, component API check)
   c. If validation fails → escalate to report-only with "MANUAL FIX REQUIRED" annotation
   d. If validation passes → add to proposed changes
4. Present ALL proposed changes to the user as a unified diff
5. Wait for explicit user confirmation
6. Apply changes
7. Re-run affected Tier 1 checks to verify improvements
8. Report before/after scores

## Important Rules

- Always run Tier 0 (codebase analysis) before browser work — source code context prevents false positives
- Never skip a page — audit every discovered route (unless --pages is set)
- Always take a screenshot before reporting a finding
- Always cross-reference findings with source code — never guess root causes
- Read the actual code before recommending fixes
- Group related findings under themes when they share a root cause
- Report what IS working — this builds confidence and identifies patterns to preserve
- The --fix mode MUST present changes and wait for confirmation before applying
- When in doubt about a fix's safety, report it — don't apply it
- Respect the existing design system — recommend within its vocabulary, not against it
- If `/ux-audit` results exist, read them to avoid duplicate work and cross-reference findings
- AI Layer 5 (Codebase Learning): Before any recommendation, check what framework, design system, CSS tokens, and shared components exist. Adapt all suggestions to the actual stack.

## Reference Files

- **`references/safety-guardrails.md`** — Never-modify and safe-to-modify lists, pre-flight validation
- **`references/scoring-rubric.md`** — Scoring system, UIQS weights, severity mapping
- **`references/report-template.md`** — Full report and scorecard templates
- **`references/passes/01-design-tokens.md`** through **`12-ui-state-coverage.md`** — Individual pass definitions
- **`scripts/evaluate.md`** — Reusable `browser_evaluate` script library
