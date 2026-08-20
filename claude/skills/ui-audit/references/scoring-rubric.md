# Scoring Rubric for UI Quality Score (UIQS)

## Per-Pass Scale (1-5)

Each of the 12 passes receives a score from 1 to 5 based on implementation quality.

| Score | Label | Meaning |
|-------|-----------|---------|
| 5 | Excellent | Production-grade. A design system team would approve without changes. Tokens, patterns, and systems are consistent, documented, and scalable. |
| 4 | Good | Minor inconsistencies exist but are not noticeable at a glance. Solid foundation with small gaps. |
| 3 | Acceptable | Works but lacks a systematic approach. Ad-hoc decisions mixed with some structure. |
| 2 | Poor | Obvious inconsistencies visible to any reviewer. Technical debt is actively accumulating. |
| 1 | Critical | No system in place. Implementation is entirely ad-hoc with no patterns or consistency. |

### Scoring Guidelines

- Score based on the **system**, not individual instances. A project with 1 bad button but a solid component library is still a 4.
- Look for **patterns**, not perfection. Consistent use of a limited token set scores higher than inconsistent use of a comprehensive one.
- **Weight severity by visibility.** Issues on primary pages/components matter more than issues on edge-case screens.

---

## UIQS Weights

Passes are weighted by their foundational impact on overall UI quality.

| Weight | Pass | Rationale |
|--------|------|-----------|
| 3x | 01 - Design Tokens | Foundation -- everything depends on tokens. Without tokens, consistency is impossible. |
| 3x | 03 - Component Quality | Core building blocks. Broken or inconsistent components cascade into broken UI everywhere. |
| 3x | 12 - UI State Coverage | User interaction quality. Missing loading, error, empty, and disabled states create dead UI. |
| 2x | 02 - CSS Architecture | Structural craft. The CSS methodology enables or limits every visual decision downstream. |
| 2x | 10 - Grid & Layout | Spatial foundation. Layout system integrity determines whether pages feel cohesive. |
| 2x | 08 - Type System | Typography craft. Readability and visual hierarchy depend on a consistent type scale. |
| 2x | 07 - Color System | Visual cohesion. Palette consistency and semantic color usage unify the entire interface. |
| 2x | 09 - Atomic Design | System architecture. Component reuse and composition patterns determine scalability. |
| 1x | 04 - Visual Regression | Polish. Rendering correctness -- overflow, clipping, z-index, alignment anomalies. |
| 1x | 05 - Gestalt Principles | Theory application. Proximity, similarity, continuity, closure in element grouping. |
| 1x | 06 - Visual Balance | Composition. Weight distribution, whitespace rhythm, and visual harmony. |
| 1x | 11 - Icon System | Detail. Icon consistency, sizing, alignment, and accessibility across the interface. |

---

## UIQS Formula

```
UIQS = (SUM of pass_score * weight) / (SUM of 5 * weight) * 100
```

### Weight Breakdown

| Weight | Count | Total Weight Units |
|--------|-------|--------------------|
| 3x | 3 passes | 9 |
| 2x | 5 passes | 10 |
| 1x | 4 passes | 4 |
| **Total** | **12 passes** | **23** |

**Maximum raw score:** 5 * 23 = 115

### Calculation Examples

| Scenario | Raw Score | UIQS |
|----------|-----------|------|
| All 5s (perfect) | 115 / 115 | 100 |
| All 4s (good) | 92 / 115 | 80 |
| All 3s (acceptable) | 69 / 115 | 60 |
| All 2s (poor) | 46 / 115 | 40 |
| Mixed (realistic) | 82 / 115 | 71 |

---

## Score Ranges

| Range | Label | Meaning |
|-------|-------|---------|
| 90-100 | System-grade | Design system team quality. Tokens, components, states, and architecture are production-ready and scalable. |
| 75-89 | Production-ready | Solid implementation. Minor polish needed but no systemic issues. Ship-ready. |
| 60-74 | Needs attention | Visible inconsistencies across pages. Some systems in place but gaps are noticeable. Sprint-level effort needed. |
| 40-59 | Design debt | Significant rework required. Multiple foundational systems missing or broken. Multi-sprint initiative. |
| < 40 | No system | Needs foundational rebuild. No consistent tokens, no component system, no architecture. Start from scratch. |

