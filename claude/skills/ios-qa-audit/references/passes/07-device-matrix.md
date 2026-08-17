# Pass 07 — Device Matrix Coverage

**Weight:** 2×

## What this audits
Are tests (especially snapshot + Maestro) run across multiple device
classes? iPhone 17 + iPhone Air + iPhone 17 Pro Max + iPad Air 11-inch
(M4) catches 95% of layout surprises.

## Tier 0
- Read `project.yml` `supportedDestinations` / Xcode target
- Read snapshot test setup for device-class variants
- Read Maestro CI config (if exists)

## Scoring
| Score | Criteria |
|---|---|
| 5 | All snapshot/Maestro tests run on 3+ device classes + Dynamic Type extremes |
| 4 | 2-3 device classes |
| 3 | One device only but explicit iPad/iPhone awareness in code |
| 2 | One device only, no awareness |
| 1 | No tests at all (defers to other passes) |

## Common findings
| Finding | Severity |
|---|---|
| Tests only on iPhone, app supports iPad | **High** |
| No Dynamic Type variant testing | **Medium** |
| No landscape orientation testing | **Low** (if app supports it) |

## Recommended fix
- snapshot-testing: parametrize `as: .image(on: .iPhone17)` over a matrix
- Maestro: `--device "iPhone 17,iPad Air 11-inch (M4)"`

## What NOT to flag
- Apps with `supportedDestinations: [iphone]` only
