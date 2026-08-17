# /ios-code-review — Scoring Rubric

Extends `_ios-shared/scoring-rubric-shared.md`. Acronym: **CRQ-iOS**.

## Pass Weights

Total: **15** (max raw 75).

| Pass | Weight | Rationale |
|---|---|---|
| 01-swiftlint-rules | 2× | Linter config is the project's automated style enforcement |
| 02-swiftformat-config | 1× | Formatter consistency, lower stakes than linting |
| 03-dead-code-periphery | 2× | Dead code is binary bloat + cognitive load |
| 04-api-design-guidelines | 3× | The canonical Swift quality bar |
| 05-file-organization | 2× | Maintainability + onboarding speed |
| 06-dependency-hygiene | 3× | Critical for security + reproducibility |
| 07-swift-evolution-adoption | 2× | Indicates the team's Swift sophistication |
