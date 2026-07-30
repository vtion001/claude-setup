# UX Audit Scoring Rubric

## Per-Pass Scoring Scale (1-5)

Each audit pass is scored on a 1-5 scale with the following criteria:

### Score: 5 — Excellent
- Meets or exceeds industry best practices
- No findings of Medium severity or higher
- Implementation demonstrates intentional design decisions
- Could be used as a reference example

### Score: 4 — Good
- Minor issues only (Low severity)
- Solid implementation with small polish opportunities
- Follows established patterns consistently
- 1-3 Low-severity findings maximum

### Score: 3 — Adequate
- Functional but with clear improvement areas
- Some Medium-severity findings present
- Inconsistent application of design principles
- 1-3 Medium-severity findings or 4+ Low-severity findings

### Score: 2 — Below Standard
- Multiple significant issues affecting user experience
- High-severity findings present
- Design principles applied sporadically
- 1-2 High-severity findings or 4+ Medium-severity findings

### Score: 1 — Critical
- Fundamental design or usability problems
- Critical-severity findings present
- Actively harms user experience, accessibility, or trust
- Any Critical-severity finding or 3+ High-severity findings

---

## Design Quality Score (DQS)

### Weighted Formula

```
DQS = (sum of (pass_score * weight) / sum of (max_score * weight)) * 100
```

Where `max_score = 5` for every pass.

### Weight Assignments

| Weight | Pass | Rationale |
|--------|------|-----------|
| **3x** | Visual Hierarchy | Core usability driver; poor hierarchy = users can't find anything |
| **3x** | Emotional Design | Brand perception and user engagement hinge on emotional resonance |
| **3x** | Nielsen's 10 Heuristics | Foundational usability principles; violations indicate systemic UX debt |
| **2x** | Typography | Readability directly impacts comprehension and time-on-task |
| **2x** | Color System | Color affects accessibility, brand consistency, and cognitive load |
| **2x** | Spacing & Layout | Spatial consistency drives perceived quality and scannability |
| **2x** | Micro-interactions | Feedback loops affect perceived responsiveness and user confidence |
| **2x** | Accessibility (WCAG) | Legal requirement and ethical obligation; affects ~15% of users |
| **1x** | Laws of UX | Advanced design maturity indicators (Fitts, Hick, Miller, etc.) |
| **1x** | Dark Patterns | Trust and ethical design verification |
| **1x** | Mobile Responsiveness | Cross-device experience quality |
| **1x** | Trust & Credibility | Conversion and user confidence signals |
| **1x** | Performance UX | Perceived speed and loading experience |

### Total Weight: 24x (across 13 passes)
### Maximum Raw Score: 120 (24 * 5)

### Calculation Example

```
Pass Scores:
  Visual Hierarchy:     4 * 3 = 12
  Emotional Design:     3 * 3 =  9
  Nielsen Heuristics:   4 * 3 = 12
  Typography:           5 * 2 = 10
  Color System:         4 * 2 =  8
  Spacing & Layout:     3 * 2 =  6
  Micro-interactions:   4 * 2 =  8
  Accessibility:        2 * 2 =  4
  Laws of UX:           4 * 1 =  4
  Dark Patterns:        5 * 1 =  5
  Mobile:               3 * 1 =  3
  Trust:                4 * 1 =  4
  Performance:          4 * 1 =  4

Weighted Sum: 89
DQS = (89 / 120) * 100 = 74.2
```

---

## DQS Range Interpretation

| Range | Rating | Meaning | Action |
|-------|--------|---------|--------|
| **90-100** | Ship-ready | Production-quality design. Minor polish only. | Ship with confidence. Address Low findings in backlog. |
| **75-89** | Good | Solid design with improvement opportunities. No blockers. | Address High/Medium findings before next release. |
| **60-74** | Needs Attention | Noticeable design gaps affecting user experience. | Dedicate sprint capacity to UX debt. Prioritize High findings. |
| **40-59** | Design Debt | Significant usability and design problems. Users notice. | Dedicated UX improvement sprint required. Block feature work. |
| **< 40** | Start Over | Fundamental design issues. Redesign likely more efficient than fixing. | Engage design team for full redesign. Current implementation is actively harmful. |

---

## Finding Severity Mapping

### Critical
- **Criteria:** Users cannot complete core tasks, data loss risk, legal/compliance violation, security exposure through UI
- **Examples:** Form submits silently fail with no feedback; WCAG AAA contrast violations on primary CTAs; clickjacking-susceptible overlays; no keyboard navigation for critical flows
- **Linear Priority:** Urgent
- **SLA:** Fix before next deployment

### High
- **Criteria:** Significant usability degradation, accessibility barriers for common assistive tech, major brand inconsistency, misleading UI patterns
- **Examples:** Touch targets below 44px on primary actions; heading hierarchy skips levels; inconsistent button styles across pages; confusing error messages; missing form labels
- **Linear Priority:** High
- **SLA:** Fix within current sprint

