# /ios-qa-audit — Report Template

Extends `_ios-shared/report-template-shared.md`. Adds:

## Test Inventory
```
XCTest:        X test methods across Y files
Swift Testing: A test methods across B files (Swift Testing adoption %)
Snapshot:      N snapshot tests
Performance:   M perf tests
Maestro flows: F flows
```

## Coverage Heatmap
| Target | Coverage % | Risk |
|---|---|---|
| Services | NN% | High → boost to 80%+ |
| Models | NN% | Medium |
| Views | NN% | Low (snapshot is better) |
| Utils | NN% | Low |

## Critical untested flows
A bulleted list of user journeys with NO Maestro flow AND NO XCUITest:
- Sign-in flow
- Payment / checkout
- Boarding pass scan
- (etc.)

## Device matrix run
Per-device pass/fail table from the Tier 1 runtime probes.

## Recommendations sequence
Suggested order, factoring leverage:
1. Add Maestro flow for X (highest value, 30 min)
2. Add snapshot tests for Y views
3. Migrate test Z to Swift Testing
