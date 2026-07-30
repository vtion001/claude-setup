# UX Audit Report Template

## Report Structure

---

## 1. Executive Summary

The executive summary provides stakeholders with a high-level overview of design quality.

### Fields

- **Project Name** -- name of the audited project
- **Audit Date** -- YYYY-MM-DD format
- **Auditor** -- Claude Code UX Audit Skill
- **Pages Audited** -- number of pages
- **Mode** -- observe or fix
- **Total Findings** -- count by severity (C Critical, H High, M Medium, L Low)

### Sections to Include

1. AI-generated narrative paragraph (3-5 sentences) summarizing overall design quality
2. Root Causes -- the findings cluster around N root causes, each with brief description
3. Top 3 High-Impact Changes table with columns: Change, Findings Resolved, Effort, Files Affected
4. Design Quality Score (DQS) -- Overall DQS: XX.X / 100
5. Estimated Fix Effort breakdown: auto-fixable, manual fix, design decision required

---

## 2. Design Quality Scorecard

### Overall Score Visualization

```
+-----------------------------------------------------+
|                                                     |
|  OVERALL DQS: [XX.X] / 100                         |
|  Rating: [Ship-ready / Good / Needs Attention /     |
|           Design Debt / Start Over]                 |
|                                                     |
|  +---------------------------------------------+   |
|  | //////////////////////..........  78/100     |   |
|  +---------------------------------------------+   |
|                                                     |
+-----------------------------------------------------+
```

### Per-Page Scores Table

```
+----------------------+------+----------------+------------------+
|  Page                |  DQS | Rating         | Findings C/H/M/L |
+----------------------+------+----------------+------------------+
|  [Page 1]            | XX.X | [Rating]       | 0 / 1 / 3 / 2   |
|  [Page 2]            | XX.X | [Rating]       | 0 / 2 / 5 / 3   |
|  [Page 3]            | XX.X | [Rating]       | 1 / 0 / 2 / 1   |
+----------------------+------+----------------+------------------+
|  OVERALL             | XX.X | [Rating]       | 1 / 3 / 10 / 6  |
+----------------------+------+----------------+------------------+
```

### Per-Pass Breakdown (All Pages Averaged)

```
+----------------------------+--------+-------+---------+
|  Pass                      | Weight | Score | Weighted |
+----------------------------+--------+-------+---------+
|  Visual Hierarchy          |   3x   |  X/5  |   XX    |
|  Emotional Design          |   3x   |  X/5  |   XX    |
|  Nielsen Heuristics        |   3x   |  X/5  |   XX    |
|  Typography                |   2x   |  X/5  |   XX    |
|  Color System              |   2x   |  X/5  |   XX    |
|  Spacing & Layout          |   2x   |  X/5  |   XX    |
|  Micro-interactions        |   2x   |  X/5  |   XX    |
|  Accessibility (WCAG)      |   2x   |  X/5  |   XX    |
|  Laws of UX                |   1x   |  X/5  |   XX    |
|  Dark Patterns             |   1x   |  X/5  |   XX    |
|  Mobile Responsiveness     |   1x   |  X/5  |   XX    |
|  Trust & Credibility       |   1x   |  X/5  |   XX    |
|  Performance UX            |   1x   |  X/5  |   XX    |
+----------------------------+--------+-------+---------+
|  TOTAL                     |  24x   |       |  XX/120 |
+----------------------------+--------+-------+---------+
```

---

## 3. Design Consistency Score

**DCS: [XX.X] / 100 -- [Rating]**

### Dimension Breakdown

```
+----------------------+--------+------------+-------------------------------+
|  Dimension           | Weight | Score      | Notes                         |
+----------------------+--------+------------+-------------------------------+
|  Color Tokens        |  20%   | [XX]%      | [N] unique values, [N] tokens |
|  Typography Scale    |  20%   | [XX]%      | [N] unique sizes found        |
|  Spacing System      |  15%   | [XX]%      | [N]% on 8px grid             |
|  Component Variants  |  20%   | [XX]%      | [N] inconsistent instances    |
|  Interactive States  |  10%   | [XX]%      | [N] missing states            |
|  Border Radii        |   5%   | [XX]%      | [N] unique values             |
|  Shadow System       |   5%   | [XX]%      | [N] unique shadows            |
|  Icon Sizing         |   5%   | [XX]%      | [N] size variations           |
+----------------------+--------+------------+-------------------------------+
|  WEIGHTED TOTAL      | 100%   | [XX.X]%    |                               |
+----------------------+--------+------------+-------------------------------+
```