### Medium
- **Criteria:** Suboptimal experience that users can work around, minor accessibility issues, inconsistent spacing/typography, missing micro-interactions
- **Examples:** 8px grid violations; font scale inconsistencies; missing hover states; images without alt text (decorative); inconsistent border radii
- **Linear Priority:** Medium
- **SLA:** Fix within next 2 sprints

### Low
- **Criteria:** Polish items, minor visual inconsistencies, optimization opportunities, nice-to-have improvements
- **Examples:** Suboptimal line lengths; minor color token misuse; animation timing tweaks; FOUT on secondary fonts; decorative element alignment
- **Linear Priority:** Low
- **SLA:** Address in backlog grooming

---

## Design Consistency Score

### Methodology

The Design Consistency Score (DCS) measures how uniformly design decisions are applied across all audited pages. It is calculated separately from DQS.

### Measured Dimensions

| Dimension | What's Checked | Weight |
|-----------|---------------|--------|
| Color tokens | Same semantic colors used for same purposes | 20% |
| Typography scale | Consistent font sizes, weights, line heights | 20% |
| Spacing system | Adherence to spacing scale (4px/8px grid) | 15% |
| Component variants | Same component styled the same way everywhere | 20% |
| Interactive states | Hover, focus, active states match across pages | 10% |
| Border radii | Consistent rounding across similar elements | 5% |
| Shadow system | Same elevation = same shadow everywhere | 5% |
| Icon sizing | Icons sized consistently relative to context | 5% |

### Scoring

```
DCS = (consistent_instances / total_instances) * 100
```

Where:
- `consistent_instances` = number of design decisions matching the dominant pattern
- `total_instances` = total design decisions measured across all pages

### DCS Interpretation

| Range | Rating |
|-------|--------|
| 90-100 | Highly consistent design system |
| 75-89 | Good consistency with minor drift |
| 60-74 | Noticeable inconsistencies |
| < 60 | No apparent design system enforcement |

---

## Per-Page Scorecard Template

```
┌─────────────────────────────────────────────────────┐
│  PAGE SCORECARD: [Page Name]                        │
│  URL: [/route/path]                                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  DQS: [XX.X] / 100    Rating: [Rating]              │
│                                                     │
│  ┌─────────────────────────────────────────┐        │
│  │ ████████████████████░░░░░░░░░░  74/100  │        │
│  └─────────────────────────────────────────┘        │
│                                                     │
│  PASS SCORES (weighted)              Score  Wtd     │
│  ─────────────────────────────────────────────      │
│  Visual Hierarchy          ███░░  3x   4    12      │
│  Emotional Design          ██░░░  3x   3     9      │
│  Nielsen Heuristics        ████░  3x   4    12      │
│  Typography                █████  2x   5    10      │
│  Color System              ████░  2x   4     8      │
│  Spacing & Layout          ███░░  2x   3     6      │
│  Micro-interactions        ████░  2x   4     8      │
│  Accessibility (WCAG)      ██░░░  2x   2     4      │
│  Laws of UX                ████░  1x   4     4      │
│  Dark Patterns             █████  1x   5     5      │
│  Mobile Responsiveness     ███░░  1x   3     3      │
│  Trust & Credibility       ████░  1x   4     4      │
│  Performance UX            ████░  1x   4     4      │
│                                                     │
│  FINDINGS SUMMARY                                   │
│  ─────────────────────────────────────────────      │
│  Critical: [0]  High: [2]  Medium: [5]  Low: [3]   │
│                                                     │
│  TOP ISSUES                                         │
│  1. [Finding title] (High)                          │
│  2. [Finding title] (High)                          │
│  3. [Finding title] (Medium)                        │
│                                                     │
│  AUTO-FIXABLE: [4] of [10]                          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Score Bar Legend

```
█ = achieved     ░ = remaining
Each █ represents 1 point on the 1-5 scale
```

### Multi-Page Summary Template

```
┌─────────────────────────────────────────────────────────────────┐
│  DESIGN QUALITY OVERVIEW                                        │
├──────────────────────┬──────┬────────┬──────────────────────────┤
│  Page                │  DQS │ Rating │ Findings (C/H/M/L)      │
├──────────────────────┼──────┼────────┼──────────────────────────┤
│  Homepage            │ 82.5 │ Good   │ 0 / 1 / 3 / 2           │
│  Dashboard           │ 74.2 │ Needs  │ 0 / 2 / 5 / 3           │
│  Settings            │ 68.3 │ Needs  │ 1 / 1 / 4 / 1           │
│  Login               │ 91.7 │ Ship   │ 0 / 0 / 1 / 2           │
├──────────────────────┼──────┼────────┼──────────────────────────┤
│  OVERALL             │ 79.2 │ Good   │ 1 / 4 / 13 / 8          │
│  Consistency (DCS)   │ 78.4 │ Good   │                          │
└──────────────────────┴──────┴────────┴──────────────────────────┘
```
