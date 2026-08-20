# Pass 04 — Size Classes / iPad Layout

**Weight:** 2×

## What this audits
For apps supporting iPad: do layouts use `.horizontalSizeClass`,
`NavigationSplitView`, adaptive grids? Or do they show iPhone-sized
content stretched on iPad?

## Tier 0
```bash
# Check target supports iPad
grep -E 'supportedDestinations|TARGETED_DEVICE_FAMILY' project.yml *.xcconfig 2>/dev/null

# Size-class awareness
grep -rn --include='*.swift' 'horizontalSizeClass\|verticalSizeClass\|NavigationSplitView' <project-root>
```

## Tier 1
Boot iPad sim; screenshot each tab; check for stretched content.

## Scoring
| Score | Criteria |
|---|---|
| 5 | iPad layouts use SplitView or adaptive grids; iPhone-only apps score 5 by definition |
| 4 | iPad works but not optimized |
| 3 | iPad shows iPhone-stretched content but no broken layout |
| 2 | iPad layout breaks (overflow, clipping, tiny content) |
| 1 | Crashes or unusable on iPad |

## Common findings
| Finding | Severity |
|---|---|
| iPad target with NavigationStack everywhere (vs SplitView) | **Medium** |
| Modal sheets sized for iPhone on iPad | **Medium** |
| Form fields stretched to full iPad width | **Low** |

## Pookoo
Per detection: `Pookoo.xcodeproj` lists iPad as supported destination.
Needs runtime check. Recommend NavigationSplitView for `Flights` +
`Settings` tabs.

## What NOT to flag
- iPhone-only apps (`supportedDestinations: [iphone]`)
- Apps with explicit iPad-deferred status documented