### Cross-Page Consistency Matrix

```
         Page1  Page2  Page3  Page4
Page1      -     92%    78%    85%
Page2     92%     -     81%    88%
Page3     78%    81%     -     74%
Page4     85%    88%    74%     -
```

---

## 4. Findings by Severity

### Critical Findings

Heading: Critical Findings ([N])

Description: These findings represent blocking issues that must be resolved before deployment.

#### Per-Finding Structure (Critical)

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Pass** | [Pass name that detected this] |
| **Page** | [Page name] ([/route]) |
| **Screenshot** | ![Finding screenshot](screenshots/[FINDING-ID].png) |

**What is Wrong:**
[Clear, specific description of the issue. What the user sees or experiences.]

**Why It Matters:**
[Impact on users, business, legal compliance. Quantify if possible -- e.g., "affects ~15% of users relying on screen readers" or "prevents form completion on mobile devices".]

**Root Cause:**
`[file/path/component.tsx]:[line number]`

**Recommended Fix:**
[diff showing current code vs proposed fix]

**Safe to Auto-Fix?** [Yes / No -- [reason if no]]

### High Findings

Heading: High Findings ([N])

Description: These findings significantly degrade the user experience and should be fixed within the current sprint.

#### Per-Finding Structure (High)

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Pass** | [Pass name] |
| **Page** | [Page name] ([/route]) |
| **Screenshot** | ![Finding screenshot](screenshots/[FINDING-ID].png) |

**What is Wrong:** [Description]

**Why It Matters:** [Impact]

**Root Cause:** `[file/path]:[line]`

**Recommended Fix:** [diff]

**Safe to Auto-Fix?** [Yes / No]

### Medium Findings

Heading: Medium Findings ([N])

Description: These findings represent noticeable quality gaps that users can work around.

#### Per-Finding Structure (Medium)

| Field | Value |
|-------|-------|
| **Severity** | Medium |
| **Pass** | [Pass name] |
| **Page** | [Page name] ([/route]) |
| **Screenshot** | ![Finding screenshot](screenshots/[FINDING-ID].png) |

**What is Wrong:** [Description]

**Why It Matters:** [Impact]

**Root Cause:** `[file/path]:[line]`

**Recommended Fix:** [diff]

**Safe to Auto-Fix?** [Yes / No]

### Low Findings

Heading: Low Findings ([N])

Description: Polish items and minor improvements for backlog consideration.

#### Per-Finding Structure (Low)

| Field | Value |
|-------|-------|
| **Severity** | Low |
| **Pass** | [Pass name] |
| **Page** | [Page name] ([/route]) |

**What is Wrong:** [Description]

**Recommended Fix:** [Brief recommendation -- no diff needed for Low severity]

**Safe to Auto-Fix?** [Yes / No]

---

## 5. Themes

### Purpose

Findings often share underlying causes. Fixing a theme resolves multiple findings at once.

### Per-Theme Structure

**Theme [N]: [Theme Name]**

| Attribute | Value |
|-----------|-------|
| **Root Cause** | [Description of the shared underlying issue] |
| **Affected Findings** | [FINDING-ID-1], [FINDING-ID-2], [FINDING-ID-3] |
| **Affected Pages** | [Page 1], [Page 2] |
| **Estimated Effort** | [S/M/L] |

**Unified Fix:**
[Description of a single change or set of changes that resolves all findings in this theme]

**Files to Modify:**
- `[file1.tsx]` -- [what to change]
- `[file2.css]` -- [what to change]

---

## 6. Recommendations by Impact-to-Effort Ratio

### Recommendations Table

| # | Recommendation | Impact | Effort | Ratio | Findings | Auto-Fixable? |
|---|----------------|--------|--------|-------|----------|---------------|
| 1 | [Add focus-visible rings] | High | Small | 9.0 | 6 | Yes |
| 2 | [Standardize spacing] | High | Medium | 6.0 | 12 | Partial (8/12) |
| 3 | [Add skip navigation] | Medium | Small | 6.0 | 4 | No |
| 4 | [Fix heading hierarchy] | Medium | Small | 6.0 | 3 | Yes |
| 5 | [Consolidate color tokens] | High | Large | 3.0 | 8 | No |
| 6 | [Add loading states] | Medium | Medium | 3.0 | 5 | No |
| 7 | [Improve error messages] | Medium | Medium | 3.0 | 4 | No |
| 8 | [Add animation curves] | Low | Small | 2.0 | 3 | Yes |

