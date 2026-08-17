# Pass 05 — File Organization

**Weight:** 2×

## What this audits
Does the file structure scale? Does one struct per file hold? Do "god
files" exist? Are concerns separated (Views, Models, Services, Utils)?

## Tier 0
```bash
# Files over N lines (configurable; default 500)
find . -name "*.swift" -type f -exec wc -l {} \; | awk '$1 > 500'

# Files declaring multiple structs/classes (potential god files)
for f in $(find . -name "*.swift" -type f); do
    count=$(grep -E "^(public |internal |private |fileprivate )?(struct|class|enum) " "$f" | wc -l)
    if [ "$count" -gt 3 ]; then echo "$f: $count types"; fi
done
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | One type per file (with helper extensions/private types OK). Clear domain folders. No file > 500 lines. |
| 4 | Mostly one-per-file. 1-2 god files <800 lines. |
| 3 | Mix; some files declare 3-4 unrelated types. |
| 2 | Several god files >1000 lines. |
| 1 | Monolithic Models.swift / Views.swift / Services.swift with 5+ types each. |

## Common findings
| Finding | Severity |
|---|---|
| File > 1000 lines containing multiple unrelated types | **Medium** |
| Models monolith (5+ unrelated struct definitions in one file) | **Medium** |
| View file with embedded helper struct that should be its own file | **Low** |
| No `Services/` directory (services scattered in `Models/`) | **Medium** |

## Recommended fix
Split into one-type-per-file. Reference Pookoo's recent refactors (per
git log): `git log --grep="refactor.*split"` shows the pattern.

## What NOT to flag
- Small helper types (under ~50 lines) embedded as `private` in their
  consumer file
- View body extracted to private `@ViewBuilder` properties in the same
  file (canonical SwiftUI pattern)
