# Pass 02 — SwiftFormat Config

**Weight:** 1×

## What this audits
Is SwiftFormat configured? Does running `swiftformat --lint .` succeed
(no proposed changes)?

## Tier 0
- Look for `.swiftformat`
- Run `swiftformat --lint .` and count file diffs

## Scoring
| Score | Criteria |
|---|---|
| 5 | `.swiftformat` present, pre-commit hook installed, zero diffs |
| 4 | Config present, < 5 file diffs (recent additions) |
| 3 | No config, but style is consistent across files (formatting-by-convention) |
| 2 | No config and style varies meaningfully across files |
| 1 | No config and broad inconsistency (different tabs/spaces, brace styles) |

## Common findings
| Finding | Severity |
|---|---|
| No `.swiftformat` | **Low** |
| Inconsistent trailing commas | **Low** |
| Mixed tabs/spaces | **Medium** |
| No pre-commit hook to enforce format | **Low** |

## Recommended fix — starter `.swiftformat`
```
--indent 4
--ifdef noindent
--commas inline
--linebreaks lf
--patternlet inline
--self remove
--stripunusedargs closure-only
--header strip
--exclude .build,Pods,DerivedData
```

## What NOT to flag
- Generated code
- Diffs introduced by a recent SwiftFormat version bump
