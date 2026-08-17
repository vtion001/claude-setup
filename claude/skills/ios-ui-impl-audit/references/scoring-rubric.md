# /ios-ui-impl-audit — Scoring Rubric

Extends `_ios-shared/scoring-rubric-shared.md`. Acronym: **UIQ-iOS**.

## Pass Weights

Total: **17** (max raw 85).

| Pass | Weight | Rationale |
|---|---|---|
| 01-hit-targets | 3× | HIG-required + WCAG 2.5.5; tiny tap targets are a real-world fail |
| 02-dynamic-type | 3× | Apple-required; failing Dynamic Type breaks accessibility |
| 03-dark-mode | 2× | User preference; clipping/contrast issues are common |
| 04-size-classes | 2× | iPad layout = real-world surface |
| 05-sf-symbols | 1× | Style consistency + system-native scaling |
| 06-view-body-perf | 2× | Janky scrolls / over-recomputed bodies |
| 07-motion-reduce | 2× | Apple-required for `accessibilityReduceMotion` |
| 08-rtl-locale | 2× | Required for any internationalized app |
