# Pass 05 — SF Symbols Adoption

**Weight:** 1×

## What this audits
Are icons SF Symbols (auto-scaling, Dynamic Type-aware, system-native
hierarchical/multicolor variants)? Or custom image assets?

## Tier 0
```bash
SFSYMBOLS=$(grep -rn --include='*.swift' 'Image(systemName:' <project-root> | wc -l)
CUSTOM_ICONS=$(grep -rn --include='*.swift' 'Image("' <project-root> | grep -v 'systemName' | wc -l)
echo "sfsymbols=$SFSYMBOLS custom=$CUSTOM_ICONS ratio=$(echo "scale=2; $SFSYMBOLS / ($SFSYMBOLS + $CUSTOM_ICONS)" | bc)"
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | SF Symbols throughout. Custom images only for brand/logo. Variable colors and hierarchical rendering used. |
| 4 | Mostly SF Symbols. 5-10 custom icons that could be replaced. |
| 3 | Mix; 30-50% custom |
| 2 | Mostly custom icons (not auto-scaling) |
| 1 | All custom; no SF Symbols |

## Common findings
| Finding | Severity |
|---|---|
| Custom image where SF Symbol exists (`arrow.right`, `star.fill`, etc.) | **Low** |
| SF Symbol used with `.resizable()` (anti-pattern — use `.imageScale(.large)`) | **Low** |
| Custom icons not @2x/@3x | **Medium** |

## Pookoo
Heavy SF Symbol use per exploration. Score 5/5.

## What NOT to flag
- Brand logo, mascot illustrations (the owl in Pookoo)
- Custom illustrations for empty states