---

## UI Consistency Score (UCS)

Cross-page uniformity measured as a weighted composite (0-100). This score measures how consistently UI decisions are applied across different pages and views.

| Dimension | Weight | What's Measured |
|-----------|--------|-----------------|
| Token Usage | 20% | Percentage of style values using tokens vs hardcoded values. Higher = more consistent. |
| Component Variants | 20% | Same component (button, card, input) styled consistently across all pages. Measures variant drift. |
| Grid System | 15% | Container widths, column counts, and gap values are consistent across pages. |
| Type Scale | 15% | Font sizes follow the same ratio/scale everywhere. No orphan sizes outside the system. |
| Color Semantics | 10% | Semantic colors (success, warning, error, info) mean the same thing on every page. |
| Icon System | 10% | Same icon library, consistent sizes, consistent alignment relative to text. |
| Spacing Values | 5% | Gap, padding, and margin values pulled from a consistent scale across pages. |
| Border Radii | 5% | Radius values are consistent across similar component types (cards, inputs, buttons). |

### UCS Calculation

```
UCS = SUM(dimension_score * dimension_weight)
```

Each dimension is scored 0-100 based on the ratio of consistent instances to total instances.

---

## Finding Severity Mapping

| Severity | Criteria | Linear Priority | Example |
|----------|----------|-----------------|---------|
| Critical | System-wide inconsistency, no tokens defined, broken interactive states, missing loading/error states on primary flows | Urgent | No design tokens exist; buttons have 7 different padding values; primary form has no error state |
| High | Significant CSS issues, missing states on primary components, major type/color inconsistencies | High | Mixed CSS methodologies; 4 different font stacks; primary button missing disabled state |
| Medium | Partial token adoption, mixed icon sets, grid inconsistencies, minor state gaps | Medium | 60% token adoption; 2 icon libraries mixed; secondary pages use different grid gaps |
| Low | Minor naming issues, polish items, non-critical accessibility gaps | Low | Inconsistent class naming convention; slight spacing misalignment; missing alt text on decorative image |

---

## Design Maturity Matrix

When both `/ui-audit` (UIQS) and `/ux-audit` (DQS) have been run on the same project, plot the results on a 2x2 quadrant matrix.

```
                    High DQS (>75)
                         |
    WELL-DESIGNED        |       MATURE
    POORLY BUILT         |       SYSTEM
    (Fix implementation) |  (Maintain & scale)
                         |
  Low UIQS (<60) -------+------- High UIQS (>75)
                         |
    NEEDS                |       WELL-BUILT
    EVERYTHING           |       POORLY DESIGNED
    (Start over)         |  (Fix UX strategy)
                         |
                    Low DQS (<60)
```

### Quadrant Recommendations

| Quadrant | UIQS | DQS | Recommendation |
|----------|------|-----|----------------|
| Mature System | >75 | >75 | Maintain and scale. Focus on polish, performance, and edge cases. |
| Well-Designed, Poorly Built | <60 | >75 | Good UX strategy exists but implementation is inconsistent. Invest in design system and component quality. |
| Well-Built, Poorly Designed | >75 | <60 | Implementation is solid but UX decisions need rethinking. Invest in user research and design review. |
| Needs Everything | <60 | <60 | Both systems and strategy need work. Prioritize foundational UX decisions first, then systematize implementation. |

---

## Scoring Checklist for Auditors

Before finalizing scores, verify:

1. Every pass score has at least 3 supporting findings (positive or negative)
2. Critical/High findings in a pass cap that pass score at 2 maximum
3. Scores are relative to the project's own framework and scale (don't penalize a simple landing page for not having a full design system)
4. UCS dimensions are measured across at least 3 distinct pages/views
5. The executive summary narrative aligns with the numerical scores
