# Pass 05 — WidgetKit / Live Activities

**Weight:** 2×

## What this audits
- `Widget` declarations
- `IntentConfiguration` vs `StaticConfiguration`
- `TimelineProvider` correctness
- Snapshot policy
- Live Activities (`ActivityAttributes`) if app has time-sensitive flows
- iOS 17+ interactive widgets (Button with App Intent)

## Tier 0
```bash
grep -rln --include='*.swift' 'Widget\|IntentConfiguration\|TimelineProvider\|ActivityAttributes' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Widget for primary value (e.g. "Next flight"); interactive; Live Activity for in-progress flows |
| 4 | Static widget present and useful |
| 3 | Widget exists but limited value |
| 2 | Widget exists but broken or always-stale |
| 1 | N/A — only score 1 if widgets would clearly help and don't exist |

## Pookoo
No widgets. "Next flight countdown" widget would be 10-minute add and high
user value. Flag as Medium (opportunity, not defect).

## What NOT to flag
- Utility apps where widgets genuinely don't add value
- Apps that haven't shipped widgets due to upcoming iOS feature
