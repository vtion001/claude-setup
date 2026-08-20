# UI Audit — Report Template

## Full Report: `ui-audit/ui-audit-report.md`

```markdown
# UI Audit Report — {Project Name}

**Date:** {date}
**URL:** {app_url}
**Framework:** {framework}
**Design System:** {design_system}
**CSS Methodology:** {css_methodology}
**Viewport(s):** {viewports}
**Passes Run:** {passes}
**Mode:** {full|quick|code-only}

---

## Executive Summary

{AI-generated narrative: 3-5 sentences identifying root cause patterns, not symptoms.}

**UI Quality Score: {score}/100 — {label}**

### Top 3 Highest-Impact Changes
1. {change} — estimated effort: {hours/sprint}
2. {change} — estimated effort: {hours/sprint}
3. {change} — estimated effort: {hours/sprint}

### Total Estimated Effort: {sprint estimate}

---

## UI Quality Scorecard

### Overall UIQS: {score}/100 — {label}

| # | Pass | Score | Weight | Weighted | Key Finding |
|---|------|-------|--------|----------|-------------|
| 01 | Design Tokens | {1-5} | 3x | {weighted} | {one-line finding} |
| 02 | CSS Architecture | {1-5} | 2x | {weighted} | {one-line finding} |
| 03 | Component Quality | {1-5} | 3x | {weighted} | {one-line finding} |
| 04 | Visual Regression | {1-5} | 1x | {weighted} | {one-line finding} |
| 05 | Gestalt Principles | {1-5} | 1x | {weighted} | {one-line finding} |
| 06 | Visual Balance | {1-5} | 1x | {weighted} | {one-line finding} |
| 07 | Color System | {1-5} | 2x | {weighted} | {one-line finding} |
| 08 | Type System | {1-5} | 2x | {weighted} | {one-line finding} |
| 09 | Atomic Design | {1-5} | 2x | {weighted} | {one-line finding} |
| 10 | Grid & Layout | {1-5} | 2x | {weighted} | {one-line finding} |
| 11 | Icon System | {1-5} | 1x | {weighted} | {one-line finding} |
| 12 | UI State Coverage | {1-5} | 3x | {weighted} | {one-line finding} |

### UI Consistency Score: {score}/100

| Dimension | Weight | Score | Issues |
|-----------|--------|-------|--------|
| Token Usage | 20% | {score} | {count} inconsistencies |
| Component Variants | 20% | {score} | {count} inconsistencies |
| Grid System | 15% | {score} | {count} inconsistencies |
| Type Scale | 15% | {score} | {count} inconsistencies |
| Color Semantics | 10% | {score} | {count} inconsistencies |
| Icon System | 10% | {score} | {count} inconsistencies |
| Spacing Values | 5% | {score} | {count} inconsistencies |
| Border Radii | 5% | {score} | {count} inconsistencies |

### Design Maturity Matrix

> Only shown when `/ux-audit` results exist in `ux-audit/`

|  | UIQS High (75+) | UIQS Low (<75) |
|--|------------------|----------------|
| **DQS High (75+)** | Excellent — well-built AND well-designed | Looks good but fragile — design debt under the surface |
| **DQS Low (<75)** | Well-built but soulless — needs design attention | Needs both engineering and design investment |

**Current position:** {quadrant label}

---

## Codebase Analysis Summary (Tier 0)

> Results from Phase 1 — source code analysis before browser work.

| Metric | Value |
|--------|-------|
| Token adoption rate | {percentage}% |
| CSS methodology | {BEM/Modules/Utility-first/Mixed} |
| Total components | {count} |
| Component reuse rate | {percentage}% |
| Unique font sizes | {count} |
| Type scale ratio | {ratio name} ({value}) |
| Unique colors | {count} |
| Icon source(s) | {libraries} |
| CSS !important count | {count} |
| Max selector depth | {levels} |

---

## Findings by Severity

### Critical

> Findings that indicate system-wide failure or missing foundations.

#### {Finding title}

| Field | Value |
|-------|-------|
| **Pass** | {pass name} |
| **Page** | {page URL} |
| **What** | {description of the issue} |
| **Why it matters** | {impact on users, developers, or system health} |
| **Root cause** | `{file}:{line}` — {explanation} |
| **Recommended fix** | {specific code change} |
| **Auto-fixable?** | {Yes — safe to modify / No — requires manual review} |
| **Screenshot** | `screenshots/findings/{filename}.png` |

{Repeat for each critical finding}

### High

{Same format as Critical}

### Medium

{Same format as Critical}

### Low

{Same format as Critical}

---

## Themes

> Related findings grouped by shared root cause. Each theme has a unified fix.

### Theme 1: {Theme title}

**Root cause:** {underlying pattern causing multiple findings}
**Affected passes:** {list of passes}
**Finding count:** {number}
**Unified fix:** {single action that addresses all related findings}
**Estimated effort:** {hours or sprint fraction}

Findings in this theme:
- {finding 1 — one line}
- {finding 2 — one line}
- {finding 3 — one line}

{Repeat for each theme}

---

## Recommendations by Impact-to-Effort Ratio

| Rank | Theme | Impact | Effort | ROI | Action |
|------|-------|--------|--------|-----|--------|
| 1 | {theme} | {High/Medium/Low} | {hours} | {High/Medium/Low} | {specific action} |
| 2 | {theme} | {High/Medium/Low} | {hours} | {High/Medium/Low} | {specific action} |
| 3 | {theme} | {High/Medium/Low} | {hours} | {High/Medium/Low} | {specific action} |

---

## What's Working Well

> Positive findings to preserve and build on.

- {positive finding 1 — what's good and why}
- {positive finding 2}
- {positive finding 3}

---

## Appendix

### A. Raw Tier 1 Data
{JSON results from all browser_evaluate scripts}

### B. Component State Coverage Matrix
| Component | Default | Hover | Focus | Active | Disabled | Loading | Error | Empty | Success |
|-----------|---------|-------|-------|--------|----------|---------|-------|-------|---------|
| {name} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} |

### C. Breakpoint Comparison Screenshots
{Links to screenshots at 375, 768, 1024, 1440px}

### D. Token Adoption Details
{List of hardcoded values found and suggested token replacements}

### E. Auto-Fix Changelog (if --fix was used)
| File | Change | Before | After | Tier 1 Score Change |
|------|--------|--------|-------|---------------------|
| {file:line} | {description} | {value} | {value} | {before → after} |
```

---

## Quick Scorecard: `ui-audit/ui-audit-scorecard.md`

```markdown
# UI Audit Scorecard — {Project Name}

**UIQS: {score}/100** | **UCS: {score}/100** | **Date:** {date}

## Pass Scores

| Pass | Score | Visual |
|------|-------|--------|
| Design Tokens (3x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| CSS Architecture (2x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Component Quality (3x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Visual Regression (1x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Gestalt Principles (1x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Visual Balance (1x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Color System (2x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Type System (2x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Atomic Design (2x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Grid & Layout (2x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| Icon System (1x) | {score}/5 | {'█' × score}{'░' × (5-score)} |
| UI State Coverage (3x) | {score}/5 | {'█' × score}{'░' × (5-score)} |

## Top 3 Issues
1. {critical/high finding — one line}
2. {critical/high finding — one line}
3. {critical/high finding — one line}

## Top 3 Strengths
1. {positive finding — one line}
2. {positive finding — one line}
3. {positive finding — one line}

## Quick Wins (< 1 hour each)
- {easy fix — one line}
- {easy fix — one line}
- {easy fix — one line}

## Next Steps
- [ ] {action item 1}
- [ ] {action item 2}
- [ ] {action item 3}
```