### Impact Scale
- **High** = Resolves Critical/High findings or fixes 5+ findings
- **Medium** = Resolves Medium findings or fixes 2-4 findings
- **Low** = Resolves Low findings or fixes 1 finding

### Effort Scale
- **Small** = < 1 hour, single file, CSS/class changes only
- **Medium** = 1-4 hours, 2-5 files, may need design decisions
- **Large** = 4+ hours, 5+ files, requires design system changes

### Ratio Calculation
Impact (High=9, Medium=3, Low=1) / Effort (Small=1, Medium=1.5, Large=3)

---

## 7. Appendix

### A. Raw Audit Data

#### Pass Scores by Page

| Pass | [Page 1] | [Page 2] | [Page 3] | Average |
|------|----------|----------|----------|---------|
| Visual Hierarchy | 4 | 3 | 4 | 3.7 |
| Emotional Design | 3 | 3 | 2 | 2.7 |
| [etc.] | | | | |

#### All Findings (Flat List)

| ID | Severity | Pass | Page | Title | Auto-Fix | Status |
|----|----------|------|------|-------|----------|--------|
| UX-001 | Critical | Accessibility | /dashboard | Missing form labels | No | Open |
| UX-002 | High | Typography | /home | 18 unique font sizes | Yes | Fixed |
| [etc.] | | | | | | |

### B. axe-core Accessibility Results

Structure for axe-core JSON report:

```json
{
  "url": "[URL]",
  "timestamp": "[ISO timestamp]",
  "violations": "[N]",
  "passes": "[N]",
  "incomplete": "[N]",
  "inapplicable": "[N]",
  "violations_detail": [
    {
      "id": "[rule-id]",
      "impact": "[critical/serious/moderate/minor]",
      "description": "[description]",
      "nodes": "[N]",
      "help_url": "[dequeuniversity URL]"
    }
  ]
}
```

### C. Performance Metrics

| Metric | [Page 1] | [Page 2] | [Page 3] | Target |
|--------|----------|----------|----------|--------|
| LCP (ms) | [value] | [value] | [value] | < 2500 |
| CLS | [value] | [value] | [value] | < 0.1 |
| FCP (ms) | [value] | [value] | [value] | < 1800 |
| TTI (ms) | [value] | [value] | [value] | < 3800 |
| Total Blocking Time (ms) | [value] | [value] | [value] | < 200 |
| DOM Nodes | [value] | [value] | [value] | < 1500 |
| Image Weight (KB) | [value] | [value] | [value] | -- |
| Font Weight (KB) | [value] | [value] | [value] | -- |

### D. Screenshots Index

| Finding ID | Page | Description | File |
|------------|------|-------------|------|
| UX-001 | /dashboard | Missing form labels | screenshots/UX-001.png |
| UX-002 | /home | Font size inconsistency | screenshots/UX-002.png |

### E. Auto-Fix Changelog (--fix mode only)

| Finding ID | File | Line | Before | After | Verified |
|------------|------|------|--------|-------|----------|
| UX-002 | src/app/page.tsx | 42 | text-xs | text-sm | Yes |
| UX-005 | src/globals.css | 18 | padding: 12px | padding: 16px | Yes |

---

## Scorecard Quick-Reference (ux-audit-scorecard.md)

This is a standalone summary file generated alongside the full report.

### Fields

- **Project Name** -- [Project Name]
- **Date** -- [YYYY-MM-DD]
- **Pages** -- [N]
- **Findings** -- [N]
- **DQS** -- [XX.X] / 100 -- [Rating]
- **DCS** -- [XX.X] / 100 -- [Rating]

#### Page Scores

| Page | DQS | C | H | M | L |
|------|-----|---|---|---|---|
| [Page 1] | XX.X | 0 | 1 | 3 | 2 |
| [Page 2] | XX.X | 0 | 2 | 1 | 4 |

#### Weakest Passes
1. [Pass name] -- [X/5] (affects [Page 1], [Page 3])
2. [Pass name] -- [X/5] (affects [Page 2])
3. [Pass name] -- [X/5] (affects all pages)

#### Quick Wins (High Impact, Low Effort)
1. [Recommendation] -- resolves [N] findings
2. [Recommendation] -- resolves [N] findings
3. [Recommendation] -- resolves [N] findings

#### Blockers (Must Fix Before Ship)
- [FINDING-ID]: [Title] ([Page])
- [FINDING-ID]: [Title] ([Page])

**Full report:** [ux-audit-report.md]
