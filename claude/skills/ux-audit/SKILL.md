---
name: ux-audit
description: >
  AI-powered UI/UX design quality auditor that uses Playwright for visual inspection
  and design reasoning to evaluate whether a live UI feels human. Runs 14 modular
  audit passes covering visual hierarchy, typography, color, spacing, micro-interactions,
  emotional design, Nielsen heuristics, Laws of UX, accessibility, dark patterns,
  mobile/responsive, trust signals, performance perception, and (when the app has
  points/badges/levels/leaderboards) gamification & reward psychology. Cross-references
  every finding against the project's own design-system manifest when one exists
  (`.impeccable/design.json`, `DESIGN.md`, `design-system/MASTER.md`) rather than only
  generic heuristics, and optionally pulls `ui-ux-pro-max` design-intelligence
  recommendations as a secondary cross-check. Supports --quick
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
- **agshub-crud** (optional — for auto-filing design debt work items; see that skill for endpoints)
- **`ui-ux-pro-max`** (optional — design-intelligence cross-check for the color/typography/style passes; see that skill's `--design-system` search)
- A running application accessible at a URL

**Auth fallback (confirmed repeatedly in practice):** if the app's login is gated behind an
OAuth popup requiring live 2FA (Google Workspace, Microsoft, etc.) with no dev bypass,
Playwright **cannot** complete it in an isolated browser profile. Fall back to
`claude-in-chrome` driving the user's already-authenticated Chrome session instead — same
navigate/screenshot/DOM-read operations, just against a real logged-in tab. Check for a dev
bypass first (`BYPASS_AUTH`/`SKIP_AUTH`/`DEV_AUTH_BYPASS` env vars, an email/password login
fallback) before concluding Playwright is blocked.

## Invocation

```
/ux-audit                                    → Full 14-pass, both tiers (Gamification pass auto-skips to N/A if no gamification elements exist)
/ux-audit --quick                            → Tier 1 only (automated scripts, fast)
/ux-audit --pass typography,color,spacing    → Cherry-pick specific passes
/ux-audit --fix                              → Audit + apply safe auto-fixes after
/ux-audit --pages /dashboard,/settings       → Audit specific pages only
/ux-audit --viewport mobile                  → Mobile-only (375px)
/ux-audit --viewport all                     → Test at 375, 768, 1024, 1440px
```

All flags are combinable. Defaults: full 14-pass, both tiers, all pages, 1920x1080.

## Pass Names (for --pass flag)

`visual-hierarchy`, `typography`, `color`, `spacing`, `micro-interactions`, `emotional`, `nielsen`, `laws-of-ux`, `accessibility`, `dark-patterns`, `mobile`, `trust`, `performance`, `gamification`

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
- **Design-system manifest** — look for `.impeccable/design.json`, `DESIGN.md`,
  `design-system/MASTER.md` (the `ui-ux-pro-max --persist` output), or an equivalent
  project-authored design-rules doc. If one exists, **read it and treat its named rules as
  ground truth** for every pass below — a project's own documented rule (e.g. "only one CTA
  color", "gray-500 is the contrast floor") always outranks a generic heuristic when they'd
  otherwise conflict. Cite the rule by name in findings that reference it (e.g. "breaks the
  design system's 'One Voice Rule'") rather than just describing the visual symptom.

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
- **Gamified/Rewards** — points, badges, levels, leaderboards, streaks → activate Pass 14
  (Gamification & Reward Psychology); this can co-occur with Dashboard or Admin/Internal on
  the same page (e.g. an employee-engagement dashboard is both)

This classification adjusts scoring weights for this page.

#### Step 3: Run Selected Passes
For each selected pass (all 14 by default — Pass 14 only if Tier 1 detected gamification elements):

1. **Read the pass reference file** from `references/passes/{pass}.md`
2. **Run Tier 1 scripts** from the pass file via `browser_evaluate` — collect JSON results
3. **Run Tier 2 AI evaluation** (unless `--quick`) — read screenshot + DOM snapshot + Tier 1 results, apply the pass's heuristics
4. **AI Pattern Recognition (Layer 1)** — interpret Tier 1 results contextually, eliminate false positives, add "Why this matters" reasoning
5. **Cross-check against `ui-ux-pro-max`** (color, typography, style, and ux domains only; optional, skip silently if unavailable) — pull its design-intelligence recommendations as a *secondary* input. Its keyword-matched search can badly mismatch niche categories (e.g. it may recommend a generic marketing-site palette for an internal HR tool) — when it conflicts with the project's own design-system manifest (Phase 0) or with clearly-established in-app conventions, the manifest/conventions win and the `ui-ux-pro-max` suggestion is noted, not followed.
6. **Score the pass** 1-5 using the pass's scoring criteria (or **N/A** for Pass 14 if no gamification elements exist on any page)
7. **Collect findings** with severity, pass tag, page, screenshot reference, root cause file:line — cite the specific design-system-manifest rule by name when a finding traces back to one

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

**agshub-crud integration (if requested):**
- File work items via `agshub-crud` (`mcp__agshub__*` tools if attached, else its REST helper) — resolve the workspace/project first, never guess
- Apply a `Design Debt` label (resolve or create it in the target project via `GET`/`POST .../labels`)
- Group by theme (one work item per theme, not per finding)
- Reference screenshot file paths, the finding, and the recommended fix in the (plain-text) description — agshub has no attachment-upload endpoint, so screenshots stay on disk and are referenced by path, not embedded
- `priority` mapped from severity using agshub's enum (`urgent`/`high`/`medium`/`low`)

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
- When a project has its own design-system manifest (Phase 0), it is the primary source of
  truth — a generic heuristic or a `ui-ux-pro-max` suggestion never overrides a documented
  project rule; note the conflict instead of "fixing" toward the generic default
- Pass 14 (Gamification) only scores pages with actual points/badges/levels/leaderboards —
  never force it to N/A→1 or invent gamification findings on a page that has none
- If Playwright can't complete login (OAuth popup + live 2FA, no dev bypass found), fall back
  to `claude-in-chrome` rather than reporting the audit as blocked

## Reference Files

- **`references/safety-guardrails.md`** — Never-modify and safe-to-modify lists, pre-flight validation
- **`references/scoring-rubric.md`** — Scoring system, DQS weights, severity mapping
- **`references/report-template.md`** — Full report and scorecard templates
- **`references/passes/01-visual-hierarchy.md`** through **`14-gamification-psychology.md`** — Individual pass definitions
- **`scripts/evaluate.md`** — Reusable `browser_evaluate` script library
