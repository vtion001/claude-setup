# /ios-qa-audit — Scoring Rubric

Extends `_ios-shared/scoring-rubric-shared.md`. Acronym: **QAH-iOS**.

## Pass Weights

Total: **17** (max raw 85).

| Pass | Weight | Rationale |
|---|---|---|
| 01-xctest-coverage | 3× | Foundation; coverage gaps everywhere else are downstream |
| 02-swift-testing-adoption | 1× | Modernization, not blocking |
| 03-snapshot-tests | 2× | Visual regression catches design drift |
| 04-maestro-flows | 3× | E2E coverage; the only test that resembles real user flow |
| 05-performance-regression | 2× | Caught early = much cheaper than caught in TestFlight |
| 06-accessibility-audit | 3× | Apple-required + WCAG + ethical |
| 07-device-matrix | 2× | iPad / smaller iPhones / dynamic type catches surprises |
| 08-crashlog-integration | 1× | TestFlight crashes already aggregate; this is augmentation |
