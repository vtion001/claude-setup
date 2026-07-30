---
name: ux-audit
description: >
  AI-powered UI/UX design quality auditor that uses Playwright for visual inspection
  and design reasoning to evaluate whether a live UI feels human. Runs 13 modular
  audit passes covering visual hierarchy, typography, color, spacing, micro-interactions,
  emotional design, Nielsen heuristics, Laws of UX, accessibility, dark patterns,
  mobile/responsive, trust signals, and performance perception. Supports --quick
  (automated only), --pass (cherry-pick), --fix (safe auto-fixes), --viewport, and
  --pages flags. This skill should be used when the user asks to "audit the design",
  "review the UX", "does this look good", "check the UI quality", "design review",
  "UX audit", "is the design human enough", "review the frontend design",
  "check visual hierarchy", "run a design audit", "ux review", "design quality check",
  "does this feel right", "rate the UI", "check design consistency".
---

# UX Audit — AI-Powered Design Quality Review

Evaluate whether a live UI feels human. Not "is it broken?" (that's `/qa-audit`) but "is it good?" — does it delight, does it guide, does it feel like a designer cared?

## Prerequisites

The following MCP tools must be available:
- **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_evaluate`, `browser_resize`, `browser_click`, `browser_hover`, `browser_console_messages`, `browser_network_requests`)
- **Linear MCP** (optional — for auto-filing design debt issues)
- A running application accessible at a URL

## Invocation

```
/ux-audit                                    → Full 13-pass, both tiers
/ux-audit --quick                            → Tier 1 only (automated scripts, fast)
/ux-audit --pass typography,color,spacing    → Cherry-pick specific passes
/ux-audit --fix                              → Audit + apply safe auto-fixes after
/ux-audit --pages /dashboard,/settings       → Audit specific pages only
/ux-audit --viewport mobile                  → Mobile-only (375px)
/ux-audit --viewport all                     → Test at 375, 768, 1024, 1440px
```

All flags are combinable. Defaults: full 13-pass, both tiers, all pages, 1920x1080.

## Pass Names (for --pass flag)

`visual-hierarchy`, `typography`, `color`, `spacing`, `micro-interactions`, `emotional`, `nielsen`, `laws-of-ux`, `accessibility`, `dark-patterns`, `mobile`, `trust`, `performance`

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
| `SCREENSHOT_DIR` | `./ux-audit/screenshots/` | Where to save screenshots |

Also detect:
- **Framework** (Next.js, Laravel, Vue, etc.) — adjusts route discovery and fix syntax
- **Design system** (shadcn, MUI, Chakra, Tailwind, CSS modules) — adjusts fix recommendations
- **Existing CSS variables/tokens** — reuse in recommendations instead of hardcoded values
- **Shared components** — identify centralized fix points

### Phase 1: Route Discovery

Extract all user-facing routes from the application.

**For Next.js:** Read `app/` or `pages/` directory structure.
**For Laravel:** `php artisan route:list --columns=method,uri,name,middleware --json` — filter GET + web/auth middleware.
**For other frameworks:** Read route definition files directly.

Organize routes into page groups:
- Public pages (no auth)
- Authenticated pages (require login)
- Admin pages (elevated roles)

If `--pages` flag is set, use only the specified pages.

### Phase 2: Authentication

If auth is required:
1. Navigate to login page
2. Screenshot the login page (it gets audited too)
3. Fill credentials and submit
4. Verify login succeeded
5. If login fails, report error and stop

### Phase 3: Page-by-Page Audit

For each discovered page:

#### Step 1: Capture
1. Navigate to the page URL via `browser_navigate`
2. Wait for full page load (network idle)
3. Take screenshot at current viewport via `browser_take_screenshot`
4. Save as `{page-name}_{viewport}_{timestamp}.png`
5. Take DOM snapshot via `browser_snapshot` for accessibility tree
6. If `--viewport all`: resize to each breakpoint via `browser_resize`, repeat screenshot + snapshot

#### Step 2: Classify Page Type (AI Layer 2)
Read the DOM snapshot and classify:
- **Dashboard** — data density, cards, charts → relax whitespace, tighten hierarchy
- **Landing page** — hero, CTA, social proof → tighten emotional design + trust
- **Form/Settings** — inputs, labels, sections → tighten error/empty states
- **Content/Blog** — long text, articles → tighten typography
- **E-commerce** — products, prices, cart → tighten trust signals
- **Onboarding** — steps, progress, welcome → tighten Peak-End Rule
- **Admin/Internal** — tables, filters, bulk actions → relax emotional, tighten efficiency

This classification adjusts scoring weights for this page.

#### Step 3: Run Selected Passes
For each selected pass (all 13 by default):

1. **Read the pass reference file** from `references/passes/{pass}.md`
2. **Run Tier 1 scripts** from the pass file via `browser_evaluate` — collect JSON results
3. **Run Tier 2 AI evaluation** (unless `--quick`) — read screenshot + DOM snapshot + Tier 1 results, apply the pass's heuristics
4. **AI Pattern Recognition (Layer 1)** — interpret Tier 1 results contextually, eliminate false positives, add "Why this matters" reasoning
5. **Score the pass** 1-5 using the pass's scoring criteria
6. **Collect findings** with severity, pass tag, page, screenshot reference, root cause file:line

#### Step 4: Source Code Cross-Reference
For each finding:
1. Read the relevant source file to identify exact file and line
2. Determine root cause (missing class, wrong token, missing state, etc.)
3. Determine specific fix (exact CSS/Tailwind change)
4. Classify: safe to auto-fix? (check against `references/safety-guardrails.md`)

### Phase 4: Cross-Page Consistency Analysis

After all pages are audited individually, run the consistency sweep:

1. Collect all design pattern instances across pages (typography, color, spacing, components, interactions, empty states, errors, loading, icons, navigation)
2. For each pattern dimension, compare values across all pages
3. Flag inconsistencies
4. **AI Layer 3 (Comparative Intelligence):** For each inconsistency, identify which page scores highest on that pattern and recommend unifying toward it — explain WHY using design principles
5. Calculate Design Consistency Score (0-100)

### Phase 5: Report Generation

Read `references/report-template.md` for the full template.

Generate:
- `ux-audit/ux-audit-report.md` — Full narrative report
- `ux-audit/ux-audit-scorecard.md` — Quick-reference scorecard
- `ux-audit/screenshots/` — All captured screenshots

**AI Layer 4 (Design Narrative):**
Write the Executive Summary as a senior designer would:
- Identify root cause patterns (not just symptoms)
- Group findings into themes with unified fixes
- Prioritize by impact-to-effort ratio
- Estimate effort in sprint-friendly terms
- Speak in design language, not just code language

**Calculate Design Quality Score (DQS):**
Read `references/scoring-rubric.md` for weights and formula.

**Linear integration (if requested):**
- File issues with label `["Design Debt"]`
- Group by theme (one issue per theme, not per finding)
- Include screenshot, finding, and recommended fix
- Priority mapped from severity

### Phase 6: Auto-Fix (if --fix)

Only runs when `--fix` flag is provided. After the full audit:

1. Read `references/safety-guardrails.md` — internalize the never-modify and safe-to-modify lists
2. Filter findings to only those marked "safe to auto-fix"
3. For each safe fix:
   a. Read the full target file
   b. Run pre-flight validation (imports check, event handler proximity check, presentational-only check)
   c. If validation fails → escalate to report-only with "MANUAL FIX REQUIRED" annotation
   d. If validation passes → add to proposed changes
4. Present ALL proposed changes to the user as a unified diff
5. Wait for explicit user confirmation
6. Apply changes
7. Re-run affected Tier 1 checks to verify improvements
8. Report before/after scores

## Important Rules

- Never skip a page — audit every discovered route (unless --pages is set)
- Always take a screenshot before reporting a finding
- Always cross-reference findings with source code — never guess root causes
- Read the actual code before recommending fixes
- Group related findings under themes when they share a root cause
- Report what IS working — this builds confidence and identifies patterns to preserve
- The --fix mode MUST present changes and wait for confirmation before applying
- When in doubt about a fix's safety, report it — don't apply it
- Respect the existing design system — recommend within its vocabulary, not against it
- AI Layer 5 (Codebase Learning): Before any recommendation, check what framework, design system, CSS tokens, and shared components exist. Adapt all suggestions to the actual stack.

## Reference Files

- **`references/safety-guardrails.md`** — Never-modify and safe-to-modify lists, pre-flight validation
- **`references/scoring-rubric.md`** — Scoring system, DQS weights, severity mapping
- **`references/report-template.md`** — Full report and scorecard templates
- **`references/passes/01-visual-hierarchy.md`** through **`13-performance-perception.md`** — Individual pass definitions
- **`scripts/evaluate.md`** — Reusable `browser_evaluate` script library
